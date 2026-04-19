<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';

	let supabase: any = null;
	let activeTab: 'settings' | 'dashboard' = 'settings';
	let loading = true;

	// Settings state
	let settings: any = {
		id: '',
		active: false,
		start_date: '',
		start_time: '',
		end_date: '',
		end_time: '',
		daily_limit: 100,
		timezone: 'Asia/Riyadh'
	};
	let settingsSaving = false;
	let settingsMessage = '';

	// Rewards state
	let rewards: any[] = [];
	let showRewardModal = false;
	let editingReward: any = null;
	let rewardForm = {
		label: '',
		reward_type: 'percentage',
		value: 0,
		max_discount: null as number | null,
		min_bill: 0,
		weight: 1,
		usage_limit: null as number | null,
		expiry_date: '',
		active: true
	};
	let rewardSaving = false;

	// Import rewards state
	let showImportModal = false;
	let importText = '';
	let importProcessing = false;

	// Dashboard state
	let dashboardStats: any = null;
	let dashboardLoading = false;
	let dateFilter = 'today';
	let customFrom = '';
	let customTo = '';

	// Realtime
	let realtimeChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadSettings();
		await loadRewards();
		setupRealtime();
		loading = false;
	});

	onDestroy(() => {
		if (realtimeChannel && supabase) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function setupRealtime() {
		if (!supabase) return;
		realtimeChannel = supabase.channel('gift-wheel-manager-realtime')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_settings' }, () => {
				loadSettings();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_rewards' }, () => {
				loadRewards();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_spins' }, () => {
				if (activeTab === 'dashboard') loadDashboard();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_coupons' }, () => {
				if (activeTab === 'dashboard') loadDashboard();
			})
			.subscribe();
	}

	// ============ SETTINGS ============

	async function loadSettings() {
		try {
			const { data, error } = await supabase
				.from('gift_wheel_settings')
				.select('*')
				.limit(1)
				.single();

			if (error) throw error;
			if (data) {
				let startDate = '', startTime = '', endDate = '', endTime = '';
				if (data.start_datetime) {
					const d = new Date(data.start_datetime);
					startDate = d.toISOString().slice(0, 10);
					startTime = d.toISOString().slice(11, 16);
				}
				if (data.end_datetime) {
					const d = new Date(data.end_datetime);
					endDate = d.toISOString().slice(0, 10);
					endTime = d.toISOString().slice(11, 16);
				}
				settings = {
					...data,
					start_date: startDate,
					start_time: startTime,
					end_date: endDate,
					end_time: endTime
				};
			}
		} catch (err) {
			console.error('Failed to load settings:', err);
		}
	}

	async function saveSettings() {
		settingsSaving = true;
		settingsMessage = '';
		try {
			const updateData: any = {
				active: settings.active,
				daily_limit: settings.daily_limit,
				timezone: settings.timezone,
				updated_at: new Date().toISOString()
			};

			if (settings.start_date) {
				const time = settings.start_time || '00:00';
				updateData.start_datetime = new Date(`${settings.start_date}T${time}:00`).toISOString();
			} else {
				updateData.start_datetime = null;
			}

			if (settings.end_date) {
				const time = settings.end_time || '23:59';
				updateData.end_datetime = new Date(`${settings.end_date}T${time}:00`).toISOString();
			} else {
				updateData.end_datetime = null;
			}

			const { error } = await supabase
				.from('gift_wheel_settings')
				.update(updateData)
				.eq('id', settings.id);

			if (error) throw error;
			settingsMessage = 'Settings saved successfully!';
			setTimeout(() => settingsMessage = '', 3000);
		} catch (err: any) {
			settingsMessage = 'Error: ' + (err.message || 'Failed to save');
		} finally {
			settingsSaving = false;
		}
	}

	// ============ REWARDS ============

	async function loadRewards() {
		try {
			const { data, error } = await supabase
				.from('gift_wheel_rewards')
				.select('*')
				.order('weight', { ascending: false });

			if (error) throw error;
			rewards = data || [];
		} catch (err) {
			console.error('Failed to load rewards:', err);
		}
	}

	function openNewReward() {
		editingReward = null;
		rewardForm = {
			label: '',
			reward_type: 'percentage',
			value: 0,
			max_discount: null,
			min_bill: 0,
			weight: 1,
			usage_limit: null,
			expiry_date: '',
			active: true
		};
		showRewardModal = true;
	}

	function openEditReward(reward: any) {
		editingReward = reward;
		rewardForm = {
			label: reward.label,
			reward_type: reward.reward_type,
			value: reward.value,
			max_discount: reward.max_discount,
			min_bill: reward.min_bill,
			weight: reward.weight,
			usage_limit: reward.usage_limit,
			expiry_date: reward.expiry_date || '',
			active: reward.active
		};
		showRewardModal = true;
	}

	async function saveReward() {
		rewardSaving = true;
		try {
			const data: any = {
				label: rewardForm.label,
				reward_type: rewardForm.reward_type,
				value: rewardForm.value,
				max_discount: rewardForm.max_discount || null,
				min_bill: rewardForm.min_bill,
				weight: rewardForm.weight,
				usage_limit: rewardForm.usage_limit || null,
				expiry_date: rewardForm.expiry_date || null,
				active: rewardForm.active,
				updated_at: new Date().toISOString()
			};

			if (editingReward) {
				const { error } = await supabase
					.from('gift_wheel_rewards')
					.update(data)
					.eq('id', editingReward.id);
				if (error) throw error;
			} else {
				const { error } = await supabase
					.from('gift_wheel_rewards')
					.insert(data);
				if (error) throw error;
			}

			showRewardModal = false;
			await loadRewards();
		} catch (err) {
			console.error('Failed to save reward:', err);
		} finally {
			rewardSaving = false;
		}
	}

	async function deleteReward(reward: any) {
		if (!confirm(`Delete reward "${reward.label}"?`)) return;
		try {
			const { error } = await supabase
				.from('gift_wheel_rewards')
				.delete()
				.eq('id', reward.id);
			if (error) throw error;
			await loadRewards();
		} catch (err) {
			console.error('Failed to delete reward:', err);
		}
	}

	async function toggleRewardActive(reward: any) {
		try {
			const { error } = await supabase
				.from('gift_wheel_rewards')
				.update({ active: !reward.active, updated_at: new Date().toISOString() })
				.eq('id', reward.id);
			if (error) throw error;
			await loadRewards();
		} catch (err) {
			console.error('Failed to toggle reward:', err);
		}
	}

	// ============ IMPORT ============

	async function importRewards() {
		importProcessing = true;
		try {
			const lines = importText.trim().split('\n').filter(l => l.trim());
			const imported: any[] = [];

			for (const line of lines) {
				// Expect CSV: label, type, value, max_discount, min_bill, weight
				const parts = line.split(',').map(p => p.trim());
				if (parts.length < 3) continue;

				imported.push({
					label: parts[0],
					reward_type: parts[1] || 'percentage',
					value: parseFloat(parts[2]) || 0,
					max_discount: parts[3] ? parseFloat(parts[3]) : null,
					min_bill: parts[4] ? parseFloat(parts[4]) : 0,
					weight: parts[5] ? parseInt(parts[5]) : 1,
					active: true
				});
			}

			if (imported.length > 0) {
				const { error } = await supabase
					.from('gift_wheel_rewards')
					.insert(imported);
				if (error) throw error;
				await loadRewards();
			}

			showImportModal = false;
			importText = '';
		} catch (err) {
			console.error('Import failed:', err);
		} finally {
			importProcessing = false;
		}
	}

	// ============ DASHBOARD ============

	async function loadDashboard() {
		dashboardLoading = true;
		try {
			let fromDate: string | null = null;
			let toDate: string | null = null;

			const today = new Date().toISOString().split('T')[0];

			if (dateFilter === 'today') {
				fromDate = today;
				toDate = today;
			} else if (dateFilter === 'week') {
				const d = new Date();
				d.setDate(d.getDate() - 7);
				fromDate = d.toISOString().split('T')[0];
				toDate = today;
			} else if (dateFilter === 'month') {
				const d = new Date();
				d.setDate(d.getDate() - 30);
				fromDate = d.toISOString().split('T')[0];
				toDate = today;
			} else if (dateFilter === 'custom') {
				fromDate = customFrom || today;
				toDate = customTo || today;
			}

			const { data, error } = await supabase.rpc('gift_wheel_dashboard_stats', {
				p_from: fromDate,
				p_to: toDate
			});

			if (error) throw error;
			dashboardStats = data;
		} catch (err) {
			console.error('Failed to load dashboard:', err);
		} finally {
			dashboardLoading = false;
		}
	}

	async function exportCSV() {
		if (!dashboardStats) return;

		let csv = 'Metric,Value\n';
		csv += `Total Spins,${dashboardStats.total_spins || 0}\n`;
		csv += `Spins Today,${dashboardStats.total_spins_today || 0}\n`;
		csv += `Unique Bills,${dashboardStats.unique_bills || 0}\n`;
		csv += `Winning Spins,${dashboardStats.winning_spins || 0}\n`;
		csv += `Losing Spins,${dashboardStats.losing_spins || 0}\n`;
		csv += `Coupons Printed,${dashboardStats.coupons_printed || 0}\n`;
		csv += `Coupons Redeemed,${dashboardStats.coupons_redeemed || 0}\n`;
		csv += `Rejected Bills,${dashboardStats.rejected_bills || 0}\n`;

		if (dashboardStats.reward_distribution) {
			csv += '\nReward Distribution\nReward,Count\n';
			for (const r of dashboardStats.reward_distribution) {
				csv += `${r.label},${r.count}\n`;
			}
		}

		if (dashboardStats.spins_by_date) {
			csv += '\nSpins by Date\nDate,Spins\n';
			for (const d of dashboardStats.spins_by_date) {
				csv += `${d.date},${d.spins}\n`;
			}
		}

		const blob = new Blob([csv], { type: 'text/csv' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `gift-wheel-report-${new Date().toISOString().split('T')[0]}.csv`;
		a.click();
		URL.revokeObjectURL(url);
	}

	// Auto-load dashboard when switching to it
	$: if (activeTab === 'dashboard' && !dashboardStats && supabase) {
		loadDashboard();
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	{#if loading}
		<div class="flex-1 flex flex-col items-center justify-center gap-3">
			<div class="w-8 h-8 border-3 border-slate-200 border-t-amber-500 rounded-full animate-spin"></div>
			<p class="text-sm text-slate-400">Loading Gift Wheel Manager...</p>
		</div>
	{:else}
		<!-- Tab Navigation -->
		<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center gap-2 shadow-sm flex-shrink-0">
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'settings' ? 'bg-amber-500 text-white shadow-lg shadow-amber-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'settings'}
			>
				⚙️ Settings
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'dashboard' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'dashboard'}
			>
				📊 Dashboard
			</button>
		</div>

		<!-- Content Area -->
		<div class="flex-1 p-6 overflow-y-auto relative">
			<!-- Decorative blobs -->
			<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-amber-100/20 rounded-full blur-[100px] -mr-48 -mt-48 pointer-events-none"></div>
			<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-emerald-100/20 rounded-full blur-[100px] -ml-48 -mb-48 pointer-events-none"></div>

			<div class="relative z-10">
				<!-- Settings Tab -->
				{#if activeTab === 'settings'}
					<!-- Activation Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔌 Activation</h3>
						<div class="flex items-center justify-between">
							<span class="text-sm font-semibold text-slate-600">Gift Wheel Active</span>
							<label class="switch">
								<input type="checkbox" bind:checked={settings.active} />
								<span class="slider-toggle"></span>
							</label>
						</div>
						{#if !settings.active}
							<p class="mt-2 text-xs font-bold text-red-500">Gift Wheel is currently disabled</p>
						{/if}
					</div>

					<!-- Schedule Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📅 Scheduled Activation</h3>
						<div class="grid grid-cols-2 gap-3">
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Start Date</span>
								<input type="date" bind:value={settings.start_date} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Start Time</span>
								<input type="time" bind:value={settings.start_time} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">End Date</span>
								<input type="date" bind:value={settings.end_date} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">End Time</span>
								<input type="time" bind:value={settings.end_time} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
						</div>
						<p class="mt-2 text-xs text-slate-400">Timezone: Saudi Arabia (Asia/Riyadh)</p>
					</div>

					<!-- Daily Limit Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔢 Daily Spin Limit</h3>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Maximum spins per day</span>
							<input type="number" bind:value={settings.daily_limit} min="1" max="10000" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<p class="mt-2 text-xs text-slate-400">Auto resets at 12:00 AM Saudi time</p>
					</div>

					<!-- Save Button -->
					<div class="flex items-center justify-end gap-3 mb-4">
						{#if settingsMessage}
							<span class="text-sm font-bold {settingsMessage.startsWith('Error') ? 'text-red-500' : 'text-emerald-600'}">{settingsMessage}</span>
						{/if}
						<button
							class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-amber-500 hover:bg-amber-600 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
							on:click={saveSettings}
							disabled={settingsSaving}
						>
							{settingsSaving ? 'Saving...' : '💾 Save Settings'}
						</button>
					</div>

					<!-- Rewards Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<div class="flex items-center justify-between mb-4">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">🎁 Rewards</h3>
							<div class="flex gap-2">
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all" on:click={() => showImportModal = true}>
									📥 Import
								</button>
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105" on:click={openNewReward}>
									➕ Add Reward
								</button>
							</div>
						</div>

						<div class="overflow-x-auto rounded-xl border border-slate-200">
							<table class="w-full border-collapse">
								<thead>
									<tr class="bg-amber-500 text-white">
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Label</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Type</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Value</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Max Disc.</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Min Bill</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Weight</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Usage</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Active</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each rewards as reward}
										<tr class="hover:bg-amber-50/40 transition-colors duration-200 border-b border-slate-100 {!reward.active ? 'opacity-40' : ''}">
											<td class="px-3 py-2.5 text-sm text-slate-700 font-semibold">{reward.label}</td>
											<td class="px-3 py-2.5 text-sm">
												{#if reward.reward_type === 'percentage'}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-blue-100 text-blue-600">percentage</span>
												{:else if reward.reward_type === 'fixed'}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-emerald-100 text-emerald-600">fixed</span>
												{:else}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-500">no_reward</span>
												{/if}
											</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.reward_type === 'no_reward' ? '-' : reward.value}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.max_discount || '-'}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.min_bill}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.weight}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.usage_count}{reward.usage_limit ? '/' + reward.usage_limit : ''}</td>
											<td class="px-3 py-2.5 text-sm">
												<button class="text-base transition-transform hover:scale-125" on:click={() => toggleRewardActive(reward)}>
													{reward.active ? '✅' : '❌'}
												</button>
											</td>
											<td class="px-3 py-2.5 text-sm flex gap-1">
												<button class="w-7 h-7 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => openEditReward(reward)} title="Edit">✏️</button>
												<button class="w-7 h-7 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => deleteReward(reward)} title="Delete">🗑️</button>
											</td>
										</tr>
									{/each}
									{#if rewards.length === 0}
										<tr><td colspan="9" class="text-center text-slate-400 py-8 text-sm">No rewards configured</td></tr>
									{/if}
								</tbody>
							</table>
						</div>

						<!-- Rules -->
						<div class="mt-4 p-3 bg-blue-50/60 border border-blue-200/60 rounded-xl">
							<h4 class="text-xs font-black text-blue-700 uppercase tracking-wide mb-2">📋 Rules</h4>
							<ul class="list-disc pl-5 text-xs text-slate-500 space-y-1">
								<li>One spin per bill only</li>
								<li>Duplicate bill numbers are prevented</li>
								<li>15%+ rewards only if bill amount {'>'} 500 SAR</li>
							</ul>
						</div>
					</div>

				<!-- Dashboard Tab -->
				{:else if activeTab === 'dashboard'}
					<!-- Filters -->
					<div class="flex items-center gap-3 mb-4 flex-wrap">
						<div class="flex gap-1">
							{#each [{ key: 'today', label: 'Today' }, { key: 'week', label: 'Week' }, { key: 'month', label: 'Month' }, { key: 'custom', label: 'Custom' }] as f}
								<button
									class="px-3 py-1.5 rounded-lg text-xs font-bold border transition-all duration-200 {dateFilter === f.key ? 'bg-amber-50 border-amber-400 text-amber-600' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}"
									on:click={() => { dateFilter = f.key; if (f.key !== 'custom') loadDashboard(); }}
								>
									{f.label}
								</button>
							{/each}
						</div>
						{#if dateFilter === 'custom'}
							<div class="flex items-center gap-2">
								<input type="date" bind:value={customFrom} class="px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 transition-all" />
								<span class="text-xs text-slate-400">to</span>
								<input type="date" bind:value={customTo} class="px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 transition-all" />
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 transition-all" on:click={loadDashboard}>Apply</button>
							</div>
						{/if}
						<button
							class="ml-auto px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all disabled:opacity-40"
							on:click={exportCSV}
							disabled={!dashboardStats}
						>
							📤 Export CSV
						</button>
					</div>

					{#if dashboardLoading}
						<div class="flex items-center justify-center py-16">
							<div class="w-8 h-8 border-3 border-slate-200 border-t-amber-500 rounded-full animate-spin"></div>
						</div>
					{:else if dashboardStats}
						<!-- Stats Grid -->
						<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.total_spins_today || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Spins Today</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.total_spins || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Total Spins</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.unique_bills || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Unique Bills</div>
							</div>
							<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-emerald-600">{dashboardStats.winning_spins || 0}</div>
								<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">Winning Spins</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.losing_spins || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Losing Spins</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.coupons_printed || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Coupons Printed</div>
							</div>
							<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-emerald-600">{dashboardStats.coupons_redeemed || 0}</div>
								<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">Coupons Redeemed</div>
							</div>
							<div class="bg-red-50/60 backdrop-blur-xl rounded-2xl border border-red-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-red-500">{dashboardStats.rejected_bills || 0}</div>
								<div class="text-[10px] font-bold text-red-400 uppercase tracking-wide mt-1">Rejected Bills</div>
							</div>
						</div>

						<!-- Reward Distribution -->
						{#if dashboardStats.reward_distribution && dashboardStats.reward_distribution.length > 0}
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
								<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🎯 Reward Distribution</h3>
								<div class="flex flex-col gap-2.5">
									{#each dashboardStats.reward_distribution as item}
										<div class="grid grid-cols-[140px_50px_1fr] items-center gap-3">
											<span class="text-sm text-slate-600 font-medium">{item.label}</span>
											<span class="text-sm font-black text-slate-800 text-right">{item.count}</span>
											<div class="h-2 bg-slate-100 rounded-full overflow-hidden">
												<div
													class="h-full bg-gradient-to-r from-amber-400 to-amber-500 rounded-full transition-all duration-500"
													style="width: {Math.min(100, (item.count / (dashboardStats.total_spins || 1)) * 100)}%; min-width: 4px"
												></div>
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Spins by Date -->
						{#if dashboardStats.spins_by_date && dashboardStats.spins_by_date.length > 0}
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
								<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📈 Spins by Date</h3>
								<div class="flex flex-col gap-1">
									{#each dashboardStats.spins_by_date as item}
										<div class="flex justify-between py-1.5 px-2 rounded-lg hover:bg-slate-50 transition-colors">
											<span class="text-sm text-slate-500">{item.date}</span>
											<span class="text-sm font-black text-slate-800">{item.spins}</span>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					{:else}
						<div class="text-center py-16 text-slate-400 text-sm">
							No data available. Click a filter to load.
						</div>
					{/if}
				{/if}
			</div>
		</div>
	{/if}

	<!-- Reward Modal -->
	{#if showRewardModal}
		<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click|self={() => showRewardModal = false}>
			<div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 scale-in overflow-hidden max-h-[85vh] overflow-y-auto">
				<div class="bg-gradient-to-r from-amber-500 to-orange-500 px-6 py-4 flex items-center justify-between">
					<h3 class="text-white font-black text-base">{editingReward ? '✏️ Edit Reward' : '➕ New Reward'}</h3>
					<button class="text-white/80 hover:text-white text-xl font-bold transition-colors" on:click={() => showRewardModal = false}>✕</button>
				</div>
				<div class="px-6 py-5 space-y-3">
					<div>
						<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Label</span>
						<input type="text" bind:value={rewardForm.label} placeholder="e.g. 10% Off" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Type</span>
							<select bind:value={rewardForm.reward_type} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all">
								<option value="percentage">Percentage (%)</option>
								<option value="fixed">Fixed Amount</option>
								<option value="no_reward">No Reward</option>
							</select>
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Value</span>
							<input type="number" bind:value={rewardForm.value} min="0" step="0.01" disabled={rewardForm.reward_type === 'no_reward'} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all disabled:opacity-40" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Max Discount (SAR)</span>
							<input type="number" bind:value={rewardForm.max_discount} min="0" step="0.01" placeholder="No limit" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Min Bill Amount (SAR)</span>
							<input type="number" bind:value={rewardForm.min_bill} min="0" step="0.01" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Weight (probability)</span>
							<input type="number" bind:value={rewardForm.weight} min="1" max="100" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Usage Limit</span>
							<input type="number" bind:value={rewardForm.usage_limit} min="0" placeholder="Unlimited" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Expiry Date</span>
							<input type="date" bind:value={rewardForm.expiry_date} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div class="flex flex-col">
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Active</span>
							<label class="switch mt-1">
								<input type="checkbox" bind:checked={rewardForm.active} />
								<span class="slider-toggle"></span>
							</label>
						</div>
					</div>
				</div>
				<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
					<button class="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 bg-slate-200 hover:bg-slate-300 transition-all" on:click={() => showRewardModal = false}>Cancel</button>
					<button
						class="px-5 py-2 rounded-xl text-sm font-bold text-white bg-emerald-600 hover:bg-emerald-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						on:click={saveReward}
						disabled={rewardSaving || !rewardForm.label}
					>
						{rewardSaving ? 'Saving...' : 'Save Reward'}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Import Modal -->
	{#if showImportModal}
		<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click|self={() => showImportModal = false}>
			<div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 scale-in overflow-hidden">
				<div class="bg-gradient-to-r from-blue-500 to-cyan-500 px-6 py-4 flex items-center justify-between">
					<h3 class="text-white font-black text-base">📥 Import Rewards</h3>
					<button class="text-white/80 hover:text-white text-xl font-bold transition-colors" on:click={() => showImportModal = false}>✕</button>
				</div>
				<div class="px-6 py-5">
					<p class="text-xs text-slate-500 mb-1">CSV format: label, type, value, max_discount, min_bill, weight</p>
					<p class="text-[11px] text-slate-400 mb-3 font-mono">Example: 10% Off, percentage, 10, 25, 0, 10</p>
					<textarea
						bind:value={importText}
						rows="8"
						placeholder="Paste CSV data here..."
						class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm font-mono resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
					></textarea>
				</div>
				<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
					<button class="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 bg-slate-200 hover:bg-slate-300 transition-all" on:click={() => showImportModal = false}>Cancel</button>
					<button
						class="px-5 py-2 rounded-xl text-sm font-bold text-white bg-blue-600 hover:bg-blue-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						on:click={importRewards}
						disabled={importProcessing || !importText.trim()}
					>
						{importProcessing ? 'Importing...' : 'Import'}
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	/* Toggle Switch */
	.switch {
		position: relative;
		display: inline-block;
		width: 44px;
		height: 24px;
	}

	.switch input { display: none; }

	.slider-toggle {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: #cbd5e1;
		border-radius: 24px;
		transition: 0.3s;
	}

	.slider-toggle::before {
		content: "";
		position: absolute;
		height: 18px;
		width: 18px;
		left: 3px;
		bottom: 3px;
		background: white;
		border-radius: 50%;
		transition: 0.3s;
		box-shadow: 0 1px 3px rgba(0,0,0,0.15);
	}

	.switch input:checked + .slider-toggle {
		background: #10b981;
	}

	.switch input:checked + .slider-toggle::before {
		transform: translateX(20px);
	}

	/* Scale-in animation */
	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}

	.scale-in {
		animation: scaleIn 0.3s ease-out;
	}
</style>
