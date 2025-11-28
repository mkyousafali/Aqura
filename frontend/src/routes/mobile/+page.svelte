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
	
	// Punch/Fingerprint Data - Store last 2 punches
	let punches = {
		records: [],
		loading: false,
		error: ''
	};
	
	// Branch Performance Stats
	let branchPerformance = {
		branches: [],
		todayStats: [],
		yesterdayStats: [],
		loading: false
	};
	
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
			await loadBranchPerformance();
			await loadRecentPunches();
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

	async function loadRecentPunches() {
		try {
			punches.loading = true;
			punches.error = '';
			
			if (!currentUserData?.employee_id) {
				console.log('⚠️ User has no employee_id, skipping punch data load');
				punches.loading = false;
				return;
			}
			
			// Query hr_fingerprint_transactions for last 2 punches
			// Note: employee_id is stored as varchar in hr_fingerprint_transactions, but users.employee_id is UUID
			// We need to get the actual employee_id from hr_employees table using the UUID
			const { data: empData, error: empError } = await supabase
				.from('hr_employees')
				.select('employee_id')
				.eq('id', currentUserData.employee_id)
				.single();
			
			if (empError || !empData?.employee_id) {
				console.log('⚠️ Could not find employee_id for user');
				punches.loading = false;
				return;
			}
			
			// Now query fingerprint transactions using the varchar employee_id - get last 2 records
			const { data, error } = await supabase
				.from('hr_fingerprint_transactions')
				.select('date, time, status, branch_id, created_at')
				.eq('employee_id', empData.employee_id)
				.order('created_at', { ascending: false })
				.limit(2);
			
			if (error) {
				if (error.code === 'PGRST116') {
					// No rows returned - user has no punch records yet
					console.log('ℹ️ No punch records found for user');
				} else {
					console.error('❌ Error loading punch data:', error);
					punches.error = 'Failed to load punch data';
				}
			} else if (data && data.length > 0) {
				// Process each punch record
				punches.records = data.map(record => {
					// Combine date and time
					// The time stored in hr_fingerprint_transactions is in Saudi timezone (UTC+3)
					// We need to convert it to UTC by subtracting 3 hours
					const saudiDate = new Date(`${record.date}T${record.time}`);
					// Convert from Saudi time (UTC+3) to UTC by subtracting 3 hours
					const utcTime = new Date(saudiDate.getTime() - (3 * 60 * 60 * 1000));
					return {
						time: utcTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
						date: utcTime.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }),
						status: record.status?.toLowerCase().includes('in') ? 'check-in' : 'check-out'
					};
				});
				console.log('✅ Recent punches loaded:', punches.records);
			}
		} catch (error) {
			console.error('Error loading recent punches:', error);
			punches.error = 'Error loading punch data';
		} finally {
			punches.loading = false;
		}
	}

	async function loadBranchPerformance() {
		branchPerformance.loading = true;
		try {
			// Load branches first ordered by ID
			const { data: branchesData, error: branchError } = await supabase
				.from('branches')
				.select('id, name_ar, name_en')
				.order('id', { ascending: true });

			if (branchError) throw branchError;

			let branches = (branchesData || []).map(b => ({
				id: b.id,
				name: $localeData.locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar)
			}));

			// Sort: user's branch first, then rest by ID
			if (currentUserData?.branchId) {
				const userBranchId = currentUserData.branchId;
				branches.sort((a, b) => {
					if (a.id === userBranchId) return -1;
					if (b.id === userBranchId) return 1;
					return a.id - b.id;
				});
			}

			branchPerformance.branches = branches;

			const today = new Date().toISOString().split('T')[0];
			const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

			// Fetch all branch data in PARALLEL (not sequential)
			const allStatsPromises = branchPerformance.branches.map(branch =>
				Promise.all([
					fetchAllTasksForDay(today, branch.id),
					fetchAllTasksForDay(yesterday, branch.id)
				]).then(([todayData, yesterdayData]) => ({
					today: {
						branchId: branch.id,
						branchName: branch.name,
						completed: todayData.completed,
						notCompleted: todayData.notCompleted,
						total: todayData.completed + todayData.notCompleted
					},
					yesterday: {
						branchId: branch.id,
						branchName: branch.name,
						completed: yesterdayData.completed,
						notCompleted: yesterdayData.notCompleted,
						total: yesterdayData.completed + yesterdayData.notCompleted
					}
				}))
			);

			const allStats = await Promise.all(allStatsPromises);
			branchPerformance.todayStats = allStats.map(s => s.today);
			branchPerformance.yesterdayStats = allStats.map(s => s.yesterday);

		} catch (error) {
			console.error('Error loading branch performance:', error);
		} finally {
			branchPerformance.loading = false;
		}
	}

	async function fetchAllTasksForDay(date, branchId) {
		const BATCH_SIZE = 1000;
		let completed = 0;
		let notCompleted = 0;

		// Fetch receiving tasks with pagination (filter by branch at DB level)
		let receivingFrom = 0;
		let hasMoreReceiving = true;
		while (hasMoreReceiving) {
			const { data, error } = await supabase
				.from('receiving_tasks')
				.select('task_status, receiving_record:receiving_records!receiving_tasks_receiving_record_id_fkey(branch_id)')
				.gte('created_at', date)
				.lt('created_at', date + 'T23:59:59')
				.range(receivingFrom, receivingFrom + BATCH_SIZE - 1);

			if (error) {
				console.error('Error fetching receiving tasks:', error);
				break;
			}

			if (data && data.length > 0) {
				data.forEach(task => {
					// Filter by branch in memory
					if (task.receiving_record && task.receiving_record.branch_id === branchId) {
						if (task.task_status === 'completed') {
							completed++;
						} else if (task.task_status !== 'cancelled') {
							notCompleted++;
						}
					}
				});
				receivingFrom += BATCH_SIZE;
				hasMoreReceiving = data.length === BATCH_SIZE;
			} else {
				hasMoreReceiving = false;
			}
		}

		// Fetch task assignments with pagination (filter by branch at DB level)
		let taskAssignFrom = 0;
		let hasMoreTaskAssign = true;
		while (hasMoreTaskAssign) {
			const { data, error } = await supabase
				.from('task_assignments')
				.select('status, assigned_to_branch_id')
				.eq('assigned_to_branch_id', branchId)
				.gte('assigned_at', date)
				.lt('assigned_at', date + 'T23:59:59')
				.range(taskAssignFrom, taskAssignFrom + BATCH_SIZE - 1);

			if (error) {
				console.error('Error fetching task assignments:', error);
				break;
			}

			if (data && data.length > 0) {
				data.forEach(task => {
					if (task.status === 'completed') {
						completed++;
					} else if (task.status !== 'cancelled') {
						notCompleted++;
					}
				});
				taskAssignFrom += BATCH_SIZE;
				hasMoreTaskAssign = data.length === BATCH_SIZE;
			} else {
				hasMoreTaskAssign = false;
			}
		}

		// Fetch quick task assignments with pagination (filter by branch at DB level)
		let quickTaskFrom = 0;
		let hasMoreQuickTask = true;
		while (hasMoreQuickTask) {
			const { data, error } = await supabase
				.from('quick_task_assignments')
				.select('status, quick_task:quick_tasks!quick_task_assignments_quick_task_id_fkey(assigned_to_branch_id)')
				.gte('created_at', date)
				.lt('created_at', date + 'T23:59:59')
				.range(quickTaskFrom, quickTaskFrom + BATCH_SIZE - 1);

			if (error) {
				console.error('Error fetching quick tasks:', error);
				break;
			}

			if (data && data.length > 0) {
				data.forEach(task => {
					// Filter by branch in memory
					if (task.quick_task && task.quick_task.assigned_to_branch_id === branchId) {
						if (task.status === 'completed') {
							completed++;
						} else if (task.status !== 'cancelled') {
							notCompleted++;
						}
					}
				});
				quickTaskFrom += BATCH_SIZE;
				hasMoreQuickTask = data.length === BATCH_SIZE;
			} else {
				hasMoreQuickTask = false;
			}
		}

		return { completed, notCompleted };
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
			<div class="stat-card punch">
				<div class="stat-icon">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<polyline points="12,6 12,12 16,14"/>
					</svg>
				</div>
				<div class="stat-info">
					{#if punches.loading}
						<div class="loading-text">Loading...</div>
					{:else if punches.error}
						<h3 style="color: #ef4444;">—</h3>
						<p>{punches.error}</p>
					{:else if punches.records.length > 0}
						<div class="punch-detail">
							<h3>{punches.records[0].time}</h3>
							<p class="punch-date">{punches.records[0].date}</p>
							<p class="punch-status" class:checkin={punches.records[0].status === 'check-in'} class:checkout={punches.records[0].status === 'check-out'}>
								{punches.records[0].status === 'check-in' ? getTranslation('mobile.dashboardContent.stats.checkIn') : getTranslation('mobile.dashboardContent.stats.checkOut')}
							</p>
						</div>
					{:else}
						<h3>—</h3>
						<p>{getTranslation('mobile.dashboardContent.stats.noPunch')}</p>
					{/if}
				</div>
			</div>
			{#if punches.records.length > 1}
				<div class="stat-card punch">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<polyline points="12,6 12,12 16,14"/>
						</svg>
					</div>
					<div class="stat-info">
						<div class="punch-detail">
							<h3>{punches.records[1].time}</h3>
							<p class="punch-date">{punches.records[1].date}</p>
							<p class="punch-status" class:checkin={punches.records[1].status === 'check-in'} class:checkout={punches.records[1].status === 'check-out'}>
								{punches.records[1].status === 'check-in' ? getTranslation('mobile.dashboardContent.stats.checkIn') : getTranslation('mobile.dashboardContent.stats.checkOut')}
							</p>
						</div>
					</div>
				</div>
			{/if}
		</div>
	</section>

	<!-- Branch Performance Section -->
	<section class="performance-section">
		<div class="section-header">
			<h2>Branch Performance</h2>
			<button class="refresh-btn" on:click={loadBranchPerformance} disabled={branchPerformance.loading}>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>

		{#if branchPerformance.loading}
			<div class="performance-loading">
				<div class="loading-spinner-small"></div>
				<p>Loading performance data...</p>
			</div>
		{:else}
			<!-- Today's Performance -->
			<div class="performance-group">
				<h3 class="group-title">Today's Performance</h3>
				<div class="branch-grid">
					{#each branchPerformance.todayStats as stat}
						<div class="branch-card">
							<h4 class="branch-name">{stat.branchName}</h4>
							<div class="pie-chart-container">
								<svg viewBox="0 0 100 100" class="pie-chart">
									{#if stat.total > 0}
										{@const completedPercent = (stat.completed / stat.total) * 100}
										{@const radius = 40}
										{@const circumference = 2 * Math.PI * radius}
										{@const completedOffset = circumference - (completedPercent / 100) * circumference}
										
										<!-- Background circle (not completed) -->
										<circle cx="50" cy="50" r="40" fill="none" stroke="#FCA5A5" stroke-width="20"/>
										
										<!-- Completed arc -->
										{#if completedPercent > 0}
											<circle 
												cx="50" 
												cy="50" 
												r="40" 
												fill="none" 
												stroke="#10B981" 
												stroke-width="20"
												stroke-dasharray={circumference}
												stroke-dashoffset={completedOffset}
												transform="rotate(-90 50 50)"
											/>
										{/if}
										
										<!-- Center text -->
										<text x="50" y="47" text-anchor="middle" class="pie-percent">{completedPercent.toFixed(0)}%</text>
										<text x="50" y="58" text-anchor="middle" class="pie-label">Complete</text>
									{:else}
										<circle cx="50" cy="50" r="40" fill="none" stroke="#E5E7EB" stroke-width="20"/>
										<text x="50" y="53" text-anchor="middle" class="pie-empty">No Tasks</text>
									{/if}
								</svg>
							</div>
							<div class="branch-stats">
								<div class="stat-item completed">
									<span class="stat-dot"></span>
									<span>{stat.completed} Completed</span>
								</div>
								<div class="stat-item pending">
									<span class="stat-dot"></span>
									<span>{stat.notCompleted} Pending</span>
								</div>
								<div class="stat-item total">
									<span>Total: {stat.total}</span>
								</div>
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Yesterday's Performance -->
			<div class="performance-group">
				<h3 class="group-title">Yesterday's Performance</h3>
				<div class="branch-grid">
					{#each branchPerformance.yesterdayStats as stat}
						<div class="branch-card">
							<h4 class="branch-name">{stat.branchName}</h4>
							<div class="pie-chart-container">
								<svg viewBox="0 0 100 100" class="pie-chart">
									{#if stat.total > 0}
										{@const completedPercent = (stat.completed / stat.total) * 100}
										{@const radius = 40}
										{@const circumference = 2 * Math.PI * radius}
										{@const completedOffset = circumference - (completedPercent / 100) * circumference}
										
										<!-- Background circle (not completed) -->
										<circle cx="50" cy="50" r="40" fill="none" stroke="#FCA5A5" stroke-width="20"/>
										
										<!-- Completed arc -->
										{#if completedPercent > 0}
											<circle 
												cx="50" 
												cy="50" 
												r="40" 
												fill="none" 
												stroke="#F59E0B" 
												stroke-width="20"
												stroke-dasharray={circumference}
												stroke-dashoffset={completedOffset}
												transform="rotate(-90 50 50)"
											/>
										{/if}
										
										<!-- Center text -->
										<text x="50" y="47" text-anchor="middle" class="pie-percent">{completedPercent.toFixed(0)}%</text>
										<text x="50" y="58" text-anchor="middle" class="pie-label">Complete</text>
									{:else}
										<circle cx="50" cy="50" r="40" fill="none" stroke="#E5E7EB" stroke-width="20"/>
										<text x="50" y="53" text-anchor="middle" class="pie-empty">No Tasks</text>
									{/if}
								</svg>
							</div>
							<div class="branch-stats">
								<div class="stat-item completed">
									<span class="stat-dot"></span>
									<span>{stat.completed} Completed</span>
								</div>
								<div class="stat-item pending">
									<span class="stat-dot"></span>
									<span>{stat.notCompleted} Pending</span>
								</div>
								<div class="stat-item total">
									<span>Total: {stat.total}</span>
								</div>
							</div>
						</div>
					{/each}
				</div>
			</div>
		{/if}
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
		border-radius: 8px;
		padding: 0.6rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 0.4rem;
		transition: all 0.3s ease;
		text-decoration: none;
		color: inherit;
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
	.stat-card.date-time .stat-icon {
		background: rgba(139, 92, 246, 0.1);
		color: #8B5CF6;
	}
	.stat-card.pending .stat-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}
	.stat-card.performance .stat-icon {
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
	.stat-card.punch .stat-icon {
		background: rgba(239, 68, 68, 0.1);
		color: #EF4444;
	}
	.stat-info h3 {
		font-size: 1rem;
		font-weight: 700;
		margin: 0 0 0.1rem 0;
		color: #1F2937;
	}
	.stat-info p {
		font-size: 0.625rem;
		color: #6B7280;
		margin: 0;
	}
	.punch-detail {
		width: 100%;
	}
	.punch-date {
		font-size: 0.5rem;
		color: #9CA3AF;
		margin-top: 0.2rem;
	}
	.punch-status {
		font-size: 0.5rem;
		margin-top: 0.2rem;
		font-weight: 600;
		text-transform: capitalize;
	}
	.punch-status.checkin {
		color: #10B981;
	}
	.punch-status.checkout {
		color: #EF4444;
	}
	.loading-text {
		font-size: 0.625rem;
		color: #6B7280;
	}

	/* Branch Performance Section */
	.performance-section {
		padding: 0 1.2rem 1.2rem 1.2rem;
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0;
	}

	.refresh-btn {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		padding: 0.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover {
		background: #F3F4F6;
		border-color: #D1D5DB;
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.refresh-btn svg {
		color: #6B7280;
	}

	.performance-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		background: white;
		border-radius: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.performance-loading p {
		color: #6B7280;
		font-size: 0.875rem;
		margin: 0;
	}

	.performance-group {
		margin-bottom: 1.5rem;
	}

	.group-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1rem 0;
		padding: 0.5rem 0.75rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.branch-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}

	.branch-name {
		font-size: 0.625rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		text-align: center;
	}

	.pie-chart-container {
		width: 100%;
		height: 140px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.pie-chart {
		width: 100%;
		height: 100%;
		max-width: 150px;
		max-height: 150px;
	}

	.pie-percent {
		font-size: 10px;
		font-weight: 700;
		fill: #1F2937;
	}

	.pie-label {
		font-size: 6px;
		fill: #6B7280;
	}

	.pie-empty {
		font-size: 7px;
		fill: #9CA3AF;
	}

	.branch-stats {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.5rem;
		color: #6B7280;
	}

	.stat-item.completed .stat-dot {
		background: #10B981;
	}

	.stat-item.pending .stat-dot {
		background: #FCA5A5;
	}

	.stat-item.total {
		font-weight: 600;
		color: #1F2937;
		padding-top: 0.5rem;
		border-top: 1px solid #E5E7EB;
		justify-content: center;
	}

	.stat-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
	}

	@media (max-width: 480px) {
		.branch-grid {
			grid-template-columns: 1fr;
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
</style>



