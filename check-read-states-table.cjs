const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkReadStatesTable() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Check notification_read_states table structure
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'notification_read_states' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\nNotification_read_states table columns:');
    columns.rows.forEach(row => {
      console.log(`- ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });

    // Check if there are any records
    const count = await client.query('SELECT COUNT(*) as count FROM notification_read_states;');
    console.log(`\nTotal read states: ${count.rows[0].count}`);

    // Show sample data if any exists
    const sample = await client.query('SELECT * FROM notification_read_states LIMIT 3;');
    if (sample.rows.length > 0) {
      console.log('\nSample read states:');
      sample.rows.forEach(row => console.log(row));
    }

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

checkReadStatesTable();