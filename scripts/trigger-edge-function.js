// Manually trigger Edge Function to process pending notifications
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs'

const supabase = createClient(supabaseUrl, supabaseKey)

async function triggerEdgeFunction() {
  console.log('⚡ Manually triggering Edge Function...\n')

  const edgeFunctionUrl = `${supabaseUrl}/functions/v1/process-push-queue`
  
  try {
    const response = await fetch(edgeFunctionUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      }
    })

    const result = await response.json()
    
    if (response.ok) {
      console.log('✅ Edge Function executed successfully!')
      console.log('📊 Result:', JSON.stringify(result, null, 2))
    } else {
      console.error('❌ Edge Function failed:')
      console.error('Status:', response.status)
      console.error('Error:', result)
    }
  } catch (error) {
    console.error('❌ Failed to call Edge Function:', error)
  }

  // Check queue status
  console.log('\n📬 Checking recent queue entries...')
  const { data: queue } = await supabase
    .from('notification_queue')
    .select('id, notification_id, status, sent_at, created_at')
    .order('created_at', { ascending: false })
    .limit(5)

  console.table(queue)
}

triggerEdgeFunction()
