// Example: How your backend should handle VAPID keys
const webpush = require('web-push');

// NEVER hardcode keys - always use environment variables
const vapidKeys = {
  publicKey: process.env.VITE_VAPID_PUBLIC_KEY || 'BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8',
  privateKey: process.env.VAPID_PRIVATE_KEY || null
};

// Validate that private key exists in production
if (!vapidKeys.privateKey) {
  console.error('VAPID_PRIVATE_KEY environment variable is required for push notifications');
  process.exit(1);
}

// Configure web-push
webpush.setVapidDetails(
  'mailto:your-email@domain.com', // Your contact email
  vapidKeys.publicKey,
  vapidKeys.privateKey
);

// Function to send push notification
async function sendPushNotification(subscription, payload) {
  try {
    await webpush.sendNotification(subscription, JSON.stringify(payload));
    console.log('Push notification sent successfully');
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
}

module.exports = {
  sendPushNotification
};