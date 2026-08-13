<script context="module" lang="ts">
	// Branches and the vendor list are identical for both instances and don't
	// change while LC Planner is open, so fetch them once and share the result
	// rather than re-fetching every time a tab is switched.
	let cachedBranches: any[] | null = null;
	let cachedVendors: any[] | null = null;
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';

	// Which side of LC Planner this instance serves. Rows are kept apart in
	// daily_temp_schedules by the payment_mode column.
	export let paymentMode: 'cash' | 'bank' = 'cash';

	// Mobile viewport: the section grows with its content instead of filling a
	// fixed-height desktop window, and the controls stack.
	export let mobile = false;

	$: modeLabel = paymentMode === 'bank' ? 'Bank Payments' : 'Cash Payments';
	$: modeIcon = paymentMode === 'bank' ? '🏦' : '💵';

	// ===== Branch =====
	let branches: any[] = [];
	let selectedBranch = '';

	// ===== Daily Temp Schedules (inline) =====
	let schedulesTab: 'vendor' | 'expense' = 'vendor';
	let schedules: any[] = [];
	let isLoadingSchedules = false;
	let isSavingSchedule = false;
	let showScheduleForm = false;

	// Schedule list search + date filter (separate per tab)
	let schedVendorListSearch = '';
	let schedVendorListDate = '';
	let schedExpenseListSearch = '';
	let schedExpenseListDate = '';

	// Custom date-filter calendars — highlight days that have a schedule
	let showVendorDateCal = false;
	let vendorCalMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
	let showExpenseDateCal = false;
	let expenseCalMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);

	// Vendor schedule form
	let schedVendorSearch = '';
	let schedSelectedVendor: any = null;
	let schedVendorAmount: number | '' = '';
	let schedVendorNotes = '';
	let schedVendorDate = new Date().toISOString().split('T')[0];
	let schedVendorList: any[] = [];
	// Expense schedule form
	let schedExpenseDescription = '';
	let schedExpenseAmount: number | '' = '';
	let schedExpenseNotes = '';
	let schedExpenseDate = new Date().toISOString().split('T')[0];

	function getCalendarWeeks(monthDate: Date) {
		const year = monthDate.getFullYear();
		const month = monthDate.getMonth();
		const startWeekday = new Date(year, month, 1).getDay();
		const daysInMonth = new Date(year, month + 1, 0).getDate();
		const cells: ({ day: number; dateStr: string } | null)[] = [];
		for (let i = 0; i < startWeekday; i++) cells.push(null);
		for (let d = 1; d <= daysInMonth; d++) {
			cells.push({ day: d, dateStr: `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}` });
		}
		while (cells.length % 7 !== 0) cells.push(null);
		const weeks = [];
		for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
		return weeks;
	}

	function closeScheduleCalendars() {
		showVendorDateCal = false;
		showExpenseDateCal = false;
	}

	function openVendorCal() {
		if (showVendorDateCal) { showVendorDateCal = false; return; }
		const base = schedVendorListDate ? new Date(schedVendorListDate + 'T00:00:00') : new Date();
		vendorCalMonth = new Date(base.getFullYear(), base.getMonth(), 1);
		showVendorDateCal = true;
		showExpenseDateCal = false;
	}
	function vendorCalPrevMonth() { vendorCalMonth = new Date(vendorCalMonth.getFullYear(), vendorCalMonth.getMonth() - 1, 1); }
	function vendorCalNextMonth() { vendorCalMonth = new Date(vendorCalMonth.getFullYear(), vendorCalMonth.getMonth() + 1, 1); }
	function selectVendorCalDate(dateStr: string) { schedVendorListDate = dateStr; showVendorDateCal = false; }

	function openExpenseCal() {
		if (showExpenseDateCal) { showExpenseDateCal = false; return; }
		const base = schedExpenseListDate ? new Date(schedExpenseListDate + 'T00:00:00') : new Date();
		expenseCalMonth = new Date(base.getFullYear(), base.getMonth(), 1);
		showExpenseDateCal = true;
		showVendorDateCal = false;
	}
	function expenseCalPrevMonth() { expenseCalMonth = new Date(expenseCalMonth.getFullYear(), expenseCalMonth.getMonth() - 1, 1); }
	function expenseCalNextMonth() { expenseCalMonth = new Date(expenseCalMonth.getFullYear(), expenseCalMonth.getMonth() + 1, 1); }
	function selectExpenseCalDate(dateStr: string) { schedExpenseListDate = dateStr; showExpenseDateCal = false; }

	onMount(async () => {
		// Opens on All Branches ('') — the branch is only narrowed by hand.
		await loadBranches();
		previousBranch = selectedBranch;
		await Promise.all([loadSchedules(), loadScheduleVendors()]);
	});

	// Reload schedules whenever the branch changes ('' = all branches)
	let previousBranch = '';
	$: if (selectedBranch !== previousBranch) {
		previousBranch = selectedBranch;
		showScheduleForm = false;
		loadSchedules();
	}

	// '' means every branch — inserts need a real branch, so the add button is
	// disabled while the list is showing all of them.
	$: isAllBranches = selectedBranch === '';
	// Name and location are shown on separate lines in the Branch column
	$: branchNameById = new Map(branches.map(b => [b.id, b.name_en]));
	$: branchLocationById = new Map(branches.map(b => [b.id, b.location_en]));

	async function loadBranches() {
		if (cachedBranches) { branches = cachedBranches; return; }
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (!error) {
				branches = data || [];
				cachedBranches = branches;
			}
		} catch (e) {
			console.error('Error loading branches:', e);
		}
	}

	// Currency symbol image from the app icons table
	$: currencySymbolUrl = $iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png';

	// 2026-08-27 -> 27/08/26
	function formatShortDate(dateStr: string) {
		if (!dateStr) return '';
		const [y, m, d] = dateStr.split('-');
		if (!y || !m || !d) return dateStr;
		return `${d}/${m}/${y.slice(-2)}`;
	}

	function getBranchDisplayName(branch: any) {
		return branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en;
	}

	async function loadScheduleVendors() {
		if (cachedVendors) { schedVendorList = cachedVendors; return; }
		try {
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, salesman_name')
				.eq('status', 'Active')
				.order('vendor_name');
			if (!error && data) {
				// Deduplicate by erp_vendor_id — keep first occurrence
				const seen = new Set();
				schedVendorList = data.filter(v => {
					if (seen.has(v.erp_vendor_id)) return false;
					seen.add(v.erp_vendor_id);
					return true;
				});
				cachedVendors = schedVendorList;
			}
		} catch (e) {
			console.error('Error loading schedule vendors:', e);
		}
	}

	async function loadSchedules() {
		isLoadingSchedules = true;
		try {
			const { data, error } = await supabase
				.rpc('get_daily_temp_schedules', {
					p_branch_id: selectedBranch ? parseInt(selectedBranch) : null,
					p_payment_mode: paymentMode
				});
			if (!error) schedules = data || [];
		} catch (e) {
			console.error('Error loading schedules:', e);
		} finally {
			isLoadingSchedules = false;
		}
	}

	function resetScheduleForm() {
		schedVendorSearch = '';
		schedSelectedVendor = null;
		schedVendorAmount = '';
		schedVendorNotes = '';
		schedVendorDate = new Date().toISOString().split('T')[0];
		schedExpenseDescription = '';
		schedExpenseAmount = '';
		schedExpenseNotes = '';
		schedExpenseDate = new Date().toISOString().split('T')[0];
		showScheduleForm = false;
	}

	$: filteredScheduleVendors = schedVendorList.filter(v =>
		v.vendor_name?.toLowerCase().includes(schedVendorSearch.toLowerCase()) ||
		String(v.erp_vendor_id).includes(schedVendorSearch)
	);

	async function saveVendorSchedule() {
		if (!schedSelectedVendor || !schedVendorAmount || Number(schedVendorAmount) <= 0) return;
		isSavingSchedule = true;
		try {
			const { error } = await supabase.from('daily_temp_schedules').insert({
				branch_id: parseInt(selectedBranch),
				payment_mode: paymentMode,
				type: 'vendor',
				vendor_id: String(schedSelectedVendor.erp_vendor_id),
				vendor_name: schedSelectedVendor.vendor_name,
				amount: Number(schedVendorAmount),
				notes: schedVendorNotes || null,
				schedule_date: schedVendorDate
			});
			if (!error) {
				resetScheduleForm();
				await loadSchedules();
			}
		} catch (e) {
			console.error('Error saving vendor schedule:', e);
		} finally {
			isSavingSchedule = false;
		}
	}

	async function saveExpenseSchedule() {
		if (!schedExpenseDescription || !schedExpenseAmount || Number(schedExpenseAmount) <= 0) return;
		isSavingSchedule = true;
		try {
			const { error } = await supabase.from('daily_temp_schedules').insert({
				branch_id: parseInt(selectedBranch),
				payment_mode: paymentMode,
				type: 'expense',
				description: schedExpenseDescription,
				amount: Number(schedExpenseAmount),
				notes: schedExpenseNotes || null,
				schedule_date: schedExpenseDate
			});
			if (!error) {
				resetScheduleForm();
				await loadSchedules();
			}
		} catch (e) {
			console.error('Error saving expense schedule:', e);
		} finally {
			isSavingSchedule = false;
		}
	}

	async function deleteSchedule(id: string) {
		try {
			await supabase.from('daily_temp_schedules').delete().eq('id', id);
			schedules = schedules.filter(s => s.id !== id);
		} catch (e) {
			console.error('Error deleting schedule:', e);
		}
	}

	// Oldest first. The RPC returns newest first (shared with the Denomination
	// window), so the order is flipped here rather than in the database.
	function oldestFirst(a: any, b: any) {
		if (a.schedule_date !== b.schedule_date) return a.schedule_date < b.schedule_date ? -1 : 1;
		return (a.created_at || '') < (b.created_at || '') ? -1 : 1;
	}

	// Dates that have at least one schedule — drives the red highlight in each calendar
	$: vendorScheduleDateSet = new Set(schedules.filter(s => s.type === 'vendor').map(s => s.schedule_date));
	$: expenseScheduleDateSet = new Set(schedules.filter(s => s.type === 'expense').map(s => s.schedule_date));
	$: vendorCalWeeks = getCalendarWeeks(vendorCalMonth);
	$: expenseCalWeeks = getCalendarWeeks(expenseCalMonth);

	$: vendorSchedules = schedules
		.filter(s => s.type === 'vendor')
		.filter(s => !schedVendorListDate || s.schedule_date === schedVendorListDate)
		.filter(s => {
			if (!schedVendorListSearch.trim()) return true;
			const q = schedVendorListSearch.toLowerCase();
			return (s.vendor_name || '').toLowerCase().includes(q) || (s.notes || '').toLowerCase().includes(q);
		})
		.sort(oldestFirst);
	$: expenseSchedules = schedules
		.filter(s => s.type === 'expense')
		.filter(s => !schedExpenseListDate || s.schedule_date === schedExpenseListDate)
		.filter(s => {
			if (!schedExpenseListSearch.trim()) return true;
			const q = schedExpenseListSearch.toLowerCase();
			return (s.description || '').toLowerCase().includes(q) || (s.notes || '').toLowerCase().includes(q);
		})
		.sort(oldestFirst);

	// Totals for the currently filtered list
	$: vendorSchedTotal = vendorSchedules.reduce((sum, s) => sum + (Number(s.amount) || 0), 0);
	$: expenseSchedTotal = expenseSchedules.reduce((sum, s) => sum + (Number(s.amount) || 0), 0);
