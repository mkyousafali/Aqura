const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  line = line.trim();
  if (line && !line.startsWith('#')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      value = value.replace(/^["']|["']$/g, '');
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTaskCompletionsStructure() {
  console.log('🔍 Checking task_completions table structure...\n');

  // Check column names
  const { data, error } = await supabase
    .from('task_completions')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Error:', error.message);
  } else if (data && data.length > 0) {
    console.log('Columns in task_completions:');
    Object.keys(data[0]).forEach(col => console.log(`  • ${col}`));
  } else {
    console.log('No data in task_completions table');
  }

  // Check quick_task_completions
  const { data: qData, error: qError } = await supabase
    .from('quick_task_completions')
    .select('*')
    .limit(1);

  if (!qError && qData && qData.length > 0) {
    console.log('\nColumns in quick_task_completions:');
    Object.keys(qData[0]).forEach(col => console.log(`  • ${col}`));
  }
}

checkTaskCompletionsStructure();
