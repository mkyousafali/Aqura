-- Grant explicit permissions to anon role on receiving_records
-- This might be what's actually blocking the 401

-- First, let's see what permissions are currently granted
SELECT grantee, privilege_type 
FROM information_schema.table_privileges 
WHERE table_name = 'receiving_records'
ORDER BY grantee;

-- Grant SELECT, INSERT, UPDATE, DELETE to anon role
GRANT SELECT, INSERT, UPDATE, DELETE ON receiving_records TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON vendor_payment_schedule TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON vendors TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON branches TO anon;

-- Also grant USAGE on schema
GRANT USAGE ON SCHEMA public TO anon;

-- Verify permissions were granted
SELECT grantee, privilege_type 
FROM information_schema.table_privileges 
WHERE table_name = 'receiving_records'
ORDER BY grantee;
