import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkCronStatus() {
  console.log('='.repeat(60));
  console.log('CHECKING PG_CRON STATUS');
  console.log('='.repeat(60));
  
  // Check if pg_cron extension is enabled
  const { data: extensions, error: extError } = await supabase
    .rpc('exec_sql', { 
      query: "SELECT * FROM pg_extension WHERE extname = 'pg_cron';" 
    });
  
  if (extError) {
    console.log('\n⚠️  Cannot check extensions (might need custom function)');
  } else {
    console.log('\n✅ pg_cron extension check:', extensions);
  }
  
  // Check cron jobs
  console.log('\n📋 Checking cron.job table...');
  const { data: jobs, error: jobError } = await supabase
    .from('cron.job')
    .select('*');
    
  if (jobError) {
    console.log('❌ Error accessing cron.job:', jobError.message);
    console.log('Details:', jobError);
  } else {
    console.log(`\n✅ Found ${jobs.length} cron job(s):`);
    jobs.forEach(job => {
      console.log('\n--- Job ---');
      console.log(`ID: ${job.jobid}`);
      console.log(`Name: ${job.jobname}`);
      console.log(`Schedule: ${job.schedule}`);
      console.log(`Active: ${job.active}`);
      console.log(`Command: ${job.command}`);
    });
  }
  
  // Check recent job runs
  console.log('\n\n📊 Checking recent cron job runs...');
  const { data: runs, error: runsError } = await supabase
    .from('cron.job_run_details')
    .select('*')
    .order('start_time', { ascending: false })
    .limit(10);
    
  if (runsError) {
    console.log('❌ Error accessing cron.job_run_details:', runsError.message);
    console.log('⚠️  This might mean pg_cron is not enabled or no jobs have run yet');
  } else {
    if (runs.length === 0) {
      console.log('⚠️  NO JOB RUNS FOUND - pg_cron might not be running!');
    } else {
      console.log(`\n✅ Found ${runs.length} recent job run(s):`);
      runs.forEach((run, i) => {
        console.log(`\n--- Run ${i + 1} ---`);
        console.log(`Job ID: ${run.jobid}`);
        console.log(`Start: ${run.start_time}`);
        console.log(`End: ${run.end_time || 'Still running'}`);
        console.log(`Status: ${run.status}`);
        console.log(`Return Message: ${run.return_message || 'None'}`);
      });
    }
  }
  
  // Check if function exists
  console.log('\n\n🔍 Checking if process_push_notification_queue() function exists...');
  const { data: functions, error: funcError } = await supabase
    .rpc('exec_sql', {
      query: "SELECT proname, prokind FROM pg_proc WHERE proname = 'process_push_notification_queue';"
    });
    
  if (funcError) {
    console.log('⚠️  Cannot check functions directly');
  } else {
    console.log('Function check:', functions);
  }
  
  // Check notification_queue for pending items
  console.log('\n\n📬 Checking notification_queue for pending items...');
  const { data: pending, error: pendingError } = await supabase
    .from('notification_queue')
    .select('id, status, created_at')
    .eq('status', 'pending')
    .order('created_at', { ascending: false })
    .limit(5);
    
  if (pendingError) {
    console.log('❌ Error:', pendingError.message);
  } else {
    console.log(`Found ${pending.length} pending notifications`);
    if (pending.length > 0) {
      console.log('⚠️  WARNING: There are pending notifications that should be processed!');
      pending.forEach(p => {
        console.log(`  - ${p.id} (created: ${p.created_at})`);
      });
    } else {
      console.log('✅ No pending notifications');
    }
  }
}

checkCronStatus().catch(console.error);
