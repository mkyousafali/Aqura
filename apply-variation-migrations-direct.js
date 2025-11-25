import { readFileSync } from 'fs';
import pg from 'pg';

const { Client } = pg;

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
const projectRef = supabaseUrl.split('//')[1].split('.')[0];

// Note: Direct PostgreSQL connection requires database password
// You'll need to get this from Supabase Dashboard > Settings > Database
console.log('⚠️  This script requires direct PostgreSQL connection.');
console.log('📋 To apply migrations, you have two options:\n');

console.log('Option 1: Apply via Supabase Dashboard (RECOMMENDED)');
console.log('─────────────────────────────────────────────────────');
console.log('1. Go to Supabase Dashboard → SQL Editor');
console.log('2. Copy and paste each migration file content:');
console.log('   - supabase/migrations/20251125000001_add_variation_columns_to_flyer_products.sql');
console.log('   - supabase/migrations/20251125000002_add_variation_tracking_to_offer_products.sql');
console.log('   - supabase/migrations/20251125000003_create_variation_audit_log.sql');
console.log('   - supabase/migrations/20251125000004_create_variation_helper_functions.sql');
console.log('   - supabase/migrations/20251125000005_update_rls_policies_for_variations.sql');
console.log('3. Execute each migration in order\n');

console.log('Option 2: Use Supabase CLI');
console.log('─────────────────────────────────────────────────────');
console.log('1. Install Supabase CLI: npm install -g supabase');
console.log('2. Link your project: supabase link --project-ref ' + projectRef);
console.log('3. Push migrations: supabase db push\n');

console.log('Option 3: Direct PostgreSQL Connection');
console.log('─────────────────────────────────────────────────────');
console.log('If you have the database password, uncomment the code below');
console.log('and add your connection string.\n');

/*
// Uncomment and configure this section if you have DB password
const connectionString = 'postgresql://postgres:[YOUR-PASSWORD]@db.' + projectRef + '.supabase.co:5432/postgres';

const client = new Client({ connectionString });

async function applyMigrations() {
  try {
    await client.connect();
    console.log('✅ Connected to database\n');

    const migrations = [
      { file: '20251125000001_add_variation_columns_to_flyer_products.sql', name: 'Add Variation Columns' },
      { file: '20251125000002_add_variation_tracking_to_offer_products.sql', name: 'Add Offer Tracking' },
      { file: '20251125000003_create_variation_audit_log.sql', name: 'Create Audit Log' },
      { file: '20251125000004_create_variation_helper_functions.sql', name: 'Create Helper Functions' },
      { file: '20251125000005_update_rls_policies_for_variations.sql', name: 'Update RLS Policies' }
    ];

    for (const migration of migrations) {
      console.log(`📄 Applying: ${migration.name}`);
      const sql = readFileSync(`./supabase/migrations/${migration.file}`, 'utf-8');
      
      try {
        await client.query(sql);
        console.log(`   ✅ Success\n`);
      } catch (error) {
        console.error(`   ❌ Failed: ${error.message}\n`);
      }
    }

    await client.end();
    console.log('🎉 Migration process completed!');
  } catch (error) {
    console.error('❌ Connection error:', error.message);
  }
}

applyMigrations();
*/
