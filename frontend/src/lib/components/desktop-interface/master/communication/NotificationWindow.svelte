<script lang="ts">
	import { onMount } from 'svelte';
	import NotificationCenter from '$lib/components/desktop-interface/master/communication/NotificationCenter.svelte';

	export let targetNotificationId: string | null = null;

	let notificationCenterComponent: any = null;

	onMount(() => {
		// If we have a target notification ID, scroll to it after component loads
		if (targetNotificationId) {
			setTimeout(() => {
				scrollToNotification(targetNotificationId);
			}, 1000);
		}
	});

	// Scroll to specific notification
	function scrollToNotification(notificationId: string) {
		try {
			// Try to find the notification element by ID
			const notificationElement = document.querySelector(`[data-notification-id="${notificationId}"]`);
			
			if (notificationElement) {
				// Scroll to the notification
				notificationElement.scrollIntoView({ 
					behavior: 'smooth', 
					block: 'center' 
				});
				
				// Highlight the notification temporarily
				notificationElement.classList.add('highlighted-notification');
				setTimeout(() => {
					notificationElement.classList.remove('highlighted-notification');
				}, 3000);
				
				console.log('✅ [NotificationWindow] Scrolled to notification:', notificationId);
			} else {
				console.log('⚠️ [NotificationWindow] Notification element not found:', notificationId);
				// Try again after a short delay in case notifications are still loading
				setTimeout(() => {
					scrollToNotification(notificationId);
				}, 2000);
			}
		} catch (error) {
			console.error('❌ [NotificationWindow] Error scrolling to notification:', error);
		}
	}
</script>

<div class="notification-window">
	<NotificationCenter bind:this={notificationCenterComponent} />
</div>

<style>
	.notification-window {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		overflow: hidden;
	}

	/* Highlighted notification styles */
	:global(.highlighted-notification) {
		animation: highlight-pulse 3s ease-in-out;
		border: 2px solid #10b981 !important;
		box-shadow: 0 0 20px rgba(16, 185, 129, 0.3) !important;
	}

	@keyframes highlight-pulse {
		0%, 100% {
			box-shadow: 0 0 20px rgba(16, 185, 129, 0.3);
		}
		50% {
			box-shadow: 0 0 30px rgba(16, 185, 129, 0.6);
		}
	}
</style>