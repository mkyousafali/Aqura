<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { locale } from '$lib/i18n';
	import { loadBreakRegisterData } from '$lib/utils/breakRegisterApi';

	export let layout: 'desktop' | 'mobile' = 'desktop';
	let breaks: any[] = [];
	let branches: any[] = [];
	let scope = 'own';
	let loading = true;
	let error = '';
	let from = '';
	let to = '';
	let status = '';
	let branch = '';
	let search = '';
	let now = Date.now();
	let timer: ReturnType<typeof setInterval> | undefined;
	let poll: ReturnType<typeof setInterval> | undefined;
	let onVisible: (() => void) | undefined;
	let onOnline: (() => void) | undefined;
	$: rtl = $locale === 'ar';
	$: shown = breaks.filter(b => {
		if (!search.trim()) return true;
		const term = search.toLowerCase();
		return [b.employee_id, b.employee_name_en, b.employee_name_ar, b.reason_en, b.reason_ar]
			.some(v => String(v || '').toLowerCase().includes(term));
	});
	$: open = shown.filter(b => b.status === 'open');
	$: closed = shown.filter(b => b.status === 'closed');

	function dateInRiyadh(daysAgo: number) {
		const date = new Date(Date.now() + 3 * 3600000 - daysAgo * 86400000);
		return date.toISOString().slice(0, 10);
	}
	async function refresh(silent = false) {
		if (!silent) loading = true;
		try {
			const result = await loadBreakRegisterData('logs', { from, to, status, branch }, layout);
			breaks = result.breaks || [];
			branches = result.branches || [];
			scope = result.scope || 'own';
			error = '';
		} catch (e) {
			breaks = [];
			error = e instanceof Error ? e.message : 'Could not load breaks';
		} finally {
			loading = false;
		}
	}
	function duration(seconds: number) {
		const value = Math.max(0, Math.floor(seconds));
		const h = Math.floor(value / 3600), m = Math.floor(value % 3600 / 60), s = value % 60;
		return h ? `${h}h ${m}m ${s}s` : m ? `${m}m ${s}s` : `${s}s`;
	}
	function shownDuration(b: any, currentTime: number) {
		return duration(b.status === 'open' ? (currentTime - new Date(b.start_time).getTime()) / 1000 : Number(b.duration_seconds) || 0);
	}
	function timestamp(value: string | null) {
		return value ? new Date(value).toLocaleString(rtl ? 'ar-SA' : 'en-GB', { timeZone: 'Asia/Riyadh', dateStyle: 'medium', timeStyle: 'short' }) : '—';
	}
	function name(b: any) { return rtl ? b.employee_name_ar || b.employee_name_en : b.employee_name_en || b.employee_name_ar; }
	function reason(b: any) { return rtl ? b.reason_ar || b.reason_en : b.reason_en || b.reason_ar; }
	function branchName(b: any) { return rtl ? b.branch_name_ar || b.branch_name_en : b.branch_name_en || b.branch_name_ar; }

	onMount(() => {
		from = dateInRiyadh(layout === 'mobile' ? 2 : 1);
		to = dateInRiyadh(layout === 'mobile' ? 0 : 1);
		refresh();
		timer = setInterval(() => { now = Date.now(); }, 1000);
		poll = setInterval(() => refresh(true), 15000);
		onVisible = () => { if (document.visibilityState === 'visible') refresh(true); };
		onOnline = () => refresh(true);
		document.addEventListener('visibilitychange', onVisible);
		window.addEventListener('online', onOnline);
	});
	onDestroy(() => { if (timer) clearInterval(timer); if (poll) clearInterval(poll); if (onVisible) document.removeEventListener('visibilitychange', onVisible); if (onOnline) window.removeEventListener('online', onOnline); });
</script>

