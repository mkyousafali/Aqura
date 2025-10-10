-- Create hr_fingerprint_transactions table for managing employee attendance data
-- This table stores fingerprint device check-in/check-out transactions

-- Create the hr_fingerprint_transactions table
CREATE TABLE IF NOT EXISTS public.hr_fingerprint_transactions (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id CHARACTER VARYING(10) NOT NULL,
    name CHARACTER VARYING(200) NULL,
    branch_id BIGINT NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_time TIME WITHOUT TIME ZONE NOT NULL,
    punch_state CHARACTER VARYING(20) NOT NULL,
    device_id CHARACTER VARYING(50) NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_fingerprint_transactions_pkey PRIMARY KEY (id),
    CONSTRAINT hr_fingerprint_transactions_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES branches (id),
    CONSTRAINT chk_hr_fingerprint_punch 
        CHECK (punch_state::text = ANY (ARRAY[
            'Check In'::character varying::text,
            'Check Out'::character varying::text
        ]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_id 
ON public.hr_fingerprint_transactions USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_date 
ON public.hr_fingerprint_transactions USING btree (transaction_date) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_punch_state 
ON public.hr_fingerprint_transactions USING btree (punch_state) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_branch_id 
ON public.hr_fingerprint_transactions USING btree (branch_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_date 
ON public.hr_fingerprint_transactions (employee_id, transaction_date);

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_datetime 
ON public.hr_fingerprint_transactions (transaction_date, transaction_time);

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_employee_datetime 
ON public.hr_fingerprint_transactions (employee_id, transaction_date, transaction_time);

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_branch_date 
ON public.hr_fingerprint_transactions (branch_id, transaction_date);

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_device 
ON public.hr_fingerprint_transactions (device_id) 
WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_recent 
ON public.hr_fingerprint_transactions (transaction_date DESC, transaction_time DESC);

-- Create composite index for attendance queries
CREATE INDEX IF NOT EXISTS idx_hr_fingerprint_attendance_lookup 
ON public.hr_fingerprint_transactions (employee_id, transaction_date, punch_state, transaction_time);

-- Add updated_at column and trigger
ALTER TABLE public.hr_fingerprint_transactions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_fingerprint_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_fingerprint_transactions_updated_at 
BEFORE UPDATE ON hr_fingerprint_transactions 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_fingerprint_transactions_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_fingerprint_transactions 
ADD CONSTRAINT chk_employee_id_format 
CHECK (employee_id ~ '^[A-Z0-9]{1,10}$');

ALTER TABLE public.hr_fingerprint_transactions 
ADD CONSTRAINT chk_transaction_date_reasonable 
CHECK (transaction_date >= '2000-01-01' AND transaction_date <= CURRENT_DATE + INTERVAL '1 day');

ALTER TABLE public.hr_fingerprint_transactions 
ADD CONSTRAINT chk_device_id_format 
CHECK (device_id IS NULL OR TRIM(device_id) != '');

-- Add table and column comments
COMMENT ON TABLE public.hr_fingerprint_transactions IS 'Fingerprint attendance transactions from biometric devices';
COMMENT ON COLUMN public.hr_fingerprint_transactions.id IS 'Unique identifier for the transaction';
COMMENT ON COLUMN public.hr_fingerprint_transactions.employee_id IS 'Employee identification number';
COMMENT ON COLUMN public.hr_fingerprint_transactions.name IS 'Employee name at time of transaction';
COMMENT ON COLUMN public.hr_fingerprint_transactions.branch_id IS 'Branch where the transaction occurred';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_date IS 'Date of the attendance transaction';
COMMENT ON COLUMN public.hr_fingerprint_transactions.transaction_time IS 'Time of the attendance transaction';
COMMENT ON COLUMN public.hr_fingerprint_transactions.punch_state IS 'Type of punch (Check In or Check Out)';
COMMENT ON COLUMN public.hr_fingerprint_transactions.device_id IS 'Identifier of the fingerprint device';
COMMENT ON COLUMN public.hr_fingerprint_transactions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.hr_fingerprint_transactions.updated_at IS 'Timestamp when record was last updated';

-- Create view for daily attendance summary
CREATE OR REPLACE VIEW daily_attendance_summary AS
SELECT 
    employee_id,
    name,
    branch_id,
    transaction_date,
    MIN(CASE WHEN punch_state = 'Check In' THEN transaction_time END) as first_check_in,
    MAX(CASE WHEN punch_state = 'Check Out' THEN transaction_time END) as last_check_out,
    COUNT(CASE WHEN punch_state = 'Check In' THEN 1 END) as total_check_ins,
    COUNT(CASE WHEN punch_state = 'Check Out' THEN 1 END) as total_check_outs,
    CASE 
        WHEN MIN(CASE WHEN punch_state = 'Check In' THEN transaction_time END) IS NOT NULL
         AND MAX(CASE WHEN punch_state = 'Check Out' THEN transaction_time END) IS NOT NULL
        THEN MAX(CASE WHEN punch_state = 'Check Out' THEN transaction_time END) - 
             MIN(CASE WHEN punch_state = 'Check In' THEN transaction_time END)
        ELSE NULL
    END as total_duration
FROM hr_fingerprint_transactions
GROUP BY employee_id, name, branch_id, transaction_date;

-- Create function to get employee attendance for date range
CREATE OR REPLACE FUNCTION get_employee_attendance(
    emp_id VARCHAR,
    start_date DATE,
    end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    transaction_date DATE,
    first_check_in TIME,
    last_check_out TIME,
    total_check_ins BIGINT,
    total_check_outs BIGINT,
    total_duration INTERVAL,
    is_complete BOOLEAN
) AS $$
BEGIN
    IF end_date IS NULL THEN
        end_date := start_date;
    END IF;
    
    RETURN QUERY
    SELECT 
        t.transaction_date,
        MIN(CASE WHEN t.punch_state = 'Check In' THEN t.transaction_time END) as first_check_in,
        MAX(CASE WHEN t.punch_state = 'Check Out' THEN t.transaction_time END) as last_check_out,
        COUNT(CASE WHEN t.punch_state = 'Check In' THEN 1 END) as total_check_ins,
        COUNT(CASE WHEN t.punch_state = 'Check Out' THEN 1 END) as total_check_outs,
        CASE 
            WHEN MIN(CASE WHEN t.punch_state = 'Check In' THEN t.transaction_time END) IS NOT NULL
             AND MAX(CASE WHEN t.punch_state = 'Check Out' THEN t.transaction_time END) IS NOT NULL
            THEN MAX(CASE WHEN t.punch_state = 'Check Out' THEN t.transaction_time END) - 
                 MIN(CASE WHEN t.punch_state = 'Check In' THEN t.transaction_time END)
            ELSE NULL
        END as total_duration,
        (COUNT(CASE WHEN t.punch_state = 'Check In' THEN 1 END) > 0 
         AND COUNT(CASE WHEN t.punch_state = 'Check Out' THEN 1 END) > 0) as is_complete
    FROM hr_fingerprint_transactions t
    WHERE t.employee_id = emp_id
      AND t.transaction_date BETWEEN start_date AND end_date
    GROUP BY t.transaction_date
    ORDER BY t.transaction_date;
END;
$$ LANGUAGE plpgsql;

-- Create function to detect attendance anomalies
CREATE OR REPLACE FUNCTION detect_attendance_anomalies(check_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    employee_id VARCHAR,
    name VARCHAR,
    branch_id BIGINT,
    anomaly_type VARCHAR,
    details TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Missing check-out
    SELECT 
        t.employee_id,
        t.name,
        t.branch_id,
        'missing_checkout'::VARCHAR as anomaly_type,
        'Has check-in but no check-out for ' || check_date::TEXT as details
    FROM hr_fingerprint_transactions t
    WHERE t.transaction_date = check_date
      AND t.punch_state = 'Check In'
      AND t.employee_id NOT IN (
          SELECT employee_id 
          FROM hr_fingerprint_transactions 
          WHERE transaction_date = check_date 
            AND punch_state = 'Check Out'
      )
    
    UNION ALL
    
    -- Missing check-in
    SELECT 
        t.employee_id,
        t.name,
        t.branch_id,
        'missing_checkin'::VARCHAR as anomaly_type,
        'Has check-out but no check-in for ' || check_date::TEXT as details
    FROM hr_fingerprint_transactions t
    WHERE t.transaction_date = check_date
      AND t.punch_state = 'Check Out'
      AND t.employee_id NOT IN (
          SELECT employee_id 
          FROM hr_fingerprint_transactions 
          WHERE transaction_date = check_date 
            AND punch_state = 'Check In'
      )
    
    UNION ALL
    
    -- Multiple check-ins without check-out
    SELECT 
        t.employee_id,
        t.name,
        t.branch_id,
        'multiple_checkins'::VARCHAR as anomaly_type,
        'Multiple check-ins (' || COUNT(*)::TEXT || ') on ' || check_date::TEXT as details
    FROM hr_fingerprint_transactions t
    WHERE t.transaction_date = check_date
      AND t.punch_state = 'Check In'
    GROUP BY t.employee_id, t.name, t.branch_id
    HAVING COUNT(*) > 1;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_fingerprint_transactions table created with attendance tracking features';