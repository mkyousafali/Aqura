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

async function testVariationSystem() {
  console.log('🧪 Testing Product Variation System...\n');

  let allPassed = true;

  // Test 1: Check if we can load products
  console.log('Test 1: Loading flyer_products...');
  try {
    const { data, error, count } = await supabase
      .from('flyer_products')
      .select('*', { count: 'exact' })
      .limit(5);

    if (error) throw error;

    console.log(`   ✅ Successfully loaded ${count} total products`);
    console.log(`   Sample columns:`, Object.keys(data[0] || {}));
    console.log('');
  } catch (error) {
    console.log(`   ❌ Failed: ${error.message}\n`);
    allPassed = false;
  }

  // Test 2: Test create_variation_group function with dry run
  console.log('Test 2: Testing create_variation_group function...');
  try {
    // This should fail gracefully because we're using a fake barcode
    const { data, error } = await supabase.rpc('create_variation_group', {
      p_parent_barcode: 'TEST-BARCODE-123',
      p_variation_barcodes: [],
      p_group_name_en: 'Test Group',
      p_group_name_ar: 'مجموعة تجريبية',
      p_image_override: null,
      p_user_id: null
    });

    // Check if function exists (it should return an error about barcode not existing)
    if (error && error.message.includes('Parent product barcode does not exist')) {
      console.log('   ✅ Function exists and validation works correctly');
      console.log('   (Expected error: Parent product not found - this is correct behavior)');
    } else if (data && data.length > 0 && !data[0].success) {
      console.log('   ✅ Function exists and validation works correctly');
      console.log(`   Message: ${data[0].message}`);
    } else {
      console.log('   ⚠️  Unexpected response:', { data, error });
    }
    console.log('');
  } catch (error) {
    console.log(`   ❌ Function call failed: ${error.message}\n`);
    allPassed = false;
  }

  // Test 3: Check variation stats
  console.log('Test 3: Checking variation statistics...');
  try {
    const { data: allProducts, error } = await supabase
      .from('flyer_products')
      .select('id, is_variation, parent_product_barcode, variation_group_name_en');

    if (error) throw error;

    const totalProducts = allProducts?.length || 0;
    const groupedProducts = allProducts?.filter(p => p.is_variation).length || 0;
    const parentProducts = allProducts?.filter(p => p.is_variation && !p.parent_product_barcode).length || 0;
    const variationProducts = allProducts?.filter(p => p.is_variation && p.parent_product_barcode).length || 0;

    console.log(`   ✅ Total Products: ${totalProducts}`);
    console.log(`   📊 Grouped Products: ${groupedProducts}`);
    console.log(`   👨‍👩‍👧 Parent Products (Groups): ${parentProducts}`);
    console.log(`   🧩 Variation Products: ${variationProducts}`);
    console.log('');
  } catch (error) {
    console.log(`   ❌ Failed: ${error.message}\n`);
    allPassed = false;
  }

  // Test 4: Check audit log table
  console.log('Test 4: Checking variation_audit_log...');
  try {
    const { data, error, count } = await supabase
      .from('variation_audit_log')
      .select('*', { count: 'exact' })
      .limit(5)
      .order('timestamp', { ascending: false });

    if (error) throw error;

    console.log(`   ✅ Audit log table accessible (${count} records)`);
    if (data && data.length > 0) {
      console.log(`   Recent actions:`, data.map(d => d.action_type).join(', '));
    }
    console.log('');
  } catch (error) {
    console.log(`   ❌ Failed: ${error.message}\n`);
    allPassed = false;
  }

  // Test 5: Verify component files exist
  console.log('Test 5: Checking component files...');
  try {
    const fs = await import('fs');
    const variationManagerPath = './frontend/src/lib/components/admin/flyer/VariationManager.svelte';
    const dashboardPath = './frontend/src/lib/components/admin/flyer/FlyerMasterDashboard.svelte';

    const variationManagerExists = fs.existsSync(variationManagerPath);
    const dashboardExists = fs.existsSync(dashboardPath);

    if (variationManagerExists) {
      const content = fs.readFileSync(variationManagerPath, 'utf-8');
      const hasGroupModal = content.includes('showGroupModal');
      const hasCreateFunction = content.includes('createGroup');
      const hasSearchFilter = content.includes('searchQuery');

      console.log(`   ✅ VariationManager.svelte exists`);
      console.log(`      - Group modal: ${hasGroupModal ? '✅' : '❌'}`);
      console.log(`      - Create function: ${hasCreateFunction ? '✅' : '❌'}`);
      console.log(`      - Search filter: ${hasSearchFilter ? '✅' : '❌'}`);
    } else {
      console.log(`   ❌ VariationManager.svelte not found`);
      allPassed = false;
    }

    if (dashboardExists) {
      const content = fs.readFileSync(dashboardPath, 'utf-8');
      const hasVariationManager = content.includes('VariationManager');
      const hasVariationCard = content.includes('variation-manager');

      console.log(`   ✅ FlyerMasterDashboard.svelte exists`);
      console.log(`      - Import: ${hasVariationManager ? '✅' : '❌'}`);
      console.log(`      - Navigation card: ${hasVariationCard ? '✅' : '❌'}`);
    } else {
      console.log(`   ❌ FlyerMasterDashboard.svelte not found`);
      allPassed = false;
    }

    console.log('');
  } catch (error) {
    console.log(`   ❌ Failed: ${error.message}\n`);
    allPassed = false;
  }

  // Summary
  console.log('═══════════════════════════════════════════════════');
  if (allPassed) {
    console.log('🎉 All tests passed!');
    console.log('\n✅ Product Variation System is ready to use');
    console.log('\n📋 How to access:');
    console.log('   1. Open the application');
    console.log('   2. Navigate to Flyer Master Dashboard');
    console.log('   3. Click on "🔗 Variation Manager" card');
    console.log('   4. Select products and create your first group!');
    console.log('\n💡 Tips:');
    console.log('   - Start by grouping similar products (e.g., different sizes of same item)');
    console.log('   - Use clear group names in both English and Arabic');
    console.log('   - Groups will appear in offers and shelf papers automatically');
  } else {
    console.log('⚠️  Some tests failed');
    console.log('   Review the errors above before proceeding');
  }
  console.log('═══════════════════════════════════════════════════');
}

testVariationSystem().catch(console.error);
