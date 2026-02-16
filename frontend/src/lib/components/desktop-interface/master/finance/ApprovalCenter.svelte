<script>
	// Approval Center Component
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { notifications } from '$lib/stores/notifications';
	import { locale, t } from '$lib/i18n';

	let requisitions = [];
	let paymentSchedules = []; // New: payment schedules requiring approval
	let vendorPayments = []; // New: vendor payments requiring approval
	let purchaseVouchers = []; // Purchase vouchers requiring approval
	let approvedPaymentSchedules = []; // Approved payment schedules from expense_scheduler
	let rejectedPaymentSchedules = []; // Rejected payment schedules
	let myCreatedRequisitions = []; // Requisitions created by current user
	let myCreatedSchedules = []; // Payment schedules created by current user
	let myCreatedVouchers = []; // Purchase vouchers created by current user
	let dayOffRequests = []; // Day off requests requiring approval
	let myDayOffRequests = []; // Day off requests created by current user
	let myApprovedSchedules = []; // My approved schedules
	let filteredRequisitions = [];
	let filteredMyRequests = [];
	let loading = true;
	let realtimeChannel = null;
	let selectedStatus = 'pending';
	let searchQuery = '';
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

	let currentUserEmployee = null; // {name_en, name_ar} from hr_employee_master

	// Get display name from user object with nested hr_employee_master
	function getDisplayName(userObj) {
		if (!userObj) return t('approvalCenter.unknown');
		const emp = userObj.hr_employee_master;
		if (emp) {
			if ($locale === 'ar' && emp.name_ar) return emp.name_ar;
			if (emp.name_en) return emp.name_en;
		}
		return userObj.username || t('approvalCenter.unknown');
	}

	// Get the current user's display name from hr_employee_master
	function getCurrentUserName() {
		if (currentUserEmployee) {
			if ($locale === 'ar' && currentUserEmployee.name_ar) return currentUserEmployee.name_ar;
			if (currentUserEmployee.name_en) return currentUserEmployee.name_en;
		}
		return $currentUser?.username || t('approvalCenter.system');
	}

	// Get translated status text
	function getStatusText(status) {
		const s = (status || 'pending').toLowerCase();
		if (s === 'pending') return t('approvalCenter.pending');
		if (s === 'approved') return t('approvalCenter.approved');
		if (s === 'rejected') return t('approvalCenter.rejected');
		if (s === 'sent_for_approval') return t('approvalCenter.sentForApproval');
		return status;
	}

	// Get locale-appropriate category name
	function getCategoryName(nameEn, nameAr) {
		if ($locale === 'ar' && nameAr) return nameAr;
		return nameEn || t('approvalCenter.na');
	}

	// Get locale-appropriate employee name
	function getEmployeeName(emp) {
		if (!emp) return t('approvalCenter.na');
		if ($locale === 'ar' && emp.name_ar) return emp.name_ar;
		return emp.name_en || emp.name_ar || t('approvalCenter.na');
	}

	onMount(() => {
		loadRequisitions();
		setupRealtime();
	});

	onDestroy(() => {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function setupRealtime() {
		if (!supabase || !$currentUser?.id) return;

		// Subscribe to changes in all relevant tables
		realtimeChannel = supabase.channel('approval-center-realtime')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'expense_requisitions' }, (payload) => {
				console.log('Real-time update: expense_requisitions', payload);
				// Check if the change involves current user (approver or creator)
				const isRelevant = 
					(payload.new && (payload.new.approver_id === $currentUser.id || payload.new.created_by === $currentUser.id)) ||
					(payload.old && (payload.old.approver_id === $currentUser.id || payload.old.created_by === $currentUser.id));
				
				if (isRelevant) loadRequisitions();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'non_approved_payment_scheduler' }, (payload) => {
				console.log('Real-time update: non_approved_payment_scheduler', payload);
				const isRelevant = 
					(payload.new && (payload.new.approver_id === $currentUser.id || payload.new.created_by === $currentUser.id)) ||
					(payload.old && (payload.old.approver_id === $currentUser.id || payload.old.created_by === $currentUser.id));
				
				if (isRelevant) loadRequisitions();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'vendor_payment_schedule' }, () => {
				loadRequisitions();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'purchase_voucher_items' }, (payload) => {
				console.log('Real-time update: purchase_voucher_items', payload);
				const isRelevant = 
					(payload.new && (payload.new.approver_id === $currentUser.id || payload.new.issued_by === $currentUser.id)) ||
					(payload.old && (payload.old.approver_id === $currentUser.id || payload.old.issued_by === $currentUser.id));
				
				if (isRelevant) loadRequisitions();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'day_off' }, (payload) => {
				console.log('Real-time update: day_off', payload);
				// day_off requests are visible to all with leave approval permission, or if they are the requester
				loadRequisitions();
			})
			.subscribe();
	}

	// Track if historical data is loaded
	let historicalDataLoaded = false;

	async function loadRequisitions() {
		try {
			loading = true;
			
			// Check if user is logged in
			if (!$currentUser?.id) {
				notifications.add({ type: 'error', message: t('approvalCenter.notifPleaseLogin') });
				loading = false;
				return;
			}
		
		console.log('🔐 Loading approval center via RPC for user:', $currentUser.username);
	
	// Single RPC call replaces 11+ queries (permissions + employee name + 9 data queries)
	const { data: rpcResult, error: rpcError } = await supabase.rpc('get_approval_center_data', {
		p_user_id: $currentUser.id
	});

	if (rpcError) {
		console.error('❌ Error calling get_approval_center_data RPC:', rpcError);
		notifications.add({ type: 'error', message: t('approvalCenter.notifLoadError') + rpcError.message });
		loading = false;
		return;
	}

	// Extract approval permissions
	const approvalPerms = rpcResult.permissions;
	
	if (approvalPerms) {
		userCanApprove = 
			approvalPerms.can_approve_requisitions ||
			approvalPerms.can_approve_single_bill ||
			approvalPerms.can_approve_multiple_bill ||
			approvalPerms.can_approve_recurring_bill ||
			approvalPerms.can_approve_vendor_payments ||
			approvalPerms.can_approve_leave_requests ||
			approvalPerms.can_approve_purchase_vouchers;
	} else {
		userCanApprove = false;
	}

	// Current user employee name
	if (rpcResult.current_user_employee) currentUserEmployee = rpcResult.current_user_employee;

	// Map requisitions + attach created_by_user from user_names
	const userNamesMap = rpcResult.user_names || {};
	requisitions = (rpcResult.requisitions || []).map(req => ({
		...req,
		created_by_user: userNamesMap[req.created_by] || null,
		created_by_username: userNamesMap[req.created_by]?.username || req.created_by || t('approvalCenter.unknown')
	}));
	console.log('✅ Loaded requisitions:', requisitions.length);

	// Payment schedules - filter single_bill by due date
	const twoDaysDate = rpcResult.two_days_date;
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
	console.log('✅ Loaded vendor payments:', vendorPayments.length);

	// Purchase vouchers (already filtered by RPC)
	purchaseVouchers = rpcResult.purchase_vouchers || [];
	console.log('✅ Loaded purchase vouchers:', purchaseVouchers.length);

	// My created items
	myCreatedRequisitions = rpcResult.my_requisitions || [];
	myCreatedSchedules = rpcResult.my_schedules || [];
	myCreatedVouchers = rpcResult.my_vouchers || [];

	// Day off requests (group by employee)
	dayOffRequests = groupDayOffRequests(rpcResult.day_off_requests || []);
	myDayOffRequests = groupDayOffRequests(rpcResult.my_day_off_requests || []);

	// Initialize empty arrays for historical data (will load on demand)
	myApprovedSchedules = [];
	approvedPaymentSchedules = [];
	rejectedPaymentSchedules = [];

	// Calculate stats (only pending for now, historical loads on demand)
	stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length + dayOffRequests.length;
	stats.approved = 0;
	stats.rejected = 0;
	stats.total = stats.pending;

	myStats.pending = myCreatedRequisitions.length + myCreatedSchedules.length + myCreatedVouchers.length + myDayOffRequests.length;
	myStats.approved = 0;
	myStats.rejected = 0;
	myStats.total = myStats.pending;
	
	console.log('📈 Approval Stats:', stats);
	console.log('📊 My Requests Stats:', myStats);

		filterRequisitions();
	
		// Load historical data in background after initial display
		loadHistoricalData();
	} catch (err) {
		console.error('Error loading requisitions:', err);
		notifications.add({ type: 'error', message: t('approvalCenter.notifLoadError') + err.message });
	} finally {
		loading = false;
	}
}
async function loadHistoricalData() {
	if (historicalDataLoaded || !$currentUser?.id) return;
	
	try {
		console.log('📚 Loading historical data in background...');
		
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
				.limit(1000),
			
			// Rejected requisitions where I'm approver
			supabase
				.from('expense_requisitions')
				.select('*')
				.eq('approver_id', $currentUser.id)
				.eq('status', 'rejected')
				.order('created_at', { ascending: false })
				.limit(1000),
			
			// My approved/rejected schedules from expense_scheduler
			supabase
				.from('expense_scheduler')
				.select(`
					*,
					approver:users!approver_id (
						id,
						username,
						hr_employee_master(name_en, name_ar)
					)
				`)
				.eq('created_by', $currentUser.id)
				.not('schedule_type', 'eq', 'recurring')
				.not('schedule_type', 'eq', 'expense_requisition')
				.order('created_at', { ascending: false })
				.limit(1000),
			
			// Approved payment schedules where I was the approver
			supabase
				.from('expense_scheduler')
				.select(`
					*,
					creator:users!created_by (
						id,
						username,
						hr_employee_master(name_en, name_ar)
					)
				`)
				.eq('approver_id', $currentUser.id)
				.not('schedule_type', 'eq', 'recurring')
				.not('schedule_type', 'eq', 'expense_requisition')
				.order('created_at', { ascending: false })
				.limit(1000),
			
			// Rejected schedules where I was the approver
			supabase
				.from('non_approved_payment_scheduler')
				.select(`
					*,
					creator:users!created_by (
						id,
						username,
						hr_employee_master(name_en, name_ar)
					)
				`)
				.eq('approver_id', $currentUser.id)
				.eq('approval_status', 'rejected')
				.order('created_at', { ascending: false })
				.limit(1000),
			
			// My approved requisitions
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
						username,
						hr_employee_master(name_en, name_ar)
					)
				`)
				.eq('created_by', $currentUser.id)
				.eq('approval_status', 'rejected')
				.in('schedule_type', ['single_bill', 'multiple_bill'])
				.order('created_at', { ascending: false })
				.limit(1000)
		]);
		
		// Process approved requisitions
		const approvedReqs = approvedReqsResult.data || [];
		const rejectedReqs = rejectedReqsResult.data || [];
		
		// Merge with existing requisitions
		requisitions = [...requisitions, ...approvedReqs, ...rejectedReqs];
		
		// Process schedules
		myApprovedSchedules = myApprovedSchedulesResult.data || [];
		approvedPaymentSchedules = approvedSchedulesResult.data || [];
		rejectedPaymentSchedules = rejectedSchedulesResult.data || [];
		
		// Merge my created requisitions
		const myApprovedReqs = myApprovedReqsResult.data || [];
		const myRejectedReqs = myRejectedReqsResult.data || [];
		myCreatedRequisitions = [...myCreatedRequisitions, ...myApprovedReqs, ...myRejectedReqs];
		
		// Merge my created schedules
		const myRejectedScheds = myRejectedSchedulesResult.data || [];
		myCreatedSchedules = [...myCreatedSchedules, ...myRejectedScheds];
		
		// Update stats with historical data
		stats.approved = approvedReqs.length + approvedPaymentSchedules.length;
		stats.rejected = rejectedReqs.length + rejectedPaymentSchedules.length;
		stats.total = stats.pending + stats.approved + stats.rejected;
		
		myStats.approved = myApprovedReqs.length + myApprovedSchedules.length;
		myStats.rejected = myRejectedReqs.length + myRejectedScheds.length;
		myStats.total = myStats.pending + myStats.approved + myStats.rejected;
		
		historicalDataLoaded = true;
		console.log('✅ Historical data loaded:', { 
			approvedReqs: approvedReqs.length,
			rejectedReqs: rejectedReqs.length,
			approvedSchedules: approvedPaymentSchedules.length,
			rejectedSchedules: rejectedPaymentSchedules.length
		});
		
		// Refresh filters if user is viewing approved/rejected
		if (selectedStatus !== 'pending') {
			filterRequisitions();
		}
	} catch (err) {
		console.error('Error loading historical data:', err);
	}
}

	function filterRequisitions() {
		if (activeSection === 'approvals') {
			// Filter approvals assigned to me
			let filtered = requisitions;
			let filteredSchedules = [];
			let filteredDayOffs = [];

			console.log('🔍 Filtering approvals assigned to me:', {
				total: requisitions.length,
				paymentSchedules: paymentSchedules.length,
				approvedSchedules: approvedPaymentSchedules.length,
				rejectedSchedules: rejectedPaymentSchedules.length,
				dayOffRequests: dayOffRequests.length,
				selectedStatus,
				searchQuery
			});

			// Filter requisitions by status
			if (selectedStatus !== 'all') {
				// Load historical data if viewing approved/rejected and not loaded yet
				if ((selectedStatus === 'approved' || selectedStatus === 'rejected') && !historicalDataLoaded) {
					loadHistoricalData();
				}
				filtered = filtered.filter(r => r.status === selectedStatus);
				console.log(`  ↳ After status filter (${selectedStatus}):`, filtered.length);
			}

			// Filter by search query
			if (searchQuery.trim()) {
				const query = searchQuery.toLowerCase();
				filtered = filtered.filter(r =>
					r.requisition_number.toLowerCase().includes(query) ||
					r.branch_name.toLowerCase().includes(query) ||
					r.requester_name.toLowerCase().includes(query) ||
					r.expense_category_name_en?.toLowerCase().includes(query) ||
					r.description?.toLowerCase().includes(query)
				);
				console.log(`  ↳ After search filter (${query}):`, filtered.length);
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
			console.log('✅ Day off approvals to show:', {
				count: filteredDayOffs.length,
				data: filteredDayOffs.map(d => ({
					id: d.id,
					approval_requested_by: d.approval_requested_by,
					currentUserId: $currentUser.id,
					isOwnRequest: d.approval_requested_by === $currentUser.id,
					approval_status: d.approval_status
				}))
			});
			
			// Apply search to payment schedules too
			if (searchQuery.trim()) {
				const query = searchQuery.toLowerCase();
				filteredSchedules = filteredSchedules.filter(s =>
					s.branch_name?.toLowerCase().includes(query) ||
					s.expense_category_name_en?.toLowerCase().includes(query) ||
					s.co_user_name?.toLowerCase().includes(query) ||
					s.schedule_type?.toLowerCase().includes(query) ||
					s.description?.toLowerCase().includes(query)
				);
			}

			// Combine filtered requisitions and payment schedules
			filteredRequisitions = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					// For approved schedules from expense_scheduler, add approval_status
					approval_status: s.approval_status || 'approved'
				})),
				// Add vendor payments (only show in pending tab)
				...(selectedStatus === 'pending' || selectedStatus === 'all' ? vendorPayments.map(vp => ({
					...vp,
					item_type: 'vendor_payment'
				})) : []),
				// Add purchase vouchers (only show in pending tab)
				...(selectedStatus === 'pending' || selectedStatus === 'all' ? purchaseVouchers.map(pv => ({
					...pv,
					item_type: 'purchase_voucher'
				})) : []),
				// Add day off requests
				...filteredDayOffs.map(d => ({ ...d, item_type: 'day_off' }))
			];
			
			console.log('✅ Final filtered approvals:', {
				requisitions: filtered.length,
				schedules: filteredSchedules.length,
				vendorPayments: (selectedStatus === 'pending' || selectedStatus === 'all' ? vendorPayments.length : 0),
				vouchers: (selectedStatus === 'pending' || selectedStatus === 'all' ? purchaseVouchers.length : 0),
				dayOffs: filteredDayOffs.length,
				total: filteredRequisitions.length
			});
		} else {
			// Filter my created requests
			let filtered = myCreatedRequisitions;
			let filteredSchedules = [];
			let filteredMyDayOffs = [];

			console.log('🔍 Filtering my created requests:', {
				total: myCreatedRequisitions.length,
				mySchedules: myCreatedSchedules.length,
				myApprovedSchedules: myApprovedSchedules.length,
				myDayOffs: myDayOffRequests.length,
				selectedStatus,
				searchQuery
			});

			// Show all requisitions or filter by status
			if (selectedStatus === 'all') {
				filtered = myCreatedRequisitions;
				// Combine all schedules: pending + rejected (from myCreatedSchedules) + approved (from myApprovedSchedules)
				filteredSchedules = [...myCreatedSchedules, ...myApprovedSchedules];
				// All day off requests
				filteredMyDayOffs = myDayOffRequests;
				console.log('✅ My day off requests (all statuses):', {
					count: filteredMyDayOffs.length,
					data: filteredMyDayOffs.map(d => ({
						id: d.id,
						approval_requested_by: d.approval_requested_by,
						currentUserId: $currentUser.id,
						isMyRequest: d.approval_requested_by === $currentUser.id,
						approval_status: d.approval_status
					}))
				});
			} else {
				// Filter requisitions by status
				filtered = myCreatedRequisitions.filter(r => r.status === selectedStatus);
				
				// Filter schedules by status
				if (selectedStatus === 'pending') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'pending');
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'pending');
					console.log('✅ My pending day off requests:', {
						count: filteredMyDayOffs.length,
						data: filteredMyDayOffs.map(d => ({
							id: d.id,
							approval_requested_by: d.approval_requested_by,
							currentUserId: $currentUser.id,
							isMyRequest: d.approval_requested_by === $currentUser.id,
							approval_status: d.approval_status
						}))
					});
				} else if (selectedStatus === 'approved') {
					filteredSchedules = myApprovedSchedules;
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'approved');
				} else if (selectedStatus === 'rejected') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'rejected');
					filteredMyDayOffs = myDayOffRequests.filter(d => d.approval_status === 'rejected');
				}
			}

			// Filter by search query
			if (searchQuery.trim()) {
				const query = searchQuery.toLowerCase();
				filtered = filtered.filter(r =>
					r.requisition_number.toLowerCase().includes(query) ||
					r.branch_name.toLowerCase().includes(query) ||
					r.expense_category_name_en?.toLowerCase().includes(query) ||
					r.description?.toLowerCase().includes(query)
				);
				
				filteredSchedules = filteredSchedules.filter(s =>
					s.branch_name?.toLowerCase().includes(query) ||
					s.expense_category_name_en?.toLowerCase().includes(query) ||
					s.co_user_name?.toLowerCase().includes(query) ||
					s.description?.toLowerCase().includes(query)
				);
			}

			// Combine filtered requests
			filteredMyRequests = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					approval_status: s.approval_status || 'approved'
				})),
				// Add my created purchase vouchers
				...myCreatedVouchers.map(pv => ({
					...pv,
					item_type: 'purchase_voucher'
				})),
				// Add my day off requests
				...filteredMyDayOffs.map(d => ({ ...d, item_type: 'day_off' }))
			];

			console.log('✅ Final filtered my requests:', {
				requisitions: filtered.length,
				schedules: filteredSchedules.length,
				vouchers: myCreatedVouchers.length,
				dayOffs: filteredMyDayOffs.length,
				total: filteredMyRequests.length
			});
		}
	}

	function openDetail(requisition) {
		selectedRequisition = requisition;
		showDetailModal = true;
	}

	function closeDetail() {
		showDetailModal = false;
		selectedRequisition = null;
	}

	function filterByStatus(status) {
		selectedStatus = status;
		filterRequisitions();
	}

	// Show confirmation modal for approval
	function showApprovalConfirm(requisitionId) {
		pendingRequisitionId = requisitionId;
		confirmAction = 'approve';
		showConfirmModal = true;
	}

	// Show confirmation modal for rejection
	function showRejectionConfirm(requisitionId) {
		pendingRequisitionId = requisitionId;
		confirmAction = 'reject';
		rejectionReason = '';
		showConfirmModal = true;
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
			await approveRequisition(pendingRequisitionId);
		} else if (confirmAction === 'reject') {
			if (!rejectionReason.trim()) {
				notifications.add({ type: 'error', message: t('approvalCenter.notifProvideReason') });
				return;
			}
			showConfirmModal = false;
			await rejectRequisition(pendingRequisitionId, rejectionReason);
		}
		cancelConfirm();
	}


	async function approveRequisition(requisitionId) {
		try {
			isProcessing = true;
		
			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the full payment schedule data
				const { data: scheduleData, error: fetchError } = await supabase
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', requisitionId)
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
					.eq('id', requisitionId);

				if (deleteError) throw deleteError;

				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: t('approvalCenter.pushPaymentScheduleApprovedTitle'),
						message: t('approvalCenter.pushPaymentScheduleApprovedMsg', { type: scheduleData.schedule_type.replace('_', ' '), branch: scheduleData.branch_name, category: getCategoryName(scheduleData.expense_category_name_en, scheduleData.expense_category_name_ar), amount: parseFloat(scheduleData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), approver: getCurrentUserName() }),
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [scheduleData.created_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
					console.log('✅ Approval notification sent to creator:', scheduleData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'success', message: t('approvalCenter.notifPaymentScheduleApproved') });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Approve vendor payment
				const { data: paymentData, error: fetchError } = await supabase
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabase
					.from('vendor_payment_schedule')
					.update({
						approval_status: 'approved',
						approved_by: $currentUser?.id,
						approved_at: new Date().toISOString(),
						approval_notes: t('approvalCenter.approvedFromCenter')
					})
					.eq('id', requisitionId);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					await notificationService.createNotification({
						title: t('approvalCenter.pushVendorPaymentApprovedTitle'),
						message: t('approvalCenter.pushVendorPaymentApprovedMsg', { vendor: paymentData.vendor_name, billNumber: paymentData.bill_number, amount: parseFloat(paymentData.final_bill_amount || paymentData.bill_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), branch: paymentData.branch_name, approver: getCurrentUserName() }),
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [paymentData.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
					console.log('✅ Approval notification sent to requester:', paymentData.approval_requested_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('approvalCenter.notifVendorPaymentApproved') });
			} else if (selectedRequisition.item_type === 'purchase_voucher') {
				// Approve purchase voucher
				const updatePayload = {
					approval_status: 'approved'
				};

				// Detect stock transfer by checking if pending fields exist (issue_type remains 'not issued' for stock transfers)
				const isStockTransfer = selectedRequisition.pending_stock_location || selectedRequisition.pending_stock_person;

				// For stock transfer: apply pending stock location and person, keep status as 'stocked'
				if (isStockTransfer) {
					// Apply pending stock location and person
					if (selectedRequisition.pending_stock_location) {
						updatePayload.stock_location = selectedRequisition.pending_stock_location;
					}
					if (selectedRequisition.pending_stock_person) {
						updatePayload.stock_person = selectedRequisition.pending_stock_person;
					}
					// Clear pending fields and approval fields
					updatePayload.pending_stock_location = null;
					updatePayload.pending_stock_person = null;
					updatePayload.approver_id = null;
					// Keep status as 'stocked', stock as 1, issue_type as 'not issued'
					// Don't touch issued_by, issued_date as they weren't set
				} else {
					// For gift/sales: change status to issued and set stock to 0
					updatePayload.status = 'issued';
					updatePayload.stock = 0;
				}

				const { error: updateError } = await supabase
					.from('purchase_voucher_items')
					.update(updatePayload)
					.eq('id', requisitionId);

				if (updateError) throw updateError;

				// Send notification
				try {
					const issueTypeLabel = isStockTransfer ? t('approvalCenter.pushStockTransferLabel') : t('approvalCenter.pushPurchaseVoucherLabel');
					const descriptionLabel = isStockTransfer ? t('approvalCenter.pushStockTransfer') : t('approvalCenter.pushYourPurchaseVoucher');
					// For stock transfer, notify the new stock person; for gift/sales, notify the issuer
					const notifyUserId = isStockTransfer 
						? selectedRequisition.pending_stock_person 
						: selectedRequisition.issued_by;
					
					if (notifyUserId) {
						await notificationService.createNotification({
							title: t('approvalCenter.pushPurchaseVoucherApprovedTitle', { type: issueTypeLabel }),
							message: t('approvalCenter.pushPurchaseVoucherApprovedMsg', { description: descriptionLabel, book: selectedRequisition.purchase_voucher_id, serial: selectedRequisition.serial_number, value: selectedRequisition.value, approver: getCurrentUserName() }),
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [notifyUserId]
						}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
						console.log('✅ Approval notification sent to:', notifyUserId);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('approvalCenter.notifPurchaseVoucherApproved') });
			} else if (selectedRequisition.item_type === 'day_off') {
				// Update day off status to approved (handle grouped requests)
				const idsToApprove = selectedRequisition._allIds || [requisitionId];
				const { error: updateError } = await supabase
					.from('day_off')
					.update({
						approval_status: 'approved',
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString()
					})
					.in('id', idsToApprove);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					if (selectedRequisition.approval_requested_by) {
						const dateInfo = selectedRequisition._dayCount > 1
							? t('approvalCenter.pushDateInfoFrom', { dateFrom: selectedRequisition._dateFrom, dateTo: selectedRequisition._dateTo, count: selectedRequisition._dayCount })
							: t('approvalCenter.pushDateInfoFor', { date: selectedRequisition.day_off_date });
						await notificationService.createNotification({
							title: t('approvalCenter.pushLeaveApprovedTitle'),
							message: t('approvalCenter.pushLeaveApprovedMsg', { dateInfo, approver: getCurrentUserName() }),
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [selectedRequisition.approval_requested_by]
						}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
						console.log('✅ Approval notification sent to requester:', selectedRequisition.approval_requested_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: t('approvalCenter.notifLeaveApproved') });
			} else {
				// Get the requisition data first
				const { data: reqData, error: reqError } = await supabase
					.from('expense_requisitions')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (reqError) throw reqError;

				// Update regular requisition status to approved
				const { error } = await supabase
					.from('expense_requisitions')
					.update({
						status: 'approved',
						updated_at: new Date().toISOString()
					})
					.eq('id', requisitionId);

				if (error) throw error;

				// Create entry in expense_scheduler so it appears in Other Payments section
				// Category can be NULL - will show as "Unknown" until request is closed with bills
				// co_user_id and co_user_name are NULL for expense_requisition (uses requester_ref_id instead)
				const schedulerEntry = {
					branch_id: reqData.branch_id,
					branch_name: reqData.branch_name,
					expense_category_id: reqData.expense_category_id || null,
					expense_category_name_en: reqData.expense_category_name_en || null,
					expense_category_name_ar: reqData.expense_category_name_ar || null,
					requisition_id: reqData.id,
					requisition_number: reqData.requisition_number,
					co_user_id: null,
					co_user_name: null,
					bill_type: 'no_bill',
					payment_method: reqData.payment_category || 'cash',
					due_date: reqData.due_date,
					amount: parseFloat(reqData.amount),
					description: reqData.description,
					schedule_type: 'expense_requisition',
					status: 'pending',
					is_paid: false,
					approver_id: reqData.approver_id,
					approver_name: reqData.approver_name,
					created_by: reqData.created_by
				};

				const { error: schedulerError } = await supabase
					.from('expense_scheduler')
					.insert([schedulerEntry]);

				if (schedulerError) {
					console.error('⚠️ Failed to create expense scheduler entry:', schedulerError);
					// Don't fail the whole approval if this fails
				} else {
					console.log('✅ Created expense scheduler entry for approved requisition');
				}
				
				// Send notification to the creator
				try {
					if (reqData) {
						await notificationService.createNotification({
							title: t('approvalCenter.pushRequisitionApprovedTitle'),
							message: t('approvalCenter.pushRequisitionApprovedMsg', { reqNumber: reqData.requisition_number, requester: reqData.requester_name, branch: reqData.branch_name, category: getCategoryName(reqData.expense_category_name_en, reqData.expense_category_name_ar), amount: parseFloat(reqData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), approver: getCurrentUserName() }),
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [reqData.created_by]
						}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
						console.log('✅ Approval notification sent to creator:', reqData.created_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'success', message: t('approvalCenter.notifRequisitionApproved') });
			}

			// Remove from pending lists without reloading
			requisitions = requisitions.filter(r => r.id !== requisitionId);
			paymentSchedules = paymentSchedules.filter(s => s.id !== requisitionId);
			vendorPayments = vendorPayments.filter(v => v.id !== requisitionId);
			purchaseVouchers = purchaseVouchers.filter(pv => pv.id !== requisitionId);
			dayOffRequests = dayOffRequests.filter(d => d.id !== requisitionId);

			// Update stats
			stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length + dayOffRequests.length;
			stats.total = stats.pending + stats.approved + stats.rejected;
	
			// Refresh filtered lists
			filterRequisitions();
	
			closeDetail();
		} catch (err) {
			console.error('Error approving:', err);
			notifications.add({ type: 'error', message: t('approvalCenter.notifApproveError') + err.message });
		} finally {
			isProcessing = false;
		}
	}

	async function rejectRequisition(requisitionId, reason) {
		try {
			isProcessing = true;

			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the schedule data first
				const { data: scheduleData, error: fetchError } = await supabase
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update payment schedule
				const { error } = await supabase
					.from('non_approved_payment_scheduler')
					.update({
						approval_status: 'rejected',
						updated_at: new Date().toISOString()
					})
					.eq('id', requisitionId);

				if (error) throw error;
				
				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: t('approvalCenter.pushPaymentScheduleRejectedTitle'),
						message: t('approvalCenter.pushPaymentScheduleRejectedMsg', { type: scheduleData.schedule_type.replace('_', ' '), reason, branch: scheduleData.branch_name, category: getCategoryName(scheduleData.expense_category_name_en, scheduleData.expense_category_name_ar), amount: parseFloat(scheduleData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), rejector: getCurrentUserName() }),
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [scheduleData.created_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
					console.log('✅ Rejection notification sent to creator:', scheduleData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
					// Don't fail the whole operation if notification fails
				}
				
				notifications.add({ type: 'warning', message: t('approvalCenter.notifPaymentScheduleRejected') });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Reject vendor payment
				const { data: paymentData, error: fetchError } = await supabase
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', requisitionId)
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
					.eq('id', requisitionId);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					await notificationService.createNotification({
						title: t('approvalCenter.pushVendorPaymentRejectedTitle'),
						message: t('approvalCenter.pushVendorPaymentRejectedMsg', { reason, vendor: paymentData.vendor_name, billNumber: paymentData.bill_number, amount: parseFloat(paymentData.final_bill_amount || paymentData.bill_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), branch: paymentData.branch_name, rejector: getCurrentUserName() }),
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [paymentData.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
					console.log('✅ Rejection notification sent to requester:', paymentData.approval_requested_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'warning', message: t('approvalCenter.notifVendorPaymentRejected') });
			} else if (selectedRequisition.item_type === 'purchase_voucher') {
				// Reject purchase voucher
				// Detect stock transfer by checking if pending fields exist (issue_type remains 'not issued' for stock transfers)
				const isStockTransfer = selectedRequisition.pending_stock_location || selectedRequisition.pending_stock_person;
				
				const rejectPayload = {
					approval_status: 'rejected',
					approver_id: null // Clear approver
				};
				
				// For stock transfer, also clear pending fields
				if (isStockTransfer) {
					rejectPayload.pending_stock_location = null;
					rejectPayload.pending_stock_person = null;
				}
				
				const { error: updateError } = await supabase
					.from('purchase_voucher_items')
					.update(rejectPayload)
					.eq('id', requisitionId);

				if (updateError) throw updateError;

				// Send notification
				try {
					const issueTypeLabel = isStockTransfer ? t('approvalCenter.pushStockTransferLabel') : t('approvalCenter.pushPurchaseVoucherLabel');
					const descriptionLabel = isStockTransfer ? t('approvalCenter.pushStockTransfer') : t('approvalCenter.pushYourPurchaseVoucher');
					// For stock transfer, notify the new stock person (who was supposed to receive); for gift/sales, notify the issuer
					const notifyUserId = isStockTransfer 
						? selectedRequisition.pending_stock_person 
						: selectedRequisition.issued_by;
					
					if (notifyUserId) {
						await notificationService.createNotification({
							title: t('approvalCenter.pushPurchaseVoucherRejectedTitle', { type: issueTypeLabel }),
							message: t('approvalCenter.pushPurchaseVoucherRejectedMsg', { description: descriptionLabel, reason, book: selectedRequisition.purchase_voucher_id, serial: selectedRequisition.serial_number, value: selectedRequisition.value, rejector: getCurrentUserName() }),
							type: 'assignment_rejected',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [notifyUserId]
						}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
						console.log('✅ Rejection notification sent to:', notifyUserId);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'warning', message: t('approvalCenter.notifPurchaseVoucherRejected') });
			} else if (selectedRequisition.item_type === 'day_off') {
				// Update day off status to rejected (handle grouped requests)
				const idsToReject = selectedRequisition._allIds || [requisitionId];
				const { error: updateError } = await supabase
					.from('day_off')
					.update({
						approval_status: 'rejected',
						rejection_reason: reason,
						approval_approved_by: $currentUser.id,
						approval_approved_at: new Date().toISOString(),
						updated_at: new Date().toISOString()
					})
					.in('id', idsToReject);

				if (updateError) throw updateError;

				// Send notification to the requester
				try {
					if (selectedRequisition.approval_requested_by) {
						const dateInfo = selectedRequisition._dayCount > 1
							? t('approvalCenter.pushDateInfoFrom', { dateFrom: selectedRequisition._dateFrom, dateTo: selectedRequisition._dateTo, count: selectedRequisition._dayCount })
							: t('approvalCenter.pushDateInfoFor', { date: selectedRequisition.day_off_date });
						await notificationService.createNotification({
							title: t('approvalCenter.pushLeaveRejectedTitle'),
							message: t('approvalCenter.pushLeaveRejectedMsg', { dateInfo, reason, rejector: getCurrentUserName() }),
							type: 'assignment_rejected',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [selectedRequisition.approval_requested_by]
						}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
						console.log('✅ Rejection notification sent to requester:', selectedRequisition.approval_requested_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'warning', message: t('approvalCenter.notifLeaveRejected') });
			} else {
				// Get requisition data first
				const { data: reqData, error: fetchError } = await supabase
					.from('expense_requisitions')
					.select('created_by, requisition_number, requester_name, amount, expense_category_name_en, expense_category_name_ar, branch_name')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update regular requisition
				const { error } = await supabase
					.from('expense_requisitions')
					.update({
						status: 'rejected',
						updated_at: new Date().toISOString()
					})
					.eq('id', requisitionId);

				if (error) throw error;
				
				// Send notification to the creator
				try {
					await notificationService.createNotification({
						title: t('approvalCenter.pushRequisitionRejectedTitle'),
						message: t('approvalCenter.pushRequisitionRejectedMsg', { reason, reqNumber: reqData.requisition_number, requester: reqData.requester_name, branch: reqData.branch_name, category: getCategoryName(reqData.expense_category_name_en, reqData.expense_category_name_ar), amount: parseFloat(reqData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), rejector: getCurrentUserName() }),
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [reqData.created_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
					console.log('✅ Rejection notification sent to creator:', reqData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'warning', message: t('approvalCenter.notifRequisitionRejected') });
			}

			// Remove from pending lists without reloading
			requisitions = requisitions.filter(r => r.id !== requisitionId);
			paymentSchedules = paymentSchedules.filter(s => s.id !== requisitionId);
			vendorPayments = vendorPayments.filter(v => v.id !== requisitionId);
			purchaseVouchers = purchaseVouchers.filter(pv => pv.id !== requisitionId);
			dayOffRequests = dayOffRequests.filter(d => d.id !== requisitionId);

			// Update stats
			stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length + dayOffRequests.length;
			stats.total = stats.pending + stats.approved + stats.rejected;

			// Refresh filtered lists
			filterRequisitions();

			closeDetail();
		} catch (err) {
			console.error('Error rejecting:', err);
			notifications.add({ type: 'error', message: t('approvalCenter.notifRejectError') + err.message });
		} finally {
			isProcessing = false;
		}
	}

	function getStatusClass(status) {
		switch (status) {
			case 'pending': return 'status-pending';
			case 'approved': return 'status-approved';
			case 'rejected': return 'status-rejected';
			default: return '';
		}
	}

	function formatCurrency(amount) {
		const loc = $locale === 'ar' ? 'ar-u-ca-gregory' : 'en-SA';
		return new Intl.NumberFormat(loc, {
			style: 'currency',
			currency: 'SAR'
		}).format(amount);
	}

	function formatDate(dateString) {
		const loc = $locale === 'ar' ? 'ar-u-ca-gregory' : 'en-US';
		return new Date(dateString).toLocaleDateString(loc, {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatDateOnly(dateString) {
		if (!dateString) return t('approvalCenter.na');
		const loc = $locale === 'ar' ? 'ar-u-ca-gregory' : 'en-US';
		return new Date(dateString).toLocaleDateString(loc, {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			timeZone: 'Asia/Riyadh'
		});
	}

	// Group day-off requests by employee + submission time + reason (same batch)
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
						? t('approvalCenter.pushDateInfoFrom', { dateFrom: req._dateFrom, dateTo: req._dateTo, count: req._dayCount })
						: t('approvalCenter.pushDateInfoFor', { date: req.day_off_date });
					await notificationService.createNotification({
						title: t('approvalCenter.pushLeaveRejectedTitle'),
						message: t('approvalCenter.pushLeaveRejectedMsg', { dateInfo, reason: '', rejector: getCurrentUserName() }),
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [req.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
				}
			} catch (notifError) {
				console.error('⚠️ Failed to send rejection notification:', notifError);
			}

			notifications.add({ type: 'success', message: t('approvalCenter.notifLeaveRejectedShort') });
			await loadRequisitions();
		} catch (err) {
			console.error('Error rejecting day off:', err);
			notifications.add({ type: 'error', message: t('approvalCenter.notifLeaveRejectFailed') });
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
						rejection_reason: t('approvalCenter.partiallyRejected')
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
							? t('approvalCenter.pushDateInfoFrom', { dateFrom: selectedRequisition._dateFrom, dateTo: selectedRequisition._dateTo, count: approvedIds.length })
							: t('approvalCenter.pushDateInfoFor', { date: selectedRequisition.day_off_date });
						message = t('approvalCenter.pushLeaveApprovedMsg', { dateInfo, approver: getCurrentUserName() });
					} else {
						message = t('approvalCenter.pushLeavePartialMsg', { approved: approvedIds.length, rejected: rejectedIds.length, approver: getCurrentUserName() });
					}
					await notificationService.createNotification({
						title: rejectedIds.length === 0 ? t('approvalCenter.pushLeaveApprovedTitle') : t('approvalCenter.pushLeavePartialTitle'),
						message,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [selectedRequisition.approval_requested_by]
					}, $currentUser?.id || $currentUser?.username || t('approvalCenter.system'));
				}
			} catch (notifError) {
				console.error('⚠️ Failed to send notification:', notifError);
			}

			const msg = rejectedIds.length === 0
				? t('approvalCenter.leaveApprovedMsg')
				: t('approvalCenter.leavePartialMsg', { approved: approvedIds.length, rejected: rejectedIds.length });
			notifications.add({ type: 'success', message: msg });
			showDayOffApproveModal = false;
			await loadRequisitions();
		} catch (err) {
			console.error('Error processing day off approval:', err);
			notifications.add({ type: 'error', message: t('approvalCenter.notifLeaveProcessFailed') });
		} finally {
			isProcessing = false;
			selectedRequisition = null;
		}
	}

</script>

<div class="approval-center">
	<!-- Section Tabs -->
	<div class="section-tabs">
		<button 
			class="tab-button {activeSection === 'approvals' ? 'active' : ''}"
			on:click={() => { activeSection = 'approvals'; filterRequisitions(); }}
		>
			📋 {t('approvalCenter.tabAssigned')}
			{#if stats.pending > 0}
				<span class="badge">{stats.pending}</span>
			{/if}
		</button>
		<button 
			class="tab-button {activeSection === 'my_requests' ? 'active' : ''}"
			on:click={() => { activeSection = 'my_requests'; filterRequisitions(); }}
		>
			📝 {t('approvalCenter.tabMyRequests')}
			{#if myStats.pending > 0}
				<span class="badge">{myStats.pending}</span>
			{/if}
		</button>
	</div>

	<!-- Stats Cards -->
	<div class="stats-grid">
		{#if activeSection === 'approvals'}
			<div class="stat-card pending clickable" on:click={() => filterByStatus('pending')}>
				<div class="stat-icon">⏳</div>
				<div class="stat-content">
					<div class="stat-value">{stats.pending}</div>
					<div class="stat-label">{t('approvalCenter.pending')}</div>
				</div>
			</div>

			<div class="stat-card approved clickable" on:click={() => filterByStatus('approved')}>
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">{stats.approved}</div>
					<div class="stat-label">{t('approvalCenter.approved')}</div>
				</div>
			</div>

			<div class="stat-card rejected clickable" on:click={() => filterByStatus('rejected')}>
				<div class="stat-icon">❌</div>
				<div class="stat-content">
					<div class="stat-value">{stats.rejected}</div>
					<div class="stat-label">{t('approvalCenter.rejected')}</div>
				</div>
			</div>

			<div class="stat-card total clickable" on:click={() => filterByStatus('all')}>
				<div class="stat-icon">📊</div>
				<div class="stat-content">
					<div class="stat-value">{stats.total}</div>
					<div class="stat-label">{t('approvalCenter.total')}</div>
				</div>
			</div>
		{:else}
			<div class="stat-card pending clickable" on:click={() => filterByStatus('pending')}>
				<div class="stat-icon">⏳</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.pending}</div>
					<div class="stat-label">{t('approvalCenter.pending')}</div>
				</div>
			</div>

			<div class="stat-card approved clickable" on:click={() => filterByStatus('approved')}>
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.approved}</div>
					<div class="stat-label">{t('approvalCenter.approved')}</div>
				</div>
			</div>

			<div class="stat-card rejected clickable" on:click={() => filterByStatus('rejected')}>
				<div class="stat-icon">❌</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.rejected}</div>
					<div class="stat-label">{t('approvalCenter.rejected')}</div>
				</div>
			</div>

			<div class="stat-card total clickable" on:click={() => filterByStatus('all')}>
				<div class="stat-icon">📊</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.total}</div>
					<div class="stat-label">{t('approvalCenter.total')}</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Filters -->
	<div class="filters">
		{#if activeSection === 'my_requests'}
			<div class="filter-group">
				<label>{t('approvalCenter.statusLabel')}</label>
				<select bind:value={selectedStatus} on:change={filterRequisitions}>
					<option value="all">{t('approvalCenter.all')}</option>
					<option value="pending">{t('approvalCenter.pending')}</option>
					<option value="approved">{t('approvalCenter.approved')}</option>
					<option value="rejected">{t('approvalCenter.rejected')}</option>
				</select>
			</div>
		{/if}
		<div class="filter-group search">
			<input
				type="text"
				bind:value={searchQuery}
				on:input={filterRequisitions}
				placeholder="🔍 {t('approvalCenter.searchPlaceholder')}"
			/>
		</div>
		<button class="btn-refresh" on:click={loadRequisitions}>🔄 {t('approvalCenter.refresh')}</button>
	</div>

	<!-- Requisitions Table -->
	<div class="content">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{t('approvalCenter.loadingRequisitions')}</p>
			</div>
		{:else if (activeSection === 'approvals' && filteredRequisitions.length === 0) || (activeSection === 'my_requests' && filteredMyRequests.length === 0)}
			<div class="empty-state">
				<div class="empty-icon">📋</div>
				<h3>{activeSection === 'approvals' ? t('approvalCenter.noApprovalsFound') : t('approvalCenter.noRequestsFound')}</h3>
				<p>{activeSection === 'approvals' ? t('approvalCenter.noApprovalsMessage') : t('approvalCenter.noRequestsMessage')}</p>
			</div>
		{:else}
			<div class="table-wrapper">
				<table class="requisitions-table">
					<thead>
						<tr>
							<th>{t('approvalCenter.requisitionNumber')}</th>
							<th>{t('approvalCenter.branch')}</th>
							<th>{t('approvalCenter.generatedBy')}</th>
							<th>{t('approvalCenter.requester')}</th>
							<th>{t('approvalCenter.category')}</th>
							<th>{t('approvalCenter.amount')}</th>
							<th>{t('approvalCenter.paymentType')}</th>
							<th>{t('approvalCenter.status')}</th>
							<th>{t('approvalCenter.dueDate')}</th>
							<th>{t('approvalCenter.date')}</th>
							<th>{t('approvalCenter.actions')}</th>
						</tr>
					</thead>
					<tbody>
						{#each (activeSection === 'approvals' ? filteredRequisitions : filteredMyRequests) as req (req.id || req.requisition_number)}
							<tr>
								{#if req.item_type === 'requisition'}
									<!-- Expense Requisition Row -->
									<td class="req-number">{req.requisition_number}</td>
									<td>{req.branch_name}</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {activeSection === 'approvals' ? (req.created_by_user ? getDisplayName(req.created_by_user) : (req.created_by_username || t('approvalCenter.unknown'))) : (req.approver_name || t('approvalCenter.notAssigned'))}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.requester_name}</div>
											<div class="requester-id">{t('approvalCenter.idLabel')} {req.requester_id}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{getCategoryName(req.expense_category_name_en, req.expense_category_name_ar)}</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.amount)}</td>
									<td class="payment-type">{req.payment_category.replace(/_/g, ' ')}</td>
									<td>
										<span class="status-badge {getStatusClass(req.status)}">
											{getStatusText(req.status)}
										</span>
									</td>
									<td class="date">{req.due_date ? formatDate(req.due_date) : '-'}</td>
									<td class="date">{formatDate(req.created_at)}</td>
									<td class="action-buttons">
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️
										</button>
										{#if req.status === 'pending' && activeSection === 'approvals' && userCanApprove}
											<button class="btn-approve-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'approve'; showConfirmModal = true; }} disabled={isProcessing}>
												✅
											</button>
											<button class="btn-reject-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'reject'; showConfirmModal = true; }} disabled={isProcessing}>
												❌
											</button>
										{/if}
									</td>
								{:else if req.item_type === 'payment_schedule'}
									<!-- Payment Schedule Row -->
									<td class="req-number">
										<span class="schedule-badge">📅 {req.schedule_type.replace(/_/g, ' ')}</span>
										<div class="schedule-id">{t('approvalCenter.scheduleId')}: {req.id}</div>
									</td>
									<td>{req.branch_name}</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {activeSection === 'approvals' ? getDisplayName(req.creator) : getDisplayName(req.approver)}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.co_user_name || '-'}</div>
											<div class="requester-id">{t('approvalCenter.coUser')}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{getCategoryName(req.expense_category_name_en, req.expense_category_name_ar)}</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.amount)}</td>
									<td class="payment-type">{req.payment_method?.replace(/_/g, ' ') || t('approvalCenter.na')}</td>
									<td>
										<span class="status-badge {
											req.approval_status === 'pending' ? 'status-pending' : 
											req.approval_status === 'approved' ? 'status-approved' : 
											req.approval_status === 'rejected' ? 'status-rejected' : 
											'status-pending'
										}">
											{getStatusText(req.approval_status)}
										</span>
									</td>
									<td class="date due-date">{req.due_date ? formatDate(req.due_date) : '-'}</td>
									<td class="date">{formatDate(req.created_at)}</td>
									<td class="action-buttons">
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️
										</button>
										{#if req.approval_status === 'pending' && activeSection === 'approvals' && userCanApprove}}
											<button class="btn-approve-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'approve'; showConfirmModal = true; }} disabled={isProcessing}>
												✅
											</button>
											<button class="btn-reject-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'reject'; showConfirmModal = true; }} disabled={isProcessing}>
												❌
											</button>
										{/if}
									</td>
								{:else if req.item_type === 'vendor_payment'}
									<!-- Vendor Payment Row -->
									<td class="req-number">
										<span class="schedule-badge vendor-payment">💰 {t('approvalCenter.vendorPayment')}</span>
										<div class="schedule-id">{t('approvalCenter.billLabel')} {req.bill_number}</div>
									</td>
									<td>{req.branch_name}</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {getDisplayName(req.requester)}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.vendor_name}</div>
											<div class="requester-id">{t('approvalCenter.vendor')}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{t('approvalCenter.catVendorPayment')}</div>
											<div class="category-ar">دفعة المورد</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.final_bill_amount || req.bill_amount)}</td>
									<td class="payment-type">{req.payment_method?.replace(/_/g, ' ') || t('approvalCenter.na')}</td>
									<td>
										<span class="status-badge status-pending">
											{t('approvalCenter.sentForApproval')}
										</span>
									</td>
									<td class="date due-date">{req.due_date ? formatDate(req.due_date) : '-'}</td>
									<td class="date">{formatDate(req.approval_requested_at)}</td>
									<td class="action-buttons">
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️
										</button>
										{#if activeSection === 'approvals' && userCanApprove}
											<button class="btn-approve-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'approve'; showConfirmModal = true; }} disabled={isProcessing}>
												✅
											</button>
											<button class="btn-reject-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'reject'; showConfirmModal = true; }} disabled={isProcessing}>
												❌
											</button>
										{/if}
									</td>
								{:else if req.item_type === 'purchase_voucher'}
									<!-- Purchase Voucher Row -->
									<td class="req-number">
										{#if req.issue_type === 'stock transfer'}
											<span class="schedule-badge transfer">📦 {t('approvalCenter.stockTransfer')}</span>
										{:else if req.issue_type === 'gift'}
											<span class="schedule-badge gift">🎁 {t('approvalCenter.gift')}</span>
										{:else if req.issue_type === 'sales'}
											<span class="schedule-badge sales">💰 {t('approvalCenter.sales')}</span>
										{:else}
											<span class="schedule-badge">🎟️ {t('approvalCenter.purchaseVoucher')}</span>
										{/if}
										<div class="schedule-id">{t('approvalCenter.book')}: {req.purchase_voucher_id}</div>
										<div class="schedule-id">{t('approvalCenter.serialNumber')}: #{req.serial_number}</div>
									</td>
									<td>
										{req.stock_location_branch?.name_en || '-'}
										{#if req.issue_type === 'stock transfer' && req.pending_location_branch}
											<div style="font-size: 11px; color: #3182ce;">→ {req.pending_location_branch.name_en}</div>
										{/if}
									</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {getDisplayName(req.issued_by_user)}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">#{req.serial_number}</div>
											<div class="requester-id">{t('approvalCenter.serialNumber')}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											{#if req.issue_type === 'stock transfer'}
												<div>{t('approvalCenter.catStockTransfer')}</div>
												<div class="category-ar">تحويل المخزون</div>
											{:else if req.issue_type === 'gift'}
												<div>{t('approvalCenter.catGift')}</div>
												<div class="category-ar">قسيمة هدية</div>
											{:else if req.issue_type === 'sales'}
												<div>{t('approvalCenter.catSales')}</div>
												<div class="category-ar">قسيمة مبيعات</div>
											{:else}
												<div>{t('approvalCenter.catPurchaseVoucher')}</div>
												<div class="category-ar">قسيمة الشراء</div>
											{/if}
										</div>
									</td>
									<td class="amount">{formatCurrency(req.value)}</td>
									<td class="payment-type">{req.status || t('approvalCenter.stocked')}</td>
									<td>
										<span class="status-badge {req.approval_status === 'pending' ? 'status-pending' : 'status-approved'}">
											{getStatusText(req.approval_status)}
										</span>
									</td>
									<td class="date">-</td>
									<td class="date">{req.issued_date ? formatDate(req.issued_date) : '-'}</td>
									<td class="action-buttons">
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️
										</button>
										{#if req.approval_status === 'pending' && activeSection === 'approvals' && userCanApprove}
											<button class="btn-approve-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'approve'; showConfirmModal = true; }} disabled={isProcessing}>
												✅
											</button>
											<button class="btn-reject-inline" on:click={() => { selectedRequisition = req; pendingRequisitionId = req.id; confirmAction = 'reject'; showConfirmModal = true; }} disabled={isProcessing}>
												❌
											</button>
										{/if}
									</td>
								{:else if req.item_type === 'day_off'}
									<!-- Day Off Request Row (Grouped) -->
									<td class="req-number">
										<span class="schedule-badge day-off">📅 {t('approvalCenter.dayOff')} {#if req._dayCount > 1}({req._dayCount} {t('approvalCenter.days')}){/if}</span>
									</td>
									<td>-</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {activeSection === 'approvals' ? getDisplayName(req.requester) : t('approvalCenter.myRequest')}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
										<div class="requester-name">{getEmployeeName(req.employee)}</div>
											<div class="requester-id">{t('approvalCenter.employee')}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{req.reason ? (req.reason.reason_en || t('approvalCenter.catDayOff')) : t('approvalCenter.catDayOff')}</div>
											<div class="category-ar">{req.reason ? (req.reason.reason_ar || 'طلب إجازة يوم') : 'طلب إجازة يوم'}</div>
										</div>
									</td>
									<td class="amount">-</td>
									<td class="payment-type">{req.is_deductible_on_salary ? '💰 ' + t('approvalCenter.yes') : t('approvalCenter.no')}</td>
									<td>
										<span class="status-badge status-{req.approval_status}">
											{getStatusText(req.approval_status)}
										</span>
									</td>
									<td class="date due-date">
										{#if req._dayCount > 1}
											{formatDateOnly(req._dateFrom)} → {formatDateOnly(req._dateTo)}
										{:else}
											{req.day_off_date ? formatDateOnly(req.day_off_date) : '-'}
										{/if}
									</td>
									<td class="date">{formatDate(req.approval_requested_at)}</td>
									<td class="action-buttons">
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️
										</button>
										{#if req.approval_status === 'pending' && activeSection === 'approvals' && userCanApprove}
											<button class="btn-approve-inline" on:click={() => openDayOffApproveModal(req)} disabled={isProcessing}>
												✅
											</button>
											<button class="btn-reject-inline" on:click={() => rejectDayOffInstant(req)} disabled={isProcessing}>
												❌
											</button>
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
</div>

<!-- Detail Modal -->
{#if showDetailModal && selectedRequisition}
	<div class="modal-overlay" on:click={closeDetail}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>📄 {selectedRequisition.item_type === 'day_off' ? t('approvalCenter.leaveRequestDetails') : selectedRequisition.item_type === 'purchase_voucher' ? t('approvalCenter.voucherDetails') : t('approvalCenter.requisitionDetails')}</h2>
				<button class="modal-close" on:click={closeDetail}>×</button>
			</div>

			<div class="modal-body">
				{#if selectedRequisition.item_type === 'requisition'}
					<!-- Requisition Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>{t('approvalCenter.requisitionNumberLabel')}</label>
							<div class="detail-value">{selectedRequisition.requisition_number}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.status')}</label>
							<span class="status-badge {getStatusClass(selectedRequisition.status)}">
								{getStatusText(selectedRequisition.status)}
							</span>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.branch')}</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.approver')}</label>
							<div class="detail-value">{selectedRequisition.approver_name || t('approvalCenter.notAssigned')}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.category')}</label>
							<div class="detail-value">
								{getCategoryName(selectedRequisition.expense_category_name_en, selectedRequisition.expense_category_name_ar)}
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.requester')}</label>
							<div class="detail-value">
								{selectedRequisition.requester_name}
								<br>
								<small>{t('approvalCenter.idLabel')} {selectedRequisition.requester_id}</small>
								<br>
								<small>{t('approvalCenter.contact')}: {selectedRequisition.requester_contact}</small>
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.amount')}</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.amount)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.vatApplicable')}</label>
							<div class="detail-value">{selectedRequisition.vat_applicable ? t('approvalCenter.yes') : t('approvalCenter.no')}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.paymentCategory')}</label>
							<div class="detail-value">{selectedRequisition.payment_category.replace(/_/g, ' ')}</div>
						</div>

						{#if selectedRequisition.credit_period}
							<div class="detail-item">
								<label>{t('approvalCenter.creditPeriod')}</label>
								<div class="detail-value">{selectedRequisition.credit_period} {t('approvalCenter.days')}</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>{t('approvalCenter.bankName')}</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>{t('approvalCenter.iban')}</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.description')}</label>
								<div class="detail-value description">{selectedRequisition.description}</div>
							</div>
						{/if}

						{#if selectedRequisition.image_url}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.attachment')}</label>
								<div class="detail-value">
									<img src={selectedRequisition.image_url} alt="Requisition" class="attachment-image" />
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.createdDate')}</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'payment_schedule'}
					<!-- Payment Schedule Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>{t('approvalCenter.scheduleType')}</label>
							<div class="detail-value">
								<span class="schedule-badge">{selectedRequisition.schedule_type.replace(/_/g, ' ')}</span>
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.status')}</label>
							<span class="status-badge {
								selectedRequisition.approval_status === 'pending' ? 'status-pending' : 
								selectedRequisition.approval_status === 'approved' ? 'status-approved' : 
								selectedRequisition.approval_status === 'rejected' ? 'status-rejected' : 
								'status-pending'
							}">
								{getStatusText(selectedRequisition.approval_status)}
							</span>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.branch')}</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.category')}</label>
							<div class="detail-value">
								{getCategoryName(selectedRequisition.expense_category_name_en, selectedRequisition.expense_category_name_ar)}
							</div>
						</div>

						{#if selectedRequisition.co_user_name}
							<div class="detail-item">
								<label>{t('approvalCenter.coUser')}</label>
								<div class="detail-value">{selectedRequisition.co_user_name}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.approver')}</label>
							<div class="detail-value">{selectedRequisition.approver_name}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.createdBy')}</label>
							<div class="detail-value">{getDisplayName(selectedRequisition.creator)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.amount')}</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.amount)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.paymentMethod')}</label>
							<div class="detail-value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || t('approvalCenter.na')}</div>
						</div>

						{#if selectedRequisition.bill_type}
							<div class="detail-item">
								<label>{t('approvalCenter.billType')}</label>
								<div class="detail-value">{selectedRequisition.bill_type.replace(/_/g, ' ')}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_number}
							<div class="detail-item">
								<label>{t('approvalCenter.billNumber')}</label>
								<div class="detail-value">{selectedRequisition.bill_number}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<label>{t('approvalCenter.billDate')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.bill_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<label>{t('approvalCenter.dueDate')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.credit_period}
							<div class="detail-item">
								<label>{t('approvalCenter.creditPeriod')}</label>
								<div class="detail-value">{selectedRequisition.credit_period} {t('approvalCenter.days')}</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>{t('approvalCenter.bankName')}</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>{t('approvalCenter.iban')}</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.description')}</label>
								<div class="detail-value description">{selectedRequisition.description}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_file_url}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.billAttachment')}</label>
								<div class="detail-value">
									<a href={selectedRequisition.bill_file_url} target="_blank" class="btn-view-file">
										📄 {t('approvalCenter.viewBillFile')}
									</a>
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.createdDate')}</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.createdBy')}</label>
							<div class="detail-value">{getDisplayName(selectedRequisition.creator)}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'vendor_payment'}
					<!-- Vendor Payment Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>{t('approvalCenter.paymentType')}</label>
							<div class="detail-value">
								<span class="schedule-badge vendor-payment">💰 {t('approvalCenter.vendorPayment')}</span>
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.status')}</label>
							<span class="status-badge status-pending">
								{t('approvalCenter.sentForApproval')}
							</span>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.billNumber')}</label>
							<div class="detail-value">{selectedRequisition.bill_number}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.vendorName')}</label>
							<div class="detail-value">{selectedRequisition.vendor_name}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.branch')}</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.billAmount')}</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.bill_amount)}</div>
						</div>

						{#if selectedRequisition.final_bill_amount && selectedRequisition.final_bill_amount !== selectedRequisition.bill_amount}
							<div class="detail-item">
								<label>{t('approvalCenter.finalBillAmount')}</label>
								<div class="detail-value amount-large">{formatCurrency(selectedRequisition.final_bill_amount)}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.paymentMethod')}</label>
							<div class="detail-value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || t('approvalCenter.na')}</div>
						</div>

						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<label>{t('approvalCenter.billDate')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.bill_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<label>{t('approvalCenter.dueDate')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.original_due_date && selectedRequisition.original_due_date !== selectedRequisition.due_date}
							<div class="detail-item">
								<label>{t('approvalCenter.originalDueDate')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.original_due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>{t('approvalCenter.bankName')}</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>{t('approvalCenter.iban')}</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.priority}
							<div class="detail-item">
								<label>{t('approvalCenter.priority')}</label>
								<div class="detail-value">{selectedRequisition.priority}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.requestedDate')}</label>
							<div class="detail-value">{formatDate(selectedRequisition.approval_requested_at)}</div>
						</div>

						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.notes')}</label>
								<div class="detail-value description">{selectedRequisition.approval_notes}</div>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'purchase_voucher'}
					<!-- Purchase Voucher Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>{t('approvalCenter.requestType')}</label>
							<div class="detail-value">
								{#if selectedRequisition.issue_type === 'stock transfer'}
									<span class="schedule-badge transfer">📦 {t('approvalCenter.stockTransfer')}</span>
								{:else if selectedRequisition.issue_type === 'gift'}
									<span class="schedule-badge gift">🎁 {t('approvalCenter.gift')}</span>
								{:else if selectedRequisition.issue_type === 'sales'}
									<span class="schedule-badge sales">💰 {t('approvalCenter.sales')}</span>
								{:else}
									<span class="schedule-badge purchase-voucher">🧾 {t('approvalCenter.purchaseVoucher')}</span>
								{/if}
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.voucherBookId')}</label>
							<div class="detail-value">{selectedRequisition.purchase_voucher_id || t('approvalCenter.na')}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.serialNumber')}</label>
							<div class="detail-value amount-large">#{selectedRequisition.serial_number || t('approvalCenter.na')}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.approvalStatus')}</label>
							<span class="status-badge {
								selectedRequisition.approval_status === 'pending' ? 'status-pending' : 
								selectedRequisition.approval_status === 'approved' ? 'status-approved' : 
								selectedRequisition.approval_status === 'rejected' ? 'status-rejected' : 
								'status-pending'
							}">
								{getStatusText(selectedRequisition.approval_status)}
							</span>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.voucherValue')}</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.value || 0)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.currentStock')}</label>
							<div class="detail-value">{selectedRequisition.stock ?? t('approvalCenter.na')}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.currentLocation')}</label>
							<div class="detail-value">{selectedRequisition.stock_location_branch?.name_en || t('approvalCenter.na')}</div>
						</div>

						{#if selectedRequisition.issue_type === 'stock transfer'}
							<div class="detail-item">
								<label>🔄 {t('approvalCenter.transferToLocation')}</label>
								<div class="detail-value" style="color: #3182ce; font-weight: 600;">
									{selectedRequisition.pending_location_branch?.name_en || t('approvalCenter.na')}
								</div>
							</div>

							<div class="detail-item">
								<label>🔄 {t('approvalCenter.transferToPerson')}</label>
								<div class="detail-value" style="color: #3182ce; font-weight: 600;">
									{getDisplayName(selectedRequisition.pending_person_user)}
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.requestedBy')}</label>
							<div class="detail-value">{getDisplayName(selectedRequisition.issued_by_user)}</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.requestDate')}</label>
							<div class="detail-value">{selectedRequisition.issued_date ? formatDate(selectedRequisition.issued_date) : t('approvalCenter.na')}</div>
						</div>

						{#if selectedRequisition.remarks}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.remarks')}</label>
								<div class="detail-value description">{selectedRequisition.remarks}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.createdDate')}</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'day_off'}
					<!-- Day Off Request Details (Grouped) -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>{t('approvalCenter.requestStatus')}</label>
							<span class="status-badge status-{selectedRequisition.approval_status}">
								{getStatusText(selectedRequisition.approval_status)}
							</span>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.employee')}</label>
							<div class="detail-value">
								👤 {getEmployeeName(selectedRequisition.employee)}
							</div>
						</div>

						<div class="detail-item">
							<label>{t('approvalCenter.requestedBy')}</label>
							<div class="detail-value">
								👤 {getDisplayName(selectedRequisition.requester)}
							</div>
						</div>

						{#if selectedRequisition._dayCount > 1}
							<div class="detail-item">
								<label>{t('approvalCenter.dateRange')}</label>
								<div class="detail-value">
									{formatDateOnly(selectedRequisition._dateFrom)} → {formatDateOnly(selectedRequisition._dateTo)}
								</div>
							</div>
							<div class="detail-item">
								<label>{t('approvalCenter.totalDays')}</label>
								<div class="detail-value">
									📅 {selectedRequisition._dayCount} {t('approvalCenter.days')}
								</div>
							</div>
							<div class="detail-item full-width">
								<label>{t('approvalCenter.allDates')}</label>
								<div class="detail-value" style="display: flex; flex-wrap: wrap; gap: 0.5rem;">
									{#each (selectedRequisition._allDates || []) as dayDate}
										<span style="background: #f0f7ff; padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.85rem; border: 1px solid #dbeafe;">
											{formatDateOnly(dayDate)}
										</span>
									{/each}
								</div>
							</div>
						{:else}
							<div class="detail-item">
								<label>{t('approvalCenter.dayOffDate')}</label>
								<div class="detail-value">{selectedRequisition.day_off_date ? formatDateOnly(selectedRequisition.day_off_date) : '-'}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.reason')}</label>
							<div class="detail-value">
								{selectedRequisition.reason ? (selectedRequisition.reason[$locale === 'en' ? 'reason_en' : 'reason_ar'] || t('approvalCenter.na')) : t('approvalCenter.na')}
								{#if selectedRequisition.reason && selectedRequisition.reason.reason_en}
									<br>
									<small style="color: #666;">EN: {selectedRequisition.reason.reason_en}</small>
								{/if}
								{#if selectedRequisition.reason && selectedRequisition.reason.reason_ar}
									<br>
									<small style="color: #666;">AR: {selectedRequisition.reason.reason_ar}</small>
								{/if}
							</div>
						</div>

						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<label>📝 {t('approvalCenter.description')}</label>
								<div class="detail-value description">{selectedRequisition.description}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.deductibleOnSalary')}</label>
							<div class="detail-value">{selectedRequisition.is_deductible_on_salary ? '💰 ' + t('approvalCenter.yes') : t('approvalCenter.no')}</div>
						</div>

						{#if selectedRequisition.document_url}
							<div class="detail-item full-width">
								<label>📎 {t('approvalCenter.documentAttached')}</label>
								<div class="detail-value">
									<button 
										class="btn-view-doc"
										on:click={() => window.open(selectedRequisition.document_url, '_blank')}
										title="Click to view document">
										📄 {t('approvalCenter.viewDocument')}
									</button>
									<br>
									<small>{t('approvalCenter.uploaded')}: {selectedRequisition.document_uploaded_at ? formatDate(selectedRequisition.document_uploaded_at) : t('approvalCenter.na')}</small>
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>{t('approvalCenter.requestedOn')}</label>
							<div class="detail-value">{formatDate(selectedRequisition.approval_requested_at)}</div>
						</div>

						{#if selectedRequisition.approval_approved_at}
							<div class="detail-item">
								<label>{t('approvalCenter.approvedOn')}</label>
								<div class="detail-value">{formatDate(selectedRequisition.approval_approved_at)}</div>
							</div>

							<div class="detail-item">
								<label>{t('approvalCenter.approvedBy')}</label>
								<div class="detail-value">👤 {selectedRequisition.approval_approved_by || t('approvalCenter.system')}</div>
							</div>
						{/if}

						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<label>{t('approvalCenter.approvalNotes')}</label>
								<div class="detail-value description">{selectedRequisition.approval_notes}</div>
							</div>
						{/if}

						{#if selectedRequisition.rejection_reason}
							<div class="detail-item full-width">
								<label style="color: #dc2626;">{t('approvalCenter.rejectionReason')}</label>
								<div class="detail-value description" style="color: #dc2626;">{selectedRequisition.rejection_reason}</div>
							</div>
						{/if}
					</div>
				{/if}
			</div>

		<div class="modal-footer">
			{#if (selectedRequisition.item_type === 'requisition' && selectedRequisition.status === 'pending') || (selectedRequisition.item_type === 'payment_schedule' && (selectedRequisition.approval_status === 'pending' || !selectedRequisition.approval_status)) || (selectedRequisition.item_type === 'vendor_payment' && selectedRequisition.approval_status === 'sent_for_approval') || (selectedRequisition.item_type === 'purchase_voucher' && selectedRequisition.approval_status === 'pending') || (selectedRequisition.item_type === 'day_off' && selectedRequisition.approval_status === 'pending')}
					{@const canApproveThis = selectedRequisition.item_type === 'payment_schedule' 
						? selectedRequisition.approver_id === $currentUser?.id 
						: selectedRequisition.item_type === 'vendor_payment'
						? userCanApprove
						: selectedRequisition.item_type === 'purchase_voucher'
						? selectedRequisition.approver_id === $currentUser?.id || userCanApprove
						: selectedRequisition.item_type === 'day_off'
						? userCanApprove
						: userCanApprove}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? t('approvalCenter.itemPaymentSchedule') : selectedRequisition.item_type === 'vendor_payment' ? t('approvalCenter.itemVendorPayment') : selectedRequisition.item_type === 'purchase_voucher' ? t('approvalCenter.itemPurchaseVoucher') : selectedRequisition.item_type === 'day_off' ? t('approvalCenter.itemDayOffRequest') : t('approvalCenter.itemRequisition')}
					{#if !canApproveThis}
						<div class="permission-notice">
							ℹ️ {t('approvalCenter.noPermission')} {itemTypeName}.
							<br><small>{selectedRequisition.item_type === 'payment_schedule' ? t('approvalCenter.assignedDifferent') : t('approvalCenter.contactAdmin')}</small>
						</div>
					{/if}
					{#if selectedRequisition.item_type === 'day_off'}
						<button
							class="btn-approve"
							on:click={() => { closeDetail(); openDayOffApproveModal(selectedRequisition); }}
							disabled={isProcessing || !canApproveThis}
							title={!canApproveThis ? t('approvalCenter.needPermissionApprove') : t('approvalCenter.approveThis')}
						>
							{isProcessing ? '⏳ ' + t('approvalCenter.processing') : '✅ ' + t('approvalCenter.approve')}
						</button>
						<button
							class="btn-reject"
							on:click={() => { closeDetail(); rejectDayOffInstant(selectedRequisition); }}
							disabled={isProcessing || !canApproveThis}
							title={!canApproveThis ? t('approvalCenter.needPermissionReject') : t('approvalCenter.rejectThis')}
						>
							{isProcessing ? '⏳ ' + t('approvalCenter.processing') : '❌ ' + t('approvalCenter.reject')}
						</button>
					{:else}
						<button
							class="btn-approve"
							on:click={() => showApprovalConfirm(selectedRequisition.id)}
							disabled={isProcessing || !canApproveThis}
							title={!canApproveThis ? t('approvalCenter.needPermissionApprove') : t('approvalCenter.approveThis')}
						>
							{isProcessing ? '⏳ ' + t('approvalCenter.processing') : '✅ ' + t('approvalCenter.approve')}
						</button>
						<button
							class="btn-reject"
							on:click={() => showRejectionConfirm(selectedRequisition.id)}
							disabled={isProcessing || !canApproveThis}
							title={!canApproveThis ? t('approvalCenter.needPermissionReject') : t('approvalCenter.rejectThis')}
						>
							{isProcessing ? '⏳ ' + t('approvalCenter.processing') : '❌ ' + t('approvalCenter.reject')}
						</button>
					{/if}
				{:else}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? t('approvalCenter.itemPaymentSchedule') : selectedRequisition.item_type === 'vendor_payment' ? t('approvalCenter.itemVendorPayment') : selectedRequisition.item_type === 'purchase_voucher' ? t('approvalCenter.itemPurchaseVoucher') : selectedRequisition.item_type === 'day_off' ? t('approvalCenter.itemDayOffRequest') : t('approvalCenter.itemRequisition')}
					<div class="status-info">
						{t('approvalCenter.statusThis')} {itemTypeName} {t('approvalCenter.hasBeenStatus')} {selectedRequisition.status || selectedRequisition.approval_status}
					</div>
				{/if}
				<button class="btn-close" on:click={closeDetail}>{t('approvalCenter.close')}</button>
			</div>
		</div>
	</div>
{/if}

<!-- Day Off Approve Modal (date checkboxes) -->
{#if showDayOffApproveModal && selectedRequisition}
<div class="confirm-overlay" on:click={() => { showDayOffApproveModal = false; selectedRequisition = null; }}>
	<div class="confirm-modal dayoff-modal" on:click|stopPropagation>
		<h3 class="confirm-title">✅ {t('approvalCenter.approveLeaveRequest')}</h3>
		<p class="confirm-message" style="margin-bottom: 0.75rem;">
			<strong>{getEmployeeName(selectedRequisition.employee)}</strong>
			— {selectedRequisition.reason ? (selectedRequisition.reason[$locale === 'ar' ? 'reason_ar' : 'reason_en'] || selectedRequisition.reason.reason_en || '') : ''}
		</p>
		<p class="confirm-message" style="font-size: 0.85rem; color: #666; margin-bottom: 0.5rem;">
		{t('approvalCenter.uncheckDaysToReject')}
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
				{t('approvalCenter.cancel')}
			</button>
			<button 
				class="btn-confirm-ok approve" 
				on:click={confirmDayOffApproval}
				disabled={isProcessing || Object.values(dayOffCheckedDates).every(v => !v)}
			>
				{isProcessing ? t('approvalCenter.processing') : `${t('approvalCenter.accept')} (${Object.values(dayOffCheckedDates).filter(v => v).length})`}
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
			{confirmAction === 'approve' ? '✅ ' + t('approvalCenter.confirmApproval') : '❌ ' + t('approvalCenter.confirmRejection')}
		</h3>
		
		<p class="confirm-message">
			{#if confirmAction === 'approve'}
				{t('approvalCenter.confirmApproveMsg')} {
					selectedRequisition?.item_type === 'payment_schedule' ? t('approvalCenter.itemPaymentSchedule') : 
					selectedRequisition?.item_type === 'vendor_payment' ? t('approvalCenter.itemVendorPayment') : 
					selectedRequisition?.item_type === 'purchase_voucher' ? t('approvalCenter.itemPurchaseVoucher') :
					selectedRequisition?.item_type === 'day_off' ? t('approvalCenter.itemDayOffRequest') :
					t('approvalCenter.itemRequisition')
				}?
			{:else}
				{t('approvalCenter.confirmRejectMsg')} {
					selectedRequisition?.item_type === 'payment_schedule' ? t('approvalCenter.itemPaymentSchedule') : 
					selectedRequisition?.item_type === 'vendor_payment' ? t('approvalCenter.itemVendorPayment') : 
					selectedRequisition?.item_type === 'purchase_voucher' ? t('approvalCenter.itemPurchaseVoucher') :
					selectedRequisition?.item_type === 'day_off' ? t('approvalCenter.itemDayOffRequest') :
					t('approvalCenter.itemRequisition')
				}?
			{/if}
		</p>
		
		{#if confirmAction === 'reject'}
			<div class="form-group">
				<label for="rejection-reason" class="form-label">{t('approvalCenter.reasonForRejection')}</label>
				<textarea
					id="rejection-reason"
					bind:value={rejectionReason}
					placeholder={t('approvalCenter.rejectionPlaceholder')}
					rows="4"
					class="rejection-textarea"
				></textarea>
			</div>
		{/if}
		
		<div class="confirm-actions">
			<button class="btn-confirm-cancel" on:click={cancelConfirm}>
				{t('approvalCenter.cancel')}
			</button>
			<button 
				class="btn-confirm-ok" 
				class:approve={confirmAction === 'approve'}
				class:reject={confirmAction === 'reject'}
				on:click={confirmActionHandler}
				disabled={confirmAction === 'reject' && !rejectionReason.trim()}
			>
				{confirmAction === 'approve' ? t('approvalCenter.approve') : t('approvalCenter.reject')}
			</button>
		</div>
	</div>
</div>
{/if}

<style>
	.approval-center {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		gap: 1.5rem;
	}

	/* Section Tabs */
	.section-tabs {
		display: flex;
		gap: 1rem;
		background: white;
		padding: 0.5rem;
		border-radius: 12px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.tab-button {
		flex: 1;
		padding: 1rem 1.5rem;
		border: none;
		background: transparent;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		color: #64748b;
		cursor: pointer;
		transition: all 0.2s;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.tab-button:hover {
		background: #f8fafc;
		color: #1e293b;
	}

	.tab-button.active {
		background: #3b82f6;
		color: white;
		box-shadow: 0 4px 6px rgba(59, 130, 246, 0.3);
	}

	.tab-button .badge {
		background: #ef4444;
		color: white;
		font-size: 0.75rem;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-weight: 700;
		min-width: 24px;
		text-align: center;
	}

	.tab-button.active .badge {
		background: white;
		color: #3b82f6;
	}

	/* Stats Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 0.75rem;
	}

	.stat-card {
		background: white;
		border-radius: 10px;
		padding: 0.75rem 1rem;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.stat-card.clickable {
		cursor: pointer;
		user-select: none;
	}

	.stat-card.clickable:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-card.clickable:active {
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-icon {
		font-size: 1.5rem;
		min-width: 36px;
		text-align: center;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 1.25rem;
		font-weight: 700;
		margin-bottom: 0.1rem;
	}

	.stat-label {
		color: #64748b;
		font-size: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.stat-card.pending .stat-value {
		color: #f59e0b;
	}

	.stat-card.approved .stat-value {
		color: #10b981;
	}

	.stat-card.rejected .stat-value {
		color: #ef4444;
	}

	.stat-card.total .stat-value {
		color: #3b82f6;
	}

	/* Filters */
	.filters {
		display: flex;
		gap: 1rem;
		align-items: center;
		background: white;
		padding: 1rem;
		border-radius: 12px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.filter-group.search {
		flex: 1;
	}

	.filter-group label {
		font-weight: 600;
		color: #475569;
		white-space: nowrap;
	}

	.filter-group select,
	.filter-group input {
		padding: 0.5rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.875rem;
	}

	.filter-group.search input {
		width: 100%;
	}

	.btn-refresh {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-refresh:hover {
		background: #2563eb;
	}

	/* Content */
	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 1.5rem;
		overflow: auto;
	}

	.loading,
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #64748b;
	}

	.spinner {
		width: 50px;
		height: 50px;
		border: 4px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.empty-state h3 {
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	/* Table */
	.table-wrapper {
		overflow-x: auto;
	}

	.requisitions-table {
		width: 100%;
		border-collapse: collapse;
	}

	.requisitions-table th,
	.requisitions-table td {
		padding: 1rem;
		text-align: left;
		border-bottom: 1px solid #e2e8f0;
	}

	.requisitions-table th {
		background: #f8fafc;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		font-size: 0.75rem;
		letter-spacing: 0.5px;
	}

	.requisitions-table tbody tr:hover {
		background: #f8fafc;
	}

	.req-number {
		font-weight: 600;
		color: #3b82f6;
	}

	.generated-by-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.generated-by-name {
		font-weight: 600;
		color: #6366f1;
		font-size: 0.875rem;
	}

	.requester-info,
	.category-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.requester-name {
		font-weight: 600;
	}

	.requester-id {
		font-size: 0.75rem;
		color: #64748b;
	}

	.category-ar {
		font-size: 0.875rem;
		color: #64748b;
		direction: rtl;
	}

	.amount {
		font-weight: 700;
		color: #10b981;
	}

	.payment-type {
		text-transform: capitalize;
		font-size: 0.875rem;
	}

	.date {
		font-size: 0.875rem;
		color: #64748b;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.schedule-badge {
		display: inline-block;
		padding: 0.4rem 0.8rem;
		background: #ede9fe;
		color: #5b21b6;
		border-radius: 8px;
		font-size: 0.7rem;
		font-weight: 700;
		text-transform: uppercase;
		margin-bottom: 0.25rem;
	}

	.schedule-badge.vendor-payment {
		background: #dcfce7;
		color: #166534;
	}

	.schedule-badge.day-off {
		background: #e0e7ff;
		color: #3730a3;
	}

	.schedule-id {
		font-size: 0.7rem;
		color: #64748b;
		margin-top: 0.25rem;
	}

	.status-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-rejected {
		background: #fee2e2;
		color: #991b1b;
	}

	.btn-view {
		padding: 0.5rem 0.75rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 1.2rem;
		font-weight: 700;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	.btn-view:hover {
		background: #2563eb;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		transform: scale(1.05);
	}

	.btn-view-doc {
		padding: 0.5rem 1rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.95rem;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn-view-doc:hover {
		background: #059669;
		transform: translateY(-2px);
	}

	.btn-view-doc:active {
		transform: translateY(0);
	}

	/* Inline action buttons */
	.action-buttons {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		justify-content: center;
	}

	.btn-approve-inline,
	.btn-reject-inline {
		padding: 0.5rem 0.75rem;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 1.2rem;
		font-weight: 900;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	.btn-approve-inline {
		background: #10b981;
		color: white;
	}

	.btn-approve-inline:hover:not(:disabled) {
		background: #059669;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		transform: scale(1.05);
	}

	.btn-reject-inline {
		background: white;
		color: #ef4444;
		border: 1.5px solid #ef4444;
	}

	.btn-reject-inline:hover:not(:disabled) {
		background: #fef2f2;
		color: #dc2626;
		border-color: #dc2626;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		transform: scale(1.05);
	}

	.btn-approve-inline:disabled,
	.btn-reject-inline:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Modal */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 2rem;
	}

	.modal-content {
		background: white;
		border-radius: 16px;
		max-width: 900px;
		width: 100%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e2e8f0;
	}

	.modal-header h2 {
		margin: 0;
		color: #1e293b;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 2rem;
		cursor: pointer;
		color: #64748b;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		transition: background 0.2s;
	}

	.modal-close:hover {
		background: #f1f5f9;
	}

	.modal-body {
		padding: 1.5rem;
		overflow-y: auto;
		flex: 1;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.detail-item.full-width {
		grid-column: 1 / -1;
	}

	.detail-item label {
		font-weight: 600;
		color: #475569;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		color: #1e293b;
		font-size: 1rem;
	}

	.detail-value.amount-large {
		font-size: 1.5rem;
		font-weight: 700;
		color: #10b981;
	}

	.detail-value.description {
		padding: 1rem;
		background: #f8fafc;
		border-radius: 8px;
		white-space: pre-wrap;
	}

	.attachment-image {
		max-width: 100%;
		border-radius: 8px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		margin-top: 0.5rem;
	}

	.modal-footer {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #e2e8f0;
		justify-content: flex-end;
		flex-wrap: wrap;
	}

	.permission-notice {
		flex: 1 0 100%;
		padding: 0.75rem 1rem;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 8px;
		color: #92400e;
		font-size: 0.875rem;
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.permission-notice small {
		font-size: 0.75rem;
		color: #b45309;
	}

	.btn-approve {
		padding: 0.5rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 900;
		transition: all 0.2s;
		transform: scale(1);
	}

	.btn-approve:hover:not(:disabled) {
		background: #059669;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		transform: scale(1.05);
	}

	.btn-reject {
		padding: 0.5rem 1.5rem;
		background: white;
		color: #ef4444;
		border: 1.5px solid #ef4444;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 900;
		transition: all 0.2s;
		transform: scale(1);
	}

	.btn-reject:hover:not(:disabled) {
		background: #fef2f2;
		color: #dc2626;
		border-color: #dc2626;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		transform: scale(1.05);
	}

	.btn-close {
		padding: 0.5rem 1.5rem;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
	}

	.btn-close:hover {
		background: #cbd5e1;
	}

	.btn-approve:disabled,
	.btn-reject:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.status-info {
		flex: 1;
		padding: 0.75rem;
		background: #f1f5f9;
		border-radius: 8px;
		text-align: center;
	font-weight: 600;
	color: #475569;
}

/* Confirmation Modal */
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
}

.confirm-modal {
	background: white;
	border-radius: 16px;
	padding: 2rem;
	max-width: 500px;
	width: 90%;
	box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	animation: modalSlideIn 0.2s ease-out;
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
	font-size: 1.5rem;
	font-weight: 700;
	color: #1e293b;
	margin: 0 0 1rem 0;
	text-align: center;
}

.confirm-message {
	font-size: 1rem;
	color: #475569;
	margin: 0 0 1.5rem 0;
	text-align: center;
	line-height: 1.6;
}

.form-group {
	margin-bottom: 1.5rem;
}

.form-label {
	display: block;
	font-size: 0.875rem;
	font-weight: 600;
	color: #334155;
	margin-bottom: 0.5rem;
}

.rejection-textarea {
	width: 100%;
	padding: 0.75rem;
	border: 2px solid #e2e8f0;
	border-radius: 8px;
	font-size: 0.875rem;
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
	gap: 1rem;
	justify-content: flex-end;
}

.btn-confirm-cancel,
.btn-confirm-ok {
	padding: 0.75rem 1.5rem;
	border: none;
	border-radius: 8px;
	font-size: 0.875rem;
	font-weight: 600;
	cursor: pointer;
	transition: all 0.2s;
}

.btn-confirm-cancel {
	background: #f1f5f9;
	color: #475569;
}

.btn-confirm-cancel:hover {
	background: #e2e8f0;
}

.btn-confirm-ok {
	color: white;
}

.btn-confirm-ok.approve {
	background: #10b981;
}

.btn-confirm-ok.approve:hover {
	background: #059669;
}

.btn-confirm-ok.reject {
	background: #ef4444;
}

.btn-confirm-ok.reject:hover {
	background: #dc2626;
}

.btn-confirm-ok:disabled {
	opacity: 0.5;
	cursor: not-allowed;
}

.btn-confirm-ok:disabled:hover {
	background: #ef4444;
}

/* Bulk Approve Modal */
.bulk-confirm-modal {
	min-width: 450px;
	max-width: 600px;
}

.modal-footer {
	display: flex;
	gap: 1rem;
	justify-content: flex-end;
	padding-top: 1.5rem;
	border-top: 1px solid #e2e8f0;
}

.bulk-confirm-message {
	font-size: 1.1rem;
	color: #1e293b;
	margin-bottom: 1rem;
	line-height: 1.6;
}

.bulk-confirm-message strong {
	color: #10b981;
	font-weight: 700;
	font-size: 1.25rem;
}

.bulk-confirm-note {
	color: #64748b;
	font-size: 0.9rem;
	font-style: italic;
	margin: 0;
	line-height: 1.5;
}

.btn-cancel {
	padding: 0.75rem 1.5rem;
	background: #e2e8f0;
	color: #475569;
	border: none;
	border-radius: 8px;
	cursor: pointer;
	font-weight: 600;
	transition: all 0.2s;
}

.btn-cancel:hover:not(:disabled) {
	background: #cbd5e1;
}

.btn-cancel:disabled {
	opacity: 0.6;
	cursor: not-allowed;
}

.btn-approve-bulk {
	padding: 0.75rem 1.5rem;
	background: #10b981;
	color: white;
	border: none;
	border-radius: 8px;
	cursor: pointer;
	font-weight: 600;
	transition: all 0.2s;
	display: flex;
	align-items: center;
	gap: 0.5rem;
}

.btn-approve-bulk:hover:not(:disabled) {
	background: #059669;
	transform: translateY(-1px);
	box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
}

.btn-approve-bulk:disabled {
	opacity: 0.7;
	cursor: not-allowed;
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

/* Day Off Approve Modal */
.dayoff-modal {
	max-width: 480px;
}

.dayoff-dates-list {
	max-height: 300px;
	overflow-y: auto;
	border: 1px solid #e2e8f0;
	border-radius: 8px;
	padding: 0.5rem;
}

.dayoff-date-row {
	display: flex;
	align-items: center;
	gap: 0.75rem;
	padding: 0.5rem 0.75rem;
	border-radius: 6px;
	cursor: pointer;
	transition: background 0.15s;
	user-select: none;
}

.dayoff-date-row:hover {
	background: #f0f7ff;
}

.dayoff-date-row.unchecked {
	opacity: 0.5;
	text-decoration: line-through;
}

.dayoff-date-row input[type="checkbox"] {
	width: 18px;
	height: 18px;
	accent-color: #10b981;
	cursor: pointer;
}

.dayoff-date-text {
	font-size: 0.95rem;
	font-weight: 500;
	color: #1e293b;
}
</style>
