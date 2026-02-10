-- Enable RLS on hr_checklist_questions with permissive policies

-- Enable Row Level Security
ALTER TABLE hr_checklist_questions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow all access to hr_checklist_questions" ON hr_checklist_questions;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to hr_checklist_questions"
  ON hr_checklist_questions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (anon required since app uses anon key)
GRANT ALL ON hr_checklist_questions TO anon;
GRANT ALL ON hr_checklist_questions TO authenticated;
GRANT ALL ON hr_checklist_questions TO service_role;

-- Grant sequence usage so inserts can auto-generate IDs
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_questions_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_questions_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_questions_id_seq TO service_role;
