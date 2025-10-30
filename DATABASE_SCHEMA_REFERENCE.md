# Aqura Database Schema Reference

*Generated on 2025-10-30T21:47:43.113Z*

## Overview

- **Database URL**: https://vmypotfsyrvuublyddyt.supabase.co
- **Total Tables**: 64
- **Storage Buckets**: 14
- **Database Functions**: 0
- **Edge Functions**: 3

## Database Tables

### ACTIVE Tables (2 tables)

#### `active_fines_view`

*✅ Table exists but detailed schema requires additional permissions*

#### `active_warnings_view`

*✅ Table exists but detailed schema requires additional permissions*

### APP Tables (1 tables)

#### `app_functions`

*✅ Table exists but detailed schema requires additional permissions*

### BRANCHES Tables (1 tables)

#### `branches`

*✅ Table exists but detailed schema requires additional permissions*

### EMPLOYEE Tables (3 tables)

#### `employee_fine_payments`

*✅ Table exists but detailed schema requires additional permissions*

#### `employee_warning_history`

*✅ Table exists but detailed schema requires additional permissions*

#### `employee_warnings`

*✅ Table exists but detailed schema requires additional permissions*

### EXPENSE Tables (4 tables)

#### `expense_parent_categories`

*✅ Table exists but detailed schema requires additional permissions*

#### `expense_requisitions`

*✅ Table exists but detailed schema requires additional permissions*

#### `expense_scheduler`

*✅ Table exists but detailed schema requires additional permissions*

#### `expense_sub_categories`

*✅ Table exists but detailed schema requires additional permissions*

### HR Tables (13 tables)

#### `hr_departments`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_document_categories_summary`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_employee_contacts`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_employee_documents`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_employee_main_documents`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_employees`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_fingerprint_transactions`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_levels`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_position_assignments`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_position_reporting_template`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_positions`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_salary_components`

*✅ Table exists but detailed schema requires additional permissions*

#### `hr_salary_wages`

*✅ Table exists but detailed schema requires additional permissions*

### NON Tables (1 tables)

#### `non_approved_payment_scheduler`

*✅ Table exists but detailed schema requires additional permissions*

### NOTIFICATION Tables (4 tables)

#### `notification_attachments`

*✅ Table exists but detailed schema requires additional permissions*

#### `notification_queue`

*✅ Table exists but detailed schema requires additional permissions*

#### `notification_read_states`

*✅ Table exists but detailed schema requires additional permissions*

#### `notification_recipients`

*✅ Table exists but detailed schema requires additional permissions*

### NOTIFICATIONS Tables (1 tables)

#### `notifications`

*✅ Table exists but detailed schema requires additional permissions*

### POSITION Tables (1 tables)

#### `position_roles_view`

*✅ Table exists but detailed schema requires additional permissions*

### PUSH Tables (1 tables)

#### `push_subscriptions`

*✅ Table exists but detailed schema requires additional permissions*

### QUICK Tables (9 tables)

#### `quick_task_assignments`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_comments`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_completion_details`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_completions`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_files`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_files_with_details`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_task_user_preferences`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_tasks`

*✅ Table exists but detailed schema requires additional permissions*

#### `quick_tasks_with_details`

*✅ Table exists but detailed schema requires additional permissions*

### RECEIVING Tables (3 tables)

#### `receiving_records`

*✅ Table exists but detailed schema requires additional permissions*

#### `receiving_records_pr_excel_status`

*✅ Table exists but detailed schema requires additional permissions*

#### `receiving_tasks`

*✅ Table exists but detailed schema requires additional permissions*

### RECURRING Tables (2 tables)

#### `recurring_assignment_schedules`

*✅ Table exists but detailed schema requires additional permissions*

#### `recurring_schedule_check_log`

*✅ Table exists but detailed schema requires additional permissions*

### REQUESTERS Tables (1 tables)

#### `requesters`

*✅ Table exists but detailed schema requires additional permissions*

### ROLE Tables (1 tables)

#### `role_permissions`

*✅ Table exists but detailed schema requires additional permissions*

### TASK Tables (5 tables)

#### `task_assignments`

*✅ Table exists but detailed schema requires additional permissions*

#### `task_attachments`

*✅ Table exists but detailed schema requires additional permissions*

#### `task_completion_summary`

*✅ Table exists but detailed schema requires additional permissions*

#### `task_completions`

*✅ Table exists but detailed schema requires additional permissions*

#### `task_images`

*✅ Table exists but detailed schema requires additional permissions*

### TASKS Tables (1 tables)

#### `tasks`

*✅ Table exists but detailed schema requires additional permissions*

### USER Tables (7 tables)

#### `user_audit_logs`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_device_sessions`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_management_view`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_password_history`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_permissions_view`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_roles`

*✅ Table exists but detailed schema requires additional permissions*

#### `user_sessions`

*✅ Table exists but detailed schema requires additional permissions*

### USERS Tables (1 tables)

#### `users`

*✅ Table exists but detailed schema requires additional permissions*

### VENDOR Tables (1 tables)

#### `vendor_payment_schedule`

*✅ Table exists but detailed schema requires additional permissions*

### VENDORS Tables (1 tables)

#### `vendors`

*✅ Table exists but detailed schema requires additional permissions*

## Storage Buckets

### `employee-documents`

- **ID**: employee-documents
- **Public**: Yes
- **Created**: 2025-09-27T06:44:19.983Z
- **Updated**: 2025-09-27T06:44:19.983Z

### `user-avatars`

