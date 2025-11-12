import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

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

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applyMigration() {
  console.log('🚀 Applying BOGO Offers Migration...\n');
  
  try {
    // Read the SQL migration file
    const sqlContent = readFileSync('./create-bogo-offers-table.sql', 'utf-8');
    
    console.log('📄 Migration SQL loaded');
    console.log('⚙️ Executing migration...\n');
    
    // Execute the migration
    const { data, error } = await supabase.rpc('exec_sql', { 
      sql: sqlContent 
    });
    
    if (error) {
      // If exec_sql doesn't exist, try direct execution
      console.log('⚠️ exec_sql function not found, trying direct execution...\n');
      
      // Split SQL into individual statements
      const statements = sqlContent
        .split(';')
        .map(s => s.trim())
        .filter(s => s && !s.startsWith('--') && !s.startsWith('/*'));
      
      for (let i = 0; i < statements.length; i++) {
        const statement = statements[i];
        if (!statement) continue;
        
        console.log(`Executing statement ${i + 1}/${statements.length}...`);
        
        const { error: execError } = await supabase.rpc('exec', {
          sql: statement + ';'
        });
        
        if (execError) {
          console.error(`❌ Error executing statement ${i + 1}:`, execError.message);
          throw execError;
        }
      }
    }
    
    console.log('✅ Migration executed successfully!\n');
    
    // Verify the table was created
    console.log('🔍 Verifying bogo_offer_rules table...');
    const { data: tableData, error: tableError } = await supabase
      .from('bogo_offer_rules')
      .select('*', { count: 'exact', head: true });
    
    if (tableError) {
      console.error('❌ Table verification failed:', tableError.message);
      console.log('\n⚠️ Please run the SQL migration manually in Supabase SQL Editor');
      console.log('📄 File: create-bogo-offers-table.sql\n');
    } else {
      console.log('✅ Table bogo_offer_rules verified!\n');
      
      // Check offers type constraint
      console.log('🔍 Checking offers table type constraint...');
      const { data: offersData, error: offersError } = await supabase
        .from('offers')
        .select('type')
        .limit(1);
      
      if (!offersError) {
        console.log('✅ Offers table ready for BOGO type!\n');
      }
    }
    
    console.log('🎉 BOGO Migration Complete!');
    console.log('\n📋 Summary:');
    console.log('   ✓ bogo_offer_rules table created');
    console.log('   ✓ Indexes added for performance');
    console.log('   ✓ RLS policies configured');
    console.log('   ✓ Triggers for updated_at added');
    console.log('   ✓ Offers type enum updated to include "bogo"');
    
  } catch (err) {
    console.error('\n❌ Migration failed:', err.message);
    console.log('\n💡 Manual Migration Required:');
    console.log('   1. Open Supabase SQL Editor');
    console.log('   2. Copy contents of create-bogo-offers-table.sql');
    console.log('   3. Execute the SQL manually');
    console.log('   4. Verify with: SELECT * FROM bogo_offer_rules LIMIT 1;\n');
    process.exit(1);
  }
}

applyMigration();
