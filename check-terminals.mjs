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
  console.log('🔍 Checking terminal_sn values...\n');
  
  await sql.connect(config);
  
  // Get all unique terminal_sn values with counts
  const terminalResult = await sql.query`
    SELECT 
      terminal_sn,
      COUNT(*) as record_count,
      MIN(punch_time) as earliest,
      MAX(punch_time) as latest
    FROM iclock_transaction
    GROUP BY terminal_sn
    ORDER BY record_count DESC
  `;
  
  console.log('📊 Terminals in Database:');
  terminalResult.recordset.forEach((term, i) => {
    console.log(`   ${i+1}. Terminal: "${term.terminal_sn}"`);
    console.log(`      Records: ${term.record_count}`);
    console.log(`      Date Range: ${term.earliest} to ${term.latest}\n`);
  });
  
  // Check for records WITHOUT terminal_sn filter from Oct 22
  const noFilterResult = await sql.query`
    SELECT COUNT(*) as count
    FROM iclock_transaction
    WHERE punch_time >= '2025-10-22'
  `;
  console.log(`✅ Total records from Oct 22 (NO terminal filter): ${noFilterResult.recordset[0].count}`);
  
  // Check with a specific terminal_sn if you know what the app is using
  // Replace 'YOUR_TERMINAL_SN' with actual value from biometric config
  const specificTerminalResult = await sql.query`
    SELECT 
      terminal_sn,
      COUNT(*) as count
    FROM iclock_transaction
    WHERE punch_time >= '2025-10-22'
    GROUP BY terminal_sn
  `;
  
  console.log('\n📋 Records from Oct 22 by Terminal:');
  specificTerminalResult.recordset.forEach(term => {
    console.log(`   Terminal "${term.terminal_sn}": ${term.count} records`);
  });
  
  await sql.close();
  console.log('\n✅ Check complete!');
  
} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
