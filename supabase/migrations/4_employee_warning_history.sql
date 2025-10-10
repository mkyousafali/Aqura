-- Create employee_warning_history table for tracking warning record changes
-- This table maintains an audit trail of all changes made to employee warnings

-- Create the employee_warning_history table
CREATE TABLE IF NOT EXISTS public.employee_warning_history (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    warning_id UUID NOT NULL,
    action_type CHARACTER VARYING(20) NOT NULL,
    old_values JSONB NULL,
    new_values JSONB NULL,
    changed_by UUID NULL,
    changed_by_username CHARACTER VARYING(255) NULL,
    change_reason TEXT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET NULL,
    user_agent TEXT NULL,
    
    CONSTRAINT employee_warning_history_pkey PRIMARY KEY (id),
    CONSTRAINT employee_warning_history_changed_by_fkey 
        FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT employee_warning_history_warning_id_fkey 
        FOREIGN KEY (warning_id) REFERENCES employee_warnings (id) ON DELETE CASCADE,
    CONSTRAINT employee_warning_history_action_type_check 
        CHECK (action_type::text = ANY (ARRAY[
            'created'::character varying,
            'updated'::character varying,
            'deleted'::character varying,
            'status_changed'::character varying,
            'fine_paid'::character varying,
            'acknowledged'::character varying,
            'resolved'::character varying
        ]::text[]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_id 
ON public.employee_warning_history USING btree (warning_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_action_type 
ON public.employee_warning_history USING btree (action_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_changed_by 
ON public.employee_warning_history USING btree (changed_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_at 
ON public.employee_warning_history USING btree (created_at) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_action 
ON public.employee_warning_history (warning_id, action_type);

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_desc 
ON public.employee_warning_history (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_user_activity 
ON public.employee_warning_history (changed_by, created_at DESC) 
WHERE changed_by IS NOT NULL;

-- Create GIN indexes for JSONB columns for efficient JSON queries
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_old_values_gin 
ON public.employee_warning_history USING gin (old_values) 
WHERE old_values IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_new_values_gin 
ON public.employee_warning_history USING gin (new_values) 
WHERE new_values IS NOT NULL;

-- Create partial indexes for specific action types
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_status_changes 
ON public.employee_warning_history (warning_id, created_at DESC) 
WHERE action_type = 'status_changed';

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_payments 
ON public.employee_warning_history (warning_id, created_at DESC) 
WHERE action_type = 'fine_paid';

-- Add table and column comments for documentation
COMMENT ON TABLE public.employee_warning_history IS 'Audit trail for employee warning record changes and actions';
COMMENT ON COLUMN public.employee_warning_history.id IS 'Unique identifier for the history record';
COMMENT ON COLUMN public.employee_warning_history.warning_id IS 'Reference to the employee warning record';
COMMENT ON COLUMN public.employee_warning_history.action_type IS 'Type of action performed on the warning';
COMMENT ON COLUMN public.employee_warning_history.old_values IS 'JSON snapshot of field values before the change';
COMMENT ON COLUMN public.employee_warning_history.new_values IS 'JSON snapshot of field values after the change';
COMMENT ON COLUMN public.employee_warning_history.changed_by IS 'User ID who made the change';
COMMENT ON COLUMN public.employee_warning_history.changed_by_username IS 'Username of who made the change';
COMMENT ON COLUMN public.employee_warning_history.change_reason IS 'Reason or description for the change';
COMMENT ON COLUMN public.employee_warning_history.created_at IS 'Timestamp when the change occurred';
COMMENT ON COLUMN public.employee_warning_history.ip_address IS 'IP address from which the change was made';
COMMENT ON COLUMN public.employee_warning_history.user_agent IS 'Browser/client user agent string';

-- Create function to automatically log warning changes
CREATE OR REPLACE FUNCTION log_employee_warning_change()
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
        
        -- Detect specific status changes
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            action_type_val := 'status_changed';
        END IF;
        
        -- Skip logging if no meaningful changes occurred
        IF old_vals = new_vals THEN
            RETURN NEW;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        action_type_val := 'deleted';
        old_vals := to_jsonb(OLD);
        new_vals := NULL;
    END IF;
    
    -- Insert history record
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
        COALESCE(NEW.updated_by, OLD.updated_by),
        COALESCE(NEW.updated_by_username, OLD.updated_by_username),
        CURRENT_TIMESTAMP
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create view for easy access to recent warning changes
CREATE OR REPLACE VIEW recent_warning_changes AS
SELECT 
    h.id,
    h.warning_id,
    h.action_type,
    h.changed_by_username,
    h.change_reason,
    h.created_at,
    h.old_values,
    h.new_values,
    u.full_name as changed_by_full_name
FROM employee_warning_history h
LEFT JOIN users u ON h.changed_by = u.id
ORDER BY h.created_at DESC
LIMIT 100;

-- Add additional constraints for data integrity
ALTER TABLE public.employee_warning_history 
ADD CONSTRAINT chk_history_has_values 
CHECK (
    (action_type = 'created' AND old_values IS NULL AND new_values IS NOT NULL) OR
    (action_type = 'deleted' AND old_values IS NOT NULL AND new_values IS NULL) OR
    (action_type IN ('updated', 'status_changed', 'fine_paid', 'acknowledged', 'resolved') 
     AND old_values IS NOT NULL AND new_values IS NOT NULL)
);

-- Create function to clean up old history records (optional)
CREATE OR REPLACE FUNCTION cleanup_old_warning_history(days_to_keep INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM employee_warning_history 
    WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Table, indexes, constraints, functions, and views created successfully
RAISE NOTICE 'employee_warning_history table created with audit capabilities and history tracking';