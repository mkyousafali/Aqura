# 🔒 Push Notifications for Locked Phones - Setup Guide

## ✅ Current Status

Your Aqura application has been enhanced to support push notifications even when the phone is locked! Here's what was implemented:

### 🚀 Enhanced Features Added:

1. **Service Worker Background Notifications**: Updated to handle push events when app is completely closed
2. **Locked Phone Notification Options**: Enhanced notification settings for maximum visibility
3. **Real VAPID Subscription Support**: Enables actual push notifications instead of mock ones
4. **Debug Tools**: Added specific testing functions for locked phone scenarios

## 🔧 Setup Instructions

### Step 1: Generate VAPID Keys

First, you need to generate VAPID keys for real push notifications:

```powershell
# Install web-push globally
npm install -g web-push

# Generate VAPID keys
web-push generate-vapid-keys
```

This will output something like:
```
Public Key: BGxYKcljWu93dfKYccNK-_7pXo8Nwwxk_X8ccsUU_ZuIjP_mD1Uy...
Private Key: bXYz1234567890abcdef...
```

### Step 2: Configure Environment Variables

Create a `.env` file in your frontend directory with:

```bash
# Enable push notifications
VITE_PUSH_NOTIFICATIONS_ENABLED=true

# Add your VAPID keys (replace with actual keys from step 1)
VITE_VAPID_PUBLIC_KEY=BGxYKcljWu93dfKYccNK-_7pXo8Nwwxk_X8ccsUU_ZuIjP_mD1Uy...
VAPID_PRIVATE_KEY=bXYz1234567890abcdef...

# Supabase configuration (if not already set)
VITE_SUPABASE_URL=https://vmypotfsyrvuublyddyt.supabase.co
VITE_SUPABASE_SERVICE_KEY=your_service_key_here
```

### Step 3: Test Locked Phone Notifications

Open your app in the browser and use the console commands:

```javascript
// Test locked phone notifications specifically
aquraPushDebug.testLockedPhoneNotification()

// Test regular notifications
aquraPushDebug.testRegularNotification()

// Check PWA status
aquraPushDebug.checkPWAStatus()
```

### Step 4: Test on Actual Device

1. **Grant Notification Permission**: Make sure notifications are allowed in browser settings
2. **Send Test Notification**: Use the debug command above
3. **Lock Your Phone**: Lock your device screen
4. **Check for Notification**: The notification should appear on the lock screen

## 🔒 Key Features for Locked Phone Notifications

### Enhanced Notification Options:
- `requireInteraction: true` - Forces notification to stay until user interacts
- `silent: false` - Ensures sound plays even when locked
- `persistent: true` - Keeps notification visible
- Enhanced vibration patterns for locked devices
- Multiple action buttons for better interaction

### Service Worker Enhancements:
- Background push event handling when app is completely closed
- Authentication checks to only show notifications to logged-in users
- Enhanced error handling and fallback notifications
- Proper notification click handling to open the app

## 📱 Testing Commands

Run these in your browser console:

```javascript
// Test locked phone notification with enhanced settings
aquraPushDebug.testLockedPhoneNotification()

// Instructions will appear in console:
// "Lock your device and check if the notification appears"
```

## 🚨 Common Issues & Solutions

### Issue 1: Notifications Don't Appear When Locked
**Solution**: Ensure you have real VAPID keys configured (not mock keys)

### Issue 2: Permission Denied
**Solution**: Check browser notification settings and grant permission

### Issue 3: Service Worker Not Active
**Solution**: Clear browser cache and restart the development server

### Issue 4: No Sound on Locked Phone
**Solution**: Check device notification settings and ensure sounds are enabled

## 🔧 PowerShell Commands for Setup

```powershell
# Navigate to your project
cd C:\AQURA\Aqura

# Install web-push for VAPID key generation
npm install -g web-push

# Generate VAPID keys
web-push generate-vapid-keys

# Create .env file in frontend directory
cd frontend
New-Item -ItemType File -Name ".env" -Force

# Add the keys to .env file (replace with your actual keys)
Add-Content .env "VITE_PUSH_NOTIFICATIONS_ENABLED=true"
Add-Content .env "VITE_VAPID_PUBLIC_KEY=YOUR_PUBLIC_KEY_HERE"
Add-Content .env "VAPID_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE"

# Restart development server
pnpm dev
```

## ✅ Verification Checklist

- [ ] VAPID keys generated and added to .env
- [ ] Push notifications enabled in browser
- [ ] Service worker active and registered
- [ ] Test notification works with app open
- [ ] **Test notification appears when phone is locked** 🔒
- [ ] Notification includes sound and vibration
- [ ] Clicking notification opens the app

## 📱 Mobile-Specific Considerations

### Android:
- Works in Chrome, Edge, Firefox
- PWA installation improves lock screen notifications
- Battery optimization settings may affect delivery

### iOS (Safari):
- Requires PWA installation for lock screen notifications
- Limited support compared to Android
- iOS 16.4+ required for proper push notifications

## 🎯 Expected Behavior

When working correctly:
1. **App Open**: Notifications appear in-app and as browser notifications
2. **App Closed**: Notifications appear via service worker
3. **Phone Locked**: Notifications appear on lock screen with sound/vibration
4. **Notification Click**: Opens app and navigates to relevant content

The enhanced implementation should now support notifications even when your phone is locked! 🔒📱