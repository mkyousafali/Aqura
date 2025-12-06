# 🔐 AUTHENTICATION & SECURITY SYSTEM AUDIT REPORT
**Date:** December 6, 2025  
**Status:** ⚠️ CRITICAL SECURITY ISSUES FOUND

---

## EXECUTIVE SUMMARY

Your application has **RLS policies enabled** but has several **critical security gaps** that undermine their effectiveness:

1. **Service Role (`supabaseAdmin`) used in frontend** - BYPASSES ALL RLS POLICIES
2. **Unvalidated user context in RLS checks** - Users can query data they shouldn't access
3. **No proper request authentication flow** - Missing JWT verification in API routes
4. **Client-side API requests without role verification** - Services bypass authentication checks
5. **Inconsistent session management** - Quick access codes stored in plaintext

---

## CRITICAL ISSUES FOUND

### ⚠️ ISSUE #1: Service Role Key Exposed in Frontend (CRITICAL)

**Location:** `frontend/src/lib/utils/supabase.ts` (Lines 1-100)

```typescript
const supabaseServiceKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY || 
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";

export const supabaseAdmin = (() => {
  _supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _supabaseAdmin;
})();
```

**Risk:** Service role key grants **full database access, bypassing ALL RLS policies**

**Where it's used (10+ locations found):**
- `src/routes/api/customer/products-with-offers/+server.ts` - Queries 7 tables without RLS
- `src/routes/api/customer/featured-offers/+server.ts` - All queries bypass RLS
- `src/lib/utils/pushSubscriptionCleanup.ts` - Unprotected cleanup operations
- `src/lib/utils/pushNotifications.ts` - Direct admin access
- Multiple API endpoints query databases directly

**Impact Score:** 🔴 CRITICAL - Any user can access any data if they reverse-engineer API calls

---

### ⚠️ ISSUE #2: No User Context Validation in RLS

**Location:** `frontend/src/lib/utils/persistentAuth.ts` (Lines 600-650)

```typescript
// ✅ Sets context but:
// 1. No validation that it succeeded
// 2. Frontend client can set ANY user_id/role_type
// 3. RLS depends on this unverified context

try {
  await supabase.rpc('set_user_context', {
    user_id: userData.id,
    role_type: userData.role_type  // ❌ From unverified client data
  });
} catch (contextError) {
  console.warn("⚠️ Failed to set user context:", contextError);
  // ❌ Continues login even if RLS context fails!
}
```

**Risk:** Even with RLS policies, if context setting fails, user may access unrestricted data

**Impact Score:** 🔴 HIGH

---

### ⚠️ ISSUE #3: Quick Access Codes Not Hashed

**Location:** Multiple login components

```typescript
// In CashierLogin.svelte, MobileLogin, etc:
const { data: userData, error: authError } = await supabase
  .from('users')
  .select('id, username, quick_access_code')  // ❌ Plaintext code comparison
  .eq('quick_access_code', accessCode)        // ❌ Direct comparison
  .single();
```

**Risk:** If database is compromised, all quick access codes are exposed

**Better Approach:** Hash codes with salt (salt should already be in DB)

---

### ⚠️ ISSUE #4: No JWT Validation in API Routes

**Location:** All API routes like `src/routes/api/customer/products-with-offers/+server.ts`

```typescript
export const GET: RequestHandler = async ({ url }) => {
  const branchId = url.searchParams.get('branchId');  // ❌ No auth check!
  
  // ❌ No verification that request is from authenticated user
  // ❌ No JWT token validation
  // ❌ Anyone can call this endpoint
  
  const { data: offers, error: offersError } = await supabaseAdmin
    .from('offers')
    .select('*')  // ❌ Full access via service role
    .eq('is_active', true);
};
```

**Risk:** API endpoints are public - no authentication required

---

### ⚠️ ISSUE #5: Inconsistent User Context Across Sessions

**Location:** Session management in `persistentAuth.ts`

- Login method stores context in RLS via `set_user_context()`
- Quick access login does the same
- But if browser tab closes, context is lost
- Next request uses old/cached context or none at all

