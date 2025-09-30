const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testNotificationCreation() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Test creating a notification like the frontend would
    const testData = {
      title: 'Test Notification',
      message: 'This is a test notification',
      type: 'announcement',
      priority: 'medium',
      target_type: 'all_users',
      created_by: 'madmin',
      created_by_name: 'Admin User',
      created_by_role: 'Master Admin',
      status: 'published',
      has_attachments: false,
      read_count: 0,
      total_recipients: 0
    };

    console.log('Testing notification creation with data:', testData);

    const result = await client.query(`
      INSERT INTO notifications (
        title, message, type, priority, target_type,
        created_by, created_by_name, created_by_role,
        status, has_attachments, read_count, total_recipients
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
      ) RETURNING id, title, status;
    `, [
      testData.title, testData.message, testData.type, testData.priority,
      testData.target_type, testData.created_by, testData.created_by_name,
      testData.created_by_role, testData.status, testData.has_attachments,
      testData.read_count, testData.total_recipients
    ]);

    console.log('✅ Notification created successfully:');
    console.log(result.rows[0]);

    // Clean up the test notification
    await client.query('DELETE FROM notifications WHERE id = $1', [result.rows[0].id]);
    console.log('🧹 Test notification cleaned up');

    await client.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    console.error('Error details:', err.detail || err.hint || 'No additional details');
    await client.end();
  }
}

testNotificationCreation();