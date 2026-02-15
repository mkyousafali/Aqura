<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';

	let currentUserData = null;
	let branchPerformance = {
		branches: [],
		dailyStats: [] as Array<{ label: string; dateStr: string; stats: Array<{ branchName: string; completed: number; pending: number; total: number }> }>,
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

			// Build 7 days of date ranges (today + 6 previous days)
			const days: Array<{ label: string; dateStr: string; startUTC: Date; endUTC: Date }> = [];
			const isArabic = $localeData.code === 'ar';
			
			for (let i = 0; i < 7; i++) {
				const dayDate = new Date(saudiNow.getTime() - i * 86400000);
				const dateStr = dayDate.toISOString().split('T')[0];
				
				const startUTC = new Date(`${dateStr}T00:00:00Z`);
				startUTC.setHours(startUTC.getHours() - 3);
				const endUTC = new Date(`${dateStr}T23:59:59Z`);
				endUTC.setHours(endUTC.getHours() - 3);

				let label: string;
				if (i === 0) {
					label = getTranslation('mobile.dashboardContent.branchPerformance.todayPerformance');
				} else if (i === 1) {
					label = getTranslation('mobile.dashboardContent.branchPerformance.yesterdayPerformance');
				} else {
					// Show formatted date for older days
					const d = new Date(dateStr + 'T12:00:00');
					label = d.toLocaleDateString(isArabic ? 'ar-SA' : 'en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
				}

				days.push({ label, dateStr, startUTC, endUTC });
			}

		// Fetch ALL receiving_records and quick_tasks for branch mapping (no filters - complete maps)
		const [allRecordsResult, allQuickTasksResult] = await Promise.all([
			supabase.from('receiving_records').select('id, branch_id'),
			supabase.from('quick_tasks').select('id, assigned_to_branch_id')
		]);

		const recordBranchMap: Record<string, string> = {};
		if (allRecordsResult.data) {
			allRecordsResult.data.forEach((r: any) => {
				recordBranchMap[r.id] = r.branch_id;
			});
		}

		const quickTaskBranchMap: Record<string, string> = {};
		if (allQuickTasksResult.data) {
			allQuickTasksResult.data.forEach((qt: any) => {
				quickTaskBranchMap[qt.id] = qt.assigned_to_branch_id;
			});
		}

		// Fetch all 3 task types for all 7 days in parallel (21 queries)
		const dayQueries = days.map(day => [
			supabase.from('receiving_tasks')
				.select('id, task_status, receiving_record_id')
				.gte('created_at', day.startUTC.toISOString())
				.lt('created_at', day.endUTC.toISOString()),
			supabase.from('task_assignments')
				.select('id, status, assigned_to_branch_id')
				.gte('assigned_at', day.startUTC.toISOString())
				.lt('assigned_at', day.endUTC.toISOString()),
			supabase.from('quick_task_assignments')
				.select('id, status, quick_task_id')
				.gte('created_at', day.startUTC.toISOString())
				.lt('created_at', day.endUTC.toISOString())
		]);

		const allResults = await Promise.all(dayQueries.flat());

		// Helper: distribute tasks into per-branch stats
		function buildBranchStatsMap(
			receiving: any[],
			tasks: any[],
			quick: any[]
		): Record<string, { completed: number; pending: number; total: number }> {
			const statsMap: Record<string, { completed: number; pending: number; total: number }> = {};

			const ensure = (branchId: string) => {
				if (!statsMap[branchId]) {
					statsMap[branchId] = { completed: 0, pending: 0, total: 0 };
				}
			};

			receiving.forEach((item: any) => {
				if (item.task_status === 'cancelled') return;
				const branchId = recordBranchMap[item.receiving_record_id];
				if (!branchId) return;
				ensure(branchId);
				statsMap[branchId].total++;
				if (item.task_status === 'completed') statsMap[branchId].completed++;
				else statsMap[branchId].pending++;
			});

			tasks.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				const branchId = item.assigned_to_branch_id;
				if (!branchId) return;
				ensure(branchId);
				statsMap[branchId].total++;
				if (item.status === 'completed') statsMap[branchId].completed++;
				else statsMap[branchId].pending++;
			});

			quick.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				const branchId = quickTaskBranchMap[item.quick_task_id];
				if (!branchId) return;
				ensure(branchId);
				statsMap[branchId].total++;
				if (item.status === 'completed') statsMap[branchId].completed++;
				else statsMap[branchId].pending++;
			});

			return statsMap;
		}

		// Build daily stats for each of the 7 days
		branchPerformance.dailyStats = days.map((day, i) => {
			const receiving = allResults[i * 3 + 0].data || [];
			const tasks = allResults[i * 3 + 1].data || [];
			const quick = allResults[i * 3 + 2].data || [];

			const statsMap = buildBranchStatsMap(receiving, tasks, quick);

			const stats = branchPerformance.branches.map((branch: any) => {
				const branchName = isArabic ? branch.name_ar : branch.name_en;
				const branchLocation = isArabic ? branch.location_ar : branch.location_en;
				const branchDisplay = `${branchName} - ${branchLocation}`;
				const s = statsMap[branch.id] || { completed: 0, pending: 0, total: 0 };
				return { branchName: branchDisplay, ...s };
			});

			return { label: day.label, dateStr: day.dateStr, stats };
		});

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
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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
		{#each branchPerformance.dailyStats as day}
			{@const filteredStats = day.stats.filter(s => s.total > 0)}
			{#if filteredStats.length > 0}
				<section class="performance-section">
					<h2>{day.label}</h2>
					<div class="branch-grid">
						{#each filteredStats as stat}
							<div class="branch-card">
								<h3 class="branch-name">{stat.branchName}</h3>
								<div class="pie-chart-container">
									<svg viewBox="0 0 100 100" class="pie-chart">
										{#if stat.total > 0}
											{@const completedPercent = (stat.completed / stat.total) * 100}
											{@const radius = 40}
											{@const circumference = 2 * Math.PI * radius}
											{@const completedOffset = circumference - (completedPercent / 100) * circumference}
											
											<circle cx="50" cy="50" r="40" fill="none" stroke="#FCA5A5" stroke-width="20"/>
											
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
											
											<text x="50" y="47" text-anchor="middle" class="pie-percent">{completedPercent.toFixed(0)}%</text>
											<text x="50" y="58" text-anchor="middle" class="pie-label">{getTranslation('mobile.dashboardContent.branchPerformance.complete')}</text>
										{:else}
											<circle cx="50" cy="50" r="40" fill="none" stroke="#E5E7EB" stroke-width="20"/>
											<text x="50" y="53" text-anchor="middle" class="pie-empty">{getTranslation('mobile.dashboardContent.branchPerformance.noTasks')}</text>
										{/if}
									</svg>
								</div>
								<div class="branch-stats">
									<div class="stat-item total">
										<span class="stat-dot"></span>
										<span>{stat.total} {getTranslation('mobile.dashboardContent.branchPerformance.total')}</span>
									</div>
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
		{/each}
	{/if}
</div>

<style>
	.branch-performance-page {
		padding: 0;
		padding-bottom: 0.5rem;
		background: #F8FAFC;
		min-height: 100%;
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.4rem 0.6rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
		margin-bottom: 0;
	}

	.page-header h1 {
		margin: 0;
		font-size: 0.88rem;
		color: #1F2937;
		font-weight: 600;
	}

	.refresh-btn {
		width: 30px;
		height: 30px;
		background: #3B82F6;
		border: none;
		border-radius: 5px;
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
		padding: 0.4rem 0.6rem;
		border-radius: 5px;
		margin: 0.4rem 0.6rem;
		font-size: 0.78rem;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		color: #6B7280;
		font-size: 0.82rem;
	}

	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 0.5rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.performance-section {
		margin-bottom: 0.4rem;
		padding: 0.4rem 0.6rem;
	}

	.performance-section h2 {
		font-size: 0.82rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.4rem 0;
	}

	.branch-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
		gap: 0.4rem;
	}

	.branch-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem;
		border: 1px solid #E5E7EB;
		transition: all 0.2s ease;
	}

	.branch-card:hover {
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
		transform: translateY(-1px);
	}

	.branch-name {
		margin: 0 0 0.3rem 0;
		font-size: 0.76rem;
		font-weight: 600;
		color: #1F2937;
		line-height: 1.3;
	}

	.pie-chart-container {
		width: 85px;
		height: 85px;
		margin: 0 auto 0.3rem;
	}

	.pie-chart {
		width: 100%;
		height: 100%;
	}

	.pie-percent {
		font-size: 16px;
		font-weight: 700;
		fill: #1F2937;
	}

	.pie-label {
		font-size: 8px;
		fill: #6B7280;
	}

	.pie-empty {
		font-size: 9px;
		fill: #9CA3AF;
	}

	.branch-stats {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.7rem;
		color: #4B5563;
	}

	.stat-item.total .stat-dot {
		background: #3B82F6;
	}

	.stat-item.total {
		font-weight: 600;
	}

	.stat-item.completed .stat-dot {
		background: #10B981;
	}

	.stat-item.pending .stat-dot {
		background: #FCA5A5;
	}

	.stat-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}
</style>
