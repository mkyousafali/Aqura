-- Create employee_warnings table for managing employee warning records
-- This table stores warnings, fines, and related information for employees

-- Create the employee_warnings table
CREATE TABLE IF NOT EXISTS public.employee_warnings (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NULL,
    employee_id UUID NULL,
    username CHARACTER VARYING(255) NULL,
    warning_type CHARACTER VARYING(50) NOT NULL,
    has_fine BOOLEAN NULL DEFAULT false,
    fine_amount NUMERIC(10, 2) NULL DEFAULT NULL::numeric,
    fine_currency CHARACTER VARYING(3) NULL DEFAULT 'USD'::character varying,
    fine_status CHARACTER VARYING(20) NULL DEFAULT 'pending'::character varying,
    fine_due_date DATE NULL,
    fine_paid_date TIMESTAMP WITHOUT TIME ZONE NULL,
    fine_paid_amount NUMERIC(10, 2) NULL DEFAULT NULL::numeric,
    warning_text TEXT NOT NULL,
    language_code CHARACTER VARYING(5) NOT NULL DEFAULT 'en'::character varying,
    task_id UUID NULL,
    task_title CHARACTER VARYING(500) NULL,
    task_description TEXT NULL,
    assignment_id UUID NULL,
    total_tasks_assigned INTEGER NULL DEFAULT 0,
    total_tasks_completed INTEGER NULL DEFAULT 0,
    total_tasks_overdue INTEGER NULL DEFAULT 0,
    completion_rate NUMERIC(5, 2) NULL DEFAULT 0,
    issued_by UUID NULL,
    issued_by_username CHARACTER VARYING(255) NULL,
    issued_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    warning_status CHARACTER VARYING(20) NULL DEFAULT 'active'::character varying,
    acknowledged_at TIMESTAMP WITHOUT TIME ZONE NULL,
    acknowledged_by UUID NULL,
    resolved_at TIMESTAMP WITHOUT TIME ZONE NULL,
    resolved_by UUID NULL,
    resolution_notes TEXT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT CURRENT_TIMESTAMP,
    branch_id BIGINT NULL,
    department_id UUID NULL,
    severity_level CHARACTER VARYING(10) NULL DEFAULT 'medium'::character varying,
    follow_up_required BOOLEAN NULL DEFAULT false,
    follow_up_date DATE NULL,
    warning_reference CHARACTER VARYING(50) NULL,
    warning_document_url TEXT NULL,
    is_deleted BOOLEAN NULL DEFAULT false,
    deleted_at TIMESTAMP WITHOUT TIME ZONE NULL,
    deleted_by UUID NULL,
    fine_paid_at TIMESTAMP WITHOUT TIME ZONE NULL,
    frontend_save_id CHARACTER VARYING(50) NULL,
    fine_payment_note TEXT NULL,
    fine_payment_method CHARACTER VARYING(50) NULL DEFAULT 'cash'::character varying,
    fine_payment_reference CHARACTER VARYING(100) NULL,
    
    CONSTRAINT employee_warnings_pkey PRIMARY KEY (id),
    CONSTRAINT employee_warnings_warning_reference_key UNIQUE (warning_reference),
    CONSTRAINT employee_warnings_deleted_by_fkey 
        FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_issued_by_fkey 
        FOREIGN KEY (issued_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_resolved_by_fkey 
        FOREIGN KEY (resolved_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_acknowledged_by_fkey 
        FOREIGN KEY (acknowledged_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL,
    CONSTRAINT employee_warnings_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT employee_warnings_warning_type_check 
        CHECK (warning_type::text = ANY (ARRAY[
            'overall_performance_no_fine'::character varying::text,
            'overall_performance_fine_threat'::character varying::text,
            'overall_performance_with_fine'::character varying::text,
            'task_specific_no_fine'::character varying::text,
            'task_specific_fine_threat'::character varying::text,
            'task_specific_with_fine'::character varying::text
        ])),
    CONSTRAINT employee_warnings_fine_status_check 
        CHECK (fine_status::text = ANY (ARRAY[
            'pending'::character varying::text,
            'paid'::character varying::text,
            'waived'::character varying::text,
            'cancelled'::character varying::text
        ])),
    CONSTRAINT employee_warnings_warning_status_check 
        CHECK (warning_status::text = ANY (ARRAY[
            'active'::character varying::text,
            'acknowledged'::character varying::text,
            'resolved'::character varying::text,
            'escalated'::character varying::text,
            'cancelled'::character varying::text
        ])),
    CONSTRAINT employee_warnings_severity_level_check 
        CHECK (severity_level::text = ANY (ARRAY[
            'low'::character varying::text,
            'medium'::character varying::text,
            'high'::character varying::text,
            'critical'::character varying::text
        ]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id 
ON public.employee_warnings USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id 
ON public.employee_warnings USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_username 
ON public.employee_warnings USING btree (username) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_type 
ON public.employee_warnings USING btree (warning_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_warning_status 
ON public.employee_warnings USING btree (warning_status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_has_fine 
ON public.employee_warnings USING btree (has_fine) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_status 
ON public.employee_warnings USING btree (fine_status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at 
ON public.employee_warnings USING btree (issued_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id 
ON public.employee_warnings USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id 
ON public.employee_warnings USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id 
ON public.employee_warnings USING btree (branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_reference 
ON public.employee_warnings USING btree (warning_reference) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted 
ON public.employee_warnings USING btree (is_deleted) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_by 
ON public.employee_warnings USING btree (issued_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_severity 
ON public.employee_warnings USING btree (severity_level) 
TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_warnings_reference_unique 
ON public.employee_warnings USING btree (warning_reference) 
TABLESPACE pg_default
WHERE warning_reference IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_type_date 
ON public.employee_warnings USING btree (user_id, warning_type, issued_at) 
TABLESPACE pg_default;

-- Additional performance indexes
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_due 
ON public.employee_warnings (fine_due_date) 
WHERE fine_due_date IS NOT NULL AND fine_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_employee_warnings_follow_up 
ON public.employee_warnings (follow_up_date) 
WHERE follow_up_required = true AND follow_up_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employee_warnings_active 
ON public.employee_warnings (issued_at DESC) 
WHERE is_deleted = false;

-- Create trigger functions
CREATE OR REPLACE FUNCTION generate_warning_reference()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.warning_reference IS NULL THEN
        NEW.warning_reference := 'WRN-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || 
                                LPAD(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::TEXT, 10, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_warning_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync fine_paid_date and fine_paid_at
    IF NEW.fine_paid_date IS NOT NULL AND NEW.fine_paid_at IS NULL THEN
        NEW.fine_paid_at = NEW.fine_paid_date;
    ELSIF NEW.fine_paid_at IS NOT NULL AND NEW.fine_paid_date IS NULL THEN
        NEW.fine_paid_date = NEW.fine_paid_at;
    END IF;
    
    -- Update fine status when payment is recorded
    IF NEW.fine_paid_amount IS NOT NULL AND NEW.fine_paid_amount > 0 THEN
        NEW.fine_status = 'paid';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
DECLARE
    action_type_val VARCHAR(20);
    old_vals JSONB;
    new_vals JSONB;
BEGIN
    -- Determine action type
    IF TG_OP = 'INSERT' THEN
        action_type_val := 'created';
        old_vals := NULL;
        new_vals := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        action_type_val := 'updated';
        old_vals := to_jsonb(OLD);
        new_vals := to_jsonb(NEW);
        
        -- Detect specific changes
        IF OLD.warning_status IS DISTINCT FROM NEW.warning_status THEN
            action_type_val := 'status_changed';
        ELSIF OLD.fine_status IS DISTINCT FROM NEW.fine_status AND NEW.fine_status = 'paid' THEN
            action_type_val := 'fine_paid';
        ELSIF OLD.acknowledged_at IS NULL AND NEW.acknowledged_at IS NOT NULL THEN
            action_type_val := 'acknowledged';
        ELSIF OLD.resolved_at IS NULL AND NEW.resolved_at IS NOT NULL THEN
            action_type_val := 'resolved';
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        action_type_val := 'deleted';
        old_vals := to_jsonb(OLD);
        new_vals := NULL;
    END IF;
    
    -- Insert into history table if it exists
    BEGIN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            new_values,
            changed_by,
            changed_by_username,
            created_at
        ) VALUES (
            COALESCE(NEW.id, OLD.id),
            action_type_val,
            old_vals,
            new_vals,
            COALESCE(NEW.issued_by, OLD.issued_by),
            COALESCE(NEW.issued_by_username, OLD.issued_by_username),
            CURRENT_TIMESTAMP
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Table might not exist yet, continue silently
            NULL;
    END;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trigger_create_warning_history
AFTER INSERT OR DELETE OR UPDATE ON employee_warnings 
FOR EACH ROW 
EXECUTE FUNCTION create_warning_history();

CREATE TRIGGER trigger_generate_warning_reference 
BEFORE INSERT ON employee_warnings 
FOR EACH ROW 
EXECUTE FUNCTION generate_warning_reference();

CREATE TRIGGER trigger_sync_fine_paid_columns 
BEFORE INSERT OR UPDATE ON employee_warnings 
FOR EACH ROW 
EXECUTE FUNCTION sync_fine_paid_columns();

CREATE TRIGGER trigger_update_warning_updated_at 
BEFORE UPDATE ON employee_warnings 
FOR EACH ROW 
EXECUTE FUNCTION update_warning_updated_at();

-- Add table and column comments
COMMENT ON TABLE public.employee_warnings IS 'Employee warning and fine management system';
COMMENT ON COLUMN public.employee_warnings.warning_reference IS 'Unique reference number for the warning';
COMMENT ON COLUMN public.employee_warnings.completion_rate IS 'Task completion rate as percentage';
COMMENT ON COLUMN public.employee_warnings.fine_amount IS 'Fine amount in specified currency';
COMMENT ON COLUMN public.employee_warnings.warning_text IS 'Warning message text';

-- Additional constraints for data integrity
ALTER TABLE public.employee_warnings 
ADD CONSTRAINT chk_fine_amount_positive 
CHECK (fine_amount IS NULL OR fine_amount > 0);

ALTER TABLE public.employee_warnings 
ADD CONSTRAINT chk_completion_rate_valid 
CHECK (completion_rate >= 0 AND completion_rate <= 100);

ALTER TABLE public.employee_warnings 
ADD CONSTRAINT chk_fine_currency_format 
CHECK (fine_currency ~ '^[A-Z]{3}$');

RAISE NOTICE 'employee_warnings table created with triggers and constraints';