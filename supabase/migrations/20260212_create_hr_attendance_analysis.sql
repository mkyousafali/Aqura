-- Create hr_analysed_attendance_data table
-- Stores daily attendance analysis results per employee
-- Automatically populated by Edge Function (runs 4x/day via pg_cron)
-- Uses UPSERT on (employee_id, shift_date) so re-runs update existing data

DROP TABLE IF EXISTS hr_analysed_attendance_data CASCADE;

CREATE TABLE hr_analysed_attendance_data (
    id BIGSERIAL PRIMARY KEY,
    employee_id TEXT NOT NULL,
    shift_date DATE NOT NULL,
    
    -- Status: Worked, Absent, Official Day Off, Approved Leave (Deductible), 
    --         Approved Leave (No Deduction), Pending Approval, Rejected-Deducted,
    --         Rejected-Not Deducted, Check-In Missing, Check-Out Missing
    status TEXT NOT NULL DEFAULT 'Absent',
    
    -- Time tracking (in minutes)
    worked_minutes INTEGER NOT NULL DEFAULT 0,
    late_minutes INTEGER NOT NULL DEFAULT 0,
    under_minutes INTEGER NOT NULL DEFAULT 0,
    
    -- Shift info for that day
    shift_start_time TIME,
    shift_end_time TIME,
    
    -- Punch times (first check-in, last check-out)
    check_in_time TIME,
    check_out_time TIME,
    
    -- Employee snapshot (for quick display without joins)
    employee_name_en TEXT,
    employee_name_ar TEXT,
    branch_id TEXT,
    nationality TEXT,
    
    -- Metadata
    analyzed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint for upsert
    CONSTRAINT unique_employee_shift_date UNIQUE (employee_id, shift_date),
    
    -- Foreign key
    CONSTRAINT fk_analysed_employee FOREIGN KEY (employee_id) 
        REFERENCES hr_employee_master(id) ON DELETE CASCADE
);

-- Indexes for fast queries
CREATE INDEX idx_analysed_att_employee_id ON hr_analysed_attendance_data(employee_id);
CREATE INDEX idx_analysed_att_date ON hr_analysed_attendance_data(shift_date);
CREATE INDEX idx_analysed_att_status ON hr_analysed_attendance_data(status);
CREATE INDEX idx_analysed_att_branch ON hr_analysed_attendance_data(branch_id);
CREATE INDEX idx_analysed_att_emp_date ON hr_analysed_attendance_data(employee_id, shift_date);

-- Enable RLS
ALTER TABLE hr_analysed_attendance_data ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to hr_analysed_attendance_data" ON hr_analysed_attendance_data;

-- Permissive policy (matching your existing pattern)
CREATE POLICY "Allow all access to hr_analysed_attendance_data"
    ON hr_analysed_attendance_data
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to all roles
GRANT ALL ON hr_analysed_attendance_data TO anon;
GRANT ALL ON hr_analysed_attendance_data TO authenticated;
GRANT ALL ON hr_analysed_attendance_data TO service_role;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE hr_analysed_attendance_data_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE hr_analysed_attendance_data_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE hr_analysed_attendance_data_id_seq TO service_role;
