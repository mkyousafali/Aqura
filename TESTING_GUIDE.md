# Testing Guide: CORS & 502 Fix Verification

## What Was Fixed

The application was experiencing two interconnected errors:
1. **CORS: No 'Access-Control-Allow-Origin' header** - Blocked fetch requests
2. **502 Bad Gateway** - Supabase returning server errors
3. **Root Cause**: Query URLs exceeded server limits due to large `.in()` filters

## Files Changed
- `frontend/src/lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte`
  - Updated 6 functions with query chunking

## How to Test

### 1. Basic Functionality Test
Open the application and navigate to the receiving module:
- The application should load without CORS errors
- Branch manager selection should show users and positions

### 2. Monitor Network Requests
Open Developer Tools → Network tab:
- Filter for "hr_position_assignments" API calls
- You should see **multiple smaller queries** (not one huge one)
- Each query URL should be reasonable length (~1-2KB, not 5KB+)
- Response status should be **200**, not 502

### 3. Test Each Selection Function
Try selecting each type of user in StartReceiving module:

✅ **Purchasing Managers** (cross-branch selection)
- Select a branch
- Click "Select Purchasing Manager"
- Should load list without errors

✅ **Branch Managers** (branch-specific)
- Should work as before

✅ **Shelf Stockers** (branch-specific)
- Click "Select Shelf Stocker"
- Should load list without errors

✅ **Accountants** (branch-specific)
- Click "Select Accountant"
- Should load list without errors

✅ **Inventory Managers** (branch-specific)
- Click "Select Inventory Manager"
- Should load list without errors

✅ **Night Supervisors** (branch-specific)
- Click "Select Night Supervisor"
- Should load list without errors

✅ **Warehouse Handlers** (branch-specific)
- Click "Select Warehouse Handler"
- Should load list without errors

### 4. Check Console Logs
Open Developer Tools → Console:

**Expected logs:**
```
✅ Loaded users from all branches for purchasing manager selection: {totalUsers: X, purchasingManagers: Y, showingAllUsers: Z}
✅ Found [role] managers: [{...}]
✅ Loaded branch users for [role] selection: {totalUsers: X, [role]: Y, showingAllUsers: Z}
```

**Should NOT see:**
```
❌ Error loading positions: {...error details...}
❌ Failed to fetch
❌ Access to fetch at '...' has been blocked by CORS policy
```

### 5. Performance Test
With 100+ employees in a branch:
- Should load smoothly without hanging
- Queries should complete within 2-3 seconds
- Multiple queries visible in Network tab (processing in parallel)

### 6. Error Handling Test
If Supabase is temporarily unavailable:
- App should gracefully handle the error
- Error message in console but app shouldn't crash
- Can still browse other parts of the app

## Expected Network Pattern

**Before Fix (SINGLE HUGE QUERY):**
```
GET /rest/v1/hr_position_assignments?...employee_id=in.(...100+ UUIDs...)
Response: 502 Bad Gateway
```

**After Fix (CHUNKED QUERIES):**
```
GET /rest/v1/hr_position_assignments?...employee_id=in.(...UUIDs 1-100...)  → 200 OK
GET /rest/v1/hr_position_assignments?...employee_id=in.(...UUIDs 101-200...) → 200 OK
GET /rest/v1/hr_position_assignments?...employee_id=in.(...UUIDs 201-300...) → 200 OK
```

## Performance Expectations

- **Small branch (10-20 employees)**: 1 query, <500ms
- **Medium branch (50 employees)**: 1 query, <800ms
- **Large branch (100+ employees)**: 2+ queries in parallel, <1.5s total
- **All users (100+ employees)**: Multiple queries, <2s total

## If Issues Still Occur

### Still seeing 502 errors?
1. Hard refresh browser (Ctrl+Shift+R)
2. Clear browser cache
3. Check Supabase service status
4. Verify .env variables are correct

### Still seeing CORS errors?
1. Check browser console for the actual error
2. The URL in the error message should now be reasonable length
3. If URL is still huge, recompile with `npm run build`

### Users not loading?
1. Verify users exist in database
2. Check that users have hr_employees linked
3. Check that hr_position_assignments records exist
4. Verify RLS policies on these tables allow access

## Rollback Plan

If critical issues arise:
```bash
# Revert to previous version
git checkout HEAD -- frontend/src/lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte
npm run dev
```

## Questions to Answer After Testing

- [ ] Can you load Purchasing Managers without errors?
- [ ] Do the Network requests show multiple queries instead of one?
- [ ] Are all queries returning 200 OK status?
- [ ] Do users load within 2-3 seconds?
- [ ] Does the error console show no CORS or 502 errors?
- [ ] Can you select users from all role dropdowns?
