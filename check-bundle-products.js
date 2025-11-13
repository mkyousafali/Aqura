// Check bundle products and their prices
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
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
  console.log('🔍 Checking bundle products and pricing...\n');

  // Get bundle
  const { data: bundle } = await supabase
    .from('offer_bundles')
    .select('*')
    .eq('id', 11)
    .single();

  console.log('📦 Bundle:', bundle);
  console.log('\n📊 Required Products:');
  
  let totalOriginal = 0;
  
  for (const item of bundle.required_products) {
    const { data: product } = await supabase
      .from('products')
      .select('id, product_name_en, sale_price')
      .eq('id', item.product_id)
      .single();
    
    const itemTotal = product.sale_price * item.quantity;
    totalOriginal += itemTotal;
    
    console.log(`  - ${product.product_name_en}`);
    console.log(`    Price: ${product.sale_price} SAR × ${item.quantity} = ${itemTotal} SAR`);
    console.log(`    Discount: ${item.discount_type} ${item.discount_value}${item.discount_type === 'percentage' ? '%' : ' SAR'}`);
  }
  
  console.log('\n💰 Pricing Calculation:');
  console.log(`  Total Original: ${totalOriginal} SAR`);
  console.log(`  Bundle Discount Type: ${bundle.discount_type}`);
  console.log(`  Bundle Discount Value: ${bundle.discount_value} SAR`);
  
  let bundlePrice;
  if (bundle.discount_type === 'amount') {
    bundlePrice = totalOriginal - bundle.discount_value;
  } else if (bundle.discount_type === 'percentage') {
    bundlePrice = totalOriginal * (1 - bundle.discount_value / 100);
  }
  
  console.log(`  Final Bundle Price: ${bundlePrice} SAR`);
  console.log(`  You Save: ${totalOriginal - bundlePrice} SAR`);
  console.log(`  Discount Percentage: ${Math.round(((totalOriginal - bundlePrice) / totalOriginal) * 100)}%`);
}

checkBundleProducts().catch(console.error);
