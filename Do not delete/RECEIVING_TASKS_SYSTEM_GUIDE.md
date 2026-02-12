# Receiving Tasks System — AI Agent Guide

> **Purpose:** Complete reference for modifying the receiving tasks system. Covers all files, RPC functions, database tables, dependencies, and where to change what.

---

## Architecture Overview

```
User clicks "🚀 Assign Tasks"
    │
    ▼
ClearanceCertificateManager.svelte → createTasksWithCertificate()
    │
    ▼
SvelteKit API: /api/receiving-tasks (POST)  →  +server.js
    │
    ▼
Supabase RPC: process_clearance_certificate_generation()
    │
    ├── Creates tasks in: receiving_tasks table
    ├── Reads templates from: receiving_task_templates table
    ├── Sends notifications to: notifications + notification_recipients tables
    └── Assigns users from: receiving_records (role user ID columns)
```

```
User clicks "Complete Task"
    │
    ▼
ReceivingTaskCompletionDialog.svelte (Desktop) OR
/mobile-interface/receiving-tasks/[id]/complete/+page.svelte (Mobile)
    │
    ├── Pre-checks (client-side):
    │     ├── checkPhotoRequirement()  →  reads require_photo_upload from template
    │     ├── checkTaskDependencies()  →  RPC: check_receiving_task_dependencies
    │     └── checkAccountantDependency()  →  queries receiving_records + vendor_payment_schedule
    │
    ▼
SvelteKit API: /api/receiving-tasks/complete (POST)  →  +server.js
    │
    ├── Server-side validation (accountant file check)
    ├── Chooses RPC function based on role_type:
    │     ├── purchase_manager  →  complete_receiving_task_simple
    │     └── all other roles   →  complete_receiving_task
    │
    ▼
RPC validates dependencies + requirements → updates receiving_tasks
```

---

## File Locations

### Frontend Components

| File | Purpose |
|------|---------|
| `frontend/src/lib/components/desktop-interface/master/operations/receiving/ClearanceCertificateManager.svelte` | Generate certificate + "Assign Tasks" button |
| `frontend/src/lib/components/desktop-interface/master/operations/receiving/ReceivingTaskCompletionDialog.svelte` | Desktop task completion form |
| `frontend/src/lib/components/desktop-interface/master/operations/receiving/ReceivingTasksDashboard.svelte` | Desktop tasks dashboard / list |
| `frontend/src/lib/components/desktop-interface/master/operations/receiving/ReceivingDataWindow.svelte` | All/Completed/Incomplete task views |
| `frontend/src/lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte` | Parent component, imports ClearanceCertificateManager |
| `frontend/src/routes/mobile-interface/receiving-tasks/[id]/complete/+page.svelte` | Mobile task completion form |

### API Endpoints

| File | Method | Purpose |
|------|--------|---------|
| `frontend/src/routes/api/receiving-tasks/+server.js` | POST | Create tasks (calls `process_clearance_certificate_generation`) |
| `frontend/src/routes/api/receiving-tasks/+server.js` | GET | Fetch tasks (calls `get_tasks_for_receiving_record`, `get_receiving_tasks_for_user`, `get_receiving_task_statistics`) |
| `frontend/src/routes/api/receiving-tasks/complete/+server.js` | POST | Complete a task (calls `complete_receiving_task` or `complete_receiving_task_simple`) |
| `frontend/src/routes/api/receiving-tasks/complete/+server.js` | GET | Validate requirements (calls `validate_task_completion_requirements`) |
| `frontend/src/routes/api/receiving-tasks/reassign/+server.js` | POST | Reassign a task (calls `reassign_receiving_task`) |
| `frontend/src/routes/api/receiving-tasks/dashboard/+server.js` | GET | User dashboard (calls `get_user_receiving_tasks_dashboard`) |

---

## Database Tables

