import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load environment variables from frontend/.env
const envPath = path.join(__dirname, '..', 'frontend', '.env');
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

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Get employee ID from command line args or use default
const employeeId = process.argv[2] || 'UARDS11';

async function checkPunches() {
  console.log(`\n📊 Checking last 2 punches for employee: ${employeeId}\n`);
  
  // Get punches from last 48 hours only
  const twoDaysAgo = new Date();
  twoDaysAgo.setHours(twoDaysAgo.getHours() - 48);
  const cutoffDate = twoDaysAgo.toISOString().split('T')[0];
  
  const { data, error } = await supabase
    .from('hr_fingerprint_transactions')
    .select('*')
    .eq('employee_id', employeeId)
    .gte('date', cutoffDate);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  if (!data || data.length === 0) {
    console.log(`❌ No punch records found for employee ${employeeId}`);
    return;
  }

  // Sort by combining date and time to get truly latest punches
  const sortedData = data.sort((a, b) => {
    const dateTimeA = new Date(`${a.date}T${a.time}`);
    const dateTimeB = new Date(`${b.date}T${b.time}`);
    return dateTimeB - dateTimeA; // Descending order (newest first)
  }).slice(0, 2); // Take only the latest 2

  console.log(`✅ Found ${data.length} total punch record(s):\n`);
  
  // Show raw database records first
  console.log('Raw data from database (as stored in UTC):');
  data.forEach((punch, index) => {
    console.log(`  ${index + 1}. Date: ${punch.date}, Time: ${punch.time} UTC, Status: ${punch.status}`);
  });
  
  // Show sorted records
  console.log('\nAll records sorted by date+time:');
  data.sort((a, b) => {
    const dateTimeA = new Date(`${a.date}T${a.time}`);
    const dateTimeB = new Date(`${b.date}T${b.time}`);
    return dateTimeB - dateTimeA;
  }).forEach((punch, index) => {
    const [h, m, s] = punch.time.split(':').map(Number);
    let sh = h - 3;
    if (sh < 0) sh += 24;
    const p = sh >= 12 ? 'PM' : 'AM';
    const dh = sh % 12 || 12;
    const t12 = `${dh}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')} ${p}`;
    console.log(`  ${index + 1}. ${punch.date} ${t12} Saudi (UTC: ${punch.time}) - ${punch.status}`);
  });
  console.log(`\nShowing latest 2:\n`);
  
  sortedData.forEach((punch, index) => {
    // Parse time and subtract 3 hours (UTC to Saudi time)
    const [hours, minutes, seconds] = punch.time.split(':').map(Number);
    let saudiHours = hours - 3;
    if (saudiHours < 0) saudiHours += 24;
    
    // Convert to 12-hour format
    const period = saudiHours >= 12 ? 'PM' : 'AM';
    const displayHours = saudiHours % 12 || 12;
    const time12hr = `${displayHours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${period}`;
    
    console.log(`Punch #${index + 1}:`);
    console.log(`  Employee ID: ${punch.employee_id}`);
    console.log(`  Name: ${punch.name || 'N/A'}`);
    console.log(`  Date: ${punch.date}`);
    console.log(`  Time: ${time12hr} (Saudi Time)`);
    console.log(`  Status: ${punch.status}`);
    console.log(`  Location: ${punch.location || 'N/A'}`);
    console.log(`  Device ID: ${punch.device_id || 'N/A'}`);
    console.log(`  Branch ID: ${punch.branch_id}`);
    console.log(`  Created At: ${punch.created_at}`);
    console.log('');
  });
}

checkPunches();
