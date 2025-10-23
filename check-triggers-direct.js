import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkTriggerStatus() {
  console.log('🔍 Checking trigger and function status with direct SQL...');
  
  try {
    // Check if trigger exists using direct SQL
    const { data: triggerData, error: triggerError } = await supabase.rpc('sql', {
      query: `
        SELECT 
          trigger_name,
          event_manipulation,
          action_timing,
          action_statement
        FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_auto_create_payment_transaction_and_task';
      `
    });
    
    if (triggerError) {
      console.log('❌ Error checking trigger with SQL:', triggerError);
      
      // Alternative approach - try to execute the function directly
      console.log('🔧 Trying alternative approach to check function...');
      
      const { data: funcCheck, error: funcError } = await supabase.rpc('sql', {
        query: `
          SELECT EXISTS(
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE p.proname = 'auto_create_payment_transaction_and_task'
            AND n.nspname = 'public'
          ) as function_exists;
        `
      });
      
      if (funcError) {
        console.log('❌ Error checking function existence:', funcError);
      } else {
        console.log('📋 Function exists:', funcCheck);
      }
      
    } else {
      console.log('✅ Trigger status:', triggerData);
    }
    
    // Check for any other triggers on vendor_payment_schedule
    const { data: allTriggers, error: allTriggersError } = await supabase.rpc('sql', {
      query: `
        SELECT 
          trigger_name,
          event_manipulation,
          action_timing
        FROM information_schema.triggers 
        WHERE event_object_table = 'vendor_payment_schedule';
      `
    });
    
    if (allTriggersError) {
      console.log('❌ Error checking all triggers:', allTriggersError);
    } else {
      console.log('📋 All triggers on vendor_payment_schedule:', allTriggers);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkTriggerStatus();