<script lang="ts">
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { addDays, breakShiftDate, shiftTimeLabel, type ShiftSchedules, type ShiftSlot } from '$lib/utils/breakShiftDate';
	import { loadBreakRegisterData } from '$lib/utils/breakRegisterApi';

	export let layout: 'desktop' | 'mobile' = 'desktop';
	let from = '';
	let to = '';
	let branch = '';
	let search = '';
	let branches: any[] = [];
	let scope = 'own';
	let rows: any[] = [];
	let schedules: ShiftSchedules = { regular: [], weekday: [], dateWise: [] };
	let loading = true;
	let error = '';
	$: rtl = $locale === 'ar';
	$: filtered = rows.filter(row => {
		const term = search.trim().toLowerCase();
		return !term || [row.employee_id, row.name_en, row.name_ar].some(value => String(value || '').toLowerCase().includes(term));
	});
	function today(daysAgo = 0) { return new Date(Date.now() + 3 * 3600000 - daysAgo * 86400000).toISOString().slice(0, 10); }
	function formatDuration(seconds: number) {
		const whole = Math.max(0, Math.floor(Number(seconds) || 0));
		const h = Math.floor(whole / 3600), m = Math.floor(whole % 3600 / 60), s = whole % 60;
		const minutes = h ? `${h}h ${m}m` : `${m}m`;
		return s ? `${minutes} ${s}s` : minutes;
	}
	function durationBand(seconds: number): 'green' | 'orange' | 'red' {
		const total = Number(seconds) || 0;
		return total < 35 * 60 ? 'green' : total <= 40 * 60 ? 'orange' : 'red';
	}
	function bandEmoji(seconds: number): string {
		return durationBand(seconds) === 'green' ? '✅' : durationBand(seconds) === 'orange' ? '⚠️' : '🚨';
	}
	function bandLabel(seconds: number): string {
		const band = durationBand(seconds);
		return rtl
			? band === 'green' ? 'أقل من ٣٥ دقيقة' : band === 'orange' ? 'من ٣٥ إلى ٤٠ دقيقة' : 'أكثر من ٤٠ دقيقة'
			: band === 'green' ? 'Under 35 minutes' : band === 'orange' ? '35 to 40 minutes' : 'Over 40 minutes';
	}
	function branchName(row: any) {
		const found = branches.find(b => Number(b.id) === Number(row.branch_id));
		return rtl ? found?.name_ar || found?.name_en || '—' : found?.name_en || found?.name_ar || '—';
	}
	async function slots(versionTable: string, slotTable: string, ids: string[]): Promise<ShiftSlot[]> {
		const versions: any[] = [];
		for (let i = 0; i < ids.length; i += 100) {
			let offset = 0;
			while (true) {
				const { data, error } = await supabase.from(versionTable).select('*').in('employee_id', ids.slice(i, i + 100))
					.lte('date_from', addDays(to, 1)).or(`date_to.is.null,date_to.gte.${addDays(from, -1)}`).order('id').range(offset, offset + 999);
				if (error) throw error;
				versions.push(...(data || []));
				if (!data || data.length < 1000) break;
				offset += 1000;
			}
		}
		const result: ShiftSlot[] = [];
		for (let i = 0; i < versions.length; i += 100) {
			const batch = versions.slice(i, i + 100);
			const { data, error } = await supabase.from(slotTable).select('version_id,shift_start_time,shift_end_time,shift_end_buffer,is_shift_overlapping_next_day').in('version_id', batch.map(v => v.id));
			if (error) throw error;
			const versionsById = new Map(batch.map(v => [v.id, v]));
			for (const slot of data || []) {
				const version = versionsById.get(slot.version_id);
				if (version) result.push({ ...version, ...slot });
			}
		}
		return result;
	}
	async function refresh() {
		if (!from || !to || from > to) { error = rtl ? 'نطاق التاريخ غير صالح' : 'Invalid date range'; return; }
		loading = true;
		error = '';
		try {
			const [scheduleData, breakData] = await Promise.all([
				loadBreakRegisterData('schedule', { from, to, branch }, layout),
				loadBreakRegisterData('logs', { from: addDays(from, -1), to: addDays(to, 1), branch }, layout)
			]);
			branches = breakData.branches || [];
			scope = breakData.scope || 'own';
			const scheduled = (scheduleData.rows || []).filter((row: any) => row.scheduled);
			const ids = [...new Set([...(scheduleData.rows || []).map((row: any) => String(row.employee_id)), ...(breakData.breaks || []).map((b: any) => String(b.employee_id))])] as string[];
			const [regular, weekday, dateWise] = await Promise.all([
				slots('hr_regular_shift_versions', 'hr_regular_shift_slots', ids),
				slots('hr_special_shift_weekday_versions', 'hr_special_shift_weekday_slots', ids),
				slots('hr_special_shift_date_wise_versions', 'hr_special_shift_date_wise_slots', ids)
			]);
			schedules = { regular, weekday, dateWise };
			const mapped = new Map<string, any>();
			for (const emp of scheduled) mapped.set(`${emp.employee_id}__${emp.shift_date}`, {
				date: emp.shift_date, employee_id: emp.employee_id, name_en: emp.name_en, name_ar: emp.name_ar,
				branch_id: emp.branch_id, total_seconds: 0, break_count: 0
			});
			for (const b of breakData.breaks || []) {
				const date = breakShiftDate(String(b.employee_id), b.start_time, schedules);
				const target = mapped.get(`${b.employee_id}__${date}`);
				if (target) { target.break_count++; target.total_seconds += Number(b.duration_seconds) || 0; }
			}
			rows = [...mapped.values()].sort((a, b) => a.date.localeCompare(b.date) || b.total_seconds - a.total_seconds);
		} catch (e) {
			rows = [];
			error = e instanceof Error ? e.message : 'Could not load total summary';
		} finally { loading = false; }
	}
	onMount(() => { from = today(1); to = from; refresh(); });
