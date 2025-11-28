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
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL || envVars.PUBLIC_SUPABASE_URL;
const supabaseKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY || envVars.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

console.log('🧪 Testing Employee Sync Logic\n');

const bioConfig = {
  server_ip: '192.168.0.3',
  database_name: 'Zkurbard',
  username: 'sa',
  password: 'Polosys*123',
  branch_id: 3
};

try {
  // Connect to ZKBioTime
  console.log('📡 Connecting to ZKBioTime...');
  const sqlConfig = {
    server: bioConfig.server_ip,
    database: bioConfig.database_name,
    user: bioConfig.username,
    password: bioConfig.password,
    options: {
      encrypt: false,
      trustServerCertificate: true
    }
  };
  
  const pool = await sql.connect(sqlConfig);
  console.log('✅ Connected\n');

  // Query employees
  const employeeQuery = `
    SELECT 
      emp_code AS employee_id,
      first_name AS name
    FROM personnel_employee
    WHERE emp_code IS NOT NULL AND first_name IS NOT NULL
  `;

  console.log('🔍 Querying ZKBioTime employees...');
  const employeeResult = await pool.request().query(employeeQuery);
  const employees = employeeResult.recordset;
  
  console.log(`✅ Found ${employees.length} employees in ZKBioTime\n`);
  console.log('👤 Sample employees:');
  employees.slice(0, 5).forEach((emp, i) => {
    console.log(`   ${i+1}. ID: ${emp.employee_id}, Name: ${emp.name}`);
  });

  // Test upsert to Supabase (just first 3 employees)
  console.log('\n🧪 Testing upsert to Supabase (first 3 employees)...');
  
  for (const emp of employees.slice(0, 3)) {
    const { data, error } = await supabase
      .from('hr_employees')
      .upsert({
        employee_id: emp.employee_id,
        name: emp.name,
        branch_id: bioConfig.branch_id
      }, {
        onConflict: 'employee_id,branch_id'
      })
      .select();

    if (error) {
      console.error(`   ❌ Failed for ${emp.employee_id}: ${error.message}`);
      console.error('      Error code:', error.code);
      console.error('      Error details:', error.details);
    } else {
      console.log(`   ✅ Upserted: ${emp.employee_id} - ${emp.name}`);
    }
  }

  // Check current count in hr_employees for branch 3
  const { count } = await supabase
    .from('hr_employees')
    .select('*', { count: 'exact', head: true })
    .eq('branch_id', 3);

  console.log(`\n📊 Total employees in hr_employees (Branch 3): ${count}`);
  
  await pool.close();
  console.log('\n✅ Test complete!');
  
} catch (error) {
  console.error('❌ Error:', error.message);
  if (error.code) console.error('   Code:', error.code);
  if (error.details) console.error('   Details:', error.details);
  process.exit(1);
}
