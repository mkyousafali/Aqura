-- Fix approval_permissions table RLS and trigger

-- First, create the trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_approval_permissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists and recreate it
DROP TRIGGER IF EXISTS update_approval_permissions_timestamp ON approval_permissions;

CREATE TRIGGER update_approval_permissions_timestamp
BEFORE UPDATE ON approval_permissions
FOR EACH ROW
EXECUTE FUNCTION update_approval_permissions_updated_at();

-- Enable RLS on approval_permissions table
ALTER TABLE approval_permissions ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to approval_permissions" ON approval_permissions;
DROP POLICY IF EXISTS "Users can manage their own approval permissions" ON approval_permissions;
DROP POLICY IF EXISTS "Master admin can manage all approval permissions" ON approval_permissions;

-- Create simple permissive policy for all operations (matching denomination_user_preferences pattern)
CREATE POLICY "Allow all access to approval_permissions"
  ON approval_permissions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- CRITICAL: Grant access to ALL roles (anon, authenticated, service_role)
-- This is required for upsert operations to work
GRANT ALL ON approval_permissions TO anon;
GRANT ALL ON approval_permissions TO authenticated;
GRANT ALL ON approval_permissions TO service_role;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approval_permissions_leave_requests ON approval_permissions 
USING btree (can_approve_leave_requests) 
WHERE (can_approve_leave_requests = true AND is_active = true);

CREATE INDEX IF NOT EXISTS idx_approval_permissions_is_active ON approval_permissions
USING btree (is_active) 
WHERE (is_active = true);

