<script lang="ts">
	import { onMount } from 'svelte';
	import { 
		isPushSupported, 
		getPermissionStatus, 
		subscribeToPushNotifications, 
		unsubscribeFromPushNotifications,
		hasActiveSubscription,
		sendTestNotification
	} from '$lib/utils/pushNotifications';
	import { currentUser } from '$lib/utils/persistentAuth';

	let isSupported = false;
	let permissionStatus: NotificationPermission = 'default';
	let isSubscribed = false;
	let isLoading = false;
	let statusMessage = '';
	let statusType: 'success' | 'error' | 'info' = 'info';

	onMount(async () => {
		isSupported = isPushSupported();
		if (isSupported) {
			permissionStatus = getPermissionStatus();
			isSubscribed = await hasActiveSubscription();
		}
	});

	async function handleToggle() {
		if (isLoading) return;

		isLoading = true;
		statusMessage = '';

		try {
			if (isSubscribed) {
				// Unsubscribe
				const success = await unsubscribeFromPushNotifications();
				if (success) {
					isSubscribed = false;
					statusMessage = '✅ Push notifications disabled';
					statusType = 'success';
					permissionStatus = getPermissionStatus();
				} else {
					throw new Error('Failed to unsubscribe');
				}
			} else {
				// Subscribe
				const subscription = await subscribeToPushNotifications();
				if (subscription) {
					isSubscribed = true;
					statusMessage = '✅ Push notifications enabled!';
					statusType = 'success';
					permissionStatus = getPermissionStatus();
				} else {
					statusMessage = '❌ Permission denied. Please enable notifications in browser settings.';
					statusType = 'error';
				}
			}
		} catch (error) {
			console.error('Error toggling push notifications:', error);
			let errorMsg = 'Unknown error occurred';
			
			if (error instanceof Error) {
				errorMsg = error.message;
				
				// Provide helpful messages for common errors
				if (errorMsg.includes('Service worker')) {
					errorMsg = 'Service worker not ready. Please refresh the page and try again.';
				} else if (errorMsg.includes('not logged in')) {
					errorMsg = 'Please log in to enable push notifications.';
				} else if (errorMsg.includes('permission')) {
					errorMsg = 'Database permission error. Please contact administrator.';
				} else if (errorMsg.includes('timeout')) {
					errorMsg = 'Request timed out. Please check your internet connection and try again.';
				}
			}
			
			statusMessage = `❌ ${errorMsg}`;
			statusType = 'error';
		} finally {
			isLoading = false;
			
			// Clear status message after 5 seconds
			if (statusMessage) {
				setTimeout(() => {
					statusMessage = '';
				}, 5000);
			}
		}
	}

	async function handleTest() {
		if (isLoading) return;

		isLoading = true;
		statusMessage = '';

		try {
			await sendTestNotification();
			statusMessage = '✅ Test notification sent! Check your notifications.';
			statusType = 'success';
		} catch (error) {
			console.error('Error sending test:', error);
			statusMessage = `❌ ${error.message}`;
			statusType = 'error';
		} finally {
			isLoading = false;

			setTimeout(() => {
				statusMessage = '';
			}, 5000);
		}
	}

	$: permissionText = permissionStatus === 'granted' ? '✅ Allowed' 
		: permissionStatus === 'denied' ? '🚫 Blocked' 
		: '⚠️ Not Set';
</script>

