<script lang="ts">
	import { toastNotifications, notifications } from '$lib/stores/notifications';
	import { fade, fly } from 'svelte/transition';

	function getIcon(type: string) {
		switch (type) {
			case 'success':
				return '✓';
			case 'error':
				return '✕';
			case 'warning':
				return '⚠';
			case 'info':
				return 'i';
			default:
				return 'i';
		}
	}

	function getColorClasses(type: string) {
		switch (type) {
			case 'success':
				return 'bg-green-50 border-green-200 text-green-800';
			case 'error':
				return 'bg-red-50 border-red-200 text-red-800';
			case 'warning':
				return 'bg-yellow-50 border-yellow-200 text-yellow-800';
			case 'info':
				return 'bg-blue-50 border-blue-200 text-blue-800';
			default:
				return 'bg-gray-50 border-gray-200 text-gray-800';
		}
	}

	function getIconColorClasses(type: string) {
		switch (type) {
			case 'success':
				return 'bg-green-100 text-green-600';
			case 'error':
				return 'bg-red-100 text-red-600';
			case 'warning':
				return 'bg-yellow-100 text-yellow-600';
			case 'info':
				return 'bg-blue-100 text-blue-600';
			default:
				return 'bg-gray-100 text-gray-600';
		}
	}
</script>

<div class="toast-container fixed top-4 right-4 z-50 space-y-2">
	{#each $toastNotifications as notification (notification.id)}
		<div
			class="toast max-w-md w-full shadow-lg rounded-lg border p-4 {getColorClasses(notification.type)}"
			transition:fly="{{ x: 300, duration: 300 }}"
		>
			<div class="flex items-start">
				<div class="flex-shrink-0">
					<div class="flex items-center justify-center w-8 h-8 rounded-full {getIconColorClasses(notification.type)}">
						<span class="text-sm font-semibold">{getIcon(notification.type)}</span>
					</div>
				</div>
				<div class="ml-3 flex-1">
					<p class="text-sm font-medium">{notification.message}</p>
				</div>
				<div class="ml-4 flex-shrink-0 flex">
					<button
						class="inline-flex text-gray-400 hover:text-gray-600 focus:outline-none focus:text-gray-600 transition ease-in-out duration-150"
						on:click={() => notifications.remove(notification.id)}
					>
						<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
							<path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
						</svg>
					</button>
				</div>
			</div>
		</div>
	{/each}
</div>

<style>
	.toast-container {
		pointer-events: none;
	}
	
	.toast {
		pointer-events: auto;
	}
</style>