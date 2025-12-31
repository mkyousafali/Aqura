<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';

	// Get notification ID from URL params
	$: notificationId = $page.params.id;
	
	let notification: any = null;
	let isLoading = true;
	let errorMessage = '';

	async function loadNotification() {
		if (!notificationId || !$currentUser?.id) {
			errorMessage = 'Invalid notification or user';
			isLoading = false;
			return;
		}

		try {
			// Mark as read when viewing
			await notificationManagement.markAsRead(notificationId, $currentUser.id);
			
			// Load notification details
			const result = await notificationManagement.getNotificationById(notificationId);
			if (result && result.data) {
				notification = result.data;
			} else {
				errorMessage = 'Notification not found';
			}
		} catch (error) {
			console.error('Error loading notification:', error);
			errorMessage = 'Failed to load notification';
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		loadNotification();
	});

	function formatTimestamp(timestamp: string) {
		const date = new Date(timestamp);
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
	}

	function getNotificationIcon(type: string) {
		switch(type) {
			case 'success': return '✅';
			case 'warning': return '⚠️';
			case 'error': return '❌';
			case 'info': return 'ℹ️';
			case 'announcement': return '📢';
			case 'task_assigned': return '📋';
			case 'task_completed': return '✅';
			case 'task_overdue': return '⏰';
			default: return '📢';
		}
	}
</script>

<div class="mobile-notification-detail">
	<!-- Header -->
	<header class="notification-header">
		<button class="back-btn" on:click={() => goto('/mobile-interface/notifications')} aria-label="Go back to notifications">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<h1>Notification Details</h1>
		<div></div> <!-- Spacer for centering -->
	</header>

	<div class="notification-content">
		{#if isLoading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading notification...</p>
			</div>
		{:else if errorMessage}
			<div class="error-state">
				<span class="error-icon">❌</span>
				<h3>Error</h3>
				<p>{errorMessage}</p>
				<button class="retry-btn" on:click={() => goto('/mobile-interface/notifications')}>
					Back to Notifications
				</button>
			</div>
		{:else if notification}
			<div class="notification-detail">
				<div class="notification-header-detail">
					<div class="notification-icon">
						{getNotificationIcon(notification.type)}
					</div>
					<div class="notification-meta">
						<h2>{notification.title}</h2>
						<div class="notification-details">
							<span class="notification-type">{notification.type}</span>
							<span class="notification-timestamp">{formatTimestamp(notification.created_at)}</span>
							{#if notification.created_by_name}
								<span class="notification-creator">by {notification.created_by_name}</span>
							{/if}
						</div>
					</div>
				</div>
				
				<div class="notification-message">
					{notification.message}
				</div>
				
				{#if notification.metadata && Object.keys(notification.metadata).length > 0}
					<div class="notification-metadata">
						<h3>Additional Information</h3>
						<pre>{JSON.stringify(notification.metadata, null, 2)}</pre>
					</div>
				{/if}
			</div>
		{:else}
			<div class="empty-state">
				<div class="empty-icon">🔔</div>
				<h3>Notification not found</h3>
				<p>The notification you're looking for doesn't exist or has been removed.</p>
				<button class="back-btn-large" on:click={() => goto('/mobile-interface/notifications')}>
					Back to Notifications
				</button>
			</div>
		{/if}
	</div>
</div>

<style>
	.mobile-notification-detail {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.notification-header {
		background: white;
		border-bottom: 1px solid #E5E7EB;
		position: sticky;
		top: 0;
		z-index: 100;
		padding: 1rem;
		padding-top: calc(1rem + env(safe-area-inset-top));
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.back-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		color: #374151;
		border-radius: 8px;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.back-btn:hover {
		background: #F3F4F6;
	}

	.notification-header h1 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.notification-content {
		flex: 1;
		padding: 1rem;
		padding-bottom: calc(1rem + env(safe-area-inset-bottom));
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #F3F4F6;
		border-top: 3px solid #10B981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		padding: 2rem;
		color: #DC2626;
	}

	.error-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.error-state h3 {
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 8px 0;
	}

	.error-state p {
		margin: 0 0 16px 0;
		color: #6B7280;
	}

	.retry-btn, .back-btn-large {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.retry-btn:hover, .back-btn-large:hover {
		background: #2563EB;
	}

	.notification-detail {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.notification-header-detail {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
		margin-bottom: 1.5rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.notification-icon {
		font-size: 2rem;
		flex-shrink: 0;
	}

	.notification-meta {
		flex: 1;
		min-width: 0;
	}

	.notification-meta h2 {
		margin: 0 0 0.5rem 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		line-height: 1.4;
	}

	.notification-details {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		font-size: 0.875rem;
		color: #6B7280;
	}

	.notification-type {
		font-weight: 500;
		text-transform: capitalize;
	}

	.notification-timestamp {
		color: #9CA3AF;
	}

	.notification-creator {
		color: #9CA3AF;
	}

	.notification-message {
		color: #374151;
		font-size: 1rem;
		line-height: 1.6;
		margin-bottom: 1.5rem;
		white-space: pre-wrap;
	}

	.notification-metadata {
		border-top: 1px solid #E5E7EB;
		padding-top: 1rem;
	}

	.notification-metadata h3 {
		margin: 0 0 0.75rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.notification-metadata pre {
		background: #F3F4F6;
		padding: 1rem;
		border-radius: 8px;
		font-size: 0.875rem;
		color: #374151;
		overflow-x: auto;
		white-space: pre-wrap;
		word-wrap: break-word;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 400px;
		text-align: center;
		color: #6B7280;
	}

	.empty-icon {
		font-size: 64px;
		margin-bottom: 24px;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 20px;
		font-weight: 600;
		margin: 0 0 8px 0;
		color: #374151;
	}

	.empty-state p {
		font-size: 16px;
		margin: 0 0 24px 0;
		max-width: 300px;
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.notification-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.notification-content {
			padding-bottom: max(1rem, env(safe-area-inset-bottom));
		}
	}
</style>
