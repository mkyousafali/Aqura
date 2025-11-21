const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabase = createClient(
  envVars.VITE_SUPABASE_URL,
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

(async () => {
  console.log('Testing orders access with different auth contexts...\n');
  
  // Test 1: Service role (should see everything)
  console.log('1. Service role access:');
  const { data: serviceData, error: serviceError } = await supabase
    .from('orders')
    .select('*');
  
  console.log(`   Result: ${serviceData?.length || 0} orders`);
  if (serviceError) {
    console.log(`   Error: ${serviceError.message}`);
  }
  
  console.log('\n2. Checking if RLS is enabled on orders table:');
  // Check table settings
  const { data: tableInfo } = await supabase
    .from('orders')
    .select('*')
    .limit(0);
  
  console.log('   Table accessible:', !tableInfo ? 'No' : 'Yes');
  
  console.log('\n3. Testing with anon key (should fail with RLS):');
  const supabaseAnon = createClient(
    envVars.VITE_SUPABASE_URL,
    envVars.VITE_SUPABASE_ANON_KEY
  );
  
  const { data: anonData, error: anonError } = await supabaseAnon
    .from('orders')
    .select('*');
  
  console.log(`   Result: ${anonData?.length || 0} orders`);
  if (anonError) {
    console.log(`   Error: ${anonError.message}`);
    console.log(`   Code: ${anonError.code}`);
  }
  
  console.log('\n4. Checking user "yousafali" details:');
  const { data: userData } = await supabase
    .from('users')
    .select('*')
    .eq('username', 'yousafali')
    .single();
  
  if (userData) {
    console.log('   ID:', userData.id);
    console.log('   Username:', userData.username);
    console.log('   Role Type:', userData.role_type);
    console.log('   Status:', userData.status);
  }
})();
