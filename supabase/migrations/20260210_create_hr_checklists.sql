-- Create hr_checklists table
-- Stores checklists with name (EN/AR) and selected question IDs from hr_checklist_questions
-- Primary ID format: CL1, CL2, CL3, ...

-- Sequence for auto-generating CL-prefixed IDs
CREATE SEQUENCE IF NOT EXISTS hr_checklists_id_seq;

CREATE TABLE IF NOT EXISTS hr_checklists (
  id VARCHAR(20) PRIMARY KEY DEFAULT 'CL' || nextval('hr_checklists_id_seq'),

  -- Checklist name (bilingual)
  checklist_name_en TEXT,
  checklist_name_ar TEXT,

  -- Selected question IDs stored as JSONB array e.g. ["Q1", "Q3", "Q5"]
  question_ids JSONB DEFAULT '[]',

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_hr_checklists_created ON hr_checklists(created_at DESC);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_hr_checklists_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hr_checklists_timestamp_update
BEFORE UPDATE ON hr_checklists
FOR EACH ROW
EXECUTE FUNCTION update_hr_checklists_timestamp();
