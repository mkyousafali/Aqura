import sql from 'mssql';

const config = {
  server: '192.168.0.3',
  database: 'Zkurbard',
  user: 'sa',
  password: 'Polosys*123',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true
  },
  connectionTimeout: 30000,
  requestTimeout: 30000
};

async function checkRecords() {
  try {
    console.log('🔌 Connecting to ZKBioTime SQL Server...');
    await sql.connect(config);
    console.log('✅ Connected!\n');

    // Check iclock_transaction table
    const transactionResult = await sql.query`
      SELECT COUNT(*) as total_transactions,
             MIN(punch_time) as earliest_punch,
             MAX(punch_time) as latest_punch
      FROM iclock_transaction
    `;
    
    console.log('📊 iclock_transaction table:');
    console.log(`   Total Records: ${transactionResult.recordset[0].total_transactions.toLocaleString()}`);
    console.log(`   Earliest Punch: ${transactionResult.recordset[0].earliest_punch}`);
    console.log(`   Latest Punch: ${transactionResult.recordset[0].latest_punch}`);
    console.log('');

    // Check records by punch_state
    const stateResult = await sql.query`
      SELECT punch_state, COUNT(*) as count
      FROM iclock_transaction
      GROUP BY punch_state
      ORDER BY punch_state
    `;
    
    console.log('📈 Records by Punch State:');
    const stateMap = {
      '0': 'Check In',
      '1': 'Check Out',
      '2': 'Break Out',
      '3': 'Break In',
      '4': 'Overtime In',
      '5': 'Overtime Out'
    };
    
    stateResult.recordset.forEach(row => {
      const stateName = stateMap[row.punch_state] || `Unknown (${row.punch_state})`;
      console.log(`   ${row.punch_state} (${stateName}): ${row.count.toLocaleString()}`);
    });
    console.log('');

    // Check personnel_employee table
    const employeeResult = await sql.query`
      SELECT COUNT(*) as total_employees,
             COUNT(CASE WHEN emp_code IS NOT NULL THEN 1 END) as with_emp_code,
             COUNT(CASE WHEN first_name IS NOT NULL THEN 1 END) as with_name
      FROM personnel_employee
    `;
    
    console.log('👥 personnel_employee table:');
    console.log(`   Total Employees: ${employeeResult.recordset[0].total_employees}`);
    console.log(`   With emp_code: ${employeeResult.recordset[0].with_emp_code}`);
    console.log(`   With first_name: ${employeeResult.recordset[0].with_name}`);
    console.log('');

    // Check recent transactions (last 7 days)
    const recentResult = await sql.query`
      SELECT COUNT(*) as recent_count
      FROM iclock_transaction
      WHERE punch_time >= DATEADD(day, -7, GETDATE())
    `;
    
    console.log('📅 Recent Activity:');
    console.log(`   Last 7 Days: ${recentResult.recordset[0].recent_count.toLocaleString()} transactions`);

    await sql.close();
    console.log('\n✅ Check complete!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code) {
      console.error('   Error Code:', error.code);
    }
  }
}

checkRecords();
