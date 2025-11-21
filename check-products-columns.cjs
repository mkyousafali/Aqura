const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
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
  console.log('Checking products table structure...\n');
  
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .limit(1);
  
  if (error) {
    console.error('❌ Error:', error.message);
  } else if (data && data.length > 0) {
    console.log('✅ Products table columns:');
    Object.keys(data[0]).forEach(col => {
      console.log(`   - ${col}`);
    });
    
    console.log('\n📊 Sample product:');
    console.log('   id:', data[0].id);
    console.log('   Has product_code?', 'product_code' in data[0]);
    console.log('   Has serial?', 'serial' in data[0]);
    console.log('   Has code?', 'code' in data[0]);
    console.log('   Has sku?', 'sku' in data[0]);
    
    // Show first few fields
    const sampleFields = {};
    ['id', 'serial', 'code', 'sku', 'product_code', 'name', 'name_ar'].forEach(field => {
      if (field in data[0]) {
        sampleFields[field] = data[0][field];
      }
    });
    console.log('\n   Sample data:', sampleFields);
  } else {
    console.log('⚠️ Products table is empty');
  }
})();
