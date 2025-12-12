const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkUserPermissions() {
  const userId = '6f883b06-13a8-476b-86ce-a7a79553a4bd';
  
  console.log('🔍 Checking permissions for user:', userId);
  console.log('='.repeat(80), '\n');

  try {
    // Get user info
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, username, is_master_admin, is_admin')
      .eq('id', userId)
      .single();

    if (userError) throw userError;
    
    console.log('👤 User: ', user.username);
    console.log('   Master Admin:', user.is_master_admin);
    console.log('   Admin:', user.is_admin);
    console.log('\n' + '='.repeat(80) + '\n');

    // Get ALL button_permissions for this user
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('button_id, is_enabled')
      .eq('user_id', userId)
      .order('button_id');

    if (permError) throw permError;

    if (!permissions || permissions.length === 0) {
      console.log('❌ No button_permissions records found for this user!');
      return;
    }

    console.log(`📊 Total permissions: ${permissions.length}\n`);

    // Get ALL button codes from sidebar_buttons
    const allButtonIds = permissions.map(p => p.button_id);
    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('id, button_code, button_name_en')
      .in('id', allButtonIds)
      .order('button_code');

    if (btnError) throw btnError;

    // Create map of button_id to button info
    const buttonMap = {};
    buttons.forEach(btn => {
      buttonMap[btn.id] = btn;
    });

    // Separate enabled and disabled
    const enabled = [];
    const disabled = [];

    permissions.forEach(perm => {
      const btn = buttonMap[perm.button_id];
      if (btn) {
        if (perm.is_enabled) {
          enabled.push(btn);
        } else {
          disabled.push(btn);
        }
      }
    });

    // Display ENABLED buttons
    console.log('✅ ENABLED BUTTONS (' + enabled.length + '):');
    console.log('-'.repeat(80));
    enabled.forEach((btn, idx) => {
      console.log(`${(idx + 1).toString().padStart(3)}. ${btn.button_code.padEnd(35)} - ${btn.button_name_en}`);
    });

    console.log('\n' + '='.repeat(80) + '\n');

    // Display DISABLED buttons
    console.log('❌ DISABLED BUTTONS (' + disabled.length + '):');
    console.log('-'.repeat(80));
    disabled.forEach((btn, idx) => {
      console.log(`${(idx + 1).toString().padStart(3)}. ${btn.button_code.padEnd(35)} - ${btn.button_name_en}`);
    });

    console.log('\n' + '='.repeat(80));
    console.log(`\n✅ Summary: ${enabled.length} Enabled, ❌ ${disabled.length} Disabled\n`);

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkUserPermissions();
