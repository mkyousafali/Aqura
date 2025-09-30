const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function createAssignmentForUser() {
  try {
    await client.connect();
    console.log('Creating assignment for user shamsu...');

    const taskId = '04503fde-43ca-406d-8eb9-c6c2b26423c0';
    const userId = 'e9f184e8-b85a-4834-b248-29c4e5ff4494'; // shamsu user

    // Create assignment for shamsu
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

    console.log('✅ Assignment created for shamsu with ID:', assignmentResult.rows[0]?.id);

    // Verify all assignments
    const verifyResult = await client.query(`
      SELECT ta.*, t.title as task_title, u.username
      FROM task_assignments ta 
      JOIN tasks t ON ta.task_id = t.id 
      JOIN users u ON ta.assigned_to_user_id = u.id
      ORDER BY ta.assigned_at DESC;
    `);

    console.log('📋 All current assignments:');
    verifyResult.rows.forEach(row => {
      console.log(`  ${row.username}: ${row.task_title} (${row.status})`);
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

createAssignmentForUser();