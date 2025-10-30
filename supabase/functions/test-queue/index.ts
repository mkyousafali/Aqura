import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    console.log('Testing queue fetch...')

    const { data, error } = await supabase
      .from('notification_queue')
      .select('*')
      .eq('status', 'pending')
      .limit(1)

    if (error) {
      return new Response(JSON.stringify({ error: 'Fetch error', details: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true, data }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Catch error', details: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