<div class="push-settings">
	<div class="header">
		<h3>🔔 Push Notifications</h3>
		<p class="subtitle">Get real-time alerts even when the app is closed</p>
	</div>

	{#if !isSupported}
		<div class="warning-banner">
			<span class="icon">⚠️</span>
			<p>Push notifications are not supported in your browser.</p>
		</div>
	{:else if !$currentUser}
		<div class="warning-banner">
			<span class="icon">⚠️</span>
			<p>Please log in to enable push notifications.</p>
		</div>
	{:else}
		<div class="settings-content">
			<!-- Status Info -->
			<div class="status-row">
				<div class="status-item">
					<span class="label">Browser Permission:</span>
					<span class="value">{permissionText}</span>
				</div>
				<div class="status-item">
					<span class="label">Status:</span>
					<span class="value {isSubscribed ? 'enabled' : 'disabled'}">
						{isSubscribed ? '✅ Enabled' : '⚪ Disabled'}
					</span>
				</div>
			</div>

			<!-- Status Message -->
			{#if statusMessage}
				<div class="status-message {statusType}">
					{statusMessage}
				</div>
			{/if}

			<!-- Action Buttons -->
			<div class="actions">
				<button 
					class="toggle-btn {isSubscribed ? 'enabled' : 'disabled'}"
					on:click={handleToggle}
					disabled={isLoading}
				>
					{#if isLoading}
						<span class="spinner"></span>
						Processing...
					{:else}
						{isSubscribed ? '🔕 Disable Notifications' : '🔔 Enable Notifications'}
					{/if}
				</button>

				{#if isSubscribed}
					<button 
						class="test-btn"
						on:click={handleTest}
						disabled={isLoading}
					>
						🧪 Send Test
					</button>
				{/if}
			</div>

			<!-- Info Box -->
			<div class="info-box">
				<p class="info-title">ℹ️ How it works:</p>
				<ul>
					<li>Receive notifications for new tasks, assignments, and important updates</li>
					<li>Notifications work even when your browser is closed</li>
					<li>You can manage permissions in your browser settings</li>
					<li>Disable anytime by clicking the button above</li>
				</ul>
			</div>
		</div>
	{/if}
</div>

<style>
	.push-settings {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		max-width: 600px;
	}

	.header {
		margin-bottom: 24px;
	}

	.header h3 {
		font-size: 20px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
	}

	.warning-banner {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 16px;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 8px;
		color: #92400e;
	}

	.warning-banner .icon {
		font-size: 24px;
	}

	.warning-banner p {
		margin: 0;
		font-size: 14px;
	}

	.settings-content {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.status-row {
		display: flex;
		gap: 24px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
		flex-wrap: wrap;
	}

	.status-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.status-item .label {
		font-size: 12px;
		color: #6b7280;
		font-weight: 500;
	}

	.status-item .value {
		font-size: 14px;
		font-weight: 600;
		color: #1f2937;
	}

	.status-item .value.enabled {
		color: #10b981;
	}

	.status-item .value.disabled {
		color: #6b7280;
	}

	.status-message {
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
	}

	.status-message.success {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #10b981;
	}

	.status-message.error {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #ef4444;
	}

	.status-message.info {
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #3b82f6;
	}

	.actions {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
	}

	.toggle-btn,
	.test-btn {
		padding: 12px 24px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		border: none;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
	}

	.toggle-btn {
		flex: 1;
		min-width: 200px;
	}

	.toggle-btn.disabled {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
	}

	.toggle-btn.disabled:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669, #047857);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.toggle-btn.enabled {
		background: #f3f4f6;
		color: #6b7280;
		border: 1px solid #d1d5db;
	}

	.toggle-btn.enabled:hover:not(:disabled) {
		background: #e5e7eb;
		transform: translateY(-1px);
	}

	.test-btn {
		background: #3b82f6;
		color: white;
	}

	.test-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.toggle-btn:disabled,
	.test-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.info-box {
		padding: 16px;
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
	}

	.info-title {
		font-size: 14px;
		font-weight: 600;
		color: #0c4a6e;
		margin: 0 0 12px 0;
	}

	.info-box ul {
		margin: 0;
		padding-left: 20px;
		color: #0c4a6e;
		font-size: 13px;
	}

	.info-box li {
		margin-bottom: 6px;
	}

	.info-box li:last-child {
		margin-bottom: 0;
	}

	/* Responsive */
	@media (max-width: 640px) {
		.push-settings {
			padding: 16px;
		}

		.status-row {
			flex-direction: column;
			gap: 12px;
		}

		.actions {
			flex-direction: column;
		}

		.toggle-btn,
		.test-btn {
			width: 100%;
		}
	}
</style>
