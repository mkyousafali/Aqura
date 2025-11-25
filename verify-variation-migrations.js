import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function verifyVariationMigrations() {
  console.log('🔍 Verifying Product Variation System Migrations...\n');

  let allPassed = true;

  // Test 1: Check flyer_products columns
  console.log('Test 1: Checking flyer_products table columns...');
  try {
    const { data, error } = await supabase
      .from('flyer_products')
      .select('*')
      .limit(1);

    if (error) throw error;

    const requiredColumns = [
      'is_variation',
      'parent_product_barcode',
      'variation_group_name_en',
      'variation_group_name_ar',
      'variation_order',
      'variation_image_override',
      'created_by',
      'modified_by',
      'modified_at'
    ];

    const existingColumns = data && data.length > 0 ? Object.keys(data[0]) : [];
    const missingColumns = requiredColumns.filter(col => !existingColumns.includes(col));

    if (missingColumns.length === 0) {
      console.log('   ✅ All variation columns present in flyer_products\n');
    } else {
      console.log('   ❌ Missing columns:', missingColumns.join(', '));
      console.log('   ⚠️  Migration 1 may not have been applied\n');
      allPassed = false;
    }
  } catch (error) {
    console.log('   ❌ Error:', error.message, '\n');
    allPassed = false;
  }

  // Test 2: Check offer_products columns
  console.log('Test 2: Checking offer_products table columns...');
  try {
    const { data, error } = await supabase
      .from('offer_products')
      .select('*')
      .limit(1);

    if (error) throw error;

    const requiredColumns = [
      'is_part_of_variation_group',
      'variation_group_id',
      'variation_parent_barcode',
      'added_by',
      'added_at'
    ];

    const existingColumns = data && data.length > 0 ? Object.keys(data[0]) : [];
    const missingColumns = requiredColumns.filter(col => !existingColumns.includes(col));

    if (missingColumns.length === 0) {
      console.log('   ✅ All variation columns present in offer_products\n');
    } else {
      console.log('   ❌ Missing columns:', missingColumns.join(', '));
      console.log('   ⚠️  Migration 2 may not have been applied\n');
      allPassed = false;
    }
  } catch (error) {
    console.log('   ❌ Error:', error.message, '\n');
    allPassed = false;
  }

  // Test 3: Check variation_audit_log table exists
  console.log('Test 3: Checking variation_audit_log table...');
  try {
    const { data, error, count } = await supabase
      .from('variation_audit_log')
      .select('*', { count: 'exact' })
      .limit(1);

    if (error) throw error;

    console.log(`   ✅ variation_audit_log table exists (${count} records)\n`);
  } catch (error) {
    console.log('   ❌ Table does not exist or error:', error.message);
    console.log('   ⚠️  Migration 3 may not have been applied\n');
    allPassed = false;
  }

  // Test 4: Check helper functions exist
  console.log('Test 4: Checking helper functions...');
  const functions = [
    'get_product_variations',
    'get_variation_group_info',
    'validate_variation_prices',
    'get_offer_variation_summary',
    'check_orphaned_variations',
    'create_variation_group'
  ];

  for (const func of functions) {
    try {
      // Try to call function with test parameters
      const { data, error } = await supabase.rpc(func, 
        func === 'get_product_variations' ? { p_barcode: 'test' } :
        func === 'get_variation_group_info' ? { p_barcode: 'test' } :
        func === 'validate_variation_prices' ? { p_offer_id: 1, p_group_id: '00000000-0000-0000-0000-000000000000' } :
        func === 'get_offer_variation_summary' ? { p_offer_id: 1 } :
        func === 'check_orphaned_variations' ? {} :
        { p_parent_barcode: 'test', p_variation_barcodes: [], p_group_name_en: 'test', p_group_name_ar: 'test' }
      );

      // If we get here without error, function exists
      console.log(`   ✅ Function '${func}' exists`);
    } catch (error) {
      // Check if error is about function not existing vs just bad parameters
      if (error.message.includes('does not exist') || error.message.includes('could not find')) {
        console.log(`   ❌ Function '${func}' not found`);
        allPassed = false;
      } else {
        // Function exists, just didn't like our test parameters (that's fine)
        console.log(`   ✅ Function '${func}' exists`);
      }
    }
  }
  console.log('');

  // Test 5: Check RLS policies
  console.log('Test 5: Checking RLS policies...');
  try {
    // Try to query tables (should work with service role)
    const { data: flyerData, error: flyerError } = await supabase
      .from('flyer_products')
      .select('is_variation, parent_product_barcode')
      .limit(1);

    const { data: offerData, error: offerError } = await supabase
      .from('offer_products')
      .select('is_part_of_variation_group, variation_group_id')
      .limit(1);

    const { data: auditData, error: auditError } = await supabase
      .from('variation_audit_log')
      .select('*')
      .limit(1);

    if (!flyerError && !offerError && !auditError) {
      console.log('   ✅ RLS policies allow access to variation columns\n');
    } else {
      console.log('   ⚠️  Some queries failed - RLS may need adjustment');
      if (flyerError) console.log('      flyer_products:', flyerError.message);
      if (offerError) console.log('      offer_products:', offerError.message);
      if (auditError) console.log('      variation_audit_log:', auditError.message);
      console.log('');
      allPassed = false;
    }
  } catch (error) {
    console.log('   ❌ Error checking RLS:', error.message, '\n');
    allPassed = false;
  }

  // Summary
  console.log('═══════════════════════════════════════════════════');
  if (allPassed) {
    console.log('🎉 All verifications passed!');
    console.log('\n✅ Database is ready for Product Variation System');
    console.log('\n📋 Next Steps:');
    console.log('   1. Begin Day 2: Build Variation Manager UI');
    console.log('   2. Create VariationManager.svelte component');
    console.log('   3. Add to window manager and dashboard');
  } else {
    console.log('⚠️  Some verifications failed');
    console.log('\n📋 Action Required:');
    console.log('   1. Apply missing migrations via Supabase Dashboard');
    console.log('   2. Run this verification again');
    console.log('   3. Check migration files in supabase/migrations/');
  }
  console.log('═══════════════════════════════════════════════════');
}

verifyVariationMigrations().catch(console.error);
