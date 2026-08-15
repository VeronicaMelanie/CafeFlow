-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('employee', 'admin');

-- CreateEnum
CREATE TYPE "contract_type" AS ENUM ('full_time', 'part_time');

-- CreateEnum
CREATE TYPE "auth_provider" AS ENUM ('google', 'email');

-- CreateEnum
CREATE TYPE "shift_type" AS ENUM ('FULL', 'CUSTOM', 'VACATION');

-- CreateEnum
CREATE TYPE "shift_status" AS ENUM ('pending', 'approved', 'auto-assigned');

-- CreateEnum
CREATE TYPE "availability_shift_type" AS ENUM ('full_time', 'custom_hours');

-- CreateEnum
CREATE TYPE "vacation_status" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "cleaning_list_key" AS ENUM ('closing', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "firebase_uid" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "user_role" NOT NULL DEFAULT 'employee',
    "contract_type" "contract_type",
    "monthly_target_hours" INTEGER NOT NULL DEFAULT 160,
    "needs_contract_type" BOOLEAN NOT NULL DEFAULT false,
    "employment_started_on" DATE,
    "fcm_token" TEXT,
    "auth_provider" "auth_provider",
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "locations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "opened_on" DATE,
    "closed_on" DATE,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_locations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "location_id" UUID NOT NULL,
    "is_primary" BOOLEAN NOT NULL,
    "valid_from" DATE NOT NULL,
    "valid_until" DATE,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "sort_order" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "category_id" UUID,
    "name" TEXT NOT NULL,
    "sku" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "consumptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "location_id" UUID NOT NULL,
    "quantity" DECIMAL(12,3) NOT NULL,
    "consumed_on" DATE NOT NULL,
    "logged_at" TIMESTAMPTZ(6) NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "consumptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shifts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "location_id" UUID NOT NULL,
    "work_date" DATE NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL,
    "end_at" TIMESTAMPTZ(6) NOT NULL,
    "type" "shift_type" NOT NULL,
    "status" "shift_status" NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "availability" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "work_date" DATE NOT NULL,
    "shift_type" "availability_shift_type" NOT NULL,
    "custom_start_time" TIME(6),
    "custom_end_time" TIME(6),
    "submitted_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "availability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vacations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "start_on" DATE NOT NULL,
    "end_on" DATE NOT NULL,
    "status" "vacation_status" NOT NULL,
    "admin_comment" TEXT,
    "requested_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vacations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scheduling_configs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "location_id" UUID,
    "year" INTEGER NOT NULL,
    "month" INTEGER NOT NULL,
    "scheduling_enabled" BOOLEAN NOT NULL DEFAULT false,
    "locked_month" BOOLEAN NOT NULL DEFAULT false,
    "enabled_at" TIMESTAMPTZ(6),
    "enabled_by" UUID,
    "max_hours_per_day" DECIMAL(6,2),
    "max_employees_per_shift" INTEGER,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scheduling_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cleaning_lists" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "location_id" UUID NOT NULL,
    "key" "cleaning_list_key" NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cleaning_lists_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cleaning_tasks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "list_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cleaning_tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cleaning_completions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "task_id" UUID NOT NULL,
    "week_id" TEXT NOT NULL,
    "completed" BOOLEAN NOT NULL DEFAULT false,
    "completed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cleaning_completions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "payload" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");

-- CreateIndex
CREATE UNIQUE INDEX "locations_code_key" ON "locations"("code");

-- CreateIndex
CREATE INDEX "user_locations_user_id_valid_from_idx" ON "user_locations"("user_id", "valid_from");

-- CreateIndex
CREATE INDEX "user_locations_location_id_valid_from_idx" ON "user_locations"("location_id", "valid_from");

-- CreateIndex
CREATE UNIQUE INDEX "user_locations_user_id_location_id_valid_from_key" ON "user_locations"("user_id", "location_id", "valid_from");

-- CreateIndex
CREATE UNIQUE INDEX "product_categories_slug_key" ON "product_categories"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "products_sku_key" ON "products"("sku");

-- CreateIndex
CREATE INDEX "products_name_idx" ON "products"("name");

-- CreateIndex
CREATE INDEX "products_category_id_idx" ON "products"("category_id");

-- CreateIndex
CREATE INDEX "consumptions_user_id_consumed_on_idx" ON "consumptions"("user_id", "consumed_on");

-- CreateIndex
CREATE INDEX "consumptions_location_id_consumed_on_idx" ON "consumptions"("location_id", "consumed_on");

-- CreateIndex
CREATE INDEX "consumptions_product_id_consumed_on_idx" ON "consumptions"("product_id", "consumed_on");

-- CreateIndex
CREATE INDEX "consumptions_location_id_user_id_consumed_on_idx" ON "consumptions"("location_id", "user_id", "consumed_on");

