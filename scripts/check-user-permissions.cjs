const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

async function checkUserPermissions() {
  try {
    // Get all users
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, username')
      .limit(5);

    if (usersError) {
      console.error('Error fetching users:', usersError);
      return;
    }

    console.log('\n=== USERS ===');
    users.forEach(u => console.log(`  ${u.id}: ${u.username}`));

    // Check button_permissions table
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('*')
      .limit(20);

    if (permError) {
      console.error('Error fetching permissions:', permError);
      return;
    }

    console.log('\n=== BUTTON_PERMISSIONS COUNT ===');
    console.log(`Total records: ${permissions?.length || 0}`);

    if (permissions && permissions.length > 0) {
      console.log('\n=== SAMPLE PERMISSIONS ===');
      permissions.slice(0, 5).forEach(p => {
        console.log(`  User: ${p.user_id}, Button: ${p.button_code}, Enabled: ${p.is_enabled}`);
      });

      // Group by user
      const userMap = {};
      permissions.forEach(p => {
        if (!userMap[p.user_id]) userMap[p.user_id] = 0;
        userMap[p.user_id]++;
      });

      console.log('\n=== PERMISSIONS PER USER ===');
      Object.entries(userMap).forEach(([userId, count]) => {
        console.log(`  User ${userId}: ${count} permissions`);
      });
    } else {
      console.log('\nNo permissions found in database!');
    }

    // Check sidebar_buttons table
    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('*')
      .limit(10);

    if (!btnError && buttons) {
      console.log('\n=== SIDEBAR_BUTTONS COUNT ===');
      console.log(`Total buttons: ${buttons?.length || 0}`);
    }
  } catch (err) {
    console.error('Error:', err);
  }
}

checkUserPermissions();
