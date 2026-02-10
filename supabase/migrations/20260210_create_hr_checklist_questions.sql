-- Create hr_checklist_questions table
-- Stores daily checklist questions with up to 6 answers, remarks, and other options
-- Primary ID format: Q1, Q2, Q3, ...

-- Sequence for auto-generating Q-prefixed IDs
CREATE SEQUENCE IF NOT EXISTS hr_checklist_questions_id_seq;

CREATE TABLE IF NOT EXISTS hr_checklist_questions (
  id VARCHAR(20) PRIMARY KEY DEFAULT 'Q' || nextval('hr_checklist_questions_id_seq'),

  -- Question text (bilingual)
  question_en TEXT,
  question_ar TEXT,

  -- Answer 1
  answer_1_en TEXT,
  answer_1_ar TEXT,
  answer_1_points INTEGER DEFAULT 0,

  -- Answer 2
  answer_2_en TEXT,
  answer_2_ar TEXT,
  answer_2_points INTEGER DEFAULT 0,

  -- Answer 3
  answer_3_en TEXT,
  answer_3_ar TEXT,
  answer_3_points INTEGER DEFAULT 0,

  -- Answer 4
  answer_4_en TEXT,
  answer_4_ar TEXT,
  answer_4_points INTEGER DEFAULT 0,

  -- Answer 5
  answer_5_en TEXT,
  answer_5_ar TEXT,
  answer_5_points INTEGER DEFAULT 0,

  -- Answer 6
  answer_6_en TEXT,
  answer_6_ar TEXT,
  answer_6_points INTEGER DEFAULT 0,

  -- Remarks option
  has_remarks BOOLEAN DEFAULT false,

  -- Other option (free-text answer with points)
  has_other BOOLEAN DEFAULT false,
  other_points INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_hr_checklist_questions_created ON hr_checklist_questions(created_at DESC);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_hr_checklist_questions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hr_checklist_questions_timestamp_update
BEFORE UPDATE ON hr_checklist_questions
FOR EACH ROW
EXECUTE FUNCTION update_hr_checklist_questions_timestamp();
