<script lang="ts">
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { addDays, shiftTimeLabel, type ShiftSchedules, type ShiftSlot } from '$lib/utils/breakShiftDate';
	import { loadBreakRegisterData } from '$lib/utils/breakRegisterApi';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import EmployeeAnalysisWindow from '$lib/components/desktop-interface/master/hr/EmployeeAnalysisWindow.svelte';

	export let layout: 'desktop' | 'mobile' = 'desktop';
	let from = '';
	let to = '';
	let branch = '';
	let search = '';
	let branches: any[] = [];
	let scope = 'own';
	let rows: any[] = [];
	let schedules: ShiftSchedules = { regular: [], weekday: [], dateWise: [] };
	let expanded = new Set<string>();
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
	function rowKey(row: any) { return `${row.employee_id}__${row.date}`; }
	function toggleRow(row: any) {
		const next = new Set(expanded);
		const key = rowKey(row);
		next.has(key) ? next.delete(key) : next.add(key);
		expanded = next;
	}
	function timeLabel(value: string | null) {
		if (!value) return '—';
		return new Intl.DateTimeFormat(rtl ? 'ar-SA' : 'en-US', {
			timeZone: 'Asia/Riyadh', hour: 'numeric', minute: '2-digit', second: '2-digit'
		}).format(new Date(value));
	}
	function reasonLabel(item: any) {
		return rtl ? item.reason_ar || item.reason_en || '—' : item.reason_en || item.reason_ar || '—';
	}
	function nonWorkingStatus(row: any): string | null {
		if (row.break_count > 0 || !row.attendance_status || row.attendance_status === 'Worked') return null;
		return row.attendance_status;
	}
	function attendanceLabel(status: string | null): string {
		if (!status) return '—';
		if (!rtl) return status;
		if (status === 'Absent') return 'غائب';
		if (status === 'Official Day Off') return 'يوم إجازة رسمي';
		if (status === 'Official Holiday') return 'عطلة رسمية';
		if (status === 'Pending Approval') return 'بانتظار الموافقة';
		if (status.startsWith('Approved Leave')) return status.includes('Deductible') ? 'إجازة معتمدة (مخصومة)' : 'إجازة معتمدة';
		return status;
	}
	function openEmployeeAttendanceAnalysis(row: any) {
		const employeeBranch = branches.find(b => Number(b.id) === Number(row.branch_id));
		const analysisWindowId = `employee-analysis-${row.employee_id}-${row.date}-${Date.now()}`;
		const requestedEndDate = addDays(row.date, 2);
		const cappedEndDate = requestedEndDate > today() ? today() : requestedEndDate;
		openWindow({
			id: analysisWindowId,
			title: `${rtl ? 'تحليل الموظف' : 'Employee Analysis'}: ${row.employee_id}`,
			component: EmployeeAnalysisWindow,
			props: {
				employee: {
					id: row.employee_id,
					name_en: row.name_en || '',
					name_ar: row.name_ar || '',
					current_branch_id: row.branch_id,
					branch_name_en: employeeBranch?.name_en || '',
					branch_name_ar: employeeBranch?.name_ar || ''
				},
				windowId: analysisWindowId,
				initialStartDate: addDays(row.date, -3),
				initialEndDate: cappedEndDate
			},
			icon: '🔍',
			size: { width: 1000, height: 700 },
			position: { x: 100 + Math.random() * 100, y: 100 + Math.random() * 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
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
			const summaryData = await loadBreakRegisterData('summary', { from, to, branch }, layout);
			branches = summaryData.branches || [];
			scope = summaryData.scope || 'own';
			const ids = [...new Set((summaryData.employees || []).map((row: any) => String(row.employee_id)))] as string[];
			const [regular, weekday, dateWise] = await Promise.all([
				slots('hr_regular_shift_versions', 'hr_regular_shift_slots', ids),
				slots('hr_special_shift_weekday_versions', 'hr_special_shift_weekday_slots', ids),
				slots('hr_special_shift_date_wise_versions', 'hr_special_shift_date_wise_slots', ids)
			]);
			schedules = { regular, weekday, dateWise };
			rows = (summaryData.employees || []).flatMap((emp: any) => (emp.days || []).map((day: any) => ({
				date: day.date, employee_id: emp.employee_id, name_en: emp.employee_name_en, name_ar: emp.employee_name_ar,
				branch_id: emp.branch_id, total_seconds: Number(day.total_seconds) || 0,
				break_count: Number(day.break_count) || 0, breaks: day.breaks || [], attendance_status: day.attendance_status || null
			}))).sort((a: any, b: any) => {
				const aAtEnd = a.attendance_status === 'Absent' || a.attendance_status === 'Pending Approval';
				const bAtEnd = b.attendance_status === 'Absent' || b.attendance_status === 'Pending Approval';
				return Number(aAtEnd) - Number(bAtEnd)
					|| a.date.localeCompare(b.date)
					|| b.total_seconds - a.total_seconds;
			});
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
	{:else if layout === 'mobile'}
		<div class="cards">{#each filtered as row, index}
			<article class={'band-' + durationBand(row.total_seconds)}>
				<button class="row-toggle" type="button" aria-expanded={expanded.has(rowKey(row))} on:click={() => toggleRow(row)}>
					<span><strong>#{index + 1} · {rtl ? row.name_ar || row.name_en : row.name_en || row.name_ar}</strong><small>{row.employee_id} · {row.date} · {branchName(row)}</small></span>
					<span>{expanded.has(rowKey(row)) ? '▴' : '▾'}</span>
				</button>
				<dl><div><dt>{rtl ? 'وقت الوردية' : 'Shift time'}</dt><dd>{shiftTimeLabel(row.employee_id, row.date, schedules)}</dd></div><div><dt>{rtl ? 'إجمالي الاستراحة' : 'Total break'}</dt><dd>{#if nonWorkingStatus(row)}<span class="attendance-status">{attendanceLabel(nonWorkingStatus(row))}</span>{:else}<span class="band-indicator" role="img" aria-label={bandLabel(row.total_seconds)} title={bandLabel(row.total_seconds)}>{bandEmoji(row.total_seconds)}</span> {formatDuration(row.total_seconds)}{/if}</dd></div><div><dt>{rtl ? 'المرات' : 'Breaks'}</dt><dd>{nonWorkingStatus(row) ? '—' : row.break_count}</dd></div></dl>
				{#if expanded.has(rowKey(row))}<div class="break-details">{#each row.breaks as item, index}<div class="break-detail"><b>#{index + 1} · {reasonLabel(item)}</b><span>{timeLabel(item.start_time)} → {timeLabel(item.end_time)}</span><strong>{formatDuration(item.duration_seconds)}</strong>{#if item.reason_note}<small>{item.reason_note}</small>{/if}</div>{:else}<p>{nonWorkingStatus(row) ? attendanceLabel(nonWorkingStatus(row)) : (rtl ? 'لم تُسجل استراحة' : 'No break logged')}</p>{/each}</div>{/if}
			</article>
		{/each}</div>
	{:else}
		<div class="table-scroll"><table><thead><tr><th>{rtl ? 'م' : 'No.'}</th><th>{rtl ? 'التاريخ' : 'Date'}</th><th>{rtl ? 'الموظف' : 'Employee'}</th><th>{rtl ? 'المعرف' : 'ID'}</th><th>{rtl ? 'الفرع' : 'Branch'}</th><th>{rtl ? 'وقت الوردية' : 'Shift time'}</th><th>{rtl ? 'إجمالي الاستراحة' : 'Total break'}</th><th>{rtl ? 'المرات' : 'Breaks'}</th><th></th></tr></thead><tbody>{#each filtered as row, index}
			<tr class="summary-row" on:click={() => toggleRow(row)}><td class="serial-number">{index + 1}</td><td>{row.date}</td><td>{rtl ? row.name_ar || row.name_en : row.name_en || row.name_ar}</td><td>{row.employee_id}</td><td>{branchName(row)}</td><td>{shiftTimeLabel(row.employee_id, row.date, schedules)}</td>{#if nonWorkingStatus(row)}<td class="attendance-status-cell"><span class="attendance-status">{attendanceLabel(nonWorkingStatus(row))}</span></td><td>—</td>{:else}<td class={'total-break band-' + durationBand(row.total_seconds)}><span class="band-indicator" role="img" aria-label={bandLabel(row.total_seconds)} title={bandLabel(row.total_seconds)}>{bandEmoji(row.total_seconds)}</span> {formatDuration(row.total_seconds)}</td><td>{row.break_count}</td>{/if}<td><div class="row-actions"><button class="analysis-button" type="button" aria-label={rtl ? 'عرض تحليل حضور الموظف' : 'View employee attendance analysis'} title={rtl ? 'عرض تحليل الحضور: ٣ أيام قبل ويومان بعد' : 'View attendance analysis: 3 days before and 2 days after'} on:click|stopPropagation={() => openEmployeeAttendanceAnalysis(row)}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.46 12C3.73 7.94 7.52 5 12 5s8.27 2.94 9.54 7c-1.27 4.06-5.06 7-9.54 7S3.73 16.06 2.46 12Z"/><circle cx="12" cy="12" r="3"/></svg></button><button class="expand-button" type="button" aria-label={rtl ? 'عرض تفاصيل الاستراحات' : 'Show break calculation details'} aria-expanded={expanded.has(rowKey(row))}>{expanded.has(rowKey(row)) ? '▴' : '▾'}</button></div></td></tr>
			{#if expanded.has(rowKey(row))}<tr class="details-row"><td colspan="9"><div class="break-details">{#each row.breaks as item, breakIndex}<div class="break-detail"><b>#{breakIndex + 1} · {reasonLabel(item)}</b><span>{timeLabel(item.start_time)} → {timeLabel(item.end_time)}</span><strong>{formatDuration(item.duration_seconds)}</strong>{#if item.reason_note}<small>{item.reason_note}</small>{/if}</div>{:else}<p>{rtl ? 'لم تُسجل استراحة' : 'No break logged'}</p>{/each}<div class="calculation-total"><span>{rtl ? 'المجموع' : 'Calculated total'}</span><strong>{row.breaks.map((item: any) => Number(item.duration_seconds) || 0).reduce((sum: number, value: number) => sum + value, 0)}s = {formatDuration(row.total_seconds)}</strong></div></div></td></tr>{/if}
		{/each}</tbody></table></div>{/if}
	<div class="footer">{rtl ? 'السجلات' : 'Records'}: {filtered.length}</div>
</section>

<style>
	.summary{padding:1rem;display:flex;flex-direction:column;gap:1rem;min-width:0}.filters{display:flex;flex-wrap:wrap;gap:.65rem}.filters label{display:flex;flex-direction:column;gap:.25rem;flex:1;min-width:130px;font-size:.75rem;font-weight:700;color:#475569}.filters button,.filters input,.filters select{min-height:44px;border:1px solid #cbd5e1;border-radius:.65rem;background:white;color:#0f172a;padding:.5rem}.filters button{align-self:end}.table-scroll{overflow:auto;max-height:calc(100vh - 360px)}table{border-collapse:collapse;width:100%;white-space:nowrap;background:white}th,td{text-align:start;padding:.7rem;border-bottom:1px solid #e2e8f0;border-inline-end:1px solid #e2e8f0;font-size:.82rem}tr>th:last-child,tr>td:last-child{border-inline-end:0}th{background:#7c3aed;color:white;position:sticky;top:0}.cards{display:grid;gap:.8rem}.cards article{background:white;border:1px solid #e2e8f0;border-radius:1rem;padding:1rem}.cards small{display:block;color:#64748b}.cards dl{display:grid;grid-template-columns:repeat(2,1fr);gap:.6rem;margin:.8rem 0 0}.cards dt{color:#64748b;font-size:.7rem}.cards dd{margin:0}.error{color:#b91c1c}.footer{font-size:.75rem;color:#64748b}.mobile{padding:.55rem .65rem;gap:.55rem}.mobile .filters{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.38rem .5rem}.mobile .filters button{min-width:0;min-height:40px;padding:.3rem .45rem;border-radius:.55rem;font-size:.82rem}.mobile .filters label{min-width:0;gap:.1rem;font-size:.69rem;line-height:1.15}.mobile .filters label:last-child:nth-child(odd){grid-column:1/-1}.mobile .filters input,.mobile .filters select{width:100%;min-width:0;min-height:40px;padding:.35rem .5rem;border-radius:.55rem;font-size:.86rem}.mobile .cards{gap:.45rem}.mobile .cards article{padding:.6rem .7rem;border-radius:.8rem}.mobile .cards strong{font-size:.88rem;line-height:1.2}.mobile .cards small{font-size:.7rem;line-height:1.25;margin-top:.12rem}.mobile .cards dl{gap:.32rem .55rem;margin:.45rem 0 0}.mobile .cards dl>div:first-child{grid-column:1/-1}.mobile .cards dt{font-size:.67rem;line-height:1.15}.mobile .cards dd{font-size:.8rem;line-height:1.2}.mobile .footer{font-size:.7rem}
	.mobile{flex:1;min-height:0;overflow:hidden}.mobile .cards{flex:1;min-height:0;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;align-content:start;padding-bottom:.3rem}
	.mobile .cards article.band-green,.total-break.band-green{background:#ecfdf5;color:#065f46}.mobile .cards article.band-orange,.total-break.band-orange{background:#fff7ed;color:#9a3412}.mobile .cards article.band-red,.total-break.band-red{background:#fff1f2;color:#9f1239}.mobile .cards article.band-green{border-color:#86efac}.mobile .cards article.band-orange{border-color:#fdba74}.mobile .cards article.band-red{border-color:#fda4af}.mobile .cards article[class*='band-'] small,.mobile .cards article[class*='band-'] dt{color:#475569}
	.summary-row{cursor:pointer}.summary-row:hover{background:#f5f3ff}.row-actions{display:flex;align-items:center;justify-content:center;gap:.35rem}.expand-button,.analysis-button{width:28px;height:28px;border:1px solid #c4b5fd;border-radius:7px;background:#f5f3ff;color:#6d28d9;font-weight:900;cursor:pointer}.expand-button{font-size:1rem}.analysis-button{display:inline-flex;align-items:center;justify-content:center}.analysis-button svg{width:17px;height:17px;fill:none;stroke:currentColor;stroke-width:2}.details-row>td{padding:.75rem 1rem;background:#fafafa}.break-details{display:grid;gap:.45rem}.break-detail{display:grid;grid-template-columns:minmax(150px,1fr) minmax(190px,1fr) auto;align-items:center;gap:.75rem;padding:.6rem .75rem;border:1px solid #e2e8f0;border-radius:.65rem;background:white;color:#334155}.break-detail b{color:#5b21b6}.break-detail strong{font-family:monospace}.break-detail small{grid-column:1/-1;color:#64748b}.calculation-total{display:flex;justify-content:flex-end;gap:1rem;padding:.65rem .75rem;border-top:2px solid #c4b5fd;color:#4c1d95}.row-toggle{display:flex;width:100%;align-items:center;justify-content:space-between;gap:.5rem;padding:0;border:0;background:transparent;color:inherit;text-align:start;cursor:pointer}.row-toggle>span:first-child{min-width:0}.mobile .break-details{margin-top:.6rem}.mobile .break-detail{grid-template-columns:1fr auto;font-size:.75rem}.mobile .break-detail span{grid-column:1/-1}.mobile .break-detail small{grid-column:1/-1}
	.attendance-status-cell{background:#f1f5f9}.attendance-status{display:inline-flex;align-items:center;padding:.28rem .65rem;border-radius:999px;background:#e2e8f0;color:#334155;font-size:.75rem;font-weight:800;white-space:nowrap}
	.serial-number{text-align:center;font-weight:800;color:#64748b;font-variant-numeric:tabular-nums}
</style>
