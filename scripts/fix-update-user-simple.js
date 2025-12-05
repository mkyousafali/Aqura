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

console.log('🔧 Creating simple update_user function (just text casting)...\n');

const sqlFunction = `
-- Drop the old function
DROP FUNCTION IF EXISTS update_user(uuid, json) CASCADE;

-- Create simple function that lets PostgreSQL handle type conversion
CREATE OR REPLACE FUNCTION update_user(
    p_user_id uuid,
    p_updates json
  )
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  DECLARE
    v_result RECORD;
  BEGIN
    -- Build dynamic UPDATE statement
    UPDATE users
    SET
      username = COALESCE(p_updates->>'username', username),
      quick_access_code = COALESCE(p_updates->>'quick_access_code', quick_access_code),
      user_type = COALESCE((p_updates->>'user_type')::text, user_type::text)::user_type_enum,
      branch_id = COALESCE((p_updates->>'branch_id')::integer, branch_id),
      employee_id = COALESCE((p_updates->>'employee_id')::uuid, employee_id),
      role_type = COALESCE((p_updates->>'role_type')::text, role_type::text)::role_type_enum,
      position_id = COALESCE((p_updates->>'position_id')::uuid, position_id),
      status = COALESCE((p_updates->>'status')::text, status::text),
      avatar = COALESCE(p_updates->>'avatar', avatar),
      ai_translation_enabled = COALESCE((p_updates->>'ai_translation_enabled')::boolean, ai_translation_enabled),
      updated_at = NOW()
    WHERE id = p_user_id
    RETURNING id INTO v_result;

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
console.log('\n✅ Simplified version - let PostgreSQL auto-cast types!');
