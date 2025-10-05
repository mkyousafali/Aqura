<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { get } from 'svelte/store';
	import { initI18n, currentLocale, localeData } from '$lib/i18n';
	import { sidebar } from '$lib/stores/sidebar';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import '../app.css';
	import WindowManager from '$lib/components/WindowManager.svelte';
	import Taskbar from '$lib/components/Taskbar.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import CommandPalette from '$lib/components/CommandPalette.svelte';
	import ToastNotifications from '$lib/components/ToastNotifications.svelte';
	import UserSwitcher from '$lib/components/UserSwitcher.svelte';
	import PushNotificationSettings from '$lib/components/PushNotificationSettings.svelte';
	
	// Enhanced imports for persistent auth and push notifications
	import { persistentAuthService, currentUser, isAuthenticated as persistentAuthState } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { pushNotificationProcessor } from '$lib/utils/pushNotificationProcessor';
	import { pushNotificationService } from '$lib/utils/pushNotifications';
	import { windowManager } from '$lib/stores/windowManager';
	import { initPWAInstall } from '$lib/stores/pwaInstall';
	import { cacheManager } from '$lib/utils/cacheManager';
	import NotificationWindow from '$lib/components/admin/communication/NotificationWindow.svelte';

	// Initialize i18n system
	initI18n();

	// Command palette state
	let showCommandPalette = false;
	
	// User management states
	let showUserSwitcher = false;
	let showNotificationSettings = false;
	
	// PWA update state
	let showUpdatePrompt = false;
	let needRefresh;
	let updateServiceWorker;
	
	// PWA update functions
	async function handlePWAUpdate() {
		console.log('PWA Update requested');
		console.log('Navigator online:', navigator.onLine);
		console.log('UpdateServiceWorker available:', !!updateServiceWorker);
		
		showUpdatePrompt = false;
		
		// Multiple connectivity checks
		const isOnline = navigator.onLine;
		let networkTest = false;
		
		try {
			// Test actual network connectivity with a small fetch
			const response = await fetch('/favicon.ico', { 
				method: 'HEAD', 
				cache: 'no-cache',
				signal: AbortSignal.timeout(3000)
			});
			networkTest = response.ok;
		} catch (error) {
			console.warn('Network test failed:', error);
			networkTest = false;
		}
		
		console.log('Network test result:', networkTest);
		
		if (!isOnline || !networkTest) {
			console.warn('No network connection detected');
			alert('No internet connection. Please check your connection and try again.');
			showUpdatePrompt = true;
			return;
		}
		
		if (updateServiceWorker) {
			try {
				console.log('Calling updateServiceWorker with skipWaiting=true');
				await updateServiceWorker(true);
				console.log('PWA update successful');
				
				// Optional: Show success message
				setTimeout(() => {
					window.location.reload();
				}, 1000);
			} catch (error) {
				console.error('PWA update failed:', error);
				alert('Update failed. Please refresh the page and try again.');
				showUpdatePrompt = true;
			}
		} else {
			console.error('updateServiceWorker function not available');
			alert('Update not available. Please refresh the page manually.');
		}
	}
	
	function dismissUpdate() {
		showUpdatePrompt = false;
	}
	
	// Auto-cleanup existing service workers and clear all caches on app startup
	async function autoCleanupServiceWorkers() {
		console.log('🧹 Starting automatic service worker cleanup and cache clearing...');
		
		// Always clear all caches on app startup/refresh
		try {
			console.log('🗑️ Clearing all application caches...');
			await cacheManager.clearAllCaches();
			
			// Get cache stats for logging
			const stats = await cacheManager.getCacheStats();
			console.log('📊 Cache stats after clearing:', stats);
			
		} catch (error) {
			console.warn('⚠️ Cache clearing failed:', error);
		}
		
		if ('serviceWorker' in navigator) {
			try {
				// Get all existing registrations
				const registrations = await navigator.serviceWorker.getRegistrations();
				
				if (registrations.length > 0) {
					console.log(`🔍 Found ${registrations.length} existing service worker(s)`);
					
					let unregisteredCount = 0;
					let preservedCount = 0;
					
					// Only unregister problematic service workers, preserve push notification SW
					for (let registration of registrations) {
						const scriptURL = registration.active?.scriptURL || registration.waiting?.scriptURL || registration.installing?.scriptURL || '';
						const scope = registration.scope;
						
						// Check if this is a push notification service worker that should be preserved
						const isPushNotificationSW = scriptURL.includes('/sw-push.js') || 
							scriptURL.includes('/sw-advanced.js') || // Preserve our enhanced SW
							(scope.includes('/') && scriptURL.includes('sw-push'));
						
						// Check if this is a problematic service worker that should be removed
						const isProblematicSW = scriptURL.includes('/sw.js') || 
							scriptURL.includes('workbox') ||
							scriptURL.includes('vite') ||
							scope.includes('workbox') ||
							(scriptURL.includes('/sw-advanced.js') === false && scope.includes('sw-advanced')); // Only remove if not our enhanced SW
						
						if (isPushNotificationSW && !isProblematicSW) {
							console.log(`✅ Preserving push notification SW: ${scope}`);
							preservedCount++;
						} else if (isProblematicSW) {
							console.log(`🗑️ Removing problematic SW: ${scope}`);
							
							// Send cache clear message before unregistering
							if (registration.active) {
								try {
									registration.active.postMessage({
										type: 'PAGE_REFRESH_DETECTED',
										timestamp: Date.now()
									});
								} catch (error) {
									console.warn('⚠️ Failed to notify service worker:', error);
								}
							}
							
							await registration.unregister();
							unregisteredCount++;
						} else {
							console.log(`⚠️ Unknown SW, preserving for safety: ${scope}`);
							preservedCount++;
						}
					}
					
					console.log(`✅ Cleanup completed: ${unregisteredCount} removed, ${preservedCount} preserved`);
				} else {
					console.log('✨ No existing service workers found');
				}
				
				console.log('🎉 Service worker cleanup and cache clearing completed successfully');
				
			} catch (error) {
				console.warn('⚠️ Service worker cleanup failed:', error);
			}
		} else {
			console.log('❌ Service workers not supported in this browser');
		}
	}
	
	// Authentication state
	let isAuthenticated = false;
	let isLoading = true;
	let currentUserData = null;
	let unsubscribePersistent: (() => void) | undefined;
	let unsubscribeUser: (() => void) | undefined;

	onMount(async () => {
		try {
			// Add desktop-mode class to body when in desktop interface (exclude mobile routes)
			const updateBodyClass = () => {
				if (isAuthenticated && !isLoginPage && !isMobileRoute && !isMobileLoginRoute) {
					document.body.classList.add('desktop-mode');
				} else {
					document.body.classList.remove('desktop-mode');
				}
			};

			// Detect app refresh/reopen and clear caches immediately
			detectAppRefreshAndClearCaches();
			
			// Add service worker message listener for cache clearing
			if ('serviceWorker' in navigator) {
				navigator.serviceWorker.addEventListener('message', (event) => {
					if (event.data && event.data.type === 'CLEAR_STORAGE_EXCEPT_AUTH') {
						clearStorageExceptAuth();
					}
				});
			}
			
			// Initialize persistent authentication first
			try {
				await persistentAuthService.initializeAuth();
				console.log('✅ Persistent auth initialization completed');
			} catch (authError) {
				console.error('❌ Persistent auth initialization failed:', authError);
				// Continue with app initialization even if auth fails
				isLoading = false;
				isAuthenticated = false;
			}
			
			// Force check auth state immediately to prevent loading hang
			const currentAuthState = $persistentAuthState;
			const currentUserState = $currentUser;
			console.log('🔐 Initial auth state check:', { authenticated: currentAuthState, user: currentUserState });
			
			// Set initial state based on current auth status
			isAuthenticated = currentAuthState;
			currentUserData = currentUserState;
			
			// Only redirect if necessary and avoid loops
			if (currentAuthState === false && $page.url.pathname !== '/login') {
				console.log('🔐 Initial check: Not authenticated, will redirect to login');
			} else if (currentAuthState === true && $page.url.pathname === '/login') {
				console.log('🔐 Initial check: Already authenticated, will redirect to dashboard');
			}
			
			// Add a small delay to allow auth state to stabilize
			await new Promise(resolve => setTimeout(resolve, 100));
			
			// Set loading to false after initial auth check (fallback)
			if (isLoading) {
				console.log('🔐 Setting initial loading state to false');
				isLoading = false;
			}
			
			// Auto-cleanup existing service workers and clear caches on startup (non-blocking)
			autoCleanupServiceWorkers().then(() => {
				console.log('🎉 Service worker cleanup completed, checking auth for notifications...');
				// Initialize notification services AFTER cleanup is complete and if user is authenticated
				if (isAuthenticated) {
					console.log('🔔 User is authenticated, initializing notification services...');
					return initializeNotificationServices();
				} else {
					console.log('🔐 User not authenticated, skipping notification initialization');
				}
			}).catch(error => {
				console.warn('⚠️ Service worker cleanup failed (non-blocking):', error);
				// Still try to initialize notifications even if cleanup failed (if authenticated)
				if (isAuthenticated) {
					console.log('🔔 Initializing notification services despite cleanup failure...');
					return initializeNotificationServices();
				}
			});
			
			// Initialize PWA install detection
			initPWAInstall();
			
			// Initialize PWA only in production and when enabled
			if (import.meta.env.PROD && import.meta.env.VITE_PWA_ENABLED !== 'false') {
				try {
					console.log('🔧 Initializing PWA in production mode...');
					
					// Manual service worker registration since we disabled automatic injection
					if ('serviceWorker' in navigator) {
						const registration = await navigator.serviceWorker.register('/sw-advanced.js', {
							scope: '/',
							updateViaCache: 'none'
						});
						
						console.log('✅ PWA Service Worker registered:', registration);
						
						// Handle service worker updates
						registration.addEventListener('updatefound', () => {
							console.log('� PWA update found');
							const newWorker = registration.installing;
							if (newWorker) {
								newWorker.addEventListener('statechange', () => {
									if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
										console.log('🆕 New PWA version available');
										showUpdatePrompt = true;
									}
								});
							}
						});
						
						// Handle controller change (when new SW takes control)
						navigator.serviceWorker.addEventListener('controllerchange', () => {
							console.log('🔄 PWA Service Worker controller changed');
							window.location.reload();
						});
						
						// Set up update function
						updateServiceWorker = async () => {
							console.log('🔄 Updating PWA Service Worker...');
							const newRegistration = await navigator.serviceWorker.register('/sw-advanced.js', {
								scope: '/',
								updateViaCache: 'none'
							});
							
							if (newRegistration.waiting) {
								newRegistration.waiting.postMessage({ type: 'SKIP_WAITING' });
							}
							
							showUpdatePrompt = false;
						};
						
						console.log('✅ PWA initialization completed');
					} else {
						console.warn('⚠️ Service Workers not supported');
					}
				} catch (error) {
					console.error('❌ PWA initialization error:', error);
				}
			} else {
				console.log('PWA disabled in development mode');
			}
			
			// Skip legacy auth initialization to prevent conflicts
			// await auth.init(); // Disabled - using persistent auth instead
			
			// Clear any legacy auth data once on startup
			localStorage.removeItem('aqura-auth-token');
			localStorage.removeItem('aqura-user-data');
			console.log('🔐 Legacy auth data cleared on startup');
			
			// Subscribe to persistent auth state
			unsubscribePersistent = persistentAuthState.subscribe(authenticated => {
				console.log('🔐 Persistent auth state changed:', authenticated);
				isAuthenticated = authenticated;
				
				// Set loading to false after we get the first auth state
				isLoading = false;
				
				// Update body class for desktop mode
				updateBodyClass();
				
				// Only redirect if we're not already on the target page to prevent loops
				if (!authenticated && $page.url.pathname !== '/login') {
					console.log('🔐 Not authenticated, redirecting to login');
					goto('/login', { replaceState: true });
				}
				
				// Redirect authenticated users away from login page
				if (authenticated && $page.url.pathname === '/login') {
					console.log('🔐 Already authenticated, redirecting to dashboard');
					goto('/', { replaceState: true });
				}
			});

			// Subscribe to current user changes
			unsubscribeUser = currentUser.subscribe(user => {
				currentUserData = user;
				console.log('Current user changed:', user);
			});

			// Fallback timeout to prevent infinite loading
			const loadingTimeout = setTimeout(() => {
				if (isLoading) {
					console.warn('⚠️ Loading timeout reached, forcing loading state to false');
					isLoading = false;
					
					// If still not authenticated after timeout, redirect to login (exclude mobile routes)
					if (!isAuthenticated && $page.url.pathname !== '/login' && !isMobileRoute && !isMobileLoginRoute) {
						console.log('🔐 Timeout reached, redirecting to login');
						goto('/login');
					}
				}
			}, 5000); // 5 second timeout
			
			// Return cleanup function for the timeout
			return () => {
				clearTimeout(loadingTimeout);
			};

			// Legacy auth subscription disabled - using persistent auth only
			// unsubscribeLegacy = auth.subscribe(session => {
			//	console.log('Legacy auth state changed:', session ? 'authenticated' : 'not authenticated');
			// });

			// Notification services will be initialized after cleanup completes
			console.log('🔔 Notification services will initialize after service worker cleanup');
		} catch (error) {
			console.error('Error initializing layout:', error);
			// Ensure loading state is always resolved even on error
			isLoading = false;
			isAuthenticated = false;
			
			// Only redirect to login if we're not already there
			if ($page.url.pathname !== '/login') {
				console.log('🔐 Initialization failed, redirecting to login');
				goto('/login', { replaceState: true });
			}
		}
		
		// Listen for page visibility changes to clear caches when user returns
		const handleVisibilityChange = () => {
			if (!document.hidden) {
				console.log('🔄 App became visible, clearing caches...');
				cacheManager.clearAllCaches().catch(error => {
					console.warn('⚠️ Failed to clear caches on visibility change:', error);
				});
			}
		};
		
		// Listen for beforeunload to clear caches when leaving
		const handleBeforeUnload = () => {
			console.log('🚪 App closing/refreshing, clearing caches...');
			// Use synchronous method for beforeunload
			navigator.sendBeacon && navigator.sendBeacon('/api/clear-cache', JSON.stringify({
				type: 'page_unload',
				timestamp: Date.now()
			}));
		};
		
		document.addEventListener('visibilitychange', handleVisibilityChange);
		window.addEventListener('beforeunload', handleBeforeUnload);
		
		// Cleanup function
		return () => {
			document.removeEventListener('visibilitychange', handleVisibilityChange);
			window.removeEventListener('beforeunload', handleBeforeUnload);
		};
	});
	
	onDestroy(() => {
		// Cleanup subscriptions on component destroy
		if (unsubscribePersistent) unsubscribePersistent();
		if (unsubscribeUser) unsubscribeUser();
		
		// Remove desktop-mode class from body
		if (typeof document !== 'undefined') {
			document.body.classList.remove('desktop-mode');
		}
	});

	async function initializeNotificationServices() {
		try {
			// Initialize push notification service first
			console.log('🚀 Initializing push notification service...');
			await pushNotificationService.initialize();
			
			// Check if push notifications are supported and user wants them
			const isSupported = notificationService.isPushNotificationSupported();
			const permission = notificationService.getPushNotificationPermission();
			
			if (isSupported && permission === 'granted') {
				// Auto-register for push notifications
				await notificationService.registerForPushNotifications();
				
				// Start real-time notification listener
				await notificationService.startRealtimeNotificationListener();
			}
			
			// Start the push notification processor
			console.log('🚀 Starting push notification processor...');
			pushNotificationProcessor.start();
			
		} catch (error) {
			console.error('Error initializing notification services:', error);
		}

		// Listen for custom events from service worker
		const handleOpenNotificationWindow = (event: CustomEvent) => {
			console.log('🔔 Opening notification window from push notification:', event.detail);
			openNotificationWindow(event.detail.notificationId);
		};

		// Add event listener for opening notification windows
		window.addEventListener('openNotificationWindow', handleOpenNotificationWindow as EventListener);

		// Cleanup function
		return () => {
			window.removeEventListener('openNotificationWindow', handleOpenNotificationWindow as EventListener);
		};
	}

	// Function to open notification window
	function openNotificationWindow(notificationId: string | null = null) {
		const windowId = `notification-center-${Date.now()}`;
		
		windowManager.openWindow({
			id: windowId,
			title: notificationId ? 'Notifications - Specific Item' : 'Notifications',
			component: NotificationWindow,
			props: {
				targetNotificationId: notificationId
			},
			icon: '🔔',
			size: { width: 900, height: 600 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		console.log('🔔 Notification window opened:', windowId, 'targeting notification:', notificationId);
	}

	// Detect app refresh/reopen and clear caches
	function detectAppRefreshAndClearCaches() {
		console.log('🔄 App startup detected, clearing caches...');
		
		// Set a flag to indicate this is a fresh app load
		sessionStorage.setItem('aqura-fresh-load', 'true');
		
		// Always clear caches on app startup (non-blocking)
		cacheManager.clearAllCaches().then(() => {
			console.log('✅ Caches cleared on app startup');
		}).catch((error) => {
			console.warn('⚠️ Failed to clear caches on startup:', error);
		});
	}
	
	// Clear storage except authentication data
	function clearStorageExceptAuth() {
		console.log('🧹 Clearing storage except authentication data...');
		
		try {
			// Get authentication-related keys to preserve
			const authKeys = [
				'aqura-device-session',
				'aqura-device-id'
			];
			
			// Preserve authentication data
			const preservedData: {[key: string]: string} = {};
			authKeys.forEach(key => {
				const value = localStorage.getItem(key);
				if (value) {
					preservedData[key] = value;
				}
			});
			
			// Clear localStorage except auth data
			const keysToRemove: string[] = [];
			for (let i = 0; i < localStorage.length; i++) {
				const key = localStorage.key(i);
				if (key && !authKeys.includes(key)) {
					keysToRemove.push(key);
				}
			}
			
			keysToRemove.forEach(key => {
				localStorage.removeItem(key);
			});
			
			// Restore preserved authentication data
			Object.entries(preservedData).forEach(([key, value]) => {
				localStorage.setItem(key, value);
			});
			
			// Clear sessionStorage except for critical session data
			const sessionAuthKeys = ['aqura-fresh-load'];
			const preservedSessionData: {[key: string]: string} = {};
			
			sessionAuthKeys.forEach(key => {
				const value = sessionStorage.getItem(key);
				if (value) {
					preservedSessionData[key] = value;
				}
			});
			
			sessionStorage.clear();
			
			// Restore preserved session data
			Object.entries(preservedSessionData).forEach(([key, value]) => {
				sessionStorage.setItem(key, value);
			});
			
			console.log('✅ Storage cleared successfully (authentication data preserved)');
			
		} catch (error) {
			console.warn('⚠️ Failed to clear storage:', error);
		}
	}
	
	// Enhanced keyboard shortcuts
	function handleGlobalKeydown(event: KeyboardEvent) {
		// Only handle shortcuts if user is authenticated
		if (!isAuthenticated) return;
		
		// Ctrl+Shift+P or Cmd+Shift+P for command palette
		if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'P') {
			event.preventDefault();
			showCommandPalette = !showCommandPalette;
		}
		
		// Ctrl+Shift+U or Cmd+Shift+U for user switcher
		if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'U') {
			event.preventDefault();
			showUserSwitcher = !showUserSwitcher;
		}
		
		// Ctrl+Shift+N or Cmd+Shift+N for notification settings
		if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'N') {
			event.preventDefault();
			showNotificationSettings = !showNotificationSettings;
		}
		
		// Escape to close all modals
		if (event.key === 'Escape') {
			showCommandPalette = false;
			showUserSwitcher = false;
			showNotificationSettings = false;
		}
	}

	// Direction class for RTL support
	$: directionClass = $localeData?.direction === 'rtl' ? 'rtl' : 'ltr';
	
	// Check if current route is login page
	// Page state management - detect mobile routes
	$: isLoginPage = $page.url.pathname === '/login';
	$: isMobileRoute = $page.url.pathname.startsWith('/mobile');
	$: isMobileLoginRoute = $page.url.pathname.startsWith('/mobile-login');

	// Update body class when authentication or page state changes (exclude mobile routes)
	$: if (typeof document !== 'undefined') {
		if (isAuthenticated && !isLoginPage && !isMobileRoute && !isMobileLoginRoute) {
			document.body.classList.add('desktop-mode');
		} else {
			document.body.classList.remove('desktop-mode');
		}
	}

	// Handle user switching
	function handleUserSwitchRequest() {
		showUserSwitcher = true;
	}

	// Handle notification settings request
	function handleNotificationSettingsRequest() {
		showNotificationSettings = true;
	}
