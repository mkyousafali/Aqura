<script>
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { goto } from '$app/navigation';
	import { getTranslation } from '$lib/i18n';
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
				notifications.add({ type: 'error', message: 'Please login to access the approval center' });
				goto('/mobile-interface/login');
				return;
			}

	// Get current user's approval permissions from approval_permissions table
	const { supabase } = await import('$lib/utils/supabase');
	const { data: approvalPerms, error: permsError } = await supabase
		.from('approval_permissions')
		.select('*')
		.eq('user_id', $currentUser.id)
		.eq('is_active', true)
		.maybeSingle(); // Use maybeSingle to handle cases where user has no approval permissions

	if (permsError) {
		console.error('Error checking user permissions:', permsError);
	}		// User can approve if ANY permission is enabled
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

		// Import supabaseAdmin for admin queries
		const { supabaseAdmin } = await import('$lib/utils/supabase');
		
		// Calculate date for filtering
		const twoDaysFromNow = new Date();
		twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
		const twoDaysDate = twoDaysFromNow.toISOString().split('T')[0];
		
		console.log('🔍 Loading pending items first for faster mobile display...');
		
		// Load only pending items first for faster initial display
		const [
			requisitionsResult,
			schedulesResult,
			vendorPaymentsResult,
			myRequisitionsResult,
			mySchedulesResult
		] = await Promise.all([
			// 1. Requisitions where current user is approver (pending only)
			supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.eq('approver_id', $currentUser.id)
				.eq('status', 'pending')
				.order('created_at', { ascending: false })
				.limit(200),
			
			// 2. Payment schedules requiring approval (pending only)
			supabaseAdmin
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
				supabaseAdmin
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
			
			// 4. My created requisitions (pending only)
			supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.eq('created_by', $currentUser.id)
				.eq('status', 'pending')
				.order('created_at', { ascending: false })
				.limit(200),
			
			// 5. My created payment schedules (pending only)
			supabaseAdmin
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
				.order('created_at', { ascending: false })
				.limit(200)
		]);
		
		// Process requisitions result
		const { data: requisitionsData, error: requisitionsError } = requisitionsResult;
		if (requisitionsError) {
			console.error('❌ Error loading requisitions:', requisitionsError);
			throw requisitionsError;
		}
		
		requisitions = requisitionsData || [];
		
		// Fetch usernames for requisitions if needed
		if (requisitions.length > 0) {
			const userIds = [...new Set(requisitions.map(r => r.created_by).filter(Boolean))];
			
			if (userIds.length > 0) {
				const { data: usersData } = await supabaseAdmin
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
		
		// Initialize empty arrays for historical data (will load on demand)
		myApprovedSchedules = [];
		approvedPaymentSchedules = [];
		rejectedPaymentSchedules = [];

		// Calculate stats (only pending for now, historical data will be loaded on demand)
		stats.pending = requisitions.length + paymentSchedules.length + vendorPayments.length;
		stats.approved = 0; // Will be loaded when user switches to approved tab
		stats.rejected = 0; // Will be loaded when user switches to rejected tab
		stats.total = stats.pending;

		// Stats for my created requests (only pending initially)
		myStats.pending = myCreatedRequisitions.length + myCreatedSchedules.length;
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
		notifications.add({ type: 'error', message: 'Error loading requisitions: ' + err.message });
	} finally {
		loading = false;
	}
}

