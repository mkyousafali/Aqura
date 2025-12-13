const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../frontend/.env') });

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseAnonKey) {
  console.error('❌ VITE_SUPABASE_ANON_KEY not found in frontend/.env');
  process.exit(1);
}

// This simulates what happens in the browser
const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

async function testApprovalFunction() {
  try {
    console.log('\n🧪 Testing approve_customer_account function...\n');

    // Try to call the function without being logged in (should fail)
    console.log('1️⃣ Testing without authentication...');
    const { data: unauthData, error: unauthError } = await supabase.rpc('approve_customer_account', {
      p_customer_id: '00000000-0000-0000-0000-000000000000',
      p_status: 'approved',
      p_notes: 'test',
      p_approved_by: '00000000-0000-0000-0000-000000000000'
    });

    if (unauthError) {
      console.log('❌ Expected error (not authenticated):', unauthError.message);
    } else {
      console.log('⚠️ Unexpected success without auth');
    }

    console.log('\n📋 Admin users who CAN approve customers:');
    console.log('─'.repeat(80));
    console.log('1. yousafali (Admin + Master Admin)');
    console.log('2. madmin (Master Admin)');
    console.log('3. Ahmed md sahli (Master Admin)');
    console.log('4. Abdhusathar (Admin)');
    console.log('5. Sadham (Admin)');
    console.log('6. shamsu (Admin)');
    console.log('─'.repeat(80));

    console.log('\n💡 To fix the error:');
    console.log('1. Make sure you are logged in as one of the admin users listed above');
    console.log('2. Or grant admin privileges to the current user');
    console.log('\n');

  } catch (err) {
    console.error('❌ Unexpected error:', err);
  }
}

testApprovalFunction();
