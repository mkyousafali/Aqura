<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authService } from '$lib/utils/persistentAuth';
	
	let debugInfo = {
		environment: '',
		vapidKey: '',
		supabaseUrl: '',
		serviceWorkerSupport: false,
		pushSupport: false,
		notificationPermission: '',
		serviceWorkerRegistrations: [],
		currentUrl: '',
		https: false,
		errors: []
	};
	
	onMount(async () => {
		// Check if user is authenticated
		const user = authService.getCurrentUser();
		if (!user) {
			goto('/login');
			return;
		}
		
		try {
			// Environment info
			debugInfo.environment = import.meta.env.MODE;
			debugInfo.vapidKey = import.meta.env.VITE_VAPID_PUBLIC_KEY ? 
				`${import.meta.env.VITE_VAPID_PUBLIC_KEY.substring(0, 20)}...` : 'NOT SET';
			debugInfo.supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'NOT SET';
			debugInfo.currentUrl = window.location.href;
			debugInfo.https = window.location.protocol === 'https:';
			
			// Service Worker support
			debugInfo.serviceWorkerSupport = 'serviceWorker' in navigator;
			debugInfo.pushSupport = 'PushManager' in window;
			
			// Notification permission
			if ('Notification' in window) {
				debugInfo.notificationPermission = Notification.permission;
			}
			
			// Service Worker registrations
			if ('serviceWorker' in navigator) {
				try {
					const registrations = await navigator.serviceWorker.getRegistrations();
					debugInfo.serviceWorkerRegistrations = registrations.map(reg => ({
						scope: reg.scope,
						state: reg.active?.state || 'inactive',
						scriptURL: reg.active?.scriptURL || 'unknown'
					}));
				} catch (error) {
					debugInfo.errors.push(`Service Worker check error: ${error.message}`);
				}
			}
			
			// Test push notification setup
			if (debugInfo.serviceWorkerSupport && debugInfo.pushSupport) {
				try {
					// Try to get existing subscription
					const registration = await navigator.serviceWorker.ready;
					const subscription = await registration.pushManager.getSubscription();
					
					if (subscription) {
						debugInfo.pushSubscriptionExists = true;
						debugInfo.pushEndpoint = subscription.endpoint;
					} else {
						debugInfo.pushSubscriptionExists = false;
					}
				} catch (error) {
					debugInfo.errors.push(`Push subscription check error: ${error.message}`);
				}
			}
			
		} catch (error) {
			debugInfo.errors.push(`General error: ${error.message}`);
		}
		
		// Trigger reactive update
		debugInfo = debugInfo;
	});
	
	async function testPushNotification() {
		try {
			const { PushNotificationManager } = await import('$lib/utils/pushNotifications');
			const pushManager = new PushNotificationManager();
			
			const result = await pushManager.initialize();
			if (result) {
				debugInfo.errors.push('✅ Push notification test: SUCCESS');
			} else {
				debugInfo.errors.push('❌ Push notification test: FAILED - initialization returned null');
			}
		} catch (error) {
			debugInfo.errors.push(`❌ Push notification test error: ${error.message}`);
		}
		debugInfo = debugInfo;
	}
</script>

<svelte:head>
	<title>Debug Info - Push Notifications</title>
</svelte:head>

