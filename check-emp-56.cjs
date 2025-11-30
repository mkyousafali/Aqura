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
    console.log('🔍 Checking employee ID 56 fingerprint data...\n');
    
    // Get last 2 punch records for employee 56
    const { data: punchData, error: punchError } = await supabase
      .from('hr_fingerprint_transactions')
      .select('employee_id, date, time, status, branch_id, created_at')
      .eq('employee_id', '56')
      .order('created_at', { ascending: false })
      .limit(2);
    
    if (punchError) {
      console.error('❌ Error querying punch data:', punchError);
      process.exit(1);
    }
    
    if (!punchData || punchData.length === 0) {
      console.log('❌ No punch records found for employee ID 56');
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
    
    // Get branch name for the branch_id
    const branchId = punchData[0]?.branch_id;
    if (branchId) {
      const { data: branchData, error: branchError } = await supabase
        .from('branches')
        .select('id, name_en, name_ar, location_en, location_ar')
        .eq('id', branchId)
        .single();
      
      if (!branchError && branchData) {
        console.log('📋 Branch Information:');
        console.log('   ID: ' + branchData.id);
        console.log('   Name (EN): ' + branchData.name_en);
        console.log('   Name (AR): ' + branchData.name_ar);
        console.log('   Location (EN): ' + branchData.location_en);
        console.log('   Location (AR): ' + branchData.location_ar);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
})();
