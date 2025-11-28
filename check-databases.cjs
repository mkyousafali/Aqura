const sql = require('mssql');

async function checkDatabases() {
  try {
    const config = {
      server: '192.168.0.3',
      user: 'sa',
      password: 'Polosys*123',
      options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true
      }
    };

    console.log('Connecting to SQL Server...');
    const pool = await sql.connect(config);

    // List all databases
    const result = await pool.request().query(`
      SELECT name 
      FROM sys.databases 
      WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
      ORDER BY name
    `);

    console.log('\nAvailable Databases:');
    console.log('====================');
    result.recordset.forEach(row => {
      console.log(row.name);
    });

    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkDatabases();
