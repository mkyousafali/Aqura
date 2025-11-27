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

// Use same timezone logic as SalesReport.svelte
const saudiOffset = 3 * 60;
const now = new Date();
const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);

const today = new Date(saudiTime.getFullYear(), saudiTime.getMonth(), saudiTime.getDate());
const yesterday = new Date(today);
yesterday.setDate(yesterday.getDate() - 1);
const dayBeforeYesterday = new Date(today);
dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);

const dates = [
  dayBeforeYesterday.toISOString().split('T')[0],
  yesterday.toISOString().split('T')[0],
  today.toISOString().split('T')[0]
];

console.log('\n🔍 Debugging Sales Report Query');
console.log('================================');
console.log('Dates being queried:', dates);
console.log('');

// Execute the EXACT same query as SalesReport.svelte
const { data, error } = await supabase
  .from('erp_daily_sales')
  .select('sale_date, net_amount, net_bills, return_amount')
  .in('sale_date', dates)
  .order('sale_date', { ascending: true });

if (error) {
  console.error('❌ Error:', error);
  process.exit(1);
}

console.log(`📦 Raw data returned (${data?.length || 0} rows):\n`);
console.table(data);

// Group by date and sum amounts (same as SalesReport.svelte)
console.log('\n📊 Grouped by Date (as displayed in component):\n');
const groupedData = dates.map(date => {
  const dayData = data?.filter(d => d.sale_date === date) || [];
  const total_amount = dayData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
  const total_bills = dayData.reduce((sum, d) => sum + (d.net_bills || 0), 0);
  const total_return = dayData.reduce((sum, d) => sum + (d.return_amount || 0), 0);
  
  console.log(`${date}:`);
  console.log(`  Rows found: ${dayData.length}`);
  console.log(`  Total Amount: ${total_amount.toFixed(2)}`);
  console.log(`  Total Bills: ${total_bills}`);
  console.log(`  Total Return: ${total_return.toFixed(2)}`);
  console.log('');
  
  return { date, total_amount, total_bills, total_return };
});

console.log('\n✅ Summary:');
console.table(groupedData);

process.exit(0);
