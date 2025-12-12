const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function findFunctionSignatures() {
  console.log('🔍 Finding exact function signatures...\n');

  // Query to get function signatures
  const query = `
    SELECT 
      p.proname as function_name,
      pg_get_function_arguments(p.oid) as arguments,
      pg_get_function_identity_arguments(p.oid) as identity_args,
      'DROP FUNCTION IF EXISTS ' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ');' as drop_statement
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
      AND (p.proname = 'create_user' OR p.proname = 'update_user')
    ORDER BY p.proname, p.oid;
  `;

  console.log('Executing query to find functions...\n');
  
  // Use fetch API to query Supabase REST API directly
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_raw_sql`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': serviceKey,
      'Authorization': `Bearer ${serviceKey}`
    },
    body: JSON.stringify({ sql: query })
  });

  if (!response.ok) {
    console.log('⚠️  Cannot use exec_raw_sql, trying alternative...\n');
    
    // Alternative: Just show what we need to drop
    console.log('📋 Use these DROP statements (try all variations):\n');
    console.log('-- For create_user:');
    console.log('DROP FUNCTION IF EXISTS create_user CASCADE;');
    console.log('');
    console.log('-- For update_user:');
    console.log('DROP FUNCTION IF EXISTS update_user CASCADE;');
    console.log('');
    console.log('⚠️  Use CASCADE to drop all versions at once');
    return;
  }

  const data = await response.json();
  console.log('📋 Exact DROP statements needed:\n');
  data.forEach(row => {
    console.log(row.drop_statement);
  });
}

findFunctionSignatures().catch(console.error);
