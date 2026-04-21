<script lang="ts">
	import { _ as t, t as translate } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';

	let supabase: any = null;
	let activeTab: 'settings' | 'dashboard' | 'logs' | 'redemptions' = 'settings';
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
		minimum_bill_amount: 0,
		timezone: 'Asia/Riyadh'
	};
	let settingsSaving = false;
	let settingsMessage = '';
	let settingsMessageIsError = false;

	// Rewards state
	let rewards: any[] = [];
	let showRewardModal = false;
	let editingReward: any = null;
	let rewardForm = {
		label: '',
		reward_label_en: '',
		reward_label_ar: '',
		reward_type: 'percentage',
		value: 0,
		max_discount: null as number | null,
		min_bill: 0,
		weight: 1,
		usage_limit: null as number | null,
		validity_days: 7,
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

	// Logs state
	let spinLogs: any[] = [];
	let logsLoading = false;
	let logsFilter = 'all';
	let logsPage = 0;
	let logsHasMore = true;

	// Redemption logs state
	let redemptionLogs: any[] = [];
	let redemptionLoading = false;
	let redemptionFilter = 'all';
	let redemptionPage = 0;
	let redemptionHasMore = true;
	const LOGS_PER_PAGE = 50;

	// Realtime
	let realtimeChannel: any = null;

	function getRedemptionStatusLabel(status: string) {
		if (status === 'redeemed') return translate('giftWheel.manager.redemptions.status.redeemed');
		if (status === 'used' || status === 'printed' || status === 'active') return translate('giftWheel.manager.redemptions.status.used');
		return status || '-';
	}

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
				if (activeTab === 'logs') loadLogs(true);
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_coupons' }, () => {
				if (activeTab === 'dashboard') loadDashboard();
				if (activeTab === 'redemptions') loadRedemptionLogs(true);
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
					end_time: endTime,
					minimum_bill_amount: data.minimum_bill_amount ?? 0
				};
			}
		} catch (err) {
			console.error('Failed to load settings:', err);
		}
	}

	async function saveSettings() {
		settingsSaving = true;
		settingsMessage = '';
		settingsMessageIsError = false;
		try {
			const updateData: any = {
				active: settings.active,
				daily_limit: settings.daily_limit,
				minimum_bill_amount: settings.minimum_bill_amount || 0,
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
			settingsMessage = translate('giftWheel.manager.messages.settingsSaved');
			settingsMessageIsError = false;
			setTimeout(() => settingsMessage = '', 3000);
		} catch (err: any) {
			settingsMessage = translate('giftWheel.manager.messages.errorPrefix') + (err.message || translate('giftWheel.manager.messages.failedToSave'));
			settingsMessageIsError = true;
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
			reward_label_en: '',
			reward_label_ar: '',
			reward_type: 'percentage',
			value: 0,
			max_discount: null,
			min_bill: 0,
			weight: 1,
			usage_limit: null,
			validity_days: 7,
			active: true
		};
		showRewardModal = true;
	}

	function openEditReward(reward: any) {
		editingReward = reward;
		rewardForm = {
			label: reward.label,
			reward_label_en: reward.reward_label_en || '',
			reward_label_ar: reward.reward_label_ar || '',
			reward_type: reward.reward_type,
			value: reward.value,
			max_discount: reward.max_discount,
			min_bill: reward.min_bill,
			weight: reward.weight,
			usage_limit: reward.usage_limit,
			validity_days: reward.validity_days ?? 7,
			active: reward.active
		};
		showRewardModal = true;
	}

	async function saveReward() {
		rewardSaving = true;
		try {
			const data: any = {
				label: rewardForm.reward_label_en || rewardForm.label,
				reward_label_en: rewardForm.reward_label_en || rewardForm.label || null,
				reward_label_ar: rewardForm.reward_label_ar || null,
				reward_type: rewardForm.reward_type,
				value: rewardForm.value,
				max_discount: rewardForm.max_discount || null,
				min_bill: rewardForm.min_bill,
				weight: rewardForm.weight,
				usage_limit: rewardForm.usage_limit || null,
				validity_days: rewardForm.validity_days || 7,
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

	// ============ LOGS ============

	async function loadLogs(reset = false) {
		logsLoading = true;
		if (reset) { logsPage = 0; spinLogs = []; logsHasMore = true; }
		try {
			let query = supabase
				.from('gift_wheel_spins')
				.select('*')
				.order('created_at', { ascending: false })
				.range(logsPage * LOGS_PER_PAGE, (logsPage + 1) * LOGS_PER_PAGE - 1);

			if (logsFilter === 'manual') query = query.eq('manual_entry', true);
			else if (logsFilter === 'winners') query = query.eq('is_winner', true);
			else if (logsFilter === 'losers') query = query.eq('is_winner', false).eq('rejected', false);
			else if (logsFilter === 'rejected') query = query.eq('rejected', true);

			const { data, error } = await query;
			if (error) throw error;

			if (reset) {
				spinLogs = data || [];
			} else {
				spinLogs = [...spinLogs, ...(data || [])];
			}
			logsHasMore = (data || []).length === LOGS_PER_PAGE;
		} catch (err) {
			console.error('Failed to load logs:', err);
		} finally {
			logsLoading = false;
		}
	}

	function loadMoreLogs() {
		logsPage++;
		loadLogs();
	}

	// ============ REDEMPTION LOGS ============

	async function loadRedemptionLogs(reset = false) {
		redemptionLoading = true;
		if (reset) { redemptionPage = 0; redemptionLogs = []; redemptionHasMore = true; }
		try {
			let query = supabase
				.from('gift_wheel_coupons')
				.select('code, status, reward_label, reward_type, reward_value, max_discount, bill_number, bill_amount, bill_date, branch_id, printed_at, redeemed_at, redeemed_bill_number, redeemed_amount, created_at')
				.order('redeemed_at', { ascending: false, nullsFirst: false })
				.order('created_at', { ascending: false })
				.range(redemptionPage * LOGS_PER_PAGE, (redemptionPage + 1) * LOGS_PER_PAGE - 1);

			if (redemptionFilter === 'redeemed') query = query.eq('status', 'redeemed');
			else if (redemptionFilter === 'used') query = query.in('status', ['used', 'printed', 'active']);

			const { data, error } = await query;
			if (error) throw error;

			if (reset) {
				redemptionLogs = data || [];
			} else {
				redemptionLogs = [...redemptionLogs, ...(data || [])];
			}
			redemptionHasMore = (data || []).length === LOGS_PER_PAGE;
		} catch (err) {
			console.error('Failed to load redemption logs:', err);
		} finally {
			redemptionLoading = false;
		}
	}

	function loadMoreRedemptionLogs() {
		redemptionPage++;
		loadRedemptionLogs();
	}

	function formatLogDate(dateStr: string) {
		const d = new Date(dateStr);
		return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) + ' ' + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
	}

	// Auto-load dashboard when switching to it
	$: if (activeTab === 'dashboard' && !dashboardStats && supabase) {
		loadDashboard();
	}

	// Auto-load logs when switching to it
	$: if (activeTab === 'logs' && spinLogs.length === 0 && supabase) {
		loadLogs(true);
	}

	// Auto-load redemption logs when switching to it
	$: if (activeTab === 'redemptions' && redemptionLogs.length === 0 && supabase) {
		loadRedemptionLogs(true);
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	{#if loading}
		<div class="flex-1 flex flex-col items-center justify-center gap-3">
			<div class="w-8 h-8 border-3 border-slate-200 border-t-amber-500 rounded-full animate-spin"></div>
			<p class="text-sm text-slate-400">{$t('giftWheel.manager.loading')}</p>
		</div>
	{:else}
		<!-- Tab Navigation -->
		<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center gap-2 shadow-sm flex-shrink-0">
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'settings' ? 'bg-amber-500 text-white shadow-lg shadow-amber-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'settings'}
			>
				⚙️ {$t('giftWheel.manager.tabs.settings')}
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'dashboard' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'dashboard'}
			>
				📊 {$t('giftWheel.manager.tabs.dashboard')}
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'logs' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'logs'}
			>
				📋 {$t('giftWheel.manager.tabs.spinLogs')}
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'redemptions' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'redemptions'}
			>
				🎟️ {$t('giftWheel.manager.tabs.redemptionLogs')}
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
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔌 {$t('giftWheel.manager.settings.activation.title')}</h3>
						<div class="flex items-center justify-between">
							<span class="text-sm font-semibold text-slate-600">{$t('giftWheel.manager.settings.activation.activeLabel')}</span>
							<label class="switch">
								<input type="checkbox" bind:checked={settings.active} />
								<span class="slider-toggle"></span>
							</label>
						</div>
						{#if !settings.active}
							<p class="mt-2 text-xs font-bold text-red-500">{$t('giftWheel.manager.settings.activation.disabled')}</p>
						{/if}
					</div>

					<!-- Schedule Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📅 {$t('giftWheel.manager.settings.schedule.title')}</h3>
						<div class="grid grid-cols-2 gap-3">
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.schedule.startDate')}</span>
								<input type="date" bind:value={settings.start_date} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.schedule.startTime')}</span>
								<input type="time" bind:value={settings.start_time} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.schedule.endDate')}</span>
								<input type="date" bind:value={settings.end_date} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.schedule.endTime')}</span>
								<input type="time" bind:value={settings.end_time} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
						</div>
						<p class="mt-2 text-xs text-slate-400">{$t('giftWheel.manager.settings.schedule.timezone')}</p>
					</div>

					<!-- Daily Limit Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔢 {$t('giftWheel.manager.settings.dailyLimit.title')}</h3>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.dailyLimit.label')}</span>
							<input type="number" bind:value={settings.daily_limit} min="1" max="10000" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<p class="mt-2 text-xs text-slate-400">{$t('giftWheel.manager.settings.dailyLimit.hint')}</p>
					</div>

						<!-- Minimum Bill Amount Card -->
						<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">💵 {$t('giftWheel.manager.settings.minimumBill.title')}</h3>
							<div>
								<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.settings.minimumBill.label')}</span>
								<input type="number" bind:value={settings.minimum_bill_amount} min="0" step="0.01" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							</div>
							<p class="mt-2 text-xs text-slate-400">{$t('giftWheel.manager.settings.minimumBill.hint')}</p>
						</div>

					<!-- Save Button -->
					<div class="flex items-center justify-end gap-3 mb-4">
						{#if settingsMessage}
							<span class="text-sm font-bold {settingsMessageIsError ? 'text-red-500' : 'text-emerald-600'}">{settingsMessage}</span>
						{/if}
						<button
							class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-amber-500 hover:bg-amber-600 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
							on:click={saveSettings}
							disabled={settingsSaving}
						>
							{settingsSaving ? $t('giftWheel.manager.actions.loading') : `💾 ${$t('giftWheel.manager.settings.save')}`}
						</button>
					</div>

					<!-- Rewards Card -->
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
						<div class="flex items-center justify-between mb-4">
							<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">🎁 {$t('giftWheel.manager.rewards.title')}</h3>
							<div class="flex gap-2">
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all" on:click={() => showImportModal = true}>
									📥 {$t('giftWheel.manager.rewards.import')}
								</button>
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105" on:click={openNewReward}>
									➕ {$t('giftWheel.manager.rewards.addReward')}
								</button>
							</div>
						</div>

						<div class="overflow-x-auto rounded-xl border border-slate-200">
							<table class="w-full border-collapse">
								<thead>
									<tr class="bg-amber-500 text-white">
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.labelEn')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.labelAr')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.type')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.value')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.maxDiscount')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.minBill')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.weight')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.validDays')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.usage')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.active')}</th>
										<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.rewards.columns.actions')}</th>
									</tr>
								</thead>
								<tbody>
									{#each rewards as reward}
										<tr class="hover:bg-amber-50/40 transition-colors duration-200 border-b border-slate-100 {!reward.active ? 'opacity-40' : ''}">
											<td class="px-3 py-2.5 text-sm text-slate-700 font-semibold">{reward.reward_label_en || reward.label}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700 font-semibold" dir="rtl">{reward.reward_label_ar || '-'}</td>
											<td class="px-3 py-2.5 text-sm">
												{#if reward.reward_type === 'percentage'}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-blue-100 text-blue-600">{$t('giftWheel.manager.rewards.type.percentage')}</span>
												{:else if reward.reward_type === 'fixed'}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-emerald-100 text-emerald-600">{$t('giftWheel.manager.rewards.type.fixed')}</span>
												{:else}
													<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-500">{$t('giftWheel.manager.rewards.type.noReward')}</span>
												{/if}
											</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.reward_type === 'no_reward' ? '-' : reward.value}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.max_discount || '-'}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.min_bill}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.weight}</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.validity_days ?? 7}d</td>
											<td class="px-3 py-2.5 text-sm text-slate-700">{reward.usage_count}{reward.usage_limit ? '/' + reward.usage_limit : ''}</td>
											<td class="px-3 py-2.5 text-sm">
												<button class="text-base transition-transform hover:scale-125" on:click={() => toggleRewardActive(reward)}>
													{reward.active ? '✅' : '❌'}
												</button>
											</td>
											<td class="px-3 py-2.5 text-sm flex gap-1">
												<button class="w-7 h-7 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => openEditReward(reward)} title={$t('giftWheel.manager.rewards.edit')}>✏️</button>
												<button class="w-7 h-7 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => deleteReward(reward)} title={$t('giftWheel.manager.rewards.delete')}>🗑️</button>
											</td>
										</tr>
									{/each}
									{#if rewards.length === 0}
											<tr><td colspan="11" class="text-center text-slate-400 py-8 text-sm">{$t('giftWheel.manager.rewards.empty')}</td></tr>
									{/if}
								</tbody>
							</table>
						</div>

						<!-- Rules -->
						<div class="mt-4 p-3 bg-blue-50/60 border border-blue-200/60 rounded-xl">
							<h4 class="text-xs font-black text-blue-700 uppercase tracking-wide mb-2">📋 {$t('giftWheel.manager.rules.title')}</h4>
							<ul class="list-disc pl-5 text-xs text-slate-500 space-y-1">
								<li>{$t('giftWheel.manager.rules.oneSpinPerBill')}</li>
								<li>{$t('giftWheel.manager.rules.duplicatePrevented')}</li>
								<li>{$t('giftWheel.manager.rules.minimumBill')} {settings.minimum_bill_amount || 0}</li>
								<li>{$t('giftWheel.manager.rules.highRewardThreshold')}</li>
							</ul>
						</div>
					</div>

				<!-- Dashboard Tab -->
				{:else if activeTab === 'dashboard'}
					<!-- Filters -->
					<div class="flex items-center gap-3 mb-4 flex-wrap">
						<div class="flex gap-1">
							{#each [
								{ key: 'today', label: $t('giftWheel.manager.dashboard.filters.today') },
								{ key: 'week', label: $t('giftWheel.manager.dashboard.filters.week') },
								{ key: 'month', label: $t('giftWheel.manager.dashboard.filters.month') },
								{ key: 'custom', label: $t('giftWheel.manager.dashboard.filters.custom') }
							] as f}
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
								<span class="text-xs text-slate-400">{$t('giftWheel.manager.dashboard.filters.to')}</span>
								<input type="date" bind:value={customTo} class="px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-amber-500 transition-all" />
								<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 transition-all" on:click={loadDashboard}>{$t('giftWheel.manager.dashboard.filters.apply')}</button>
							</div>
						{/if}
						<button
							class="ml-auto px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all disabled:opacity-40"
							on:click={exportCSV}
							disabled={!dashboardStats}
						>
							📤 {$t('giftWheel.manager.dashboard.exportCsv')}
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
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.spinsToday')}</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.total_spins || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.totalSpins')}</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.unique_bills || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.uniqueBills')}</div>
							</div>
							<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-emerald-600">{dashboardStats.winning_spins || 0}</div>
								<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.winningSpins')}</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.losing_spins || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.losingSpins')}</div>
							</div>
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-slate-800">{dashboardStats.coupons_printed || 0}</div>
								<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.couponsPrinted')}</div>
							</div>
							<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-emerald-600">{dashboardStats.coupons_redeemed || 0}</div>
								<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.couponsRedeemed')}</div>
							</div>
							<div class="bg-red-50/60 backdrop-blur-xl rounded-2xl border border-red-200 shadow-sm p-4 text-center">
								<div class="text-2xl font-black text-red-500">{dashboardStats.rejected_bills || 0}</div>
								<div class="text-[10px] font-bold text-red-400 uppercase tracking-wide mt-1">{$t('giftWheel.manager.dashboard.stats.rejectedBills')}</div>
							</div>
						</div>

						<!-- Reward Distribution -->
						{#if dashboardStats.reward_distribution && dashboardStats.reward_distribution.length > 0}
							<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
								<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🎯 {$t('giftWheel.manager.dashboard.rewardDistribution')}</h3>
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
								<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📈 {$t('giftWheel.manager.dashboard.spinsByDate')}</h3>
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
							{$t('giftWheel.manager.dashboard.empty')}
						</div>
					{/if}
				<!-- Logs Tab -->
				{:else if activeTab === 'logs'}
					<!-- Filters -->
					<div class="flex items-center gap-2 mb-4 flex-wrap">
						{#each [
							{ key: 'all', label: $t('giftWheel.manager.logs.filters.all') },
							{ key: 'manual', label: $t('giftWheel.manager.logs.filters.manual') },
							{ key: 'winners', label: $t('giftWheel.manager.logs.filters.winners') },
							{ key: 'losers', label: $t('giftWheel.manager.logs.filters.losers') },
							{ key: 'rejected', label: $t('giftWheel.manager.logs.filters.rejected') }
						] as f}
							<button
								class="px-3 py-1.5 rounded-lg text-xs font-bold border transition-all duration-200 {logsFilter === f.key ? 'bg-blue-50 border-blue-400 text-blue-600' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}"
								on:click={() => { logsFilter = f.key; loadLogs(true); }}
							>
								{f.label}
							</button>
						{/each}
						<button
							class="ml-auto px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
							on:click={() => loadLogs(true)}
						>
							🔄 {$t('giftWheel.manager.actions.refresh')}
						</button>
					</div>

					{#if logsLoading && spinLogs.length === 0}
						<div class="flex items-center justify-center py-16">
							<div class="w-8 h-8 border-3 border-slate-200 border-t-blue-500 rounded-full animate-spin"></div>
						</div>
					{:else}
						<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden">
							<div class="overflow-x-auto">
								<table class="w-full border-collapse">
									<thead>
										<tr class="bg-blue-600 text-white">
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.date')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.bill')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.amount')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.billDate')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.result')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.reward')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.coupon')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.entry')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.logs.columns.enteredBy')}</th>
										</tr>
									</thead>
									<tbody>
										{#each spinLogs as log}
											<tr class="hover:bg-blue-50/40 transition-colors duration-200 border-b border-slate-100">
												<td class="px-3 py-2 text-xs text-slate-500 whitespace-nowrap">{formatLogDate(log.created_at)}</td>
												<td class="px-3 py-2 text-sm text-slate-700 font-semibold">{log.bill_number}</td>
												<td class="px-3 py-2 text-sm text-slate-700">{log.bill_amount} SAR</td>
												<td class="px-3 py-2 text-xs text-slate-500">{log.bill_date || '-'}</td>
												<td class="px-3 py-2 text-xs">
													{#if log.rejected}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-red-100 text-red-600">{$t('giftWheel.manager.logs.status.rejected')}</span>
													{:else if log.is_winner}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-emerald-100 text-emerald-600">{$t('giftWheel.manager.logs.status.winner')}</span>
													{:else}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-500">{$t('giftWheel.manager.logs.status.noWin')}</span>
													{/if}
												</td>
												<td class="px-3 py-2 text-sm text-slate-700">{log.reward_label || log.reject_reason || '-'}</td>
												<td class="px-3 py-2 text-sm font-mono text-emerald-600 font-bold">{log.coupon_code || '-'}</td>
												<td class="px-3 py-2 text-xs">
													{#if log.manual_entry}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-orange-100 text-orange-600">{$t('giftWheel.manager.logs.entry.manual')}</span>
													{:else}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-blue-100 text-blue-600">{$t('giftWheel.manager.logs.entry.ocr')}</span>
													{/if}
												</td>
												<td class="px-3 py-2 text-xs text-slate-600 font-semibold">{log.manual_entry_username || '-'}</td>
											</tr>
										{/each}
										{#if spinLogs.length === 0}
											<tr><td colspan="9" class="text-center text-slate-400 py-8 text-sm">{$t('giftWheel.manager.logs.empty')}</td></tr>
										{/if}
									</tbody>
								</table>
							</div>
							{#if logsHasMore && spinLogs.length > 0}
								<div class="p-3 text-center border-t border-slate-100">
									<button
										class="px-4 py-2 rounded-xl text-xs font-bold text-blue-600 bg-blue-50 hover:bg-blue-100 transition-all disabled:opacity-50"
										on:click={loadMoreLogs}
										disabled={logsLoading}
									>
										{logsLoading ? $t('giftWheel.manager.actions.loading') : $t('giftWheel.manager.actions.loadMore')}
									</button>
								</div>
							{/if}
						</div>
						<p class="text-xs text-slate-400 mt-2">{$t('giftWheel.manager.common.showing')} {spinLogs.length} {$t('giftWheel.manager.common.records')}</p>
					{/if}

				<!-- Redemption Logs Tab -->
				{:else if activeTab === 'redemptions'}
					<!-- Filters -->
					<div class="flex items-center gap-2 mb-4 flex-wrap">
						{#each [{ key: 'all', label: $t('giftWheel.manager.redemptions.filters.all') }, { key: 'used', label: $t('giftWheel.manager.redemptions.filters.used') }, { key: 'redeemed', label: $t('giftWheel.manager.redemptions.filters.redeemed') }] as f}
							<button
								class="px-3 py-1.5 rounded-lg text-xs font-bold border transition-all duration-200 {redemptionFilter === f.key ? 'bg-purple-50 border-purple-400 text-purple-600' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}"
								on:click={() => { redemptionFilter = f.key; loadRedemptionLogs(true); }}
							>
								{f.label}
							</button>
						{/each}
						<button
							class="ml-auto px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
							on:click={() => loadRedemptionLogs(true)}
						>
							🔄 {$t('giftWheel.manager.actions.refresh')}
						</button>
					</div>

					{#if redemptionLoading && redemptionLogs.length === 0}
						<div class="flex items-center justify-center py-16">
							<div class="w-8 h-8 border-3 border-slate-200 border-t-purple-500 rounded-full animate-spin"></div>
						</div>
					{:else}
						<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden">
							<div class="overflow-x-auto">
								<table class="w-full border-collapse">
									<thead>
										<tr class="bg-purple-600 text-white">
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.status')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.coupon')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.reward')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.originalBill')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.originalAmount')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.redeemedBill')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.redeemedAmount')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.branch')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.printedAt')}</th>
											<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('giftWheel.manager.redemptions.columns.redeemedAt')}</th>
										</tr>
									</thead>
									<tbody>
										{#each redemptionLogs as log}
											<tr class="hover:bg-purple-50/40 transition-colors duration-200 border-b border-slate-100">
												<td class="px-3 py-2 text-xs">
													{#if log.status === 'redeemed'}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-emerald-100 text-emerald-600">{$t('giftWheel.manager.redemptions.status.redeemed')}</span>
													{:else if log.status === 'used' || log.status === 'printed' || log.status === 'active'}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-amber-100 text-amber-600">{$t('giftWheel.manager.redemptions.status.used')}</span>
													{:else}
														<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-500">{getRedemptionStatusLabel(log.status)}</span>
													{/if}
												</td>
												<td class="px-3 py-2 text-sm font-mono text-purple-700 font-bold">{log.code || '-'}</td>
												<td class="px-3 py-2 text-sm text-slate-700">{log.reward_label || '-'}</td>
												<td class="px-3 py-2 text-sm text-slate-700 font-semibold">{log.bill_number || '-'}</td>
												<td class="px-3 py-2 text-sm text-slate-700">{log.bill_amount || '-'} SAR</td>
												<td class="px-3 py-2 text-sm text-slate-700 font-semibold">{log.redeemed_bill_number || '-'}</td>
												<td class="px-3 py-2 text-sm text-slate-700">{log.redeemed_amount || '-'} SAR</td>
												<td class="px-3 py-2 text-xs text-slate-600">{log.branch_id || '-'}</td>
												<td class="px-3 py-2 text-xs text-slate-500">{log.printed_at ? formatLogDate(log.printed_at) : '-'}</td>
												<td class="px-3 py-2 text-xs text-slate-500">{log.redeemed_at ? formatLogDate(log.redeemed_at) : '-'}</td>
											</tr>
										{/each}
										{#if redemptionLogs.length === 0}
											<tr><td colspan="10" class="text-center text-slate-400 py-8 text-sm">{$t('giftWheel.manager.redemptions.empty')}</td></tr>
										{/if}
									</tbody>
								</table>
							</div>
							{#if redemptionHasMore && redemptionLogs.length > 0}
								<div class="p-3 text-center border-t border-slate-100">
									<button
										class="px-4 py-2 rounded-xl text-xs font-bold text-purple-600 bg-purple-50 hover:bg-purple-100 transition-all disabled:opacity-50"
										on:click={loadMoreRedemptionLogs}
										disabled={redemptionLoading}
									>
										{redemptionLoading ? $t('giftWheel.manager.actions.loading') : $t('giftWheel.manager.actions.loadMore')}
									</button>
								</div>
							{/if}
						</div>
						<p class="text-xs text-slate-400 mt-2">{$t('giftWheel.manager.common.showing')} {redemptionLogs.length} {$t('giftWheel.manager.common.records')}</p>
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
					<h3 class="text-white font-black text-base">{editingReward ? `✏️ ${$t('giftWheel.manager.modals.reward.editTitle')}` : `➕ ${$t('giftWheel.manager.modals.reward.newTitle')}`}</h3>
					<button class="text-white/80 hover:text-white text-xl font-bold transition-colors" on:click={() => showRewardModal = false}>✕</button>
				</div>
				<div class="px-6 py-5 space-y-3">
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.labelEn')}</span>
							<input type="text" bind:value={rewardForm.reward_label_en} placeholder={$t('giftWheel.manager.modals.reward.labelEnPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.labelAr')}</span>
							<input type="text" bind:value={rewardForm.reward_label_ar} placeholder={$t('giftWheel.manager.modals.reward.labelArPlaceholder')} dir="rtl" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.type')}</span>
							<select bind:value={rewardForm.reward_type} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all">
								<option value="percentage">{$t('giftWheel.manager.modals.reward.typePercentage')}</option>
								<option value="fixed">{$t('giftWheel.manager.modals.reward.typeFixed')}</option>
								<option value="no_reward">{$t('giftWheel.manager.modals.reward.typeNoReward')}</option>
							</select>
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.value')}</span>
							<input type="number" bind:value={rewardForm.value} min="0" step="0.01" disabled={rewardForm.reward_type === 'no_reward'} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all disabled:opacity-40" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.maxDiscount')}</span>
							<input type="number" bind:value={rewardForm.max_discount} min="0" step="0.01" placeholder={$t('giftWheel.manager.modals.reward.noLimit')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.minBill')}</span>
							<input type="number" bind:value={rewardForm.min_bill} min="0" step="0.01" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.weight')}</span>
							<input type="number" bind:value={rewardForm.weight} min="1" max="100" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.usageLimit')}</span>
							<input type="number" bind:value={rewardForm.usage_limit} min="0" placeholder={$t('giftWheel.manager.modals.reward.unlimited')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.validityDays')}</span>
							<input type="number" bind:value={rewardForm.validity_days} min="1" max="365" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
							<p class="text-[10px] text-slate-400 mt-1">{$t('giftWheel.manager.modals.reward.validityHint')}</p>
						</div>
						<div class="flex flex-col">
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('giftWheel.manager.modals.reward.active')}</span>
							<label class="switch mt-1">
								<input type="checkbox" bind:checked={rewardForm.active} />
								<span class="slider-toggle"></span>
							</label>
						</div>
					</div>
				</div>
				<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
					<button class="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 bg-slate-200 hover:bg-slate-300 transition-all" on:click={() => showRewardModal = false}>{$t('giftWheel.manager.modals.common.cancel')}</button>
					<button
						class="px-5 py-2 rounded-xl text-sm font-bold text-white bg-emerald-600 hover:bg-emerald-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						on:click={saveReward}
						disabled={rewardSaving || (!rewardForm.reward_label_en && !rewardForm.label)}
					>
						{rewardSaving ? $t('giftWheel.manager.actions.loading') : $t('giftWheel.manager.modals.reward.save')}
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
					<h3 class="text-white font-black text-base">📥 {$t('giftWheel.manager.modals.import.title')}</h3>
					<button class="text-white/80 hover:text-white text-xl font-bold transition-colors" on:click={() => showImportModal = false}>✕</button>
				</div>
				<div class="px-6 py-5">
					<p class="text-xs text-slate-500 mb-1">{$t('giftWheel.manager.modals.import.csvFormat')}</p>
					<p class="text-[11px] text-slate-400 mb-3 font-mono">{$t('giftWheel.manager.modals.import.example')}</p>
					<textarea
						bind:value={importText}
						rows="8"
						placeholder={$t('giftWheel.manager.modals.import.placeholder')}
						class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm font-mono resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
					></textarea>
				</div>
				<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
					<button class="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 bg-slate-200 hover:bg-slate-300 transition-all" on:click={() => showImportModal = false}>{$t('giftWheel.manager.modals.common.cancel')}</button>
					<button
						class="px-5 py-2 rounded-xl text-sm font-bold text-white bg-blue-600 hover:bg-blue-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						on:click={importRewards}
						disabled={importProcessing || !importText.trim()}
					>
						{importProcessing ? $t('giftWheel.manager.modals.import.importing') : $t('giftWheel.manager.modals.import.import')}
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
