import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * DEPRECATED: This edge function is no longer used.
 * The application has migrated to a self-hosted backend.
 * Keeping for reference only.
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // DEPRECATED: This function is no longer used
    // Keeping implementation for reference
    
    // Create Supabase client with anonymous key (RLS enforced)
    const supabase = createClient(
      'https://supabase.urbanaqura.com',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    console.log('Starting automatic overdue task reminder check...')

    // Get overdue tasks that haven't received reminders yet
    const { data: overdueTasks, error: tasksError } = await supabase.rpc('get_overdue_tasks_without_reminders')
    
    if (tasksError) {
      console.error('Error fetching overdue tasks:', tasksError)
      throw tasksError
    }

    console.log(`Found ${overdueTasks?.length || 0} overdue tasks needing reminders`)

    let remindersSent = 0

    // Process each overdue task
    for (const task of overdueTasks || []) {
      try {
        // Create notification
        const { data: notification, error: notifError } = await supabase
          .from('notifications')
          .insert({
            title: '⚠️ Overdue Task Reminder',
            message: `Task: "${task.task_title}" | Assigned to: ${task.user_name} | Deadline: ${new Date(task.deadline).toLocaleString('en-US', { 
              year: 'numeric', 
              month: '2-digit', 
              day: '2-digit', 
              hour: '2-digit', 
              minute: '2-digit' 
            })} | Overdue by: ${Math.round(task.hours_overdue * 10) / 10} hours. Please complete it as soon as possible.`,
            type: 'task_overdue',
            target_users: [task.assigned_to_user_id],
            target_type: 'specific_users',
            status: 'published',
            sent_at: new Date().toISOString(),
            created_by: 'system',
            created_by_name: 'System',
            created_by_role: 'system',
            task_id: task.task_id,
            priority: 'medium',
            read_count: 0,
            total_recipients: 1,
            metadata: {
              task_assignment_id: task.assignment_id,
              task_title: task.task_title,
              hours_overdue: Math.round(task.hours_overdue * 10) / 10,
              deadline: task.deadline,
              reminder_type: 'automatic'
            }
          })
          .select()
          .single()

        if (notifError) {
          console.error(`Error creating notification for task ${task.assignment_id}:`, notifError)
          continue
        }

        // Log the reminder
        const { error: logError } = await supabase
          .from('task_reminder_logs')
          .insert({
            task_assignment_id: task.assignment_id,
            task_title: task.task_title,
            assigned_to_user_id: task.assigned_to_user_id,
            deadline: task.deadline,
            hours_overdue: Math.round(task.hours_overdue * 10) / 10,
            notification_id: notification.id,
            status: 'sent'
          })

        if (logError) {
          console.error(`Error logging reminder for task ${task.assignment_id}:`, logError)
          continue
        }

        remindersSent++
        console.log(`Sent reminder for task "${task.task_title}" to ${task.user_name}`)
      } catch (error) {
        console.error(`Failed to process task ${task.assignment_id}:`, error)
      }
    }

    console.log(`Completed. Sent ${remindersSent} reminders.`)

    return new Response(
      JSON.stringify({
        success: true,
        reminders_sent: remindersSent,
        message: `Processed ${overdueTasks?.length || 0} overdue tasks, sent ${remindersSent} reminders`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Error in check-overdue-reminders function:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
