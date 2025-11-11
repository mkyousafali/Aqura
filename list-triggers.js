// List all database triggers
import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('\n🔍 Fetching database triggers...\n');

const { data: triggers, error } = await supabase.rpc('get_database_triggers');

if (error) {
  console.error('Error:', error.message);
  process.exit(1);
}

console.log(`✅ Total: ${triggers.length} triggers\n`);

// Group by table
const triggersByTable = {};
triggers.forEach(t => {
  const table = t.event_object_table || t.table_name;
  if (!triggersByTable[table]) {
    triggersByTable[table] = [];
  }
  triggersByTable[table].push({
    name: t.trigger_name,
    event: t.event_manipulation || t.event,
    timing: t.action_timing || t.timing,
    function: t.action_statement || t.function_name
  });
});

// Sort tables alphabetically
const sortedTables = Object.keys(triggersByTable).sort();

console.log('📂 Triggers by Table:\n');
console.log('='.repeat(80));

sortedTables.forEach(table => {
  console.log(`\n${table} (${triggersByTable[table].length} triggers):`);
  triggersByTable[table].forEach(t => {
    console.log(`  - ${t.name}`);
    console.log(`    ${t.timing} ${t.event} → ${t.function}`);
  });
});

console.log('\n' + '='.repeat(80));
console.log(`📈 Total: ${triggers.length} triggers across ${sortedTables.length} tables`);
console.log('\n✅ Complete!\n');
