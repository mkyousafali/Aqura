import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      const value = match[2].trim().replace(/^["']|["']$/g, ''); // Remove quotes
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL || envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY || envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  console.error('PUBLIC_SUPABASE_URL:', supabaseUrl ? '✓' : '✗');
  console.error('SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? '✓' : '✗');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkHRTables() {
  console.log('🔍 Checking all HR-related tables (hr_*)...\n');

  // Query to get all HR tables using RPC or direct query
  const { data: tables, error: tablesError } = await supabase.rpc('get_hr_tables');

  // If RPC doesn't exist, try direct query
  if (tablesError) {
    // Try using a simple query to list HR tables
    const hrTableNames = [
      'hr_employees',
      'hr_departments',
      'hr_positions',
      'hr_position_assignments',
      'hr_levels',
      'hr_salary_components',
      'hr_salary_wages',
      'hr_employee_contacts',
      'hr_employee_documents',
      'hr_fingerprint_transactions',
      'hr_position_reporting_template'
    ];

    console.log(`📊 Checking ${hrTableNames.length} known HR tables:\n`);

    for (const tableName of hrTableNames) {
      await checkTable(tableName);
    }
  } else {
    for (const table of tables) {
      await checkTable(table.table_name);
    }
  }

  console.log('\n✅ HR tables check complete!');
}

async function checkTable(tableName) {
  try {
    // Get row count
    const { count, error: countError } = await supabase
      .from(tableName)
      .select('*', { count: 'exact', head: true });

    console.log(`\n📋 Table: ${tableName}`);
    
    if (countError) {
      console.log(`   ❌ Error: ${countError.message}`);
      return;
    }
    
    console.log(`   Records: ${count || 0}`);

    // Get sample data for tables with records
    if (count > 0) {
      const { data: sample, error: sampleError } = await supabase
        .from(tableName)
        .select('*')
        .limit(2);

      if (sample && sample.length > 0) {
        console.log(`   Columns: ${Object.keys(sample[0]).join(', ')}`);
        console.log(`   Sample record:`);
        const sampleStr = JSON.stringify(sample[0], null, 2);
        console.log(`     ${sampleStr.split('\n').join('\n     ')}`);
      }
    }

  } catch (err) {
    console.error(`   ❌ Error checking ${tableName}:`, err.message);
  }
}

checkHRTables().catch(console.error);