</script>

<!-- Daily Temp Schedules — inline -->
<div class="sched-section" class:mobile on:click={closeScheduleCalendars} role="presentation">
	<div class="sched-section-header">
		<span class="sched-section-title">{modeIcon} {modeLabel} — Daily Temp Schedules</span>
		<select class="sched-branch-select" bind:value={selectedBranch}>
			<option value="">🌐 All Branches</option>
			{#each branches as b}
				<option value={String(b.id)}>{getBranchDisplayName(b)}</option>
			{/each}
		</select>
	</div>

	<!-- Tabs -->
	<div class="schedules-tabs">
		<button class="sched-tab" class:active={schedulesTab === 'vendor'} on:click={() => { schedulesTab = 'vendor'; showScheduleForm = false; }}>
			Vendor
		</button>
		<button class="sched-tab" class:active={schedulesTab === 'expense'} on:click={() => { schedulesTab = 'expense'; showScheduleForm = false; }}>
			Expenses
		</button>
	</div>

	<div class="sched-section-body">

		<!-- VENDOR TAB -->
		{#if schedulesTab === 'vendor'}
			<div class="sched-tab-content">
				{#if showScheduleForm}
					<div class="sched-form">
						<div class="sched-form-title">New Vendor Schedule</div>
						<!-- Vendor search -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-vendor-search">Vendor</label>
							{#if schedSelectedVendor}
								<div class="sched-selected-vendor">
									<span>{schedSelectedVendor.vendor_name}</span>
									<button on:click={() => { schedSelectedVendor = null; schedVendorSearch = ''; }}>✕</button>
								</div>
							{:else}
								<input
									id="{paymentMode}-sched-vendor-search"
									type="text"
									placeholder="Search vendors..."
									bind:value={schedVendorSearch}
									class="sched-input"
								/>
								<div class="sched-vendor-dropdown">
									{#each filteredScheduleVendors as v}
										<button class="sched-vendor-option" on:click={() => { schedSelectedVendor = v; schedVendorSearch = ''; }}>
											<span class="vendor-name">{v.vendor_name}</span>
											<span class="vendor-id">{v.salesman_name || 'N/A'}</span>
										</button>
									{:else}
										<div class="sched-no-results">No vendors found</div>
									{/each}
								</div>
							{/if}
						</div>
						<!-- Schedule Date -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-vendor-date">Schedule Date</label>
							<input id="{paymentMode}-sched-vendor-date" type="date" bind:value={schedVendorDate} class="sched-input" />
						</div>
						<!-- Amount -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-vendor-amount">Amount (<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />)</label>
							<input id="{paymentMode}-sched-vendor-amount" type="number" min="0" step="0.01" placeholder="0.00" bind:value={schedVendorAmount} class="sched-input" />
						</div>
						<!-- Notes -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-vendor-notes">Notes <span class="optional">(optional)</span></label>
							<input id="{paymentMode}-sched-vendor-notes" type="text" placeholder="Add a note..." bind:value={schedVendorNotes} class="sched-input" />
						</div>
						<div class="sched-form-actions">
							<button class="sched-cancel-btn" on:click={resetScheduleForm}>Cancel</button>
							<button class="sched-save-btn" on:click={saveVendorSchedule} disabled={!schedSelectedVendor || !schedVendorAmount || !schedVendorDate || isSavingSchedule}>
								{isSavingSchedule ? 'Saving...' : 'Save'}
							</button>
						</div>
					</div>
				{/if}

				<!-- Vendor schedule search + add + date filter -->
				<div class="sched-filter-row">
					<input
						type="text"
						placeholder="Search vendor or notes..."
						bind:value={schedVendorListSearch}
						class="sched-input sched-filter-search"
					/>
					<div class="sched-total-chip">
						<span class="sched-total-label">Total</span>
						<span class="sched-total-value"><img src={currencySymbolUrl} alt="SAR" class="currency-icon" /> {vendorSchedTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						<span class="sched-total-count">({vendorSchedules.length})</span>
					</div>
					<button type="button" class="sched-add-icon-btn" on:click={() => showScheduleForm = true} disabled={isAllBranches} title={isAllBranches ? 'Pick a branch to add a schedule' : 'Add vendor schedule'}>+</button>
					<div class="sched-date-filter-wrap">
						<button type="button" class="sched-input sched-filter-date-btn" on:click|stopPropagation={openVendorCal}>
							<span>{formatShortDate(schedVendorListDate) || 'Any date'}</span>
							<span class="sched-cal-icon">📅</span>
						</button>
						{#if showVendorDateCal}
							<div class="sched-cal-popup" on:click|stopPropagation role="presentation">
								<div class="sched-cal-header">
									<button type="button" class="sched-cal-nav" on:click={vendorCalPrevMonth}>‹</button>
									<span class="sched-cal-title">{vendorCalMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</span>
									<button type="button" class="sched-cal-nav" on:click={vendorCalNextMonth}>›</button>
								</div>
								<div class="sched-cal-weekdays">
									{#each ['S', 'M', 'T', 'W', 'T', 'F', 'S'] as wd}<span>{wd}</span>{/each}
								</div>
								{#each vendorCalWeeks as week}
									<div class="sched-cal-week">
										{#each week as cell}
											{#if cell}
												<button type="button"
													class="sched-cal-day"
													class:has-schedule={vendorScheduleDateSet.has(cell.dateStr)}
													class:selected={schedVendorListDate === cell.dateStr}
													on:click={() => selectVendorCalDate(cell.dateStr)}>
													{cell.day}
												</button>
											{:else}
												<span class="sched-cal-day empty"></span>
											{/if}
										{/each}
									</div>
								{/each}
								<div class="sched-cal-footer">
									<button type="button" class="sched-cal-today" on:click={() => selectVendorCalDate(new Date().toISOString().split('T')[0])}>Today</button>
									{#if schedVendorListDate}
										<button type="button" class="sched-cal-clear-date" on:click={() => { schedVendorListDate = ''; showVendorDateCal = false; }}>Clear date</button>
									{/if}
								</div>
							</div>
						{/if}
					</div>
					{#if schedVendorListSearch || schedVendorListDate}
						<button class="sched-filter-clear" on:click={() => { schedVendorListSearch = ''; schedVendorListDate = ''; }} title="Clear filters">✕</button>
					{/if}
				</div>

				<!-- Vendor schedule table -->
				{#if isLoadingSchedules}
					<div class="sched-loading">Loading...</div>
				{:else if vendorSchedules.length === 0}
					<div class="sched-empty">{schedVendorListSearch || schedVendorListDate ? 'No vendor schedules match your filters' : 'No vendor schedules yet'}</div>
				{:else}
					<div class="sched-table-wrap">
						<table class="sched-table">
							<thead>
								<tr>
									<th>Date</th>
									{#if isAllBranches}<th>Branch</th>{/if}
									<th>Vendor</th>
									<th>Amount</th>
									<th>Notes</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each vendorSchedules as s}
									<tr>
										<td class="sched-col-date">{formatShortDate(s.schedule_date)}</td>
										{#if isAllBranches}
										<td class="sched-col-branch">
											<span class="branch-name">{branchNameById.get(s.branch_id) || s.branch_id}</span>
											{#if branchLocationById.get(s.branch_id)}
												<span class="branch-location">{branchLocationById.get(s.branch_id)}</span>
											{/if}
										</td>
									{/if}
										<td class="sched-col-name">{s.vendor_name}</td>
										<td class="sched-col-amount"><img src={currencySymbolUrl} alt="SAR" class="currency-icon" /> {Number(s.amount).toLocaleString()}</td>
										<td class="sched-col-notes">{s.notes || '—'}</td>
										<td><button class="sched-delete-btn" on:click={() => deleteSchedule(s.id)}>×</button></td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}

		<!-- EXPENSE TAB -->
		{#if schedulesTab === 'expense'}
			<div class="sched-tab-content">
				{#if showScheduleForm}
					<div class="sched-form">
						<div class="sched-form-title">New Expense Schedule</div>
						<!-- Schedule Date -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-exp-date">Schedule Date</label>
							<input id="{paymentMode}-sched-exp-date" type="date" bind:value={schedExpenseDate} class="sched-input" />
						</div>
						<!-- Description -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-exp-desc">Description</label>
							<input id="{paymentMode}-sched-exp-desc" type="text" placeholder="Expense description..." bind:value={schedExpenseDescription} class="sched-input" />
						</div>
						<!-- Amount -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-exp-amount">Amount (<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />)</label>
							<input id="{paymentMode}-sched-exp-amount" type="number" min="0" step="0.01" placeholder="0.00" bind:value={schedExpenseAmount} class="sched-input" />
						</div>
						<!-- Notes -->
						<div class="sched-form-field">
							<label for="{paymentMode}-sched-exp-notes">Notes <span class="optional">(optional)</span></label>
							<input id="{paymentMode}-sched-exp-notes" type="text" placeholder="Add a note..." bind:value={schedExpenseNotes} class="sched-input" />
						</div>
						<div class="sched-form-actions">
							<button class="sched-cancel-btn" on:click={resetScheduleForm}>Cancel</button>
							<button class="sched-save-btn" on:click={saveExpenseSchedule} disabled={!schedExpenseDescription || !schedExpenseAmount || !schedExpenseDate || isSavingSchedule}>
								{isSavingSchedule ? 'Saving...' : 'Save'}
							</button>
						</div>
					</div>
				{/if}

				<!-- Expense schedule search + add + date filter -->
				<div class="sched-filter-row">
					<input
						type="text"
						placeholder="Search description or notes..."
						bind:value={schedExpenseListSearch}
						class="sched-input sched-filter-search"
					/>
					<div class="sched-total-chip">
						<span class="sched-total-label">Total</span>
						<span class="sched-total-value"><img src={currencySymbolUrl} alt="SAR" class="currency-icon" /> {expenseSchedTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						<span class="sched-total-count">({expenseSchedules.length})</span>
					</div>
					<button type="button" class="sched-add-icon-btn" on:click={() => showScheduleForm = true} disabled={isAllBranches} title={isAllBranches ? 'Pick a branch to add a schedule' : 'Add expense schedule'}>+</button>
					<div class="sched-date-filter-wrap">
						<button type="button" class="sched-input sched-filter-date-btn" on:click|stopPropagation={openExpenseCal}>
							<span>{formatShortDate(schedExpenseListDate) || 'Any date'}</span>
							<span class="sched-cal-icon">📅</span>
						</button>
						{#if showExpenseDateCal}
							<div class="sched-cal-popup" on:click|stopPropagation role="presentation">
								<div class="sched-cal-header">
									<button type="button" class="sched-cal-nav" on:click={expenseCalPrevMonth}>‹</button>
									<span class="sched-cal-title">{expenseCalMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</span>
									<button type="button" class="sched-cal-nav" on:click={expenseCalNextMonth}>›</button>
								</div>
								<div class="sched-cal-weekdays">
									{#each ['S', 'M', 'T', 'W', 'T', 'F', 'S'] as wd}<span>{wd}</span>{/each}
								</div>
								{#each expenseCalWeeks as week}
									<div class="sched-cal-week">
										{#each week as cell}
											{#if cell}
												<button type="button"
													class="sched-cal-day"
													class:has-schedule={expenseScheduleDateSet.has(cell.dateStr)}
													class:selected={schedExpenseListDate === cell.dateStr}
													on:click={() => selectExpenseCalDate(cell.dateStr)}>
													{cell.day}
												</button>
											{:else}
												<span class="sched-cal-day empty"></span>
											{/if}
										{/each}
									</div>
								{/each}
								<div class="sched-cal-footer">
									<button type="button" class="sched-cal-today" on:click={() => selectExpenseCalDate(new Date().toISOString().split('T')[0])}>Today</button>
									{#if schedExpenseListDate}
										<button type="button" class="sched-cal-clear-date" on:click={() => { schedExpenseListDate = ''; showExpenseDateCal = false; }}>Clear date</button>
									{/if}
								</div>
							</div>
						{/if}
					</div>
					{#if schedExpenseListSearch || schedExpenseListDate}
						<button class="sched-filter-clear" on:click={() => { schedExpenseListSearch = ''; schedExpenseListDate = ''; }} title="Clear filters">✕</button>
					{/if}
				</div>

				<!-- Expense schedule table -->
				{#if isLoadingSchedules}
					<div class="sched-loading">Loading...</div>
				{:else if expenseSchedules.length === 0}
					<div class="sched-empty">{schedExpenseListSearch || schedExpenseListDate ? 'No expense schedules match your filters' : 'No expense schedules yet'}</div>
				{:else}
					<div class="sched-table-wrap">
						<table class="sched-table">
							<thead>
								<tr>
									<th>Date</th>
									{#if isAllBranches}<th>Branch</th>{/if}
									<th>Description</th>
									<th>Amount</th>
									<th>Notes</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each expenseSchedules as s}
									<tr>
										<td class="sched-col-date">{formatShortDate(s.schedule_date)}</td>
										{#if isAllBranches}
										<td class="sched-col-branch">
											<span class="branch-name">{branchNameById.get(s.branch_id) || s.branch_id}</span>
											{#if branchLocationById.get(s.branch_id)}
												<span class="branch-location">{branchLocationById.get(s.branch_id)}</span>
											{/if}
										</td>
									{/if}
										<td class="sched-col-name">{s.description}</td>
										<td class="sched-col-amount"><img src={currencySymbolUrl} alt="SAR" class="currency-icon" /> {Number(s.amount).toLocaleString()}</td>
										<td class="sched-col-notes">{s.notes || '—'}</td>
										<td><button class="sched-delete-btn" on:click={() => deleteSchedule(s.id)}>×</button></td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}

	</div>
</div>

<style>
/* ===== Daily Temp Schedules — inline ===== */
	.sched-section {
		display: flex;
		flex-direction: column;
		height: 100%;
		min-height: 0;
	}

	.sched-section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 10px;
		padding: 14px 18px;
		background: linear-gradient(135deg, rgba(71,85,105,0.92) 0%, rgba(100,116,139,0.92) 100%);
		backdrop-filter: blur(8px);
		color: #fff;
		flex-shrink: 0;
	}

	.sched-section-title {
		font-weight: 700;
		font-size: 0.95rem;
		letter-spacing: 0.01em;
	}

	.sched-branch-select {
		background: rgba(255,255,255,0.9);
		border: 1px solid rgba(255,255,255,0.5);
		border-radius: 8px;
		color: #1e293b;
		padding: 6px 10px;
		font-size: 0.8rem;
		font-weight: 600;
		outline: none;
		cursor: pointer;
		max-width: 320px;
	}

	.schedules-tabs {
		display: flex;
		background: rgba(241, 245, 249, 0.6);
		border-bottom: 1px solid rgba(203, 213, 225, 0.6);
		flex-shrink: 0;
	}

	.sched-tab {
		flex: 1;
		padding: 12px;
		background: transparent;
		border: none;
		color: #64748b;
		font-size: 0.9rem;
		font-weight: 500;
		cursor: pointer;
		border-bottom: 2px solid transparent;
		transition: all 0.2s;
	}

	.sched-tab.active {
		color: #475569;
		border-bottom-color: #475569;
		background: rgba(255,255,255,0.5);
		font-weight: 600;
	}

	.sched-tab:hover:not(.active) {
		color: #475569;
		background: rgba(255,255,255,0.3);
	}

	.sched-section-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 18px;
		background: rgba(248, 250, 252, 0.4);
	}

	.sched-tab-content {
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	.sched-add-icon-btn {
		flex-shrink: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #475569, #64748b);
		color: #fff;
		border: none;
		border-radius: 8px;
		font-size: 1.1rem;
		line-height: 1;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(100,116,139,0.3);
	}

	.sched-add-icon-btn:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 14px rgba(100,116,139,0.4);
	}

	.sched-add-icon-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
		box-shadow: none;
	}

	.sched-form {
		background: rgba(255, 255, 255, 0.75);
		border: 1px solid rgba(203, 213, 225, 0.7);
		border-radius: 14px;
		padding: 18px;
		display: flex;
		flex-direction: column;
		gap: 14px;
		box-shadow: 0 2px 12px rgba(100,116,139,0.07);
	}

	.sched-form-title {
		font-weight: 700;
		color: #1e293b;
		font-size: 0.9rem;
	}

	.sched-form-field {
		display: flex;
		flex-direction: column;
		gap: 5px;
		position: relative;
	}

	.sched-form-field label {
		font-size: 0.78rem;
		color: #475569;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.sched-form-field .optional {
		color: #94a3b8;
		font-size: 0.7rem;
		text-transform: none;
		letter-spacing: 0;
		font-weight: 400;
	}

	.sched-input {
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 8px;
		color: #1e293b;
		padding: 9px 12px;
		font-size: 0.875rem;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.sched-input:focus {
		border-color: #475569;
		box-shadow: 0 0 0 3px rgba(100,116,139,0.12);
	}

	.sched-input::placeholder {
		color: #94a3b8;
	}

	.sched-filter-row {
		display: flex;
		align-items: center;
		gap: 8px;
		margin: 4px 0 10px;
	}

	.sched-filter-search {
		flex: 1;
		min-width: 0;
	}

	.sched-total-chip {
		display: flex;
		align-items: baseline;
		gap: 6px;
		flex-shrink: 0;
		height: 34px;
		padding: 0 14px;
		border-radius: 8px;
		background: rgba(241, 245, 249, 0.95);
		border: 1px solid rgba(203, 213, 225, 0.9);
		white-space: nowrap;
	}

	.sched-total-label {
		font-size: 0.68rem;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.sched-total-value {
		font-size: 0.9rem;
		font-weight: 700;
		color: #1e293b;
	}

	.sched-total-count {
		font-size: 0.72rem;
		color: #94a3b8;
	}

	.sched-date-filter-wrap {
		position: relative;
		flex-shrink: 0;
	}

	.sched-filter-date-btn {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		width: 155px;
		cursor: pointer;
		text-align: left;
		color: #1e293b;
	}

	.sched-filter-date-btn span:first-child {
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.sched-cal-icon {
		font-size: 0.8rem;
		flex-shrink: 0;
	}

	.sched-cal-popup {
		position: absolute;
		top: calc(100% + 6px);
		right: 0;
		z-index: 20;
		width: 240px;
		background: #ffffff;
		border: 1px solid rgba(203, 213, 225, 0.9);
		border-radius: 10px;
		box-shadow: 0 10px 30px rgba(15, 23, 42, 0.15);
		padding: 10px;
	}

	.sched-cal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 8px;
	}

	.sched-cal-title {
		font-size: 0.8rem;
		font-weight: 600;
		color: #1e293b;
	}

	.sched-cal-nav {
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(241, 245, 249, 0.9);
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 6px;
		color: #475569;
		font-size: 0.95rem;
		cursor: pointer;
		line-height: 1;
	}
	.sched-cal-nav:hover {
		background: rgba(226, 232, 240, 0.9);
	}

	.sched-cal-weekdays {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		margin-bottom: 2px;
	}
	.sched-cal-weekdays span {
		text-align: center;
		font-size: 0.65rem;
		font-weight: 600;
		color: #94a3b8;
	}

	.sched-cal-week {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
	}

	.sched-cal-day {
		width: 100%;
		aspect-ratio: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: none;
		border-radius: 6px;
		font-size: 0.75rem;
		color: #334155;
		cursor: pointer;
	}
	.sched-cal-day:hover {
		background: rgba(226, 232, 240, 0.8);
	}
	.sched-cal-day.empty {
		cursor: default;
	}

	/* Dates that already have a schedule — highlighted in red */
	.sched-cal-day.has-schedule {
		background: rgba(239, 68, 68, 0.15);
		color: #b91c1c;
		font-weight: 700;
		box-shadow: inset 0 0 0 1px rgba(239, 68, 68, 0.4);
	}
	.sched-cal-day.has-schedule:hover {
		background: rgba(239, 68, 68, 0.28);
	}

	.sched-cal-day.selected {
		background: #475569 !important;
		color: #ffffff !important;
		box-shadow: none;
	}

	.sched-cal-footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-top: 8px;
		padding-top: 8px;
		border-top: 1px solid rgba(226, 232, 240, 0.9);
	}

	.sched-cal-today,
	.sched-cal-clear-date {
		background: none;
		border: none;
		font-size: 0.7rem;
		font-weight: 600;
		cursor: pointer;
		padding: 2px 4px;
	}
	.sched-cal-today {
		color: #475569;
	}
	.sched-cal-clear-date {
		color: #dc2626;
	}

	.sched-filter-clear {
		flex-shrink: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(241, 245, 249, 0.9);
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 8px;
		color: #64748b;
		cursor: pointer;
		transition: all 0.15s;
	}

	.sched-filter-clear:hover {
		background: rgba(254, 226, 226, 0.9);
		border-color: rgba(252, 165, 165, 0.9);
		color: #dc2626;
	}

	.sched-selected-vendor {
		display: flex;
		align-items: center;
		justify-content: space-between;
		background: rgba(241, 245, 249, 0.9);
		border: 1px solid rgba(100,116,139,0.35);
		border-radius: 8px;
		padding: 9px 12px;
		color: #334155;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.sched-selected-vendor button {
		background: none;
		border: none;
		color: #94a3b8;
		cursor: pointer;
		font-size: 0.8rem;
	}

	.sched-selected-vendor button:hover {
		color: #ef4444;
	}

	.sched-vendor-dropdown {
		position: static;
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(12px);
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 10px;
		z-index: 100;
		max-height: 220px;
		overflow-y: auto;
		box-shadow: 0 4px 12px rgba(0,0,0,0.08);
		margin-top: 6px;
	}

	.sched-vendor-option {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		padding: 10px 14px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(226, 232, 240, 0.7);
		color: #1e293b;
		cursor: pointer;
		text-align: left;
		font-size: 0.83rem;
		transition: background 0.15s;
	}

	.sched-vendor-option:last-child {
		border-bottom: none;
	}

	.sched-vendor-option:hover {
		background: rgba(241, 245, 249, 0.8);
	}

	.sched-vendor-option .vendor-name {
		font-weight: 600;
		color: #1e293b;
	}

	.sched-vendor-option .vendor-id {
		color: #94a3b8;
		font-size: 0.75rem;
	}

	.sched-no-results {
		padding: 10px 12px;
		color: #94a3b8;
		font-size: 0.83rem;
		background: rgba(255,255,255,0.8);
		border: 1px solid rgba(203,213,225,0.7);
		border-radius: 8px;
		text-align: center;
		margin-top: 4px;
	}

	.sched-form-actions {
		display: flex;
		gap: 8px;
		justify-content: flex-end;
		padding-top: 4px;
	}

	.sched-cancel-btn {
		background: rgba(241, 245, 249, 0.9);
		color: #64748b;
		border: 1px solid rgba(203, 213, 225, 0.7);
		padding: 8px 18px;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.sched-cancel-btn:hover {
		background: #e2e8f0;
		color: #334155;
	}

	.sched-save-btn {
		background: linear-gradient(135deg, #475569, #64748b);
		color: #fff;
		border: none;
		padding: 8px 22px;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 600;
		box-shadow: 0 2px 8px rgba(100,116,139,0.3);
		transition: all 0.2s;
	}

	.sched-save-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
		box-shadow: none;
	}

	.sched-save-btn:not(:disabled):hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 14px rgba(100,116,139,0.4);
	}

	.sched-loading, .sched-empty {
		text-align: center;
		color: #94a3b8;
		font-size: 0.875rem;
		padding: 28px 0;
	}

	.sched-delete-btn {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 0.85rem;
		font-weight: 700;
		color: #ef4444;
		opacity: 0.6;
		transition: opacity 0.2s;
		padding: 2px 6px;
		border-radius: 4px;
	}

	.sched-delete-btn:hover {
		opacity: 1;
		background: rgba(239, 68, 68, 0.1);
	}

	/* Schedules table */
	.sched-table-wrap {
		overflow-x: auto;
		border-radius: 10px;
		border: 1px solid rgba(203, 213, 225, 0.7);
		background: rgba(255,255,255,0.7);
	}

	.sched-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.83rem;
	}

	.sched-table thead tr {
		background: rgba(241, 245, 249, 0.8);
		border-bottom: 1px solid rgba(203, 213, 225, 0.7);
	}

	.sched-table th {
		padding: 9px 12px;
		text-align: left;
		font-weight: 600;
		color: #475569;
		font-size: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		white-space: nowrap;
		border-right: 1px solid rgba(203, 213, 225, 0.8);
	}

	.sched-table th:last-child,
	.sched-table td:last-child {
		border-right: none;
	}

	.sched-table tbody tr {
		border-bottom: 1px solid rgba(226, 232, 240, 0.6);
		transition: background 0.15s;
	}

	.sched-table tbody tr:last-child {
		border-bottom: none;
	}

	.sched-table tbody tr:hover {
		background: rgba(241, 245, 249, 0.5);
	}

	.sched-table td {
		padding: 9px 12px;
		color: #1e293b;
		vertical-align: middle;
		border-right: 1px solid rgba(226, 232, 240, 0.9);
	}

	/* Branch name on the first line, its location on a second, quieter one */
	.sched-col-branch {
		white-space: nowrap;
		line-height: 1.25;
	}

	.sched-col-branch .branch-name {
		display: block;
		font-weight: 600;
		color: #475569;
		font-size: 0.78rem;
	}

	.sched-col-branch .branch-location {
		display: block;
		color: #94a3b8;
		font-size: 0.68rem;
		font-weight: 500;
	}

	.sched-col-date {
		white-space: nowrap;
		font-weight: 600;
		color: #475569;
		font-size: 0.8rem;
	}

	.sched-col-name {
		font-weight: 500;
		max-width: 160px;
	}

	.sched-col-amount {
		white-space: nowrap;
		font-weight: 700;
		color: #059669;
	}

	/* Saudi Riyal glyph served from the app icons table */
	.currency-icon {
		height: 0.72em;
		width: auto;
		display: inline-block;
		vertical-align: baseline;
	}

	.sched-col-notes {
		color: #64748b;
		font-size: 0.78rem;
		max-width: 120px;
	}

	/* ===== Mobile ===== */
	.sched-section.mobile {
		height: auto;
	}

	.sched-section.mobile .sched-section-header {
		flex-direction: column;
		align-items: stretch;
		gap: 8px;
		padding: 10px 12px;
	}

	.sched-section.mobile .sched-section-title {
		font-size: 0.85rem;
	}

	.sched-section.mobile .sched-branch-select {
		max-width: 100%;
		width: 100%;
	}

	.sched-section.mobile .sched-tab {
		padding: 10px 6px;
		font-size: 0.82rem;
	}

	.sched-section.mobile .sched-section-body {
		overflow-y: visible;
		padding: 10px;
	}

	/* Search, total and date filter stack into rows that fit a phone */
	.sched-section.mobile .sched-filter-row {
		flex-wrap: wrap;
	}

	.sched-section.mobile .sched-filter-search {
		flex: 1 1 100%;
	}

	.sched-section.mobile .sched-total-chip {
		flex: 1 1 auto;
		justify-content: center;
	}

	.sched-section.mobile .sched-date-filter-wrap,
	.sched-section.mobile .sched-filter-date-btn {
		flex: 1 1 auto;
		width: auto;
		min-width: 130px;
	}

	/* Keep the calendar inside the viewport rather than off the right edge */
	.sched-section.mobile .sched-cal-popup {
		right: auto;
		left: 0;
		width: min(240px, calc(100vw - 48px));
	}

	.sched-section.mobile .sched-form {
		padding: 12px;
		border-radius: 12px;
	}

	/* The table keeps its own horizontal scroll; only the density changes */
	.sched-section.mobile .sched-table {
		font-size: 0.78rem;
	}

	.sched-section.mobile .sched-table th,
	.sched-section.mobile .sched-table td {
		padding: 7px 9px;
	}

	.sched-section.mobile .sched-col-name,
	.sched-section.mobile .sched-col-notes {
		max-width: 140px;
	}
</style>
