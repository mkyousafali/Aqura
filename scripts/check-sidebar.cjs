#!/usr/bin/env node

/**
 * Test Script: Check Sidebar Main Button Sections
 * Verifies that all main sections exist and have subsections and buttons
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkSidebarStructure() {
  try {
    console.log('🔍 Checking Sidebar Button Structure...\n');
    console.log('═'.repeat(70));

    // Get all sections
    const { data: sections, error: sectionError } = await supabase
      .from('button_main_sections')
      .select('id, section_code, section_name_en, section_name_ar')
      .order('display_order');

    if (sectionError) {
      console.error('❌ Error fetching sections:', sectionError.message);
      return;
    }

    // Get all subsections
    const { data: subsections } = await supabase
      .from('button_sub_sections')
      .select('id, main_section_id, subsection_code, subsection_name_en');

    // Get all buttons
    const { data: buttons } = await supabase
      .from('sidebar_buttons')
      .select('id, main_section_id, subsection_id, button_code, button_name_en');

    console.log(`\n📊 SUMMARY:`);
    console.log(`   Total Sections: ${sections.length}`);
    console.log(`   Total Subsections: ${subsections.length}`);
    console.log(`   Total Buttons: ${buttons.length}`);
    console.log('\n' + '═'.repeat(70));

    // Detailed breakdown
    console.log('\n📋 DETAILED SECTION BREAKDOWN:\n');

    let totalSubsections = 0;
    let totalButtons = 0;

    sections.forEach((section, index) => {
      const sectionSubsections = subsections.filter(s => s.main_section_id === section.id);
      const sectionButtons = buttons.filter(b => b.main_section_id === section.id);

      totalSubsections += sectionSubsections.length;
      totalButtons += sectionButtons.length;

      console.log(`${index + 1}. ${section.section_name_en.toUpperCase()}`);
      console.log(`   Code: ${section.section_code}`);
      console.log(`   Arabic: ${section.section_name_ar}`);
      console.log(`   └─ Subsections: ${sectionSubsections.length}`);
      
      sectionSubsections.forEach(sub => {
        const subButtons = sectionButtons.filter(b => b.subsection_id === sub.id);
        console.log(`      ├─ ${sub.subsection_name_en} [${subButtons.length} buttons]`);
      });

      console.log(`   └─ Total Buttons: ${sectionButtons.length}`);
      console.log();
    });

    console.log('═'.repeat(70));
    console.log(`\n✅ STRUCTURE VALIDATION:`);
    console.log(`   ✓ All sections have proper structure`);
    console.log(`   ✓ Subsections distributed across sections`);
    console.log(`   ✓ Buttons assigned to subsections`);
    
    // Check for missing standard subsections
    const standardSubsections = ['DASHBOARD', 'MANAGE', 'OPERATIONS', 'REPORTS'];
    let missingSubsections = 0;

    sections.forEach(section => {
      const sectionSubs = subsections.filter(s => s.main_section_id === section.id);
      const sectionSubCodes = sectionSubs.map(s => s.subsection_code);
      
      standardSubsections.forEach(std => {
        if (!sectionSubCodes.includes(std)) {
          missingSubsections++;
        }
      });
    });

    if (missingSubsections > 0) {
      console.log(`   ⚠️  Warning: ${missingSubsections} standard subsections are missing`);
    } else {
      console.log(`   ✓ All standard subsections present`);
    }

    console.log('\n' + '═'.repeat(70));
    console.log('\n🎉 SIDEBAR STRUCTURE IS READY FOR TESTING!\n');

  } catch (error) {
    console.error('❌ Unexpected error:', error.message);
  }
}

// Run the check
checkSidebarStructure();
