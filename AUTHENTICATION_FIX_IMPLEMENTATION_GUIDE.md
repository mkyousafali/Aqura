# 🔒 STEP-BY-STEP AUTHENTICATION SYSTEM FIX GUIDE

## Overview
This guide provides exact code changes to secure your application's authentication system.

---

## STEP 1: Remove Service Role Key from Frontend

### File: `frontend/src/lib/utils/supabase.ts`

**BEFORE:**
```typescript
const supabaseServiceKey =
  import.meta.env.VITE_SUPABASE_SERVICE_KEY || "eyJhbGc...";

export const supabaseAdmin = (() => {
  _supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _supabaseAdmin;
})();
```

**AFTER:**
```typescript
// ✅ REMOVED: Service role key should NEVER be in frontend
// All admin operations must go through backend API routes

// Storage operations moved to backend - see STEP 7
```

**Why:** Service role key bypasses ALL RLS policies. Keep it only on backend server.

---

## STEP 2: Create Backend Auth Validation

### New File: `frontend/src/lib/server/auth.ts`

```typescript
import { supabase } from '$lib/utils/supabase';

/**
 * Validates JWT token from request header
 * Returns authenticated user data or null
 */
export async function validateRequest(request: Request) {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return { user: null, error: 'Missing or invalid authorization header' };
    }

    const token = authHeader.slice(7); // Remove "Bearer "

    // Verify token with Supabase
    const { data: { user: authUser }, error: authError } = 
      await supabase.auth.getUser(token);

    if (authError || !authUser) {
      console.warn('❌ [Auth] Token validation failed:', authError?.message);
      return { user: null, error: 'Invalid or expired token' };
    }

    // Get user details with role/permissions
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select(`
        id,
        username,
        role,
        role_type,
        user_type,
        status,
        hr_employees (
          id,
          employee_id,
          branch_id
        )
      `)
      .eq('id', authUser.id)
      .eq('status', 'active')
      .single();

    if (userError || !userData) {
      console.warn('❌ [Auth] User not found or inactive:', userError?.message);
      return { user: null, error: 'User not found or inactive' };
    }

    // ✅ User is authenticated and active
    return { 
      user: {
        ...authUser,
        ...userData,
      }, 
      error: null 
    };
  } catch (error) {
    console.error('❌ [Auth] Validation error:', error);
    return { user: null, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/**
 * Gets user ID from request (for use in RLS queries)
 */
export async function getUserIdFromRequest(request: Request): Promise<string | null> {
  const { user, error } = await validateRequest(request);
  if (error || !user) {
    return null;
  }
  return user.id;
}

/**
 * Checks if user has specific role
 */
export async function hasRole(request: Request, requiredRole: string): Promise<boolean> {
  const { user, error } = await validateRequest(request);
  if (error || !user) {
    return false;
  }
  return user.role_type === requiredRole;
}

/**
 * Checks if user is admin
 */
export async function isAdmin(request: Request): Promise<boolean> {
  const { user, error } = await validateRequest(request);
  if (error || !user) {
    return false;
  }
  return user.role_type === 'Master Admin' || user.role_type === 'Admin';
}
```

---

## STEP 3: Fix Customer Products API Route

### File: `frontend/src/routes/api/customer/products-with-offers/+server.ts`

**BEFORE:**
```typescript
import { supabaseAdmin } from '$lib/utils/supabase';

export const GET: RequestHandler = async ({ url }) => {
  const branchId = url.searchParams.get('branchId');
  
  // ❌ No authentication
  // ❌ Using supabaseAdmin (service role)
  const { data: offers, error: offersError } = await supabaseAdmin
    .from('offers')
    .select('*');  // Unrestricted access
};
```

