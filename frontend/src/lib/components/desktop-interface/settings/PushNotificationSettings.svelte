<script lang="ts">
	import { onMount } from 'svelte';
	import { notificationService } from '$lib/utils/notificationManagement';

	// State
	let isSupported = false;
	let permission: NotificationPermission = 'default';
	let isRegistered = false;
	let isLoading = false;
	let error = '';
	let success = '';

	onMount(async () => {
		checkSupport();
		checkPermission();
		await checkRegistrationStatus();
	});

	function checkSupport() {
		isSupported = notificationService.isPushNotificationSupported();
	}

	function checkPermission() {
		permission = notificationService.getPushNotificationPermission();
	}

	async function checkRegistrationStatus() {
		// This would typically check if the device is registered with the backend
		// For now, we'll use localStorage to check
		isRegistered = localStorage.getItem('aqura-device-id') !== null;
	}

	async function requestPermission() {
		try {
			isLoading = true;
			error = '';
			success = '';

			const result = await notificationService.requestPushNotificationPermission();
			permission = result;

			if (result === 'granted') {
				success = 'Notification permission granted!';
				await registerForNotifications();
			} else {
				error = 'Notification permission denied. You can enable it in browser settings.';
			}
		} catch (err) {
			console.error('Error requesting permission:', err);
			error = 'Failed to request notification permission';
		} finally {
			isLoading = false;
		}
	}

	async function registerForNotifications() {
		try {
			isLoading = true;
			error = '';
			success = '';

			const result = await notificationService.registerForPushNotifications();
			
			if (result) {
				isRegistered = true;
				success = 'Successfully registered for push notifications!';
				
				// Start real-time listener
				// 🔴 DISABLED: Real-time subscriptions - causing performance issues
				console.warn("⚠️ Real-time notifications disabled temporarily");
				// await notificationService.startRealtimeNotificationListener();
			} else {
				error = 'Failed to register for push notifications';
			}
		} catch (err) {
			console.error('Error registering for notifications:', err);
			error = 'Failed to register for push notifications';
		} finally {
			isLoading = false;
		}
	}

	async function unregisterFromNotifications() {
		try {
			isLoading = true;
			error = '';
			success = '';

			await notificationService.unregisterFromPushNotifications();
			isRegistered = false;
			success = 'Successfully unregistered from push notifications';
		} catch (err) {
			console.error('Error unregistering from notifications:', err);
			error = 'Failed to unregister from push notifications';
		} finally {
			isLoading = false;
		}
	}

	async function sendTestNotification() {
		try {
			isLoading = true;
			error = '';
			success = '';

			await notificationService.sendTestNotification();
			success = 'Test notification sent!';
		} catch (err) {
			console.error('Error sending test notification:', err);
			error = 'Failed to send test notification';
		} finally {
			isLoading = false;
		}
	}

	function getPermissionText(perm: NotificationPermission): string {
		switch (perm) {
			case 'granted':
				return 'Granted';
			case 'denied':
				return 'Denied';
			case 'default':
				return 'Not set';
			default:
				return 'Unknown';
		}
	}

	function getPermissionColor(perm: NotificationPermission): string {
		switch (perm) {
			case 'granted':
				return 'text-green-600 bg-green-100';
			case 'denied':
				return 'text-red-600 bg-red-100';
			case 'default':
				return 'text-yellow-600 bg-yellow-100';
			default:
				return 'text-gray-600 bg-gray-100';
		}
	}
</script>

