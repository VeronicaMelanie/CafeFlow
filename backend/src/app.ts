import express from 'express';
import { prisma } from './db.js';
import { requireAuth } from './auth/requireAuth.js';
import type { TokenVerifier } from './auth/verifyToken.js';
import { getFirebaseAuth } from './firebase.js';
import {
  isPrivilegedActor,
  isSuperadminEmail,
  isSuperadminSession,
  locationCodeFromName,
} from './superadmin.js';

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatTimestamptz(value: Date): string {
  return value.toISOString();
}

function formatTimeOnly(value: Date | string | null): string | null {
  if (value == null) return null;
  if (typeof value === 'string') {
    const match = value.match(/^(\d{2}:\d{2}:\d{2})/);
    return match ? match[1] : value;
  }
  const hours = String(value.getUTCHours()).padStart(2, '0');
  const minutes = String(value.getUTCMinutes()).padStart(2, '0');
  const seconds = String(value.getUTCSeconds()).padStart(2, '0');
  return `${hours}:${minutes}:${seconds}`;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function routeUuid(value: string | string[] | undefined): string | null {
  const id = Array.isArray(value) ? value[0] : value;
  if (!id || !UUID_RE.test(id)) return null;
  return id;
}

type AvailabilityShiftTypeValue = 'full_time' | 'custom_hours';

type AvailabilityRow = {
  id: string;
  userId: string;
  workDate: Date;
  shiftType: AvailabilityShiftTypeValue;
  customStartTime: Date | string | null;
  customEndTime: Date | string | null;
  submittedAt: Date;
};

function serializeAvailability(row: AvailabilityRow) {
  return {
    id: row.id,
    user_id: row.userId,
    work_date: formatDateOnly(row.workDate),
    shift_type: row.shiftType,
    custom_start_time: formatTimeOnly(row.customStartTime),
    custom_end_time: formatTimeOnly(row.customEndTime),
    submitted_at: formatTimestamptz(row.submittedAt),
  };
}

function parseDateOnlyInput(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return date;
}

function parseTimeOnlyInput(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?$/.exec(value);
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = Number(match[3] ?? '0');
  if (hours > 23 || minutes > 59 || seconds > 59) return null;
  return new Date(Date.UTC(1970, 0, 1, hours, minutes, seconds));
}

function isUniqueViolation(error: unknown): boolean {
  return Boolean(
    error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code: unknown }).code === 'P2002',
  );
}

type ParsedAvailabilityWrite = {
  workDate?: Date;
  shiftType: AvailabilityShiftTypeValue;
  customStartTime: Date | null;
  customEndTime: Date | null;
  clientUserId?: string;
};

function parseAvailabilityWrite(
  body: unknown,
  options: { workDateRequired: boolean },
): ParsedAvailabilityWrite | { error: 'invalid_availability' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_availability' };
  }
  const data = body as Record<string, unknown>;

  if (data.user_id != null && typeof data.user_id !== 'string') {
    return { error: 'invalid_availability' };
  }
  const clientUserId =
    typeof data.user_id === 'string' && data.user_id.trim() !== ''
      ? data.user_id.trim()
      : undefined;

  let workDate: Date | undefined;
  if (options.workDateRequired || data.work_date !== undefined) {
    const parsed = parseDateOnlyInput(data.work_date);
    if (!parsed) return { error: 'invalid_availability' };
    workDate = parsed;
  }

  if (data.shift_type !== 'full_time' && data.shift_type !== 'custom_hours') {
    return { error: 'invalid_availability' };
  }

  if (data.shift_type === 'full_time') {
    return {
      workDate,
      shiftType: 'full_time',
      customStartTime: null,
      customEndTime: null,
      clientUserId,
    };
  }

  const customStartTime = parseTimeOnlyInput(data.custom_start_time);
  const customEndTime = parseTimeOnlyInput(data.custom_end_time);
  if (!customStartTime || !customEndTime) {
    return { error: 'invalid_availability' };
  }
  if (customEndTime.getTime() <= customStartTime.getTime()) {
    return { error: 'invalid_availability' };
  }

  return {
    workDate,
    shiftType: 'custom_hours',
    customStartTime,
    customEndTime,
    clientUserId,
  };
}

async function findAppUserByFirebaseUid(firebaseUid: string) {
  return prisma.user.findUnique({
    where: { firebaseUid },
    select: { id: true, firebaseUid: true, role: true, email: true },
  });
}

const USER_PUBLIC_SELECT = {
  id: true,
  firebaseUid: true,
  email: true,
  name: true,
  role: true,
  contractType: true,
  employmentStartedOn: true,
  monthlyTargetHours: true,
  needsContractType: true,
  authProvider: true,
} as const;

type PublicUserRow = {
  id: string;
  firebaseUid: string;
  email: string;
  name: string;
  role: 'employee' | 'admin';
  contractType: 'full_time' | 'part_time' | null;
  employmentStartedOn: Date | null;
  monthlyTargetHours: number;
  needsContractType: boolean;
  authProvider: 'google' | 'email' | null;
};

type ContractTypeValue = 'full_time' | 'part_time';
type AuthProviderValue = 'google' | 'email';

const ADMIN_NAME_TOKENS = ['malina', 'florin'] as const;

function serializeUser(row: PublicUserRow) {
  return {
    id: row.id,
    firebase_uid: row.firebaseUid,
    email: row.email,
    name: row.name,
    role: row.role,
    contract_type: row.contractType,
    employment_started_on: formatDateOnly(row.employmentStartedOn),
    monthly_target_hours: row.monthlyTargetHours,
    needs_contract_type: row.needsContractType,
    auth_provider: row.authProvider,
  };
}

function isPredefinedAdminName(name: string): boolean {
  const normalized = name.trim().toLowerCase();
  return ADMIN_NAME_TOKENS.some((token) => normalized.includes(token));
}

const PRODUCT_PUBLIC_SELECT = {
  id: true,
  name: true,
  categoryId: true,
  sku: true,
  isActive: true,
} as const;

function serializeProduct(row: {
  id: string;
  name: string;
  categoryId: string | null;
  sku: string | null;
  isActive: boolean;
}) {
  return {
    id: row.id,
    name: row.name,
    category_id: row.categoryId,
    sku: row.sku,
    is_active: row.isActive,
  };
}

function serializeLocation(row: {
  id: string;
  code: string;
  name: string;
  isActive: boolean;
  openedOn: Date | null;
  closedOn: Date | null;
}) {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    is_active: row.isActive,
    opened_on: formatDateOnly(row.openedOn),
    closed_on: formatDateOnly(row.closedOn),
  };
}

async function deleteUserAndRelations(userId: string) {
  await prisma.$transaction(async (tx) => {
    await tx.notification.deleteMany({ where: { userId } });
    await tx.cleaningCompletion.deleteMany({ where: { userId } });
    await tx.consumption.deleteMany({ where: { userId } });
    await tx.shift.deleteMany({ where: { userId } });
    await tx.availability.deleteMany({ where: { userId } });
    await tx.vacation.deleteMany({ where: { userId } });
    await tx.userLocation.deleteMany({ where: { userId } });
    await tx.schedulingConfig.updateMany({
      where: { enabledById: userId },
      data: { enabledById: null },
    });
    await tx.user.delete({ where: { id: userId } });
  });
}

function mapAuthProvider(value: string | undefined): AuthProviderValue {
  if (value === 'password' || value === 'email') return 'email';
  return 'google';
}

function parseContractType(
  value: unknown,
): ContractTypeValue | { error: 'invalid_user' } {
  if (value !== 'full_time' && value !== 'part_time') {
    return { error: 'invalid_user' };
  }
  return value;
}

function parseUserCreateName(
  body: unknown,
  token: { uid: string; name?: string },
): string | { error: 'invalid_user' } | { error: 'forbidden' } {
  if (body != null && (typeof body !== 'object' || Array.isArray(body))) {
    return { error: 'invalid_user' };
  }
  const data = (body ?? {}) as Record<string, unknown>;
  if (Object.hasOwn(data, 'firebase_uid')) {
    if (typeof data.firebase_uid !== 'string' || data.firebase_uid !== token.uid) {
      return { error: 'forbidden' };
    }
  }
  if (Object.hasOwn(data, 'role')) {
    return { error: 'invalid_user' };
  }
  if (data.name != null && typeof data.name !== 'string') {
    return { error: 'invalid_user' };
  }
  const fromBody = typeof data.name === 'string' ? data.name.trim() : '';
  const fromToken = (token.name ?? '').trim();
  return fromBody || fromToken || 'Employee';
}

type ParsedUserPatch = {
  name?: string;
  monthlyTargetHours?: number;
  contractType?: ContractTypeValue;
  needsContractType?: boolean;
  employmentStartedOn?: Date | null;
  employmentStartedOnSpecified: boolean;
};

