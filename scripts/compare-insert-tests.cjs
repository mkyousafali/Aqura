const { createClient } = require('@supabase/supabase-js');

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';
const supabase = createClient('https://supabase.urbanaqura.com', anonKey);

(async () => {
  try {
    console.log('=== COMPARING INSERTS ===\n');
    
    // Test 1: branches INSERT (this works)
    console.log('Test 1: INSERT to branches (works)');
    const { error: branchError } = await supabase
      .from('branches')
      .insert({
        name_en: 'Test Branch ' + Date.now(),
        name_ar: 'فرع الاختبار',
        location_en: 'Test Location',
        location_ar: 'موقع الاختبار',
        is_active: true
      });
    
    if (branchError) {
      console.error('❌ branches INSERT failed:', branchError.code, branchError.message);
    } else {
      console.log('✅ branches INSERT works!');
    }
    
    // Test 2: button_main_sections INSERT (this fails)
    console.log('\nTest 2: INSERT to button_main_sections (fails)');
    const { error: buttonError } = await supabase
      .from('button_main_sections')
      .insert({
        section_code: 'TEST_' + Date.now(),
        section_name_en: 'Test Section',
        section_name_ar: 'قسم اختبار',
        display_order: 1,
        is_active: true
      });
    
    if (buttonError) {
      console.error('❌ button_main_sections INSERT failed:', buttonError.code, buttonError.message);
    } else {
      console.log('✅ button_main_sections INSERT works!');
    }
    
    // Test 3: Try with only required fields
    console.log('\nTest 3: INSERT to button_main_sections with minimal fields');
    const { error: minimalError } = await supabase
      .from('button_main_sections')
      .insert({
        section_code: 'MINIMAL_' + Date.now(),
        section_name_en: 'Minimal Test'
      });
    
    if (minimalError) {
      console.error('❌ Minimal INSERT failed:', minimalError.code, minimalError.message);
    } else {
      console.log('✅ Minimal INSERT works!');
    }
  } catch (e) {
    console.error('Exception:', e.message);
  }
})();
