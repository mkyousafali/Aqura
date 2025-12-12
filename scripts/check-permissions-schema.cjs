const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

async function checkSchema() {
  try {
    // Get full table structure
    const { data: fullData, error } = await supabase
      .from('button_permissions')
      .select('*')
      .limit(1);

    if (error) {
      console.error('Error:', error);
      return;
    }

    if (fullData && fullData.length > 0) {
      console.log('=== FULL BUTTON_PERMISSIONS RECORD ===');
      console.log(JSON.stringify(fullData[0], null, 2));
    }
  } catch (err) {
    console.error('Error:', err);
  }
}

checkSchema();
