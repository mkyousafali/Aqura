// Test push notification registration with the corrected service role key
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

console.log('🧪 Testing push notification registration...\n');

// Generate a UUID from string (matching the frontend logic)
function generateUUIDFromString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
    }
    
    // Create a proper 32-character hex string from the hash
    const hex = Math.abs(hash).toString(16).padStart(8, '0');
    // Repeat and extend to get 32 chars
    const fullHex = (hex + hex + hex + hex).substring(0, 32);
    
    // Format as proper UUID
    const uuid = `${fullHex.slice(0, 8)}-${fullHex.slice(8, 12)}-4${fullHex.slice(13, 16)}-a${fullHex.slice(17, 20)}-${fullHex.slice(20, 32)}`;
    return uuid;
}

async function testPushRegistration() {
    try {
        // Use a real user from the database 
        const testUser = {
            id: 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', // Real user ID from database
            username: 'madmin'
        };
        
        const deviceId = `test-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        // Use the actual user ID since this user exists in database
        const userUUID = testUser.id;
        
        console.log('👤 Test user:', testUser);
        console.log('🔄 Original ID:', testUser.id);
        console.log('🆔 Generated UUID:', userUUID);
        console.log('📱 Device ID:', deviceId);
        
        // Test data structure that matches the actual table schema
        const testRegistration = {
            user_id: userUUID,
            device_id: deviceId,
            endpoint: 'https://fcm.googleapis.com/fcm/send/test-endpoint',
            p256dh: 'test-p256dh-key-string',
            auth: 'test-auth-key-string',
            device_type: 'desktop',
            browser_name: 'Chrome',
            user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            is_active: true,
            last_seen: new Date().toISOString()
        };
        
        console.log('\n📤 Attempting to insert test registration...');
        
        const { data, error } = await supabase
            .from('push_subscriptions')
            .insert(testRegistration)
            .select();
            
        if (error) {
            console.error('❌ Registration failed:', error);
            return false;
        } else {
            console.log('✅ Registration successful!');
            console.log('📊 Inserted data:', data);
            
            // Clean up test data
            console.log('\n🧹 Cleaning up test data...');
            const { error: deleteError } = await supabase
                .from('push_subscriptions')
                .delete()
                .eq('device_id', deviceId);
                
            if (deleteError) {
                console.warn('⚠️ Cleanup failed:', deleteError);
            } else {
                console.log('✅ Test data cleaned up');
            }
            
            return true;
        }
        
    } catch (err) {
        console.error('❌ Test failed with exception:', err);
        return false;
    }
}

async function testUpdateLastSeen() {
    try {
        console.log('\n🕐 Testing updateLastSeen functionality...');
        
        // Create a test device first using real user
        const deviceId = `test-update-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const userUUID = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b'; // Use real user ID
        
        const testDevice = {
            user_id: userUUID,
            device_id: deviceId,
            endpoint: 'https://fcm.googleapis.com/fcm/send/test-update-endpoint',
            p256dh: 'test-update-p256dh-key',
            auth: 'test-update-auth-key',
            device_type: 'desktop',
            browser_name: 'Chrome',
            user_agent: 'test-agent',
            is_active: true,
            last_seen: new Date().toISOString()
        };
        
        // Insert test device
        const { error: insertError } = await supabase
            .from('push_subscriptions')
            .insert(testDevice);
            
        if (insertError) {
            console.error('❌ Failed to create test device:', insertError);
            return false;
        }
        
        console.log('📱 Created test device:', deviceId);
        
        // Wait a second then update last_seen
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        const newLastSeen = new Date().toISOString();
        const { error: updateError } = await supabase
            .from('push_subscriptions')
            .update({ 
                last_seen: newLastSeen,
                is_active: true 
            })
            .eq('device_id', deviceId);
            
        if (updateError) {
            console.error('❌ Failed to update last_seen:', updateError);
        } else {
            console.log('✅ Successfully updated last_seen');
        }
        
        // Clean up
        await supabase
            .from('push_subscriptions')
            .delete()
            .eq('device_id', deviceId);
            
        console.log('✅ Test device cleaned up');
        return !updateError;
        
    } catch (err) {
        console.error('❌ UpdateLastSeen test failed:', err);
        return false;
    }
}

async function runAllTests() {
    console.log('🚀 Starting push notification tests...\n');
    
    const test1 = await testPushRegistration();
    const test2 = await testUpdateLastSeen();
    
    console.log('\n📊 Test Results:');
    console.log(`   Registration test: ${test1 ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`   UpdateLastSeen test: ${test2 ? '✅ PASS' : '❌ FAIL'}`);
    
    if (test1 && test2) {
        console.log('\n🎉 All tests passed! Push notifications should work correctly.');
    } else {
        console.log('\n⚠️ Some tests failed. Check the errors above.');
    }
}

runAllTests();