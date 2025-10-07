// Enhanced service worker for Aqura PWA
// Provides offline functionality, background sync, and data caching

const CACHE_NAME = 'aqura-v1';
const DATA_CACHE_NAME = 'aqura-data-v1';

// Critical resources to cache for offline functionality
const STATIC_CACHE_URLS = [
	'/',
	'/manifest.webmanifest',
	'/offline.html', // Fallback page
	// Add other critical static assets
];

// API endpoints to cache with different strategies
const API_CACHE_PATTERNS = [
	'/api/employees',
	'/api/branches', 
	'/api/vendors',
	'/api/users'
];

// Install event - cache critical resources
self.addEventListener('install', (event) => {
	console.log('[ServiceWorker] Install');
	event.waitUntil(
		caches.open(CACHE_NAME)
			.then((cache) => {
				console.log('[ServiceWorker] Pre-caching offline page');
				return cache.addAll(STATIC_CACHE_URLS);
			})
			.then(() => self.skipWaiting())
	);
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
	console.log('[ServiceWorker] Activate');
	event.waitUntil(
		caches.keys().then((cacheNames) => {
			return Promise.all(
				cacheNames.map((cacheName) => {
					if (cacheName !== CACHE_NAME && cacheName !== DATA_CACHE_NAME) {
						console.log('[ServiceWorker] Removing old cache', cacheName);
						return caches.delete(cacheName);
					}
				})
			);
		}).then(() => self.clients.claim())
	);
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', (event) => {
	const { request } = event;
	const url = new URL(request.url);

	// Handle API requests with network-first strategy
	if (isApiRequest(url)) {
		event.respondWith(
			caches.open(DATA_CACHE_NAME)
				.then((cache) => {
					return fetch(request)
						.then((response) => {
							// If request is successful, clone and cache
							if (response.status === 200) {
								cache.put(request.url, response.clone());
							}
							return response;
						})
						.catch(() => {
							// If network fails, try cache
							return cache.match(request);
						});
				})
		);
		return;
	}

	// Handle static assets with cache-first strategy
	event.respondWith(
		caches.match(request)
			.then((cachedResponse) => {
				if (cachedResponse) {
					return cachedResponse;
				}
				return fetch(request);
			})
			.catch(() => {
				// Return offline page for navigation requests
				if (request.mode === 'navigate') {
					return caches.match('/offline.html');
				}
			})
	);
});

// Background sync for offline data operations
self.addEventListener('sync', (event) => {
	console.log('[ServiceWorker] Background sync triggered', event.tag);
	
	if (event.tag === 'background-sync-employees') {
		event.waitUntil(syncEmployeeData());
	} else if (event.tag === 'background-sync-branches') {
		event.waitUntil(syncBranchData());
	} else if (event.tag === 'background-sync-vendors') {
		event.waitUntil(syncVendorData());
	}
});

// Push notification handling
self.addEventListener('push', (event) => {
	console.log('[ServiceWorker] Push received', event);
	
	const options = {
		body: event.data ? event.data.text() : 'New update available',
		icon: '/icons/icon-192x192.png',
		badge: '/icons/badge.png',
		vibrate: [100, 50, 100],
		data: {
			dateOfArrival: Date.now(),
			primaryKey: '1'
		},
		actions: [
			{
				action: 'explore',
				title: 'View Details',
				icon: '/icons/checkmark.png'
			},
			{
				action: 'close',
				title: 'Close',
				icon: '/icons/xmark.png'
			}
		]
	};

	event.waitUntil(
		self.registration.showNotification('Aqura Management', options)
	);
});

// Notification click handling
self.addEventListener('notificationclick', (event) => {
	console.log('[ServiceWorker] Notification click received');
	
	event.notification.close();
	
	if (event.action === 'explore') {
		event.waitUntil(
			clients.openWindow('/')
		);
	}
});

// Helper functions
function isApiRequest(url) {
	return API_CACHE_PATTERNS.some(pattern => 
		url.pathname.startsWith(pattern)
	);
}

async function syncEmployeeData() {
	try {
		// Get pending employee operations from IndexedDB
		const pendingOperations = await getPendingOperations('employees');
		
		for (const operation of pendingOperations) {
			try {
				await fetch('/api/employees', {
					method: operation.method,
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify(operation.data)
				});
				
				// Remove from pending operations
				await removePendingOperation('employees', operation.id);
			} catch (error) {
				console.error('Failed to sync employee operation:', error);
			}
		}
	} catch (error) {
		console.error('Employee sync failed:', error);
	}
}

async function syncBranchData() {
	try {
		const pendingOperations = await getPendingOperations('branches');
		
		for (const operation of pendingOperations) {
			try {
				await fetch('/api/branches', {
					method: operation.method,
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify(operation.data)
				});
				
				await removePendingOperation('branches', operation.id);
			} catch (error) {
				console.error('Failed to sync branch operation:', error);
			}
		}
	} catch (error) {
		console.error('Branch sync failed:', error);
	}
}

async function syncVendorData() {
	try {
		const pendingOperations = await getPendingOperations('vendors');
		
		for (const operation of pendingOperations) {
			try {
				await fetch('/api/vendors', {
					method: operation.method,
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify(operation.data)
				});
				
				await removePendingOperation('vendors', operation.id);
			} catch (error) {
				console.error('Failed to sync vendor operation:', error);
			}
		}
	} catch (error) {
		console.error('Vendor sync failed:', error);
	}
}

// IndexedDB helpers for offline operations
async function getPendingOperations(type) {
	// Implementation would use IndexedDB to retrieve pending operations
	return [];
}

async function removePendingOperation(type, id) {
	// Implementation would remove completed operation from IndexedDB
	return true;
}
