// Quick check of current permission system state
const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
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

async function checkPermissions() {
  console.log('🔍 Checking current permission system state...\n');

  // Check app_functions
  const { data: functions, error: funcError } = await supabase
    .from('app_functions')
    .select('*')
    .order('category', { ascending: true });

  if (funcError) {
    console.error('❌ Error fetching functions:', funcError.message);
    return;
  }

  console.log(`📊 app_functions table: ${functions.length} functions found\n`);
  
  // Group by category
  const byCategory = {};
  functions.forEach(f => {
    if (!byCategory[f.category]) byCategory[f.category] = [];
    byCategory[f.category].push(f);
  });

  Object.keys(byCategory).sort().forEach(cat => {
    console.log(`  ${cat}: ${byCategory[cat].length} functions`);
    byCategory[cat].forEach(f => {
      console.log(`    - ${f.function_name} (${f.function_code})`);
    });
  });

  // Check role_permissions
  const { data: permissions, error: permError } = await supabase
    .from('role_permissions')
    .select('*, user_roles(role_name), app_functions(function_name, function_code)');

  if (permError) {
    console.error('❌ Error fetching permissions:', permError.message);
    return;
  }

  console.log(`\n🔐 role_permissions table: ${permissions.length} permission mappings found\n`);

  // Group by role
  const byRole = {};
  permissions.forEach(p => {
    const roleName = p.user_roles?.role_name || 'Unknown';
    if (!byRole[roleName]) byRole[roleName] = [];
    byRole[roleName].push(p);
  });

  Object.keys(byRole).sort().forEach(role => {
    console.log(`  ${role}: ${byRole[role].length} permissions`);
    byRole[role].forEach(p => {
      const func = p.app_functions;
      const perms = [];
      if (p.can_view) perms.push('View');
      if (p.can_add) perms.push('Add');
      if (p.can_edit) perms.push('Edit');
      if (p.can_delete) perms.push('Delete');
      if (p.can_export) perms.push('Export');
      console.log(`    - ${func?.function_name || 'Unknown'} (${func?.function_code || '?'}): ${perms.join(', ')}`);
    });
  });

  // Check user_roles
  const { data: roles, error: roleError } = await supabase
    .from('user_roles')
    .select('*')
    .order('role_name', { ascending: true });

  if (roleError) {
    console.error('❌ Error fetching roles:', roleError.message);
    return;
  }

  console.log(`\n👥 user_roles table: ${roles.length} roles found`);

  // Summary
  console.log('\n📋 Summary:');
  console.log(`   Functions: ${functions.length} / 43 (need ${43 - functions.length} more)`);
  console.log(`   Permissions: ${permissions.length}`);
  console.log(`   Roles: ${roles.length}`);
  
  // Find Master Admin and Admin roles
  const masterAdmin = roles.find(r => r.role_code === 'MASTER_ADMIN');
  const admin = roles.find(r => r.role_code === 'ADMIN');
  
  if (masterAdmin) {
    const masterPerms = permissions.filter(p => p.role_id === masterAdmin.id);
    console.log(`   Master Admin permissions: ${masterPerms.length}`);
  }
  
  if (admin) {
    const adminPerms = permissions.filter(p => p.role_id === admin.id);
    console.log(`   Admin permissions: ${adminPerms.length}`);
  }
}

checkPermissions()
  .then(() => {
    console.log('\n✨ Check complete!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n💥 Check failed:', err);
    process.exit(1);
  });
