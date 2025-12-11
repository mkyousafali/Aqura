const { createClient } = require('@supabase/supabase-js');
const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);
const fs = require('fs');

(async () => {
  try {
    // Get all users
    const { data: users, error: usersError } = await supabase.from('users').select('id');
    if (usersError) throw usersError;
    console.log(`Found ${users.length} users`);
    
    // Generate SQL inserts for button_permissions
    // This will insert is_enabled = true for all users and all buttons
    let sqlInsert = '\n-- Grant all button permissions to all users\n';
    sqlInsert += 'INSERT INTO button_permissions (user_id, button_id, is_enabled) \n';
    sqlInsert += 'SELECT \n';
    sqlInsert += '  u.id as user_id,\n';
    sqlInsert += '  b.id as button_id,\n';
    sqlInsert += '  true as is_enabled\n';
    sqlInsert += 'FROM (\n';
    
    // List all users
    sqlInsert += '  SELECT id FROM (VALUES \n';
    const userValues = users.map(u => `    ('${u.id}'::uuid)`).join(',\n');
    sqlInsert += userValues + '\n';
    sqlInsert += '  ) AS u(id)\n';
    sqlInsert += ') u\n';
    sqlInsert += 'CROSS JOIN sidebar_buttons b\n';
    sqlInsert += 'ON CONFLICT (user_id, button_id) DO NOTHING;\n';
    
    console.log('\nSQL INSERT statement generated:');
    console.log(sqlInsert);
    
    // Write to file
    const migrationFile = 'd:\\Aqura\\supabase\\migrations\\button_permissions_insert.sql';
    fs.writeFileSync(migrationFile, sqlInsert);
    console.log(`\nInsert statement written to: ${migrationFile}`);
    
  } catch (err) {
    console.error('Error:', err.message);
  }
})();
