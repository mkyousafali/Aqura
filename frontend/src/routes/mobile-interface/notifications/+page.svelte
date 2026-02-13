<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { db, supabase } from '$lib/utils/supabase';
	import { refreshNotificationCounts } from '$lib/stores/notifications';
	import FileDownload from '$lib/components/common/FileDownload.svelte';
	import {
		isPushSupported,
		hasActiveSubscription,
		subscribeToPushNotifications,
		unsubscribeFromPushNotifications
	} from '$lib/utils/pushNotifications';

	// ── State ──
	$: userId = $currentUser?.id;
	$: isAdminOrMaster = $currentUser?.isMasterAdmin || $currentUser?.isAdmin || false;

	let allNotifications: any[] = [];
	type NotificationWithReadState = any; // getAllNotifications adds is_read at runtime
	let isLoading = true;
	let errorMessage = '';
	let currentPage = 0;
	const pageSize = 30;
	let hasMoreNotifications = false;
	let isLoadingMore = false;

	// Filters
	let filterType = 'all';

	// Push notification state
	let pushSupported = false;
	let pushEnabled = false;
	let pushLoading = false;

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// User cache for displaying usernames (admin)
	let userCache: Record<string, string> = {};

	// Refresh listener
	let refreshInterval: ReturnType<typeof setInterval>;

	// ── Computed ── (only unread notifications)
	$: filteredNotifications = allNotifications.filter(n => {
		if (n.read) return false;
		if (filterType === 'all') return true;
		return n.type === filterType;
	});

	$: unreadCount = allNotifications.filter(n => !n.read).length;

	// ── Lifecycle ──
	let hasInitialized = false;

	// Watch for userId to become available (may not be ready at onMount)
	$: if (userId && !hasInitialized) {
		hasInitialized = true;
		initNotifications();
	}

	function initNotifications() {
		// Check push support in background
		pushSupported = isPushSupported();
		if (pushSupported) {
			hasActiveSubscription().then(r => { pushEnabled = r; }).catch(() => {});
		}

		// Load notifications immediately
		loadNotifications();

		// Silent refresh every 30 seconds
		if (refreshInterval) clearInterval(refreshInterval);
		refreshInterval = setInterval(() => {
			if (!document.hidden) silentRefresh();
		}, 30000);
	}

	onMount(() => {
		// Listen for refresh event from layout header button
		window.addEventListener('refreshNotifications', handleRefreshEvent);
	});

	onDestroy(() => {
		window.removeEventListener('refreshNotifications', handleRefreshEvent);
		if (refreshInterval) clearInterval(refreshInterval);
	});

	function handleRefreshEvent() {
		loadNotifications();
	}

	// ── Data Loading ──
	async function loadNotifications() {
		if (!userId) {
			console.warn('🔔 [Mobile Notifications] No userId, skipping load');
			isLoading = false;
			return;
		}

		try {
			if (allNotifications.length === 0) isLoading = true;
			errorMessage = '';
			currentPage = 0;

			console.log('🔔 [Mobile Notifications] Loading for userId:', userId);
			const apiNotifications = await notificationManagement.getUserNotifications(userId, currentPage, pageSize);
			console.log('🔔 [Mobile Notifications] API returned', apiNotifications.length, 'notifications');

			// Phase 1: Show ALL notifications instantly with basic data (same as desktop)
			allNotifications = apiNotifications.map(mapBasic);
			isLoading = false;
			hasMoreNotifications = apiNotifications.length === pageSize;

			// Phase 2: Load attachments in background for unread only
			const unreadApi = apiNotifications.filter(n => !n.is_read);
			if (unreadApi.length > 0) {
				Promise.all([
					loadAttachments(unreadApi),
					loadUserCache()
				]).then(([transformed]) => {
					if (transformed.length > 0) {
						const ids = new Set(transformed.map((n: any) => n.id));
						allNotifications = [...transformed, ...allNotifications.filter(n => !ids.has(n.id))];
					}
				}).catch(err => {
					console.warn('Background attachment loading failed:', err);
				});
			}
		} catch (error) {
			console.error('Error loading notifications:', error);
			errorMessage = 'Failed to load notifications. Please try again.';
			isLoading = false;
		}
	}

	async function loadMoreNotifications() {
		if (isLoadingMore || !hasMoreNotifications || !userId) return;
		try {
			isLoadingMore = true;
			currentPage++;
			const apiNotifications = await notificationManagement.getUserNotifications(userId, currentPage, pageSize);
			const newMapped = apiNotifications.map(mapBasic);
			allNotifications = [...allNotifications, ...newMapped];
			hasMoreNotifications = apiNotifications.length === pageSize;

			// Load attachments in background for unread
			const unreadApi = apiNotifications.filter(n => !n.is_read);
			if (unreadApi.length > 0) {
				loadAttachments(unreadApi).then(transformed => {
					const ids = new Set(transformed.map((n: any) => n.id));
					allNotifications = [...transformed, ...allNotifications.filter(n => !ids.has(n.id))];
				}).catch(() => {});
			}
		} catch (error) {
			console.error('Error loading more notifications:', error);
		} finally {
			isLoadingMore = false;
		}
	}

	async function silentRefresh() {
		if (!userId) return;
		try {
			const apiNotifications = await notificationManagement.getUserNotifications(userId, 0, pageSize);
			allNotifications = apiNotifications.map(mapBasic);

			const unreadApi = apiNotifications.filter(n => !n.is_read);
			if (unreadApi.length > 0) {
				Promise.all([
					loadAttachments(unreadApi),
					loadUserCache()
				]).then(([transformed]) => {
					if (transformed.length > 0) {
						const ids = new Set(transformed.map((n: any) => n.id));
						allNotifications = [...transformed, ...allNotifications.filter(n => !ids.has(n.id))];
					}
				}).catch(() => {});
			}
		} catch {
			// Silent fail
		}
	}

	// ── Map / Transform ──
	function mapBasic(notification: any) {
		return {
			id: notification.notification_id || notification.id,
			title: notification.title,
			message: notification.message,
			type: notification.type,
			timestamp: formatTimestamp(notification.created_at),
			raw_created_at: notification.created_at,
			read: notification.is_read || false,
			priority: notification.priority,
			createdBy: notification.created_by_name,
			target_users: notification.target_users,
			target_type: notification.target_type,
			status: notification.status,
			readCount: notification.read_count,
			totalRecipients: notification.total_recipients,
			metadata: notification.metadata || {},
			task_id: notification.task_id,
			task_assignment_id: notification.task_assignment_id,
			image_url: null as string | null,
			attachments: [] as any[]
		};
	}

	async function loadAttachments(apiNotifications: any[]) {
		const notifications = apiNotifications.map(mapBasic);
		const notificationIds = apiNotifications.map(n => n.notification_id || n.id);

		// Collect task IDs
		const taskIds = apiNotifications
			.filter(n => n.metadata?.task_id || n.task_id)
			.map(n => n.metadata?.task_id || n.task_id);

		// Fire both attachment queries in parallel
		const [notifAttachResult, taskAttachResult] = await Promise.allSettled([
			notificationIds.length > 0
				? db.notificationAttachments.getBatchByNotificationIds(notificationIds)
				: Promise.resolve({ data: [], error: null }),
			taskIds.length > 0
				? (async () => {
					const CHUNK = 25;
					const chunks: string[][] = [];
					for (let i = 0; i < taskIds.length; i += CHUNK) chunks.push(taskIds.slice(i, i + CHUNK));
					const results = await Promise.allSettled(
						chunks.map(c => supabase.from('task_images').select('*').in('task_id', c))
					);
					const combined: any[] = [];
					for (const r of results) {
						if (r.status === 'fulfilled' && r.value.data) combined.push(...r.value.data);
					}
					return combined;
				})()
				: Promise.resolve([])
		]);

		// Apply notification attachments
		if (notifAttachResult.status === 'fulfilled' && notifAttachResult.value?.data?.length) {
			const byNotif = notifAttachResult.value.data.reduce((acc: any, att: any) => {
				if (!acc[att.notification_id]) acc[att.notification_id] = [];
				acc[att.notification_id].push({
					...att,
					fileUrl: att.file_path?.startsWith('http') ? att.file_path : `https://supabase.urbanaqura.com/storage/v1/object/public/notification-images/${att.file_path}`,
					fileName: att.file_name, fileSize: att.file_size, fileType: att.file_type,
					uploadedAt: att.created_at, uploadedBy: att.uploaded_by
				});
				return acc;
			}, {} as Record<string, any[]>);

			notifications.forEach(n => {
				const atts = byNotif[n.id] || [];
				n.attachments = atts;
				const img = atts.find((a: any) => a.fileType?.startsWith('image/'));
				if (img) n.image_url = img.fileUrl;
			});
		}

		// Apply task attachments
		if (taskAttachResult.status === 'fulfilled' && taskAttachResult.value?.length) {
			const byTask = (taskAttachResult.value as any[]).reduce((acc: any, att: any) => {
				if (!acc[att.task_id]) acc[att.task_id] = [];
				acc[att.task_id].push({
					id: att.id,
					fileName: att.file_name || 'Unknown File',
					fileSize: att.file_size || 0,
					fileType: att.file_type || 'application/octet-stream',
					fileUrl: att.file_path?.startsWith('http') ? att.file_path : `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${att.file_path || ''}`,
					downloadUrl: att.file_path?.startsWith('http') ? att.file_path : `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${att.file_path || ''}`,
					uploadedBy: att.uploaded_by_name || att.uploaded_by || 'Unknown',
					uploadedAt: att.created_at
				});
				return acc;
			}, {} as Record<string, any[]>);

			for (const n of notifications) {
				const orig = apiNotifications.find(a => (a.notification_id || a.id) === n.id);
				const tid = orig?.metadata?.task_id || orig?.task_id;
				if (tid && byTask[tid]) {
					n.attachments = [...n.attachments, ...byTask[tid]];
				}
			}
		}

		return notifications;
	}

	// ── User Cache ──
	async function loadUserCache() {
		try {
			const userIds = new Set<string>();
			for (const n of allNotifications) {
				const m = n.metadata || {};
				if (m.assigned_to) userIds.add(m.assigned_to);
				let targets = n.target_users;
				if (typeof targets === 'string') { try { targets = JSON.parse(targets); } catch {} }
				if (Array.isArray(targets)) targets.forEach((id: string) => { if (id) userIds.add(id); });
			}

			if (userIds.size === 0) return;
			const ids = Array.from(userIds);

			const { data: employees } = await supabase.from('hr_employees').select('id, name, employee_id').in('id', ids);
			if (employees) {
				for (const e of employees) {
					if (e.name) userCache[e.id] = e.name;
					else if (e.employee_id) userCache[e.id] = `Employee ${e.employee_id}`;
				}
			}

			const missing = ids.filter(id => !userCache[id]);
			if (missing.length > 0) {
				const { data: users } = await supabase.from('users').select('id, username').in('id', missing);
				if (users) {
					for (const u of users) { if (u.username) userCache[u.id] = u.username; }
				}
			}
		} catch {}
	}

	// ── Helpers ──
	function formatTimestamp(isoString: string): string {
		const date = new Date(isoString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		const diffHours = Math.floor(diffMins / 60);
		const diffDays = Math.floor(diffHours / 24);
		if (diffMins < 1) return 'Just now';
		if (diffMins < 60) return `${diffMins}m ago`;
		if (diffHours < 24) return `${diffHours}h ago`;
		if (diffDays < 7) return `${diffDays}d ago`;
		return date.toLocaleDateString();
	}

	function getNotificationIcon(type: string) {
		switch (type) {
			case 'success': return '✅';
			case 'warning': return '⚠️';
			case 'error': return '❌';
			case 'info': return 'ℹ️';
			case 'announcement': return '📢';
			case 'task_assigned': return '📋';
			case 'task_completed': return '✅';
			case 'task_overdue': return '⏰';
			case 'approval_request': return '🔖';
			default: return '📢';
		}
	}

	function splitMessageParts(message: string): { type: 'text' | 'url'; value: string }[] {
		if (!message) return [];
		const urlRegex = /(https?:\/\/[^\s]+)/g;
		const parts: { type: 'text' | 'url'; value: string }[] = [];
		let lastIndex = 0;
		let match;
		while ((match = urlRegex.exec(message)) !== null) {
			if (match.index > lastIndex) parts.push({ type: 'text', value: message.slice(lastIndex, match.index) });
			parts.push({ type: 'url', value: match[1] });
			lastIndex = match.index + match[0].length;
		}
		if (lastIndex < message.length) parts.push({ type: 'text', value: message.slice(lastIndex) });
		return parts;
	}

	function isImageUrl(url: string): boolean {
		const lower = url.toLowerCase();
		return /\.(jpg|jpeg|png|gif|webp|svg|bmp)(\?.*)?$/i.test(lower) || (lower.includes('supabase') && lower.includes('storage'));
	}

	function getTargetUsersDisplay(notification: any): string {
		try {
			if (!notification.target_users) return '';
			let ids: string[] = [];
			if (typeof notification.target_users === 'string') {
				try {
					const parsed = JSON.parse(notification.target_users);
					ids = Array.isArray(parsed) ? parsed : parsed.user_ids || [];
				} catch { ids = [notification.target_users]; }
			} else if (Array.isArray(notification.target_users)) {
				ids = notification.target_users;
			}
			if (ids.length === 0) return '';
			const names = ids.map(id => userCache[id] || `ID: ${id.substring(0, 8)}...`);
			if (names.length <= 2) return names.join(', ');
			return `${names.slice(0, 2).join(', ')} +${names.length - 2}`;
		} catch { return ''; }
	}

	// ── Actions ──
	async function markAsRead(id: string) {
		if (!userId) return;
		try {
			const result = await notificationManagement.markAsRead(id, userId);
			if (result.success) {
				allNotifications = allNotifications.filter(n => n.id !== id);
				refreshNotificationCounts(undefined, true);
			}
		} catch (error) {
			console.error('Error marking as read:', error);
		}
	}

	async function markAllAsRead() {
		if (!userId) return;
		try {
			const result = await notificationManagement.markAllAsRead(userId);
			if (result.success) {
				allNotifications = [];
				refreshNotificationCounts(undefined, true);
			}
		} catch (error) {
			console.error('Error marking all as read:', error);
		}
	}

	async function deleteNotification(id: string) {
		try {
			const result = await notificationManagement.deleteNotification(id);
			if (result.success) {
				allNotifications = allNotifications.filter(n => n.id !== id);
			}
		} catch (error) {
			console.error('Error deleting notification:', error);
		}
	}

	async function togglePushNotifications() {
		if (pushLoading) return;
		pushLoading = true;
		try {
			if (pushEnabled) {
				await unsubscribeFromPushNotifications();
				pushEnabled = false;
			} else {
				await subscribeToPushNotifications();
				pushEnabled = true;
			}
		} catch (error) {
			console.error('Error toggling push:', error);
		} finally {
			pushLoading = false;
		}
	}

	function openImageModal(url: string) {
		selectedImageUrl = url;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	function openCreateNotification() {
		goto('/mobile-interface/notifications/create');
	}

	// Infinite scroll
	function handleScroll(e: Event) {
		const target = e.target as HTMLElement;
		if (target.scrollHeight - target.scrollTop - target.clientHeight < 200) {
			loadMoreNotifications();
		}
	}
</script>

<div class="notification-page">
	<!-- Header Bar -->
	<div class="top-bar">
		<div class="top-bar-left">
			<span class="top-title">🔔 Notifications</span>
			<span class="unread-pill">{unreadCount}</span>
		</div>
		<div class="top-bar-right">
			{#if pushSupported}
				<button class="icon-btn" class:push-on={pushEnabled} on:click={togglePushNotifications} disabled={pushLoading} title={pushEnabled ? 'Push On' : 'Push Off'}>
					{pushEnabled ? '🔔' : '🔕'}
				</button>
			{/if}
			{#if unreadCount > 0}
				<button class="text-btn" on:click={markAllAsRead}>✓ Read All</button>
			{/if}
			{#if isAdminOrMaster}
				<button class="text-btn create" on:click={openCreateNotification}>+ New</button>
			{/if}
		</div>
	</div>

	<!-- Filters -->
	<div class="filter-bar">
		<select bind:value={filterType} class="filter-select">
			<option value="all">All</option>
			<option value="success">Success</option>
			<option value="warning">Warning</option>
			<option value="error">Error</option>
			<option value="info">Info</option>
			<option value="announcement">Announce</option>
			<option value="task_assigned">Tasks</option>
			<option value="approval_request">Approvals</option>
		</select>

	</div>

	<!-- Error -->
	{#if errorMessage}
		<div class="error-bar">
			<span>❌ {errorMessage}</span>
			<button on:click={loadNotifications}>Retry</button>
		</div>
	{/if}

	<!-- Loading -->
	{#if isLoading}
		<div class="loading-container">
			<div class="spinner"></div>
			<span>Loading notifications...</span>
		</div>
	{:else if filteredNotifications.length === 0}
		<div class="empty-state">
			<div class="empty-icon">🔔</div>
			<h3>No notifications</h3>
			<p>All caught up! No unread notifications.</p>
		</div>
	{:else}
		<!-- Notification List -->
		<div class="notification-list" on:scroll={handleScroll}>
			{#each filteredNotifications as notification (notification.id)}
				<div
					class="notif-card {notification.read ? 'read' : 'unread'}"
					class:border-red-500={notification.priority === 'urgent'}
					class:border-orange-500={notification.priority === 'high'}
					class:border-yellow-400={notification.priority === 'medium'}
					class:border-gray-300={notification.priority === 'low'}
				>
					<!-- Top row: icon + title + time -->
					<div class="notif-top">
						<span class="notif-icon">{getNotificationIcon(notification.type)}</span>
						<div class="notif-info">
							<div class="notif-title">{notification.title}</div>
							<div class="notif-meta">
								<span class="notif-time">{notification.timestamp}</span>
								{#if notification.createdBy}
									<span class="notif-creator">• {notification.createdBy}</span>
								{/if}
								{#if isAdminOrMaster && notification.readCount !== undefined}
									<span class="notif-read-stats">• {notification.readCount}/{notification.totalRecipients} read</span>
								{/if}
							</div>
						</div>
						<!-- Action buttons -->
						<div class="notif-actions">
							{#if !notification.read}
								<button class="act-btn" on:click|stopPropagation={() => markAsRead(notification.id)} title="Mark as read">👁️</button>
							{/if}
							{#if isAdminOrMaster}
								<button class="act-btn del" on:click|stopPropagation={() => deleteNotification(notification.id)} title="Delete">🗑️</button>
							{/if}
						</div>
					</div>

					<!-- Message text -->
					<div class="notif-message">
						{#each splitMessageParts(notification.message) as part}
							{#if part.type === 'url'}
								{#if isImageUrl(part.value)}
									<button class="inline-link img-link" on:click|stopPropagation={() => openImageModal(part.value)}>🖼️ View Image</button>
								{:else}
									<a href={part.value} target="_blank" rel="noopener noreferrer" class="inline-link" on:click|stopPropagation>🔗 Open Link</a>
								{/if}
							{:else}
								{part.value}
							{/if}
						{/each}
					</div>

					<!-- Target Users (admin only) -->
					{#if isAdminOrMaster && notification.target_users}
						{@const display = getTargetUsersDisplay(notification)}
						{#if display}
							<div class="notif-targets">
								<span class="targets-icon">👥</span>
								<span class="targets-text">{display}</span>
							</div>
						{/if}
					{/if}

					<!-- Attachments -->
					{#if notification.image_url || (notification.attachments && notification.attachments.length > 0)}
						<div class="notif-attachments">
							{#if notification.image_url}
								<button class="img-thumb" on:click|stopPropagation={() => openImageModal(notification.image_url)} title="View image">
									<img src={notification.image_url} alt="Notification" loading="lazy" on:error={(e) => { e.currentTarget.parentElement.style.display = 'none'; }} />
									<div class="img-overlay">🔍</div>
								</button>
							{/if}
							{#if notification.attachments && notification.attachments.length > 0}
								<div class="file-list">
									<FileDownload
										files={notification.attachments}
										showDetails={false}
										compact={true}
										maxHeight="120px"
									/>
								</div>
							{/if}
						</div>
					{/if}

					<!-- Unread dot -->
					{#if !notification.read}
						<div class="unread-dot"></div>
					{/if}
				</div>
			{/each}

			{#if isLoadingMore}
				<div class="loading-more">
					<div class="spinner small"></div>
					<span>Loading more...</span>
				</div>
			{/if}

			{#if !hasMoreNotifications && filteredNotifications.length > 0}
				<div class="end-message">No more notifications</div>
			{/if}
		</div>
	{/if}
</div>

<!-- Image Modal -->
{#if showImageModal}
	<div class="image-modal-overlay" on:click={closeImageModal}>
		<div class="image-modal-content" on:click|stopPropagation>
			<button class="image-modal-close" on:click={closeImageModal}>✕</button>
			<img src={selectedImageUrl} alt="Full size" />
		</div>
	</div>
{/if}

<style>
	.notification-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
		overflow: hidden;
	}

	/* ── Top Bar ── */
	.top-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: white;
		border-bottom: 1px solid #e2e8f0;
		flex-shrink: 0;
	}

	.top-bar-left {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.top-title {
		font-size: 18px;
		font-weight: 700;
		color: #1e293b;
	}

	.unread-pill {
		background: #ef4444;
		color: white;
		font-size: 11px;
		font-weight: 700;
		padding: 2px 8px;
		border-radius: 10px;
		min-width: 20px;
		text-align: center;
	}

	.top-bar-right {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.icon-btn {
		width: 36px;
		height: 36px;
		border: 1.5px solid #d1d5db;
		border-radius: 8px;
		background: white;
		font-size: 16px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.icon-btn.push-on {
		border-color: #10b981;
		background: #ecfdf5;
	}

	.text-btn {
		padding: 6px 12px;
		font-size: 13px;
		font-weight: 600;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		background: #10b981;
		color: white;
	}

	.text-btn.create {
		background: #3b82f6;
	}

	/* ── Filter Bar ── */
	.filter-bar {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 8px 16px;
		background: white;
		border-bottom: 1px solid #e2e8f0;
		flex-shrink: 0;
	}

	.filter-select {
		flex: 1;
		padding: 6px 10px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 13px;
		background: white;
		color: #374151;
	}

	/* ── Error Bar ── */
	.error-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 16px;
		background: #fef2f2;
		border-bottom: 1px solid #fecaca;
		color: #b91c1c;
		font-size: 13px;
		flex-shrink: 0;
	}

	.error-bar button {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 4px 12px;
		font-size: 12px;
		cursor: pointer;
	}

	/* ── Loading ── */
	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		flex: 1;
		gap: 12px;
		color: #6b7280;
		font-size: 14px;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #10b981;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.spinner.small {
		width: 24px;
		height: 24px;
		border-width: 3px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* ── Empty State ── */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		flex: 1;
		text-align: center;
		color: #6b7280;
		padding: 40px 20px;
	}

	.empty-icon {
		font-size: 48px;
		opacity: 0.4;
		margin-bottom: 12px;
	}

	.empty-state h3 {
		font-size: 18px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 4px;
	}

	.empty-state p {
		font-size: 14px;
		margin: 0;
	}

	/* ── Notification List ── */
	.notification-list {
		flex: 1;
		overflow-y: auto;
		padding: 8px 12px;
		-webkit-overflow-scrolling: touch;
	}

	/* ── Notification Card ── */
	.notif-card {
		position: relative;
		background: white;
		border-radius: 10px;
		border-left: 4px solid #10b981;
		margin-bottom: 8px;
		padding: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
		transition: opacity 0.2s;
	}

	.notif-card.read {
		opacity: 0.7;
		border-left-color: #d1d5db;
		background: #fafafa;
	}

	.notif-card.border-red-500 { border-left-color: #ef4444; }
	.notif-card.border-orange-500 { border-left-color: #f97316; }
	.notif-card.border-yellow-400 { border-left-color: #facc15; }
	.notif-card.border-gray-300 { border-left-color: #d1d5db; }

	.notif-card.unread.border-red-500 { background: #fef2f2; }

	.notif-top {
		display: flex;
		align-items: flex-start;
		gap: 8px;
	}

	.notif-icon {
		font-size: 20px;
		flex-shrink: 0;
		margin-top: 1px;
	}

	.notif-info {
		flex: 1;
		min-width: 0;
	}

	.notif-title {
		font-size: 14px;
		font-weight: 600;
		color: #1e293b;
		line-height: 1.3;
		word-break: break-word;
	}

	.notif-meta {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 4px;
		margin-top: 2px;
		font-size: 11px;
		color: #94a3b8;
	}

	.notif-time {
		color: #64748b;
	}

	.notif-creator {
		color: #10b981;
		font-weight: 500;
	}

	.notif-read-stats {
		color: #3b82f6;
		font-weight: 500;
	}

	.notif-actions {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
	}

	.act-btn {
		width: 32px;
		height: 32px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		background: white;
		font-size: 14px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.act-btn:active {
		background: #f3f4f6;
	}

	.act-btn.del:active {
		background: #fef2f2;
		border-color: #fca5a5;
	}

	/* ── Message ── */
	.notif-message {
		font-size: 13px;
		line-height: 1.5;
		color: #475569;
		margin-top: 6px;
		padding-left: 28px;
		word-break: break-word;
	}

	.inline-link {
		display: inline-flex;
		align-items: center;
		gap: 2px;
		padding: 2px 8px;
		margin: 2px 0;
		background: #eff6ff;
		color: #2563eb;
		font-size: 12px;
		font-weight: 600;
		border-radius: 6px;
		border: 1px solid #bfdbfe;
		text-decoration: none;
		cursor: pointer;
	}

	.inline-link.img-link {
		background: #faf5ff;
		color: #7c3aed;
		border-color: #ddd6fe;
	}

	/* ── Target Users ── */
	.notif-targets {
		display: flex;
		align-items: center;
		gap: 6px;
		padding-left: 28px;
		margin-top: 6px;
		font-size: 12px;
		color: #64748b;
	}

	.targets-text {
		background: #f1f5f9;
		padding: 1px 8px;
		border-radius: 10px;
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	/* ── Attachments ── */
	.notif-attachments {
		margin-top: 8px;
		padding-left: 28px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.img-thumb {
		position: relative;
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		border-radius: 8px;
		overflow: hidden;
		display: inline-block;
		max-width: 200px;
	}

	.img-thumb img {
		max-width: 200px;
		max-height: 140px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
		display: block;
	}

	.img-overlay {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.3);
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		opacity: 0;
		font-size: 24px;
		transition: opacity 0.2s;
	}

	.img-thumb:active .img-overlay {
		opacity: 1;
	}

	.file-list {
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		overflow: hidden;
	}

	.unread-dot {
		position: absolute;
		top: 12px;
		right: 12px;
		width: 8px;
		height: 8px;
		background: #10b981;
		border-radius: 50%;
	}

	/* ── Loading More ── */
	.loading-more {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 16px;
		color: #6b7280;
		font-size: 13px;
	}

	.end-message {
		text-align: center;
		padding: 16px;
		color: #94a3b8;
		font-size: 12px;
	}

	/* ── Image Modal ── */
	.image-modal-overlay {
		position: fixed;
		inset: 0;
		z-index: 100;
		background: rgba(0, 0, 0, 0.85);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 16px;
	}

	.image-modal-content {
		position: relative;
		max-width: 100%;
		max-height: 100%;
	}

	.image-modal-content img {
		max-width: 100%;
		max-height: 85vh;
		object-fit: contain;
		border-radius: 8px;
	}

	.image-modal-close {
		position: absolute;
		top: -12px;
		right: -12px;
		width: 32px;
		height: 32px;
		background: white;
		border: none;
		border-radius: 50%;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
		display: flex;
		align-items: center;
		justify-content: center;
	}
</style>
