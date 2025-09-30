const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function cleanupOrphanedNotifications() {
  try {
    await client.connect();
    console.log('Connected to database');

    // First, let's see which notifications are task-related
    const taskNotifications = await client.query(`
      SELECT id, type, title, message, created_at 
      FROM notifications 
      WHERE type = 'task_assigned' 
      ORDER BY created_at DESC;
    `);
    
    console.log('\nTask-related notifications:');
    taskNotifications.rows.forEach(row => {
      console.log(`- ${row.id}: ${row.title}`);
      console.log(`  Message: ${row.message}`);
      console.log(`  Created: ${row.created_at}`);
    });

    // Delete task-related notifications since all tasks are gone
    const deleteResult = await client.query(`
      DELETE FROM notifications 
      WHERE type = 'task_assigned';
    `);
    
    console.log(`\nDeleted ${deleteResult.rowCount} task-related notifications`);

    // Also clean up any orphaned notification read states
    const readStatesCleanup = await client.query(`
      DELETE FROM notification_read_states 
      WHERE notification_id NOT IN (SELECT id FROM notifications);
    `);
    
    console.log(`Cleaned up ${readStatesCleanup.rowCount} orphaned read states`);

    // Also clean up any orphaned notification recipients
    const recipientsCleanup = await client.query(`
      DELETE FROM notification_recipients 
      WHERE notification_id NOT IN (SELECT id FROM notifications);
    `);
    
    console.log(`Cleaned up ${recipientsCleanup.rowCount} orphaned recipients`);

    // Check remaining notifications
    const remaining = await client.query('SELECT COUNT(*) as count FROM notifications;');
    console.log(`\nRemaining notifications: ${remaining.rows[0].count}`);

    await client.end();
    console.log('\nCleanup completed successfully!');
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

cleanupOrphanedNotifications();