function parseUserPatch(
  body: unknown,
): ParsedUserPatch | { error: 'invalid_user' } | { error: 'forbidden' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_user' };
  }
  const data = body as Record<string, unknown>;
  if (Object.hasOwn(data, 'firebase_uid')) {
    return { error: 'forbidden' };
  }
  if (
    Object.hasOwn(data, 'role') ||
    Object.hasOwn(data, 'fcm_token') ||
    Object.hasOwn(data, 'email') ||
    Object.hasOwn(data, 'auth_provider') ||
    Object.hasOwn(data, 'id')
  ) {
    return { error: 'invalid_user' };
  }

  const patch: ParsedUserPatch = { employmentStartedOnSpecified: false };

  if (Object.hasOwn(data, 'name')) {
    if (typeof data.name !== 'string' || data.name.trim() === '') {
      return { error: 'invalid_user' };
    }
    patch.name = data.name.trim();
  }

  if (Object.hasOwn(data, 'monthly_target_hours')) {
    if (
      typeof data.monthly_target_hours !== 'number' ||
      !Number.isInteger(data.monthly_target_hours) ||
      data.monthly_target_hours <= 0
    ) {
      return { error: 'invalid_user' };
    }
    patch.monthlyTargetHours = data.monthly_target_hours;
  }

  if (Object.hasOwn(data, 'contract_type')) {
    const parsed = parseContractType(data.contract_type);
    if (typeof parsed === 'object') return parsed;
    patch.contractType = parsed;
  }

  if (Object.hasOwn(data, 'needs_contract_type')) {
    if (typeof data.needs_contract_type !== 'boolean') {
      return { error: 'invalid_user' };
    }
    patch.needsContractType = data.needs_contract_type;
  }

  if (Object.hasOwn(data, 'employment_started_on')) {
    patch.employmentStartedOnSpecified = true;
    if (data.employment_started_on === null) {
      patch.employmentStartedOn = null;
    } else {
      const parsed = parseDateOnlyInput(data.employment_started_on);
      if (!parsed) return { error: 'invalid_user' };
      patch.employmentStartedOn = parsed;
    }
  }

  if (
    patch.name === undefined &&
    patch.monthlyTargetHours === undefined &&
    patch.contractType === undefined &&
    patch.needsContractType === undefined &&
    !patch.employmentStartedOnSpecified
  ) {
    return { error: 'invalid_user' };
  }

  return patch;
}

function ownerMayApplyUserPatch(patch: ParsedUserPatch): boolean {
  return (
    patch.name === undefined &&
    patch.monthlyTargetHours === undefined &&
    !patch.employmentStartedOnSpecified
  );
}

type VacationStatusValue = 'pending' | 'approved' | 'rejected';

type VacationRow = {
  id: string;
  userId: string;
  startOn: Date;
  endOn: Date;
  status: VacationStatusValue;
  adminComment: string | null;
  requestedAt: Date;
};

function serializeVacation(row: VacationRow) {
  return {
    id: row.id,
    user_id: row.userId,
    start_on: formatDateOnly(row.startOn),
    end_on: formatDateOnly(row.endOn),
    status: row.status,
    admin_comment: row.adminComment,
    requested_at: formatTimestamptz(row.requestedAt),
  };
}

type ParsedVacationCreate = {
  startOn: Date;
  endOn: Date;
  clientUserId?: string;
};

function parseVacationCreate(
  body: unknown,
): ParsedVacationCreate | { error: 'invalid_vacation' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_vacation' };
  }
  const data = body as Record<string, unknown>;
  if (data.user_id != null && typeof data.user_id !== 'string') {
    return { error: 'invalid_vacation' };
  }
  const clientUserId =
    typeof data.user_id === 'string' && data.user_id.trim() !== ''
      ? data.user_id.trim()
      : undefined;
  const startOn = parseDateOnlyInput(data.start_on);
  const endOn = parseDateOnlyInput(data.end_on);
  if (!startOn || !endOn || endOn.getTime() < startOn.getTime()) {
    return { error: 'invalid_vacation' };
  }
  return { startOn, endOn, clientUserId };
}

type ParsedVacationPatch = {
  status: 'approved' | 'rejected';
  adminComment?: string | null;
  hasAdminComment: boolean;
};

function parseVacationPatch(
  body: unknown,
): ParsedVacationPatch | { error: 'invalid_vacation' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_vacation' };
  }
  const data = body as Record<string, unknown>;
  if (data.status !== 'approved' && data.status !== 'rejected') {
    return { error: 'invalid_vacation' };
  }
  const hasAdminComment = Object.prototype.hasOwnProperty.call(
    data,
    'admin_comment',
  );
  if (
    hasAdminComment &&
    data.admin_comment != null &&
    typeof data.admin_comment !== 'string'
  ) {
    return { error: 'invalid_vacation' };
  }
  return {
    status: data.status,
    hasAdminComment,
    adminComment: hasAdminComment
      ? (data.admin_comment as string | null)
      : undefined,
  };
}

const CLEANING_LIST_KEYS = [
  'closing',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

type CleaningListKeyValue = (typeof CLEANING_LIST_KEYS)[number];

const WEEK_ID_RE = /^[0-9]{4}-W[0-9]{2}$/;

type CleaningListRow = {
  id: string;
  locationId: string;
  key: CleaningListKeyValue;
};

type CleaningTaskRow = {
  id: string;
  listId: string;
  title: string;
  sortOrder: number;
  isActive: boolean;
};

type CleaningCompletionRow = {
  id: string;
  userId: string;
  taskId: string;
  weekId: string;
  completed: boolean;
  completedAt: Date | null;
};

function serializeCleaningList(row: CleaningListRow) {
  return {
    id: row.id,
    location_id: row.locationId,
    key: row.key,
  };
}

function serializeCleaningTask(row: CleaningTaskRow) {
  return {
    id: row.id,
    list_id: row.listId,
    title: row.title,
    sort_order: row.sortOrder,
    is_active: row.isActive,
  };
}

function serializeCleaningCompletion(row: CleaningCompletionRow) {
  return {
    id: row.id,
    user_id: row.userId,
    task_id: row.taskId,
    week_id: row.weekId,
    completed: row.completed,
    completed_at: row.completedAt ? formatTimestamptz(row.completedAt) : null,
  };
}

function parseCleaningListKey(value: unknown): CleaningListKeyValue | null {
  if (typeof value !== 'string') return null;
  return (CLEANING_LIST_KEYS as readonly string[]).includes(value)
    ? (value as CleaningListKeyValue)
    : null;
}

type ParsedCleaningCompletionWrite = {
  taskId: string;
  weekId: string;
  completed: boolean;
  clientUserId?: string;
};

function parseCleaningCompletionWrite(
  body: unknown,
): ParsedCleaningCompletionWrite | { error: 'invalid_cleaning' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_cleaning' };
  }
  const data = body as Record<string, unknown>;
  const taskId = routeUuid(
    typeof data.task_id === 'string' ? data.task_id : undefined,
  );
  if (!taskId) return { error: 'invalid_cleaning' };
  if (typeof data.week_id !== 'string' || !WEEK_ID_RE.test(data.week_id)) {
    return { error: 'invalid_cleaning' };
  }
  if (typeof data.completed !== 'boolean') {
    return { error: 'invalid_cleaning' };
  }
  if (data.user_id != null && typeof data.user_id !== 'string') {
    return { error: 'invalid_cleaning' };
  }
  const clientUserId =
    typeof data.user_id === 'string' && data.user_id.trim() !== ''
      ? data.user_id.trim()
      : undefined;
  if (clientUserId && !routeUuid(clientUserId)) {
    return { error: 'invalid_cleaning' };
  }
  return {
    taskId,
    weekId: data.week_id,
    completed: data.completed,
    clientUserId,
  };
}

type ParsedCleaningTaskCreate = {
  title: string;
  listId?: string;
  locationName?: string;
  key?: CleaningListKeyValue;
};

function parseCleaningTaskCreate(
  body: unknown,
): ParsedCleaningTaskCreate | { error: 'invalid_cleaning' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_cleaning' };
  }
  const data = body as Record<string, unknown>;
  if (typeof data.title !== 'string' || data.title.trim() === '') {
    return { error: 'invalid_cleaning' };
  }
  const listId = routeUuid(
    typeof data.list_id === 'string' ? data.list_id : undefined,
  );
  if (listId) {
    return { title: data.title.trim(), listId };
  }
  if (typeof data.location !== 'string' || data.location.trim() === '') {
    return { error: 'invalid_cleaning' };
  }
  const key = parseCleaningListKey(data.key);
  if (!key) return { error: 'invalid_cleaning' };
  return {
    title: data.title.trim(),
    locationName: data.location.trim(),
    key,
  };
}

type ParsedCleaningTaskPatch = {
  title?: string;
  sortOrder?: number;
  isActive?: boolean;
};

