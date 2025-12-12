-- Grant INSERT, UPDATE, DELETE permissions to anon role on button tables
-- This fixes the 42501 (permission denied) error when trying to INSERT

GRANT INSERT, UPDATE, DELETE ON button_main_sections TO anon;
GRANT INSERT, UPDATE, DELETE ON button_sub_sections TO anon;
GRANT INSERT, UPDATE, DELETE ON sidebar_buttons TO anon;
GRANT INSERT, UPDATE, DELETE ON button_permissions TO anon;

-- Verify the grants were applied
SELECT 
  grantee,
  privilege_type,
  table_name
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('button_main_sections', 'button_sub_sections', 'sidebar_buttons', 'button_permissions')
  AND grantee = 'anon'
ORDER BY table_name, privilege_type;