**AFTER:**
```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';
import { validateRequest } from '$lib/server/auth';

export const GET: RequestHandler = async ({ request, url }) => {
  try {
    // ✅ STEP 1: Validate user authentication
    const { user, error: authError } = await validateRequest(request);
    
    if (authError || !user) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const branchId = url.searchParams.get('branchId');
    const serviceType = url.searchParams.get('serviceType');

    if (!branchId) {
      return json({ error: 'Missing branchId parameter' }, { status: 400 });
    }

    const now = new Date().toISOString();

    // ✅ STEP 2: Query as authenticated user (RLS applies)
    const { data: offers, error: offersError } = await supabase
      .from('offers')
      .select('*')
      .eq('is_active', true)
      .in('type', ['product', 'bogo', 'bundle'])
      .lte('start_date', now)
      .gte('end_date', now);

    if (offersError) {
      console.error('❌ Error fetching offers:', offersError);
      return json({ error: 'Failed to fetch offers' }, { status: 500 });
    }

    // ✅ STEP 3: Filter client-side based on user's branch access
    const filteredOffers = (offers || []).filter((offer) => {
      // Only show offers for user's branch or global offers
      if (offer.branch_id && offer.branch_id !== branchId) {
        return false;
      }
      
      // Filter by service type
      if (offer.service_type && offer.service_type !== 'both' && offer.service_type !== serviceType) {
        return false;
      }

      return true;
    });

    const offerIds = filteredOffers.map((o) => o.id);

    if (offerIds.length === 0) {
      // Get regular products
      const { data: products, error: productsError } = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('product_name_en');

      if (productsError) {
        return json({ error: 'Failed to fetch products' }, { status: 500 });
      }

      return json({ 
        products: products || [],
        offers: [],
        userId: user.id  // ✅ Return authenticated user ID
      });
    }

    // Get products for offers
    const { data: products, error: productsError } = await supabase
      .from('products')
      .select('*')
      .eq('is_active', true)
      .order('product_name_en');

    if (productsError) {
      return json({ error: 'Failed to fetch products' }, { status: 500 });
    }

    return json({ 
      products: products || [],
      offers: filteredOffers,
      userId: user.id  // ✅ Return authenticated user ID
    });
  } catch (error) {
    console.error('❌ API Error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};
```

---

## STEP 4: Fix Featured Offers API Route

### File: `frontend/src/routes/api/customer/featured-offers/+server.ts`

**AFTER:**
```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';
import { validateRequest } from '$lib/server/auth';

export const GET: RequestHandler = async ({ request, url }) => {
  try {
    // ✅ Validate authentication
    const { user, error: authError } = await validateRequest(request);
    
    if (authError || !user) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const branchId = url.searchParams.get('branchId');
    
    if (!branchId) {
      return json({ error: 'Missing branchId' }, { status: 400 });
    }

    const now = new Date().toISOString();

    // ✅ Query as authenticated user
    const { data: featuredOffers, error } = await supabase
      .from('featured_offers')
      .select(`
        *,
        offers (
          id,
          type,
          is_active
        )
      `)
      .eq('is_active', true)
      .eq('offers.is_active', true)
      .lte('offers.start_date', now)
      .gte('offers.end_date', now)
      .limit(10);

    if (error) {
      console.error('❌ Error fetching featured offers:', error);
      return json({ error: 'Failed to fetch featured offers' }, { status: 500 });
    }

    return json({ 
      offers: featuredOffers || [],
      userId: user.id 
    });
  } catch (error) {
    console.error('❌ API Error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};
```

---

## STEP 5: Update Frontend Login to Send Tokens

### File: `frontend/src/lib/utils/persistentAuth.ts`

**UPDATE LOGIN FUNCTION:**
```typescript
// After successful login, get session token
async login(username: string, password: string) {
  // ... existing code ...

  // After supabase.auth.signInWithPassword succeeds:
  const { data: authData } = await supabase.auth.signInWithPassword({...});

  // ✅ Get the session token
  const sessionToken = authData.session?.access_token;

  if (!sessionToken) {
    return { success: false, error: 'Failed to get session token' };
  }

  // Store token for use in API requests
  const userSession: UserSession = {
    // ... existing fields ...
    token: sessionToken,  // ✅ Store JWT token
  };

  // Use this token in API requests:
  const response = await fetch('/api/customer/products-with-offers?branchId=123', {
    headers: {
      'Authorization': `Bearer ${sessionToken}`  // ✅ Send token
    }
  });
}
```

---

## STEP 6: Hash Quick Access Codes

### Database Migration: `migrations/hash-quick-access-codes.sql`

