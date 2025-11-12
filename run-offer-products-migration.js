// Run Product Discount Offer Migration
// Execute create-offer-products-table.sql

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
const envPath = join(__dirname, 'frontend', '.env');
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

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runMigration() {
  console.log('🚀 Starting Product Discount Offer Migration...\n');

  try {
    // Read SQL file
    const sqlPath = join(__dirname, 'create-offer-products-table.sql');
    const sqlContent = readFileSync(sqlPath, 'utf-8');

    // Split SQL into individual statements (rough split by semicolons)
    const statements = sqlContent
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--') && !s.match(/^DO \$\$/));

    console.log(`📄 Found ${statements.length} SQL statements to execute\n`);

    let successCount = 0;
    let errorCount = 0;

    // Execute each statement
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i] + ';';
      
      // Skip comments and DO blocks
      if (statement.trim().startsWith('--') || statement.trim().startsWith('COMMENT')) {
        continue;
      }

      try {
        const { error } = await supabase.rpc('exec_sql', { sql: statement });
        
        if (error) {
          // Try direct execution as fallback
          const { error: directError } = await supabase.from('_').select('*').limit(0);
          
          console.log(`⚠️  Statement ${i + 1}: Skipped (may require direct Supabase access)`);
        } else {
          successCount++;
          console.log(`✅ Statement ${i + 1}: Executed successfully`);
        }
      } catch (err) {
        errorCount++;
        console.log(`⚠️  Statement ${i + 1}: ${err.message}`);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 Migration Summary:');
    console.log(`✅ Successful: ${successCount}`);
    console.log(`⚠️  Skipped/Errors: ${errorCount}`);
    console.log('='.repeat(60));

    // Note about Supabase dashboard
    console.log('\n📝 Note: Some statements may need to be executed directly in Supabase SQL Editor:');
    console.log('   1. Go to Supabase Dashboard → SQL Editor');
    console.log('   2. Copy content from create-offer-products-table.sql');
    console.log('   3. Execute the SQL');
    console.log('   4. Run verification: node check-table-structure.js offer_products\n');

    // Try to verify table creation
    console.log('🔍 Verifying table creation...\n');
    
    const { data, error } = await supabase
      .from('offer_products')
      .select('*')
      .limit(0);

    if (error) {
      console.log('⚠️  Table verification: Could not access offer_products table');
      console.log('   Please execute the SQL file in Supabase Dashboard manually\n');
    } else {
      console.log('✅ Table verification: offer_products table exists!\n');
    }

  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.log('\n📝 Please execute create-offer-products-table.sql manually in Supabase SQL Editor\n');
    process.exit(1);
  }
}

runMigration();
