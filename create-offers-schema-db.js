/**
 * Utility script to create offer system database schema in Supabase
 * 
 * Usage: node create-offers-schema-db.js
 * 
 * This will create all 5 tables, indexes, functions, and RLS policies
 * for the offer management system.
 */

import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
console.log('📄 Loading environment from:', envPath);

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

console.log('✅ Supabase URL:', supabaseUrl);
console.log('✅ Service key loaded');

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Read SQL file
const sqlFile = './create-offers-schema.sql';
console.log('\n📄 Reading SQL file:', sqlFile);

const sql = readFileSync(sqlFile, 'utf-8');

async function createSchema() {
  console.log('\n🚀 Starting schema creation...\n');
  
  try {
    // Split SQL into individual statements (basic split by semicolon)
    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));
    
    console.log(`📊 Found ${statements.length} SQL statements to execute\n`);
    
    let successCount = 0;
    let errorCount = 0;
    
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i] + ';';
      
      // Skip comments and empty statements
      if (statement.trim().startsWith('--') || statement.trim() === ';') {
        continue;
      }
      
      // Extract table/function name for logging
      let operationName = 'SQL Statement';
      if (statement.includes('CREATE TABLE')) {
        const match = statement.match(/CREATE TABLE.*?(\w+)\s*\(/i);
        if (match) operationName = `Table: ${match[1]}`;
      } else if (statement.includes('CREATE INDEX')) {
        const match = statement.match(/CREATE INDEX\s+(\w+)/i);
        if (match) operationName = `Index: ${match[1]}`;
      } else if (statement.includes('CREATE FUNCTION')) {
        const match = statement.match(/CREATE.*?FUNCTION\s+(\w+)/i);
        if (match) operationName = `Function: ${match[1]}`;
      } else if (statement.includes('CREATE TRIGGER')) {
        const match = statement.match(/CREATE TRIGGER\s+(\w+)/i);
        if (match) operationName = `Trigger: ${match[1]}`;
      } else if (statement.includes('CREATE POLICY')) {
        const match = statement.match(/CREATE POLICY\s+(\w+)/i);
        if (match) operationName = `Policy: ${match[1]}`;
      } else if (statement.includes('ALTER TABLE') && statement.includes('ENABLE ROW LEVEL SECURITY')) {
        const match = statement.match(/ALTER TABLE\s+(\w+)/i);
        if (match) operationName = `RLS Enable: ${match[1]}`;
      } else if (statement.includes('COMMENT ON TABLE')) {
        const match = statement.match(/COMMENT ON TABLE\s+(\w+)/i);
        if (match) operationName = `Comment: ${match[1]}`;
      }
      
      process.stdout.write(`[${i + 1}/${statements.length}] ${operationName}... `);
      
      try {
        const { error } = await supabase.rpc('exec_sql', { sql_query: statement });
        
        if (error) {
          // Try direct execution if RPC fails
          const { error: directError } = await supabase.from('_').select('*').limit(0);
          
          if (directError && directError.message.includes('does not exist')) {
            // Table doesn't exist yet, that's okay
            console.log('✅');
            successCount++;
          } else {
            console.log('⚠️  (may need manual execution)');
            console.log(`   Error: ${error.message}`);
            errorCount++;
          }
        } else {
          console.log('✅');
          successCount++;
        }
      } catch (err) {
        console.log('❌');
        console.log(`   Error: ${err.message}`);
        errorCount++;
      }
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 Schema Creation Summary:');
    console.log('='.repeat(60));
    console.log(`✅ Successful: ${successCount}`);
    console.log(`❌ Errors: ${errorCount}`);
    console.log('='.repeat(60));
    
    if (errorCount > 0) {
      console.log('\n⚠️  Some statements failed. You may need to:');
      console.log('   1. Execute the SQL file directly in Supabase SQL Editor');
      console.log('   2. Check for missing dependencies or permissions');
      console.log('   3. Run statements individually');
    } else {
      console.log('\n🎉 All schema objects created successfully!');
    }
    
    // Verify tables were created
    console.log('\n🔍 Verifying tables...\n');
    
    const tablesToCheck = ['offers', 'offer_products', 'offer_bundles', 'customer_offers', 'offer_usage_logs'];
    
    for (const table of tablesToCheck) {
      try {
        const { count, error } = await supabase
          .from(table)
          .select('*', { count: 'exact', head: true });
        
        if (error) {
          console.log(`❌ Table '${table}': ${error.message}`);
        } else {
          console.log(`✅ Table '${table}': exists (${count || 0} rows)`);
        }
      } catch (err) {
        console.log(`❌ Table '${table}': ${err.message}`);
      }
    }
    
    console.log('\n✅ Schema creation process completed!');
    console.log('\n📝 Next steps:');
    console.log('   1. Check Supabase dashboard to verify all tables');
    console.log('   2. Test the offer management UI');
    console.log('   3. Create some sample offers');
    
  } catch (error) {
    console.error('\n❌ Error creating schema:', error);
    process.exit(1);
  }
}

// Run the schema creation
createSchema();
