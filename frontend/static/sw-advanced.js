// Enhanced service worker for Aqura PWA
// Provides offline functionality, background sync, data caching, and cache clearing
// IMPORTANT: Authentication data is preserved during cache clearing to keep users logged in

// Import workbox from CDN for service worker
importScripts('https://storage.googleapis.com/workbox-cdn/releases/7.0.0/workbox-sw.js');

// Initialize workbox
if (workbox) {
	console.log('[ServiceWorker] Workbox loaded successfully');
	
	// Enable debug mode in development
	workbox.setConfig({ debug: false });
	
	// The __WB_MANIFEST will be injected by vite-plugin-pwa
	// This handles precaching of static assets
	const manifest = self.__WB_MANIFEST || [];
	
	// Set up precaching with workbox
	workbox.precaching.precacheAndRoute(manifest);
	workbox.precaching.cleanupOutdatedCaches();
} else {
	console.error('[ServiceWorker] Workbox failed to load');
}

// Skip waiting and claim clients immediately for faster activation
self.skipWaiting();
self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

// Listen for immediate activation
self.addEventListener('message', (event) => {
	if (event.data && event.data.type === 'SKIP_WAITING') {
		self.skipWaiting();
	}
});

const CACHE_NAME = 'aqura-v1';
const DATA_CACHE_NAME = 'aqura-data-v1';
const PRECACHE_NAME = 'precache-v1';
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

// Install event - cache critical resources and handle precaching
self.addEventListener('install', (event) => {
	console.log('[ServiceWorker] Install');
	event.waitUntil(
		(async () => {
			// Clear all existing caches first if force clear is enabled
			if (FORCE_CLEAR_CACHE) {
				console.log('[ServiceWorker] 🧹 Force clearing all caches on install...');
				await clearAllCaches();
			}
			
			// Handle precache manifest from vite-plugin-pwa
			if (manifest && manifest.length > 0) {
				try {
					const precacheUrls = manifest.map(entry => entry.url || entry);
					const precacheCache = await caches.open(PRECACHE_NAME);
					console.log('[ServiceWorker] Precaching static assets:', precacheUrls.length, 'files');
					
					// Cache each file individually to handle failures gracefully
					const precacheResults = await Promise.allSettled(
						precacheUrls.map(url => precacheCache.add(url))
					);
					
					// Log any failures but don't block installation
					precacheResults.forEach((result, index) => {
						if (result.status === 'rejected') {
							console.warn(`[ServiceWorker] Failed to precache ${precacheUrls[index]}:`, result.reason);
						}
					});
				} catch (error) {
					console.error('[ServiceWorker] Precaching failed:', error);
				}
			}
			
			// Then setup main cache with critical resources
			try {
				const cache = await caches.open(CACHE_NAME);
				console.log('[ServiceWorker] Caching critical offline resources');
				
				// Cache each file individually with enhanced error handling
				const cachePromises = STATIC_CACHE_URLS.map(async (url, index) => {
					try {
						await cache.add(url);
						return { success: true, url };
					} catch (error) {
						// Only log in development, silently handle in production
						if (self.location.hostname === 'localhost') {
							console.warn(`[ServiceWorker] Failed to cache ${url}:`, error);
						}
						return { success: false, url, error };
					}
				});
				
				const results = await Promise.allSettled(cachePromises);
				const cached = results.filter(result => 
					result.status === 'fulfilled' && result.value.success
				).length;
				
				console.log(`[ServiceWorker] Successfully cached ${cached}/${STATIC_CACHE_URLS.length} static resources`);
				
				return self.skipWaiting();
			} catch (error) {
				// Only log critical errors in development
				if (self.location.hostname === 'localhost') {
					console.error('[ServiceWorker] Cache setup failed:', error);
				}
				// Continue anyway to prevent blocking PWA installation
				return self.skipWaiting();
			}
		})()
	);
});

