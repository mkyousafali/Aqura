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

(async () => {
  console.log('Checking ALL offers in database...\n');
  
  // First check total count
  const { data: allOffers, error: allError, count } = await supabase
    .from('offers')
    .select('id, type, discount_type, name_ar, name_en', { count: 'exact' });
  
  console.log(`📊 Total offers in database: ${count}\n`);
  
  if (allOffers && allOffers.length > 0) {
    console.log('Offer breakdown by type:');
    const byType = {};
    allOffers.forEach(o => {
      byType[o.type] = (byType[o.type] || 0) + 1;
    });
    Object.keys(byType).forEach(type => {
      console.log(`  - ${type}: ${byType[type]} offers`);
    });
    console.log('');
  }
  
  // Now check product offers specifically
  const { data, error } = await supabase
    .from('offers')
    .select('*, offer_products(*)')
    .eq('type', 'product')
    .order('created_at', { ascending: false });
  
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  console.log(`Found ${data.length} product discount offers\n`);
  
  data.forEach(offer => {
    console.log(`========================================`);
    console.log(`Offer ID: ${offer.id}`);
    console.log(`Name (AR): ${offer.name_ar}`);
    console.log(`Name (EN): ${offer.name_en}`);
    console.log(`Type: ${offer.type}`);
    console.log(`Discount Type: ${offer.discount_type}`);
    console.log(`Active: ${offer.is_active}`);
    console.log(`Start Date: ${offer.start_date}`);
    console.log(`End Date: ${offer.end_date}`);
    console.log(`Created: ${offer.created_at}`);
    console.log(`Updated: ${offer.updated_at}`);
    console.log(`Products Count: ${offer.offer_products?.length || 0}`);
    
    if (offer.offer_products && offer.offer_products.length > 0) {
      console.log(`Products:`);
      offer.offer_products.forEach((p, idx) => {
        console.log(`  ${idx + 1}. Product ID: ${p.product_id}`);
        console.log(`     Quantity: ${p.offer_qty}`);
        console.log(`     Percentage: ${p.offer_percentage}%`);
        console.log(`     Offer Price: ${p.offer_price} SAR`);
        console.log(`     Max Uses: ${p.max_uses || 'unlimited'}`);
      });
    }
    console.log('');
  });
})();
