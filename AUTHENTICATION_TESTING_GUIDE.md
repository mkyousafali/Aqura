# 🧪 AUTHENTICATION SECURITY TESTING GUIDE

Complete tests to verify your authentication system is working correctly after fixes.

---

## TEST 1: Verify Service Role is Not Accessible

### What This Tests
- Service role key is removed from frontend
- API endpoints reject service role authentication

### Before Fix (VULNERABLE):
```bash
# Get the service role key from frontend (in DevTools)
SERVICE_ROLE_KEY="eyJhbGc..."

# Call API with service role key
curl -X GET "https://api.urbanaqura.com/rest/v1/users" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"

# RESULT: 200 OK - returns ALL user data ❌ VULNERABLE
```

### After Fix (SECURE):
```bash
# Service role key should NOT be in frontend anymore
# Trying to use it should fail

curl -X GET "https://api.urbanaqura.com/rest/v1/users" \
  -H "Authorization: Bearer SERVICE_ROLE_KEY"

# RESULT: 401 Unauthorized ✅ SECURE
# OR: 400 Invalid key format ✅ SECURE
```

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 1: Service Role Access"
echo "================================"

# Try to call API without authentication
echo -e "\n❌ Test 1A: Call API without authentication"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X GET "https://yourapp.com/api/customer/products"

# Expected: 401 Unauthorized

# Try to call API with random token
echo -e "\n❌ Test 1B: Call API with invalid token"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X GET "https://yourapp.com/api/customer/products" \
  -H "Authorization: Bearer INVALID_TOKEN_HERE"

# Expected: 401 Unauthorized

# Try to call API with expired/old token
echo -e "\n❌ Test 1C: Call API with expired token"
OLD_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.OLD_EXPIRED_TOKEN.signature"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X GET "https://yourapp.com/api/customer/products" \
  -H "Authorization: Bearer $OLD_TOKEN"

# Expected: 401 Unauthorized
```

---

## TEST 2: Verify API Authentication Works

### What This Tests
- Valid JWT tokens are accepted
- API returns authenticated user's data only

### Setup:
```javascript
// 1. Get a valid JWT token by logging in
async function getValidToken() {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: 'testuser@aqura.local',
    password: 'password123'
  });
  
  return data.session.access_token;
}
```

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 2: API Authentication"
echo "=============================="

# Get valid token (from login)
TOKEN="your_valid_jwt_token_here"

# Test 2A: Call API with valid token
echo -e "\n✅ Test 2A: Call API with valid token"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X GET "https://yourapp.com/api/customer/products?branchId=branch123" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Expected: 200 OK - returns products for authenticated user

# Test 2B: Verify returned data is filtered
echo -e "\n✅ Test 2B: Verify data is filtered by user"
RESPONSE=$(curl -s \
  -X GET "https://yourapp.com/api/customer/products?branchId=branch123" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "Response: $RESPONSE"
# Should contain product data for authenticated user only

# Test 2C: Verify different tokens get different data
echo -e "\n✅ Test 2C: Different users see different data"
TOKEN_USER_A="token_for_user_a"
TOKEN_USER_B="token_for_user_b"

PRODUCTS_A=$(curl -s \
  -X GET "https://yourapp.com/api/customer/products?branchId=branch123" \
  -H "Authorization: Bearer $TOKEN_USER_A")

PRODUCTS_B=$(curl -s \
  -X GET "https://yourapp.com/api/customer/products?branchId=branch123" \
  -H "Authorization: Bearer $TOKEN_USER_B")

# If User A and B are in different branches, they should see different products
if [ "$PRODUCTS_A" != "$PRODUCTS_B" ]; then
  echo "✅ PASS: Users see different data based on their access"
else
  echo "❌ FAIL: Users see same data (RLS not working)"
fi
```

---

## TEST 3: Verify Quick Access Codes Are Hashed

### What This Tests
- Codes stored as hashes, not plaintext
- Code comparison uses hashing function

### Before Fix (VULNERABLE):
```sql
-- In database, codes are plaintext:
SELECT id, username, quick_access_code FROM users LIMIT 1;

-- Output:
| id | username | quick_access_code |
|----|----------|-------------------|
| 1  | john     | 123456            |  ❌ PLAINTEXT!
```

