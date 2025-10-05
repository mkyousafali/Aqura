<script lang="ts">
	import { onMount } from 'svelte';
	import { persistentAuthService, currentUser, deviceSessions } from '$lib/utils/persistentAuth';
	import type { UserSession } from '$lib/utils/persistentAuth';

	// Component props
	export let isOpen = false;
	export let onClose: () => void = () => {};

	// State
	let deviceUsers: UserSession[] = [];
	let currentActiveUser: UserSession | null = null;
	let isLoading = false;
	let error = '';

	// Load device users
	onMount(async () => {
		await loadDeviceUsers();
		
		// Subscribe to current user changes
		const unsubscribe = currentUser.subscribe(user => {
			currentActiveUser = user;
		});

		return unsubscribe;
	});

	async function loadDeviceUsers() {
		try {
			isLoading = true;
			deviceUsers = await persistentAuthService.getDeviceUsers();
		} catch (err) {
			console.error('Error loading device users:', err);
			error = 'Failed to load users';
		} finally {
			isLoading = false;
		}
	}

	async function switchToUser(userId: string) {
		try {
			isLoading = true;
			error = '';
			
			const result = await persistentAuthService.switchUser(userId);
			
			if (result.success) {
				await loadDeviceUsers();
				onClose();
			} else {
				error = result.error || 'Failed to switch user';
			}
		} catch (err) {
			console.error('Error switching user:', err);
			error = 'Failed to switch user';
		} finally {
			isLoading = false;
		}
	}

	async function removeUser(userId: string, event: Event) {
		event.stopPropagation();
		
		try {
			isLoading = true;
			error = '';
			
			// If removing current user, logout instead
			if (currentActiveUser?.id === userId) {
				await persistentAuthService.logout();
				onClose();
				return;
			}
			
			// Remove user session from device
			await persistentAuthService['removeUserSession'](userId);
			await loadDeviceUsers();
		} catch (err) {
			console.error('Error removing user:', err);
			error = 'Failed to remove user';
		} finally {
			isLoading = false;
		}
	}

	function getUserInitials(displayName: string): string {
		return displayName
			.split(' ')
			.map(word => word.charAt(0))
			.join('')
			.toUpperCase()
			.slice(0, 2);
	}

	function formatLastActivity(loginTime: string): string {
		const now = new Date();
		const login = new Date(loginTime);
		const diffInMinutes = Math.floor((now.getTime() - login.getTime()) / (1000 * 60));
		
		if (diffInMinutes < 1) return 'Just now';
		if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
		
		const diffInHours = Math.floor(diffInMinutes / 60);
		if (diffInHours < 24) return `${diffInHours}h ago`;
		
		const diffInDays = Math.floor(diffInHours / 24);
		return `${diffInDays}d ago`;
	}

	// Close modal when clicking outside
	function handleBackdropClick(event: MouseEvent) {
		if (event.target === event.currentTarget) {
			onClose();
		}
	}
</script>

{#if isOpen}
	<!-- Modal backdrop -->
	<div 
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
		on:click={handleBackdropClick}
		role="dialog"
		aria-modal="true"
		aria-labelledby="user-switch-title"
	>
		<!-- Modal content -->
		<div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 max-h-[80vh] overflow-hidden">
			<!-- Header -->
			<div class="px-6 py-4 border-b border-gray-200">
				<div class="flex items-center justify-between">
					<h2 id="user-switch-title" class="text-lg font-semibold text-gray-900">
						Switch User Account
					</h2>
					<button
						on:click={onClose}
						class="text-gray-400 hover:text-gray-600 transition-colors"
						aria-label="Close"
					>
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>
			</div>

			<!-- Content -->
			<div class="px-6 py-4">
				{#if error}
					<div class="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
						{error}
					</div>
				{/if}

				{#if isLoading}
					<div class="flex items-center justify-center py-8">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
						<span class="ml-2 text-gray-600">Loading...</span>
					</div>
				{:else if deviceUsers.length === 0}
					<div class="text-center py-8">
						<div class="text-gray-500 mb-4">
							<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
							</svg>
						</div>
						<p class="text-gray-600 mb-4">No other users found on this device</p>
						<button
							on:click={onClose}
							class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
						>
							Close
						</button>
					</div>
				{:else}
					<div class="space-y-3 max-h-64 overflow-y-auto">
						{#each deviceUsers as user (user.id)}
							<div 
								class="flex items-center p-3 rounded-lg border border-gray-200 hover:border-blue-300 hover:bg-blue-50 cursor-pointer transition-all {currentActiveUser?.id === user.id ? 'bg-blue-100 border-blue-400' : ''}"
								on:click={() => switchToUser(user.id)}
								role="button"
								tabindex="0"
								on:keydown={(e) => e.key === 'Enter' && switchToUser(user.id)}
							>
								<!-- User Avatar -->
								<div class="flex-shrink-0 w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white font-medium">
									{getUserInitials(user.employeeName || user.username)}
								</div>

								<!-- User Info -->
								<div class="flex-1 ml-3 min-w-0">
									<div class="flex items-center justify-between">
										<p class="text-sm font-medium text-gray-900 truncate">
											{user.employeeName || user.username}
											{#if currentActiveUser?.id === user.id}
												<span class="ml-2 px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">
													Active
												</span>
											{/if}
										</p>
										{#if currentActiveUser?.id !== user.id}
											<button
												on:click={(e) => removeUser(user.id, e)}
												class="text-gray-400 hover:text-red-600 transition-colors p-1"
												aria-label="Remove user"
												title="Remove user from device"
											>
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
												</svg>
											</button>
										{/if}
									</div>
									<p class="text-xs text-gray-500 truncate">
										{user.email}
									</p>
									<div class="flex items-center justify-between mt-1">
										<span class="text-xs text-gray-500 capitalize">
											{user.role}
										</span>
										<span class="text-xs text-gray-400">
											{formatLastActivity(user.loginTime)}
										</span>
									</div>
								</div>

								<!-- Current user indicator -->
								{#if currentActiveUser?.id === user.id}
									<div class="flex-shrink-0 ml-2">
										<div class="w-3 h-3 bg-green-500 rounded-full"></div>
									</div>
								{/if}
							</div>
						{/each}
					</div>

					<!-- Actions -->
					<div class="mt-6 pt-4 border-t border-gray-200">
						<div class="flex space-x-3">
							<button
								on:click={onClose}
								class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50 transition-colors"
							>
								Cancel
							</button>
							<button
								on:click={() => {
									persistentAuthService.logout();
									onClose();
								}}
								class="flex-1 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
							>
								Logout All
							</button>
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	/* Scrollbar styling */
	.space-y-3::-webkit-scrollbar {
		width: 6px;
	}

	.space-y-3::-webkit-scrollbar-track {
		background: #f1f1f1;
		border-radius: 3px;
	}

	.space-y-3::-webkit-scrollbar-thumb {
		background: #c1c1c1;
		border-radius: 3px;
	}

	.space-y-3::-webkit-scrollbar-thumb:hover {
		background: #a8a8a8;
	}
</style>