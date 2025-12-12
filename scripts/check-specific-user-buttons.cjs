const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkSpecificUser() {
  const userId = '6f883b06-13a8-476b-86ce-a7a79553a4bd';
  
  console.log('🔍 Checking user:', userId, '\n');

  try {
    // Get user info
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id, username, is_master_admin, is_admin')
      .eq('id', userId)
      .single();

    if (userError) throw userError;
    
    console.log('👤 User:', user.username);
    console.log('   Master Admin:', user.is_master_admin);
    console.log('   Admin:', user.is_admin);
    console.log('');

    // Check button_permissions for this user
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('button_id, is_enabled')
      .eq('user_id', userId);

    if (permError) throw permError;

    console.log(`📊 Total button_permissions records: ${permissions?.length || 0}`);
    
    if (permissions && permissions.length > 0) {
      const enabled = permissions.filter(p => p.is_enabled);
      const disabled = permissions.filter(p => !p.is_enabled);
      
      console.log(`✅ Enabled: ${enabled.length}`);
      console.log(`❌ Disabled: ${disabled.length}\n`);

      // Get button codes for enabled buttons
      if (enabled.length > 0) {
        const enabledButtonIds = enabled.map(p => p.button_id);

        const { data: buttons, error: btnError } = await supabase
          .from('sidebar_buttons')
          .select('id, button_code, button_name_en')
          .in('id', enabledButtonIds);

        if (!btnError && buttons) {
          console.log(`📋 All ${buttons.length} enabled button codes:`);
          buttons.forEach(btn => {
            console.log(`   ${btn.button_code.padEnd(30)} - ${btn.button_name_en}`);
          });
        }
      } else {
        console.log('⚠️  No enabled buttons for this user!\n');
        
        // Show some disabled ones
        if (disabled.length > 0) {
          const disabledButtonIds = disabled.slice(0, 5).map(p => p.button_id);
          const { data: disabledButtons } = await supabase
            .from('sidebar_buttons')
            .select('button_code, button_name_en')
            .in('id', disabledButtonIds);
          
          if (disabledButtons) {
            console.log('📋 Sample disabled buttons:');
            disabledButtons.forEach(btn => {
              console.log(`   ❌ ${btn.button_code} - ${btn.button_name_en}`);
            });
          }
        }
      }
    } else {
      console.log('⚠️  No button_permissions records found for this user!');
      console.log('   This user needs permissions to be created.');
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkSpecificUser();
