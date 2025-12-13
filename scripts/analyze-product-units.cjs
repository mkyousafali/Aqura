const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function analyzeProductUnits() {
  console.log('🔍 ANALYZING product_units TABLE AND flyer_products.unit_name\n');
  console.log('='.repeat(80));
  
  // Check product_units table structure
  const { data: units, error: unitsError } = await supabase
    .from('product_units')
    .select('*')
    .limit(10);
  
  if (unitsError) {
    console.error('❌ Error fetching product_units:', unitsError.message);
  } else {
    console.log('\n📊 product_units TABLE STRUCTURE (sample):');
    if (units && units.length > 0) {
      console.log('Columns:', Object.keys(units[0]));
      console.log('\nSample records:');
      units.forEach((unit, i) => {
        console.log(`${i + 1}.`, JSON.stringify(unit, null, 2));
      });
    }
    
    const { count: unitsCount } = await supabase
      .from('product_units')
      .select('*', { count: 'exact', head: true });
    
    console.log('\n📋 Total units in product_units:', unitsCount);
  }
  
  // Get all units from product_units
  const { data: allUnits } = await supabase
    .from('product_units')
    .select('*')
    .order('id');
  
  if (allUnits) {
    console.log('\n📋 ALL UNITS IN product_units:');
    allUnits.forEach((unit, i) => {
      const nameField = unit.unit_name || unit.name_en || unit.name || 'N/A';
      console.log(`${i + 1}. ID: ${unit.id} | Name: ${nameField}`);
    });
  }
  
  console.log('\n' + '='.repeat(80));
  
  // Get unique unit_name values from flyer_products
  const { data: flyerProducts } = await supabase
    .from('flyer_products')
    .select('unit_name')
    .order('unit_name');
  
  if (flyerProducts) {
    const uniqueUnitNames = [...new Set(flyerProducts.map(p => p.unit_name).filter(Boolean))];
    
    console.log('\n📊 FLYER_PRODUCTS UNIT_NAME ANALYSIS:');
    console.log(`Total products: ${flyerProducts.length}`);
    console.log(`Unique unit_name values: ${uniqueUnitNames.length}`);
    
    // Count products per unit
    const unitCounts = {};
    flyerProducts.forEach(p => {
      if (p.unit_name) {
        unitCounts[p.unit_name] = (unitCounts[p.unit_name] || 0) + 1;
      }
    });
    
    console.log('\n📋 UNIT NAME DISTRIBUTION:');
    Object.entries(unitCounts)
      .sort((a, b) => b[1] - a[1])
      .forEach(([unit, count], i) => {
        console.log(`${i + 1}. "${unit}" - ${count} products`);
      });
    
    console.log('\n📋 ALL UNIQUE UNIT NAMES (sorted):');
    uniqueUnitNames.sort().forEach((unit, i) => {
      console.log(`${i + 1}. "${unit}"`);
    });
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('\n💡 RECOMMENDATION:');
  console.log('We can migrate unit_name to unit_id similar to category migration:');
  console.log('1. Change product_units id from UUID to VARCHAR(10) with codes like UNIT001, UNIT002');
  console.log('2. Insert unique unit_name values into product_units');
  console.log('3. Add unit_id VARCHAR(10) to flyer_products');
  console.log('4. Map flyer_products.unit_name to unit_id');
  console.log('5. Drop unit_name column from flyer_products');
}

analyzeProductUnits().catch(console.error);