<section class="break-log" class:mobile={layout === 'mobile'} dir={rtl ? 'rtl' : 'ltr'}>
	<div class="filters">
		<label>{rtl ? 'من' : 'From'}<input type="date" bind:value={from} on:change={() => refresh()} /></label>
		<label>{rtl ? 'إلى' : 'To'}<input type="date" bind:value={to} on:change={() => refresh()} /></label>
		<label>{rtl ? 'الحالة' : 'Status'}<select bind:value={status} on:change={() => refresh()}><option value="">{rtl ? 'الكل' : 'All'}</option><option value="open">{rtl ? 'مفتوحة' : 'Open'}</option><option value="closed">{rtl ? 'مغلقة' : 'Closed'}</option></select></label>
		{#if scope === 'all'}
			<label>{rtl ? 'الفرع' : 'Branch'}<select bind:value={branch} on:change={() => refresh()}><option value="">{rtl ? 'كل الفروع' : 'All branches'}</option>{#each branches as b}<option value={String(b.id)}>{rtl ? b.name_ar || b.name_en : b.name_en || b.name_ar}</option>{/each}</select></label>
		{/if}
		<label>{rtl ? 'بحث' : 'Search'}<input type="search" bind:value={search} placeholder={rtl ? 'الاسم أو المعرف أو السبب' : 'Name, ID or reason'} /></label>
	</div>
	<div class="totals"><span>{rtl ? 'مفتوحة' : 'Open'}: {open.length}</span><span>{rtl ? 'مغلقة' : 'Closed'}: {closed.length}</span><span>{rtl ? 'الإجمالي' : 'Total'}: {shown.length}</span></div>
	{#if loading}<p class="message">{rtl ? 'جاري التحميل...' : 'Loading...'}</p>
	{:else if error}<p class="message error" role="alert">{error}</p>
	{:else if shown.length === 0}<p class="message">{rtl ? 'لا توجد استراحات' : 'No breaks found'}</p>
	{:else if layout === 'mobile'}
		<div class="cards">{#each shown as b (b.id)}
			<article class={b.status === 'open' ? 'card open-card' : 'card'}>
				<div class="card-heading"><strong>{name(b)} <small>{b.employee_id}</small></strong><span class:active={b.status === 'open'}>{b.status === 'open' ? (rtl ? 'مفتوحة' : 'Open') : (rtl ? 'مغلقة' : 'Closed')}</span></div>
				<dl><div><dt>{rtl ? 'الفرع' : 'Branch'}</dt><dd>{branchName(b) || '—'}</dd></div><div><dt>{rtl ? 'السبب' : 'Reason'}</dt><dd>{reason(b) || '—'}</dd></div>
					{#if b.reason_note}<div><dt>{rtl ? 'ملاحظة' : 'Note'}</dt><dd>{b.reason_note}</dd></div>{/if}
					<div><dt>{rtl ? 'البداية' : 'Start'}</dt><dd>{timestamp(b.start_time)}</dd></div><div><dt>{rtl ? 'النهاية' : 'End'}</dt><dd>{timestamp(b.end_time)}</dd></div><div><dt>{rtl ? 'المدة' : 'Duration'}</dt><dd>{shownDuration(b, now)}</dd></div></dl>
			</article>
		{/each}</div>
	{:else}
		<div class="table-scroll"><table><thead><tr><th>{rtl ? 'الموظف' : 'Employee'}</th><th>{rtl ? 'المعرف' : 'ID'}</th><th>{rtl ? 'الفرع' : 'Branch'}</th><th>{rtl ? 'السبب' : 'Reason'}</th><th>{rtl ? 'ملاحظة' : 'Note'}</th><th>{rtl ? 'البداية' : 'Start'}</th><th>{rtl ? 'النهاية' : 'End'}</th><th>{rtl ? 'المدة' : 'Duration'}</th><th>{rtl ? 'الحالة' : 'Status'}</th></tr></thead>
			<tbody>{#each shown as b (b.id)}<tr><td>{name(b)}</td><td>{b.employee_id}</td><td>{branchName(b)}</td><td>{reason(b)}</td><td>{b.reason_note || '—'}</td><td>{timestamp(b.start_time)}</td><td>{timestamp(b.end_time)}</td><td>{shownDuration(b, now)}</td><td>{b.status}</td></tr>{/each}</tbody></table></div>
	{/if}
</section>

<style>
	.break-log{display:flex;flex-direction:column;gap:1rem;padding:1rem;min-width:0}.filters{display:flex;flex-wrap:wrap;gap:.65rem}.filters label{display:flex;flex-direction:column;gap:.25rem;font-size:.75rem;font-weight:700;color:#475569;min-width:130px;flex:1}.filters input,.filters select{min-height:44px;padding:.5rem;border:1px solid #cbd5e1;border-radius:.65rem;background:white;color:#0f172a}.totals{display:flex;gap:.5rem;flex-wrap:wrap}.totals span{background:#ecfdf5;border:1px solid #a7f3d0;border-radius:.65rem;padding:.55rem .8rem;font-weight:700}.table-scroll{overflow:auto;max-height:calc(100vh - 360px)}table{width:100%;border-collapse:collapse;white-space:nowrap;background:white}th,td{padding:.7rem;border-bottom:1px solid #e2e8f0;text-align:start}th{position:sticky;top:0;background:#059669;color:white}td{font-size:.82rem}.cards{display:grid;gap:.8rem}.card{background:white;border:1px solid #e2e8f0;border-radius:1rem;padding:1rem;box-shadow:0 4px 12px #0f172a0a}.card-heading{display:flex;justify-content:space-between;gap:.75rem}.card-heading small{display:block;color:#64748b;font-weight:400}.card-heading span{background:#e2e8f0;padding:.25rem .6rem;border-radius:999px;font-size:.75rem}.card-heading span.active{background:#d1fae5;color:#065f46}dl{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.65rem;margin:.8rem 0 0}dt{font-size:.7rem;color:#64748b}dd{margin:0;overflow-wrap:anywhere;font-size:.85rem}.message{text-align:center;padding:2rem}.error{color:#b91c1c}.mobile{padding:.55rem .65rem;gap:.55rem}.mobile .filters{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.38rem .5rem}.mobile .filters label{min-width:0;gap:.1rem;font-size:.69rem;line-height:1.15}.mobile .filters label:last-child{grid-column:1/-1}.mobile .filters input,.mobile .filters select{width:100%;min-width:0;min-height:40px;padding:.35rem .5rem;border-radius:.55rem;font-size:.86rem}.mobile .totals{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:.35rem}.mobile .totals span{min-width:0;text-align:center;font-size:.75rem;line-height:1.2;padding:.38rem .2rem;border-radius:.55rem}.mobile .cards{gap:.45rem}.mobile .card{padding:.6rem .7rem;border-radius:.8rem;box-shadow:0 2px 8px #0f172a08}.mobile .card-heading{align-items:center;gap:.4rem;line-height:1.2}.mobile .card-heading strong{font-size:.88rem}.mobile .card-heading small{display:inline;margin-inline-start:.25rem;font-size:.72rem;white-space:nowrap}.mobile .card-heading span{flex:none;padding:.2rem .5rem;font-size:.69rem}.mobile dl{gap:.38rem .55rem;margin:.48rem 0 0}.mobile dt{font-size:.67rem;line-height:1.15}.mobile dd{font-size:.8rem;line-height:1.25}
	.mobile{flex:1;min-height:0;overflow:hidden}.mobile .cards{flex:1;min-height:0;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;align-content:start;padding-bottom:.3rem}.mobile .card-heading strong{flex:1;min-width:0;overflow-wrap:anywhere}.mobile .card.open-card{background:#fff1f2;border-color:#fda4af}.mobile .open-card .card-heading span.active{background:#ffe4e6;color:#9f1239}
</style>
