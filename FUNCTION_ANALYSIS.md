# Analysis of process_clearance_certificate_generation Function

## Current State (From Code Analysis)

### Function Call Signature
**Endpoint:** POST `/api/receiving-tasks`

**Called from:** `frontend/src/routes/api/receiving-tasks/+server.js`

**Parameters:**
```javascript
{
  receiving_record_id_param: UUID,      // The receiving record being processed
  clearance_certificate_url_param: string, // URL of generated certificate PDF
  generated_by_user_id: UUID,           // User who generated certificate
  generated_by_name: string | null,     // Optional user name
  generated_by_role: string | null      // Optional user role
}
```

**Expected Return Structure:**
```javascript
{
  success: boolean,
  tasks_created: number,
  notifications_sent: number,
  error?: string,           // If success is false
  error_code?: string       // If success is false
}
```

### Current Problems Identified

1. **Empty receiving_tasks table** - Despite certificates being generated, no records in `receiving_tasks`
2. **Duplicate tasks** - 22 tasks created for single receiving record (function called multiple times)
3. **No template system** - Tasks created dynamically each time
4. **Weak relationship** - No direct FK between `tasks` and `receiving_records`, only text parsing

### Database Functions That Need Updates

Based on `ReceivingDataWindow.svelte` and `+server.js`:

1. ✅ `process_clearance_certificate_generation(receiving_record_id_param, clearance_certificate_url_param, generated_by_user_id, generated_by_name, generated_by_role)` - NEEDS REWRITE
2. ⚠️ `get_all_receiving_tasks()` - Used by dashboard
3. ⚠️ `get_completed_receiving_tasks()` - Used by dashboard
4. ⚠️ `get_incomplete_receiving_tasks()` - Used by dashboard
5. ⚠️ `get_receiving_tasks_for_user(user_id_param, status_filter, limit_count)` - Used by API GET endpoint
6. ⚠️ `get_tasks_for_receiving_record(receiving_record_id_param)` - Used by API GET endpoint
7. ⚠️ `get_receiving_task_statistics(branch_id_param, date_from, date_to)` - Used by API GET endpoint

### Role Types (From Templates)

From `receiving_task_templates_data.sql`:
1. `branch_manager`
2. `purchase_manager`
3. `inventory_manager`
4. `night_supervisor`
5. `warehouse_handler`
6. `shelf_stocker`
7. `accountant`

## New Architecture Design

### Tables

#### receiving_task_templates ✅ CREATED
- Stores reusable task templates for each role
- Fields: role_type, title_template, description_template, priority, estimated_days
- Templates use {placeholders} like `{bill_number}`, `{vendor_name}`, `{branch_name}`

#### receiving_tasks ✅ STRUCTURE UPDATED
- Now standalone (no FK to tasks/task_assignments)
- Key fields:
  - `receiving_record_id` - FK to receiving_records
  - `template_id` - FK to receiving_task_templates  
  - `role_type` - Which role this task is for
  - `assigned_user_id` - User assigned to this task
  - `title` - Populated from template with placeholders replaced
  - `description` - Populated from template with placeholders replaced
  - `priority` - Copied from template
  - `due_date` - Calculated from template.estimated_days
  - `task_status` - 'pending', 'in_progress', 'completed', 'cancelled'
  - `task_completed` - boolean flag
  - `completed_at`, `completed_by_user_id` - Completion tracking
  - `clearance_certificate_url` - Link to certificate

### New process_clearance_certificate_generation Logic

