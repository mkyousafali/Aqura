const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testFullNotificationFlow() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Test the exact data structure that the frontend would send
    const frontendData = {
      title: 'test',
      message: 'test',
      type: 'info', // Changed from announcement to info (which is default)
      priority: 'medium',
      target_type: 'all_users'
    };

    // Simulate the createNotification function logic
    console.log('Testing with frontend data structure:');
    console.log(frontendData);

    // First get user info (simulating the function)
    const userResult = await client.query(`
      SELECT username, role_type 
      FROM users 
      WHERE username = 'madmin'
    `);

    console.log('User lookup result:', userResult.rows);

    const userData = userResult.rows[0];
    const createdByName = userData?.username || 'madmin';
    const createdByRole = userData?.role_type || 'Admin';

    console.log(`Using createdByName: ${createdByName}, createdByRole: ${createdByRole}`);

    // Now create the notification with all required fields
    const insertData = {
      ...frontendData,
      created_by: 'madmin',
      created_by_name: createdByName,
      created_by_role: createdByRole,
      status: 'published',
      has_attachments: false,
      read_count: 0,
      total_recipients: 0
    };

    console.log('Final insert data:');
    console.log(insertData);

    const result = await client.query(`
      INSERT INTO notifications (
        title, message, type, priority, target_type,
        created_by, created_by_name, created_by_role,
        status, has_attachments, read_count, total_recipients
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
      ) RETURNING *;
    `, [
      insertData.title, insertData.message, insertData.type, insertData.priority,
      insertData.target_type, insertData.created_by, insertData.created_by_name,
      insertData.created_by_role, insertData.status, insertData.has_attachments,
      insertData.read_count, insertData.total_recipients
    ]);

    console.log('✅ Notification created successfully:');
    console.log({
      id: result.rows[0].id,
      title: result.rows[0].title,
      status: result.rows[0].status,
      created_by_name: result.rows[0].created_by_name
    });

    // Clean up
    await client.query('DELETE FROM notifications WHERE id = $1', [result.rows[0].id]);
    console.log('🧹 Test notification cleaned up');

    await client.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    if (err.detail) console.error('Detail:', err.detail);
    if (err.hint) console.error('Hint:', err.hint);
    await client.end();
  }
}

testFullNotificationFlow();