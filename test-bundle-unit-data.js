// Test what unit data is available in bundle products
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testBundleUnitData() {
  console.log('🔍 Testing bundle product unit data...\n');

  // Get bundle
  const { data: bundle } = await supabase
    .from('offer_bundles')
    .select('*')
    .eq('id', 11)
    .single();

  console.log('📦 Bundle required_products:', bundle.required_products);

  // Get products
  const productIds = bundle.required_products.map(item => item.product_id);
  const { data: products } = await supabase
    .from('products')
    .select('*')
    .in('id', productIds);

  console.log('\n📊 Product Details:\n');
  products.forEach(product => {
    console.log(`Product: ${product.product_name_en}`);
    console.log(`  ID: ${product.id}`);
    console.log(`  Price: ${product.sale_price}`);
    console.log(`  Unit Name EN: ${product.unit_name_en || 'NOT SET'}`);
    console.log(`  Unit Name AR: ${product.unit_name_ar || 'NOT SET'}`);
    console.log(`  Unit Qty: ${product.unit_qty || 'NOT SET'}`);
    console.log(`  Category: ${product.category_name_en || 'NOT SET'}`);
    console.log('');
  });

  // Create items_with_details like the API does
  const items_with_details = bundle.required_products.map(item => {
    const product = products.find(p => p.id === item.product_id);
    return {
      ...item,
      product
    };
  });

  console.log('✅ Items with details structure:');
  items_with_details.forEach((item, index) => {
    console.log(`\nItem ${index + 1}:`);
    console.log(`  Quantity: ${item.quantity}`);
    console.log(`  Discount: ${item.discount_type} ${item.discount_value}`);
    console.log(`  Product Name: ${item.product?.product_name_en}`);
    console.log(`  Unit Name: ${item.product?.unit_name_en || 'MISSING'}`);
    console.log(`  Unit Qty: ${item.product?.unit_qty || 'MISSING'}`);
  });
}

testBundleUnitData().catch(console.error);
