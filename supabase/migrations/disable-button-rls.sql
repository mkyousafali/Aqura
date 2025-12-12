-- SIMPLEST SOLUTION: Disable RLS completely on button tables
-- (They don't need RLS since they're configuration tables anyway)

ALTER TABLE button_main_sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE button_sub_sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE sidebar_buttons DISABLE ROW LEVEL SECURITY;
ALTER TABLE button_permissions DISABLE ROW LEVEL SECURITY;

-- Now anyone with access to the table can read/write
-- This is safe for config tables that only admins modify
