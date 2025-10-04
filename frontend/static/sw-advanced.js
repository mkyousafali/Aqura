// Enhanced service worker for Aqura PWA
// Provides offline functionality, background sync, data caching, and cache clearing
// IMPORTANT: Authentication data is preserved during cache clearing to keep users logged in

const CACHE_NAME = 'aqura-v1';
const DATA_CACHE_NAME = 'aqura-data-v1';
const FORCE_CLEAR_CACHE = true; // Set to true to clear caches on every activation

// Authentication-related storage keys that should NEVER be cleared
const PRESERVE_AUTH_KEYS = [
	'aqura-device-session',    // User sessions and login state
	'aqura-device-id',         // Device identification
	'aqura-auth-token',        // Authentication tokens
	'aqura-user-data'          // User profile data
];

// Authentication-related IndexedDB names that should be preserved
const PRESERVE_AUTH_DBS = [
	'auth', 'session', 'user', 'login', 'token', 'device'
];

// Critical resources to cache for offline functionality
const STATIC_CACHE_URLS = [
	'/',
	'/manifest.json',
	'/offline.html'
];

// API endpoints to cache with different strategies
const API_CACHE_PATTERNS = [
	'/api/employees',
	'/api/branches', 
	'/api/vendors',
	'/api/users'
];

// Cache clearing utility functions (preserves authentication data)
async function clearAllCaches() {
	console.log('[ServiceWorker] 🧹 Starting cache clearing (preserving auth data)...');
	
	try {
		const cacheNames = await caches.keys();
		console.log(`[ServiceWorker] 🗑️ Found ${cacheNames.length} cache(s) to clear`);
		
		// Delete all existing caches
		const deletionPromises = cacheNames.map(async (cacheName) => {
			console.log(`[ServiceWorker]    🗑️ Deleting cache: ${cacheName}`);
			return caches.delete(cacheName);
		});
		
		await Promise.all(deletionPromises);
		console.log('[ServiceWorker] ✅ All caches cleared successfully');
		
		// Clear IndexedDB (except authentication data)
		if ('indexedDB' in self) {
			try {
				const databases = await indexedDB.databases();
				
				for (const db of databases) {
					// Preserve authentication and session related databases
					if (db.name && 
						!db.name.includes('auth') && 
						!db.name.includes('session') && 
						!db.name.includes('user') &&
						!db.name.includes('login') &&
						!db.name.includes('token') &&
						!db.name.includes('device')) {
						try {
							const deleteRequest = indexedDB.deleteDatabase(db.name);
							await new Promise((resolve, reject) => {
								deleteRequest.onsuccess = () => resolve();
								deleteRequest.onerror = () => reject(deleteRequest.error);
							});
							console.log(`[ServiceWorker] 🗑️ Deleted IndexedDB: ${db.name}`);
						} catch (error) {
							console.warn(`[ServiceWorker] Failed to delete IndexedDB ${db.name}:`, error);
						}
					} else {
						console.log(`[ServiceWorker] 🔐 Preserving auth-related IndexedDB: ${db.name}`);
					}
				}
			} catch (error) {
				console.warn('[ServiceWorker] Failed to clear IndexedDB:', error);
			}
		}
		
		// Notify all clients about cache clearing (but preserve auth data)
		const clients = await self.clients.matchAll();
		clients.forEach(client => {
			client.postMessage({
				type: 'CLEAR_STORAGE_EXCEPT_AUTH',
				timestamp: Date.now()
			});
		});
		
	} catch (error) {
		console.error('[ServiceWorker] ❌ Failed to clear caches:', error);
	}
}

// Enhanced cache clearing on page refresh detection
async function handlePageRefresh() {
	console.log('[ServiceWorker] 🔄 Page refresh detected, clearing caches...');
	await clearAllCaches();
}

// Install event - cache critical resources and clear old caches
self.addEventListener('install', (event) => {
	console.log('[ServiceWorker] Install');
	event.waitUntil(
		(async () => {
			// Clear all existing caches first if force clear is enabled
			if (FORCE_CLEAR_CACHE) {
				console.log('[ServiceWorker] 🧹 Force clearing all caches on install...');
				await clearAllCaches();
			}
			
			// Then setup fresh cache
			try {
				const cache = await caches.open(CACHE_NAME);
				console.log('[ServiceWorker] Pre-caching offline resources');
				
				// Cache each file individually to handle failures gracefully
				const results = await Promise.allSettled(
					STATIC_CACHE_URLS.map(url => cache.add(url))
				);
				
				// Log any failures but don't block installation
				results.forEach((result, index) => {
					if (result.status === 'rejected') {
						console.warn(`[ServiceWorker] Failed to cache ${STATIC_CACHE_URLS[index]}:`, result.reason);
					}
				});
				
				return self.skipWaiting();
			} catch (error) {
				console.error('[ServiceWorker] Cache setup failed:', error);
				// Continue anyway to prevent blocking
				return self.skipWaiting();
			}
		})()
	);
});

// Activate event - enhanced cache cleanup and force clear
self.addEventListener('activate', (event) => {
	console.log('[ServiceWorker] Activate');
	event.waitUntil(
		(async () => {
			// Always clear all caches on activation for fresh state
			console.log('[ServiceWorker] 🧹 Clearing all caches on activation...');
			await clearAllCaches();
			
			// Then setup fresh caches
			try {
				const cacheNames = await caches.keys();
				console.log('[ServiceWorker] Setting up fresh cache state');
				
				// Claim all clients immediately
				await self.clients.claim();
				
				// Notify all clients that service worker is ready with fresh state
				const clients = await self.clients.matchAll();
				clients.forEach(client => {
					client.postMessage({
						type: 'SW_ACTIVATED_FRESH',
						timestamp: Date.now(),
						cachesCleared: true
					});
				});
				
				console.log('[ServiceWorker] ✅ Activation complete with fresh state');
			} catch (error) {
				console.error('[ServiceWorker] Activation error:', error);
			}
		})()
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
					return caches.match('/offline.html').then((cachedOffline) => {
						if (cachedOffline) {
							return cachedOffline;
						}
						// Fallback if offline.html isn't cached
						return new Response(
							'<html><body><h1>Offline</h1><p>You are offline. Please check your connection.</p></body></html>',
							{ headers: { 'Content-Type': 'text/html' } }
						);
					});
				}
			})
	);
});

// Message handling for cache clearing requests
self.addEventListener('message', (event) => {
	console.log('[ServiceWorker] Message received:', event.data);
	
	if (event.data && event.data.type) {
		switch (event.data.type) {
			case 'CLEAR_ALL_CACHES':
				console.log('[ServiceWorker] 🧹 Cache clear requested from client');
				event.waitUntil(
					clearAllCaches().then(() => {
						// Respond back to client
						event.ports[0]?.postMessage({
							type: 'CACHES_CLEARED',
							success: true,
							timestamp: Date.now()
						});
					}).catch((error) => {
						console.error('[ServiceWorker] Cache clear failed:', error);
						event.ports[0]?.postMessage({
							type: 'CACHES_CLEARED',
							success: false,
							error: error.message,
							timestamp: Date.now()
						});
					})
				);
				break;
				
			case 'PAGE_REFRESH_DETECTED':
				console.log('[ServiceWorker] 🔄 Page refresh detected from client');
				event.waitUntil(handlePageRefresh());
				break;
				
			case 'SKIP_WAITING':
				console.log('[ServiceWorker] Skip waiting requested');
				self.skipWaiting();
				break;
				
			default:
				console.log('[ServiceWorker] Unknown message type:', event.data.type);
		}
	}
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
