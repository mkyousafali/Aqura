const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function compareProductTables() {
  console.log('🔍 COMPARING products vs flyer_products TABLES\n');
  console.log('='.repeat(80));
  
  // Get products table structure
  const { data: products, error: productsError } = await supabase
    .from('products')
    .select('*')
    .limit(1);
  
  // Get flyer_products table structure
  const { data: flyerProducts, error: flyerError } = await supabase
    .from('flyer_products')
    .select('*')
    .limit(1);
  
  if (productsError) {
    console.log('❌ Error fetching products:', productsError.message);
  } else if (products && products.length > 0) {
    console.log('\n📊 PRODUCTS TABLE COLUMNS:');
    const productCols = Object.keys(products[0]).sort();
    productCols.forEach((col, i) => {
      console.log(`${i + 1}. ${col}`);
    });
    console.log(`\nTotal columns: ${productCols.length}`);
  }
  
  console.log('\n' + '='.repeat(80));
  
  if (flyerError) {
    console.log('❌ Error fetching flyer_products:', flyerError.message);
  } else if (flyerProducts && flyerProducts.length > 0) {
    console.log('\n📊 FLYER_PRODUCTS TABLE COLUMNS:');
    const flyerCols = Object.keys(flyerProducts[0]).sort();
    flyerCols.forEach((col, i) => {
      console.log(`${i + 1}. ${col}`);
    });
    console.log(`\nTotal columns: ${flyerCols.length}`);
  }
  
  console.log('\n' + '='.repeat(80));
  
  // Compare columns
  if (products && products.length > 0 && flyerProducts && flyerProducts.length > 0) {
    const productCols = Object.keys(products[0]).sort();
    const flyerCols = Object.keys(flyerProducts[0]).sort();
    
    // Columns in products but NOT in flyer_products
    const missingInFlyer = productCols.filter(col => !flyerCols.includes(col));
    
    // Columns in flyer_products but NOT in products
    const extraInFlyer = flyerCols.filter(col => !productCols.includes(col));
    
    // Common columns
    const common = productCols.filter(col => flyerCols.includes(col));
    
    console.log('\n⚠️  COLUMNS IN products BUT MISSING IN flyer_products:');
    if (missingInFlyer.length > 0) {
      missingInFlyer.forEach((col, i) => {
        console.log(`${i + 1}. ${col}`);
      });
      console.log(`\nTotal missing: ${missingInFlyer.length}`);
    } else {
      console.log('✅ None - all products columns exist in flyer_products');
    }
    
    console.log('\n' + '='.repeat(80));
    
    console.log('\n📋 EXTRA COLUMNS IN flyer_products (NOT in products):');
    if (extraInFlyer.length > 0) {
      extraInFlyer.forEach((col, i) => {
        console.log(`${i + 1}. ${col}`);
      });
      console.log(`\nTotal extra: ${extraInFlyer.length}`);
    } else {
      console.log('✅ None');
    }
    
    console.log('\n' + '='.repeat(80));
    
    console.log('\n✅ COMMON COLUMNS (in both tables):');
    console.log(`Total: ${common.length} columns`);
    common.forEach((col, i) => {
      console.log(`${i + 1}. ${col}`);
    });
  }
  
  console.log('\n' + '='.repeat(80));
  
  // Count records
  const { count: productsCount } = await supabase
    .from('products')
    .select('*', { count: 'exact', head: true });
  
  const { count: flyerCount } = await supabase
    .from('flyer_products')
    .select('*', { count: 'exact', head: true });
  
  console.log('\n📊 RECORD COUNTS:');
  console.log(`products table: ${productsCount} records`);
  console.log(`flyer_products table: ${flyerCount} records`);
  
  console.log('\n' + '='.repeat(80));
  console.log('\n💡 MIGRATION READINESS:');
  
  if (products && flyerProducts && products.length > 0 && flyerProducts.length > 0) {
    const productCols = Object.keys(products[0]);
    const flyerCols = Object.keys(flyerProducts[0]);
    const missingInFlyer = productCols.filter(col => !flyerCols.includes(col));
    
    if (missingInFlyer.length === 0) {
      console.log('✅ READY TO MIGRATE!');
      console.log('   All columns from products table exist in flyer_products');
      console.log('\n📋 NEXT STEPS:');
      console.log('   1. DROP TABLE products CASCADE;');
      console.log('   2. ALTER TABLE flyer_products RENAME TO products;');
      console.log('   3. Update code references from flyer_products to products');
    } else {
      console.log('❌ NOT READY - Missing columns in flyer_products:');
      missingInFlyer.forEach(col => console.log(`   - ${col}`));
      console.log('\n📋 REQUIRED ACTION:');
      console.log('   Add missing columns to flyer_products before migration');
    }
  }
}

compareProductTables().catch(console.error);
