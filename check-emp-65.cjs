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

(async () => {
  try {
    console.log('🔍 Checking employee ID 65 fingerprint data...\n');
    
    // Get last 2 punch records for employee 65
    const { data: punchData, error: punchError } = await supabase
      .from('hr_fingerprint_transactions')
      .select('employee_id, date, time, status, branch_id, created_at')
      .eq('employee_id', '65')
      .order('created_at', { ascending: false })
      .limit(2);
    
    if (punchError) {
      console.error('❌ Error querying punch data:', punchError);
      process.exit(1);
    }
    
    if (!punchData || punchData.length === 0) {
      console.log('❌ No punch records found for employee ID 65');
      process.exit(0);
    }
    
    console.log('✅ Found', punchData.length, 'punch records:\n');
    
    // Display punch records
    punchData.forEach((record, index) => {
      console.log('📍 Punch #' + (index + 1) + ':');
      console.log('   Date: ' + record.date);
      console.log('   Time: ' + record.time);
      console.log('   Status: ' + record.status);
      console.log('   Branch ID: ' + record.branch_id);
      console.log('   Created At: ' + record.created_at + '\n');
    });
    
    // Show timezone conversion
    console.log('\n🔄 TIMEZONE CONVERSION:');
    punchData.forEach((record, index) => {
      const saudiDate = new Date(record.date + 'T' + record.time);
      const utcTime = new Date(saudiDate.getTime() - (3 * 60 * 60 * 1000));
      console.log('Punch #' + (index + 1) + ':');
      console.log('   Saudi: ' + record.time + ' → UTC: ' + utcTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }));
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
})();