// Activate event - enhanced cache cleanup and client claiming
self.addEventListener('activate', (event) => {
	console.log('[ServiceWorker] Activate');
	event.waitUntil(
		(async () => {
			// Always clear all caches on activation for fresh state
			console.log('[ServiceWorker] 🧹 Clearing all caches on activation...');
			await clearAllCaches();
			
			// Immediately claim all clients for faster activation
			await self.clients.claim();
			console.log('[ServiceWorker] ✅ Clients claimed immediately');
			
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

// Message handling for cache clearing requests and notification debugging
self.addEventListener('message', (event) => {
	console.log('[ServiceWorker] 📨 Message received:', event.data);
	
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
				
			case 'SHOW_NOTIFICATION':
				console.log('[ServiceWorker] 🔔 Direct notification request received:', event.data);
				event.waitUntil(
					self.registration.showNotification(event.data.title || 'Aqura Management', {
						body: event.data.body || 'Notification',
						icon: event.data.icon || '/icons/icon-192x192.png',
						badge: event.data.badge || '/icons/icon-96x96.png',
						tag: event.data.tag || `aqura-notification-${Date.now()}`,
						requireInteraction: true,
						silent: false,
						data: event.data.data || {}
					}).then(() => {
						console.log('[ServiceWorker] ✅ Direct notification shown successfully');
						event.ports[0]?.postMessage({
							type: 'NOTIFICATION_SHOWN',
							success: true,
							timestamp: Date.now()
						});
					}).catch((error) => {
						console.error('[ServiceWorker] ❌ Direct notification failed:', error);
						event.ports[0]?.postMessage({
							type: 'NOTIFICATION_SHOWN',
							success: false,
							error: error ? (error.message || String(error)) : 'Unknown notification error',
							timestamp: Date.now()
						});
					})
				);
				break;
				
			case 'CHECK_NOTIFICATION_PERMISSION':
				console.log('[ServiceWorker] 🔍 Checking notification permission');
				event.ports[0]?.postMessage({
					type: 'NOTIFICATION_PERMISSION_STATUS',
					permission: 'default', // Service Worker can't check permission directly
					swActive: !!self.registration.active,
					swScope: self.registration.scope,
					timestamp: Date.now()
				});
				break;
				
			default:
				console.log('[ServiceWorker] ❓ Unknown message type:', event.data.type);
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

// Push notification handling - handles both push events and direct showNotification calls
// CRITICAL: This works even when main app is completely closed but user is still logged in
self.addEventListener('push', (event) => {
	console.log('[ServiceWorker] 🔔 Push received - App may be completely closed', event);
	
	let notificationData;
	try {
		// Try to parse JSON data from push event
		notificationData = event.data ? event.data.json() : null;
		console.log('[ServiceWorker] 📨 Parsed notification data:', notificationData);
	} catch (error) {
		console.warn('[ServiceWorker] ⚠️ JSON parsing failed, using fallback:', error);
		// Fallback to text if JSON parsing fails
		notificationData = event.data ? { body: event.data.text() } : null;
	}
	
	// Check if user is still authenticated (even if app is closed)
	const checkAuthAndShowNotification = async () => {
		try {
			// Check for authentication data in storage
			const hasAuthData = await checkStoredAuth();
			console.log('[ServiceWorker] 🔐 Authentication check result:', hasAuthData);
			
			if (!hasAuthData) {
				console.log('[ServiceWorker] ❌ User not authenticated, skipping notification');
				return; // Don't show notifications to unauthenticated users
			}
			
			// Enhanced options for closed app scenario
			const options = {
				body: notificationData?.body || notificationData?.message || 'New update available',
				icon: notificationData?.icon || '/icons/icon-192x192.png',
				badge: notificationData?.badge || '/icons/icon-96x96.png',
				tag: notificationData?.tag || `aqura-notification-${Date.now()}`,
				// Enhanced for closed app - more aggressive to get user attention
				vibrate: [200, 100, 200, 100, 200], // Longer vibration for closed app
				requireInteraction: true, // Always require interaction when app is closed
				silent: false,
				// Enhanced timestamp tracking
				timestamp: Date.now(),
				data: {
					...notificationData?.data,
					dateOfArrival: Date.now(),
					notificationId: notificationData?.notificationId || Date.now(),
					appState: 'closed', // Track that app was closed when notification arrived
					authenticated: true, // User was authenticated when notification was sent
					deliveryMethod: 'service-worker-background'
				},
				// Enhanced actions for closed app scenario
				actions: [
					{
						action: 'open',
						title: '🚀 Open App',
						icon: '/icons/icon-96x96.png'
					},
					{
						action: 'view',
						title: '👁️ View Details',
						icon: '/icons/checkmark.png'
					},
					{
						action: 'dismiss',
						title: '❌ Dismiss',
						icon: '/icons/xmark.png'
					}
				]
			};

			console.log('[ServiceWorker] 🔔 Showing notification for closed app:', {
				title: notificationData?.title || 'Aqura Management',
				options: options,
				appState: 'closed',
				userAuthenticated: true
			});

			// Show the notification
			await self.registration.showNotification(
				notificationData?.title || 'Aqura Management', 
				options
			);
			
			console.log('[ServiceWorker] ✅ Background notification displayed successfully');
			
		} catch (error) {
			console.error('[ServiceWorker] ❌ Failed to show background notification:', error);
			
			// Fallback notification without auth check
			const fallbackOptions = {
				body: 'You have a new notification from Aqura',
				icon: '/icons/icon-192x192.png',
				badge: '/icons/icon-96x96.png',
				tag: `aqura-fallback-${Date.now()}`,
				requireInteraction: true,
				data: {
					fallback: true,
					error: error.message,
					appState: 'closed'
				}
			};
			
			await self.registration.showNotification('Aqura Management', fallbackOptions);
			console.log('[ServiceWorker] ✅ Fallback notification shown');
		}
	};
	
	event.waitUntil(checkAuthAndShowNotification());
});

// Helper function to check stored authentication
async function checkStoredAuth() {
	try {
		// Check for authentication indicators in various storage mechanisms
		
		// 1. Check localStorage/sessionStorage indicators
		const clients = await self.clients.matchAll();
		for (const client of clients) {
			if (client.url.includes(self.registration.scope)) {
				// Found a client, app might not be completely closed
				console.log('[ServiceWorker] 🔍 Found app client, checking auth state...');
				return true; // Assume authenticated if app client exists
			}
		}
		
		// 2. Check for auth-related cache data
		const cacheNames = await caches.keys();
		for (const cacheName of cacheNames) {
			if (PRESERVE_AUTH_KEYS.some(key => cacheName.includes(key))) {
				console.log('[ServiceWorker] 🔍 Found auth-related cache:', cacheName);
				return true;
			}
		}
		
		// 3. Basic heuristic - if we received a push notification, 
		//    it's likely the user is authenticated on the server side
		console.log('[ServiceWorker] 🔍 No explicit auth indicators, but push notification received');
		console.log('[ServiceWorker] 🔍 Assuming user is authenticated (server sent the push)');
		return true;
		
	} catch (error) {
		console.warn('[ServiceWorker] ⚠️ Auth check failed, defaulting to show notification:', error);
		return true; // Default to showing notification if check fails
	}
}

// Notification click handling - properly handle notification interactions
// CRITICAL: This handles clicks when main app is completely closed
self.addEventListener('notificationclick', (event) => {
	console.log('[ServiceWorker] 🔔 Notification click received (app may be closed):', event);
	console.log('[ServiceWorker] 🔔 Notification data:', event.notification.data);
	console.log('[ServiceWorker] 🔔 Action clicked:', event.action);
	
	// Close the notification
	event.notification.close();
	
	// Handle different actions with enhanced closed app support
	if (event.action === 'open' || event.action === 'explore' || event.action === 'view') {
		console.log('[ServiceWorker] � Opening/focusing app from closed state');
		event.waitUntil(
			handleAppOpen(event.notification.data).catch((error) => {
				console.error('[ServiceWorker] ❌ Error opening app from notification:', error);
			})
		);
	} else if (event.action === 'dismiss' || event.action === 'close') {
		console.log('[ServiceWorker] ❌ Notification dismissed by user');
		// Log dismissal for analytics
		event.waitUntil(
			logNotificationDismissal(event.notification.data)
		);
	} else {
		// Default action (clicking on notification body) - open app
		console.log('[ServiceWorker] 🔍 Default notification click - opening app from closed state');
		event.waitUntil(
			handleAppOpen(event.notification.data).catch((error) => {
				console.error('[ServiceWorker] ❌ Error opening app from notification:', error);
			})
		);
	}
});

// Enhanced app opening logic for closed app scenario
async function handleAppOpen(notificationData) {
	console.log('[ServiceWorker] 🔍 Handling app open from closed state...');
	
	try {
		// First, check if there are any existing app windows
		const clientList = await clients.matchAll({ 
			type: 'window', 
			includeUncontrolled: true 
		});
		
		console.log(`[ServiceWorker] 🔍 Found ${clientList.length} existing windows`);
		
		// Check if app is already open
		for (const client of clientList) {
			if (client.url.includes(self.registration.scope) && 'focus' in client) {
				console.log('[ServiceWorker] 📱 Found existing app window, focusing it');
				
				// Send notification data to the existing window
				if ('postMessage' in client) {
					client.postMessage({
						type: 'NOTIFICATION_CLICK',
						data: notificationData,
						source: 'service-worker',
						appWasClosed: false
					});
				}
				
				return client.focus();
			}
		}
		
		// No existing window found - app was completely closed
		console.log('[ServiceWorker] 🆕 No existing app window found - app was closed');
		console.log('[ServiceWorker] 🚀 Opening new app window...');
		
		// Determine the best route to open based on notification data and user preferences
		const targetRoute = await determineTargetRoute(notificationData);
		console.log('[ServiceWorker] 🎯 Target route determined:', targetRoute);
		
		// Open new window
		const newClient = await clients.openWindow(targetRoute);
		
		if (newClient) {
			console.log('[ServiceWorker] ✅ New app window opened successfully');
			
			// Wait a moment for the window to load, then send notification data
			setTimeout(() => {
				if ('postMessage' in newClient) {
					newClient.postMessage({
						type: 'NOTIFICATION_CLICK',
						data: notificationData,
						source: 'service-worker',
						appWasClosed: true, // Indicate app was closed
						openedFromNotification: true
					});
					console.log('[ServiceWorker] 📨 Notification data sent to new window');
				}
			}, 2000); // Wait 2 seconds for app to initialize
			
			return newClient.focus();
		} else {
			console.error('[ServiceWorker] ❌ Failed to open new app window');
			throw new Error('Failed to open new app window');
		}
		
	} catch (error) {
		console.error('[ServiceWorker] ❌ Error in handleAppOpen:', error);
		
		// Fallback: try to open at root
		console.log('[ServiceWorker] 🔄 Attempting fallback app open at root...');
		return clients.openWindow('/');
	}
}

// Determine the best route to open based on notification data and user preferences
async function determineTargetRoute(notificationData) {
	try {
		// Check notification data for specific route
		if (notificationData?.data?.url) {
			console.log('[ServiceWorker] 🎯 Using notification-specific URL:', notificationData.data.url);
			return notificationData.data.url;
		}
		
		// Check for specific notification types
		if (notificationData?.data?.type) {
			const notificationType = notificationData.data.type;
			console.log('[ServiceWorker] 🔍 Notification type:', notificationType);
			
			switch (notificationType) {
				case 'task':
					return '/mobile/tasks';
				case 'employee':
					return '/mobile/employees';
				case 'branch':
					return '/mobile/branches';
				case 'vendor':
					return '/mobile/vendors';
				case 'system':
					return '/mobile/dashboard';
				default:
					console.log('[ServiceWorker] � Unknown notification type, using mobile dashboard');
					return '/mobile/dashboard';
			}
		}
		
		// Get user's preferred interface from stored data
		const preferredInterface = await getStoredInterfacePreference();
		console.log('[ServiceWorker] 📱 User interface preference:', preferredInterface);
		
		// Default routes based on interface preference
		if (preferredInterface === 'mobile') {
			return '/mobile/dashboard';
		} else {
			return '/dashboard';
		}
		
	} catch (error) {
		console.warn('[ServiceWorker] ⚠️ Error determining target route, using fallback:', error);
		return '/mobile/dashboard'; // Safe fallback
	}
}

// Get stored interface preference
async function getStoredInterfacePreference() {
	try {
		// Try to get interface preference from cache or storage
		// This is a best-effort attempt since app is closed
		
		// Default to mobile for PWA installations
		const isPWA = self.registration.scope.includes('standalone') || 
		             location.search.includes('utm_source=pwa');
		
		return isPWA ? 'mobile' : 'mobile'; // Default to mobile for better mobile experience
	} catch (error) {
		console.warn('[ServiceWorker] ⚠️ Could not determine interface preference:', error);
		return 'mobile'; // Safe default
	}
}

// Log notification dismissal for analytics
async function logNotificationDismissal(notificationData) {
	try {
		console.log('[ServiceWorker] 📊 Logging notification dismissal:', {
			notificationId: notificationData?.notificationId,
			timestamp: Date.now(),
			appState: 'closed'
		});
		
		// Could send to analytics endpoint if needed
		// For now, just log to console for debugging
		
	} catch (error) {
		console.warn('[ServiceWorker] ⚠️ Failed to log notification dismissal:', error);
	}
}

// Helper function to get appropriate route based on interface preference
async function getAppropriateRoute() {
	try {
		// Check interface preference from localStorage
		const interfacePreference = await getStorageValue('aqura-interface-preference');
		const userInterfacePreference = await getStorageValue('aqura-user-interface-preference');
		const forceMobile = await getStorageValue('aqura-force-mobile');
		const lastInterface = await getStorageValue('aqura-last-interface');
		
		console.log('[ServiceWorker] 🔍 Interface preferences:', {
			interfacePreference,
			userInterfacePreference,
			forceMobile,
			lastInterface
		});
		
		// Check if mobile interface is preferred
		const isMobilePreferred = interfacePreference === 'mobile' || 
								forceMobile === 'true' || 
								lastInterface === 'mobile';
		
		if (isMobilePreferred) {
			console.log('[ServiceWorker] 📱 Mobile interface preferred, redirecting to /mobile');
			return '/mobile';
		}
		
		console.log('[ServiceWorker] 🖥️ Desktop interface preferred, redirecting to /');
		return '/';
	} catch (error) {
		console.error('[ServiceWorker] ❌ Error determining appropriate route:', error);
		// Default to root path
		return '/';
	}
}

// Helper function to get storage values from IndexedDB or localStorage
async function getStorageValue(key) {
	try {
		// Try to access localStorage (this works in service worker context)
		return new Promise((resolve) => {
			// Send message to clients to get localStorage value
			self.clients.matchAll().then((clients) => {
				if (clients.length > 0) {
					const messageChannel = new MessageChannel();
					messageChannel.port1.onmessage = (event) => {
						resolve(event.data.value);
					};
					
					clients[0].postMessage({
						type: 'GET_STORAGE_VALUE',
						key: key
					}, [messageChannel.port2]);
				} else {
					resolve(null);
				}
			});
		});
	} catch (error) {
		console.error('[ServiceWorker] ❌ Error getting storage value:', error);
		return null;
	}
}

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
