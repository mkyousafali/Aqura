import { createClient } from '@supabase/supabase-js';

// Hardcoded credentials for quick check
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkExistingFunction() {
  console.log('🔍 Checking existing process_clearance_certificate_generation function...\n');

  try {
    // Use raw SQL query via REST API
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/pg_get_functiondef`, {
      method: 'POST',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        func_oid: '(SELECT oid FROM pg_proc WHERE proname = \'process_clearance_certificate_generation\')'
      })
    });

    if (!response.ok) {
      console.log('⚠️  Cannot query function definition directly.\n');
      console.log('Let me check what we know from the codebase:\n');
      
      // Based on the API endpoint we found earlier
      console.log('📋 From ClearanceCertificateManager.svelte:');
      console.log('Function is called via: POST /api/receiving-tasks');
      console.log('\nParameters passed:');
      console.log('  - receiving_record_id: UUID');
      console.log('  - clearance_certificate_url: string');
      console.log('  - generated_by_user_id: UUID');
      
      // Check actual receiving data to understand the flow
      console.log('\n\n� Let me check actual receiving records with certificates...\n');
      
      const { data: receivingData, error: recError } = await supabase
        .from('receiving_records')
        .select('id, bill_number, clearance_certificate_url, clearance_certificate_generated_at')
        .not('clearance_certificate_url', 'is', null)
        .limit(3);
      
      if (!recError && receivingData) {
        console.log(`Found ${receivingData.length} receiving records with certificates:\n`);
        receivingData.forEach(rec => {
          console.log(`  📄 Bill: ${rec.bill_number}`);
          console.log(`     ID: ${rec.id}`);
          console.log(`     Certificate: ${rec.clearance_certificate_url}`);
          console.log(`     Generated: ${rec.clearance_certificate_generated_at}\n`);
        });
        
        // Now check if these have any tasks in the tasks table
        if (receivingData.length > 0) {
          console.log('\n🔍 Checking tasks created for these receiving records...\n');
          
          const { data: tasksData, error: tasksError } = await supabase
            .from('tasks')
            .select('id, title, description, status, created_at')
            .ilike('title', '%' + receivingData[0].bill_number + '%')
            .limit(10);
          
          if (!tasksError && tasksData) {
            console.log(`Found ${tasksData.length} tasks matching bill number "${receivingData[0].bill_number}":\n`);
            tasksData.forEach(task => {
              console.log(`  ✓ ${task.title}`);
              console.log(`    Status: ${task.status}`);
              console.log(`    Created: ${task.created_at}\n`);
            });
          }
          
          // Check receiving_tasks table
          console.log('\n🔍 Checking receiving_tasks table...\n');
          const { data: recTasks, error: recTasksError } = await supabase
            .from('receiving_tasks')
            .select('*')
            .eq('receiving_record_id', receivingData[0].id);
          
          if (!recTasksError) {
            console.log(`Found ${recTasks?.length || 0} entries in receiving_tasks for this record.`);
            if (recTasks && recTasks.length > 0) {
              console.log('Sample entry:', JSON.stringify(recTasks[0], null, 2));
            }
          }
        }
      }
      
      return;
    }

    const data = await response.json();
    console.log('✅ Function definition:', data);

  } catch (err) {
    console.error('❌ Unexpected error:', err.message);
  }
}

// Execute the check
checkExistingFunction()
  .then(() => {
    console.log('\n✅ Check complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
  });
