const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkButtonPermissions() {
  console.log('🔍 Checking button permissions system...\n');

  try {
    // Get a sample user
    const { data: users, error: userError } = await supabase
      .from('users')
      .select('id, username')
      .limit(1);

    if (userError) throw userError;
    
    if (!users || users.length === 0) {
      console.log('❌ No users found');
      return;
    }

    const user = users[0];
    console.log(`👤 Testing with user: ${user.username} (${user.id})\n`);

    // Check button_permissions for this user
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('button_id, is_enabled')
      .eq('user_id', user.id);

    if (permError) throw permError;

    console.log(`📊 Total button_permissions records: ${permissions?.length || 0}`);
    
    if (permissions && permissions.length > 0) {
      const enabled = permissions.filter(p => p.is_enabled).length;
      const disabled = permissions.filter(p => !p.is_enabled).length;
      console.log(`✅ Enabled: ${enabled}`);
      console.log(`❌ Disabled: ${disabled}\n`);

      // Get button codes for enabled buttons
      const enabledButtonIds = permissions
        .filter(p => p.is_enabled)
        .map(p => p.button_id);

      if (enabledButtonIds.length > 0) {
        const { data: buttons, error: btnError } = await supabase
          .from('sidebar_buttons')
          .select('id, button_code, button_name_en')
          .in('id', enabledButtonIds)
          .limit(10);

        if (!btnError && buttons) {
          console.log('📋 Sample enabled buttons (first 10):');
          buttons.forEach(btn => {
            console.log(`   ${btn.button_code} - ${btn.button_name_en}`);
          });
        }
      }
    } else {
      console.log('⚠️  No button permissions found for this user');
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkButtonPermissions();
