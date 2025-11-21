const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
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

const supabase = createClient(
  envVars.VITE_SUPABASE_URL,
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

(async () => {
  console.log('Searching for "deleted_at" references in database functions and triggers...\n');
  
  // Check all function definitions
  const { data: functions, error: funcError } = await supabase.rpc('exec_sql', {
    sql_query: `
      SELECT 
        proname as function_name,
        pg_get_functiondef(oid) as definition
      FROM pg_proc
      WHERE pg_get_functiondef(oid) ILIKE '%deleted_at%'
      ORDER BY proname;
    `
  });
  
  if (funcError) {
    console.error('Functions check error:', funcError.message);
  } else if (functions && functions.length > 0) {
    console.log('Functions referencing "deleted_at":');
    functions.forEach(f => {
      console.log(`\n- ${f.function_name}`);
      console.log(f.definition.substring(0, 500) + '...');
    });
  } else {
    console.log('No functions found with "deleted_at" references');
  }
  
  console.log('\n' + '='.repeat(80) + '\n');
  
  // Check all trigger definitions
  const { data: triggers, error: trigError } = await supabase.rpc('exec_sql', {
    sql_query: `
      SELECT 
        tgname as trigger_name,
        tgrelid::regclass as table_name,
        pg_get_triggerdef(oid) as definition
      FROM pg_trigger
      WHERE NOT tgisinternal
      AND pg_get_triggerdef(oid) ILIKE '%deleted_at%'
      ORDER BY tgname;
    `
  });
  
  if (trigError) {
    console.error('Triggers check error:', trigError.message);
  } else if (triggers && triggers.length > 0) {
    console.log('Triggers referencing "deleted_at":');
    triggers.forEach(t => {
      console.log(`\n- ${t.trigger_name} on ${t.table_name}`);
      console.log(t.definition);
    });
  } else {
    console.log('No triggers found with "deleted_at" references');
  }
})();
