const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  console.log('=== UNIQUE ROLE_TYPE VALUES IN USERS TABLE ===');
  const { data: users, error } = await supabase
    .from('users')
    .select('role_type')
    .not('role_type', 'is', null);

  if (error) {
    console.error('Error:', error.message);
  } else {
    const uniqueRoles = [...new Set(users.map(u => u.role_type))].sort();
    console.log('Found role_type values:', uniqueRoles);
    console.log('\nTotal unique roles:', uniqueRoles.length);
  }

  console.log('\n=== USER_ROLES TABLE (All Roles) ===');
  const { data: roles, error: rolesError } = await supabase
    .from('user_roles')
    .select('role_name, role_code')
    .order('role_name');

  if (rolesError) {
    console.error('Error:', rolesError.message);
  } else {
    console.log('Available roles:');
    roles.forEach(r => {
      console.log(`  - ${r.role_name} (${r.role_code})`);
    });
  }
})();
