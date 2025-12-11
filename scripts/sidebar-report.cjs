#!/usr/bin/env node

/**
 * Final Report: Sidebar Structure (Sections, Subsections, Buttons)
 * Data from actual database
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function getFullStructure() {
  try {
    console.log('\n🔘 SIDEBAR COMPLETE STRUCTURE:\n');
    console.log('═'.repeat(70));

    // Get all data
    const { data: sections } = await supabase
      .from('button_main_sections')
      .select('id, section_code, section_name_en')
      .order('display_order');

    const { data: subsections } = await supabase
      .from('button_sub_sections')
      .select('id, main_section_id, subsection_code, subsection_name_en')
      .order('display_order');

    const { data: buttons } = await supabase
      .from('sidebar_buttons')
      .select('id, main_section_id, subsection_id, button_name_en, button_code')
      .order('display_order');

    let totalButtons = 0;

    sections.forEach((section, index) => {
      console.log(`\n${index + 1}. ${section.section_name_en.toUpperCase()}`);
      
      const sectionSubs = subsections.filter(s => s.main_section_id === section.id);
      const sectionButtons = buttons.filter(b => b.main_section_id === section.id);

      sectionSubs.forEach(sub => {
        const subButtons = sectionButtons.filter(b => b.subsection_id === sub.id);
        console.log(`   └─ ${sub.subsection_name_en} [${subButtons.length}]`);
        
        subButtons.slice(0, 2).forEach(btn => {
          console.log(`      • ${btn.button_name_en}`);
        });
        
        if (subButtons.length > 2) {
          console.log(`      ... and ${subButtons.length - 2} more`);
        }
        
        totalButtons += subButtons.length;
      });

      console.log(`   📌 Section Total: ${sectionButtons.length} buttons`);
    });

    console.log('\n' + '═'.repeat(70));
    console.log(`\n📊 FINAL SUMMARY:`);
    console.log(`   Sections: ${sections.length}`);
    console.log(`   Subsections: ${subsections.length}`);
    console.log(`   Total Buttons: ${totalButtons}\n`);

  } catch (error) {
    console.error('Error:', error.message);
  }
}

getFullStructure();
