-- =====================================================
-- Complete Warning System Recreation Script
-- This script drops and recreates all warning-related tables and functions
-- =====================================================

-- Drop existing tables and functions (in correct order due to dependencies)
DROP TRIGGER IF EXISTS trigger_create_warning_history ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_generate_warning_reference ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_update_warning_updated_at ON employee_warnings;
DROP FUNCTION IF EXISTS create_warning_history();
DROP FUNCTION IF EXISTS generate_warning_reference();
DROP FUNCTION IF EXISTS update_warning_updated_at();

-- Drop tables (history first, then main table)
DROP TABLE IF EXISTS employee_warning_history CASCADE;
DROP TABLE IF EXISTS employee_warnings CASCADE;

-- =====================================================
-- 1. Employee Warnings Main Table
-- =====================================================

CREATE TABLE public.employee_warnings (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NULL,
  employee_id uuid NULL,
  username character varying(255) NULL,
  warning_type character varying(50) NOT NULL,
  has_fine boolean NULL DEFAULT false,
  fine_amount numeric(10, 2) NULL DEFAULT NULL::numeric,
  fine_currency character varying(3) NULL DEFAULT 'USD'::character varying,
  fine_status character varying(20) NULL DEFAULT 'pending'::character varying,
  fine_due_date date NULL,
  fine_paid_date timestamp without time zone NULL,
  fine_paid_amount numeric(10, 2) NULL DEFAULT NULL::numeric,
  warning_text text NOT NULL,
  language_code character varying(5) NOT NULL DEFAULT 'en'::character varying,
  task_id uuid NULL,
  task_title character varying(500) NULL,
  task_description text NULL,
  assignment_id uuid NULL,
  total_tasks_assigned integer NULL DEFAULT 0,
  total_tasks_completed integer NULL DEFAULT 0,
  total_tasks_overdue integer NULL DEFAULT 0,
  completion_rate numeric(5, 2) NULL DEFAULT 0,
  issued_by uuid NULL,
  issued_by_username character varying(255) NULL,
  issued_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  warning_status character varying(20) NULL DEFAULT 'active'::character varying,
  acknowledged_at timestamp without time zone NULL,
  acknowledged_by uuid NULL,
  resolved_at timestamp without time zone NULL,
  resolved_by uuid NULL,
  resolution_notes text NULL,
  created_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone NULL DEFAULT CURRENT_TIMESTAMP,
  branch_id bigint NULL,
  department_id uuid NULL,
  severity_level character varying(10) NULL DEFAULT 'medium'::character varying,
  follow_up_required boolean NULL DEFAULT false,
  follow_up_date date NULL,
  warning_reference character varying(50) NULL,
  warning_document_url text NULL,
  is_deleted boolean NULL DEFAULT false,
  deleted_at timestamp without time zone NULL,
  deleted_by uuid NULL,
  
  -- Primary key
  CONSTRAINT employee_warnings_pkey PRIMARY KEY (id),
  
  -- Unique constraints
  CONSTRAINT employee_warnings_warning_reference_key UNIQUE (warning_reference),
  
  -- Foreign key constraints
  CONSTRAINT employee_warnings_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL,
  CONSTRAINT employee_warnings_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  
  -- Check constraints
  CONSTRAINT employee_warnings_warning_type_check CHECK (
    (warning_type)::text = ANY (
      ARRAY[
        'overall_performance_no_fine'::character varying,
        'overall_performance_fine_threat'::character varying,
        'overall_performance_with_fine'::character varying,
        'task_specific_no_fine'::character varying,
        'task_specific_fine_threat'::character varying,
        'task_specific_with_fine'::character varying
      ]::text[]
    )
  ),
  CONSTRAINT employee_warnings_fine_status_check CHECK (
    (fine_status)::text = ANY (
      ARRAY[
        'pending'::character varying,
        'paid'::character varying,
        'waived'::character varying,
        'cancelled'::character varying
      ]::text[]
    )
  ),
  CONSTRAINT employee_warnings_warning_status_check CHECK (
    (warning_status)::text = ANY (
      ARRAY[
        'active'::character varying,
        'acknowledged'::character varying,
        'resolved'::character varying,
        'escalated'::character varying,
        'cancelled'::character varying
      ]::text[]
    )
  ),
  CONSTRAINT employee_warnings_severity_level_check CHECK (
    (severity_level)::text = ANY (
      ARRAY[
        'low'::character varying,
        'medium'::character varying,
        'high'::character varying,
        'critical'::character varying
      ]::text[]
    )
  )
) TABLESPACE pg_default;

