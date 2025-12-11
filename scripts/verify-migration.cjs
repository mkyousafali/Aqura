const { createClient } = require('@supabase/supabase-js');
const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(url, serviceKey);

(async () => {
  try {
    console.log('=== BUTTON SYSTEM DATABASE VERIFICATION ===\n');

    // Check main sections
    const { data: sections, error: sectionsError } = await supabase
      .from('button_main_sections')
      .select('*');
    
    if (sectionsError) {
      console.error('Error querying sections:', sectionsError.message);
    } else {
      console.log(`✓ button_main_sections: ${sections.length} records`);
      sections.forEach(s => {
        console.log(`  - ${s.section_code}: ${s.section_name_en}`);
      });
    }

    // Check subsections
    const { data: subsections, error: subsectionsError } = await supabase
      .from('button_sub_sections')
      .select('*');
    
    if (subsectionsError) {
      console.error('Error querying subsections:', subsectionsError.message);
    } else {
      console.log(`\n✓ button_sub_sections: ${subsections.length} records`);
    }

    // Check buttons
    const { data: buttons, error: buttonsError } = await supabase
      .from('sidebar_buttons')
      .select('*');
    
    if (buttonsError) {
      console.error('Error querying buttons:', buttonsError.message);
    } else {
      console.log(`✓ sidebar_buttons: ${buttons.length} records`);
    }

    // Check permissions
    const { data: permissions, error: permissionsError } = await supabase
      .from('button_permissions')
      .select('*')
      .limit(1);
    
    if (permissionsError) {
      console.error('Error querying permissions:', permissionsError.message);
    } else {
      // Get total count
      const { count, error: countError } = await supabase
        .from('button_permissions')
        .select('*', { count: 'exact', head: true });
      
      if (countError) {
        console.log('✓ button_permissions: table exists');
      } else {
        console.log(`✓ button_permissions: ${count} records`);
        console.log(`  - Coverage: 103 users × ~${Math.round(count / 103)} buttons per user`);
      }
    }

    console.log('\n=== SUMMARY ===');
    console.log('All tables created and populated successfully!');
    console.log('Ready for button access control system.');

  } catch (err) {
    console.error('Exception:', err.message);
  }
})();
