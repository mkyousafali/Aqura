import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

async function triggerProcessor() {
  console.log('🚀 Triggering Edge Function to process queue...\n');
  
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/process-push-queue`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${anonKey}`,
        'Content-Type': 'application/json'
      }
    });
    
    const data = await response.json();
    
    console.log('📊 Response status:', response.status);
    console.log('📦 Response data:', JSON.stringify(data, null, 2));
    
    if (response.ok) {
      console.log('\n✅ Edge Function executed successfully!');
      console.log(`Processed: ${data.processed}`);
      console.log(`Sent: ${data.sent}`);
      console.log(`Failed: ${data.failed}`);
    } else {
      console.log('\n❌ Edge Function returned error');
    }
  } catch (error) {
    console.error('❌ Error calling Edge Function:', error);
  }
}

triggerProcessor();
