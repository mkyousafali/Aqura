const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1cGFiYXNlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDg3NTUyNywiZXhwIjoyMDgwNDUxNTI3fQ.0cQzl6VaMLJAkPvN5rUvvHhp1k8QlCr3P3yKPgLUNFA';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkProductsRLS() {
  console.log('=== CHECKING PRODUCTS TABLE RLS ===\n');

  // Check if RLS is enabled
  const { data: rlsStatus, error: rlsError } = await supabase
    .rpc('exec_sql', {
      query: `
        SELECT 
          schemaname,
          tablename,
          rowsecurity
        FROM pg_tables
        WHERE tablename = 'products'
      `
    });

  if (rlsError) {
    console.error('❌ Error checking RLS status:', rlsError);
  } else {
    console.log('📊 RLS Status:', rlsStatus);
  }

  // Check policies
  const { data: policies, error: policiesError } = await supabase
    .rpc('exec_sql', {
      query: `
        SELECT 
          policyname,
          cmd,
          qual,
          with_check
        FROM pg_policies
        WHERE tablename = 'products'
      `
    });

  if (policiesError) {
    console.error('❌ Error checking policies:', policiesError);
  } else {
    console.log('\n📋 RLS Policies on products:', policies);
  }

  // Try to query products directly
  const { data: products, error: productsError, count } = await supabase
    .from('products')
    .select('id, barcode, product_name_en', { count: 'exact' })
    .limit(5);

  console.log('\n📦 Direct query result:');
  console.log('Count:', count);
  console.log('Error:', productsError);
  console.log('Sample products:', products);
}

checkProductsRLS();
