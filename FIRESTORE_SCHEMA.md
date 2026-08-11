# CafeFlow Firestore Schema

## Collections Overview

### 1. users
Stores user account information and profile data.

**Fields:**
- `uid` (string) - Unique user ID from Firebase Auth
- `email` (string) - User's email address
- `name` (string) - Full name of the user
- `role` (string) - User role: 'employee' or 'admin'
- `workType` (string) - Contract type: 'Full-time' or 'Part-time'
- `contractType` (string) - Required onboarding contract type: `full_time` or `part_time`
- `needsContractType` (boolean) - True only for newly created accounts until onboarding is completed
- `authProvider` (string) - Auth provider used: `google` or `email`
- `monthlyTargetHours` (number) - Target monthly working hours (160 for full-time, 80 for part-time)
- `primaryLocation` (string) - Primary work location: 'Gara' or 'Avantgarden'
- `secondaryLocation` (string) - Secondary work location (optional)
- `fcmToken` (string) - Firebase Cloud Messaging token for notifications (optional)

**Indexes:**
- Single index on `role` for filtering employees vs admins

---

### 2. shifts
Stores scheduled shifts for employees.

**Fields:**
- `userId` (string) - ID of the employee assigned to the shift
- `userName` (string) - Name of the employee
- `date` (timestamp) - Date of the shift
- `startTime` (timestamp) - Shift start time
- `endTime` (timestamp) - Shift end time
- `type` (string) - Shift type: 'FULL', 'CUSTOM', or 'VACATION'
- `location` (string) - Work location: 'Gara' or 'Avantgarden'
- `status` (string) - Shift status: 'pending', 'approved', or 'auto-assigned'

**Indexes:**
- Composite index: `date` (ASC) + `location` (ASC) + `status` (ASC)
- Composite index: `userId` (ASC) + `date` (ASC)

---

### 3. availability
Stores employee availability submissions (first-come-first-served ordering).

**Fields:**
- `userId` (string) - ID of the employee
- `date` (timestamp) - Date of availability (normalized to midnight)
- `shiftType` (string) - `full_time` (07:00–18:00, 11h) or `custom_hours` (custom window)
- `isFullDay` (boolean) - Legacy mirror of full-time; kept for backward compatibility
- `customStartTime` (timestamp) - Custom start (required when `shiftType` is `custom_hours`)
- `customEndTime` (timestamp) - Custom end (required when `shiftType` is `custom_hours`)
- `submissionTimestamp` (timestamp) - Exact submission time for FCFS scheduling priority

**Indexes:**
- Composite index: `date` (ASC) + `userId` (ASC)
- Composite index: `userId` (ASC) + `date` (ASC)

**Migration:** Existing documents without `shiftType` are read as `full_time` when `isFullDay` is true, otherwise `part_time`. New writes always set `shiftType` and `submissionTimestamp`.

---

### 3b. scheduling_config
Admin-controlled gate for employee availability per month (and optionally per location).

**Document IDs:**
- Global: `{year}_{month}` (e.g. `2026_06`)
- Per location: `{year}_{month}_{location}` (e.g. `2026_06_Gara`)

**Fields:**
- `year` (number)
- `month` (number)
- `location` (string, optional) - `Gara`, `Avantgarden`, or omitted for all locations
- `schedulingEnabled` (boolean) - When true, employees may submit availability
- `lockedMonth` (boolean) - Admin override to lock editing (optional)
- `enabledAt` (timestamp) - When scheduling was last opened
- `enabledBy` (string) - Admin UID who enabled scheduling

**Indexes:**
- Composite index: `year` (ASC) + `month` (ASC)

---

### 4. vacations
Stores vacation requests from employees.

**Fields:**
- `userId` (string) - ID of the employee requesting vacation
- `userName` (string) - Name of the employee
- `startDate` (timestamp) - Vacation start date
- `endDate` (timestamp) - Vacation end date
- `status` (string) - Request status: 'pending', 'approved', or 'rejected'
- `adminComment` (string) - Admin's comment on the request (optional)
- `requestedAt` (timestamp) - When the request was submitted

**Indexes:**
- Composite index: `status` (ASC) + `requestedAt` (DESC)
- Composite index: `userId` (ASC) + `requestedAt` (DESC)

---

### 5. consumptions
Stores consumption logs for employees.

**Fields:**
- `userId` (string) - ID of the employee
- `userName` (string) - Name of the employee
- `item` (string) - Name of the consumed item
- `quantity` (number) - Quantity consumed
- `date` (timestamp) - Date of consumption
- `notes` (string) - Additional notes (optional)

**Indexes:**
- Composite index: `userId` (ASC) + `date` (DESC)

---

## Business Rules

### Capacity Limits
- **Maximum daily capacity per location:** 22 hours
- **Maximum concurrent employees:** 2 employees per time slot
- **Operating hours:** 07:00 - 18:00 (11 hours per full shift)

### Scheduling Priority
1. **First-come-first-served** by `submissionTimestamp` (earlier submissions win when capacity is full)
2. Primary location employees get priority (tie-breaker)
3. Underbooked employees (farthest from target) get priority (tie-breaker)

### Availability Editing Rules
- Employees may edit availability only for **future months** (locked from the 1st day of the target month onward)
- Employees may submit only after an admin sets `schedulingEnabled: true` for that month in `scheduling_config`
- Full time: fixed 07:00–18:00 (11 hours). Custom hours: custom times within 07:00–18:00

### Vacation Rules
- Approved vacation days count as worked hours toward monthly target
- Each vacation day counts as 11 hours (full shift equivalent)
- Admins can approve or reject vacation requests
- Employees can view their vacation status and history

### User Roles
- **Admin:** Can manage schedules, approve vacations, view all data
- **Employee:** Can submit availability, request vacations, log consumptions, view own data

---

## Security Rules Summary

- All collections require authentication
- Users can only read/write their own data unless they are admins
- Admins have full read/write access to all collections
- Vacation and consumption data is readable by admins and the owning user
