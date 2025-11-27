import sql from 'mssql';

const config = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

async function checkRedeemTables() {
  try {
    const pool = await sql.connect(config);
    
    // Search for tables with "redeem" in name
    console.log('=== TABLES WITH "REDEEM" IN NAME ===\n');
    const tables = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_NAME LIKE '%redeem%' OR TABLE_NAME LIKE '%Redeem%'
      ORDER BY TABLE_NAME
    `);
    
    if (tables.recordset.length > 0) {
      console.log('Found tables:');
      tables.recordset.forEach(t => console.log(`  - ${t.TABLE_NAME}`));
    } else {
      console.log('No tables with "redeem" in name found.');
    }
    
    // Search for columns with "redeem" in name
    console.log('\n\n=== COLUMNS WITH "REDEEM" IN NAME ===\n');
    const columns = await pool.request().query(`
      SELECT 
        TABLE_NAME, 
        COLUMN_NAME, 
        DATA_TYPE,
        IS_NULLABLE
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE COLUMN_NAME LIKE '%redeem%' OR COLUMN_NAME LIKE '%Redeem%'
      ORDER BY TABLE_NAME, COLUMN_NAME
    `);
    
    if (columns.recordset.length > 0) {
      console.log('Found columns:');
      columns.recordset.forEach(c => {
        console.log(`  📊 ${c.TABLE_NAME}.${c.COLUMN_NAME} (${c.DATA_TYPE})`);
      });
      
      // Get sample data from each table with redeem columns
      console.log('\n\n=== SAMPLE DATA FROM TABLES WITH REDEEM COLUMNS ===\n');
      
      const uniqueTables = [...new Set(columns.recordset.map(c => c.TABLE_NAME))];
      
      for (const tableName of uniqueTables) {
        const redeemColumns = columns.recordset
          .filter(c => c.TABLE_NAME === tableName)
          .map(c => c.COLUMN_NAME);
        
        console.log(`\n${tableName}:`);
        console.log(`  Redeem columns: ${redeemColumns.join(', ')}`);
        
        try {
          const sampleData = await pool.request().query(`
            SELECT TOP 5 *
            FROM ${tableName}
            WHERE ${redeemColumns[0]} IS NOT NULL
            ORDER BY ${redeemColumns[0]} DESC
          `);
          
          if (sampleData.recordset.length > 0) {
            console.log(`  Records with redeem data: ${sampleData.recordset.length}`);
            console.log(`  Sample record:`, JSON.stringify(sampleData.recordset[0], null, 2));
          } else {
            console.log('  No records with redeem data yet.');
          }
        } catch (err) {
          console.log(`  Error querying: ${err.message}`);
        }
      }
    } else {
      console.log('No columns with "redeem" in name found.');
    }
    
    // Check PrivilegeCardTransaction table for redemption tracking
    console.log('\n\n=== PRIVILEGE CARD TRANSACTION TABLE (Redemption Tracking) ===\n');
    try {
      const privTrans = await pool.request().query(`
        SELECT TOP 5 *
        FROM PrivilegeCardTransaction
        ORDER BY TransactionDate DESC
      `);
      
      if (privTrans.recordset.length > 0) {
        console.log('PrivilegeCardTransaction columns:');
        console.log('  ', Object.keys(privTrans.recordset[0]).join(', '));
        console.log('\nSample transaction:');
        console.log(JSON.stringify(privTrans.recordset[0], null, 2));
      }
    } catch (err) {
      console.log('PrivilegeCardTransaction table not found or error:', err.message);
    }
    
    await pool.close();
  } catch (err) {
    console.error('Error:', err.message);
  }
}

checkRedeemTables();
