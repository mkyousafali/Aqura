<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import CreateNotification from '$lib/components/admin/communication/CreateNotification.svelte';

	let currentUserData = null;
	let stats = {
		pendingTasks: 0,
		completedTasks: 0,
		unreadNotifications: 0,
		totalTasks: 0
	};
	let recentNotifications = [];
	let isLoading = true;
	
	// Image preview modal
	let showImagePreview = false;
	let previewImage = null;
	
	// Create notification modal
	let showCreateNotificationModal = false;
	
	// Computed role check
	$: userRole = currentUserData?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Reactive refresh when returning to dashboard
	$: if ($page.url.pathname === '/mobile' && currentUserData) {
		refreshNotificationCount();
	}

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadDashboardData();
		}
		isLoading = false;
		
		// Set up automatic refresh for notification count every 30 seconds
		const refreshInterval = setInterval(async () => {
			if (currentUserData) {
				await refreshNotificationCount();
			}
		}, 30000);
		
		// Refresh when page becomes visible (user returns to dashboard)
		const handleVisibilityChange = async () => {
			if (!document.hidden && currentUserData) {
				await refreshNotificationCount();
			}
		};
		
		document.addEventListener('visibilitychange', handleVisibilityChange);
		
		// Cleanup on component destroy
		return () => {
			clearInterval(refreshInterval);
			document.removeEventListener('visibilitychange', handleVisibilityChange);
		};
	});

	async function refreshNotificationCount() {
		try {
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				stats.unreadNotifications = userNotifications.filter(n => !n.is_read).length;
			} else {
				stats.unreadNotifications = 0;
			}
		} catch (error) {
			console.error('Error refreshing notification count:', error);
		}
	}

	async function loadDashboardData() {
		try {
			// Load task statistics
			const { data: taskAssignments, error: taskError } = await supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!inner(
						id,
						title,
						description,
						priority,
						due_date,
						status,
						created_at
					)
				`)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false });

			if (!taskError && taskAssignments) {
				stats.totalTasks = taskAssignments.length;
				stats.pendingTasks = taskAssignments.filter(t => 
					t.status === 'assigned' || t.status === 'in_progress'
				).length;
				stats.completedTasks = taskAssignments.filter(t => 
					t.status === 'completed'
				).length;
			}

			// Load notification statistics
			try {
				const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
				
				if (userNotifications && userNotifications.length > 0) {
					// Count unread notifications
					stats.unreadNotifications = userNotifications.filter(n => !n.is_read).length;
				} else {
					stats.unreadNotifications = 0;
				}
			} catch (error) {
				console.error('❌ [Mobile Dashboard] Error loading notifications:', error);
				stats.unreadNotifications = 0;
			}

			// Load recent notifications
			await loadRecentNotifications();

		} catch (error) {
			console.error('Error loading dashboard data:', error);
		}
	}

	async function loadRecentNotifications() {
		if (!currentUserData) return;

		try {
			// Calculate date range: yesterday, today, and overdue notifications
			const today = new Date();
			const yesterday = new Date(today);
			yesterday.setDate(yesterday.getDate() - 1);
			yesterday.setHours(0, 0, 0, 0);

			let notifications;
			let error;

			if (isAdminOrMaster) {
				// Admin/Master Admin: Show all notifications from yesterday, today, and overdue
				const result = await supabase
					.from('notifications')
					.select(`
						*,
						notification_attachments(id, file_name, file_type, file_size, file_path),
						tasks(id, title, task_images(id, file_name, file_type, file_url, image_type)),
						task_assignments(id, task_id, tasks(id, title, task_images(id, file_name, file_type, file_url, image_type)))
					`)
					.gte('created_at', yesterday.toISOString())
					.order('created_at', { ascending: false })
					.limit(20);
				
				notifications = result.data;
				error = result.error;
			} else {
				// Regular users: Show notifications sent to them from yesterday, today, and overdue
				const result = await supabase
					.from('notifications')
					.select(`
						*,
						notification_attachments(id, file_name, file_type, file_size, file_path),
						tasks(id, title, task_images(id, file_name, file_type, file_url, image_type)),
						task_assignments(id, task_id, tasks(id, title, task_images(id, file_name, file_type, file_url, image_type)))
					`)
					.gte('created_at', yesterday.toISOString())
					.order('created_at', { ascending: false })
					.limit(20);

				// Filter to show all_users notifications or specific notifications for this user
				notifications = result.data?.filter(notification => {
					return notification.target_type === 'all_users' || 
						   (notification.target_type === 'specific_users' && 
						    notification.target_users && 
						    notification.target_users.includes(currentUserData.id));
				}) || [];
				error = result.error;
			}

			if (error) {
				console.error('Error loading recent notifications:', error);
				recentNotifications = [];
				return;
			}

			// For each notification, get recipients info and process attachments
			if (notifications) {
				const notificationsWithRecipients = await Promise.all(
					notifications.map(async (notification) => {
						// Get recipients for this notification
						const { data: recipients, error: recipientsError } = await supabase
							.from('notification_recipients')
							.select(`
								user:users (
									id,
									username,
									employee:hr_employees (
										name
									)
								)
							`)
							.eq('notification_id', notification.id);

						if (recipientsError) {
							console.error('Error loading recipients:', recipientsError);
							return {
								...notification,
								recipients: [],
								recipients_text: 'Unknown',
								all_attachments: []
							};
						}

						// Format recipients text
						let recipientsText = 'Unknown';
						if (notification.target_type === 'all_users') {
							recipientsText = 'All Users';
						} else if (recipients && recipients.length > 0) {
							const userNames = recipients.map(r => {
								// Use employee name if available, fallback to username
								return r.user?.employee?.name || r.user?.username || 'Unknown';
							});
							if (userNames.length <= 3) {
								recipientsText = userNames.join(', ');
							} else {
								recipientsText = `${userNames.slice(0, 2).join(', ')} and ${userNames.length - 2} others`;
							}
						}

						// Process attachments from multiple sources
						const allAttachments = [];
						
						// 1. Add notification attachments
						if (notification.notification_attachments) {
							allAttachments.push(...notification.notification_attachments.map(att => ({
								...att,
								type: 'notification_attachment',
								is_image: att.file_type && att.file_type.startsWith('image/'),
								file_url: att.file_path, // Use file_path from schema
								source: 'Notification'
							})));
						}

						// 2. Add task images from direct task relationship
						if (notification.tasks && notification.tasks.task_images) {
							console.log('📎 [Debug] Found task images from direct task:', notification.tasks.task_images.length);
							allAttachments.push(...notification.tasks.task_images.map(img => ({
								...img,
								type: 'task_image',
								is_image: true,
								source: `Task: ${notification.tasks.title}`
							})));
						}

						// 3. Add task images from task assignment relationship  
						if (notification.task_assignments && notification.task_assignments.tasks && notification.task_assignments.tasks.task_images) {
							console.log('📎 [Debug] Found task images from assignment:', notification.task_assignments.tasks.task_images.length);
							allAttachments.push(...notification.task_assignments.tasks.task_images.map(img => ({
								...img,
								type: 'task_image_assignment',
								is_image: true,
								source: `Task: ${notification.task_assignments.tasks.title}`
							})));
						}

						// 4. For quick task notifications, fetch quick task files if this is a quick task notification
						if (notification.message && 
						   (notification.message.toLowerCase().includes('quick task') || 
						    notification.title.toLowerCase().includes('quick task'))) {
							try {
								// Try to get quick task ID from metadata first
								let quickTaskId = null;
								if (notification.metadata && notification.metadata.quick_task_id) {
									quickTaskId = notification.metadata.quick_task_id;
								} else {
									// Try to extract from notification title or message
									const titleMatch = notification.title?.match(/quick task.*?([a-f0-9-]{36})/i);
									const messageMatch = notification.message?.match(/quick task.*?([a-f0-9-]{36})/i);
									if (titleMatch) {
										quickTaskId = titleMatch[1];
									} else if (messageMatch) {
										quickTaskId = messageMatch[1];
									}
								}
								
								if (quickTaskId) {
									// Get files for specific quick task only
									const { data: quickTaskFiles } = await supabase
										.from('quick_task_files')
										.select('*, quick_tasks(title)')
										.eq('quick_task_id', quickTaskId);
									
									if (quickTaskFiles && quickTaskFiles.length > 0) {
										allAttachments.push(...quickTaskFiles.map(file => ({
											...file,
											type: 'quick_task_file',
											is_image: file.file_type && file.file_type.startsWith('image/'),
											file_url: file.storage_path,
											source: `Quick Task: ${file.quick_tasks?.title || 'Unknown'}`
										})));
									}
								}
							} catch (quickTaskError) {
								console.warn('📎 [Debug] Could not fetch quick task files:', quickTaskError);
							}
						}

						console.log('📎 [Debug] Final attachments for notification:', notification.id, 'count:', allAttachments.length, allAttachments);

						return {
							...notification,
							recipients: recipients || [],
							recipients_text: recipientsText,
							all_attachments: allAttachments
						};
					})
				);

				recentNotifications = notificationsWithRecipients;
				console.log('📱 [Mobile Dashboard] Loaded recent notifications:', recentNotifications);
				console.log('📎 [Mobile Dashboard] Attachments check:', recentNotifications.map(n => ({
					id: n.id,
					title: n.title,
					has_attachments: n.has_attachments,
					attachments_count: n.all_attachments?.length || 0,
					attachments: n.all_attachments
				})));
			} else {
				recentNotifications = [];
			}

		} catch (error) {
			console.error('Error loading recent notifications:', error);
			recentNotifications = [];
		}
	}

	// Helper function to get proper file URL
	function getFileUrl(attachment) {
		console.log('🔗 [URL Debug] Processing attachment:', attachment);
		
		const baseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public';
		
		if (attachment.type === 'task_image') {
			// Task images use file_url or file_path
			const fileName = attachment.file_url || attachment.file_path;
			if (fileName) {
				const url = `${baseUrl}/task-images/${fileName}`;
				console.log('🔗 [URL Debug] Constructed task image URL:', url);
				return url;
			}
		} else if (attachment.type === 'quick_task_file') {
			// Quick task files use storage_path
			if (attachment.storage_path) {
				const url = `${baseUrl}/quick-task-files/${attachment.storage_path}`;
				console.log('🔗 [URL Debug] Constructed quick task URL:', url);
				return url;
			}
		} else if (attachment.type === 'notification_attachment') {
			// Notification attachments use file_path
			const fileName = attachment.file_path || attachment.file_url;
			if (fileName) {
				const url = `${baseUrl}/notification-images/${fileName}`;
				console.log('🔗 [URL Debug] Constructed notification URL:', url);
				return url;
			}
		}
		
		// Fallback: if it's already a full URL, use it
		if (attachment.file_url && attachment.file_url.startsWith('http')) {
			console.log('🔗 [URL Debug] Using full URL:', attachment.file_url);
			return attachment.file_url;
		}
		
		console.log('🔗 [URL Debug] No valid URL found for attachment:', attachment);
		return null;
	}

	// Helper function to download files
	function downloadFile(attachment) {
		const downloadUrl = getFileUrl(attachment);
		
		if (downloadUrl) {
			// Create a temporary link and trigger download
			const link = document.createElement('a');
			link.href = downloadUrl;
			link.download = attachment.file_name || 'download';
			link.target = '_blank';
			link.rel = 'noopener noreferrer';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		} else {
			console.error('No download URL available for attachment:', attachment);
		}
	}

	// Image preview functions
	function openImagePreview(attachment) {
		previewImage = {
			url: getFileUrl(attachment),
			name: attachment.file_name,
			source: attachment.source || 'Unknown'
		};
		showImagePreview = true;
	}

	function closeImagePreview() {
		showImagePreview = false;
		previewImage = null;
	}

	function formatDate(dateString) {
		const date = new Date(dateString);
		const now = new Date();
		const diffInMs = now.getTime() - date.getTime();
		const diffInHours = diffInMs / (1000 * 60 * 60);
		const diffInDays = diffInMs / (1000 * 60 * 60 * 24);

		if (diffInHours < 1) {
			const diffInMinutes = Math.floor(diffInMs / (1000 * 60));
			return `${diffInMinutes}m ago`;
		} else if (diffInHours < 24) {
			return `${Math.floor(diffInHours)}h ago`;
		} else if (diffInDays < 7) {
			return `${Math.floor(diffInDays)}d ago`;
		} else {
			return date.toLocaleDateString();
		}
	}

	function logout() {
		// Clear interface preference to allow user to choose again
		interfacePreferenceService.clearPreference(currentUserData?.id);
		
		// Logout from persistent auth service
		persistentAuthService.logout().then(() => {
			// Redirect to login page to choose interface again
			goto('/login');
		}).catch((error) => {
			console.error('Logout error:', error);
			// Still redirect even if logout fails
			goto('/login');
		});
	}

	function openCreateNotification() {
		showCreateNotificationModal = true;
	}

	function closeCreateNotification() {
		showCreateNotificationModal = false;
		// Refresh notifications after creating a new one
		loadDashboardData();
	}
</script>

<svelte:head>
	<title>Dashboard - Aqura Mobile</title>
</svelte:head>

<div class="mobile-dashboard">
	{#if isLoading}
		<div class="loading-content">
			<div class="loading-spinner"></div>
			<p>Loading dashboard...</p>
		</div>
	{:else}
		<!-- Stats Grid -->
		<section class="stats-section">
			<div class="stats-grid">
				<div class="stat-card pending">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<polyline points="12,6 12,12 16,14"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.pendingTasks}</h3>
						<p>Pending Tasks</p>
					</div>
				</div>

				<div class="stat-card completed">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
							<polyline points="22,4 12,14.01 9,11.01"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.completedTasks}</h3>
						<p>Completed</p>
					</div>
				</div>

				<div class="stat-card notifications" on:click={() => goto('/mobile/notifications')} role="button" tabindex="0">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
							<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.unreadNotifications}</h3>
						<p>Notifications</p>
					</div>
				</div>

				<div class="stat-card total">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
							<rect x="9" y="7" width="6" height="5"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.totalTasks}</h3>
						<p>Total Tasks</p>
					</div>
				</div>
			</div>
		</section>

		<!-- Recent Notifications Section -->
		<section class="recent-section">
			<div class="section-header">
				<h2>Recent Notifications</h2>
				<span class="section-subtitle">
					{isAdminOrMaster ? 'All notifications in system' : 'Your recent notifications'}
				</span>
			</div>
			
			{#if recentNotifications.length > 0}
				<div class="notifications-list">
					{#each recentNotifications as notification}
						<div class="notification-card">
							<div class="notification-header">
								<h4>{notification.title}</h4>
								<span class="notification-time">{formatDate(notification.created_at)}</span>
							</div>
							<p class="notification-message">{notification.message}</p>
							<div class="notification-meta">
								<div class="notification-sender">
									<span class="meta-label">Sent by:</span>
									<span class="meta-value">
										{notification.created_by_name || 'System'}
									</span>
								</div>
								<div class="notification-recipients">
									<span class="meta-label">Sent to:</span>
									<span class="meta-value">{notification.recipients_text}</span>
								</div>
							</div>
							
							<!-- Attachments Section -->
							{#if notification.all_attachments && notification.all_attachments.length > 0}
								<div class="notification-attachments">
									<h5>Attachments ({notification.all_attachments.length})</h5>
									<div class="attachments-grid">
										{#each notification.all_attachments as attachment}
											<div class="attachment-item">
												{#if attachment.is_image}
													<!-- Image Preview -->
													<div class="attachment-image" on:click={() => openImagePreview(attachment)} role="button" tabindex="0">
														<img src={getFileUrl(attachment)} alt={attachment.file_name} loading="lazy" />
														<div class="preview-overlay">
															<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
																<circle cx="12" cy="12" r="3"/>
															</svg>
														</div>
													</div>
													<div class="attachment-info">
														<span class="attachment-name">{attachment.file_name}</span>
														{#if attachment.source}
															<span class="attachment-source">From: {attachment.source}</span>
														{/if}
														<button class="download-btn-small" on:click|stopPropagation={() => downloadFile(attachment)} title="Download">
															<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																<polyline points="7,10 12,15 17,10"/>
																<line x1="12" y1="15" x2="12" y2="3"/>
															</svg>
															Download
														</button>
													</div>
												{:else}
													<!-- File Item -->
													<div class="attachment-file">
														<div class="file-icon">
															<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/>
															</svg>
														</div>
														<div class="file-info">
															<span class="file-name">{attachment.file_name}</span>
															<span class="file-type">{attachment.file_type || 'Unknown'}</span>
															{#if attachment.source}
																<span class="file-source">From: {attachment.source}</span>
															{/if}
														</div>
														<button class="download-btn" on:click={() => downloadFile(attachment)} title="Download">
															<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																<polyline points="7,10 12,15 17,10"/>
																<line x1="12" y1="15" x2="12" y2="3"/>
															</svg>
														</button>
													</div>
												{/if}
											</div>
										{/each}
									</div>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{:else}
				<div class="empty-state">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
						<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
						<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
					</svg>
					<p>No recent notifications</p>
				</div>
			{/if}
		</section>
	{/if}
</div>

<!-- Create Notification Modal -->
{#if showCreateNotificationModal}
	<div class="modal-overlay">
		<div class="modal-container">
			<div class="modal-header">
				<h2>Create Notification</h2>
				<button class="close-btn" on:click={closeCreateNotification}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="modal-content">
				<CreateNotification />
			</div>
		</div>
	</div>
{/if}

<!-- Image Preview Modal -->
{#if showImagePreview && previewImage}
	<div class="image-preview-modal" on:click={closeImagePreview} role="button" tabindex="0">
		<div class="modal-backdrop">
			<div class="image-preview-container" on:click|stopPropagation>
				<div class="preview-header">
					<h3>{previewImage.name}</h3>
					<div class="preview-actions">
						<button class="download-btn-modal" on:click={() => downloadFile({...previewImage, file_name: previewImage.name})}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
								<polyline points="7,10 12,15 17,10"/>
								<line x1="12" y1="15" x2="12" y2="3"/>
							</svg>
							Download
						</button>
						<button class="close-btn" on:click={closeImagePreview}>
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="18" y1="6" x2="6" y2="18"/>
								<line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>
				</div>
				<div class="preview-image-wrapper">
					<img src={previewImage.url} alt={previewImage.name} />
				</div>
				<div class="preview-footer">
					<span class="image-source">Source: {previewImage.source}</span>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-dashboard {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Loading */
	.loading-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Stats Section */
	.stats-section {
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}

	.stat-card {
		background: white;
		border-radius: 13px; /* Reduced from 16px (20% smaller) */
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 0.8rem; /* Reduced from 1rem (20% smaller) */
		transition: all 0.3s ease;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-icon {
		width: 38px; /* Reduced from 48px (20% smaller) */
		height: 38px; /* Reduced from 48px (20% smaller) */
		border-radius: 10px; /* Reduced from 12px (20% smaller) */
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.stat-card.pending .stat-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}

	.stat-card.completed .stat-icon {
		background: rgba(16, 185, 129, 0.1);
		color: #10B981;
	}

	.stat-card.notifications .stat-icon {
		background: rgba(245, 158, 11, 0.1);
		color: #F59E0B;
	}

	.stat-card.notifications {
		cursor: pointer;
	}

	.stat-card.notifications:hover {
		transform: translateY(-3px);
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.2);
	}

	.stat-card.notifications:active {
		transform: translateY(-1px);
	}

	.stat-card.total .stat-icon {
		background: rgba(107, 114, 128, 0.1);
		color: #6B7280;
	}

	.stat-info h3 {
		font-size: 1.6rem; /* Reduced from 2rem (20% smaller) */
		font-weight: 700;
		margin: 0 0 0.2rem 0; /* Reduced from 0.25rem */
		color: #1F2937;
	}

	.stat-info p {
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		color: #6B7280;
		margin: 0;
	}

	/* Recent Notifications Section */
	.recent-section {
		padding: 0 1.2rem 1.2rem 1.2rem;
	}

	.section-header {
		margin-bottom: 1rem;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.25rem 0;
	}

	.section-subtitle {
		font-size: 0.75rem;
		color: #6B7280;
		font-weight: 400;
	}

	.notifications-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.notification-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-left: 4px solid #3B82F6;
		transition: all 0.3s ease;
	}

	.notification-card:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.notification-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.5rem;
		gap: 0.75rem;
	}

	.notification-header h4 {
		font-size: 0.9rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		line-height: 1.3;
		flex: 1;
	}

	.notification-time {
		font-size: 0.7rem;
		color: #9CA3AF;
		font-weight: 400;
		flex-shrink: 0;
	}

	.notification-message {
		font-size: 0.8rem;
		color: #4B5563;
		line-height: 1.4;
		margin: 0 0 0.75rem 0;
	}

	.notification-meta {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		padding-top: 0.5rem;
		border-top: 1px solid #F3F4F6;
	}

	.notification-sender,
	.notification-recipients {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.meta-label {
		font-size: 0.65rem;
		color: #9CA3AF;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		min-width: 45px;
	}

	.meta-value {
		font-size: 0.7rem;
		color: #6B7280;
		font-weight: 400;
	}

	/* Notification Attachments Styles */
	.notification-attachments {
		margin-top: 0.75rem;
		padding-top: 0.75rem;
		border-top: 1px solid #F3F4F6;
	}

	.notification-attachments h5 {
		font-size: 0.75rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.5rem 0;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.attachments-grid {
		display: grid;
		gap: 0.5rem;
		grid-template-columns: repeat(auto-fit, minmax(80px, 1fr));
	}

	.attachment-item {
		position: relative;
	}

	.attachment-info {
		margin-top: 0.25rem;
		text-align: center;
	}

	.attachment-name {
		display: block;
		font-size: 0.75rem;
		font-weight: 500;
		color: #374151;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.attachment-source {
		display: block;
		font-size: 0.625rem;
		color: #6B7280;
		margin-top: 0.125rem;
		font-style: italic;
	}

	.file-source {
		display: block;
		font-size: 0.625rem;
		color: #6B7280;
		margin-top: 0.125rem;
		font-style: italic;
	}

	.attachment-image {
		position: relative;
		width: 80px;
		height: 80px;
		border-radius: 8px;
		overflow: hidden;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		flex-shrink: 0;
		cursor: pointer;
		transition: transform 0.2s ease;
	}

	.attachment-image:hover {
		transform: scale(1.05);
	}

	.attachment-image img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.preview-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.3);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
	}

	.attachment-image:hover .preview-overlay {
		opacity: 1;
	}

	.download-btn-small {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 4px 8px;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		background: white;
		color: #6B7280;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s ease;
		margin-top: 4px;
	}

	.download-btn-small:hover {
		background: #F3F4F6;
		color: #374151;
		border-color: #D1D5DB;
	}

	.attachment-file {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		min-height: 60px;
	}

	.file-icon {
		flex-shrink: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #E5E7EB;
		border-radius: 6px;
		color: #6B7280;
	}

	.file-info {
		flex: 1;
		min-width: 0;
	}

	.file-name {
		display: block;
		font-size: 0.7rem;
		font-weight: 500;
		color: #374151;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.file-type {
		display: block;
		font-size: 0.6rem;
		color: #9CA3AF;
		text-transform: uppercase;
	}

	.download-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s ease;
		flex-shrink: 0;
	}

	.download-btn:hover {
		background: #2563EB;
	}

	.download-btn:active {
		background: #1D4ED8;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		text-align: center;
		color: #9CA3AF;
	}

	.empty-state svg {
		margin-bottom: 0.75rem;
		opacity: 0.5;
	}

	.empty-state p {
		font-size: 0.875rem;
		margin: 0;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.mobile-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.stats-section,
		.recent-section {
			padding-left: 1rem;
			padding-right: 1rem;
		}

		.stat-card {
			padding: 1rem;
		}

		.stat-icon {
			width: 40px;
			height: 40px;
		}

		.stat-info h3 {
			font-size: 1.5rem;
		}

		.notification-card {
			padding: 0.875rem;
		}

		.attachment-image {
			width: 60px;
			height: 60px;
		}

		.attachments-grid {
			gap: 0.5rem;
			grid-template-columns: repeat(auto-fit, minmax(60px, 1fr));
		}

		.notification-header h4 {
			font-size: 0.85rem;
		}

		.notification-message {
			font-size: 0.75rem;
		}

		.attachments-grid {
			grid-template-columns: repeat(auto-fit, minmax(60px, 1fr));
		}

		.attachment-file {
			padding: 0.375rem;
			min-height: 50px;
		}

		.file-icon {
			width: 24px;
			height: 24px;
		}

		.download-btn {
			padding: 0.375rem;
		}
	}

	/* Safe area handling for iOS */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.modal-container {
		background: white;
		border-radius: 12px;
		max-width: 500px;
		width: 100%;
		max-height: 90vh;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F9FAFB;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.close-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		border-radius: 6px;
		color: #6B7280;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #E5E7EB;
		color: #374151;
	}

	.modal-content {
		padding: 0;
		overflow-y: auto;
		max-height: calc(90vh - 80px);
	}
	
	/* Image Preview Modal */
	.image-preview-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-backdrop {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		backdrop-filter: blur(4px);
	}

	.image-preview-container {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
		z-index: 1001;
	}

	.preview-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		background: #F8FAFC;
		border-bottom: 1px solid #E5E7EB;
	}

	.preview-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.preview-actions {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.download-btn-modal {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.download-btn-modal:hover {
		background: #2563EB;
	}

	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		background: #F3F4F6;
		border: none;
		border-radius: 6px;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #E5E7EB;
		color: #374151;
	}

	.preview-image-wrapper {
		display: flex;
		align-items: center;
		justify-content: center;
		max-height: 70vh;
		overflow: hidden;
	}

	.preview-image-wrapper img {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
	}

	.preview-footer {
		padding: 1rem 1.5rem;
		background: #F8FAFC;
		border-top: 1px solid #E5E7EB;
	}

	.image-source {
		font-size: 0.875rem;
		color: #6B7280;
	}

	@media (max-width: 768px) {
		.image-preview-container {
			max-width: 95vw;
			max-height: 95vh;
		}

		.preview-header {
			padding: 0.75rem 1rem;
		}

		.preview-header h3 {
			font-size: 1rem;
			max-width: 150px;
		}

		.download-btn-modal {
			padding: 0.375rem 0.75rem;
			font-size: 0.8rem;
		}

		.close-btn {
			width: 36px;
			height: 36px;
		}

		.preview-footer {
			padding: 0.75rem 1rem;
		}

		.image-source {
			font-size: 0.8rem;
		}
	}
</style>