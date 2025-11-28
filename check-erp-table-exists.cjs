const sql = require('mssql');

async function checkERPTable() {
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

    console.log('Connecting to URBAN2_2025...');
    const pool = await sql.connect(config);

    // Check if table exists
    const tableCheck = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_NAME = 'InvTransactionMaster'
    `);

    if (tableCheck.recordset.length > 0) {
      console.log('✅ Table InvTransactionMaster EXISTS');
      
      // Test query
      const result = await pool.request().query(`
        SELECT TOP 1 * FROM InvTransactionMaster WHERE VoucherType = 'SI'
      `);
      
      console.log('✅ Can query table successfully');
      console.log('Sample columns:', Object.keys(result.recordset[0] || {}));
    } else {
      console.log('❌ Table InvTransactionMaster does NOT exist');
      
      // Show similar tables
      const similar = await pool.request().query(`
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME LIKE '%InvTransaction%'
      `);
      
      console.log('\nSimilar tables:');
      similar.recordset.forEach(row => {
        console.log('  -', row.TABLE_NAME);
      });
    }

    await pool.close();
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

checkERPTable();
