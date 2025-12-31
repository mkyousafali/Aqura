<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { dataService } from '$lib/utils/dataService';
	import { realtimeService } from '$lib/utils/realtimeService';
	// import { goAPI } from '$lib/utils/goAPI'; // Removed - Go backend no longer used
	import { localeData } from '$lib/i18n';
	
	let currentUserData = null;
	let stats = {
		pendingTasks: 0
	};
	let isLoading = true;
	let currentTime = new Date();
	let unsubscribeFingerprint: (() => void) | null = null;
	let employeeCode: string | null = null; // Store employee code for realtime subscription
	
	// Computed formatted time and date based on current locale
	$: formattedTime = currentTime.toLocaleTimeString($localeData.code === 'ar' ? 'ar-SA' : 'en-US', { hour: '2-digit', minute: '2-digit' });
	$: formattedDate = currentTime.toLocaleDateString($localeData.code === 'ar' ? 'ar-SA' : 'en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
	
	// Punch/Fingerprint Data - Store last 2 punches
	let punches = {
		records: [],
		loading: false,
		error: ''
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
			// Load dashboard data from Go backend (combines tasks + punches)
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
			if (unsubscribeFingerprint) {
				console.log('🔌 Cleaning up fingerprint realtime subscription');
				unsubscribeFingerprint();
			}
		};
	});
	
	onDestroy(() => {
		if (unsubscribeFingerprint) {
			unsubscribeFingerprint();
		}
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
			const startTime = performance.now();
			console.log('🔍 Loading mobile dashboard from Supabase...');
			
			// Step 1: Get current user's UUID
			const userUuid = currentUserData?.id;
			console.log('👤 Step 1 - Current user UUID:', userUuid);
			
			if (!userUuid) {
				console.warn('⚠️ Current user UUID not found');
				punches = {
					records: [],
					loading: false,
					error: 'User ID not found'
				};
				return;
			}
			
			// Step 2: Look up user record to get employee_id field from users table
			console.log('🔍 Step 2 - Looking up user record in users table...');
			const { data: userRecord, error: userError } = await supabase
				.from('users')
				.select('id, employee_id')
				.eq('id', userUuid)
				.single();
			
			if (userError || !userRecord) {
				console.warn('⚠️ User record not found:', userError);
				punches = {
					records: [],
					loading: false,
					error: 'User record not found'
				};
				return;
			}
			
			const employeeUuid = userRecord.employee_id;
			console.log('👥 Step 2 - User employee_id (UUID):', employeeUuid);
			
			if (!employeeUuid) {
				console.warn('⚠️ Employee ID not linked to user');
				punches = {
					records: [],
					loading: false,
					error: 'Employee not linked to user account'
				};
				return;
			}
			
			// Step 3: Look up hr_employees to get employee_id code
			console.log('🔍 Step 3 - Looking up employee record...');
			const { data: employeeRecord, error: empError } = await supabase
				.from('hr_employees')
				.select('id, employee_id')
				.eq('id', employeeUuid)
				.single();
			
			if (empError || !employeeRecord) {
				console.warn('⚠️ Employee record not found:', empError);
				punches = {
					records: [],
					loading: false,
					error: 'Employee record not found'
				};
				return;
			}
			
			const employeeCode = employeeRecord.employee_id;
			console.log('🎯 Step 3 - Found employee_id (code):', employeeCode);
			
			// Step 4: Get today's date
			const today = new Date().toISOString().split('T')[0];
			console.log('📅 Step 4 - Today\'s date:', today);
			
			// Step 5: Search hr_fingerprint_transactions for:
			// - employee_id = employeeCode
			// - date = today
			// - order by time descending
			console.log('🔍 Step 5 - Searching fingerprint transactions...');
			const { data: punchData, error: punchError } = await supabase
				.from('hr_fingerprint_transactions')
				.select('*')
				.eq('employee_id', employeeCode)
				.eq('date', today)
				.order('time', { ascending: false });
			
			console.log('📊 Step 5 - Punch data:', punchData);
			console.log('❌ Step 5 - Error:', punchError);
			
			if (punchError) {
				console.error('Error loading punches:', punchError);
				punches = {
					records: [],
					loading: false,
					error: punchError.message
				};
				return;
			}
			
			// Step 6: Get latest 2 and display
			if (punchData && punchData.length > 0) {
				console.log('✅ Step 6 - Found', punchData.length, 'punch records');
				
				const punchRecords = punchData
					.slice(0, 2) // Get last 2 punches (already sorted by time DESC)
					.map(punch => {
						// Convert time to 12-hour format
						let formattedTime = punch.time || '';
						if (formattedTime) {
							try {
								// Parse time string (HH:MM:SS or HH:MM)
								const [hours, minutes] = formattedTime.split(':').slice(0, 2);
								const hour = parseInt(hours, 10);
								const minute = minutes || '00';
								const ampm = hour >= 12 ? 'PM' : 'AM';
								const hour12 = hour % 12 || 12;
								formattedTime = `${hour12.toString().padStart(2, '0')}:${minute} ${ampm}`;
							} catch (e) {
								console.error('Error formatting time:', e);
							}
						}
						
						// Map database columns to display format
						const mappedPunch = {
							time: formattedTime,
							date: punch.date || '',
							status: punch.status === 'Check In' ? 'check-in' : 'check-out',
							raw: punch
						};
						console.log('📍 Mapped punch:', mappedPunch);
						return mappedPunch;
					});
				
				console.log('✅ Step 6 - Displaying', punchRecords.length, 'punch records');
				punches = {
					records: punchRecords,
					loading: false,
					error: ''
				};
			} else {
				console.log('ℹ️ Step 6 - No punch records found');
				punches = {
					records: [],
					loading: false,
					error: ''
				};
			}
			
			// Step 7: Setup real-time subscription for this employee's punches
			console.log('📡 Step 7 - Setting up real-time subscription for employee:', employeeCode);
			if (unsubscribeFingerprint) {
				console.log('🔌 Cleaning up previous subscription');
				unsubscribeFingerprint();
			}
			
			unsubscribeFingerprint = realtimeService.subscribeToEmployeeFingerprintChanges(
				employeeCode,
				(payload) => {
					console.log('🔔 Real-time punch update received:', payload);
					
					// Only process changes for today
					const today = new Date().toISOString().split('T')[0];
					const punchDate = payload.new?.date || payload.old?.date;
					
					if (punchDate !== today) {
						console.log('⏭️ Punch is not for today, skipping');
						return;
					}
					
					if (payload.eventType === 'INSERT') {
						// New punch record - format and add to display
						const newPunch = payload.new;
						let formattedTime = newPunch.time || '';
						
						if (formattedTime) {
							try {
								const [hours, minutes] = formattedTime.split(':').slice(0, 2);
								const hour = parseInt(hours, 10);
								const minute = minutes || '00';
								const ampm = hour >= 12 ? 'PM' : 'AM';
								const hour12 = hour % 12 || 12;
								formattedTime = `${hour12.toString().padStart(2, '0')}:${minute} ${ampm}`;
							} catch (e) {
								console.error('Error formatting realtime punch time:', e);
							}
						}
						
						const mappedNewPunch = {
							time: formattedTime,
							date: newPunch.date || '',
							status: newPunch.status === 'Check In' ? 'check-in' : 'check-out',
							raw: newPunch
						};
						
						// Add to beginning of list and keep only last 2
						punches.records = [mappedNewPunch, ...punches.records].slice(0, 2);
						console.log('✅ Punch list updated in real-time:', punches.records);
					}
				}
			);
			
			console.log('✅ Real-time subscription set up successfully');
			
			// Set pending tasks to 0 for now (TODO: implement task loading)
			stats.pendingTasks = 0;
			
			const endTime = performance.now();
			console.log(`✅ Dashboard loaded in ${(endTime - startTime).toFixed(2)}ms`);
			
		} catch (error) {
			console.error('Error loading dashboard data:', error);
			punches = {
				records: [],
				loading: false,
				error: error instanceof Error ? error.message : 'Failed to load punch data'
			};
		}
	}

	// Helper function to get proper file URL
	function getFileUrl(attachment) {
		const baseUrl = 'https://supabase.urbanaqura.com/storage/v1/object/public';
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
			<p>{getTranslation('mobile.dashboardContent.branchPerformance.loadingDashboard')}</p>
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
					<h3>{formattedTime}</h3>
					<p>{formattedDate}</p>
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




