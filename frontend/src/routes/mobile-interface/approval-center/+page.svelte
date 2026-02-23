<script>
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { goto } from '$app/navigation';
	import { getTranslation, locale } from '$lib/i18n';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { notifications } from '$lib/stores/notifications';

	let loading = true;
	let requisitions = [];
	let paymentSchedules = []; // Pending payment schedules where user is approver
	let vendorPayments = []; // Vendor payments sent for approval
	let approvedPaymentSchedules = []; // Approved payment schedules from expense_scheduler
	let rejectedPaymentSchedules = []; // Rejected payment schedules
	let myCreatedRequisitions = []; // Requisitions created by current user
	let myCreatedSchedules = []; // Payment schedules created by current user
	let myApprovedSchedules = []; // My approved schedules
	let dayOffRequests = []; // Day off requests requiring approval
	let myDayOffRequests = []; // My created day off requests
	let filteredRequisitions = [];
	let filteredMyRequests = [];
	let selectedStatus = 'pending';
	let selectedRequisition = null;
	let showDetailModal = false;
	let isProcessing = false;
	let userCanApprove = false; // Track if current user has approval permissions
	let activeSection = 'approvals'; // 'approvals' or 'my_requests'
	
	// Confirmation modal state
	let showConfirmModal = false;
	let confirmAction = null; // 'approve' or 'reject'
	let pendingRequisitionId = null;
	let rejectionReason = '';

	// Day-off approval modal state
	let showDayOffApproveModal = false;
	let dayOffCheckedDates = {}; // id -> checked (boolean)
	
	// Reactive: Check if user can approve SELECTED item
	$: canApproveSelected = selectedRequisition 
		? (selectedRequisition.item_type === 'payment_schedule' 
			? selectedRequisition.approver_id === $currentUser?.id 
			: userCanApprove)
		: false;

	// Stats for approvals assigned to me
	let stats = {
		pending: 0,
		approved: 0,
		rejected: 0,
		total: 0
	};

	// Stats for my created requests
	let myStats = {
		pending: 0,
		approved: 0,
		rejected: 0,
		total: 0
	};

	onMount(() => {
		loadRequisitions();
	});

	// Track if historical data is loaded
	let historicalDataLoaded = false;

	async function loadRequisitions() {
		try {
			loading = true;
			
			// Check if user is logged in
			if (!$currentUser?.id) {
				notifications.add({ type: 'error', message: t('Please login to access the approval center', 'يرجى تسجيل الدخول للوصول إلى مركز الموافقات') });
				goto('/mobile-interface/login');
				return;
			}

	// Get all approval center data via single RPC call
	const { supabase } = await import('$lib/utils/supabase');
	const { data: rpcResult, error: rpcError } = await supabase.rpc('get_approval_center_data', {
		p_user_id: $currentUser.id
	});

	if (rpcError) {
		console.error('❌ RPC error:', rpcError);
		notifications.add({ type: 'error', message: t('Error loading approval data', 'خطأ في تحميل بيانات الموافقات') });
		loading = false;
		return;
	}

	console.log('✅ Approval center RPC result received');

	// Extract approval permissions
	const approvalPerms = rpcResult.permissions || null;

	if (approvalPerms) {
		userCanApprove = 
			approvalPerms.can_approve_requisitions ||
			approvalPerms.can_approve_single_bill ||
			approvalPerms.can_approve_multiple_bill ||
			approvalPerms.can_approve_recurring_bill ||
			approvalPerms.can_approve_vendor_payments ||
			approvalPerms.can_approve_leave_requests;
	} else {
		userCanApprove = false;
	}
	console.log('👤 User approval permission:', userCanApprove);

	// Two days date for filtering
	const twoDaysDate = rpcResult.two_days_date;

	// Map requisitions + attach usernames
	const userNamesMap = rpcResult.user_names || {};
	requisitions = (rpcResult.requisitions || []).map(req => ({
		...req,
		created_by_username: userNamesMap[req.created_by]?.username || req.created_by || 'Unknown'
	}));
	console.log('✅ Loaded requisitions:', requisitions.length);

	// Payment schedules - filter single_bill by due date
	paymentSchedules = (rpcResult.payment_schedules || []).filter(schedule => {
		if (schedule.schedule_type === 'multiple_bill') return true;
		return schedule.due_date && schedule.due_date <= twoDaysDate;
	});
	console.log('✅ Loaded payment schedules:', paymentSchedules.length);

	// Vendor payments - filter by amount limit
	vendorPayments = (rpcResult.vendor_payments || []).filter(payment => {
		if (!approvalPerms || !approvalPerms.can_approve_vendor_payments) return false;
		const paymentAmount = payment.final_bill_amount || payment.bill_amount || 0;
		if (approvalPerms.vendor_payment_amount_limit === 0) return true;
		return approvalPerms.vendor_payment_amount_limit >= paymentAmount;
	});
	console.log('✅ Loaded vendor payments for approval:', vendorPayments.length);

	// My created requisitions
	myCreatedRequisitions = rpcResult.my_requisitions || [];
	console.log('✅ My created requisitions:', myCreatedRequisitions.length);

	// My created schedules
	myCreatedSchedules = rpcResult.my_schedules || [];
	console.log('✅ My created payment schedules:', myCreatedSchedules.length);

	// Day off requests - apply employee names from RPC
	const employeeNamesMap = rpcResult.employee_names || {};
	{
		let rawDayOffs = rpcResult.day_off_requests || [];
		// Enrich requester with employee names
		rawDayOffs = rawDayOffs.map(d => {
			if (d.requester?.id && employeeNamesMap[d.requester.id]) {
				return { ...d, requester: { ...d.requester, name_en: employeeNamesMap[d.requester.id].name_en, name_ar: employeeNamesMap[d.requester.id].name_ar } };
			}
			return d;
		});
		dayOffRequests = groupDayOffRequests(rawDayOffs);
	}
	console.log('✅ Day off requests for approval (grouped):', dayOffRequests.length);

	// My day off requests
	myDayOffRequests = groupDayOffRequests(rpcResult.my_day_off_requests || []);
	console.log('✅ My day off requests (grouped):', myDayOffRequests.length);

	// Enrich vendor payments with employee names
	vendorPayments = vendorPayments.map(v => {
		if (v.requester?.id && employeeNamesMap[v.requester.id]) {
			return { ...v, requester: { ...v.requester, name_en: employeeNamesMap[v.requester.id].name_en, name_ar: employeeNamesMap[v.requester.id].name_ar } };
		}
		return v;
	});

	// Initialize empty arrays for historical data (will load on demand)
	myApprovedSchedules = [];
	approvedPaymentSchedules = [];
	rejectedPaymentSchedules = [];

	// Calculate stats (only pending for now, historical data will be loaded on demand)
	stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + dayOffRequests.length;
	stats.approved = 0;
	stats.rejected = 0;
	stats.total = stats.pending;

	// Stats for my created requests (only pending initially)
	myStats.pending = myCreatedRequisitions.length + myCreatedSchedules.length + myDayOffRequests.length;
		myStats.approved = 0; // Will be loaded on demand
		myStats.rejected = 0; // Will be loaded on demand
		myStats.total = myStats.pending;

		console.log('📈 Approval Stats:', stats);
		console.log('📈 My Requests Stats:', myStats);

		filterRequisitions();
		
		// Load historical data in background after initial display
		loadHistoricalData();
	} catch (err) {
		console.error('Error loading requisitions:', err);
		notifications.add({ type: 'error', message: t('Error loading requisitions: ', 'خطأ في تحميل الطلبات: ') + err.message });
	} finally {
		loading = false;
	}
}

