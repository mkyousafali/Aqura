# RECEIVING TASKS SYSTEM - MIGRATION GUIDE
## Run these SQL files in Supabase SQL Editor in this exact order:

### ✅ Step 1: Create Templates Table
**File:** `receiving_task_templates.sql`
- Creates the templates table with deadline_hours column
- Drops existing table if present

### ✅ Step 2: Populate Templates Data  
**File:** `receiving_task_templates_data.sql`
- Inserts 7 role templates
- branch_manager, inventory_manager, night_supervisor, warehouse_handler, shelf_stocker, accountant: 24 hours
- purchase_manager: 72 hours

### ✅ Step 3: Update receiving_tasks Structure
**File:** `update_receiving_tasks_structure.sql`
- Adds: template_id, title, description, priority, due_date, completed_by_user_id, task_status
- Removes: task_id, assignment_id
- Adds indexes and constraints

### ✅ Step 4: Main Processing Function
**File:** `process_clearance_certificate_generation.sql`
- Creates tasks from templates
- Duplicate prevention
- Deadline calculation (UTC+3)
- Placeholder replacement

### 🆕 Step 5: Query Functions (Run these now)
**File:** `get_all_receiving_tasks.sql`
- Returns all receiving tasks with details

**File:** `get_completed_receiving_tasks.sql`
- Returns only completed tasks

**File:** `get_incomplete_receiving_tasks.sql`
- Returns pending/in-progress tasks

**File:** `get_user_receiving_tasks_dashboard.sql`
- Returns user-specific dashboard with statistics

**File:** `complete_receiving_task.sql`
- Marks task as completed
- Updates status, timestamps, completed_by

---

## 🚀 After Running All Migrations:
1. ✅ Templates system ready
2. ✅ Task creation working (7 tasks per certificate)
3. ✅ Query functions available
4. 🔄 Update API endpoints (next step)

## 📊 Test Results So Far:
- ✅ 7 tasks created successfully
- ✅ Deadlines calculated correctly (24h/72h)
- ✅ UTC+3 timezone working
- ✅ Placeholders replaced
- ✅ No duplicates
