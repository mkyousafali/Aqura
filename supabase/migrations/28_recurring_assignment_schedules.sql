-- Create recurring_assignment_schedules table for managing recurring task assignments
-- This table handles automated scheduling and execution of recurring task assignments

-- Create the recurring_assignment_schedules table
CREATE TABLE IF NOT EXISTS public.recurring_assignment_schedules (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL,
    repeat_type TEXT NOT NULL,
    repeat_interval INTEGER NOT NULL DEFAULT 1,
    repeat_on_days INTEGER[] NULL,
    repeat_on_date INTEGER NULL,
    repeat_on_month INTEGER NULL,
    execute_time TIME WITHOUT TIME ZONE NOT NULL DEFAULT '09:00:00'::time without time zone,
    timezone TEXT NULL DEFAULT 'UTC'::text,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    max_occurrences INTEGER NULL,
    is_active BOOLEAN NULL DEFAULT true,
    last_executed_at TIMESTAMP WITH TIME ZONE NULL,
    next_execution_at TIMESTAMP WITH TIME ZONE NOT NULL,
    executions_count INTEGER NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_by TEXT NOT NULL,
    
    CONSTRAINT recurring_assignment_schedules_pkey PRIMARY KEY (id),
    CONSTRAINT fk_recurring_schedules_assignment 
        FOREIGN KEY (assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
    CONSTRAINT chk_repeat_interval_positive 
        CHECK (repeat_interval > 0),
    CONSTRAINT chk_max_occurrences_positive 
        CHECK (max_occurrences IS NULL OR max_occurrences > 0),
    CONSTRAINT recurring_assignment_schedules_repeat_type_check 
        CHECK (repeat_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text, 'custom'::text])),
    CONSTRAINT chk_schedule_bounds 
        CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_next_execution_after_start 
        CHECK ((next_execution_at)::date >= start_date)
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_assignment_id 
ON public.recurring_assignment_schedules USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_next_execution 
ON public.recurring_assignment_schedules USING btree (next_execution_at, is_active) 
TABLESPACE pg_default
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_active 
ON public.recurring_assignment_schedules USING btree (is_active, repeat_type) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_created_by 
ON public.recurring_assignment_schedules (created_by);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_timezone 
ON public.recurring_assignment_schedules (timezone);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_execution_count 
ON public.recurring_assignment_schedules (executions_count);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_last_executed 
ON public.recurring_assignment_schedules (last_executed_at DESC);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_date_range 
ON public.recurring_assignment_schedules (start_date, end_date);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_type_interval 
ON public.recurring_assignment_schedules (repeat_type, repeat_interval);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_active_execution 
ON public.recurring_assignment_schedules (is_active, next_execution_at, repeat_type) 
WHERE is_active = true;

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_due_soon 
ON public.recurring_assignment_schedules (next_execution_at) 
WHERE is_active = true AND next_execution_at <= now() + INTERVAL '1 hour';

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_overdue 
ON public.recurring_assignment_schedules (next_execution_at) 
WHERE is_active = true AND next_execution_at < now();

-- Create GIN index for repeat_on_days array
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_repeat_days 
ON public.recurring_assignment_schedules USING gin (repeat_on_days);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_recurring_assignment_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_recurring_assignment_schedules_updated_at 
BEFORE UPDATE ON recurring_assignment_schedules 
FOR EACH ROW 
EXECUTE FUNCTION update_recurring_assignment_schedules_updated_at();

-- Add additional validation constraints
ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_repeat_on_days_valid 
CHECK (
    repeat_on_days IS NULL OR 
    (array_length(repeat_on_days, 1) > 0 AND 
     NOT EXISTS (SELECT 1 FROM unnest(repeat_on_days) AS day WHERE day < 0 OR day > 6))
);

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_repeat_on_date_valid 
CHECK (repeat_on_date IS NULL OR (repeat_on_date >= 1 AND repeat_on_date <= 31));

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_repeat_on_month_valid 
CHECK (repeat_on_month IS NULL OR (repeat_on_month >= 1 AND repeat_on_month <= 12));

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_executions_count_non_negative 
CHECK (executions_count >= 0);

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_timezone_valid 
CHECK (timezone IS NULL OR timezone ~ '^[A-Za-z_/]+$');

-- Add additional columns for enhanced functionality
ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS failure_count INTEGER DEFAULT 0;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS last_failure_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS failure_reason TEXT;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS max_retries INTEGER DEFAULT 3;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{}';

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS execution_history JSONB DEFAULT '[]';

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS skip_holidays BOOLEAN DEFAULT false;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS skip_weekends BOOLEAN DEFAULT false;

