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

async function checkPunchStateDetails() {
  try {
    const pool = await sql.connect(sqlConfig);
    
    console.log('Getting sample records for each punch_state...\n');
    
    // Get samples for each punch_state
    for (let state of [0, 1, 4, 5]) {
      console.log(`\n=== punch_state ${state} ===`);
      
      const result = await pool.request().query(`
        SELECT TOP 3
          emp_code,
          punch_time,
          punch_state,
          terminal_sn,
          terminal_alias,
          area_alias
        FROM iclock_transaction
        WHERE punch_state = ${state}
        ORDER BY punch_time DESC
      `);
      
      result.recordset.forEach((r, i) => {
        console.log(`${i + 1}. Employee: ${r.emp_code}, Time: ${r.punch_time.toLocaleString()}, Device: ${r.terminal_alias || r.terminal_sn}`);
      });
    }
    
    // Check if there's any documentation or related tables
    console.log('\n\n=== Checking for attendance work code table ===');
    const tablesResult = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_NAME LIKE '%work%' 
         OR TABLE_NAME LIKE '%code%'
         OR TABLE_NAME LIKE '%attendance%'
         OR TABLE_NAME LIKE '%state%'
      ORDER BY TABLE_NAME
    `);
    
    console.log('Related tables:');
    tablesResult.recordset.forEach(t => {
      console.log(`  - ${t.TABLE_NAME}`);
    });
    
    await pool.close();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkPunchStateDetails();
