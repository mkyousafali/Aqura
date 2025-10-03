// Test push notification registration manually
console.log('🧪 Testing Push Notification Registration...\n');

// Mock the browser environment for testing
const mockSubscription = {
  endpoint: 'https://fcm.googleapis.com/fcm/send/test-endpoint-12345',
  keys: {
    p256dh: 'BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8',
    auth: 'test-auth-key-12345'
  }
};

// Test the exact data structure that should work
const testData = {
  user_id: 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', // Your current user ID
  device_id: `${Date.now()}-test-device`,
  push_subscription: mockSubscription, // This should be JSONB
  device_type: 'desktop',
  browser_name: 'Chrome',
  user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  is_active: true,
  last_seen: new Date().toISOString()
};

console.log('📋 Test data structure:');
console.log(JSON.stringify(testData, null, 2));

console.log('\n🔍 Data validation:');
console.log('✅ user_id:', typeof testData.user_id, testData.user_id);
console.log('✅ device_id:', typeof testData.device_id, testData.device_id);
console.log('✅ push_subscription:', typeof testData.push_subscription, 'keys:', Object.keys(testData.push_subscription));
console.log('✅ device_type:', typeof testData.device_type, testData.device_type);
console.log('✅ browser_name:', typeof testData.browser_name, testData.browser_name);
console.log('✅ user_agent:', typeof testData.user_agent, testData.user_agent.substring(0, 50) + '...');
console.log('✅ is_active:', typeof testData.is_active, testData.is_active);
console.log('✅ last_seen:', typeof testData.last_seen, testData.last_seen);

console.log('\n💡 The issue might be:');
console.log('1. RLS (Row Level Security) policies expecting auth.uid()');
console.log('2. Custom auth system not matching Supabase auth');
console.log('3. Column name mismatch (but this looks correct)');

console.log('\n🔧 Solutions to try:');
console.log('1. Use service role key (bypasses RLS)');
console.log('2. Temporarily disable RLS for testing');
console.log('3. Use proper Supabase auth token');

console.log('\n📝 Recommended fix: Use anon key with proper auth or service role key');