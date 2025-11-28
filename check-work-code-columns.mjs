import sql from 'mssql';

const sqlConfig = {
  server: '192.168.0.3',
  database: 'Zkurbard',
  user: 'sa',
  password: 'Polosys*123',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true,
  }
};

async function checkWorkCodeStructure() {
  try {
    const pool = await sql.connect(sqlConfig);
    
    console.log('Checking iclock_terminalworkcode columns...\n');
    
    const result = await pool.request().query(`
      SELECT COLUMN_NAME, DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'iclock_terminalworkcode'
      ORDER BY ORDINAL_POSITION
    `);
    
    console.log('Columns:');
    result.recordset.forEach(r => {
      console.log(`  ${r.COLUMN_NAME} (${r.DATA_TYPE})`);
    });
    
    // Get sample data
    console.log('\n\nSample data:');
    const dataResult = await pool.request().query(`
      SELECT TOP 10 * FROM iclock_terminalworkcode
    `);
    
    dataResult.recordset.forEach((r, i) => {
      console.log(`\n${i + 1}.`, JSON.stringify(r, null, 2));
    });
    
    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkWorkCodeStructure();
