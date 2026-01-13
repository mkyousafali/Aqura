<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { get } from 'svelte/store';
	import { initI18n, currentLocale, localeData } from '$lib/i18n';
	import { sidebar } from '$lib/stores/sidebar';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import '../../app.css';
	import WindowManager from '$lib/components/common/WindowManager.svelte';
	import Taskbar from '$lib/components/desktop-interface/common/Taskbar.svelte';
	import Sidebar from '$lib/components/desktop-interface/common/Sidebar.svelte';
	import CommandPalette from '$lib/components/desktop-interface/common/CommandPalette.svelte';
	import ToastNotifications from '$lib/components/common/ToastNotifications.svelte';
	import UserSwitcher from '$lib/components/common/UserSwitcher.svelte';
	
	// Enhanced imports for persistent auth
	import { persistentAuthService, currentUser, isAuthenticated as persistentAuthState } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { handleUserLogin } from '$lib/utils/mobileLoginHelper';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { initPWAInstall } from '$lib/stores/pwaInstall';
	// import { cacheManager } from '$lib/utils/cacheManager'; // Removed - cacheManager deleted
	import { startNotificationListener } from '$lib/stores/notifications';
	import NotificationWindow from '$lib/components/desktop-interface/master/communication/NotificationWindow.svelte';
	import { initPreload } from '$lib/utils/preload';
	
	// Import task badge debug utilities in development
	if (import.meta.env.DEV) {
		import('$lib/utils/taskBadgeDebug');
	}

	// Initialize i18n system
	initI18n();
	
	// Initialize data preloading for faster navigation
	initPreload();

	// Command palette state
	let showCommandPalette = false;
	
	// User management states
	let showUserSwitcher = false;
	let showNotificationSettings = false;
	
	// PWA update state
	let showUpdatePrompt = false;
	let needRefresh;
	let updateServiceWorker;
	
	// Popout mode detection
	let isPopoutMode = false;
	let popoutWindowId = '';
	let popoutWindowData = null;
	
	// Check if this is a popout instance using URL parameters
	$: {
		if (typeof window !== 'undefined') {
			const urlParams = new URLSearchParams(window.location.search);
			const popoutParam = urlParams.get('popout');
			const windowDataParam = urlParams.get('windowData');
			
			console.log('🪟 URL check - popout param:', popoutParam);
			console.log('🪟 URL check - windowData param:', windowDataParam ? 'present' : 'missing');
			
			isPopoutMode = !!popoutParam;
			popoutWindowId = popoutParam || '';
			
			// Try to get window data from URL parameter first
			if (windowDataParam) {
				try {
					popoutWindowData = JSON.parse(decodeURIComponent(windowDataParam));
					console.log('🪟 Window data from URL parameter:', popoutWindowData);
				} catch (e) {
					console.error('Failed to parse window data from URL:', e);
				}
			}
			
			// Debug logging
			if (isPopoutMode) {
				console.log('🪟 Popout mode detected:', popoutWindowId);
				if (!popoutWindowData) {
					console.log('🪟 No window data in URL, will wait for postMessage...');
				}
			}
		}
	}
	
	// Recreate the window in popout mode
	$: if (isPopoutMode && popoutWindowData) {
		console.log('🪟 Reactive statement triggered - isAuthenticated:', isAuthenticated);
		console.log('🪟 popoutWindowData:', popoutWindowData);
		
		if (isAuthenticated) {
			console.log('🔐 Authentication confirmed in popout:', isAuthenticated);
			console.log('🪟 Setting up popout window...');
			setupPopoutWindow();
		} else {
			console.log('🔐 Authentication pending in popout mode...');
			console.log('🔐 Auth state:', isAuthenticated);
			// For popout windows, try to setup anyway after a delay
			setTimeout(() => {
				if (!isAuthenticated) {
					console.log('🔐 Force setting up popout window (authentication timeout)');
					setupPopoutWindow();
				}
			}, 2000);
		}
	}
	
	// Handle authentication state changes for popout
	$: if (isPopoutMode && popoutWindowData && isAuthenticated) {
		console.log('🔐 Authentication state changed in popout, setting up window...');
		// Check if window hasn't been created yet
		if (!windowManager.getWindow(popoutWindowData.id)) {
			console.log('🪟 Window not found, creating...');
			setupPopoutWindow();
		} else {
			console.log('🪟 Window already exists');
		}
	}
	
	async function setupPopoutWindow() {
		if (!popoutWindowData) {
			console.log('🪟 setupPopoutWindow called but no window data available');
			return;
		}
		
		console.log('🪟 Setting up popout window:', popoutWindowData.title);
		console.log('🪟 Window data:', popoutWindowData);
		
		// Dynamically import the component based on component name
		let component;
		const componentName = popoutWindowData.componentName || popoutWindowData.component?.name;
		
		console.log('🪟 Loading component:', componentName);
		
		try {
			// Map component names to imports
			switch (componentName) {
				case 'VendorMaster':
					const { default: VendorMaster } = await import('$lib/components/desktop-interface/master/VendorMaster.svelte');
					component = VendorMaster;
					break;
				case 'BranchMaster':
					const { default: BranchMaster } = await import('$lib/components/desktop-interface/master/BranchMaster.svelte');
					component = BranchMaster;
					break;
				case 'StartReceiving':
					const { default: StartReceiving } = await import('$lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte');
					component = StartReceiving;
					break;
				case 'Receiving':
					const { default: Receiving } = await import('$lib/components/desktop-interface/master/operations/Receiving.svelte');
					component = Receiving;
					break;
				case 'ReceivingRecords':
					const { default: ReceivingRecords } = await import('$lib/components/desktop-interface/master/operations/receiving/ReceivingRecords.svelte');
					component = ReceivingRecords;
					break;
				case 'ReceivingTasksDashboard':
					const { default: ReceivingTasksDashboard } = await import('$lib/components/desktop-interface/master/operations/receiving/ReceivingTasksDashboard.svelte');
					component = ReceivingTasksDashboard;
					break;
				case 'ReceivingDataWindow':
					const { default: ReceivingDataWindow } = await import('$lib/components/desktop-interface/master/operations/receiving/ReceivingDataWindow.svelte');
					component = ReceivingDataWindow;
					break;
				case 'PaymentManager':
					const { default: PaymentManager } = await import('$lib/components/desktop-interface/master/finance/PaymentManager.svelte');
					component = PaymentManager;
					break;
				case 'MonthDetails':
					console.log('🪟 Loading MonthDetails component...');
					const { default: MonthDetails } = await import('$lib/components/desktop-interface/master/finance/MonthDetails.svelte');
					component = MonthDetails;
					console.log('🪟 MonthDetails component loaded:', component);
					break;
				case 'TaskMaster':
					const { default: TaskMaster } = await import('$lib/components/desktop-interface/master/TaskMaster.svelte');
					component = TaskMaster;
					break;
				case 'HRMaster':
					const { default: HRMaster } = await import('$lib/components/desktop-interface/master/HRMaster.svelte');
					component = HRMaster;
					break;
				case 'OperationsMaster':
					const { default: OperationsMaster } = await import('$lib/components/desktop-interface/master/OperationsMaster.svelte');
					component = OperationsMaster;
					break;
				case 'FinanceMaster':
					const { default: FinanceMaster } = await import('$lib/components/desktop-interface/master/FinanceMaster.svelte');
					component = FinanceMaster;
					break;
				case 'UserManagement':
					const { default: UserManagement } = await import('$lib/components/desktop-interface/settings/UserManagement.svelte');
					component = UserManagement;
					break;
				case 'CommunicationCenter':
					const { default: CommunicationCenter } = await import('$lib/components/desktop-interface/master/CommunicationCenter.svelte');
					component = CommunicationCenter;
					break;
				case 'Settings':
					const { default: Settings } = await import('$lib/components/desktop-interface/settings/Settings.svelte');
					component = Settings;
					break;
				case 'UploadVendor':
					const { default: UploadVendor } = await import('$lib/components/desktop-interface/master/vendor/UploadVendor.svelte');
					component = UploadVendor;
					break;
				case 'ManageVendor':
					const { default: ManageVendor } = await import('$lib/components/desktop-interface/master/vendor/ManageVendor.svelte');
					component = ManageVendor;
					break;
				case 'EditUser':
					const { default: EditUser } = await import('$lib/components/desktop-interface/settings/user/EditUser.svelte');
					component = EditUser;
					break;
				case 'NotificationCenter':
					const { default: NotificationCenter } = await import('$lib/components/desktop-interface/master/communication/NotificationCenter.svelte');
					component = NotificationCenter;
					break;
			case 'ProductSelectorWindow':
				const { default: ProductSelectorWindow } = await import('$lib/components/desktop-interface/admin-customer-app/offers/ProductSelectorWindow.svelte');
				component = ProductSelectorWindow;
				break;
			case 'FlyerMasterDashboard':
				const { default: FlyerMasterDashboard } = await import('$lib/components/desktop-interface/marketing/flyer/FlyerMasterDashboard.svelte');
				component = FlyerMasterDashboard;
				break;
			default:
				console.error('🪟 Unknown component name:', componentName);
				return;
		}			console.log('🪟 Component loaded successfully:', component);
			
		} catch (error) {
			console.error('🪟 Failed to load component:', componentName, error);
			return;
		}
		
		// Recreate the window in the window manager with the loaded component
		const windowConfig = {
			id: popoutWindowData.id,
			title: popoutWindowData.title,
			component: component,
			props: popoutWindowData.props || {},
			icon: popoutWindowData.icon,
			size: popoutWindowData.size,
			position: { x: 0, y: 0 },
			resizable: false,
			minimizable: false,
			maximizable: false,
			closable: false,
			popOutEnabled: false,
			state: 'normal',
			isActive: true
		};
		
		console.log('🪟 Creating window with config:', windowConfig);
		const newWindowId = windowManager.openWindow(windowConfig);
		console.log('🪟 Window created with ID:', newWindowId);
		
		windowManager.activateWindow(popoutWindowData.id);
		console.log('🪟 Window activated:', popoutWindowData.id);
		
		// Signal to parent window that loading is complete
		if (window.parent && window.parent !== window) {
			console.log('🪟 Signaling parent window that loading is complete');
			try {
				window.parent.postMessage({
					type: 'popout-loading-complete',
					windowId: popoutWindowData.id
				}, '*');
				console.log('🪟 PostMessage sent successfully');
			} catch (error) {
				console.error('🪟 Failed to send postMessage:', error);
			}
		} else {
			console.log('🪟 Not in iframe context, parent:', window.parent === window ? 'same as window' : 'different');
		}
	}
	
	// Handle window open requests from pop-out windows
	function handleCrossWindowMessages() {
		if (typeof window !== 'undefined') {
			window.addEventListener('message', (event) => {
				// Only handle messages from our own domain
				if (event.origin !== window.location.origin) return;
				
				console.log('🪟 Parent received message:', event.data);
				
				if (event.data && event.data.type === 'open-window-from-popout') {
					const { windowConfig } = event.data;
					console.log('🪟 Opening window from popout:', windowConfig);
					
					// Open the window in the main application and also pop it out
					const newWindowId = windowManager.openWindow(windowConfig);
					
					// Immediately pop out the new window so it appears as a separate browser window
					setTimeout(() => {
						windowManager.popOutWindow(newWindowId);
					}, 100);
				} else if (event.data && event.data.type === 'popout-ready') {
					const { windowId } = event.data;
					console.log('🪟 Popout iframe ready, sending window data for:', windowId);
					
					// Find the window and send its data to the iframe
					const targetWindow = windowManager.getWindow(windowId);
					console.log('🪟 Found target window:', targetWindow);
					
					if (targetWindow) {
						const windowData = {
							id: targetWindow.id,
							title: targetWindow.title,
							componentName: targetWindow.component?.name || 'UnknownComponent',
							props: targetWindow.props || {},
							icon: targetWindow.icon,
							size: targetWindow.size
						};
						
						console.log('🪟 Sending window data to iframe:', windowData);
						
						event.source.postMessage({
							type: 'popout-window-data',
							windowData: windowData
						}, event.origin);
					} else {
						console.log('🪟 No window found in parent for ID:', windowId);
						console.log('🪟 Available windows:', get(windowManager.windowList));
					}
				}
			});
		}
	}

	// Initialize cross-window message handling
	onMount(() => {
		handleCrossWindowMessages();
		
		// Handle popout window setup
		if (isPopoutMode) {
			console.log('🪟 Setting up popout for window:', popoutWindowId);
			
			// If we already have window data from URL, set up immediately
			if (popoutWindowData) {
				console.log('🪟 Window data available from URL, setting up...');
				if (isAuthenticated) {
					setupPopoutWindow();
				}
			} else {
				// Fall back to postMessage approach
				console.log('🪟 Setting up postMessage listener for window:', popoutWindowId);
				
				const handleMessage = (event) => {
					// Verify origin for security
					if (event.origin !== window.location.origin) return;
					
					console.log('🪟 Received message in popout:', event.data);
					
					if (event.data && event.data.type === 'popout-window-data') {
						console.log('🪟 Received window data:', event.data.windowData);
						popoutWindowData = event.data.windowData;
						
						// Set up the window once we have the data
						if (isAuthenticated) {
							console.log('🪟 Setting up window immediately (authenticated)');
							setupPopoutWindow();
						} else {
							console.log('🪟 Waiting for authentication...');
						}
					}
				};
				
				window.addEventListener('message', handleMessage);
				
				// Send ready message to parent to request window data
				console.log('🪟 Sending popout-ready message to parent for window:', popoutWindowId);
				window.parent.postMessage({
					type: 'popout-ready',
					windowId: popoutWindowId
				}, window.location.origin);
			}
		}
		
		// Expose window manager proxy for popout iframes
		if (typeof window !== 'undefined' && popoutWindowId) {
			window.windowManagerProxy = {
				openWindow: (config) => {
					// Send message to parent window to open a new window
					if (window.parent && window.parent !== window) {
						window.parent.postMessage({
							type: 'open-window-from-popout',
							windowConfig: config
						}, window.location.origin);
					}
				}
			};
		}
	});
	
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
	
	// No automatic cache clearing - manual only
	async function setupServiceWorkers() {
		console.log('🔧 Setting up service workers without automatic cache clearing...');
		
		if ('serviceWorker' in navigator) {
			try {
				// Get all existing registrations
				const registrations = await navigator.serviceWorker.getRegistrations();
				
				if (registrations.length > 0) {
					console.log(`🔍 Found ${registrations.length} existing service worker(s)`);
					
					let preservedCount = 0;
					
					// Preserve all service workers unless they're clearly problematic
					for (let registration of registrations) {
						const scriptURL = registration.active?.scriptURL || registration.waiting?.scriptURL || registration.installing?.scriptURL || '';
						const scope = registration.scope;
						
						console.log(`✅ Preserving SW: ${scope}`);
						preservedCount++;
					}
					
					console.log(`✅ Setup completed: ${preservedCount} service workers preserved`);
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
	
	// Initialization guards
	let notificationServicesInitialized = false;
	let isInitializingNotifications = false;
	let initializationTimeout: ReturnType<typeof setTimeout> | null = null;

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

			// Detect app refresh/reopen - no automatic cache clearing
			// Just setup body classes
			
			// Add service worker message listener for cache clearing and storage requests
			if ('serviceWorker' in navigator) {
				navigator.serviceWorker.addEventListener('message', (event) => {
					if (event.data && event.data.type === 'CLEAR_STORAGE_EXCEPT_AUTH') {
						clearStorageExceptAuth();
					} else if (event.data && event.data.type === 'GET_STORAGE_VALUE') {
						// Handle storage value requests from service worker
						const key = event.data.key;
						const value = localStorage.getItem(key);
						
						// Respond back through the message port
						if (event.ports && event.ports[0]) {
							event.ports[0].postMessage({ value });
						}
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
			
			// Check interface preference and redirect if needed
			if (currentAuthState && currentUserState) {
				const userId = currentUserState.id;
				const currentPath = $page.url.pathname;
				
				// Check if user has mobile preference and isn't already on mobile routes (exclude cashier)
				if (interfacePreferenceService.isMobilePreferred(userId) && 
					!currentPath.startsWith('/mobile-interface') && 
					!currentPath.startsWith('/mobile-interface/login') &&
					!currentPath.startsWith('/cashier-interface')) {
					
					console.log('🔐 User has mobile preference, redirecting to mobile interface');
					goto('/mobile-interface');
					return;
				}
				
				// Check if user doesn't have mobile preference but is on mobile routes (exclude cashier)
				if (!interfacePreferenceService.isMobilePreferred(userId) && 
					currentPath.startsWith('/mobile-interface') &&
					!currentPath.startsWith('/cashier-interface')) {
					
					console.log('🔐 User does not have mobile preference, redirecting to desktop interface');
					goto('/');
					return;
				}
			}
			
			// Set initial state based on current auth status
			isAuthenticated = currentAuthState;
			currentUserData = currentUserState;
			
			// Only redirect if necessary and avoid loops
			const isCashier = $page.url.pathname.startsWith('/cashier-interface');
			if (currentAuthState === false && $page.url.pathname !== '/login' && $page.url.pathname !== '/mobile-interface/login' && !isCashier) {
				console.log('🔐 Initial check: Not authenticated, will redirect to login');
			} else if (currentAuthState === true && ($page.url.pathname === '/login' || $page.url.pathname === '/mobile-interface/login') && !isCashier) {
				console.log('🔐 Initial check: Already authenticated, will redirect to appropriate dashboard');
				
				// Redirect to appropriate interface based on preference
				const redirectRoute = interfacePreferenceService.getAppropriateRoute(currentUserState?.id);
				goto(redirectRoute);
				return;
			}
			
			// Add a small delay to allow auth state to stabilize
			await new Promise(resolve => setTimeout(resolve, 100));
			
			// Set loading to false after initial auth check (fallback)
			if (isLoading) {
				console.log('🔐 Setting initial loading state to false');
				isLoading = false;
			}
			
			// No automatic cleanup or cache clearing - only setup service workers when needed
			if (!isAuthenticated) {
				console.log('🔧 User not authenticated, standard service worker setup...');
				setupServiceWorkers().then(() => {
					console.log('🎉 Service worker setup completed');
				}).catch(error => {
					console.warn('⚠️ Service worker setup failed (non-blocking):', error);
				});
			} else {
				console.log('🔔 User authenticated, service workers preserved for push notifications...');
			}
			
			// Initialize notification services if user is authenticated
			if (isAuthenticated && !notificationServicesInitialized && !isInitializingNotifications) {
				console.log('🔔 User is authenticated, initializing notification services...');
				// Debounce initialization to prevent rapid calls
				if (initializationTimeout) {
					clearTimeout(initializationTimeout);
				}
				initializationTimeout = setTimeout(() => {
					initializeNotificationServices().catch(error => {
						console.warn('⚠️ Notification initialization failed:', error);
					});
				}, 500); // 500ms debounce
			}
			
			// Initialize PWA install detection
			initPWAInstall();
			
			// Initialize PWA only in production and when enabled
			if (import.meta.env.PROD && import.meta.env.VITE_PWA_ENABLED !== 'false') {
				try {
					console.log('🔧 Initializing PWA in production mode...');
					
					// Manual service worker registration for our custom SW
					if ('serviceWorker' in navigator) {
						// Register our unified service worker (sw.js now contains our enhanced features)
						let registration;
						try {
							registration = await navigator.serviceWorker.register('/sw.js', {
								scope: '/',
								updateViaCache: 'none'
							});
							console.log('✅ Service Worker registered successfully:', registration);
						} catch (swError) {
							console.error('❌ Service Worker registration failed:', swError);
							return; // Exit if registration fails
						}
						
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
							// Use same fallback strategy for updates
							let newRegistration;
							try {
								newRegistration = await navigator.serviceWorker.register('/sw.js', {
									scope: '/',
									updateViaCache: 'none'
								});
							} catch (swError) {
								console.warn('⚠️ Update: Service worker registration failed, retrying...');
								newRegistration = await navigator.serviceWorker.register('/sw.js', {
									scope: '/',
									updateViaCache: 'none'
								});
							}
							
							if (newRegistration.waiting) {
								newRegistration.waiting.postMessage({ type: 'SKIP_WAITING' });
							}
							
							showUpdatePrompt = false;
						};
						
						// Force check for updates every 30 seconds
						const checkForUpdates = async () => {
							if (registration) {
								console.log('🔍 Checking for service worker updates...');
								try {
									await registration.update();
								} catch (error) {
									console.warn('⚠️ Update check failed:', error);
								}
							}
						};
						
						// Check for updates immediately and then every 30 seconds
						checkForUpdates();
						setInterval(checkForUpdates, 30000);
						
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
				// Also exclude customer and cashier routes from employee authentication checks
				const isCustomerRoute = $page.url.pathname.startsWith('/customer-interface');
				const isCashierRoute = $page.url.pathname.startsWith('/cashier-interface');
				if (!authenticated && $page.url.pathname !== '/login' && !isCustomerRoute && !isCashierRoute) {
					console.log('🔐 Not authenticated, redirecting to login');
					goto('/login', { replaceState: true });
				}
				
				// Redirect authenticated users away from login page (except cashier)
				if (authenticated && $page.url.pathname === '/login' && !isCashierRoute) {
					console.log('🔐 Already authenticated, redirecting to dashboard');
					goto('/', { replaceState: true });
				}
			});

			// Subscribe to current user changes
			unsubscribeUser = currentUser.subscribe(user => {
				const previousUser = currentUserData;
				currentUserData = user;
				console.log('Current user changed:', user);
				
				// Check if this is a new login (user was null/undefined and now has a value)
				if (!previousUser && user && user.id) {
					console.log('🔐 New user login detected, checking mobile push notification prompt...');
					// Trigger mobile push notification prompt for new logins
					handleUserLogin(user.id, true).catch(error => {
						console.error('❌ Error handling user login for push notifications:', error);
					});
				}
			});

			// Fallback timeout to prevent infinite loading
			const loadingTimeout = setTimeout(() => {
				if (isLoading) {
					console.warn('⚠️ Loading timeout reached, forcing loading state to false');
					isLoading = false;
					
					// If still not authenticated after timeout, redirect to login (exclude mobile, customer, and cashier routes)
					const isCustomerRouteTimeout = $page.url.pathname.startsWith('/customer-interface');
					const isCashierRouteTimeout = $page.url.pathname.startsWith('/cashier-interface');
					if (!isAuthenticated && $page.url.pathname !== '/login' && !isMobileRoute && !isMobileLoginRoute && !isCustomerRouteTimeout && !isCashierRouteTimeout) {
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
			
			// Only redirect to login if we're not already there and not on customer routes
			const isCustomerRouteError = $page.url.pathname.startsWith('/customer-interface');
			if ($page.url.pathname !== '/login' && !isCustomerRouteError) {
				console.log('🔐 Initialization failed, redirecting to login');
				goto('/login', { replaceState: true });
			}
		}
		
		// No automatic cache clearing on visibility changes or page unload
		// Manual cache clearing only through user settings
		
		// Cleanup function
		return () => {
			// No event listeners to remove since we don't auto-clear caches
		};
	});
	
	onDestroy(() => {
		// Cleanup subscriptions on component destroy
		if (unsubscribePersistent) unsubscribePersistent();
		if (unsubscribeUser) unsubscribeUser();
		
		// Clean up initialization timeout
		if (initializationTimeout) {
			clearTimeout(initializationTimeout);
		}
		
		// Remove desktop-mode class from body
		if (typeof document !== 'undefined') {
			document.body.classList.remove('desktop-mode');
		}
	});

	async function initializeNotificationServices() {
		// Prevent multiple simultaneous initializations
		if (isInitializingNotifications) {
			console.warn('⚠️ Notification services initialization already in progress');
			return;
		}
		
		if (notificationServicesInitialized) {
			console.log('✅ Notification services already initialized');
			return;
		}
		
		isInitializingNotifications = true;
		
		try {
			// Mark as initialized
			notificationServicesInitialized = true;
			console.log('✅ Notification services initialization skipped (push removed)');
			
		} catch (error) {
			console.error('❌ Error initializing notification services:', error);
		} finally {
			isInitializingNotifications = false;
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
		
		openWindow({
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
	// No automatic cache clearing on app startup
	// Manual cache clearing only through user settings
	
	// Clear storage except authentication data (for manual clearing only)
	function clearStorageExceptAuth() {
		console.log('🧹 Clearing storage except authentication data...');
		
		try {
			// Get authentication-related keys to preserve
			const authKeys = [
				'aqura-device-session',
				'aqura-device-id',
				// Push notification related keys - CRITICAL
				'push-subscription-endpoint',
				'push-subscription-p256dh', 
				'push-subscription-auth',
				'notification-permission-granted'
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
	$: isMobileRoute = $page.url.pathname.startsWith('/mobile-interface');
	$: isMobileLoginRoute = $page.url.pathname.startsWith('/mobile-interface/login');
	$: isCashierRoute = $page.url.pathname.startsWith('/cashier-interface');

	// Update body class when authentication or page state changes (exclude mobile and cashier routes)
	$: if (typeof document !== 'undefined') {
		if (isAuthenticated && !isLoginPage && !isMobileRoute && !isMobileLoginRoute && !isCashierRoute) {
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
{#if isLoading && !isMobileRoute && !isMobileLoginRoute && !isCashierRoute}
	<div class="loading-screen">
		<div class="loading-spinner"></div>
		<p>Loading...</p>
	</div>
{:else if isMobileRoute || isMobileLoginRoute || isCashierRoute}
	<!-- Mobile and cashier routes get no desktop layout - completely independent -->
	<slot />
{:else}
	<div class="app {directionClass}" dir={$localeData?.direction || 'ltr'}>
		<!-- Show full UI only if authenticated and not on login page -->
		{#if isAuthenticated && !isLoginPage}
			{#if isPopoutMode}
				<!-- Popout mode - show only the specific window without sidebar/taskbar -->
				<div class="popout-container">
					<WindowManager popoutOnly={popoutWindowId} />
				</div>
			{:else}
				<!-- Normal mode - show full UI -->
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
						</div>
					</div>
				</div>
			{/if}				<!-- PWA Update Prompt -->
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
			{/if}
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
		width: 100%;
		height: 100%;
		display: flex;
		align-items: stretch;
		justify-content: stretch;
		position: relative;
		z-index: 1;
		padding: 0;
		margin: 0;
	}

	/* Popout container for iframe mode */
	.popout-container {
		width: 100vw;
		height: 100vh;
		overflow: hidden;
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

