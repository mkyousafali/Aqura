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

console.log('🔒 UNIQUE CONSTRAINT SETUP');
console.log('==========================\n');

console.log('📖 WHAT IS A UNIQUE CONSTRAINT?');
console.log('--------------------------------');
console.log('A UNIQUE constraint is like a rule that prevents duplicate records.\n');
console.log('Think of it like this:');
console.log('  ❌ Without constraint: Database accepts everything → duplicates pile up');
console.log('  ✅ With constraint: Database checks first → rejects duplicates automatically\n');

console.log('📋 FOR hr_fingerprint_transactions TABLE:');
console.log('------------------------------------------');
console.log('We will create a rule that says:\n');
console.log('  "You CANNOT insert a record if another record already exists with');
console.log('   the SAME combination of:');
console.log('     • employee_id (who punched)');
console.log('     • date (what day)');
console.log('     • time (what time)');
console.log('     • status (Check In/Out)');
console.log('     • branch_id (which branch)"\n');

console.log('🎯 PRACTICAL EXAMPLE:');
console.log('----------------------');
console.log('If database already has:');
console.log('  Employee 29 | 2025-11-28 | 20:27:24 | Check Out | Branch 3\n');
console.log('And you try to insert:');
console.log('  Employee 29 | 2025-11-28 | 20:27:24 | Check Out | Branch 3\n');
console.log('❌ Database will REJECT it and say: "This record already exists!"\n');

console.log('But if you try to insert:');
console.log('  Employee 29 | 2025-11-28 | 20:28:00 | Check Out | Branch 3');
console.log('                              ^^^^^^^ Different time\n');
console.log('✅ Database will ACCEPT it because the time is different!\n');

console.log('💡 WHY THIS HELPS:');
console.log('-------------------');
console.log('  1. Prevents sync from creating duplicates (automatic protection)');
console.log('  2. Even if sync logic has bugs, database won\'t allow duplicates');
console.log('  3. Keeps data clean without manual checking every time\n');

console.log('⚙️  CREATING THE CONSTRAINT...\n');

async function addUniqueConstraint() {
  try {
    // SQL query to add unique constraint
    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        ALTER TABLE hr_fingerprint_transactions 
        ADD CONSTRAINT unique_fingerprint_transaction 
        UNIQUE (employee_id, date, time, status, branch_id);
      `
    }).catch(async () => {
      // If RPC doesn't exist, use direct query
      const { data, error } = await supabase
        .from('_sql')
        .select('*')
        .limit(0);
      
      // Fallback: Show SQL command for manual execution
      console.log('📝 MANUAL EXECUTION REQUIRED');
      console.log('-----------------------------\n');
      console.log('Please run this SQL command in Supabase SQL Editor:\n');
      console.log('```sql');
      console.log('ALTER TABLE hr_fingerprint_transactions');
      console.log('ADD CONSTRAINT unique_fingerprint_transaction');
      console.log('UNIQUE (employee_id, date, time, status, branch_id);');
      console.log('```\n');
      console.log('📍 How to run it:');
      console.log('  1. Go to Supabase Dashboard');
      console.log('  2. Click "SQL Editor" in left menu');
      console.log('  3. Click "New Query"');
      console.log('  4. Paste the SQL command above');
      console.log('  5. Click "Run" button\n');
      console.log('✅ After running, the constraint will be active immediately!');
      return { manual: true };
    });

    if (data && !data.manual) {
      console.log('✅ CONSTRAINT CREATED SUCCESSFULLY!\n');
      console.log('🎉 WHAT HAPPENS NOW:');
      console.log('--------------------');
      console.log('  ✅ Any new sync will automatically skip duplicates');
      console.log('  ✅ Database will reject duplicate inserts immediately');
      console.log('  ✅ You can run sync as many times as you want - no duplicates!\n');
      console.log('🧪 TEST IT:');
      console.log('  Try running historical sync again - it should say "0 new records"');
      console.log('  because all records already exist!\n');
    }

  } catch (err) {
    console.log('📝 MANUAL EXECUTION REQUIRED');
    console.log('-----------------------------\n');
    console.log('Please run this SQL command in Supabase SQL Editor:\n');
    console.log('```sql');
    console.log('ALTER TABLE hr_fingerprint_transactions');
    console.log('ADD CONSTRAINT unique_fingerprint_transaction');
    console.log('UNIQUE (employee_id, date, time, status, branch_id);');
    console.log('```\n');
    console.log('📍 How to run it:');
    console.log('  1. Go to Supabase Dashboard');
    console.log('  2. Click "SQL Editor" in left menu');
    console.log('  3. Click "New Query"');
    console.log('  4. Paste the SQL command above');
    console.log('  5. Click "Run" button\n');
    console.log('⚠️  IMPORTANT: You MUST delete duplicates FIRST!');
    console.log('   Run: node delete-duplicate-transactions.mjs');
    console.log('   Then run this constraint script again.\n');
    console.log('❌ If you try to add constraint while duplicates exist,');
    console.log('   it will fail because the constraint cannot be applied');
    console.log('   to data that already violates the rule!\n');
  }
}

addUniqueConstraint();
