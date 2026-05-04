<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	type Tab = 'dashboard' | 'manage';
	let activeTab: Tab = 'dashboard';

	let supabase: any = null;

	// â”€â”€ Campaign Settings â”€â”€
	let settings: any = null;
	let settingsLoading = true;

	// ── Schedule inputs (Saudi time = UTC+3) ──
	let scheduleStart = '';  // datetime-local value
	let scheduleEnd   = '';
	let scheduleSaving = false;
	let scheduleError = '';
	let scheduleSuccess = '';

	// Convert UTC ISO → Saudi datetime-local string for inputs
	function toSaudiLocal(isoUtc: string | null | undefined): string {
		if (!isoUtc) return '';
		const ms = new Date(isoUtc).getTime() + 3 * 60 * 60 * 1000;
		const d = new Date(ms);
		const pad = (n: number) => String(n).padStart(2, '0');
		return `${d.getUTCFullYear()}-${pad(d.getUTCMonth()+1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
	}

	// Convert Saudi datetime-local string → UTC ISO for storage
	function fromSaudiLocal(localStr: string): string | null {
		if (!localStr) return null;
		return new Date(localStr + ':00+03:00').toISOString();
	}

	let stats: any = null;
	let statsLoading = true;
	let statsError = '';

	// â”€â”€ Realtime â”€â”€
	let channel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await Promise.all([loadSettings(), loadStats()]);
		setupRealtime();
	});

	onDestroy(() => {
		if (channel && supabase) supabase.removeChannel(channel);
	});

	function setupRealtime() {
		if (!supabase) return;
		channel = supabase.channel('vip-campaign-admin-rt')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'vip_redemptions' }, () => {
				if (activeTab === 'dashboard') loadStats();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'vip_campaign_settings' }, () => {
				loadSettings();
			})
			.subscribe();
	}

	async function loadSettings() {
		settingsLoading = true;
		scheduleError = '';
		try {
			const { data, error } = await supabase
				.from('vip_campaign_settings')
				.select('*')
				.limit(1)
				.single();
			if (error) throw error;
			settings = data;
			// Populate schedule inputs from DB (convert UTC → Saudi time)
			scheduleStart = toSaudiLocal(data?.start_datetime);
			scheduleEnd   = toSaudiLocal(data?.end_datetime);
		} catch (err: any) {
			scheduleError = err.message || 'Failed to load settings';
		} finally {
			settingsLoading = false;
		}
	}

	// ── Save schedule (converts Saudi input → UTC for DB) ──
	async function saveSchedule() {
		scheduleError = '';
		scheduleSuccess = '';
		if (!scheduleStart || !scheduleEnd) {
			scheduleError = 'Please enter both start and end date/time.';
			return;
		}
		const startUtc = fromSaudiLocal(scheduleStart);
		const endUtc   = fromSaudiLocal(scheduleEnd);
		if (!startUtc || !endUtc) {
			scheduleError = 'Invalid date/time.';
			return;
		}
		if (new Date(endUtc) <= new Date(startUtc)) {
			scheduleError = 'End time must be after start time.';
			return;
		}
		scheduleSaving = true;
		try {
			// Determine is_active based on current time vs schedule
			const nowUtc = new Date().toISOString();
			const shouldBeActive = nowUtc >= startUtc && nowUtc <= endUtc;
			const { error } = await supabase
				.from('vip_campaign_settings')
				.update({
					start_datetime: startUtc,
					end_datetime:   endUtc,
					is_active:      shouldBeActive,
					updated_at:     new Date().toISOString()
				})
				.eq('id', settings.id);
			if (error) throw error;
			settings = { ...settings, start_datetime: startUtc, end_datetime: endUtc, is_active: shouldBeActive };
			scheduleSuccess = 'Schedule saved. Campaign will auto-activate at the scheduled time (Saudi time).';
		} catch (err: any) {
			scheduleError = err.message || 'Failed to save schedule.';
		} finally {
			scheduleSaving = false;
		}
	}

	async function clearSchedule() {
		scheduleError = '';
		scheduleSuccess = '';
		scheduleSaving = true;
		try {
			const { error } = await supabase
				.from('vip_campaign_settings')
				.update({ start_datetime: null, end_datetime: null, is_active: false, updated_at: new Date().toISOString() })
				.eq('id', settings.id);
			if (error) throw error;
			settings = { ...settings, start_datetime: null, end_datetime: null, is_active: false };
			scheduleStart = '';
			scheduleEnd   = '';
			scheduleSuccess = 'Schedule cleared. Campaign is now INACTIVE.';
		} catch (err: any) {
			scheduleError = err.message || 'Failed to clear schedule.';
		} finally {
			scheduleSaving = false;
		}
	}

	async function loadStats() {
		statsLoading = true;
		statsError = '';
		try {
			const { data, error } = await supabase.rpc('get_vip_redemption_stats');
			if (error) throw error;
			stats = data;
		} catch (err: any) {
			statsError = err.message || 'Failed to load stats';
		} finally {
			statsLoading = false;
		}
	}

	function formatDate(iso: string) {
		if (!iso) return '-';
		return new Date(iso).toLocaleString('en-GB', {
			day: '2-digit', month: 'short', year: 'numeric',
			hour: '2-digit', minute: '2-digit'
		});
	}

	function formatSAR(n: number) {
		return 'SAR ' + Number(n || 0).toLocaleString('en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	$: recentList = stats?.recent ?? [];

	// ── Poster Upload ──────────────────────────────────────────────────────────
	let posterUploading = false;
	let posterUploadSuccess = '';
	let posterUploadError = '';
	let posterFileInput: HTMLInputElement;

	async function uploadPoster() {
		if (!posterFileInput?.files?.length) {
			posterUploadError = 'Please select a file to upload.';
			return;
		}
		const file = posterFileInput.files[0];
		const ext = file.name.split('.').pop()?.toLowerCase() || 'bin';
		const storagePath = `vip-poster/instruction_poster.${ext}`;
		posterUploading = true;
		posterUploadSuccess = '';
		posterUploadError = '';
		try {
			const { error: uploadError } = await supabase.storage
				.from('offer-pdfs')
				.upload(storagePath, file, { upsert: true });
			if (uploadError) throw uploadError;

			const { error: dbError } = await supabase
				.from('vip_campaign_settings')
				.update({
					instruction_poster_path: storagePath,
					instruction_poster_mime_type: file.type || null,
					updated_at: new Date().toISOString()
				})
				.eq('id', settings.id);
			if (dbError) throw dbError;

			settings = { ...settings, instruction_poster_path: storagePath, instruction_poster_mime_type: file.type || null };
			posterUploadSuccess = 'Instruction poster uploaded successfully.';
			posterFileInput.value = '';
		} catch (err: any) {
			posterUploadError = err.message || 'Upload failed.';
		} finally {
			posterUploading = false;
		}
	}

	async function removePoster() {
		if (!settings?.instruction_poster_path) return;
		posterUploading = true;
		posterUploadError = '';
		posterUploadSuccess = '';
		try {
			await supabase.storage.from('offer-pdfs').remove([settings.instruction_poster_path]);
			const { error } = await supabase
				.from('vip_campaign_settings')
				.update({ instruction_poster_path: null, instruction_poster_mime_type: null, updated_at: new Date().toISOString() })
				.eq('id', settings.id);
			if (error) throw error;
			settings = { ...settings, instruction_poster_path: null, instruction_poster_mime_type: null };
			posterUploadSuccess = 'Poster removed.';
		} catch (err: any) {
			posterUploadError = err.message || 'Failed to remove poster.';
		} finally {
			posterUploading = false;
		}
	}

	$: posterPublicUrl = (settings?.instruction_poster_path && supabase)
		? supabase.storage.from('offer-pdfs').getPublicUrl(settings.instruction_poster_path).data.publicUrl
		: null;
	$: posterIsImage = (settings?.instruction_poster_mime_type ?? '').startsWith('image/');

	$: if (activeTab === 'dashboard' && !stats && supabase) loadStats();
</script>
<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
<!-- Tab Bar -->
<div class="bg-white border-b border-slate-200 px-6 py-3 flex items-center gap-2 shadow-sm flex-shrink-0">
<button
class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'dashboard' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
on:click={() => { activeTab = 'dashboard'; loadStats(); }}
>
📊 Dashboard
</button>
<button
class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wider transition-all duration-300 rounded-xl overflow-hidden {activeTab === 'manage' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
on:click={() => (activeTab = 'manage')}
>
⚙️ Manage
</button>
</div>

<!-- Content Area -->
<div class="flex-1 p-6 overflow-y-auto relative">
<!-- Decorative blobs -->
<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-purple-100/20 rounded-full blur-[100px] -mr-48 -mt-48 pointer-events-none"></div>
<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-violet-100/20 rounded-full blur-[100px] -ml-48 -mb-48 pointer-events-none"></div>

<div class="relative z-10">

{#if activeTab === 'dashboard'}
{#if statsLoading}
<div class="flex items-center justify-center py-16">
<div class="w-8 h-8 border-4 border-slate-200 border-t-purple-500 rounded-full animate-spin"></div>
</div>
{:else if statsError}
<div class="bg-red-50 border border-red-200 text-red-700 rounded-2xl px-5 py-4 text-sm font-semibold">{statsError}</div>
{:else}
<!-- Stats cards -->
<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
<div class="text-2xl font-black text-slate-800">{stats?.total_redemptions ?? 0}</div>
<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Total Redemptions</div>
</div>
<div class="bg-purple-50/60 backdrop-blur-xl rounded-2xl border border-purple-200 shadow-sm p-4 text-center">
<div class="text-2xl font-black text-purple-700">{stats?.today_redemptions ?? 0}</div>
<div class="text-[10px] font-bold text-purple-400 uppercase tracking-wide mt-1">Today's Redemptions</div>
</div>
<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 text-center">
<div class="text-xl font-black text-slate-800">{formatSAR(stats?.total_discount)}</div>
<div class="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-1">Total Discount Given</div>
</div>
<div class="bg-emerald-50/60 backdrop-blur-xl rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
<div class="text-xl font-black text-emerald-700">{formatSAR(stats?.today_discount)}</div>
<div class="text-[10px] font-bold text-emerald-500 uppercase tracking-wide mt-1">Today's Discount</div>
</div>
</div>

<!-- Recent table -->
<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden">
<div class="px-5 py-3 border-b border-slate-100 flex items-center justify-between">
<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide">👑 Recent VIP Redemptions</h3>
<button
class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all"
on:click={loadStats}
>
🔄 Refresh
</button>
</div>
{#if recentList.length === 0}
<div class="text-center text-slate-400 py-10 text-sm">No redemptions recorded yet.</div>
{:else}
<div class="overflow-x-auto">
<table class="w-full border-collapse">
<thead>
<tr class="bg-purple-600 text-white">
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Date &amp; Time</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Mobile</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Bill #</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Bill Amount</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Discount</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Cashier Name</th>
<th class="px-3 py-2.5 text-xs font-black uppercase tracking-wider text-left">Branch</th>
</tr>
</thead>
<tbody>
{#each recentList as row}
<tr class="hover:bg-purple-50/40 transition-colors duration-200 border-b border-slate-100">
<td class="px-3 py-2 text-xs text-slate-500 whitespace-nowrap">{formatDate(row.redeemed_at)}</td>
<td class="px-3 py-2 text-sm font-mono text-slate-700 font-semibold">{row.whatsapp_number}</td>
<td class="px-3 py-2 text-sm text-slate-700 font-semibold">{row.bill_number}</td>
<td class="px-3 py-2 text-sm text-blue-600 font-semibold">{formatSAR(row.bill_amount)}</td>
<td class="px-3 py-2 text-sm text-emerald-600 font-semibold">{formatSAR(row.discounted_value)}</td>
<td class="px-3 py-2 text-xs text-slate-600">{row.cashier_name_en || row.cashier_id || '-'}</td>
<td class="px-3 py-2 text-xs text-slate-600">
  <div class="font-semibold">{row.branch_name_en || row.branch_id || '-'}</div>
  {#if row.branch_location_en}<div class="text-slate-400 mt-0.5">{row.branch_location_en}</div>{/if}
</td>
</tr>
{/each}
</tbody>
</table>
</div>
<p class="text-xs text-slate-400 px-5 py-2">Showing {recentList.length} most recent records</p>
{/if}
</div>
{/if}

{:else}
{#if settingsLoading}
<div class="flex items-center justify-center py-16">
<div class="w-8 h-8 border-4 border-slate-200 border-t-emerald-500 rounded-full animate-spin"></div>
</div>
{:else if !settings}
<div class="bg-red-50 border border-red-200 text-red-700 rounded-2xl px-5 py-4 text-sm font-semibold">Could not load campaign settings.</div>
{:else}
<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-6 max-w-xl">
<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-2">🗓️ Campaign Schedule <span class="text-purple-500 normal-case font-semibold">(Saudi Time, UTC+3)</span></h3>

<div class="flex items-center gap-3 mb-4 flex-wrap">
{#if settings.is_active}
<span class="px-3 py-1.5 rounded-xl text-sm font-bold bg-emerald-100 text-emerald-700 border border-emerald-200">🟢 VIP Campaign is ACTIVE</span>
{:else}
<span class="px-3 py-1.5 rounded-xl text-sm font-bold bg-red-50 text-red-600 border border-red-200">🔴 VIP Campaign is INACTIVE</span>
{/if}
<span class="text-xs text-slate-400">Last updated: {formatDate(settings.updated_at)}</span>
</div>

<p class="text-sm text-slate-500 mb-4 leading-relaxed">
  Set a start and end date/time. The campaign will <strong class="text-slate-700">auto-activate</strong> when the start time arrives and <strong class="text-slate-700">auto-deactivate</strong> at the end time — every cashier's tab updates in real time.
</p>

{#if settings.start_datetime}
<div class="mb-4 flex items-center gap-3 flex-wrap">
  <span class="text-xs font-bold text-slate-500 uppercase tracking-wide">Current Schedule:</span>
  <span class="px-3 py-1 rounded-lg text-xs font-bold bg-blue-50 text-blue-700 border border-blue-200">
    🕐 {toSaudiLocal(settings.start_datetime).replace('T', ' ')} → {toSaudiLocal(settings.end_datetime).replace('T', ' ')} (KSA)
  </span>
  {#if settings.is_active}
    <span class="px-2 py-1 rounded-lg text-[10px] font-bold bg-emerald-100 text-emerald-700 border border-emerald-200">🟢 ACTIVE NOW</span>
  {:else if settings.start_datetime && new Date() < new Date(settings.start_datetime)}
    <span class="px-2 py-1 rounded-lg text-[10px] font-bold bg-amber-100 text-amber-700 border border-amber-200">⏳ SCHEDULED</span>
  {:else}
    <span class="px-2 py-1 rounded-lg text-[10px] font-bold bg-slate-100 text-slate-500 border border-slate-200">⏹ ENDED</span>
  {/if}
</div>
{/if}

<div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4">
  <div>
    <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1" for="sched-start">Start Date &amp; Time (KSA)</label>
    <input
      id="sched-start"
      type="datetime-local"
      class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400"
      bind:value={scheduleStart}
      disabled={scheduleSaving}
    />
  </div>
  <div>
    <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1" for="sched-end">End Date &amp; Time (KSA)</label>
    <input
      id="sched-end"
      type="datetime-local"
      class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400"
      bind:value={scheduleEnd}
      disabled={scheduleSaving}
    />
  </div>
</div>

{#if scheduleSuccess}
  <div class="bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-xl px-4 py-3 text-sm font-semibold mb-3">{scheduleSuccess}</div>
{/if}
{#if scheduleError}
  <div class="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm font-semibold mb-3">{scheduleError}</div>
{/if}

<div class="flex items-center gap-3 flex-wrap">
  <button
    class="px-5 py-2.5 rounded-xl text-sm font-black text-white bg-purple-600 hover:bg-purple-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none whitespace-nowrap"
    on:click={saveSchedule}
    disabled={scheduleSaving}
  >
    {scheduleSaving ? 'Saving…' : '💾 Save Schedule'}
  </button>
  {#if settings.start_datetime}
    <button
      class="px-4 py-2.5 rounded-xl text-sm font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-all disabled:opacity-50 whitespace-nowrap"
      on:click={clearSchedule}
      disabled={scheduleSaving}
    >
      🗑️ Clear Schedule
    </button>
  {/if}
</div>
<p class="text-[10px] text-slate-400 mt-3">⚡ The server checks the schedule every minute and pushes realtime updates to all connected devices.</p>
</div>

<!-- ── Instruction Poster ── -->
<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-6 max-w-xl mt-4">
<h3 class="text-sm font-black text-slate-700 uppercase tracking-wide mb-3">🖼️ Instruction Poster</h3>
<p class="text-sm text-slate-500 mb-4 leading-relaxed">
  Upload an instruction poster for cashiers. It will be displayed in the VIP Redemption tab so staff know what to do.
</p>

{#if posterPublicUrl}
  <div class="mb-3 rounded-xl overflow-hidden border border-slate-200 bg-slate-50">
    {#if posterIsImage}
      <img src={posterPublicUrl} alt="Instruction Poster" class="w-full max-h-64 object-contain" />
    {:else}
      <a href={posterPublicUrl} target="_blank" rel="noopener noreferrer"
        class="flex items-center gap-2 px-4 py-3 bg-blue-50 text-blue-700 font-semibold text-sm hover:bg-blue-100 transition-colors">
        📄 View Current Instruction Poster
      </a>
    {/if}
  </div>
  <p class="text-xs text-slate-400 mb-3 font-mono truncate">{settings.instruction_poster_path}</p>
{:else}
  <div class="mb-4 bg-slate-50 border border-dashed border-slate-300 rounded-xl px-4 py-6 text-center text-slate-400 text-sm">
    No instruction poster uploaded yet.
  </div>
{/if}

{#if posterUploadSuccess}
  <div class="bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-xl px-4 py-3 text-sm font-semibold mb-3">{posterUploadSuccess}</div>
{/if}
{#if posterUploadError}
  <div class="bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm font-semibold mb-3">{posterUploadError}</div>
{/if}

<div class="flex items-center gap-3 flex-wrap">
  <label class="flex-1 min-w-0">
    <input
      type="file"
      class="block w-full text-sm text-slate-500 file:mr-3 file:py-2 file:px-4 file:rounded-lg file:border-0 file:font-semibold file:bg-purple-50 file:text-purple-700 hover:file:bg-purple-100 cursor-pointer"
      bind:this={posterFileInput}
      disabled={posterUploading}
    />
  </label>
  <button
    class="px-5 py-2.5 rounded-xl text-sm font-black text-white bg-purple-600 hover:bg-purple-700 shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none whitespace-nowrap"
    on:click={uploadPoster}
    disabled={posterUploading}
  >
    {#if posterUploading}Uploading…{:else if posterPublicUrl}🔄 Replace Poster{:else}⬆️ Upload Poster{/if}
  </button>
  {#if posterPublicUrl}
    <button
      class="px-4 py-2.5 rounded-xl text-sm font-bold text-red-600 bg-red-50 hover:bg-red-100 border border-red-200 transition-all disabled:opacity-50 whitespace-nowrap"
      on:click={removePoster}
      disabled={posterUploading}
    >
      🗑️ Remove
    </button>
  {/if}
</div>
</div>

{/if}
{/if}

</div>
</div>
</div>
