<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';
	import { realtimeService } from '$lib/utils/realtimeService';
	import { t, isRTL, currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import BiometricExport from '$lib/components/desktop-interface/master/hr/BiometricExport.svelte';

	let totalPresentToday = 0;
	let branchBreakdown = [];
	let allTransactions = [];
	let employeeMap = new Map(); // Map to store employee data by id
	let branchMap = new Map(); // Map to store branch data by id
	let positionMap = new Map(); // Map to store employee positions by employee UUID id
	let allBranches = []; // Store all branches for filter dropdown
	let allDates = []; // Store all unique dates for filter dropdown
	let biometricConnections = []; // Store biometric connection sync status
	let loading = true;
	let loadingProgress = 0; // 0-100
	let loadingStatus = ''; // Current loading status message
	let refreshingSyncStatus = false;
	let error = '';
	let unsubscribeFingerprint: (() => void) | null = null;
	
	// Data loading mode
	let loadingMode = 'today'; // 'today', 'specific', 'range', 'all'
	let specificDate = '';
	let startDate = '';
	let endDate = '';
	
	// Filter state
	let selectedBranch = ''; // Empty string means "All"
	let selectedDate = ''; // Empty string means "All"
	let filteredTransactions = [];
	
	// Search state
	let searchQuery = '';
	let searchType = 'employee-id'; // 'employee-id' or 'name'

	onMount(async () => {
		await loadData();
		setupRealtimeSubscription();
	});
	
	onDestroy(() => {
		if (unsubscribeFingerprint) {
			console.log('🔌 Cleaning up biometric realtime subscription');
			unsubscribeFingerprint();
		}
	});

	async function loadData() {
		try {
			loading = true;
			error = '';
			console.time('⏱️ BiometricData loadData');

			// Get today's date upfront
			const today = new Date().toISOString().split('T')[0];

			// Load all independent data in parallel instead of sequentially
			console.log('📥 Starting parallel data load for:', loadingMode);
			
			// Always load today's data by default (fast path)
			const fingerprintPromise = supabase
				.from('hr_fingerprint_transactions')
				.select('*')
				.eq('date', today)
				.order('time', { ascending: false });

			// Execute all queries in parallel directly to Supabase (no dataService overhead)
			const [employeesRes, branchesRes, positionsRes, fingerprintRes] = await Promise.all([
				supabase.from('hr_employees').select('id, employee_id, branch_id, name').order('employee_id'),
				supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar'),
				supabase.from('hr_position_assignments').select('employee_id, position:position_id(position_title_en, position_title_ar)').eq('is_current', true),
				fingerprintPromise
			]);

			// Also load biometric connections in parallel (non-blocking)
			loadBiometricConnections().catch(err => console.error('Error loading biometric connections:', err));

			// Process employees
			const employees = employeesRes.data || [];
			const empError = employeesRes.error;
			if (empError) {
				console.error('Failed to load employees:', empError);
			} else {
				console.log(`✅ Loaded ${employees.length} employees`);
				employees.forEach(emp => {
					const compositeKey = `${emp.employee_id}_${emp.branch_id}`;
					employeeMap.set(compositeKey, emp);
				});
			}

			// Process branches
			const branches = branchesRes.data || [];
			const branchError = branchesRes.error;
			if (branchError) {
				console.error('Failed to load branches:', branchError);
			} else {
				console.log(`✅ Loaded ${branches.length} branches`);
				branches.forEach(branch => {
					branchMap.set(branch.id, branch);
				});
			}

			// Process position assignments
			const positionAssignments = positionsRes.data || [];
			const posError = positionsRes.error;
			if (posError) {
				console.error('Failed to load position assignments:', posError);
			} else {
				console.log(`✅ Loaded ${positionAssignments.length} position assignments`);
				positionAssignments.forEach(assignment => {
					if (assignment.employee_id && assignment.position) {
						positionMap.set(assignment.employee_id, {
							en: assignment.position.position_title_en || 'N/A',
							ar: assignment.position.position_title_ar || 'N/A'
						});
					}
				});
			}

			// Process fingerprint data
			const data = fingerprintRes.data || [];
			const fetchError = fingerprintRes.error;
			
			if (fetchError) {
				console.error('Failed to load fingerprint data:', fetchError);
				error = 'Failed to load fingerprint data';
				console.timeEnd('⏱️ BiometricData loadData');
				return;
			}

			if (!data || data.length === 0) {
				console.log('ℹ️ No fingerprint data found');
				totalPresentToday = 0;
				branchBreakdown = [];
				allTransactions = [];
				console.timeEnd('⏱️ BiometricData loadData');
				return;
			}

			console.log(`✅ Loaded ${data.length} fingerprint transactions`);

			// Store all transactions sorted by date and time (latest first)
			allTransactions = data.sort((a, b) => {
				const dateCompare = new Date(b.date).getTime() - new Date(a.date).getTime();
				if (dateCompare !== 0) return dateCompare;
				return b.time.localeCompare(a.time);
			});

			// Filter for today's transactions
			const todayTransactions = data.filter(transaction => transaction.date === today);

			if (todayTransactions.length === 0) {
				totalPresentToday = 0;
				branchBreakdown = [];
				console.log('ℹ️ No transactions for today');
				console.timeEnd('⏱️ BiometricData loadData');
				return;
			}

			// Count unique employees present today and build branch stats
			const uniqueEmployees = new Set();
			const branchStatsMap = new Map();

			todayTransactions.forEach(transaction => {
				const status = transaction.status;
				
				if (status === 'Check In') {
					uniqueEmployees.add(transaction.employee_id);
				}

				// Build branch breakdown
				if (!branchStatsMap.has(transaction.branch_id)) {
					branchStatsMap.set(transaction.branch_id, {
						branchId: transaction.branch_id,
						location: transaction.location,
						checkIns: 0,
						checkOuts: 0,
						uniqueEmployees: new Set()
					});
				}

				const branch = branchStatsMap.get(transaction.branch_id);
				if (status === 'Check In') {
					branch.checkIns++;
					branch.uniqueEmployees.add(transaction.employee_id);
				} else if (status === 'Check Out') {
					branch.checkOuts++;
				}
			});

			totalPresentToday = uniqueEmployees.size;

			// Convert to array and sort
			branchBreakdown = Array.from(branchStatsMap.values())
				.map(branch => ({
					...branch,
					uniqueEmployees: branch.uniqueEmployees.size
				}))
				.sort((a, b) => b.uniqueEmployees - a.uniqueEmployees);

			console.timeEnd('⏱️ BiometricData loadData');

		} catch (err) {
			console.error('Error loading data:', err);
			error = 'Error loading fingerprint data';
		} finally {
			loading = false;
			// Extract unique dates and branches after data is loaded
			extractUniqueValues();
			applyFilters();
		}
	}

	function setupRealtimeSubscription() {
		console.log('📡 Setting up real-time subscription for biometric data...');
		
		// Get today's date for filtering
		const today = new Date().toISOString().split('T')[0];
		
		// Unsubscribe from previous subscription if exists
		if (unsubscribeFingerprint) {
			console.log('🔌 Cleaning up previous subscription');
			unsubscribeFingerprint();
		}
		
		// Subscribe based on loading mode
		if (loadingMode === 'today') {
			// For today's data, subscribe to today's date only
			unsubscribeFingerprint = realtimeService.subscribeToDateFingerprintChanges(
				today,
				handleRealtimeUpdate
			);
		} else {
			// For other modes, subscribe to all changes
			unsubscribeFingerprint = realtimeService.subscribeToFingerprintChanges(
				handleRealtimeUpdate
			);
		}
	}

	function handleRealtimeUpdate(payload) {
		console.log('🔔 Real-time biometric data update received:', payload);
		
		const eventType = payload.eventType;
		const newData = payload.new;
		const oldData = payload.old;
		
		if (eventType === 'INSERT') {
			// Add new punch record
			allTransactions = [newData, ...allTransactions].sort((a, b) => {
				const dateCompare = new Date(b.date).getTime() - new Date(a.date).getTime();
				if (dateCompare !== 0) return dateCompare;
				return b.time.localeCompare(a.time);
			});
			
			console.log('✅ New punch added in real-time. Total records:', allTransactions.length);
			
			// Re-extract unique values and apply filters
			extractUniqueValues();
			applyFilters();
			
			// Update today's statistics if the new record is for today
			const today = new Date().toISOString().split('T')[0];
			if (newData.date === today) {
				updateTodayStatistics();
			}
		} else if (eventType === 'UPDATE') {
			// Update existing record
			const index = allTransactions.findIndex(t => t.id === newData.id);
			if (index !== -1) {
				allTransactions[index] = newData;
				console.log('✅ Punch updated in real-time at index:', index);
				applyFilters();
			}
		} else if (eventType === 'DELETE') {
			// Remove deleted record
			allTransactions = allTransactions.filter(t => t.id !== oldData.id);
			console.log('✅ Punch removed in real-time. Total records:', allTransactions.length);
			extractUniqueValues();
			applyFilters();
		}
	}

	function updateTodayStatistics() {
		const today = new Date().toISOString().split('T')[0];
		const todayTransactions = allTransactions.filter(t => t.date === today);
		
		// Get unique employees for today
		const todayEmployeeIds = new Set();
		const branchStats = new Map();
		
		todayTransactions.forEach(transaction => {
			todayEmployeeIds.add(transaction.employee_id);
			
			const branchId = transaction.branch_id;
			if (!branchStats.has(branchId)) {
				branchStats.set(branchId, new Set());
			}
			branchStats.get(branchId).add(transaction.employee_id);
		});
		
		totalPresentToday = todayEmployeeIds.size;
		
		branchBreakdown = Array.from(branchStats.entries())
			.map(([branchId, uniqueEmployees]) => ({
				...branchMap.get(branchId),
				uniqueEmployees: uniqueEmployees.size
			}))
			.sort((a, b) => b.uniqueEmployees - a.uniqueEmployees);
	}

	function extractUniqueValues() {
		// Get unique dates from all transactions
		const uniqueDates = new Set();
		allTransactions.forEach(transaction => {
			uniqueDates.add(transaction.date);
		});
		// Sort dates in descending order (latest first)
		allDates = Array.from(uniqueDates).sort().reverse();
		
		// Get unique branches
		allBranches = Array.from(branchMap.values()).sort((a, b) => 
			(a.name_en || '').localeCompare(b.name_en || '')
		);
	}

	function applyFilters() {
		let filtered = allTransactions;
		
		// Filter by branch
		if (selectedBranch) {
			filtered = filtered.filter(t => t.branch_id === selectedBranch);
		}
		
		// Filter by date
		if (selectedDate) {
			filtered = filtered.filter(t => t.date === selectedDate);
		}
		
		// Search filter
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase().trim();
			filtered = filtered.filter(transaction => {
				if (searchType === 'employee-id') {
					return String(transaction.employee_id).toLowerCase().includes(query);
				} else if (searchType === 'name') {
					const employeeName = getEmployeeName(transaction.employee_id, transaction.branch_id).toLowerCase();
					return employeeName.includes(query);
				}
				return true;
			});
		}
		
		filteredTransactions = filtered;
	}

	// Reactive updates when filters or search changes
	$: if (selectedBranch !== undefined && selectedDate !== undefined && searchQuery !== undefined && searchType !== undefined) {
		applyFilters();
	}

	// Load today's data when switching to today mode
	$: if (loadingMode === 'today') {
		loadDataOnDemand('today', null, null);
	}

	// Load all data when switching to all mode
	$: if (loadingMode === 'all') {
		loadDataOnDemand('all', null, null);
	}

	async function loadDataOnDemand(mode, dateOrStart, endDateVal) {
		try {
			loading = true;
			loadingProgress = 0;
			loadingStatus = `${t('app.loading')}...`;
			console.log('📥 Loading data on demand for mode:', mode);
			const today = new Date().toISOString().split('T')[0];
			let query = supabase.from('hr_fingerprint_transactions').select('*');

			if (mode === 'today') {
				loadingStatus = `${t('app.loading')} ${t('hr.loadToday')}...`;
				query = query.eq('date', today).order('time', { ascending: false }).limit(1000);
			} else if (mode === 'specific') {
				loadingStatus = `${t('app.loading')} ${t('hr.loadSpecificDate')}...`;
				query = query.eq('date', dateOrStart).order('time', { ascending: false }).limit(1000);
			} else if (mode === 'range') {
				loadingStatus = `${t('app.loading')} ${t('hr.loadDateRange')}...`;
				query = query
					.gte('date', dateOrStart)
					.lte('date', endDateVal)
					.order('date', { ascending: false })
					.order('time', { ascending: false })
					.limit(1000);
			} else if (mode === 'all') {
				loadingStatus = `${t('app.loading')} ${t('hr.loadAllData')}...`;
				query = query.order('date', { ascending: false }).order('time', { ascending: false }).limit(1000);
			}

			loadingProgress = 10;

			// Load fingerprint data and employee/branch data in parallel
			const [fingerprintRes, employeesRes, branchesRes, positionsRes] = await Promise.all([
				query,
				supabase.from('hr_employees').select('id, employee_id, branch_id, name').order('employee_id'),
				supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar'),
				supabase.from('hr_position_assignments').select('employee_id, position:position_id(position_title_en, position_title_ar)').eq('is_current', true)
			]);

			loadingProgress = 50;

			const { data, error } = fingerprintRes;

			if (error) {
				console.error('Failed to load data on demand:', error);
				loading = false;
				return;
			}

			// Process employees in parallel
			const employees = employeesRes.data || [];
			const empError = employeesRes.error;
			if (empError) {
				console.error('Failed to load employees:', empError);
			} else {
				employees.forEach(emp => {
					const compositeKey = `${emp.employee_id}_${emp.branch_id}`;
					employeeMap.set(compositeKey, emp);
				});
			}

			// Process branches
			const branches = branchesRes.data || [];
			const branchError = branchesRes.error;
			if (branchError) {
				console.error('Failed to load branches:', branchError);
			} else {
				branches.forEach(branch => {
					branchMap.set(branch.id, branch);
				});
			}

			// Process position assignments
			const positionAssignments = positionsRes.data || [];
			const posError = positionsRes.error;
			if (posError) {
				console.error('Failed to load position assignments:', posError);
			} else {
				positionAssignments.forEach(assignment => {
					if (assignment.employee_id && assignment.position) {
						positionMap.set(assignment.employee_id, {
							en: assignment.position.position_title_en || 'N/A',
							ar: assignment.position.position_title_ar || 'N/A'
						});
					}
				});
			}

			loadingProgress = 75;
			console.log(`✅ Loaded ${data?.length || 0} records on demand (mode: ${mode})`);
			allTransactions = (data || []).sort((a, b) => {
				const dateCompare = new Date(b.date).getTime() - new Date(a.date).getTime();
				if (dateCompare !== 0) return dateCompare;
				return b.time.localeCompare(a.time);
			});

			loadingProgress = 90;
			// Re-extract unique values and apply filters
			extractUniqueValues();
			applyFilters();

			loadingProgress = 100;
			setTimeout(() => {
				loading = false;
				loadingProgress = 0;
				loadingStatus = '';
			}, 300);
		} catch (err) {
			console.error('Error loading data on demand:', err);
			loading = false;
			loadingProgress = 0;
		}
	}

	function formatDate(dateString) {
		// dateString is in YYYY-MM-DD format
		// Parse and format as DD/MM/YYYY
		const [year, month, day] = dateString.split('-');
		return `${day}/${month}/${year}`;
	}

	function formatSyncTime(timestamp) {
		if (!timestamp) return 'Never';
		const date = new Date(timestamp);
		
		// Format as: Nov 30, 2025 at 3:42 PM
		const dateStr = date.toLocaleDateString('en-US', { 
			year: 'numeric', 
			month: 'short', 
			day: 'numeric' 
		});
		const timeStr = date.toLocaleTimeString('en-US', { 
			hour: '2-digit', 
			minute: '2-digit',
			hour12: true 
		});
		
		return `${dateStr} at ${timeStr}`;
	}

	function formatTime(timeString) {
		// timeString is in HH:MM:SS format - display as stored
		const [hours, minutes] = timeString.split(':');
		let hour = parseInt(hours);
		
		// Convert to 12-hour format
		const ampm = hour >= 12 ? 'PM' : 'AM';
		const displayHour = hour % 12 || 12;
		return `${String(displayHour).padStart(2, '0')}:${minutes} ${ampm}`;
	}

	function getEmployeeName(employeeId, branchId) {
		// Use composite key to match both employee_id and branch_id
		const compositeKey = `${employeeId}_${branchId}`;
		const employee = employeeMap.get(compositeKey);
		if (employee && employee.name) {
			return employee.name;
		}
		return '—';
	}

	function getLocalizedText(enText, arText) {
		// Get current locale from the store
		const locale = currentLocale ? (typeof currentLocale === 'object' ? currentLocale : 'en') : 'en';
		
		// If we have a store, get the value
		let currentLang = 'en';
		if (typeof locale === 'object' && locale.subscribe) {
			// It's a store, get its current value
			let value;
			locale.subscribe(v => { value = v; })();
			currentLang = value || 'en';
		} else {
			currentLang = locale || 'en';
		}
		
		if (currentLang === 'ar' && arText) {
			return arText;
		}
		return enText || '—';
	}

	function getBranchName(branchId) {
		const branch = branchMap.get(branchId);
		if (branch) {
			return getLocalizedText(branch.name_en, branch.name_ar);
		}
		return '—';
	}

	function getPosition(employeeUuid) {
		// employeeUuid is the UUID id from hr_employees table
		const positionData = positionMap.get(employeeUuid);
		if (!positionData) return '—';
		
		// positionData is now an object with {en, ar} structure for localization
		if (typeof positionData === 'object') {
			return getLocalizedText(positionData.en, positionData.ar);
		}
		// Fallback for legacy string format
		return positionData || '—';
	}

	async function loadBiometricConnections() {
		const { data: connections, error: connError } = await supabase
			.from('biometric_connections')
			.select('*')
			.eq('is_active', true)
			.order('branch_id', { ascending: true });
		if (connError) {
			console.error('Failed to load biometric connections:', connError);
		} else if (connections) {
			biometricConnections = connections;
		}
	}

	async function refreshSyncStatus() {
		refreshingSyncStatus = true;
		try {
			await loadBiometricConnections();
			// Small delay to show the refresh animation
			await new Promise(resolve => setTimeout(resolve, 500));
		} finally {
			refreshingSyncStatus = false;
		}
	}

	function handleExportToExcel() {
		openWindow({
			id: 'biometric-export-' + Date.now(),
			title: t('hr.exportToExcel'),
			component: BiometricExport,
			icon: '📊',
			size: { width: 800, height: 600 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="biometric-data">
	<div class="content">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{loadingStatus || t('app.loading')}</p>
				<div class="progress-bar-container">
					<div class="progress-bar" style="width: {loadingProgress}%"></div>
				</div>
				<p class="progress-text">{loadingProgress}%</p>
			</div>
		{:else if error}
			<div class="error-message">
				<span class="error-icon">⚠️</span>
				<p>{error}</p>
				<button class="retry-btn" on:click={loadData}>{t('common.retry')}</button>
			</div>
		{:else}
			<div class="cards-container">
				<!-- Total Present Today Card -->
				<div class="card present-card">
					<div class="card-header">
						<h3 class="card-title">{t('hr.presentToday')}</h3>
						<div class="card-header-actions">
							<button class="export-btn" on:click={handleExportToExcel} title={t('hr.exportToExcel')}>
								📊 {t('hr.exportToExcel')}
							</button>
							<span class="card-icon">👥</span>
						</div>
					</div>
					<div class="card-body">
						<div class="metric-value">{totalPresentToday}</div>
						<p class="metric-label">{t('hr.employees')}</p>
						<p class="metric-date">{formatDate(new Date().toISOString())}</p>
					</div>
				</div>

				<!-- Branch-wise Breakdown Card -->
				<div class="card breakdown-card">
					<div class="card-header">
						<h3 class="card-title">{t('hr.branchBreakdown')}</h3>
						<span class="card-icon">🏢</span>
					</div>
					<div class="card-body">
						{#if branchBreakdown.length === 0}
							<div class="no-data">
								<p>{t('hr.invalidDate')}</p>
							</div>
						{:else}
							<div class="branch-list">
								{#each branchBreakdown as branch (branch.branchId)}
									<div class="branch-item">
										<div class="branch-info">
											<h4 class="branch-name">{branch.location}</h4>
											<p class="branch-stats">
												{t('hr.checkIn')}: {branch.checkIns} | {t('hr.checkOut')}: {branch.checkOuts}
											</p>
										</div>
										<div class="branch-count">
											<span class="count-value">{branch.uniqueEmployees}</span>
											<span class="count-label">{t('hr.presentToday')}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>

				<!-- Sync Status Card -->
				<div class="card sync-card">
					<div class="card-header">
						<h3 class="card-title">{t('hr.syncStatus')}</h3>
						<button 
							class="refresh-btn" 
							class:refreshing={refreshingSyncStatus}
							on:click={refreshSyncStatus} 
							disabled={refreshingSyncStatus}
							title="Refresh sync status"
						>
						🔄
					</button>
					</div>
					<div class="card-body">
						{#if biometricConnections.length === 0}
							<div class="no-data">
								<p>{t('hr.noSyncData')}</p>
							</div>
						{:else}
							<div class="sync-list">
								{#each biometricConnections as conn (conn.id)}
									<div class="sync-item">
										<div class="sync-branch-name">{conn.branch_name}</div>
										<div class="sync-details">
											<div class="sync-row">
												<span class="sync-label">👥 {t('hr.employees')}:</span>
												<span class="sync-time">{formatSyncTime(conn.last_sync_at)}</span>
											</div>
											<div class="sync-row">
												<span class="sync-label">📋 {t('hr.transactions')}:</span>
												<span class="sync-time">{formatSyncTime(conn.last_employee_sync_at)}</span>
											</div>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			</div>

			<!-- All Transactions Table -->
			<div class="table-section">
			<div class="table-header">
				<h3 class="table-title">{t('hr.allFingerprint')}</h3>
				<p class="table-subtitle">{t('hr.showing')} {filteredTransactions.length} {t('hr.of')} {allTransactions.length} {t('hr.transactions')}</p>
			</div>
			
			<!-- Data Loading Mode Radio Buttons -->
			<div class="loading-mode-container">
				<div class="radio-group-horizontal">
					<label class="radio-label-mode">
						<input type="radio" value="today" bind:group={loadingMode} class="radio-input" />
						<span class="radio-text">📅 {t('hr.loadToday')}</span>
					</label>
					
					<label class="radio-label-mode">
						<input type="radio" value="specific" bind:group={loadingMode} class="radio-input" />
						<span class="radio-text">🗓️ {t('hr.loadSpecificDate')}</span>
					</label>
					
					<label class="radio-label-mode">
						<input type="radio" value="range" bind:group={loadingMode} class="radio-input" />
						<span class="radio-text">📆 {t('hr.loadDateRange')}</span>
					</label>
					
					<label class="radio-label-mode">
						<input type="radio" value="all" bind:group={loadingMode} class="radio-input" />
						<span class="radio-text">📊 {t('hr.loadAllData')}</span>
					</label>
				</div>
				
				<!-- Date inputs based on selection -->
				{#if loadingMode === 'specific'}
					<div class="date-input-container">
						<input 
							type="date" 
							bind:value={specificDate} 
							class="date-input"
							aria-label="Select specific date"
						/>
						<button class="load-btn" on:click={() => loadDataOnDemand('specific', specificDate)} disabled={!specificDate}>
							{t('hr.loadData')}
						</button>
					</div>
				{:else if loadingMode === 'range'}
					<div class="date-input-container">
						<input 
							type="date" 
							bind:value={startDate} 
							class="date-input"
							placeholder="Start Date"
							aria-label="Select start date"
						/>
						<span class="date-separator">→</span>
						<input 
							type="date" 
							bind:value={endDate} 
							class="date-input"
							placeholder="End Date"
							aria-label="Select end date"
						/>
						<button class="load-btn" on:click={() => loadDataOnDemand('range', startDate, endDate)} disabled={!startDate || !endDate}>
							{t('hr.loadData')}
						</button>
					</div>
				{/if}
			</div>
			
			<!-- Search Bar -->
				<div class="search-bar-container">
					<div class="search-input-group">
						<input
							type="text"
							placeholder={t('hr.search')}
							class="search-input"
							bind:value={searchQuery}
							aria-label="Search transactions"
						/>
						<span class="search-icon">🔍</span>
					</div>

					<div class="search-radio-group">
						<label class="radio-label">
							<input type="radio" value="employee-id" bind:group={searchType} class="radio-input" />
							<span>{t('hr.employeeId')}</span>
						</label>
						<label class="radio-label">
							<input type="radio" value="name" bind:group={searchType} class="radio-input" />
							<span>{t('hr.name')}</span>
						</label>
					</div>

					{#if searchQuery}
						<button class="clear-search-btn" on:click={() => { searchQuery = ''; }}>
							{t('hr.clearSearch')}
						</button>
					{/if}
				</div>

				<!-- Filters -->
				<div class="filters-container">
					<div class="filter-group">
						<label for="branch-filter" class="filter-label">{t('hr.branch')}</label>
						<select id="branch-filter" class="filter-select" bind:value={selectedBranch}>
							<option value="">{t('branches.allBranches')}</option>
							{#each allBranches as branch (branch.id)}
								<option value={branch.id}>{getLocalizedText(branch.name_en, branch.name_ar)}</option>
							{/each}
						</select>
					</div>

					<div class="filter-group">
						<label for="date-filter" class="filter-label">{t('hr.date')}</label>
						<select id="date-filter" class="filter-select" bind:value={selectedDate}>
							<option value="">{t('hr.allDates')}</option>
							{#each allDates as date (date)}
								<option value={date}>{formatDate(date)}</option>
							{/each}
						</select>
					</div>

					{#if selectedBranch || selectedDate}
						<button class="clear-filters-btn" on:click={() => { selectedBranch = ''; selectedDate = ''; }}>
							{t('hr.clearFilters')}
						</button>
					{/if}
				</div>

				<div class="table-container">
					<table class="transactions-table">
						<thead>
							<tr>
								<th>{t('hr.employeeId')}</th>
								<th>{t('hr.name')}</th>
								<th>{t('hr.position')}</th>
								<th>{t('hr.branch')}</th>
								<th>{t('hr.date')}</th>
								<th>{t('hr.time')}</th>
								<th>{t('hr.status')}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredTransactions as transaction (transaction.id)}
								<tr class="table-row" class:check-in={transaction.status === 'Check In'} class:check-out={transaction.status === 'Check Out'}>
									<td class="employee-id">{transaction.employee_id}</td>
									<td class="employee-name">{getEmployeeName(transaction.employee_id, transaction.branch_id)}</td>
									<td class="position-col">{getPosition(employeeMap.get(`${transaction.employee_id}_${transaction.branch_id}`)?.id)}</td>
									<td class="branch-col">{getBranchName(transaction.branch_id)}</td>
									<td class="date-col">{formatDate(transaction.date)}</td>
									<td class="time-col">{formatTime(transaction.time)}</td>
									<td class="status-col">
										<span class="status-badge {transaction.status === 'Check In' ? 'in' : 'out'}">
											{transaction.status}
										</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.biometric-data {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.content {
		flex: 1;
		padding: 24px;
		overflow-y: auto;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 16px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.progress-bar-container {
		width: 200px;
		height: 8px;
		background: #e5e7eb;
		border-radius: 4px;
		overflow: hidden;
		margin-top: 16px;
	}

	.progress-bar {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6, #10b981);
		border-radius: 4px;
		transition: width 0.3s ease;
	}

	.progress-text {
		font-size: 14px;
		font-weight: 600;
		color: #3b82f6;
		margin: 0;
		margin-top: 8px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 20px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		color: #dc2626;
	}

	.error-icon {
		font-size: 24px;
	}

	.error-message p {
		margin: 0;
		text-align: center;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s;
	}

	.retry-btn:hover {
		background: #b91c1c;
		transform: translateY(-1px);
	}

	.cards-container {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 20px;
	}

	.card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
		transition: all 0.3s ease;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
	}

	.card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		border-color: #d1d5db;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 20px;
		background: linear-gradient(135deg, #f3f4f6 0%, #f9fafb 100%);
		border-bottom: 1px solid #e5e7eb;
	}

	.card-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.card-icon {
		font-size: 20px;
	}

	.card-body {
		padding: 20px;
	}

	.present-card .card-header {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
	}

	.card-header-actions {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.export-btn {
		padding: 8px 16px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.export-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
	}

	.export-btn:active {
		transform: translateY(0);
	}

	.refresh-btn {
		background: none;
		border: none;
		font-size: 24px;
		cursor: pointer;
		padding: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s ease;
		border-radius: 50%;
		width: 36px;
		height: 36px;
	}

	.refresh-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.5);
		transform: rotate(180deg);
	}

	.refresh-btn:active:not(:disabled) {
		transform: rotate(180deg) scale(0.9);
	}

	.refresh-btn:disabled {
		cursor: not-allowed;
		opacity: 0.6;
	}

	.refresh-btn.refreshing {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	.present-card .card-title {
		color: #065f46;
	}

	.breakdown-card .card-header {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
	}

	.breakdown-card .card-title {
		color: #0c2d6b;
	}

	.sync-card .card-header {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
	}

	.sync-card .card-title {
		color: #92400e;
	}

	.sync-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.sync-item {
		padding: 12px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.sync-branch-name {
		font-size: 14px;
		font-weight: 600;
		color: #111827;
		margin-bottom: 8px;
	}

	.sync-details {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.sync-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 11px;
		gap: 8px;
	}

	.sync-label {
		color: #6b7280;
		font-weight: 500;
		flex-shrink: 0;
	}

	.sync-time {
		color: #059669;
		font-weight: 600;
		text-align: right;
		flex: 1;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.metric-value {
		font-size: 48px;
		font-weight: 700;
		color: #059669;
		line-height: 1;
		margin-bottom: 8px;
	}

	.metric-label {
		font-size: 14px;
		color: #6b7280;
		margin: 0 0 4px 0;
		font-weight: 500;
	}

	.metric-date {
		font-size: 12px;
		color: #9ca3af;
		margin: 0;
	}

	.no-data {
		text-align: center;
		padding: 20px;
		color: #9ca3af;
	}

	.no-data p {
		margin: 0;
	}

	.branch-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.branch-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #f3f4f6;
		transition: all 0.2s;
	}

	.branch-item:hover {
		background: #f3f4f6;
		border-color: #e5e7eb;
	}

	.branch-info {
		flex: 1;
	}

	.branch-name {
		font-size: 14px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.branch-stats {
		font-size: 12px;
		color: #6b7280;
		margin: 0;
	}

	.branch-count {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding-left: 12px;
		border-left: 1px solid #e5e7eb;
	}

	.count-value {
		font-size: 20px;
		font-weight: 700;
		color: #3b82f6;
	}

	.count-label {
		font-size: 11px;
		color: #9ca3af;
		font-weight: 500;
	}

	.search-bar-container {
		display: flex;
		gap: 16px;
		padding: 16px 20px;
		background: #ffffff;
		border-bottom: 1px solid #e5e7eb;
		align-items: center;
		flex-wrap: wrap;
	}

	.search-input-group {
		position: relative;
		flex: 1;
		min-width: 250px;
		height: 42px;
		display: flex;
		align-items: center;
	}

	.search-input {
		width: 100%;
		height: 100%;
		padding: 10px 14px 10px 36px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #111827;
		transition: all 0.2s;
		font-family: inherit;
	}

	.search-input::placeholder {
		color: #9ca3af;
	}

	.search-input:hover {
		border-color: #9ca3af;
		background: #f9fafb;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
		background: white;
	}

	.search-icon {
		position: absolute;
		left: 10px;
		top: 50%;
		transform: translateY(-50%);
		font-size: 16px;
		color: #9ca3af;
		pointer-events: none;
	}

	.search-radio-group {
		display: flex;
		gap: 12px;
		align-items: center;
		height: 42px;
	}

	.radio-label {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		cursor: pointer;
		font-size: 13px;
		color: #64748b;
		font-weight: 500;
		user-select: none;
		padding: 10px 16px;
		height: 42px;
		border-radius: 8px;
		border: 2px solid #cbd5e1;
		background: #f8fafc;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
		white-space: nowrap;
	}

	.radio-label:hover {
		background: #f1f5f9;
		border-color: #94a3b8;
		color: #475569;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.06);
		transform: translateY(-1px);
	}

	.radio-label:has(.radio-input:checked) {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		border-color: #0284c7;
		color: #0c2d6b;
		font-weight: 600;
		box-shadow: 0 4px 12px rgba(2, 132, 199, 0.2);
	}

	.radio-label:has(.radio-input:checked):hover {
		background: linear-gradient(135deg, #bfdbfe 0%, #93c5fd 100%);
		border-color: #0369a1;
		box-shadow: 0 6px 16px rgba(2, 132, 199, 0.3);
	}

	.radio-input {
		cursor: pointer;
		accent-color: #0284c7;
		width: 20px;
		height: 20px;
		flex-shrink: 0;
		transition: all 0.2s;
		border: 2px solid #cbd5e1;
		appearance: none;
		-webkit-appearance: none;
		background: white;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.radio-input:hover {
		border-color: #94a3b8;
		box-shadow: 0 0 8px rgba(2, 132, 199, 0.2);
	}

	.radio-input:checked {
		background: #0284c7;
		border-color: #0284c7;
		box-shadow: 0 0 0 4px rgba(2, 132, 199, 0.2);
	}

	.radio-input:checked::after {
		content: '✓';
		color: white;
		font-size: 12px;
		font-weight: bold;
	}

	.radio-input:focus {
		outline: 2px solid #0284c7;
		outline-offset: 2px;
	}

	.clear-search-btn {
		padding: 10px 16px;
		height: 42px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #fca5a5;
		color: #7f1d1d;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.clear-search-btn:hover {
		background: #f87171;
		color: white;
		transform: translateY(-1px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.filters-container {
		display: flex;
		gap: 12px;
		padding: 16px 20px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		flex-wrap: wrap;
		align-items: flex-end;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
		flex: 0 1 auto;
		min-width: 200px;
	}

	.filter-label {
		font-size: 12px;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 13px;
		background: white;
		color: #111827;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
	}

	.filter-select:hover {
		border-color: #9ca3af;
		background: #f3f4f6;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.clear-filters-btn {
		padding: 8px 16px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.clear-filters-btn:hover {
		background: #dc2626;
		transform: translateY(-1px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	/* Loading Mode Radio Buttons */
	.loading-mode-container {
		padding: 16px 20px;
		background: linear-gradient(135deg, #fef3c7 0%, #fef9e7 100%);
		border-bottom: 1px solid #fbbf24;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.radio-group-horizontal {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
		align-items: center;
	}

	.radio-label-mode {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		font-size: 14px;
		color: #92400e;
		font-weight: 500;
		user-select: none;
		padding: 10px 18px;
		border-radius: 8px;
		border: 2px solid #fbbf24;
		background: white;
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		white-space: nowrap;
	}

	.radio-label-mode:hover {
		background: #fffbeb;
		border-color: #f59e0b;
		color: #78350f;
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
		transform: translateY(-1px);
	}

	.radio-label-mode:has(.radio-input:checked) {
		background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
		border-color: #d97706;
		color: white;
		font-weight: 600;
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.radio-label-mode:has(.radio-input:checked):hover {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		border-color: #b45309;
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.5);
	}

	.radio-text {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.date-input-container {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		background: white;
		border-radius: 8px;
		border: 1px solid #fbbf24;
	}

	.date-input {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		color: #111827;
		background: white;
		transition: all 0.2s;
		min-width: 150px;
	}

	.date-input:hover {
		border-color: #9ca3af;
		background: #f9fafb;
	}

	.date-input:focus {
		outline: none;
		border-color: #f59e0b;
		box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
	}

	.date-separator {
		font-size: 18px;
		color: #92400e;
		font-weight: bold;
	}

	.load-btn {
		padding: 8px 24px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.load-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
	}

	.load-btn:disabled {
		background: #d1d5db;
		cursor: not-allowed;
		opacity: 0.6;
	}

	@media (max-width: 768px) {
		.search-bar-container {
			flex-direction: column;
			gap: 12px;
		}

		.search-input-group {
			width: 100%;
			min-width: unset;
		}

		.search-radio-group {
			width: 100%;
			justify-content: flex-start;
		}

		.clear-search-btn {
			width: 100%;
		}

		.radio-group-horizontal {
			flex-direction: column;
			width: 100%;
		}

		.radio-label-mode {
			width: 100%;
			justify-content: center;
		}

		.date-input-container {
			flex-direction: column;
			align-items: stretch;
		}

		.date-input {
			width: 100%;
		}

		.load-btn {
			width: 100%;
		}

		.filters-container {
			flex-direction: column;
		}

		.filter-group {
			width: 100%;
			min-width: unset;
		}

		.clear-filters-btn {
			width: 100%;
		}
	}

	@media (max-width: 768px) {
		.cards-container {
			grid-template-columns: 1fr;
		}

		.metric-value {
			font-size: 36px;
		}

		.branch-item {
			flex-direction: column;
			align-items: flex-start;
			gap: 8px;
		}

		.branch-count {
			width: 100%;
			flex-direction: row;
			justify-content: space-between;
			align-items: center;
			padding-left: 0;
			border-left: none;
			padding-top: 8px;
			border-top: 1px solid #e5e7eb;
		}
	}

	.table-section {
		margin-top: 24px;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		height: calc(100vh - 600px);
		min-height: 400px;
	}

	.table-header {
		padding: 16px 20px;
		background: linear-gradient(135deg, #f3f4f6 0%, #f9fafb 100%);
		border-bottom: 1px solid #e5e7eb;
	}

	.table-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.table-subtitle {
		font-size: 13px;
		color: #6b7280;
		margin: 0;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		position: relative;
	}

	.transactions-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.transactions-table thead {
		position: sticky;
		top: 0;
		z-index: 10;
		background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
	}

	.transactions-table th {
		padding: 14px 16px;
		text-align: left;
		font-weight: 700;
		color: #1e293b;
		background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
		border-bottom: 2px solid #cbd5e1;
		white-space: nowrap;
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.7px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.03);
	}

	.transactions-table td {
		padding: 14px 16px;
		border-bottom: 1px solid #e2e8f0;
		color: #1e293b;
		background: white;
	}

	.table-row {
		transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
		border-left: 4px solid transparent;
	}

	.table-row:hover {
		background: linear-gradient(90deg, #f0f9ff 0%, #ffffff 50%, #fef3f2 100%);
		box-shadow: inset 0 0 0 1px rgba(59, 130, 246, 0.1);
	}

	.table-row.check-in {
		border-left: 4px solid #10b981;
	}

	.table-row.check-in:hover {
		background: linear-gradient(90deg, #ecfdf5 0%, #ffffff 50%, #f0fdf4 100%);
		box-shadow: inset 0 0 8px rgba(16, 185, 129, 0.1);
	}

	.table-row.check-out {
		border-left: 4px solid #ef4444;
	}

	.table-row.check-out:hover {
		background: linear-gradient(90deg, #fef2f2 0%, #ffffff 50%, #fef8f8 100%);
		box-shadow: inset 0 0 8px rgba(239, 68, 68, 0.1);
	}

	.employee-id {
		font-family: 'Courier New', monospace;
		font-weight: 700;
		color: #0284c7;
		font-size: 12px;
		letter-spacing: 0.5px;
	}

	.employee-name {
		font-weight: 600;
		color: #1e293b;
		letter-spacing: 0.3px;
	}

	.position-col {
		color: #5b4cac;
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 0.3px;
	}

	.branch-col {
		color: #475569;
		font-size: 12px;
		font-weight: 500;
	}

	.date-col {
		font-family: 'Courier New', monospace;
		color: #64748b;
		font-size: 12px;
		font-weight: 500;
		letter-spacing: 0.3px;
	}

	.time-col {
		font-family: 'Courier New', monospace;
		font-weight: 700;
		color: #334155;
		letter-spacing: 0.3px;
	}

	.status-col {
		text-align: center;
	}

	.status-badge {
		display: inline-block;
		padding: 6px 14px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 700;
		white-space: nowrap;
		letter-spacing: 0.5px;
		text-transform: uppercase;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
		transition: all 0.2s;
	}

	.status-badge.in {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
		color: #065f46;
		border: 1px solid #6ee7b7;
	}

	.status-badge.in:hover {
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.2);
		transform: translateY(-1px);
	}

	.status-badge.out {
		background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
		color: #7f1d1d;
		border: 1px solid #fca5a5;
	}

	.status-badge.out:hover {
		box-shadow: 0 4px 8px rgba(239, 68, 68, 0.2);
		transform: translateY(-1px);
	}

	@media (max-width: 1024px) {
		.table-section {
			height: calc(100vh - 500px);
		}

		.transactions-table th,
		.transactions-table td {
			padding: 10px 12px;
			font-size: 12px;
		}
	}

	@media (max-width: 768px) {
		.table-section {
			height: auto;
			max-height: 500px;
		}

		.transactions-table {
			font-size: 11px;
		}

		.transactions-table th,
		.transactions-table td {
			padding: 8px 10px;
		}

		.employee-id,
		.branch-col,
		.date-col {
			font-size: 11px;
		}
	}
</style>