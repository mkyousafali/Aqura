// Test if service role key is working
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testServiceRole() {
    console.log('Testing service role key...');
    
    try {
        // Test table access
        const { data, error } = await supabase
            .from('push_subscriptions')
            .select('*')
            .limit(1);
            
        if (error) {
            console.error('❌ Service role test failed:', error);
        } else {
            console.log('✅ Service role key is working');
            console.log('Data:', data);
        }
        
        // Test insert with dummy data
        const testData = {
            user_id: 'test-user-id',
            device_id: 'test-device-' + Date.now(),
            push_subscription: { test: true },
            device_type: 'desktop',
            browser_name: 'test',
            user_agent: 'test-agent',
            is_active: true
        };
        
        const { data: insertData, error: insertError } = await supabase
            .from('push_subscriptions')
            .insert(testData)
            .select();
            
        if (insertError) {
            console.error('❌ Insert test failed:', insertError);
        } else {
            console.log('✅ Insert test successful');
            
            // Clean up test data
            await supabase
                .from('push_subscriptions')
                .delete()
                .eq('device_id', testData.device_id);
                
            console.log('✅ Test data cleaned up');
        }
        
    } catch (err) {
        console.error('❌ Unexpected error:', err);
    }
}

testServiceRole();