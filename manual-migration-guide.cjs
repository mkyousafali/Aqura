const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

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

console.log(`
╔════════════════════════════════════════════════════════════════╗
║  📋 MANUAL MIGRATION INSTRUCTIONS                              ║
╚════════════════════════════════════════════════════════════════╝

The migration files are ready in: supabase/migrations/

To apply them, please follow these steps:

1. Open Supabase Dashboard: ${envVars.VITE_SUPABASE_URL.replace('/rest/v1', '')}
   
2. Navigate to: SQL Editor (left sidebar)

3. Copy and paste each migration file in order:
   
   📄 File 1: supabase/migrations/20251120000001_create_orders_table.sql
   📄 File 2: supabase/migrations/20251120000002_create_order_items_table.sql
   📄 File 3: supabase/migrations/20251120000003_create_order_audit_logs_table.sql
   📄 File 4: supabase/migrations/20251120000004_extend_offer_usage_logs.sql

4. Click "RUN" for each file

5. Verify tables were created using this command in SQL Editor:
   
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('orders', 'order_items', 'order_audit_logs');

─────────────────────────────────────────────────────────────────

💡 TIP: You can also use Supabase CLI:
   supabase db push

Or apply directly in SQL Editor by copy-pasting the SQL files.

Press Enter when done to verify the tables...
`);

// Wait for user confirmation
const readline = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout
});

readline.question('', async () => {
  readline.close();
  
  const supabase = createClient(envVars.VITE_SUPABASE_URL, envVars.VITE_SUPABASE_SERVICE_ROLE_KEY);
  
  console.log('\n🔍 Verifying tables...\n');
  
  const tables = ['orders', 'order_items', 'order_audit_logs'];
  let allExist = true;
  
  for (const table of tables) {
    const { error } = await supabase.from(table).select('id', { count: 'exact', head: true });
    
    if (error) {
      console.log(`❌ ${table}: NOT FOUND`);
      allExist = false;
    } else {
      console.log(`✅ ${table}: EXISTS`);
    }
  }
  
  if (allExist) {
    console.log('\n🎉 All tables successfully created!\n');
  } else {
    console.log('\n⚠️  Some tables are missing. Please apply the migrations manually.\n');
  }
});
