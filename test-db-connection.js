import { createClient } from '@supabase/supabase-js';
import https from 'https';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

console.log('='.repeat(60));
console.log('SUPABASE CONNECTION TEST');
console.log('='.repeat(60));
console.log('URL:', supabaseUrl);
console.log('Date:', new Date().toISOString());
console.log('='.repeat(60));

// Test 1: Basic HTTP connectivity
async function testHttpConnectivity() {
  console.log('\n[Test 1] Testing HTTP connectivity...');
  return new Promise((resolve) => {
    const url = new URL(supabaseUrl);
    const options = {
      hostname: url.hostname,
      port: 443,
      path: '/rest/v1/',
      method: 'GET',
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': `Bearer ${supabaseAnonKey}`
      }
    };

    const req = https.request(options, (res) => {
      console.log(`Status Code: ${res.statusCode}`);
      console.log(`Status Message: ${res.statusMessage}`);
      
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('✅ HTTP endpoint is reachable');
          resolve(true);
        } else {
          console.log('❌ HTTP endpoint returned error');
          console.log('Response:', data.substring(0, 200));
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.log('❌ HTTP request failed:', error.message);
      resolve(false);
    });

    req.end();
  });
}

// Test 2: Supabase client initialization
async function testClientInit() {
  console.log('\n[Test 2] Testing Supabase client initialization...');
  try {
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    console.log('✅ Supabase client initialized');
    return supabase;
  } catch (error) {
    console.log('❌ Client initialization failed:', error.message);
    return null;
  }
}

// Test 3: Database query
async function testDatabaseQuery(supabase) {
  console.log('\n[Test 3] Testing database query...');
  try {
    const { data, error } = await supabase
      .from('products')
      .select('id')
      .limit(1);
    
    if (error) {
      console.log('❌ Query failed:', error.message);
      console.log('Error details:', error);
      return false;
    }
    
    console.log('✅ Database query successful');
    console.log('Data:', data);
    return true;
  } catch (err) {
    console.log('❌ Unexpected error:', err.message);
    return false;
  }
}

// Test 4: Auth service
async function testAuthService(supabase) {
  console.log('\n[Test 4] Testing auth service...');
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) {
      console.log('❌ Auth check failed:', error.message);
      return false;
    }
    
    console.log('✅ Auth service accessible');
    console.log('Session status:', session ? 'Active' : 'No active session');
    return true;
  } catch (err) {
    console.log('❌ Auth error:', err.message);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  const httpOk = await testHttpConnectivity();
  const supabase = await testClientInit();
  
  if (!supabase) {
    console.log('\n' + '='.repeat(60));
    console.log('⚠️  Cannot proceed without Supabase client');
    console.log('='.repeat(60));
    return;
  }
  
  const dbOk = await testDatabaseQuery(supabase);
  const authOk = await testAuthService(supabase);
  
  console.log('\n' + '='.repeat(60));
  console.log('TEST SUMMARY');
  console.log('='.repeat(60));
  console.log('HTTP Connectivity:', httpOk ? '✅ PASS' : '❌ FAIL');
  console.log('Client Init:', supabase ? '✅ PASS' : '❌ FAIL');
  console.log('Database Query:', dbOk ? '✅ PASS' : '❌ FAIL');
  console.log('Auth Service:', authOk ? '✅ PASS' : '❌ FAIL');
  console.log('='.repeat(60));
  
  if (httpOk && supabase && dbOk && authOk) {
    console.log('\n✅ ALL TESTS PASSED - Database connection is healthy!');
  } else {
    console.log('\n❌ SOME TESTS FAILED - Please check the errors above');
  }
}

runAllTests();
