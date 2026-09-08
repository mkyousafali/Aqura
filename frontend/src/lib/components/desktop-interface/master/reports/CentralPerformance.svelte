<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	let supabase: any = null;
	let loading = false;
	let error = '';
	let selectedDate = '';
	let report: any = null;

	// Collapsible sections — all collapsed by default
	let open: Record<string, boolean> = {
		sales: false, receivedBills: false, paidBills: false,
		expenses: false, cashier: false, tasks: false,
		attendance: false, incidents: false,
	};
	function toggle(key: string) { open[key] = !open[key]; open = open; }

	const fmt = (n: number) => (n || 0).toLocaleString('en-US', { maximumFractionDigits: 0 });
	$: isArabic = $locale === 'ar';
	$: cur = isArabic ? 'ر.س' : 'SAR';

	function getYesterday() {
		const now = new Date(new Date().getTime() + 3 * 60 * 60 * 1000);
		now.setDate(now.getDate() - 1);
		const pad = (n: number) => String(n).padStart(2, '0');
		return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
	}

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		selectedDate = getYesterday();
		await loadReport();
	});

	async function loadReport() {
		if (!supabase) return;
		loading = true; error = ''; report = null;
		try {
			const { data: sessionData } = await supabase.auth.getSession();
			const token = sessionData.session?.access_token;
			const res = await fetch(
				`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/daily-report`,
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
					body: JSON.stringify({ date: selectedDate }),
				}
			);
			const json = await res.json();
			if (json.error) throw new Error(json.error);
			report = json;
		} catch (e: any) { error = e.message; }
		loading = false;
	}

	function diffColor(n: number) {
		if (n > 0) return '#16a34a';
		if (n < 0) return '#dc2626';
		return '#6b7280';
	}
	function diffSign(n: number) { return n > 0 ? `+${fmt(n)}` : fmt(n); }

	$: salesTotal      = report?.sales?.reduce((a: number, s: any) => a + (s.net_amount || 0), 0) ?? 0;
	$: receivedTotal   = report?.receivedBills?.reduce((a: number, g: any) => a + (g.subtotal || 0), 0) ?? 0;
	$: paidTotal       = report?.paidBills?.reduce((a: number, b: any) => a + (b.amount || 0), 0) ?? 0;
	$: expensesTotal   = report?.paidExpenses?.filter((e: any) => (e.amount || 0) > 0).reduce((a: number, e: any) => a + (e.amount || 0), 0) ?? 0;
	$: attendanceTotal = report?.attendance?.reduce((a: number, x: any) => a + (x.total || 0), 0) ?? 0;
	$: incidentsCount  = report?.incidents?.length ?? 0;
</script>

