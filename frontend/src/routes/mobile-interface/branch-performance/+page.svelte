<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';

	let currentUserData = null;
	let branchPerformance = {
		branches: [],
		todayStats: [],
		yesterdayStats: [],
		loading: false,
		error: ''
	};

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadBranchPerformance();
		}
	});

	async function loadBranchPerformance() {
		branchPerformance.loading = true;
		branchPerformance.error = '';

		try {
			console.log('📊 Loading all branches performance data...');


		// Get all branches - select location and name columns
		const { data: branches, error: branchError } = await supabase
			.from('branches')
			.select('id, name_en, name_ar, location_en, location_ar')
			.order('name_en', { ascending: true });

		if (branchError) throw branchError;			branchPerformance.branches = branches || [];

			// Get today and yesterday dates in Saudi Arabia timezone (GMT+3)
			// Create dates adjusted for Saudi timezone
			const saudiNow = new Date(new Date().getTime() + (3 * 60 * 60 * 1000));
			const today = saudiNow.toISOString().split('T')[0];
			const yesterdaySaudi = new Date(saudiNow.getTime() - 86400000);
			const yesterday = yesterdaySaudi.toISOString().split('T')[0];

			// Get start and end times for today and yesterday in UTC
			// Today starts at 00:00:00 Saudi time = 21:00:00 UTC (previous day)
			// Today ends at 23:59:59 Saudi time = 20:59:59 UTC (same day)
			const todayStartUTC = new Date(`${today}T00:00:00Z`);
			todayStartUTC.setHours(todayStartUTC.getHours() - 3); // Subtract 3 hours for GMT+3
			const todayEndUTC = new Date(`${today}T23:59:59Z`);
			todayEndUTC.setHours(todayEndUTC.getHours() - 3);

			const yesterdayStartUTC = new Date(`${yesterday}T00:00:00Z`);
			yesterdayStartUTC.setHours(yesterdayStartUTC.getHours() - 3);
			const yesterdayEndUTC = new Date(`${yesterday}T23:59:59Z`);
			yesterdayEndUTC.setHours(yesterdayEndUTC.getHours() - 3);

		// Load stats for all branches
		const allStatsPromises = branchPerformance.branches.map(async (branch) => {
		const isArabic = $localeData.code === 'ar';
		const branchName = isArabic ? branch.name_ar : branch.name_en;
		const branchLocation = isArabic ? branch.location_ar : branch.location_en;
		const branchDisplay = `${branchName} - ${branchLocation}`;
		
		try {
			// Helper to safely execute queries
			const safeQuery = async (query) => {
				try {
					const result = await query;
					return result || { data: [], count: 0 };
				} catch (err) {
					console.warn(`Query error for branch ${branch.id}:`, err);
					return { data: [], count: 0 };
				}
			};				// Fetch all three types of tasks for today and yesterday
				const [todayReceiving, todayTasks, todayQuick, yesterdayReceiving, yesterdayTasks, yesterdayQuick] = await Promise.all([
					// Today's receiving tasks
					safeQuery(
						supabase
							.from('receiving_tasks')
							.select('id, task_status, receiving_records(branch_id)', { count: 'exact' })
							.eq('receiving_records.branch_id', branch.id)
					.gte('created_at', todayStartUTC.toISOString())
					.lt('created_at', todayEndUTC.toISOString())
					),
					// Today's task assignments
					safeQuery(
						supabase
							.from('task_assignments')
							.select('id, status', { count: 'exact' })
							.eq('assigned_to_branch_id', branch.id)
					.gte('assigned_at', todayStartUTC.toISOString())
					.lt('assigned_at', todayEndUTC.toISOString())
					),
					// Today's quick tasks
					safeQuery(
						supabase
							.from('quick_task_assignments')
							.select('id, status, quick_tasks(assigned_to_branch_id)', { count: 'exact' })
							.eq('quick_tasks.assigned_to_branch_id', branch.id)
							.gte('created_at', `${today}T00:00:00`)
							.lt('created_at', `${today}T23:59:59`)
					),
					// Yesterday's receiving tasks
					safeQuery(
						supabase
							.from('receiving_tasks')
							.select('id, task_status, receiving_records(branch_id)', { count: 'exact' })
							.eq('receiving_records.branch_id', branch.id)
						.gte('created_at', yesterdayStartUTC.toISOString())
						.lt('created_at', yesterdayEndUTC.toISOString())
					),
					// Yesterday's task assignments
					safeQuery(
						supabase
							.from('task_assignments')
							.select('id, status', { count: 'exact' })
							.eq('assigned_to_branch_id', branch.id)
						.gte('assigned_at', yesterdayStartUTC.toISOString())
						.lt('assigned_at', yesterdayEndUTC.toISOString())
					),
					// Yesterday's quick tasks
					safeQuery(
						supabase
							.from('quick_task_assignments')
							.select('id, status, quick_tasks(assigned_to_branch_id)', { count: 'exact' })
							.eq('quick_tasks.assigned_to_branch_id', branch.id)
							.gte('created_at', `${yesterday}T00:00:00`)
							.lt('created_at', `${yesterday}T23:59:59`)
					)
				]);

				// Calculate today's stats - safely handle null/undefined
				const todayReceivingData = todayReceiving.data || [];
				const todayTasksData = todayTasks.data || [];
				const todayQuickData = todayQuick.data || [];

				const todayReceivingCompleted = todayReceivingData.filter(r => r.task_status === 'completed').length || 0;
				const todayTasksCompleted = todayTasksData.filter(t => t.status === 'completed').length || 0;
				const todayQuickCompleted = todayQuickData.filter(q => q.status === 'completed').length || 0;

				const todayTotal = (todayReceiving.count || 0) + (todayTasks.count || 0) + (todayQuick.count || 0);
				const todayCompleted = todayReceivingCompleted + todayTasksCompleted + todayQuickCompleted;

				// Calculate yesterday's stats - safely handle null/undefined
				const yesterdayReceivingData = yesterdayReceiving.data || [];
				const yesterdayTasksData = yesterdayTasks.data || [];
				const yesterdayQuickData = yesterdayQuick.data || [];

				const yesterdayReceivingCompleted = yesterdayReceivingData.filter(r => r.task_status === 'completed').length || 0;
				const yesterdayTasksCompleted = yesterdayTasksData.filter(t => t.status === 'completed').length || 0;
				const yesterdayQuickCompleted = yesterdayQuickData.filter(q => q.status === 'completed').length || 0;

				const yesterdayTotal = (yesterdayReceiving.count || 0) + (yesterdayTasks.count || 0) + (yesterdayQuick.count || 0);
				const yesterdayCompleted = yesterdayReceivingCompleted + yesterdayTasksCompleted + yesterdayQuickCompleted;

				return {
					today: {
						branchName: branchDisplay,
						completed: todayCompleted,
						pending: todayTotal - todayCompleted,
						total: todayTotal
					},
					yesterday: {
						branchName: branchDisplay,
						completed: yesterdayCompleted,
						pending: yesterdayTotal - yesterdayCompleted,
						total: yesterdayTotal
					}
				};
			} catch (err) {
				console.error(`Error loading stats for branch ${branch.id}:`, err);
				return {
					today: { branchName: branchDisplay, completed: 0, pending: 0, total: 0 },
					yesterday: { branchName: branchDisplay, completed: 0, pending: 0, total: 0 }
				};
			}
		});			const allStats = await Promise.all(allStatsPromises);
			branchPerformance.todayStats = allStats.map(s => s.today);
			branchPerformance.yesterdayStats = allStats.map(s => s.yesterday);

			console.log('✅ Branch performance loaded successfully');
		} catch (error) {
			console.error('Error loading branch performance:', error);
			branchPerformance.error = 'Failed to load branch performance data';
		} finally {
			branchPerformance.loading = false;
		}
	}
