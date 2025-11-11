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

const functionName = process.argv[2] || 'complete_receiving_task_simple';

console.log(`🔍 Getting definition for function: ${functionName}`);
console.log('='.repeat(80));

const { data, error } = await supabase.rpc('get_function_definition', {
  function_name_param: functionName
});

if (error) {
  console.error('❌ Error:', error);
  process.exit(1);
}

if (!data || data.length === 0) {
  console.log('❌ Function not found');
  process.exit(1);
}

console.log('\n📜 Function Definition:');
console.log('-'.repeat(80));
console.log(data);
console.log('-'.repeat(80));
