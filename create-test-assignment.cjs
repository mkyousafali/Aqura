const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function createTestAssignment() {
  try {
    await client.connect();
    console.log('Creating test task assignment...');

    // First check existing tasks
    const tasksResult = await client.query('SELECT id, title FROM tasks LIMIT 3;');
    console.log('Available tasks:', tasksResult.rows);

    // Check existing users
    const usersResult = await client.query('SELECT id, username FROM users WHERE username IS NOT NULL LIMIT 3;');
    console.log('Available users:', usersResult.rows);

    if (tasksResult.rows.length > 0 && usersResult.rows.length > 0) {
      const taskId = tasksResult.rows[0].id;
      const userId = usersResult.rows[0].id;
      
      console.log(`Creating assignment: Task ${taskId} -> User ${userId}`);

      // Create test assignment
      const assignmentResult = await client.query(`
        INSERT INTO task_assignments (
          task_id, 
          assignment_type, 
          assigned_to_user_id, 
          assigned_by, 
          assigned_by_name, 
          status
        ) 
        VALUES ($1, 'user', $2, 'system', 'Test Admin', 'assigned')
        ON CONFLICT (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id) 
        DO UPDATE SET 
          assigned_at = now(),
          status = 'assigned'
        RETURNING id;
      `, [taskId, userId]);

      console.log('✅ Test assignment created with ID:', assignmentResult.rows[0]?.id);

      // Verify the assignment
      const verifyResult = await client.query(`
        SELECT ta.*, t.title as task_title 
        FROM task_assignments ta 
        JOIN tasks t ON ta.task_id = t.id 
        WHERE ta.assigned_to_user_id = $1;
      `, [userId]);

      console.log('📋 Assignments for user:', verifyResult.rows);
    } else {
      console.log('❌ No tasks or users found to create assignment');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

createTestAssignment();