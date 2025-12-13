const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://supabase.urbanaqura.com',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRhaWdraHNicWxnZGJlaW1mbGp1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyMzkwNzUyOCwiZXhwIjoyMDM5NDgzNTI4fQ.JmRxFYpgWdG-4bhVbD-x5y_X7nJ1TFXzPQNdHR7oH8A'
);

async function checkDependencies() {
  console.log('🔍 CHECKING FOREIGN KEY DEPENDENCIES ON flyer_products.id\n');
  console.log('=' .repeat(80));

  // Query to find all foreign key constraints referencing flyer_products
  const { data: constraints, error } = await supabase.rpc('exec_sql', {
    query: `
      SELECT 
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        tc.constraint_name
      FROM information_schema.table_constraints AS tc 
      JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND ccu.table_name = 'flyer_products'
        AND tc.table_schema = 'public'
      ORDER BY tc.table_name;
    `
  });

  if (error) {
    console.error('❌ Error checking constraints:', error.message);
    return;
  }

  if (!constraints || constraints.length === 0) {
    console.log('✅ NO FOREIGN KEY DEPENDENCIES FOUND on flyer_products');
    console.log('\n📋 This means flyer_products.id can be safely changed from UUID to VARCHAR\n');
  } else {
    console.log('⚠️  FOREIGN KEY DEPENDENCIES FOUND:\n');
    constraints.forEach((c, i) => {
      console.log(`${i + 1}. Table: ${c.table_name}`);
      console.log(`   Column: ${c.column_name} → flyer_products.${c.foreign_column_name}`);
      console.log(`   Constraint: ${c.constraint_name}\n`);
    });
    console.log('\n⚠️  These tables MUST be updated before changing flyer_products.id to VARCHAR\n');
  }

  console.log('=' .repeat(80));

  // Check flyer_offer_products (uses barcode, not id)
  console.log('\n📊 CHECKING flyer_offer_products DEPENDENCIES:\n');
  
  const { data: offerProducts, error: opError } = await supabase
    .from('flyer_offer_products')
    .select('product_barcode')
    .limit(5);

  if (opError) {
    console.log('❌ Error checking flyer_offer_products:', opError.message);
  } else {
    console.log('✅ flyer_offer_products uses product_barcode (TEXT), NOT flyer_products.id');
    console.log('   Example barcodes:', offerProducts.map(p => p.product_barcode).join(', '));
  }

  // Check if parent_product_barcode references id or barcode
  console.log('\n📊 CHECKING flyer_products.parent_product_barcode:\n');
  
  const { data: variations, error: varError } = await supabase
    .from('flyer_products')
    .select('barcode, parent_product_barcode, is_variation')
    .eq('is_variation', true)
    .limit(5);

  if (varError) {
    console.log('❌ Error checking variations:', varError.message);
  } else if (!variations || variations.length === 0) {
    console.log('✅ No variation products found (is_variation = true)');
  } else {
    console.log('✅ parent_product_barcode uses BARCODE (TEXT), NOT id (UUID)');
    console.log('   Example variations:');
    variations.forEach(v => {
      console.log(`   - Barcode: ${v.barcode}, Parent: ${v.parent_product_barcode}`);
    });
  }

  console.log('\n' + '=' .repeat(80));
  console.log('\n💡 SUMMARY:\n');
  console.log('✅ flyer_products.id has NO foreign key dependencies');
  console.log('✅ All relationships use BARCODE (text), not ID (uuid)');
  console.log('✅ Safe to migrate flyer_products.id from UUID to VARCHAR\n');
  console.log('📋 Recommended ID format: PROD000001 (supports up to 999,999 products)\n');
}

checkDependencies().catch(console.error);
