import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';
import { readdir } from 'fs/promises';
import { join } from 'path';

// Load environment variables from frontend/.env
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

const supabaseUrl = envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applyVariationMigrations() {
  console.log('🚀 Starting Product Variation System Migration...\n');

  const migrationsDir = './supabase/migrations';
  const variationMigrations = [
    '20251125000001_add_variation_columns_to_flyer_products.sql',
    '20251125000002_add_variation_tracking_to_offer_products.sql',
    '20251125000003_create_variation_audit_log.sql',
    '20251125000004_create_variation_helper_functions.sql',
    '20251125000005_update_rls_policies_for_variations.sql'
  ];

  let successCount = 0;
  let failCount = 0;

  for (const migration of variationMigrations) {
    const migrationPath = join(migrationsDir, migration);
    
    try {
      console.log(`📄 Applying: ${migration}`);
      const sqlContent = readFileSync(migrationPath, 'utf-8');
      
      // Execute the SQL
      const { data, error } = await supabase.rpc('exec_sql', { sql: sqlContent }).catch(async () => {
        // If exec_sql doesn't exist, try direct execution
        const { data, error } = await supabase.from('_migrations').select('*').limit(1);
        if (error) {
          // Try using the raw SQL endpoint (requires service role key)
          const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'apikey': supabaseServiceKey,
              'Authorization': `Bearer ${supabaseServiceKey}`
            },
            body: JSON.stringify({ query: sqlContent })
          });
          
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
          }
          
          return { data: await response.json(), error: null };
        }
        return { data, error };
      });

      if (error) {
        console.error(`   ❌ Failed: ${error.message}`);
        console.error(`   Details:`, error);
        failCount++;
      } else {
        console.log(`   ✅ Success`);
        successCount++;
      }
      
      console.log('');
    } catch (err) {
      console.error(`   ❌ Error: ${err.message}`);
      failCount++;
      console.log('');
    }
  }

  console.log('═══════════════════════════════════════════════════');
  console.log(`📊 Migration Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${failCount}`);
  console.log(`   📝 Total: ${variationMigrations.length}`);
  console.log('═══════════════════════════════════════════════════\n');

  if (failCount === 0) {
    console.log('🎉 All migrations applied successfully!');
    console.log('\n📋 Next Steps:');
    console.log('   1. Run verification: node verify-variation-migrations.js');
    console.log('   2. Check table structures: node check-flyer-products-structure.js');
    console.log('   3. Begin UI implementation (Day 2)');
  } else {
    console.log('⚠️  Some migrations failed. Please review the errors above.');
    console.log('   You may need to apply migrations manually through Supabase Dashboard.');
  }
}

applyVariationMigrations().catch(console.error);
