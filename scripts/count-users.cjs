const { createClient } = require('@supabase/supabase-js');
const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

(async () => {
  try {
    // Get all users
    let allUsers = [];
    let page = 0;
    const pageSize = 1000;
    
    while (true) {
      const { data, error } = await supabase
        .from('users')
        .select('id')
        .range(page * pageSize, (page + 1) * pageSize - 1);
      
      if (error) {
        console.error('Error:', error.message);
        break;
      }
      
      if (!data || data.length === 0) break;
      
      allUsers = allUsers.concat(data);
      console.log(`Page ${page}: fetched ${data.length} users (total: ${allUsers.length})`);
      
      if (data.length < pageSize) break;
      page++;
    }
    
    console.log('\n=== TOTAL USERS: ' + allUsers.length + ' ===');
  } catch (err) {
    console.error('Exception:', err.message);
  }
})();
