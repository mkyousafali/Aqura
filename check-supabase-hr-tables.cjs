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

async function checkTableStructures() {
    console.log('🔍 Checking Supabase Table Structures\n');
    console.log('='.repeat(100));
    
    // Check hr_employees table
    console.log('\n📋 TABLE: hr_employees');
    console.log('='.repeat(100));
    
    const { data: hrEmployees, error: hrError, count: hrCount } = await supabase
        .from('hr_employees')
        .select('*', { count: 'exact' })
        .limit(1);

    if (hrError) {
        console.log('❌ Error querying hr_employees:', hrError.message);
    } else {
        console.log(`✅ Total Records: ${hrCount}`);
        
        if (hrEmployees && hrEmployees.length > 0) {
            console.log('\n📊 COLUMNS IN hr_employees:');
            console.log('-'.repeat(100));
            const columns = Object.keys(hrEmployees[0]);
            columns.forEach((col, index) => {
                const value = hrEmployees[0][col];
                const type = typeof value;
                const valueStr = value !== null ? String(value).substring(0, 50) : 'NULL';
                console.log(`${index + 1}. ${col.padEnd(30)} | Type: ${type.padEnd(10)} | Sample: ${valueStr}`);
            });
            
            console.log('\n📄 SAMPLE RECORD:');
            console.log('-'.repeat(100));
            console.log(JSON.stringify(hrEmployees[0], null, 2));
        } else {
            console.log('⚠️  No records found in hr_employees table');
        }
    }

    // Check hr_fingerprint_transactions table
    console.log('\n\n📋 TABLE: hr_fingerprint_transactions');
    console.log('='.repeat(100));
    
    const { data: fingerprint, error: fingerprintError, count: fingerprintCount } = await supabase
        .from('hr_fingerprint_transactions')
        .select('*', { count: 'exact' })
        .limit(1);

    if (fingerprintError) {
        console.log('❌ Error querying hr_fingerprint_transactions:', fingerprintError.message);
        console.log('Error details:', fingerprintError);
    } else {
        console.log(`✅ Total Records: ${fingerprintCount}`);
        
        if (fingerprint && fingerprint.length > 0) {
            console.log('\n📊 COLUMNS IN hr_fingerprint_transactions:');
            console.log('-'.repeat(100));
            const columns = Object.keys(fingerprint[0]);
            columns.forEach((col, index) => {
                const value = fingerprint[0][col];
                const type = typeof value;
                const valueStr = value !== null ? String(value).substring(0, 50) : 'NULL';
                console.log(`${index + 1}. ${col.padEnd(30)} | Type: ${type.padEnd(10)} | Sample: ${valueStr}`);
            });
            
            console.log('\n📄 SAMPLE RECORD:');
            console.log('-'.repeat(100));
            console.log(JSON.stringify(fingerprint[0], null, 2));
        } else {
            console.log('⚠️  No records found in hr_fingerprint_transactions table');
        }
    }

    // Get latest 5 fingerprint transactions if table exists
    if (!fingerprintError && fingerprintCount > 0) {
        console.log('\n\n📋 LATEST 5 FINGERPRINT TRANSACTIONS:');
        console.log('='.repeat(100));
        
        const { data: latestTransactions, error: latestError } = await supabase
            .from('hr_fingerprint_transactions')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(5);

        if (latestError) {
            console.log('❌ Error fetching latest transactions:', latestError.message);
        } else if (latestTransactions && latestTransactions.length > 0) {
            latestTransactions.forEach((trans, index) => {
                console.log(`\n${index + 1}. Transaction:`);
                console.log(JSON.stringify(trans, null, 2));
            });
        }
    }

    console.log('\n' + '='.repeat(100));
    console.log('✅ Table structure check completed!');
}

checkTableStructures();
