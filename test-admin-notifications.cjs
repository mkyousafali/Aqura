const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testAdminNotificationView() {
  try {
    await client.connect();
    console.log('Connected to database');

    const userId = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'; // Admin user ID

    // Test the query that getAllNotifications should now use
    console.log('\n=== Testing admin notification view query ===');
    const adminResult = await client.query(`
      SELECT 
        n.*,
        COALESCE(nrs.is_read, false) as is_read,
        nrs.read_at
      FROM notifications n
      LEFT JOIN notification_read_states nrs 
        ON n.id = nrs.notification_id 
        AND nrs.user_id = $1
      WHERE n.status = 'published'
      ORDER BY n.created_at DESC;
    `, [userId]);

    console.log(`Found ${adminResult.rows.length} notifications for admin:`);
    adminResult.rows.forEach(row => {
      console.log(`- ${row.title}: read = ${row.is_read} (read_at: ${row.read_at})`);
    });

    // Test mark some as read functionality for admin user
    console.log('\n=== Testing mark first 3 notifications as read for admin ===');
    
    const firstThree = adminResult.rows.slice(0, 3);
    for (const notification of firstThree) {
      await client.query(`
        INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (notification_id, user_id) 
        DO UPDATE SET is_read = $3, read_at = $4;
      `, [notification.id, userId, true, new Date().toISOString()]);
      
      console.log(`✅ Marked "${notification.title}" as read`);
    }

    // Verify the changes
    console.log('\n=== Verifying updated read states ===');
    const verifyResult = await client.query(`
      SELECT 
        n.title,
        COALESCE(nrs.is_read, false) as is_read,
        nrs.read_at
      FROM notifications n
      LEFT JOIN notification_read_states nrs 
        ON n.id = nrs.notification_id 
        AND nrs.user_id = $1
      WHERE n.status = 'published'
      ORDER BY n.created_at DESC;
    `, [userId]);

    console.log('Final notification read states:');
    verifyResult.rows.forEach(row => {
      const status = row.is_read ? '✅ READ' : '📩 UNREAD';
      console.log(`${status} - ${row.title}`);
    });

    const readCount = verifyResult.rows.filter(row => row.is_read).length;
    const totalCount = verifyResult.rows.length;
    console.log(`\n📊 Summary: ${readCount}/${totalCount} notifications read`);

    await client.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    await client.end();
  }
}

testAdminNotificationView();