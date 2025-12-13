const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../frontend/.env') });

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseServiceKey = process.env.VITE_SUPABASE_SERVICE_KEY;

if (!supabaseServiceKey) {
  console.error('❌ VITE_SUPABASE_SERVICE_KEY not found in frontend/.env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function checkUserAdminStatus() {
  try {
    console.log('\n🔍 Checking user admin status...\n');

    // Get all users to see who might be trying to approve
    const { data: users, error } = await supabase
      .from('users')
      .select('id, username, is_admin, is_master_admin')
      .order('username');

    if (error) {
      console.error('❌ Error fetching users:', error);
      return;
    }

    console.log('📊 All Users:');
    console.log('─'.repeat(100));
    
    users.forEach(user => {
      const adminStatus = user.is_admin ? '✅ Admin' : '❌ Not Admin';
      const masterAdminStatus = user.is_master_admin ? '✅ Master Admin' : '❌ Not Master Admin';
      const canApprove = user.is_admin || user.is_master_admin;
      
      console.log(`
User: ${user.username || 'No username'}
ID: ${user.id}
${adminStatus}
${masterAdminStatus}
Can Approve Customers: ${canApprove ? '✅ YES' : '❌ NO'}
${'─'.repeat(100)}
      `);
    });

    // Count admin users
    const adminUsers = users.filter(u => u.is_admin || u.is_master_admin);
    console.log(`\n📈 Summary: ${adminUsers.length} user(s) with admin privileges out of ${users.length} total users\n`);

  } catch (err) {
    console.error('❌ Unexpected error:', err);
  }
}

checkUserAdminStatus();