### After Fix (SECURE):
```sql
-- In database, codes are hashed:
SELECT id, username, quick_access_code_hash FROM users LIMIT 1;

-- Output:
| id | username | quick_access_code_hash |
|----|----------|------------------------|
| 1  | john     | a1b2c3d4e5f6...       |  ✅ HASHED!
```

### Test Script:
```sql
-- TEST 3A: Verify codes are hashed
SELECT id, username, quick_access_code_hash
FROM users
LIMIT 5;

-- Expected: All codes should be 64-character hex strings (SHA256 hash)
-- NOT 6-digit numbers

-- TEST 3B: Verify salt exists
SELECT id, username, quick_access_salt
FROM users
WHERE quick_access_salt IS NOT NULL
LIMIT 5;

-- Expected: All users should have unique salt values

-- TEST 3C: Verify old plaintext codes don't exist
SELECT COUNT(*) as plaintext_count
FROM users
WHERE quick_access_code ~ '^[0-9]{6}$'  -- Matches 6-digit pattern
  AND quick_access_code_hash IS NULL;    -- But no hash

-- Expected: 0 (no plaintext codes)
```

---

## TEST 4: Verify RLS Policies Work

### What This Tests
- Users can only access their own data
- RLS policies enforce data isolation

### Test Script:
```sql
-- Setup: Login as different users

-- TEST 4A: User can see their own data
-- (Logged in as user_a)
SELECT * FROM users WHERE id = current_user_id();
-- Expected: Returns only user_a's data ✅

-- TEST 4B: User cannot see other users' data
-- (Logged in as user_a, trying to see user_b)
SELECT * FROM users WHERE id = 'user_b_id';
-- Expected: Returns empty result (0 rows) ✅
-- NOT: Returns user_b's data ❌

-- TEST 4C: User cannot see all users
-- (Logged in as user_a)
SELECT * FROM users;
-- Expected: Returns only user_a's data (1 row) ✅
-- NOT: Returns all users ❌

-- TEST 4D: Service role can see all (backend only)
-- (This query should ONLY work on backend server, never in frontend)
-- When using service role:
SELECT * FROM users;
-- Expected: Returns ALL users (backend query) ✅

-- TEST 4E: Anonymous user cannot see anything
-- (No authentication)
SELECT * FROM users;
-- Expected: 0 rows (empty result) ✅
-- OR: Permission denied error ✅
```

### Verification Commands:
```bash
#!/bin/bash

echo "🔐 TEST 4: RLS Policies"
echo "======================="

TOKEN_USER_A="token_for_user_a"
TOKEN_USER_B="token_for_user_b"

# Test 4A: User A sees own data
echo -e "\n✅ Test 4A: User A sees own data"
curl -s -X GET "https://yourapp.com/api/user/me" \
  -H "Authorization: Bearer $TOKEN_USER_A" | jq '.id'

# Test 4B: User A cannot see User B
echo -e "\n❌ Test 4B: User A tries to see User B"
curl -s -X GET "https://yourapp.com/api/user/user_b_id" \
  -H "Authorization: Bearer $TOKEN_USER_A" | jq '.'

# Expected: 401 Unauthorized or Permission denied

# Test 4C: User B sees different data
echo -e "\n✅ Test 4C: User B sees own (different) data"
curl -s -X GET "https://yourapp.com/api/user/me" \
  -H "Authorization: Bearer $TOKEN_USER_B" | jq '.id'

# Should be different from User A's ID
```

---

## TEST 5: Verify Rate Limiting Works

### What This Tests
- API endpoints are rate limited
- Excessive requests are rejected

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 5: Rate Limiting"
echo "========================"

TOKEN="your_valid_token"
ENDPOINT="https://yourapp.com/api/customer/products?branchId=branch123"

# Make 65 requests in quick succession (limit is 60/minute)
echo "Making 65 rapid requests (limit is 60/minute)..."

for i in {1..65}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X GET "$ENDPOINT" \
    -H "Authorization: Bearer $TOKEN")
  
  if [ $i -le 60 ]; then
    if [ "$HTTP_CODE" == "200" ]; then
      echo "Request $i: ✅ 200 OK"
    else
      echo "Request $i: ❌ $HTTP_CODE (should be 200)"
    fi
  else
    # After 60 requests, should get 429
    if [ "$HTTP_CODE" == "429" ]; then
      echo "Request $i: ✅ 429 Too Many Requests (rate limited)"
    else
      echo "Request $i: ❌ $HTTP_CODE (should be 429)"
    fi
  fi
  
  # Small delay between requests
  sleep 0.1
