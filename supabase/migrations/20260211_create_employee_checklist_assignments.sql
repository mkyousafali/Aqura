-- Create employee_checklist_assignments table
CREATE TABLE IF NOT EXISTS employee_checklist_assignments (
  id BIGSERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
  assigned_to_user_id TEXT,
  branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL,
  checklist_id TEXT NOT NULL REFERENCES hr_checklists(id) ON DELETE CASCADE,
  frequency_type TEXT NOT NULL CHECK (frequency_type IN ('daily', 'weekly')),
  day_of_week TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  assigned_by TEXT,
  updated_by TEXT
);

-- Rename user_id to assigned_to_user_id if it exists (for existing tables)
DO $$ 
BEGIN 
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'employee_checklist_assignments' AND column_name = 'user_id'
  ) THEN 
    ALTER TABLE employee_checklist_assignments RENAME COLUMN user_id TO assigned_to_user_id;
  END IF;
END $$;

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_employee_checklist_assignments_employee_id ON employee_checklist_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_checklist_assignments_assigned_to_user_id ON employee_checklist_assignments(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_employee_checklist_assignments_checklist_id ON employee_checklist_assignments(checklist_id);
CREATE INDEX IF NOT EXISTS idx_employee_checklist_assignments_branch_id ON employee_checklist_assignments(branch_id);
CREATE INDEX IF NOT EXISTS idx_employee_checklist_assignments_deleted_at ON employee_checklist_assignments(deleted_at);
