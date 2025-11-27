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

const supabase = createClient(envVars.PUBLIC_SUPABASE_URL, envVars.SUPABASE_SERVICE_ROLE_KEY);

// Get today's date in Saudi timezone
const saudiOffset = 3 * 60;
const now = new Date();
const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
const today = saudiTime.toISOString().split('T')[0];

console.log(`\n📊 Checking Sales Data for ${today}\n`);

const { data, error } = await supabase
  .from('erp_daily_sales')
  .select('sale_date, branch_id, net_amount, net_bills, return_amount')
  .eq('sale_date', today)
  .order('branch_id');

if (error) {
  console.error('❌ Error:', error);
  process.exit(1);
}

if (data && data.length > 0) {
  console.log('Branch ID | Net Amount    | Net Bills | Return Amount');
  console.log('----------|---------------|-----------|---------------');
  data.forEach(row => {
    console.log(`    ${String(row.branch_id).padStart(2)}    | ${row.net_amount.toFixed(2).padStart(12)} | ${String(row.net_bills).padStart(9)} | ${row.return_amount.toFixed(2).padStart(12)}`);
  });
  
  const totalAmount = data.reduce((sum, d) => sum + (d.net_amount || 0), 0);
  const totalBills = data.reduce((sum, d) => sum + (d.net_bills || 0), 0);
  const totalReturn = data.reduce((sum, d) => sum + (d.return_amount || 0), 0);
  
  console.log('----------|---------------|-----------|---------------');
  console.log(`  TOTAL   | ${totalAmount.toFixed(2).padStart(12)} | ${String(totalBills).padStart(9)} | ${totalReturn.toFixed(2).padStart(12)}`);
  console.log('\n✅ This total should match what the Daily Sales Overview shows for today');
} else {
  console.log('⚠️ No data found for today');
}

process.exit(0);
