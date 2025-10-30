// Check the actual payload
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs'

const supabase = createClient(supabaseUrl, supabaseKey)

async function checkPayload() {
  const { data: queue } = await supabase
    .from('notification_queue')
    .select('payload')
    .eq('id', 'ac4f7bd8-0d3f-4af4-81d2-f0f9c5874ea6')
    .single()

  console.log('Payload:', JSON.stringify(queue.payload, null, 2))
  
  const tag = queue.payload?.tag
  console.log('\nTag value:', tag)
  console.log('Tag length:', tag?.length || 0)
}

checkPayload()
