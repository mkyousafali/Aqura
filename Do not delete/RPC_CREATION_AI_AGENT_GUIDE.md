# RPC Creation — AI Agent Guide

## ⚠️ MANDATORY: Always Verify Table Columns BEFORE Writing Any RPC

**NEVER assume column names.** Every table has unique column naming conventions. Always run `\d tablename` on the server to verify exact column names before writing SQL.

---

## Step 1: Check ALL Related Table Structures

Before writing ANY RPC function, run this command for EVERY table you plan to reference:

```bash
ssh -o StrictHostKeyChecking=no root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c '\d TABLE_NAME' 2>&1"
```

### Common Tables & Their ACTUAL Column Names

#### `task_assignments`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `task_id` | uuid | FK → tasks |
| `assigned_to_user_id` | uuid | FK → users (NOT `assigned_to`) |
| `assigned_to_branch_id` | bigint | FK → branches |
| `assigned_by` | uuid | FK → users |
| `assigned_by_name` | text | Denormalized |
| `assigned_at` | timestamptz | |
| `status` | text | Default: 'assigned' |
| `deadline_date` | date | |
| `deadline_time` | time | |
| `deadline_datetime` | timestamptz | Auto-computed trigger |
| `completed_at` | timestamptz | |
| `notes` | text | ✅ EXISTS |
| `priority_override` | text | ⚠️ NOT `priority` — use `COALESCE(ta.priority_override, tk.priority, 'medium')` |
| `assignment_type` | text | |

#### `tasks`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `title` | text | |
| `description` | text | |
| `priority` | text | ✅ EXISTS here (low/medium/high) |
| `created_by` | uuid | |

#### `quick_tasks`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `title` | text | |
| `description` | text | |
| `priority` | varchar(20) | ✅ EXISTS |
| `deadline_datetime` | timestamptz | ⚠️ NOT `deadline` |
| `assigned_by` | uuid | |
| `assigned_to_branch_id` | uuid | |

#### `quick_task_assignments`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `quick_task_id` | uuid | FK → quick_tasks |
| `assigned_to_user_id` | uuid | FK → users |
| `status` | varchar(50) | Default: 'pending' |
| `created_at` | timestamptz | |
| `completed_at` | timestamptz | |
| ~~`notes`~~ | — | ❌ DOES NOT EXIST |
| ~~`priority`~~ | — | ❌ DOES NOT EXIST (use quick_tasks.priority) |

#### `receiving_tasks`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `receiving_record_id` | uuid | FK → receiving_records |
| `assigned_user_id` | uuid | ⚠️ NOT `assigned_to_user_id` |
| `task_status` | varchar(50) | ⚠️ NOT `status` |
| `title` | text | |
| `description` | text | |
| `priority` | varchar(20) | ✅ EXISTS |
| `due_date` | timestamptz | ⚠️ NOT `deadline` |
| `created_at` | timestamptz | |
| `completed_at` | timestamptz | |
| `completion_notes` | text | ⚠️ NOT `notes` |
| `role_type` | varchar(50) | |

#### `receiving_records`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `user_id` | uuid | Creator |
| `branch_id` | bigint | FK → branches |

#### `branches`
| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | PK |
| `name_en` | text | |
| `name_ar` | text | |
| `location_en` | text | |
| `location_ar` | text | |

#### `users`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `username` | text | |

#### `hr_employee_master`
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `user_id` | uuid | FK → users |
| `name_en` | text | |
| `name_ar` | text | |
| `current_branch_id` | bigint | FK → branches |

---

## Step 2: Write the RPC

Create a `.sql` file in workspace root (e.g., `temp_rpc_FUNCTIONNAME.sql`).

### Template Structure:
```sql
DROP FUNCTION IF EXISTS public.function_name(param_types);

CREATE OR REPLACE FUNCTION public.function_name(
  p_param1 type DEFAULT default_value
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
  v_result json;
BEGIN
  -- Query logic here
  RETURN v_result;
END;
$function$;
```

### Key Rules:
1. **Always use `COALESCE`** for nullable JOINs
2. **Always cast UUIDs** properly when comparing
3. **Use `LEFT JOIN`** for optional relations (branches, users, employee names)
4. **Include both `name_en` and `name_ar`** for bilingual support
5. **Use `json_agg(row_to_json(...))` pattern** for returning arrays
6. **Wrap in `COALESCE(..., '[]'::json)`** to avoid NULL arrays

---

## Step 3: Deploy to Server

```bash
scp "c:\Users\mkyou\Aqura\temp_rpc_FILENAME.sql" "root@8.213.42.21:/tmp/temp_rpc_FILENAME.sql"
ssh -o StrictHostKeyChecking=no root@8.213.42.21 "docker cp /tmp/temp_rpc_FILENAME.sql supabase-db:/tmp/temp_rpc_FILENAME.sql; docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/temp_rpc_FILENAME.sql 2>&1"
```

### Expected success output:
```
DROP FUNCTION
CREATE FUNCTION
```

### If you see errors:
- `42703` = Column does not exist → Re-check with `\d tablename`
- `42P13` = Return type mismatch → Check RETURNS clause
- `PGRST203` = Function overload conflict → DROP old function first with exact param types

---

## Step 4: Call from Frontend

```typescript
const { data, error } = await supabase.rpc('function_name', { p_param1: value });
```

---

## ❌ Common Mistakes to AVOID

| Mistake | Correct |
|---------|---------|
| `ta.priority` | `COALESCE(ta.priority_override, tk.priority, 'medium')` |
| `ta.assigned_to` | `ta.assigned_to_user_id` |
| `qta.notes` | Column doesn't exist — use `NULL as notes` |
| `rt.status` | `rt.task_status` |
| `rt.notes` | `rt.completion_notes` |
| `rt.assigned_to_user_id` | `rt.assigned_user_id` |
| `qt.deadline` | `qt.deadline_datetime` |
| `rt.deadline` | `rt.due_date` |
| Assuming column exists | Always run `\d tablename` first |

---

## 🔒 Server Access Info

- **Server IP:** `8.213.42.21`
- **SSH:** `root@8.213.42.21`
- **DB Container:** `supabase-db`
- **DB User:** `supabase_admin`
- **DB Name:** `postgres`
- **Supabase URL:** `https://supabase.urbanaqura.com`
- **Service Role Key:** *(set in .env file, do not hardcode)*

---

## Quick Column Check Command

To check any table quickly:
```bash
ssh -o StrictHostKeyChecking=no root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c '\d TABLE_NAME' 2>&1"
```

Filter for specific columns:
```bash
... | Select-String -Pattern "column_name|other_column"
```