ALTER TABLE public.recurring_assignment_schedules 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Add validation for new columns
ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_failure_count_non_negative 
CHECK (failure_count >= 0);

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_retry_count_non_negative 
CHECK (retry_count >= 0);

ALTER TABLE public.recurring_assignment_schedules 
ADD CONSTRAINT chk_max_retries_non_negative 
CHECK (max_retries >= 0);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_failure_count 
ON public.recurring_assignment_schedules (failure_count) 
WHERE failure_count > 0;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_retry_count 
ON public.recurring_assignment_schedules (retry_count) 
WHERE retry_count > 0;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_skip_options 
ON public.recurring_assignment_schedules (skip_holidays, skip_weekends);

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_notification_settings 
ON public.recurring_assignment_schedules USING gin (notification_settings);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_execution_history 
ON public.recurring_assignment_schedules USING gin (execution_history);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_metadata 
ON public.recurring_assignment_schedules USING gin (metadata);

-- Add table and column comments
COMMENT ON TABLE public.recurring_assignment_schedules IS 'Schedules for recurring task assignments with comprehensive execution management';
COMMENT ON COLUMN public.recurring_assignment_schedules.id IS 'Unique identifier for the schedule';
COMMENT ON COLUMN public.recurring_assignment_schedules.assignment_id IS 'Reference to the task assignment';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_type IS 'Type of recurrence (daily, weekly, monthly, yearly, custom)';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_interval IS 'Interval between repetitions';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_days IS 'Days of week for weekly recurrence (0=Sunday, 6=Saturday)';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_date IS 'Day of month for monthly recurrence';
COMMENT ON COLUMN public.recurring_assignment_schedules.repeat_on_month IS 'Month for yearly recurrence';
COMMENT ON COLUMN public.recurring_assignment_schedules.execute_time IS 'Time of day to execute';
COMMENT ON COLUMN public.recurring_assignment_schedules.timezone IS 'Timezone for execution time';
COMMENT ON COLUMN public.recurring_assignment_schedules.start_date IS 'When the schedule starts';
COMMENT ON COLUMN public.recurring_assignment_schedules.end_date IS 'When the schedule ends (optional)';
COMMENT ON COLUMN public.recurring_assignment_schedules.max_occurrences IS 'Maximum number of executions (optional)';
COMMENT ON COLUMN public.recurring_assignment_schedules.is_active IS 'Whether the schedule is active';
COMMENT ON COLUMN public.recurring_assignment_schedules.last_executed_at IS 'When last executed';
COMMENT ON COLUMN public.recurring_assignment_schedules.next_execution_at IS 'When next execution is scheduled';
COMMENT ON COLUMN public.recurring_assignment_schedules.executions_count IS 'Number of times executed';
COMMENT ON COLUMN public.recurring_assignment_schedules.failure_count IS 'Number of failed executions';
COMMENT ON COLUMN public.recurring_assignment_schedules.last_failure_at IS 'When last failure occurred';
COMMENT ON COLUMN public.recurring_assignment_schedules.failure_reason IS 'Reason for last failure';
COMMENT ON COLUMN public.recurring_assignment_schedules.retry_count IS 'Current retry attempt count';
COMMENT ON COLUMN public.recurring_assignment_schedules.max_retries IS 'Maximum retry attempts';
COMMENT ON COLUMN public.recurring_assignment_schedules.notification_settings IS 'Notification preferences as JSON';
COMMENT ON COLUMN public.recurring_assignment_schedules.execution_history IS 'History of executions as JSON array';
COMMENT ON COLUMN public.recurring_assignment_schedules.skip_holidays IS 'Whether to skip execution on holidays';
COMMENT ON COLUMN public.recurring_assignment_schedules.skip_weekends IS 'Whether to skip execution on weekends';
COMMENT ON COLUMN public.recurring_assignment_schedules.metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.recurring_assignment_schedules.created_by IS 'User who created the schedule';
COMMENT ON COLUMN public.recurring_assignment_schedules.created_at IS 'When the schedule was created';
COMMENT ON COLUMN public.recurring_assignment_schedules.updated_at IS 'When the schedule was last updated';

