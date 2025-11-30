import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function deleteAllNotifications() {
  console.log('🗑️  Starting deletion of all notifications...\n');

  try {
    // First, get the count
    const { count, error: countError } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true });

    if (countError) {
      console.error('❌ Error counting notifications:', countError.message);
      return;
    }

    console.log(`📊 Found ${count} notification records\n`);

    if (count === 0) {
      console.log('✅ Table is already empty!');
      return;
    }

    // Confirm deletion
    console.log('⚠️  WARNING: This will delete ALL notifications permanently!');
    console.log('   This includes related records in:\n');
    console.log('   - notification_recipients');
    console.log('   - notification_read_states');
    console.log('   - notification_attachments');
    console.log('   - task_reminder_logs\n');
    console.log('   Proceeding with deletion...\n');

    // Step 1: Delete notification_recipients
    console.log('🗑️  Deleting notification_recipients...');
    const { count: recipientsCount, error: recipientsError } = await supabase
      .from('notification_recipients')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    if (recipientsError) {
      console.error('❌ Error deleting notification_recipients:', recipientsError.message);
    } else {
      console.log(`✅ Deleted notification_recipients records\n`);
    }

    // Step 2: Delete notification_read_states
    console.log('🗑️  Deleting notification_read_states...');
    const { count: readStatesCount, error: readStatesError } = await supabase
      .from('notification_read_states')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    if (readStatesError) {
      console.error('❌ Error deleting notification_read_states:', readStatesError.message);
    } else {
      console.log(`✅ Deleted notification_read_states records\n`);
    }

    // Step 3: Delete notification_attachments
    console.log('🗑️  Deleting notification_attachments...');
    const { count: attachmentsCount, error: attachmentsError } = await supabase
      .from('notification_attachments')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    if (attachmentsError) {
      console.error('❌ Error deleting notification_attachments:', attachmentsError.message);
    } else {
      console.log(`✅ Deleted notification_attachments records\n`);
    }

    // Step 4: Delete task_reminder_logs
    console.log('🗑️  Deleting task_reminder_logs...');
    const { count: reminderLogsCount, error: reminderLogsError } = await supabase
      .from('task_reminder_logs')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');
    
    if (reminderLogsError) {
      console.error('❌ Error deleting task_reminder_logs:', reminderLogsError.message);
    } else {
      console.log(`✅ Deleted task_reminder_logs records\n`);
    }

    // Step 5: Finally delete all notifications
    console.log('🗑️  Deleting notifications...');
    const { error: deleteError } = await supabase
      .from('notifications')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000');

    if (deleteError) {
      console.error('❌ Error deleting notifications:', deleteError.message);
      return;
    }

    console.log(`✅ Successfully deleted ${count} notifications!\n`);
    
    // Verify deletion
    const { count: newCount } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true });

    console.log(`✅ Current notification count: ${newCount}`);
    console.log(`✅ All notification-related data has been cleared!`);

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

deleteAllNotifications();
