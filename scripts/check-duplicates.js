import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';

async function checkDuplicates() {
  console.log('='.repeat(60));
  console.log('CHECKING DUPLICATE SUBSCRIPTIONS');
  console.log('='.repeat(60));
  
  const { data: subs, error } = await supabase
    .from('push_subscriptions')
    .select('*')
    .eq('user_id', userId);
    
  if (error) {
    console.log('❌ Error:', error.message);
    return;
  }
  
  console.log(`\nFound ${subs.length} push subscription(s) for user:\n`);
  
  subs.forEach((sub, i) => {
    console.log(`--- Subscription ${i + 1} ---`);
    console.log(`ID: ${sub.id}`);
    console.log(`Device ID: ${sub.device_id}`);
    console.log(`Endpoint: ${sub.endpoint?.substring(0, 50)}...`);
    console.log(`Active: ${sub.is_active}`);
    console.log(`Created: ${sub.created_at}`);
    console.log(`Last Seen: ${sub.last_seen}`);
    console.log('');
  });
  
  // Check if they're duplicates
  const uniqueEndpoints = new Set(subs.map(s => s.endpoint));
  const uniqueDeviceIds = new Set(subs.map(s => s.device_id));
  
  console.log('📊 Analysis:');
  console.log(`Total subscriptions: ${subs.length}`);
  console.log(`Unique endpoints: ${uniqueEndpoints.size}`);
  console.log(`Unique device IDs: ${uniqueDeviceIds.size}`);
  
  if (subs.length > uniqueEndpoints.size) {
    console.log('\n⚠️  DUPLICATE SUBSCRIPTIONS FOUND!');
    console.log('Multiple subscriptions with same endpoint exist.');
    console.log('This causes multiple push notifications to be sent.');
    
    // Find duplicates
    const endpointCount = {};
    subs.forEach(sub => {
      if (!endpointCount[sub.endpoint]) {
        endpointCount[sub.endpoint] = [];
      }
      endpointCount[sub.endpoint].push(sub.id);
    });
    
    console.log('\n🔍 Duplicate groups:');
    Object.entries(endpointCount).forEach(([endpoint, ids]) => {
      if (ids.length > 1) {
        console.log(`\nEndpoint: ${endpoint.substring(0, 50)}...`);
        console.log(`Subscription IDs: ${ids.join(', ')}`);
        console.log(`Count: ${ids.length} (should be 1)`);
      }
    });
    
    // Suggest cleanup
    console.log('\n💡 Solution: Clean up old subscriptions');
    console.log('Keep only the most recent one for each device.');
  } else {
    console.log('\n✅ No duplicates found!');
  }
}

checkDuplicates().catch(console.error);
