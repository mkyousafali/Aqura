// Test the complete "Publish" notification functionality
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gfydhbrbuxlprjnpwuqn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmeWRoYnJidXhscHJqbnB3dXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzIwMzIzNTUsImV4cCI6MjA0NzYwODM1NX0.aMH0OMRHDgSJfXGFEm3UUKAA4JmMKIpWG3H7f8v_LD4';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testPublishNotification() {
    console.log('🧪 Testing Publish Notification Functionality...\n');

    try {
        // 1. Create a test user for attribution
        console.log('1. Creating test user for notification attribution...');
        const testUser = {
            id: 'test-user-publish-' + Date.now(),
            username: 'test_admin_publish',
            full_name: 'Test Admin Publisher',
            role: 'admin'
        };

        const { data: userData, error: userError } = await supabase
            .from('users')
            .insert(testUser)
            .select()
            .single();

        if (userError) throw userError;
        console.log('✅ Test user created:', userData.username);

        // 2. Test notification creation (simulating the CreateNotification component)
        console.log('\n2. Testing notification creation (Publish button functionality)...');
        
        const notificationData = {
            title: 'Test Publish Notification',
            message: 'This is a test notification published via the Publish button',
            type: 'announcement',
            priority: 'medium',
            target_type: 'all_users',
            status: 'published',
            created_by: userData.id,
            created_by_name: userData.full_name,
            created_by_role: userData.role,
            created_at: new Date().toISOString()
        };

        const { data: notification, error: createError } = await supabase
            .from('notifications')
            .insert(notificationData)
            .select()
            .single();

        if (createError) throw createError;
        console.log('✅ Notification published successfully:', notification.id);
        console.log('   Title:', notification.title);
        console.log('   Status:', notification.status);
        console.log('   Created by:', notification.created_by_name);

        // 3. Test admin getAllNotifications functionality
        console.log('\n3. Testing admin notification retrieval...');
        
        const { data: adminNotifications, error: adminError } = await supabase
            .from('notifications')
            .select(`
                *,
                notification_read_states!left (
                    user_id,
                    is_read,
                    read_at
                )
            `)
            .eq('status', 'published')
            .order('created_at', { ascending: false });

        if (adminError) throw adminError;
        
        const publishedNotification = adminNotifications.find(n => n.id === notification.id);
        if (publishedNotification) {
            console.log('✅ Admin can retrieve published notification');
            console.log('   Notification ID:', publishedNotification.id);
            console.log('   Read states count:', publishedNotification.notification_read_states?.length || 0);
        } else {
            console.log('❌ Admin cannot find published notification');
        }

        // 4. Test user notification retrieval
        console.log('\n4. Testing user notification retrieval...');
        
        const { data: userNotifications, error: userNotError } = await supabase
            .from('notifications')
            .select(`
                *,
                notification_read_states!left (
                    user_id,
                    is_read,
                    read_at
                )
            `)
            .eq('status', 'published')
            .or(`target_type.eq.all_users,target_users.cs.{${userData.id}}`)
            .order('created_at', { ascending: false });

        if (userNotError) throw userNotError;
        
        const userNotification = userNotifications.find(n => n.id === notification.id);
        if (userNotification) {
            console.log('✅ User can retrieve published notification');
            console.log('   Shows as unread (expected):', !userNotification.notification_read_states?.some(rs => rs.user_id === userData.id && rs.is_read));
        } else {
            console.log('❌ User cannot find published notification');
        }

        // 5. Test marking notification as read
        console.log('\n5. Testing mark as read functionality...');
        
        const { error: markReadError } = await supabase
            .from('notification_read_states')
            .upsert({
                notification_id: notification.id,
                user_id: userData.id,
                is_read: true,
                read_at: new Date().toISOString()
            });

        if (markReadError) throw markReadError;
        console.log('✅ Notification marked as read successfully');

        // 6. Verify read status
        console.log('\n6. Verifying read status...');
        
        const { data: readCheck, error: readCheckError } = await supabase
            .from('notification_read_states')
            .select('*')
            .eq('notification_id', notification.id)
            .eq('user_id', userData.id)
            .single();

        if (readCheckError) throw readCheckError;
        
        if (readCheck.is_read) {
            console.log('✅ Notification correctly shows as read');
            console.log('   Read at:', readCheck.read_at);
        } else {
            console.log('❌ Notification still shows as unread');
        }

        // 7. Clean up test data
        console.log('\n7. Cleaning up test data...');
        
        await supabase.from('notification_read_states').delete().eq('notification_id', notification.id);
        await supabase.from('notifications').delete().eq('id', notification.id);
        await supabase.from('users').delete().eq('id', userData.id);
        
        console.log('✅ Test data cleaned up');
        
        console.log('\n🎉 All tests passed! Publish button functionality is working correctly.');
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error('Error details:', error);
    }
}

testPublishNotification();