```sql
CREATE OR REPLACE FUNCTION process_clearance_certificate_generation(
  receiving_record_id_param UUID,
  clearance_certificate_url_param TEXT,
  generated_by_user_id UUID,
  generated_by_name TEXT DEFAULT NULL,
  generated_by_role TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_tasks_created INT := 0;
  v_notifications_sent INT := 0;
  v_receiving_record RECORD;
  v_template RECORD;
  v_task_id UUID;
  v_title TEXT;
  v_description TEXT;
  v_due_date TIMESTAMP;
  v_assigned_user_id UUID;
BEGIN
  
  -- 1. CHECK FOR EXISTING TASKS (Prevent Duplicates)
  IF EXISTS (
    SELECT 1 FROM receiving_tasks 
    WHERE receiving_record_id = receiving_record_id_param
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Tasks already exist for this receiving record',
      'error_code', 'DUPLICATE_TASKS',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- 2. GET RECEIVING RECORD DATA
  SELECT 
    rr.*,
    v.vendor_name,
    b.name_en as branch_name
  INTO v_receiving_record
  FROM receiving_records rr
  LEFT JOIN vendors v ON v.id = rr.vendor_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  WHERE rr.id = receiving_record_id_param;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECORD_NOT_FOUND',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- 3. LOOP THROUGH EACH TEMPLATE AND CREATE TASKS
  FOR v_template IN 
    SELECT * FROM receiving_task_templates 
    ORDER BY priority DESC
  LOOP
    
    -- Replace placeholders in title
    v_title := v_template.title_template;
    v_title := REPLACE(v_title, '{bill_number}', v_receiving_record.bill_number);
    v_title := REPLACE(v_title, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_title := REPLACE(v_title, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));
    
    -- Replace placeholders in description
    v_description := v_template.description_template;
    v_description := REPLACE(v_description, '{bill_number}', v_receiving_record.bill_number);
    v_description := REPLACE(v_description, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_description := REPLACE(v_description, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));
    v_description := REPLACE(v_description, '{due_date}', TO_CHAR(CURRENT_DATE + v_template.estimated_days, 'YYYY-MM-DD'));
    
    -- Calculate due date
    v_due_date := CURRENT_TIMESTAMP + (v_template.estimated_days || ' days')::INTERVAL;
    
    -- Find user with this role (simplified - you may want more sophisticated assignment logic)
    SELECT user_id INTO v_assigned_user_id
    FROM user_roles
    WHERE role = v_template.role_type
    LIMIT 1;
    
    -- Generate task ID
    v_task_id := gen_random_uuid();
    
    -- 4. INSERT INTO receiving_tasks (NOT tasks table!)
    INSERT INTO receiving_tasks (
      id,
      receiving_record_id,
      template_id,
      role_type,
      assigned_user_id,
      title,
      description,
      priority,
      due_date,
      task_status,
      task_completed,
      clearance_certificate_url,
      created_at
    ) VALUES (
      v_task_id,
      receiving_record_id_param,
      v_template.id,
      v_template.role_type,
      v_assigned_user_id,
      v_title,
      v_description,
      v_template.priority,
      v_due_date,
      'pending',
      false,
      clearance_certificate_url_param,
      CURRENT_TIMESTAMP
    );
    
    v_tasks_created := v_tasks_created + 1;
    
    -- 5. SEND NOTIFICATION (if user assigned)
    IF v_assigned_user_id IS NOT NULL THEN
      -- Create notification (use existing notification system)
      INSERT INTO notifications (
        user_id,
        title,
        message,
        type,
        reference_id,
        reference_type,
        created_at
      ) VALUES (
        v_assigned_user_id,
        'New Receiving Task Assigned',
        v_title,
        'task_assignment',
        v_task_id::TEXT,
        'receiving_task',
        CURRENT_TIMESTAMP
      );
      
      v_notifications_sent := v_notifications_sent + 1;
    END IF;
    
  END LOOP;

  -- 6. RETURN SUCCESS
  RETURN json_build_object(
    'success', true,
    'tasks_created', v_tasks_created,
    'notifications_sent', v_notifications_sent,
    'receiving_record_id', receiving_record_id_param
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'error_code', 'INTERNAL_ERROR',
    'tasks_created', 0,
    'notifications_sent', 0
  );
END;
$$ LANGUAGE plpgsql;
```

## Key Differences from Old Implementation

1. ✅ **Duplicate Prevention** - Checks for existing tasks before creating new ones
2. ✅ **Template-Based** - Uses `receiving_task_templates` table instead of hardcoded logic
3. ✅ **Full Separation** - Only inserts into `receiving_tasks`, NOT `tasks` or `task_assignments`
4. ✅ **Placeholder Replacement** - Dynamic title/description with context from receiving record
5. ✅ **Direct Relationship** - Strong FK between `receiving_tasks` and `receiving_records`
6. ✅ **Proper Error Handling** - Returns structured JSON with error codes
7. ✅ **Transaction Safety** - Uses exception handling for rollback

## Next Steps

1. ✅ Create `receiving_task_templates` table
2. ✅ Populate 7 template records
3. ✅ Update `receiving_tasks` structure
4. 🔄 Create new `process_clearance_certificate_generation` function
5. ⏳ Update dashboard query functions to work with new structure
6. ⏳ Test complete flow end-to-end
7. ⏳ Deploy to Supabase
