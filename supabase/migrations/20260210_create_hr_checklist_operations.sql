-- Create hr_checklist_operations table for storing completed checklist responses
-- Primary key pattern: CLO1, CLO2, etc.

-- Create sequence for primary key
CREATE SEQUENCE IF NOT EXISTS hr_checklist_operations_id_seq;

CREATE TABLE IF NOT EXISTS hr_checklist_operations (
  id VARCHAR(20) PRIMARY KEY DEFAULT 'CLO' || nextval('hr_checklist_operations_id_seq'),
  user_id UUID NOT NULL,
  employee_id VARCHAR(50) REFERENCES hr_employee_master(id) ON DELETE SET NULL,
  box_number INTEGER,
  box_operation_id UUID REFERENCES box_operations(id) ON DELETE SET NULL,
  checklist_id VARCHAR(20) NOT NULL REFERENCES hr_checklists(id) ON DELETE CASCADE,
  answers JSONB NOT NULL DEFAULT '[]',
  total_points INTEGER NOT NULL DEFAULT 0,
  branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL,
  operation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  operation_time TIME NOT NULL DEFAULT CURRENT_TIME,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_user ON hr_checklist_operations(user_id);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_employee ON hr_checklist_operations(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_box_number ON hr_checklist_operations(box_number);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_box ON hr_checklist_operations(box_operation_id);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_checklist ON hr_checklist_operations(checklist_id);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_branch ON hr_checklist_operations(branch_id);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_date ON hr_checklist_operations(operation_date DESC);
CREATE INDEX IF NOT EXISTS idx_hr_checklist_operations_created ON hr_checklist_operations(created_at DESC);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_hr_checklist_operations_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hr_checklist_operations_timestamp_update
BEFORE UPDATE ON hr_checklist_operations
FOR EACH ROW
EXECUTE FUNCTION update_hr_checklist_operations_timestamp();

-- Add comment describing the JSONB structure
COMMENT ON COLUMN hr_checklist_operations.answers IS 'JSONB array: [{ question_id: "Q1", answer_key: "a1", answer_text: "Yes", points: 5, remarks: "...", other_value: "..." }, ...]';
