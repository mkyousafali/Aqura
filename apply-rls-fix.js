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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Read migration file
const sql = fs.readFileSync('./supabase/migrations/20251120000008_fix_customer_order_rls.sql', 'utf-8');

console.log('📝 Applying migration: 20251120000008_fix_customer_order_rls.sql\n');
console.log('⚠️  Note: This migration must be run via Supabase SQL Editor');
console.log('');
console.log('Copy the following SQL and paste it into Supabase SQL Editor:');
console.log('='.repeat(80));
console.log(sql);
console.log('='.repeat(80));
console.log('');
console.log('OR apply manually by opening:');
console.log('  ./supabase/migrations/20251120000008_fix_customer_order_rls.sql');
