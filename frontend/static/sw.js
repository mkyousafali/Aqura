// Service Worker for background push notifications
// This file should be placed in the static folder to be served at root

// Cache name
const CACHE_NAME = 'aqura-notifications-v1';

// Install event
self.addEventListener('install', (event) => {
	console.log('Service Worker installing...');
	
	// Force activation immediately
	event.waitUntil(
		self.skipWaiting()
	);
});

// Activate event
self.addEventListener('activate', (event) => {
	console.log('Service Worker activating...');
	
	event.waitUntil(
		// Claim all clients immediately
		self.clients.claim()
	);
});

// Push event - handle incoming push notifications
self.addEventListener('push', (event) => {
	console.log('Push event received:', event);

	let notificationData = {
		title: 'New Notification',
		body: 'You have a new notification',
		icon: '/favicon.png',
		badge: '/badge-icon.png',
		data: {}
	};

	// Parse push data if available
	if (event.data) {
		try {
			const pushData = event.data.json();
			notificationData = {
				title: pushData.title || notificationData.title,
				body: pushData.body || notificationData.body,
				icon: pushData.icon || notificationData.icon,
				badge: pushData.badge || notificationData.badge,
				data: pushData.data || {}
			};
		} catch (error) {
			console.error('Error parsing push data:', error);
		}
	}

	// Show the notification
	const notificationPromise = self.registration.showNotification(
		notificationData.title,
		{
			body: notificationData.body,
			icon: notificationData.icon,
			badge: notificationData.badge,
			data: notificationData.data,
			tag: notificationData.data.notification_id || 'aqura-notification',
			requireInteraction: true,
			actions: [
				{
					action: 'view',
					title: 'View',
					icon: '/icons/view.png'
				},
				{
					action: 'dismiss',
					title: 'Dismiss',
					icon: '/icons/dismiss.png'
				}
			],
			silent: false,
			vibrate: [200, 100, 200],
			timestamp: Date.now()
		}
	);

	event.waitUntil(notificationPromise);
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
	console.log('Notification clicked:', event);

	const notification = event.notification;
	const action = event.action;
	const data = notification.data || {};

	// Close the notification
	notification.close();

	// Handle different actions
	if (action === 'dismiss') {
		// Just close, no action needed
		return;
	}

	// Default action or 'view' action
	let messageData = {
		type: 'open_notification_window',
		notificationId: data.notification_id || null
	};

	// Open or focus the app
	event.waitUntil(
		self.clients.matchAll({
			type: 'window',
			includeUncontrolled: true
		}).then((clientList) => {
			// Check if app is already open
			for (const client of clientList) {
				if (client.url.includes(self.location.origin)) {
					// Focus existing window and send message to open notification window
					client.focus();
					client.postMessage(messageData);
					return;
				}
			}
			
			// Open new window and send message after load
			return self.clients.openWindow('/').then((client) => {
				if (client) {
					// Wait a moment for the app to load, then send message
					setTimeout(() => {
						client.postMessage(messageData);
					}, 2000);
				}
			});
		})
	);
});

// Message event - handle messages from the main app
self.addEventListener('message', (event) => {
	console.log('Service Worker received message:', event.data);

	const { type, data } = event.data;

	switch (type) {
		case 'SKIP_WAITING':
			self.skipWaiting();
			break;
		
		case 'CACHE_NOTIFICATION':
			// Cache notification data for offline access
			if (data && data.notification) {
				// Store in IndexedDB or cache
				cacheNotification(data.notification);
			}
			break;
		
		case 'MARK_AS_READ':
			// Handle marking notification as read
			if (data && data.notificationId) {
				markNotificationAsRead(data.notificationId);
			}
			break;
		
		default:
			console.log('Unknown message type:', type);
	}
});

// Background sync for offline notification actions
self.addEventListener('sync', (event) => {
	console.log('Background sync event:', event.tag);

	if (event.tag === 'notification-actions') {
		event.waitUntil(
			syncNotificationActions()
		);
	}
});

// Helper functions

/**
 * Cache notification for offline access
 */
async function cacheNotification(notification) {
	try {
		// Open IndexedDB
		const db = await openNotificationDB();
		const transaction = db.transaction(['notifications'], 'readwrite');
		const store = transaction.objectStore('notifications');
		
		// Store notification
		await store.put({
			id: notification.id,
			title: notification.title,
			body: notification.body,
			data: notification.data,
			timestamp: Date.now(),
			read: false
		});
		
		console.log('Notification cached successfully');
	} catch (error) {
		console.error('Error caching notification:', error);
	}
}

/**
 * Mark notification as read (queue for sync)
 */
async function markNotificationAsRead(notificationId) {
	try {
		// Queue action for background sync
		const db = await openNotificationDB();
		const transaction = db.transaction(['actions'], 'readwrite');
		const store = transaction.objectStore('actions');
		
		await store.put({
			id: Date.now(),
			type: 'mark_read',
			notificationId,
			timestamp: Date.now(),
			synced: false
		});
		
		// Register background sync
		await self.registration.sync.register('notification-actions');
		
		console.log('Notification marked as read (queued for sync)');
	} catch (error) {
		console.error('Error marking notification as read:', error);
	}
}

/**
 * Sync notification actions when online
 */
async function syncNotificationActions() {
	try {
		const db = await openNotificationDB();
		const transaction = db.transaction(['actions'], 'readonly');
		const store = transaction.objectStore('actions');
		
		// Get all unsynced actions
		const unsyncedActions = await store.getAll();
		const pendingActions = unsyncedActions.filter(action => !action.synced);
		
		for (const action of pendingActions) {
			try {
				if (action.type === 'mark_read') {
					// Send to server
					await fetch('/api/notifications/mark-read', {
						method: 'POST',
						headers: {
							'Content-Type': 'application/json'
						},
						body: JSON.stringify({
							notificationId: action.notificationId
						})
					});
					
					// Mark as synced
					const updateTransaction = db.transaction(['actions'], 'readwrite');
					const updateStore = updateTransaction.objectStore('actions');
					action.synced = true;
					await updateStore.put(action);
				}
			} catch (error) {
				console.error('Error syncing action:', action, error);
			}
		}
		
		console.log('Notification actions synced successfully');
	} catch (error) {
		console.error('Error syncing notification actions:', error);
	}
}

/**
 * Open IndexedDB for notifications
 */
function openNotificationDB() {
	return new Promise((resolve, reject) => {
		const request = indexedDB.open('AquraNotifications', 1);
		
		request.onerror = () => reject(request.error);
		request.onsuccess = () => resolve(request.result);
		
		request.onupgradeneeded = (event) => {
			const db = event.target.result;
			
			// Create notifications store
			if (!db.objectStoreNames.contains('notifications')) {
				const notificationStore = db.createObjectStore('notifications', { keyPath: 'id' });
				notificationStore.createIndex('timestamp', 'timestamp', { unique: false });
				notificationStore.createIndex('read', 'read', { unique: false });
			}
			
			// Create actions store
			if (!db.objectStoreNames.contains('actions')) {
				const actionStore = db.createObjectStore('actions', { keyPath: 'id' });
				actionStore.createIndex('synced', 'synced', { unique: false });
				actionStore.createIndex('timestamp', 'timestamp', { unique: false });
			}
		};
	});
}