### `receiving_task_templates`
**Purpose:** Defines WHAT tasks to create, their deadlines, photo requirements, and role dependencies.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `role_type` | VARCHAR | One of: `branch_manager`, `purchase_manager`, `inventory_manager`, `accountant`, `night_supervisor`, `warehouse_handler`, `shelf_stocker` |
| `title_template` | TEXT | Task title with placeholders: `{bill_number}`, `{vendor_name}`, `{branch_name}` |
| `description_template` | TEXT | Task description with placeholders: `{bill_number}`, `{vendor_name}`, `{branch_name}`, `{vendor_id}`, `{bill_amount}`, `{bill_date}`, `{received_by}`, `{certificate_url}`, `{deadline}` |
| `priority` | VARCHAR | `high`, `medium`, `low` |
| `deadline_hours` | INT | Hours from creation until due |
| `require_photo_upload` | BOOLEAN | Must upload photo to complete |
| `depends_on_role_types` | TEXT[] | Array of role_types that must complete first (checked by `check_receiving_task_dependencies` RPC) |

**Current template data (as of Feb 2026):**

| role_type | depends_on | photo | deadline | priority |
|-----------|-----------|-------|----------|----------|
| `shelf_stocker` | `[]` (none) | **Yes** | 24h | high |
| `warehouse_handler` | `[]` (none) | No | 24h | high |
| `inventory_manager` | `[]` (none) | No | 24h | high |
| `purchase_manager` | `[]` (none) | No | **72h** | high |
| `accountant` | `null` (none) | No | 24h | high |
| `branch_manager` | `["shelf_stocker"]` | No | 24h | high |
| `night_supervisor` | `["shelf_stocker"]` | No | 24h | high |

### `receiving_tasks`
**Purpose:** The actual tasks created per delivery.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `receiving_record_id` | UUID | FK to `receiving_records` |
| `template_id` | UUID | FK to `receiving_task_templates` |
| `role_type` | VARCHAR | Role this task is for |
| `assigned_user_id` | UUID | Who must complete this task |
| `title` | TEXT | Filled-in title |
| `description` | TEXT | Filled-in description |
| `priority` | VARCHAR | From template |
| `due_date` | TIMESTAMPTZ | Calculated from `deadline_hours` |
| `task_status` | VARCHAR | `pending` → `completed` |
| `task_completed` | BOOLEAN | true/false |
| `completed_at` | TIMESTAMPTZ | When completed |
| `completed_by_user_id` | UUID | Who completed it |
| `completion_photo_url` | TEXT | URL of uploaded photo |
| `completion_notes` | TEXT | User notes |
| `erp_reference_number` | VARCHAR | ERP ref (inventory_manager only) |
| `original_bill_uploaded` | BOOLEAN | Flag (inventory_manager only) |
| `original_bill_file_path` | TEXT | Path to original bill |
| `clearance_certificate_url` | TEXT | URL of the certificate |
| `requires_erp_reference` | BOOLEAN | From template |
| `requires_original_bill_upload` | BOOLEAN | From template |
| `requires_reassignment` | BOOLEAN | Can this task be reassigned |
| `rule_effective_date` | DATE | Backward compat — old tasks exempt from photo rule |

### `receiving_records`
**Key columns used by the task system:**

| Column | Used By | Purpose |
|--------|---------|---------|
| `branch_manager_user_id` | Task creation | Assign branch_manager task |
| `purchasing_manager_user_id` | Task creation | Assign purchase_manager task |
| `inventory_manager_user_id` | Task creation | Assign inventory_manager task |
| `accountant_user_id` | Task creation | Assign accountant task |
| `night_supervisor_user_ids` | Task creation | UUID[] — first element assigned |
| `warehouse_handler_user_ids` | Task creation | UUID[] — first element assigned |
| `shelf_stocker_user_ids` | Task creation | UUID[] — first element assigned |
| `pr_excel_file_url` | Completion check | Accountant + Purchase Manager blocked if empty |
| `original_bill_url` | Completion check | Accountant blocked if empty |
| `erp_purchase_invoice_uploaded` | On completion | Updated by inventory_manager |
| `pr_excel_file_uploaded` | On completion | Updated by inventory_manager |
| `original_bill_uploaded` | On completion | Updated by inventory_manager |

### `vendor_payment_schedule` / `vendor_payment_schedules`
**Note:** Two table names exist in code — `vendor_payment_schedule` (frontend) and `vendor_payment_schedules` (in `complete_receiving_task` RPC). This mismatch is why `complete_receiving_task_simple` was created for purchase_manager.