```sql
-- ============================================================
-- HASH QUICK ACCESS CODES
-- ============================================================

-- 1. Create function to hash code with salt
CREATE OR REPLACE FUNCTION hash_quick_access_code(
  p_code TEXT,
  p_salt TEXT
) RETURNS TEXT AS $$
BEGIN
  RETURN encode(
    digest(p_code || p_salt, 'sha256'),
    'hex'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Add hashed code column if not exists
ALTER TABLE users
ADD COLUMN IF NOT EXISTS quick_access_code_hash TEXT;

-- 3. Migrate existing codes
UPDATE users
SET quick_access_code_hash = hash_quick_access_code(
  quick_access_code,
  quick_access_salt
)
WHERE quick_access_code IS NOT NULL
  AND quick_access_code_hash IS NULL;

-- 4. Update RLS policy to check hash instead
CREATE OR REPLACE FUNCTION authenticate_with_quick_access(
  p_access_code TEXT
) RETURNS TABLE (
  success BOOLEAN,
  user_id UUID,
  error_message TEXT
) AS $$
DECLARE
  v_user_id UUID;
  v_salt TEXT;
  v_hashed_input TEXT;
  v_hashed_code TEXT;
BEGIN
  -- Get user with matching code
  SELECT u.id, u.quick_access_salt, u.quick_access_code_hash
  INTO v_user_id, v_salt, v_hashed_code
  FROM users u
  WHERE u.status = 'active'
  LIMIT 1 FOR UPDATE; -- Prevent timing attacks

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, NULL::UUID, 'User not found'::TEXT;
    RETURN;
  END IF;

  -- Hash the input code
  v_hashed_input := hash_quick_access_code(p_access_code, v_salt);

  -- Compare hashes
  IF v_hashed_input = v_hashed_code THEN
    RETURN QUERY SELECT TRUE, v_user_id, NULL::TEXT;
  ELSE
    RETURN QUERY SELECT FALSE, NULL::UUID, 'Invalid access code'::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Drop old plaintext column after migration confirmed
-- ALTER TABLE users DROP COLUMN quick_access_code;
```

**Update Login Code:**
```typescript
// In persistentAuth.ts
async loginWithQuickAccess(quickAccessCode: string) {
  // ✅ Use RPC function instead of direct comparison
  const { data: authResult, error } = await supabase.rpc(
    'authenticate_with_quick_access',
    { p_access_code: quickAccessCode }
  );

  if (error || !authResult?.success) {
    return { success: false, error: 'Invalid access code' };
  }

  const userId = authResult.user_id;
  
  // Continue with normal login flow
  // ...
}
```

---

## STEP 7: Move Push Notification Operations to Backend

### New API Route: `frontend/src/routes/api/notifications/subscription/+server.ts`

```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';
import { validateRequest } from '$lib/server/auth';

// POST: Subscribe to push notifications
export const POST: RequestHandler = async ({ request }) => {
  try {
    const { user, error: authError } = await validateRequest(request);
    
    if (authError || !user) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { subscription } = await request.json();

    if (!subscription) {
      return json({ error: 'Invalid subscription' }, { status: 400 });
    }

    // ✅ Save subscription as authenticated user
    const { error } = await supabase
      .from('push_subscriptions')
      .upsert({
        user_id: user.id,
        subscription: subscription,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,subscription'
      });

    if (error) {
      console.error('❌ Subscription error:', error);
      return json({ error: 'Failed to save subscription' }, { status: 500 });
    }

    return json({ success: true });
  } catch (error) {
    console.error('❌ API Error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};

// DELETE: Unsubscribe from push notifications
export const DELETE: RequestHandler = async ({ request }) => {
  try {
    const { user, error: authError } = await validateRequest(request);
    
    if (authError || !user) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { subscription } = await request.json();

    // ✅ Delete as authenticated user
    const { error } = await supabase
      .from('push_subscriptions')
      .delete()
      .eq('user_id', user.id)
      .eq('subscription', subscription);

    if (error) {
      console.error('❌ Unsubscribe error:', error);
      return json({ error: 'Failed to unsubscribe' }, { status: 500 });
    }

    return json({ success: true });
  } catch (error) {
    console.error('❌ API Error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};
```

