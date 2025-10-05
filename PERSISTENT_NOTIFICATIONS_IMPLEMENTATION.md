# Persistent Notifications & Multi-User System Implementation

## Overview
This implementation provides comprehensive persistent notifications that work even when the app is closed, along with multi-user session management on the same device. Users can receive notifications on both mobile and desktop devices, and can easily switch between multiple user accounts logged in on the same device.

## Features Implemented

### 1. Persistent Push Notifications
- **Background notifications** when app is closed
- **Cross-platform support** (mobile and desktop)
- **Service Worker integration** for offline functionality
- **Real-time notification delivery** via Supabase realtime
- **Notification permission management**
- **Test notification functionality**

### 2. Multi-User Session Management
- **Multiple users** can be logged in on the same device
- **Quick user switching** without re-authentication
- **Persistent login sessions** (24-hour duration)
- **Device-specific user storage**
- **Session validity checking**
- **Automatic cleanup of expired sessions**

### 3. Enhanced Authentication System
- **Persistent device registration** for push notifications
- **User activity tracking** with audit logs
- **Automatic session refresh** on user activity
- **Cross-tab session synchronization**
- **Secure logout with device cleanup**

## File Structure

### Core Services
```
frontend/src/lib/utils/
├── pushNotifications.ts       # Push notification service
├── persistentAuth.ts          # Multi-user authentication
└── notificationManagement.ts  # Enhanced notification management
```

### Components
```
frontend/src/lib/components/
├── UserSwitcher.svelte             # User switching modal
├── PushNotificationSettings.svelte # Notification settings
└── ...
```

### Database Schema
```
29-push-notifications-schema.sql   # Database tables for push notifications
```

### Service Worker
```
frontend/static/sw.js              # Background notification handling
```

## Database Tables Added

### 1. push_subscriptions
Stores device registration data for push notifications:
- `user_id` - Reference to users table
- `device_id` - Unique device identifier
- `endpoint`, `p256dh`, `auth` - Push subscription data
- `device_type` - Mobile or desktop
- `browser_name` - Browser information
- `is_active` - Active status
- `last_seen` - Last activity timestamp

### 2. notification_queue
Manages reliable notification delivery:
- `notification_id` - Reference to notifications
- `user_id` - Target user
- `device_id` - Target device
- `status` - Delivery status (pending/sent/failed/delivered)
- `payload` - Notification data
- `retry_count` - Failed delivery retries

### 3. user_device_sessions
Tracks multi-user sessions per device:
- `user_id` - Reference to users
- `device_id` - Unique device identifier
- `session_token` - Session authentication
- `device_type` - Mobile or desktop
- `is_active` - Session status
- `expires_at` - Session expiration

## API Integration

### Push Notification Service (`pushNotifications.ts`)
```typescript
// Initialize push notifications
await pushNotificationService.initialize();

// Show notification
await pushNotificationService.showNotification({
  title: "New Task Assigned",
  body: "You have a new task to complete",
  data: { notification_id: "123", url: "/tasks/123" }
});

// Register device
await pushNotificationService.registerDevice();

// Unregister on logout
await pushNotificationService.unregisterDevice();
```

### Persistent Authentication (`persistentAuth.ts`)
```typescript
// Login user
const result = await persistentAuthService.login(username, password);

// Switch user
const switchResult = await persistentAuthService.switchUser(userId);

// Get device users
const deviceUsers = await persistentAuthService.getDeviceUsers();

// Logout
await persistentAuthService.logout();
```

### Enhanced Notification Management (`notificationManagement.ts`)
```typescript
// Register for push notifications
await notificationService.registerForPushNotifications();

// Start real-time listener
await notificationService.startRealtimeNotificationListener();

// Send test notification
await notificationService.sendTestNotification();

// Check support
const isSupported = notificationService.isPushNotificationSupported();
```

## User Interface Components

### 1. UserSwitcher Component
- Modal interface for switching between users
- Shows all users logged in on current device
- Displays user avatars, names, roles, and last activity
- Option to remove users from device
- Quick logout all functionality

### 2. PushNotificationSettings Component
- Browser support detection
- Permission status display
- Device registration status
- Enable/disable notifications
- Test notification functionality
- Help and troubleshooting information

### 3. Enhanced Taskbar
- User menu with additional options:
  - Switch User (when multiple users exist)
  - Notification Settings
  - Test Notification (in development mode)
