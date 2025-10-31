const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file from frontend directory
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const env = {};
envContent.split('\n').forEach(line => {
  line = line.trim();
  if (line && !line.startsWith('#')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      value = value.replace(/^["']|["']$/g, '');
      env[key] = value;
    }
  }
});

const supabaseUrl = env.VITE_SUPABASE_URL;
const supabaseServiceKey = env.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing environment variables!');
  console.error('VITE_SUPABASE_URL:', supabaseUrl ? 'Found' : 'Missing');
  console.error('VITE_SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? 'Found' : 'Missing');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function checkQuickTaskCompletions() {
  console.log('Checking quick_task_completions table structure...\n');

  // Get sample data to see columns
  const { data, error } = await supabase
    .from('quick_task_completions')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Error fetching data:', error);
  } else if (data && data.length > 0) {
    console.log('Sample record columns:');
    console.log(Object.keys(data[0]));
    console.log('\nSample data:');
    console.log(JSON.stringify(data[0], null, 2));
  } else {
    console.log('No data in quick_task_completions table');
  }

  // Get column info from information_schema
  const { data: schemaData, error: schemaError } = await supabase.rpc('exec_sql', {
    sql: `
      SELECT 
        column_name, 
        data_type, 
        is_nullable,
        column_default
      FROM information_schema.columns 
      WHERE table_name = 'quick_task_completions' 
      ORDER BY ordinal_position
    `
  }).catch(async () => {
    // If exec_sql doesn't exist, try direct query
    return await supabase
      .from('information_schema.columns')
      .select('column_name, data_type, is_nullable, column_default')
      .eq('table_name', 'quick_task_completions')
      .order('ordinal_position');
  });

  if (schemaError) {
    console.error('\nError fetching schema:', schemaError);
  } else if (schemaData) {
    console.log('\nTable schema:');
    console.table(schemaData);
  }

  // Check total count
  const { count, error: countError } = await supabase
    .from('quick_task_completions')
    .select('*', { count: 'exact', head: true });

  if (!countError) {
    console.log(`\nTotal records: ${count}`);
  }
}

checkQuickTaskCompletions().catch(console.error);
