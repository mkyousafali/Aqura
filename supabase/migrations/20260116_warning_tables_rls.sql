-- Enable RLS on warning tables with permissive policies (matching app pattern)

-- 1. Warning Main Category RLS
ALTER TABLE warning_main_category ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to warning_main_category" ON warning_main_category;

CREATE POLICY "Allow all access to warning_main_category"
  ON warning_main_category
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON warning_main_category TO authenticated;
GRANT ALL ON warning_main_category TO service_role;
GRANT ALL ON warning_main_category TO anon;

-- 2. Warning Sub Category RLS
ALTER TABLE warning_sub_category ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to warning_sub_category" ON warning_sub_category;

CREATE POLICY "Allow all access to warning_sub_category"
  ON warning_sub_category
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON warning_sub_category TO authenticated;
GRANT ALL ON warning_sub_category TO service_role;
GRANT ALL ON warning_sub_category TO anon;

-- 3. Warning Violation RLS
ALTER TABLE warning_violation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to warning_violation" ON warning_violation;

CREATE POLICY "Allow all access to warning_violation"
  ON warning_violation
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON warning_violation TO authenticated;
GRANT ALL ON warning_violation TO service_role;
GRANT ALL ON warning_violation TO anon;