// Load historical (approved/rejected) data in background
async function loadHistoricalData() {
	if (historicalDataLoaded || !$currentUser?.id) return;
	
	try {
		console.log('📚 Loading historical data in background...');
		
		const { supabaseAdmin } = await import('$lib/utils/supabase');
		
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
		supabaseAdmin
			.from('expense_requisitions')
			.select('*')
			.eq('approver_id', $currentUser.id)
			.eq('status', 'approved')
			.order('created_at', { ascending: false })
			.limit(1000),		// Rejected requisitions where I'm approver
		supabaseAdmin
			.from('expense_requisitions')
			.select('*')
			.eq('approver_id', $currentUser.id)
			.eq('status', 'rejected')
			.order('created_at', { ascending: false })
			.limit(1000),		// My approved/rejected schedules from expense_scheduler
		supabaseAdmin
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
		supabaseAdmin
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
		supabaseAdmin
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
		supabaseAdmin
			.from('expense_requisitions')
			.select('*')
			.eq('created_by', $currentUser.id)
			.eq('status', 'approved')
			.order('created_at', { ascending: false })
			.limit(1000),
		
		// My rejected requisitions
		supabaseAdmin
			.from('expense_requisitions')
			.select('*')
			.eq('created_by', $currentUser.id)
			.eq('status', 'rejected')
			.order('created_at', { ascending: false })
			.limit(1000),
		
		// My rejected schedules
		supabaseAdmin
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

	function filterRequisitions() {
		if (activeSection === 'approvals') {
			// Filter approvals assigned to me
			let filtered = requisitions;
			let filteredSchedules = [];

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

			// Combine filtered requisitions, payment schedules, and vendor payments
			filteredRequisitions = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					approval_status: s.approval_status || 'approved'
				})),
				...(selectedStatus === 'pending' || selectedStatus === 'all' 
					? vendorPayments.map(v => ({ ...v, item_type: 'vendor_payment' }))
					: [])
			];
		} else {
			// Filter my created requests
			let filtered = myCreatedRequisitions;
			let filteredSchedules = [];

			// Filter by status
			if (selectedStatus === 'all') {
				// Show all requisitions
				filtered = myCreatedRequisitions;
				// Combine all schedules: pending + rejected (from myCreatedSchedules) + approved (from myApprovedSchedules)
				filteredSchedules = [...myCreatedSchedules, ...myApprovedSchedules];
			} else {
				// Filter requisitions by status
				filtered = myCreatedRequisitions.filter(r => r.status === selectedStatus);
				
				// Filter schedules by status
				if (selectedStatus === 'pending') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'pending');
				} else if (selectedStatus === 'approved') {
					filteredSchedules = myApprovedSchedules;
				} else if (selectedStatus === 'rejected') {
					filteredSchedules = myCreatedSchedules.filter(s => s.approval_status === 'rejected');
				}
			}

			// Combine filtered requests
			filteredMyRequests = [
				...filtered.map(r => ({ ...r, item_type: 'requisition' })),
				...filteredSchedules.map(s => ({ 
					...s, 
					item_type: 'payment_schedule',
					approval_status: s.approval_status || 'approved'
				}))
			];
		}
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
				notifications.add({ type: 'error', message: 'Please provide a reason for rejection' });
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
			const { supabaseAdmin } = await import('$lib/utils/supabase');

			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the full payment schedule data
				const { data: scheduleData, error: fetchError } = await supabaseAdmin
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Move to expense_scheduler
				const { error: insertError } = await supabaseAdmin
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
				const { error: deleteError } = await supabaseAdmin
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

				notifications.add({ type: 'success', message: 'Payment schedule approved and moved to expense scheduler!' });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Approve vendor payment
				const { data: paymentData, error: fetchError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabaseAdmin
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

				notifications.add({ type: 'success', message: 'Vendor payment approved successfully!' });
			} else {
				// Update regular requisition
				const { error } = await supabaseAdmin
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
					co_user_name: null,
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
					created_by: selectedRequisition.created_by
				};

				const { error: schedulerError } = await supabaseAdmin
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

		notifications.add({ type: 'success', message: 'Requisition approved successfully!' });
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
	console.error('Error approving:', err);
	notifications.add({ type: 'error', message: 'Error approving: ' + err.message });
} finally {
	isProcessing = false;
}
}

