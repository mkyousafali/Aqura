# Fix: Push Subscription Creating New Entry on Every Refresh

## Problem
The push notification subscription was creating a **new database entry** every time the user refreshed the page, instead of reusing the existing subscription.

## Root Cause
In `frontend/src/lib/utils/pushNotifications.ts`, the `registerDevice()` method was:

1. **Always generating a new device ID** using `Date.now()` and `Math.random()`
2. Looking for an existing subscription with this NEW device ID (which never existed)
3. Creating a new subscription entry every time

### Before (Line 333):
```typescript
const deviceId = this.generateDeviceId(); // Always creates NEW ID
```

## Solution
Modified the `registerDevice()` method to:

1. **Check localStorage first** for an existing device ID
2. Only generate a new device ID if none exists
3. Reuse the existing device ID on subsequent page loads

### After (Lines 332-339):
```typescript
// Check for existing device ID in localStorage first
// Only generate new one if none exists
let deviceId = localStorage.getItem('aqura-device-id');
if (!deviceId) {
    deviceId = this.generateDeviceId();
    console.log('🆕 Generated new device ID:', deviceId);
} else {
    console.log('♻️ Reusing existing device ID:', deviceId);
}
```

## How It Works Now

### First Visit/Login:
1. No device ID exists in localStorage
2. Generate new device ID
3. Create new subscription in database
4. Store device ID in localStorage

### Subsequent Page Refreshes:
1. Load existing device ID from localStorage
2. Look up existing subscription using that device ID
3. Update the existing subscription (not create new)
4. Reuse the same subscription

## Benefits

✅ **No duplicate subscriptions** - One subscription per device per user
✅ **Cleaner database** - No unnecessary subscription entries
✅ **Better performance** - Less database writes
✅ **Consistent behavior** - Device maintains same identity across sessions

## Testing

To verify the fix:

1. **Clear existing subscriptions**:
   ```sql
   -- Run in Supabase SQL Editor to see current subscriptions
   SELECT id, user_id, device_id, created_at 
   FROM push_subscriptions 
   WHERE user_id = 'YOUR_USER_ID' 
   ORDER BY created_at DESC;
   ```

2. **Test the flow**:
   - Login to the app
   - Note the device ID in console: `🆕 Generated new device ID: ...`
   - Refresh the page
   - Should see: `♻️ Reusing existing device ID: ...`
   - Check database - should have ONLY ONE subscription for this device

3. **Verify localStorage**:
   ```javascript
   // In browser console
   localStorage.getItem('aqura-device-id')
   // Should return the same ID across page refreshes
   ```

## Related Files

- **Fixed**: `frontend/src/lib/utils/pushNotifications.ts` (Line 318-339)
- **Helper Method**: `generateDeviceId()` (Line 656) - Only called when no existing ID
- **Storage Key**: `aqura-device-id` in localStorage

## Notes

- The device ID is stored in localStorage, so it persists across:
  - ✅ Page refreshes
  - ✅ Browser restarts
  - ✅ App restarts
  
- The device ID is cleared when:
  - ❌ User logs out (calls `unregisterDevice()`)
  - ❌ User clears browser data
  - ❌ User uses incognito/private mode (new session)

## Date
January 30, 2025
