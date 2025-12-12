#!/usr/bin/env node

/**
 * Quick check - test anon key access to button tables
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://supabase.urbanaqura.com';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';

const supabase = createClient(SUPABASE_URL, ANON_KEY);

async function testAccess() {
  try {
    console.log('🧪 Testing anon key access to button tables...\n');

    // Test 1: SELECT
    console.log('Test 1: SELECT from button_main_sections');
    const { data: selectData, error: selectError } = await supabase
      .from('button_main_sections')
      .select('*')
      .limit(1);

    if (selectError) {
      console.error('❌ SELECT failed:', selectError.message);
      if (selectError.message.includes('401')) {
        console.log('   Reason: 401 Unauthorized - RLS policy blocking SELECT');
      }
    } else {
      console.log('✅ SELECT works:', selectData?.length || 0, 'rows');
    }

    // Test 2: INSERT (test only, don't commit)
    console.log('\nTest 2: Attempting INSERT to button_main_sections');
    const { data: insertData, error: insertError } = await supabase
      .from('button_main_sections')
      .insert({
        name_en: 'TEST_BUTTON_' + Date.now(),
        name_ar: 'اختبار',
        is_active: true
      })
      .select()
      .single();

    if (insertError) {
      console.error('❌ INSERT failed:', insertError.message);
      if (insertError.message.includes('401')) {
        console.log('   Reason: 401 Unauthorized - RLS policy blocking INSERT');
      }
    } else {
      console.log('✅ INSERT works! ID:', insertData?.id);
      
      // Clean up - delete the test record
      if (insertData?.id) {
        await supabase
          .from('button_main_sections')
          .delete()
          .eq('id', insertData.id);
        console.log('   Cleaned up test record');
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY:');
    console.log('='.repeat(60));
    
    if (selectError && selectError.message.includes('401')) {
      console.log('\n🚨 PROBLEM: RLS policies are NOT allowing anon key access');
      console.log('\n✅ Solutions:');
      console.log('   1. Verify SQL was executed in Supabase SQL Editor');
      console.log('   2. Check that ALTER TABLE ENABLE ROW LEVEL SECURITY ran');
      console.log('   3. Use this SQL to check current state:');
      console.log(`
      SELECT tablename, count(*) as policy_count
      FROM pg_policies
      WHERE tablename IN ('button_main_sections', 'button_sub_sections', 'sidebar_buttons', 'button_permissions')
      GROUP BY tablename
      ORDER BY tablename;
      `);
    } else {
      console.log('\n✅ SUCCESS! Anon key can access button tables');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testAccess().then(() => {
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
