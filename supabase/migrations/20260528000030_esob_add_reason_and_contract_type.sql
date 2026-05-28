-- Add contract_type and termination_reason columns to ESOB records
ALTER TABLE hr_employee_esob_records
  ADD COLUMN IF NOT EXISTS contract_type text DEFAULT 'indefinite',
  ADD COLUMN IF NOT EXISTS termination_reason text;
