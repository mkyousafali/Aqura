// Check December 2025 payments
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

console.log('\n🔍 Checking December 2025 payments...\n');

const { data: payments, error } = await supabase
  .from('vendor_payment_schedule')
  .select('id, vendor_name, bill_amount, final_bill_amount, due_date, scheduled_date, created_at')
  .gte('scheduled_date', '2025-12-01')
  .lte('scheduled_date', '2025-12-31')
  .order('scheduled_date', { ascending: true });

if (error) {
  console.error('❌ Error:', error);
} else {
  console.log(`✅ Found ${payments.length} payments in December 2025\n`);
  console.log('='.repeat(120));
  
  payments.forEach(p => {
    const schedDate = new Date(p.scheduled_date);
    console.log(`\n📅 ID: ${p.id}`);
    console.log(`   Vendor: ${p.vendor_name}`);
    console.log(`   Amount: ${p.final_bill_amount || p.bill_amount}`);
    console.log(`   Due Date: ${p.due_date}`);
    console.log(`   Scheduled Date: ${p.scheduled_date} (Day ${schedDate.getDate()})`);
  });
  
  console.log('\n' + '='.repeat(120));
  
  // Check our specific payment
  const targetPayment = payments.find(p => p.id === 'fa939cd4-f9d1-45e3-8f7b-e00ec4041f59');
  if (targetPayment) {
    console.log('\n✅ Found target payment fa939cd4-f9d1-45e3-8f7b-e00ec4041f59');
    console.log('   Scheduled Date:', targetPayment.scheduled_date);
    console.log('   Due Date:', targetPayment.due_date);
  } else {
    console.log('\n❌ Target payment NOT found in December 2025 range');
  }
}

console.log('\n✅ Complete!\n');
