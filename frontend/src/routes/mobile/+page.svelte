<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';
	
	let currentUserData = null;
	let stats = {
		pendingTasks: 0
	};
	let isLoading = true;
	let currentTime = new Date();
	
	// Update time every second
	let timeInterval: ReturnType<typeof setInterval>;
	// Computed role check
	$: userRole = currentUserData?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';
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
		
		// Update time every second
		timeInterval = setInterval(() => {
			currentTime = new Date();
		}, 1000);
		
		// Cleanup on destroy
		return () => {
			if (timeInterval) clearInterval(timeInterval);
		};
	});
	function handleViewOffer(event: CustomEvent) {
		selectedOffer = event.detail;
		showOfferModal = true;
	}

	function closeOfferModal() {
		showOfferModal = false;
		selectedOffer = null;
	}
	async function loadDashboardData() {
		try {
			console.log('🔍 Loading mobile dashboard stats (optimized for speed)...');
			// Optimized: Load only counts in parallel, no joins, filter at database level
		const [taskAssignmentsResult, quickTaskAssignmentsResult, receivingTasksResult] = await Promise.all([
				// Count pending regular tasks only (no joins, no data fetching)
				supabase
					.from('task_assignments')
					.select('status', { count: 'exact', head: false })
					.eq('assigned_to_user_id', currentUserData.id)
					.not('status', 'in', '(completed,cancelled)'),
				// Count pending quick tasks only
				supabase
					.from('quick_task_assignments')
					.select('status', { count: 'exact', head: false })
					.eq('assigned_to_user_id', currentUserData.id)
					.not('status', 'in', '(completed,cancelled)'),
				// Count pending receiving tasks only
				supabase
					.from('receiving_tasks')
					.select('task_status', { count: 'exact', head: false })
					.eq('assigned_user_id', currentUserData.id)
					.not('task_status', 'in', '(completed,cancelled)')
			]);
			
			// Calculate pending tasks from counts
			const taskCount = taskAssignmentsResult.count || 0;
			const quickTaskCount = quickTaskAssignmentsResult.count || 0;
			const receivingTaskCount = receivingTasksResult.count || 0;
			
			stats.pendingTasks = taskCount + quickTaskCount + receivingTaskCount;
			
		} catch (error) {
			console.error('Error loading dashboard data:', error);
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
			<div class="stat-card date-time">
				<div class="stat-icon">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
						<line x1="16" y1="2" x2="16" y2="6"/>
						<line x1="8" y1="2" x2="8" y2="6"/>
						<line x1="3" y1="10" x2="21" y2="10"/>
					</svg>
				</div>
				<div class="stat-info">
					<h3>{currentTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}</h3>
					<p>{currentTime.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })}</p>
				</div>
			</div>
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
		</div>
	</section>
	{/if}
</div>

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

	/* Featured Offers LED Screen - Top Section */
	.offers-section.led-screen {
		padding: 0;
		margin: 0;
		background: linear-gradient(180deg, #000000 0%, #1a1a1a 100%);
		min-height: 180px;
	}

	.offers-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		color: #9CA3AF;
	}

	.loading-spinner-small {
		width: 24px;
		height: 24px;
		border: 3px solid rgba(255, 255, 255, 0.2);
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.offers-loading p {
		margin: 0;
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.no-offers-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		text-align: center;
		color: rgba(255, 255, 255, 0.7);
	}

	.no-offers-message .offer-icon {
		font-size: 3rem;
		margin-bottom: 0.75rem;
		opacity: 0.5;
	}

	.no-offers-message p {
		margin: 0 0 0.5rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
	}

	.no-offers-message small {
		font-size: 0.8125rem;
		color: rgba(255, 255, 255, 0.5);
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
</style>