| Column | Purpose |
|--------|---------|
| `receiving_record_id` | Links to receiving record |
| `pr_excel_verified` | Boolean — checked by frontend accountant dependency |
| `verification_status` | Text — checked by `complete_receiving_task` RPC for purchase_manager (must be `'verified'`) |

---

## All RPC Functions

### Task Creation

| # | Function | Called From | Purpose |
|---|----------|------------|---------|
| 1 | `process_clearance_certificate_generation` | `/api/receiving-tasks` POST | Creates all tasks + notifications for a delivery |

### Task Completion

| # | Function | Called From | Purpose |
|---|----------|------------|---------|
| 2 | `complete_receiving_task` | `/api/receiving-tasks/complete` POST | Completes task with full validation (all roles except purchase_manager) |
| 3 | `complete_receiving_task_simple` | `/api/receiving-tasks/complete` POST | Completes task with light validation (purchase_manager only) |
| 4 | `validate_task_completion_requirements` | `/api/receiving-tasks/complete` GET | Pre-checks requirements before showing form |

### Dependency Checks (called by other RPCs, not directly from API)

| # | Function | Called By | Purpose |
|---|----------|----------|---------|
| 5 | `check_receiving_task_dependencies` | `complete_receiving_task` RPC + frontend UI | Checks if `depends_on_role_types` tasks are completed |
| 6 | `check_accountant_dependency` | `complete_receiving_task` RPC | Checks Original Bill URL + PR Excel URL exist |
| 7 | `get_dependency_completion_photos` | Frontend (desktop + mobile) | Gets photos from completed dependency tasks |

### Task Reading

| # | Function | Called From | Purpose |
|---|----------|------------|---------|
| 8 | `get_tasks_for_receiving_record` | `/api/receiving-tasks` GET | All tasks for one delivery |
| 9 | `get_receiving_tasks_for_user` | `/api/receiving-tasks` GET | User's incomplete tasks |
| 10 | `get_user_receiving_tasks_dashboard` | `/api/receiving-tasks/dashboard` GET | User's stats + recent tasks |
| 11 | `get_all_receiving_tasks` | `ReceivingDataWindow.svelte` (direct) | All tasks in system |
| 12 | `get_completed_receiving_tasks` | `ReceivingDataWindow.svelte` (direct) | Completed tasks only |
| 13 | `get_incomplete_receiving_tasks` | `ReceivingDataWindow.svelte` (direct) | Incomplete tasks only |
| 14 | `get_receiving_task_statistics` | `/api/receiving-tasks` GET | Aggregate stats |

### Task Reassignment

| # | Function | Called From | Purpose |
|---|----------|------------|---------|
| 15 | `reassign_receiving_task` | `/api/receiving-tasks/reassign` POST | Reassign task to different user |

---

## Dependency Map (Current State)

### Template-Level Dependencies (`depends_on_role_types` column)
These are checked by `check_receiving_task_dependencies` RPC:

```
shelf_stocker        →  (no dependency, starts immediately)
warehouse_handler    →  (no dependency, starts immediately)
inventory_manager    →  (no dependency, starts immediately)
purchase_manager     →  (no dependency, starts immediately)
accountant           →  null (no template dependency)
branch_manager       →  depends on: ["shelf_stocker"]
night_supervisor     →  depends on: ["shelf_stocker"]
```

### Hardcoded Dependencies (in RPC function code)
These are NOT in the template table — they're in SQL function logic:

**In `complete_receiving_task`:**
- **accountant** → calls `check_accountant_dependency()` which checks `receiving_records.original_bill_url` + `receiving_records.pr_excel_file_url`
- **inventory_manager** → validates `erp_reference_param` not empty + `has_pr_excel_file` = true + `has_original_bill` = true
- **purchase_manager** → checks `receiving_records.pr_excel_file_url` + `vendor_payment_schedules.verification_status = 'verified'`

**In `complete_receiving_task_simple`:**
- **purchase_manager** → only checks `receiving_records.pr_excel_file_url` exists
- **accountant** → only checks `receiving_records.original_bill_url` exists

**In frontend (`ReceivingTaskCompletionDialog.svelte` + mobile page):**
- **accountant** → `checkAccountantDependency()` also checks `vendor_payment_schedule.pr_excel_verified = true`
- **inventory_manager** → reactive `isInventoryFormValid` checks all 4 fields filled
- **Any role with template `require_photo_upload = true`** → `checkPhotoRequirement()` reads template

