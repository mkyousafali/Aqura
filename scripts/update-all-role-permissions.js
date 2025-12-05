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

const supabase = createClient(envVars.VITE_SUPABASE_URL, envVars.VITE_SUPABASE_SERVICE_KEY);

console.log('🔄 UPDATING ROLE PERMISSIONS FOR ALL 35 ROLES...\n');

// Get all roles and functions
const { data: roles } = await supabase
  .from('user_roles')
  .select('id, role_code')
  .eq('is_active', true);

const { data: functions } = await supabase
  .from('app_functions')
  .select('id')
  .eq('is_active', true);

console.log('Found: ' + roles?.length + ' roles, ' + functions?.length + ' functions\n');

// Define permissions by role type
const getPermissions = (roleCode) => {
  if (roleCode === 'MASTER_ADMIN') {
    return { can_view: true, can_add: true, can_edit: true, can_delete: true, can_export: true };
  } else if (roleCode === 'ADMIN') {
    return { can_view: true, can_add: true, can_edit: true, can_delete: false, can_export: true };
  } else {
    // All other roles (Position-based)
    return { can_view: true, can_add: true, can_edit: false, can_delete: false, can_export: true };
  }
};

let totalUpdated = 0;

// Update permissions for each role and function
for (const role of roles || []) {
  const perms = getPermissions(role.role_code);
  console.log('Processing role: ' + role.role_code);

  for (const func of functions || []) {
    // Check if permission exists
    const { data: existing } = await supabase
      .from('role_permissions')
      .select('id')
      .eq('role_id', role.id)
      .eq('function_id', func.id)
      .maybeSingle();

    if (existing) {
      // Update existing
      await supabase
        .from('role_permissions')
        .update(perms)
        .eq('role_id', role.id)
        .eq('function_id', func.id);
    } else {
      // Insert new
      await supabase
        .from('role_permissions')
        .insert({
          role_id: role.id,
          function_id: func.id,
          ...perms
        });
    }
    totalUpdated++;
  }
}

console.log('\n✅ Updated: ' + totalUpdated + ' permission records\n');

// Verify
console.log('📊 VERIFICATION:\n');

const masterAdmin = roles?.find(r => r.role_code === 'MASTER_ADMIN');
if (masterAdmin) {
  const { data: masterPerms } = await supabase
    .from('role_permissions')
    .select('can_view, can_add, can_edit, can_delete, can_export')
    .eq('role_id', masterAdmin.id)
    .limit(1)
    .single();
  
  console.log('MASTER_ADMIN:');
  if (masterPerms) {
    console.log('  View: ' + (masterPerms.can_view ? '✅' : '❌'));
    console.log('  Add:  ' + (masterPerms.can_add ? '✅' : '❌'));
    console.log('  Edit: ' + (masterPerms.can_edit ? '✅' : '❌'));
    console.log('  Delete: ' + (masterPerms.can_delete ? '✅' : '❌'));
    console.log('  Export: ' + (masterPerms.can_export ? '✅' : '❌'));
  }
}

const admin = roles?.find(r => r.role_code === 'ADMIN');
if (admin) {
  const { data: adminPerms } = await supabase
    .from('role_permissions')
    .select('can_view, can_add, can_edit, can_delete, can_export')
    .eq('role_id', admin.id)
    .limit(1)
    .single();
  
  console.log('\nADMIN:');
  if (adminPerms) {
    console.log('  View: ' + (adminPerms.can_view ? '✅' : '❌'));
    console.log('  Add:  ' + (adminPerms.can_add ? '✅' : '❌'));
    console.log('  Edit: ' + (adminPerms.can_edit ? '✅' : '❌'));
    console.log('  Delete: ' + (adminPerms.can_delete ? '✅' : '❌'));
    console.log('  Export: ' + (adminPerms.can_export ? '✅' : '❌'));
  }
}

// Get a position-based role
const positionRole = roles?.find(r => !['MASTER_ADMIN', 'ADMIN'].includes(r.role_code));
if (positionRole) {
  const { data: positionPerms } = await supabase
    .from('role_permissions')
    .select('can_view, can_add, can_edit, can_delete, can_export')
    .eq('role_id', positionRole.id)
    .limit(1)
    .single();
  
  console.log('\nPOSITION-BASED ROLES (Sample: ' + positionRole.role_code + '):');
  if (positionPerms) {
    console.log('  View: ' + (positionPerms.can_view ? '✅' : '❌'));
    console.log('  Add:  ' + (positionPerms.can_add ? '✅' : '❌'));
    console.log('  Edit: ' + (positionPerms.can_edit ? '✅' : '❌'));
    console.log('  Delete: ' + (positionPerms.can_delete ? '✅' : '❌'));
    console.log('  Export: ' + (positionPerms.can_export ? '✅' : '❌'));
  }
}

console.log('\n✅ Role Permissions Updated Successfully!');
