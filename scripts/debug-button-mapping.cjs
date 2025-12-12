const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function debugButtonMapping() {
  const userId = '6f883b06-13a8-476b-86ce-a7a79553a4bd';
  
  console.log('🔍 Debugging button mapping issue...\n');

  try {
    // Get enabled button IDs for this user
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('button_id, is_enabled')
      .eq('user_id', userId)
      .eq('is_enabled', true)
      .order('button_id');

    if (permError) throw permError;

    console.log(`📊 Found ${permissions.length} enabled button IDs:\n`);
    
    const enabledIds = permissions.map(p => p.button_id);
    console.log('Button IDs:', enabledIds.join(', '));
    console.log('\n' + '='.repeat(80) + '\n');

    // Now get what those IDs actually map to
    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('id, button_code, button_name_en')
      .in('id', enabledIds)
      .order('id');

    if (btnError) throw btnError;

    console.log('✅ Actual buttons for these IDs:\n');
    buttons.forEach(btn => {
      console.log(`   ID ${btn.id.toString().padStart(3)} → ${btn.button_code.padEnd(35)} - ${btn.button_name_en}`);
    });

    console.log('\n' + '='.repeat(80) + '\n');

    // Check if button codes match what UI shows
    console.log('🔍 Checking if UI buttons exist in enabled list:\n');
    
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

    const enabledCodes = buttons.map(b => b.button_code);
    
    uiButtons.forEach(code => {
      const exists = enabledCodes.includes(code);
      console.log(`   ${exists ? '✅' : '❌'} ${code}`);
    });

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

debugButtonMapping();
