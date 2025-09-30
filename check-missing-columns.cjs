const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkMissingColumns() {
  try {
    await client.connect();
    console.log('Checking for missing columns...');

    const result = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'tasks' 
      AND column_name IN ('task_type', 'finish_criteria');
    `);
    
    console.log('Found columns:', result.rows.map(r => r.column_name));
    
    const requiredColumns = ['task_type', 'finish_criteria'];
    const existingColumns = result.rows.map(r => r.column_name);
    const missingColumns = requiredColumns.filter(col => !existingColumns.includes(col));
    
    console.log('Missing columns:', missingColumns);

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

checkMissingColumns();