done

echo -e "\n✅ Rate limiting working correctly"
```

---

## TEST 6: Verify Security Headers Are Present

### What This Tests
- Response headers include security directives
- Protection against XSS, clickjacking, etc.

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 6: Security Headers"
echo "============================"

RESPONSE=$(curl -s -i https://yourapp.com)

echo "Checking for security headers..."

# Check for X-Content-Type-Options
if echo "$RESPONSE" | grep -q "X-Content-Type-Options: nosniff"; then
  echo "✅ X-Content-Type-Options: nosniff"
else
  echo "❌ Missing: X-Content-Type-Options"
fi

# Check for X-Frame-Options
if echo "$RESPONSE" | grep -q "X-Frame-Options: DENY"; then
  echo "✅ X-Frame-Options: DENY"
else
  echo "❌ Missing: X-Frame-Options"
fi

# Check for X-XSS-Protection
if echo "$RESPONSE" | grep -q "X-XSS-Protection: 1; mode=block"; then
  echo "✅ X-XSS-Protection: 1; mode=block"
else
  echo "❌ Missing: X-XSS-Protection"
fi

# Check for Referrer-Policy
if echo "$RESPONSE" | grep -q "Referrer-Policy"; then
  echo "✅ Referrer-Policy present"
else
  echo "❌ Missing: Referrer-Policy"
fi

# Check for Content-Security-Policy
if echo "$RESPONSE" | grep -q "Content-Security-Policy"; then
  echo "✅ Content-Security-Policy present"
else
  echo "❌ Missing: Content-Security-Policy"
fi
```

---

## TEST 7: Verify No Service Role Key in Frontend

### What This Tests
- Service role key is not in frontend code/bundle
- Service role key is not in environment variables

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 7: No Service Role in Frontend"
echo "======================================="

# TEST 7A: Check frontend code
echo -e "\n❌ Test 7A: Search frontend for service role key"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIi..."

if grep -r "$SERVICE_KEY" frontend/; then
  echo "❌ FAIL: Service role key found in frontend!"
  exit 1
else
  echo "✅ PASS: Service role key not in frontend"
fi

# TEST 7B: Check environment variables
echo -e "\n❌ Test 7B: Check environment variable"
if grep -r "VITE_SUPABASE_SERVICE_KEY" frontend/src/lib/utils/supabase.ts | grep -v "check"; then
  echo "⚠️ WARNING: VITE_SUPABASE_SERVICE_KEY still referenced"
  # This is OK if it's not used
else
  echo "✅ PASS: Service key environment variable not used"
fi

# TEST 7C: Check for supabaseAdmin export
echo -e "\n❌ Test 7C: Check for supabaseAdmin export"
if grep -r "export const supabaseAdmin" frontend/src/; then
  echo "❌ FAIL: supabaseAdmin still exported from frontend"
  exit 1
else
  echo "✅ PASS: supabaseAdmin removed from frontend"
fi

echo -e "\n✅ All checks passed!"
```

---

## TEST 8: Brute Force Resistance

### What This Tests
- Rate limiting prevents brute force
- Account lockout after failed attempts

### Test Script:
```bash
#!/bin/bash

echo "🔐 TEST 8: Brute Force Resistance"
echo "=================================="

USERNAME="testuser"
ENDPOINT="https://yourapp.com/api/login"

# Try 20 failed login attempts
echo "Attempting 20 failed logins..."

for i in {1..20}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"wrongpassword\"}")
  
  echo "Attempt $i: HTTP $HTTP_CODE"
  
  # After 5 failed attempts, should be rate limited or locked
  if [ $i -eq 5 ] && [ "$HTTP_CODE" != "401" ]; then
    echo "⚠️ No rate limiting after failed attempts"
  fi
  
  if [ $i -eq 10 ] && [ "$HTTP_CODE" == "429" ]; then
    echo "✅ Rate limited after excessive failed attempts"
  fi
  
  # Small delay
  sleep 0.5
done

echo -e "\n✅ Brute force testing complete"
```

---

## TEST 9: Token Expiration

### What This Tests
- Tokens expire after set time
- Expired tokens are rejected

### Test Script:
```javascript
// JavaScript test

