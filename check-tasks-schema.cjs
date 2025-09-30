const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkTasksSchema() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Check tasks table foreign keys
    const fkResult = await client.query(`
      SELECT tc.constraint_name, tc.table_name, kcu.column_name, 
             ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
      FROM information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu 
        ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage AS ccu 
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'tasks';
    `);
    
    console.log('📋 Tasks table foreign keys:');
    fkResult.rows.forEach(row => {
      console.log(`  ${row.column_name} -> ${row.foreign_table_name}.${row.foreign_column_name} (${row.constraint_name})`);
    });

    // Check all columns in tasks table
    const columnsResult = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'tasks'
      ORDER BY ordinal_position;
    `);
    
    console.log('\n📋 Tasks table columns:');
    columnsResult.rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type} ${row.is_nullable === 'YES' ? '(nullable)' : '(not null)'}`);
    });

    // Check if users table exists
    const usersCheck = await client.query(`
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_name = 'users' AND table_schema = 'public';
    `);
    
    console.log(`\n📋 Users table exists: ${usersCheck.rows[0].count > 0 ? 'Yes' : 'No'}`);

    if (usersCheck.rows[0].count > 0) {
      // Check users table structure
      const usersResult = await client.query(`
        SELECT column_name, data_type
        FROM information_schema.columns 
        WHERE table_name = 'users'
        ORDER BY ordinal_position;
      `);
      
      console.log('\n📋 Users table columns:');
      usersResult.rows.forEach(row => {
        console.log(`  ${row.column_name}: ${row.data_type}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

checkTasksSchema();