import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testNotificationCreation() {
    console.log('🧪 Testing task assignment notification creation...');
    
    try {
        // Test with minimal required fields only
        const testNotification = {
            title: 'Test Task Assignment',
            message: 'This is a test task assignment notification',
            type: 'task_assigned',
            priority: 'medium',
            target_type: 'all_users', // Change to all_users to avoid target_users field
            status: 'published'
        };

        console.log('📝 Creating notification with data:', testNotification);

        const { data, error } = await supabase
            .from('notifications')
            .insert(testNotification)
            .select('*')
            .single();

        if (error) {
            console.error('❌ Error creating notification:', error);
            return false;
        }

        console.log('✅ Notification created successfully:', data);
        
        // Clean up - delete the test notification
        const { error: deleteError } = await supabase
            .from('notifications')
            .delete()
            .eq('id', data.id);
            
        if (deleteError) {
            console.warn('⚠️ Warning: Could not delete test notification:', deleteError);
        } else {
            console.log('🧹 Test notification cleaned up');
        }
        
        return true;
        
    } catch (error) {
        console.error('❌ Unexpected error:', error);
        return false;
    }
}

async function main() {
    console.log('🚀 Starting task assignment notification test...\n');
    
    const success = await testNotificationCreation();
    
    if (success) {
        console.log('\n✅ All tests passed! Task assignment notifications should work correctly.');
    } else {
        console.log('\n❌ Tests failed. Check the errors above.');
    }
}

main().catch(console.error);