- Visual indicators for notification support

## Keyboard Shortcuts

- `Ctrl+Shift+U` (Cmd+Shift+U on Mac) - Open User Switcher
- `Ctrl+Shift+N` (Cmd+Shift+N on Mac) - Open Notification Settings
- `Ctrl+Shift+P` (Cmd+Shift+P on Mac) - Open Command Palette
- `Escape` - Close all modals

## Security Features

### Row Level Security (RLS)
- Users can only access their own push subscriptions
- Admins can view all subscriptions for management
- Notification queue is protected per user
- Device sessions are user-specific

### Session Management
- 24-hour session duration with auto-refresh
- Secure device identification
- Activity-based session validation
- Automatic cleanup of expired sessions

### Push Notification Security
- VAPID key authentication (requires setup)
- Device-specific subscription management
- Secure payload encryption
- User permission validation

## Setup Requirements

### 1. VAPID Keys
Generate VAPID keys for push notifications:
```bash
npx web-push generate-vapid-keys
```
Update `VAPID_PUBLIC_KEY` in `pushNotifications.ts`

### 2. Database Migration
Run the push notifications schema:
```sql
-- Apply 29-push-notifications-schema.sql to your database
```

### 3. Environment Variables
```env
# Add to .env if needed
VITE_VAPID_PUBLIC_KEY=your-vapid-public-key
```

### 4. Service Worker Setup
The service worker is automatically registered via `app.html`

## Browser Support

### Push Notifications
- ✅ Chrome 50+
- ✅ Firefox 44+
- ✅ Safari 16+
- ✅ Edge 79+
- ❌ Internet Explorer

### Service Workers
- ✅ Chrome 40+
- ✅ Firefox 44+
- ✅ Safari 11.1+
- ✅ Edge 17+

## Usage Examples

### Basic Setup
```typescript
// In your main app component
import { persistentAuthService } from '$lib/utils/persistentAuth';
import { notificationService } from '$lib/utils/notificationManagement';

// Initialize on app start
await persistentAuthService.initializeAuth();
await notificationService.registerForPushNotifications();
```

### User Switching
```typescript
// Get available users on device
const users = await persistentAuthService.getDeviceUsers();

// Switch to specific user
const result = await persistentAuthService.switchUser(userId);
if (result.success) {
  console.log('Switched to user:', result.user);
}
```

### Sending Notifications
```typescript
// Create notification (will auto-queue for push delivery)
const notification = await notificationService.createNotification({
  title: "System Update",
  message: "New features are available",
  type: "info",
  priority: "medium",
  target_type: "all_users"
});
```

## Troubleshooting

### Push Notifications Not Working
1. Check browser support
2. Verify notification permission granted
3. Ensure VAPID keys are configured
4. Check service worker registration
5. Verify network connectivity

### User Switching Issues
1. Check localStorage availability
2. Verify session validity
3. Ensure proper user data in database
4. Check for session conflicts

### Service Worker Problems
1. Ensure `sw.js` is in static folder
2. Check browser developer tools for errors
3. Verify service worker scope
4. Clear browser cache if needed

## Performance Considerations

### Memory Usage
- Session data stored in localStorage (limited to ~5MB)
- Automatic cleanup of expired sessions
- Efficient notification queue management

### Network Usage
- Real-time subscriptions only when app is active
- Batched notification delivery
- Compressed push payloads

### Battery Usage
- Background sync only when necessary
- Efficient service worker implementation
- Minimal CPU usage for session monitoring

## Future Enhancements

### Planned Features
- [ ] Rich notification support (images, actions)
- [ ] Notification scheduling and delays
- [ ] Cross-device notification sync
- [ ] Advanced notification filtering
- [ ] Notification analytics and tracking
- [ ] Custom notification sounds
- [ ] Notification categories and priorities
- [ ] Offline notification caching
- [ ] Push notification A/B testing
- [ ] Integration with external push services

### Scalability Improvements
- [ ] Redis for session management
- [ ] Message queue for notification delivery
- [ ] CDN for service worker distribution
- [ ] Database indexing optimization
- [ ] Horizontal scaling support

## Conclusion

This implementation provides a robust foundation for persistent notifications and multi-user session management. The system is designed to be secure, scalable, and user-friendly while maintaining compatibility with existing code. Users can now receive notifications even when the app is closed and easily switch between multiple accounts on the same device.