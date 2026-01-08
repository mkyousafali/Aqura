-- Enable RLS on denomination_transactions table with permissive policies (matching hr_employee_master pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE denomination_transactions ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to denomination_transactions" ON denomination_transactions;
DROP POLICY IF EXISTS "authenticated_can_view_denomination_transactions" ON denomination_transactions;
DROP POLICY IF EXISTS "authenticated_can_insert_denomination_transactions" ON denomination_transactions;
DROP POLICY IF EXISTS "authenticated_can_update_denomination_transactions" ON denomination_transactions;
DROP POLICY IF EXISTS "authenticated_can_delete_denomination_transactions" ON denomination_transactions;
DROP POLICY IF EXISTS "service_role_full_access_denomination_transactions" ON denomination_transactions;

-- Simple permissive policy for all operations (matches hr_employee_master and denomination_user_preferences pattern)
CREATE POLICY "Allow all access to denomination_transactions"
  ON denomination_transactions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to all roles (matches hr_employee_master pattern)
GRANT ALL ON denomination_transactions TO authenticated;
GRANT ALL ON denomination_transactions TO service_role;
GRANT ALL ON denomination_transactions TO anon;
