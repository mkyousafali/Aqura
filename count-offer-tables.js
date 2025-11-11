import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const env = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      env[match[1].trim()] = match[2].trim();
    }
  }
});

const supabase = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_SERVICE_ROLE_KEY);

console.log('\n📊 Checking Offer System Tables...\n');
console.log('='.repeat(80));

// Get all tables that contain 'offer' in the name
const { data: schemaData, error } = await supabase
  .rpc('get_database_schema');

if (error) {
  console.error('Error:', error);
  process.exit(1);
}

console.log('Schema data type:', typeof schemaData, Array.isArray(schemaData));

const tables = Array.isArray(schemaData) ? schemaData : (schemaData?.tables || []);
const offerTables = tables.filter(t => t.table_name && t.table_name.includes('offer'));

console.log('\n🗂️  Offer System Tables:\n');
offerTables.forEach((t, i) => {
  console.log(`${i + 1}. ${t.table_name}`);
  console.log(`   Type: ${t.table_type || 'table'}`);
  console.log('');
});

console.log('='.repeat(80));
console.log(`\n📈 Total: ${offerTables.length} offer-related tables\n`);

// Get row counts
console.log('📊 Row Counts:\n');
for (const table of offerTables) {
  const { count } = await supabase
    .from(table.table_name)
    .select('*', { count: 'exact', head: true });
  
  console.log(`   ${table.table_name}: ${count || 0} rows`);
}

console.log('\n' + '='.repeat(80));
