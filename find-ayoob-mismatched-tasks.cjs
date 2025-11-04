const { createClient } = require('@supabase/supabase-js');

// Use service role key for better access
const supabase = createClient(
  'https://dqvocnzudtzqjgdmcglt.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxdm9jbnp1ZHR6cWpnZG1jZ2x0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMTMyODQ5NSwiZXhwIjoyMDQ2OTA0NDk1fQ.N2EAXE0UOk0cgJUy0hUmCvGWWUiP3KU_bN6L5fHWcDw'
);

async function findAyoobMismatchedTasks() {
  try {
    console.log('🔍 Finding Ayoob\'s mismatched tasks...\n');

    // First, get Ayoob's user info
    const { data: ayoobUser, error: userError } = await supabase
      .from('users')
      .select('id, username, role_type')
      .eq('username', 'ayoob')
      .single();

    if (userError || !ayoobUser) {
      console.error('❌ Error finding Ayoob:', userError);
      return;
    }

    console.log('👤 Ayoob Info:', ayoobUser);

    // Get all of Ayoob's assigned tasks
    const { data: ayoobTasks, error: tasksError } = await supabase
      .from('receiving_tasks')
      .select(`
        id,
        role_type,
        status,
        created_at,
        receiving_record_id
      `)
      .eq('assigned_user_id', ayoobUser.id)
      .eq('status', 'assigned');

    if (tasksError) {
      console.error('❌ Error fetching Ayoob\'s tasks:', tasksError);
      return;
    }

    console.log(`📋 Ayoob has ${ayoobTasks.length} assigned tasks\n`);

    // Find mismatched tasks (where Ayoob's role != task role)
    const mismatchedTasks = ayoobTasks.filter(task => 
      task.role_type !== ayoobUser.role_type
    );

    console.log(`❌ Found ${mismatchedTasks.length} mismatched tasks for Ayoob:`);
    
    if (mismatchedTasks.length === 0) {
      console.log('✅ No mismatched tasks found for Ayoob!');
      return;
    }

    // Group by role type
    const tasksByRole = {};
    mismatchedTasks.forEach(task => {
      if (!tasksByRole[task.role_type]) {
        tasksByRole[task.role_type] = [];
      }
      tasksByRole[task.role_type].push(task);
    });

    console.log('\n📊 Mismatched tasks by role:');
    Object.entries(tasksByRole).forEach(([roleType, tasks]) => {
      console.log(`\n🔸 ${roleType}: ${tasks.length} tasks`);
      tasks.slice(0, 5).forEach(task => {
        console.log(`  - Task ID: ${task.id} (created: ${task.created_at})`);
      });
      if (tasks.length > 5) {
        console.log(`  ... and ${tasks.length - 5} more`);
      }
    });

    // Show the task IDs for deletion
    const taskIds = mismatchedTasks.map(task => task.id);
    console.log(`\n📝 Task IDs to delete: [${taskIds.join(', ')}]`);

    console.log('\n⚠️  Would you like to delete these mismatched tasks? (y/n)');
    console.log('These are the tasks causing the role mismatch error for Ayoob.');
    
    // For safety, show what would be deleted
    console.log('\n🔍 PREVIEW - Tasks that would be deleted:');
    mismatchedTasks.forEach(task => {
      console.log(`  ❌ Task ${task.id}: Ayoob (${ayoobUser.role_type}) assigned to ${task.role_type} task`);
    });

    // Return the task IDs for manual deletion if needed
    return taskIds;

  } catch (error) {
    console.error('❌ Script error:', error);
  }
}

async function deleteAyoobMismatchedTasks(taskIds) {
  try {
    console.log(`\n🗑️  Deleting ${taskIds.length} mismatched tasks for Ayoob...`);
    
    const { error: deleteError } = await supabase
      .from('receiving_tasks')
      .delete()
      .in('id', taskIds);

    if (deleteError) {
      console.error('❌ Error deleting tasks:', deleteError);
      return false;
    }

    console.log(`✅ Successfully deleted ${taskIds.length} mismatched tasks!`);
    return true;

  } catch (error) {
    console.error('❌ Delete error:', error);
    return false;
  }
}

// Run the analysis
async function main() {
  const taskIds = await findAyoobMismatchedTasks();
  
  if (taskIds && taskIds.length > 0) {
    console.log('\n🚀 To delete these tasks, run:');
    console.log('node -e "require(\'./find-ayoob-mismatched-tasks.cjs\').deleteAyoobMismatchedTasks([' + taskIds.join(', ') + '])"');
  }
}

main();

// Export for manual use
module.exports = { findAyoobMismatchedTasks, deleteAyoobMismatchedTasks };