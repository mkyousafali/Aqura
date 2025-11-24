import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

console.log('URL:', supabaseUrl);
console.log('Key:', supabaseServiceKey ? 'Found' : 'Missing');

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkUserRoles() {
  console.log('📊 Checking users table for role_type values...\n');

  const { data, error } = await supabase
    .from('users')
    .select('id, username, role_type')
    .limit(10);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log('Users found:', data.length);
  console.log('\nUser Details:');
  console.log('='.repeat(80));
  
  data.forEach(user => {
    console.log(`Username: ${user.username}`);
    console.log(`  ID: ${user.id}`);
    console.log(`  Role Type: ${user.role_type || 'null'}`);
    console.log('-'.repeat(80));
  });

  // Check specifically for master_admin
  const { data: masterAdmins, error: masterError } = await supabase
    .from('users')
    .select('id, username, role_type')
    .or('role_type.eq.Master Admin,role_type.eq.Admin,role_type.eq.master_admin,role_type.eq.admin');

  if (masterError) {
    console.error('❌ Error checking admin users:', masterError.message);
  } else {
    console.log('\n🔑 Admin Users (Master Admin / Admin):');
    console.log('='.repeat(80));
    if (masterAdmins.length === 0) {
      console.log('⚠️  No admin users found!');
    } else {
      masterAdmins.forEach(user => {
        console.log(`✅ ${user.username} (ID: ${user.id}) - Role Type: ${user.role_type}`);
      });
    }
  }

  // Check what role_type values exist in the database
  const { data: allRoleTypes, error: roleError } = await supabase
    .from('users')
    .select('role_type')
    .limit(100);

  if (!roleError) {
    const uniqueRoleTypes = [...new Set(allRoleTypes.map(u => u.role_type))];
    console.log('\n📋 All unique role_type values found:');
    console.log('='.repeat(80));
    uniqueRoleTypes.forEach(type => {
      console.log(`  - ${type}`);
    });
  }
}

checkUserRoles();