<div class="bg-white rounded-lg shadow-lg p-6">
	<div class="flex items-center mb-6">
		<div class="p-2 bg-blue-100 rounded-lg mr-3">
			<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z" />
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
			</svg>
		</div>
		<div>
			<h2 class="text-xl font-semibold text-gray-900">Push Notifications</h2>
			<p class="text-sm text-gray-600">Manage your notification preferences</p>
		</div>
	</div>

	<!-- Status Messages -->
	{#if error}
		<div class="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded-lg">
			<div class="flex items-center">
				<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
				</svg>
				{error}
			</div>
		</div>
	{/if}

	{#if success}
		<div class="mb-4 p-3 bg-green-100 border border-green-400 text-green-700 rounded-lg">
			<div class="flex items-center">
				<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
				</svg>
				{success}
			</div>
		</div>
	{/if}

	<!-- Support Status -->
	<div class="space-y-4">
		<div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
			<div class="flex items-center">
				<div class={`w-3 h-3 rounded-full mr-3 ${isSupported ? 'bg-green-500' : 'bg-red-500'}`}></div>
				<div>
					<p class="font-medium text-gray-900">Browser Support</p>
					<p class="text-sm text-gray-600">
						{isSupported ? 'Push notifications are supported' : 'Push notifications not supported'}
					</p>
				</div>
			</div>
			<span class={`px-3 py-1 rounded-full text-sm font-medium ${isSupported ? 'text-green-600 bg-green-100' : 'text-red-600 bg-red-100'}`}>
				{isSupported ? 'Supported' : 'Not Supported'}
			</span>
		</div>

		<!-- Permission Status -->
		<div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
			<div class="flex items-center">
				<div class={`w-3 h-3 rounded-full mr-3 ${permission === 'granted' ? 'bg-green-500' : permission === 'denied' ? 'bg-red-500' : 'bg-yellow-500'}`}></div>
				<div>
					<p class="font-medium text-gray-900">Permission Status</p>
					<p class="text-sm text-gray-600">
						Current notification permission
					</p>
				</div>
			</div>
			<span class={`px-3 py-1 rounded-full text-sm font-medium ${getPermissionColor(permission)}`}>
				{getPermissionText(permission)}
			</span>
		</div>

		<!-- Registration Status -->
		<div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
			<div class="flex items-center">
				<div class={`w-3 h-3 rounded-full mr-3 ${isRegistered ? 'bg-green-500' : 'bg-gray-400'}`}></div>
				<div>
					<p class="font-medium text-gray-900">Registration Status</p>
					<p class="text-sm text-gray-600">
						{isRegistered ? 'Device is registered for notifications' : 'Device is not registered'}
					</p>
				</div>
			</div>
			<span class={`px-3 py-1 rounded-full text-sm font-medium ${isRegistered ? 'text-green-600 bg-green-100' : 'text-gray-600 bg-gray-100'}`}>
				{isRegistered ? 'Registered' : 'Not Registered'}
			</span>
		</div>
	</div>

	<!-- Actions -->
	{#if isSupported}
		<div class="mt-6 space-y-3">
			{#if permission === 'default' || permission === 'denied'}
				<button
					on:click={requestPermission}
					disabled={isLoading}
					class="w-full flex items-center justify-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
				>
					{#if isLoading}
						<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
					{:else}
						<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z" />
						</svg>
					{/if}
					Enable Notifications
				</button>
			{:else if permission === 'granted'}
				<div class="flex space-x-3">
					{#if !isRegistered}
						<button
							on:click={registerForNotifications}
							disabled={isLoading}
							class="flex-1 flex items-center justify-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						>
							{#if isLoading}
								<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
							{:else}
								<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
								</svg>
							{/if}
							Register Device
						</button>
					{:else}
						<button
							on:click={unregisterFromNotifications}
							disabled={isLoading}
							class="flex-1 flex items-center justify-center px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						>
							{#if isLoading}
								<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
							{:else}
								<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
								</svg>
							{/if}
							Unregister
						</button>
					{/if}

					{#if isRegistered}
						<button
							on:click={sendTestNotification}
							disabled={isLoading}
							class="flex-1 flex items-center justify-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						>
							{#if isLoading}
								<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
							{:else}
								<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
							{/if}
							Test Notification
						</button>
					{/if}
				</div>
			{/if}
		</div>
	{:else}
		<div class="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
			<div class="flex items-center">
				<svg class="w-5 h-5 text-yellow-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z" />
				</svg>
				<div>
					<p class="font-medium text-yellow-800">Browser Not Supported</p>
					<p class="text-sm text-yellow-700">
						Your browser doesn't support push notifications. Please use a modern browser like Chrome, Firefox, or Safari.
					</p>
				</div>
			</div>
		</div>
	{/if}

	<!-- Help Text -->
	<div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
		<div class="flex items-start">
			<svg class="w-5 h-5 text-blue-600 mr-2 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
			</svg>
			<div>
				<p class="font-medium text-blue-800 mb-1">About Push Notifications</p>
				<ul class="text-sm text-blue-700 space-y-1">
					<li>• Receive notifications even when the app is closed</li>
					<li>• Stay updated on new tasks, announcements, and messages</li>
					<li>• Works on both mobile and desktop devices</li>
					<li>• You can disable notifications anytime in browser settings</li>
				</ul>
			</div>
		</div>
	</div>
</div>