### Visual Dependency Chain

```
Delivery Arrives
    │
    ▼
🚀 Assign Tasks (creates all 7 tasks at once)
    │
    │   ── NO DEPENDENCIES (can start immediately) ──
    │
    ├── Shelf Stocker (24h) ────── Must upload PHOTO to complete
    ├── Warehouse Handler (24h) ── Just mark as done
    ├── Inventory Manager (24h) ── Must provide: ERP ref + PR Excel + Original Bill
    ├── Purchase Manager (72h) ─── Must have: PR Excel uploaded + payment verified
    │
    │   ── WAITS FOR SHELF STOCKER (template dependency) ──
    │
    ├── Branch Manager (24h) ───── Blocked until Shelf Stocker completes
    ├── Night Supervisor (24h) ─── Blocked until Shelf Stocker completes
    │
    │   ── WAITS FOR FILES (hardcoded, not template dependency) ──
    │
    └── Accountant (24h) ──────── Blocked until Original Bill URL + PR Excel URL exist
                                   (uploaded by Inventory Manager)
```

---

## How To: Common Changes

### Change a role's deadline
1. Update `receiving_task_templates` table in Supabase: `UPDATE receiving_task_templates SET deadline_hours = 48 WHERE role_type = 'shelf_stocker';`
2. No code changes needed — `process_clearance_certificate_generation` reads it dynamically

### Add a new template dependency (e.g., make accountant wait for inventory_manager via template)
1. Update template: `UPDATE receiving_task_templates SET depends_on_role_types = ARRAY['inventory_manager'] WHERE role_type = 'accountant';`
2. The `check_receiving_task_dependencies` RPC will automatically enforce it
3. **Note:** Accountant also has hardcoded checks in `check_accountant_dependency` and frontend `checkAccountantDependency()` — those still apply on top

### Remove a dependency (e.g., branch_manager no longer waits for shelf_stocker)
1. Update template: `UPDATE receiving_task_templates SET depends_on_role_types = ARRAY[]::TEXT[] WHERE role_type = 'branch_manager';`
2. No code changes needed

### Require photo upload for a role
1. Update template: `UPDATE receiving_task_templates SET require_photo_upload = true WHERE role_type = 'warehouse_handler';`
2. No code changes needed — both desktop and mobile UI already check `require_photo_upload` from template

### Add a new role type
1. Insert new row in `receiving_task_templates` with `role_type`, `title_template`, `description_template`, etc.
2. Add the user assignment column to `receiving_records` (e.g., `new_role_user_id UUID`)
3. Add a CASE branch in `process_clearance_certificate_generation` RPC under Step 3 role assignment
4. If role has special completion requirements, add validation in `complete_receiving_task` RPC
5. If role needs blocking in `check_receiving_task_dependencies`, add user-friendly name to CASE statement

### Change which RPC is used for a role's completion
- File: `frontend/src/routes/api/receiving-tasks/complete/+server.js` (around line 165)
- Current logic: `purchase_manager` → `complete_receiving_task_simple`, all others → `complete_receiving_task`

### Change inventory manager form validation
- **Frontend (client-side):** `ReceivingTaskCompletionDialog.svelte` line ~375 — reactive `isInventoryFormValid`
- **RPC (server-side):** `complete_receiving_task` — search for `role_type = 'inventory_manager'`
- Both must be updated together

### Change accountant dependency checks
- **RPC sub-function:** `check_accountant_dependency` — checks `original_bill_url` + `pr_excel_file_url` on `receiving_records`
- **Main RPC:** `complete_receiving_task` — calls `check_accountant_dependency` when `role_type = 'accountant'`
- **Simple RPC:** `complete_receiving_task_simple` — has its own inline accountant check (just `original_bill_url`)
- **Frontend desktop:** `ReceivingTaskCompletionDialog.svelte` → `checkAccountantDependency()` — checks same files + `vendor_payment_schedule.pr_excel_verified`
- **Frontend mobile:** `receiving-tasks/[id]/complete/+page.svelte` → `checkAccountantDependency()` — same as desktop
- **API server:** `api/receiving-tasks/complete/+server.js` — has server-side accountant file check before calling RPC
- **⚠️ Total places to update: 5 locations (3 backend, 2 frontend)**

