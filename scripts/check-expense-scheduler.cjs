const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create admin client with service role key (bypasses RLS)
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

async function checkExpenseSchedulerData() {
  console.log('🔍 Checking expense_scheduler table with SERVICE ROLE KEY...\n');

  try {
    // Query all data from expense_scheduler
    const { data, error, count } = await supabaseAdmin
      .from('expense_scheduler')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false });

    if (error) {
      console.error('❌ Error querying expense_scheduler:', error);
      return;
    }

    console.log('✅ Query successful!');
    console.log(`📊 Total records in expense_scheduler: ${count || data?.length || 0}\n`);

    if (data && data.length > 0) {
      console.log('📋 Sample records (first 5):');
      console.log('='.repeat(80));
      
      data.slice(0, 5).forEach((record, index) => {
        console.log(`\n${index + 1}. ID: ${record.id}`);
        console.log(`   Schedule Type: ${record.schedule_type || 'NOT SET'}`);
        console.log(`   Branch: ${record.branch_name}`);
        console.log(`   Category: ${record.expense_category_name_en || 'N/A'}`);
        console.log(`   Amount: ${record.amount}`);
        console.log(`   Due Date: ${record.due_date || 'NOT SET'}`);
        console.log(`   Is Paid: ${record.is_paid}`);
        console.log(`   Status: ${record.status}`);
        console.log(`   Created By: ${record.co_user_name}`);
        console.log(`   Created At: ${record.created_at}`);
      });

      console.log('\n' + '='.repeat(80));
      
      // Group by schedule_type
      const byScheduleType = {};
      data.forEach(record => {
        const type = record.schedule_type || 'NOT_SET';
        if (!byScheduleType[type]) {
          byScheduleType[type] = { count: 0, withDueDate: 0, withoutDueDate: 0 };
        }
        byScheduleType[type].count++;
        if (record.due_date) {
          byScheduleType[type].withDueDate++;
        } else {
          byScheduleType[type].withoutDueDate++;
        }
      });

      console.log('\n📊 Summary by Schedule Type:');
      console.log('='.repeat(80));
      Object.entries(byScheduleType).forEach(([type, stats]) => {
        console.log(`\n${type}:`);
        console.log(`  Total Records: ${stats.count}`);
        console.log(`  With Due Date: ${stats.withDueDate}`);
        console.log(`  Without Due Date: ${stats.withoutDueDate}`);
      });
      console.log('\n' + '='.repeat(80));
      
      // Group by month
      const byMonth = {};
      const recordsByMonth = {};
      data.forEach(record => {
        if (record.due_date) {
          const month = record.due_date.substring(0, 7); // YYYY-MM
          if (!byMonth[month]) {
            byMonth[month] = { count: 0, total: 0, paid: 0, unpaid: 0 };
            recordsByMonth[month] = [];
          }
          byMonth[month].count++;
          byMonth[month].total += parseFloat(record.amount || 0);
          if (record.is_paid) {
            byMonth[month].paid += parseFloat(record.amount || 0);
          } else {
            byMonth[month].unpaid += parseFloat(record.amount || 0);
          }
          recordsByMonth[month].push(record);
        }
      });

      console.log('\n📅 Summary by Month:');
      console.log('='.repeat(80));
      Object.entries(byMonth).forEach(([month, stats]) => {
        console.log(`\n${month}:`);
        console.log(`  Records: ${stats.count}`);
        console.log(`  Total: ${stats.total.toFixed(2)}`);
        console.log(`  Paid: ${stats.paid.toFixed(2)}`);
        console.log(`  Unpaid: ${stats.unpaid.toFixed(2)}`);
        
        // Show details of records in this month
        console.log(`\n  Details:`);
        recordsByMonth[month].forEach((rec, idx) => {
          console.log(`    ${idx + 1}. ID: ${rec.id}, Type: ${rec.schedule_type || 'N/A'}, Amount: ${rec.amount}, Due: ${rec.due_date}, Paid: ${rec.is_paid}`);
        });
      });
      console.log('\n' + '='.repeat(80));

    } else {
      console.log('⚠️  No records found in expense_scheduler table');
      console.log('💡 The table exists but is empty. You need to add data first.');
    }

  } catch (error) {
    console.error('❌ Exception:', error);
  }
}

// Run the check
checkExpenseSchedulerData()
  .then(() => {
    console.log('\n✅ Check complete!');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
  });
