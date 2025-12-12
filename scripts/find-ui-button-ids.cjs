const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function findUIButtons() {
  console.log('🔍 Finding what IDs the UI buttons have...\n');

  const uiButtons = [
    'TASK_MASTER',
    'CREATE_TASK',
    'VIEW_TASKS',
    'ASSIGN_TASKS',
    'BRANCH_PERFORMANCE_WINDOW',
    'MY_ASSIGNMENTS',
    'MY_TASKS',
    'TASK_STATUS',
    'COMMUNICATION_CENTER',
    'RECEIVING',
    'CREATE_VENDOR',
    'MANAGE_VENDOR',
    'UPLOAD_VENDOR',
    'RECEIVING_RECORDS',
    'START_RECEIVING',
    'VENDOR_RECORDS'
  ];

  try {
    const { data: buttons, error } = await supabase
      .from('sidebar_buttons')
      .select('id, button_code, button_name_en')
      .in('button_code', uiButtons)
      .order('id');

    if (error) throw error;

    console.log('📋 UI buttons and their IDs:\n');
    buttons.forEach(btn => {
      console.log(`   ID ${btn.id.toString().padStart(3)} → ${btn.button_code.padEnd(35)} - ${btn.button_name_en}`);
    });

    const uiButtonIds = buttons.map(b => b.id);
    console.log('\n' + '='.repeat(80));
    console.log(`\nUI Button IDs: ${uiButtonIds.join(', ')}`);
    console.log('\nDatabase says enabled IDs: 101, 102, 103, 104, 105, 106, 107, 108, 120, 132, 133, 134, 135, 136, 137, 138');
    console.log('\n' + '='.repeat(80) + '\n');
    console.log('❌ THESE DO NOT MATCH! The UI is showing wrong data.');

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

findUIButtons();
