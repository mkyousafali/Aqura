const sql = require('mssql');

const config = {
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  user: 'sa',
  password: 'Polosys*123',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

async function getSalesDateRange() {
  try {
    const pool = await sql.connect(config);
    
    const result = await pool.request().query(`
      SELECT 
        MIN(CAST(TransactionDate AS DATE)) AS FirstDate,
        MAX(CAST(TransactionDate AS DATE)) AS LastDate,
        COUNT(DISTINCT CAST(TransactionDate AS DATE)) AS TotalDays
      FROM InvTransactionMaster
      WHERE VoucherType = 'SI'
    `);
    
    const data = result.recordset[0];
    console.log('\n📅 Sales Data Range:');
    console.log('==================');
    console.log('First Sale Date:', data.FirstDate);
    console.log('Last Sale Date:', data.LastDate);
    console.log('Total Days with Sales:', data.TotalDays);
    console.log('==================\n');
    
    await pool.close();
  } catch (err) {
    console.error('Error:', err.message);
  }
}

getSalesDateRange();
