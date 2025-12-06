// Check RLS policies for erp_daily_sales and branches tables
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables from frontend/.env
dotenv.config({ path: join(__dirname, '../frontend/.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.VITE_SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in frontend/.env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkRLSPolicies() {
  console.log('🔍 Checking RLS status and policies...\n');

  // Check RLS status
  const { data: rlsStatus, error: rlsError } = await supabase.rpc('exec_sql', {
    sql: `
      SELECT schemaname, tablename, rowsecurity 
      FROM pg_tables 
      WHERE tablename IN ('erp_daily_sales', 'branches')
      ORDER BY tablename;
    `
  });

  if (rlsError) {
    // Try alternative method
    const { data: tables, error: tablesError } = await supabase
      .from('pg_tables')
      .select('schemaname, tablename, rowsecurity')
      .in('tablename', ['erp_daily_sales', 'branches']);

    if (tablesError) {
      console.log('⚠️ Cannot query pg_tables directly, using SQL query...\n');
      
      // Use raw SQL query
      const { data, error } = await supabase.rpc('exec_sql', {
        sql: `
          SELECT 
            tablename,
            CASE 
              WHEN rowsecurity THEN 'Enabled'
              ELSE 'Disabled'
            END as rls_status
          FROM pg_tables 
          WHERE schemaname = 'public' 
          AND tablename IN ('erp_daily_sales', 'branches');
        `
      });

      if (error) {
        console.log('❌ Error checking RLS status:', error.message);
        console.log('\n📝 Running direct SQL query instead...\n');
        
        // Try with rpc if available
        const query1 = `
          SELECT tablename, 
                 pg_tables.rowsecurity as rls_enabled
          FROM pg_tables 
          WHERE schemaname = 'public' 
            AND tablename IN ('erp_daily_sales', 'branches')
          ORDER BY tablename;
        `;
        
        console.log('RLS Status Query:', query1);
      } else {
        console.log('✅ RLS Status:');
        console.table(data);
      }
    } else {
      console.log('✅ RLS Status:');
      console.table(tables);
    }
  } else {
    console.log('✅ RLS Status:');
    console.table(rlsStatus);
  }

  // Check policies using direct query
  console.log('\n🔍 Checking existing policies...\n');
  
  const { data: policies, error: policiesError } = await supabase.rpc('exec_sql', {
    sql: `
      SELECT 
        schemaname,
        tablename,
        policyname,
        permissive,
        roles,
        cmd as command,
        qual as using_expression
      FROM pg_policies 
      WHERE tablename IN ('erp_daily_sales', 'branches')
      ORDER BY tablename, policyname;
    `
  });

  if (policiesError) {
    console.log('⚠️ Cannot query policies directly');
    console.log('\n📋 Run this SQL in Supabase Dashboard to check policies:');
    console.log(`
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd as command
FROM pg_policies 
WHERE tablename IN ('erp_daily_sales', 'branches')
ORDER BY tablename, policyname;
    `);
  } else {
    if (policies && policies.length > 0) {
      console.log('✅ Existing Policies:');
      console.table(policies);
    } else {
      console.log('ℹ️ No policies found for these tables');
    }
  }

  console.log('\n📊 Summary:');
  console.log('- erp_daily_sales: Check if RLS is enabled and what policies exist');
  console.log('- branches: Check if RLS is enabled and what policies exist');
  console.log('\nIf RLS is disabled, the service role key is required to access these tables.');
}

checkRLSPolicies().catch(console.error);
