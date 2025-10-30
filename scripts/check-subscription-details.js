import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';
const deviceId = '1761826981752-db7bdaiua';

async function checkSubscription() {
  console.log('='.repeat(60));
  console.log(`Checking subscription for device: ${deviceId}`);
  console.log('='.repeat(60));
  
  const { data: sub, error } = await supabase
    .from('push_subscriptions')
    .select('*')
    .eq('device_id', deviceId)
    .single();
    
  if (error) {
    console.log('❌ Error:', error.message);
    return;
  }
  
  console.log('\n📱 Subscription record:');
  console.log(JSON.stringify(sub, null, 2));
  
  console.log('\n🔍 Analysis:');
  console.log(`User ID: ${sub.user_id}`);
  console.log(`Device ID: ${sub.device_id}`);
  console.log(`Created: ${sub.created_at}`);
  console.log(`\nSubscription object type: ${typeof sub.subscription}`);
  console.log(`Subscription is null: ${sub.subscription === null}`);
  console.log(`Subscription keys: ${sub.subscription ? Object.keys(sub.subscription).join(', ') : 'N/A'}`);
  
  if (sub.subscription) {
    console.log('\n📦 Subscription content:');
    console.log(JSON.stringify(sub.subscription, null, 2));
  } else {
    console.log('\n⚠️  PROBLEM: Subscription field is NULL or empty!');
    console.log('This means the push subscription was not properly saved.');
    console.log('The user needs to re-subscribe from their device.');
  }
}

checkSubscription().catch(console.error);
