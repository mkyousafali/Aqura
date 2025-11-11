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

// Query pg_proc to get function definition
const { data, error } = await supabase.rpc('exec_sql', {
  sql: `
    SELECT 
      p.proname as function_name,
      pg_get_functiondef(p.oid) as definition
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = '${functionName}'
    LIMIT 1;
  `
});

if (error) {
  console.error('❌ Error:', error);
  
  // Try direct query instead
  const query = `
    SELECT pg_get_functiondef(oid) as definition
    FROM pg_proc 
    WHERE proname = '${functionName}' 
    AND pronamespace = 'public'::regnamespace;
  `;
  
  console.log('\n🔄 Trying alternative query...');
  const { data: altData, error: altError } = await supabase.rpc('exec_sql', { sql: query });
  
  if (altError) {
    console.error('❌ Alternative query also failed:', altError);
    process.exit(1);
  }
  
  console.log('\n📜 Function Definition:');
  console.log('-'.repeat(80));
  console.log(altData);
  process.exit(0);
}

if (!data || data.length === 0) {
  console.log('❌ Function not found');
  process.exit(1);
}

console.log('\n📜 Function Definition:');
console.log('-'.repeat(80));
console.log(data[0].definition);