-- Create view for active schedules with assignment details
CREATE OR REPLACE VIEW recurring_schedules_active AS
SELECT 
    rs.id,
    rs.assignment_id,
    ta.name as assignment_name,
    ta.description as assignment_description,
    rs.repeat_type,
    rs.repeat_interval,
    rs.repeat_on_days,
    rs.repeat_on_date,
    rs.repeat_on_month,
    rs.execute_time,
    rs.timezone,
    rs.start_date,
    rs.end_date,
    rs.max_occurrences,
    rs.last_executed_at,
    rs.next_execution_at,
    rs.executions_count,
    rs.failure_count,
    rs.retry_count,
    rs.max_retries,
    rs.skip_holidays,
    rs.skip_weekends,
    rs.notification_settings,
    rs.metadata,
    rs.created_by,
    rs.created_at,
    rs.updated_at,
    CASE 
        WHEN rs.next_execution_at <= now() THEN true
        ELSE false
    END as is_due,
    CASE 
        WHEN rs.end_date IS NOT NULL AND rs.end_date < CURRENT_DATE THEN true
        WHEN rs.max_occurrences IS NOT NULL AND rs.executions_count >= rs.max_occurrences THEN true
        ELSE false
    END as is_expired,
    EXTRACT(EPOCH FROM (rs.next_execution_at - now())) / 60 as minutes_until_execution
FROM recurring_assignment_schedules rs
LEFT JOIN task_assignments ta ON rs.assignment_id = ta.id
WHERE rs.is_active = true
ORDER BY rs.next_execution_at ASC;

-- Create function to calculate next execution time
CREATE OR REPLACE FUNCTION calculate_next_execution(
    schedule_id UUID,
    from_datetime TIMESTAMPTZ DEFAULT now()
)
RETURNS TIMESTAMPTZ AS $$
DECLARE
    schedule_rec RECORD;
    next_exec TIMESTAMPTZ;
    target_date DATE;
    target_time TIME;
    day_of_week INTEGER;
    days_ahead INTEGER;
BEGIN
    SELECT * INTO schedule_rec 
    FROM recurring_assignment_schedules 
    WHERE id = schedule_id;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- Convert execution time to target timezone
    target_time := schedule_rec.execute_time;
    
    CASE schedule_rec.repeat_type
        WHEN 'daily' THEN
            target_date := (from_datetime::date) + (schedule_rec.repeat_interval || ' days')::interval;
            
        WHEN 'weekly' THEN
            IF schedule_rec.repeat_on_days IS NOT NULL AND array_length(schedule_rec.repeat_on_days, 1) > 0 THEN
                -- Find next occurrence based on specified days
                day_of_week := EXTRACT(dow FROM from_datetime);
                days_ahead := NULL;
                
                FOR i IN 1..array_length(schedule_rec.repeat_on_days, 1) LOOP
                    DECLARE
                        target_dow INTEGER := schedule_rec.repeat_on_days[i];
                        diff INTEGER;
                    BEGIN
                        diff := (target_dow - day_of_week + 7) % 7;
                        IF diff = 0 AND from_datetime::time >= target_time THEN
                            diff := 7;
                        END IF;
                        
                        IF days_ahead IS NULL OR diff < days_ahead THEN
                            days_ahead := diff;
                        END IF;
                    END;
                END LOOP;
                
                target_date := (from_datetime::date) + (days_ahead || ' days')::interval;
            ELSE
                target_date := (from_datetime::date) + (schedule_rec.repeat_interval * 7 || ' days')::interval;
            END IF;
            
        WHEN 'monthly' THEN
            IF schedule_rec.repeat_on_date IS NOT NULL THEN
                target_date := date_trunc('month', from_datetime) + 
                              (schedule_rec.repeat_interval || ' months')::interval + 
                              ((schedule_rec.repeat_on_date - 1) || ' days')::interval;
            ELSE
                target_date := (from_datetime::date) + (schedule_rec.repeat_interval || ' months')::interval;
            END IF;
            
        WHEN 'yearly' THEN
            target_date := (from_datetime::date) + (schedule_rec.repeat_interval || ' years')::interval;
            
        ELSE -- custom or other
            target_date := (from_datetime::date) + '1 day'::interval;
    END CASE;
    
    -- Combine date and time
    next_exec := target_date + target_time;
    
    -- Apply timezone conversion if needed
    IF schedule_rec.timezone IS NOT NULL AND schedule_rec.timezone != 'UTC' THEN
        next_exec := next_exec AT TIME ZONE schedule_rec.timezone AT TIME ZONE 'UTC';
    END IF;
    
    -- Skip weekends if configured
    IF schedule_rec.skip_weekends THEN
        WHILE EXTRACT(dow FROM next_exec) IN (0, 6) LOOP
            next_exec := next_exec + '1 day'::interval;
        END LOOP;
    END IF;
    
    RETURN next_exec;
END;
$$ LANGUAGE plpgsql;

