const { createClient } = require('@supabase/supabase-js');

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';
const supabase = createClient('https://supabase.urbanaqura.com', anonKey);

(async () => {
  try {
    console.log('=== TESTING BUTTON TABLES ===\n');
    
    console.log('Test 1: SELECT from button_main_sections');
    const { data: selectData, error: selectError } = await supabase
      .from('button_main_sections')
      .select('count')
      .limit(1);
    
    if (selectError) {
      console.error('❌ SELECT failed:', selectError.code, selectError.message);
    } else {
      console.log('✅ SELECT works!');
    }
    
    console.log('\nTest 2: Try INSERT without .select()');
    const { error: insertError } = await supabase
      .from('button_main_sections')
      .insert({ 
        section_code: 'DIAG_' + Date.now(),
        section_name_en: 'Test', 
        section_name_ar: 'اختبار', 
        display_order: 1, 
        is_active: true 
      });
    
    if (insertError) {
      console.error('❌ INSERT failed:', insertError.code, '-', insertError.message);
      console.error('Details:', insertError.details);
      console.error('Hint:', insertError.hint);
    } else {
      console.log('✅ INSERT works!');
    }
  } catch (e) {
    console.error('Exception:', e.message);
  }
})();
