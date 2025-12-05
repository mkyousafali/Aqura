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

console.log('🔍 Checking users table RLS status...\n');

// Check if RLS is enabled
const { data: rls } = await supabase
  .rpc('get_table_rls_status', { table_name: 'users' })
  .catch(e => {
    console.log('Note: RLS check function may not exist, checking via direct query...');
    return { data: null };
  });

if (rls) {
  console.log('RLS Status:', rls);
} else {
  console.log('⚠️ Could not check RLS status directly');
}

// Try fetching user with anon key to see what policies allow
console.log('\n📋 Sample users in database:');
const { data: users } = await supabase
  .from('users')
  .select('id, username, role_type, created_at')
  .limit(10);

if (users) {
  console.log(`Found ${users.length} users:\n`);
  users.forEach(u => {
    console.log(`  - ${u.username} (${u.role_type})`);
  });
} else {
  console.log('Could not fetch users');
}

console.log('\n💡 To fix the permission issue:');
console.log('1. Go to Supabase Dashboard → SQL Editor');
console.log('2. Run: ALTER TABLE users DISABLE ROW LEVEL SECURITY;');
console.log('3. Test your update');
console.log('4. Or update the user "Abdhusathar" role_type to "Admin"');