function parseCleaningTaskPatch(
  body: unknown,
): ParsedCleaningTaskPatch | { error: 'invalid_cleaning' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_cleaning' };
  }
  const data = body as Record<string, unknown>;
  const parsed: ParsedCleaningTaskPatch = {};
  if (data.title !== undefined) {
    if (typeof data.title !== 'string' || data.title.trim() === '') {
      return { error: 'invalid_cleaning' };
    }
    parsed.title = data.title.trim();
  }
  if (data.sort_order !== undefined) {
    if (
      typeof data.sort_order !== 'number' ||
      !Number.isInteger(data.sort_order) ||
      data.sort_order < 0
    ) {
      return { error: 'invalid_cleaning' };
    }
    parsed.sortOrder = data.sort_order;
  }
  if (data.is_active !== undefined) {
    if (typeof data.is_active !== 'boolean') {
      return { error: 'invalid_cleaning' };
    }
    parsed.isActive = data.is_active;
  }
  if (
    parsed.title === undefined &&
    parsed.sortOrder === undefined &&
    parsed.isActive === undefined
  ) {
    return { error: 'invalid_cleaning' };
  }
  return parsed;
}

function parseCleaningTaskReorder(
  body: unknown,
): { ids: string[] } | { error: 'invalid_cleaning' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_cleaning' };
  }
  const data = body as Record<string, unknown>;
  if (!Array.isArray(data.ids) || data.ids.length === 0) {
    return { error: 'invalid_cleaning' };
  }
  const ids: string[] = [];
  for (const item of data.ids) {
    if (typeof item !== 'string') return { error: 'invalid_cleaning' };
    const id = routeUuid(item);
    if (!id) return { error: 'invalid_cleaning' };
    ids.push(id);
  }
  if (new Set(ids).size !== ids.length) {
    return { error: 'invalid_cleaning' };
  }
  return { ids };
}

type ConsumptionRow = {
  id: string;
  userId: string;
  productId: string;
  locationId: string;
  quantity: { toString(): string } | number;
  consumedOn: Date;
  loggedAt: Date;
  notes: string | null;
  product?: { name: string } | null;
};

const consumptionSelect = {
  id: true,
  userId: true,
  productId: true,
  locationId: true,
  quantity: true,
  consumedOn: true,
  loggedAt: true,
  notes: true,
  product: { select: { name: true } },
} as const;

function serializeConsumption(row: ConsumptionRow) {
  return {
    id: row.id,
    user_id: row.userId,
    product_id: row.productId,
    product_name: row.product?.name ?? null,
    location_id: row.locationId,
    quantity: Number(row.quantity),
    consumed_on: formatDateOnly(row.consumedOn),
    logged_at: formatTimestamptz(row.loggedAt),
    notes: row.notes,
  };
}

function parseConsumptionQuantity(value: unknown): number | null {
  const numeric =
    typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
  if (typeof numeric !== 'number' || !Number.isFinite(numeric) || numeric <= 0) {
    return null;
  }
  return numeric;
}

function parseProductName(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().replace(/\s+/g, ' ');
  if (trimmed.length < 1 || trimmed.length > 80) return null;
  return trimmed;
}

function parseConsumptionNotes(value: unknown): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

type ParsedConsumptionCreate = {
  productId?: string;
  productName?: string;
  consumedOn: Date;
  quantity: number;
  notes: string | null;
  locationId?: string;
  clientUserId?: string;
};

function parseConsumptionCreate(
  body: unknown,
): ParsedConsumptionCreate | { error: 'invalid_consumption' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_consumption' };
  }
  const data = body as Record<string, unknown>;
  const productId = routeUuid(
    typeof data.product_id === 'string' ? data.product_id : undefined,
  );
  const productName = parseProductName(data.product_name);
  const consumedOn = parseDateOnlyInput(data.consumed_on);
  const quantity = parseConsumptionQuantity(data.quantity);
  if ((!productId && !productName) || !consumedOn || quantity == null) {
    return { error: 'invalid_consumption' };
  }
  if (data.notes !== undefined && data.notes !== null && typeof data.notes !== 'string') {
    return { error: 'invalid_consumption' };
  }
  if (data.user_id != null && typeof data.user_id !== 'string') {
    return { error: 'invalid_consumption' };
  }
  const clientUserId =
    typeof data.user_id === 'string' && data.user_id.trim() !== ''
      ? data.user_id.trim()
      : undefined;
  if (clientUserId && !routeUuid(clientUserId)) {
    return { error: 'invalid_consumption' };
  }
  const locationId = routeUuid(
    typeof data.location_id === 'string' ? data.location_id : undefined,
  );
  if (data.location_id != null && !locationId) {
    return { error: 'invalid_consumption' };
  }
  return {
    productId: productId ?? undefined,
    productName: productName ?? undefined,
    consumedOn,
    quantity,
    notes: parseConsumptionNotes(data.notes) ?? null,
    locationId: locationId ?? undefined,
    clientUserId,
  };
}

type ParsedConsumptionPatch = {
  productId?: string;
  productName?: string;
  quantity?: number;
  notes?: string | null;
  hasNotes: boolean;
};

function parseConsumptionPatch(
  body: unknown,
): ParsedConsumptionPatch | { error: 'invalid_consumption' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_consumption' };
  }
  const data = body as Record<string, unknown>;
  const parsed: ParsedConsumptionPatch = { hasNotes: false };
  if (data.product_id !== undefined) {
    const productId = routeUuid(
      typeof data.product_id === 'string' ? data.product_id : undefined,
    );
    if (!productId) return { error: 'invalid_consumption' };
    parsed.productId = productId;
  }
  if (data.product_name !== undefined) {
    const productName = parseProductName(data.product_name);
    if (!productName) return { error: 'invalid_consumption' };
    parsed.productName = productName;
  }
  if (data.quantity !== undefined) {
    const quantity = parseConsumptionQuantity(data.quantity);
    if (quantity == null) return { error: 'invalid_consumption' };
    parsed.quantity = quantity;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'notes')) {
    if (data.notes !== null && typeof data.notes !== 'string') {
      return { error: 'invalid_consumption' };
    }
    parsed.hasNotes = true;
    parsed.notes = parseConsumptionNotes(data.notes) ?? null;
  }
  if (
    parsed.productId === undefined &&
    parsed.productName === undefined &&
    parsed.quantity === undefined &&
    !parsed.hasNotes
  ) {
    return { error: 'invalid_consumption' };
  }
  return parsed;
}

async function findOrCreateProductByName(name: string): Promise<string> {
  const existing = await prisma.product.findFirst({
    where: { name: { equals: name, mode: 'insensitive' } },
    select: { id: true },
    orderBy: { createdAt: 'asc' },
  });
  if (existing) return existing.id;
  const created = await prisma.product.create({
    data: { name, isActive: true },
    select: { id: true },
  });
  return created.id;
}

async function resolveConsumptionLocation(
  userId: string,
  consumedOn: Date,
  requestedLocationId?: string,
): Promise<string | null> {
  if (requestedLocationId) {
    const assigned = await prisma.userLocation.findFirst({
      where: {
        userId,
        locationId: requestedLocationId,
        validFrom: { lte: consumedOn },
        OR: [{ validUntil: null }, { validUntil: { gte: consumedOn } }],
      },
      select: { locationId: true },
    });
    if (assigned) return assigned.locationId;
  }

  const shifts = await prisma.shift.findMany({
    where: { userId, workDate: consumedOn },
    select: { locationId: true },
  });
  const shiftLocations = [...new Set(shifts.map((row) => row.locationId))];
  if (shiftLocations.length === 1) return shiftLocations[0];
  if (
    shiftLocations.length > 1 &&
    requestedLocationId &&
    shiftLocations.includes(requestedLocationId)
  ) {
    return requestedLocationId;
  }

  const assignments = await prisma.userLocation.findMany({
    where: {
      userId,
      validFrom: { lte: consumedOn },
      OR: [{ validUntil: null }, { validUntil: { gte: consumedOn } }],
    },
    select: { locationId: true, isPrimary: true },
  });
  const unique = [...new Set(assignments.map((row) => row.locationId))];
  if (unique.length === 1) return unique[0];
  const primary = [
    ...new Set(
      assignments.filter((row) => row.isPrimary).map((row) => row.locationId),
    ),
  ];
  if (primary.length === 1) return primary[0];
  if (requestedLocationId && unique.includes(requestedLocationId)) {
    return requestedLocationId;
  }
  const preferred =
    assignments.find((row) => row.isPrimary) ?? assignments[0];
  if (preferred) return preferred.locationId;

  const fallbackLocation = await prisma.location.findFirst({
    where: { isActive: true },
    orderBy: { name: 'asc' },
    select: { id: true },
  });
  return fallbackLocation?.id ?? null;
}

