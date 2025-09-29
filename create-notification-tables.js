// Script to create notification tables directly using Supabase client
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ'

const supabase = createClient(supabaseUrl, supabaseKey, {
  db: {
    schema: 'public'
  }
})

async function createNotificationTables() {
  console.log('Creating notification tables...')

  try {
    // Create notifications table
    console.log('Creating notifications table...')
    const { error: createNotificationsError } = await supabase.from('notifications').select('id').limit(1)
    
    if (createNotificationsError) {
      console.log('Notifications table does not exist, need to create via SQL editor')
      console.log('Please run the notification-center-schema.sql in Supabase SQL editor')
      return
    }

    console.log('✓ Notifications table exists')

    // Insert some test data
    console.log('Inserting test notification...')
    const { data: testNotification, error: insertError } = await supabase
      .from('notifications')
      .insert([
        {
          title: 'Welcome to the Notification System',
          message: 'This is a test notification to verify the system is working correctly.',
          type: 'info',
          priority: 'medium',
          status: 'published',
          target_type: 'all_users',
          created_by: 'system'
        }
      ])
      .select()

    if (insertError) {
      console.error('Error inserting test notification:', insertError)
    } else {
      console.log('✓ Test notification created:', testNotification)
    }

    // Try to fetch notifications
    console.log('Fetching existing notifications...')
    const { data: notifications, error: fetchError } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })

    if (fetchError) {
      console.error('Error fetching notifications:', fetchError)
    } else {
      console.log(`✓ Found ${notifications.length} notifications:`)
      notifications.forEach(notif => {
        console.log(`  - ${notif.title} (${notif.type}, ${notif.status})`)
      })
    }

  } catch (error) {
    console.error('Error:', error.message)
  }
}

createNotificationTables().catch(console.error)