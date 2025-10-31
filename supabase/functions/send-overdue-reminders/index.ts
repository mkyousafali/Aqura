import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const now = new Date()
    console.log('🔍 Checking for overdue tasks at:', now.toISOString())

    // Get all incomplete task assignments that are overdue
    const { data: overdueAssignments, error: assignmentsError } = await supabaseClient
      .from('task_assignments')
      .select(`
        id,
        task_id,
        assigned_to,
        deadline_datetime,
        deadline_date,
        tasks (
          title,
          description
        ),
        users!task_assignments_assigned_to_fkey (
          id,
          username
        ),
        branches (
          id,
          name_en
        )
      `)
      .is('completed_at', null)
      .not('deadline_datetime', 'is', null)
      .lt('deadline_datetime', now.toISOString())

    // Get quick task assignments that are overdue
    const { data: overdueQuickAssignments, error: quickError } = await supabaseClient
      .from('quick_task_assignments')
      .select(`
        id,
        quick_task_id,
        assigned_to,
        quick_tasks (
          id,
          title,
          deadline_datetime
        ),
        users!quick_task_assignments_assigned_to_fkey (
          id,
          username
        )
      `)
      .is('completed', null)
      .not('quick_tasks.deadline_datetime', 'is', null)

    if (assignmentsError) {
      console.error('❌ Error fetching overdue assignments:', assignmentsError)
    }

    if (quickError) {
      console.error('❌ Error fetching overdue quick assignments:', quickError)
    }

    let remindersCreated = 0
    let remindersSkipped = 0

    // Process regular task assignments
    if (overdueAssignments && overdueAssignments.length > 0) {
      console.log(`📋 Found ${overdueAssignments.length} overdue regular tasks`)

      for (const assignment of overdueAssignments) {
        try {
          // Check if reminder already sent for this assignment
          const { data: existingReminder } = await supabaseClient
            .from('notifications')
            .select('id')
            .eq('type', 'task_overdue_reminder')
            .eq('data->>assignment_id', assignment.id)
            .single()

          if (existingReminder) {
            console.log(`⏭️  Reminder already sent for assignment ${assignment.id}`)
            remindersSkipped++
            continue
          }

          // Calculate hours overdue
          const deadline = new Date(assignment.deadline_datetime || assignment.deadline_date)
          const hoursOverdue = Math.floor((now.getTime() - deadline.getTime()) / (1000 * 60 * 60))

          // Create notification
          const { error: notifError } = await supabaseClient
            .from('notifications')
            .insert({
              user_id: assignment.assigned_to,
              type: 'task_overdue_reminder',
              title: '⚠️ Overdue Task Reminder',
              message: `Your task "${assignment.tasks?.title}" is ${hoursOverdue} hour(s) overdue. Please complete it as soon as possible.`,
              data: {
                task_id: assignment.task_id,
                assignment_id: assignment.id,
                task_type: 'regular',
                deadline: assignment.deadline_datetime || assignment.deadline_date,
                hours_overdue: hoursOverdue,
                branch_name: assignment.branches?.name_en,
                auto_sent: true
              },
              created_at: now.toISOString()
            })

          if (notifError) {
            console.error(`❌ Error creating notification for ${assignment.id}:`, notifError)
          } else {
            console.log(`✅ Reminder sent for assignment ${assignment.id}`)
            remindersCreated++
          }
        } catch (error) {
          console.error(`❌ Error processing assignment ${assignment.id}:`, error)
        }
      }
    }

    // Process quick task assignments
    if (overdueQuickAssignments && overdueQuickAssignments.length > 0) {
      // Filter only actually overdue tasks
      const actuallyOverdue = overdueQuickAssignments.filter(qa => {
        if (!qa.quick_tasks?.deadline_datetime) return false
        const deadline = new Date(qa.quick_tasks.deadline_datetime)
        return deadline < now
      })

      console.log(`📋 Found ${actuallyOverdue.length} overdue quick tasks`)

      for (const quickAssignment of actuallyOverdue) {
        try {
          // Check if reminder already sent
          const { data: existingReminder } = await supabaseClient
            .from('notifications')
            .select('id')
            .eq('type', 'task_overdue_reminder')
            .eq('data->>assignment_id', quickAssignment.id)
            .single()

          if (existingReminder) {
            console.log(`⏭️  Reminder already sent for quick assignment ${quickAssignment.id}`)
            remindersSkipped++
            continue
          }

          // Calculate hours overdue
          const deadline = new Date(quickAssignment.quick_tasks.deadline_datetime)
          const hoursOverdue = Math.floor((now.getTime() - deadline.getTime()) / (1000 * 60 * 60))

          // Create notification
          const { error: notifError } = await supabaseClient
            .from('notifications')
            .insert({
              user_id: quickAssignment.assigned_to,
              type: 'task_overdue_reminder',
              title: '⚠️ Overdue Quick Task Reminder',
              message: `Your quick task "${quickAssignment.quick_tasks?.title}" is ${hoursOverdue} hour(s) overdue. Please complete it as soon as possible.`,
              data: {
                task_id: quickAssignment.quick_task_id,
                assignment_id: quickAssignment.id,
                task_type: 'quick',
                deadline: quickAssignment.quick_tasks.deadline_datetime,
                hours_overdue: hoursOverdue,
                auto_sent: true
              },
              created_at: now.toISOString()
            })

          if (notifError) {
            console.error(`❌ Error creating notification for ${quickAssignment.id}:`, notifError)
          } else {
            console.log(`✅ Reminder sent for quick assignment ${quickAssignment.id}`)
            remindersCreated++
          }
        } catch (error) {
          console.error(`❌ Error processing quick assignment ${quickAssignment.id}:`, error)
        }
      }
    }

    const summary = {
      success: true,
      timestamp: now.toISOString(),
      reminders_sent: remindersCreated,
      reminders_skipped: remindersSkipped,
      total_overdue_found: (overdueAssignments?.length || 0) + (overdueQuickAssignments?.length || 0),
      message: `Sent ${remindersCreated} automatic reminders, skipped ${remindersSkipped} (already sent)`
    }

    console.log('📊 Summary:', summary)

    return new Response(
      JSON.stringify(summary),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('❌ Fatal error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
