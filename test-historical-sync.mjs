import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL || envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY || envVars.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in frontend/.env');
  console.error('   Looking for: VITE_SUPABASE_URL and VITE_SUPABASE_SERVICE_ROLE_KEY');
  console.error('   Found vars:', Object.keys(envVars));
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🧪 Testing Historical Sync Logic\n');

// Biometric connection config
const bioConfig = {
  server_ip: '192.168.0.3',
  database_name: 'Zkurbard',
  username: 'sa',
  password: 'Polosys*123',
  terminal_sn: 'MFP3243700773',  // Use actual terminal
  branch_id: 3
};

const startDate = '2025-10-22';

try {
  // Connect to ZKBioTime SQL Server
  console.log('📡 Connecting to ZKBioTime...');
  const sqlConfig = {
    server: bioConfig.server_ip,
    database: bioConfig.database_name,
    user: bioConfig.username,
    password: bioConfig.password,
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true
    }
  };
  
  const pool = await sql.connect(sqlConfig);
  console.log('✅ Connected to ZKBioTime\n');

  // Build query
  const queryDate = new Date(startDate);
  console.log('🔍 Query Parameters:');
  console.log('   Start Date (raw):', startDate);
  console.log('   Start Date (parsed):', queryDate);
  console.log('   Start Date (ISO):', queryDate.toISOString());
  console.log('   Terminal S/N:', bioConfig.terminal_sn);
  console.log('   Branch ID:', bioConfig.branch_id);
  console.log('');

  let transactionQuery = `
    SELECT 
      emp_code AS employee_id,
      punch_time,
      punch_state,
      terminal_sn,
      terminal_alias,
      area_alias
    FROM iclock_transaction
    WHERE punch_time >= @startDate
  `;

  if (bioConfig.terminal_sn) {
    transactionQuery += ` AND terminal_sn = @terminal_sn`;
  }

  transactionQuery += ` ORDER BY punch_time ASC`;

  console.log('📋 SQL Query:');
  console.log(transactionQuery);
  console.log('');

  const request = pool.request();
  request.input('startDate', sql.DateTime, queryDate);
  
  if (bioConfig.terminal_sn) {
    request.input('terminal_sn', sql.NVarChar, bioConfig.terminal_sn);
  }

  console.log('⏳ Executing query...');
  const transactionResult = await request.query(transactionQuery);
  const transactions = transactionResult.recordset;

  console.log(`✅ Query returned ${transactions.length} records\n`);

  if (transactions.length === 0) {
    console.log('❌ No records found! Check:');
    console.log('   - Date range is correct');
    console.log('   - Terminal S/N exists in database');
    process.exit(1);
  }

  console.log('📊 First 3 records from SQL Server:');
  transactions.slice(0, 3).forEach((t, i) => {
    console.log(`   ${i+1}. Employee: ${t.employee_id}, Time: ${t.punch_time}, State: "${t.punch_state}" (type: ${typeof t.punch_state})`);
  });
  console.log('');

  // Transform records (with parseInt fix)
  console.log('🔄 Transforming records with parseInt() fix...');
  const transformedTransactions = transactions.map(t => {
    const punchDate = new Date(t.punch_time);
    
    // CRITICAL: Convert STRING to NUMBER
    const punchState = parseInt(t.punch_state, 10);
    let status;
    switch(punchState) {
      case 0: status = 'Check In'; break;
      case 1: status = 'Check Out'; break;
      case 2: status = 'Break Out'; break;
      case 3: status = 'Break In'; break;
      case 4: status = 'Overtime In'; break;
      case 5: status = 'Overtime Out'; break;
      default: 
        console.warn(`   ⚠️ Unknown punch_state: "${t.punch_state}" (parsed: ${punchState}) for employee ${t.employee_id}`);
        return null;
    }
    
    return {
      employee_id: t.employee_id,
      date: punchDate.toISOString().split('T')[0],
      time: punchDate.toTimeString().split(' ')[0],
      status: status,
      device_id: t.terminal_sn || t.terminal_alias || 'Unknown',
      location: t.area_alias || 'Unknown',
      branch_id: bioConfig.branch_id,
      created_at: new Date().toISOString()
    };
  }).filter(t => t !== null);

  console.log(`✅ Transform complete: ${transformedTransactions.length} valid records (filtered ${transactions.length - transformedTransactions.length})\n`);

  if (transformedTransactions.length === 0) {
    console.log('❌ ALL records filtered out! punch_state values not matching switch cases.');
    console.log('   Check if parseInt() is working correctly.');
    process.exit(1);
  }

  console.log('📋 First 3 transformed records:');
  transformedTransactions.slice(0, 3).forEach((t, i) => {
    console.log(`   ${i+1}. ${JSON.stringify(t, null, 2)}`);
  });
  console.log('');

  // Test insert with just 5 records
  console.log('🧪 Testing insert with 5 sample records...');
  const testBatch = transformedTransactions.slice(0, 5);
  
  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .insert(testBatch)
    .select();

  if (error) {
    console.error('❌ INSERT FAILED:');
    console.error('   Error message:', error.message);
    console.error('   Error code:', error.code);
    console.error('   Error details:', error.details);
    console.error('   Error hint:', error.hint);
    console.error('\n   Sample record that failed:');
    console.error(JSON.stringify(testBatch[0], null, 2));
    process.exit(1);
  }

  console.log('✅ INSERT SUCCESS!');
  console.log(`   Inserted ${data.length} records`);
  console.log('\n📊 Returned data sample:');
  console.log(JSON.stringify(data[0], null, 2));

  // Check total count in table
  const { count } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*', { count: 'exact', head: true });

  console.log(`\n📈 Total records in hr_fingerprint_transactions: ${count}`);
  console.log('\n✅ Test complete! The logic works correctly.');
  console.log('   Problem: The .exe is using OLD CODE without parseInt() fix.');
  console.log('   Solution: Need to rebuild the package with updated main.js');

  await pool.close();
  
} catch (error) {
  console.error('❌ Error:', error.message);
  if (error.stack) {
    console.error('Stack:', error.stack);
  }
  process.exit(1);
}