</script>

<div class="branch-performance-page">
	<div class="page-header">
		<h1>{getTranslation('mobile.dashboardContent.branchPerformance.title')}</h1>
		<button class="refresh-btn" on:click={loadBranchPerformance} disabled={branchPerformance.loading}>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
			</svg>
		</button>
	</div>

	{#if branchPerformance.error}
		<div class="error-message">
			<p>{branchPerformance.error}</p>
		</div>
	{/if}

	{#if branchPerformance.loading}
		<div class="loading-container">
			<div class="spinner"></div>
			<p>{getTranslation('mobile.dashboardContent.branchPerformance.loadingData')}</p>
		</div>
	{:else}
		<!-- Today's Performance -->
		<section class="performance-section">
			<h2>{getTranslation('mobile.dashboardContent.branchPerformance.todayPerformance')}</h2>
			<div class="branch-grid">
				{#each branchPerformance.todayStats as stat}
					<div class="branch-card">
						<h3 class="branch-name">{stat.branchName}</h3>
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
									<text x="50" y="58" text-anchor="middle" class="pie-label">{getTranslation('mobile.dashboardContent.branchPerformance.complete')}</text>
								{:else}
									<circle cx="50" cy="50" r="40" fill="none" stroke="#E5E7EB" stroke-width="20"/>
									<text x="50" y="53" text-anchor="middle" class="pie-empty">{getTranslation('mobile.dashboardContent.branchPerformance.noTasks')}</text>
								{/if}
							</svg>
						</div>
						<div class="branch-stats">
							<div class="stat-item completed">
								<span class="stat-dot"></span>
								<span>{stat.completed} {getTranslation('mobile.dashboardContent.branchPerformance.completed')}</span>
							</div>
							<div class="stat-item pending">
								<span class="stat-dot"></span>
								<span>{stat.pending} {getTranslation('mobile.dashboardContent.branchPerformance.pending')}</span>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</section>

		<!-- Yesterday's Performance -->
		<section class="performance-section">
			<h2>{getTranslation('mobile.dashboardContent.branchPerformance.yesterdayPerformance')}</h2>
			<div class="branch-grid">
				{#each branchPerformance.yesterdayStats as stat}
					<div class="branch-card">
						<h3 class="branch-name">{stat.branchName}</h3>
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
									<text x="50" y="58" text-anchor="middle" class="pie-label">{getTranslation('mobile.dashboardContent.branchPerformance.complete')}</text>
								{:else}
									<circle cx="50" cy="50" r="40" fill="none" stroke="#E5E7EB" stroke-width="20"/>
									<text x="50" y="53" text-anchor="middle" class="pie-empty">{getTranslation('mobile.dashboardContent.branchPerformance.noTasks')}</text>
								{/if}
							</svg>
						</div>
						<div class="branch-stats">
							<div class="stat-item completed">
								<span class="stat-dot"></span>
								<span>{stat.completed} {getTranslation('mobile.dashboardContent.branchPerformance.completed')}</span>
							</div>
							<div class="stat-item pending">
								<span class="stat-dot"></span>
								<span>{stat.pending} {getTranslation('mobile.dashboardContent.branchPerformance.pending')}</span>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</section>
	{/if}
</div>

<style>
	.branch-performance-page {
		padding: 1rem;
		background: #F8FAFC;
		min-height: 100vh;
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.5rem;
	}

	.page-header h1 {
		margin: 0;
		font-size: 1.5rem;
		color: #1F2937;
		font-weight: 700;
	}

	.refresh-btn {
		width: 40px;
		height: 40px;
		background: #3B82F6;
		border: none;
		border-radius: 8px;
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563EB;
		transform: scale(1.05);
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.error-message {
		background: #FEE2E2;
		border: 1px solid #FECACA;
		color: #DC2626;
		padding: 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
		color: #6B7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.performance-section {
		margin-bottom: 2rem;
	}

	.performance-section h2 {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1rem 0;
	}

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
		gap: 1rem;
	}

	.branch-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		transition: all 0.2s ease;
	}

	.branch-card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
		transform: translateY(-2px);
	}

	.branch-name {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.pie-chart-container {
		width: 120px;
		height: 120px;
		margin: 0 auto 1rem;
	}

	.pie-chart {
		width: 100%;
		height: 100%;
	}

	.pie-percent {
		font-size: 18px;
		font-weight: 700;
		fill: #1F2937;
	}

	.pie-label {
		font-size: 10px;
		fill: #6B7280;
	}

	.pie-empty {
		font-size: 11px;
		fill: #9CA3AF;
	}

	.branch-stats {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #4B5563;
	}

	.stat-item.completed .stat-dot {
		background: #10B981;
	}

	.stat-item.pending .stat-dot {
		background: #FCA5A5;
	}

	.stat-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex-shrink: 0;
	}
</style>
