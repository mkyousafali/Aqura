const { createClient } = require('@supabase/supabase-js');

// Use the actual Supabase credentials
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  console.log('\n🔍 Checking Flyer Master Database Tables...\n');

  // Check flyer_products table
  console.log('📦 Checking flyer_products table...');
  const { data: products, error: pError, count: pCount } = await supabase
    .from('flyer_products')
    .select('*', { count: 'exact', head: true });
  
  if (pError) {
    console.log('   ❌ flyer_products: ' + pError.message);
  } else {
    console.log('   ✅ flyer_products table exists');
    console.log(`   📊 Total records: ${pCount || 0}`);
  }

  // Check flyer_offers table
  console.log('\n🎁 Checking flyer_offers table...');
  const { data: offers, error: oError, count: oCount } = await supabase
    .from('flyer_offers')
    .select('*', { count: 'exact', head: true });
  
  if (oError) {
    console.log('   ❌ flyer_offers: ' + oError.message);
  } else {
    console.log('   ✅ flyer_offers table exists');
    console.log(`   📊 Total records: ${oCount || 0}`);
  }

  // Check flyer_offer_products table
  console.log('\n🔗 Checking flyer_offer_products table...');
  const { data: offerProds, error: opError, count: opCount } = await supabase
    .from('flyer_offer_products')
    .select('*', { count: 'exact', head: true });
  
  if (opError) {
    console.log('   ❌ flyer_offer_products: ' + opError.message);
  } else {
    console.log('   ✅ flyer_offer_products table exists');
    console.log(`   📊 Total records: ${opCount || 0}`);
  }

  // Check storage bucket
  console.log('\n🪣 Checking storage bucket...');
  const { data: buckets, error: bError } = await supabase.storage.listBuckets();
  
  if (bError) {
    console.log('   ❌ Storage buckets error: ' + bError.message);
  } else {
    const flyerBucket = buckets.find(b => b.id === 'flyer-product-images');
    if (flyerBucket) {
      console.log('   ✅ flyer-product-images bucket exists');
      console.log(`   📊 Bucket details:`, {
        public: flyerBucket.public,
        file_size_limit: flyerBucket.file_size_limit,
        allowed_mime_types: flyerBucket.allowed_mime_types
      });
    } else {
      console.log('   ❌ flyer-product-images bucket NOT found');
      console.log('   💡 You need to create it manually in Supabase Dashboard');
    }
  }

  console.log('\n✅ Verification Complete!\n');
})();
