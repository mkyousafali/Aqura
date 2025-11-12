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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkBundleProducts() {
  console.log('🔍 Checking Bundle Products and All Products...\n');
  
  // 1. Get bundle products
  const { data: bundleData, error: bundleError } = await supabase
    .from('offer_bundles')
    .select('required_products, offer_id, bundle_name_en');
  
  if (bundleError) {
    console.error('❌ Error fetching bundles:', bundleError);
    return;
  }
  
  console.log('📦 Bundle Products:');
  bundleData?.forEach(bundle => {
    console.log(`\nBundle: ${bundle.bundle_name_en} (Offer ID: ${bundle.offer_id})`);
    if (Array.isArray(bundle.required_products)) {
      bundle.required_products.forEach(item => {
        console.log(`  - Product ID: ${item.product_id}`);
      });
    }
  });
  
  // 2. Get Butter Croissant products
  const { data: products, error: productError } = await supabase
    .from('products')
    .select('id, product_name_en, barcode')
    .ilike('product_name_en', '%Butter Croissant%');
  
  if (productError) {
    console.error('❌ Error fetching products:', productError);
    return;
  }
  
  console.log('\n\n🥐 Butter Croissant Products:');
  products?.forEach(p => {
    console.log(`  - Product ID: ${p.id}`);
    console.log(`    Name: ${p.product_name_en}`);
    console.log(`    Barcode: ${p.barcode}`);
  });
  
  // 3. Check if they match
  console.log('\n\n🔍 Matching Check:');
  const bundleProductIds = new Set();
  bundleData?.forEach(bundle => {
    if (Array.isArray(bundle.required_products)) {
      bundle.required_products.forEach(item => {
        bundleProductIds.add(item.product_id);
      });
    }
  });
  
  products?.forEach(p => {
    const isInBundle = bundleProductIds.has(p.id);
    console.log(`  ${p.product_name_en} (${p.barcode}): ${isInBundle ? '✅ IN BUNDLE' : '❌ NOT IN BUNDLE'}`);
  });
}

checkBundleProducts();