</script>

<svelte:window on:keydown={handleGlobalKeydown} />

<!-- Show loading screen while checking authentication -->
{#if isLoading && !isMobileRoute && !isMobileLoginRoute}
	<div class="loading-screen">
		<div class="loading-spinner"></div>
		<p>Loading...</p>
	</div>
{:else if isMobileRoute || isMobileLoginRoute}
	<!-- Mobile routes get no desktop layout - completely independent -->
	<slot />
{:else}
	<div class="app {directionClass}" dir={$localeData?.direction || 'ltr'}>
		<!-- Show full UI only if authenticated and not on login page -->
		{#if isAuthenticated && !isLoginPage}
			<!-- Sidebar Navigation -->
			<Sidebar />
			
			<!-- Desktop Background -->
			<div class="desktop" style="margin-left: {$sidebar.width}px">
				<!-- Main content area -->
				<main class="main-content">
					<slot />
				</main>
				
				<!-- Window Management System -->
				<WindowManager />
				
				<!-- Command Palette -->
				<CommandPalette 
					bind:visible={showCommandPalette}
					on:close={() => showCommandPalette = false}
				/>

				<!-- User Switcher Modal -->
				<UserSwitcher
					isOpen={showUserSwitcher}
					onClose={() => showUserSwitcher = false}
				/>

				<!-- Push Notification Settings Modal -->
				{#if showNotificationSettings}
					<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
						<div class="max-w-lg w-full mx-4">
							<div class="bg-white rounded-lg shadow-xl">
								<div class="flex items-center justify-between px-6 py-4 border-b border-gray-200">
									<h2 class="text-lg font-semibold text-gray-900">Notification Settings</h2>
									<button
										on:click={() => showNotificationSettings = false}
										class="text-gray-400 hover:text-gray-600 transition-colors"
									>
										<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
										</svg>
									</button>
								</div>
								<div class="p-6">
									<PushNotificationSettings />
								</div>
							</div>
						</div>
					</div>
				{/if}
				
				<!-- PWA Update Prompt -->
				{#if showUpdatePrompt}
					<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
						<div class="max-w-md w-full mx-4">
							<div class="bg-white rounded-lg shadow-xl">
								<div class="p-6">
									<div class="flex items-center justify-center mb-4">
										<div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
											<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
											</svg>
										</div>
									</div>
									<h3 class="text-lg font-semibold text-gray-900 text-center mb-2">Update Available</h3>
									<p class="text-gray-600 text-center mb-6">A new version of Aqura is available. Update now to get the latest features and improvements.</p>
									<div class="flex gap-3">
										<button
											on:click={dismissUpdate}
											class="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors"
										>
											Later
										</button>
										<button
											on:click={handlePWAUpdate}
											class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
										>
											Update Now
										</button>
									</div>
								</div>
							</div>
						</div>
					</div>
				{/if}
			</div>
			
			<!-- Taskbar -->
			<Taskbar 
				on:user-switch-request={handleUserSwitchRequest}
				on:notification-settings-request={handleNotificationSettingsRequest}
			/>
			
			<!-- Toast Notifications -->
			<ToastNotifications />
		{:else}
			<!-- Simple layout for login page or unauthenticated users -->
			<main class="simple-layout">
				<slot />
			</main>
		{/if}
	</div>
{/if}

<style>
	.loading-screen {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		font-family: 'Inter', 'Segoe UI', sans-serif;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(255, 255, 255, 0.3);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.loading-screen p {
		font-size: 1.1rem;
		opacity: 0.9;
	}

	.simple-layout {
		min-height: 100vh;
		min-height: 100dvh; /* Use dynamic viewport height for mobile */
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: auto; /* Allow scrolling in simple layout */
		-webkit-overflow-scrolling: touch; /* Smooth scrolling on iOS */
	}

	.app {
		min-height: 100vh;
		min-height: 100dvh; /* Use dynamic viewport height for mobile */
		background: #F9FAFB;
		background-attachment: fixed;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		overflow: auto; /* Allow scrolling on mobile */
		position: relative;
	}

	.app::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(107, 114, 128, 0.08) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(156, 163, 175, 0.06) 0%, transparent 50%),
			radial-gradient(circle at 50% 50%, rgba(209, 213, 219, 0.04) 0%, transparent 60%),
			radial-gradient(circle at 80% 20%, rgba(229, 231, 235, 0.08) 0%, transparent 40%),
			radial-gradient(circle at 20% 80%, rgba(243, 244, 246, 0.1) 0%, transparent 45%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236B7280' fill-opacity='0.02'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.desktop {
		height: calc(100vh - 56px); /* Fixed taskbar height */
		position: relative;
		overflow: hidden;
		z-index: 1;
		transition: margin-left 0.3s ease;
	}

	.main-content {
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
		z-index: 1;
	}

	/* RTL Support */
	.app.rtl {
		direction: rtl;
	}

	/* Global styles for window content */
	:global(.window-content) {
		font-family: inherit;
	}

	:global(.window-content h1) {
		font-size: 1.5rem;
		font-weight: 600;
		margin-bottom: 1rem;
		color: #1e293b;
	}

	:global(.window-content h2) {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 0.75rem;
		color: #334155;
	}

	:global(.window-content p) {
		color: #64748b;
		line-height: 1.6;
		margin-bottom: 1rem;
	}

	/* Button styles */
	:global(.btn) {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		border: 1px solid transparent;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		text-decoration: none;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	:global(.btn-primary) {
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		border-color: #15A34A;
	}

	:global(.btn-primary:hover) {
		background: linear-gradient(135deg, #166534 0%, #15A34A 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(21, 163, 74, 0.25);
	}

	:global(.btn-secondary) {
		background: #4F46E5;
		color: white;
		border-color: #4F46E5;
	}

	:global(.btn-secondary:hover) {
		background: #4338CA;
		border-color: #4338CA;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(79, 70, 229, 0.25);
	}

	:global(.btn-accent) {
		background: linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%);
		color: #0B1220;
		border-color: #F59E0B;
	}

	:global(.btn-accent:hover) {
		background: linear-gradient(135deg, #D97706 0%, #F59E0B 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.25);
	}

	:global(.btn-success) {
		background: #10B981;
		color: white;
		border-color: #10B981;
	}

	:global(.btn-success:hover) {
		background: #059669;
		border-color: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.25);
	}

	/* Form styles */
	:global(.form-group) {
		margin-bottom: 1rem;
	}

	:global(.form-label) {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.25rem;
	}

	:global(.form-input) {
		width: 100%;
		padding: 0.5rem 0.75rem;
		border: 1px solid #E5E7EB;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		background: #FFFFFF;
		color: #0B1220;
		transition: border-color 0.15s ease, box-shadow 0.15s ease;
	}

	:global(.form-input:focus) {
		outline: none;
		border-color: #4F46E5;
		box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
	}

	/* Table styles */
	:global(.table) {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	:global(.table th) {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 0.75rem;
		text-align: left;
		font-weight: 500;
		color: #374151;
	}

	:global(.table td) {
		border: 1px solid #e2e8f0;
		padding: 0.75rem;
		color: #6b7280;
	}

	:global(.table tbody tr:hover) {
		background: #f9fafb;
	}

	/* Utility classes */
	:global(.p-4) { padding: 1rem; }
	:global(.p-6) { padding: 1.5rem; }
	:global(.mb-4) { margin-bottom: 1rem; }
	:global(.text-center) { text-align: center; }
	:global(.text-xl) { font-size: 1.25rem; }
	:global(.font-bold) { font-weight: 700; }
	:global(.opacity-50) { opacity: 0.5; }
</style>
