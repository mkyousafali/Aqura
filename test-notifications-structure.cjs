const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkNotificationsTableStructure() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Check notifications table structure
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'notifications' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\nNotifications table structure:');
    columns.rows.forEach(row => {
      const required = row.is_nullable === 'NO' ? '(REQUIRED)' : '(optional)';
      console.log(`- ${row.column_name}: ${row.data_type} ${required} default: ${row.column_default}`);
    });

    // Check what notification types are valid
    const typeEnum = await client.query(`
      SELECT enumlabel 
      FROM pg_enum 
      WHERE enumtypid = (
        SELECT oid 
        FROM pg_type 
        WHERE typname = 'notification_type_enum'
      )
      ORDER BY enumsortorder;
    `);
    
    console.log('\nValid notification types:');
    typeEnum.rows.forEach(row => console.log(`- ${row.enumlabel}`));

    // Check what target types are valid
    const targetEnum = await client.query(`
      SELECT enumlabel 
      FROM pg_enum 
      WHERE enumtypid = (
        SELECT oid 
        FROM pg_type 
        WHERE typname = 'notification_target_type_enum'
      )
      ORDER BY enumsortorder;
    `);
    
    console.log('\nValid target types:');
    targetEnum.rows.forEach(row => console.log(`- ${row.enumlabel}`));

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

checkNotificationsTableStructure();