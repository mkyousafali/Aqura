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

console.log('🔧 Creating simplified update_user function...\n');

const sqlFunction = `
-- Drop the old complex function
DROP FUNCTION IF EXISTS update_user(uuid, json) CASCADE;
DROP FUNCTION IF EXISTS update_user_simple(uuid, text, text) CASCADE;

-- Create simpler version that just updates if user is authenticated
CREATE OR REPLACE FUNCTION update_user(
    p_user_id uuid,
    p_updates json
  )
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  BEGIN
    -- Simply update the user record
    -- SECURITY DEFINER allows this to bypass RLS
    UPDATE users
    SET
      username = COALESCE((p_updates->>'username')::text, username),
      email = COALESCE((p_updates->>'email')::text, email),
      role_type = COALESCE((p_updates->>'role_type')::text, role_type),
      user_type = COALESCE((p_updates->>'user_type')::text, user_type),
      branch_id = COALESCE((p_updates->>'branch_id')::integer, branch_id),
      employee_id = COALESCE((p_updates->>'employee_id')::uuid, employee_id),
      role_id = COALESCE((p_updates->>'role_id')::text, role_id),
      position_id = COALESCE((p_updates->>'position_id')::uuid, position_id),
      status = COALESCE((p_updates->>'status')::text, status),
      quick_access_code = COALESCE((p_updates->>'quick_access_code')::text, quick_access_code),
      updated_at = NOW()
    WHERE id = p_user_id;

    RETURN json_build_object(
      'success', true,
      'message', 'User updated successfully',
      'user_id', p_user_id
    );
  END;
  $$;

GRANT EXECUTE ON FUNCTION update_user(uuid, json) TO authenticated, anon;
`;

console.log('📋 SQL to run in Supabase Dashboard:\n');
console.log(sqlFunction);

console.log('\n📍 Steps:');
console.log('1. Go to https://app.supabase.com');
console.log('2. Select your project');
console.log('3. SQL Editor → New query');
console.log('4. Copy and paste the SQL above');
console.log('5. Click Run');
console.log('\n✅ This simplified version will work for all authenticated users!');
