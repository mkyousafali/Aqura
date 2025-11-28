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

async function checkWorkCode() {
  try {
    const pool = await sql.connect(sqlConfig);
    
    console.log('Checking iclock_terminalworkcode table...\n');
    
    const result = await pool.request().query(`
      SELECT * FROM iclock_terminalworkcode
      ORDER BY work_code
    `);
    
    console.log('Work codes:');
    result.recordset.forEach(r => {
      console.log(JSON.stringify(r, null, 2));
    });
    
    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkWorkCode();
