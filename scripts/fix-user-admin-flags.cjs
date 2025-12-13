const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../frontend/.env') });

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseServiceKey = process.env.VITE_SUPABASE_SERVICE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function fixUserAdminFlags() {
  try {
    console.log('\n🔧 Checking and fixing user admin flags...\n');

    // Get users that should be admins based on their username
    const adminUsernames = ['yousafali', 'madmin', 'Ahmed md sahli', 'Abdhusathar', 'Sadham', 'shamsu'];

    console.log('📋 Checking admin status for key users:\n');

    for (const username of adminUsernames) {
      const { data: user, error } = await supabase
        .from('users')
        .select('id, username, is_admin, is_master_admin')
        .eq('username', username)
        .single();

      if (error || !user) {
        console.log(`❌ ${username}: Not found`);
        continue;
      }

      const hasAdminPrivileges = user.is_admin || user.is_master_admin;
      const statusIcon = hasAdminPrivileges ? '✅' : '❌';
      
      console.log(`${statusIcon} ${user.username}:`);
      console.log(`   - is_admin: ${user.is_admin}`);
      console.log(`   - is_master_admin: ${user.is_master_admin}`);
      console.log(`   - Can approve: ${hasAdminPrivileges ? 'YES' : 'NO'}`);

      // If user should have admin but doesn't, offer to fix
      if (!hasAdminPrivileges) {
        console.log(`   ⚠️  WARNING: ${username} should be admin but has no admin flags!`);
        
        // Auto-fix: Grant admin privileges
        const { error: updateError } = await supabase
          .from('users')
          .update({ 
            is_admin: true,
            updated_at: new Date().toISOString()
          })
          .eq('id', user.id);

        if (updateError) {
          console.log(`   ❌ Failed to grant admin: ${updateError.message}`);
        } else {
          console.log(`   ✅ FIXED: Granted admin privileges to ${username}`);
        }
      }
      console.log('');
    }

    console.log('\n🔍 Checking for users currently logged in (active sessions)...\n');

    // Check user_sessions table
    const { data: sessions, error: sessionsError } = await supabase
      .from('user_sessions')
      .select(`
        user_id,
        created_at,
        users (
          id,
          username,
          is_admin,
          is_master_admin
        )
      `)
      .order('created_at', { ascending: false })
      .limit(10);

    if (sessionsError) {
      console.log('❌ Error checking sessions:', sessionsError.message);
    } else if (sessions && sessions.length > 0) {
      console.log('📊 Recent login sessions:\n');
      sessions.forEach((session, index) => {
        const user = session.users;
        if (user) {
          const hasAdmin = user.is_admin || user.is_master_admin;
          const icon = hasAdmin ? '✅' : '❌';
          console.log(`${icon} ${user.username}`);
          console.log(`   - Logged in: ${new Date(session.created_at).toLocaleString()}`);
          console.log(`   - Can approve: ${hasAdmin ? 'YES' : 'NO'}`);
        }
      });
    } else {
      console.log('ℹ️  No recent sessions found');
    }

    console.log('\n✅ Admin flags check complete!\n');
    console.log('💡 If a user still gets "Access denied", they need to:');
    console.log('   1. Log out completely');
    console.log('   2. Log back in (to refresh their session with new admin flags)');
    console.log('   3. Try approving customers again\n');

  } catch (err) {
    console.error('❌ Unexpected error:', err);
  }
}

fixUserAdminFlags();
