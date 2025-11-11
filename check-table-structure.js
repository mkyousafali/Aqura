// Check table structure - Get column names and types
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
      const value = match[2].trim();
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Get table name from command line argument
const tableName = process.argv[2] || 'hr_employees';

console.log(`\n🔍 Checking structure of table: ${tableName}`);
console.log('='.repeat(60));

// Get one record to see all columns
const { data, error, count } = await supabase
  .from(tableName)
  .select('*', { count: 'exact' })
  .limit(1);

if (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}

console.log(`\n📊 Total records: ${count}`);

if (data && data.length > 0) {
  console.log('\n📋 Column Structure:');
  console.log('-'.repeat(60));
  
  const columns = Object.keys(data[0]);
  columns.forEach((col, idx) => {
    const value = data[0][col];
    const type = value === null ? 'null' : typeof value;
    const preview = value === null ? 'NULL' : 
                   typeof value === 'string' ? `"${value.substring(0, 30)}${value.length > 30 ? '...' : ''}"` :
                   typeof value === 'object' ? JSON.stringify(value).substring(0, 30) :
                   value;
    console.log(`${idx + 1}. ${col.padEnd(30)} | ${type.padEnd(10)} | ${preview}`);
  });

  console.log('\n📄 Sample Record (Full):');
  console.log('-'.repeat(60));
  console.log(JSON.stringify(data[0], null, 2));
} else {
  console.log('\n⚠️ No records found in table');
}

console.log('\n✅ Structure check complete!\n');
