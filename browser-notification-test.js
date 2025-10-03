// Simple browser-based notification test
// Run this in your browser console (F12 -> Console tab)

console.log('🧪 Testing browser notifications...');

// Check if notifications are supported
if (!('Notification' in window)) {
  console.log('❌ This browser does not support notifications');
} else {
  console.log('✅ Browser supports notifications');
  console.log('Current permission:', Notification.permission);
  
  // Request permission if needed
  if (Notification.permission === 'granted') {
    console.log('✅ Permission already granted');
    
    // Create a test notification
    const notification = new Notification('🎉 Test Notification', {
      body: 'Hello! This is a test browser notification.',
      icon: '/favicon.png',
      badge: '/badge-icon.png',
      tag: 'test-notification',
      requireInteraction: false
    });
    
    notification.onclick = function() {
      console.log('🔔 Notification clicked!');
      window.focus();
      notification.close();
    };
    
    notification.onshow = function() {
      console.log('👀 Notification displayed');
    };
    
    notification.onclose = function() {
      console.log('❌ Notification closed');
    };
    
    console.log('📱 Test notification created! You should see it now.');
    console.log('💡 If you don\'t see it, try:');
    console.log('   1. Minimize or switch away from this browser tab');
    console.log('   2. Check your system notification settings');
    console.log('   3. Check browser notification permissions');
    
  } else if (Notification.permission === 'denied') {
    console.log('❌ Notifications are blocked. Please enable them in browser settings.');
  } else {
    console.log('❓ Requesting notification permission...');
    Notification.requestPermission().then(permission => {
      console.log('Permission result:', permission);
      if (permission === 'granted') {
        console.log('✅ Permission granted! You can now run this script again.');
      } else {
        console.log('❌ Permission denied. Please enable notifications manually.');
      }
    });
  }
}