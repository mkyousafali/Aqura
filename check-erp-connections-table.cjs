const { readFileSync } = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables from frontend/.env
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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkERPConnectionsTable() {
  try {
    console.log('🔍 Checking erp_connections table structure in Supabase...\n');
    
    // Get sample data from erp_connections
    const { data, error, count } = await supabase
      .from('erp_connections')
      .select('*', { count: 'exact' })
      .limit(2);

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    console.log('📊 TABLE: erp_connections');
    console.log('=' .repeat(80));
    console.log(`   Total records: ${count}\n`);
    
    if (data && data.length > 0) {
      console.log('📌 COLUMNS (from sample data):');
      const columns = Object.keys(data[0]);
      columns.forEach(col => {
        console.log(`   - ${col}`);
      });
      
      console.log('\n📄 SAMPLE RECORDS:\n');
      data.forEach((record, index) => {
        console.log(`${index + 1}. Record ID: ${record.id}`);
        Object.entries(record).forEach(([key, value]) => {
          console.log(`   ${key}: ${value}`);
        });
        console.log('-'.repeat(80));
      });
    } else {
      console.log('⚠️  No records found in erp_connections table');
    }

    console.log('\n✅ PROPOSED biometric_connections TABLE STRUCTURE:');
    console.log('=' .repeat(80));
    console.log('Based on erp_connections, but with modifications:\n');
    console.log('📋 Columns to KEEP (similar to ERP):');
    console.log('   - id (primary key)');
    console.log('   - branch_id (references branches.id)');
    console.log('   - branch_name (branch display name)');
    console.log('   - server_ip (biometric server IP)');
    console.log('   - server_name (SQL Server instance name)');
    console.log('   - database_name (ZKBioTime database name)');
    console.log('   - username (SQL Server username)');
    console.log('   - password (SQL Server password)');
    console.log('   - device_id (computer name running sync app)');
    console.log('   - is_active (enable/disable sync)');
    console.log('   - last_sync_at (timestamp)');
    console.log('   - created_at (timestamp)');
    console.log('   - updated_at (timestamp)');
    
    console.log('\n❌ Column to REMOVE:');
    console.log('   - erp_branch_id (not needed for biometric)');
    
    console.log('\n➕ Column to ADD:');
    console.log('   - terminal_sn (Terminal Serial Number from ZKBioTime)');
    console.log('     Example: "MFP3243700773"');
    console.log('     Purpose: Track which biometric device belongs to this branch');
    
    console.log('\n🔑 UNIQUE CONSTRAINT:');
    console.log('   - UNIQUE(branch_id, device_id) - One biometric config per branch per PC');

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkERPConnectionsTable();
