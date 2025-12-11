#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkButtonCodes() {
  try {
    console.log('🔍 Checking Button Codes in Database...\n');

    const { data: buttons, error } = await supabase
      .from('sidebar_buttons')
      .select('button_code, button_name_en')
      .limit(20)
      .order('id');

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    console.log('Sample Button Codes from Database:');
    console.log('═'.repeat(70));
    buttons.forEach((btn, i) => {
      console.log(`${i + 1}. Code: "${btn.button_code}" | Name: "${btn.button_name_en}"`);
    });
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkButtonCodes();
