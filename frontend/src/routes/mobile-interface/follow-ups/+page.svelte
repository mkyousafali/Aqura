<script lang="ts">
	import { _ as t, currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';

	let activeTab: 'po' | 'other' | 'mytasks' = 'mytasks';

	// PO state
	let showCreateModal = false;
	let branches: any[] = [];
	let selectedBranchId = '';
	let branchesLoading = false;
	let vendors: any[] = [];
	let filteredVendors: any[] = [];
	let vendorSearchQuery = '';
	let selectedVendor: any = null;
	let vendorsLoading = false;
	let paymentMode = '';
	let creditPeriod = '';
	let poAmount = '';
	let expectedDeliveryDate = '';
	let salesmanName = '';
	let salesmanContact = '';
	let saving = false;
	let saveError = '';
	let records: any[] = [];
	let recordsLoading = false;

	// Other state
	let showOtherModal = false;
	let otherRecords: any[] = [];
	let otherRecordsLoading = false;
	let otherSaving = false;
	let otherError = '';
	let otherBranchId = '';
	let otherDescription = '';
	let otherScheduleType = '';
	let otherRecurrenceType = '';
	let otherTime = '';
	let otherDayOfWeek = '';
	let otherDayOfMonth = '';
	let otherMonth = '';
	let otherStartMonth = '';
	let otherUsers: any[] = [];
	let otherFilteredUsers: any[] = [];
	let otherUserSearch = '';
	let otherUsersLoading = false;
	let otherSelectedUser: any = null;

	// Occurrences
	let occurrences: any[] = [];
	let occurrencesLoading = false;

	// My Tasks
	let myTasks: any[] = [];
	let myTasksLoading = false;
	let showMyTaskModal = false;
	let myTaskSaving = false;
	let myTaskError = '';
	let myTaskTitle = '';
	let myTaskDescription = '';
	let myTaskTimeline = 'no_timeline';
	let myTaskDueDate = '';
	let myTaskDueTime = '';
	let myTaskRecurrenceType = '';
	let myTaskDayOfWeek = '';
	let myTaskDayOfMonth = '';
	let myTaskMonth = '';
	let myTaskStartMonth = '';

	const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
	const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

	$: if (vendorSearchQuery !== undefined) filterVendors();
	$: if (otherUserSearch !== undefined) filterOtherUsers();

	function filterVendors() {
		if (!vendorSearchQuery.trim()) filteredVendors = vendors;
		else {
			const q = vendorSearchQuery.toLowerCase();
			filteredVendors = vendors.filter(v =>
				(v.erp_vendor_id && v.erp_vendor_id.toString().includes(q)) ||
				(v.vendor_name && v.vendor_name.toLowerCase().includes(q))
			);
		}
	}

	function filterOtherUsers() {
		if (!otherUserSearch.trim()) otherFilteredUsers = otherUsers;
		else {
			const q = otherUserSearch.toLowerCase();
			otherFilteredUsers = otherUsers.filter(u => (u.name_en && u.name_en.toLowerCase().includes(q)) || (u.id && u.id.toLowerCase().includes(q)));
		}
	}

	onMount(() => {
		loadRecords();
		loadOtherRecords();
		loadOccurrences();
		loadMyTasks();
	});

	// --- PO functions ---
	async function loadBranches() {
		branchesLoading = true;
		try {
			const { data, error } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').eq('is_active', true).order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (err: any) { console.error(err); } finally { branchesLoading = false; }
	}

	async function loadVendors() {
		if (!selectedBranchId) { vendors = []; filteredVendors = []; return; }
		vendorsLoading = true;
		try {
			const { data, error } = await supabase.from('vendors').select('erp_vendor_id, vendor_name, salesman_name, place').or(`branch_id.eq.${selectedBranchId},branch_id.is.null`).eq('status', 'Active').order('vendor_name').limit(10000);
			if (error) throw error;
			vendors = data || []; filteredVendors = vendors;
		} catch (err: any) { console.error(err); } finally { vendorsLoading = false; }
	}

	async function loadRecords() {
		recordsLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_my_action_followup_po_records', { p_user_id: $currentUser?.id });
			if (error) throw error;
			if (data?.success) records = data.data || [];
		} catch (err: any) { console.error(err); } finally { recordsLoading = false; }
	}

	function openCreateModal() {
		showCreateModal = true; selectedBranchId = ''; selectedVendor = null; vendorSearchQuery = '';
		vendors = []; filteredVendors = []; paymentMode = ''; creditPeriod = ''; poAmount = '';
		expectedDeliveryDate = ''; salesmanName = ''; salesmanContact = ''; saveError = '';
		loadBranches();
	}

	function getSelectedBranchName() {
		const b = branches.find(br => br.id.toString() === selectedBranchId);
		return b ? ($currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en) : '';
	}
	function getSelectedBranchLocation() {
		const b = branches.find(br => br.id.toString() === selectedBranchId);
		return b ? ($currentLocale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || '')) : '';
	}

	async function handleSave() {
		saveError = '';
		if (!selectedBranchId || !selectedVendor || !paymentMode || !poAmount || !expectedDeliveryDate) { saveError = 'Please fill all required fields.'; return; }
		if (paymentMode === 'credit' && (!creditPeriod || parseInt(creditPeriod) <= 0)) { saveError = 'Credit period required.'; return; }
		saving = true;
		try {
			const { data, error } = await supabase.rpc('create_action_followup_po', {
				p_branch_id: parseInt(selectedBranchId), p_branch_name: getSelectedBranchName(),
				p_vendor_erp_id: selectedVendor.erp_vendor_id.toString(), p_vendor_name: selectedVendor.vendor_name,
				p_payment_mode: paymentMode, p_credit_period: paymentMode === 'credit' ? parseInt(creditPeriod) : null,
				p_po_amount: parseFloat(poAmount), p_expected_delivery_date: expectedDeliveryDate,
				p_salesman_name: salesmanName.trim() || null, p_salesman_contact: salesmanContact.trim() || null,
				p_user_id: $currentUser?.id || null, p_branch_location: getSelectedBranchLocation() || null
			});
			if (error) throw error;
			if (data && !data.success) { saveError = data.error; return; }
			showCreateModal = false; await loadRecords();
		} catch (err: any) { saveError = err.message; } finally { saving = false; }
	}

	// --- Other functions ---
	async function loadOtherRecords() {
		otherRecordsLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_my_action_followup_other_records', { p_user_id: $currentUser?.id });
			if (error) throw error;
			if (data?.success) otherRecords = data.data || [];
		} catch (err: any) { console.error(err); } finally { otherRecordsLoading = false; }
	}

	async function loadOtherUsers() {
		if (!otherBranchId) { otherUsers = []; otherFilteredUsers = []; return; }
		otherUsersLoading = true;
		try {
			const { data, error } = await supabase.from('hr_employee_master').select('user_id, id, name_en').eq('current_branch_id', parseInt(otherBranchId)).in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job']).order('name_en');
			if (error) throw error;
			otherUsers = data || []; otherFilteredUsers = otherUsers;
		} catch (err: any) { console.error(err); } finally { otherUsersLoading = false; }
	}

	async function loadOccurrences() {
		occurrencesLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_my_followup_occurrences', { p_user_id: $currentUser?.id });
			if (error) throw error;
			if (data?.success) occurrences = data.data || [];
		} catch (err: any) { console.error(err); } finally { occurrencesLoading = false; }
	}

	function openOtherModal() {
		showOtherModal = true; otherBranchId = ''; otherDescription = ''; otherScheduleType = '';
		otherRecurrenceType = ''; otherTime = ''; otherDayOfWeek = ''; otherDayOfMonth = '';
		otherMonth = ''; otherStartMonth = ''; otherSelectedUser = null; otherUserSearch = '';
		otherUsers = []; otherFilteredUsers = []; otherError = ''; loadBranches();
	}

	async function handleOtherSave() {
		otherError = '';
		if (!otherBranchId || !otherDescription.trim() || !otherScheduleType) { otherError = 'Fill required fields.'; return; }
		otherSaving = true;
		try {
			const { data, error } = await supabase.rpc('create_action_followup_other', {
				p_branch_id: parseInt(otherBranchId), p_branch_name: getSelectedBranchName(),
				p_branch_location: getSelectedBranchLocation() || null, p_description: otherDescription.trim(),
				p_schedule_type: otherScheduleType,
				p_recurrence_type: otherScheduleType === 'recurring' ? otherRecurrenceType : null,
				p_recurrence_time: otherTime || null,
				p_recurrence_day_of_week: otherDayOfWeek ? parseInt(otherDayOfWeek) : null,
				p_recurrence_day_of_month: otherDayOfMonth ? parseInt(otherDayOfMonth) : null,
				p_recurrence_month: otherMonth ? parseInt(otherMonth) : null,
				p_recurrence_start_month: otherStartMonth ? parseInt(otherStartMonth) : null,
				p_related_user_id: otherSelectedUser?.user_id || null,
				p_related_user_name: otherSelectedUser?.name_en || null,
				p_user_id: $currentUser?.id || null
			});
			if (error) throw error;
			if (data && !data.success) { otherError = data.error; return; }
			showOtherModal = false; await loadOtherRecords();
		} catch (err: any) { otherError = err.message; } finally { otherSaving = false; }
	}

	async function markPoFinished(id: number) {
		await supabase.rpc('finish_action_followup_po', { p_po_id: id }); await loadRecords();
	}

	async function markOtherFinished(id: number) {
		await supabase.rpc('finish_action_followup_other', { p_id: id }); await loadOtherRecords();
	}
	async function finishOccurrence(id: number) {
		await supabase.rpc('finish_followup_occurrence', { p_id: id }); await loadOccurrences();
	}

	// --- My Tasks functions ---
	async function loadMyTasks() {
		if (!$currentUser?.id) return;
		myTasksLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_my_followup_tasks', { p_user_id: $currentUser.id });
			if (error) throw error;
			if (data?.success) myTasks = data.data || [];
		} catch (err: any) { console.error(err); } finally { myTasksLoading = false; }
	}

	function openMyTaskModal() {
		showMyTaskModal = true; myTaskTitle = ''; myTaskDescription = ''; myTaskTimeline = 'no_timeline';
		myTaskDueDate = ''; myTaskDueTime = ''; myTaskRecurrenceType = ''; myTaskDayOfWeek = '';
		myTaskDayOfMonth = ''; myTaskMonth = ''; myTaskStartMonth = ''; myTaskError = '';
	}

	async function handleMyTaskSave() {
		myTaskError = '';
		if (!myTaskTitle.trim()) { myTaskError = 'Title required.'; return; }
		myTaskSaving = true;
		try {
			const { data, error } = await supabase.rpc('create_my_task', {
				p_user_id: $currentUser?.id, p_title: myTaskTitle.trim(), p_description: myTaskDescription.trim() || null,
				p_timeline_type: myTaskTimeline, p_due_date: myTaskTimeline === 'with_timeline_single' ? myTaskDueDate : null,
				p_due_time: myTaskDueTime || null,
				p_recurrence_type: myTaskTimeline === 'with_timeline_recurring' ? myTaskRecurrenceType : null,
				p_recurrence_day_of_week: myTaskDayOfWeek ? parseInt(myTaskDayOfWeek) : null,
				p_recurrence_day_of_month: myTaskDayOfMonth ? parseInt(myTaskDayOfMonth) : null,
				p_recurrence_month: myTaskMonth ? parseInt(myTaskMonth) : null,
				p_recurrence_start_month: myTaskStartMonth ? parseInt(myTaskStartMonth) : null
			});
			if (error) throw error;
			showMyTaskModal = false; await loadMyTasks();
		} catch (err: any) { myTaskError = err.message; } finally { myTaskSaving = false; }
	}

	async function finishMyTask(id: number) { await supabase.rpc('finish_my_task', { p_id: id, p_user_id: $currentUser?.id }); await loadMyTasks(); }
	async function unfinishMyTask(id: number) { await supabase.rpc('unfinish_my_task', { p_id: id, p_user_id: $currentUser?.id }); await loadMyTasks(); }
	async function deleteMyTask(id: number) { await supabase.rpc('delete_my_task', { p_id: id, p_user_id: $currentUser?.id }); await loadMyTasks(); }

	function formatDate(d: string) { return d ? new Date(d).toLocaleDateString() : '—'; }
	function formatDateTime(d: string) { return d ? new Date(d).toLocaleString() : '—'; }

	function formatRecurrence(rec: any): string {
		if (rec.schedule_type === 'single') return 'Single';
		let str = rec.recurrence_type || '';
		if (rec.recurrence_time) str += ' @ ' + rec.recurrence_time.substring(0, 5);
		return str;
	}

	function formatMyTaskSchedule(task: any): string {
		if (task.timeline_type === 'no_timeline') return 'No Timeline';
		if (task.timeline_type === 'with_timeline_single') return (task.due_date || '') + (task.due_time ? ' @ ' + task.due_time.substring(0, 5) : '');
		return task.recurrence_type || '';
	}

	function getDeliveryStatus(rec: any): { text: string; cls: string } {
		if (rec.is_finished) return { text: $currentLocale === 'ar' ? 'تم التسليم' : 'Delivered', cls: 'delivery-done' };
		if (!rec.expected_delivery_date) return { text: '—', cls: '' };
		const today = new Date(); today.setHours(0, 0, 0, 0);
		const due = new Date(rec.expected_delivery_date); due.setHours(0, 0, 0, 0);
		const diff = Math.ceil((due.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
		if (diff < 0) return { text: $currentLocale === 'ar' ? 'لم يتم التسليم بعد' : 'Not Delivered Yet', cls: 'delivery-overdue' };
		if (diff === 0) return { text: $currentLocale === 'ar' ? 'مستحق اليوم' : 'Due Today', cls: 'delivery-today' };
		return { text: diff + ($currentLocale === 'ar' ? ' يوم متبقي' : ' days remaining'), cls: 'delivery-upcoming' };
	}
</script>

<svelte:head><title>Follow-Ups - Aqura Mobile</title></svelte:head>

<div class="followups-mobile">
	<!-- Tabs -->
	<div class="mobile-tabs">
		<button class="mtab" class:active={activeTab === 'po'} on:click={() => activeTab = 'po'}>PO</button>
		<button class="mtab" class:active={activeTab === 'other'} on:click={() => activeTab = 'other'}>{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</button>
		<button class="mtab" class:active={activeTab === 'mytasks'} on:click={() => activeTab = 'mytasks'}>{$currentLocale === 'ar' ? 'مهامي' : 'My Tasks'}</button>
	</div>

	<!-- PO Tab -->
	{#if activeTab === 'po'}
		<div class="tab-body">
			<button class="fab-btn" on:click={openCreateModal}>+</button>
			{#if recordsLoading}
				<p class="loading-text">Loading...</p>
			{:else if records.filter(r => !r.is_finished).length === 0}
				<p class="empty-text">No PO follow-ups yet.</p>
			{:else}
				{#each records.filter(r => !r.is_finished) as rec}
					<div class="card">
						<div class="card-top">
							{#if rec.approval_status === 'approved'}
								<input type="checkbox" class="check" on:change={() => markPoFinished(rec.id)} title="Mark as delivered" />
							{/if}
							<span class="card-vendor">{rec.vendor_name}</span>
							<span class="card-amount">{parseFloat(rec.po_amount).toFixed(2)}</span>
						</div>
						<div class="card-mid">
							<span>{rec.branch_name}</span>
							<span class="badge" class:pending={rec.approval_status === 'pending'} class:approved={rec.approval_status === 'approved'} class:rejected={rec.approval_status === 'rejected'}>{rec.approval_status}</span>
						</div>
						<div class="card-bot">
							<span class="delivery-status {getDeliveryStatus(rec).cls}">{getDeliveryStatus(rec).text}</span>
							<span class="delivery-date-sub">{formatDate(rec.expected_delivery_date)}</span>
						</div>
					</div>
				{/each}
			{/if}
		</div>
	{/if}

	<!-- Other Tab -->
	{#if activeTab === 'other'}
		<div class="tab-body">
			<button class="fab-btn" on:click={openOtherModal}>+</button>
			{#if otherRecordsLoading}
				<p class="loading-text">Loading...</p>
			{:else if otherRecords.filter(r => !r.is_finished && r.schedule_type === 'single').length === 0 && occurrences.filter(o => !o.is_finished).length === 0}
				<p class="empty-text">No follow-ups yet.</p>
			{:else}
				{#each otherRecords.filter(r => !r.is_finished && r.schedule_type === 'single') as rec}
					<div class="card">
						<div class="card-top">
							<span class="card-desc">{rec.description}</span>
							<input type="checkbox" class="check" on:change={() => markOtherFinished(rec.id)} />
						</div>
						<div class="card-mid"><span>{rec.branch_name}</span><span>{formatRecurrence(rec)}</span></div>
					</div>
				{/each}
				{#each occurrences.filter(o => !o.is_finished) as occ}
					<div class="card occ-card">
						<div class="card-top">
							<span class="card-desc">{occ.description}</span>
							<input type="checkbox" class="check" on:change={() => finishOccurrence(occ.id)} />
						</div>
						<div class="card-mid"><span>{occ.branch_name}</span><span>{occ.due_date}</span></div>
					</div>
				{/each}
			{/if}
		</div>
	{/if}

	<!-- My Tasks Tab -->
	{#if activeTab === 'mytasks'}
		<div class="tab-body">
			<button class="fab-btn" on:click={openMyTaskModal}>+</button>
			{#if myTasksLoading}
				<p class="loading-text">Loading...</p>
			{:else if myTasks.filter(t => !t.is_finished).length === 0}
				<p class="empty-text">No tasks yet. Add one!</p>
			{:else}
				{#each myTasks.filter(t => !t.is_finished) as task}
					<div class="card task-card">
						<input type="checkbox" class="check" on:change={() => finishMyTask(task.id)} />
						<div class="task-info">
							<span class="task-title">{task.title}</span>
							{#if task.description}<span class="task-desc">{task.description}</span>{/if}
							<span class="task-sched">{formatMyTaskSchedule(task)}</span>
						</div>
						<button class="del-btn" on:click={() => deleteMyTask(task.id)}>🗑</button>
					</div>
				{/each}
			{/if}
			{#if myTasks.filter(t => t.is_finished).length > 0}
				<details class="done-section">
					<summary>Completed ({myTasks.filter(t => t.is_finished).length})</summary>
					{#each myTasks.filter(t => t.is_finished) as task}
						<div class="card task-card done">
							<input type="checkbox" class="check" checked on:change={() => unfinishMyTask(task.id)} />
							<div class="task-info"><span class="task-title">{task.title}</span></div>
						</div>
					{/each}
				</details>
			{/if}
		</div>
	{/if}
</div>

<!-- PO Modal -->
{#if showCreateModal}
<div class="modal-bg" on:click|self={() => showCreateModal = false}>
	<div class="modal">
		<h3>New PO Follow-Up</h3>
		<select bind:value={selectedBranchId} on:change={() => { selectedVendor = null; if (selectedBranchId) loadVendors(); }} class="input">
			<option value="">Select Branch</option>
			{#each branches as b}<option value={b.id.toString()}>{b.name_en}</option>{/each}
		</select>
		{#if selectedVendor}
			<div class="selected-item">{selectedVendor.vendor_name} <button on:click={() => selectedVendor = null}>×</button></div>
		{:else if selectedBranchId}
			<input bind:value={vendorSearchQuery} placeholder="Search vendor..." class="input" />
			<div class="list">{#each filteredVendors.slice(0, 20) as v}<button class="list-item" on:click={() => selectedVendor = v}>{v.erp_vendor_id} - {v.vendor_name}</button>{/each}</div>
		{/if}
		<select bind:value={paymentMode} class="input">
			<option value="">Payment Mode</option><option value="spot">Spot</option><option value="credit">Credit</option>
		</select>
		{#if paymentMode === 'credit'}<input bind:value={creditPeriod} type="number" placeholder="Credit period (days)" class="input" />{/if}
		<input bind:value={poAmount} type="number" placeholder="PO Amount" class="input" />
		<input bind:value={salesmanName} placeholder="Salesman Name" class="input" />
		<input bind:value={salesmanContact} placeholder="Contact Number" class="input" />
		<input bind:value={expectedDeliveryDate} type="date" class="input" />
		{#if saveError}<p class="error">{saveError}</p>{/if}
		<div class="modal-actions">
			<button class="btn-cancel" on:click={() => showCreateModal = false}>Cancel</button>
			<button class="btn-save" on:click={handleSave} disabled={saving}>{saving ? '...' : 'Save'}</button>
		</div>
	</div>
</div>
{/if}

<!-- Other Modal -->
{#if showOtherModal}
<div class="modal-bg" on:click|self={() => showOtherModal = false}>
	<div class="modal">
		<h3>New Follow-Up</h3>
		<select bind:value={otherBranchId} on:change={() => { if (otherBranchId) loadOtherUsers(); }} class="input">
			<option value="">Select Branch</option>
			{#each branches as b}<option value={b.id.toString()}>{b.name_en}</option>{/each}
		</select>
		<textarea bind:value={otherDescription} placeholder="Description" rows="3" class="input"></textarea>
		<select bind:value={otherScheduleType} class="input">
			<option value="">Schedule Type</option><option value="single">Single</option><option value="recurring">Recurring</option>
		</select>
		{#if otherScheduleType === 'recurring'}
			<select bind:value={otherRecurrenceType} class="input">
				<option value="">Recurrence</option><option value="daily">Daily</option><option value="weekly">Weekly</option><option value="monthly">Monthly</option>
			</select>
			{#if otherRecurrenceType === 'weekly'}<select bind:value={otherDayOfWeek} class="input"><option value="">Day</option>{#each dayNames as d, i}<option value={i.toString()}>{d}</option>{/each}</select>{/if}
			{#if otherRecurrenceType === 'monthly'}<select bind:value={otherDayOfMonth} class="input"><option value="">Day of month</option>{#each Array.from({length:31},(_,i)=>i+1) as d}<option value={d.toString()}>{d}</option>{/each}</select>{/if}
			<input bind:value={otherTime} type="time" class="input" />
		{/if}
		{#if otherSelectedUser}
			<div class="selected-item">{otherSelectedUser.name_en} <button on:click={() => otherSelectedUser = null}>×</button></div>
		{:else if otherBranchId}
			<input bind:value={otherUserSearch} placeholder="Search user..." class="input" />
			<div class="list">{#each otherFilteredUsers.slice(0, 15) as u}<button class="list-item" on:click={() => otherSelectedUser = u}>{u.id} - {u.name_en}</button>{/each}</div>
		{/if}
		{#if otherError}<p class="error">{otherError}</p>{/if}
		<div class="modal-actions">
			<button class="btn-cancel" on:click={() => showOtherModal = false}>Cancel</button>
			<button class="btn-save" on:click={handleOtherSave} disabled={otherSaving}>{otherSaving ? '...' : 'Save'}</button>
		</div>
	</div>
</div>
{/if}

<!-- My Task Modal -->
{#if showMyTaskModal}
<div class="modal-bg" on:click|self={() => showMyTaskModal = false}>
	<div class="modal">
		<h3>New Task</h3>
		<input bind:value={myTaskTitle} placeholder="Task title" class="input" />
		<textarea bind:value={myTaskDescription} placeholder="Notes (optional)" rows="2" class="input"></textarea>
		<select bind:value={myTaskTimeline} class="input">
			<option value="no_timeline">No Timeline</option><option value="with_timeline_single">With Date</option><option value="with_timeline_recurring">Recurring</option>
		</select>
		{#if myTaskTimeline === 'with_timeline_single'}
			<input bind:value={myTaskDueDate} type="date" class="input" />
			<input bind:value={myTaskDueTime} type="time" class="input" />
		{/if}
		{#if myTaskTimeline === 'with_timeline_recurring'}
			<select bind:value={myTaskRecurrenceType} class="input">
				<option value="">Recurrence</option><option value="daily">Daily</option><option value="weekly">Weekly</option><option value="monthly">Monthly</option>
			</select>
			{#if myTaskRecurrenceType === 'weekly'}<select bind:value={myTaskDayOfWeek} class="input"><option value="">Day</option>{#each dayNames as d, i}<option value={i.toString()}>{d}</option>{/each}</select>{/if}
			{#if myTaskRecurrenceType === 'monthly'}<select bind:value={myTaskDayOfMonth} class="input"><option value="">Day</option>{#each Array.from({length:31},(_,i)=>i+1) as d}<option value={d.toString()}>{d}</option>{/each}</select>{/if}
			<input bind:value={myTaskDueTime} type="time" class="input" />
		{/if}
		{#if myTaskError}<p class="error">{myTaskError}</p>{/if}
		<div class="modal-actions">
			<button class="btn-cancel" on:click={() => showMyTaskModal = false}>Cancel</button>
			<button class="btn-save" on:click={handleMyTaskSave} disabled={myTaskSaving}>{myTaskSaving ? '...' : 'Save'}</button>
		</div>
	</div>
</div>
{/if}

<style>
	.followups-mobile { padding: 0; min-height: 100%; display: flex; flex-direction: column; }
	.mobile-tabs { display: flex; position: sticky; top: 0; z-index: 10; background: white; border-bottom: 1px solid #e5e7eb; padding: 8px 8px 0; gap: 6px; }
	.mtab { flex: 1; padding: 10px 0; border: 2px solid #e5e7eb; background: #f9fafb; font-size: 14px; font-weight: 500; color: #6b7280; cursor: pointer; border-radius: 10px 10px 0 0; transition: all 0.2s; }
	.mtab.active { font-weight: 600; }
	.mtab:nth-child(1) { border-color: rgba(59,130,246,0.3); }
	.mtab:nth-child(2) { border-color: rgba(139,92,246,0.3); }
	.mtab:nth-child(3) { border-color: rgba(16,185,129,0.3); }
	.mtab:nth-child(1).active { color: #3b82f6; border-color: #3b82f6; background: rgba(59,130,246,0.1); }
	.mtab:nth-child(2).active { color: #8b5cf6; border-color: #8b5cf6; background: rgba(139,92,246,0.1); }
	.mtab:nth-child(3).active { color: #10b981; border-color: #10b981; background: rgba(16,185,129,0.1); }
	.tab-body { flex: 1; padding: 16px; padding-bottom: 80px; position: relative; }
	.fab-btn { position: fixed; bottom: 80px; right: 20px; width: 52px; height: 52px; border-radius: 50%; background: #3b82f6; color: white; border: none; font-size: 28px; box-shadow: 0 4px 12px rgba(59,130,246,0.4); z-index: 50; cursor: pointer; }
	.loading-text, .empty-text { text-align: center; color: #9ca3af; padding: 40px 0; }
	.card { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 12px; margin-bottom: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
	.occ-card { border-left: 3px solid #3b82f6; }
	.card-top { display: flex; justify-content: space-between; align-items: center; }
	.card-vendor { font-weight: 600; font-size: 14px; color: #1f2937; flex: 1; }
	.check + .card-vendor { margin-left: 8px; }
	.card-amount { font-weight: 700; color: #1f2937; }
	.card-desc { font-size: 14px; color: #1f2937; flex: 1; }
	.card-mid { display: flex; justify-content: space-between; font-size: 12px; color: #6b7280; margin-top: 4px; }
	.card-bot { font-size: 11px; color: #9ca3af; margin-top: 4px; display: flex; justify-content: space-between; align-items: center; }
	.delivery-status { font-size: 11px; font-weight: 600; }
	.delivery-done { color: #16a34a; }
	.delivery-overdue { color: #dc2626; }
	.delivery-today { color: #d97706; }
	.delivery-upcoming { color: #2563eb; }
	.delivery-date-sub { font-size: 10px; color: #9ca3af; }
	.badge { font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 10px; text-transform: uppercase; }
	.badge.pending { background: #fef3c7; color: #92400e; }
	.badge.approved { background: #dcfce7; color: #166534; }
	.badge.rejected { background: #fee2e2; color: #991b1b; }
	.check { width: 20px; height: 20px; min-width: 20px; accent-color: #3b82f6; cursor: pointer; border: 2px solid #3b82f6; border-radius: 4px; background: white; -webkit-appearance: none; appearance: none; }
	.check:checked { background: #3b82f6; background-image: url("data:image/svg+xml,%3csvg viewBox='0 0 16 16' fill='white' xmlns='http://www.w3.org/2000/svg'%3e%3cpath d='M12.207 4.793a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0l-2-2a1 1 0 011.414-1.414L6.5 9.086l4.293-4.293a1 1 0 011.414 0z'/%3e%3c/svg%3e"); background-repeat: no-repeat; background-position: center; }
	.task-card { display: flex; align-items: flex-start; gap: 10px; }
	.task-card.done { opacity: 0.5; }
	.task-card.done .task-title { text-decoration: line-through; }
	.task-info { flex: 1; display: flex; flex-direction: column; gap: 2px; }
	.task-title { font-size: 14px; font-weight: 600; color: #1f2937; }
	.task-desc { font-size: 12px; color: #6b7280; }
	.task-sched { font-size: 11px; color: #3b82f6; }
	.del-btn { border: none; background: none; font-size: 16px; opacity: 0.4; cursor: pointer; }
	.done-section { margin-top: 16px; }
	.done-section summary { font-size: 13px; color: #6b7280; cursor: pointer; padding: 8px 0; }
	/* Modals */
	.modal-bg { position: fixed; inset: 0; background: rgba(0,0,0,0.4); display: flex; align-items: flex-end; z-index: 9999; }
	.modal { background: white; width: 100%; max-height: 85vh; overflow-y: auto; border-radius: 16px 16px 0 0; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
	.modal h3 { margin: 0 0 4px; font-size: 17px; }
	.input { padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; width: 100%; box-sizing: border-box; }
	textarea.input { resize: vertical; }
	.selected-item { display: flex; align-items: center; justify-content: space-between; padding: 8px 12px; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 8px; font-size: 13px; color: #166534; }
	.selected-item button { border: none; background: none; font-size: 18px; cursor: pointer; color: #166534; }
	.list { max-height: 120px; overflow-y: auto; border: 1px solid #e5e7eb; border-radius: 8px; }
	.list-item { display: block; width: 100%; padding: 8px 12px; border: none; background: none; text-align: left; font-size: 13px; cursor: pointer; border-bottom: 1px solid #f3f4f6; }
	.list-item:hover { background: #f0f9ff; }
	.error { color: #dc2626; font-size: 13px; margin: 0; padding: 8px; background: #fef2f2; border-radius: 6px; }
	.modal-actions { display: flex; gap: 10px; }
	.btn-cancel { flex: 1; padding: 10px; border: 1px solid #d1d5db; border-radius: 8px; background: white; font-size: 14px; cursor: pointer; }
	.btn-save { flex: 1; padding: 10px; border: none; border-radius: 8px; background: #3b82f6; color: white; font-size: 14px; font-weight: 600; cursor: pointer; }
	.btn-save:disabled { opacity: 0.5; }
</style>
