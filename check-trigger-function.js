// Check the trigger function definition in the database
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTriggerFunction() {
    console.log('🔍 Checking trigger function definition...\n');
    
    try {
        // Get the function definition
        const { data, error } = await supabase.rpc('exec_sql', {
            query: `
                SELECT 
                    p.proname as function_name,
                    pg_get_functiondef(p.oid) as function_definition
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE p.proname = 'trigger_sync_erp_reference_on_task_completion'
                AND n.nspname = 'public';
            `
        });

        if (error) {
            console.error('❌ Error fetching function:', error);
            
            // Try alternative method - direct query
            console.log('\n🔄 Trying alternative method...\n');
            
            const { data: altData, error: altError } = await supabase
                .from('pg_proc')
                .select('*')
                .eq('proname', 'trigger_sync_erp_reference_on_task_completion')
                .single();
            
            if (altError) {
                console.error('❌ Alternative method also failed:', altError);
            } else {
                console.log('✅ Function exists:', altData);
            }
        } else {
            console.log('✅ Function definition:\n');
            console.log(data);
        }
        
        // Check triggers on task_completions table
        console.log('\n\n🔍 Checking triggers on task_completions table...\n');
        
        const { data: triggerData, error: triggerError } = await supabase.rpc('exec_sql', {
            query: `
                SELECT 
                    t.tgname as trigger_name,
                    t.tgenabled as is_enabled,
                    p.proname as function_name
                FROM pg_trigger t
                JOIN pg_class c ON t.tgrelid = c.oid
                JOIN pg_proc p ON t.tgfoid = p.oid
                WHERE c.relname = 'task_completions'
                AND t.tgname NOT LIKE 'RI_%';
            `
        });
        
        if (triggerError) {
            console.error('❌ Error fetching triggers:', triggerError);
        } else {
            console.log('✅ Triggers on task_completions:\n');
            console.log(triggerData);
        }
        
    } catch (err) {
        console.error('❌ Unexpected error:', err);
    }
}

checkTriggerFunction();
