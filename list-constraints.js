// List all database constraints
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

console.log('\n🔍 Fetching database constraints...\n');

// Try to get constraints using RPC
const { data: constraints, error } = await supabase.rpc('get_database_constraints');

if (error || !constraints) {
  console.log('⚠️  get_database_constraints function not available.');
  console.log('📝 Note: Database constraints can be viewed directly in Supabase Dashboard.\n');
  console.log('Alternative: Check constraints per table using check-table-structure.js\n');
  console.log(`Error: ${error?.message || 'No data returned'}\n`);
  process.exit(1);
}

console.log('\n✅ Retrieved constraint data\n');

// Group by table and type
const byTable = {};
const byType = {};

constraints.forEach(tc => {
  const table = tc.table_name;
  const type = tc.constraint_type;
  
  if (!byTable[table]) byTable[table] = [];
  byTable[table].push(tc);
  
  if (!byType[type]) byType[type] = 0;
  byType[type]++;
});

console.log('📂 Constraints by Table:\n');
console.log('='.repeat(80));

Object.entries(byTable).sort().forEach(([table, tableConstraints]) => {
  console.log(`\n${table} (${tableConstraints.length} constraints):`);
  
  // Group by constraint type for better readability
  const byTypeInTable = {};
  tableConstraints.forEach(c => {
    if (!byTypeInTable[c.constraint_type]) byTypeInTable[c.constraint_type] = [];
    byTypeInTable[c.constraint_type].push(c);
  });
  
  // Display PRIMARY KEY first
  if (byTypeInTable['PRIMARY KEY']) {
    byTypeInTable['PRIMARY KEY'].forEach(c => {
      console.log(`  PRIMARY KEY: ${c.column_name || c.constraint_name}`);
    });
  }
  
  // Then FOREIGN KEY
  if (byTypeInTable['FOREIGN KEY']) {
    byTypeInTable['FOREIGN KEY'].forEach(c => {
      const ref = c.foreign_table ? ` → ${c.foreign_table}.${c.foreign_column}` : '';
      console.log(`  FOREIGN KEY: ${c.column_name}${ref}`);
    });
  }
  
  // Then UNIQUE
  if (byTypeInTable['UNIQUE']) {
    byTypeInTable['UNIQUE'].forEach(c => {
      console.log(`  UNIQUE: ${c.column_name || c.constraint_name}`);
    });
  }
  
  // Then CHECK
  if (byTypeInTable['CHECK']) {
    byTypeInTable['CHECK'].forEach(c => {
      const clause = c.check_clause ? ` (${c.check_clause})` : '';
      console.log(`  CHECK: ${c.constraint_name}${clause}`);
    });
  }
});

console.log('\n' + '='.repeat(80));
console.log('\n📊 Summary by Type:');
Object.entries(byType).sort().forEach(([type, count]) => {
  console.log(`  ${type}: ${count}`);
});
console.log(`\n📈 Total: ${constraints.length} constraints`);

console.log('\n✅ Complete!\n');
