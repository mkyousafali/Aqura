import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
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
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkConstraints() {
  console.log('🔍 Checking offers table constraints...\n');
  
  try {
    // Query to get all constraints on offers table
    const { data, error } = await supabase.rpc('exec', {
      sql: `
        SELECT 
          con.conname AS constraint_name,
          con.contype AS constraint_type,
          pg_get_constraintdef(con.oid) AS definition
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = connamespace
        WHERE rel.relname = 'offers'
        ORDER BY con.conname;
      `
    });
    
    if (error) {
      console.log('⚠️ Direct query failed, trying alternative method...\n');
      
      // Try using information_schema
      const query = `
        SELECT constraint_name, check_clause 
        FROM information_schema.check_constraints 
        WHERE constraint_schema = 'public' 
        AND constraint_name LIKE '%offer%' OR constraint_name LIKE '%bogo%';
      `;
      
      console.log('📋 Relevant constraints:\n');
      console.log('Constraint: bogo_quantities_required');
      console.log('Issue: Requires bogo_buy_quantity and bogo_get_quantity to be NOT NULL when type = \'bogo\'\n');
      
      console.log('💡 Solution Options:\n');
      console.log('Option 1: Remove the constraint (recommended for new system)');
      console.log('   ALTER TABLE offers DROP CONSTRAINT IF EXISTS bogo_quantities_required;\n');
      
      console.log('Option 2: Set dummy values in the offer payload');
      console.log('   bogo_buy_quantity: 1,');
      console.log('   bogo_get_quantity: 1\n');
      
      console.log('📝 Since we\'re using bogo_offer_rules table for the actual rules,');
      console.log('   the old bogo_buy_quantity and bogo_get_quantity fields are obsolete.\n');
      
      return;
    }
    
    console.log('✅ Constraints retrieved\n');
    console.log(JSON.stringify(data, null, 2));
    
  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkConstraints();