### Change purchase manager completion requirements
- **Main RPC:** `complete_receiving_task` — checks `pr_excel_file_url` + `vendor_payment_schedules.verification_status`
- **Simple RPC:** `complete_receiving_task_simple` — only checks `pr_excel_file_url`
- **Frontend desktop:** `ReceivingTaskCompletionDialog.svelte` → `loadVerificationStatus()` loads `vendor_payment_schedule.pr_excel_verified`
- **API router:** `api/receiving-tasks/complete/+server.js` line ~165 — decides which RPC to call
- **⚠️ Known issue:** RPC uses `vendor_payment_schedules` (plural), frontend uses `vendor_payment_schedule` (singular) — may be different tables

### Modify task notification content
- **RPC:** `process_clearance_certificate_generation` — Step 5, the notification INSERT statement
- Change the `message` field (concatenated string) or `metadata` JSONB

### Change task title/description placeholders
- **RPC:** `process_clearance_certificate_generation` — Step 3, search for `REPLACE(v_title` and `REPLACE(v_description`
- Available placeholders: `{bill_number}`, `{vendor_name}`, `{branch_name}`, `{vendor_id}`, `{bill_amount}`, `{bill_date}`, `{received_by}`, `{certificate_url}`, `{deadline}`
- To add a new placeholder: add a new `REPLACE` line in the RPC + use it in the template text

---

## SQL to View/Modify Templates

```sql
-- View all templates
SELECT * FROM receiving_task_templates ORDER BY priority DESC;

-- View current dependencies
SELECT role_type, depends_on_role_types, require_photo_upload, deadline_hours
FROM receiving_task_templates ORDER BY role_type;

-- Change a dependency
UPDATE receiving_task_templates
SET depends_on_role_types = ARRAY['warehouse_handler']
WHERE role_type = 'shelf_stocker';

-- Add photo requirement
UPDATE receiving_task_templates
SET require_photo_upload = true
WHERE role_type = 'warehouse_handler';

-- Change deadline
UPDATE receiving_task_templates
SET deadline_hours = 48
WHERE role_type = 'accountant';

-- View all RPC functions
SELECT proname, pg_get_functiondef(oid)
FROM pg_proc
WHERE proname IN (
  'process_clearance_certificate_generation',
  'complete_receiving_task',
  'complete_receiving_task_simple',
  'check_receiving_task_dependencies',
  'check_accountant_dependency',
  'validate_task_completion_requirements',
  'get_dependency_completion_photos',
  'reassign_receiving_task',
  'get_tasks_for_receiving_record',
  'get_receiving_tasks_for_user',
  'get_receiving_task_statistics',
  'get_user_receiving_tasks_dashboard',
  'get_all_receiving_tasks',
  'get_completed_receiving_tasks',
  'get_incomplete_receiving_tasks'
);
```

---

## Known Issues / Gotchas

1. **Table name mismatch:** `vendor_payment_schedule` (singular, used in frontend) vs `vendor_payment_schedules` (plural, used in `complete_receiving_task` RPC). This is why `complete_receiving_task_simple` was created — to avoid the table that may not exist.

2. **Accountant dependency is hardcoded in 5 places** — not driven by template. Any change to accountant requirements must be updated in all 5 locations (see "Change accountant dependency checks" above).

3. **`depends_on_role_types` is `null` for accountant**, not `[]` — the `check_receiving_task_dependencies` RPC handles both cases, but if you set it to a non-null array, both the template check AND the hardcoded check will run.

4. **Night supervisor / warehouse handler / shelf stocker arrays** — task creation only assigns to the **first element** `[1]` of the user ID array. Other users in the array don't get tasks.

5. **Backward compatibility:** Tasks with `rule_effective_date = NULL` are exempt from photo upload requirements (even if template says `require_photo_upload = true`).

6. **Duplicate prevention:** `process_clearance_certificate_generation` checks `EXISTS (SELECT 1 FROM receiving_tasks WHERE receiving_record_id = ...)` — if ANY task exists for that delivery, no new tasks are created, even if templates were added later.