-- CreateIndex
CREATE INDEX "shifts_user_id_work_date_idx" ON "shifts"("user_id", "work_date");

-- CreateIndex
CREATE INDEX "shifts_location_id_work_date_idx" ON "shifts"("location_id", "work_date");

-- CreateIndex
CREATE UNIQUE INDEX "availability_user_id_work_date_key" ON "availability"("user_id", "work_date");

-- CreateIndex
CREATE INDEX "vacations_user_id_start_on_end_on_idx" ON "vacations"("user_id", "start_on", "end_on");

-- CreateIndex
CREATE INDEX "scheduling_configs_year_month_idx" ON "scheduling_configs"("year", "month");

-- CreateIndex
CREATE UNIQUE INDEX "cleaning_lists_location_id_key_key" ON "cleaning_lists"("location_id", "key");

-- CreateIndex
CREATE INDEX "cleaning_tasks_list_id_idx" ON "cleaning_tasks"("list_id");

-- CreateIndex
CREATE INDEX "cleaning_completions_user_id_week_id_idx" ON "cleaning_completions"("user_id", "week_id");

-- CreateIndex
CREATE INDEX "cleaning_completions_task_id_week_id_idx" ON "cleaning_completions"("task_id", "week_id");

-- CreateIndex
CREATE UNIQUE INDEX "cleaning_completions_user_id_task_id_week_id_key" ON "cleaning_completions"("user_id", "task_id", "week_id");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");

-- AddForeignKey
ALTER TABLE "user_locations" ADD CONSTRAINT "user_locations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_locations" ADD CONSTRAINT "user_locations_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "product_categories"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "consumptions" ADD CONSTRAINT "consumptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "consumptions" ADD CONSTRAINT "consumptions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "consumptions" ADD CONSTRAINT "consumptions_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "availability" ADD CONSTRAINT "availability_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vacations" ADD CONSTRAINT "vacations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_enabled_by_fkey" FOREIGN KEY ("enabled_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cleaning_lists" ADD CONSTRAINT "cleaning_lists_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cleaning_tasks" ADD CONSTRAINT "cleaning_tasks_list_id_fkey" FOREIGN KEY ("list_id") REFERENCES "cleaning_lists"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cleaning_completions" ADD CONSTRAINT "cleaning_completions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "cleaning_completions" ADD CONSTRAINT "cleaning_completions_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "cleaning_tasks"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Check constraints (Prisma does not emit these from schema.prisma)
ALTER TABLE "users" ADD CONSTRAINT "users_monthly_target_hours_positive" CHECK ("monthly_target_hours" > 0);

ALTER TABLE "locations" ADD CONSTRAINT "locations_closed_on_gte_opened_on" CHECK ("closed_on" IS NULL OR "opened_on" IS NULL OR "closed_on" >= "opened_on");

ALTER TABLE "user_locations" ADD CONSTRAINT "user_locations_valid_until_gte_valid_from" CHECK ("valid_until" IS NULL OR "valid_until" >= "valid_from");

ALTER TABLE "consumptions" ADD CONSTRAINT "consumptions_quantity_positive" CHECK ("quantity" > 0);

ALTER TABLE "shifts" ADD CONSTRAINT "shifts_end_at_gte_start_at" CHECK ("end_at" >= "start_at");

ALTER TABLE "availability" ADD CONSTRAINT "availability_shift_times_consistent" CHECK (
    ("shift_type" = 'full_time' AND "custom_start_time" IS NULL AND "custom_end_time" IS NULL)
    OR
    ("shift_type" = 'custom_hours' AND "custom_start_time" IS NOT NULL AND "custom_end_time" IS NOT NULL AND "custom_end_time" > "custom_start_time")
);

ALTER TABLE "vacations" ADD CONSTRAINT "vacations_end_on_gte_start_on" CHECK ("end_on" >= "start_on");

ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_month_range" CHECK ("month" >= 1 AND "month" <= 12);

ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_year_range" CHECK ("year" >= 2000 AND "year" <= 2100);

ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_max_hours_positive" CHECK ("max_hours_per_day" IS NULL OR "max_hours_per_day" > 0);

ALTER TABLE "scheduling_configs" ADD CONSTRAINT "scheduling_configs_max_employees_positive" CHECK ("max_employees_per_shift" IS NULL OR "max_employees_per_shift" > 0);

ALTER TABLE "cleaning_completions" ADD CONSTRAINT "cleaning_completions_week_id_format" CHECK ("week_id" ~ '^[0-9]{4}-W[0-9]{2}$');

-- PostgreSQL UNIQUE allows multiple NULLs. NULLS NOT DISTINCT guarantees one
-- global config (location_id IS NULL) per year/month, and one per location.
CREATE UNIQUE INDEX "scheduling_configs_year_month_location_id_uidx"
    ON "scheduling_configs" ("year", "month", "location_id")
    NULLS NOT DISTINCT;
