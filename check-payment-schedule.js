// Check specific payment schedule record
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

const recordId = 'fa939cd4-f9d1-45e3-8f7b-e00ec4041f59';

console.log('\n🔍 Checking payment schedule record:', recordId);
console.log('='.repeat(80));

const { data, error } = await supabase
  .from('vendor_payment_schedule')
  .select('*')
  .eq('id', recordId)
  .single();

if (error) {
  console.error('❌ Error:', error);
} else {
  console.log('\n📋 Record Details:');
  console.log(JSON.stringify(data, null, 2));
  
  console.log('\n📅 Key Dates:');
  console.log('Schedule Date:', data.schedule_date);
  console.log('Created At:', data.created_at);
  console.log('Updated At:', data.updated_at);
  
  console.log('\n💰 Payment Details:');
  console.log('Amount:', data.amount);
  console.log('Payment Method:', data.payment_method);
  console.log('Status:', data.status);
  
  console.log('\n🔗 Related IDs:');
  console.log('Branch ID:', data.branch_id);
  console.log('Vendor ID:', data.vendor_id);
  console.log('Receiving Record ID:', data.receiving_record_id);
}

console.log('\n✅ Complete!\n');
