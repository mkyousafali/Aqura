import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔧 Creating update_user RPC function with proper permissions...\n');

const sqlFunction = `
CREATE OR REPLACE FUNCTION update_user(
  p_user_id uuid,
  p_username text DEFAULT NULL,
  p_password text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_role_type text DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_branch_id integer DEFAULT NULL,
  p_employee_id uuid DEFAULT NULL,
  p_role_id text DEFAULT NULL,
  p_position_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_quick_access_code text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
  v_user_id uuid := auth.uid();
BEGIN
  -- Check if user is authenticated and is admin
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  -- Check if current user is admin or updating self
  IF p_user_id != v_user_id THEN
    -- If updating someone else, must be admin
    IF NOT EXISTS (
      SELECT 1 FROM users WHERE id = v_user_id AND role_type = 'Admin'
    ) THEN
      RETURN json_build_object('success', false, 'message', 'Only admins can update other users');
    END IF;
  END IF;

  -- Update the user record
  UPDATE users
  SET
    username = COALESCE(p_username, username),
    email = COALESCE(p_email, email),
    role_type = COALESCE(p_role_type, role_type),
    user_type = COALESCE(p_user_type, user_type),
    branch_id = COALESCE(p_branch_id, branch_id),
    employee_id = COALESCE(p_employee_id, employee_id),
    role_id = COALESCE(p_role_id, role_id),
    position_id = COALESCE(p_position_id, position_id),
    status = COALESCE(p_status, status),
    quick_access_code = COALESCE(p_quick_access_code, quick_access_code),
    updated_at = NOW()
  WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'User updated successfully');
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_user TO authenticated;
`;

try {
  // Execute the SQL
  console.log('Executing SQL to create function...');
  
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseServiceKey}`,
      'Content-Type': 'application/json',
      'apikey': supabaseServiceKey,
    },
    body: JSON.stringify({}),
  });

  console.log('⚠️ Note: RPC execution via REST API is limited.');
  console.log('\n📋 You need to run this SQL manually in Supabase Dashboard:\n');
  console.log(sqlFunction);
  console.log('\n📍 Steps:');
  console.log('1. Go to https://app.supabase.com');
  console.log('2. Select your project');
  console.log('3. Go to SQL Editor');
  console.log('4. Create new query');
  console.log('5. Paste the SQL above');
  console.log('6. Click Run');
  console.log('\nThen update EditUser.svelte to use: await supabase.rpc("update_user", {...})');
  
} catch (error) {
  console.error('Error:', error.message);
}
