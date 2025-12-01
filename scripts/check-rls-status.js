import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pg from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables from frontend/.env
const envPath = join(__dirname, '..', 'frontend', '.env');
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

async function checkRLSDirect() {
  console.log('🔍 Querying Supabase for RLS status...\n');

  try {
    // Use Supabase REST API to query pg_tables directly
    const { data: tables, error } = await supabase
      .from('pg_tables')
      .select('tablename, rowsecurity')
      .eq('schemaname', 'public')
      .order('tablename');

    if (error) {
      console.log('⚠️  Direct query failed, trying via SQL function...\n');
      
      // Create a temporary function to query RLS status
      const sqlQuery = `
        SELECT 
          tablename,
          rowsecurity as rls_enabled,
          (SELECT COUNT(*) FROM pg_policies WHERE tablename = pg_tables.tablename) as policy_count
        FROM pg_tables 
        WHERE schemaname = 'public'
        ORDER BY tablename;
      `;
      
      // Execute via raw SQL
      const { data: sqlData, error: sqlError } = await supabase.rpc('exec_sql', { query: sqlQuery });
      
      if (sqlError) {
        console.log('⚠️  SQL function not available. Using metadata API...\n');
        
        // Try using the PostgREST metadata endpoint
        const response = await fetch(`${supabaseUrl}/rest/v1/`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey,
            'Accept': 'application/openapi+json'
          }
        });
        
        if (!response.ok) {
          throw new Error(`Metadata fetch failed: ${response.statusText}`);
        }
        
        const metadata = await response.json();
        const tableNames = Object.keys(metadata.definitions || {});
        
        console.log('📊 Found tables from metadata:', tableNames.length);
        console.log('\n⚠️  Note: Cannot determine RLS status from metadata alone.');
        console.log('📝 Listing all tables found:\n');
        
        tableNames.forEach((table, idx) => {
          console.log(`${idx + 1}. ${table}`);
        });
        
        console.log('\n💡 Recommendation: Check Supabase Dashboard > Database > Tables for RLS status');
        console.log('   Or run SQL query directly in Supabase SQL Editor:');
        console.log('\n   SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = \'public\' ORDER BY tablename;\n');
        
        return;
      }
      
      analyzeTables(sqlData);
      return;
    }

    analyzeTables(tables);

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.log('\n💡 Please ensure you have proper access rights to query system tables.');
  }
}

function analyzeTables(tables) {
  const withRLS = tables.filter(t => t.rls_enabled === true || t.rowsecurity === true);
  const withoutRLS = tables.filter(t => t.rls_enabled === false || t.rowsecurity === false);
  
  console.log(`✅ Tables WITH RLS enabled (${withRLS.length}):`);
  if (withRLS.length > 0) {
    withRLS.forEach(t => {
      const policyInfo = t.policy_count ? ` (${t.policy_count} policies)` : '';
      console.log(`   ✓ ${t.tablename}${policyInfo}`);
    });
  } else {
    console.log('   (none)');
  }
  
  console.log(`\n❌ Tables WITHOUT RLS enabled (${withoutRLS.length}):`);
  if (withoutRLS.length > 0) {
    withoutRLS.forEach(t => {
      console.log(`   ✗ ${t.tablename}`);
    });
  } else {
    console.log('   (none)');
  }
  
  console.log(`\n📊 Summary:`);
  console.log(`   Total tables: ${tables.length}`);
  console.log(`   With RLS: ${withRLS.length} (${((withRLS.length / tables.length) * 100).toFixed(1)}%)`);
  console.log(`   Without RLS: ${withoutRLS.length} (${((withoutRLS.length / tables.length) * 100).toFixed(1)}%)`);
  
  if (withoutRLS.length > 0) {
    console.log(`\n⚠️  WARNING: ${withoutRLS.length} tables are exposed without RLS protection!`);
  }
}

checkRLSDirect().catch(console.error);
