import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkDataCount() {
  console.log('Checking hr_fingerprint_transactions data...\n');

  const { data, error, count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact', head: false })
    .limit(10);

  if (error) {
    console.error('❌ Error:', error);
    return;
  }

  console.log(`📊 Total records in table: ${count}`);
  
  if (count > 0) {
    console.log('\n✅ Sample records:');
    data.forEach((r, i) => {
      console.log(`${i + 1}. ${r.employee_id} - ${r.date} ${r.time} - ${r.status} - Branch: ${r.branch_id}`);
    });

    // Check date range
    console.log('\n📅 Checking date range...');
    const { data: dateRange } = await supabase
      .from('hr_fingerprint_transactions')
      .select('date')
      .order('date', { ascending: true })
      .limit(1);

    const { data: dateRangeMax } = await supabase
      .from('hr_fingerprint_transactions')
      .select('date')
      .order('date', { ascending: false })
      .limit(1);

    if (dateRange && dateRange.length > 0) {
      console.log(`Oldest: ${dateRange[0].date}`);
    }
    if (dateRangeMax && dateRangeMax.length > 0) {
      console.log(`Newest: ${dateRangeMax[0].date}`);
    }

    // Check branch distribution
    console.log('\n🏢 Records per branch:');
    const { data: branches } = await supabase
      .from('hr_fingerprint_transactions')
      .select('branch_id')
      .order('branch_id');

    if (branches) {
      const branchCounts = branches.reduce((acc, r) => {
        acc[r.branch_id] = (acc[r.branch_id] || 0) + 1;
        return acc;
      }, {});
      
      Object.entries(branchCounts).forEach(([branch, count]) => {
        console.log(`Branch ${branch}: ${count} records`);
      });
    }
  } else {
    console.log('\n❌ Table is EMPTY - No data was inserted!');
  }
}

checkDataCount();
