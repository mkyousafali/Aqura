// Test script for push notifications after deployment
import { supabase } from '../frontend/src/lib/utils/supabase.js';

async function testPushNotificationFunction() {
  console.log('🧪 Testing Supabase Edge Function for Push Notifications...');

  const testSubscription = {
    endpoint: 'https://example.com/test-endpoint',
    keys: {
      p256dh: 'test-p256dh-key',
      auth: 'test-auth-key'
    }
  };

  const testPayload = {
    title: 'Test Notification',
    body: 'This is a test from your Aqura system!',
    icon: '/favicon.png',
    data: { url: '/test' }
  };

  try {
    console.log('📤 Calling edge function...');
    
    const { data, error } = await supabase.functions.invoke('send-push-notification', {
      body: {
        subscription: testSubscription,
        payload: testPayload
      }
    });

    if (error) {
      console.error('❌ Edge function error:', error);
      return false;
    }

    console.log('✅ Edge function response:', data);
    console.log('🎉 Push notification function is working!');
    return true;

  } catch (err) {
    console.error('❌ Test failed:', err);
    return false;
  }
}

// Run the test
testPushNotificationFunction().then(success => {
  if (success) {
    console.log('\n✅ DEPLOYMENT SUCCESSFUL!');
    console.log('Push notifications are ready to use in your application.');
  } else {
    console.log('\n❌ DEPLOYMENT NEEDS ATTENTION');
    console.log('Check the deployment guide: EASY_SUPABASE_DEPLOYMENT.md');
  }
});