const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkRealButtons() {
  const userId = '6f883b06-13a8-476b-86ce-a7a79553a4bd';
  
  console.log('🔍 Finding ACTUAL enabled buttons (not sorted)...\n');

  try {
    // Get enabled button permissions
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('button_id')
      .eq('user_id', userId)
      .eq('is_enabled', true);

    if (permError) throw permError;

    const enabledIds = permissions.map(p => p.button_id);
    console.log(`Found ${enabledIds.length} enabled button IDs:`, enabledIds, '\n');

    // Get the actual button details WITHOUT sorting by code
    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('id, button_code, button_name_en')
      .in('id', enabledIds)
      .order('id');  // Sort by ID, not code

    if (btnError) throw btnError;

    console.log('✅ ENABLED BUTTONS (sorted by ID):\n');
    buttons.forEach((btn, idx) => {
      console.log(`${(idx + 1).toString().padStart(3)}. ID:${btn.id.toString().padStart(3)} ${btn.button_code.padEnd(35)} - ${btn.button_name_en}`);
    });

    // Now check what the UI is showing
    console.log('\n' + '='.repeat(80));
    console.log('\n🎯 Checking UI buttons:\n');
    
    const uiButtonCodes = [
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
    
    let matchCount = 0;
    uiButtonCodes.forEach(code => {
      const isEnabled = enabledCodes.includes(code);
      if (isEnabled) matchCount++;
      console.log(`   ${isEnabled ? '✅' : '❌'} ${code}`);
    });

    console.log(`\n📊 Match: ${matchCount}/${uiButtonCodes.length} UI buttons are in enabled list`);

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkRealButtons();
