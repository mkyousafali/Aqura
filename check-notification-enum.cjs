const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkNotificationEnum() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Check the notification_status_enum values
    const enumValues = await client.query(`
      SELECT enumlabel 
      FROM pg_enum 
      WHERE enumtypid = (
        SELECT oid 
        FROM pg_type 
        WHERE typname = 'notification_status_enum'
      )
      ORDER BY enumsortorder;
    `);
    
    console.log('\nCurrent notification_status_enum values:');
    enumValues.rows.forEach(row => console.log(`- ${row.enumlabel}`));

    // Check notifications table structure
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'notifications' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\nNotifications table columns:');
    columns.rows.forEach(row => {
      console.log(`- ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });

    // Check actual status values in notifications table
    const statuses = await client.query(`
      SELECT DISTINCT status, COUNT(*) as count 
      FROM notifications 
      GROUP BY status 
      ORDER BY count DESC;
    `);
    
    console.log('\nCurrent status values in notifications table:');
    statuses.rows.forEach(row => {
      console.log(`- ${row.status}: ${row.count} notifications`);
    });

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

checkNotificationEnum();