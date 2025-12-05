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

console.log('🔧 Setting up update_user database function...\n');

// SQL to create the update_user function
const sqlStatements = [
  // Drop existing function if it exists
  `DROP FUNCTION IF EXISTS update_user(uuid, json) CASCADE;`,
  
  // Create the new update_user function
  `CREATE OR REPLACE FUNCTION update_user(
    p_user_id uuid,
    p_updates json
  )
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  DECLARE
    v_current_user_id uuid := auth.uid();
    v_is_admin boolean;
    v_update_count int;
  BEGIN
    -- Check if user is authenticated
    IF v_current_user_id IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Not authenticated'
      );
    END IF;

    -- Check if current user is admin
    SELECT (role_type = 'Admin') INTO v_is_admin
    FROM users
    WHERE id = v_current_user_id;

    -- Allow: 1) updating own record OR 2) admin updating any record
    IF p_user_id != v_current_user_id AND NOT v_is_admin THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Permission denied: Only admins can update other users'
      );
    END IF;

    -- Update the user with dynamic JSON fields
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
    WHERE id = p_user_id
    AND (
      -- User can update self
      p_user_id = v_current_user_id
      OR
      -- Or admin can update anyone
      v_is_admin = true
    );

    GET DIAGNOSTICS v_update_count = ROW_COUNT;

    IF v_update_count = 0 THEN
      RETURN json_build_object(
        'success', false,
        'message', 'User not found or no permission to update'
      );
    END IF;

    RETURN json_build_object(
      'success', true,
      'message', 'User updated successfully',
      'user_id', p_user_id
    );
  END;
  $$;`,
  
  // Grant execute permission to authenticated users
  `GRANT EXECUTE ON FUNCTION update_user(uuid, json) TO authenticated;`,
  
  // Also create a simpler version for updating specific fields
  `CREATE OR REPLACE FUNCTION update_user_simple(
    p_user_id uuid,
    p_field text,
    p_value text
  )
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  DECLARE
    v_current_user_id uuid := auth.uid();
    v_is_admin boolean;
  BEGIN
    -- Check if user is authenticated
    IF v_current_user_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    -- Check if current user is admin
    SELECT (role_type = 'Admin') INTO v_is_admin
    FROM users WHERE id = v_current_user_id;

    -- Check permissions
    IF p_user_id != v_current_user_id AND NOT v_is_admin THEN
      RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;

    -- Update the specific field
    EXECUTE format('UPDATE users SET %I = %L, updated_at = NOW() WHERE id = %L',
      p_field, p_value, p_user_id);

    RETURN json_build_object('success', true, 'message', 'Updated successfully');
  END;
  $$;`,
  
  `GRANT EXECUTE ON FUNCTION update_user_simple(uuid, text, text) TO authenticated;`
];

console.log('📋 SQL functions to execute:\n');

// Print all SQL statements
sqlStatements.forEach((sql, index) => {
  console.log(`${index + 1}. ${sql.split('\n')[0].substring(0, 60)}...`);
});

console.log('\n');
console.log('=' .repeat(70));
console.log('📍 MANUAL STEPS - Run in Supabase SQL Editor:');
console.log('=' .repeat(70));
console.log('\n1. Go to: https://app.supabase.com');
console.log('2. Select your project');
console.log('3. Go to: SQL Editor (left sidebar)');
console.log('4. Click: New query');
console.log('5. Copy and paste ALL SQL below:');
console.log('\n' + '─'.repeat(70) + '\n');

sqlStatements.forEach(sql => {
  console.log(sql);
  console.log('');
});

console.log('\n' + '─'.repeat(70));
console.log('\n6. Click: Run');
console.log('7. Verify: "No errors" message appears');
console.log('\n✅ Once done, the updateUser function in frontend will work!');
console.log('   The function has built-in permission checks:\n');
console.log('   ✓ Users can update their own record');
console.log('   ✓ Only admins can update other users');
console.log('   ✓ RLS is still active but bypassed by function\n');
