<script lang="ts">
	import { _ as t, currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';

	let activeTab: 'po' | 'other' | 'approvers' | 'finished' | 'mytasks' = 'po';

	// Modal state
	let showCreateModal = false;

	// Branch selection
	let branches: any[] = [];
	let selectedBranchId = '';
	let branchesLoading = false;

	// Vendor selection (same pattern as Start Receiving)
	let vendors: any[] = [];
	let filteredVendors: any[] = [];
	let vendorSearchQuery = '';
	let selectedVendor: any = null;
	let vendorsLoading = false;

	// Form fields
	let paymentMode = '';
	let creditPeriod = '';
	let poAmount = '';
	let expectedDeliveryDate = '';
	let salesmanName = '';
	let salesmanContact = '';

	// Save state
	let saving = false;
	let saveError = '';

	// Records
	let records: any[] = [];
	let recordsLoading = false;

	// --- Other tab state ---
	let showOtherModal = false;
	let otherRecords: any[] = [];
	let otherRecordsLoading = false;
	let otherSaving = false;
	let otherError = '';

	// Other form
	let otherBranchId = '';
	let otherDescription = '';
	let otherScheduleType = '';
	let otherRecurrenceType = '';
	let otherTime = '';
	let otherDayOfWeek = '';
	let otherDayOfMonth = '';
	let otherMonth = '';
	let otherStartMonth = '';
	let otherRelatedUserId = '';
	let otherRelatedUserName = '';

	// User search for Related User
	let otherUsers: any[] = [];
	let otherFilteredUsers: any[] = [];
	let otherUserSearch = '';
	let otherUsersLoading = false;
	let otherSelectedUser: any = null;

	// Occurrences
	let occurrences: any[] = [];
	let occurrencesLoading = false;
	let finishedItems: any[] = [];

	// --- My Tasks state ---
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

	// --- Approvers tab state ---
	let showApproverModal = false;
	let approvers: any[] = [];
	let approversLoading = false;
	let approverSaving = false;
	let approverError = '';
	let approverUserId = '';
	let approverUserName = '';
	let approverCanPo = true;
	let approverBranchPerm = 'all';
	let approverSelectedBranches: number[] = [];
	let approverUsers: any[] = [];
	let approverFilteredUsers: any[] = [];
	let approverUserSearch = '';
	let approverUsersLoading = false;
	let approverSelectedUser: any = null;

	// PO approval actions
	let showRejectModal = false;
	let rejectingPoId: number | null = null;
	let rejectReason = '';
	let approvalActioning = false;

	$: if (vendorSearchQuery !== undefined) filterVendors();

	$: finishedItems = [
		...records.filter(r => r.is_finished).map(r => ({ ...r, source: 'po', finished_sort: r.finished_at || r.updated_at })),
		...otherRecords.filter(r => r.is_finished).map(r => ({ ...r, source: 'other', finished_sort: r.finished_at || r.updated_at })),
		...occurrences.filter(o => o.is_finished).map(o => ({ ...o, source: 'occurrence', finished_sort: o.finished_at || o.created_at }))
	].sort((a, b) => new Date(b.finished_sort).getTime() - new Date(a.finished_sort).getTime());

	function filterVendors() {
		if (!vendorSearchQuery.trim()) {
			filteredVendors = vendors;
		} else {
			const q = vendorSearchQuery.toLowerCase();
			filteredVendors = vendors.filter(v =>
				(v.erp_vendor_id && v.erp_vendor_id.toString().includes(q)) ||
				(v.vendor_name && v.vendor_name.toLowerCase().includes(q)) ||
				(v.salesman_name && v.salesman_name.toLowerCase().includes(q)) ||
				(v.place && v.place.toLowerCase().includes(q))
			);
		}
	}

	onMount(() => {
		loadRecords();
		loadOtherRecords();
		loadOccurrences();
		loadApprovers();
		loadMyTasks();
	});

	// --- Other tab functions ---
	$: if (otherUserSearch !== undefined) filterOtherUsers();

	function filterOtherUsers() {
		if (!otherUserSearch.trim()) {
			otherFilteredUsers = otherUsers;
		} else {
			const q = otherUserSearch.toLowerCase();
			otherFilteredUsers = otherUsers.filter(u =>
				(u.name_en && u.name_en.toLowerCase().includes(q)) ||
				(u.id && u.id.toLowerCase().includes(q))
			);
		}
	}

	async function loadOtherRecords() {
		otherRecordsLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_action_followup_other_records');
			if (error) throw error;
			if (data?.success) otherRecords = data.data || [];
		} catch (err: any) {
			console.error('Error loading other records:', err);
		} finally {
			otherRecordsLoading = false;
		}
	}

	async function loadOtherUsers() {
		if (!otherBranchId) { otherUsers = []; otherFilteredUsers = []; return; }
		otherUsersLoading = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('user_id, id, name_en')
				.eq('current_branch_id', parseInt(otherBranchId))
				.in('employment_status', ['Job (With Finger)', 'Remote Job'])
				.order('name_en');
			if (error) throw error;
			otherUsers = data || [];
			otherFilteredUsers = otherUsers;
		} catch (err: any) {
			console.error('Error loading users:', err);
		} finally {
			otherUsersLoading = false;
		}
	}

	function openOtherModal() {
		showOtherModal = true;
		otherBranchId = '';
		otherDescription = '';
		otherScheduleType = '';
		otherRecurrenceType = '';
		otherTime = '';
		otherDayOfWeek = '';
		otherDayOfMonth = '';
		otherMonth = '';
		otherStartMonth = '';
		otherSelectedUser = null;
		otherUserSearch = '';
		otherUsers = [];
		otherFilteredUsers = [];
		otherError = '';
		loadBranches();
	}

	function closeOtherModal() { showOtherModal = false; }

	function handleOtherBranchChange() {
		otherSelectedUser = null;
		otherUserSearch = '';
		if (otherBranchId) loadOtherUsers();
		else { otherUsers = []; otherFilteredUsers = []; }
	}

	function selectOtherUser(u: any) {
		otherSelectedUser = u;
	}

	function clearOtherUser() {
		otherSelectedUser = null;
		otherUserSearch = '';
		otherFilteredUsers = otherUsers;
	}

	function getOtherBranchName(): string {
		const b = branches.find(br => br.id.toString() === otherBranchId);
		if (!b) return '';
		return $currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en;
	}

	function getOtherBranchLocation(): string {
		const b = branches.find(br => br.id.toString() === otherBranchId);
		if (!b) return '';
		return $currentLocale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || '');
	}

	async function handleOtherSave() {
		otherError = '';
		if (!otherBranchId) { otherError = $t('actionFollowUps.errBranch'); return; }
		if (!otherDescription.trim()) { otherError = $t('actionFollowUps.errDescription'); return; }
		if (!otherScheduleType) { otherError = $t('actionFollowUps.errScheduleType'); return; }
		if (otherScheduleType === 'recurring') {
			if (!otherRecurrenceType) { otherError = $t('actionFollowUps.errRecurrenceType'); return; }
			if (!otherTime) { otherError = $t('actionFollowUps.errTime'); return; }
			if (otherRecurrenceType === 'weekly' && !otherDayOfWeek) { otherError = $t('actionFollowUps.errDayOfWeek'); return; }
			if ((otherRecurrenceType === 'monthly' || otherRecurrenceType === 'quarterly' || otherRecurrenceType === 'every_6_months' || otherRecurrenceType === 'yearly') && !otherDayOfMonth) { otherError = $t('actionFollowUps.errDayOfMonth'); return; }
			if ((otherRecurrenceType === 'quarterly' || otherRecurrenceType === 'every_6_months' || otherRecurrenceType === 'yearly') && !otherMonth) { otherError = $t('actionFollowUps.errMonth'); return; }
		}

		otherSaving = true;
		try {
			const { data, error } = await supabase.rpc('create_action_followup_other', {
				p_branch_id: parseInt(otherBranchId),
				p_branch_name: getOtherBranchName(),
				p_branch_location: getOtherBranchLocation() || null,
				p_description: otherDescription.trim(),
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
			if (data && !data.success) { otherError = data.error || 'Unknown error'; return; }
			closeOtherModal();
			await loadOtherRecords();
		} catch (err: any) {
			otherError = err.message || 'Failed to save';
		} finally {
			otherSaving = false;
		}
	}

	async function markOtherFinished(id: number) {
		try {
			const { error } = await supabase.rpc('finish_action_followup_other', { p_id: id });
			if (error) throw error;
			await loadOtherRecords();
		} catch (err: any) { console.error('Error marking other finished:', err); }
	}

	async function unmarkOtherFinished(id: number) {
		try {
			const { error } = await supabase.rpc('unfinish_action_followup_other', { p_id: id });
			if (error) throw error;
			await loadOtherRecords();
		} catch (err: any) { console.error('Error unmarking other finished:', err); }
	}

	async function loadOccurrences() {
		occurrencesLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_followup_occurrences');
			if (error) throw error;
			if (data?.success) occurrences = data.data || [];
		} catch (err: any) { console.error('Error loading occurrences:', err); }
		finally { occurrencesLoading = false; }
	}

	async function finishOccurrence(id: number) {
		try {
			const { error } = await supabase.rpc('finish_followup_occurrence', { p_id: id });
			if (error) throw error;
			await loadOccurrences();
		} catch (err: any) { console.error('Error finishing occurrence:', err); }
	}

	async function unfinishOccurrence(id: number) {
		try {
			const { error } = await supabase.rpc('unfinish_followup_occurrence', { p_id: id });
			if (error) throw error;
			await loadOccurrences();
		} catch (err: any) { console.error('Error unfinishing occurrence:', err); }
	}

	// --- My Tasks functions ---
	async function loadMyTasks() {
		if (!$currentUser?.id) return;
		myTasksLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_my_followup_tasks', { p_user_id: $currentUser.id });
			if (error) throw error;
			if (data?.success) myTasks = data.data || [];
		} catch (err: any) { console.error('Error loading my tasks:', err); }
		finally { myTasksLoading = false; }
	}

	function openMyTaskModal() {
		showMyTaskModal = true;
		myTaskTitle = ''; myTaskDescription = ''; myTaskTimeline = 'no_timeline';
		myTaskDueDate = ''; myTaskDueTime = ''; myTaskRecurrenceType = '';
		myTaskDayOfWeek = ''; myTaskDayOfMonth = ''; myTaskMonth = ''; myTaskStartMonth = '';
		myTaskError = '';
	}

	async function handleMyTaskSave() {
		myTaskError = '';
		if (!myTaskTitle.trim()) { myTaskError = $t('actionFollowUps.errTaskTitle'); return; }
		if (myTaskTimeline === 'with_timeline_single' && !myTaskDueDate) { myTaskError = $t('actionFollowUps.errDeliveryDate'); return; }
		if (myTaskTimeline === 'with_timeline_recurring' && !myTaskRecurrenceType) { myTaskError = $t('actionFollowUps.errRecurrenceType'); return; }

		myTaskSaving = true;
		try {
			const { data, error } = await supabase.rpc('create_my_task', {
				p_user_id: $currentUser?.id,
				p_title: myTaskTitle.trim(),
				p_description: myTaskDescription.trim() || null,
				p_timeline_type: myTaskTimeline,
				p_due_date: myTaskTimeline === 'with_timeline_single' ? myTaskDueDate : null,
				p_due_time: myTaskDueTime || null,
				p_recurrence_type: myTaskTimeline === 'with_timeline_recurring' ? myTaskRecurrenceType : null,
				p_recurrence_day_of_week: myTaskDayOfWeek ? parseInt(myTaskDayOfWeek) : null,
				p_recurrence_day_of_month: myTaskDayOfMonth ? parseInt(myTaskDayOfMonth) : null,
				p_recurrence_month: myTaskMonth ? parseInt(myTaskMonth) : null,
				p_recurrence_start_month: myTaskStartMonth ? parseInt(myTaskStartMonth) : null
			});
			if (error) throw error;
			if (data && !data.success) { myTaskError = data.error; return; }
			showMyTaskModal = false;
			await loadMyTasks();
		} catch (err: any) { myTaskError = err.message || 'Failed'; }
		finally { myTaskSaving = false; }
	}

	async function finishMyTask(id: number) {
		try {
			const { error } = await supabase.rpc('finish_my_task', { p_id: id, p_user_id: $currentUser?.id });
			if (error) throw error;
			await loadMyTasks();
		} catch (err: any) { console.error('Error:', err); }
	}

	async function unfinishMyTask(id: number) {
		try {
			const { error } = await supabase.rpc('unfinish_my_task', { p_id: id, p_user_id: $currentUser?.id });
			if (error) throw error;
			await loadMyTasks();
		} catch (err: any) { console.error('Error:', err); }
	}

	async function deleteMyTask(id: number) {
		try {
			const { error } = await supabase.rpc('delete_my_task', { p_id: id, p_user_id: $currentUser?.id });
			if (error) throw error;
			await loadMyTasks();
		} catch (err: any) { console.error('Error:', err); }
	}

	function formatMyTaskSchedule(task: any): string {
		if (task.timeline_type === 'no_timeline') return $t('actionFollowUps.noTimeline');
		if (task.timeline_type === 'with_timeline_single') {
			let s = task.due_date || '';
			if (task.due_time) s += ' @ ' + task.due_time.substring(0, 5);
			return s;
		}
		return formatRecurrence({ schedule_type: 'recurring', recurrence_type: task.recurrence_type,
			recurrence_day_of_week: task.recurrence_day_of_week, recurrence_day_of_month: task.recurrence_day_of_month,
			recurrence_month: task.recurrence_month, recurrence_start_month: task.recurrence_start_month,
			recurrence_time: task.due_time });
	}

	const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
	const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

	function formatRecurrence(rec: any): string {
		if (rec.schedule_type === 'single') return $t('actionFollowUps.single');
		let str = '';
		switch (rec.recurrence_type) {
			case 'daily': str = $t('actionFollowUps.daily'); break;
			case 'weekly': str = $t('actionFollowUps.weekly') + ' - ' + (dayNames[rec.recurrence_day_of_week] || ''); break;
			case 'monthly': str = $t('actionFollowUps.monthly') + ' - Day ' + rec.recurrence_day_of_month; break;
			case 'quarterly': str = $t('actionFollowUps.quarterly') + ' - ' + (monthNames[(rec.recurrence_month || 1) - 1] || '') + ' ' + rec.recurrence_day_of_month; break;
			case 'every_6_months': str = $t('actionFollowUps.every6Months') + ' - ' + (monthNames[(rec.recurrence_start_month || 1) - 1] || '') + ' ' + rec.recurrence_day_of_month; break;
			case 'yearly': str = $t('actionFollowUps.yearly') + ' - ' + (monthNames[(rec.recurrence_month || 1) - 1] || '') + ' ' + rec.recurrence_day_of_month; break;
			default: str = rec.recurrence_type || '';
		}
		if (rec.recurrence_time) str += ' @ ' + rec.recurrence_time.substring(0, 5);
		return str;
	}

	// --- Approvers tab functions ---
	$: if (approverUserSearch !== undefined) filterApproverUsers();

	function filterApproverUsers() {
		if (!approverUserSearch.trim()) approverFilteredUsers = approverUsers;
		else {
			const q = approverUserSearch.toLowerCase();
			approverFilteredUsers = approverUsers.filter(u =>
				(u.name_en && u.name_en.toLowerCase().includes(q)) || (u.id && u.id.toLowerCase().includes(q)));
		}
	}

	async function loadApprovers() {
		approversLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_action_followup_approvers');
			if (error) throw error;
			if (data?.success) approvers = data.data || [];
		} catch (err: any) { console.error('Error loading approvers:', err); }
		finally { approversLoading = false; }
	}

	async function loadApproverUsers() {
		approverUsersLoading = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('user_id, id, name_en')
				.in('employment_status', ['Job (With Finger)', 'Remote Job'])
				.order('name_en');
			if (error) throw error;
			approverUsers = data || [];
			approverFilteredUsers = approverUsers;
		} catch (err: any) { console.error('Error loading users:', err); }
		finally { approverUsersLoading = false; }
	}

	function openApproverModal() {
		showApproverModal = true;
		approverSelectedUser = null;
		approverUserSearch = '';
		approverCanPo = true;
		approverBranchPerm = 'all';
		approverSelectedBranches = [];
		approverError = '';
		loadApproverUsers();
		loadBranches();
	}

	function closeApproverModal() { showApproverModal = false; }

	function selectApproverUser(u: any) { approverSelectedUser = u; }
	function clearApproverUser() { approverSelectedUser = null; approverUserSearch = ''; approverFilteredUsers = approverUsers; }

	function toggleApproverBranch(bid: number) {
		if (approverSelectedBranches.includes(bid)) approverSelectedBranches = approverSelectedBranches.filter(b => b !== bid);
		else approverSelectedBranches = [...approverSelectedBranches, bid];
	}

	async function handleApproverSave() {
		approverError = '';
		if (!approverSelectedUser) { approverError = $t('actionFollowUps.errSelectUser'); return; }
		if (approverBranchPerm === 'selected' && approverSelectedBranches.length === 0) {
			approverError = $t('actionFollowUps.errSelectBranches'); return;
		}

		approverSaving = true;
		try {
			const { data, error } = await supabase.rpc('save_action_followup_approver', {
				p_user_id: approverSelectedUser.user_id,
				p_user_name: approverSelectedUser.name_en,
				p_can_approve_po: approverCanPo,
				p_branch_permission: approverBranchPerm,
				p_selected_branches: approverBranchPerm === 'selected' ? JSON.stringify(approverSelectedBranches.map(String)) : '[]',
				p_created_by: $currentUser?.id || null
			});
			if (error) throw error;
			if (data && !data.success) { approverError = data.error; return; }
			closeApproverModal();
			await loadApprovers();
		} catch (err: any) { approverError = err.message || 'Failed to save'; }
		finally { approverSaving = false; }
	}

	async function deleteApprover(id: number) {
		try {
			const { data, error } = await supabase.rpc('delete_action_followup_approver', { p_id: id });
			if (error) throw error;
			await loadApprovers();
		} catch (err: any) { console.error('Error deleting approver:', err); }
	}

	function getBranchNames(ids: any[]): string {
		if (!ids || ids.length === 0) return '';
		return ids.map(id => {
			const b = branches.find(br => br.id.toString() === id.toString());
			return b ? b.name_en : id;
		}).join(', ');
	}

	// --- PO Approval actions ---
	async function approvePo(poId: number) {
		approvalActioning = true;
		try {
			const empName = await getMyEmployeeName();
			const { data, error } = await supabase.rpc('approve_action_followup_po', {
				p_po_id: poId, p_approver_id: $currentUser?.id, p_approver_name: empName
			});
			if (error) throw error;
			await loadRecords();
		} catch (err: any) { console.error('Error approving:', err); }
		finally { approvalActioning = false; }
	}

	async function markPoFinished(poId: number) {
		try {
			const { error } = await supabase.rpc('finish_action_followup_po', { p_po_id: poId });
			if (error) throw error;
			await loadRecords();
		} catch (err: any) { console.error('Error marking finished:', err); }
	}

	async function unmarkPoFinished(poId: number) {
		try {
			const { error } = await supabase.rpc('unfinish_action_followup_po', { p_po_id: poId });
			if (error) throw error;
			await loadRecords();
		} catch (err: any) { console.error('Error unmarking finished:', err); }
	}

	function openRejectModal(poId: number) {
		rejectingPoId = poId;
		rejectReason = '';
		showRejectModal = true;
	}

	async function confirmReject() {
		if (rejectingPoId === null) return;
		approvalActioning = true;
		try {
			const empName = await getMyEmployeeName();
			const { data, error } = await supabase.rpc('reject_action_followup_po', {
				p_po_id: rejectingPoId, p_approver_id: $currentUser?.id,
				p_approver_name: empName, p_reason: rejectReason.trim() || null
			});
			if (error) throw error;
			showRejectModal = false;
			rejectingPoId = null;
			await loadRecords();
		} catch (err: any) { console.error('Error rejecting:', err); }
		finally { approvalActioning = false; }
	}

	async function getMyEmployeeName(): Promise<string> {
		try {
			const { data } = await supabase.from('hr_employee_master').select('name_en').eq('user_id', $currentUser?.id).single();
			return data?.name_en || '';
		} catch { return ''; }
	}

	// Check if current user can approve POs
	function canApprovePos(): boolean {
		return approvers.some(a => a.user_id === $currentUser?.id && a.can_approve_po);
	}

	async function sendPoApprovalNotifications(branchName: string, vendorName: string, amount: string) {
		try {
			const branchId = parseInt(selectedBranchId);
			const eligible = approvers.filter(a => a.can_approve_po && (a.branch_permission === 'all' ||
				(a.selected_branches || []).map(String).includes(branchId.toString())));
			if (eligible.length === 0) return;

			const empName = await getMyEmployeeName();
			await notificationService.createNotification({
				title: 'PO Follow-Up Approval Request',
				message: `${empName || 'A user'} created a PO follow-up for ${vendorName} (${branchName}) - Amount: ${amount}. Please review and approve.`,
				type: 'approval_request',
				priority: 'high',
				target_type: 'specific_users',
				target_users: eligible.map(a => a.user_id)
			}, $currentUser?.id || '');
		} catch (err) { console.error('Error sending notifications:', err); }
	}

	async function loadBranches() {
		branchesLoading = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (err: any) {
			console.error('Error loading branches:', err);
		} finally {
			branchesLoading = false;
		}
	}

	async function loadVendors() {
		if (!selectedBranchId) { vendors = []; filteredVendors = []; return; }
		vendorsLoading = true;
		try {
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, salesman_name, place, payment_method, credit_period')
				.or(`branch_id.eq.${selectedBranchId},branch_id.is.null`)
				.eq('status', 'Active')
				.order('vendor_name', { ascending: true })
				.limit(10000);
			if (error) throw error;
			vendors = data || [];
			filteredVendors = vendors;
		} catch (err: any) {
			console.error('Error loading vendors:', err);
		} finally {
			vendorsLoading = false;
		}
	}

	async function loadRecords() {
		recordsLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_action_followup_po_records');
			if (error) throw error;
			if (data?.success) {
				records = data.data || [];
			}
		} catch (err: any) {
			console.error('Error loading records:', err);
		} finally {
			recordsLoading = false;
		}
	}

	function openCreateModal() {
		showCreateModal = true;
		selectedBranchId = '';
		selectedVendor = null;
		vendorSearchQuery = '';
		vendors = [];
		filteredVendors = [];
		paymentMode = '';
		creditPeriod = '';
		poAmount = '';
		expectedDeliveryDate = '';
		salesmanName = '';
		salesmanContact = '';
		saveError = '';
		loadBranches();
	}

	function closeCreateModal() {
		showCreateModal = false;
	}

	function selectVendor(vendor: any) {
		selectedVendor = vendor;
	}

	function clearVendor() {
		selectedVendor = null;
		vendorSearchQuery = '';
		filteredVendors = vendors;
	}

	function handleBranchChange() {
		selectedVendor = null;
		vendorSearchQuery = '';
		if (selectedBranchId) loadVendors();
		else { vendors = []; filteredVendors = []; }
	}

	function getSelectedBranchName(): string {
		const b = branches.find(br => br.id.toString() === selectedBranchId);
		if (!b) return '';
		const isAr = $currentLocale === 'ar';
		return isAr ? (b.name_ar || b.name_en) : b.name_en;
	}

	function getSelectedBranchLocation(): string {
		const b = branches.find(br => br.id.toString() === selectedBranchId);
		if (!b) return '';
		const isAr = $currentLocale === 'ar';
		return isAr ? (b.location_ar || b.location_en || '') : (b.location_en || '');
	}

	async function handleSave() {
		saveError = '';
		if (!selectedBranchId) { saveError = $t('actionFollowUps.errBranch'); return; }
		if (!selectedVendor) { saveError = $t('actionFollowUps.errVendor'); return; }
		if (!paymentMode) { saveError = $t('actionFollowUps.errPaymentMode'); return; }
		if (paymentMode === 'credit' && (!creditPeriod || parseInt(creditPeriod) <= 0)) {
			saveError = $t('actionFollowUps.errCreditPeriod'); return;
		}
		if (!poAmount || parseFloat(poAmount) <= 0) { saveError = $t('actionFollowUps.errPoAmount'); return; }
		if (!expectedDeliveryDate) { saveError = $t('actionFollowUps.errDeliveryDate'); return; }

		saving = true;
		try {
			const { data, error } = await supabase.rpc('create_action_followup_po', {
				p_branch_id: parseInt(selectedBranchId),
				p_branch_name: getSelectedBranchName(),
				p_vendor_erp_id: selectedVendor.erp_vendor_id.toString(),
				p_vendor_name: selectedVendor.vendor_name,
				p_payment_mode: paymentMode,
				p_credit_period: paymentMode === 'credit' ? parseInt(creditPeriod) : null,
				p_po_amount: parseFloat(poAmount),
				p_expected_delivery_date: expectedDeliveryDate,
				p_salesman_name: salesmanName.trim() || null,
				p_salesman_contact: salesmanContact.trim() || null,
				p_user_id: $currentUser?.id || null,
				p_branch_location: getSelectedBranchLocation() || null
			});
			if (error) throw error;
			if (data && !data.success) {
				saveError = data.error || 'Unknown error';
				return;
			}
			closeCreateModal();
			await loadRecords();
			// Notify eligible approvers
			sendPoApprovalNotifications(getSelectedBranchName(), selectedVendor.vendor_name, poAmount);
		} catch (err: any) {
			saveError = err.message || 'Failed to save';
		} finally {
			saving = false;
		}
	}

	function formatDate(d: string) {
		if (!d) return '—';
		return new Date(d).toLocaleDateString();
	}

	function getDeliveryStatus(rec: any): { text: string; cls: string } {
		if (rec.is_finished) return { text: $t('actionFollowUps.delivered'), cls: 'delivery-done' };
		if (!rec.expected_delivery_date) return { text: '—', cls: '' };
		const today = new Date(); today.setHours(0, 0, 0, 0);
		const due = new Date(rec.expected_delivery_date); due.setHours(0, 0, 0, 0);
		const diff = Math.ceil((due.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
		if (diff < 0) return { text: $t('actionFollowUps.notDelivered'), cls: 'delivery-overdue' };
		if (diff === 0) return { text: $t('actionFollowUps.dueToday'), cls: 'delivery-today' };
		return { text: diff + ' ' + $t('actionFollowUps.daysRemaining'), cls: 'delivery-upcoming' };
	}

	function formatDateTime(d: string) {
		if (!d) return '—';
		return new Date(d).toLocaleString();
	}
</script>

<div class="action-followups-container">
	<!-- Tab Bar -->
	<div class="tab-bar">
		<button class="tab-btn" class:active={activeTab === 'po'} on:click={() => activeTab = 'po'}>
			{$t('actionFollowUps.po')}
		</button>
		<button class="tab-btn" class:active={activeTab === 'other'} on:click={() => activeTab = 'other'}>
			{$t('actionFollowUps.other')}
		</button>
		<button class="tab-btn" class:active={activeTab === 'approvers'} on:click={() => activeTab = 'approvers'}>
			{$t('actionFollowUps.approvers')}
		</button>
		<button class="tab-btn" class:active={activeTab === 'finished'} on:click={() => activeTab = 'finished'}>
			{$t('actionFollowUps.finishedTab')}
		</button>
		<button class="tab-btn" class:active={activeTab === 'mytasks'} on:click={() => activeTab = 'mytasks'}>
			{$t('actionFollowUps.myTasksTab')}
		</button>
	</div>

	<!-- Tab Content -->
	<div class="tab-content">
		{#if activeTab === 'po'}
			<div class="tab-panel po-panel">
				<div class="po-header">
					<h3>{$t('actionFollowUps.poRecords')}</h3>
					<button class="create-btn" on:click={openCreateModal}>
						+ {$t('actionFollowUps.createPo')}
					</button>
				</div>

				{#if recordsLoading}
					<div class="loading-state">
						<div class="spinner"></div>
						<span>{$t('actionFollowUps.loading')}</span>
					</div>
				{:else if records.length === 0}
					<div class="empty-state">
						<span class="empty-icon">📦</span>
						<p>{$t('actionFollowUps.poPlaceholder')}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{$t('actionFollowUps.branch')}</th>
									<th>{$t('actionFollowUps.vendor')}</th>
									<th>{$t('actionFollowUps.paymentMode')}</th>
									<th>{$t('actionFollowUps.poAmountLabel')}</th>
									<th>{$t('actionFollowUps.expectedDelivery')}</th>
									<th>{$t('actionFollowUps.approvalStatus')}</th>
									<th>{$t('actionFollowUps.approvedRejectedBy')}</th>
									<th>{$t('actionFollowUps.createdBy')}</th>
									<th>{$t('actionFollowUps.createdAt')}</th>
									<th>{$t('actionFollowUps.finished')}</th>
									{#if canApprovePos()}<th>{$t('actionFollowUps.actions')}</th>{/if}
								</tr>
							</thead>
							<tbody>
								{#each records.filter(r => !r.is_finished) as rec, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td>
											<span class="branch-name-cell">{rec.branch_name || rec.branch_id}</span>
											{#if rec.branch_location}<br/><span class="branch-location-cell">{rec.branch_location}</span>{/if}
										</td>
										<td>
											<span class="vendor-name-cell">{rec.vendor_name}</span>
											<span class="vendor-id-cell">({rec.vendor_erp_id})</span>
										</td>
										<td>
											<span class="mode-badge" class:spot={rec.payment_mode === 'spot'} class:credit={rec.payment_mode === 'credit'}>
												{rec.payment_mode === 'spot' ? $t('actionFollowUps.spotPayment') : $t('actionFollowUps.creditPayment')}
											</span>
										</td>
										<td class="num-cell amount-cell">{parseFloat(rec.po_amount).toFixed(2)}</td>
										<td>
											<span class="delivery-status {getDeliveryStatus(rec).cls}">
												{getDeliveryStatus(rec).text}
											</span>
											<br/><span class="delivery-date-sub">{formatDate(rec.expected_delivery_date)}</span>
										</td>
										<td>
											<span class="status-badge" class:pending={rec.approval_status === 'pending'} class:approved={rec.approval_status === 'approved'} class:rejected={rec.approval_status === 'rejected'}>
												{rec.approval_status === 'pending' ? $t('actionFollowUps.pendingApproval') : rec.approval_status === 'approved' ? $t('actionFollowUps.approved') : $t('actionFollowUps.rejected')}
											</span>
										</td>
										<td>
											{#if rec.approved_by_name}
												{rec.approved_by_name}
												{#if rec.rejection_reason}<br/><span class="reject-reason">({rec.rejection_reason})</span>{/if}
											{:else}—{/if}
										</td>
										<td>{rec.created_by_name || '—'}</td>
										<td class="date-cell">{formatDateTime(rec.created_at)}</td>
										<td class="action-cell">
											<input
												type="checkbox"
												class="finished-checkbox"
												checked={rec.is_finished}
												disabled={rec.approval_status !== 'approved' || (!rec.is_finished && rec.approved_by !== $currentUser?.id) || (rec.is_finished && !$currentUser?.isMasterAdmin)}
												on:change={() => rec.is_finished ? unmarkPoFinished(rec.id) : markPoFinished(rec.id)}
											/>
										</td>
										{#if canApprovePos()}
											<td class="action-cell">
												{#if rec.approval_status === 'pending'}
													<button class="approve-btn" on:click={() => approvePo(rec.id)} disabled={approvalActioning}>✓</button>
													<button class="reject-btn" on:click={() => openRejectModal(rec.id)} disabled={approvalActioning}>✗</button>
												{:else}
													<span class="action-done">—</span>
												{/if}
											</td>
										{/if}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{:else if activeTab === 'other'}
			<div class="tab-panel po-panel">
				<div class="po-header">
					<h3>{$t('actionFollowUps.otherRecords')}</h3>
					<button class="create-btn" on:click={openOtherModal}>
						+ {$t('actionFollowUps.createOther')}
					</button>
				</div>

				{#if otherRecordsLoading}
					<div class="loading-state"><div class="spinner"></div><span>{$t('actionFollowUps.loading')}</span></div>
				{:else if otherRecords.length === 0}
					<div class="empty-state">
						<span class="empty-icon">📋</span>
						<p>{$t('actionFollowUps.otherPlaceholder')}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{$t('actionFollowUps.branch')}</th>
									<th>{$t('actionFollowUps.descriptionLabel')}</th>
									<th>{$t('actionFollowUps.schedule')}</th>
									<th>{$t('actionFollowUps.relatedUser')}</th>
									<th>{$t('actionFollowUps.createdBy')}</th>
									<th>{$t('actionFollowUps.createdAt')}</th>
									<th>{$t('actionFollowUps.finished')}</th>
								</tr>
							</thead>
							<tbody>
								{#each otherRecords.filter(r => !r.is_finished) as rec, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td>
											<span class="branch-name-cell">{rec.branch_name || rec.branch_id}</span>
											{#if rec.branch_location}<br/><span class="branch-location-cell">{rec.branch_location}</span>{/if}
										</td>
										<td class="desc-cell">{rec.description}</td>
										<td><span class="schedule-cell">{formatRecurrence(rec)}</span></td>
										<td>{rec.related_user_name || '—'}</td>
										<td>{rec.created_by_name || '—'}</td>
										<td class="date-cell">{formatDateTime(rec.created_at)}</td>
										<td class="action-cell">
											<input
												type="checkbox"
												class="finished-checkbox"
												checked={rec.is_finished}
												disabled={(!rec.is_finished && rec.created_by !== $currentUser?.id) || (rec.is_finished && !$currentUser?.isMasterAdmin)}
												on:change={() => rec.is_finished ? unmarkOtherFinished(rec.id) : markOtherFinished(rec.id)}
											/>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}

				<!-- Occurrences Section -->
				{#if occurrences.length > 0 || occurrencesLoading}
					<div class="occurrences-section">
						<h4>{$t('actionFollowUps.occurrencesTitle')}</h4>
						{#if occurrencesLoading}
							<div class="loading-state"><div class="spinner"></div><span>{$t('actionFollowUps.loading')}</span></div>
						{:else}
							<div class="records-table-wrap">
								<table class="records-table">
									<thead>
										<tr>
											<th>#</th>
											<th>{$t('actionFollowUps.branch')}</th>
											<th>{$t('actionFollowUps.descriptionLabel')}</th>
											<th>{$t('actionFollowUps.dueDate')}</th>
											<th>{$t('actionFollowUps.relatedUser')}</th>
											<th>{$t('actionFollowUps.finished')}</th>
										</tr>
									</thead>
									<tbody>
										{#each occurrences.filter(o => !o.is_finished) as occ, i}
											<tr>
												<td class="num-cell">{i + 1}</td>
												<td>
													<span class="branch-name-cell">{occ.branch_name || occ.branch_id}</span>
													{#if occ.branch_location}<br/><span class="branch-location-cell">{occ.branch_location}</span>{/if}
												</td>
												<td class="desc-cell">{occ.description}</td>
												<td>{occ.due_date}{#if occ.due_time} <span class="schedule-cell">@ {occ.due_time.substring(0, 5)}</span>{/if}</td>
												<td>{occ.related_user_name || '—'}</td>
												<td class="action-cell">
													<input
														type="checkbox"
														class="finished-checkbox"
														checked={occ.is_finished}
														disabled={(!occ.is_finished && occ.created_by !== $currentUser?.id) || (occ.is_finished && !$currentUser?.isMasterAdmin)}
														on:change={() => occ.is_finished ? unfinishOccurrence(occ.id) : finishOccurrence(occ.id)}
													/>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		{:else if activeTab === 'approvers'}
			<div class="tab-panel po-panel">
				<div class="po-header">
					<h3>{$t('actionFollowUps.approversTitle')}</h3>
					<button class="create-btn" on:click={openApproverModal}>
						+ {$t('actionFollowUps.addApprover')}
					</button>
				</div>

				{#if approversLoading}
					<div class="loading-state"><div class="spinner"></div><span>{$t('actionFollowUps.loading')}</span></div>
				{:else if approvers.length === 0}
					<div class="empty-state">
						<span class="empty-icon">👥</span>
						<p>{$t('actionFollowUps.approversPlaceholder')}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{$t('actionFollowUps.user')}</th>
									<th>{$t('actionFollowUps.canApprovePo')}</th>
									<th>{$t('actionFollowUps.branchPermission')}</th>
									<th>{$t('actionFollowUps.actions')}</th>
								</tr>
							</thead>
							<tbody>
								{#each approvers as ap, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td>{ap.user_name || ap.user_id}</td>
										<td class="num-cell">
											{#if ap.can_approve_po}<span class="status-badge approved">✓</span>{:else}<span class="status-badge rejected">✗</span>{/if}
										</td>
										<td>
											{#if ap.branch_permission === 'all'}
												<span class="mode-badge spot">{$t('actionFollowUps.allBranches')}</span>
											{:else}
												{getBranchNames(ap.selected_branches || [])}
											{/if}
										</td>
										<td class="action-cell">
											<button class="reject-btn" on:click={() => deleteApprover(ap.id)} title="Remove">🗑</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
		{#if activeTab === 'finished'}
			<div class="tab-panel po-panel">
				<div class="po-header">
					<h3>{$t('actionFollowUps.finishedTab')}</h3>
				</div>

				{#if finishedItems.length === 0}
					<div class="empty-state">
						<span class="empty-icon">✅</span>
						<p>{$t('actionFollowUps.noFinishedItems')}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{$t('actionFollowUps.typeLabel')}</th>
									<th>{$t('actionFollowUps.branch')}</th>
									<th>{$t('actionFollowUps.descriptionLabel')}</th>
									<th>{$t('actionFollowUps.finishedAt')}</th>
									<th>{$t('actionFollowUps.createdBy')}</th>
								</tr>
							</thead>
							<tbody>
								{#each finishedItems as item, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td>
											<span class="mode-badge" class:spot={item.source === 'po'} class:credit={item.source === 'other' || item.source === 'occurrence'}>
												{item.source === 'po' ? 'PO' : item.source === 'occurrence' ? 'Occurrence' : 'Other'}
											</span>
										</td>
										<td>
											<span class="branch-name-cell">{item.branch_name || ''}</span>
											{#if item.branch_location}<br/><span class="branch-location-cell">{item.branch_location}</span>{/if}
										</td>
										<td class="desc-cell">
											{#if item.source === 'po'}
												{item.vendor_name} — {parseFloat(item.po_amount || 0).toFixed(2)}
											{:else}
												{item.description || '—'}
											{/if}
										</td>
										<td class="date-cell">{item.finished_sort ? formatDateTime(item.finished_sort) : '—'}</td>
										<td>{item.created_by_name || '—'}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
		{#if activeTab === 'mytasks'}
			<div class="tab-panel po-panel">
				<div class="po-header">
					<h3>{$t('actionFollowUps.myTasksTab')}</h3>
					<button class="create-btn" on:click={openMyTaskModal}>
						+ {$t('actionFollowUps.addTask')}
					</button>
				</div>

				{#if myTasksLoading}
					<div class="loading-state"><div class="spinner"></div><span>{$t('actionFollowUps.loading')}</span></div>
				{:else if myTasks.filter(t => !t.is_finished).length === 0}
					<div class="empty-state">
						<span class="empty-icon">📝</span>
						<p>{$t('actionFollowUps.noTasks')}</p>
					</div>
				{:else}
					<div class="my-tasks-list">
						{#each myTasks.filter(t => !t.is_finished) as task}
							<div class="task-card">
								<div class="task-check">
									<input type="checkbox" class="finished-checkbox" checked={false} on:change={() => finishMyTask(task.id)} />
								</div>
								<div class="task-body">
									<div class="task-title">{task.title}</div>
									{#if task.description}<div class="task-desc">{task.description}</div>{/if}
									<div class="task-meta">
										<span class="task-schedule">{formatMyTaskSchedule(task)}</span>
									</div>
								</div>
								<button class="task-delete" on:click={() => deleteMyTask(task.id)} title="Delete">🗑</button>
							</div>
						{/each}
					</div>
				{/if}

				<!-- Completed tasks (collapsed) -->
				{#if myTasks.filter(t => t.is_finished).length > 0}
					<details class="completed-section">
						<summary>{$t('actionFollowUps.completedTasks')} ({myTasks.filter(t => t.is_finished).length})</summary>
						<div class="my-tasks-list">
							{#each myTasks.filter(t => t.is_finished) as task}
								<div class="task-card task-done">
									<div class="task-check">
										<input type="checkbox" class="finished-checkbox" checked={true} on:change={() => unfinishMyTask(task.id)} />
									</div>
									<div class="task-body">
										<div class="task-title">{task.title}</div>
										{#if task.description}<div class="task-desc">{task.description}</div>{/if}
									</div>
								</div>
							{/each}
						</div>
					</details>
				{/if}
			</div>
		{/if}
	</div>
</div>

<!-- Create PO Follow-Up Modal -->
{#if showCreateModal}
	<div class="modal-overlay" on:click|self={closeCreateModal}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{$t('actionFollowUps.createPoTitle')}</h3>
				<button class="modal-close" on:click={closeCreateModal}>×</button>
			</div>
			<div class="modal-body">
				<!-- Branch -->
				<div class="form-group">
					<label for="afu-branch">{$t('actionFollowUps.branch')}</label>
					{#if branchesLoading}
						<div class="field-loading">{$t('actionFollowUps.loading')}</div>
					{:else}
						<select id="afu-branch" bind:value={selectedBranchId} on:change={handleBranchChange} class="form-select">
							<option value="">-- {$t('actionFollowUps.selectBranch')} --</option>
							{#each branches as b}
								<option value={b.id.toString()}>
									{$currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en}
									{#if $currentLocale === 'ar' ? (b.location_ar || b.location_en) : b.location_en}
										- {$currentLocale === 'ar' ? (b.location_ar || b.location_en) : b.location_en}
									{/if}
								</option>
							{/each}
						</select>
					{/if}
				</div>

				<!-- Vendor -->
				<div class="form-group">
					<label>{$t('actionFollowUps.vendor')}</label>
					{#if !selectedBranchId}
						<div class="field-hint">{$t('actionFollowUps.selectBranchFirst')}</div>
					{:else if selectedVendor}
						<div class="selected-vendor-bar">
							<div class="sv-info">
								<span class="sv-name">{selectedVendor.vendor_name}</span>
								<span class="sv-id">({selectedVendor.erp_vendor_id})</span>
							</div>
							<button class="sv-change" on:click={clearVendor}>{$t('actionFollowUps.change')}</button>
						</div>
					{:else if vendorsLoading}
						<div class="field-loading">{$t('actionFollowUps.loadingVendors')}</div>
					{:else}
						<div class="vendor-selector">
							<input
								type="text"
								bind:value={vendorSearchQuery}
								placeholder={$t('actionFollowUps.searchVendor')}
								class="form-input search-input"
							/>
							<div class="vendor-list">
								{#if filteredVendors.length === 0}
									<div class="no-vendors">{$t('actionFollowUps.noVendorsFound')}</div>
								{:else}
									{#each filteredVendors.slice(0, 50) as v}
										<button class="vendor-row" on:click={() => selectVendor(v)}>
											<span class="vr-id">{v.erp_vendor_id}</span>
											<span class="vr-name">{v.vendor_name}</span>
											{#if v.place}<span class="vr-place">{v.place}</span>{/if}
										</button>
									{/each}
									{#if filteredVendors.length > 50}
										<div class="more-hint">{filteredVendors.length - 50} {$t('actionFollowUps.moreVendors')}</div>
									{/if}
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<!-- Payment Mode -->
				<div class="form-group">
					<label for="afu-payment">{$t('actionFollowUps.paymentMode')}</label>
					<select id="afu-payment" bind:value={paymentMode} class="form-select">
						<option value="">-- {$t('actionFollowUps.selectPaymentMode')} --</option>
						<option value="spot">{$t('actionFollowUps.spotPayment')}</option>
						<option value="credit">{$t('actionFollowUps.creditPayment')}</option>
					</select>
				</div>

				<!-- Credit Period (only if credit) -->
				{#if paymentMode === 'credit'}
					<div class="form-group">
						<label for="afu-credit">{$t('actionFollowUps.creditPeriodLabel')} <span class="required">*</span></label>
						<div class="input-with-suffix">
							<input id="afu-credit" type="number" bind:value={creditPeriod} min="1" placeholder="30" class="form-input" />
							<span class="input-suffix">{$t('actionFollowUps.days')}</span>
						</div>
					</div>
				{/if}

				<!-- PO Amount -->
				<div class="form-group">
					<label for="afu-amount">{$t('actionFollowUps.poAmountLabel')}</label>
					<input id="afu-amount" type="number" bind:value={poAmount} min="0.01" step="0.01" placeholder="0.00" class="form-input" />
				</div>

				<!-- Salesman Name -->
				<div class="form-group">
					<label for="afu-salesman">{$t('actionFollowUps.salesmanName')}</label>
					<input id="afu-salesman" type="text" bind:value={salesmanName} placeholder={$t('actionFollowUps.salesmanNamePlaceholder')} class="form-input" />
				</div>

				<!-- Salesman Contact -->
				<div class="form-group">
					<label for="afu-salesman-contact">{$t('actionFollowUps.salesmanContact')}</label>
					<input id="afu-salesman-contact" type="text" bind:value={salesmanContact} placeholder={$t('actionFollowUps.salesmanContactPlaceholder')} class="form-input" />
				</div>

				<!-- Expected Delivery Date -->
				<div class="form-group">
					<label for="afu-date">{$t('actionFollowUps.expectedDelivery')}</label>
					<input id="afu-date" type="date" bind:value={expectedDeliveryDate} class="form-input" />
				</div>

				<!-- Error -->
				{#if saveError}
					<div class="save-error">{saveError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeCreateModal} disabled={saving}>{$t('actionFollowUps.cancel')}</button>
				<button class="save-btn" on:click={handleSave} disabled={saving}>
					{#if saving}
						<span class="spinner-sm"></span>
					{/if}
					{$t('actionFollowUps.save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Create Other Follow-Up Modal -->
{#if showOtherModal}
	<div class="modal-overlay" on:click|self={closeOtherModal}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{$t('actionFollowUps.createOtherTitle')}</h3>
				<button class="modal-close" on:click={closeOtherModal}>×</button>
			</div>
			<div class="modal-body">
				<!-- Branch -->
				<div class="form-group">
					<label for="other-branch">{$t('actionFollowUps.branch')}</label>
					{#if branchesLoading}
						<div class="field-loading">{$t('actionFollowUps.loading')}</div>
					{:else}
						<select id="other-branch" bind:value={otherBranchId} on:change={handleOtherBranchChange} class="form-select">
							<option value="">-- {$t('actionFollowUps.selectBranch')} --</option>
							{#each branches as b}
								<option value={b.id.toString()}>
									{$currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en}
									{#if $currentLocale === 'ar' ? (b.location_ar || b.location_en) : b.location_en}
										- {$currentLocale === 'ar' ? (b.location_ar || b.location_en) : b.location_en}
									{/if}
								</option>
							{/each}
						</select>
					{/if}
				</div>

				<!-- Description -->
				<div class="form-group">
					<label for="other-desc">{$t('actionFollowUps.descriptionLabel')}</label>
					<textarea id="other-desc" bind:value={otherDescription} placeholder={$t('actionFollowUps.descriptionPlaceholder')} rows="3" class="form-input form-textarea"></textarea>
				</div>

				<!-- Schedule Type -->
				<div class="form-group">
					<label for="other-schedule">{$t('actionFollowUps.scheduleType')}</label>
					<select id="other-schedule" bind:value={otherScheduleType} class="form-select">
						<option value="">-- {$t('actionFollowUps.selectScheduleType')} --</option>
						<option value="single">{$t('actionFollowUps.single')}</option>
						<option value="recurring">{$t('actionFollowUps.recurring')}</option>
					</select>
				</div>

				<!-- Recurring Options -->
				{#if otherScheduleType === 'recurring'}
					<div class="form-group">
						<label for="other-recurrence">{$t('actionFollowUps.recurrenceType')}</label>
						<select id="other-recurrence" bind:value={otherRecurrenceType} class="form-select">
							<option value="">-- {$t('actionFollowUps.selectRecurrenceType')} --</option>
							<option value="daily">{$t('actionFollowUps.daily')}</option>
							<option value="weekly">{$t('actionFollowUps.weekly')}</option>
							<option value="monthly">{$t('actionFollowUps.monthly')}</option>
							<option value="quarterly">{$t('actionFollowUps.quarterly')}</option>
							<option value="every_6_months">{$t('actionFollowUps.every6Months')}</option>
							<option value="yearly">{$t('actionFollowUps.yearly')}</option>
						</select>
					</div>

					<!-- Weekly: day of week -->
					{#if otherRecurrenceType === 'weekly'}
						<div class="form-group">
							<label for="other-dow">{$t('actionFollowUps.dayOfWeek')}</label>
							<select id="other-dow" bind:value={otherDayOfWeek} class="form-select">
								<option value="">-- {$t('actionFollowUps.selectDay')} --</option>
								{#each dayNames as day, i}
									<option value={i.toString()}>{day}</option>
								{/each}
							</select>
						</div>
					{/if}

					<!-- Monthly/Quarterly/6-months/Yearly: day of month -->
					{#if otherRecurrenceType === 'monthly' || otherRecurrenceType === 'quarterly' || otherRecurrenceType === 'every_6_months' || otherRecurrenceType === 'yearly'}
						<div class="form-group">
							<label for="other-dom">{$t('actionFollowUps.dayOfMonth')}</label>
							<select id="other-dom" bind:value={otherDayOfMonth} class="form-select">
								<option value="">-- {$t('actionFollowUps.selectDay')} --</option>
								{#each Array.from({length: 31}, (_, i) => i + 1) as d}
									<option value={d.toString()}>{d}</option>
								{/each}
							</select>
							{#if parseInt(otherDayOfMonth) > 28}
								<span class="field-hint">{$t('actionFollowUps.dayOverflowNote')}</span>
							{/if}
						</div>
					{/if}

					<!-- Quarterly/Yearly: month -->
					{#if otherRecurrenceType === 'quarterly' || otherRecurrenceType === 'yearly'}
						<div class="form-group">
							<label for="other-month">{$t('actionFollowUps.monthLabel')}</label>
							<select id="other-month" bind:value={otherMonth} class="form-select">
								<option value="">-- {$t('actionFollowUps.selectMonth')} --</option>
								{#each monthNames as m, i}
									<option value={(i + 1).toString()}>{m}</option>
								{/each}
							</select>
						</div>
					{/if}

					<!-- Every 6 months: start month -->
					{#if otherRecurrenceType === 'every_6_months'}
						<div class="form-group">
							<label for="other-start-month">{$t('actionFollowUps.startMonth')}</label>
							<select id="other-start-month" bind:value={otherStartMonth} class="form-select">
								<option value="">-- {$t('actionFollowUps.selectMonth')} --</option>
								{#each monthNames as m, i}
									<option value={(i + 1).toString()}>{m}</option>
								{/each}
							</select>
						</div>
					{/if}

					<!-- Time -->
					{#if otherRecurrenceType}
						<div class="form-group">
							<label for="other-time">{$t('actionFollowUps.time')}</label>
							<input id="other-time" type="time" bind:value={otherTime} class="form-input" />
						</div>
					{/if}
				{/if}

				<!-- Related User -->
				<div class="form-group">
					<label>{$t('actionFollowUps.relatedUser')}</label>
					{#if !otherBranchId}
						<div class="field-hint">{$t('actionFollowUps.selectBranchFirst')}</div>
					{:else if otherSelectedUser}
						<div class="selected-vendor-bar">
							<div class="sv-info">
								<span class="sv-name">{otherSelectedUser.name_en}</span>
								<span class="sv-id">({otherSelectedUser.id})</span>
							</div>
							<button class="sv-change" on:click={clearOtherUser}>{$t('actionFollowUps.change')}</button>
						</div>
					{:else if otherUsersLoading}
						<div class="field-loading">{$t('actionFollowUps.loading')}</div>
					{:else}
						<div class="vendor-selector">
							<input type="text" bind:value={otherUserSearch} placeholder={$t('actionFollowUps.searchUser')} class="form-input search-input" />
							<div class="vendor-list">
								{#if otherFilteredUsers.length === 0}
									<div class="no-vendors">{$t('actionFollowUps.noUsersFound')}</div>
								{:else}
									{#each otherFilteredUsers.slice(0, 30) as u}
										<button class="vendor-row" on:click={() => selectOtherUser(u)}>
											<span class="vr-id">{u.id}</span>
											<span class="vr-name">{u.name_en}</span>
										</button>
									{/each}
								{/if}
							</div>
						</div>
					{/if}
				</div>

				{#if otherError}
					<div class="save-error">{otherError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeOtherModal} disabled={otherSaving}>{$t('actionFollowUps.cancel')}</button>
				<button class="save-btn" on:click={handleOtherSave} disabled={otherSaving}>
					{#if otherSaving}<span class="spinner-sm"></span>{/if}
					{$t('actionFollowUps.save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Add Approver Modal -->
{#if showApproverModal}
	<div class="modal-overlay" on:click|self={closeApproverModal}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{$t('actionFollowUps.addApproverTitle')}</h3>
				<button class="modal-close" on:click={closeApproverModal}>×</button>
			</div>
			<div class="modal-body">
				<!-- User -->
				<div class="form-group">
					<label>{$t('actionFollowUps.user')}</label>
					{#if approverSelectedUser}
						<div class="selected-vendor-bar">
							<div class="sv-info">
								<span class="sv-name">{approverSelectedUser.name_en}</span>
								<span class="sv-id">({approverSelectedUser.id})</span>
							</div>
							<button class="sv-change" on:click={clearApproverUser}>{$t('actionFollowUps.change')}</button>
						</div>
					{:else if approverUsersLoading}
						<div class="field-loading">{$t('actionFollowUps.loading')}</div>
					{:else}
						<div class="vendor-selector">
							<input type="text" bind:value={approverUserSearch} placeholder={$t('actionFollowUps.searchUser')} class="form-input search-input" />
							<div class="vendor-list">
								{#if approverFilteredUsers.length === 0}
									<div class="no-vendors">{$t('actionFollowUps.noUsersFound')}</div>
								{:else}
									{#each approverFilteredUsers.slice(0, 30) as u}
										<button class="vendor-row" on:click={() => selectApproverUser(u)}>
											<span class="vr-id">{u.id}</span>
											<span class="vr-name">{u.name_en}</span>
										</button>
									{/each}
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<!-- Can Approve PO -->
				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={approverCanPo} />
						{$t('actionFollowUps.canApprovePo')}
					</label>
				</div>

				<!-- Branch Permission -->
				<div class="form-group">
					<label>{$t('actionFollowUps.branchPermission')}</label>
					<select bind:value={approverBranchPerm} class="form-select">
						<option value="all">{$t('actionFollowUps.allBranches')}</option>
						<option value="selected">{$t('actionFollowUps.selectedBranchesOnly')}</option>
					</select>
				</div>

				{#if approverBranchPerm === 'selected'}
					<div class="form-group">
						<label>{$t('actionFollowUps.selectBranchesLabel')}</label>
						<div class="branch-checkboxes">
							{#each branches as b}
								<label class="branch-check-item">
									<input type="checkbox" checked={approverSelectedBranches.includes(b.id)} on:change={() => toggleApproverBranch(b.id)} />
									{$currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en}
								</label>
							{/each}
						</div>
					</div>
				{/if}

				{#if approverError}
					<div class="save-error">{approverError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeApproverModal} disabled={approverSaving}>{$t('actionFollowUps.cancel')}</button>
				<button class="save-btn" on:click={handleApproverSave} disabled={approverSaving}>
					{#if approverSaving}<span class="spinner-sm"></span>{/if}
					{$t('actionFollowUps.save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Reject Reason Modal -->
{#if showRejectModal}
	<div class="modal-overlay" on:click|self={() => showRejectModal = false}>
		<div class="modal-container" style="width: 420px;">
			<div class="modal-header">
				<h3>{$t('actionFollowUps.rejectTitle')}</h3>
				<button class="modal-close" on:click={() => showRejectModal = false}>×</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label for="reject-reason">{$t('actionFollowUps.rejectReasonLabel')}</label>
					<textarea id="reject-reason" bind:value={rejectReason} placeholder={$t('actionFollowUps.rejectReasonPlaceholder')} rows="3" class="form-input form-textarea"></textarea>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={() => showRejectModal = false}>{$t('actionFollowUps.cancel')}</button>
				<button class="reject-confirm-btn" on:click={confirmReject} disabled={approvalActioning}>
					{$t('actionFollowUps.confirmReject')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- My Task Modal -->
{#if showMyTaskModal}
	<div class="modal-overlay" on:click|self={() => showMyTaskModal = false}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{$t('actionFollowUps.addTaskTitle')}</h3>
				<button class="modal-close" on:click={() => showMyTaskModal = false}>×</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label for="mt-title">{$t('actionFollowUps.taskTitle')}</label>
					<input id="mt-title" type="text" bind:value={myTaskTitle} placeholder={$t('actionFollowUps.taskTitlePlaceholder')} class="form-input" />
				</div>
				<div class="form-group">
					<label for="mt-desc">{$t('actionFollowUps.taskDescription')}</label>
					<textarea id="mt-desc" bind:value={myTaskDescription} placeholder={$t('actionFollowUps.taskDescPlaceholder')} rows="2" class="form-input form-textarea"></textarea>
				</div>
				<div class="form-group">
					<label for="mt-timeline">{$t('actionFollowUps.timelineType')}</label>
					<select id="mt-timeline" bind:value={myTaskTimeline} class="form-select">
						<option value="no_timeline">{$t('actionFollowUps.noTimeline')}</option>
						<option value="with_timeline_single">{$t('actionFollowUps.singleWithTime')}</option>
						<option value="with_timeline_recurring">{$t('actionFollowUps.recurringTask')}</option>
					</select>
				</div>

				{#if myTaskTimeline === 'with_timeline_single'}
					<div class="form-group">
						<label for="mt-date">{$t('actionFollowUps.dueDate')}</label>
						<input id="mt-date" type="date" bind:value={myTaskDueDate} class="form-input" />
					</div>
					<div class="form-group">
						<label for="mt-time">{$t('actionFollowUps.time')}</label>
						<input id="mt-time" type="time" bind:value={myTaskDueTime} class="form-input" />
					</div>
				{/if}

				{#if myTaskTimeline === 'with_timeline_recurring'}
					<div class="form-group">
						<label for="mt-rec">{$t('actionFollowUps.recurrenceType')}</label>
						<select id="mt-rec" bind:value={myTaskRecurrenceType} class="form-select">
							<option value="">-- {$t('actionFollowUps.selectRecurrenceType')} --</option>
							<option value="daily">{$t('actionFollowUps.daily')}</option>
							<option value="weekly">{$t('actionFollowUps.weekly')}</option>
							<option value="monthly">{$t('actionFollowUps.monthly')}</option>
							<option value="quarterly">{$t('actionFollowUps.quarterly')}</option>
							<option value="every_6_months">{$t('actionFollowUps.every6Months')}</option>
							<option value="yearly">{$t('actionFollowUps.yearly')}</option>
						</select>
					</div>
					{#if myTaskRecurrenceType === 'weekly'}
						<div class="form-group">
							<label>{$t('actionFollowUps.dayOfWeek')}</label>
							<select bind:value={myTaskDayOfWeek} class="form-select">
								<option value="">--</option>
								{#each dayNames as day, i}<option value={i.toString()}>{day}</option>{/each}
							</select>
						</div>
					{/if}
					{#if myTaskRecurrenceType === 'monthly' || myTaskRecurrenceType === 'quarterly' || myTaskRecurrenceType === 'every_6_months' || myTaskRecurrenceType === 'yearly'}
						<div class="form-group">
							<label>{$t('actionFollowUps.dayOfMonth')}</label>
							<select bind:value={myTaskDayOfMonth} class="form-select">
								<option value="">--</option>
								{#each Array.from({length: 31}, (_, i) => i + 1) as d}<option value={d.toString()}>{d}</option>{/each}
							</select>
						</div>
					{/if}
					{#if myTaskRecurrenceType === 'quarterly' || myTaskRecurrenceType === 'yearly'}
						<div class="form-group">
							<label>{$t('actionFollowUps.monthLabel')}</label>
							<select bind:value={myTaskMonth} class="form-select">
								<option value="">--</option>
								{#each monthNames as m, i}<option value={(i+1).toString()}>{m}</option>{/each}
							</select>
						</div>
					{/if}
					{#if myTaskRecurrenceType === 'every_6_months'}
						<div class="form-group">
							<label>{$t('actionFollowUps.startMonth')}</label>
							<select bind:value={myTaskStartMonth} class="form-select">
								<option value="">--</option>
								{#each monthNames as m, i}<option value={(i+1).toString()}>{m}</option>{/each}
							</select>
						</div>
					{/if}
					<div class="form-group">
						<label>{$t('actionFollowUps.time')}</label>
						<input type="time" bind:value={myTaskDueTime} class="form-input" />
					</div>
				{/if}

				{#if myTaskError}
					<div class="save-error">{myTaskError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={() => showMyTaskModal = false} disabled={myTaskSaving}>{$t('actionFollowUps.cancel')}</button>
				<button class="save-btn" on:click={handleMyTaskSave} disabled={myTaskSaving}>
					{#if myTaskSaving}<span class="spinner-sm"></span>{/if}
					{$t('actionFollowUps.save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.action-followups-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(135deg, #f0f4ff 0%, #e8edf8 50%, #f5f7fc 100%);
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
		color: #1e293b;
		overflow: hidden;
	}

	.tab-bar {
		display: flex;
		gap: 6px;
		padding: 16px 20px 0;
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border-bottom: 1px solid rgba(255, 255, 255, 0.5);
	}

	.tab-btn {
		padding: 10px 24px;
		border: 1px solid rgba(255, 255, 255, 0.5);
		border-bottom: none;
		border-radius: 10px 10px 0 0;
		background: rgba(255, 255, 255, 0.35);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		color: #475569;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		position: relative;
	}

	.tab-btn:hover { background: rgba(255, 255, 255, 0.55); color: #1e293b; }

	.tab-btn.active {
		background: rgba(255, 255, 255, 0.7);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		color: #3b82f6;
		font-weight: 600;
		border-color: rgba(59, 130, 246, 0.25);
		box-shadow: 0 -2px 8px rgba(59, 130, 246, 0.1);
	}

	.tab-btn.active::after {
		content: '';
		position: absolute;
		bottom: -1px; left: 0; right: 0;
		height: 2px;
		background: rgba(255, 255, 255, 0.7);
	}

	.tab-content { flex: 1; overflow: auto; padding: 20px; }

	.tab-panel {
		min-height: 100%;
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 12px;
		box-shadow: 0 4px 24px rgba(0, 0, 0, 0.04);
		padding: 20px;
	}

	.po-panel { display: flex; flex-direction: column; gap: 16px; }

	.empty-state { text-align: center; padding: 60px 20px; opacity: 0.6; }
	.empty-icon { font-size: 48px; display: block; margin-bottom: 12px; }
	.empty-state p { font-size: 15px; color: #64748b; margin: 0; }

	.po-header { display: flex; align-items: center; justify-content: space-between; }
	.po-header h3 { margin: 0; font-size: 16px; color: #1e293b; }

	.create-btn {
		padding: 8px 18px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.create-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4); }

	.loading-state { display: flex; align-items: center; justify-content: center; gap: 10px; padding: 40px; color: #64748b; }
	.spinner { width: 20px; height: 20px; border: 2px solid #e0e0e0; border-top: 2px solid #3b82f6; border-radius: 50%; animation: spin 0.7s linear infinite; }
	.spinner-sm { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.3); border-top: 2px solid white; border-radius: 50%; animation: spin 0.7s linear infinite; display: inline-block; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.records-table-wrap { overflow-x: auto; }

	.records-table { width: 100%; border-collapse: collapse; font-size: 13px; }

	.records-table thead th {
		padding: 10px 12px;
		text-align: left;
		font-weight: 600;
		color: #475569;
		background: rgba(241, 245, 249, 0.7);
		border-bottom: 2px solid rgba(226, 232, 240, 0.8);
		white-space: nowrap;
	}

	.records-table tbody td {
		padding: 10px 12px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.5);
		color: #334155;
	}

	.records-table tbody tr:hover { background: rgba(241, 245, 249, 0.5); }

	.num-cell { text-align: center; }
	.amount-cell { font-weight: 600; color: #1e293b; }
	.date-cell { font-size: 12px; color: #64748b; white-space: nowrap; }
	.vendor-name-cell { font-weight: 500; }
	.vendor-id-cell { font-size: 11px; color: #94a3b8; margin-left: 4px; }
	.branch-name-cell { font-weight: 500; }
	.branch-location-cell { font-size: 11px; color: #94a3b8; }
	.desc-cell { max-width: 250px; white-space: pre-wrap; word-break: break-word; }
	.schedule-cell { font-size: 12px; color: #475569; }
	.form-textarea { resize: vertical; min-height: 60px; }

	.mode-badge {
		display: inline-block;
		padding: 2px 10px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.mode-badge.spot { background: #dcfce7; color: #166534; }
	.mode-badge.credit { background: #fef3c7; color: #92400e; }

	/* Modal */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.4);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
	}

	.modal-container {
		background: rgba(255, 255, 255, 0.92);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.7);
		border-radius: 16px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
		width: 560px;
		max-height: 85vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 18px 24px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.6);
	}

	.modal-header h3 { margin: 0; font-size: 17px; color: #1e293b; }

	.modal-close {
		width: 32px; height: 32px;
		border: none; border-radius: 8px;
		background: rgba(241, 245, 249, 0.6);
		font-size: 20px;
		color: #64748b;
		cursor: pointer;
		display: flex; align-items: center; justify-content: center;
		transition: all 0.15s;
	}

	.modal-close:hover { background: #fee2e2; color: #ef4444; }

	.modal-body {
		padding: 20px 24px;
		overflow-y: auto;
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		padding: 16px 24px;
		border-top: 1px solid rgba(226, 232, 240, 0.6);
	}

	.form-group { display: flex; flex-direction: column; gap: 6px; }
	.form-group label { font-size: 13px; font-weight: 600; color: #475569; }
	.required { color: #ef4444; }

	.form-select, .form-input {
		padding: 9px 12px;
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.7);
		font-size: 14px;
		color: #1e293b;
		outline: none;
		transition: border-color 0.15s, box-shadow 0.15s;
	}

	.form-select:focus, .form-input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.field-hint { font-size: 13px; color: #94a3b8; font-style: italic; }
	.field-loading { font-size: 13px; color: #64748b; }

	.vendor-selector { display: flex; flex-direction: column; gap: 6px; }
	.search-input { width: 100%; box-sizing: border-box; }

	.vendor-list {
		max-height: 180px;
		overflow-y: auto;
		border: 1px solid rgba(203, 213, 225, 0.5);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.6);
	}

	.vendor-row {
		display: flex;
		align-items: center;
		gap: 10px;
		width: 100%;
		padding: 8px 12px;
		border: none;
		background: none;
		cursor: pointer;
		text-align: left;
		font-size: 13px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.4);
		transition: background 0.1s;
		color: #334155;
	}

	.vendor-row:hover { background: rgba(59, 130, 246, 0.08); }
	.vendor-row:last-child { border-bottom: none; }
	.vr-id { font-weight: 600; color: #3b82f6; min-width: 50px; }
	.vr-name { flex: 1; }
	.vr-place { font-size: 11px; color: #94a3b8; }

	.no-vendors { padding: 16px; text-align: center; color: #94a3b8; font-size: 13px; }
	.more-hint { padding: 6px 12px; text-align: center; color: #94a3b8; font-size: 11px; }

	.selected-vendor-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 12px;
		background: rgba(236, 253, 245, 0.8);
		border: 1px solid rgba(134, 239, 172, 0.6);
		border-radius: 8px;
	}

	.sv-info { display: flex; align-items: center; gap: 6px; }
	.sv-name { font-weight: 600; color: #166534; }
	.sv-id { font-size: 12px; color: #64748b; }

	.sv-change {
		padding: 4px 10px;
		background: none;
		border: 1px solid rgba(134, 239, 172, 0.6);
		border-radius: 6px;
		color: #166534;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.15s;
	}

	.sv-change:hover { background: rgba(134, 239, 172, 0.3); }

	.input-with-suffix { display: flex; align-items: center; gap: 8px; }
	.input-with-suffix .form-input { flex: 1; }
	.input-suffix { font-size: 13px; color: #64748b; }

	.save-error {
		padding: 10px 14px;
		background: rgba(254, 226, 226, 0.8);
		border: 1px solid rgba(252, 165, 165, 0.6);
		border-radius: 8px;
		color: #991b1b;
		font-size: 13px;
	}

	.cancel-btn {
		padding: 9px 20px;
		background: rgba(241, 245, 249, 0.7);
		border: 1px solid rgba(203, 213, 225, 0.6);
		border-radius: 8px;
		color: #475569;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.15s;
	}

	.cancel-btn:hover { background: rgba(226, 232, 240, 0.8); }

	.save-btn {
		padding: 9px 24px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		border: none;
		border-radius: 8px;
		color: white;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: all 0.15s;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.save-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4); }
	.save-btn:disabled { opacity: 0.6; cursor: not-allowed; }
	.cancel-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	/* Status badges */
	.status-badge {
		display: inline-block; padding: 2px 10px; border-radius: 12px;
		font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px;
	}
	.status-badge.pending { background: #fef3c7; color: #92400e; }
	.status-badge.approved { background: #dcfce7; color: #166534; }
	.status-badge.rejected { background: #fee2e2; color: #991b1b; }
	.reject-reason { font-size: 11px; color: #991b1b; font-style: italic; }

	/* Approve/reject buttons */
	.action-cell { white-space: nowrap; }
	.approve-btn {
		padding: 4px 10px; border: none; border-radius: 6px;
		background: #dcfce7; color: #166534; font-weight: 700; font-size: 14px;
		cursor: pointer; margin-right: 4px; transition: all 0.15s;
	}
	.approve-btn:hover { background: #bbf7d0; }
	.reject-btn {
		padding: 4px 10px; border: none; border-radius: 6px;
		background: #fee2e2; color: #991b1b; font-weight: 700; font-size: 14px;
		cursor: pointer; transition: all 0.15s;
	}
	.reject-btn:hover { background: #fecaca; }
	.approve-btn:disabled, .reject-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.action-done { color: #94a3b8; }
	.finished-checkbox { width: 18px; height: 18px; accent-color: #16a34a; cursor: pointer; }
	.finished-checkbox:disabled { cursor: not-allowed; opacity: 0.4; }

	/* Delivery status */
	.delivery-status { font-size: 12px; font-weight: 600; }
	.delivery-done { color: #16a34a; }
	.delivery-overdue { color: #dc2626; }
	.delivery-today { color: #d97706; }
	.delivery-upcoming { color: #2563eb; }
	.delivery-date-sub { font-size: 10px; color: #94a3b8; }
	.occurrences-section { margin-top: 24px; padding-top: 16px; border-top: 1px solid rgba(226, 232, 240, 0.6); }
	.occurrences-section h4 { margin: 0 0 12px; font-size: 15px; color: #334155; }
	.finished-row { opacity: 0.5; }

	/* My Tasks */
	.my-tasks-list { display: flex; flex-direction: column; gap: 8px; }
	.task-card {
		display: flex; align-items: flex-start; gap: 12px; padding: 12px 14px;
		background: rgba(255,255,255,0.6); border: 1px solid rgba(226,232,240,0.6);
		border-radius: 10px; transition: all 0.15s;
	}
	.task-card:hover { background: rgba(255,255,255,0.85); }
	.task-done { opacity: 0.5; }
	.task-done .task-title { text-decoration: line-through; }
	.task-check { padding-top: 2px; }
	.task-body { flex: 1; min-width: 0; }
	.task-title { font-size: 14px; font-weight: 600; color: #1e293b; }
	.task-desc { font-size: 12px; color: #64748b; margin-top: 2px; }
	.task-meta { margin-top: 4px; }
	.task-schedule { font-size: 11px; color: #3b82f6; background: rgba(59,130,246,0.08); padding: 2px 8px; border-radius: 4px; }
	.task-delete { border: none; background: none; cursor: pointer; font-size: 14px; opacity: 0.4; transition: opacity 0.15s; }
	.task-delete:hover { opacity: 1; }
	.completed-section { margin-top: 16px; }
	.completed-section summary { cursor: pointer; font-size: 13px; color: #64748b; font-weight: 500; padding: 8px 0; }
	.completed-section .my-tasks-list { margin-top: 8px; }
	.reject-confirm-btn {
		padding: 9px 24px; background: #ef4444; border: none; border-radius: 8px;
		color: white; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.15s;
	}
	.reject-confirm-btn:hover { background: #dc2626; }
	.reject-confirm-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	/* Approver form */
	.checkbox-label { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 14px; color: #334155; }
	.checkbox-label input[type="checkbox"] { width: 18px; height: 18px; accent-color: #3b82f6; cursor: pointer; }
	.branch-checkboxes { display: flex; flex-direction: column; gap: 6px; max-height: 160px; overflow-y: auto;
		padding: 8px; border: 1px solid rgba(203, 213, 225, 0.5); border-radius: 8px; background: rgba(255,255,255,0.5); }
	.branch-check-item { display: flex; align-items: center; gap: 6px; font-size: 13px; color: #334155; cursor: pointer; }
	.branch-check-item input[type="checkbox"] { accent-color: #3b82f6; cursor: pointer; }
</style>