async function rejectRequisition(reason) {
	if (!selectedRequisition || isProcessing) return;

	try {
		isProcessing = true;
		const { supabaseAdmin } = await import('$lib/utils/supabase');			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Update payment schedule
				const { error } = await supabaseAdmin
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

				notifications.add({ type: 'success', message: 'Payment schedule rejected.' });
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Reject vendor payment
				const { data: paymentData, error: fetchError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', selectedRequisition.id)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabaseAdmin
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

				notifications.add({ type: 'success', message: 'Vendor payment rejected.' });
			} else {
				// Update regular requisition
				const { error } = await supabaseAdmin
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

				notifications.add({ type: 'success', message: 'Requisition rejected.' });
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
			notifications.add({ type: 'error', message: 'Error rejecting: ' + err.message });
		} finally {
			isProcessing = false;
		}
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatAmount(amount) {
		if (!amount) return '0.00';
		return parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}
</script>

<div class="mobile-approval-center">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading requisitions...</p>
		</div>
	{:else}
		<!-- Section Tabs -->
		<div class="section-tabs">
			<button 
				class="tab-button {activeSection === 'approvals' ? 'active' : ''}"
				on:click={() => { activeSection = 'approvals'; filterRequisitions(); }}
			>
				📋 Approvals for Me
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
				<p>No approvals assigned to you</p>
			</div>
		{:else if activeSection === 'my_requests' && filteredMyRequests.length === 0}
			<div class="empty-state">
				<div class="empty-icon">📋</div>
				<p>You haven't created any requests yet</p>
			</div>
			{:else}
				{#each (activeSection === 'approvals' ? filteredRequisitions : filteredMyRequests) as req}
					<div class="req-card" on:click={() => openDetail(req)}>
						{#if req.item_type === 'requisition'}
							<!-- Expense Requisition Card -->
							<div class="req-header">
								<div class="req-number">{req.requisition_number}</div>
								<div class="status-badge status-{req.status}">{req.status}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">Branch:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{activeSection === 'approvals' ? 'Generated by:' : 'Approver:'}</span>
									<span class="value">👤 {activeSection === 'approvals' ? req.created_by_username : (req.approver_name || 'Not Assigned')}</span>
								</div>
								<div class="info-row">
									<span class="label">Amount:</span>
									<span class="value amount">SAR {formatAmount(req.amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">Due Date:</span>
									<span class="value">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">Date:</span>
									<span class="value">{formatDate(req.created_at)}</span>
								</div>
							</div>
						{:else if req.item_type === 'payment_schedule'}
							<!-- Payment Schedule Card -->
							<div class="req-header">
								<div class="req-number">
									<span class="schedule-badge">📅 {req.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
								</div>
								<div class="status-badge status-{req.approval_status || 'pending'}">{(req.approval_status || 'pending').toUpperCase()}</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">Branch:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">{activeSection === 'approvals' ? 'Generated by:' : 'Approver:'}</span>
									<span class="value">👤 {activeSection === 'approvals' ? (req.creator?.username || 'Unknown') : (req.approver?.username || 'Not Assigned')}</span>
								</div>
								<div class="info-row">
									<span class="label">Category:</span>
									<span class="value">{req.expense_category_name_en}</span>
								</div>
								<div class="info-row">
									<span class="label">C/O User:</span>
									<span class="value">👤 {req.co_user_name || 'System'}</span>
								</div>
								<div class="info-row">
									<span class="label">Amount:</span>
									<span class="value amount">SAR {formatAmount(req.amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">Due Date:</span>
									<span class="value due-date">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">Date:</span>
									<span class="value">{formatDate(req.created_at)}</span>
								</div>
							</div>
						{:else if req.item_type === 'vendor_payment'}
							<!-- Vendor Payment Card -->
							<div class="req-header">
								<div class="req-number">
									<span class="schedule-badge vendor-payment">💰 VENDOR PAYMENT</span>
									<div class="bill-number">Bill: {req.bill_number}</div>
								</div>
								<div class="status-badge status-pending">SENT FOR APPROVAL</div>
							</div>
							<div class="req-info">
								<div class="info-row">
									<span class="label">Vendor:</span>
									<span class="value">{req.vendor_name}</span>
								</div>
								<div class="info-row">
									<span class="label">Branch:</span>
									<span class="value">{req.branch_name}</span>
								</div>
								<div class="info-row">
									<span class="label">Requested by:</span>
									<span class="value">👤 {req.requester?.username || 'Unknown User'}</span>
								</div>
								<div class="info-row">
									<span class="label">Amount:</span>
									<span class="value amount">SAR {formatAmount(req.final_bill_amount || req.bill_amount)}</span>
								</div>
								<div class="info-row">
									<span class="label">Payment Method:</span>
									<span class="value">{req.payment_method?.replace(/_/g, ' ') || 'N/A'}</span>
								</div>
								<div class="info-row">
									<span class="label">Due Date:</span>
									<span class="value due-date">{req.due_date ? formatDate(req.due_date) : '-'}</span>
								</div>
								<div class="info-row">
									<span class="label">Requested:</span>
									<span class="value">{formatDate(req.approval_requested_at)}</span>
								</div>
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
				<h2>Requisition Details</h2>
				<button class="close-btn" on:click={closeDetail}>✕</button>
			</div>

			<div class="modal-body">
				{#if selectedRequisition.item_type === 'requisition'}
					<!-- Requisition Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">Requisition #:</span>
							<span class="value">{selectedRequisition.requisition_number}</span>
						</div>
						<div class="detail-item">
							<span class="label">Branch:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Generated by:</span>
							<span class="value">{selectedRequisition.created_by_username}</span>
						</div>
						<div class="detail-item">
							<span class="label">Requester:</span>
							<span class="value">{selectedRequisition.requester_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Category:</span>
							<span class="value">{selectedRequisition.expense_category_name_en}</span>
						</div>
						<div class="detail-item">
							<span class="label">Amount:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.amount)}</span>
						</div>
						<div class="detail-item">
							<span class="label">Payment Type:</span>
							<span class="value">{selectedRequisition.payment_type}</span>
						</div>
						<div class="detail-item">
							<span class="label">Status:</span>
							<span class="status-badge status-{selectedRequisition.status}">{selectedRequisition.status}</span>
						</div>
						<div class="detail-item">
							<span class="label">Date:</span>
							<span class="value">{formatDate(selectedRequisition.created_at)}</span>
						</div>
						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<span class="label">Description:</span>
								<span class="value">{selectedRequisition.description}</span>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'payment_schedule'}
					<!-- Payment Schedule Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">Schedule Type:</span>
							<span class="value">
								<span class="schedule-badge">📅 {selectedRequisition.schedule_type.replace(/_/g, ' ').toUpperCase()}</span>
							</span>
						</div>
						<div class="detail-item">
							<span class="label">Branch:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Category:</span>
							<span class="value">{selectedRequisition.expense_category_name_en}</span>
						</div>
						{#if selectedRequisition.co_user_name}
							<div class="detail-item">
								<span class="label">C/O User:</span>
								<span class="value">👤 {selectedRequisition.co_user_name}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">Approver:</span>
							<span class="value">{selectedRequisition.approver_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Created By:</span>
							<span class="value">{selectedRequisition.creator?.username || 'Unknown'}</span>
						</div>
						<div class="detail-item">
							<span class="label">Amount:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.amount)}</span>
						</div>
						<div class="detail-item">
							<span class="label">Payment Method:</span>
							<span class="value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || 'N/A'}</span>
						</div>
						{#if selectedRequisition.bill_type}
							<div class="detail-item">
								<span class="label">Bill Type:</span>
								<span class="value">{selectedRequisition.bill_type.replace(/_/g, ' ')}</span>
							</div>
						{/if}
						{#if selectedRequisition.bill_number}
							<div class="detail-item">
								<span class="label">Bill Number:</span>
								<span class="value">{selectedRequisition.bill_number}</span>
							</div>
						{/if}
						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<span class="label">Due Date:</span>
								<span class="value">{formatDate(selectedRequisition.due_date)}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">Status:</span>
							<span class="status-badge status-{selectedRequisition.approval_status || 'pending'}">
								{(selectedRequisition.approval_status || 'pending').toUpperCase()}
							</span>
						</div>
						<div class="detail-item">
							<span class="label">Date:</span>
							<span class="value">{formatDate(selectedRequisition.created_at)}</span>
						</div>
						{#if selectedRequisition.description}
							<div class="detail-item full-width">
								<span class="label">Description:</span>
								<span class="value">{selectedRequisition.description}</span>
							</div>
						{/if}
					</div>
				{:else if selectedRequisition.item_type === 'vendor_payment'}
					<!-- Vendor Payment Details -->
					<div class="detail-section">
						<div class="detail-item">
							<span class="label">Payment Type:</span>
							<span class="schedule-badge vendor-payment">💰 VENDOR PAYMENT</span>
						</div>
						<div class="detail-item">
							<span class="label">Bill Number:</span>
							<span class="value">{selectedRequisition.bill_number}</span>
						</div>
						<div class="detail-item">
							<span class="label">Vendor Name:</span>
							<span class="value">{selectedRequisition.vendor_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Branch:</span>
							<span class="value">{selectedRequisition.branch_name}</span>
						</div>
						<div class="detail-item">
							<span class="label">Requested by:</span>
							<span class="value">👤 {selectedRequisition.requester?.username || 'Unknown User'}</span>
						</div>
						<div class="detail-item">
							<span class="label">Bill Amount:</span>
							<span class="value amount-large">SAR {formatAmount(selectedRequisition.bill_amount)}</span>
						</div>
						{#if selectedRequisition.final_bill_amount && selectedRequisition.final_bill_amount !== selectedRequisition.bill_amount}
							<div class="detail-item">
								<span class="label">Final Amount:</span>
								<span class="value amount-large">SAR {formatAmount(selectedRequisition.final_bill_amount)}</span>
							</div>
						{/if}
						<div class="detail-item">
							<span class="label">Payment Method:</span>
							<span class="value">{selectedRequisition.payment_method?.replace(/_/g, ' ') || 'N/A'}</span>
						</div>
						{#if selectedRequisition.bill_date}
							<div class="detail-item">
								<span class="label">Bill Date:</span>
								<span class="value">{formatDate(selectedRequisition.bill_date)}</span>
							</div>
						{/if}
						{#if selectedRequisition.due_date}
							<div class="detail-item">
								<span class="label">Due Date:</span>
								<span class="value">{formatDate(selectedRequisition.due_date)}</span>
							</div>
						{/if}
						{#if selectedRequisition.bank_name}
							<div class="detail-item">
								<span class="label">Bank Name:</span>
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
							<span class="label">Status:</span>
							<span class="status-badge status-pending">SENT FOR APPROVAL</span>
						</div>
						<div class="detail-item">
							<span class="label">Requested Date:</span>
							<span class="value">{formatDate(selectedRequisition.approval_requested_at)}</span>
						</div>
						{#if selectedRequisition.approval_notes}
							<div class="detail-item full-width">
								<span class="label">Notes:</span>
								<span class="value">{selectedRequisition.approval_notes}</span>
							</div>
						{/if}
					</div>
				{/if}

				{#if (selectedRequisition.item_type === 'requisition' && selectedRequisition.status === 'pending') || (selectedRequisition.item_type === 'payment_schedule' && (selectedRequisition.approval_status === 'pending' || !selectedRequisition.approval_status)) || (selectedRequisition.item_type === 'vendor_payment' && selectedRequisition.approval_status === 'sent_for_approval')}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}
					{#if !canApproveSelected}
						<div class="permission-notice">
							ℹ️ You do not have permission to approve or reject this {itemTypeName}.
							<br><small>{selectedRequisition.item_type === 'payment_schedule' ? 'Only the assigned approver can approve this payment.' : 'Please contact your administrator for approval permissions.'}</small>
						</div>
					{/if}
					<div class="action-buttons">
						<button 
							class="btn-approve" 
							on:click={() => openConfirmModal('approve')} 
							disabled={isProcessing || !canApproveSelected}
							title={!canApproveSelected ? 'You need approval permissions' : 'Approve this ' + itemTypeName}
						>
							✅ Approve
						</button>
						<button 
							class="btn-reject" 
							on:click={() => openConfirmModal('reject')} 
							disabled={isProcessing || !canApproveSelected}
							title={!canApproveSelected ? 'You need approval permissions' : 'Reject this ' + itemTypeName}
						>
							❌ Reject
						</button>
					</div>
				{:else}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}
					<div class="status-info">
						This {itemTypeName} has been {selectedRequisition.status || selectedRequisition.approval_status}
					</div>
				{/if}
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
	.mobile-approval-center {
		padding: 1rem;
		padding-bottom: 5rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
		color: #6B7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Section Tabs */
	.section-tabs {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
		background: #F3F4F6;
		padding: 0.25rem;
		border-radius: 12px;
	}

	.tab-button {
		flex: 1;
		padding: 0.75rem 1rem;
		border: none;
		background: transparent;
		border-radius: 10px;
		font-size: 0.875rem;
		font-weight: 600;
		color: #6B7280;
		cursor: pointer;
		transition: all 0.2s;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.tab-button.active {
		background: white;
		color: #3B82F6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.tab-button .badge {
		background: #EF4444;
		color: white;
		font-size: 0.625rem;
		padding: 0.125rem 0.375rem;
		border-radius: 10px;
		font-weight: 700;
		min-width: 18px;
		text-align: center;
	}

	.tab-button.active .badge {
		background: #3B82F6;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		text-align: center;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		transition: all 0.2s;
	}

	.stat-card:active {
		transform: scale(0.98);
	}

	.stat-value {
		font-size: 2rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.stat-label {
		font-size: 0.75rem;
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
		gap: 1rem;
	}

	.req-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		transition: all 0.2s;
	}

	.req-card:active {
		transform: scale(0.98);
	}

	.req-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.75rem;
		padding-bottom: 0.75rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.req-number {
		font-weight: 700;
		color: #1F2937;
		font-size: 0.875rem;
	}

	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.schedule-badge {
		display: inline-block;
		padding: 0.35rem 0.75rem;
		background: #ede9fe;
		color: #5b21b6;
		border-radius: 8px;
		font-size: 0.65rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.schedule-badge.vendor-payment {
		background: #dcfce7;
		color: #166534;
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
		gap: 0.5rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		font-size: 0.875rem;
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
		padding: 3rem 1rem;
		color: #9CA3AF;
	}

	.empty-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
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
		border-radius: 20px 20px 0 0;
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
		padding: 1.25rem;
		border-bottom: 1px solid #F3F4F6;
		position: sticky;
		top: 0;
		background: white;
		z-index: 10;
	}

	.modal-header h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
	}

	.close-btn {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		border: none;
		background: #F3F4F6;
		color: #6B7280;
		font-size: 1.25rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-body {
		padding: 1.25rem;
	}

	.detail-section {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.detail-item {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 8px;
	}

	.detail-item.full-width {
		flex-direction: column;
		gap: 0.5rem;
	}

	.detail-item .label {
		color: #6B7280;
		font-weight: 500;
		font-size: 0.875rem;
	}

	.detail-item .value {
		color: #1F2937;
		font-weight: 600;
		font-size: 0.875rem;
		text-align: right;
	}

	.amount-large {
		color: #10B981 !important;
		font-family: 'Courier New', monospace;
		font-size: 1.125rem !important;
	}

	.permission-notice {
		padding: 0.875rem 1rem;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 12px;
		color: #92400e;
		font-size: 0.875rem;
		text-align: center;
		margin-bottom: 1rem;
	}

	.permission-notice small {
		font-size: 0.75rem;
		color: #b45309;
		display: block;
		margin-top: 0.25rem;
	}

	.action-buttons {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		padding-top: 1rem;
		border-top: 1px solid #F3F4F6;
	}

	.btn-approve,
	.btn-reject {
		padding: 1rem;
		border-radius: 12px;
		border: none;
		font-weight: 600;
		font-size: 1rem;
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
		padding: 1rem;
		background: #F3F4F6;
		border-radius: 12px;
		text-align: center;
		color: #6B7280;
		font-weight: 600;
		margin-top: 1rem;
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
		padding: 1rem;
	}

	.confirm-modal {
		background: white;
		border-radius: 16px;
		padding: 1.5rem;
		max-width: 500px;
		width: 100%;
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
		font-size: 1.25rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 1rem 0;
		text-align: center;
	}

	.confirm-message {
		font-size: 0.9rem;
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
		gap: 0.75rem;
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
</style>


