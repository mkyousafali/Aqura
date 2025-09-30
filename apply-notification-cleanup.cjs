const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function applyNotificationCleanup() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Read and apply the notification cleanup schema
    const schema = fs.readFileSync('notification-cascade-cleanup.sql', 'utf8');
    await client.query(schema);
    
    console.log('Notification cascade cleanup schema applied successfully!');
    
    // Verify the cleanup worked
    const notificationCount = await client.query('SELECT COUNT(*) as count FROM notifications;');
    console.log(`Current notification count: ${notificationCount.rows[0].count}`);
    
    // Check remaining notifications
    const remaining = await client.query('SELECT id, type, title FROM notifications ORDER BY created_at DESC;');
    console.log('\nRemaining notifications:');
    remaining.rows.forEach(row => {
      console.log(`- ${row.type}: ${row.title}`);
    });

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

applyNotificationCleanup();