**Update Frontend to use API:**
```typescript
// Before:
const { error } = await supabaseAdmin
  .from('push_subscriptions')
  .upsert({ ... });

// After:
const response = await fetch('/api/notifications/subscription', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${userToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ subscription })
});
```

---

## STEP 8: Add Rate Limiting Middleware

### New File: `frontend/src/lib/server/rateLimit.ts`

```typescript
import { LRUCache } from 'lru-cache';

// In-memory cache (use Redis for production)
const requestCounts = new LRUCache<string, number>({
  max: 10000,
  ttl: 1000 * 60 // 1 minute
});

export function checkRateLimit(
  userId: string,
  limit: number = 60
): { allowed: boolean; remaining: number } {
  const key = `rate-limit:${userId}`;
  const current = requestCounts.get(key) || 0;
  const newCount = current + 1;

  requestCounts.set(key, newCount);

  return {
    allowed: newCount <= limit,
    remaining: Math.max(0, limit - newCount)
  };
}
```

**Use in API route:**
```typescript
import { checkRateLimit } from '$lib/server/rateLimit';

export const GET: RequestHandler = async ({ request }) => {
  const { user, error: authError } = await validateRequest(request);
  
  if (authError || !user) {
    return json({ error: 'Unauthorized' }, { status: 401 });
  }

  // ✅ Check rate limit
  const { allowed, remaining } = checkRateLimit(user.id, 100);

  if (!allowed) {
    return json(
      { error: 'Rate limit exceeded' },
      { 
        status: 429,
        headers: { 'Retry-After': '60' }
      }
    );
  }

  // Continue with normal request...
};
```

---

## STEP 9: Add Security Headers

### File: `frontend/src/hooks.server.ts`

```typescript
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);

  // ✅ Add security headers
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set(
    'Permissions-Policy',
    'geolocation=(), microphone=(), camera=()'
  );
  
  // CSP Header (adjust as needed)
  response.headers.set(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
  );

  return response;
};
```

---

## VERIFICATION CHECKLIST

After implementing changes:

- [ ] `supabaseAdmin` export removed from `supabase.ts`
- [ ] All API routes validate JWT tokens via `validateRequest()`
- [ ] Quick access codes are hashed in database
- [ ] Frontend sends JWT token in `Authorization` header
- [ ] Quick access code comparison uses hash function
- [ ] Rate limiting is implemented on all API routes
- [ ] Security headers are added in hooks
- [ ] RLS policies are still enabled on all sensitive tables
- [ ] Tested: Anonymous requests are rejected (401)
- [ ] Tested: Expired tokens are rejected (401)
- [ ] Tested: Users can only access their own data

---

## TESTING THE FIX

### Test 1: Verify Service Role is Gone
```bash
# This should fail (service role key should not exist in frontend)
curl -H "Authorization: Bearer SERVICE_ROLE_KEY" \
  https://yourapp.com/api/customer/products

# Expected: 401 Unauthorized or error
```

### Test 2: Verify API Authentication Works
```bash
# Without token:
curl https://yourapp.com/api/customer/products
# Expected: 401 Unauthorized

# With valid token:
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://yourapp.com/api/customer/products
# Expected: 200 OK with user's data
```

### Test 3: Verify Quick Access Code Hashing
```sql
-- Check that codes are hashed in database
SELECT id, username, quick_access_code_hash 
FROM users 
WHERE quick_access_code_hash IS NOT NULL
LIMIT 1;

-- Should show hash (64-char hex), not plaintext 6-digit code
```

---

## ROLLBACK PLAN

If issues arise:

1. **Revert API routes** - Keep service role version temporarily
2. **Disable auth check** - Comment out `validateRequest()` calls
3. **Keep hashing** - Don't revert database changes
4. **Debug logs** - Enable console logging to find issues

---

## NEXT STEPS

1. Implement in order (Steps 1-9)
2. Test each step thoroughly
3. Deploy to staging first
4. Monitor logs for auth errors
5. Full production rollout

Good luck! Your authentication system will be much more secure after these changes.
