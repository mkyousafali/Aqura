const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

async function checkAllTables() {
  try {
    // Check sidebar_buttons
    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('*');

    console.log('=== SIDEBAR_BUTTONS TABLE ===');
    console.log(`Total buttons: ${buttons?.length || 0}`);
    if (buttons && buttons.length > 0) {
      console.log('\nFirst 10 buttons:');
      buttons.slice(0, 10).forEach(b => {
        console.log(`  ID: ${b.id}, Code: ${b.code}, Name: ${b.name}`);
      });
    }

    // Check button_permissions for ABBAS user
    const { data: Abbas, error: abError } = await supabase
      .from('users')
      .select('id')
      .eq('username', 'ABBAS')
      .single();

    if (!abError && Abbas) {
      console.log(`\n=== ABBAS USER ID ===`);
      console.log(`ID: ${Abbas.id}`);

      const { data: perms } = await supabase
        .from('button_permissions')
        .select('*')
        .eq('user_id', Abbas.id);

      console.log(`\nABBAS Permissions (${perms?.length || 0})`);
      if (perms && perms.length > 0) {
        perms.forEach(p => {
          const btn = buttons?.find(b => b.id === p.button_id);
          console.log(`  Button: ${btn?.code || 'ID: ' + p.button_id}, Enabled: ${p.is_enabled}`);
        });
      }
    } else {
      console.log('\nABBAS user not found');
    }

  } catch (err) {
    console.error('Error:', err);
  }
}

checkAllTables();