<div class="cp-wrap">
	<!-- Animated gradient background -->
	<div class="cp-bg"></div>

	<div class="cp-container">
		<!-- ── Header ── -->
		<div class="cp-header">
			<div class="cp-title">
				<div class="cp-title-icon">📊</div>
				<div>
					<h2>{isArabic ? 'الأداء المركزي' : 'Central Performance'}</h2>
					<p class="cp-subtitle">{isArabic ? 'تقرير يومي شامل' : 'Daily Operations Report'}</p>
				</div>
			</div>
			<div class="cp-controls">
				<input type="date" class="cp-date-input" bind:value={selectedDate} on:change={loadReport} />
				<button class="cp-refresh-btn" on:click={loadReport} disabled={loading}>
					<span class:spin={loading}>🔄</span>
					{isArabic ? 'تحديث' : 'Refresh'}
				</button>
			</div>
		</div>

		{#if loading}
			<div class="cp-loading">
				<div class="cp-spinner-ring"></div>
				<p>{isArabic ? 'جارٍ تحميل التقرير...' : 'Loading report...'}</p>
			</div>
		{:else if error}
			<div class="glass-section cp-error-card">⚠️ {error}</div>
		{:else if report}

			<!-- ══ SALES ══ -->
			{@const salesBranches = report.sales?.length ?? 0}
			<div class="glass-section" class:expanded={open.sales}>
				<button class="section-header" on:click={() => toggle('sales')}>
					<div class="sh-left">
						<span class="sh-icon green">💰</span>
						<span class="sh-label">{isArabic ? 'المبيعات' : 'Sales'}</span>
						<span class="sh-chip green">{salesBranches} {isArabic ? 'فرع' : 'branches'}</span>
					</div>
					<div class="sh-right">
						<span class="sh-value">{fmt(salesTotal)} {cur}</span>
						<span class="sh-arrow" class:rotated={open.sales}>›</span>
					</div>
				</button>
				{#if open.sales}
					<div class="section-body">
						<div class="card-grid">
							{#each (report.sales || []) as s}
								<div class="data-card green-card">
									<div class="dc-label">{isArabic ? s.branch_name_ar : s.branch_name_en}</div>
									<div class="dc-value">{fmt(s.net_amount)}<span class="dc-cur"> {cur}</span></div>
									<div class="dc-sub">{s.net_bills} {isArabic ? 'فاتورة' : 'bills'} · {isArabic ? 'مرتجع' : 'ret.'} {fmt(s.return_amount)}</div>
								</div>
							{/each}
							{#if salesBranches > 1}
								<div class="data-card total-card">
									<div class="dc-label">{isArabic ? 'الإجمالي' : 'Grand Total'}</div>
									<div class="dc-value">{fmt(salesTotal)}<span class="dc-cur"> {cur}</span></div>
									<div class="dc-sub">{report.sales.reduce((a: number, s: any) => a + (s.net_bills || 0), 0)} {isArabic ? 'فاتورة' : 'bills'}</div>
								</div>
							{/if}
						</div>
					</div>
				{/if}
			</div>

			<!-- ══ RECEIVED BILLS ══ -->
			{@const rbCount = report.receivedBills?.reduce((a: number, g: any) => a + (g.count || 0), 0) ?? 0}
			<div class="glass-section" class:expanded={open.receivedBills}>
				<button class="section-header" on:click={() => toggle('receivedBills')}>
					<div class="sh-left">
						<span class="sh-icon orange">📥</span>
						<span class="sh-label">{isArabic ? 'الفواتير المستلمة' : 'Bills Received'}</span>
						<span class="sh-chip orange">{rbCount} {isArabic ? 'فاتورة' : 'bills'}</span>
					</div>
					<div class="sh-right">
						<span class="sh-value">{fmt(receivedTotal)} {cur}</span>
						<span class="sh-arrow" class:rotated={open.receivedBills}>›</span>
					</div>
				</button>
				{#if open.receivedBills}
					<div class="section-body">
						<table class="g-table">
							<thead><tr>
								<th>{isArabic ? 'الفرع' : 'Branch'}</th>
								<th>{isArabic ? 'عدد' : 'Bills'}</th>
								<th>{isArabic ? 'الإجمالي' : 'Total'}</th>
							</tr></thead>
							<tbody>
								{#each (report.receivedBills || []) as g}
									<tr>
										<td>{isArabic ? g.branch_name_ar : g.branch_name_en}</td>
										<td class="tc">{g.count}</td>
										<td class="tr">{fmt(g.subtotal)} {cur}</td>
									</tr>
								{/each}
								<tr class="total-row">
									<td>{isArabic ? 'الإجمالي' : 'Total'}</td>
									<td class="tc">{rbCount}</td>
									<td class="tr">{fmt(receivedTotal)} {cur}</td>
								</tr>
							</tbody>
						</table>
					</div>
				{/if}
			</div>

			<!-- ══ PAID BILLS ══ -->
			{@const pbCount = report.paidBills?.length ?? 0}
			<div class="glass-section" class:expanded={open.paidBills}>
				<button class="section-header" on:click={() => toggle('paidBills')}>
					<div class="sh-left">
						<span class="sh-icon green">✅</span>
						<span class="sh-label">{isArabic ? 'الفواتير المدفوعة' : 'Bills Paid'}</span>
						<span class="sh-chip green">{pbCount} {isArabic ? 'فاتورة' : 'bills'}</span>
					</div>
					<div class="sh-right">
						<span class="sh-value">{fmt(paidTotal)} {cur}</span>
						<span class="sh-arrow" class:rotated={open.paidBills}>›</span>
					</div>
				</button>
				{#if open.paidBills}
					<div class="section-body">
						<table class="g-table">
							<thead><tr>
								<th>{isArabic ? 'المورد' : 'Vendor'}</th>
								<th>{isArabic ? 'الفرع' : 'Branch'}</th>
								<th>{isArabic ? 'طريقة' : 'Method'}</th>
								<th>{isArabic ? 'المبلغ' : 'Amount'}</th>
							</tr></thead>
							<tbody>
								{#each (report.paidBills || []) as b}
									<tr>
										<td>{b.vendor_name}</td>
										<td>{b.branch_name || '-'}</td>
										<td><span class="g-badge">{b.payment_method || '-'}</span></td>
										<td class="tr">{fmt(b.amount)} {cur}</td>
									</tr>
								{/each}
								<tr class="total-row">
									<td colspan="3">{isArabic ? 'الإجمالي' : 'Total'}</td>
									<td class="tr">{fmt(paidTotal)} {cur}</td>
								</tr>
							</tbody>
						</table>
					</div>
				{/if}
			</div>

			<!-- ══ EXPENSES ══ -->
			{@const expFiltered = report.paidExpenses?.filter((e: any) => (e.amount || 0) > 0) || []}
			<div class="glass-section" class:expanded={open.expenses}>
				<button class="section-header" on:click={() => toggle('expenses')}>
					<div class="sh-left">
						<span class="sh-icon orange">💸</span>
						<span class="sh-label">{isArabic ? 'المصروفات' : 'Expenses'}</span>
						<span class="sh-chip orange">{expFiltered.length} {isArabic ? 'بند' : 'items'}</span>
					</div>
					<div class="sh-right">
						<span class="sh-value">{fmt(expensesTotal)} {cur}</span>
						<span class="sh-arrow" class:rotated={open.expenses}>›</span>
					</div>
				</button>
				{#if open.expenses}
					<div class="section-body">
						{#if expFiltered.length}
							<table class="g-table">
								<thead><tr>
									<th>{isArabic ? 'الفئة' : 'Category'}</th>
									<th>{isArabic ? 'الفرع' : 'Branch'}</th>
									<th>{isArabic ? 'طريقة' : 'Method'}</th>
									<th>{isArabic ? 'المبلغ' : 'Amount'}</th>
								</tr></thead>
								<tbody>
									{#each expFiltered as e}
										<tr>
											<td>{isArabic ? e.category_ar : e.category_en}{e.vendor_name ? ` — ${e.vendor_name}` : ''}</td>
											<td>{e.branch_name}</td>
											<td><span class="g-badge">{e.payment_method || '-'}</span></td>
											<td class="tr">{fmt(e.amount)} {cur}</td>
										</tr>
									{/each}
									<tr class="total-row">
										<td colspan="3">{isArabic ? 'الإجمالي' : 'Total'}</td>
										<td class="tr">{fmt(expensesTotal)} {cur}</td>
									</tr>
								</tbody>
							</table>
						{:else}
							<p class="g-empty">{isArabic ? 'لا توجد مصروفات' : 'No expenses'}</p>
						{/if}
					</div>
				{/if}
			</div>

			<!-- ══ CASHIER ══ -->
			{@const cs = report.cashierSummary}
			<div class="glass-section" class:expanded={open.cashier}>
				<button class="section-header" on:click={() => toggle('cashier')}>
					<div class="sh-left">
						<span class="sh-icon green">🖥️</span>
						<span class="sh-label">{isArabic ? 'تقارير الكاشير' : 'Cashier'}</span>
						{#if cs}
							<span class="sh-chip green">{cs.totalBoxes} {isArabic ? 'صندوق' : 'boxes'}</span>
							{#if cs.flagged > 0}<span class="sh-chip orange">{cs.flagged} {isArabic ? 'بفرق' : 'diff'}</span>{/if}
						{/if}
					</div>
					<div class="sh-right">
						{#if cs}
							<span class="sh-value" style="color:#16a34a">+{fmt(cs.totalExcess)}</span>
							<span class="sh-value" style="color:#dc2626; margin-left:8px">-{fmt(Math.abs(cs.totalShort))}</span>
						{/if}
						<span class="sh-arrow" class:rotated={open.cashier}>›</span>
					</div>
				</button>
				{#if open.cashier}
					<div class="section-body">
						{#if report.cashierReports?.length}
							<table class="g-table">
								<thead><tr>
									<th>{isArabic ? 'الكاشير' : 'Cashier'}</th>
									<th>{isArabic ? 'الفرع' : 'Branch'}</th>
									<th>{isArabic ? 'موقع' : 'Pos.'}</th>
									<th>{isArabic ? 'المبيعات' : 'Sales'}</th>
									<th>{isArabic ? 'فرق نقد' : 'Cash Δ'}</th>
									<th>{isArabic ? 'فرق بطاقة' : 'Card Δ'}</th>
									<th>{isArabic ? 'الصافي' : 'Net Δ'}</th>
								</tr></thead>
								<tbody>
									{#each report.cashierReports as c}
										<tr>
											<td>{c.cashier_name || '-'}</td>
											<td>{isArabic ? c.branch_name_ar : c.branch_name_en}</td>
											<td class="tc">{c.box_number}</td>
											<td class="tr">{fmt(c.total_sales)} {cur}</td>
											<td class="tr" style="color:{diffColor(c.difference_cash)}">{diffSign(c.difference_cash)}</td>
											<td class="tr" style="color:{diffColor(c.difference_card)}">{diffSign(c.difference_card)}</td>
											<td class="tr fw" style="color:{diffColor(c.difference_total)}">{diffSign(c.difference_total)}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						{:else}
							<p class="g-empty">{isArabic ? 'لا توجد فروق' : 'No differences'}</p>
						{/if}
					</div>
				{/if}
			</div>

			<!-- ══ TASK PERFORMANCE ══ -->
			{@const avgRate = report.taskPerformance?.length
				? Math.round(report.taskPerformance.reduce((a: number, tk: any) => a + (tk.completion_rate || 0), 0) / report.taskPerformance.length)
				: 0}
			<div class="glass-section" class:expanded={open.tasks}>
				<button class="section-header" on:click={() => toggle('tasks')}>
					<div class="sh-left">
						<span class="sh-icon orange">📋</span>
						<span class="sh-label">{isArabic ? 'أداء المهام' : 'Task Performance'}</span>
						<span class="sh-chip" class:green={avgRate >= 70} class:orange={avgRate < 70}>{avgRate}% {isArabic ? 'متوسط' : 'avg'}</span>
					</div>
					<div class="sh-right">
						<span class="sh-value">{report.taskPerformance?.length ?? 0} {isArabic ? 'فروع' : 'branches'}</span>
						<span class="sh-arrow" class:rotated={open.tasks}>›</span>
					</div>
				</button>
				{#if open.tasks}
					<div class="section-body">
						<div class="card-grid">
							{#each (report.taskPerformance || []) as tk}
								{@const col = tk.completion_rate >= 90 ? '#16a34a' : tk.completion_rate >= 70 ? '#ea580c' : '#dc2626'}
								<div class="data-card task-card">
									<div class="dc-label">{isArabic ? tk.branch_name_ar : tk.branch_name_en}</div>
									<div class="task-bar-wrap">
										<div class="task-bar-fill" style="width:{tk.completion_rate || 0}%; background:{col}"></div>
									</div>
									<div class="dc-value" style="color:{col}">{Math.round(tk.completion_rate || 0)}%</div>
									<div class="dc-sub">✅ {tk.completed} · ⏳ {tk.pending} · ⚠️ {tk.overdue}</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}
			</div>

			<!-- ══ ATTENDANCE ══ -->
			{@const absentTotal = report.attendance?.reduce((a: number, x: any) => a + (x.absent || 0), 0) ?? 0}
			<div class="glass-section" class:expanded={open.attendance}>
				<button class="section-header" on:click={() => toggle('attendance')}>
					<div class="sh-left">
						<span class="sh-icon green">👥</span>
						<span class="sh-label">{isArabic ? 'الحضور' : 'Attendance'}</span>
						<span class="sh-chip green">{attendanceTotal} {isArabic ? 'موظف' : 'staff'}</span>
						{#if absentTotal > 0}<span class="sh-chip orange">{absentTotal} {isArabic ? 'غائب' : 'absent'}</span>{/if}
					</div>
					<div class="sh-right">
						<span class="sh-value">{report.attendance?.length ?? 0} {isArabic ? 'فروع' : 'branches'}</span>
						<span class="sh-arrow" class:rotated={open.attendance}>›</span>
					</div>
				</button>
				{#if open.attendance}
					<div class="section-body">
						<table class="g-table">
							<thead><tr>
								<th>{isArabic ? 'الفرع' : 'Branch'}</th>
								<th>{isArabic ? 'حاضر' : 'Present'}</th>
								<th>{isArabic ? 'غائب' : 'Absent'}</th>
								<th>{isArabic ? 'متأخر' : 'Late'}</th>
								<th>{isArabic ? 'إجمالي' : 'Total'}</th>
								<th>{isArabic ? 'ملاحظات' : 'Notes'}</th>
							</tr></thead>
							<tbody>
								{#each (report.attendance || []) as a}
									<tr>
										<td>{isArabic ? a.branch_name_ar : a.branch_name_en}</td>
										<td class="tc" style="color:#16a34a;font-weight:600">{a.present}</td>
										<td class="tc" style="color:{a.absent > 0 ? '#dc2626' : '#6b7280'};font-weight:600">{a.absent}</td>
										<td class="tc" style="color:{a.late > 0 ? '#ea580c' : '#6b7280'}">{a.late}</td>
										<td class="tc">{a.total}</td>
										<td class="notes-cell">
											{#if a.absent_names?.length}<div class="note-line absent">↗ {a.absent_names.join(', ')}</div>{/if}
											{#if a.late_names?.length}<div class="note-line late">⏰ {a.late_names.map((l: any) => `${l.name}(${l.late_minutes}m)`).join(', ')}</div>{/if}
											{#if a.missing_checkout?.length}<div class="note-line missing">🚪 {a.missing_checkout.join(', ')}</div>{/if}
											{#if a.under_time?.length}<div class="note-line under">⬇ {a.under_time.map((u: any) => `${u.name}(${u.under_minutes}m)`).join(', ')}</div>{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>

			<!-- ══ INCIDENTS ══ -->
			{#if incidentsCount > 0}
				<div class="glass-section incidents-section" class:expanded={open.incidents}>
					<button class="section-header" on:click={() => toggle('incidents')}>
						<div class="sh-left">
							<span class="sh-icon orange">🚨</span>
							<span class="sh-label">{isArabic ? 'الحوادث' : 'Incidents'}</span>
							<span class="sh-chip orange">{incidentsCount}</span>
						</div>
						<div class="sh-right">
							<span class="sh-arrow" class:rotated={open.incidents}>›</span>
						</div>
					</button>
					{#if open.incidents}
						<div class="section-body">
							<table class="g-table">
								<thead><tr>
									<th>{isArabic ? 'النوع' : 'Type'}</th>
									<th>{isArabic ? 'الموظف' : 'Employee'}</th>
									<th>{isArabic ? 'الفرع' : 'Branch'}</th>
									<th>{isArabic ? 'المخالفة' : 'Violation'}</th>
									<th>{isArabic ? 'الحالة' : 'Status'}</th>
								</tr></thead>
								<tbody>
									{#each report.incidents as inc}
										<tr>
											<td>{isArabic ? inc.incident_type_ar : inc.incident_type_en}</td>
											<td>{isArabic ? inc.employee_name_ar : inc.employee_name_en}</td>
											<td>{isArabic ? inc.branch_name_ar : inc.branch_name_en}</td>
											<td>{isArabic ? inc.violation_ar : (inc.violation_en || '-')}</td>
											<td><span class="g-badge" style="background:{inc.resolution_status === 'resolved' ? 'rgba(22,163,74,0.15)' : 'rgba(234,88,12,0.15)'}; color:{inc.resolution_status === 'resolved' ? '#15803d' : '#c2410c'}">{inc.resolution_status}</span></td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				</div>
			{/if}

		{:else}
			<div class="glass-section cp-idle">
				<p>📅 {isArabic ? 'اختر تاريخاً وانقر تحديث' : 'Select a date and click Refresh'}</p>
			</div>
		{/if}
	</div>
</div>

<style>
	/* ── Wrapper & animated background ── */
	.cp-wrap {
		position: relative;
		width: 100%;
		height: 100%;
		overflow: hidden;
		font-family: system-ui, -apple-system, sans-serif;
	}

	.cp-bg {
		position: absolute;
		inset: 0;
		background: linear-gradient(135deg, #f0fdf4 0%, #fff7ed 40%, #ecfdf5 70%, #fff7ed 100%);
		background-size: 400% 400%;
		animation: bgShift 12s ease infinite;
		z-index: 0;
	}
	@keyframes bgShift {
		0%   { background-position: 0% 50%; }
		50%  { background-position: 100% 50%; }
		100% { background-position: 0% 50%; }
	}

	.cp-container {
		position: relative;
		z-index: 1;
		padding: 20px;
		height: 100%;
		overflow-y: auto;
		color: #1a1a1a;
	}

	/* ── Header ── */
	.cp-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: 12px;
		margin-bottom: 16px;
		background: rgba(255,255,255,0.6);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255,255,255,0.85);
		border-radius: 16px;
		padding: 14px 20px;
		box-shadow: 0 4px 24px rgba(0,0,0,0.06);
	}

	.cp-title { display: flex; align-items: center; gap: 12px; }

	.cp-title-icon {
		font-size: 2rem;
		filter: drop-shadow(0 2px 4px rgba(22,163,74,0.3));
	}

	.cp-title h2 {
		margin: 0;
		font-size: 1.3rem;
		font-weight: 800;
		background: linear-gradient(135deg, #15803d, #c2410c);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.cp-subtitle { margin: 0; font-size: 0.72rem; color: #6b7280; }

	.cp-controls { display: flex; gap: 10px; align-items: center; }

	.cp-date-input {
		background: rgba(255,255,255,0.8);
		border: 1.5px solid rgba(22,163,74,0.3);
		color: #1a1a1a;
		padding: 8px 14px;
		border-radius: 10px;
		font-size: 0.875rem;
		font-weight: 500;
		outline: none;
		transition: border-color 0.2s;
	}
	.cp-date-input:focus { border-color: #16a34a; }

	.cp-refresh-btn {
		background: linear-gradient(135deg, #16a34a, #15803d);
		color: white;
		border: none;
		padding: 8px 18px;
		border-radius: 10px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: 6px;
		box-shadow: 0 4px 12px rgba(22,163,74,0.3);
		transition: transform 0.15s, box-shadow 0.15s;
	}
	.cp-refresh-btn:hover { transform: translateY(-1px); box-shadow: 0 6px 16px rgba(22,163,74,0.4); }
	.cp-refresh-btn:disabled { opacity: 0.6; cursor: default; transform: none; }

	.spin { display: inline-block; animation: spin 0.9s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ── Loading ── */
	.cp-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
		padding: 60px 0;
		color: #6b7280;
	}
	.cp-spinner-ring {
		width: 44px; height: 44px;
		border: 3px solid rgba(22,163,74,0.15);
		border-top-color: #16a34a;
		border-right-color: #ea580c;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	/* ── Glass Section (collapsible card) ── */
	.glass-section {
		background: rgba(255,255,255,0.45);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.8);
		border-radius: 14px;
		margin-bottom: 8px;
		overflow: hidden;
		box-shadow: 0 2px 10px rgba(0,0,0,0.05);
		transition: box-shadow 0.25s, border-color 0.25s;
	}
	.glass-section.expanded {
		box-shadow: 0 8px 30px rgba(0,0,0,0.09);
		border-color: rgba(255,255,255,0.95);
	}
	.incidents-section { border-left: 3px solid rgba(234,88,12,0.5); }

	/* ── Section header (always visible strip) ── */
	.section-header {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		background: transparent;
		border: none;
		cursor: pointer;
		text-align: left;
		gap: 12px;
		transition: background 0.18s;
	}
	.section-header:hover { background: rgba(255,255,255,0.45); }

	.sh-left { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; flex: 1; }
	.sh-right { display: flex; align-items: center; gap: 8px; }

	.sh-icon {
		font-size: 1rem;
		width: 32px; height: 32px;
		display: flex; align-items: center; justify-content: center;
		border-radius: 9px;
		flex-shrink: 0;
	}
	.sh-icon.green { background: rgba(22,163,74,0.1); }
	.sh-icon.orange { background: rgba(234,88,12,0.1); }

	.sh-label { font-size: 0.92rem; font-weight: 700; color: #111827; }

	.sh-chip {
		font-size: 0.7rem;
		font-weight: 600;
		padding: 2px 8px;
		border-radius: 20px;
	}
	.sh-chip.green { background: rgba(22,163,74,0.1); color: #15803d; }
	.sh-chip.orange { background: rgba(234,88,12,0.1); color: #c2410c; }

	.sh-value { font-size: 0.88rem; font-weight: 700; color: #374151; white-space: nowrap; }

	.sh-arrow {
		font-size: 1.4rem;
		color: #9ca3af;
		font-weight: 300;
		transition: transform 0.25s;
		display: inline-block;
		line-height: 1;
	}
	.sh-arrow.rotated { transform: rotate(90deg); }

	/* ── Expanded body ── */
	.section-body {
		padding: 0 14px 14px;
		animation: fadeDown 0.18s ease;
		overflow-x: auto;
	}
	@keyframes fadeDown {
		from { opacity: 0; transform: translateY(-5px); }
		to   { opacity: 1; transform: translateY(0); }
	}

	/* ── Card grid ── */
	.card-grid { display: flex; flex-wrap: wrap; gap: 10px; }

	.data-card {
		border-radius: 12px;
		padding: 14px 16px;
		min-width: 150px;
		flex: 1;
		background: rgba(255,255,255,0.65);
		border: 1px solid rgba(255,255,255,0.9);
		box-shadow: 0 1px 6px rgba(0,0,0,0.04);
	}
	.green-card { border-top: 3px solid #16a34a; }
	.total-card { border-top: 3px solid #ea580c; background: rgba(255,247,237,0.65); }
	.task-card  { border-top: 3px solid #16a34a; }

	.dc-label { font-size: 0.7rem; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 0.04em; margin-bottom: 5px; }
	.dc-value { font-size: 1.35rem; font-weight: 800; color: #111827; line-height: 1.1; }
	.dc-cur   { font-size: 0.75rem; font-weight: 500; color: #9ca3af; }
	.dc-sub   { font-size: 0.72rem; color: #9ca3af; margin-top: 4px; }

	.task-bar-wrap { height: 4px; background: rgba(0,0,0,0.07); border-radius: 2px; overflow: hidden; margin: 7px 0 3px; }
	.task-bar-fill { height: 100%; border-radius: 2px; transition: width 0.5s ease; }

	/* ── Glass table ── */
	.g-table { width: 100%; border-collapse: collapse; font-size: 0.83rem; min-width: 400px; }
	.g-table th {
		background: rgba(22,163,74,0.07);
		color: #15803d;
		font-weight: 700;
		font-size: 0.7rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		padding: 8px 12px;
		text-align: left;
		white-space: nowrap;
		border-bottom: 1px solid rgba(22,163,74,0.1);
	}
	.g-table td {
		padding: 8px 12px;
		border-top: 1px solid rgba(0,0,0,0.04);
		color: #374151;
	}
	.g-table tbody tr:hover td { background: rgba(22,163,74,0.04); }
	.total-row td { background: rgba(234,88,12,0.06) !important; font-weight: 700; color: #c2410c; }

	.tc { text-align: center; }
	.tr { text-align: right; font-variant-numeric: tabular-nums; }
	.fw { font-weight: 700; }

	/* ── Badge ── */
	.g-badge {
		background: rgba(22,163,74,0.1);
		color: #15803d;
		padding: 2px 8px;
		border-radius: 6px;
		font-size: 0.7rem;
		font-weight: 600;
	}

	/* ── Attendance notes ── */
	.notes-cell { max-width: 260px; }
	.note-line { font-size: 0.71rem; margin-bottom: 2px; border-radius: 4px; padding: 1px 5px; }
	.note-line.absent  { color: #b91c1c; background: rgba(185,28,28,0.07); }
	.note-line.late    { color: #c2410c; background: rgba(194,65,12,0.07); }
	.note-line.missing { color: #6d28d9; background: rgba(109,40,217,0.07); }
	.note-line.under   { color: #1d4ed8; background: rgba(29,78,216,0.07); }

	/* ── Misc ── */
	.cp-error-card { padding: 16px 20px; color: #dc2626; font-weight: 600; }
	.cp-idle { padding: 48px; text-align: center; color: #6b7280; font-size: 1rem; }
	.g-empty { color: #9ca3af; font-style: italic; text-align: center; padding: 14px 0; margin: 0; }
</style>
