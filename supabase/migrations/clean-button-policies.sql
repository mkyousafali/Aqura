-- NUCLEAR OPTION: Drop all button table policies and recreate fresh

-- Drop ALL existing policies on button tables
DROP POLICY IF EXISTS "allow_delete" ON button_main_sections;
DROP POLICY IF EXISTS "allow_insert" ON button_main_sections;
DROP POLICY IF EXISTS "allow_select" ON button_main_sections;
DROP POLICY IF EXISTS "allow_update" ON button_main_sections;
DROP POLICY IF EXISTS "rls_delete" ON button_main_sections;
DROP POLICY IF EXISTS "rls_insert" ON button_main_sections;
DROP POLICY IF EXISTS "rls_select" ON button_main_sections;
DROP POLICY IF EXISTS "rls_update" ON button_main_sections;

DROP POLICY IF EXISTS "allow_delete" ON button_sub_sections;
DROP POLICY IF EXISTS "allow_insert" ON button_sub_sections;
DROP POLICY IF EXISTS "allow_select" ON button_sub_sections;
DROP POLICY IF EXISTS "allow_update" ON button_sub_sections;
DROP POLICY IF EXISTS "rls_delete" ON button_sub_sections;
DROP POLICY IF EXISTS "rls_insert" ON button_sub_sections;
DROP POLICY IF EXISTS "rls_select" ON button_sub_sections;
DROP POLICY IF EXISTS "rls_update" ON button_sub_sections;

DROP POLICY IF EXISTS "allow_delete" ON sidebar_buttons;
DROP POLICY IF EXISTS "allow_insert" ON sidebar_buttons;
DROP POLICY IF EXISTS "allow_select" ON sidebar_buttons;
DROP POLICY IF EXISTS "allow_update" ON sidebar_buttons;
DROP POLICY IF EXISTS "rls_delete" ON sidebar_buttons;
DROP POLICY IF EXISTS "rls_insert" ON sidebar_buttons;
DROP POLICY IF EXISTS "rls_select" ON sidebar_buttons;
DROP POLICY IF EXISTS "rls_update" ON sidebar_buttons;

DROP POLICY IF EXISTS "allow_delete" ON button_permissions;
DROP POLICY IF EXISTS "allow_insert" ON button_permissions;
DROP POLICY IF EXISTS "allow_select" ON button_permissions;
DROP POLICY IF EXISTS "allow_update" ON button_permissions;
DROP POLICY IF EXISTS "rls_delete" ON button_permissions;
DROP POLICY IF EXISTS "rls_insert" ON button_permissions;
DROP POLICY IF EXISTS "rls_select" ON button_permissions;
DROP POLICY IF EXISTS "rls_update" ON button_permissions;

-- Now create SINGLE policies per operation per table (matching branches exactly)

-- ============ button_main_sections ============
CREATE POLICY "allow_select" ON button_main_sections FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON button_main_sections FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON button_main_sections FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON button_main_sections FOR DELETE USING (true);

-- ============ button_sub_sections ============
CREATE POLICY "allow_select" ON button_sub_sections FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON button_sub_sections FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON button_sub_sections FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON button_sub_sections FOR DELETE USING (true);

-- ============ sidebar_buttons ============
CREATE POLICY "allow_select" ON sidebar_buttons FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON sidebar_buttons FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON sidebar_buttons FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON sidebar_buttons FOR DELETE USING (true);

-- ============ button_permissions ============
CREATE POLICY "allow_select" ON button_permissions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON button_permissions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON button_permissions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON button_permissions FOR DELETE USING (true);
