import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkAndTest() {
  console.log('🔍 Checking receiving records...\n');

  // Check ALL receiving records
  const { data: allRecords, error: allError } = await supabase
    .from('receiving_records')
    .select('id, bill_number, certificate_url, certificate_generated_at, vendor_id, branch_id')
    .order('created_at', { ascending: false })
    .limit(5);

  if (allError) {
    console.error('❌ Error:', allError.message);
    return;
  }

  console.log(`Found ${allRecords?.length || 0} recent receiving records:\n`);
  
  allRecords?.forEach((rec, idx) => {
    console.log(`${idx + 1}. Bill: ${rec.bill_number}`);
    console.log(`   ID: ${rec.id}`);
    console.log(`   Certificate: ${rec.certificate_url || 'NONE'}`);
    console.log(`   Generated: ${rec.certificate_generated_at || 'NONE'}\n`);
  });

  // Pick first record for testing
  if (allRecords && allRecords.length > 0) {
    const testRecord = allRecords[0];
    console.log(`\n📋 Testing with: ${testRecord.bill_number}\n`);

    // Test the function
    const { data: result, error: funcError } = await supabase.rpc(
      'process_clearance_certificate_generation',
      {
        receiving_record_id_param: testRecord.id,
        clearance_certificate_url_param: 'https://test.pdf',
        generated_by_user_id: '00000000-0000-0000-0000-000000000000',
        generated_by_name: 'Test User',
        generated_by_role: 'admin'
      }
    );

    if (funcError) {
      console.error('❌ Function error:', funcError.message);
      console.error('Details:', funcError);
    } else {
      console.log('✅ Function result:\n');
      console.log(JSON.stringify(result, null, 2));

      // Check created tasks
      if (result && result.success) {
        console.log('\n📋 Checking created tasks...\n');
        
        const { data: tasks, error: tasksError } = await supabase
          .from('receiving_tasks')
          .select('*')
          .eq('receiving_record_id', testRecord.id);

        if (tasks) {
          console.log(`✅ Created ${tasks.length} tasks:\n`);
          tasks.forEach((t, idx) => {
            console.log(`${idx + 1}. [${t.role_type}] ${t.title}`);
            console.log(`   Status: ${t.task_status}`);
            console.log(`   Priority: ${t.priority}`);
            console.log(`   Assigned: ${t.assigned_user_id || 'NONE'}\n`);
          });
        }
      }
    }
  }
}

checkAndTest()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal:', err);
    process.exit(1);
  });
