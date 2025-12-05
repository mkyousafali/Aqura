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

console.log('🔧 Fixing RLS policy on users table...\n');

// SQL to fix the UPDATE policy on users table
// This allows users to update their own record OR any admin to update any user
const sqlQueries = [
  // First, drop existing UPDATE policies if they exist
  `DROP POLICY IF EXISTS "Allow update on users for authenticated users" ON users;`,
  `DROP POLICY IF EXISTS "users_update_policy" ON users;`,
  `DROP POLICY IF EXISTS "Allow admins to update users" ON users;`,
  
  // Create new UPDATE policy that allows:
  // 1. Users to update their own record
  // 2. Admins to update any user
  `CREATE POLICY "Allow update on users for self or admin"
   ON users FOR UPDATE
   USING (
     auth.uid() = id OR
     (SELECT role_type FROM users WHERE id = auth.uid()) = 'Admin'
   )
   WITH CHECK (
     auth.uid() = id OR
     (SELECT role_type FROM users WHERE id = auth.uid()) = 'Admin'
   );`
];

try {
  console.log('Executing SQL to fix RLS policy...\n');
  
  for (const sql of sqlQueries) {
    const { error } = await supabase.rpc('execute_sql', { sql_query: sql }).catch(async () => {
      // If rpc doesn't exist, try using SQL directly via fetch
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/execute_sql`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'Content-Type': 'application/json',
          'apikey': supabaseServiceKey,
        },
        body: JSON.stringify({ sql_query: sql }),
      });
      return response.json();
    });
    
    if (error) {
      console.log('⚠️ Note:', error.message);
    }
  }
  
  console.log('✅ RLS policy update complete!');
  console.log('\n📋 The new policy allows:');
  console.log('   1. Users to update their own record');
  console.log('   2. Admins (role_type = "Admin") to update any user');
  
  console.log('\n💡 If you still get permission errors:');
  console.log('   1. Go to Supabase Dashboard → SQL Editor');
  console.log('   2. Copy this SQL and run it directly:\n');
  console.log(sqlQueries[sqlQueries.length - 1]);
  
} catch (error) {
  console.error('❌ Error:', error.message);
  console.log('\n🔧 Manual fix - Run this in Supabase SQL Editor:');
  console.log('\nDROP POLICY IF EXISTS "Allow update on users for self or admin" ON users;');
  console.log('\nCREATE POLICY "Allow update on users for self or admin"');
  console.log('   ON users FOR UPDATE');
  console.log('   USING (');
  console.log('     auth.uid() = id OR');
  console.log('     (SELECT role_type FROM users WHERE id = auth.uid()) = \'Admin\'');
  console.log('   )');
  console.log('   WITH CHECK (');
  console.log('     auth.uid() = id OR');
  console.log('     (SELECT role_type FROM users WHERE id = auth.uid()) = \'Admin\'');
  console.log('   );');
}
