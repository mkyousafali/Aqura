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
	import PWAInstallPrompt from '$lib/components/PWAInstallPrompt.svelte';
	import ToastNotifications from '$lib/components/ToastNotifications.svelte';
	import UserSwitcher from '$lib/components/UserSwitcher.svelte';
	import PushNotificationSettings from '$lib/components/PushNotificationSettings.svelte';
	
	// Enhanced imports for persistent auth and push notifications
	import { persistentAuthService, currentUser, isAuthenticated as persistentAuthState } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { pushNotificationProcessor } from '$lib/utils/pushNotificationProcessor';
	import { windowManager } from '$lib/stores/windowManager';
	import NotificationWindow from '$lib/components/admin/communication/NotificationWindow.svelte';

	// Initialize i18n system
	initI18n();

	// Command palette state
	let showCommandPalette = false;
	
	// User management states
	let showUserSwitcher = false;
	let showNotificationSettings = false;
	
	// Authentication state
	let isAuthenticated = false;
	let isLoading = true;
	let currentUserData = null;
	let unsubscribePersistent: (() => void) | undefined;
	let unsubscribeUser: (() => void) | undefined;
	
	// Debug flag to temporarily disable redirects
	let allowRedirects = false;

	onMount(async () => {
		try {
			// Initialize persistent authentication first
			await persistentAuthService.initializeAuth();
			
			// Add a small delay to allow auth state to stabilize
			await new Promise(resolve => setTimeout(resolve, 100));
			
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
				
				// Enable redirects after initial auth check is complete
				if (!allowRedirects) {
					setTimeout(() => {
						allowRedirects = true;
						console.log('🔐 Redirects enabled');
					}, 1500); // Allow 1.5 seconds for auth synchronization
				}
				
				// Only redirect if we're definitely not authenticated and redirects are allowed
				if (!authenticated && $page.url.pathname !== '/login' && allowRedirects) {
					console.log('🔐 Not authenticated, redirecting to login');
					setTimeout(() => {
						// Double-check we're still not authenticated before redirecting
						if (!isAuthenticated && $page.url.pathname !== '/login') {
							goto('/login');
						}
					}, 100);
				}
			});

			// Subscribe to current user changes
			unsubscribeUser = currentUser.subscribe(user => {
				currentUserData = user;
				console.log('Current user changed:', user);
			});

			// Legacy auth subscription disabled - using persistent auth only
			// unsubscribeLegacy = auth.subscribe(session => {
			//	console.log('Legacy auth state changed:', session ? 'authenticated' : 'not authenticated');
			// });

			// Initialize push notifications and real-time listeners for authenticated users
			if (isAuthenticated) {
				await initializeNotificationServices();
			}
		} catch (error) {
			console.error('Error initializing layout:', error);
			isLoading = false;
		}
	});
	
	onDestroy(() => {
		// Cleanup subscriptions on component destroy
		if (unsubscribePersistent) unsubscribePersistent();
		if (unsubscribeUser) unsubscribeUser();
		// unsubscribeLegacy not used anymore
	});

	async function initializeNotificationServices() {
		try {
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
	$: isLoginPage = $page.url.pathname === '/login';

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
{#if isLoading}
	<div class="loading-screen">
		<div class="loading-spinner"></div>
		<p>Loading...</p>
	</div>
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

<!-- PWA Install Prompt -->
<PWAInstallPrompt />

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
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.app {
		min-height: 100vh;
		background: #F9FAFB;
		background-attachment: fixed;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		overflow: hidden;
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
