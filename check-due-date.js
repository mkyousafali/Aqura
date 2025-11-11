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

console.log('\n🔍 Checking due_date vs scheduled_date for December 2025 payments...\n');

// Get December 2025 payments by scheduled_date
const { data: byScheduledDate, error: error1 } = await supabase
  .from('vendor_payment_schedule')
  .select('id, vendor_name, bill_number, due_date, scheduled_date, final_bill_amount')
  .gte('scheduled_date', '2025-12-01')
  .lt('scheduled_date', '2026-01-01')
  .order('scheduled_date');

console.log(`📅 Payments with scheduled_date in December 2025: ${byScheduledDate?.length || 0}`);

// Get December 2025 payments by due_date
const { data: byDueDate, error: error2 } = await supabase
  .from('vendor_payment_schedule')
  .select('id, vendor_name, bill_number, due_date, scheduled_date, final_bill_amount')
  .gte('due_date', '2025-12-01')
  .lt('due_date', '2026-01-01')
  .order('due_date');

console.log(`📅 Payments with due_date in December 2025: ${byDueDate?.length || 0}\n`);

// Check specific payment
const { data: specificPayment } = await supabase
  .from('vendor_payment_schedule')
  .select('*')
  .eq('id', 'fa939cd4-f9d1-45e3-8f7b-e00ec4041f59')
  .single();

if (specificPayment) {
  console.log('🎯 Target Payment (fa939cd4-f9d1-45e3-8f7b-e00ec4041f59):');
  console.log('   Vendor:', specificPayment.vendor_name);
  console.log('   Bill:', specificPayment.bill_number);
  console.log('   due_date:', specificPayment.due_date);
  console.log('   scheduled_date:', specificPayment.scheduled_date);
  console.log('   Amount:', specificPayment.final_bill_amount);
  
  const dueDate = new Date(specificPayment.due_date);
  const scheduledDate = new Date(specificPayment.scheduled_date);
  
  console.log('\n   Parsed due_date:');
  console.log('     Month:', dueDate.getMonth(), '(0-indexed, 11=December)');
  console.log('     Date:', dueDate.getDate());
  console.log('     Year:', dueDate.getFullYear());
  console.log('     Is December 10?', dueDate.getMonth() === 11 && dueDate.getDate() === 10);
  
  console.log('\n   Parsed scheduled_date:');
  console.log('     Month:', scheduledDate.getMonth(), '(0-indexed, 11=December)');
  console.log('     Date:', scheduledDate.getDate());
  console.log('     Year:', scheduledDate.getFullYear());
  console.log('     Is December 10?', scheduledDate.getMonth() === 11 && scheduledDate.getDate() === 10);
}

// Show sample of December 10 payments by due_date
const { data: dec10ByDue } = await supabase
  .from('vendor_payment_schedule')
  .select('vendor_name, bill_number, due_date, scheduled_date, final_bill_amount')
  .gte('due_date', '2025-12-10')
  .lt('due_date', '2025-12-11')
  .limit(5);

console.log(`\n📊 Sample December 10 payments by due_date (first 5 of ${dec10ByDue?.length || 0}):`);
dec10ByDue?.forEach(p => {
  console.log(`   ${p.vendor_name} - ${p.bill_number} - ${p.final_bill_amount} SAR`);
  console.log(`     due_date: ${p.due_date}`);
  console.log(`     scheduled_date: ${p.scheduled_date}`);
});

// Show sample of December 10 payments by scheduled_date
const { data: dec10ByScheduled } = await supabase
  .from('vendor_payment_schedule')
  .select('vendor_name, bill_number, due_date, scheduled_date, final_bill_amount')
  .gte('scheduled_date', '2025-12-10')
  .lt('scheduled_date', '2025-12-11')
  .limit(5);

console.log(`\n📊 Sample December 10 payments by scheduled_date (first 5 of ${dec10ByScheduled?.length || 0}):`);
dec10ByScheduled?.forEach(p => {
  console.log(`   ${p.vendor_name} - ${p.bill_number} - ${p.final_bill_amount} SAR`);
  console.log(`     due_date: ${p.due_date}`);
  console.log(`     scheduled_date: ${p.scheduled_date}`);
});