const schedulingConfigSelect = {
  id: true,
  year: true,
  month: true,
  locationId: true,
  schedulingEnabled: true,
  lockedMonth: true,
  enabledById: true,
  enabledAt: true,
  maxHoursPerDay: true,
  maxEmployeesPerShift: true,
} as const;

function serializeSchedulingConfig(row: {
  id: string;
  year: number;
  month: number;
  locationId: string | null;
  schedulingEnabled: boolean;
  lockedMonth: boolean;
  enabledById: string | null;
  enabledAt: Date | null;
  maxHoursPerDay: unknown;
  maxEmployeesPerShift: number | null;
}) {
  return {
    id: row.id,
    year: row.year,
    month: row.month,
    location_id: row.locationId,
    scheduling_enabled: row.schedulingEnabled,
    locked_month: row.lockedMonth,
    enabled_by: row.enabledById,
    enabled_at: row.enabledAt ? formatTimestamptz(row.enabledAt) : null,
    max_hours_per_day:
      row.maxHoursPerDay == null ? null : Number(row.maxHoursPerDay),
    max_employees_per_shift: row.maxEmployeesPerShift,
  };
}

function parseCalendarYear(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value)) return null;
  if (value < 2000 || value > 2100) return null;
  return value;
}

function parseCalendarMonth(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value)) return null;
  if (value < 1 || value > 12) return null;
  return value;
}

function parseOptionalBoolean(
  value: unknown,
): boolean | undefined | 'invalid' {
  if (value === undefined) return undefined;
  if (typeof value !== 'boolean') return 'invalid';
  return value;
}

type ParsedSchedulingCreate = {
  year: number;
  month: number;
  locationName?: string;
  locationId?: string;
  schedulingEnabled?: boolean;
  lockedMonth?: boolean;
};

function parseSchedulingCreate(
  body: unknown,
): ParsedSchedulingCreate | { error: 'invalid_scheduling' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_scheduling' };
  }
  const data = body as Record<string, unknown>;
  const year = parseCalendarYear(data.year);
  const month = parseCalendarMonth(data.month);
  if (year == null || month == null) return { error: 'invalid_scheduling' };

  const schedulingEnabled = parseOptionalBoolean(data.scheduling_enabled);
  if (schedulingEnabled === 'invalid') return { error: 'invalid_scheduling' };
  const lockedMonth = parseOptionalBoolean(data.locked_month);
  if (lockedMonth === 'invalid') return { error: 'invalid_scheduling' };
  if (schedulingEnabled === undefined && lockedMonth === undefined) {
    return { error: 'invalid_scheduling' };
  }

  let locationId: string | undefined;
  if (data.location_id != null && data.location_id !== '') {
    if (typeof data.location_id !== 'string') {
      return { error: 'invalid_scheduling' };
    }
    const id = routeUuid(data.location_id);
    if (!id) return { error: 'invalid_scheduling' };
    locationId = id;
  }

  let locationName: string | undefined;
  if (data.location != null && data.location !== '') {
    if (typeof data.location !== 'string') {
      return { error: 'invalid_scheduling' };
    }
    const name = data.location.trim();
    if (!name) return { error: 'invalid_scheduling' };
    locationName = name;
  }

  return {
    year,
    month,
    locationName,
    locationId,
    schedulingEnabled,
    lockedMonth,
  };
}

type ParsedSchedulingPatch = {
  schedulingEnabled?: boolean;
  lockedMonth?: boolean;
};

function parseSchedulingPatch(
  body: unknown,
): ParsedSchedulingPatch | { error: 'invalid_scheduling' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_scheduling' };
  }
  const data = body as Record<string, unknown>;
  const schedulingEnabled = parseOptionalBoolean(data.scheduling_enabled);
  if (schedulingEnabled === 'invalid') return { error: 'invalid_scheduling' };
  const lockedMonth = parseOptionalBoolean(data.locked_month);
  if (lockedMonth === 'invalid') return { error: 'invalid_scheduling' };
  if (schedulingEnabled === undefined && lockedMonth === undefined) {
    return { error: 'invalid_scheduling' };
  }
  return { schedulingEnabled, lockedMonth };
}

async function resolveSchedulingLocationId(parsed: {
  locationId?: string;
  locationName?: string;
}): Promise<string | null | { error: 'invalid_scheduling' | 'not_found' }> {
  if (parsed.locationId) {
    const location = await prisma.location.findUnique({
      where: { id: parsed.locationId },
      select: { id: true, name: true },
    });
    if (!location) return { error: 'not_found' };
    if (parsed.locationName && location.name !== parsed.locationName) {
      return { error: 'invalid_scheduling' };
    }
    return location.id;
  }
  if (parsed.locationName) {
    const location = await prisma.location.findFirst({
      where: { name: parsed.locationName },
      select: { id: true },
    });
    if (!location) return { error: 'not_found' };
    return location.id;
  }
  return null;
}

function schedulingEnabledWriteData(
  actorId: string,
  schedulingEnabled: boolean,
  lockedMonth: boolean | undefined,
) {
  return {
    schedulingEnabled,
    lockedMonth: lockedMonth ?? false,
    enabledAt: new Date(),
    enabledById: actorId,
  };
}

type ShiftTypeValue = 'FULL' | 'CUSTOM' | 'VACATION';
type ShiftStatusValue = 'pending' | 'approved' | 'auto_assigned';

const shiftSelect = {
  id: true,
  userId: true,
  locationId: true,
  workDate: true,
  startAt: true,
  endAt: true,
  shiftType: true,
  status: true,
} as const;

function serializeShift(row: {
  id: string;
  userId: string;
  locationId: string;
  workDate: Date;
  startAt: Date;
  endAt: Date;
  shiftType: ShiftTypeValue;
  status: ShiftStatusValue;
}) {
  return {
    id: row.id,
    user_id: row.userId,
    location_id: row.locationId,
    work_date: formatDateOnly(row.workDate),
    start_at: formatTimestamptz(row.startAt),
    end_at: formatTimestamptz(row.endAt),
    type: row.shiftType,
    status: row.status,
  };
}

function parseTimestamptzInput(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(
      value,
    )
  ) {
    return null;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

function parseShiftType(value: unknown): ShiftTypeValue | null {
  if (value === 'FULL' || value === 'CUSTOM' || value === 'VACATION') {
    return value;
  }
  return null;
}

function parseShiftStatus(value: unknown): ShiftStatusValue | null {
  if (value === 'pending' || value === 'approved') return value;
  if (value === 'auto_assigned' || value === 'auto-assigned') {
    return 'auto_assigned';
  }
  return null;
}

type ParsedShiftWrite = {
  userId: string;
  locationName?: string;
  locationId?: string;
  workDate: Date;
  startAt: Date;
  endAt: Date;
  shiftType: ShiftTypeValue;
  status: ShiftStatusValue;
};

function parseShiftWrite(
  body: unknown,
  options: { userIdRequired: boolean },
): ParsedShiftWrite | { error: 'invalid_shift' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_shift' };
  }
  const data = body as Record<string, unknown>;

  let userId: string | undefined;
  if (data.user_id != null && data.user_id !== '') {
    if (typeof data.user_id !== 'string') return { error: 'invalid_shift' };
    const id = routeUuid(data.user_id);
    if (!id) return { error: 'invalid_shift' };
    userId = id;
  } else if (options.userIdRequired) {
    return { error: 'invalid_shift' };
  }

  let locationId: string | undefined;
  if (data.location_id != null && data.location_id !== '') {
    if (typeof data.location_id !== 'string') return { error: 'invalid_shift' };
    const id = routeUuid(data.location_id);
    if (!id) return { error: 'invalid_shift' };
    locationId = id;
  }

  let locationName: string | undefined;
  if (data.location != null && data.location !== '') {
    if (typeof data.location !== 'string') return { error: 'invalid_shift' };
    const name = data.location.trim();
    if (!name) return { error: 'invalid_shift' };
    locationName = name;
  }

  if (!locationId && !locationName && options.userIdRequired) {
    return { error: 'invalid_shift' };
  }

  const workDate = parseDateOnlyInput(data.work_date);
  if (!workDate) return { error: 'invalid_shift' };
  const startAt = parseTimestamptzInput(data.start_at);
  const endAt = parseTimestamptzInput(data.end_at);
  if (!startAt || !endAt) return { error: 'invalid_shift' };
  if (endAt.getTime() < startAt.getTime()) return { error: 'invalid_shift' };

  const shiftType = parseShiftType(data.type);
  const status = parseShiftStatus(data.status);
  if (!shiftType || !status) return { error: 'invalid_shift' };

  return {
    userId: userId ?? '',
    locationName,
    locationId,
    workDate,
    startAt,
    endAt,
    shiftType,
    status,
  };
}

