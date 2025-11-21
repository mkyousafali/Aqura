const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Load environment variables
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

const supabase = createClient(
  envVars.VITE_SUPABASE_URL, 
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

async function applyMigrations() {
  const migrations = [
    '20251120000001_create_orders_table.sql',
    '20251120000002_create_order_items_table.sql',
    '20251120000003_create_order_audit_logs_table.sql',
    '20251120000004_extend_offer_usage_logs.sql'
  ];

  console.log('🚀 Starting database migrations...\n');

  for (const migration of migrations) {
    console.log(`📝 Applying: ${migration}`);
    const migrationPath = path.join('./supabase/migrations', migration);
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    try {
      // Execute SQL directly using the REST API
      const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });
      
      if (error) {
        console.error(`❌ Error in ${migration}:`, error.message);
        console.error('   Details:', error);
        
        // Try alternative method - execute statement by statement
        console.log(`   🔄 Retrying with statement-by-statement execution...`);
        const statements = sql.split(';').filter(s => s.trim());
        
        for (let i = 0; i < statements.length; i++) {
          const stmt = statements[i].trim();
          if (stmt && !stmt.startsWith('--') && stmt.length > 0) {
            const { error: stmtError } = await supabase.rpc('exec_sql', { sql_query: stmt + ';' });
            if (stmtError && !stmtError.message.includes('already exists')) {
              console.error(`   ❌ Statement ${i + 1} failed:`, stmtError.message);
            }
          }
        }
        console.log(`   ✅ Completed ${migration} (with warnings)`);
      } else {
        console.log(`   ✅ Successfully applied ${migration}`);
      }
    } catch (err) {
      console.error(`❌ Exception in ${migration}:`, err.message);
    }
    console.log('');
  }

  console.log('🎉 Migration process completed!\n');
  
  // Verify tables were created
  console.log('🔍 Verifying tables...');
  const { data: tables, error: tablesError } = await supabase
    .from('orders')
    .select('count', { count: 'exact', head: true });
    
  if (tablesError) {
    console.log('❌ Orders table verification failed:', tablesError.message);
  } else {
    console.log('✅ Orders table exists');
  }
}

applyMigrations().catch(console.error);
