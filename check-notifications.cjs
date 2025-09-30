const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkNotifications() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Check notification tables
    const tables = await client.query("SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%notification%' ORDER BY table_name;");
    console.log('\nNotification tables:');
    tables.rows.forEach(row => console.log('-', row.table_name));

    // Check total notifications count
    const count = await client.query('SELECT COUNT(*) as count FROM notifications;');
    console.log('\nTotal notifications:', count.rows[0].count);

    // Check recent notifications
    const recent = await client.query('SELECT id, type, title, message, created_at FROM notifications ORDER BY created_at DESC LIMIT 5;');
    console.log('\nRecent notifications:');
    recent.rows.forEach(row => {
      console.log(`- ${row.id}: ${row.type} - ${row.title}`);
      console.log(`  Message: ${row.message}`);
      console.log(`  Created: ${row.created_at}`);
    });

    // Check if there are tasks
    const taskCount = await client.query('SELECT COUNT(*) as count FROM tasks;');
    console.log('\nTotal tasks:', taskCount.rows[0].count);

    // Check if there are task assignments
    const assignmentCount = await client.query('SELECT COUNT(*) as count FROM task_assignments;');
    console.log('Total task assignments:', assignmentCount.rows[0].count);

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

checkNotifications();