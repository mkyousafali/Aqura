const sql = require('mssql');

async function checkTables() {
  try {
    const config = {
      server: '192.168.0.3',
      database: 'URBAN2_2025',
      user: 'sa',
      password: 'Polosys*123',
      options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true
      }
    };

    console.log('Connecting to ERP database...');
    const pool = await sql.connect(config);

    // List all tables
    const result = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_NAME LIKE '%Transaction%' OR TABLE_NAME LIKE '%Invoice%' OR TABLE_NAME LIKE '%Sales%'
      ORDER BY TABLE_NAME
    `);

    console.log('\nTables with Transaction/Invoice/Sales:');
    console.log('=====================================');
    result.recordset.forEach(row => {
      console.log(row.TABLE_NAME);
    });

    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkTables();
