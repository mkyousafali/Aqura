const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://dqvocnzudtzqjgdmcglt.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxdm9jbnp1ZHR6cWpnZG1jZ2x0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzMjg0OTUsImV4cCI6MjA0NjkwNDQ5NX0.bYSt7hZm_K2EXQSQvFnrQHI0vkmzMV9Aw_6YCsCAKsw'
);

async function findAndDeleteMismatchedTasks() {
  try {
    console.log('🔍 Finding mismatched receiving tasks...\n');

    // Get all active receiving tasks with user info
    const { data: tasks, error: tasksError } = await supabase
      .from('receiving_tasks')
      .select(`
        id,
        role_type,
        status,
        assigned_user_id,
        created_at,
        receiving_record:receiving_records(receiving_number, branch_id),
        user:users(username, role_type)
      `)
      .eq('status', 'assigned');

    if (tasksError) {
      console.error('❌ Error fetching tasks:', tasksError);
      return;
    }

    console.log(`📋 Found ${tasks.length} active tasks\n`);

    // Find mismatched tasks
    const mismatchedTasks = tasks.filter(task => {
      const userRole = task.user?.role_type;
      const taskRole = task.role_type;
      
      // Check if there's a role mismatch
      return userRole && taskRole && userRole !== taskRole;
    });

    console.log(`❌ Found ${mismatchedTasks.length} mismatched tasks:`);
    
    if (mismatchedTasks.length === 0) {
      console.log('✅ No mismatched tasks found!');
      return;
    }

    // Group by user for better overview
    const tasksByUser = {};
    mismatchedTasks.forEach(task => {
      const username = task.user?.username || 'unknown';
      if (!tasksByUser[username]) {
        tasksByUser[username] = [];
      }
      tasksByUser[username].push(task);
    });

    // Display mismatched tasks by user
    console.log('\n📊 Mismatched tasks by user:');
    Object.entries(tasksByUser).forEach(([username, userTasks]) => {
      console.log(`\n👤 ${username} (${userTasks[0].user.role_type}):`);
      userTasks.forEach(task => {
        console.log(`  - Task ${task.id}: ${task.role_type} (RN: ${task.receiving_record?.receiving_number || 'N/A'})`);
      });
    });

    // Ask for confirmation before deletion
    console.log(`\n⚠️  About to delete ${mismatchedTasks.length} mismatched tasks.`);
    console.log('This action cannot be undone!');
    
    // For safety, let's do a dry run first
    console.log('\n🔍 DRY RUN - Tasks that would be deleted:');
    mismatchedTasks.forEach(task => {
      console.log(`  - Task ID ${task.id}: User ${task.user.username} (${task.user.role_type}) assigned to ${task.role_type} task`);
    });

    // Uncomment the next lines to actually perform the deletion
    /*
    console.log('\n🗑️  Deleting mismatched tasks...');
    
    const taskIds = mismatchedTasks.map(task => task.id);
    
    const { error: deleteError } = await supabase
      .from('receiving_tasks')
      .delete()
      .in('id', taskIds);

    if (deleteError) {
      console.error('❌ Error deleting tasks:', deleteError);
      return;
    }

    console.log(`✅ Successfully deleted ${taskIds.length} mismatched tasks!`);
    */

    console.log('\n📝 To actually delete these tasks, uncomment the deletion code in the script.');

  } catch (error) {
    console.error('❌ Script error:', error);
  }
}

// Add a function to delete specific tasks by ID
async function deleteSpecificTasks(taskIds) {
  try {
    console.log(`🗑️  Deleting specific tasks: ${taskIds.join(', ')}`);
    
    const { error: deleteError } = await supabase
      .from('receiving_tasks')
      .delete()
      .in('id', taskIds);

    if (deleteError) {
      console.error('❌ Error deleting tasks:', deleteError);
      return;
    }

    console.log(`✅ Successfully deleted ${taskIds.length} tasks!`);
  } catch (error) {
    console.error('❌ Delete error:', error);
  }
}

// Run the analysis
findAndDeleteMismatchedTasks();

// Export functions for manual use
module.exports = { findAndDeleteMismatchedTasks, deleteSpecificTasks };