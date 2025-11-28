import sql from 'mssql';

const config = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3',
  database: 'Zkurbard',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

try {
  console.log('🔍 Checking date range in iclock_transaction...\n');
  
  await sql.connect(config);
  
  // Get date range
  const dateRangeResult = await sql.query`
    SELECT 
      MIN(punch_time) as earliest_punch,
      MAX(punch_time) as latest_punch,
      COUNT(*) as total_records
    FROM iclock_transaction
  `;
  
  console.log('📊 Date Range Summary:');
  console.log('   Earliest punch:', dateRangeResult.recordset[0].earliest_punch);
  console.log('   Latest punch:', dateRangeResult.recordset[0].latest_punch);
  console.log('   Total records:', dateRangeResult.recordset[0].total_records);
  
  // Check specific date ranges
  console.log('\n📅 Records by Date Range:');
  
  const ranges = [
    { name: 'October 2025', start: '2025-10-01', end: '2025-10-31' },
    { name: 'November 2025', start: '2025-11-01', end: '2025-11-30' },
    { name: 'Last 30 days', start: new Date(Date.now() - 30*24*60*60*1000).toISOString().split('T')[0], end: new Date().toISOString().split('T')[0] },
    { name: 'Last 7 days', start: new Date(Date.now() - 7*24*60*60*1000).toISOString().split('T')[0], end: new Date().toISOString().split('T')[0] }
  ];
  
  for (const range of ranges) {
    const result = await sql.query`
      SELECT COUNT(*) as count
      FROM iclock_transaction
      WHERE punch_time >= ${range.start} AND punch_time <= ${range.end}
    `;
    console.log(`   ${range.name} (${range.start} to ${range.end}): ${result.recordset[0].count} records`);
  }
  
  // Check if there's data starting from 2025-10-22
  const oct22Result = await sql.query`
    SELECT COUNT(*) as count
    FROM iclock_transaction
    WHERE punch_time >= '2025-10-22'
  `;
  console.log(`\n🎯 From Oct 22, 2025 onwards: ${oct22Result.recordset[0].count} records`);
  
  // Show sample records from different dates
  console.log('\n📋 Sample Records:');
  const sampleResult = await sql.query`
    SELECT TOP 5 
      punch_time,
      emp_code,
      punch_state,
      terminal_sn
    FROM iclock_transaction
    ORDER BY punch_time DESC
  `;
  
  sampleResult.recordset.forEach((record, i) => {
    console.log(`   ${i+1}. ${record.punch_time} - Employee ${record.emp_code} - State ${record.punch_state}`);
  });
  
  await sql.close();
  console.log('\n✅ Check complete!');
  
} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
