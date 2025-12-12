#!/usr/bin/env node

/**
 * Apply fixed RLS policies to button tables
 * This fixes the 401 errors by allowing anon key access (like receiving_records and vendors)
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ Missing environment variables:');
  console.error('   VITE_SUPABASE_URL:', SUPABASE_URL ? '✓' : '✗');
  console.error('   SUPABASE_SERVICE_ROLE_KEY:', SERVICE_ROLE_KEY ? '✓' : '✗');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function applyRLSPolicies() {
  try {
    console.log('🔧 Applying fixed RLS policies to button tables...\n');

    // The SQL to apply
    const sql = `
-- Enable RLS on button tables
ALTER TABLE IF EXISTS button_main_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS button_sub_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sidebar_buttons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS button_permissions ENABLE ROW LEVEL SECURITY;

-- Policies for button_main_sections (allow public role full access like branches table)
DROP POLICY IF EXISTS "allow_select" ON button_main_sections;
CREATE POLICY "allow_select" ON button_main_sections
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_main_sections;
CREATE POLICY "allow_insert" ON button_main_sections
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_main_sections;
CREATE POLICY "allow_update" ON button_main_sections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_main_sections;
CREATE POLICY "allow_delete" ON button_main_sections
  FOR DELETE
  USING (true);

-- Policies for button_sub_sections (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON button_sub_sections;
CREATE POLICY "allow_select" ON button_sub_sections
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_sub_sections;
CREATE POLICY "allow_insert" ON button_sub_sections
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_sub_sections;
CREATE POLICY "allow_update" ON button_sub_sections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_sub_sections;
CREATE POLICY "allow_delete" ON button_sub_sections
  FOR DELETE
  USING (true);

-- Policies for sidebar_buttons (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON sidebar_buttons;
CREATE POLICY "allow_select" ON sidebar_buttons
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON sidebar_buttons;
CREATE POLICY "allow_insert" ON sidebar_buttons
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON sidebar_buttons;
CREATE POLICY "allow_update" ON sidebar_buttons
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON sidebar_buttons;
CREATE POLICY "allow_delete" ON sidebar_buttons
  FOR DELETE
  USING (true);

-- Policies for button_permissions (allow public role full access)
DROP POLICY IF EXISTS "allow_select" ON button_permissions;
CREATE POLICY "allow_select" ON button_permissions
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "allow_insert" ON button_permissions;
CREATE POLICY "allow_insert" ON button_permissions
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_update" ON button_permissions;
CREATE POLICY "allow_update" ON button_permissions
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "allow_delete" ON button_permissions;
CREATE POLICY "allow_delete" ON button_permissions
  FOR DELETE
  USING (true);
    `;

    // Execute using raw SQL via Supabase
    const { error } = await supabase.rpc('sql_execute', { sql_code: sql });
    
    if (error) {
      // If sql_execute doesn't exist, try direct method
      console.log('⚠️ sql_execute RPC not available, attempting direct SQL execution...');
      
      // Split into individual statements and execute
      const statements = sql.split(';').filter(stmt => stmt.trim());
      
      for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i].trim();
        if (!stmt) continue;
        
        const stmtFull = stmt + ';';
        console.log(`\n[${i + 1}/${statements.length}] Executing statement...`);
        console.log(`  ${stmt.substring(0, 60)}...`);
        
        // Use fetch to execute via pg_net or similar
        const { error: execError } = await supabase
          .from('pg_stat_statements')
          .select('*')
          .limit(0);
          
        // This won't work directly - need to notify user
      }
      
      throw new Error('Direct SQL execution not available. Please execute the migration manually in Supabase SQL Editor.');
    }

    console.log('\n✅ RLS policies applied successfully!');
    console.log('\n📝 Summary:');
    console.log('   • button_main_sections: SELECT, INSERT, UPDATE, DELETE (public role)');
    console.log('   • button_sub_sections: SELECT, INSERT, UPDATE, DELETE (public role)');
    console.log('   • sidebar_buttons: SELECT, INSERT, UPDATE, DELETE (public role)');
    console.log('   • button_permissions: SELECT, INSERT, UPDATE, DELETE (public role)');
    console.log('\n🔓 Anon key can now INSERT/UPDATE to button tables like receiving_records');

  } catch (error) {
    console.error('❌ Error applying RLS policies:');
    console.error('   ' + error.message);
    console.error('\n📋 Alternative: Execute this SQL manually in Supabase SQL Editor:');
    console.error('   1. Go to supabase.urbanaqura.com');
    console.error('   2. Navigate to SQL Editor');
    console.error('   3. Create new query');
    console.error('   4. Open file: supabase/migrations/button_tables_rls.sql');
    console.error('   5. Copy all contents and paste into SQL Editor');
    console.error('   6. Click Execute');
    process.exit(1);
  }
}

applyRLSPolicies().then(() => {
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
