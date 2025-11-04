<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import CreateNotification from '$lib/components/admin/communication/CreateNotification.svelte';
	import { localeData } from '$lib/i18n';

	let currentUserData = null;
	let stats = {
		pendingTasks: 0,
		completedTasks: 0,
		unreadNotifications: 0,
		totalTasks: 0
	};
	let recentNotifications = [];
	let isLoading = true;
	
	// Swipe gesture state
	let swipeStartX = 0;
	let swipeCurrentX = 0;
	let swipeThreshold = 100; // Minimum distance for swipe
	let isSwipeActive = false;
	let swipeTargetNotification = null;
	
	// Success message state
	let showSuccessMessage = false;
	let successMessage = '';
	
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
		refreshNotificationCount(true); // Silent refresh
	}

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
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
				await refreshNotificationCount(true); // Silent refresh
			}
		}, 30000);
		
		// Refresh when page becomes visible (user returns to dashboard)
		const handleVisibilityChange = async () => {
			if (!document.hidden && currentUserData) {
				await refreshNotificationCount(true); // Silent refresh
			}
		};
		
		document.addEventListener('visibilitychange', handleVisibilityChange);
		
		// Cleanup on component destroy
		return () => {
			clearInterval(refreshInterval);
			document.removeEventListener('visibilitychange', handleVisibilityChange);
		};
	});

	async function refreshNotificationCount(silent = false) {
		try {
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				stats.unreadNotifications = userNotifications.filter(n => !n.is_read).length;
			} else {
				stats.unreadNotifications = 0;
			}
		} catch (error) {
			if (!silent) {
				console.error('Error refreshing notification count:', error);
			}
		}
	}

	async function loadDashboardData() {
		try {
			// Load task statistics - include tasks assigned TO user OR assigned BY user to themselves
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
				.or(`assigned_to_user_id.eq.${currentUserData.id},and(assigned_by.eq.${currentUserData.id},assigned_to_user_id.eq.${currentUserData.id})`)
				.order('assigned_at', { ascending: false });

			if (!taskError && taskAssignments) {
				stats.totalTasks = taskAssignments.length;
				// Count pending tasks based on assignment status - include all non-completed/cancelled statuses
				stats.pendingTasks = taskAssignments.filter(t => 
					t.status !== 'completed' && t.status !== 'cancelled'
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
			// Use the notification management service to get notifications with read states
			let notifications;
			let error;

			// All users should get the same notification format with attachments
			const result = await notificationManagement.getAllNotifications(currentUserData.id);
			notifications = result || [];
			error = null;

			if (error) {
				console.error('Error loading recent notifications:', error);
				recentNotifications = [];
				return;
			}

			// Filter to recent notifications (yesterday, today, and overdue)
			const today = new Date();
			const yesterday = new Date(today);
			yesterday.setDate(yesterday.getDate() - 1);
			yesterday.setHours(0, 0, 0, 0);

			const filteredNotifications = notifications.filter(notification => {
				const notificationDate = new Date(notification.created_at);
				return notificationDate >= yesterday;
			}).slice(0, 20); // Limit to 20 recent notifications

			if (error) {
				console.error('Error loading recent notifications:', error);
				recentNotifications = [];
				return;
			}

			// For each notification, get recipients info, process attachments, and check read state
			if (filteredNotifications) {
				const notificationsWithRecipients = await Promise.all(
					filteredNotifications.map(async (notification) => {
						const notificationId = notification.notification_id || notification.id;

						// Check read state for current user
						let isRead = false;
						
						// First try to get read state from the notification object (for regular users)
						if (notification.is_read !== undefined) {
							isRead = notification.is_read;
						} else {
							// For admin users or when read state is not included, check directly
							try {
								const { data: readState, error: readError } = await supabase
									.from('notification_read_states')
									.select('is_read')
									.eq('notification_id', notificationId)
									.eq('user_id', currentUserData.id)
									.single();
								
								if (readError) {
									// Default to unread if we can't check
									isRead = false;
								} else {
									isRead = readState ? readState.is_read : false;
								}
							} catch (readError) {
								// If no read state exists or permission denied, notification is unread
								isRead = false;
							}
						}

						// Try multiple approaches to get recipient information
						let recipients = [];
						let recipientsError = null;

						// Approach 1: Try notification_recipients table first
						try {
							const { data: recipientsData, error } = await supabase
								.from('notification_recipients')
								.select(`
									user_id,
									user:users (
										id,
										username,
										employee:hr_employees (
											name
										)
									)
								`)
								.eq('notification_id', notificationId);

							if (error) {
								recipientsError = error;
							} else if (recipientsData && recipientsData.length > 0) {
								recipients = recipientsData;
							}
						} catch (e) {
							// Recipients table access error
						}

						// Approach 2: If no recipients from table, try to resolve from target_users
						if (recipients.length === 0 && notification.target_users) {
							try {
								let targetUserIds = notification.target_users;
								
								// Parse target_users if it's a JSON string
								if (typeof targetUserIds === 'string') {
									try {
										targetUserIds = JSON.parse(targetUserIds);
									} catch (e) {
										// Failed to parse target_users JSON
									}
								}

								if (Array.isArray(targetUserIds) && targetUserIds.length > 0) {
									
									// Get user information for the target user IDs
									const { data: usersData, error: usersError } = await supabase
										.from('users')
										.select(`
											id,
											username,
											employee:hr_employees (
												name
											)
										`)
										.in('id', targetUserIds);

									if (usersError) {
										// Users query failed
									} else if (usersData && usersData.length > 0) {
										recipients = usersData.map(user => ({
											user_id: user.id,
											user: user
										}));
									}
								}
							} catch (e) {
								// Error processing target_users
							}
						}

						if (recipientsError) {
							// Try to get user info from notification metadata or target_users as fallback
							let fallbackRecipients = 'Recipients';
							try {
								if (notification.target_type === 'all_users') {
									fallbackRecipients = 'All Users';
								} else if (notification.target_type === 'specific_users' && notification.target_users) {
									// Try to parse target_users if it's a JSON string
									let targetUsers = notification.target_users;
									if (typeof targetUsers === 'string') {
										try {
											targetUsers = JSON.parse(targetUsers);
										} catch (e) {
											// Keep as string if parsing fails
										}
									}
									if (Array.isArray(targetUsers) && targetUsers.length > 0) {
										fallbackRecipients = `${targetUsers.length} user${targetUsers.length > 1 ? 's' : ''}`;
									} else {
										fallbackRecipients = 'Specific Users';
									}
								} else if (notification.created_by_name) {
									fallbackRecipients = `Created by ${notification.created_by_name}`;
								}
							} catch (e) {
								console.warn('Error processing fallback recipients:', e);
							}
							
							return {
								...notification,
								recipients: [],
								recipients_text: fallbackRecipients,
								all_attachments: []
							};
						}

						// Format recipients text
						let recipientsText = 'Recipients';
						if (notification.target_type === 'all_users') {
							recipientsText = 'All Users';
						} else if (recipients && recipients.length > 0) {
							const userNames = recipients.map(r => {
								// Use employee name or username in that order
								return r.user?.employee?.name || 
									   r.user?.username || 
									   `User ${r.user?.id?.substring(0, 8) || 'Unknown'}`;
							}).filter(name => name && name !== 'Unknown' && !name.startsWith('User Unknown')); // Filter out empty/unknown names
							
							if (userNames.length > 0) {
								if (userNames.length <= 3) {
									recipientsText = userNames.join(', ');
								} else {
									recipientsText = `${userNames.slice(0, 2).join(', ')} and ${userNames.length - 2} others`;
								}
							} else {
								// If no valid names found but we have recipients, show count
								recipientsText = `${recipients.length} user${recipients.length > 1 ? 's' : ''}`;
							}
						} else if (notification.target_type === 'specific_users' && notification.target_users) {
							// Try to get count from target_users metadata
							try {
								let targetUsers = notification.target_users;
								if (typeof targetUsers === 'string') {
									targetUsers = JSON.parse(targetUsers);
								}
								if (Array.isArray(targetUsers) && targetUsers.length > 0) {
									recipientsText = `${targetUsers.length} specific user${targetUsers.length > 1 ? 's' : ''}`;
								} else {
									recipientsText = 'Specific Users';
								}
							} catch (e) {
								recipientsText = 'Specific Users';
							}
						} else if (notification.created_by_name) {
							// Fallback to creator if no recipients found
							recipientsText = `By ${notification.created_by_name}`;
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
							
							allAttachments.push(...notification.tasks.task_images.map(img => ({
								...img,
								type: 'task_image',
								is_image: true,
								source: `Task: ${notification.tasks.title}`
							})));
						}

						// 3. Add task images from task assignment relationship  
						if (notification.task_assignments && notification.task_assignments.tasks && notification.task_assignments.tasks.task_images) {
							
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

						// Remove duplicates based on file path/URL and file name to prevent double display
						const uniqueAttachments = allAttachments.filter((att, index, self) => {
							const identifier = att.file_url || att.file_path || att.storage_path;
							return index === self.findIndex(a => {
								const aIdentifier = a.file_url || a.file_path || a.storage_path;
								return aIdentifier === identifier && a.file_name === att.file_name;
							});
						});

						return {
							...notification,
							id: notificationId, // Ensure consistent ID
							recipients: recipients || [],
							recipients_text: recipientsText,
							all_attachments: uniqueAttachments,
							read: isRead
						};
					})
				);

				recentNotifications = notificationsWithRecipients.filter(n => !n.read); // Only show unread notifications in recent section
				
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
		
		
		const baseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public';
		
		if (attachment.type === 'task_image') {
			// Task images use file_url or file_path
			const fileName = attachment.file_url || attachment.file_path;
			if (fileName) {
				const url = `${baseUrl}/task-images/${fileName}`;
				
				return url;
			}
		} else if (attachment.type === 'quick_task_file') {
			// Quick task files use storage_path
			if (attachment.storage_path) {
				const url = `${baseUrl}/quick-task-files/${attachment.storage_path}`;
				
				return url;
			}
		} else if (attachment.type === 'notification_attachment') {
			// Notification attachments use file_path
			const fileName = attachment.file_path || attachment.file_url;
			if (fileName) {
				const url = `${baseUrl}/notification-images/${fileName}`;
				
				return url;
			}
		}
		
		// Fallback: if it's already a full URL, use it
		if (attachment.file_url && attachment.file_url.startsWith('http')) {
			
			return attachment.file_url;
		}
		
		
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

	// Swipe gesture functions
	function handleTouchStart(event, notification) {
		if (notification.read) return; // Only allow swipe on unread notifications
		
		swipeStartX = event.touches[0].clientX;
		swipeCurrentX = swipeStartX;
		isSwipeActive = true;
		swipeTargetNotification = notification;
	}

	function handleTouchMove(event) {
		if (!isSwipeActive || !swipeTargetNotification) return;
		
		swipeCurrentX = event.touches[0].clientX;
		const deltaX = swipeCurrentX - swipeStartX;
		
		// Only allow left swipe (negative delta)
		if (deltaX < 0) {
			event.preventDefault();
			// Apply transform to show visual feedback
			const element = event.currentTarget;
			element.style.transform = `translateX(${Math.max(deltaX, -120)}px)`;
			element.style.opacity = Math.max(0.5, 1 + deltaX / 200);
		}
	}

	function handleTouchEnd(event) {
		if (!isSwipeActive || !swipeTargetNotification) return;
		
		const deltaX = swipeCurrentX - swipeStartX;
		const element = event.currentTarget;
		
		// Reset transform
		element.style.transform = '';
		element.style.opacity = '';
		
		// Check if swipe distance meets threshold for mark as read
		if (deltaX < -swipeThreshold) {
			markNotificationAsRead(swipeTargetNotification.id);
		}
		
		// Reset swipe state
		isSwipeActive = false;
		swipeTargetNotification = null;
		swipeStartX = 0;
		swipeCurrentX = 0;
	}

	// Mark individual notification as read
	async function markNotificationAsRead(notificationId) {
		if (!currentUserData?.id) return;
		
		try {
			const result = await notificationManagement.markAsRead(notificationId, currentUserData.id);
			if (result.success) {
				// Remove notification from recent list since it's now read
				recentNotifications = recentNotifications.filter(n => n.id !== notificationId);
				// Update stats
				if (stats.unreadNotifications > 0) {
					stats.unreadNotifications--;
				}
				// Show success message
				showSuccess('Notification marked as read');
				// Refresh notification count to sync with other components
				await refreshNotificationCount(true);
			}
		} catch (error) {
			console.error('Error marking notification as read:', error);
		}
	}

	// Mark all notifications as read
	async function markAllNotificationsAsRead() {
		if (!currentUserData?.id || recentNotifications.length === 0) return;
		
		try {
			const result = await notificationManagement.markAllAsRead(currentUserData.id);
			if (result.success) {
				const count = recentNotifications.length;
				// Clear all notifications from recent list
				recentNotifications = [];
				// Reset unread count
				stats.unreadNotifications = 0;
				// Show success message
				showSuccess(`${count} notifications marked as read`);
				// Refresh notification count to sync with other components
				await refreshNotificationCount(true);
			}
		} catch (error) {
			console.error('Error marking all notifications as read:', error);
		}
	}

	// Show success message
	function showSuccess(message) {
		successMessage = message;
		showSuccessMessage = true;
		// Auto hide after 3 seconds
		setTimeout(() => {
			showSuccessMessage = false;
		}, 3000);
	}
</script>

<svelte:head>
	<title>Dashboard - Aqura Mobile</title>
</svelte:head>

<div class="mobile-dashboard">
	{#if showSuccessMessage}
		<div class="success-message">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M20 6L9 17l-5-5"/>
			</svg>
			{successMessage}
		</div>
	{/if}
	
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
						<p>{getTranslation('mobile.dashboardContent.stats.pendingTasks')}</p>
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
						<p>{getTranslation('mobile.dashboardContent.stats.completed')}</p>
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
						<p>{getTranslation('mobile.dashboardContent.stats.notifications')}</p>
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
						<p>{getTranslation('mobile.dashboardContent.stats.totalTasks')}</p>
					</div>
				</div>
			</div>
		</section>

		<!-- Recent Notifications Section -->
		<section class="recent-section">
			<div class="section-header">
				<div class="section-title-row">
					<h2>{getTranslation('mobile.dashboardContent.recentNotifications.title')}</h2>
					{#if recentNotifications.length > 0}
						<button class="mark-all-read-btn" on:click={markAllNotificationsAsRead}>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M20 6L9 17l-5-5"/>
							</svg>
							Mark all read
						</button>
					{/if}
				</div>
				<span class="section-subtitle">
					{getTranslation('mobile.dashboardContent.recentNotifications.allInSystem')}
					{#if recentNotifications.filter(n => !n.read).length > 0}
						• Swipe left to mark as read
					{/if}
				</span>
			</div>
			
			{#if recentNotifications.length > 0}
				<div class="notifications-list">
					{#each recentNotifications as notification}
						<div class="notification-card {notification.read ? 'read' : 'unread'}" 
							 data-notification-id={notification.id}
							 on:touchstart={!notification.read ? (e) => handleTouchStart(e, notification) : null}
							 on:touchmove={handleTouchMove}
							 on:touchend={handleTouchEnd}>
							<div class="notification-header">
								<h4>{notification.title}</h4>
								<div class="notification-actions">
									<span class="notification-time">{formatDate(notification.created_at)}</span>
									{#if !notification.read}
										<button class="mark-read-btn" on:click={() => markNotificationAsRead(notification.id)} title="Mark as read">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M20 6L9 17l-5-5"/>
											</svg>
										</button>
									{/if}
								</div>
							</div>
							<p class="notification-message">{notification.message}</p>
							<div class="notification-meta">
								<div class="notification-sender">
									<span class="meta-label">{getTranslation('mobile.dashboardContent.labels.sentBy')}</span>
									<span class="meta-value">
										{notification.created_by_name || getTranslation('mobile.dashboardContent.labels.system')}
									</span>
								</div>
								<div class="notification-recipients">
									<span class="meta-label">{getTranslation('mobile.dashboardContent.labels.sentTo')}</span>
									<span class="meta-value">{notification.recipients_text}</span>
								</div>
							</div>
							
							<!-- Attachments Section -->
							{#if notification.all_attachments && notification.all_attachments.length > 0}
								<div class="notification-attachments">
									<h5>{getTranslation('mobile.dashboardContent.labels.attachments')} ({notification.all_attachments.length})</h5>
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
															<span class="attachment-source">{getTranslation('mobile.dashboardContent.labels.from')} {attachment.source}</span>
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
																<span class="file-source">{getTranslation('mobile.dashboardContent.labels.from')} {attachment.source}</span>
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
					<p>{getTranslation('mobile.dashboardContent.recentNotifications.noNotifications')}</p>
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
				<h2>{getTranslation('mobile.dashboardContent.actions.createNotification')}</h2>
				<button class="close-btn" on:click={closeCreateNotification} aria-label="Close">
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
							{getTranslation('mobile.dashboardContent.actions.download')}
						</button>
						<button class="close-btn" on:click={closeImagePreview} aria-label="Close">
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
					<span class="image-source">{getTranslation('mobile.dashboardContent.actions.source')}: {previewImage.source}</span>
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
		position: relative;
	}

	/* Success Message */
	.success-message {
		position: fixed;
		top: 1rem;
		left: 50%;
		transform: translateX(-50%);
		background: #10B981;
		color: white;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
		z-index: 1000;
		animation: slideDown 0.3s ease-out;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateX(-50%) translateY(-100%);
		}
		to {
			opacity: 1;
			transform: translateX(-50%) translateY(0);
		}
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

	.section-title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.25rem;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
	}

	.mark-all-read-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.5rem 0.75rem;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 0.375rem;
		white-space: nowrap;
	}

	.mark-all-read-btn:hover {
		background: #2563EB;
		transform: translateY(-1px);
	}

	.mark-all-read-btn:active {
		transform: translateY(0);
	}

	.section-subtitle {
		font-size: 0.75rem;
		color: #6B7280;
		font-weight: 400;
	}

	.swipe-hint {
		font-size: 0.7rem;
		color: #10B981;
		margin-top: 0.25rem;
		font-style: italic;
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
		touch-action: pan-y; /* Allow vertical scrolling but handle horizontal swipes */
		position: relative;
		overflow: hidden;
	}

	.notification-card.unread {
		border-left-color: #10B981;
		background: linear-gradient(135deg, #ffffff 0%, #f0fdf4 100%);
	}

	.notification-card.read {
		border-left-color: #D1D5DB;
		opacity: 0.8;
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

	.notification-actions {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-shrink: 0;
	}

	.notification-time {
		font-size: 0.7rem;
		color: #9CA3AF;
		font-weight: 400;
	}

	.mark-read-btn {
		background: #10B981;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.375rem;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0.8;
	}

	.mark-read-btn:hover {
		background: #059669;
		opacity: 1;
		transform: scale(1.05);
	}

	.mark-read-btn:active {
		transform: scale(0.95);
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
