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

async function checkPunchStates() {
  try {
    const pool = await sql.connect(sqlConfig);
    
    console.log('Checking distinct punch_state values...\n');
    
    const result = await pool.request().query(`
      SELECT 
        punch_state,
        COUNT(*) as count
      FROM iclock_transaction
      GROUP BY punch_state
      ORDER BY punch_state
    `);
    
    console.log('Punch state distribution:');
    result.recordset.forEach(r => {
      console.log(`  punch_state ${r.punch_state}: ${r.count} transactions`);
    });
    
    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkPunchStates();