// Load historical (approved/rejected) data in background
async function loadHistoricalData() {
	if (historicalDataLoaded || !$currentUser?.id) return;
	
	try {
		console.log('📚 Loading historical data in background...');
		
		const { supabase } = await import('$lib/utils/supabase');
		
		const [
			approvedReqsResult,
			rejectedReqsResult,
			myApprovedSchedulesResult,
			approvedSchedulesResult,
			rejectedSchedulesResult,
			myApprovedReqsResult,
			myRejectedReqsResult,
			myRejectedSchedulesResult
		] = await Promise.all([
		// Approved requisitions where I'm approver
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('approver_id', $currentUser.id)
			.eq('status', 'approved')
			.order('created_at', { ascending: false })
			.limit(1000),		// Rejected requisitions where I'm approver
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('approver_id', $currentUser.id)
			.eq('status', 'rejected')
			.order('created_at', { ascending: false })
			.limit(1000),		// My approved/rejected schedules from expense_scheduler
		supabase
			.from('expense_scheduler')
			.select(`
				*,
				approver:users!approver_id (
					id,
					username
				)
			`)
			.eq('created_by', $currentUser.id)
			.not('schedule_type', 'eq', 'recurring')
			.not('schedule_type', 'eq', 'expense_requisition')
			.order('created_at', { ascending: false })
			.limit(1000),		// Approved payment schedules where I was the approver
		supabase
			.from('expense_scheduler')
			.select(`
				*,
				creator:users!created_by (
					id,
					username
				)
			`)
			.eq('approver_id', $currentUser.id)
			.not('schedule_type', 'eq', 'recurring')
			.not('schedule_type', 'eq', 'expense_requisition')
			.order('created_at', { ascending: false })
			.limit(1000),		// Rejected schedules where I was the approver
		supabase
			.from('non_approved_payment_scheduler')
			.select(`
				*,
				creator:users!created_by (
					id,
					username
				)
			`)
			.eq('approver_id', $currentUser.id)
			.eq('approval_status', 'rejected')
			.order('created_at', { ascending: false })
			.limit(1000),		// My approved requisitions
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('created_by', $currentUser.id)
			.eq('status', 'approved')
			.order('created_at', { ascending: false })
			.limit(1000),
		
		// My rejected requisitions
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('created_by', $currentUser.id)
			.eq('status', 'rejected')
			.order('created_at', { ascending: false })
			.limit(1000),
		
		// My rejected schedules
		supabase
			.from('non_approved_payment_scheduler')
			.select(`
				*,
				approver:users!approver_id (
					id,
					username
				)
			`)
			.eq('created_by', $currentUser.id)
			.eq('approval_status', 'rejected')
			.in('schedule_type', ['single_bill', 'multiple_bill'])
			.order('created_at', { ascending: false })
			.limit(1000)
		]);
		
		// Process and merge results with existing data
		const { data: approvedReqs } = approvedReqsResult;
		const { data: rejectedReqs } = rejectedReqsResult;
		
		if (approvedReqs) requisitions = [...requisitions, ...approvedReqs];
		if (rejectedReqs) requisitions = [...requisitions, ...rejectedReqs];
		
		const { data: myApprovedSchedulesData } = myApprovedSchedulesResult;
		if (myApprovedSchedulesData) myApprovedSchedules = myApprovedSchedulesData;
		
		const { data: approvedSchedulesData } = approvedSchedulesResult;
		if (approvedSchedulesData) approvedPaymentSchedules = approvedSchedulesData;
		
		const { data: rejectedSchedulesData } = rejectedSchedulesResult;
		if (rejectedSchedulesData) rejectedPaymentSchedules = rejectedSchedulesData;
		
		const { data: myApprovedReqs } = myApprovedReqsResult;
		const { data: myRejectedReqs } = myRejectedReqsResult;
		const { data: myRejectedSchedulesData } = myRejectedSchedulesResult;
		
		if (myApprovedReqs) myCreatedRequisitions = [...myCreatedRequisitions, ...myApprovedReqs];
		if (myRejectedReqs) myCreatedRequisitions = [...myCreatedRequisitions, ...myRejectedReqs];
		if (myRejectedSchedulesData) myCreatedSchedules = [...myCreatedSchedules, ...myRejectedSchedulesData];
		
		// Update stats with complete data
		stats.approved = (approvedReqs?.length || 0) + (approvedSchedulesData?.length || 0);
		stats.rejected = (rejectedReqs?.length || 0) + (rejectedSchedulesData?.length || 0);
		stats.total = stats.pending + stats.approved + stats.rejected;
		
		myStats.approved = (myApprovedReqs?.length || 0) + (myApprovedSchedulesData?.length || 0);
		myStats.rejected = (myRejectedReqs?.length || 0) + (myRejectedSchedulesData?.length || 0);
		myStats.total = myStats.pending + myStats.approved + myStats.rejected;
		
		historicalDataLoaded = true;
		console.log('✅ Historical data loaded in background');
		console.log('📈 Updated Approval Stats:', stats);
		console.log('📈 Updated My Requests Stats:', myStats);
		
		// Refresh filtered lists if user is viewing historical data
		if (selectedStatus !== 'pending') {
			filterRequisitions();
		}
	} catch (err) {
		console.error('❌ Error loading historical data:', err);
	}
}

	// Group day-off records that belong to the same leave request (same employee + same requested_at timestamp)
	function groupDayOffRequests(dayOffs) {
		const groups = new Map();
		for (const d of dayOffs) {
			// Truncate timestamp to minute level so batch inserts with slightly different seconds still group together
			let approvalMinute = '';
			if (d.approval_requested_at) {
				const dt = new Date(d.approval_requested_at);
				approvalMinute = `${dt.getFullYear()}-${dt.getMonth()}-${dt.getDate()}-${dt.getHours()}-${dt.getMinutes()}`;
			}
			// Group by employee_id + approval time (minute) + reason (same batch submission)
			const key = `${d.employee_id}_${approvalMinute}_${d.day_off_reason_id || ''}`;
			if (!groups.has(key)) {
				groups.set(key, []);
			}
			groups.get(key).push(d);
		}
		
		const grouped = [];
		for (const [key, records] of groups) {
			// Sort records by date
			records.sort((a, b) => (a.day_off_date || '').localeCompare(b.day_off_date || ''));
			
			const first = records[0];
			const last = records[records.length - 1];
			
			grouped.push({
				...first,
				// Add grouped info
				_grouped: true,
				_allIds: records.map(r => r.id),
				_allDates: records.map(r => r.day_off_date),
				_dateFrom: first.day_off_date,
				_dateTo: last.day_off_date,
				_dayCount: records.length
			});
		}
		
		return grouped;
	}

	function filterRequisitions() {
		if (activeSection === 'approvals') {
			// Filter approvals assigned to me
			let filtered = requisitions;
			let filteredSchedules = [];
			let filteredDayOffs = [];

			// Filter requisitions by status
			if (selectedStatus !== 'all') {
				filtered = filtered.filter(r => r.status === selectedStatus);
			}

			// Filter payment schedules based on status
			if (selectedStatus === 'all') {
				filteredSchedules = [...paymentSchedules, ...approvedPaymentSchedules, ...rejectedPaymentSchedules];
			} else if (selectedStatus === 'pending') {
				filteredSchedules = [...paymentSchedules];
			} else if (selectedStatus === 'approved') {
				filteredSchedules = [...approvedPaymentSchedules];
			} else if (selectedStatus === 'rejected') {
				filteredSchedules = [...rejectedPaymentSchedules];
			}

			// Filter day off requests based on status
			if (selectedStatus === 'all' || selectedStatus === 'pending') {
				filteredDayOffs = dayOffRequests;
			}

			// Combine filtered requisitions, payment schedules, vendor payments, and day off requests
			filteredRequisitions = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					approval_status: s.approval_status || 'approved'
				})),
				...(selectedStatus === 'pending' || selectedStatus === 'all' 
					? vendorPayments.map(v => ({ ...v, item_type: 'vendor_payment' }))
					: []),
				...filteredDayOffs.map(d => ({ ...d, item_type: 'day_off' }))
			];
		} else {
			// Filter my created requests
			let filtered = myCreatedRequisitions;
			let filteredSchedules = [];
			let filteredMyDayOffs = [];

			// Filter by status
			if (selectedStatus === 'all') {
				// Show all requisitions
				filtered = myCreatedRequisitions;
				// Combine all schedules: pending + rejected (from myCreatedSchedules) + approved (from myApprovedSchedules)
				filteredSchedules = [...myCreatedSchedules, ...myApprovedSchedules];
				// All day off requests
				filteredMyDayOffs = myDayOffRequests;
			} else {
				// Filter requisitions by status
				filtered = myCreatedRequisitions.filter(r => r.status === selectedStatus);
				
				// Filter schedules by status
				if (selectedStatus === 'pending') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'pending');
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'pending');
				} else if (selectedStatus === 'approved') {
					filteredSchedules = myApprovedSchedules;
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'approved');
				} else if (selectedStatus === 'rejected') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'rejected');
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'rejected');
				}
			}

			// Combine filtered requests
			filteredMyRequests = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					approval_status: s.approval_status || 'approved'
				})),
				...filteredMyDayOffs.map(d => ({ ...d, item_type: 'day_off' }))
			];
			
			console.log('🔍 Filtered my requests:', {
				requisitions: filtered.length,
				schedules: filteredSchedules.length,
				dayOffs: filteredMyDayOffs.length,
				total: filteredMyRequests.length
			});
		}
		
		console.log('📊 Filtered approvals:', {
			forMe: activeSection === 'approvals' ? filteredRequisitions.length : 0,
			myRequests: activeSection === 'my_requests' ? filteredMyRequests.length : 0
		});
	}

	function filterByStatus(status) {
		selectedStatus = status;
		filterRequisitions();
	}

	function openDetail(requisition) {
		selectedRequisition = requisition;
		showDetailModal = true;
	}

	function closeDetail() {
		showDetailModal = false;
		selectedRequisition = null;
	}

	// Open confirmation modal
	function openConfirmModal(action) {
		if (!selectedRequisition) return;
		confirmAction = action;
		rejectionReason = '';
		showConfirmModal = true;
	}

	// Show confirmation modal for approval
	function showApprovalConfirm() {
		if (!selectedRequisition) return;
		pendingRequisitionId = selectedRequisition.id;
		confirmAction = 'approve';
		showConfirmModal = true;
	}

	// Show confirmation modal for rejection
	function showRejectionConfirm() {
		if (!selectedRequisition) return;
		pendingRequisitionId = selectedRequisition.id;
		confirmAction = 'reject';
		rejectionReason = '';
		showConfirmModal = true;
	}

	// Open day-off approve modal with all dates pre-checked
	function openDayOffApproveModal(req) {
		selectedRequisition = req;
		dayOffCheckedDates = {};
		const allIds = req._allIds || [req.id];
		const allDates = req._allDates || [req.day_off_date];
		for (let i = 0; i < allIds.length; i++) {
			dayOffCheckedDates[allIds[i]] = true;
		}
		showDayOffApproveModal = true;
	}

	// Reject day-off instantly (all days, no popup)
	async function rejectDayOffInstant(req) {
		if (isProcessing) return;
		selectedRequisition = req;
		try {
			isProcessing = true;
			const { supabase } = await import('$lib/utils/supabase');
			const idsToReject = req._allIds || [req.id];
			const { error: updateError } = await supabase
				.from('day_off')
				.update({
					approval_status: 'rejected',
					approval_approved_by: $currentUser.id,
					approval_approved_at: new Date().toISOString(),
					rejection_reason: 'Rejected by approver'
				})
				.in('id', idsToReject);

			if (updateError) throw updateError;

			// Send notification
			try {
				if (req.approval_requested_by) {
					const dateInfo = req._dayCount > 1
						? `from ${req._dateFrom} to ${req._dateTo} (${req._dayCount} days)`
						: `for ${req.day_off_date}`;
					await notificationService.createNotification({
						title: 'Leave Request Rejected',
						message: `Your leave request ${dateInfo} has been rejected.\n\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [req.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
				}
			} catch (notifError) {
				console.error('⚠️ Failed to send rejection notification:', notifError);
			}

			notifications.add({ type: 'success', message: t('Leave request rejected.', 'تم رفض طلب الإجازة.') });
			await loadRequisitions();
		} catch (err) {
			console.error('Error rejecting day off:', err);
			notifications.add({ type: 'error', message: t('Failed to reject leave request.', 'فشل في رفض طلب الإجازة.') });
		} finally {
			isProcessing = false;
			selectedRequisition = null;
		}
	}

	// Confirm day-off approval (approve checked, reject unchecked)
	async function confirmDayOffApproval() {
		if (!selectedRequisition || isProcessing) return;
		try {
			isProcessing = true;
			const { supabase } = await import('$lib/utils/supabase');
			const allIds = selectedRequisition._allIds || [selectedRequisition.id];
			const approvedIds = allIds.filter(id => dayOffCheckedDates[id]);
			const rejectedIds = allIds.filter(id => !dayOffCheckedDates[id]);

			// Approve checked days
			if (approvedIds.length > 0) {
				const { error } = await supabase
					.from('day_off')
					.update({
						approval_status: 'approved',
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString()
					})
					.in('id', approvedIds);
				if (error) throw error;
			}

			// Reject unchecked days
			if (rejectedIds.length > 0) {
				const { error } = await supabase
					.from('day_off')
					.update({
						approval_status: 'rejected',
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString(),
						rejection_reason: 'Partially rejected by approver'
					})
					.in('id', rejectedIds);
				if (error) throw error;
			}

			// Send notification
			try {
				if (selectedRequisition.approval_requested_by) {
					let message = '';
					if (rejectedIds.length === 0) {
						const dateInfo = approvedIds.length > 1
							? `from ${selectedRequisition._dateFrom} to ${selectedRequisition._dateTo} (${approvedIds.length} days)`
							: `for ${selectedRequisition.day_off_date}`;
						message = `Your leave request ${dateInfo} has been approved!\n\nApproved by: ${$currentUser?.username}`;
					} else {
						message = `Your leave request has been partially approved.\n\n✅ Approved: ${approvedIds.length} day(s)\n❌ Rejected: ${rejectedIds.length} day(s)\n\nApproved/Rejected by: ${$currentUser?.username}`;
					}
					await notificationService.createNotification({
						title: rejectedIds.length === 0 ? 'Leave Request Approved' : 'Leave Request Partially Approved',
						message,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [selectedRequisition.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
				}
			} catch (notifError) {
				console.error('⚠️ Failed to send notification:', notifError);
			}

			const msg = rejectedIds.length === 0
				? t('Leave request approved!', 'تمت الموافقة على طلب الإجازة!')
				: `${t('Leave', 'إجازة')}: ${approvedIds.length} ${t('approved', 'موافق')}, ${rejectedIds.length} ${t('rejected', 'مرفوض')}.`;
			notifications.add({ type: 'success', message: msg });
			showDayOffApproveModal = false;
			await loadRequisitions();
		} catch (err) {
			console.error('Error processing day off approval:', err);
			notifications.add({ type: 'error', message: t('Failed to process leave request.', 'فشل في معالجة طلب الإجازة.') });
		} finally {
			isProcessing = false;
			selectedRequisition = null;
		}
	}

	// Cancel confirmation
	function cancelConfirm() {
		showConfirmModal = false;
		confirmAction = null;
		pendingRequisitionId = null;
		rejectionReason = '';
	}

	// Confirm action
	async function confirmActionHandler() {
		if (confirmAction === 'approve') {
			showConfirmModal = false;
			await approveRequisition();
		} else if (confirmAction === 'reject') {
			if (!rejectionReason.trim()) {
			notifications.add({ type: 'error', message: t('Please provide a reason for rejection', 'يرجى تقديم سبب للرفض') });
				return;
			}
			showConfirmModal = false;
			await rejectRequisition(rejectionReason);
		}
		cancelConfirm();
	}

	async function approveRequisition() {
		if (!selectedRequisition || isProcessing) return;

		try {
			isProcessing = true;
			const { supabase } = await import('$lib/utils/supabase');

			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the full payment schedule data
				const { data: scheduleData, error: fetchError } = await supabase
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Move to expense_scheduler
				const { error: insertError } = await supabase
					.from('expense_scheduler')
					.insert([{
						schedule_type: scheduleData.schedule_type,
						branch_id: scheduleData.branch_id,
						branch_name: scheduleData.branch_name,
						expense_category_id: scheduleData.expense_category_id,
						expense_category_name_en: scheduleData.expense_category_name_en,
						expense_category_name_ar: scheduleData.expense_category_name_ar,
						requisition_id: null,
						requisition_number: null,
						co_user_id: scheduleData.co_user_id,
						co_user_name: scheduleData.co_user_name,
						payment_method: scheduleData.payment_method,
						amount: scheduleData.amount,
						description: scheduleData.description,
						bill_type: scheduleData.bill_type,
						bill_number: scheduleData.bill_number,
						bill_date: scheduleData.bill_date,
						bill_file_url: scheduleData.bill_file_url,
						due_date: scheduleData.due_date,
						credit_period: scheduleData.credit_period,
						bank_name: scheduleData.bank_name,
						iban: scheduleData.iban,
						status: 'pending',
						is_paid: false,
						recurring_type: scheduleData.recurring_type,
						recurring_metadata: scheduleData.recurring_metadata,
						approver_id: scheduleData.approver_id,
						approver_name: scheduleData.approver_name,
						created_by: scheduleData.created_by
					}]);

				if (insertError) throw insertError;

				// Delete from non_approved_payment_scheduler
				const { error: deleteError } = await supabase
					.from('non_approved_payment_scheduler')
					.delete()
					.eq('id', selectedRequisition.id);

				if (deleteError) throw deleteError;

				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: 'Payment Schedule Approved',
						message: `Your ${scheduleData.schedule_type.replace('_', ' ')} payment schedule has been approved!\n\nBranch: ${scheduleData.branch_name}\nCategory: ${scheduleData.expense_category_name_en}\nAmount: ${parseFloat(scheduleData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nDue Date: ${scheduleData.due_date}\nApproved by: ${$currentUser?.username}`,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [scheduleData.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Approval notification sent to creator:', scheduleData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Payment schedule approved and moved to expense scheduler!', 'تمت الموافقة على جدول الدفع ونقله إلى جدولة المصروفات!') });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Approve vendor payment
				const { data: paymentData, error: fetchError } = await supabase
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabase
					.from('vendor_payment_schedule')
					.update({
						approval_status: 'approved',
						approved_by: $currentUser?.id,
						approved_at: new Date().toISOString(),
						approval_notes: 'Approved from Mobile Approval Center'
					})
					.eq('id', selectedRequisition.id);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					await notificationService.createNotification({
						title: 'Vendor Payment Approved',
						message: `Your vendor payment has been approved!\n\nVendor: ${paymentData.vendor_name}\nBill Number: ${paymentData.bill_number}\nAmount: ${parseFloat(paymentData.final_bill_amount || paymentData.bill_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nBranch: ${paymentData.branch_name}\nApproved by: ${$currentUser?.username}`,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [paymentData.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Approval notification sent to requester:', paymentData.approval_requested_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Vendor payment approved successfully!', 'تمت الموافقة على دفع المورد بنجاح!') });
			} else if (selectedRequisition.item_type === 'day_off') {
				// Approve day off request (all records in group)
				const idsToUpdate = selectedRequisition._allIds || [selectedRequisition.id];
				const { error: updateError } = await supabase
					.from('day_off')
					.update({
						approval_status: 'approved',
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString()
					})
					.in('id', idsToUpdate);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					if (selectedRequisition.approval_requested_by) {
						const dateInfo = selectedRequisition._dayCount > 1
							? `from ${selectedRequisition._dateFrom} to ${selectedRequisition._dateTo} (${selectedRequisition._dayCount} days)`
							: `for ${selectedRequisition.day_off_date}`;
						await notificationService.createNotification({
							title: 'Leave Request Approved',
							message: `Your leave request ${dateInfo} has been approved!\n\nApproved by: ${$currentUser?.username}`,
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [selectedRequisition.approval_requested_by]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log('✅ Approval notification sent to requester:', selectedRequisition.approval_requested_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Leave request approved successfully!', 'تمت الموافقة على طلب الإجازة بنجاح!') });
			} else {
				// Update regular requisition
				const { error } = await supabase
					.from('expense_requisitions')
					.update({
						status: 'approved',
						updated_at: new Date().toISOString()
					})
					.eq('id', selectedRequisition.id);

				if (error) throw error;

				// Create entry in expense_scheduler
				const schedulerEntry = {
					branch_id: selectedRequisition.branch_id,
					branch_name: selectedRequisition.branch_name,
					expense_category_id: selectedRequisition.expense_category_id || null,
					expense_category_name_en: selectedRequisition.expense_category_name_en || null,
					expense_category_name_ar: selectedRequisition.expense_category_name_ar || null,
					requisition_id: selectedRequisition.id,
					requisition_number: selectedRequisition.requisition_number,
					co_user_id: null,
					co_user_name: selectedRequisition.requester_name || null,
					bill_type: 'no_bill',
					payment_method: selectedRequisition.payment_category || 'cash',
					due_date: selectedRequisition.due_date,
					amount: parseFloat(selectedRequisition.amount),
					description: selectedRequisition.description,
					schedule_type: 'expense_requisition',
					status: 'pending',
					is_paid: false,
					approver_id: selectedRequisition.approver_id,
					approver_name: selectedRequisition.approver_name,
					created_by: selectedRequisition.created_by,
					vendor_id: selectedRequisition.vendor_id || null,
					vendor_name: selectedRequisition.vendor_name || null
				};

				const { error: schedulerError } = await supabase
					.from('expense_scheduler')
					.insert([schedulerEntry]);

				if (schedulerError) {
					console.error('⚠️ Failed to create expense scheduler entry:', schedulerError);
				} else {
					console.log('✅ Created expense scheduler entry for approved requisition');
				}

				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: 'Expense Requisition Approved',
						message: `Your expense requisition has been approved!\n\nRequisition: ${selectedRequisition.requisition_number}\nRequester: ${selectedRequisition.requester_name}\nBranch: ${selectedRequisition.branch_name}\nCategory: ${selectedRequisition.expense_category_name_en}\nAmount: ${parseFloat(selectedRequisition.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nApproved by: ${$currentUser?.username}`,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [selectedRequisition.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Approval notification sent to creator:', selectedRequisition.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

		notifications.add({ type: 'success', message: t('Requisition approved successfully!', 'تمت الموافقة على الطلب بنجاح!') });
	}

	// Remove from pending lists without reloading
	requisitions = requisitions.filter(r => r.id !== selectedRequisition.id);
	paymentSchedules = paymentSchedules.filter(s => s.id !== selectedRequisition.id);
	vendorPayments = vendorPayments.filter(v => v.id !== selectedRequisition.id);
	dayOffRequests = dayOffRequests.filter(d => d.id !== selectedRequisition.id);
	
	// Update stats
	stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + dayOffRequests.length;
	stats.total = stats.pending + stats.approved + stats.rejected;
	
	// Refresh filtered lists
	filterRequisitions();
	
	closeDetail();
} catch (err) {
	console.error('Error approving:', err);
	notifications.add({ type: 'error', message: t('Error approving: ', 'خطأ في الموافقة: ') + err.message });
} finally {
	isProcessing = false;
}
}

async function rejectRequisition(reason) {
	if (!selectedRequisition || isProcessing) return;

	try {
		isProcessing = true;
		const { supabase } = await import('$lib/utils/supabase');			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Update payment schedule
				const { error } = await supabase
					.from('non_approved_payment_scheduler')
					.update({
						approval_status: 'rejected',
						updated_at: new Date().toISOString()
					})
					.eq('id', selectedRequisition.id);

				if (error) throw error;

				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: 'Payment Schedule Rejected',
						message: `Your ${selectedRequisition.schedule_type?.replace('_', ' ') || 'payment schedule'} has been rejected.\n\nReason: ${reason}\n\nBranch: ${selectedRequisition.branch_name}\nCategory: ${selectedRequisition.expense_category_name_en}\nAmount: ${parseFloat(selectedRequisition.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [selectedRequisition.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Rejection notification sent to creator:', selectedRequisition.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Payment schedule rejected.', 'تم رفض جدول الدفع.') });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Reject vendor payment
				const { data: paymentData, error: fetchError } = await supabase
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabase
					.from('vendor_payment_schedule')
					.update({
						approval_status: 'rejected',
						approved_by: $currentUser?.id,
						approved_at: new Date().toISOString(),
						approval_notes: `Rejected: ${reason}`
					})
					.eq('id', selectedRequisition.id);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					await notificationService.createNotification({
						title: 'Vendor Payment Rejected',
						message: `Your vendor payment has been rejected.\n\nReason: ${reason}\n\nVendor: ${paymentData.vendor_name}\nBill Number: ${paymentData.bill_number}\nAmount: ${parseFloat(paymentData.final_bill_amount || paymentData.bill_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nBranch: ${paymentData.branch_name}\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [paymentData.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Rejection notification sent to requester:', paymentData.approval_requested_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Vendor payment rejected.', 'تم رفض دفع المورد.') });
			} else if (selectedRequisition.item_type === 'day_off') {
				// Reject day off request (all records in group)
				const idsToUpdate = selectedRequisition._allIds || [selectedRequisition.id];
				const { error: updateError } = await supabase
					.from('day_off')
					.update({
						approval_status: 'rejected',
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString(),
						rejection_reason: reason
					})
					.in('id', idsToUpdate);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					if (selectedRequisition.approval_requested_by) {
						const dateInfo = selectedRequisition._dayCount > 1
							? `from ${selectedRequisition._dateFrom} to ${selectedRequisition._dateTo} (${selectedRequisition._dayCount} days)`
							: `for ${selectedRequisition.day_off_date}`;
						await notificationService.createNotification({
							title: 'Leave Request Rejected',
							message: `Your leave request ${dateInfo} has been rejected.\n\nReason: ${reason}\n\nRejected by: ${$currentUser?.username}`,
							type: 'assignment_rejected',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [selectedRequisition.approval_requested_by]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log('✅ Rejection notification sent to requester:', selectedRequisition.approval_requested_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Leave request rejected.', 'تم رفض طلب الإجازة.') });
			} else {
				// Update regular requisition
				const { error } = await supabase
					.from('expense_requisitions')
					.update({
						status: 'rejected',
						updated_at: new Date().toISOString(),
						description: selectedRequisition.description 
							? `${selectedRequisition.description}\n\nRejection Reason: ${reason}`
							: `Rejection Reason: ${reason}`
					})
					.eq('id', selectedRequisition.id);

				if (error) throw error;

				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: 'Expense Requisition Rejected',
						message: `Your expense requisition has been rejected.\n\nReason: ${reason}\n\nRequisition: ${selectedRequisition.requisition_number}\nRequester: ${selectedRequisition.requester_name}\nBranch: ${selectedRequisition.branch_name}\nCategory: ${selectedRequisition.expense_category_name_en}\nAmount: ${parseFloat(selectedRequisition.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [selectedRequisition.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Rejection notification sent to creator:', selectedRequisition.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('Requisition rejected.', 'تم رفض الطلب.') });
			}

			// Remove from pending lists without reloading
			requisitions = requisitions.filter(r => r.id !== selectedRequisition.id);
			paymentSchedules = paymentSchedules.filter(s => s.id !== selectedRequisition.id);
			vendorPayments = vendorPayments.filter(v => v.id !== selectedRequisition.id);
			
			// Update stats
			stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length;
			stats.total = stats.pending + stats.approved + stats.rejected;
			
			// Refresh filtered lists
			filterRequisitions();
			
			closeDetail();
		} catch (err) {
			console.error('Error rejecting:', err);
			notifications.add({ type: 'error', message: t('Error rejecting: ', 'خطأ في الرفض: ') + err.message });
		} finally {
			isProcessing = false;
		}
	}

	function formatDate(dateString) {
		if (!dateString) return t('N/A', 'غير متوفر');
		return new Date(dateString).toLocaleDateString(isAr ? 'ar-EG' : 'en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit',
			timeZone: 'Asia/Riyadh'
		});
	}

	function formatDateOnly(dateString) {
		if (!dateString) return t('N/A', 'غير متوفر');
		return new Date(dateString).toLocaleDateString(isAr ? 'ar-EG' : 'en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			timeZone: 'Asia/Riyadh'
		});
	}

	function formatAmount(amount) {
		if (!amount) return '0.00';
		return parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	// Bilingual helper
	$: isAr = $locale === 'ar';
	function t(en, ar) { return isAr ? ar : en; }
	function translateStatus(status) {
		if (!status) return t('PENDING', 'قيد الانتظار');
		const map = {
			'pending': t('PENDING', 'قيد الانتظار'),
			'approved': t('APPROVED', 'موافق'),
			'rejected': t('REJECTED', 'مرفوض'),
			'sent_for_approval': t('SENT FOR APPROVAL', 'مرسل للموافقة'),
		};
		return map[status.toLowerCase()] || status.toUpperCase();
	}

	function timeAgo(dateString) {
		if (!dateString) return t('N/A', 'غير متوفر');
		const now = new Date();
		const date = new Date(dateString);
		const diffMs = now - date;
		const diffSec = Math.floor(diffMs / 1000);
		const diffMin = Math.floor(diffSec / 60);
		const diffHr = Math.floor(diffMin / 60);
		const diffDays = Math.floor(diffHr / 24);

		if (diffDays === 0) {
			if (diffSec < 60) return t('Just now', 'الآن');
			if (diffMin < 60) return isAr ? `منذ ${diffMin} دقيقة` : `${diffMin}m ago`;
			return isAr ? `منذ ${diffHr} ساعة` : `${diffHr}h ago`;
		}
		return isAr ? `منذ ${diffDays} يوم` : `${diffDays} days ago`;
	}
</script>

<div class="mobile-approval-center" dir={isAr ? 'rtl' : 'ltr'}>
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>{t('Loading requisitions...', 'جاري تحميل الطلبات...')}</p>
		</div>
	{:else}
		<!-- Section Tabs -->
		<div class="section-tabs">
			<button 
				class="tab-button {activeSection === 'approvals' ? 'active' : ''}"
				on:click={() => { activeSection = 'approvals'; filterRequisitions(); }}
			>
				📋 {t('Approvals for Me', 'الموافقات لي')}
				{#if stats.pending > 0}
					<span class="badge">{stats.pending}</span>
				{/if}
			</button>
			<button 
				class="tab-button {activeSection === 'my_requests' ? 'active' : ''}"
				on:click={() => { activeSection = 'my_requests'; filterRequisitions(); }}
			>
				📝 {t('My Requests', 'طلباتي')}
				{#if myStats.pending > 0}
					<span class="badge">{myStats.pending}</span>
				{/if}
			</button>
		</div>

		<!-- Stats Cards -->
		<div class="stats-grid">
			{#if activeSection === 'approvals'}
				<div class="stat-card pending" on:click={() => filterByStatus('pending')}>
					<div class="stat-value">{stats.pending}</div>
					<div class="stat-label">⏳ {getTranslation('approvals.pending')}</div>
				</div>
				<div class="stat-card approved" on:click={() => filterByStatus('approved')}>
					<div class="stat-value">{stats.approved}</div>
					<div class="stat-label">✅ {getTranslation('approvals.approved')}</div>
				</div>
				<div class="stat-card rejected" on:click={() => filterByStatus('rejected')}>
					<div class="stat-value">{stats.rejected}</div>
					<div class="stat-label">❌ {getTranslation('approvals.rejected')}</div>
				</div>
				<div class="stat-card total" on:click={() => filterByStatus('all')}>
					<div class="stat-value">{stats.total}</div>
					<div class="stat-label">📊 {getTranslation('approvals.total')}</div>
				</div>
			{:else}
				<div class="stat-card pending" on:click={() => filterByStatus('pending')}>
					<div class="stat-value">{myStats.pending}</div>
					<div class="stat-label">⏳ {getTranslation('approvals.pending')}</div>
				</div>
				<div class="stat-card approved" on:click={() => filterByStatus('approved')}>
					<div class="stat-value">{myStats.approved}</div>
					<div class="stat-label">✅ {getTranslation('approvals.approved')}</div>
				</div>
				<div class="stat-card rejected" on:click={() => filterByStatus('rejected')}>
					<div class="stat-value">{myStats.rejected}</div>
					<div class="stat-label">❌ {getTranslation('approvals.rejected')}</div>
				</div>
				<div class="stat-card total" on:click={() => filterByStatus('all')}>
					<div class="stat-value">{myStats.total}</div>
					<div class="stat-label">📊 {getTranslation('approvals.total')}</div>
				</div>
			{/if}
		</div>

		<!-- Requisitions List -->
		<div class="requisitions-list">
			{#if activeSection === 'approvals' && filteredRequisitions.length === 0}
				<div class="empty-state">
					<div class="empty-icon">📋</div>
					<p>{t('No approvals assigned to you', 'لا توجد موافقات مخصصة لك')}</p>
				</div>
			{:else if activeSection === 'my_requests' && filteredMyRequests.length === 0}
				<div class="empty-state">
					<div class="empty-icon">📋</div>
					<p>{t("You haven't created any requests yet", 'لم تقم بإنشاء أي طلبات بعد')}</p>
				</div>
			{:else}
				{#each (activeSection === 'approvals' ? filteredRequisitions : filteredMyRequests) as req (req.id || req.requisition_number)}
					<div 
						class="req-card"
					>
						<div class="card-header">
							<div class="card-title" on:click={() => openDetail(req)}>
								{#if req.item_type === 'requisition'}
							<!-- Expense Requisition Card -->
							<div class="req-header">
								<div class="req-number">{req.requisition_number}</div>
								<div class="status-badge status-{req.status}">{translateStatus(req.status)}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">{t('Branch', 'الفرع')}:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{activeSection === 'approvals' ? t('Generated by', 'أنشأ بواسطة') : t('Approver', 'المعتمد')}:</span>
									<span class="value">👤 {activeSection === 'approvals' ? req.created_by_username : (req.approver_name || t('Not Assigned', 'غير معين'))}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Amount', 'المبلغ')}:</span>
									<span class="value amount">SAR {formatAmount(req.amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Due Date', 'تاريخ الاستحقاق')}:</span>
									<span class="value">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Date', 'التاريخ')}:</span>
									<span class="value">{timeAgo(req.created_at)}</span>
								</div>
							</div>
						{:else if req.item_type === 'payment_schedule'}
							<!-- Payment Schedule Card -->
							<div class="req-header">
								<div class="req-number">
									<span class="schedule-badge">📅 {req.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
								</div>
								<div class="status-badge status-{req.approval_status || 'pending'}">{translateStatus(req.approval_status || 'pending')}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">{t('Branch', 'الفرع')}:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{activeSection === 'approvals' ? t('Generated by', 'أنشأ بواسطة') : t('Approver', 'المعتمد')}:</span>
									<span class="value">👤 {activeSection === 'approvals' ? (req.creator?.username || t('Unknown', 'غير معروف')) : (req.approver?.username || t('Not Assigned', 'غير معين'))}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Category', 'الفئة')}:</span>
									<span class="value">{req.expense_category_name_en}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('C/O User', 'مستخدم C/O')}:</span>
									<span class="value">👤 {req.co_user_name || t('System', 'النظام')}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Amount', 'المبلغ')}:</span>
									<span class="value amount">SAR {formatAmount(req.amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Due Date', 'تاريخ الاستحقاق')}:</span>
									<span class="value due-date">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Date', 'التاريخ')}:</span>
									<span class="value">{timeAgo(req.created_at)}</span>
								</div>
							</div>
						{:else if req.item_type === 'vendor_payment'}
							<!-- Vendor Payment Card -->
							<div class="req-header">
								<div class="req-number">
									<span class="schedule-badge vendor-payment">💰 {t('VENDOR PAYMENT', 'دفع مورد')}</span>
									<div class="bill-number">{t('Bill', 'فاتورة')}: {req.bill_number}</div>
								</div>
								<div class="status-badge status-pending">{t('SENT FOR APPROVAL', 'مرسل للموافقة')}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">{t('Vendor', 'المورد')}:</span>
									<span class="value">{req.vendor_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Branch', 'الفرع')}:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Requested by', 'طلب بواسطة')}:</span>
									<span class="value">👤 {isAr ? (req.requester?.name_ar || req.requester?.name_en || req.requester?.username || t('Unknown User', 'مستخدم غير معروف')) : (req.requester?.name_en || req.requester?.username || t('Unknown User', 'مستخدم غير معروف'))}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Amount', 'المبلغ')}:</span>
									<span class="value amount">SAR {formatAmount(req.final_bill_amount || req.bill_amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Payment Method', 'طريقة الدفع')}:</span>
									<span class="value">{req.payment_method?.replace(/_/g, ' ') || t('N/A', 'غير متوفر')}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Due Date', 'تاريخ الاستحقاق')}:</span>
									<span class="value due-date">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">{t('Requested on', 'تاريخ الطلب')}:</span>
									<span class="value">{timeAgo(req.approval_requested_at)}</span>
								</div>
							</div>
						{:else if req.item_type === 'day_off'}
							<!-- Day Off Request Card -->
							<div class="req-header">
								<div class="req-number">
									<span class="schedule-badge day-off">📅 {t('DAY OFF', 'إجازة')} {#if req._dayCount > 1}({req._dayCount} {t('days', 'أيام')}){/if}</span>
								</div>
								<div class="status-badge status-{req.approval_status}">{translateStatus(req.approval_status)}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">{t('Employee', 'الموظف')}:</span>
									<span class="value">👤 {req.employee ? (isAr ? (req.employee.name_ar || req.employee.name_en || t('N/A', 'غير متوفر')) : (req.employee.name_en || req.employee.name_ar || t('N/A', 'غير متوفر'))) : t('N/A', 'غير متوفر')}</span>
								</div>
								{#if activeSection === 'approvals'}
									<div class="info-row">
										<span class="label">{t('Requested by', 'طلب بواسطة')}:</span>
										<span class="value">👤 {isAr ? (req.requester?.name_ar || req.requester?.name_en || req.requester?.username || t('Unknown User', 'مستخدم غير معروف')) : (req.requester?.name_en || req.requester?.username || t('Unknown User', 'مستخدم غير معروف'))}</span>
									</div>
								{/if}
								<div class="info-row">
									<span class="label">{t('Reason', 'السبب')}:</span>
									<span class="value">{req.reason ? (req.reason[$locale === 'en' ? 'reason_en' : 'reason_ar'] || t('N/A', 'غير متوفر')) : t('No reason', 'بدون سبب')}</span>
								</div>
								<div class="info-row">
									<span class="label">{req._dayCount > 1 ? t('From', 'من') + ':' : t('Day Off Date', 'تاريخ الإجازة') + ':'}</span>
									<span class="value">{req._dateFrom ? formatDateOnly(req._dateFrom) : '-'}</span>
								</div>
								{#if req._dayCount > 1}
									<div class="info-row">
										<span class="label">{t('To', 'إلى')}:</span>
										<span class="value">{req._dateTo ? formatDateOnly(req._dateTo) : '-'}</span>
									</div>
									<div class="info-row">
										<span class="label">{t('Total Days', 'إجمالي الأيام')}:</span>
										<span class="value">{req._dayCount} {t('days', 'أيام')}</span>
									</div>
								{/if}
								{#if req.is_deductible_on_salary}
									<div class="info-row">
										<span class="label">{t('Deductible', 'خصم من الراتب')}:</span>
										<span class="value">💰 {t('Yes', 'نعم')}</span>
									</div>
								{/if}
								{#if req.document_url}
									<div class="info-row">
										<span class="label">{t('Document', 'المستند')}:</span>
										<span class="value">
											<button 
												class="btn-view-doc"
												on:click={() => window.open(req.document_url, '_blank')}
												title={t('Click to view document', 'اضغط لعرض المستند')}>
												📄 {t('View Document', 'عرض المستند')}
											</button>
										</span>
									</div>
								{/if}
								<div class="info-row">
									<span class="label">{t('Requested on', 'تاريخ الطلب')}:</span>
									<span class="value">{timeAgo(req.approval_requested_at)}</span>
								</div>
							</div>
						{/if}
						</div>
					</div>
					<!-- Action Buttons -->
					{#if ((req.item_type === 'requisition' && req.status === 'pending') || 
					      (req.item_type === 'payment_schedule' && req.approval_status === 'pending') || 
					      (req.item_type === 'vendor_payment') ||
					      (req.item_type === 'day_off' && req.approval_status === 'pending')) && 
					     activeSection === 'approvals' && userCanApprove}
						<div class="card-actions">
							{#if req.item_type === 'day_off'}
								<button class="btn-approve-card" on:click|stopPropagation={() => openDayOffApproveModal(req)} disabled={isProcessing}>
									✅ {t('Accept', 'قبول')}
								</button>
								<button class="btn-reject-card" on:click|stopPropagation={() => rejectDayOffInstant(req)} disabled={isProcessing}>
									❌ {t('Reject', 'رفض')}
								</button>
							{:else}
								<button class="btn-approve-card" on:click|stopPropagation={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'approve'; showConfirmModal = true; }} disabled={isProcessing}>
									✅ {t('Accept', 'قبول')}
								</button>
								<button class="btn-reject-card" on:click|stopPropagation={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'reject'; showConfirmModal = true; }} disabled={isProcessing}>
									❌ {t('Reject', 'رفض')}
								</button>
							{/if}
						</div>
					{/if}
				</div>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<!-- Detail Modal -->
{#if showDetailModal && selectedRequisition}
	<div class="modal-overlay" on:click={closeDetail}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>{t('Requisition Details', 'تفاصيل الطلب')}</h2>
				<button class="close-btn" on:click={closeDetail}>✕</button>
			</div>

			<div class="modal-body">
				{#if selectedRequisition.item_type === 'requisition'}
					<!-- Requisition Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">{t('Requisition #', 'رقم الطلب')}:</span>
							<span class="value">{selectedRequisition.requisition_number}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Branch', 'الفرع')}:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Generated by', 'أنشأ بواسطة')}:</span>
							<span class="value">{selectedRequisition.created_by_username}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Requester', 'مقدم الطلب')}:</span>
							<span class="value">{selectedRequisition.requester_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Category', 'الفئة')}:</span>
							<span class="value">{selectedRequisition.expense_category_name_en}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Amount', 'المبلغ')}:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.amount)}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Payment Type', 'نوع الدفع')}:</span>
							<span class="value">{selectedRequisition.payment_type}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Status', 'الحالة')}:</span>
							<span class="status-badge status-{selectedRequisition.status}">{translateStatus(selectedRequisition.status)}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Date', 'التاريخ')}:</span>
							<span class="value">{timeAgo(selectedRequisition.created_at)}</span>
						</div>
						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<span class="label">{t('Description', 'الوصف')}:</span>
								<span class="value">{selectedRequisition.description}</span>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'payment_schedule'}
					<!-- Payment Schedule Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">{t('Schedule Type', 'نوع الجدول')}:</span>
							<span class="value">
								<span class="schedule-badge">📅 {selectedRequisition.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
							</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Branch', 'الفرع')}:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Category', 'الفئة')}:</span>
							<span class="value">{selectedRequisition.expense_category_name_en}</span>
						</div>
						{#if selectedRequisition.co_user_name}
							<div class="detail-item">
								<span class="label">{t('C/O User', 'مستخدم C/O')}:</span>
								<span class="value">👤 {selectedRequisition.co_user_name}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">{t('Approver', 'المعتمد')}:</span>
							<span class="value">{selectedRequisition.approver_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Created By', 'أنشأ بواسطة')}:</span>
							<span class="value">{selectedRequisition.creator?.username || t('Unknown', 'غير معروف')}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Amount', 'المبلغ')}:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.amount)}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Payment Method', 'طريقة الدفع')}:</span>
							<span class="value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || t('N/A', 'غير متوفر')}</span>
						</div>
						{#if selectedRequisition.bill_type}
							<div class="detail-item">
								<span class="label">{t('Bill Type', 'نوع الفاتورة')}:</span>
								<span class="value">{selectedRequisition.bill_type.replace(/_/g, ' ')}</span>
							</div>
						{/if}
						{#if selectedRequisition.bill_number}
							<div class="detail-item">
								<span class="label">{t('Bill Number', 'رقم الفاتورة')}:</span>
								<span class="value">{selectedRequisition.bill_number}</span>
							</div>
						{/if}
						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<span class="label">{t('Due Date', 'تاريخ الاستحقاق')}:</span>
								<span class="value">{formatDate(selectedRequisition.due_date)}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">{t('Status', 'الحالة')}:</span>
							<span class="status-badge status-{selectedRequisition.approval_status || 'pending'}">
								{translateStatus(selectedRequisition.approval_status || 'pending')}
							</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Date', 'التاريخ')}:</span>
							<span class="value">{timeAgo(selectedRequisition.created_at)}</span>
						</div>
						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<span class="label">{t('Description', 'الوصف')}:</span>
								<span class="value">{selectedRequisition.description}</span>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'vendor_payment'}
					<!-- Vendor Payment Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">{t('Payment Type', 'نوع الدفع')}:</span>
							<span class="schedule-badge vendor-payment">💰 {t('VENDOR PAYMENT', 'دفع مورد')}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Bill Number', 'رقم الفاتورة')}:</span>
							<span class="value">{selectedRequisition.bill_number}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Vendor Name', 'اسم المورد')}:</span>
							<span class="value">{selectedRequisition.vendor_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Branch', 'الفرع')}:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Requested by', 'طلب بواسطة')}:</span>
							<span class="value">👤 {isAr ? (selectedRequisition.requester?.name_ar || selectedRequisition.requester?.name_en || selectedRequisition.requester?.username || t('Unknown User', 'مستخدم غير معروف')) : (selectedRequisition.requester?.name_en || selectedRequisition.requester?.username || t('Unknown User', 'مستخدم غير معروف'))}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Bill Amount', 'مبلغ الفاتورة')}:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.bill_amount)}</span>
						</div>
						{#if selectedRequisition.final_bill_amount && selectedRequisition.final_bill_amount !== selectedRequisition.bill_amount}
							<div class="detail-item">
								<span class="label">{t('Final Amount', 'المبلغ النهائي')}:</span>
								<span class="value amount-large">SAR {formatAmount(selectedRequisition.final_bill_amount)}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">{t('Payment Method', 'طريقة الدفع')}:</span>
							<span class="value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || t('N/A', 'غير متوفر')}</span>
						</div>
						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<span class="label">{t('Bill Date', 'تاريخ الفاتورة')}:</span>
								<span class="value">{formatDate(selectedRequisition.bill_date)}</span>
							</div>
						{/if}
						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<span class="label">{t('Due Date', 'تاريخ الاستحقاق')}:</span>
								<span class="value">{formatDate(selectedRequisition.due_date)}</span>
							</div>
						{/if}
						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<span class="label">{t('Bank Name', 'اسم البنك')}:</span>
								<span class="value">{selectedRequisition.bank_name}</span>
							</div>
						{/if}
						{#if selectedRequisition.iban}
							<div class="detail-item">
								<span class="label">IBAN:</span>
								<span class="value">{selectedRequisition.iban}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">{t('Status', 'الحالة')}:</span>
							<span class="status-badge status-pending">{t('SENT FOR APPROVAL', 'مرسل للموافقة')}</span>
						</div>
						<div class="detail-item">
							<span class="label">{t('Requested on', 'تاريخ الطلب')}:</span>
							<span class="value">{timeAgo(selectedRequisition.approval_requested_at)}</span>
						</div>
						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<span class="label">{t('Notes', 'ملاحظات')}:</span>
								<span class="value">{selectedRequisition.approval_notes}</span>
							</div>
						{/if}
					</div>
				{/if}

				{#if (selectedRequisition.item_type === 'requisition' && selectedRequisition.status === 'pending') || (selectedRequisition.item_type === 'payment_schedule' && (selectedRequisition.approval_status === 'pending' || !selectedRequisition.approval_status)) || (selectedRequisition.item_type === 'vendor_payment' && selectedRequisition.approval_status === 'sent_for_approval')}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? t('payment schedule', 'جدول الدفع') : selectedRequisition.item_type === 'vendor_payment' ? t('vendor payment', 'دفع مورد') : t('requisition', 'طلب')}
					{#if !canApproveSelected}
						<div class="permission-notice">
							ℹ️ {t('You do not have permission to approve or reject this', 'ليس لديك صلاحية للموافقة أو رفض هذا')} {itemTypeName}.
							<br><small>{selectedRequisition.item_type === 'payment_schedule' ? t('Only the assigned approver can approve this payment.', 'فقط المعتمد المعين يمكنه الموافقة على هذا الدفع.') : t('Please contact your administrator for approval permissions.', 'يرجى التواصل مع المسؤول للحصول على صلاحيات الموافقة.')}</small>
						</div>
					{/if}
					<div class="action-buttons">
						<button 
							class="btn-approve" 
							on:click={() => openConfirmModal('approve')} 
							disabled={isProcessing || !canApproveSelected}
							title={!canApproveSelected ? t('You need approval permissions', 'تحتاج صلاحيات الموافقة') : t('Approve this', 'الموافقة على هذا') + ' ' + itemTypeName}
						>
							✅ {t('Approve', 'موافقة')}
						</button>
						<button 
							class="btn-reject" 
							on:click={() => openConfirmModal('reject')} 
							disabled={isProcessing || !canApproveSelected}
							title={!canApproveSelected ? t('You need approval permissions', 'تحتاج صلاحيات الموافقة') : t('Reject this', 'رفض هذا') + ' ' + itemTypeName}
						>
							❌ {t('Reject', 'رفض')}
						</button>
					</div>
				{:else}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? t('payment schedule', 'جدول الدفع') : selectedRequisition.item_type === 'vendor_payment' ? t('vendor payment', 'دفع مورد') : selectedRequisition.item_type === 'day_off' ? t('day off request', 'طلب إجازة') : t('requisition', 'طلب')}
					<div class="status-info">
						{t('This', 'هذا')} {itemTypeName} {t('has been', 'تم')} {translateStatus(selectedRequisition.status || selectedRequisition.approval_status)}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Day Off Approve Modal (date checkboxes) -->
{#if showDayOffApproveModal && selectedRequisition}
<div class="confirm-overlay" on:click={() => { showDayOffApproveModal = false; selectedRequisition = null; }}>
	<div class="confirm-modal dayoff-modal" on:click|stopPropagation>
		<h3 class="confirm-title">✅ {t('Approve Leave Request', 'الموافقة على طلب الإجازة')}</h3>
		<p class="confirm-message" style="margin-bottom: 0.75rem;">
			<strong>{selectedRequisition.employee ? (isAr ? (selectedRequisition.employee.name_ar || selectedRequisition.employee.name_en || t('N/A', 'غير متوفر')) : (selectedRequisition.employee.name_en || selectedRequisition.employee.name_ar || t('N/A', 'غير متوفر'))) : t('N/A', 'غير متوفر')}</strong>
			— {selectedRequisition.reason ? (isAr ? (selectedRequisition.reason.reason_ar || selectedRequisition.reason.reason_en || '') : (selectedRequisition.reason.reason_en || selectedRequisition.reason.reason_ar || '')) : ''}
		</p>
		<p class="confirm-message" style="font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;">
			{t('Uncheck any days you want to reject', 'ألغِ تحديد الأيام التي تريد رفضها')}
		</p>
		<div class="dayoff-dates-list">
			{#each (selectedRequisition._allIds || [selectedRequisition.id]) as dayId, i}
				{@const dayDate = (selectedRequisition._allDates || [selectedRequisition.day_off_date])[i]}
				<label class="dayoff-date-row" class:unchecked={!dayOffCheckedDates[dayId]}>
					<input type="checkbox" bind:checked={dayOffCheckedDates[dayId]} />
					<span class="dayoff-date-text">{formatDateOnly(dayDate)}</span>
				</label>
			{/each}
		</div>
		<div class="confirm-actions" style="margin-top: 1rem;">
			<button class="btn-confirm-cancel" on:click={() => { showDayOffApproveModal = false; selectedRequisition = null; }}>
				{t('Cancel', 'إلغاء')}
			</button>
			<button 
				class="btn-confirm-ok approve" 
				on:click={confirmDayOffApproval}
				disabled={isProcessing || Object.values(dayOffCheckedDates).every(v => !v)}
			>
				{isProcessing ? t('Processing...', 'جاري المعالجة...') : `${t('Accept', 'قبول')} (${Object.values(dayOffCheckedDates).filter(v => v).length})`}
			</button>
		</div>
	</div>
</div>
{/if}

<!-- Confirmation Modal -->
{#if showConfirmModal}
<div class="confirm-overlay" on:click={cancelConfirm}>
	<div class="confirm-modal" on:click|stopPropagation>
		<h3 class="confirm-title">
			{confirmAction === 'approve' ? '✅ ' + t('Confirm Approval', 'تأكيد الموافقة') : '❌ ' + t('Confirm Rejection', 'تأكيد الرفض')}
		</h3>
		
		<p class="confirm-message">
			{#if confirmAction === 'approve'}
				{t('Are you sure you want to approve this', 'هل أنت متأكد من الموافقة على هذا')} {selectedRequisition?.item_type === 'payment_schedule' ? t('payment schedule', 'جدول الدفع') : selectedRequisition?.item_type === 'vendor_payment' ? t('vendor payment', 'دفع مورد') : selectedRequisition?.item_type === 'day_off' ? t('day off request', 'طلب إجازة') : t('requisition', 'الطلب')}؟
			{:else}
				{t('Are you sure you want to reject this', 'هل أنت متأكد من رفض هذا')} {selectedRequisition?.item_type === 'payment_schedule' ? t('payment schedule', 'جدول الدفع') : selectedRequisition?.item_type === 'vendor_payment' ? t('vendor payment', 'دفع مورد') : selectedRequisition?.item_type === 'day_off' ? t('day off request', 'طلب إجازة') : t('requisition', 'الطلب')}؟
			{/if}
		</p>
		
		{#if confirmAction === 'reject'}
			<div class="form-group">
				<label for="rejection-reason" class="form-label">{t('Reason for Rejection', 'سبب الرفض')} *</label>
				<textarea
					id="rejection-reason"
					bind:value={rejectionReason}
					placeholder={t('Please provide a detailed reason for rejection...', 'يرجى تقديم سبب مفصل للرفض...')}
					rows="4"
					class="rejection-textarea"
				></textarea>
			</div>
		{/if}
		
		<div class="confirm-actions">
			<button class="btn-confirm-cancel" on:click={cancelConfirm}>
				{t('Cancel', 'إلغاء')}
			</button>
			<button 
				class="btn-confirm-ok" 
				class:approve={confirmAction === 'approve'}
				class:reject={confirmAction === 'reject'}
				on:click={confirmActionHandler}
				disabled={confirmAction === 'reject' && !rejectionReason.trim()}
			>
				{confirmAction === 'approve' ? t('Approve', 'موافقة') : t('Reject', 'رفض')}
			</button>
		</div>
	</div>
</div>
{/if}

<style>
	.mobile-approval-center {
		padding: 0.5rem;
		padding-bottom: 4rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 1.5rem 0.5rem;
		color: #6B7280;
	}

	.spinner {
		width: 28px;
		height: 28px;
		border: 2px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 0.5rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Section Tabs */
	.section-tabs {
		display: flex;
		gap: 0.25rem;
		margin-bottom: 0.5rem;
		background: #F3F4F6;
		padding: 0.15rem;
		border-radius: 6px;
	}

	.tab-button {
		flex: 1;
		padding: 0.35rem 0.5rem;
		border: none;
		background: transparent;
		border-radius: 5px;
		font-size: 0.76rem;
		font-weight: 600;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
	}

	.tab-button.active {
		background: white;
		color: #3B82F6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.tab-button .badge {
		background: #EF4444;
		color: white;
		font-size: 0.6rem;
		padding: 0.1rem 0.3rem;
		border-radius: 6px;
		font-weight: 700;
		min-width: 14px;
		text-align: center;
	}

	.tab-button.active .badge {
		background: #3B82F6;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.35rem;
		margin-bottom: 0.5rem;
	}

	.stat-card {
		background: white;
		border-radius: 6px;
		padding: 0.4rem;
		text-align: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		transition: all 0.2s;
	}

	.stat-card:active {
		transform: scale(0.98);
	}

	.stat-value {
		font-size: 1.2rem;
		font-weight: 700;
		margin-bottom: 0.1rem;
	}

	.stat-label {
		font-size: 0.65rem;
		color: #6B7280;
		text-transform: uppercase;
		font-weight: 600;
	}

	.stat-card.pending .stat-value { color: #F59E0B; }
	.stat-card.approved .stat-value { color: #10B981; }
	.stat-card.rejected .stat-value { color: #EF4444; }
	.stat-card.total .stat-value { color: #3B82F6; }

	.requisitions-list {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		max-height: calc(100vh - 200px);
		overflow-y: auto;
		padding-bottom: 1rem;
	}

	.req-card {
		background: white;
		border-radius: 6px;
		padding: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
		transition: all 0.2s;
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.card-header {
		flex: 1;
		cursor: pointer;
	}

	.card-header:active {
		opacity: 0.8;
	}

	.card-title {
		flex: 1;
	}

	.card-actions {
		display: flex;
		gap: 0.3rem;
		padding-top: 0.3rem;
		border-top: 1px solid #F3F4F6;
	}

	.btn-approve-card,
	.btn-reject-card {
		flex: 1;
		padding: 0.4rem;
		border: none;
		border-radius: 5px;
		font-size: 0.76rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.2rem;
	}

	.btn-approve-card {
		background: #10B981;
		color: white;
	}

	.btn-approve-card:active:not(:disabled) {
		background: #059669;
		transform: scale(0.98);
	}

	.btn-reject-card {
		background: #EF4444;
		color: white;
	}

	.btn-reject-card:active:not(:disabled) {
		background: #DC2626;
		transform: scale(0.98);
	}

	.btn-approve-card:disabled,
	.btn-reject-card:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.req-card:active {
		transform: none;
	}

	.req-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.3rem;
		padding-bottom: 0.3rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.req-number {
		font-weight: 700;
		color: #1F2937;
		font-size: 0.76rem;
	}

	.status-badge {
		padding: 0.15rem 0.4rem;
		border-radius: 5px;
		font-size: 0.65rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.schedule-badge {
		display: inline-block;
		padding: 0.2rem 0.4rem;
		background: #ede9fe;
		color: #5b21b6;
		border-radius: 5px;
		font-size: 0.6rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.schedule-badge.vendor-payment {
		background: #dcfce7;
		color: #166534;
	}

	.schedule-badge.day-off {
		background: #e0e7ff;
		color: #3730a3;
	}

	.bill-number {
		font-size: 0.7rem;
		color: #64748b;
		margin-top: 0.25rem;
		font-weight: 400;
		text-transform: none;
	}

	.status-badge.status-pending {
		background: #FEF3C7;
		color: #D97706;
	}

	.status-badge.status-approved {
		background: #D1FAE5;
		color: #059669;
	}

	.status-badge.status-rejected {
		background: #FEE2E2;
		color: #DC2626;
	}

	.req-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		font-size: 0.76rem;
	}

	.info-row .label {
		color: #6B7280;
		font-weight: 500;
	}

	.info-row .value {
		color: #1F2937;
		font-weight: 600;
		text-align: right;
	}

	.info-row .value.amount {
		color: #10B981;
		font-family: 'Courier New', monospace;
	}

	.empty-state {
		text-align: center;
		padding: 1.5rem 0.5rem;
		color: #9CA3AF;
	}

	.empty-icon {
		font-size: 1.8rem;
		margin-bottom: 0.5rem;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: flex-end;
		z-index: 2000;
		animation: fadeIn 0.2s;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.modal-content {
		background: white;
		width: 100%;
		max-height: 85vh;
		border-radius: 10px 10px 0 0;
		overflow-y: auto;
		animation: slideUp 0.3s;
	}

	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.6rem;
		border-bottom: 1px solid #F3F4F6;
		position: sticky;
		top: 0;
		background: white;
		z-index: 10;
	}

	.modal-header h2 {
		font-size: 0.88rem;
		font-weight: 700;
		color: #1F2937;
	}

	.close-btn {
		width: 26px;
		height: 26px;
		border-radius: 50%;
		border: none;
		background: #F3F4F6;
		color: #6B7280;
		font-size: 0.88rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-body {
		padding: 0.6rem;
	}

	.detail-section {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		margin-bottom: 0.6rem;
	}

	.detail-item {
		display: flex;
		justify-content: space-between;
		padding: 0.4rem;
		background: #F9FAFB;
		border-radius: 5px;
	}

	.detail-item.full-width {
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-item .label {
		color: #6B7280;
		font-weight: 500;
		font-size: 0.76rem;
	}

	.detail-item .value {
		color: #1F2937;
		font-weight: 600;
		font-size: 0.76rem;
		text-align: right;
	}

	.amount-large {
		color: #10B981 !important;
		font-family: 'Courier New', monospace;
		font-size: 0.88rem !important;
	}

	.permission-notice {
		padding: 0.5rem 0.6rem;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 6px;
		color: #92400e;
		font-size: 0.76rem;
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.permission-notice small {
		font-size: 0.65rem;
		color: #b45309;
		display: block;
		margin-top: 0.15rem;
	}

	.action-buttons {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.35rem;
		padding-top: 0.5rem;
		border-top: 1px solid #F3F4F6;
	}

	.btn-approve,
	.btn-reject {
		padding: 0.45rem;
		border-radius: 6px;
		border: none;
		font-weight: 600;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-approve {
		background: #10B981;
		color: white;
	}

	.btn-approve:active {
		background: #059669;
		transform: scale(0.98);
	}

	.btn-reject {
		background: #EF4444;
		color: white;
	}

	.btn-reject:active {
		background: #DC2626;
		transform: scale(0.98);
	}

	.btn-approve:disabled,
	.btn-reject:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.status-info {
		padding: 0.5rem;
		background: #F3F4F6;
		border-radius: 6px;
		text-align: center;
		color: #6B7280;
		font-weight: 600;
		margin-top: 0.5rem;
		border-top: 1px solid #E5E7EB;
	}

	/* Confirmation Modal Styles */
	.confirm-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		backdrop-filter: blur(4px);
		padding: 0.5rem;
	}

	.confirm-modal {
		background: white;
		border-radius: 8px;
		padding: 0.7rem;
		max-width: 500px;
		width: 100%;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		animation: modalSlideIn 0.2s ease-out;
	}

	.dayoff-modal {
		max-height: 80vh;
		overflow-y: auto;
	}

	.dayoff-dates-list {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		max-height: 50vh;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		padding: 0.5rem;
	}

	.dayoff-date-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.4rem 0.5rem;
		border-radius: 4px;
		cursor: pointer;
		transition: background 0.15s;
		font-size: 0.85rem;
	}

	.dayoff-date-row:hover {
		background: #f0f9ff;
	}

	.dayoff-date-row.unchecked {
		background: #fef2f2;
		text-decoration: line-through;
		color: #9ca3af;
	}

	.dayoff-date-row input[type="checkbox"] {
		width: 18px;
		height: 18px;
		accent-color: #10b981;
		cursor: pointer;
	}

	.dayoff-date-text {
		flex: 1;
	}

	@keyframes modalSlideIn {
		from {
			opacity: 0;
			transform: translateY(-20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	.confirm-title {
		font-size: 0.88rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 0.5rem 0;
		text-align: center;
	}

	.confirm-message {
		font-size: 0.76rem;
		color: #475569;
		margin: 0 0 0.7rem 0;
		text-align: center;
		line-height: 1.5;
	}

	.form-group {
		margin-bottom: 0.7rem;
	}

	.form-label {
		display: block;
		font-size: 0.76rem;
		font-weight: 600;
		color: #334155;
		margin-bottom: 0.3rem;
	}

	.rejection-textarea {
		width: 100%;
		padding: 0.4rem;
		border: 2px solid #e2e8f0;
		border-radius: 5px;
		font-size: 0.76rem;
		font-family: inherit;
		resize: vertical;
		transition: border-color 0.2s;
	}

	.rejection-textarea:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.rejection-textarea::placeholder {
		color: #94a3b8;
	}

	.confirm-actions {
		display: flex;
		gap: 0.35rem;
		justify-content: flex-end;
	}

	.btn-confirm-cancel,
	.btn-confirm-ok {
		padding: 0.4rem 0.8rem;
		border: none;
		border-radius: 5px;
		font-size: 0.76rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-confirm-cancel {
		background: #f1f5f9;
		color: #475569;
	}

	.btn-confirm-cancel:active {
		background: #e2e8f0;
	}

	.btn-confirm-ok {
		color: white;
	}

	.btn-confirm-ok.approve {
		background: #10b981;
	}

	.btn-confirm-ok.approve:active {
		background: #059669;
	}

	.btn-confirm-ok.reject {
		background: #ef4444;
	}

	.btn-confirm-ok.reject:active {
		background: #dc2626;
	}

	.btn-confirm-ok:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Bulk Actions */
	.bulk-actions {
		display: flex;
		gap: 0.35rem;
		padding: 0.5rem;
		background: white;
		border-radius: 6px;
		margin-bottom: 0.5rem;
		flex-wrap: wrap;
	}

	.btn-approve-bulk,
	.btn-clear-bulk,
	.btn-mark-all {
		flex: 1;
		padding: 0.4rem 0.5rem;
		border: none;
		border-radius: 5px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 90px;
		white-space: nowrap;
		font-size: 0.76rem;
	}

	.btn-approve-bulk {
		background: #10b981;
		color: white;
	}

	.btn-approve-bulk:active:not(:disabled) {
		background: #059669;
	}

	.btn-approve-bulk:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-clear-bulk {
		background: #ef4444;
		color: white;
	}

	.btn-clear-bulk:active {
		background: #dc2626;
	}

	.btn-mark-all {
		background: #8b5cf6;
		color: white;
	}

	.btn-mark-all:active {
		background: #7c3aed;
	}

	/* Card Checkbox */
	.card-checkbox {
		position: absolute;
		top: 8px;
		right: 8px;
		z-index: 10;
	}

	.card-checkbox input[type="checkbox"] {
		width: 16px;
		height: 16px;
		cursor: pointer;
		accent-color: #3b82f6;
	}

	.req-card.selected {
		background: #eff6ff;
		border: 2px solid #3b82f6;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.2);
	}

	.req-card.selected::before {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 4px;
		background: #3b82f6;
		border-radius: 8px 0 0 8px;
	}

	/* Bulk Confirmation Modal */
	.bulk-confirm-modal {
		min-width: 300px;
		max-width: 90vw;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.6rem;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 0.88rem;
		color: #1e293b;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 1.1rem;
		color: #64748b;
		cursor: pointer;
		padding: 0;
		width: 26px;
		height: 26px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-close:active {
		color: #1e293b;
	}

	.modal-body {
		margin-bottom: 0.6rem;
	}

	.bulk-confirm-message {
		font-size: 0.82rem;
		color: #1e293b;
		margin-bottom: 0.5rem;
		line-height: 1.5;
	}

	.bulk-confirm-message strong {
		color: #10b981;
		font-weight: 700;
		font-size: 0.88rem;
	}

	.bulk-confirm-note {
		color: #64748b;
		font-size: 0.72rem;
		font-style: italic;
		margin: 0;
		line-height: 1.4;
	}

	.modal-footer {
		display: flex;
		gap: 0.35rem;
		justify-content: flex-end;
	}

	.btn-cancel {
		padding: 0.4rem 0.8rem;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 5px;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
		font-size: 0.76rem;
	}

	.btn-cancel:active:not(:disabled) {
		background: #cbd5e1;
	}

	.btn-cancel:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-approve-bulk-modal {
		padding: 0.4rem 0.8rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 5px;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.76rem;
	}

	.btn-approve-bulk-modal:active:not(:disabled) {
		background: #059669;
	}

	.btn-approve-bulk-modal:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	.btn-view-doc {
		padding: 0.3rem 0.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 5px;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.76rem;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
	}

	.btn-view-doc:hover {
		background: #059669;
		transform: translateY(-2px);
	}

	.btn-view-doc:active {
		transform: translateY(0);
	}

	.spinner-small {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>


