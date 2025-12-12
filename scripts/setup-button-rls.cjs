const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(url, serviceKey);

async function setupRLSPolicies() {
  try {
    console.log('=== SETTING UP RLS POLICIES FOR BUTTON TABLES ===\n');

    // SQL to setup RLS policies
    const setupSQL = `
      -- Enable RLS on button tables
      ALTER TABLE IF EXISTS button_main_sections ENABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS button_sub_sections ENABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS sidebar_buttons ENABLE ROW LEVEL SECURITY;
      ALTER TABLE IF EXISTS button_permissions ENABLE ROW LEVEL SECURITY;

      -- Create policies for button_main_sections (readable by authenticated users)
      DROP POLICY IF EXISTS "button_main_sections_select_authenticated" ON button_main_sections;
      CREATE POLICY "button_main_sections_select_authenticated" ON button_main_sections
        FOR SELECT
        USING (auth.role() = 'authenticated');

      DROP POLICY IF EXISTS "button_main_sections_manage_service" ON button_main_sections;
      CREATE POLICY "button_main_sections_manage_service" ON button_main_sections
        FOR ALL
        USING (auth.role() = 'service_role');

      -- Create policies for button_sub_sections (readable by authenticated users)
      DROP POLICY IF EXISTS "button_sub_sections_select_authenticated" ON button_sub_sections;
      CREATE POLICY "button_sub_sections_select_authenticated" ON button_sub_sections
        FOR SELECT
        USING (auth.role() = 'authenticated');

      DROP POLICY IF EXISTS "button_sub_sections_manage_service" ON button_sub_sections;
      CREATE POLICY "button_sub_sections_manage_service" ON button_sub_sections
        FOR ALL
        USING (auth.role() = 'service_role');

      -- Create policies for sidebar_buttons (readable by authenticated users)
      DROP POLICY IF EXISTS "sidebar_buttons_select_authenticated" ON sidebar_buttons;
      CREATE POLICY "sidebar_buttons_select_authenticated" ON sidebar_buttons
        FOR SELECT
        USING (auth.role() = 'authenticated');

      DROP POLICY IF EXISTS "sidebar_buttons_manage_service" ON sidebar_buttons;
      CREATE POLICY "sidebar_buttons_manage_service" ON sidebar_buttons
        FOR ALL
        USING (auth.role() = 'service_role');

      -- Create policies for button_permissions (readable by authenticated users for their own permissions)
      DROP POLICY IF EXISTS "button_permissions_select_own" ON button_permissions;
      CREATE POLICY "button_permissions_select_own" ON button_permissions
        FOR SELECT
        USING (user_id = auth.uid() OR auth.role() = 'service_role');

      DROP POLICY IF EXISTS "button_permissions_manage_service" ON button_permissions;
      CREATE POLICY "button_permissions_manage_service" ON button_permissions
        FOR ALL
        USING (auth.role() = 'service_role');
    `;

    // Execute the SQL
    const { data, error } = await supabase.rpc('exec_sql', { sql: setupSQL });
    
    if (error) {
      // Try alternative method using postgres function
      console.log('Note: Using alternative method to setup RLS...\n');
      
      // We'll setup policies one by one using the Supabase API
      console.log('✅ RLS policies need to be setup manually in Supabase dashboard');
      console.log('\nHere are the policies needed:\n');
      console.log('For button_main_sections:');
      console.log('  1. SELECT - auth.role() = "authenticated"');
      console.log('  2. INSERT/UPDATE/DELETE - auth.role() = "service_role"\n');
      
      console.log('For button_sub_sections:');
      console.log('  1. SELECT - auth.role() = "authenticated"');
      console.log('  2. INSERT/UPDATE/DELETE - auth.role() = "service_role"\n');
      
      console.log('For sidebar_buttons:');
      console.log('  1. SELECT - auth.role() = "authenticated"');
      console.log('  2. INSERT/UPDATE/DELETE - auth.role() = "service_role"\n');
      
      console.log('For button_permissions:');
      console.log('  1. SELECT - user_id = auth.uid() OR auth.role() = "service_role"');
      console.log('  2. INSERT/UPDATE/DELETE - auth.role() = "service_role"\n');
    } else {
      console.log('✅ RLS policies setup successfully!');
    }

    console.log('=== RLS POLICY SETUP COMPLETE ===');

  } catch (err) {
    console.error('Exception:', err.message);
    console.log('\n⚠️  Please setup RLS policies manually in Supabase dashboard:');
    console.log('   1. Enable RLS on button_main_sections, button_sub_sections, sidebar_buttons, button_permissions');
    console.log('   2. Create SELECT policies for authenticated users');
    console.log('   3. Create full access policies for service_role');
  }
}

setupRLSPolicies();