type ParsedShiftPatch = {
  locationName?: string;
  locationId?: string;
  workDate?: Date;
  startAt?: Date;
  endAt?: Date;
  shiftType?: ShiftTypeValue;
  status?: ShiftStatusValue;
};

function parseShiftPatch(
  body: unknown,
): ParsedShiftPatch | { error: 'invalid_shift' } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'invalid_shift' };
  }
  const data = body as Record<string, unknown>;
  const patch: ParsedShiftPatch = {};

  if (data.work_date !== undefined) {
    const workDate = parseDateOnlyInput(data.work_date);
    if (!workDate) return { error: 'invalid_shift' };
    patch.workDate = workDate;
  }
  if (data.start_at !== undefined) {
    const startAt = parseTimestamptzInput(data.start_at);
    if (!startAt) return { error: 'invalid_shift' };
    patch.startAt = startAt;
  }
  if (data.end_at !== undefined) {
    const endAt = parseTimestamptzInput(data.end_at);
    if (!endAt) return { error: 'invalid_shift' };
    patch.endAt = endAt;
  }
  if (data.type !== undefined) {
    const shiftType = parseShiftType(data.type);
    if (!shiftType) return { error: 'invalid_shift' };
    patch.shiftType = shiftType;
  }
  if (data.status !== undefined) {
    const status = parseShiftStatus(data.status);
    if (!status) return { error: 'invalid_shift' };
    patch.status = status;
  }
  if (data.location_id != null && data.location_id !== '') {
    if (typeof data.location_id !== 'string') return { error: 'invalid_shift' };
    const id = routeUuid(data.location_id);
    if (!id) return { error: 'invalid_shift' };
    patch.locationId = id;
  }
  if (data.location != null && data.location !== '') {
    if (typeof data.location !== 'string') return { error: 'invalid_shift' };
    const name = data.location.trim();
    if (!name) return { error: 'invalid_shift' };
    patch.locationName = name;
  }

  if (
    patch.workDate === undefined &&
    patch.startAt === undefined &&
    patch.endAt === undefined &&
    patch.shiftType === undefined &&
    patch.status === undefined &&
    patch.locationId === undefined &&
    patch.locationName === undefined
  ) {
    return { error: 'invalid_shift' };
  }
  return patch;
}

async function resolveShiftLocationId(parsed: {
  locationId?: string;
  locationName?: string;
}): Promise<string | { error: 'invalid_shift' | 'not_found' }> {
  if (parsed.locationId) {
    const location = await prisma.location.findUnique({
      where: { id: parsed.locationId },
      select: { id: true, name: true },
    });
    if (!location) return { error: 'not_found' };
    if (parsed.locationName && location.name !== parsed.locationName) {
      return { error: 'invalid_shift' };
    }
    return location.id;
  }
  if (parsed.locationName) {
    const location = await prisma.location.findFirst({
      where: { name: parsed.locationName },
      select: { id: true },
    });
    if (!location) return { error: 'not_found' };
    return location.id;
  }
  return { error: 'invalid_shift' };
}

const LOCAL_WEB_ORIGINS = [
  'http://127.0.0.1:8765',
  'http://localhost:8765',
] as const;

const PRODUCTION_WEB_ORIGINS = [
  'https://cafeflow-5tg.web.app',
] as const;

function extraCorsOrigins(env: NodeJS.ProcessEnv): string[] {
  const raw = env.CORS_ORIGINS ?? '';
  const requireHttps = env.NODE_ENV === 'production';
  const origins: string[] = [];
  for (const part of raw.split(',')) {
    const origin = part.trim();
    if (!origin) continue;
    let url: URL;
    try {
      url = new URL(origin);
    } catch {
      continue;
    }
    if (url.protocol !== 'https:' && url.protocol !== 'http:') continue;
    if (requireHttps && url.protocol !== 'https:') continue;
    if (origin !== `${url.protocol}//${url.host}`) continue;
    origins.push(origin);
  }
  return origins;
}

export function corsAllowlist(
  env: NodeJS.ProcessEnv = process.env,
): Set<string> {
  const origins = new Set<string>(PRODUCTION_WEB_ORIGINS);
  if (env.NODE_ENV !== 'production') {
    for (const origin of LOCAL_WEB_ORIGINS) origins.add(origin);
  }
  for (const origin of extraCorsOrigins(env)) origins.add(origin);
  return origins;
}

function applyWebCors(
  req: express.Request,
  res: express.Response,
  next: express.NextFunction,
) {
  const origin = req.headers.origin;
  if (typeof origin === 'string' && corsAllowlist().has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, Accept',
    );
    res.setHeader(
      'Access-Control-Allow-Methods',
      'GET, HEAD, POST, PATCH, PUT, DELETE, OPTIONS',
    );
    res.setHeader('Access-Control-Max-Age', '600');
  }
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
}

