#!/usr/bin/env node

/**
 * Test Script: Insert Mock Test Section with Subsections and Buttons
 * This creates temporary test data in the database for testing the Button Generator
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function insertTestData() {
  try {
    console.log('Starting test data insertion...\n');

    // 1. Create test section
    console.log('1. Creating test section...');
    const { data: sectionData, error: sectionError } = await supabase
      .from('button_main_sections')
      .insert({
        section_name_en: 'Test Section',
        section_name_ar: 'قسم الاختبار',
        section_code: 'TEST_SECTION',
        display_order: 11,
        is_active: true
      })
      .select();

    if (sectionError) {
      console.error('Error creating section:', sectionError.message);
      return;
    }

    const testSectionId = sectionData[0].id;
    console.log(`✓ Created section with ID: ${testSectionId}\n`);

    // 2. Create subsections
    console.log('2. Creating test subsections...');
    const { data: subsectionData, error: subsectionError } = await supabase
      .from('button_sub_sections')
      .insert([
        {
          main_section_id: testSectionId,
          subsection_name_en: 'Test Dashboard',
          subsection_name_ar: 'لوحة تحكم الاختبار',
          subsection_code: 'TEST_DASHBOARD',
          display_order: 1,
          is_active: true
        },
        {
          main_section_id: testSectionId,
          subsection_name_en: 'Test Management',
          subsection_name_ar: 'إدارة الاختبار',
          subsection_code: 'TEST_MANAGEMENT',
          display_order: 2,
          is_active: true
        }
      ])
      .select();

    if (subsectionError) {
      console.error('Error creating subsections:', subsectionError.message);
      return;
    }

    console.log(`✓ Created ${subsectionData.length} subsections\n`);

    // 3. Create mock buttons
    console.log('3. Creating test buttons...');
    
    const mockButtons = [
      // Custom button (single word, no underscore, not in standard list)
      {
        main_section_id: testSectionId,
        subsection_id: subsectionData[0].id,
        button_name_en: 'Test Custom Button',
        button_name_ar: 'زر الاختبار المخصص',
        button_code: 'TEST_CUSTOM_BUTTON',
        icon: '🧪',
        display_order: 1,
        is_active: true
      },
      // Another custom button
      {
        main_section_id: testSectionId,
        subsection_id: subsectionData[1].id,
        button_name_en: 'Custom Feature',
        button_name_ar: 'ميزة مخصصة',
        button_code: 'CUSTOM_FEATURE_SPECIAL_ACTION',
        icon: '⚙️',
        display_order: 2,
        is_active: true
      },
      // Standard pattern button (for comparison)
      {
        main_section_id: testSectionId,
        subsection_id: subsectionData[0].id,
        button_name_en: 'Test Standard',
        button_name_ar: 'اختبار معياري',
        button_code: 'TEST_STANDARD',
        icon: '✓',
        display_order: 3,
        is_active: true
      }
    ];

    const { data: buttonData, error: buttonError } = await supabase
      .from('sidebar_buttons')
      .insert(mockButtons)
      .select();

    if (buttonError) {
      console.error('Error creating buttons:', buttonError.message);
      return;
    }

    console.log(`✓ Created ${buttonData.length} buttons\n`);

    // 4. Create permissions for all users
    console.log('4. Creating button permissions for all users...');
    const { data: allUsers } = await supabase.from('users').select('id');

    if (allUsers && allUsers.length > 0) {
      const permissionRecords = [];
      for (const button of buttonData) {
        for (const user of allUsers) {
          permissionRecords.push({
            user_id: user.id,
            button_id: button.id,
            is_enabled: false
          });
        }
      }

      const { error: permError } = await supabase.from('button_permissions').insert(permissionRecords);

      if (permError) {
        console.error('Error creating permissions:', permError.message);
        return;
      }

      console.log(`✓ Created ${permissionRecords.length} permission records\n`);
    }

    console.log('═══════════════════════════════════════════════════════════');
    console.log('✓ TEST DATA INSERTED SUCCESSFULLY!');
    console.log('═══════════════════════════════════════════════════════════\n');

    console.log('Test Data Summary:');
    console.log(`• Section: "Test Section" (CODE: TEST_SECTION, ID: ${testSectionId})`);
    console.log(`• Subsections: "Test Dashboard", "Test Management"`);
    console.log(`• Buttons created:`);
    console.log(`  - TEST_CUSTOM_BUTTON (single word pattern - may be detected as custom)`);
    console.log(`  - CUSTOM_FEATURE_SPECIAL_ACTION (4 parts - will be detected as custom)`);
    console.log(`  - TEST_STANDARD (standard 2-part pattern)\n`);

    console.log('Next Steps:');
    console.log('1. Open the Button Generator in your application');
    console.log('2. Click "✓ Check New Custom Buttons" in the Buttons tab');
    console.log('3. Verify that the modal shows the custom buttons with their locations\n');

    console.log('To clean up test data, run:');
    console.log('  DELETE FROM sidebar_buttons WHERE main_section_id = ' + testSectionId + ';');
    console.log('  DELETE FROM button_main_sections WHERE id = ' + testSectionId + ';');

  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

insertTestData();
