import { createClient } from '@supabase/supabase-js';
import sql from 'mssql';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Biometric config
const bioConfig = {
  server_ip: '192.168.0.3',
  database_name: 'Zkurbard',
  username: 'sa',
  password: 'Polosys*123',
  branch_id: 3,
  device_id: 'ZK-MAIN',
  terminal_sn: null
};

async function testHistoricalSync() {
  console.log('🔄 Testing biometric historical sync...\n');

  try {
    // Connect to ZKBioTime
    const sqlConfig = {
      server: bioConfig.server_ip,
      database: bioConfig.database_name,
      user: bioConfig.username,
      password: bioConfig.password,
      options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectionTimeout: 30000,
        requestTimeout: 30000
      },
      pool: {
        max: 5,
        min: 1,
        idleTimeoutMillis: 30000
      }
    };

    console.log('Connecting to ZKBioTime...');
    const pool = await sql.connect(sqlConfig);
    console.log('✅ Connected!\n');

    // Query transactions
    let transactionQuery = `
      SELECT TOP 5
        emp_code AS employee_id,
        punch_time,
        punch_state,
        terminal_sn,
        terminal_alias,
        area_alias
      FROM iclock_transaction
      WHERE punch_time >= '2025-11-27'
      ORDER BY punch_time DESC
    `;

    const result = await pool.request().query(transactionQuery);
    const transactions = result.recordset;

    console.log(`Found ${transactions.length} sample transactions\n`);
    
    // Debug: Check raw data
    console.log('Raw transaction sample:');
    console.log('punch_state:', transactions[0].punch_state, 'type:', typeof transactions[0].punch_state);
    console.log('Full record:', JSON.stringify(transactions[0], null, 2));
    console.log('\n');

    // Transform transactions (same as sync app)
    const transformedTransactions = transactions.map(t => {
      const punchDate = new Date(t.punch_time);
      
      // Convert punch_state to number (SQL Server returns it as string)
      const punchState = parseInt(t.punch_state, 10);
      
      // Map punch state to status text
      let status;
      switch(punchState) {
        case 0: status = 'Check In'; break;
        case 1: status = 'Check Out'; break;
        case 2: status = 'Break Out'; break;
        case 3: status = 'Break In'; break;
        case 4: status = 'Overtime In'; break;
        case 5: status = 'Overtime Out'; break;
        default: 
          console.warn(`Unknown punch_state: ${t.punch_state}`);
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

    console.log('Sample transformed record:');
    console.log(JSON.stringify(transformedTransactions[0], null, 2));
    console.log('\n');

    // Try insert
    console.log('Attempting insert...');
    const { data, error } = await supabase
      .from('hr_fingerprint_transactions')
      .insert(transformedTransactions)
      .select();

    if (error) {
      console.error('❌ INSERT FAILED:');
      console.error('Message:', error.message);
      console.error('Code:', error.code);
      console.error('Details:', error.details);
      console.error('Hint:', error.hint);
      console.error('\nFull error:', JSON.stringify(error, null, 2));
    } else {
      console.log(`✅ SUCCESS! Inserted ${data?.length || 0} records`);
      console.log('Sample inserted record:');
      console.log(JSON.stringify(data[0], null, 2));
    }

    await pool.close();

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

testHistoricalSync();
