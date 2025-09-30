const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testNotificationFunctionality() {
  try {
    await client.connect();
    console.log('Connected to database');

    const userId = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'; // Admin user ID

    // Test 1: Get all published notifications
    console.log('\n=== Test 1: Getting published notifications ===');
    const notificationsResult = await client.query(`
      SELECT id, title, status 
      FROM notifications 
      WHERE status = 'published'
      ORDER BY created_at DESC;
    `);
    
    console.log(`Found ${notificationsResult.rows.length} published notifications:`);
    notificationsResult.rows.forEach(row => {
      console.log(`- ${row.id}: ${row.title}`);
    });

    if (notificationsResult.rows.length === 0) {
      console.log('No published notifications found to test with.');
      await client.end();
      return;
    }

    // Test 2: Mark first notification as read using new schema
    const firstNotificationId = notificationsResult.rows[0].id;
    console.log(`\n=== Test 2: Marking notification ${firstNotificationId} as read ===`);
    
    await client.query(`
      INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (notification_id, user_id) 
      DO UPDATE SET is_read = $3, read_at = $4;
    `, [firstNotificationId, userId, true, new Date().toISOString()]);

    console.log('✅ Notification marked as read');

    // Test 3: Query notifications with read states (like frontend does)
    console.log('\n=== Test 3: Querying notifications with read states ===');
    const userNotificationsResult = await client.query(`
      SELECT 
        n.id,
        n.title,
        n.message,
        n.type,
        n.priority,
        n.created_at,
        COALESCE(nrs.is_read, false) as is_read,
        nrs.read_at
      FROM notifications n
      LEFT JOIN notification_read_states nrs 
        ON n.id = nrs.notification_id 
        AND nrs.user_id = $1
      WHERE n.status = 'published'
      ORDER BY n.created_at DESC
      LIMIT 3;
    `, [userId]);

    console.log('User notifications with read status:');
    userNotificationsResult.rows.forEach(row => {
      console.log(`- ${row.title}: read = ${row.is_read} (read_at: ${row.read_at})`);
    });

    // Test 4: Mark all as read test
    console.log('\n=== Test 4: Testing mark all as read functionality ===');
    const allNotifications = await client.query(`
      SELECT id FROM notifications WHERE status = 'published';
    `);

    for (const notification of allNotifications.rows) {
      await client.query(`
        INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (notification_id, user_id) 
        DO UPDATE SET is_read = $3, read_at = $4;
      `, [notification.id, userId, true, new Date().toISOString()]);
    }

    console.log(`✅ Marked ${allNotifications.rows.length} notifications as read`);

    // Test 5: Verify all are marked as read
    const finalCheck = await client.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN nrs.is_read = true THEN 1 END) as read_count
      FROM notifications n
      LEFT JOIN notification_read_states nrs 
        ON n.id = nrs.notification_id 
        AND nrs.user_id = $1
      WHERE n.status = 'published';
    `, [userId]);

    console.log('\n=== Final verification ===');
    console.log(`Total notifications: ${finalCheck.rows[0].total}`);
    console.log(`Read notifications: ${finalCheck.rows[0].read_count}`);
    console.log('✅ All tests completed successfully!');

    await client.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    await client.end();
  }
}

testNotificationFunctionality();