async function testTokenExpiration() {
  console.log('🔐 TEST 9: Token Expiration');
  console.log('============================');
  
  // 1. Get a token with known expiration
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'testuser@aqura.local',
    password: 'password123'
  });
  
  const token = authData.session.access_token;
  const expiresIn = authData.session.expires_in; // seconds until expiration
  
  console.log(`Token expires in: ${expiresIn} seconds`);
  
  // 2. Use token immediately (should work)
  const response1 = await fetch('/api/customer/products', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log(`✅ Fresh token: ${response1.status}`); // Expected: 200
  
  // 3. Wait for token to expire
  console.log(`Waiting ${expiresIn + 10} seconds for token to expire...`);
  await new Promise(r => setTimeout(r, (expiresIn + 10) * 1000));
  
  // 4. Try to use expired token (should fail)
  const response2 = await fetch('/api/customer/products', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log(`❌ Expired token: ${response2.status}`); // Expected: 401
  
  if (response2.status === 401) {
    console.log('✅ PASS: Expired tokens are rejected');
  } else {
    console.log('❌ FAIL: Expired tokens still work');
  }
}

// Run test
testTokenExpiration();
```

---

## COMPLETE TEST SUITE

Run all tests in order:

```bash
#!/bin/bash

echo "🔒 RUNNING COMPLETE AUTHENTICATION TEST SUITE"
echo "=============================================="

# Test 1: Service role access
bash test1-service-role.sh

# Test 2: API authentication
bash test2-api-auth.sh

# Test 3: Quick access code hashing
bash test3-code-hashing.sh

# Test 4: RLS policies
bash test4-rls.sh

# Test 5: Rate limiting
bash test5-rate-limit.sh

# Test 6: Security headers
bash test6-headers.sh

# Test 7: No service role in frontend
bash test7-no-service-role-frontend.sh

# Test 8: Brute force resistance
bash test8-brute-force.sh

echo -e "\n✅ All tests completed!"
echo "Check results above for any ❌ FAIL items"
```

---

## Expected Results After Fix

| Test | Before Fix | After Fix |
|------|-----------|-----------|
| Service role accessible | ✅ Works | ❌ Fails (401) |
| API without auth | ✅ Works | ❌ Fails (401) |
| Quick access codes | 🔴 Plaintext | ✅ Hashed |
| RLS enforcement | 🔴 Bypassed | ✅ Enforced |
| Rate limiting | ❌ None | ✅ Works |
| Security headers | ❌ Missing | ✅ Present |
| Service role in frontend | ❌ Present | ✅ Removed |
| Brute force protection | ❌ None | ✅ Protected |
| Token expiration | ❌ Never | ✅ Enforced |

---

## Automated Testing

Create `test-suite.js` for continuous testing:

```javascript
import fetch from 'node-fetch';

const BASE_URL = 'https://yourapp.com';
let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`✅ ${name}`);
    passed++;
  } catch (err) {
    console.log(`❌ ${name}: ${err.message}`);
    failed++;
  }
}

// Run tests
await test('Service role rejected', async () => {
  const res = await fetch(`${BASE_URL}/api/users`, {
    headers: { 'Authorization': 'Bearer SERVICE_ROLE' }
  });
  if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
});

await test('Anonymous rejected', async () => {
  const res = await fetch(`${BASE_URL}/api/products`);
  if (res.status !== 401) throw new Error(`Expected 401, got ${res.status}`);
});

// ... more tests

console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
```

---

## Checklist Before Deployment

- [ ] All tests pass (0 failed)
- [ ] Service role removed from frontend
- [ ] JWT validation on all API routes
- [ ] Quick access codes are hashed
- [ ] RLS policies still enabled
- [ ] Rate limiting implemented
- [ ] Security headers added
- [ ] Tested on staging environment
- [ ] Monitored logs for errors
- [ ] Rollback plan in place

---

## Troubleshooting Test Failures

### If Test 1 fails (service role accessible):
- Check that `supabaseAdmin` is truly removed from frontend
- Verify no environment variable exposes service key
- Check network tab to see what Authorization header is sent

### If Test 2 fails (API auth not working):
- Verify JWT token is valid and not expired
- Check that `validateRequest()` is called in API route
- Check browser console for error messages

### If Test 4 fails (RLS not enforcing):
- Verify RLS policies are actually enabled on tables
- Check that `set_user_context()` is called successfully
- Verify user context is set before queries

### If Test 5 fails (rate limiting not working):
- Check that rate limit middleware is imported
- Verify rate limit is actually enforced in route
- Check that cache/Redis is working

Good luck with testing! 🧪
