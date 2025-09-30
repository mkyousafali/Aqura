const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function addIsReadColumn() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Read and apply the schema change
    const schema = fs.readFileSync('add-is-read-column.sql', 'utf8');
    await client.query(schema);
    
    console.log('is_read column added successfully!');
    
    // Verify the change
    const columns = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'notification_read_states' 
      ORDER BY ordinal_position;
    `);
    
    console.log('\nUpdated notification_read_states table columns:');
    columns.rows.forEach(row => {
      console.log(`- ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable}, default: ${row.column_default})`);
    });

    // Check updated data
    const sample = await client.query('SELECT * FROM notification_read_states LIMIT 3;');
    if (sample.rows.length > 0) {
      console.log('\nSample read states after update:');
      sample.rows.forEach(row => console.log(row));
    }

    await client.end();
  } catch (err) {
    console.error('Error:', err.message);
    await client.end();
  }
}

addIsReadColumn();