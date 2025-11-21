const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
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

const supabase = createClient(envVars.VITE_SUPABASE_URL, envVars.VITE_SUPABASE_SERVICE_ROLE_KEY);

(async () => {
  const { data, error } = await supabase.from('orders').select('selected_location, customer_name').limit(3);
  
  if (error) {
    console.error('Error:', error.message);
  } else if (data) {
    console.log('Sample orders:');
    data.forEach((row, i) => {
      console.log(`\nOrder ${i+1}:`);
      console.log('  selected_location:', row.selected_location);
    });
  }
})();
