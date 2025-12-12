const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkUserButtons() {
  const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';
  
  console.log('🔍 Checking user and button permissions...\n');

  // 1. Check user details
  console.log('1️⃣ User Details:');
  const { data: user, error: userError } = await supabase
    .from('users')
    .select('id, username, is_master_admin, is_admin, user_type')
    .eq('id', userId)
    .single();

  if (userError) {
    console.log('   ❌ Error:', userError.message);
  } else {
    console.log('   Username:', user.username);
    console.log('   Is Master Admin:', user.is_master_admin);
    console.log('   Is Admin:', user.is_admin);
    console.log('   User Type:', user.user_type);
  }

  // 2. Check button permissions
  console.log('\n2️⃣ Button Permissions:');
  const { data: permissions, error: permError } = await supabase
    .from('button_permissions')
    .select(`
      id,
      is_enabled,
      sidebar_buttons (
        button_code,
        button_name_en,
        main_section_id,
        subsection_id
      )
    `)
    .eq('user_id', userId);

  if (permError) {
    console.log('   ❌ Error:', permError.message);
  } else {
    console.log(`   Total permissions: ${permissions.length}`);
    const enabled = permissions.filter(p => p.is_enabled);
    console.log(`   Enabled: ${enabled.length}`);
    console.log(`   Disabled: ${permissions.length - enabled.length}`);
    
    if (enabled.length === 0) {
      console.log('\n   ⚠️  WARNING: NO BUTTONS ENABLED FOR THIS USER!');
    } else {
      console.log('\n   Enabled buttons:');
      enabled.forEach(p => {
        console.log(`   - ${p.sidebar_buttons.button_code}: ${p.sidebar_buttons.button_name_en}`);
      });
    }
  }

  // 3. Check total sidebar buttons
  console.log('\n3️⃣ Total Sidebar Buttons in System:');
  const { data: allButtons, error: btnError } = await supabase
    .from('sidebar_buttons')
    .select('id, button_code, button_name_en, main_section_id, subsection_id');

  if (btnError) {
    console.log('   ❌ Error:', btnError.message);
  } else {
    console.log(`   Total buttons in system: ${allButtons.length}`);
  }

  // 4. Check delivery section buttons specifically
  console.log('\n4️⃣ Delivery Section Buttons:');
  const { data: sections, error: sectError } = await supabase
    .from('button_main_sections')
    .select('id, section_name_en')
    .ilike('section_name_en', '%delivery%');

  if (sectError) {
    console.log('   ❌ Error:', sectError.message);
  } else if (sections.length > 0) {
    for (const section of sections) {
      console.log(`\n   Section: ${section.section_name_en} (ID: ${section.id})`);
      
      const { data: sectionButtons } = await supabase
        .from('sidebar_buttons')
        .select('button_code, button_name_en')
        .eq('main_section_id', section.id);
      
      if (sectionButtons && sectionButtons.length > 0) {
        sectionButtons.forEach(btn => {
          console.log(`   - ${btn.button_code}: ${btn.button_name_en}`);
        });
      } else {
        console.log('   No buttons found in this section');
      }
    }
  } else {
    console.log('   No delivery section found');
  }

  console.log('\n✅ Check complete');
}

checkUserButtons().catch(console.error);