export function createApp(verifyIdToken: TokenVerifier) {
  const app = express();
  app.disable('x-powered-by');
  if (process.env.NODE_ENV === 'production') {
    app.set('trust proxy', 1);
  }
  app.use(applyWebCors);
  app.use(express.json({ limit: '256kb' }));

  app.get('/health', async (_req, res) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      res.json({
        status: 'ok',
        database: 'connected',
      });
    } catch {
      res.status(503).json({
        status: 'error',
        database: 'disconnected',
      });
    }
  });

  app.get('/api/auth/me', requireAuth(verifyIdToken), (req, res) => {
    const user = req.authUser;
    if (!user) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }

    res.json({
      authenticated: true,
      uid: user.uid,
      email: user.email ?? null,
      name: user.name ?? null,
      is_superadmin: isSuperadminSession(user),
    });
  });

  app.get('/api/users', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.user.findMany({
        select: USER_PUBLIC_SELECT,
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeUser(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post('/api/users', requireAuth(verifyIdToken), async (req, res) => {
    try {
      const authUser = req.authUser;
      if (!authUser) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      const parsedName = parseUserCreateName(req.body, authUser);
      if (typeof parsedName === 'object') {
        res.status(parsedName.error === 'forbidden' ? 403 : 400).json({
          error: parsedName.error,
        });
        return;
      }

      const existing = await prisma.user.findUnique({
        where: { firebaseUid: authUser.uid },
        select: USER_PUBLIC_SELECT,
      });
      if (existing) {
        res.json(serializeUser(existing));
        return;
      }

      const row = await prisma.user.create({
        data: {
          firebaseUid: authUser.uid,
          email: authUser.email ?? '',
          name: parsedName,
          role: isPredefinedAdminName(parsedName) ? 'admin' : 'employee',
          contractType: null,
          monthlyTargetHours: 160,
          needsContractType: true,
          authProvider: mapAuthProvider(authUser.authProvider),
        },
        select: USER_PUBLIC_SELECT,
      });
      res.status(201).json(serializeUser(row));
    } catch (error) {
      if (isUniqueViolation(error)) {
        const existing = await prisma.user.findUnique({
          where: { firebaseUid: req.authUser?.uid ?? '' },
          select: USER_PUBLIC_SELECT,
        });
        if (existing) {
          res.json(serializeUser(existing));
          return;
        }
        res.status(409).json({ error: 'conflict' });
        return;
      }
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.patch('/api/users/:id', requireAuth(verifyIdToken), async (req, res) => {
    try {
      const authUser = req.authUser;
      if (!authUser) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      const id = routeUuid(req.params.id);
      if (!id) {
        res.status(400).json({ error: 'invalid_user' });
        return;
      }

      const actor = await findAppUserByFirebaseUid(authUser.uid);
      if (!actor) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const parsed = parseUserPatch(req.body);
      if ('error' in parsed) {
        res.status(parsed.error === 'forbidden' ? 403 : 400).json({
          error: parsed.error,
        });
        return;
      }

      const existing = await prisma.user.findUnique({
        where: { id },
        select: USER_PUBLIC_SELECT,
      });
      if (!existing) {
        res.status(404).json({ error: 'not_found' });
        return;
      }

      const isOwner = actor.id === existing.id;
      const isAdmin = isPrivilegedActor(actor, authUser);
      if (!isOwner && !isAdmin) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }
      if (isOwner && !isAdmin && !ownerMayApplyUserPatch(parsed)) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const needsContractType =
        parsed.needsContractType !== undefined
          ? parsed.needsContractType
          : parsed.contractType !== undefined && isOwner && !isAdmin
            ? false
            : undefined;

      const row = await prisma.user.update({
        where: { id },
        data: {
          ...(parsed.name !== undefined ? { name: parsed.name } : {}),
          ...(parsed.monthlyTargetHours !== undefined
            ? { monthlyTargetHours: parsed.monthlyTargetHours }
            : {}),
          ...(parsed.contractType !== undefined
            ? { contractType: parsed.contractType }
            : {}),
          ...(needsContractType !== undefined ? { needsContractType } : {}),
          ...(parsed.employmentStartedOnSpecified
            ? { employmentStartedOn: parsed.employmentStartedOn }
            : {}),
        },
        select: USER_PUBLIC_SELECT,
      });
      res.json(serializeUser(row));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.get('/api/locations', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.location.findMany({
        select: {
          id: true,
          code: true,
          name: true,
          isActive: true,
          openedOn: true,
          closedOn: true,
        },
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
      });

      res.json(
        rows.map((row) => ({
          id: row.id,
          code: row.code,
          name: row.name,
          is_active: row.isActive,
          opened_on: formatDateOnly(row.openedOn),
          closed_on: formatDateOnly(row.closedOn),
        })),
      );
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.get('/api/shifts', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.shift.findMany({
        select: shiftSelect,
        orderBy: [{ workDate: 'asc' }, { startAt: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeShift(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post(
    '/api/shifts/bulk',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }
        const items = (req.body as { shifts?: unknown }).shifts;
        if (!Array.isArray(items) || items.length === 0 || items.length > 500) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }

        const parsedItems: Array<
          ParsedShiftWrite & { locationUuid: string }
        > = [];
        for (const item of items) {
          const parsed = parseShiftWrite(item, { userIdRequired: true });
          if ('error' in parsed) {
            res.status(400).json({ error: 'invalid_shift' });
            return;
          }
          const locationId = await resolveShiftLocationId(parsed);
          if (typeof locationId === 'object') {
            res.status(locationId.error === 'not_found' ? 404 : 400).json({
              error: locationId.error,
            });
            return;
          }
          const user = await prisma.user.findUnique({
            where: { id: parsed.userId },
            select: { id: true },
          });
          if (!user) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
          parsedItems.push({ ...parsed, locationUuid: locationId });
        }

        const rows = await prisma.$transaction(
          parsedItems.map((item) =>
            prisma.shift.create({
              data: {
                userId: item.userId,
                locationId: item.locationUuid,
                workDate: item.workDate,
                startAt: item.startAt,
                endAt: item.endAt,
                shiftType: item.shiftType,
                status: item.status,
              },
              select: shiftSelect,
            }),
          ),
        );
        res.status(201).json(rows.map((row) => serializeShift(row)));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.post('/api/shifts', requireAuth(verifyIdToken), async (req, res) => {
    try {
      const authUser = req.authUser;
      if (!authUser) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      const actor = await findAppUserByFirebaseUid(authUser.uid);
      if (!actor) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const parsed = parseShiftWrite(req.body, { userIdRequired: true });
      if ('error' in parsed) {
        res.status(400).json({ error: 'invalid_shift' });
        return;
      }
      if (!isPrivilegedActor(actor, authUser) && parsed.userId !== actor.id) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const locationId = await resolveShiftLocationId(parsed);
      if (typeof locationId === 'object') {
        res.status(locationId.error === 'not_found' ? 404 : 400).json({
          error: locationId.error,
        });
        return;
      }

      const user = await prisma.user.findUnique({
        where: { id: parsed.userId },
        select: { id: true },
      });
      if (!user) {
        res.status(404).json({ error: 'not_found' });
        return;
      }

      const row = await prisma.shift.create({
        data: {
          userId: parsed.userId,
          locationId,
          workDate: parsed.workDate,
          startAt: parsed.startAt,
          endAt: parsed.endAt,
          shiftType: parsed.shiftType,
          status: parsed.status,
        },
        select: shiftSelect,
      });
      res.status(201).json(serializeShift(row));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.patch(
    '/api/shifts/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseShiftPatch(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }

        const existing = await prisma.shift.findUnique({
          where: { id },
          select: {
            id: true,
            userId: true,
            startAt: true,
            endAt: true,
          },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser) && existing.userId !== actor.id) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        let locationId: string | undefined;
        if (parsed.locationId || parsed.locationName) {
          const resolved = await resolveShiftLocationId(parsed);
          if (typeof resolved === 'object') {
            res.status(resolved.error === 'not_found' ? 404 : 400).json({
              error: resolved.error,
            });
            return;
          }
          locationId = resolved;
        }

        const nextStart = parsed.startAt ?? existing.startAt;
        const nextEnd = parsed.endAt ?? existing.endAt;
        if (nextEnd.getTime() < nextStart.getTime()) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }

        const row = await prisma.shift.update({
          where: { id },
          data: {
            ...(parsed.workDate ? { workDate: parsed.workDate } : {}),
            ...(parsed.startAt ? { startAt: parsed.startAt } : {}),
            ...(parsed.endAt ? { endAt: parsed.endAt } : {}),
            ...(parsed.shiftType ? { shiftType: parsed.shiftType } : {}),
            ...(parsed.status ? { status: parsed.status } : {}),
            ...(locationId ? { locationId } : {}),
          },
          select: shiftSelect,
        });
        res.json(serializeShift(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/shifts/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_shift' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const existing = await prisma.shift.findUnique({
          where: { id },
          select: { id: true, userId: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser) && existing.userId !== actor.id) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        await prisma.shift.delete({ where: { id } });
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/availability', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.availability.findMany({
        select: {
          id: true,
          userId: true,
          workDate: true,
          shiftType: true,
          customStartTime: true,
          customEndTime: true,
          submittedAt: true,
        },
        orderBy: [{ workDate: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeAvailability(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post('/api/availability', requireAuth(verifyIdToken), async (req, res) => {
    try {
      const authUser = req.authUser;
      if (!authUser) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      const actor = await findAppUserByFirebaseUid(authUser.uid);
      if (!actor) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const parsed = parseAvailabilityWrite(req.body, { workDateRequired: true });
      if ('error' in parsed || !parsed.workDate) {
        res.status(400).json({ error: 'invalid_availability' });
        return;
      }
      if (parsed.clientUserId && parsed.clientUserId !== actor.id) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const row = await prisma.availability.create({
        data: {
          userId: actor.id,
          workDate: parsed.workDate,
          shiftType: parsed.shiftType,
          customStartTime: parsed.customStartTime,
          customEndTime: parsed.customEndTime,
          submittedAt: new Date(),
        },
      });
      res.status(201).json(serializeAvailability(row));
    } catch (error) {
      if (isUniqueViolation(error)) {
        res.status(409).json({ error: 'conflict' });
        return;
      }
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.patch(
    '/api/availability/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_availability' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseAvailabilityWrite(req.body, {
          workDateRequired: false,
        });
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_availability' });
          return;
        }
        if (parsed.clientUserId && parsed.clientUserId !== actor.id) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const existing = await prisma.availability.findUnique({
          where: { id },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (
          existing.userId !== actor.id &&
          !isPrivilegedActor(actor, authUser)
        ) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const row = await prisma.availability.update({
          where: { id },
          data: {
            ...(parsed.workDate ? { workDate: parsed.workDate } : {}),
            shiftType: parsed.shiftType,
            customStartTime: parsed.customStartTime,
            customEndTime: parsed.customEndTime,
          },
        });
        res.json(serializeAvailability(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/availability/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_availability' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const existing = await prisma.availability.findUnique({
          where: { id },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (
          existing.userId !== actor.id &&
          !isPrivilegedActor(actor, authUser)
        ) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        await prisma.availability.delete({ where: { id } });
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/vacations', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.vacation.findMany({
        select: {
          id: true,
          userId: true,
          startOn: true,
          endOn: true,
          status: true,
          adminComment: true,
          requestedAt: true,
        },
        orderBy: [{ startOn: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeVacation(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post('/api/vacations', requireAuth(verifyIdToken), async (req, res) => {
    try {
      const authUser = req.authUser;
      if (!authUser) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      const actor = await findAppUserByFirebaseUid(authUser.uid);
      if (!actor) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const parsed = parseVacationCreate(req.body);
      if ('error' in parsed) {
        res.status(400).json({ error: 'invalid_vacation' });
        return;
      }
      if (parsed.clientUserId && parsed.clientUserId !== actor.id) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }

      const row = await prisma.vacation.create({
        data: {
          userId: actor.id,
          startOn: parsed.startOn,
          endOn: parsed.endOn,
          status: 'pending',
          adminComment: null,
          requestedAt: new Date(),
        },
      });
      res.status(201).json(serializeVacation(row));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.patch(
    '/api/vacations/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_vacation' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseVacationPatch(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_vacation' });
          return;
        }

        const existing = await prisma.vacation.findUnique({ where: { id } });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (existing.status !== 'pending') {
          res.status(400).json({ error: 'invalid_transition' });
          return;
        }

        const row = await prisma.vacation.update({
          where: { id },
          data: {
            status: parsed.status,
            ...(parsed.hasAdminComment
              ? { adminComment: parsed.adminComment ?? null }
              : {}),
          },
        });
        res.json(serializeVacation(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/cleaning', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const [lists, tasks, completions] = await Promise.all([
        prisma.cleaningList.findMany({
          select: {
            id: true,
            locationId: true,
            key: true,
          },
          orderBy: [{ key: 'asc' }, { id: 'asc' }],
        }),
        prisma.cleaningTask.findMany({
          select: {
            id: true,
            listId: true,
            title: true,
            sortOrder: true,
            isActive: true,
          },
          orderBy: [{ listId: 'asc' }, { sortOrder: 'asc' }, { id: 'asc' }],
        }),
        prisma.cleaningCompletion.findMany({
          select: {
            id: true,
            userId: true,
            taskId: true,
            weekId: true,
            completed: true,
            completedAt: true,
          },
          orderBy: [{ weekId: 'asc' }, { id: 'asc' }],
        }),
      ]);

      res.json({
        lists: lists.map((row) => serializeCleaningList(row)),
        tasks: tasks.map((row) => serializeCleaningTask(row)),
        completions: completions.map((row) => serializeCleaningCompletion(row)),
      });
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.put(
    '/api/cleaning/completions',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseCleaningCompletionWrite(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        let targetUserId = actor.id;
        if (parsed.clientUserId && parsed.clientUserId !== actor.id) {
          if (!isPrivilegedActor(actor, authUser)) {
            res.status(403).json({ error: 'forbidden' });
            return;
          }
          const target = await prisma.user.findUnique({
            where: { id: parsed.clientUserId },
            select: { id: true },
          });
          if (!target) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
          targetUserId = target.id;
        }

        const task = await prisma.cleaningTask.findUnique({
          where: { id: parsed.taskId },
          select: { id: true },
        });
        if (!task) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const completedAt = parsed.completed ? new Date() : null;
        const existing = await prisma.cleaningCompletion.findFirst({
          where: {
            userId: targetUserId,
            taskId: parsed.taskId,
            weekId: parsed.weekId,
          },
        });

        const row = existing
          ? await prisma.cleaningCompletion.update({
              where: { id: existing.id },
              data: {
                completed: parsed.completed,
                completedAt,
              },
            })
          : await prisma.cleaningCompletion.create({
              data: {
                userId: targetUserId,
                taskId: parsed.taskId,
                weekId: parsed.weekId,
                completed: parsed.completed,
                completedAt,
              },
            });

        res.json(serializeCleaningCompletion(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.post(
    '/api/cleaning/tasks',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseCleaningTaskCreate(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        let listId = parsed.listId;
        if (!listId) {
          const location = await prisma.location.findFirst({
            where: { name: parsed.locationName },
            select: { id: true },
          });
          if (!location || !parsed.key) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
          const list = await prisma.cleaningList.findFirst({
            where: { locationId: location.id, key: parsed.key },
            select: { id: true },
          });
          if (!list) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
          listId = list.id;
        } else {
          const list = await prisma.cleaningList.findUnique({
            where: { id: listId },
            select: { id: true },
          });
          if (!list) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
        }

        const max = await prisma.cleaningTask.aggregate({
          where: { listId, isActive: true },
          _max: { sortOrder: true },
        });
        const sortOrder = (max._max.sortOrder ?? -1) + 1;

        const row = await prisma.cleaningTask.create({
          data: {
            listId,
            title: parsed.title,
            sortOrder,
            isActive: true,
          },
        });
        res.status(201).json(serializeCleaningTask(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.put(
    '/api/cleaning/tasks/reorder',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseCleaningTaskReorder(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        const existing = await prisma.cleaningTask.findMany({
          where: { id: { in: parsed.ids } },
          select: { id: true },
        });
        if (existing.length !== parsed.ids.length) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const rows = await prisma.$transaction(
          parsed.ids.map((id, index) =>
            prisma.cleaningTask.update({
              where: { id },
              data: { sortOrder: index },
            }),
          ),
        );
        res.json(rows.map((row) => serializeCleaningTask(row)));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/cleaning/tasks/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseCleaningTaskPatch(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        const existing = await prisma.cleaningTask.findUnique({ where: { id } });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const row = await prisma.cleaningTask.update({
          where: { id },
          data: {
            ...(parsed.title !== undefined ? { title: parsed.title } : {}),
            ...(parsed.sortOrder !== undefined
              ? { sortOrder: parsed.sortOrder }
              : {}),
            ...(parsed.isActive !== undefined
              ? { isActive: parsed.isActive }
              : {}),
          },
        });
        res.json(serializeCleaningTask(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/cleaning/tasks/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_cleaning' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const existing = await prisma.cleaningTask.findUnique({ where: { id } });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const row = await prisma.cleaningTask.update({
          where: { id },
          data: { isActive: false },
        });
        res.json(serializeCleaningTask(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/scheduling', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.schedulingConfig.findMany({
        select: schedulingConfigSelect,
        orderBy: [{ year: 'asc' }, { month: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeSchedulingConfig(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post(
    '/api/scheduling',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseSchedulingCreate(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_scheduling' });
          return;
        }

        const locationId = await resolveSchedulingLocationId(parsed);
        if (locationId && typeof locationId === 'object') {
          res.status(locationId.error === 'not_found' ? 404 : 400).json({
            error: locationId.error,
          });
          return;
        }

        const enabledWrite =
          parsed.schedulingEnabled === undefined
            ? {
                schedulingEnabled: false,
                lockedMonth: parsed.lockedMonth ?? false,
              }
            : schedulingEnabledWriteData(
                actor.id,
                parsed.schedulingEnabled,
                parsed.lockedMonth,
              );

        const row = await prisma.schedulingConfig.create({
          data: {
            year: parsed.year,
            month: parsed.month,
            locationId,
            ...enabledWrite,
          },
          select: schedulingConfigSelect,
        });
        res.status(201).json(serializeSchedulingConfig(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/scheduling/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_scheduling' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }
        if (!isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseSchedulingPatch(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_scheduling' });
          return;
        }

        const existing = await prisma.schedulingConfig.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const data =
          parsed.schedulingEnabled === undefined
            ? { lockedMonth: parsed.lockedMonth }
            : schedulingEnabledWriteData(
                actor.id,
                parsed.schedulingEnabled,
                parsed.lockedMonth,
              );

        const row = await prisma.schedulingConfig.update({
          where: { id },
          data,
          select: schedulingConfigSelect,
        });
        res.json(serializeSchedulingConfig(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/consumptions', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.consumption.findMany({
        select: consumptionSelect,
        orderBy: [{ consumedOn: 'asc' }, { loggedAt: 'asc' }, { id: 'asc' }],
      });

      res.json(rows.map((row) => serializeConsumption(row)));
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  app.post(
    '/api/consumptions',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseConsumptionCreate(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }
        if (parsed.clientUserId && parsed.clientUserId !== actor.id) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        let productId = parsed.productId ?? null;
        if (!productId && parsed.productName) {
          productId = await findOrCreateProductByName(parsed.productName);
        }
        if (!productId) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }

        const product = await prisma.product.findUnique({
          where: { id: productId },
          select: { id: true },
        });
        if (!product) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const locationId = await resolveConsumptionLocation(
          actor.id,
          parsed.consumedOn,
          parsed.locationId,
        );
        if (!locationId) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }

        const row = await prisma.consumption.create({
          data: {
            userId: actor.id,
            productId,
            locationId,
            quantity: parsed.quantity,
            consumedOn: parsed.consumedOn,
            loggedAt: new Date(),
            notes: parsed.notes,
          },
          select: consumptionSelect,
        });
        res.status(201).json(serializeConsumption(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/consumptions/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const parsed = parseConsumptionPatch(req.body);
        if ('error' in parsed) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }

        const existing = await prisma.consumption.findUnique({ where: { id } });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (existing.userId !== actor.id && !isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        let nextProductId = parsed.productId ?? null;
        if (!nextProductId && parsed.productName) {
          nextProductId = await findOrCreateProductByName(parsed.productName);
        }
        if (nextProductId) {
          const product = await prisma.product.findUnique({
            where: { id: nextProductId },
            select: { id: true },
          });
          if (!product) {
            res.status(404).json({ error: 'not_found' });
            return;
          }
        }

        const row = await prisma.consumption.update({
          where: { id },
          data: {
            ...(nextProductId ? { productId: nextProductId } : {}),
            ...(parsed.quantity !== undefined
              ? { quantity: parsed.quantity }
              : {}),
            ...(parsed.hasNotes ? { notes: parsed.notes ?? null } : {}),
          },
          select: consumptionSelect,
        });
        res.json(serializeConsumption(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/consumptions/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const authUser = req.authUser;
        if (!authUser) {
          res.status(401).json({ error: 'unauthorized' });
          return;
        }

        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_consumption' });
          return;
        }

        const actor = await findAppUserByFirebaseUid(authUser.uid);
        if (!actor) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        const existing = await prisma.consumption.findUnique({ where: { id } });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (existing.userId !== actor.id && !isPrivilegedActor(actor, authUser)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        await prisma.consumption.delete({ where: { id } });
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/products', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const rows = await prisma.product.findMany({
        select: {
          id: true,
          name: true,
          categoryId: true,
          sku: true,
          isActive: true,
        },
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
      });

      res.json(
        rows.map((row) => ({
          id: row.id,
          name: row.name,
          category_id: row.categoryId,
          sku: row.sku,
          is_active: row.isActive,
        })),
      );
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  async function requireSuperadmin(
    req: express.Request,
    res: express.Response,
  ) {
    const authUser = req.authUser;
    if (!authUser) {
      res.status(401).json({ error: 'unauthorized' });
      return null;
    }
    if (!isSuperadminSession(authUser)) {
      res.status(403).json({ error: 'forbidden' });
      return null;
    }
    const actor = await findAppUserByFirebaseUid(authUser.uid);
    if (!actor) {
      res.status(403).json({ error: 'forbidden' });
      return null;
    }
    return { authUser, actor };
  }

  app.get(
    '/api/superadmin/overview',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const [
          users,
          products,
          locations,
          shifts,
          availability,
          vacations,
          consumptions,
        ] = await Promise.all([
          prisma.user.count(),
          prisma.product.count(),
          prisma.location.count(),
          prisma.shift.count(),
          prisma.availability.count(),
          prisma.vacation.count(),
          prisma.consumption.count(),
        ]);
        res.json({
          users,
          products,
          locations,
          shifts,
          availability,
          vacations,
          consumptions,
        });
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/superadmin/users/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_user' });
          return;
        }
        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_user' });
          return;
        }
        const data = req.body as Record<string, unknown>;
        const patch: { name?: string; role?: 'admin' | 'employee' } = {};
        if (Object.hasOwn(data, 'name')) {
          if (typeof data.name !== 'string' || data.name.trim() === '') {
            res.status(400).json({ error: 'invalid_user' });
            return;
          }
          patch.name = data.name.trim();
        }
        if (Object.hasOwn(data, 'role')) {
          if (data.role !== 'admin' && data.role !== 'employee') {
            res.status(400).json({ error: 'invalid_user' });
            return;
          }
          patch.role = data.role;
        }
        if (patch.name === undefined && patch.role === undefined) {
          res.status(400).json({ error: 'invalid_user' });
          return;
        }

        const existing = await prisma.user.findUnique({
          where: { id },
          select: USER_PUBLIC_SELECT,
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const row = await prisma.user.update({
          where: { id },
          data: patch,
          select: USER_PUBLIC_SELECT,
        });
        res.json(serializeUser(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/superadmin/users/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        const gate = await requireSuperadmin(req, res);
        if (!gate) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_user' });
          return;
        }

        const existing = await prisma.user.findUnique({
          where: { id },
          select: { id: true, firebaseUid: true, email: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        if (existing.id === gate.actor.id) {
          res.status(400).json({ error: 'invalid_user' });
          return;
        }
        if (isSuperadminEmail(existing.email)) {
          res.status(403).json({ error: 'forbidden' });
          return;
        }

        await deleteUserAndRelations(existing.id);
        try {
          await getFirebaseAuth().deleteUser(existing.firebaseUid);
        } catch {
          // Postgres row is already gone; login recreation is acceptable.
        }
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.post(
    '/api/superadmin/products',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }
        const data = req.body as Record<string, unknown>;
        if (typeof data.name !== 'string' || data.name.trim() === '') {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }
        const name = data.name.trim();
        let sku: string | null | undefined;
        if (Object.hasOwn(data, 'sku')) {
          if (data.sku !== null && typeof data.sku !== 'string') {
            res.status(400).json({ error: 'invalid_product' });
            return;
          }
          sku = typeof data.sku === 'string' ? data.sku.trim() || null : null;
        }
        const duplicate = await prisma.product.findFirst({
          where: { name: { equals: name, mode: 'insensitive' } },
          select: { id: true },
        });
        if (duplicate) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        const row = await prisma.product.create({
          data: {
            name,
            ...(sku !== undefined ? { sku } : {}),
            isActive: data.is_active === false ? false : true,
          },
          select: PRODUCT_PUBLIC_SELECT,
        });
        res.status(201).json(serializeProduct(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/superadmin/products/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }
        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }
        const data = req.body as Record<string, unknown>;
        const patch: {
          name?: string;
          sku?: string | null;
          isActive?: boolean;
        } = {};
        if (Object.hasOwn(data, 'name')) {
          if (typeof data.name !== 'string' || data.name.trim() === '') {
            res.status(400).json({ error: 'invalid_product' });
            return;
          }
          patch.name = data.name.trim();
        }
        if (Object.hasOwn(data, 'sku')) {
          if (data.sku !== null && typeof data.sku !== 'string') {
            res.status(400).json({ error: 'invalid_product' });
            return;
          }
          patch.sku = typeof data.sku === 'string' ? data.sku.trim() || null : null;
        }
        if (Object.hasOwn(data, 'is_active')) {
          if (typeof data.is_active !== 'boolean') {
            res.status(400).json({ error: 'invalid_product' });
            return;
          }
          patch.isActive = data.is_active;
        }
        if (
          patch.name === undefined &&
          patch.sku === undefined &&
          patch.isActive === undefined
        ) {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }

        const existing = await prisma.product.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }

        const row = await prisma.product.update({
          where: { id },
          data: patch,
          select: PRODUCT_PUBLIC_SELECT,
        });
        res.json(serializeProduct(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/superadmin/products/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_product' });
          return;
        }
        const existing = await prisma.product.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        await prisma.$transaction(async (tx) => {
          await tx.consumption.deleteMany({ where: { productId: id } });
          await tx.product.delete({ where: { id } });
        });
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.post(
    '/api/superadmin/locations',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_location' });
          return;
        }
        const data = req.body as Record<string, unknown>;
        if (typeof data.name !== 'string' || data.name.trim() === '') {
          res.status(400).json({ error: 'invalid_location' });
          return;
        }
        const name = data.name.trim();
        let code =
          typeof data.code === 'string' && data.code.trim() !== ''
            ? locationCodeFromName(data.code)
            : locationCodeFromName(name);
        const taken = await prisma.location.findUnique({
          where: { code },
          select: { id: true },
        });
        if (taken) {
          code = `${code}_${Date.now().toString(36).slice(-4)}`;
        }
        const row = await prisma.location.create({
          data: { name, code, isActive: true },
        });
        res.status(201).json(serializeLocation(row));
      } catch (error) {
        if (isUniqueViolation(error)) {
          res.status(409).json({ error: 'conflict' });
          return;
        }
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.patch(
    '/api/superadmin/locations/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_location' });
          return;
        }
        if (
          req.body == null ||
          typeof req.body !== 'object' ||
          Array.isArray(req.body)
        ) {
          res.status(400).json({ error: 'invalid_location' });
          return;
        }
        const data = req.body as Record<string, unknown>;
        const patch: { name?: string; isActive?: boolean } = {};
        if (Object.hasOwn(data, 'name')) {
          if (typeof data.name !== 'string' || data.name.trim() === '') {
            res.status(400).json({ error: 'invalid_location' });
            return;
          }
          patch.name = data.name.trim();
        }
        if (Object.hasOwn(data, 'is_active')) {
          if (typeof data.is_active !== 'boolean') {
            res.status(400).json({ error: 'invalid_location' });
            return;
          }
          patch.isActive = data.is_active;
        }
        if (patch.name === undefined && patch.isActive === undefined) {
          res.status(400).json({ error: 'invalid_location' });
          return;
        }
        const existing = await prisma.location.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        const row = await prisma.location.update({
          where: { id },
          data: patch,
        });
        res.json(serializeLocation(row));
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.delete(
    '/api/superadmin/vacations/:id',
    requireAuth(verifyIdToken),
    async (req, res) => {
      try {
        if (!(await requireSuperadmin(req, res))) return;
        const id = routeUuid(req.params.id);
        if (!id) {
          res.status(400).json({ error: 'invalid_vacation' });
          return;
        }
        const existing = await prisma.vacation.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) {
          res.status(404).json({ error: 'not_found' });
          return;
        }
        await prisma.vacation.delete({ where: { id } });
        res.status(204).send();
      } catch {
        res.status(500).json({ error: 'internal_error' });
      }
    },
  );

  app.get('/api/audit', requireAuth(verifyIdToken), async (_req, res) => {
    try {
      const tables = await prisma.$queryRaw<Array<{ table_name: string }>>`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN ('audit', 'audit_logs', 'audits')
        ORDER BY table_name
      `;
      if (tables.length === 0) {
        res.json([]);
        return;
      }
      res.json([]);
    } catch {
      res.status(500).json({ error: 'internal_error' });
    }
  });

  return app;
}
