<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	let supabase: any = null;
	let activeTab: 'settings' | 'rewards' | 'dashboard' | 'logs' | 'redemptions' = 'settings';

	// ── Settings ──────────────────────────────────────────────────────────────
	let settings: any = null;
	let settingsLoading = false;
	let settingsSaving = false;
	let settingsError = '';
	let settingsSuccess = '';

	// form fields
	let active = false;
	let startDate = '', startTime = '', endDate = '', endTime = '';
	let dailyLimit = 100;
	let minimumBillAmount = 0;
	let enforeBillDate = true;
	let boxCount = 6;
	const DEFAULT_TERMS_EN = `1. The campaign is valid for a limited period as determined by Urban Market management.
2. Participation is allowed only using purchase receipts issued by Urban Market.
3. The receipt must be issued on the same day of participation.
4. A minimum bill amount may be required to qualify for participation.
5. Each receipt can be used only once.
6. Receipt details must be valid and match the system records.
7. Customers must enter a valid mobile number to receive the voucher.
8. Rewards are distributed randomly through the electronic system.
9. Vouchers and rewards cannot be exchanged for cash.
10. Shopping vouchers are valid for future purchases only and cannot be used on the same bill.
11. Each voucher has a specific expiry date and must be used before expiration.
12. Vouchers may not be combined with certain promotions or discounts based on branch policy.
13. Urban Market reserves the right to reject or cancel any participation suspected of misuse or fraud.
14. Urban Market reserves the right to modify, suspend, or terminate the campaign and its terms at any time without prior notice.
15. Participation in the campaign confirms full acceptance of all terms and conditions.`;

	const DEFAULT_TERMS_AR = `1. الحملة سارية لفترة محدودة يحددها إدارة أوربان ماركت.
2. يُسمح بالمشاركة فقط باستخدام إيصالات الشراء الصادرة من أوربان ماركت.
3. يجب أن يكون الإيصال صادرًا في نفس يوم المشاركة.
4. قد يُشترط حد أدنى لقيمة الفاتورة للتأهل للمشاركة.
5. لا يمكن استخدام كل إيصال إلا مرة واحدة فقط.
6. يجب أن تكون تفاصيل الإيصال صحيحة ومطابقة لسجلات النظام.
7. يجب على العملاء إدخال رقم جوال صحيح لاستلام القسيمة.
8. تُوزَّع الجوائز بشكل عشوائي عبر النظام الإلكتروني.
9. لا يمكن استبدال القسائم والجوائز بنقد.
10. قسائم التسوق صالحة للمشتريات المستقبلية فقط ولا يمكن استخدامها على نفس الفاتورة.
11. لكل قسيمة تاريخ انتهاء محدد ويجب استخدامها قبل انتهاء الصلاحية.
12. قد لا تُدمج القسائم مع بعض العروض أو الخصومات وفقًا لسياسة الفرع.
13. يحتفظ أوربان ماركت بالحق في رفض أو إلغاء أي مشاركة يُشتبه في إساءة استخدامها أو الاحتيال.
14. يحتفظ أوربان ماركت بالحق في تعديل الحملة أو تعليقها أو إنهائها وشروطها في أي وقت دون إشعار مسبق.
15. المشاركة في الحملة تعني الموافقة الكاملة على جميع الشروط والأحكام.`;

	let termsEn = DEFAULT_TERMS_EN, termsAr = DEFAULT_TERMS_AR;

	// ── Poster ────────────────────────────────────────────────────────────────
	let posterPath = '';
	let posterUploading = false;
	let posterError = '';
	let posterSuccess = '';

	// ── Rewards ───────────────────────────────────────────────────────────────
	let rewards: any[] = [];
	let rewardsLoading = false;
	let showRewardModal = false;
	let editingReward: any = null;
	let rewardForm = { label_en: '', label_ar: '', voucher_value: 0, is_no_win: false, weight: 1, max_count: '', expiry_days: 30, active: true };
	let rewardSaving = false;
	let rewardError = '';

	// ── Dashboard ─────────────────────────────────────────────────────────────
	let dashboardStats: any = null;
	let dashboardLoading = false;
	let dashboardFrom = new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0];
	let dashboardTo = new Date().toISOString().split('T')[0];

	// ── Logs ──────────────────────────────────────────────────────────────────
	let logs: any[] = [];
	let logsLoading = false;
	let logsPage = 0;
	const PAGE_SIZE = 50;

	// ── Redemptions ───────────────────────────────────────────────────────────
	let redemptions: any[] = [];
	let redemptionsLoading = false;
	let redemptionsPage = 0;

	// ── Realtime ──────────────────────────────────────────────────────────────
	let rtChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadSettings();
		await loadRewards();
		setupRealtime();
		if (activeTab === 'dashboard') await loadDashboard();
		if (activeTab === 'logs') await loadLogs();
		if (activeTab === 'redemptions') await loadRedemptions();
	});

	onDestroy(() => {
		if (rtChannel && supabase) supabase.removeChannel(rtChannel);
	});

	function setupRealtime() {
		rtChannel = supabase
			.channel('surprise-box-manager-rt')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'surprise_box_settings' }, () => loadSettings())
			.on('postgres_changes', { event: '*', schema: 'public', table: 'surprise_box_rewards' }, () => loadRewards())
			.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'surprise_box_plays' }, () => {
				if (activeTab === 'logs') loadLogs();
				if (activeTab === 'dashboard') loadDashboard();
			})
			.on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'surprise_box_vouchers' }, () => {
				if (activeTab === 'redemptions') loadRedemptions();
			})
			.subscribe();
	}

	// ── SETTINGS ──────────────────────────────────────────────────────────────
	async function loadSettings() {
		settingsLoading = true;
		try {
			const { data } = await supabase.from('surprise_box_settings').select('*').limit(1).single();
			if (data) {
				settings = data;
				active = data.active;
				dailyLimit = data.daily_limit;
				minimumBillAmount = data.minimum_bill_amount;
				enforeBillDate = data.enforce_bill_date;
				boxCount = data.box_count;
				termsEn = data.terms_en || DEFAULT_TERMS_EN;
				termsAr = data.terms_ar || DEFAULT_TERMS_AR;
				posterPath = data.instruction_poster_path || '';
				if (data.start_datetime) {
					const dt = new Date(data.start_datetime);
					startDate = dt.toISOString().split('T')[0];
					startTime = dt.toTimeString().slice(0,5);
				}
				if (data.end_datetime) {
					const dt = new Date(data.end_datetime);
					endDate = dt.toISOString().split('T')[0];
					endTime = dt.toTimeString().slice(0,5);
				}
			}
		} catch(e) { settingsError = 'Failed to load settings'; }
		finally { settingsLoading = false; }
	}

	async function saveSettings() {
		settingsSaving = true;
		settingsError = '';
		settingsSuccess = '';
		try {
			const payload: any = {
				active,
				daily_limit: dailyLimit,
				minimum_bill_amount: minimumBillAmount,
				enforce_bill_date: enforeBillDate,
				box_count: boxCount,
				terms_en: termsEn,
				terms_ar: termsAr,
				start_datetime: startDate && startTime ? new Date(`${startDate}T${startTime}:00`).toISOString() : null,
				end_datetime: endDate && endTime ? new Date(`${endDate}T${endTime}:00`).toISOString() : null,
				updated_at: new Date().toISOString()
			};
			if (settings?.id) {
				const { error } = await supabase.from('surprise_box_settings').update(payload).eq('id', settings.id);
				if (error) throw error;
			} else {
				const { error } = await supabase.from('surprise_box_settings').insert(payload);
				if (error) throw error;
			}
			settingsSuccess = 'Settings saved successfully!';
			await loadSettings();
		} catch(e: any) { settingsError = e?.message || 'Failed to save'; }
		finally { settingsSaving = false; }
	}

	// ── POSTER ────────────────────────────────────────────────────────────────
	async function uploadPoster(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		if (file.size > 5 * 1024 * 1024) { posterError = 'File too large (max 5MB)'; return; }
		posterUploading = true;
		posterError = '';
		posterSuccess = '';
		try {
			const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg';
			const path = `surprise-box/instruction-poster.${ext}`;
			const { error: upErr } = await supabase.storage.from('offer-pdfs').upload(path, file, { upsert: true });
			if (upErr) throw upErr;
			if (settings?.id) {
				const { error: dbErr } = await supabase.from('surprise_box_settings').update({ instruction_poster_path: path }).eq('id', settings.id);
				if (dbErr) throw dbErr;
			}
			await loadSettings();
			posterSuccess = 'Poster uploaded successfully!';
			setTimeout(() => posterSuccess = '', 4000);
		} catch (err: any) {
			posterError = err?.message || 'Upload failed';
		} finally {
			posterUploading = false;
			(e.target as HTMLInputElement).value = '';
		}
	}

	async function removePoster() {
		if (!posterPath || posterUploading) return;
		posterUploading = true;
		posterError = '';
		try {
			await supabase.storage.from('offer-pdfs').remove([posterPath]);
			if (settings?.id) {
				await supabase.from('surprise_box_settings').update({ instruction_poster_path: null }).eq('id', settings.id);
			}
			await loadSettings();
		} catch (err: any) {
			posterError = err?.message || 'Failed to remove poster';
		} finally {
			posterUploading = false;
		}
	}

	// ── REWARDS ───────────────────────────────────────────────────────────────
	async function loadRewards() {
		rewardsLoading = true;
		try {
			const { data } = await supabase.from('surprise_box_rewards').select('*').order('weight', { ascending: false });
			rewards = data || [];
		} catch { }
		finally { rewardsLoading = false; }
	}

	function openNewReward() {
		editingReward = null;
		rewardForm = { label_en: '', label_ar: '', voucher_value: 0, is_no_win: false, weight: 1, max_count: '', expiry_days: 30, active: true };
		rewardError = '';
		showRewardModal = true;
	}

	function openEditReward(r: any) {
		editingReward = r;
		rewardForm = {
			label_en: r.label_en,
			label_ar: r.label_ar,
			voucher_value: r.voucher_value,
			is_no_win: r.is_no_win,
			weight: r.weight,
			max_count: r.max_count != null ? String(r.max_count) : '',
			expiry_days: r.expiry_days,
			active: r.active
		};
		rewardError = '';
		showRewardModal = true;
	}

	async function saveReward() {
		rewardSaving = true;
		rewardError = '';
		try {
			const payload = {
				label_en: rewardForm.label_en.trim(),
				label_ar: rewardForm.label_ar.trim(),
				voucher_value: rewardForm.is_no_win ? 0 : Number(rewardForm.voucher_value),
				is_no_win: rewardForm.is_no_win,
				weight: Number(rewardForm.weight),
				max_count: rewardForm.max_count !== '' ? Number(rewardForm.max_count) : null,
				expiry_days: Number(rewardForm.expiry_days),
				active: rewardForm.active
			};
			if (editingReward) {
				const { error } = await supabase.from('surprise_box_rewards').update(payload).eq('id', editingReward.id);
				if (error) throw error;
			} else {
				const { error } = await supabase.from('surprise_box_rewards').insert(payload);
				if (error) throw error;
			}
			showRewardModal = false;
			await loadRewards();
		} catch(e: any) { rewardError = e?.message || 'Failed to save reward'; }
		finally { rewardSaving = false; }
	}

	async function toggleReward(r: any) {
		await supabase.from('surprise_box_rewards').update({ active: !r.active }).eq('id', r.id);
		await loadRewards();
	}

	async function deleteReward(id: string) {
		if (!confirm('Delete this reward?')) return;
		await supabase.from('surprise_box_rewards').delete().eq('id', id);
		await loadRewards();
	}

	// ── DASHBOARD ─────────────────────────────────────────────────────────────
	async function loadDashboard() {
		dashboardLoading = true;
		try {
			const { data } = await supabase.rpc('surprise_box_dashboard_stats', {
				p_from: `${dashboardFrom}T00:00:00Z`,
				p_to: `${dashboardTo}T23:59:59Z`
			});
			dashboardStats = data;
		} catch { }
		finally { dashboardLoading = false; }
	}

	// ── LOGS ──────────────────────────────────────────────────────────────────
	async function loadLogs(reset = true) {
		if (reset) logsPage = 0;
		logsLoading = true;
		try {
			const { data } = await supabase
				.from('surprise_box_plays')
				.select('*, surprise_box_rewards(label_en, label_ar)')
				.order('created_at', { ascending: false })
				.range(logsPage * PAGE_SIZE, logsPage * PAGE_SIZE + PAGE_SIZE - 1);
			if (reset) logs = data || [];
			else logs = [...logs, ...(data || [])];
		} catch { }
		finally { logsLoading = false; }
	}

	// ── REDEMPTIONS ───────────────────────────────────────────────────────────
	async function loadRedemptions(reset = true) {
		if (reset) redemptionsPage = 0;
		redemptionsLoading = true;
		try {
			const { data } = await supabase
				.from('surprise_box_vouchers')
				.select('*')
				.order('created_at', { ascending: false })
				.range(redemptionsPage * PAGE_SIZE, redemptionsPage * PAGE_SIZE + PAGE_SIZE - 1);
			if (reset) redemptions = data || [];
			else redemptions = [...redemptions, ...(data || [])];
		} catch { }
		finally { redemptionsLoading = false; }
	}

	// ── Tab switching ─────────────────────────────────────────────────────────
	async function switchTab(tab: typeof activeTab) {
		activeTab = tab;
		if (tab === 'dashboard') await loadDashboard();
		if (tab === 'logs') await loadLogs();
		if (tab === 'redemptions') await loadRedemptions();
	}

	async function downloadLogVoucher(log: any) {
		if (!log.voucher_code) return;

		// Fetch voucher details (value + expiry) from vouchers table
		let voucherValue = 0;
		let expiresAt = '';
		try {
			const { data } = await supabase
				.from('surprise_box_vouchers')
				.select('voucher_value, expires_at')
				.eq('code', log.voucher_code)
				.single();
			if (data) { voucherValue = data.voucher_value; expiresAt = data.expires_at || ''; }
		} catch { /* use fallbacks */ }

		const rewardLabel = $locale === 'ar'
			? (log.surprise_box_rewards?.label_ar || log.surprise_box_rewards?.label_en || 'قسيمة مشتريات')
			: (log.surprise_box_rewards?.label_en || log.surprise_box_rewards?.label_ar || 'Shopping Voucher');

		const { downloadVoucherPNG } = await import('$lib/utils/voucherCanvas');
		await downloadVoucherPNG(
			{
				voucherCode:  log.voucher_code,
				voucherValue,
				rewardLabel,
				expiresAt,
				billNumber:   log.bill_number
			},
			`surprise-box-${log.voucher_code}.png`
		);
	}

	function fmtDate(d: string) {
		if (!d) return '—';
		return new Date(d).toLocaleString('en-SA', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
	}
	function fmtDay(d: string) {
		if (!d) return '—';
		return new Date(d).toLocaleDateString('en-SA', { year: 'numeric', month: 'short', day: 'numeric' });
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">

	<!-- Tab Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center gap-2 shadow-sm flex-shrink-0 flex-wrap">
		<button
			class="flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl {activeTab === 'settings' ? 'bg-violet-600 text-white shadow-lg shadow-violet-200 scale-[1.02]' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'}"
			on:click={() => switchTab('settings')}
		>⚙️ Settings</button>
		<button
			class="flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl {activeTab === 'rewards' ? 'bg-amber-500 text-white shadow-lg shadow-amber-200 scale-[1.02]' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'}"
			on:click={() => switchTab('rewards')}
		>🎁 Rewards</button>
		<button
			class="flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl {activeTab === 'dashboard' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'}"
			on:click={() => switchTab('dashboard')}
		>📊 Dashboard</button>
		<button
			class="flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl {activeTab === 'logs' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'}"
			on:click={() => switchTab('logs')}
		>📋 Logs</button>
		<button
			class="flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl {activeTab === 'redemptions' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'}"
			on:click={() => switchTab('redemptions')}
		>✅ Redemptions</button>
	</div>

	<!-- Content -->
	<div class="flex-1 p-6 overflow-y-auto relative">
		<!-- Decorative blobs -->
		<div class="absolute top-0 right-0 w-96 h-96 bg-violet-100/20 rounded-full blur-[100px] -mr-48 -mt-48 pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-96 h-96 bg-purple-100/20 rounded-full blur-[100px] -ml-48 -mb-48 pointer-events-none"></div>

		<div class="relative z-10">

		<!-- ── SETTINGS ──────────────────────────────────────────────────────── -->
		{#if activeTab === 'settings'}
			{#if settingsLoading}
				<div class="flex items-center justify-center py-16">
					<div class="w-8 h-8 border-[3px] border-slate-200 border-t-violet-500 rounded-full animate-spin"></div>
				</div>
			{:else}
				<!-- Active toggle -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔌 {$t('surpriseBox.manager.settings.campaignStatus')}</h3>
					<div class="flex items-center justify-between">
						<span class="text-sm font-semibold text-slate-600">{$t('surpriseBox.manager.settings.campaignActive')}</span>
						<label class="switch">
							<input type="checkbox" bind:checked={active} />
							<span class="slider-toggle"></span>
						</label>
					</div>
					{#if !active}
						<p class="mt-2 text-xs font-bold text-red-500">{$t('surpriseBox.manager.settings.campaignDisabled')}</p>
					{/if}
				</div>

				<!-- Schedule -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📅 {$t('surpriseBox.manager.settings.schedule')}</h3>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.startDate')}</span>
							<input type="date" bind:value={startDate} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.startTime')}</span>
							<input type="time" bind:value={startTime} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.endDate')}</span>
							<input type="date" bind:value={endDate} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.endTime')}</span>
							<input type="time" bind:value={endTime} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
					</div>
					<p class="mt-2 text-xs text-slate-400">{$t('surpriseBox.manager.settings.scheduleHint')}</p>
				</div>

				<!-- Limits -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🔢 {$t('surpriseBox.manager.settings.limits')}</h3>
					<div class="grid grid-cols-2 gap-3 mb-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.dailyLimit')}</span>
							<input type="number" min="1" bind:value={dailyLimit} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.minimumAmount')}</span>
							<input type="number" min="0" step="0.01" bind:value={minimumBillAmount} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.boxCount')}</span>
							<input type="number" min="1" max="12" bind:value={boxCount} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all" />
						</div>
						<div class="flex flex-col gap-1.5">
							<span class="block text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('surpriseBox.manager.settings.enforceBillDate')}</span>
							<p class="text-xs text-slate-400">{$t('surpriseBox.manager.settings.enforceBillDateHint')}</p>
							<label class="switch mt-1">
								<input type="checkbox" bind:checked={enforeBillDate} />
								<span class="slider-toggle"></span>
							</label>
						</div>
					</div>
				</div>

				<!-- Terms -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">📜 {$t('surpriseBox.manager.settings.terms')}</h3>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.termsEn')}</span>
							<textarea bind:value={termsEn} rows="4" placeholder="Enter terms in English…"
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all resize-y"></textarea>
						</div>
						<div>
							<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.settings.termsAr')}</span>
							<textarea bind:value={termsAr} rows="4" dir="rtl" placeholder="أدخل الشروط بالعربية…"
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all resize-y"></textarea>
						</div>
					</div>
				</div>

				<!-- Instruction Poster -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-1">🖼️ Instruction Poster</h3>
					<p class="text-xs text-slate-400 mb-3">Displayed to cashiers in the Surprise Box Redemption section.</p>

					{#if posterPath && supabase}
						{@const posterPreviewUrl = supabase.storage.from('offer-pdfs').getPublicUrl(posterPath).data.publicUrl}
						<div class="relative mb-3">
							<img src={posterPreviewUrl} alt="Instruction Poster" class="w-full max-h-56 object-contain rounded-xl border border-slate-200 bg-slate-50" />
							<button
								class="absolute top-2 right-2 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center text-xs shadow-md transition-all disabled:opacity-50"
								disabled={posterUploading}
								on:click={removePoster}
							>✕</button>
						</div>
					{/if}

					<label class="flex items-center gap-3 cursor-pointer">
						<span class="px-4 py-2 rounded-xl text-xs font-bold text-white bg-violet-600 hover:bg-violet-700 shadow-md transition-all {posterUploading ? 'opacity-50 cursor-not-allowed' : ''}">
							{#if posterUploading}⏳ Uploading…{:else if posterPath}🔄 Replace Poster{:else}📤 Upload Poster{/if}
						</span>
						<span class="text-xs text-slate-400">JPG, PNG, WEBP — max 5MB</span>
						<input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" disabled={posterUploading} on:change={uploadPoster} />
					</label>

					{#if posterError}<p class="mt-2 text-xs font-bold text-red-500">{posterError}</p>{/if}
					{#if posterSuccess}<p class="mt-2 text-xs font-bold text-emerald-600">{posterSuccess}</p>{/if}
				</div>

				<!-- Save -->
				<div class="flex items-center justify-end gap-3 mb-4">
					{#if settingsError}
						<span class="text-sm font-bold text-red-500">{settingsError}</span>
					{/if}
					{#if settingsSuccess}
						<span class="text-sm font-bold text-emerald-600">{settingsSuccess}</span>
					{/if}
					<button
						class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-violet-600 hover:bg-violet-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						disabled={settingsSaving}
						on:click={saveSettings}
					>
						{settingsSaving ? $t('surpriseBox.manager.settings.saving') : `💾 ${$t('surpriseBox.manager.settings.save')}`}
					</button>
				</div>
			{/if}

		<!-- ── REWARDS ────────────────────────────────────────────────────────── -->
		{:else if activeTab === 'rewards'}
			<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">🎁 {$t('surpriseBox.manager.rewards.title')}</h3>
					<button
						class="px-4 py-1.5 rounded-lg text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105"
						on:click={openNewReward}
					>➕ {$t('surpriseBox.manager.rewards.addReward')}</button>
				</div>
				{#if rewardsLoading}
					<div class="flex items-center justify-center py-8">
						<div class="w-8 h-8 border-[3px] border-slate-200 border-t-amber-500 rounded-full animate-spin"></div>
					</div>
				{:else}
					<div class="overflow-x-auto rounded-xl border border-slate-200">
						<table class="w-full border-collapse">
							<thead>
								<tr class="bg-amber-500 text-white">
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.labelEn')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.labelAr')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.value')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.weight')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.max')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.issued')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.expiry')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.noWin')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.active')}</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">{$t('surpriseBox.manager.rewards.columns.actions')}</th>
								</tr>
							</thead>
							<tbody>
								{#each rewards as r}
									<tr class="hover:bg-amber-50/40 transition-colors border-b border-slate-100 {!r.active ? 'opacity-40' : ''}">
										<td class="px-3 py-2.5 text-sm text-slate-700 font-semibold">{r.label_en}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700" dir="rtl">{r.label_ar}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700">{r.is_no_win ? '—' : `${r.voucher_value} SAR`}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700">{r.weight}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700">{r.max_count ?? '∞'}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700">{r.issued_count}</td>
										<td class="px-3 py-2.5 text-sm text-slate-700">{r.expiry_days}d</td>
										<td class="px-3 py-2.5 text-sm">
											{#if r.is_no_win}
												<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-500">{$t('surpriseBox.manager.common.yes')}</span>
											{:else}
												<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold bg-emerald-100 text-emerald-600">{$t('surpriseBox.manager.common.no')}</span>
											{/if}
										</td>
										<td class="px-3 py-2.5 text-sm">
											<button class="text-base transition-transform hover:scale-125" on:click={() => toggleReward(r)}>
												{r.active ? '✅' : '❌'}
											</button>
										</td>
										<td class="px-3 py-2.5 text-sm flex gap-1">
											<button class="w-7 h-7 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => openEditReward(r)}>✏️</button>
											<button class="w-7 h-7 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 flex items-center justify-center transition-all hover:scale-110" on:click={() => deleteReward(r.id)}>🗑️</button>
										</td>
									</tr>
								{/each}
								{#if rewards.length === 0}
									<tr><td colspan="10" class="text-center text-slate-400 py-8 text-sm">{$t('surpriseBox.manager.rewards.noRewards')}</td></tr>
								{/if}
							</tbody>
						</table>
					</div>
				{/if}
			</div>

		<!-- ── DASHBOARD ──────────────────────────────────────────────────────── -->
		{:else if activeTab === 'dashboard'}
			<!-- Date filter -->
			<div class="flex items-center gap-3 mb-4 flex-wrap">
				<div class="flex items-center gap-2">
					<input type="date" bind:value={dashboardFrom} class="px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 transition-all" />
					<span class="text-xs text-slate-400">{$t('surpriseBox.manager.dashboard.to')}</span>
					<input type="date" bind:value={dashboardTo} class="px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 transition-all" />
					<button class="px-4 py-1.5 rounded-lg text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 transition-all" on:click={loadDashboard}>🔄 {$t('surpriseBox.manager.dashboard.apply')}</button>
				</div>
			</div>

			{#if dashboardLoading}
				<div class="flex items-center justify-center py-16">
					<div class="w-8 h-8 border-[3px] border-slate-200 border-t-emerald-500 rounded-full animate-spin"></div>
				</div>
			{:else if dashboardStats}
				<div class="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-4">
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-slate-800">{dashboardStats.total_plays ?? 0}</div>
						<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.totalPlays')}</div>
					</div>
					<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-emerald-600">{dashboardStats.total_winners ?? 0}</div>
						<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.winners')}</div>
					</div>
					<div class="bg-red-50/60 backdrop-blur-xl rounded-2xl border border-red-200 shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-red-500">{dashboardStats.total_rejected ?? 0}</div>
						<div class="text-[10px] font-bold text-red-400 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.rejected')}</div>
					</div>
					<div class="bg-amber-50/60 backdrop-blur-xl rounded-2xl border border-amber-200 shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-amber-600">{dashboardStats.total_voucher_value ?? 0} SAR</div>
						<div class="text-[10px] font-bold text-amber-500 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.voucherValue')}</div>
					</div>
					<div class="bg-violet-50/60 backdrop-blur-xl rounded-2xl border border-violet-200 shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-violet-600">{dashboardStats.total_redeemed ?? 0}</div>
						<div class="text-[10px] font-bold text-violet-500 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.redeemed')}</div>
					</div>
					<div class="bg-teal-50/60 backdrop-blur-xl rounded-2xl border border-teal-200 shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-teal-600">{dashboardStats.total_redeemed_value ?? 0} SAR</div>
						<div class="text-[10px] font-bold text-teal-500 uppercase tracking-wide mt-1">Redeemed Value</div>
					</div>
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
						<div class="text-2xl font-black text-slate-800">{dashboardStats.redemption_rate ?? 0}%</div>
						<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">{$t('surpriseBox.manager.dashboard.redemptionRate')}</div>
					</div>
				</div>
			{:else}
				<div class="text-center py-16 text-slate-400 text-sm">{$t('surpriseBox.manager.dashboard.noData')}</div>
			{/if}

		<!-- ── LOGS ───────────────────────────────────────────────────────────── -->
		{:else if activeTab === 'logs'}
			<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">📋 {$t('surpriseBox.manager.logs.title')}</h3>
					<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all" on:click={() => loadLogs()}>🔄 {$t('surpriseBox.manager.logs.refresh')}</button>
				</div>
				{#if logsLoading}
					<div class="flex items-center justify-center py-8">
						<div class="w-8 h-8 border-[3px] border-slate-200 border-t-blue-500 rounded-full animate-spin"></div>
					</div>
				{:else}
					<div class="overflow-x-auto rounded-xl border border-slate-200">
						<table class="w-full border-collapse">
							<thead>
								<tr class="bg-blue-600 text-white">
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Date</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Bill #</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Amount</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Bill Date</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Reward</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Voucher Code</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Winner</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Rejected</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Reason</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Manual</th>
								<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-center whitespace-nowrap">Download</th>
								</tr>
							</thead>
							<tbody>
								{#each logs as log}
									<tr class="hover:bg-blue-50/40 transition-colors border-b border-slate-100 {log.rejected ? 'opacity-60' : ''}">
										<td class="px-3 py-2 text-xs text-slate-600">{fmtDate(log.created_at)}</td>
										<td class="px-3 py-2 text-xs"><code class="font-mono bg-slate-100 rounded px-1.5 py-0.5 text-slate-700">{log.bill_number}</code></td>
										<td class="px-3 py-2 text-xs text-slate-700">{log.bill_amount} SAR</td>
										<td class="px-3 py-2 text-xs text-slate-600">{log.bill_date || '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-700 font-semibold">{$locale === 'ar' ? (log.surprise_box_rewards?.label_ar || log.surprise_box_rewards?.label_en || '—') : (log.surprise_box_rewards?.label_en || log.surprise_box_rewards?.label_ar || '—')}</td>
										<td class="px-3 py-2 text-xs"><code class="font-mono bg-slate-100 rounded px-1.5 py-0.5 text-slate-700">{log.voucher_code || '—'}</code></td>
										<td class="px-3 py-2 text-xs">
											<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold {log.is_winner ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-500'}">{log.is_winner ? $t('surpriseBox.manager.common.yes') : $t('surpriseBox.manager.common.no')}</span>
										</td>
										<td class="px-3 py-2 text-xs">
											<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold {log.rejected ? 'bg-red-100 text-red-600' : 'bg-emerald-100 text-emerald-600'}">{log.rejected ? $t('surpriseBox.manager.common.yes') : $t('surpriseBox.manager.common.no')}</span>
										</td>
										<td class="px-3 py-2 text-xs text-slate-500">{log.reject_reason || '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-500">{log.manual_entry ? `✏️ ${log.manual_entry_username || ''}` : '—'}</td>
										<td class="px-3 py-2 text-center">
											{#if log.is_winner && log.voucher_code}
												<button
													class="px-2 py-1 rounded-lg text-[11px] font-bold bg-amber-100 text-amber-700 hover:bg-amber-200 border border-amber-300 transition-all whitespace-nowrap"
													on:click={() => downloadLogVoucher(log)}
												>{$t('surpriseBox.manager.logs.download')}</button>
											{:else}
												<span class="text-slate-300">—</span>
											{/if}
										</td>
									</tr>
								{/each}
								{#if logs.length === 0}
							<tr><td colspan="11" class="text-center text-slate-400 py-8 text-sm">{$t('surpriseBox.manager.logs.noLogs')}</td></tr>
								{/if}
							</tbody>
						</table>
					</div>
					{#if logs.length === PAGE_SIZE}
						<button class="w-full mt-3 px-4 py-2 rounded-xl text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
							on:click={() => { logsPage++; loadLogs(false); }}>{$t('surpriseBox.manager.logs.loadMore')}</button>
					{/if}
				{/if}
			</div>

		<!-- ── REDEMPTIONS ────────────────────────────────────────────────────── -->
		{:else if activeTab === 'redemptions'}
			<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 mb-4">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">✅ {$t('surpriseBox.manager.redemptions.title')}</h3>
					<button class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all" on:click={() => loadRedemptions()}>🔄 {$t('surpriseBox.manager.redemptions.refresh')}</button>
				</div>
				{#if redemptionsLoading}
					<div class="flex items-center justify-center py-8">
						<div class="w-8 h-8 border-[3px] border-slate-200 border-t-purple-500 rounded-full animate-spin"></div>
					</div>
				{:else}
					<div class="overflow-x-auto rounded-xl border border-slate-200">
						<table class="w-full border-collapse">
							<thead>
								<tr class="bg-purple-600 text-white">
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Code</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Label</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Value</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Status</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Issued</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Expires</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Bill #</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Redeemed At</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Redeemed Bill</th>
									<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left whitespace-nowrap">Amount</th>
								</tr>
							</thead>
							<tbody>
								{#each redemptions as v}
									<tr class="hover:bg-purple-50/40 transition-colors border-b border-slate-100">
										<td class="px-3 py-2 text-xs"><code class="font-mono bg-slate-100 rounded px-1.5 py-0.5 text-slate-700">{v.code}</code></td>
										<td class="px-3 py-2 text-xs text-slate-700 font-semibold">{$locale === 'ar' ? (v.label_ar || v.label_en || '—') : (v.label_en || v.label_ar || '—')}</td>
										<td class="px-3 py-2 text-xs text-slate-700">{v.voucher_value} SAR</td>
										<td class="px-3 py-2 text-xs">
											<span class="px-2 py-0.5 rounded-lg text-[11px] font-bold {v.status === 'redeemed' ? 'bg-emerald-100 text-emerald-600' : v.status === 'expired' ? 'bg-red-100 text-red-600' : v.status === 'cancelled' ? 'bg-slate-100 text-slate-500' : 'bg-blue-100 text-blue-600'}">{v.status}</span>
										</td>
										<td class="px-3 py-2 text-xs text-slate-600">{fmtDay(v.issued_at)}</td>
										<td class="px-3 py-2 text-xs text-slate-600">{v.expires_at || '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-600">{v.bill_number || '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-600">{v.redeemed_at ? fmtDate(v.redeemed_at) : '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-600">{v.redeemed_bill_number || '—'}</td>
										<td class="px-3 py-2 text-xs text-slate-700">{v.redeemed_amount != null ? `${v.redeemed_amount} SAR` : '—'}</td>
									</tr>
								{/each}
								{#if redemptions.length === 0}
							<tr><td colspan="10" class="text-center text-slate-400 py-8 text-sm">{$t('surpriseBox.manager.redemptions.noRedemptions')}</td></tr>
								{/if}
							</tbody>
						</table>
					</div>
					{#if redemptions.length === PAGE_SIZE}
						<button class="w-full mt-3 px-4 py-2 rounded-xl text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
							on:click={() => { redemptionsPage++; loadRedemptions(false); }}>{$t('surpriseBox.manager.redemptions.loadMore')}</button>
					{/if}
				{/if}
			</div>
		{/if}

		</div><!-- /relative z-10 -->
	</div><!-- /content -->
</div>

<!-- ── REWARD MODAL ────────────────────────────────────────────────────────── -->
{#if showRewardModal}
	<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-2xl border border-slate-200 shadow-2xl p-6 w-full max-w-lg flex flex-col gap-4 max-h-[90vh] overflow-y-auto">
			<h3 class="text-base font-black text-slate-800">{editingReward ? $t('surpriseBox.manager.modal.editReward') : $t('surpriseBox.manager.modal.addReward')}</h3>

			<!-- No-win toggle -->
			<div class="flex items-center justify-between py-1">
				<span class="text-sm font-semibold text-slate-600">{$t('surpriseBox.manager.modal.noWin')}</span>
				<label class="switch">
					<input type="checkbox" bind:checked={rewardForm.is_no_win} />
					<span class="slider-toggle"></span>
				</label>
			</div>

			<div class="grid grid-cols-2 gap-3">
				<div>
					<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.labelEn')}</span>
					<input type="text" bind:value={rewardForm.label_en} placeholder="e.g. 10 SAR Voucher"
						class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
				</div>
				<div>
					<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.labelAr')}</span>
					<input type="text" dir="rtl" bind:value={rewardForm.label_ar} placeholder="مثال: قسيمة 10 ريال"
						class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
				</div>
			</div>

			{#if !rewardForm.is_no_win}
				<div>
					<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.voucherValue')}</span>
					<input type="number" min="0" step="0.01" bind:value={rewardForm.voucher_value}
						class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
				</div>
			{/if}

			<div class="grid grid-cols-2 gap-3">
				<div>
					<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.weight')}</span>
					<input type="number" min="1" bind:value={rewardForm.weight}
						class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
				</div>
				<div>
					<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.maxCount')}</span>
					<input type="number" min="1" bind:value={rewardForm.max_count} placeholder="Unlimited"
						class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
				</div>
			</div>

			<div>
				<span class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">{$t('surpriseBox.manager.modal.expiryDays')}</span>
				<input type="number" min="1" bind:value={rewardForm.expiry_days}
					class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 transition-all" />
			</div>

			<div class="flex items-center justify-between py-1">
				<span class="text-sm font-semibold text-slate-600">{$t('surpriseBox.manager.modal.active')}</span>
				<label class="switch">
					<input type="checkbox" bind:checked={rewardForm.active} />
					<span class="slider-toggle"></span>
				</label>
			</div>

			{#if rewardError}
				<div class="bg-red-50 border border-red-200 rounded-xl px-4 py-2 text-sm text-red-600 font-semibold">{rewardError}</div>
			{/if}

			<div class="flex gap-3">
				<button
					class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-violet-600 hover:bg-violet-700 shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed"
					disabled={rewardSaving}
					on:click={saveReward}
				>{rewardSaving ? $t('surpriseBox.manager.modal.saving') : $t('surpriseBox.manager.modal.save')}</button>
				<button
					class="px-4 py-2.5 rounded-xl font-bold text-sm text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
					on:click={() => showRewardModal = false}
				>{ $t('surpriseBox.manager.modal.cancel')}</button>
			</div>
		</div>
	</div>
{/if}

<style>
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
		top: 0; left: 0; right: 0; bottom: 0;
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
	.switch input:checked + .slider-toggle { background: #7c3aed; }
	.switch input:checked + .slider-toggle::before { transform: translateX(20px); }
</style>
