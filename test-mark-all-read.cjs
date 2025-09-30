const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testNotificationMarkAllAsRead() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Test the markAllAsRead functionality by simulating what the frontend does
    const userId = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'; // Admin user ID

    // First get all active notifications (using correct enum value)
    const notificationsResult = await client.query(`
      SELECT id, title, status 
      FROM notifications 
      WHERE status = 'published'
      ORDER BY created_at DESC;
    `);
    
    console.log('\nPublished notifications:');
    notificationsResult.rows.forEach(row => {
      console.log(`- ${row.id}: ${row.title} (status: ${row.status})`);
    });

    if (notificationsResult.rows.length === 0) {
      console.log('No published notifications found. This is expected since we cleaned up earlier.');
      await client.end();
      return;
    }

    // Check existing read states for this user
    const readStatesResult = await client.query(`
      SELECT nrs.notification_id, nrs.is_read 
      FROM notification_read_states nrs
      WHERE nrs.user_id = $1;
    `, [userId]);

    console.log('\nCurrent read states for user:');
    readStatesResult.rows.forEach(row => {
      console.log(`- ${row.notification_id}: read = ${row.is_read}`);
    });

    // Test marking all as read (simulate the frontend function)
    const readStates = notificationsResult.rows.map(notification => ({
      notification_id: notification.id,
      user_id: userId,
      is_read: true,
      read_at: new Date().toISOString()
    }));

    console.log('\nCreating read states for notifications...');
    for (const readState of readStates) {
      await client.query(`
        INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (notification_id, user_id) 
        DO UPDATE SET is_read = $3, read_at = $4;
      `, [readState.notification_id, readState.user_id, readState.is_read, readState.read_at]);
    }

    console.log('✅ Mark all as read test completed successfully!');

    await client.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    await client.end();
  }
}

testNotificationMarkAllAsRead();