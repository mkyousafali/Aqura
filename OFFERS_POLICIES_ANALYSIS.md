# Offers Table RLS Policy Analysis

## Current State: 9 Policies Found

### Policy Breakdown

#### 1. "allow_all_operations" (ALL) ⚠️ PROBLEMATIC
- **Operation:** ALL (applies to SELECT, INSERT, UPDATE, DELETE)
- **USING:** `true`
- **WITH CHECK:** `true`
- **Issue:** Allows everything unconditionally - overrides more specific policies
- **Action:** DELETE - Too permissive

#### 2. "anon_full_access" (ALL) ⚠️ PROBLEMATIC
- **Operation:** ALL
- **USING:** `((jwt() ->> 'role'::text) = 'anon'::text)`
- **Issue:** Grants full access to anonymous users - security risk
- **Action:** DELETE - Too permissive

#### 3. "authenticated_full_access" (ALL) ⚠️ PROBLEMATIC
- **Operation:** ALL
- **USING:** `(uid() IS NOT NULL)`
- **Issue:** Grants full access to any authenticated user - overrides specific policies
- **Action:** DELETE - Too permissive

#### 4. "allow_delete" (DELETE) ✓ KEEP
- **Operation:** DELETE
- **USING:** `true`
- **Issue:** None - clean delete policy
- **Action:** KEEP

#### 5. "Allow anon insert offers" (INSERT) ⚠️ DUPLICATE
- **Operation:** INSERT
- **WITH CHECK:** `true`
- **Issue:** Duplicate of allow_insert, less clear name
- **Action:** DELETE - redundant

#### 6. "allow_insert" (INSERT) ✓ KEEP
- **Operation:** INSERT
- **WITH CHECK:** `true`
- **Issue:** None - clean insert policy
- **Action:** KEEP

#### 7. "allow_select" (SELECT) ✓ KEEP
- **Operation:** SELECT
- **USING:** `true`
- **Issue:** None - simple select policy
- **Action:** KEEP (though customer_view_active_offers might be needed for customers)

#### 8. "customer_view_active_offers" (SELECT) ⚠️ OPTIONAL
- **Operation:** SELECT
- **USING:** `((is_active = true) AND ((now() >= start_date) AND (now() <= end_date)))`
- **Issue:** Restricts customers to only active offers - good for customer view, but conflicts with allow_select
- **Action:** DELETE for now (can re-add if needed for customer-specific filtering)

#### 9. "allow_update" (UPDATE) ✓ KEEP
- **Operation:** UPDATE
- **USING:** `true`
- **WITH CHECK:** `true`
- **Issue:** None - clean update policy
- **Action:** KEEP

## Summary

**Problems:**
- 3 "ALL" operation policies that override everything (security risk)
- 2 duplicate INSERT policies
- 2 SELECT policies that conflict

**Solution:**
Keep only 4 clean policies:
1. `allow_select` - SELECT with `USING (true)`
2. `allow_insert` - INSERT with `WITH CHECK (true)`
3. `allow_update` - UPDATE with `USING (true)` and `WITH CHECK (true)`
4. `allow_delete` - DELETE with `USING (true)`

This matches the pattern used on the `products` table.

## Next Steps

1. Run: `cleanup-offers-policies.sql`
2. Verify: Run `check-offers-rls.sql`
3. Test: Try loading offers in OfferManagement component