---

### ⚠️ ISSUE #6: Service Roles Used for Data Queries

**Locations with risk:**
```
✗ src/routes/api/customer/products-with-offers/+server.ts (8 queries)
✗ src/routes/api/customer/featured-offers/+server.ts (all queries)
✗ src/lib/utils/pushSubscriptionCleanup.ts (5+ operations)
✗ src/lib/utils/pushQueuePoller.ts
✗ src/lib/utils/pushNotifications.ts
✗ supabase.ts storage operations (2 locations)
```

**All of these bypass RLS because they use `supabaseAdmin`**

---

## CURRENT AUTHENTICATION FLOW ISSUES

### Login Flow (Current):
```
1. User enters username/password or quick access code
2. Frontend queries users table (still via anon key for quick access)
3. set_user_context() called but no verification
4. Session stored in localStorage
5. API requests happen with...
   ❌ No token validation
   ❌ Service role queries (bypass RLS)
   ❌ Unverified user context
```

### Why RLS isn't working:
```
RLS Policy requires:
  - auth.uid() = user_id ✅ Set by set_user_context
  - user_role matches check ✅ Set by set_user_context
  
But policy enforcement is bypassed by:
  - supabaseAdmin queries (10+ places)
  - API routes with no auth check
  - Context can fail silently
```

---

## RECOMMENDED FIXES (Priority Order)

### 🔴 PRIORITY 1: Remove Service Role from Frontend (IMMEDIATE)

**Action:** Move ALL `supabaseAdmin` queries to backend API routes with authentication

```typescript
// ❌ BEFORE (Frontend - supabase.ts)
export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

// ✅ AFTER (Backend only - API route)
export const GET: RequestHandler = async ({ request, locals }) => {
  // 1. Validate JWT token
  const token = request.headers.get('Authorization')?.split(' ')[1];
  const user = await verifyToken(token);
  
  if (!user) return json({ error: 'Unauthorized' }, { status: 401 });
  
  // 2. Use service role on backend only
  const { data } = await supabaseAdmin
    .from('table')
    .select('*')
    .eq('user_id', user.id);  // ✅ Verified user context
  
  return json(data);
};
```

**Affected Files to Fix:**
- `src/routes/api/customer/products-with-offers/+server.ts` - Move to backend
- `src/routes/api/customer/featured-offers/+server.ts` - Move to backend
- `src/lib/utils/supabase.ts` - Remove supabaseAdmin export
- `src/lib/utils/pushSubscriptionCleanup.ts` - Use API route
- `src/lib/utils/pushNotifications.ts` - Use API route
- All storage operations - Move to backend

---

### 🔴 PRIORITY 2: Implement Proper JWT Token Validation

**Create:** `src/lib/server/auth.ts`

```typescript
import * as jwt from '@supabase/gotrue-js';

export async function validateRequest(request: Request) {
  const token = request.headers.get('Authorization')?.split(' ')[1];
  
  if (!token) {
    return { user: null, error: 'No token provided' };
  }
  
  try {
    // Verify JWT signature
    const decoded = await supabase.auth.getUser(token);
    
    if (!decoded) {
      return { user: null, error: 'Invalid token' };
    }
    
    // Get user with role verification
    const { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('id', decoded.user.id)
      .single();
    
    return { user, error: null };
  } catch (err) {
    return { user: null, error: err.message };
  }
}
```

**Apply to all API routes:**
```typescript
export const GET: RequestHandler = async ({ request }) => {
  const { user, error } = await validateRequest(request);
  
  if (!user) {
    return json({ error }, { status: 401 });
  }
  
  // ✅ Now user is verified
  return json(data);
};
```

---

### 🔴 PRIORITY 3: Hash Quick Access Codes

**Update:** User table quick access code storage

```sql
-- Add hashing function (if not exists)
CREATE OR REPLACE FUNCTION hash_quick_access_code(code TEXT, salt TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN encode(
    digest(code || salt, 'sha256'),
    'hex'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update user validation to hash input
-- Before storing, hash: hash_quick_access_code(code, salt)
-- Before comparing: hash_quick_access_code(input, salt) = stored_hash
```

