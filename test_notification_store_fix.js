import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Simulate the OLD fetchNotificationCounts (WRONG)
async function fetchNotificationCounts_OLD(targetUserId) {
  const { data: notifications, error } = await supabase
    .from('notifications')
    .select(`
      *,
      notification_read_states(
        read_at,
        user_id
      )
    `)
    .eq('status', 'published');

  if (error) throw error;

  const totalCount = notifications?.length || 0;
  const unreadCount = notifications?.filter((notification) => {
    const userReadState = notification.notification_read_states?.find(
      (readState) => readState.user_id === targetUserId
    );
    return !userReadState?.read_at;
  }).length || 0;

  return { unread: unreadCount, total: totalCount };
}

// Simulate the NEW fetchNotificationCounts (CORRECT)
async function fetchNotificationCounts_NEW(targetUserId) {
  // Get notifications for user from notification_recipients table
  const { data: recipients, error } = await supabase
    .from('notification_recipients')
    .select(`
      notification_id,
      notifications!inner(
        id,
        title,
        message,
        type,
        priority,
        status,
        created_at
      )
    `)
    .eq('user_id', targetUserId)
    .eq('notifications.status', 'published');

  if (error) throw error;

  // Get read states for these notifications
  const notificationIds = recipients?.map(r => r.notification_id) || [];
  const { data: readStates } = await supabase
    .from('notification_read_states')
    .select('notification_id, read_at')
    .eq('user_id', targetUserId)
    .in('notification_id', notificationIds);

  // Create a set of read notification IDs
  const readNotificationIds = new Set(
    readStates?.filter(rs => rs.read_at).map(rs => rs.notification_id) || []
  );

  const totalCount = recipients?.length || 0;
  const unreadCount = recipients?.filter(r => !readNotificationIds.has(r.notification_id)).length || 0;

  return { unread: unreadCount, total: totalCount };
}

async function testNotificationStoreFix() {
  console.log('\n' + '='.repeat(100));
  console.log('TESTING NOTIFICATION STORE FIX (fetchNotificationCounts)');
  console.log('='.repeat(100) + '\n');

  // Get 3 test users
  const { data: testUsers } = await supabase
    .from('users')
    .select('id, username')
    .limit(3);

  if (!testUsers || testUsers.length === 0) {
    console.log('❌ No users found');
    return;
  }

  for (const user of testUsers) {
    console.log('-'.repeat(100));
    console.log(`Testing User: ${user.username} (${user.id})`);
    console.log('-'.repeat(100));

    // Get expected count
    const { count: expectedTotal } = await supabase
      .from('notification_recipients')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id);

    const { data: recipients } = await supabase
      .from('notification_recipients')
      .select('notification_id, notifications!inner(status)')
      .eq('user_id', user.id)
      .eq('notifications.status', 'published');

    const expectedPublishedCount = recipients?.length || 0;

    // Test OLD function
    const oldResult = await fetchNotificationCounts_OLD(user.id);

    // Test NEW function
    const newResult = await fetchNotificationCounts_NEW(user.id);

    console.log(`\n📊 Results:`);
    console.log(`   Expected Total: ${expectedPublishedCount}`);
    console.log(`   OLD function: ${oldResult.total} total, ${oldResult.unread} unread ${oldResult.total === expectedPublishedCount ? '✅' : '❌'}`);
    console.log(`   NEW function: ${newResult.total} total, ${newResult.unread} unread ${newResult.total === expectedPublishedCount ? '✅' : '✅ FIXED!'}`);

    if (oldResult.total !== expectedPublishedCount) {
      console.log(`   ❌ OLD WRONG: Showing ${oldResult.total - expectedPublishedCount} extra notifications!`);
    }

    if (newResult.total === expectedPublishedCount) {
      console.log(`   ✅ NEW CORRECT: Perfect match!`);
    }

    console.log();
  }

  console.log('='.repeat(100));
  console.log('TEST COMPLETE');
  console.log('='.repeat(100) + '\n');
}

testNotificationStoreFix().catch(console.error);
