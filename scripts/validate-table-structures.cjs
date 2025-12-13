/**
 * Validate Table Structures: products vs flyer_products
 * Purpose: Compare schemas before migration
 * Date: 2024-12-13
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function validateTableStructures() {
  console.log('🔍 VALIDATING TABLE STRUCTURES\n');
  console.log('='.repeat(80));

  try {
    // Get all columns from products table
    console.log('\n📊 PART 1: Products Table Columns');
    console.log('-'.repeat(80));
    
    const { data: productsColumns, error: productsError } = await supabase
      .rpc('exec_sql', {
        query: `
          SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
          FROM information_schema.columns
          WHERE table_schema = 'public' 
            AND table_name = 'products'
          ORDER BY ordinal_position;
        `
      });

    if (productsError) {
      console.error('❌ Error fetching products columns:', productsError);
      // Try direct query instead
      const { data: directData, error: directError } = await supabase
        .from('products')
        .select('*')
        .limit(1);
      
      if (directData && directData.length > 0) {
        const columns = Object.keys(directData[0]);
        console.log(`✅ Products table has ${columns.length} columns:`);
        columns.forEach(col => console.log(`  - ${col}`));
      } else {
        throw directError || new Error('Could not fetch products structure');
      }
    } else {
      console.log(`✅ Products table has ${productsColumns?.length || 0} columns`);
      productsColumns?.forEach(col => {
        console.log(`  - ${col.column_name} (${col.data_type}) ${col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`);
      });
    }

    // Get all columns from flyer_products table
    console.log('\n📊 PART 2: Flyer_Products Table Columns');
    console.log('-'.repeat(80));
    
    const { data: flyerData, error: flyerError } = await supabase
      .from('flyer_products')
      .select('*')
      .limit(1);
    
    if (flyerError) {
      console.error('❌ Error fetching flyer_products:', flyerError);
      throw flyerError;
    }

    const flyerColumns = Object.keys(flyerData[0] || {});
    console.log(`✅ Flyer_products table has ${flyerColumns.length} columns:`);
    flyerColumns.forEach(col => console.log(`  - ${col}`));

    // Get products columns for comparison
    const { data: productsData, error: productsDataError } = await supabase
      .from('products')
      .select('*')
      .limit(1);
    
    const productsColumnsArray = Object.keys(productsData?.[0] || {});

    // Find missing columns in flyer_products
    console.log('\n❗ PART 3: Columns in PRODUCTS but NOT in FLYER_PRODUCTS');
    console.log('-'.repeat(80));
    
    const missingInFlyer = productsColumnsArray.filter(col => !flyerColumns.includes(col));
    
    if (missingInFlyer.length === 0) {
      console.log('✅ All products columns exist in flyer_products');
    } else {
      console.log(`⚠️  Found ${missingInFlyer.length} missing columns:`);
      missingInFlyer.forEach(col => console.log(`  ❌ ${col}`));
    }

    // Find extra columns in flyer_products
    console.log('\n➕ PART 4: Columns in FLYER_PRODUCTS but NOT in PRODUCTS');
    console.log('-'.repeat(80));
    
    const extraInFlyer = flyerColumns.filter(col => !productsColumnsArray.includes(col));
    
    if (extraInFlyer.length === 0) {
      console.log('✅ No extra columns in flyer_products');
    } else {
      console.log(`ℹ️  Found ${extraInFlyer.length} extra columns (variation-related, OK):`);
      extraInFlyer.forEach(col => console.log(`  ➕ ${col}`));
    }

    // Check required columns for customer app
    console.log('\n🔑 PART 5: Required Columns Check');
    console.log('-'.repeat(80));
    
    const requiredColumns = [
      'id', 'product_name_en', 'product_name_ar', 'barcode',
      'sale_price', 'cost', 'profit', 'profit_percentage',
      'current_stock', 'minim_qty', 'minimum_qty_alert', 'maximum_qty',
      'category_id', 'category_name_en', 'category_name_ar',
      'unit_id', 'unit_name_en', 'unit_name_ar', 'unit_qty',
      'tax_category_id', 'tax_percentage',
      'image_url', 'is_active', 'product_serial'
    ];

    const missingRequired = requiredColumns.filter(col => !flyerColumns.includes(col));
    
    if (missingRequired.length === 0) {
      console.log('✅ All required columns exist in flyer_products');
    } else {
      console.log(`❌ Missing ${missingRequired.length} required columns:`);
      missingRequired.forEach(col => console.log(`  ❌ ${col}`));
    }

    // Summary
    console.log('\n📋 SUMMARY');
    console.log('='.repeat(80));
    console.log(`Products table columns:        ${productsColumnsArray.length}`);
    console.log(`Flyer_products table columns:  ${flyerColumns.length}`);
    console.log(`Missing in flyer_products:     ${missingInFlyer.length}`);
    console.log(`Extra in flyer_products:       ${extraInFlyer.length}`);
    console.log(`Missing required columns:      ${missingRequired.length}`);

    // Migration readiness
    console.log('\n🚦 MIGRATION READINESS');
    console.log('='.repeat(80));
    
    if (missingRequired.length === 0) {
      console.log('✅ READY FOR MIGRATION');
      console.log('   All required columns exist in flyer_products');
      console.log('   Safe to proceed with table rename');
    } else {
      console.log('❌ NOT READY FOR MIGRATION');
      console.log('   Run the column addition migration first:');
      console.log('   File: supabase/migrations/20241212_add_columns_to_flyer_products.sql');
    }

    console.log('\n' + '='.repeat(80));

  } catch (error) {
    console.error('❌ Validation failed:', error);
    process.exit(1);
  }
}

// Run validation
validateTableStructures();