-- =====================================================
-- 2. Employee Warning History Table
-- =====================================================

CREATE TABLE public.employee_warning_history (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  warning_id uuid NOT NULL,
  action_type character varying(20) NOT NULL, -- 'created', 'updated', 'deleted', 'status_changed', 'fine_paid'
  old_values jsonb NULL,
  new_values jsonb NULL,
  changed_by uuid NULL,
  changed_by_username character varying(255) NULL,
  change_reason text NULL,
  created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip_address inet NULL,
  user_agent text NULL,
  
  -- Primary key
  CONSTRAINT employee_warning_history_pkey PRIMARY KEY (id),
  
  -- Foreign key constraints
  CONSTRAINT employee_warning_history_warning_id_fkey FOREIGN KEY (warning_id) REFERENCES employee_warnings (id) ON DELETE CASCADE,
  CONSTRAINT employee_warning_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL,
  
  -- Check constraints
  CONSTRAINT employee_warning_history_action_type_check CHECK (
    action_type IN ('created', 'updated', 'deleted', 'status_changed', 'fine_paid', 'acknowledged', 'resolved')
  )
) TABLESPACE pg_default;

-- =====================================================
-- 3. Indexes for Performance
-- =====================================================

-- Employee Warnings Indexes
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id ON public.employee_warnings USING btree (user_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id ON public.employee_warnings USING btree (employee_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_username ON public.employee_warnings USING btree (username) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_type ON public.employee_warnings USING btree (warning_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_status ON public.employee_warnings USING btree (warning_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_has_fine ON public.employee_warnings USING btree (has_fine) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_status ON public.employee_warnings USING btree (fine_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at ON public.employee_warnings USING btree (issued_at) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id ON public.employee_warnings USING btree (task_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id ON public.employee_warnings USING btree (assignment_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id ON public.employee_warnings USING btree (branch_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_reference ON public.employee_warnings USING btree (warning_reference) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted ON public.employee_warnings USING btree (is_deleted) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_by ON public.employee_warnings USING btree (issued_by) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warnings_severity ON public.employee_warnings USING btree (severity_level) TABLESPACE pg_default;

-- Warning History Indexes
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_id ON public.employee_warning_history USING btree (warning_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_action_type ON public.employee_warning_history USING btree (action_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_changed_by ON public.employee_warning_history USING btree (changed_by) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_at ON public.employee_warning_history USING btree (created_at) TABLESPACE pg_default;

-- =====================================================
-- 4. Helper Functions
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_warning_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate warning reference number
CREATE OR REPLACE FUNCTION generate_warning_reference()
RETURNS TRIGGER AS $$
DECLARE
    ref_number TEXT;
    counter INTEGER;
BEGIN
    -- Generate reference in format: WRN-YYYY-NNNN
    SELECT COALESCE(MAX(CAST(SUBSTRING(warning_reference FROM 9) AS INTEGER)), 0) + 1
    INTO counter
    FROM employee_warnings
    WHERE warning_reference LIKE 'WRN-' || EXTRACT(YEAR FROM CURRENT_DATE) || '-%';
    
    ref_number := 'WRN-' || EXTRACT(YEAR FROM CURRENT_DATE) || '-' || LPAD(counter::TEXT, 4, '0');
    
    NEW.warning_reference := ref_number;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fixed function to create warning history (CORRECTED)
CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT (new warning created)
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (
            warning_id, 
            action_type, 
            old_values, 
            new_values, 
            changed_by, 
            changed_by_username
        )
        VALUES (
            NEW.id, 
            'created', 
            NULL, 
            to_jsonb(NEW), 
            NEW.issued_by,  -- Use issued_by instead of updated_at
            NEW.issued_by_username
        );
        RETURN NEW;
    END IF;
    
    -- Handle UPDATE (warning modified)
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO employee_warning_history (
            warning_id, 
            action_type, 
            old_values, 
            new_values, 
            changed_by, 
            changed_by_username
        )
        VALUES (
            NEW.id, 
            'updated', 
            to_jsonb(OLD), 
            to_jsonb(NEW), 
            NEW.issued_by,  -- Use issued_by instead of updated_at
            NEW.issued_by_username
        );
        RETURN NEW;
    END IF;
    
    -- Handle DELETE (warning deleted)
    IF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (
            warning_id, 
            action_type, 
            old_values, 
            new_values, 
            changed_by, 
            changed_by_username
        )
        VALUES (
            OLD.id, 
            'deleted', 
            to_jsonb(OLD), 
            NULL, 
            OLD.deleted_by,  -- Use deleted_by for delete operations
            'system'
        );
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. Triggers
-- =====================================================

-- Trigger to automatically update updated_at column
CREATE TRIGGER trigger_update_warning_updated_at 
    BEFORE UPDATE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_warning_updated_at();

-- Trigger to generate warning reference number
CREATE TRIGGER trigger_generate_warning_reference 
    BEFORE INSERT ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION generate_warning_reference();

-- Trigger to create history records
CREATE TRIGGER trigger_create_warning_history
    AFTER INSERT OR UPDATE OR DELETE ON employee_warnings 
    FOR EACH ROW 
    EXECUTE FUNCTION create_warning_history();

-- =====================================================
-- 6. Views for Easy Data Access
-- =====================================================

-- View for active warnings with employee details
CREATE OR REPLACE VIEW active_warnings_view AS
SELECT 
    w.*,
    e.name as employee_name,
    e.employee_id as employee_code,
    u.username as issued_by_user,
    b.name_en as branch_name
FROM employee_warnings w
LEFT JOIN hr_employees e ON w.employee_id = e.id
LEFT JOIN users u ON w.issued_by = u.id
LEFT JOIN branches b ON w.branch_id = b.id
WHERE w.is_deleted = false
ORDER BY w.issued_at DESC;

-- View for active fines
CREATE OR REPLACE VIEW active_fines_view AS
SELECT 
    w.*,
    e.name as employee_name,
    e.employee_id as employee_code,
    b.name_en as branch_name,
    CASE 
        WHEN w.fine_due_date < CURRENT_DATE THEN 'overdue'
        WHEN w.fine_due_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'due_soon'
        ELSE 'pending'
    END as fine_urgency
FROM employee_warnings w
LEFT JOIN hr_employees e ON w.employee_id = e.id
LEFT JOIN branches b ON w.branch_id = b.id
WHERE w.has_fine = true 
  AND w.fine_status = 'pending'
  AND w.is_deleted = false
ORDER BY w.fine_due_date ASC NULLS LAST;

-- =====================================================
-- 7. Sample Data (Optional - uncomment to insert test data)
-- =====================================================

/*
-- Insert a sample warning (uncomment to test)
INSERT INTO employee_warnings (
    user_id,
    employee_id,
    username,
    warning_type,
    warning_text,
    language_code,
    issued_by,
    issued_by_username,
    warning_status,
    severity_level
) VALUES (
    'e9f184e8-b85a-4834-b248-29c4e5ff4494',  -- Replace with actual user ID
    'e9f184e8-b85a-4834-b248-29c4e5ff4494',  -- Replace with actual employee ID
    'shamsu',
    'overall_performance_no_fine',
    'This is a test warning for performance issues.',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',  -- Replace with admin user ID
    'madmin',
    'active',
    'medium'
);
*/

-- =====================================================
-- 8. Verification Queries
-- =====================================================

-- Check table creation
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE tablename IN ('employee_warnings', 'employee_warning_history')
ORDER BY tablename;

-- Check indexes
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE tablename IN ('employee_warnings', 'employee_warning_history')
ORDER BY tablename, indexname;

-- Check triggers
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table IN ('employee_warnings', 'employee_warning_history')
ORDER BY event_object_table, trigger_name;

-- Check functions
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name IN ('update_warning_updated_at', 'generate_warning_reference', 'create_warning_history')
ORDER BY routine_name;

-- Check views
SELECT 
    table_name,
    view_definition
FROM information_schema.views 
WHERE table_name IN ('active_warnings_view', 'active_fines_view')
ORDER BY table_name;

COMMENT ON TABLE employee_warnings IS 'Employee warning records with performance tracking and fine management';
COMMENT ON TABLE employee_warning_history IS 'Audit trail for all changes to employee warnings';
COMMENT ON VIEW active_warnings_view IS 'View showing all active warnings with employee and branch details';
COMMENT ON VIEW active_fines_view IS 'View showing all pending fines with urgency indicators';

-- =====================================================
-- Script completed successfully!
-- =====================================================