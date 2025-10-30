// Check if pg_cron jobs are configured
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function checkCronJobs() {
    console.log('🔍 Checking pg_cron jobs...\n');
    
    // Query cron.job table to see scheduled jobs
    const { data, error } = await supabase
        .rpc('exec_sql', {
            query: 'SELECT * FROM cron.job ORDER BY jobid;'
        });
    
    if (error) {
        console.error('❌ Error fetching cron jobs:', error);
        console.log('\n💡 This might mean pg_cron is not installed or not accessible');
    } else {
        console.log('✅ Cron jobs found:', JSON.stringify(data, null, 2));
    }
    
    // Also manually trigger the Edge Function to test
    console.log('\n🧪 Manually triggering the process-push-queue Edge Function...\n');
    
    try {
        const response = await fetch(`${SUPABASE_URL}/functions/v1/process-push-queue`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
        
        const result = await response.json();
        console.log('📡 Edge Function Response:', JSON.stringify(result, null, 2));
        console.log('Status:', response.status, response.statusText);
    } catch (error) {
        console.error('❌ Error calling Edge Function:', error.message);
    }
}

checkCronJobs().catch(console.error);