-- Create function to execute a scheduled assignment
CREATE OR REPLACE FUNCTION execute_scheduled_assignment(schedule_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    schedule_rec RECORD;
    next_exec TIMESTAMPTZ;
    execution_result JSONB;
BEGIN
    SELECT * INTO schedule_rec 
    FROM recurring_assignment_schedules 
    WHERE id = schedule_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Check if execution is due
    IF schedule_rec.next_execution_at > now() THEN
        RETURN false;
    END IF;
    
    -- Check if schedule has expired
    IF (schedule_rec.end_date IS NOT NULL AND schedule_rec.end_date < CURRENT_DATE) OR
       (schedule_rec.max_occurrences IS NOT NULL AND schedule_rec.executions_count >= schedule_rec.max_occurrences) THEN
        UPDATE recurring_assignment_schedules 
        SET is_active = false,
            updated_at = now()
        WHERE id = schedule_id;
        RETURN false;
    END IF;
    
    BEGIN
        -- Calculate next execution time
        next_exec := calculate_next_execution(schedule_id, now());
        
        -- Update execution tracking
        UPDATE recurring_assignment_schedules 
        SET last_executed_at = now(),
            next_execution_at = next_exec,
            executions_count = executions_count + 1,
            retry_count = 0,
            execution_history = execution_history || jsonb_build_object(
                'executed_at', now(),
                'success', true,
                'execution_count', executions_count + 1
            ),
            updated_at = now()
        WHERE id = schedule_id;
        
        RETURN true;
        
    EXCEPTION WHEN OTHERS THEN
        -- Handle execution failure
        UPDATE recurring_assignment_schedules 
        SET failure_count = failure_count + 1,
            last_failure_at = now(),
            failure_reason = SQLERRM,
            retry_count = retry_count + 1,
            execution_history = execution_history || jsonb_build_object(
                'executed_at', now(),
                'success', false,
                'error', SQLERRM,
                'retry_count', retry_count + 1
            ),
            updated_at = now()
        WHERE id = schedule_id;
        
        RETURN false;
    END;
END;
$$ LANGUAGE plpgsql;

-- Create function to get due schedules
CREATE OR REPLACE FUNCTION get_due_schedules(
    limit_param INTEGER DEFAULT 100
)
RETURNS TABLE(
    schedule_id UUID,
    assignment_id UUID,
    assignment_name VARCHAR,
    repeat_type TEXT,
    next_execution_at TIMESTAMPTZ,
    minutes_overdue DECIMAL,
    retry_count INTEGER,
    max_retries INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rs.id,
        rs.assignment_id,
        ta.name as assignment_name,
        rs.repeat_type,
        rs.next_execution_at,
        EXTRACT(EPOCH FROM (now() - rs.next_execution_at)) / 60 as minutes_overdue,
        rs.retry_count,
        rs.max_retries
    FROM recurring_assignment_schedules rs
    LEFT JOIN task_assignments ta ON rs.assignment_id = ta.id
    WHERE rs.is_active = true 
      AND rs.next_execution_at <= now()
      AND (rs.retry_count < rs.max_retries OR rs.max_retries = 0)
    ORDER BY rs.next_execution_at ASC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to get schedule statistics
CREATE OR REPLACE FUNCTION get_schedule_statistics()
RETURNS TABLE(
    total_schedules BIGINT,
    active_schedules BIGINT,
    due_schedules BIGINT,
    overdue_schedules BIGINT,
    failed_schedules BIGINT,
    total_executions BIGINT,
    total_failures BIGINT,
    avg_execution_interval DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_schedules,
        COUNT(*) FILTER (WHERE is_active = true) as active_schedules,
        COUNT(*) FILTER (WHERE is_active = true AND next_execution_at <= now()) as due_schedules,
        COUNT(*) FILTER (WHERE is_active = true AND next_execution_at < now() - INTERVAL '1 hour') as overdue_schedules,
        COUNT(*) FILTER (WHERE failure_count > 0) as failed_schedules,
        COALESCE(SUM(executions_count), 0) as total_executions,
        COALESCE(SUM(failure_count), 0) as total_failures,
        AVG(EXTRACT(EPOCH FROM (next_execution_at - last_executed_at)) / 3600) FILTER (WHERE last_executed_at IS NOT NULL) as avg_execution_interval
    FROM recurring_assignment_schedules;
END;
$$ LANGUAGE plpgsql;

-- Create function to pause/resume schedule
CREATE OR REPLACE FUNCTION toggle_schedule_status(
    schedule_id UUID,
    new_status BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE recurring_assignment_schedules 
    SET is_active = new_status,
        updated_at = now()
    WHERE id = schedule_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'recurring_assignment_schedules table created with comprehensive scheduling and execution management features';