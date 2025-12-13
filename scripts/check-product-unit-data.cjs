const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkProductUnits() {
  console.log('🔍 CHECKING PRODUCT UNIT DATA\n');
  
  // Get first 5 products with unit data
  const { data: products, error } = await supabase
    .from('products')
    .select('id, product_name_en, unit_id, unit_name_en, unit_name_ar, unit_qty')
    .limit(5);
  
  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }
  
  console.log('📦 SAMPLE PRODUCTS:\n');
  products.forEach((p, i) => {
    console.log(`${i + 1}. ${p.product_name_en}`);
    console.log(`   - unit_id: ${p.unit_id}`);
    console.log(`   - unit_name_en: ${p.unit_name_en}`);
    console.log(`   - unit_name_ar: ${p.unit_name_ar}`);
    console.log(`   - unit_qty: ${p.unit_qty}`);
    console.log('');
  });
  
  // Check how many have unit_id set
  const { data: withUnitId } = await supabase
    .from('products')
    .select('id', { count: 'exact' })
    .not('unit_id', 'is', null);
  
  const { data: withUnitName } = await supabase
    .from('products')
    .select('id', { count: 'exact' })
    .not('unit_name_en', 'is', null);
  
  console.log(`📊 STATISTICS:`);
  console.log(`   - Products with unit_id: ${withUnitId?.length || 0}`);
  console.log(`   - Products with unit_name_en: ${withUnitName?.length || 0}`);
  
  // Get product_units to show what they contain
  const { data: units } = await supabase
    .from('product_units')
    .select('id, name_en, name_ar');
  
  console.log('\n📋 PRODUCT_UNITS TABLE:');
  units?.forEach(u => {
    console.log(`   - ${u.id}: ${u.name_en} / ${u.name_ar}`);
  });
}

checkProductUnits().catch(console.error);