</script>

<section class="summary" class:mobile={layout === 'mobile'} dir={rtl ? 'rtl' : 'ltr'}>
	<div class="filters"><button on:click={() => { from = today(); to = from; refresh(); }}>{rtl ? 'اليوم' : 'Today'}</button><button on:click={() => { from = today(1); to = from; refresh(); }}>{rtl ? 'أمس' : 'Yesterday'}</button>
		<label>{rtl ? 'من' : 'From'}<input type="date" bind:value={from} on:change={refresh} /></label><label>{rtl ? 'إلى' : 'To'}<input type="date" bind:value={to} on:change={refresh} /></label>
		{#if scope === 'all'}<label>{rtl ? 'الفرع' : 'Branch'}<select bind:value={branch} on:change={refresh}><option value="">{rtl ? 'كل الفروع' : 'All branches'}</option>{#each branches as b}<option value={String(b.id)}>{rtl ? b.name_ar || b.name_en : b.name_en || b.name_ar}</option>{/each}</select></label>{/if}
		<label>{rtl ? 'بحث' : 'Search'}<input type="search" bind:value={search} placeholder={rtl ? 'موظف أو معرف' : 'Employee or ID'} /></label>
	</div>
	{#if loading}<p>{rtl ? 'جاري التحميل...' : 'Loading...'}</p>{:else if error}<p role="alert" class="error">{error}</p>{:else if !filtered.length}<p>{rtl ? 'لا توجد بيانات' : 'No data available'}</p>
	{:else if layout === 'mobile'}<div class="cards">{#each filtered as row}<article class={'band-' + durationBand(row.total_seconds)}><strong>{rtl ? row.name_ar || row.name_en : row.name_en || row.name_ar}</strong><small>{row.employee_id} · {row.date} · {branchName(row)}</small><dl><div><dt>{rtl ? 'وقت الوردية' : 'Shift time'}</dt><dd>{shiftTimeLabel(row.employee_id, row.date, schedules)}</dd></div><div><dt>{rtl ? 'إجمالي الاستراحة' : 'Total break'}</dt><dd><span class="band-indicator" role="img" aria-label={bandLabel(row.total_seconds)} title={bandLabel(row.total_seconds)}>{bandEmoji(row.total_seconds)}</span> {formatDuration(row.total_seconds)}</dd></div><div><dt>{rtl ? 'المرات' : 'Breaks'}</dt><dd>{row.break_count}</dd></div></dl></article>{/each}</div>
	{:else}<div class="table-scroll"><table><thead><tr><th>{rtl ? 'التاريخ' : 'Date'}</th><th>{rtl ? 'الموظف' : 'Employee'}</th><th>{rtl ? 'المعرف' : 'ID'}</th><th>{rtl ? 'الفرع' : 'Branch'}</th><th>{rtl ? 'وقت الوردية' : 'Shift time'}</th><th>{rtl ? 'إجمالي الاستراحة' : 'Total break'}</th><th>{rtl ? 'المرات' : 'Breaks'}</th></tr></thead><tbody>{#each filtered as row}<tr><td>{row.date}</td><td>{rtl ? row.name_ar || row.name_en : row.name_en || row.name_ar}</td><td>{row.employee_id}</td><td>{branchName(row)}</td><td>{shiftTimeLabel(row.employee_id, row.date, schedules)}</td><td class={'total-break band-' + durationBand(row.total_seconds)}><span class="band-indicator" role="img" aria-label={bandLabel(row.total_seconds)} title={bandLabel(row.total_seconds)}>{bandEmoji(row.total_seconds)}</span> {formatDuration(row.total_seconds)}</td><td>{row.break_count}</td></tr>{/each}</tbody></table></div>{/if}
	<div class="footer">{rtl ? 'السجلات' : 'Records'}: {filtered.length}</div>
</section>

<style>
	.summary{padding:1rem;display:flex;flex-direction:column;gap:1rem;min-width:0}.filters{display:flex;flex-wrap:wrap;gap:.65rem}.filters label{display:flex;flex-direction:column;gap:.25rem;flex:1;min-width:130px;font-size:.75rem;font-weight:700;color:#475569}.filters button,.filters input,.filters select{min-height:44px;border:1px solid #cbd5e1;border-radius:.65rem;background:white;color:#0f172a;padding:.5rem}.filters button{align-self:end}.table-scroll{overflow:auto;max-height:calc(100vh - 360px)}table{border-collapse:collapse;width:100%;white-space:nowrap;background:white}th,td{text-align:start;padding:.7rem;border-bottom:1px solid #e2e8f0;font-size:.82rem}th{background:#7c3aed;color:white;position:sticky;top:0}.cards{display:grid;gap:.8rem}.cards article{background:white;border:1px solid #e2e8f0;border-radius:1rem;padding:1rem}.cards small{display:block;color:#64748b}.cards dl{display:grid;grid-template-columns:repeat(2,1fr);gap:.6rem;margin:.8rem 0 0}.cards dt{color:#64748b;font-size:.7rem}.cards dd{margin:0}.error{color:#b91c1c}.footer{font-size:.75rem;color:#64748b}.mobile{padding:.55rem .65rem;gap:.55rem}.mobile .filters{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.38rem .5rem}.mobile .filters button{min-width:0;min-height:40px;padding:.3rem .45rem;border-radius:.55rem;font-size:.82rem}.mobile .filters label{min-width:0;gap:.1rem;font-size:.69rem;line-height:1.15}.mobile .filters label:last-child:nth-child(odd){grid-column:1/-1}.mobile .filters input,.mobile .filters select{width:100%;min-width:0;min-height:40px;padding:.35rem .5rem;border-radius:.55rem;font-size:.86rem}.mobile .cards{gap:.45rem}.mobile .cards article{padding:.6rem .7rem;border-radius:.8rem}.mobile .cards strong{font-size:.88rem;line-height:1.2}.mobile .cards small{font-size:.7rem;line-height:1.25;margin-top:.12rem}.mobile .cards dl{gap:.32rem .55rem;margin:.45rem 0 0}.mobile .cards dl>div:first-child{grid-column:1/-1}.mobile .cards dt{font-size:.67rem;line-height:1.15}.mobile .cards dd{font-size:.8rem;line-height:1.2}.mobile .footer{font-size:.7rem}
	.mobile{flex:1;min-height:0;overflow:hidden}.mobile .cards{flex:1;min-height:0;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;align-content:start;padding-bottom:.3rem}
	.mobile .cards article.band-green,.total-break.band-green{background:#ecfdf5;color:#065f46}.mobile .cards article.band-orange,.total-break.band-orange{background:#fff7ed;color:#9a3412}.mobile .cards article.band-red,.total-break.band-red{background:#fff1f2;color:#9f1239}.mobile .cards article.band-green{border-color:#86efac}.mobile .cards article.band-orange{border-color:#fdba74}.mobile .cards article.band-red{border-color:#fda4af}.mobile .cards article[class*='band-'] small,.mobile .cards article[class*='band-'] dt{color:#475569}
</style>