**Update:** Login function

```typescript
// Hash before comparing
const { data: salt } = await supabase
  .from('users')
  .select('quick_access_salt')
  .eq('username', username)
  .single();

const hashedInput = await hashCode(accessCode, salt);

const { data: user } = await supabase
  .from('users')
  .select('*')
  .eq('quick_access_code_hash', hashedInput)  // Compare hash, not plaintext
  .single();
```

---

### 🔴 PRIORITY 4: Validate User Context Setting

```typescript
// In persistentAuth.ts
try {
  const { error: contextError } = await supabase.rpc('set_user_context', {
    user_id: userData.id,
    role_type: userData.role_type
  });
  
  if (contextError) {
    throw new Error("Failed to set user context");  // ✅ Fail if context fails
  }
  
  console.log("✅ User context verified");
} catch (contextError) {
  // ✅ Don't continue if RLS context failed
  return { 
    success: false, 
    error: "Security context setup failed. Please try again." 
  };
}
```

---

### 🟡 PRIORITY 5: Implement Rate Limiting

```typescript
// Create middleware for API routes
export async function handleRateLimit(userId: string): Promise<boolean> {
  const cacheKey = `rate-limit:${userId}`;
  
  // Check Redis/cache for request count
  const count = await cache.increment(cacheKey);
  
  if (count === 1) {
    await cache.expire(cacheKey, 60); // Reset every 60 seconds
  }
  
  // Allow 60 requests per minute per user
  return count <= 60;
}
```

---

## TESTING CHECKLIST

### Test 1: Verify RLS Actually Works
```sql
-- As anonymous user:
SELECT * FROM users;  -- Should be empty

-- As authenticated user:
SELECT * FROM users WHERE id = current_user_id();  -- Should return own record

-- As different user (simulate context breach):
-- Should NOT return data outside their scope
```

### Test 2: Test API Authentication
```bash
# Without token:
curl https://app.com/api/customer/products  
# Expected: 401 Unauthorized

# With invalid token:
curl -H "Authorization: Bearer INVALID" https://app.com/api/customer/products
# Expected: 401 Unauthorized

# With valid token:
curl -H "Authorization: Bearer VALID_JWT" https://app.com/api/customer/products
# Expected: 200 OK with user's data only
```

### Test 3: Test Service Role is Not Accessible
```bash
# Try to use service role key from frontend:
curl -H "Authorization: Bearer SERVICE_ROLE_KEY" https://app.com/api/
# Expected: Should fail or be restricted
```

---

## SECURITY HEADERS CHECKLIST

Add to `svelte.config.js` or headers:

```javascript
// In SvelteKit hooks
export async function handle({ event, resolve }) {
  const response = await resolve(event);
  
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  
  return response;
}
```

---

## SUMMARY TABLE

| Issue | Severity | Status | Action |
|-------|----------|--------|--------|
| Service role in frontend | 🔴 CRITICAL | NOT FIXED | Remove immediately |
| No API authentication | 🔴 CRITICAL | NOT FIXED | Add JWT validation |
| Plaintext quick access codes | 🔴 CRITICAL | NOT FIXED | Implement hashing |
| Unvalidated RLS context | 🔴 HIGH | NOT FIXED | Add validation |
| No rate limiting | 🟡 MEDIUM | NOT FIXED | Implement ASAP |
| Missing security headers | 🟡 MEDIUM | NOT FIXED | Add headers |

---

## NEXT STEPS

1. **TODAY:** Remove `supabaseAdmin` from frontend (src/lib/utils/supabase.ts)
2. **TODAY:** Add JWT validation to all API routes
3. **TOMORROW:** Hash quick access codes
4. **TOMORROW:** Add rate limiting to API endpoints
5. **THIS WEEK:** Add security headers
6. **THIS WEEK:** Conduct full RLS testing

---

## CONTACT

For questions about this audit, refer to the detailed analysis in each section above.

**Generated:** 2025-12-06  
**Review Cycle:** Every 2 weeks or after code changes