<div class="debug-container">
	<h1>🔧 Push Notification Debug Information</h1>
	
	<div class="debug-section">
		<h2>Environment</h2>
		<div class="debug-item">
			<strong>Mode:</strong> {debugInfo.environment}
		</div>
		<div class="debug-item">
			<strong>Current URL:</strong> {debugInfo.currentUrl}
		</div>
		<div class="debug-item">
			<strong>HTTPS:</strong> {debugInfo.https ? '✅ Yes' : '❌ No'}
		</div>
		<div class="debug-item">
			<strong>VAPID Key:</strong> {debugInfo.vapidKey}
		</div>
		<div class="debug-item">
			<strong>Supabase URL:</strong> {debugInfo.supabaseUrl}
		</div>
	</div>
	
	<div class="debug-section">
		<h2>Browser Support</h2>
		<div class="debug-item">
			<strong>Service Worker Support:</strong> {debugInfo.serviceWorkerSupport ? '✅ Yes' : '❌ No'}
		</div>
		<div class="debug-item">
			<strong>Push Manager Support:</strong> {debugInfo.pushSupport ? '✅ Yes' : '❌ No'}
		</div>
		<div class="debug-item">
			<strong>Notification Permission:</strong> {debugInfo.notificationPermission}
		</div>
	</div>
	
	{#if debugInfo.serviceWorkerRegistrations.length > 0}
		<div class="debug-section">
			<h2>Service Worker Registrations</h2>
			{#each debugInfo.serviceWorkerRegistrations as registration}
				<div class="debug-item">
					<strong>Scope:</strong> {registration.scope}<br>
					<strong>State:</strong> {registration.state}<br>
					<strong>Script:</strong> {registration.scriptURL}
				</div>
			{/each}
		</div>
	{/if}
	
	{#if debugInfo.pushSubscriptionExists !== undefined}
		<div class="debug-section">
			<h2>Push Subscription</h2>
			<div class="debug-item">
				<strong>Exists:</strong> {debugInfo.pushSubscriptionExists ? '✅ Yes' : '❌ No'}
			</div>
			{#if debugInfo.pushEndpoint}
				<div class="debug-item">
					<strong>Endpoint:</strong> {debugInfo.pushEndpoint.substring(0, 60)}...
				</div>
			{/if}
		</div>
	{/if}
	
	<div class="debug-section">
		<h2>Test Functions</h2>
		<button class="test-button" on:click={testPushNotification}>
			🧪 Test Push Notification Setup
		</button>
	</div>
	
	{#if debugInfo.errors.length > 0}
		<div class="debug-section">
			<h2>Logs & Errors</h2>
			{#each debugInfo.errors as error}
				<div class="debug-error">{error}</div>
			{/each}
		</div>
	{/if}
	
	<div class="debug-section">
		<h2>Recommendations</h2>
		<div class="recommendations">
			{#if !debugInfo.https && debugInfo.environment === 'production'}
				<div class="recommendation error">❌ HTTPS is required for push notifications in production</div>
			{/if}
			
			{#if debugInfo.vapidKey === 'NOT SET' || debugInfo.vapidKey.includes('your-vapid')}
				<div class="recommendation error">❌ VAPID public key not properly configured</div>
			{/if}
			
			{#if debugInfo.notificationPermission === 'denied'}
				<div class="recommendation error">❌ Notification permission denied by user</div>
			{/if}
			
			{#if debugInfo.notificationPermission === 'default'}
				<div class="recommendation warning">⚠️ Notification permission not requested yet</div>
			{/if}
			
			{#if !debugInfo.serviceWorkerSupport}
				<div class="recommendation error">❌ Browser doesn't support Service Workers</div>
			{/if}
			
			{#if !debugInfo.pushSupport}
				<div class="recommendation error">❌ Browser doesn't support Push Manager</div>
			{/if}
			
			{#if debugInfo.https && debugInfo.serviceWorkerSupport && debugInfo.pushSupport && debugInfo.vapidKey !== 'NOT SET'}
				<div class="recommendation success">✅ Basic requirements met for push notifications</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.debug-container {
		max-width: 800px;
		margin: 0 auto;
		padding: 20px;
		font-family: monospace;
		background: #1a1a1a;
		color: #ffffff;
		min-height: 100vh;
	}
	
	h1 {
		color: #4ade80;
		border-bottom: 2px solid #4ade80;
		padding-bottom: 10px;
	}
	
	h2 {
		color: #60a5fa;
		margin-top: 30px;
		margin-bottom: 15px;
	}
	
	.debug-section {
		background: #2a2a2a;
		padding: 15px;
		margin: 15px 0;
		border-radius: 8px;
		border-left: 4px solid #60a5fa;
	}
	
	.debug-item {
		margin: 10px 0;
		padding: 8px;
		background: #3a3a3a;
		border-radius: 4px;
	}
	
	.debug-error {
		margin: 5px 0;
		padding: 8px;
		background: #451a1a;
		border-left: 4px solid #ef4444;
		border-radius: 4px;
	}
	
	.test-button {
		background: #4ade80;
		color: #000;
		border: none;
		padding: 12px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: bold;
		font-size: 14px;
	}
	
	.test-button:hover {
		background: #22c55e;
	}
	
	.recommendation {
		margin: 8px 0;
		padding: 10px;
		border-radius: 6px;
		font-weight: bold;
	}
	
	.recommendation.success {
		background: #1a4a1a;
		border-left: 4px solid #4ade80;
	}
	
	.recommendation.warning {
		background: #4a4a1a;
		border-left: 4px solid #facc15;
	}
	
	.recommendation.error {
		background: #4a1a1a;
		border-left: 4px solid #ef4444;
	}
</style>