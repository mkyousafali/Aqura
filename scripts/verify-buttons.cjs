const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkButtons() {
  // Get all buttons with section and subsection info
  const { data: buttons, error } = await supabase
    .from('sidebar_buttons')
    .select('id, button_code, button_name_en, button_name_ar, main_section_id, subsection_id')
    .order('button_code');
  
  if (error) {
    console.log('Error:', error.message);
    return;
  }

  // Get sections and subsections for mapping
  const { data: sections } = await supabase.from('button_main_sections').select('id, section_code, section_name_en');
  const { data: subsections } = await supabase.from('button_sub_sections').select('id, subsection_code, subsection_name_en');

  const sectionMap = {};
  const subsectionMap = {};
  sections.forEach(s => sectionMap[s.id] = s);
  subsections.forEach(s => subsectionMap[s.id] = s);

  console.log('Total buttons in database:', buttons.length);
  console.log('\n--- ALL BUTTON CODES ---\n');
  
  buttons.forEach(b => {
    const section = sectionMap[b.main_section_id];
    const subsection = subsectionMap[b.subsection_id];
    const hasSeparator = b.button_code.includes('_');
    const parts = b.button_code.split('_').length;
    console.log(`${b.button_code} | ${b.button_name_en} | Section: ${section?.section_code} | Sub: ${subsection?.subsection_code} | Parts: ${parts}`);
  });

  // Analyze which buttons are "custom" by the current logic
  console.log('\n--- BUTTONS MATCHING CUSTOM CRITERIA ---\n');
  const customButtons = buttons.filter(b => {
    return !b.button_code.includes('_') || b.button_code.split('_').length > 3;
  });

  if (customButtons.length === 0) {
    console.log('No buttons match custom criteria (no underscore OR more than 3 parts)');
  } else {
    console.log(`Found ${customButtons.length} buttons matching custom criteria:\n`);
    customButtons.forEach(b => {
      const section = sectionMap[b.main_section_id];
      const subsection = subsectionMap[b.subsection_id];
      console.log(`- ${b.button_code} (${b.button_name_en}) [${section?.section_code} > ${subsection?.subsection_code}]`);
    });
  }
}

checkButtons();