- **ID**: user-avatars
- **Public**: Yes
- **Created**: 2025-09-27T09:37:55.546Z
- **Updated**: 2025-09-27T09:37:55.546Z

### `documents`

- **ID**: documents
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z

### `original-bills`

- **ID**: original-bills
- **Public**: Yes
- **Created**: 2025-10-16T09:39:29.747Z
- **Updated**: 2025-10-16T09:39:29.747Z
- **Sample Files**: 00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273_original_bill_1761570591589.pdf, 00cdf681-f02c-4b2e-b55f-935b67b3d207_original_bill_1761458249984.pdf, 01606783-122e-45d1-8abd-5e571f5a904f_original_bill_1760791212218.pdf, 04ae5d05-35a4-4bc5-ad89-9e17aa06eea3_original_bill_1761561461713.pdf, 04bc2c9f-5c7a-4d9c-8793-aeeca1ff2386_original_bill_1761545944729.pdf

### `vendor-contracts`

- **ID**: vendor-contracts
- **Public**: Yes
- **Created**: 2025-09-20T10:53:24.356Z
- **Updated**: 2025-09-20T10:53:24.356Z

### `pr-excel-files`

- **ID**: pr-excel-files
- **Public**: Yes
- **Created**: 2025-10-18T19:05:27.954Z
- **Updated**: 2025-10-18T19:05:27.954Z
- **Sample Files**: 00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273_pr_excel_1761577725969.xlsx, 00cdf681-f02c-4b2e-b55f-935b67b3d207_pr_excel_1761465354796.xlsx, 04ae5d05-35a4-4bc5-ad89-9e17aa06eea3_pr_excel_1761571631458.xlsx, 04bc2c9f-5c7a-4d9c-8793-aeeca1ff2386_pr_excel_1761569325036.xlsx, 05262d70-2dac-442a-9279-c4b8fe484c0b_pr_excel_1761395018752.xlsx

### `requisition-images`

- **ID**: requisition-images
- **Public**: Yes
- **Created**: 2025-10-26T15:56:44.886Z
- **Updated**: 2025-10-26T15:56:44.886Z
- **Sample Files**: REQ-20251026-1513.png, REQ-20251026-2059.png, REQ-20251026-3178.png, REQ-20251026-3751.png, REQ-20251026-7712.png

### `expense-scheduler-bills`

- **ID**: expense-scheduler-bills
- **Public**: No
- **Created**: 2025-10-27T17:17:54.351Z
- **Updated**: 2025-10-27T17:17:54.351Z
- **Sample Files**: 1

### `notification-images`

- **ID**: notification-images
- **Public**: Yes
- **Created**: 2025-10-05T08:21:22.199Z
- **Updated**: 2025-10-05T08:21:22.199Z
- **Sample Files**: .emptyFolderPlaceholder

### `task-images`

- **ID**: task-images
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z
- **Sample Files**: .emptyFolderPlaceholder, file-1760096993793-3hwjv2x4jb.jpg, file-1760108062123-zb2xk6kzz6.png

### `warning-documents`

- **ID**: warning-documents
- **Public**: Yes
- **Created**: 2025-10-30T17:22:56.189Z
- **Updated**: 2025-10-30T17:22:56.189Z
- **Sample Files**: 2025

### `quick-task-files`

- **ID**: quick-task-files
- **Public**: Yes
- **Created**: 2025-10-06T11:32:05.112Z
- **Updated**: 2025-10-06T11:32:05.112Z
- **Sample Files**: .emptyFolderPlaceholder, quick-task-1760097684032-qkcnfyr8m6i.jpg, quick-task-1760101943817-q7jc3ravee.jpg, quick-task-1760102796805-grxeo40pu2.jpg, quick-task-1760107259037-52b0fc8rejr.png

### `completion-photos`

- **ID**: completion-photos
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z
- **Sample Files**: quick-task-completion-0cef9d38-3cb3-4c77-a34a-6010bbae154d-1760186327172.jpg, quick-task-completion-afad0b88-e458-47da-9e27-df949fd44d29-1760259874252.jpg, quick-task-completion-bda0b915-b197-4d97-9789-9a5585f65102-1760112977141.png, quick-task-completion-e5ab6536-2ddf-4283-bf33-f9b7063c9e8b-1760260513385.jpg, quick-task-completion-e5ab6536-2ddf-4283-bf33-f9b7063c9e8b-1760260636184.jpg

### `clearance-certificates`

- **ID**: clearance-certificates
- **Public**: Yes
- **Created**: 2025-10-16T07:51:17.889Z
- **Updated**: 2025-10-16T07:51:17.889Z
- **Sample Files**: .emptyFolderPlaceholder, clearance-certificate-00441dfb-6fab-437f-9e12-57cabe1421b8-1761573566878.png, clearance-certificate-00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273-1761558142473.png, clearance-certificate-00cdf681-f02c-4b2e-b55f-935b67b3d207-1761456664719.png, clearance-certificate-01606783-122e-45d1-8abd-5e571f5a904f-1760778531851.png

## Edge Functions

### `process-push-queue`

- **Path**: \supabase\functions\process-push-queue
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import webpush from 'npm:web-push@3.6.6'

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIq...
```

### `send-push-notification`

- **Path**: \supabase\functions\send-push-notification
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8"

...
```

### `test-queue`

- **Path**: \supabase\functions\test-queue
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_RO...
```


---

*This reference was automatically generated from the Aqura database schema on 2025-10-30T21:47:43.113Z*
