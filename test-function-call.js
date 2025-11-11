import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

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

console.log('🧪 Testing complete_receiving_task_simple function...');
console.log('='.repeat(80));

const testTaskId = '9871acc0-9bac-4dc4-993e-7a1117522599';
const testUserId = '4ff8b724-ac89-4f55-b453-27145ffa3dd5';

console.log('\n📋 Test Parameters:');
console.log('  - Task ID:', testTaskId);
console.log('  - User ID:', testUserId);

// Call the function
const { data, error } = await supabase.rpc('complete_receiving_task_simple', {
  receiving_task_id_param: testTaskId,
  user_id_param: testUserId,
  completion_photo_url_param: null,
  completion_notes_param: 'Test from script'
});

console.log('\n📊 Function Result:');
console.log('-'.repeat(80));
if (error) {
  console.log('❌ Error:', error);
} else {
  console.log('✅ Data:', JSON.stringify(data, null, 2));
}

// Also check what the function source might look like
console.log('\n🔍 Checking database for function source...');
const { data: funcData, error: funcError } = await supabase
  .from('pg_proc')
  .select('*')
  .eq('proname', 'complete_receiving_task_simple')
  .single();

if (funcError) {
  console.log('⚠️  Could not query pg_proc directly (expected - RLS might block this)');
  console.log('\n💡 Solution: We need to update the database function via Supabase Dashboard SQL Editor');
  console.log('\n📝 The function needs to check file uploads, not inventory_manager task:');
  console.log(`
    -- FOR ACCOUNTANT ROLE:
    -- OLD (WRONG): Check if inventory_manager task is completed
    -- NEW (CORRECT): Check if pr_excel_file_uploaded AND original_bill_uploaded are TRUE
  `);
}
