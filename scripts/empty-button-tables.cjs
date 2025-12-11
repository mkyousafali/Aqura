#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function emptyTables() {
  try {
    console.log('🧹 Emptying Button Permission Tables...\n');

    // Delete in correct order (respecting foreign key constraints)
    console.log('1️⃣ Deleting button_permissions...');
    const { error: permError } = await supabase
      .from('button_permissions')
      .delete()
      .neq('id', 0); // Delete all records

    if (permError) {
      console.error('❌ Error deleting permissions:', permError.message);
    } else {
      console.log('✅ button_permissions cleared');
    }

    console.log('\n2️⃣ Deleting sidebar_buttons...');
    const { error: btnError } = await supabase
      .from('sidebar_buttons')
      .delete()
      .neq('id', 0); // Delete all records

    if (btnError) {
      console.error('❌ Error deleting buttons:', btnError.message);
    } else {
      console.log('✅ sidebar_buttons cleared');
    }

    console.log('\n3️⃣ Deleting button_sub_sections...');
    const { error: subError } = await supabase
      .from('button_sub_sections')
      .delete()
      .neq('id', 0); // Delete all records

    if (subError) {
      console.error('❌ Error deleting subsections:', subError.message);
    } else {
      console.log('✅ button_sub_sections cleared');
    }

    console.log('\n4️⃣ Deleting button_main_sections...');
    const { error: secError } = await supabase
      .from('button_main_sections')
      .delete()
      .neq('id', 0); // Delete all records

    if (secError) {
      console.error('❌ Error deleting sections:', secError.message);
    } else {
      console.log('✅ button_main_sections cleared');
    }

    console.log('\n✨ All button permission tables have been emptied!');
    console.log('\n📊 You can now use ButtonGenerator to populate fresh data from the sidebar code.');

  } catch (error) {
    console.error('Error:', error.message);
  }
}

emptyTables();
