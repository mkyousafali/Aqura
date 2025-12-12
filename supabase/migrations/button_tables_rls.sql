-- Enable RLS on button tables
ALTER TABLE IF EXISTS button_main_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS button_sub_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sidebar_buttons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS button_permissions ENABLE ROW LEVEL SECURITY;

-- Policies for button_main_sections (allow public role full access like branches table)
DROP POLICY IF EXISTS "allow_select" ON button_main_sections;
CREATE POLICY "allow_select" ON button_main_sections
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_main_sections;
CREATE POLICY "allow_insert" ON button_main_sections
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_main_sections;
CREATE POLICY "allow_update" ON button_main_sections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_main_sections;
CREATE POLICY "allow_delete" ON button_main_sections
  FOR DELETE
  USING (true);

-- Policies for button_sub_sections (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON button_sub_sections;
CREATE POLICY "allow_select" ON button_sub_sections
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_sub_sections;
CREATE POLICY "allow_insert" ON button_sub_sections
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_sub_sections;
CREATE POLICY "allow_update" ON button_sub_sections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_sub_sections;
CREATE POLICY "allow_delete" ON button_sub_sections
  FOR DELETE
  USING (true);

-- Policies for sidebar_buttons (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON sidebar_buttons;
CREATE POLICY "allow_select" ON sidebar_buttons
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON sidebar_buttons;
CREATE POLICY "allow_insert" ON sidebar_buttons
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON sidebar_buttons;
CREATE POLICY "allow_update" ON sidebar_buttons
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON sidebar_buttons;
CREATE POLICY "allow_delete" ON sidebar_buttons
  FOR DELETE
  USING (true);

-- Policies for button_permissions (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON button_permissions;
CREATE POLICY "allow_select" ON button_permissions
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_permissions;
CREATE POLICY "allow_insert" ON button_permissions
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_permissions;
CREATE POLICY "allow_update" ON button_permissions
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_permissions;
CREATE POLICY "allow_delete" ON button_permissions
  FOR DELETE
  USING (true);
