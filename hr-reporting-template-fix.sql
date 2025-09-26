-- =====================================================
-- FIX HR POSITION REPORTING TEMPLATE - 5 MANAGER COLUMNS
-- Run this in Supabase to completely restructure the reporting template
-- =====================================================

-- Step 1: Drop the current table and recreate with correct structure
DROP TABLE IF EXISTS hr_position_reporting_template CASCADE;

-- Step 2: Create new table with 5 manager position columns
CREATE TABLE hr_position_reporting_template (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subordinate_position_id UUID NOT NULL REFERENCES hr_positions(id) UNIQUE, -- Select Position (only one entry per position)
    manager_position_1 UUID REFERENCES hr_positions(id), -- Reports To Slot 1
    manager_position_2 UUID REFERENCES hr_positions(id), -- Reports To Slot 2  
    manager_position_3 UUID REFERENCES hr_positions(id), -- Reports To Slot 3
    manager_position_4 UUID REFERENCES hr_positions(id), -- Reports To Slot 4
    manager_position_5 UUID REFERENCES hr_positions(id), -- Reports To Slot 5
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Ensure a position doesn't report to itself in any slot
    CONSTRAINT chk_no_self_report_1 CHECK (subordinate_position_id != manager_position_1),
    CONSTRAINT chk_no_self_report_2 CHECK (subordinate_position_id != manager_position_2),
    CONSTRAINT chk_no_self_report_3 CHECK (subordinate_position_id != manager_position_3),
    CONSTRAINT chk_no_self_report_4 CHECK (subordinate_position_id != manager_position_4),
    CONSTRAINT chk_no_self_report_5 CHECK (subordinate_position_id != manager_position_5)
);

-- Step 3: Add indexes for performance
CREATE INDEX idx_hr_position_template_subordinate ON hr_position_reporting_template(subordinate_position_id);
CREATE INDEX idx_hr_position_template_mgr1 ON hr_position_reporting_template(manager_position_1);
CREATE INDEX idx_hr_position_template_mgr2 ON hr_position_reporting_template(manager_position_2);
CREATE INDEX idx_hr_position_template_mgr3 ON hr_position_reporting_template(manager_position_3);
CREATE INDEX idx_hr_position_template_mgr4 ON hr_position_reporting_template(manager_position_4);
CREATE INDEX idx_hr_position_template_mgr5 ON hr_position_reporting_template(manager_position_5);

-- Step 4: Update table comment
COMMENT ON TABLE hr_position_reporting_template IS 'HR Position Reporting Template - Each position can report to up to 5 different manager positions (Slots 1-5)';

-- Verification query to check the table structure
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'hr_position_reporting_template' 
AND table_schema = 'public'
ORDER BY ordinal_position;