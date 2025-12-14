<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { t, currentLocale } from '$lib/i18n';

	export let onClose: () => void;

	let loading = false;
	let fromDate = '';
	let toDate = '';
	let specificDate = '';
	let loadingCard2 = false;
	
	// Stats for pie chart
	let stats = {
		completed: 0,
		notCompleted: 0,
		total: 0
	};

	// Card 2 stats
	let statsCard2 = {
		completed: 0,
		notCompleted: 0,
		total: 0
	};

	// Branch-wise stats
	let branchStats: Record<string, { name: string; completed: number; notCompleted: number; total: number }> = {};
	
	// Card 2 branch-wise stats
	let branchStatsCard2: Record<string, { name: string; completed: number; notCompleted: number; total: number }> = {};

	// Card 3 - Last 3 Days
	let selectedBranchCard3 = '';
	let loadingCard3 = false;
	let allBranches: Array<{ id: string; name_en: string; name_ar: string }> = [];
	
	// Card 3 stats for each day
	let statsCard3Day1: Record<string, number> = {}; // Today
	let statsCard3Day2: Record<string, number> = {}; // Yesterday
	let statsCard3Day3: Record<string, number> = {}; // 2 days ago

	onMount(async () => {
		console.log('📊 [BranchPerformanceWindow] Component initialized');
		// Load all branches for Card 3 dropdown
		const { data: branchesData } = await supabase
			.from('branches')
			.select('id, name_en, name_ar');
		if (branchesData) {
			allBranches = branchesData;
		}
	});

	async function loadBranchPerformance() {
		if (!fromDate || !toDate) {
			alert('Please select both From Date and To Date');
			return;
		}

		loading = true;
		console.log('📊 Loading branch performance for period:', fromDate, 'to', toDate);

		try {
			const startDate = `${fromDate}T00:00:00`;
			const endDate = `${toDate}T23:59:59`;

			// Fetch receiving tasks
			const { data: receivingData, error: recError } = await supabase
				.from('receiving_tasks')
				.select('id, task_status, created_at, receiving_record_id')
				.gte('created_at', startDate)
				.lte('created_at', endDate);

			if (recError) throw recError;

			// Fetch task assignments with branch ID
			const { data: tasksData, error: taskError } = await supabase
				.from('task_assignments')
				.select('id, status, assigned_at, assigned_to_branch_id')
				.gte('assigned_at', startDate)
				.lte('assigned_at', endDate);

			if (taskError) throw taskError;

			// Fetch quick task assignments
			const { data: quickData, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select('id, status, created_at, quick_task_id')
				.gte('created_at', startDate)
				.lte('created_at', endDate);

			if (quickError) throw quickError;

			// Fetch receiving records to map to branches
			let recordMap: Record<string, string> = {};
			const receiving = receivingData || [];
			if (receiving.length > 0) {
				const recordIds = [...new Set(receiving.map((r: any) => r.receiving_record_id).filter(Boolean))];
				if (recordIds.length > 0) {
					const { data: records } = await supabase
						.from('receiving_records')
						.select('id, branch_id');
					if (records) {
						records.forEach((r: any) => {
							recordMap[r.id] = r.branch_id;
						});
					}
				}
			}

			// Fetch all branches
			const { data: branchesData } = await supabase
				.from('branches')
				.select('id, name_en, name_ar');
			const branchMap: Record<string, string> = {};
			if (branchesData) {
				branchesData.forEach((b: any) => {
					branchMap[b.id] = b.name_en || b.name_ar || `Branch ${b.id}`;
				});
			}

			// Fetch quick tasks for branch mapping
			let quickTaskMap: Record<string, string> = {};
			const quick = quickData || [];
			if (quick.length > 0) {
				const quickTaskIds = [...new Set(quick.map((q: any) => q.quick_task_id).filter(Boolean))];
				if (quickTaskIds.length > 0) {
					const { data: quickTasks } = await supabase
						.from('quick_tasks')
						.select('id, assigned_to_branch_id');
					if (quickTasks) {
						quickTasks.forEach((qt: any) => {
							quickTaskMap[qt.id] = qt.assigned_to_branch_id;
						});
					}
				}
			}

			// Initialize branch stats
			branchStats = {};

			// Process receiving tasks
			let totalCompleted = 0;
			let totalTasks = 0;
			
			console.log('📦 Receiving tasks fetched:', receiving.length);
			receiving.forEach((item: any) => {
				if (item.task_status === 'cancelled') return;
				
				const branchId = recordMap[item.receiving_record_id];
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.task_status === 'completed';

				if (branchId) {
					if (!branchStats[branchId]) {
						branchStats[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStats[branchId].total++;
					if (isCompleted) branchStats[branchId].completed++;
					else branchStats[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Process task assignments
			const tasks = tasksData || [];
			console.log('📋 Task assignments fetched:', tasks.length);
			tasks.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				
				const branchId = item.assigned_to_branch_id;
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.status === 'completed';

				if (branchId) {
					if (!branchStats[branchId]) {
						branchStats[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStats[branchId].total++;
					if (isCompleted) branchStats[branchId].completed++;
					else branchStats[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Process quick task assignments
			console.log('⚡ Quick tasks fetched:', quick.length);
			quick.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				
				const branchId = quickTaskMap[item.quick_task_id];
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.status === 'completed';

				if (branchId) {
					if (!branchStats[branchId]) {
						branchStats[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStats[branchId].total++;
					if (isCompleted) branchStats[branchId].completed++;
					else branchStats[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Set total stats
			stats = {
				completed: totalCompleted,
				notCompleted: totalTasks - totalCompleted,
				total: totalTasks
			};

			console.log('✅ Branch performance loaded:', stats);
			console.log('🏢 Branch breakdown:', branchStats);
		} catch (error) {
			console.error('❌ Error loading branch performance:', error);
			alert('Error loading branch performance data');
		} finally {
			loading = false;
		}
	}

	async function loadSpecificDatePerformance() {
		if (!specificDate) {
			alert('Please select a specific date');
			return;
		}

		loadingCard2 = true;
		console.log('📊 Loading specific date performance for:', specificDate);

		try {
			const startDate = `${specificDate}T00:00:00`;
			const endDate = `${specificDate}T23:59:59`;

			// Fetch receiving tasks
			const { data: receivingData, error: recError } = await supabase
				.from('receiving_tasks')
				.select('id, task_status, created_at, receiving_record_id')
				.gte('created_at', startDate)
				.lte('created_at', endDate);

			if (recError) throw recError;

			// Fetch task assignments with branch ID
			const { data: tasksData, error: taskError } = await supabase
				.from('task_assignments')
				.select('id, status, assigned_at, assigned_to_branch_id')
				.gte('assigned_at', startDate)
				.lte('assigned_at', endDate);

			if (taskError) throw taskError;

			// Fetch quick task assignments
			const { data: quickData, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select('id, status, created_at, quick_task_id')
				.gte('created_at', startDate)
				.lte('created_at', endDate);

			if (quickError) throw quickError;

			// Fetch receiving records to map to branches
			let recordMap: Record<string, string> = {};
			const receiving = receivingData || [];
			if (receiving.length > 0) {
				const recordIds = [...new Set(receiving.map((r: any) => r.receiving_record_id).filter(Boolean))];
				if (recordIds.length > 0) {
					const { data: records } = await supabase
						.from('receiving_records')
						.select('id, branch_id');
					if (records) {
						records.forEach((r: any) => {
							recordMap[r.id] = r.branch_id;
						});
					}
				}
			}

			// Fetch all branches
			const { data: branchesData } = await supabase
				.from('branches')
				.select('id, name_en, name_ar');
			const branchMap: Record<string, string> = {};
			if (branchesData) {
				branchesData.forEach((b: any) => {
					branchMap[b.id] = b.name_en || b.name_ar || `Branch ${b.id}`;
				});
			}

			// Fetch quick tasks for branch mapping
			let quickTaskMap: Record<string, string> = {};
			const quick = quickData || [];
			if (quick.length > 0) {
				const quickTaskIds = [...new Set(quick.map((q: any) => q.quick_task_id).filter(Boolean))];
				if (quickTaskIds.length > 0) {
					const { data: quickTasks } = await supabase
						.from('quick_tasks')
						.select('id, assigned_to_branch_id');
					if (quickTasks) {
						quickTasks.forEach((qt: any) => {
							quickTaskMap[qt.id] = qt.assigned_to_branch_id;
						});
					}
				}
			}

			// Initialize branch stats
			branchStatsCard2 = {};

			// Process receiving tasks
			let totalCompleted = 0;
			let totalTasks = 0;
			
			console.log('📦 Receiving tasks fetched:', receiving.length);
			receiving.forEach((item: any) => {
				if (item.task_status === 'cancelled') return;
				
				const branchId = recordMap[item.receiving_record_id];
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.task_status === 'completed';

				if (branchId) {
					if (!branchStatsCard2[branchId]) {
						branchStatsCard2[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStatsCard2[branchId].total++;
					if (isCompleted) branchStatsCard2[branchId].completed++;
					else branchStatsCard2[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Process task assignments
			const tasks = tasksData || [];
			console.log('📋 Task assignments fetched:', tasks.length);
			tasks.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				
				const branchId = item.assigned_to_branch_id;
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.status === 'completed';

				if (branchId) {
					if (!branchStatsCard2[branchId]) {
						branchStatsCard2[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStatsCard2[branchId].total++;
					if (isCompleted) branchStatsCard2[branchId].completed++;
					else branchStatsCard2[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Process quick task assignments
			console.log('⚡ Quick tasks fetched:', quick.length);
			quick.forEach((item: any) => {
				if (item.status === 'cancelled') return;
				
				const branchId = quickTaskMap[item.quick_task_id];
				const branchName = branchId ? (branchMap[branchId] || 'Unknown') : 'Unknown';
				const isCompleted = item.status === 'completed';

				if (branchId) {
					if (!branchStatsCard2[branchId]) {
						branchStatsCard2[branchId] = { name: branchName, completed: 0, notCompleted: 0, total: 0 };
					}
					branchStatsCard2[branchId].total++;
					if (isCompleted) branchStatsCard2[branchId].completed++;
					else branchStatsCard2[branchId].notCompleted++;
				}

				totalTasks++;
				if (isCompleted) totalCompleted++;
			});

			// Set total stats for card 2
			statsCard2 = {
				completed: totalCompleted,
				notCompleted: totalTasks - totalCompleted,
				total: totalTasks
			};

			console.log('✅ Specific date performance loaded:', statsCard2);
			console.log('🏢 Branch breakdown:', branchStatsCard2);
		} catch (error) {
			console.error('❌ Error loading specific date performance:', error);
			alert('Error loading specific date performance data');
		} finally {
			loadingCard2 = false;
		}
	}

	function calculatePieChart() {
		if (stats.total === 0) return { completed: 0, notCompleted: 0 };

		const completedPercent = (stats.completed / stats.total) * 100;
		const notCompletedPercent = (stats.notCompleted / stats.total) * 100;

		return { completedPercent, notCompletedPercent };
	}

	async function loadCard3Performance() {
		if (!selectedBranchCard3) {
			alert('Please select a branch');
			return;
		}

		loadingCard3 = true;
		console.log('📊 Loading Card 3 performance for branch:', selectedBranchCard3);

		try {
			// Get today's date
			const today = new Date();
			const day1 = new Date(today);
			day1.setDate(day1.getDate()); // Today
			const day2 = new Date(today);
			day2.setDate(day2.getDate() - 1); // Yesterday
			const day3 = new Date(today);
			day3.setDate(day3.getDate() - 2); // 2 days ago

			const formatDate = (date: Date) => date.toISOString().split('T')[0];
			const dateStr1 = formatDate(day1);
			const dateStr2 = formatDate(day2);
			const dateStr3 = formatDate(day3);

			console.log('📊 Card 3 dates:', dateStr1, dateStr2, dateStr3);

			// Helper function to fetch stats for a specific date
			const fetchDayStats = async (dateStr: string) => {
				const startTime = `${dateStr}T00:00:00`;
				const endTime = `${dateStr}T23:59:59`;

				// Fetch receiving tasks
				const { data: receivingData } = await supabase
					.from('receiving_tasks')
					.select('id, task_status, receiving_record_id')
					.gte('created_at', startTime)
					.lte('created_at', endTime);

				// Fetch task assignments
				const { data: tasksData } = await supabase
					.from('task_assignments')
					.select('id, status, assigned_to_branch_id')
					.gte('assigned_at', startTime)
					.lte('assigned_at', endTime);

				// Fetch receiving records to map to branches
				let recordMap: Record<string, string> = {};
				const receiving = receivingData || [];
				if (receiving.length > 0) {
					const recordIds = [...new Set(receiving.map((r: any) => r.receiving_record_id).filter(Boolean))];
					if (recordIds.length > 0) {
						const { data: records } = await supabase
							.from('receiving_records')
							.select('id, branch_id');
						if (records) {
							records.forEach((r: any) => {
								recordMap[r.id] = r.branch_id;
							});
						}
					}
				}

				// Count tasks for selected branch
				let completed = 0;
				let notCompleted = 0;

				// Count receiving tasks for branch
				receiving.forEach((task: any) => {
					const branchId = recordMap[task.receiving_record_id];
					if (branchId === selectedBranchCard3) {
						if (task.task_status === 'completed') {
							completed++;
						} else {
							notCompleted++;
						}
					}
				});

				// Count task assignments for branch
				(tasksData || []).forEach((task: any) => {
					if (task.assigned_to_branch_id === selectedBranchCard3) {
						if (task.status === 'completed') {
							completed++;
						} else {
							notCompleted++;
						}
					}
				});

				return { completed, notCompleted, total: completed + notCompleted };
			};

			// Fetch stats for all 3 days
			const [day1Stats, day2Stats, day3Stats] = await Promise.all([
				fetchDayStats(dateStr1),
				fetchDayStats(dateStr2),
				fetchDayStats(dateStr3)
			]);

			statsCard3Day1 = day1Stats;
			statsCard3Day2 = day2Stats;
			statsCard3Day3 = day3Stats;

			console.log('📊 Card 3 stats:', { day1: statsCard3Day1, day2: statsCard3Day2, day3: statsCard3Day3 });
		} catch (error) {
			console.error('❌ Error loading Card 3 performance:', error);
			alert('Error loading performance data');
		} finally {
			loadingCard3 = false;
		}
	}

	function polarToCartesian(centerX: number, centerY: number, radius: number, angleInDegrees: number) {
		const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
		return {
			x: centerX + (radius * Math.cos(angleInRadians)),
			y: centerY + (radius * Math.sin(angleInRadians))
		};
	}

	function createArcPath(centerX: number, centerY: number, radius: number, startAngle: number, endAngle: number) {
		const start = polarToCartesian(centerX, centerY, radius, endAngle);
		const end = polarToCartesian(centerX, centerY, radius, startAngle);
		const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
		
		return [
			"M", centerX, centerY,
			"L", start.x, start.y,
			"A", radius, radius, 0, largeArcFlag, 0, end.x, end.y,
			"Z"
		].join(" ");
	}

	function createPieSegments(total: number, completed: number) {
		if (total === 0) return [];
		
		const completedAngle = (completed / total) * 360;
		const segments = [];
		const notCompleted = total - completed;

		// If no completed tasks, show full red circle (split into two 180° arcs)
		if (completed === 0) {
			segments.push({
				path: createArcPath(60, 60, 50, 0, 180),
				shadowPath: createArcPath(60, 62, 50, 0, 180),
				color: '#fa003f',
				shadowColor: '#c90030',
				label: 'Not Completed'
			});
			segments.push({
				path: createArcPath(60, 60, 50, 180, 360),
				shadowPath: createArcPath(60, 62, 50, 180, 360),
				color: '#fa003f',
				shadowColor: '#c90030',
				label: 'Not Completed'
			});
		} else {
			// Not completed segment (drawn first for layering) - RED
			if (notCompleted > 0) {
				segments.push({
					path: createArcPath(60, 60, 50, completedAngle, 360),
					shadowPath: createArcPath(60, 62, 50, completedAngle, 360),
					color: '#fa003f',
					shadowColor: '#c90030',
					label: 'Not Completed'
				});
			}

			// Completed segment (drawn last to appear on top) - GREEN
			segments.push({
				path: createArcPath(60, 60, 50, 0, completedAngle),
				shadowPath: createArcPath(60, 62, 50, 0, completedAngle),
				color: '#008000',
				shadowColor: '#005500',
				label: 'Completed'
			});
		}

		return segments;
	}

	function createSmallPieSegments(total: number, completed: number) {
		if (total === 0) return [];
		
		const completedAngle = (completed / total) * 360;
		const segments = [];
		const notCompleted = total - completed;

		// If no completed tasks, show full red circle (split into two 180° arcs)
		if (completed === 0) {
			segments.push({
				path: createArcPath(50, 50, 40, 0, 180),
				shadowPath: createArcPath(50, 51, 40, 0, 180),
				color: '#fa003f',
				shadowColor: '#c90030',
				label: 'Not Completed'
			});
			segments.push({
				path: createArcPath(50, 50, 40, 180, 360),
				shadowPath: createArcPath(50, 51, 40, 180, 360),
				color: '#fa003f',
				shadowColor: '#c90030',
				label: 'Not Completed'
			});
		} else {
			// Not completed segment (drawn first for layering) - RED
			if (notCompleted > 0) {
				segments.push({
					path: createArcPath(50, 50, 40, completedAngle, 360),
					shadowPath: createArcPath(50, 51, 40, completedAngle, 360),
					color: '#fa003f',
					shadowColor: '#c90030',
					label: 'Not Completed'
				});
			}

			// Completed segment (drawn last to appear on top) - GREEN
			segments.push({
				path: createArcPath(50, 50, 40, 0, completedAngle),
				shadowPath: createArcPath(50, 51, 40, 0, completedAngle),
				color: '#008000',
				shadowColor: '#005500',
				label: 'Completed'
			});
		}

		return segments;
	}

</script>

<div class="bp-container">
	<div class="content">
		<div class="cards-grid">
			<!-- Card 1: Date Range -->
			<div class="card">
				<div class="card-header">
					<h3 class="card-title">{t('mobile.dashboardContent.branchPerformance.dateRange') || '📅 Date Range'}</h3>
				</div>
				<div class="card-body">
					<div class="date-range-form">
						<div class="form-group">
							<label for="from-date">{t('mobile.dashboardContent.branchPerformance.fromDate') || 'From Date'}</label>
							<input
								id="from-date"
								type="date"
								bind:value={fromDate}
								class="date-input"
								disabled={loading}
							/>
						</div>
						<div class="form-group">
							<label for="to-date">{t('mobile.dashboardContent.branchPerformance.toDate') || 'To Date'}</label>
							<input
								id="to-date"
								type="date"
								bind:value={toDate}
								class="date-input"
								disabled={loading}
							/>
						</div>
						<button class="apply-btn" on:click={loadBranchPerformance} disabled={loading}>
							{loading ? t('common.loading') || 'Loading...' : t('mobile.dashboardContent.branchPerformance.loadPerformance') || 'Load Performance'}
						</button>
					</div>

					{#if stats.total > 0}
						{@const { completedPercent } = calculatePieChart()}
						{@const segments = createPieSegments(stats.total, stats.completed)}
						<div class="pie-chart-container">
							<div class="pie-wrapper">
								<h4 class="pie-title">📊 Total Performance</h4>
							<div class="pie-chart-wrapper">
								<svg class="pie-svg" viewBox="0 0 120 120">
									<defs>
										<filter id="shadow-large" x="-50%" y="-50%" width="200%" height="200%">
											<feDropShadow dx="0" dy="3" stdDeviation="2" flood-opacity="0.3" flood-color="#000000" />
										</filter>
										<radialGradient id="grad-green" cx="35%" cy="35%">
											<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
											<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
										</radialGradient>
										<radialGradient id="grad-red" cx="35%" cy="35%">
											<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
											<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
										</radialGradient>
									</defs>
									<!-- Shadow layer -->
									{#each segments as segment}
										<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
									{/each}
									<!-- Main segments with gradient -->
									{#each segments as segment}
										<path 
											d={segment.path} 
											fill={segment.color === '#008000' ? 'url(#grad-green)' : 'url(#grad-red)'}
											filter="url(#shadow-large)"
											stroke="white"
											stroke-width="1"
										/>
									{/each}
								</svg>
								<!-- Center text overlay -->
								<div class="pie-text">
									<div class="pie-percent">{completedPercent.toFixed(0)}%</div>
									<div class="pie-count">{stats.completed}/{stats.total}</div>
								</div>
							</div>
							</div>
						</div>

						<!-- Branch-wise performance -->
						{#if Object.keys(branchStats).length > 0}
							<div class="branches-grid">
								<h4 class="branches-title">🏢 Branch-wise Performance</h4>
								<div class="branches-container">
									{#each Object.entries(branchStats) as [branchId, branch]}
										{@const branchCompleted = branch.completed}
										{@const branchTotal = branch.total}
										{@const branchPercent = branchTotal > 0 ? (branchCompleted / branchTotal) * 100 : 0}
										{@const branchSegments = createSmallPieSegments(branchTotal, branchCompleted)}
										<div class="branch-item">
											<h5 class="branch-name">{$currentLocale === 'ar' ? branch.name_ar : branch.name_en}</h5>
										<div class="pie-chart-wrapper-small">
											<svg class="pie-svg-small" viewBox="0 0 100 100">
												<defs>
													<filter id="shadow-small-{branchId}" x="-50%" y="-50%" width="200%" height="200%">
														<feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-opacity="0.3" flood-color="#000000" />
													</filter>
													<radialGradient id="grad-green-small-{branchId}" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
													</radialGradient>
													<radialGradient id="grad-red-small-{branchId}" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
													</radialGradient>
												</defs>
												<!-- Shadow layer -->
												{#each branchSegments as segment}
													<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
												{/each}
												<!-- Main segments with gradient -->
												{#each branchSegments as segment}
													<path 
														d={segment.path} 
														fill={segment.color === '#008000' ? `url(#grad-green-small-${branchId})` : `url(#grad-red-small-${branchId})`}
														filter="url(#shadow-small-{branchId})"
														stroke="white"
														stroke-width="0.8"
													/>
												{/each}
											</svg>
											<div class="pie-text-small">
												<div class="pie-percent-small">{branchPercent.toFixed(0)}%</div>
												<div class="pie-count-small">{branchCompleted}/{branchTotal}</div>
											</div>
										</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					{/if}
				</div>
			</div>

			<!-- Card 2: Specific Date -->
			<div class="card">
				<div class="card-header">
					<h3 class="card-title">{t('mobile.dashboardContent.branchPerformance.specificDate') || '📅 Specific Date'}</h3>
				</div>
				<div class="card-body">
					<div class="date-range-form">
						<div class="form-group">
							<label for="specific-date">{t('mobile.dashboardContent.branchPerformance.selectDate') || 'Select Date'}</label>
							<input
								id="specific-date"
								type="date"
								bind:value={specificDate}
								class="date-input"
								disabled={loadingCard2}
							/>
						</div>
						<button class="apply-btn" on:click={loadSpecificDatePerformance} disabled={loadingCard2}>
							{loadingCard2 ? t('common.loading') || 'Loading...' : t('mobile.dashboardContent.branchPerformance.loadPerformance') || 'Load Performance'}
						</button>
					</div>

					{#if statsCard2.total > 0}
						{@const { completedPercent: completedPercentCard2 } = (() => {
							const completed = (statsCard2.completed / statsCard2.total) * 100;
							return { completedPercent: completed };
						})()}
						{@const segmentsCard2 = createPieSegments(statsCard2.total, statsCard2.completed)}
						<div class="pie-chart-container">
							<div class="pie-wrapper">
								<h4 class="pie-title">📊 Total Performance</h4>
							<div class="pie-chart-wrapper">
								<svg class="pie-svg" viewBox="0 0 120 120">
									<defs>
										<filter id="shadow-large-card2" x="-50%" y="-50%" width="200%" height="200%">
											<feDropShadow dx="0" dy="3" stdDeviation="2" flood-opacity="0.3" flood-color="#000000" />
										</filter>
										<radialGradient id="grad-green-card2" cx="35%" cy="35%">
											<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
											<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
										</radialGradient>
										<radialGradient id="grad-red-card2" cx="35%" cy="35%">
											<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
											<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
										</radialGradient>
									</defs>
									<!-- Shadow layer -->
									{#each segmentsCard2 as segment}
										<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
									{/each}
									<!-- Main segments with gradient -->
									{#each segmentsCard2 as segment}
										<path 
											d={segment.path} 
											fill={segment.color === '#008000' ? 'url(#grad-green-card2)' : 'url(#grad-red-card2)'}
											filter="url(#shadow-large-card2)"
											stroke="white"
											stroke-width="1"
										/>
									{/each}
								</svg>
								<!-- Center text overlay -->
								<div class="pie-text">
									<div class="pie-percent">{completedPercentCard2.toFixed(0)}%</div>
									<div class="pie-count">{statsCard2.completed}/{statsCard2.total}</div>
								</div>
							</div>
							</div>
						</div>

						<!-- Branch-wise performance -->
						{#if Object.keys(branchStatsCard2).length > 0}
							<div class="branches-grid">
								<h4 class="branches-title">🏢 Branch-wise Performance</h4>
								<div class="branches-container">
									{#each Object.entries(branchStatsCard2) as [branchId, branch]}
										{@const branchCompleted = branch.completed}
										{@const branchTotal = branch.total}
										{@const branchPercent = branchTotal > 0 ? (branchCompleted / branchTotal) * 100 : 0}
										{@const branchSegmentsCard2 = createSmallPieSegments(branchTotal, branchCompleted)}
										<div class="branch-item">
											<h5 class="branch-name">{$currentLocale === 'ar' ? branch.name_ar : branch.name_en}</h5>
										<div class="pie-chart-wrapper-small">
											<svg class="pie-svg-small" viewBox="0 0 100 100">
												<defs>
													<filter id="shadow-small-card2-{branchId}" x="-50%" y="-50%" width="200%" height="200%">
														<feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-opacity="0.3" flood-color="#000000" />
													</filter>
													<radialGradient id="grad-green-small-card2-{branchId}" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
													</radialGradient>
													<radialGradient id="grad-red-small-card2-{branchId}" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
													</radialGradient>
												</defs>
												<!-- Shadow layer -->
												{#each branchSegmentsCard2 as segment}
													<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
												{/each}
												<!-- Main segments with gradient -->
												{#each branchSegmentsCard2 as segment}
													<path 
														d={segment.path} 
														fill={segment.color === '#008000' ? `url(#grad-green-small-card2-${branchId})` : `url(#grad-red-small-card2-${branchId})`}
														filter="url(#shadow-small-card2-{branchId})"
														stroke="white"
														stroke-width="0.8"
													/>
												{/each}
											</svg>
											<div class="pie-text-small">
												<div class="pie-percent-small">{branchPercent.toFixed(0)}%</div>
												<div class="pie-count-small">{branchCompleted}/{branchTotal}</div>
											</div>
										</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					{/if}
				</div>
			</div>

			<!-- Card 3 -->
			<div class="card">
				<div class="card-header">
					<h3 class="card-title">{t('mobile.dashboardContent.branchPerformance.last3Days') || 'Last 3 Days Performance'}</h3>
				</div>
				<div class="card-body">
					<div class="input-group">
						<label>{t('mobile.dashboardContent.branchPerformance.selectBranch') || 'Select Branch:'}</label>
						<select bind:value={selectedBranchCard3}>
							<option value="">{t('common.chooseBranch') || '-- Choose Branch --'}</option>
							{#each allBranches as branch (branch.id)}
								<option value={branch.id}>{$currentLocale === 'ar' ? branch.name_ar : branch.name_en}</option>
							{/each}
						</select>
					</div>

				<button class="load-btn" on:click={loadCard3Performance} disabled={loadingCard3}>
					{loadingCard3 ? t('common.loading') || '⏳ Loading...' : t('mobile.dashboardContent.branchPerformance.loadPerformance') || '📊 Load Performance'}
				</button>					{#if !loadingCard3}
						<div class="days-container">
							<!-- Day 1: Today -->
							<div class="day-card">
								{#if true}
									{@const today = new Date()}
									{@const day1Str = today.toLocaleDateString('en-GB')}
									{@const day1Str2 = today.getDate()}
									<h4 class="day-title">{t('common.today') || 'Today'} ({day1Str})</h4>
									{#if statsCard3Day1 && statsCard3Day1.total > 0}
										{@const day1Segments = createSmallPieSegments(statsCard3Day1.total, statsCard3Day1.completed)}
										{@const day1Percent = statsCard3Day1.total > 0 ? (statsCard3Day1.completed / statsCard3Day1.total) * 100 : 0}
										<div class="pie-chart-wrapper-small">
											<svg class="pie-svg-small" viewBox="0 0 100 100">
												<defs>
													<filter id="shadow-day1" x="-50%" y="-50%" width="200%" height="200%">
														<feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-opacity="0.3" flood-color="#000000" />
													</filter>
													<radialGradient id="grad-green-day1" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
													</radialGradient>
													<radialGradient id="grad-red-day1" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
													</radialGradient>
												</defs>
												<!-- Shadow layer -->
												{#each day1Segments as segment}
													<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
												{/each}
												<!-- Main segments with gradient -->
												{#each day1Segments as segment}
													<path 
														d={segment.path} 
														fill={segment.color === '#008000' ? 'url(#grad-green-day1)' : 'url(#grad-red-day1)'}
														filter="url(#shadow-day1)"
														stroke="white"
														stroke-width="0.8"
													/>
												{/each}
											</svg>
											<div class="pie-text-small">
												<div class="pie-percent-small">{day1Percent.toFixed(0)}%</div>
												<div class="pie-count-small">{statsCard3Day1.completed}/{statsCard3Day1.total}</div>
											</div>
										</div>
									{:else}
										<div class="no-data">{t('mobile.dashboardContent.branchPerformance.noDataToday') || 'No data for today'}</div>
									{/if}
								{/if}
							</div>

							<!-- Day 2: Yesterday -->
							<div class="day-card">
								{#if true}
									{@const yesterday = (() => { const d = new Date(); d.setDate(d.getDate() - 1); return d; })()}
									{@const day2Str = yesterday.toLocaleDateString('en-GB')}
									<h4 class="day-title">{t('common.yesterday') || 'Yesterday'} ({day2Str})</h4>
									{#if statsCard3Day2 && statsCard3Day2.total > 0}
										{@const day2Segments = createSmallPieSegments(statsCard3Day2.total, statsCard3Day2.completed)}
										{@const day2Percent = statsCard3Day2.total > 0 ? (statsCard3Day2.completed / statsCard3Day2.total) * 100 : 0}
										<div class="pie-chart-wrapper-small">
											<svg class="pie-svg-small" viewBox="0 0 100 100">
												<defs>
													<filter id="shadow-day2" x="-50%" y="-50%" width="200%" height="200%">
														<feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-opacity="0.3" flood-color="#000000" />
													</filter>
													<radialGradient id="grad-green-day2" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
													</radialGradient>
													<radialGradient id="grad-red-day2" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
													</radialGradient>
												</defs>
												<!-- Shadow layer -->
												{#each day2Segments as segment}
													<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
												{/each}
												<!-- Main segments with gradient -->
												{#each day2Segments as segment}
													<path 
														d={segment.path} 
														fill={segment.color === '#008000' ? 'url(#grad-green-day2)' : 'url(#grad-red-day2)'}
														filter="url(#shadow-day2)"
														stroke="white"
														stroke-width="0.8"
													/>
												{/each}
											</svg>
											<div class="pie-text-small">
												<div class="pie-percent-small">{day2Percent.toFixed(0)}%</div>
												<div class="pie-count-small">{statsCard3Day2.completed}/{statsCard3Day2.total}</div>
											</div>
										</div>
									{:else}
										<div class="no-data">{t('mobile.dashboardContent.branchPerformance.noDataYesterday') || 'No data for yesterday'}</div>
									{/if}
								{/if}
							</div>

							<!-- Day 3: 2 Days Ago -->
							<div class="day-card">
								{#if true}
									{@const twodaysago = (() => { const d = new Date(); d.setDate(d.getDate() - 2); return d; })()}
									{@const day3Str = twodaysago.toLocaleDateString('en-GB')}
									<h4 class="day-title">{t('mobile.dashboardContent.branchPerformance.twoDaysAgo') || '2 Days Ago'} ({day3Str})</h4>
									{#if statsCard3Day3 && statsCard3Day3.total > 0}
										{@const day3Segments = createSmallPieSegments(statsCard3Day3.total, statsCard3Day3.completed)}
										{@const day3Percent = statsCard3Day3.total > 0 ? (statsCard3Day3.completed / statsCard3Day3.total) * 100 : 0}
										<div class="pie-chart-wrapper-small">
											<svg class="pie-svg-small" viewBox="0 0 100 100">
												<defs>
													<filter id="shadow-day3" x="-50%" y="-50%" width="200%" height="200%">
														<feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-opacity="0.3" flood-color="#000000" />
													</filter>
													<radialGradient id="grad-green-day3" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#00cc00;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#008000;stop-opacity:1" />
													</radialGradient>
													<radialGradient id="grad-red-day3" cx="35%" cy="35%">
														<stop offset="0%" style="stop-color:#ff3366;stop-opacity:1" />
														<stop offset="100%" style="stop-color:#fa003f;stop-opacity:1" />
													</radialGradient>
												</defs>
												<!-- Shadow layer -->
												{#each day3Segments as segment}
													<path d={segment.shadowPath} fill={segment.shadowColor} opacity="0.3" />
												{/each}
												<!-- Main segments with gradient -->
												{#each day3Segments as segment}
													<path 
														d={segment.path} 
														fill={segment.color === '#008000' ? 'url(#grad-green-day3)' : 'url(#grad-red-day3)'}
														filter="url(#shadow-day3)"
														stroke="white"
														stroke-width="0.8"
													/>
												{/each}
											</svg>
											<div class="pie-text-small">
												<div class="pie-percent-small">{day3Percent.toFixed(0)}%</div>
												<div class="pie-count-small">{statsCard3Day3.completed}/{statsCard3Day3.total}</div>
											</div>
										</div>
									{:else}
										<div class="no-data">{t('mobile.dashboardContent.branchPerformance.noDataTwoDaysAgo') || 'No data for 2 days ago'}</div>
									{/if}
								{/if}
							</div>
						</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.bp-container {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		height: 100%;
		padding: 24px;
	}

	.content {
		flex: 1;
		overflow-y: auto;
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 20px;
	}

	.card {
		background: white;
		border: 2px solid #ff9800;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		transition: all 0.2s ease;
	}

	.card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
		transform: translateY(-2px);
		border-color: #f57c00;
	}

	.card-header {
		padding: 16px;
		background: white;
		border-bottom: 2px solid #ff9800;
	}

	.card-title {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #ff9800;
	}

	.card-body {
		padding: 16px;
		min-height: auto;
		color: #9ca3af;
		font-size: 14px;
	}

	.card:first-child .card-body {
		display: flex;
		flex-direction: column;
		min-height: auto;
	}

	.date-range-form {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-size: 13px;
		font-weight: 500;
		color: #374151;
	}

	.date-input {
		padding: 8px 12px;
		border: 1px solid #ff9800;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
	}

	.date-input:focus {
		outline: none;
		border-color: #f57c00;
		box-shadow: 0 0 0 3px rgba(255, 152, 0, 0.1);
	}

	.apply-btn {
		padding: 10px 16px;
		background: #ff9800;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.apply-btn:hover {
		background: #f57c00;
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(255, 152, 0, 0.3);
	}

	.apply-btn:active {
		transform: translateY(0);
	}

	.apply-btn:disabled {
		background: #d3d3d3;
		cursor: not-allowed;
		transform: none;
	}

	.pie-chart-container {
		display: flex;
		justify-content: center;
		align-items: center;
		margin-top: 20px;
		padding-top: 20px;
		border-top: 1px solid #f3f4f6;
	}

	.pie-wrapper {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
	}

	.pie-title {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0;
	}

	.pie-svg {
		width: 180px;
		height: 180px;
	}

	.pie-svg-small {
		width: 140px;
		height: 140px;
	}

	.pie-percent {
		font-size: 22px;
		font-weight: bold;
		color: #0066cc;
	}

	.pie-percent-small {
		font-size: 16px;
		font-weight: bold;
		color: #0066cc;
	}

	.pie-label {
		font-size: 12px;
		color: #0066cc;
		font-weight: 500;
	}

	.pie-count {
		font-size: 11px;
		color: #0066cc;
	}

	.pie-count-small {
		font-size: 10px;
		color: #0066cc;
	}

	.branches-grid {
		margin-top: 24px;
		padding-top: 24px;
		border-top: 1px solid #f3f4f6;
	}

	.branches-title {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 16px 0;
	}

	.branches-container {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
		gap: 16px;
	}

	.branch-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 12px;
		background: #fafafa;
		border-radius: 8px;
		border: 1px solid #f0f0f0;
	}

	.branch-name {
		font-size: 12px;
		font-weight: 600;
		color: #008000;
		text-align: center;
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: 8px;
		margin-bottom: 12px;
	}

	.input-group label {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	.input-group select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background-color: white;
		color: #374151;
		cursor: pointer;
		background-image: url("data:image/svg+xml;charset=UTF-8,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3e%3cpolyline points='6 9 12 15 18 9'%3e%3c/polyline%3e%3c/svg%3e");
		background-repeat: no-repeat;
		background-position: right 8px center;
		padding-right: 32px;
		appearance: none;
		-webkit-appearance: none;
		-moz-appearance: none;
	}

	:global([dir="rtl"]) .input-group select {
		background-position: left 8px center;
		padding-right: 12px;
		padding-left: 32px;
	}

	.input-group select:focus {
		outline: none;
		border-color: #ff9800;
		box-shadow: 0 0 0 3px rgba(255, 152, 0, 0.1);
	}

	.days-container {
		display: flex;
		flex-direction: column;
		gap: 16px;
		margin-top: 20px;
	}

	.day-card {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 12px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
	}

	.day-title {
		font-size: 13px;
		font-weight: 600;
		color: #374151;
		margin: 0;
		text-align: center;
	}

	.no-data {
		font-size: 12px;
		color: #9ca3af;
		text-align: center;
		padding: 20px 0;
	}
</style>
