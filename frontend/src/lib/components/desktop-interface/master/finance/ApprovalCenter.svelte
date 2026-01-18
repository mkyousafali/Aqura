<script>
	// Approval Center Component
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { notifications } from '$lib/stores/notifications';
	import { locale } from '$lib/i18n';

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
				notifications.add({ type: 'error', message: 'Please login to access the approval center' });
				loading = false;
				return;
			}
		
		console.log('🔐 Current user:', $currentUser);
		// Get current user's approval permissions from approval_permissions table
		const { data: approvalPerms, error: permsError } = await supabase
			.from('approval_permissions')
			.select('*')
			.eq('user_id', $currentUser.id)
		.eq('is_active', true)
		.maybeSingle(); // Use maybeSingle to handle cases where user has no approval permissions

	console.log('👤 Approval permissions query result:', { approvalPerms, permsError });

	if (permsError) {
		console.error('Error fetching approval permissions:', permsError);
		notifications.add({ type: 'error', message: 'Error checking user permissions: ' + permsError.message });
		loading = false;
		return;
	}
	
	// User can approve if ANY permission is enabled
	if (approvalPerms) {
			userCanApprove = 
				approvalPerms.can_approve_requisitions ||
				approvalPerms.can_approve_single_bill ||
				approvalPerms.can_approve_multiple_bill ||
				approvalPerms.can_approve_recurring_bill ||
				approvalPerms.can_approve_vendor_payments ||
				approvalPerms.can_approve_leave_requests ||
				approvalPerms.can_approve_purchase_vouchers;
			
			console.log('👤 User approval permissions:', {
				canApprove: userCanApprove,
				requisitions: approvalPerms.can_approve_requisitions,
				single_bill: approvalPerms.can_approve_single_bill,
				multiple_bill: approvalPerms.can_approve_multiple_bill,
				recurring_bill: approvalPerms.can_approve_recurring_bill,
				vendor_payments: approvalPerms.can_approve_vendor_payments,
				leave_requests: approvalPerms.can_approve_leave_requests,
				purchase_vouchers: approvalPerms.can_approve_purchase_vouchers
			});
		} else {
		userCanApprove = false;
		console.log('👤 No approval permissions found for user');
	}

	console.log('✅ Loading approval center for user:', $currentUser.username);
	
	// Calculate date for filtering
	const twoDaysFromNow = new Date();
	twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
	const twoDaysDate = twoDaysFromNow.toISOString().split('T')[0];
	
	console.log('🔍 Loading pending items first for faster display...');
	
	// Load only pending items first for faster initial display
	const [
		requisitionsResult,
		schedulesResult,
		vendorPaymentsResult,
		purchaseVouchersResult,
		myRequisitionsResult,
		mySchedulesResult,
		myVouchersResult,
		dayOffRequestsResult,
		myDayOffRequestsResult
	] = await Promise.all([
		// 1. Requisitions where current user is approver (pending only)
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('approver_id', $currentUser.id)
			.eq('status', 'pending')
			.order('created_at', { ascending: false })
			.limit(200),
			
			// 2. Payment schedules requiring approval
			supabase
				.from('non_approved_payment_scheduler')
				.select(`
					*,
					creator:users!created_by (
						id,
						username
					)
				`)
				.eq('approval_status', 'pending')
				.eq('approver_id', $currentUser.id)
				.in('schedule_type', ['single_bill', 'multiple_bill'])
				.order('created_at', { ascending: false })
				.limit(200),
			
			// 3. Vendor payments requiring approval (only if user has permission)
			(approvalPerms && approvalPerms.can_approve_vendor_payments) ? 
				supabase
					.from('vendor_payment_schedule')
					.select(`
						*,
						requester:users!approval_requested_by (
							id,
							username
						)
					`)
				.eq('approval_status', 'sent_for_approval')
				.order('approval_requested_at', { ascending: false })
				.limit(200) :
			Promise.resolve({ data: [], error: null }),
		
		// 4. Purchase vouchers requiring approval (only if user has permission)
		(approvalPerms && approvalPerms.can_approve_purchase_vouchers) ?
			supabase
				.from('purchase_voucher_items')
				.select(`
					*,
					issued_by_user:users!purchase_voucher_items_issued_by_fkey (
						id,
						username
					),
					stock_location_branch:branches!purchase_voucher_items_stock_location_fkey (
						id,
						name_en
					),
					pending_location_branch:branches!purchase_voucher_items_pending_stock_location_fkey (
						id,
						name_en
					),
					pending_person_user:users!purchase_voucher_items_pending_stock_person_fkey (
						id,
						username
					)
				`)
				.eq('approval_status', 'pending')
				.eq('approver_id', $currentUser.id)
				.order('issued_date', { ascending: false })
				.limit(200) :
			Promise.resolve({ data: [], error: null }),
		// 5. My created requisitions (pending only)
		supabase
			.from('expense_requisitions')
			.select('*')
			.eq('created_by', $currentUser.id)
			.eq('status', 'pending')
			.order('created_at', { ascending: false })
			.limit(200),
		
		// 6. My created payment schedules (pending only)
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
		.eq('approval_status', 'pending')
		.in('schedule_type', ['single_bill', 'multiple_bill'])
		.order('created_at', { ascending: false}),
		
		// 7. My created purchase vouchers (pending only)
		supabase
			.from('purchase_voucher_items')
			.select(`
				*,
			approver_user:users!purchase_voucher_items_approver_id_fkey (
				id,
				username
			)
		`)
		.eq('issued_by', $currentUser.id)
		.eq('approval_status', 'pending')
		.order('issued_date', { ascending: false })
		.limit(200),
		
		// 8. Day off approval requests (if user has permission)
		// Show ALL pending day-off requests to users with can_approve_leave_requests permission
		(approvalPerms && approvalPerms.can_approve_leave_requests) ?
			supabase
				.from('day_off')
				.select(`
					*,
					requester:users!approval_requested_by (
						id,
						username
					),
					employee:hr_employee_master!employee_id (
						id,
						name_en,
						name_ar
					),
					reason:day_off_reasons!day_off_reason_id (
						id,
						reason_en,
						reason_ar
					)
				`)
				.eq('approval_status', 'pending')
				.order('approval_requested_at', { ascending: false })
				.limit(200) :
			Promise.resolve({ data: [], error: null }),
		
		// 9. My day off requests (all statuses)
		supabase
			.from('day_off')
			.select(`
				*,
				reason:day_off_reasons!day_off_reason_id (
					id,
					reason_en,
					reason_ar
				)
			`)
			.eq('approval_requested_by', $currentUser.id)
			.order('approval_requested_at', { ascending: false })
			.limit(200)
	]);
	
	// Process requisitions result
	const { data: requisitionsData, error: requisitionsError } = requisitionsResult;
	if (requisitionsError) {
		console.error('❌ Error loading requisitions:', requisitionsError);
	} else {
		requisitions = requisitionsData || [];
	}
		
		// Fetch usernames for requisitions if needed
		if (requisitions.length > 0) {
			const userIds = [...new Set(requisitions.map(r => r.created_by).filter(Boolean))];
			
			if (userIds.length > 0) {
				const { data: usersData } = await supabase
					.from('users')
					.select('id, username')
					.in('id', userIds);
				
				const userMap = {};
				if (usersData) {
					usersData.forEach(user => {
						userMap[user.id] = user.username;
					});
				}
				
				requisitions = requisitions.map(req => ({
					...req,
					created_by_username: userMap[req.created_by] || req.created_by || 'Unknown'
				}));
			}
		}
		console.log('✅ Loaded requisitions:', requisitions.length);
		
		// Process payment schedules result
		const { data: schedulesData, error: schedulesError } = schedulesResult;
		if (schedulesError) {
			console.error('❌ Error loading payment schedules:', schedulesError);
		} else {
			// Filter single_bill by due date, show all multiple_bill
			paymentSchedules = (schedulesData || []).filter(schedule => {
				if (schedule.schedule_type === 'multiple_bill') {
					return true;
				}
				return schedule.due_date && schedule.due_date <= twoDaysDate;
			});
			console.log('✅ Loaded payment schedules:', paymentSchedules.length);
		}
		
		// Process vendor payments result
		const { data: vendorPaymentsData, error: vendorPaymentsError } = vendorPaymentsResult;
		if (vendorPaymentsError) {
			console.error('❌ Error loading vendor payments:', vendorPaymentsError);
		} else {
			// Filter by amount limit if set
			vendorPayments = (vendorPaymentsData || []).filter(payment => {
				if (!approvalPerms || !approvalPerms.can_approve_vendor_payments) return false;
				const paymentAmount = payment.final_bill_amount || payment.bill_amount || 0;
				if (approvalPerms.vendor_payment_amount_limit === 0) return true;
				return approvalPerms.vendor_payment_amount_limit >= paymentAmount;
			});
			console.log('✅ Loaded vendor payments for approval:', vendorPayments.length);
		}
		
		// Process purchase vouchers result
		const { data: vouchersData, error: vouchersError } = purchaseVouchersResult;
		if (vouchersError) {
			console.error('❌ Error loading purchase vouchers:', vouchersError);
		} else {
			purchaseVouchers = vouchersData || [];
			console.log('✅ Loaded purchase vouchers for approval:', purchaseVouchers.length);
		}
		
		// Process my created requisitions
		const { data: myReqData, error: myReqError } = myRequisitionsResult;
		if (!myReqError && myReqData) {
			myCreatedRequisitions = myReqData || [];
			console.log('✅ My created requisitions:', myCreatedRequisitions.length);
		}
		
	// Process my created schedules
	const { data: mySchedulesData, error: mySchedulesError } = mySchedulesResult;
	if (!mySchedulesError && mySchedulesData) {
		myCreatedSchedules = mySchedulesData || [];
		console.log('✅ My created payment schedules:', myCreatedSchedules.length);
	}
	
	// Process my created purchase vouchers
	const { data: myVouchersData, error: myVouchersError } = myVouchersResult;
	if (!myVouchersError && myVouchersData) {
		myCreatedVouchers = myVouchersData || [];
		console.log('✅ My created purchase vouchers:', myCreatedVouchers.length);
	}
	
	// Process day off approval requests
	const { data: dayOffRequestsData, error: dayOffRequestsError } = dayOffRequestsResult;
	if (dayOffRequestsError) {
		console.error('❌ Error loading day off requests:', dayOffRequestsError);
	} else {
		dayOffRequests = dayOffRequestsData || [];
		console.log('✅ Day off approval requests:', dayOffRequests.length, dayOffRequests);
	}
	
	// Process my day off requests
	const { data: myDayOffRequestsData, error: myDayOffRequestsError } = myDayOffRequestsResult;
	if (myDayOffRequestsError) {
		console.error('❌ Error loading my day off requests:', myDayOffRequestsError);
	} else {
		myDayOffRequests = myDayOffRequestsData || [];
		console.log('✅ My day off requests:', myDayOffRequests.length, myDayOffRequests);
	}
	
	// Initialize empty arrays for historical data (will load on demand)
	myApprovedSchedules = [];
	approvedPaymentSchedules = [];
	rejectedPaymentSchedules = [];
	let myApprovedSchedulesCount = 0;
	let approvedSchedulesCount = 0;
	let rejectedSchedulesCount = 0;

	// Calculate stats (only pending for now, historical data will be loaded on demand)
	// Stats for approvals assigned to me
	stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length + dayOffRequests.length;
	stats.approved = 0; // Will be loaded when user switches to approved tab
	stats.rejected = 0; // Will be loaded when user switches to rejected tab
	stats.total = stats.pending;

	// Stats for my created requests (only pending initially)
	myStats.pending = myCreatedRequisitions.length + myCreatedSchedules.length + myCreatedVouchers.length + myDayOffRequests.length;
	myStats.approved = 0; // Will be loaded on demand
	myStats.rejected = 0; // Will be loaded on demand
	myStats.total = myStats.pending;
	
	console.log('📈 Approval Stats:', stats);
	console.log('📊 My Requests Stats:', myStats);

		filterRequisitions();
	
		// Load historical data in background after initial display
		loadHistoricalData();
	} catch (err) {
		console.error('Error loading requisitions:', err);
		notifications.add({ type: 'error', message: 'Error loading requisitions: ' + err.message });
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
						username
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
						username
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
						username
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
						username
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
				notifications.add({ type: 'error', message: 'Please provide a reason for rejection' });
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
						title: 'Payment Schedule Approved',
						message: `Your ${scheduleData.schedule_type.replace('_', ' ')} payment schedule has been approved!\n\nBranch: ${scheduleData.branch_name}\nCategory: ${scheduleData.expense_category_name_en}\nAmount: ${parseFloat(scheduleData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nApproved by: ${$currentUser?.username}`,
						type: 'assignment_approved',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [scheduleData.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Approval notification sent to creator:', scheduleData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'success', message: 'Payment schedule approved and moved to expense scheduler!' });
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
						approval_notes: 'Approved from Approval Center'
					})
					.eq('id', requisitionId);

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

				notifications.add({ type: 'success', message: 'Vendor payment approved successfully!' });
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
					const issueTypeLabel = isStockTransfer ? 'Stock Transfer' : 'Purchase Voucher';
					// For stock transfer, notify the new stock person; for gift/sales, notify the issuer
					const notifyUserId = isStockTransfer 
						? selectedRequisition.pending_stock_person 
						: selectedRequisition.issued_by;
					
					if (notifyUserId) {
						await notificationService.createNotification({
							title: `${issueTypeLabel} Approved`,
							message: `${isStockTransfer ? 'Stock transfer' : 'Your purchase voucher'} has been approved!\n\nBook: ${selectedRequisition.purchase_voucher_id}\nSerial: #${selectedRequisition.serial_number}\nValue: SAR ${selectedRequisition.value}\nApproved by: ${$currentUser?.username}`,
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [notifyUserId]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log('✅ Approval notification sent to:', notifyUserId);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
				}

				notifications.add({ type: 'success', message: 'Purchase voucher approved successfully!' });
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
							title: 'Expense Requisition Approved',
							message: `Your expense requisition has been approved!\n\nRequisition: ${reqData.requisition_number}\nRequester: ${reqData.requester_name}\nBranch: ${reqData.branch_name}\nCategory: ${reqData.expense_category_name_en || 'N/A'}\nAmount: ${parseFloat(reqData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nApproved by: ${$currentUser?.username}`,
							type: 'assignment_approved',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [reqData.created_by]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log('✅ Approval notification sent to creator:', reqData.created_by);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send approval notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'success', message: 'Requisition approved and added to expense scheduler!' });
			}

			// Remove from pending lists without reloading
			requisitions = requisitions.filter(r => r.id !== requisitionId);
			paymentSchedules = paymentSchedules.filter(s => s.id !== requisitionId);
			vendorPayments = vendorPayments.filter(v => v.id !== requisitionId);
			purchaseVouchers = purchaseVouchers.filter(pv => pv.id !== requisitionId);

			// Update stats
			stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length;
			stats.total = stats.pending + stats.approved + stats.rejected;
	
			// Refresh filtered lists
			filterRequisitions();
	
			closeDetail();
		} catch (err) {
			console.error('Error approving:', err);
			notifications.add({ type: 'error', message: 'Error approving: ' + err.message });
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
						title: 'Payment Schedule Rejected',
						message: `Your ${scheduleData.schedule_type.replace('_', ' ')} payment schedule has been rejected.\n\nReason: ${reason}\n\nBranch: ${scheduleData.branch_name}\nCategory: ${scheduleData.expense_category_name_en}\nAmount: ${parseFloat(scheduleData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [scheduleData.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Rejection notification sent to creator:', scheduleData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
					// Don't fail the whole operation if notification fails
				}
				
				notifications.add({ type: 'warning', message: 'Payment schedule rejected successfully!' });
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

				notifications.add({ type: 'warning', message: 'Vendor payment rejected successfully!' });
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
					const issueTypeLabel = isStockTransfer ? 'Stock Transfer' : 'Purchase Voucher';
					// For stock transfer, notify the new stock person (who was supposed to receive); for gift/sales, notify the issuer
					const notifyUserId = isStockTransfer 
						? selectedRequisition.pending_stock_person 
						: selectedRequisition.issued_by;
					
					if (notifyUserId) {
						await notificationService.createNotification({
							title: `${issueTypeLabel} Rejected`,
							message: `${isStockTransfer ? 'Stock transfer' : 'Your purchase voucher'} has been rejected.\n\nReason: ${reason}\n\nBook: ${selectedRequisition.purchase_voucher_id}\nSerial: #${selectedRequisition.serial_number}\nValue: SAR ${selectedRequisition.value}\nRejected by: ${$currentUser?.username}`,
							type: 'assignment_rejected',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [notifyUserId]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log('✅ Rejection notification sent to:', notifyUserId);
					}
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
				}

				notifications.add({ type: 'warning', message: 'Purchase voucher rejected successfully!' });
			} else {
				// Get requisition data first
				const { data: reqData, error: fetchError } = await supabase
					.from('expense_requisitions')
					.select('created_by, requisition_number, requester_name, amount, expense_category_name_en, branch_name')
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
						title: 'Expense Requisition Rejected',
						message: `Your expense requisition has been rejected.\n\nReason: ${reason}\n\nRequisition: ${reqData.requisition_number}\nRequester: ${reqData.requester_name}\nBranch: ${reqData.branch_name}\nCategory: ${reqData.expense_category_name_en}\nAmount: ${parseFloat(reqData.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nRejected by: ${$currentUser?.username}`,
						type: 'assignment_rejected',
						priority: 'high',
						target_type: 'specific_users',
						target_users: [reqData.created_by]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Rejection notification sent to creator:', reqData.created_by);
				} catch (notifError) {
					console.error('⚠️ Failed to send rejection notification:', notifError);
					// Don't fail the whole operation if notification fails
				}

				notifications.add({ type: 'warning', message: 'Requisition rejected successfully!' });
			}

			// Remove from pending lists without reloading
			requisitions = requisitions.filter(r => r.id !== requisitionId);
			paymentSchedules = paymentSchedules.filter(s => s.id !== requisitionId);
			vendorPayments = vendorPayments.filter(v => v.id !== requisitionId);
			purchaseVouchers = purchaseVouchers.filter(pv => pv.id !== requisitionId);

			// Update stats
			stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length + purchaseVouchers.length;
			stats.total = stats.pending + stats.approved + stats.rejected;

			// Refresh filtered lists
			filterRequisitions();

			closeDetail();
		} catch (err) {
			console.error('Error rejecting:', err);
			notifications.add({ type: 'error', message: 'Error rejecting: ' + err.message });
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
		return new Intl.NumberFormat('en-SA', {
			style: 'currency',
			currency: 'SAR'
		}).format(amount);
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

</script>

<div class="approval-center">
	<div class="header">
		<h1 class="title">✅ Approval Center</h1>
		<p class="subtitle">Review and approve expense requests</p>
	</div>

	<!-- Section Tabs -->
	<div class="section-tabs">
		<button 
			class="tab-button {activeSection === 'approvals' ? 'active' : ''}"
			on:click={() => { activeSection = 'approvals'; filterRequisitions(); }}
		>
			📋 Approvals Assigned to Me
			{#if stats.pending > 0}
				<span class="badge">{stats.pending}</span>
			{/if}
		</button>
		<button 
			class="tab-button {activeSection === 'my_requests' ? 'active' : ''}"
			on:click={() => { activeSection = 'my_requests'; filterRequisitions(); }}
		>
			📝 My Requests
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
					<div class="stat-label">Pending</div>
				</div>
			</div>

			<div class="stat-card approved clickable" on:click={() => filterByStatus('approved')}>
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">{stats.approved}</div>
					<div class="stat-label">Approved</div>
				</div>
			</div>

			<div class="stat-card rejected clickable" on:click={() => filterByStatus('rejected')}>
				<div class="stat-icon">❌</div>
				<div class="stat-content">
					<div class="stat-value">{stats.rejected}</div>
					<div class="stat-label">Rejected</div>
				</div>
			</div>

			<div class="stat-card total clickable" on:click={() => filterByStatus('all')}>
				<div class="stat-icon">📊</div>
				<div class="stat-content">
					<div class="stat-value">{stats.total}</div>
					<div class="stat-label">Total</div>
				</div>
			</div>
		{:else}
			<div class="stat-card pending clickable" on:click={() => filterByStatus('pending')}>
				<div class="stat-icon">⏳</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.pending}</div>
					<div class="stat-label">Pending</div>
				</div>
			</div>

			<div class="stat-card approved clickable" on:click={() => filterByStatus('approved')}>
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.approved}</div>
					<div class="stat-label">Approved</div>
				</div>
			</div>

			<div class="stat-card rejected clickable" on:click={() => filterByStatus('rejected')}>
				<div class="stat-icon">❌</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.rejected}</div>
					<div class="stat-label">Rejected</div>
				</div>
			</div>

			<div class="stat-card total clickable" on:click={() => filterByStatus('all')}>
				<div class="stat-icon">📊</div>
				<div class="stat-content">
					<div class="stat-value">{myStats.total}</div>
					<div class="stat-label">Total</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="filter-group">
			<label>Status:</label>
			<select bind:value={selectedStatus} on:change={filterRequisitions}>
				<option value="all">All</option>
				<option value="pending">Pending</option>
				<option value="approved">Approved</option>
				<option value="rejected">Rejected</option>
			</select>
		</div>
		<div class="filter-group search">
			<input
				type="text"
				bind:value={searchQuery}
				on:input={filterRequisitions}
				placeholder="🔍 Search by number, branch, requester, category..."
			/>
		</div>
		<button class="btn-refresh" on:click={loadRequisitions}>🔄 Refresh</button>
	</div>

	<!-- Requisitions Table -->
	<div class="content">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading requisitions...</p>
			</div>
		{:else if (activeSection === 'approvals' && filteredRequisitions.length === 0) || (activeSection === 'my_requests' && filteredMyRequests.length === 0)}
			<div class="empty-state">
				<div class="empty-icon">📋</div>
				<h3>No {activeSection === 'approvals' ? 'Approvals' : 'Requests'} Found</h3>
				<p>There are no {activeSection === 'approvals' ? 'approvals' : 'requests'} matching your filters.</p>
			</div>
		{:else}
			<div class="table-wrapper">
				<table class="requisitions-table">
					<thead>
						<tr>
							<th>Requisition #</th>
							<th>Branch</th>
							<th>Generated By</th>
							<th>Requester</th>
							<th>Category</th>
							<th>Amount</th>
							<th>Payment Type</th>
							<th>Status</th>
							<th>Due Date</th>
							<th>Date</th>
							<th>Actions</th>
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
												👤 {activeSection === 'approvals' ? (req.created_by_username || 'Unknown') : (req.approver_name || 'Not Assigned')}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.requester_name}</div>
											<div class="requester-id">ID: {req.requester_id}</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{req.expense_category_name_en}</div>
											<div class="category-ar">{req.expense_category_name_ar}</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.amount)}</td>
									<td class="payment-type">{req.payment_category.replace(/_/g, ' ')}</td>
									<td>
										<span class="status-badge {getStatusClass(req.status)}">
											{req.status.toUpperCase()}
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
										<span class="schedule-badge">📅 {req.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
										<div class="schedule-id">ID: {req.id}</div>
									</td>
									<td>{req.branch_name}</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {activeSection === 'approvals' ? (req.creator?.username || 'Unknown') : (req.approver?.username || 'Not Assigned')}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.co_user_name || '-'}</div>
											<div class="requester-id">C/O User</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>{req.expense_category_name_en}</div>
											<div class="category-ar">{req.expense_category_name_ar || ''}</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.amount)}</td>
									<td class="payment-type">{req.payment_method?.replace(/_/g, ' ') || 'N/A'}</td>
									<td>
										<span class="status-badge {
											req.approval_status === 'pending' ? 'status-pending' : 
											req.approval_status === 'approved' ? 'status-approved' : 
											req.approval_status === 'rejected' ? 'status-rejected' : 
											'status-pending'
										}">
											{(req.approval_status || 'pending').toUpperCase()}
										</span>
									</td>
									<td class="date due-date">{req.due_date ? formatDate(req.due_date) : '-'}</td>
									<td class="date">{formatDate(req.created_at)}</td>
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
								{:else if req.item_type === 'vendor_payment'}
									<!-- Vendor Payment Row -->
									<td class="req-number">
										<span class="schedule-badge vendor-payment">💰 VENDOR PAYMENT</span>
										<div class="schedule-id">Bill: {req.bill_number}</div>
									</td>
									<td>{req.branch_name}</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {req.requester?.username || 'Unknown User'}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.vendor_name}</div>
											<div class="requester-id">Vendor</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>Vendor Payment</div>
											<div class="category-ar">دفعة المورد</div>
										</div>
									</td>
									<td class="amount">{formatCurrency(req.final_bill_amount || req.bill_amount)}</td>
									<td class="payment-type">{req.payment_method?.replace(/_/g, ' ') || 'N/A'}</td>
									<td>
										<span class="status-badge status-pending">
											SENT FOR APPROVAL
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
											<span class="schedule-badge transfer">📦 STOCK TRANSFER</span>
										{:else if req.issue_type === 'gift'}
											<span class="schedule-badge gift">🎁 GIFT</span>
										{:else if req.issue_type === 'sales'}
											<span class="schedule-badge sales">💰 SALES</span>
										{:else}
											<span class="schedule-badge">🎟️ PURCHASE VOUCHER</span>
										{/if}
										<div class="schedule-id">Book: {req.purchase_voucher_id}</div>
										<div class="schedule-id">Serial: #{req.serial_number}</div>
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
												👤 {req.issued_by_user?.username || 'Unknown'}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">#{req.serial_number}</div>
											<div class="requester-id">Serial Number</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											{#if req.issue_type === 'stock transfer'}
												<div>Stock Transfer</div>
												<div class="category-ar">تحويل المخزون</div>
											{:else if req.issue_type === 'gift'}
												<div>Gift Voucher</div>
												<div class="category-ar">قسيمة هدية</div>
											{:else if req.issue_type === 'sales'}
												<div>Sales Voucher</div>
												<div class="category-ar">قسيمة مبيعات</div>
											{:else}
												<div>Purchase Voucher</div>
												<div class="category-ar">قسيمة الشراء</div>
											{/if}
										</div>
									</td>
									<td class="amount">{formatCurrency(req.value)}</td>
									<td class="payment-type">{req.status || 'Stocked'}</td>
									<td>
										<span class="status-badge {req.approval_status === 'pending' ? 'status-pending' : 'status-approved'}">
											{(req.approval_status || 'pending').toUpperCase()}
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
									<!-- Day Off Request Row -->
									<td class="req-number">
										<span class="schedule-badge day-off">📅 DAY OFF</span>
									</td>
									<td>-</td>
									<td>
										<div class="generated-by-info">
											<div class="generated-by-name">
												👤 {activeSection === 'approvals' ? (req.requester?.username || 'Unknown') : 'My Request'}
											</div>
										</div>
									</td>
									<td>
										<div class="requester-info">
											<div class="requester-name">{req.employee ? (req.employee.name_en || req.employee.name_ar || 'N/A') : 'N/A'}</div>
											<div class="requester-id">Employee</div>
										</div>
									</td>
									<td>
										<div class="category-info">
											<div>Day Off Request</div>
											<div class="category-ar">طلب إجازة يوم</div>
										</div>
									</td>
									<td class="amount">-</td>
									<td class="payment-type">{req.is_deductible_on_salary ? '💰 Deductible' : 'No Deduction'}</td>
									<td>
										<span class="status-badge status-{req.approval_status}">
											{(req.approval_status || 'pending').toUpperCase()}
										</span>
									</td>
									<td class="date due-date">{req.day_off_date ? formatDate(req.day_off_date) : '-'}</td>
									<td class="date">{formatDate(req.approval_requested_at)}</td>
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
				<h2>📄 Requisition Details</h2>
				<button class="modal-close" on:click={closeDetail}>×</button>
			</div>

			<div class="modal-body">
				{#if selectedRequisition.item_type === 'requisition'}
					<!-- Requisition Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>Requisition Number</label>
							<div class="detail-value">{selectedRequisition.requisition_number}</div>
						</div>

						<div class="detail-item">
							<label>Status</label>
							<span class="status-badge {getStatusClass(selectedRequisition.status)}">
								{selectedRequisition.status.toUpperCase()}
							</span>
						</div>

						<div class="detail-item">
							<label>Branch</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>Approver</label>
							<div class="detail-value">{selectedRequisition.approver_name || 'Not Assigned'}</div>
						</div>

						<div class="detail-item">
							<label>Category</label>
							<div class="detail-value">
								{selectedRequisition.expense_category_name_en}
								<br>
								<span class="category-ar">{selectedRequisition.expense_category_name_ar}</span>
							</div>
						</div>

						<div class="detail-item">
							<label>Requester</label>
							<div class="detail-value">
								{selectedRequisition.requester_name}
								<br>
								<small>ID: {selectedRequisition.requester_id}</small>
								<br>
								<small>Contact: {selectedRequisition.requester_contact}</small>
							</div>
						</div>

						<div class="detail-item">
							<label>Amount</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.amount)}</div>
						</div>

						<div class="detail-item">
							<label>VAT Applicable</label>
							<div class="detail-value">{selectedRequisition.vat_applicable ? 'Yes' : 'No'}</div>
						</div>

						<div class="detail-item">
							<label>Payment Category</label>
							<div class="detail-value">{selectedRequisition.payment_category.replace(/_/g, ' ')}</div>
						</div>

						{#if selectedRequisition.credit_period}
							<div class="detail-item">
								<label>Credit Period</label>
								<div class="detail-value">{selectedRequisition.credit_period} days</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>Bank Name</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>IBAN</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<label>Description</label>
								<div class="detail-value description">{selectedRequisition.description}</div>
							</div>
						{/if}

						{#if selectedRequisition.image_url}
							<div class="detail-item full-width">
								<label>Attachment</label>
								<div class="detail-value">
									<img src={selectedRequisition.image_url} alt="Requisition" class="attachment-image" />
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Created Date</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'payment_schedule'}
					<!-- Payment Schedule Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>Schedule Type</label>
							<div class="detail-value">
								<span class="schedule-badge">{selectedRequisition.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
							</div>
						</div>

						<div class="detail-item">
							<label>Status</label>
							<span class="status-badge {
								selectedRequisition.approval_status === 'pending' ? 'status-pending' : 
								selectedRequisition.approval_status === 'approved' ? 'status-approved' : 
								selectedRequisition.approval_status === 'rejected' ? 'status-rejected' : 
								'status-pending'
							}">
								{(selectedRequisition.approval_status || 'pending').toUpperCase()}
							</span>
						</div>

						<div class="detail-item">
							<label>Branch</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>Category</label>
							<div class="detail-value">
								{selectedRequisition.expense_category_name_en}
								{#if selectedRequisition.expense_category_name_ar}
									<br>
									<span class="category-ar">{selectedRequisition.expense_category_name_ar}</span>
								{/if}
							</div>
						</div>

						{#if selectedRequisition.co_user_name}
							<div class="detail-item">
								<label>C/O User</label>
								<div class="detail-value">{selectedRequisition.co_user_name}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Approver</label>
							<div class="detail-value">{selectedRequisition.approver_name}</div>
						</div>

						<div class="detail-item">
							<label>Created By</label>
							<div class="detail-value">{selectedRequisition.creator?.username || 'Unknown'}</div>
						</div>

						<div class="detail-item">
							<label>Amount</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.amount)}</div>
						</div>

						<div class="detail-item">
							<label>Payment Method</label>
							<div class="detail-value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || 'N/A'}</div>
						</div>

						{#if selectedRequisition.bill_type}
							<div class="detail-item">
								<label>Bill Type</label>
								<div class="detail-value">{selectedRequisition.bill_type.replace(/_/g, ' ')}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_number}
							<div class="detail-item">
								<label>Bill Number</label>
								<div class="detail-value">{selectedRequisition.bill_number}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<label>Bill Date</label>
								<div class="detail-value">{formatDate(selectedRequisition.bill_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<label>Due Date</label>
								<div class="detail-value">{formatDate(selectedRequisition.due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.credit_period}
							<div class="detail-item">
								<label>Credit Period</label>
								<div class="detail-value">{selectedRequisition.credit_period} days</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>Bank Name</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>IBAN</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<label>Description</label>
								<div class="detail-value description">{selectedRequisition.description}</div>
							</div>
						{/if}

						{#if selectedRequisition.bill_file_url}
							<div class="detail-item full-width">
								<label>Bill Attachment</label>
								<div class="detail-value">
									<a href={selectedRequisition.bill_file_url} target="_blank" class="btn-view-file">
										📄 View Bill File
									</a>
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Created Date</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>

						<div class="detail-item">
							<label>Created By</label>
							<div class="detail-value">{selectedRequisition.creator?.username || 'Unknown'}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'vendor_payment'}
					<!-- Vendor Payment Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>Payment Type</label>
							<div class="detail-value">
								<span class="schedule-badge vendor-payment">💰 VENDOR PAYMENT</span>
							</div>
						</div>

						<div class="detail-item">
							<label>Status</label>
							<span class="status-badge status-pending">
								SENT FOR APPROVAL
							</span>
						</div>

						<div class="detail-item">
							<label>Bill Number</label>
							<div class="detail-value">{selectedRequisition.bill_number}</div>
						</div>

						<div class="detail-item">
							<label>Vendor Name</label>
							<div class="detail-value">{selectedRequisition.vendor_name}</div>
						</div>

						<div class="detail-item">
							<label>Branch</label>
							<div class="detail-value">{selectedRequisition.branch_name}</div>
						</div>

						<div class="detail-item">
							<label>Bill Amount</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.bill_amount)}</div>
						</div>

						{#if selectedRequisition.final_bill_amount && selectedRequisition.final_bill_amount !== selectedRequisition.bill_amount}
							<div class="detail-item">
								<label>Final Bill Amount</label>
								<div class="detail-value amount-large">{formatCurrency(selectedRequisition.final_bill_amount)}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Payment Method</label>
							<div class="detail-value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || 'N/A'}</div>
						</div>

						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<label>Bill Date</label>
								<div class="detail-value">{formatDate(selectedRequisition.bill_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<label>Due Date</label>
								<div class="detail-value">{formatDate(selectedRequisition.due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.original_due_date && selectedRequisition.original_due_date !== selectedRequisition.due_date}
							<div class="detail-item">
								<label>Original Due Date</label>
								<div class="detail-value">{formatDate(selectedRequisition.original_due_date)}</div>
							</div>
						{/if}

						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<label>Bank Name</label>
								<div class="detail-value">{selectedRequisition.bank_name}</div>
							</div>
						{/if}

						{#if selectedRequisition.iban}
							<div class="detail-item">
								<label>IBAN</label>
								<div class="detail-value">{selectedRequisition.iban}</div>
							</div>
						{/if}

						{#if selectedRequisition.priority}
							<div class="detail-item">
								<label>Priority</label>
								<div class="detail-value">{selectedRequisition.priority}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Requested Date</label>
							<div class="detail-value">{formatDate(selectedRequisition.approval_requested_at)}</div>
						</div>

						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<label>Notes</label>
								<div class="detail-value description">{selectedRequisition.approval_notes}</div>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'purchase_voucher'}
					<!-- Purchase Voucher Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>Request Type</label>
							<div class="detail-value">
								{#if selectedRequisition.issue_type === 'stock transfer'}
									<span class="schedule-badge transfer">📦 STOCK TRANSFER</span>
								{:else if selectedRequisition.issue_type === 'gift'}
									<span class="schedule-badge gift">🎁 GIFT</span>
								{:else if selectedRequisition.issue_type === 'sales'}
									<span class="schedule-badge sales">💰 SALES</span>
								{:else}
									<span class="schedule-badge purchase-voucher">🧾 PURCHASE VOUCHER</span>
								{/if}
							</div>
						</div>

						<div class="detail-item">
							<label>Voucher Book ID</label>
							<div class="detail-value">{selectedRequisition.purchase_voucher_id || 'N/A'}</div>
						</div>

						<div class="detail-item">
							<label>Serial Number</label>
							<div class="detail-value amount-large">#{selectedRequisition.serial_number || 'N/A'}</div>
						</div>

						<div class="detail-item">
							<label>Approval Status</label>
							<span class="status-badge {
								selectedRequisition.approval_status === 'pending' ? 'status-pending' : 
								selectedRequisition.approval_status === 'approved' ? 'status-approved' : 
								selectedRequisition.approval_status === 'rejected' ? 'status-rejected' : 
								'status-pending'
							}">
								{(selectedRequisition.approval_status || 'pending').toUpperCase()}
							</span>
						</div>

						<div class="detail-item">
							<label>Voucher Value</label>
							<div class="detail-value amount-large">{formatCurrency(selectedRequisition.value || 0)}</div>
						</div>

						<div class="detail-item">
							<label>Current Stock</label>
							<div class="detail-value">{selectedRequisition.stock ?? 'N/A'}</div>
						</div>

						<div class="detail-item">
							<label>Current Location</label>
							<div class="detail-value">{selectedRequisition.stock_location_branch?.name_en || 'N/A'}</div>
						</div>

						{#if selectedRequisition.issue_type === 'stock transfer'}
							<div class="detail-item">
								<label>🔄 Transfer To Location</label>
								<div class="detail-value" style="color: #3182ce; font-weight: 600;">
									{selectedRequisition.pending_location_branch?.name_en || 'N/A'}
								</div>
							</div>

							<div class="detail-item">
								<label>🔄 Transfer To Person</label>
								<div class="detail-value" style="color: #3182ce; font-weight: 600;">
									{selectedRequisition.pending_person_user?.username || 'N/A'}
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Requested By</label>
							<div class="detail-value">{selectedRequisition.issued_by_user?.username || 'Unknown'}</div>
						</div>

						<div class="detail-item">
							<label>Request Date</label>
							<div class="detail-value">{selectedRequisition.issued_date ? formatDate(selectedRequisition.issued_date) : 'N/A'}</div>
						</div>

						{#if selectedRequisition.remarks}
							<div class="detail-item full-width">
								<label>Remarks</label>
								<div class="detail-value description">{selectedRequisition.remarks}</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Created Date</label>
							<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
						</div>
					</div>
				{:else if selectedRequisition.item_type === 'day_off'}
					<!-- Day Off Request Details -->
					<div class="detail-grid">
						<div class="detail-item">
							<label>Request Status</label>
							<span class="status-badge status-{selectedRequisition.approval_status}">
								{selectedRequisition.approval_status?.toUpperCase() || 'PENDING'}
							</span>
						</div>

						<div class="detail-item">
							<label>Employee</label>
							<div class="detail-value">
								👤 {selectedRequisition.employee ? (selectedRequisition.employee.name_en || selectedRequisition.employee.name_ar || 'N/A') : 'N/A'}
							</div>
						</div>

						<div class="detail-item">
							<label>Requested By</label>
							<div class="detail-value">
								👤 {selectedRequisition.requester?.username || 'Unknown User'}
							</div>
						</div>

						<div class="detail-item">
							<label>Day Off Date</label>
							<div class="detail-value">{selectedRequisition.day_off_date ? formatDate(selectedRequisition.day_off_date) : '-'}</div>
						</div>

						<div class="detail-item">
							<label>Reason</label>
							<div class="detail-value">
								{selectedRequisition.reason ? (selectedRequisition.reason[$locale === 'en' ? 'reason_en' : 'reason_ar'] || 'N/A') : 'No reason'}
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

						<div class="detail-item">
							<label>Deductible on Salary</label>
							<div class="detail-value">{selectedRequisition.is_deductible_on_salary ? '💰 Yes' : 'No'}</div>
						</div>

						{#if selectedRequisition.document_url}
							<div class="detail-item full-width">
								<label>📎 Document Attached</label>
								<div class="detail-value">
									<button 
										class="btn-view-doc"
										on:click={() => window.open(selectedRequisition.document_url, '_blank')}
										title="Click to view document">
										📄 View Document
									</button>
									<br>
									<small>Uploaded: {selectedRequisition.document_uploaded_at ? formatDate(selectedRequisition.document_uploaded_at) : 'N/A'}</small>
								</div>
							</div>
						{/if}

						<div class="detail-item">
							<label>Requested On</label>
							<div class="detail-value">{formatDate(selectedRequisition.approval_requested_at)}</div>
						</div>

						{#if selectedRequisition.approval_approved_at}
							<div class="detail-item">
								<label>Approved On</label>
								<div class="detail-value">{formatDate(selectedRequisition.approval_approved_at)}</div>
							</div>

							<div class="detail-item">
								<label>Approved By</label>
								<div class="detail-value">👤 {selectedRequisition.approval_approved_by || 'System'}</div>
							</div>
						{/if}

						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<label>Approval Notes</label>
								<div class="detail-value description">{selectedRequisition.approval_notes}</div>
							</div>
						{/if}

						{#if selectedRequisition.rejection_reason}
							<div class="detail-item full-width">
								<label style="color: #dc2626;">Rejection Reason</label>
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
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : selectedRequisition.item_type === 'purchase_voucher' ? 'purchase voucher' : selectedRequisition.item_type === 'day_off' ? 'day off request' : 'requisition'}
					{#if !canApproveThis}
						<div class="permission-notice">
							ℹ️ You do not have permission to approve or reject this {itemTypeName}.
							<br><small>{selectedRequisition.item_type === 'payment_schedule' ? 'This schedule is assigned to a different approver.' : 'Please contact your administrator for approval permissions.'}</small>
						</div>
					{/if}
					<button
						class="btn-approve"
						on:click={() => showApprovalConfirm(selectedRequisition.id)}
						disabled={isProcessing || !canApproveThis}
						title={!canApproveThis ? 'You need approval permissions to approve this item' : 'Approve this item'}
					>
						{isProcessing ? '⏳ Processing...' : '✅ Approve'}
					</button>
					<button
						class="btn-reject"
						on:click={() => showRejectionConfirm(selectedRequisition.id)}
						disabled={isProcessing || !canApproveThis}
						title={!canApproveThis ? 'You need approval permissions to reject this item' : 'Reject this item'}
					>
						{isProcessing ? '⏳ Processing...' : '❌ Reject'}
					</button>
				{:else}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : selectedRequisition.item_type === 'purchase_voucher' ? 'purchase voucher' : 'requisition'}
					<div class="status-info">
						This {itemTypeName} has been {selectedRequisition.status || selectedRequisition.approval_status}
					</div>
				{/if}
				<button class="btn-close" on:click={closeDetail}>Close</button>
			</div>
		</div>
	</div>
{/if}

<!-- Confirmation Modal -->
{#if showConfirmModal}
<div class="confirm-overlay" on:click={cancelConfirm}>
	<div class="confirm-modal" on:click|stopPropagation>
		<h3 class="confirm-title">
			{confirmAction === 'approve' ? '✅ Confirm Approval' : '❌ Confirm Rejection'}
		</h3>
		
		<p class="confirm-message">
			{#if confirmAction === 'approve'}
				Are you sure you want to approve this {selectedRequisition?.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition?.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}?
			{:else}
				Are you sure you want to reject this {selectedRequisition?.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition?.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}?
			{/if}
		</p>
		
		{#if confirmAction === 'reject'}
			<div class="form-group">
				<label for="rejection-reason" class="form-label">Reason for Rejection *</label>
				<textarea
					id="rejection-reason"
					bind:value={rejectionReason}
					placeholder="Please provide a detailed reason for rejection..."
					rows="4"
					class="rejection-textarea"
				></textarea>
			</div>
		{/if}
		
		<div class="confirm-actions">
			<button class="btn-confirm-cancel" on:click={cancelConfirm}>
				Cancel
			</button>
			<button 
				class="btn-confirm-ok" 
				class:approve={confirmAction === 'approve'}
				class:reject={confirmAction === 'reject'}
				on:click={confirmActionHandler}
				disabled={confirmAction === 'reject' && !rejectionReason.trim()}
			>
				{confirmAction === 'approve' ? 'Approve' : 'Reject'}
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

	.header {
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
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
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		display: flex;
		align-items: center;
		gap: 1rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.stat-card.clickable {
		cursor: pointer;
		user-select: none;
	}

	.stat-card.clickable:hover {
		transform: translateY(-4px);
		box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-card.clickable:active {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-icon {
		font-size: 2.5rem;
		min-width: 60px;
		text-align: center;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 2rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.stat-label {
		color: #64748b;
		font-size: 0.875rem;
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
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-view:hover {
		background: #2563eb;
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
		font-weight: 600;
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
		transform: scale(1.05);
	}

	.btn-reject-inline {
		background: #ef4444;
		color: white;
	}

	.btn-reject-inline:hover:not(:disabled) {
		background: #dc2626;
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
		padding: 0.75rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-approve:hover:not(:disabled) {
		background: #059669;
	}

	.btn-reject {
		padding: 0.75rem 1.5rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-reject:hover:not(:disabled) {
		background: #dc2626;
	}

	.btn-close {
		padding: 0.75rem 1.5rem;
		background: #64748b;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-close:hover {
		background: #475569;
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
</style>
