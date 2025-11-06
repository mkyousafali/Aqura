<script>
	// Approval Center Component
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';

	let requisitions = [];
	let paymentSchedules = []; // New: payment schedules requiring approval
	let vendorPayments = []; // New: vendor payments requiring approval
	let approvedPaymentSchedules = []; // Approved payment schedules from expense_scheduler
	let rejectedPaymentSchedules = []; // Rejected payment schedules
	let myCreatedRequisitions = []; // Requisitions created by current user
	let myCreatedSchedules = []; // Payment schedules created by current user
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

	async function loadRequisitions() {
		try {
		loading = true;
		
		// Check if user is logged in
		if (!$currentUser?.id) {
			alert('❌ Please login to access the approval center');
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
		alert('❌ Error checking user permissions: ' + permsError.message);
		loading = false;
		return;
	}		// User can approve if ANY permission is enabled
		if (approvalPerms) {
			userCanApprove = 
				approvalPerms.can_approve_requisitions ||
				approvalPerms.can_approve_single_bill ||
				approvalPerms.can_approve_multiple_bill ||
				approvalPerms.can_approve_recurring_bill ||
				approvalPerms.can_approve_vendor_payments ||
				approvalPerms.can_approve_leave_requests;
			
			console.log('👤 User approval permissions:', {
				canApprove: userCanApprove,
				requisitions: approvalPerms.can_approve_requisitions,
				single_bill: approvalPerms.can_approve_single_bill,
				multiple_bill: approvalPerms.can_approve_multiple_bill,
				recurring_bill: approvalPerms.can_approve_recurring_bill,
				vendor_payments: approvalPerms.can_approve_vendor_payments,
				leave_requests: approvalPerms.can_approve_leave_requests
			});
		} else {
			userCanApprove = false;
			console.log('👤 No approval permissions found for user');
		}

		console.log('✅ Loading approval center for user:', $currentUser.username);
		
		// Import supabaseAdmin for admin queries
		const { supabaseAdmin } = await import('$lib/utils/supabase');
		
		// Calculate date for filtering
		const twoDaysFromNow = new Date();
		twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
		const twoDaysDate = twoDaysFromNow.toISOString().split('T')[0];
		
		console.log('🔍 Loading all data in parallel for better performance...');
		
		// Run all queries in parallel for better performance
		const [
			requisitionsResult,
			schedulesResult,
			vendorPaymentsResult,
			myRequisitionsResult,
			mySchedulesResult,
			myApprovedSchedulesResult,
			approvedSchedulesResult,
			rejectedSchedulesResult
		] = await Promise.all([
			// 1. Requisitions where current user is approver
			supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.eq('approver_id', $currentUser.id)
				.order('created_at', { ascending: false }),
			
			// 2. Payment schedules requiring approval
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
				.order('created_at', { ascending: false }),
			
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
					.order('approval_requested_at', { ascending: false }) :
				Promise.resolve({ data: [], error: null }),
			
			// 4. My created requisitions
			supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.eq('created_by', $currentUser.id)
				.order('created_at', { ascending: false }),
			
			// 5. My created payment schedules
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
				.in('schedule_type', ['single_bill', 'multiple_bill'])
				.order('created_at', { ascending: false }),
			
			// 6. My approved/rejected schedules from expense_scheduler
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
				.order('created_at', { ascending: false }),
			
			// 7. Approved payment schedules where I was the approver
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
				.order('created_at', { ascending: false }),
			
			// 8. Rejected schedules where I was the approver
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
		
		// Process my approved schedules
		const { data: myApprovedSchedulesData, error: myApprovedSchedulesError } = myApprovedSchedulesResult;
		let myApprovedSchedulesCount = 0;
		if (!myApprovedSchedulesError && myApprovedSchedulesData) {
			myApprovedSchedules = myApprovedSchedulesData || [];
			myApprovedSchedulesCount = myApprovedSchedules.length;
			console.log('✅ My approved schedules loaded:', myApprovedSchedulesCount);
		}
		
		// Process approved schedules where I was approver
		const { data: approvedSchedulesData, error: approvedSchedulesError } = approvedSchedulesResult;
		let approvedSchedulesCount = 0;
		if (!approvedSchedulesError && approvedSchedulesData) {
			approvedPaymentSchedules = approvedSchedulesData || [];
			approvedSchedulesCount = approvedPaymentSchedules.length;
			console.log('✅ Approved payment schedules loaded (where user is approver):', approvedSchedulesCount);
		}
		
		// Process rejected schedules
		const { data: rejectedSchedulesData, error: rejectedSchedulesError } = rejectedSchedulesResult;
		let rejectedSchedulesCount = 0;
		if (!rejectedSchedulesError && rejectedSchedulesData) {
			rejectedPaymentSchedules = rejectedSchedulesData || [];
			rejectedSchedulesCount = rejectedPaymentSchedules.length;
			console.log('✅ Rejected payment schedules loaded:', rejectedSchedulesCount);
		}

		// Calculate stats (include both requisitions and payment schedules)
		// Stats for approvals assigned to me
		// Only count items where current user is the approver
		const myApprovedRequisitions = requisitions.filter(r => r.status === 'approved' && r.approver_id === $currentUser.id);
		const myRejectedRequisitions = requisitions.filter(r => r.status === 'rejected' && r.approver_id === $currentUser.id);
		
		stats.pending = requisitions.filter(r => r.status === 'pending').length + paymentSchedules.length + vendorPayments.length;
		stats.approved = myApprovedRequisitions.length + approvedSchedulesCount;
		stats.rejected = myRejectedRequisitions.length + rejectedSchedulesCount;
		stats.total = stats.pending + stats.approved + stats.rejected;

		// Stats for my created requests
		myStats.pending = myCreatedRequisitions.filter(r => r.status === 'pending').length + 
		                  myCreatedSchedules.filter(s => s.approval_status === 'pending').length;
		myStats.approved = myCreatedRequisitions.filter(r => r.status === 'approved').length + myApprovedSchedulesCount;
		myStats.rejected = myCreatedRequisitions.filter(r => r.status === 'rejected').length +
		                   myCreatedSchedules.filter(s => s.approval_status === 'rejected').length;
		myStats.total = myStats.pending + myStats.approved + myStats.rejected;

		console.log('📈 Approval Stats:', stats);
		console.log('� My Requests Stats:', myStats);
		console.log('�📊 Stats breakdown:', {
			requisitions: requisitions.length,
			paymentSchedules: paymentSchedules.length,
			approvedSchedules: approvedSchedulesCount,
			rejectedSchedules: rejectedSchedulesCount,
			pendingRequisitions: requisitions.filter(r => r.status === 'pending').length,
			approvedRequisitions: requisitions.filter(r => r.status === 'approved').length,
			rejectedRequisitions: requisitions.filter(r => r.status === 'rejected').length,
			myCreatedRequisitions: myCreatedRequisitions.length,
			myCreatedSchedules: myCreatedSchedules.length,
			myApprovedSchedules: myApprovedSchedulesCount
		});

		filterRequisitions();
		} catch (err) {
			console.error('Error loading requisitions:', err);
			alert('Error loading requisitions: ' + err.message);
		} finally {
			loading = false;
		}
	}

	function filterRequisitions() {
		if (activeSection === 'approvals') {
			// Filter approvals assigned to me
			let filtered = requisitions;
			let filteredSchedules = [];

			console.log('🔍 Filtering approvals assigned to me:', {
				total: requisitions.length,
				paymentSchedules: paymentSchedules.length,
				approvedSchedules: approvedPaymentSchedules.length,
				rejectedSchedules: rejectedPaymentSchedules.length,
				selectedStatus,
				searchQuery
			});

			// Filter requisitions by status
			if (selectedStatus !== 'all') {
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
				})) : [])
			];

			console.log('✅ Final filtered approvals:', {
				requisitions: filtered.length,
				schedules: filteredSchedules.length,
				total: filteredRequisitions.length
			});
		} else {
			// Filter my created requests
			let filtered = myCreatedRequisitions;
			let filteredSchedules = [];

			console.log('🔍 Filtering my created requests:', {
				total: myCreatedRequisitions.length,
				mySchedules: myCreatedSchedules.length,
				myApprovedSchedules: myApprovedSchedules.length,
				selectedStatus,
				searchQuery
			});

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
				}))
			];

			console.log('✅ Final filtered my requests:', {
				requisitions: filtered.length,
				schedules: filteredSchedules.length,
				total: filteredMyRequests.length
			});
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

	async function approveRequisition(requisitionId) {
		if (!confirm('Are you sure you want to approve this ' + (selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : 'requisition') + '?')) return;

		try {
			isProcessing = true;

			// Use supabaseAdmin for update operations
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the full payment schedule data
				const { data: scheduleData, error: fetchError } = await supabaseAdmin
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', requisitionId)
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

				alert('✅ Payment schedule approved and moved to expense scheduler!');
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Approve vendor payment
				const { data: paymentData, error: fetchError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update vendor payment status
				const { error: updateError } = await supabaseAdmin
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

				alert('✅ Vendor payment approved successfully!');
			} else {
				// Get the requisition data first
				const { data: reqData, error: reqError } = await supabaseAdmin
					.from('expense_requisitions')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (reqError) throw reqError;

				// Update regular requisition status to approved
				const { error } = await supabaseAdmin
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

				const { error: schedulerError } = await supabaseAdmin
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
				
				alert('✅ Requisition approved and added to expense scheduler!');
			}

			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error approving:', err);
			alert('Error approving: ' + err.message);
		} finally {
			isProcessing = false;
		}
	}

	async function rejectRequisition(requisitionId) {
		const reason = prompt('Please provide a reason for rejection:');
		if (!reason) return;

		try {
			isProcessing = true;

			// Use supabaseAdmin for update operations
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			// Check if it's a payment schedule or regular requisition
			if (selectedRequisition.item_type === 'payment_schedule') {
				// Get the schedule data first
				const { data: scheduleData, error: fetchError } = await supabaseAdmin
					.from('non_approved_payment_scheduler')
					.select('*')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update payment schedule
				const { error } = await supabaseAdmin
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
				
				alert('❌ Payment schedule rejected successfully!');
			} else if (selectedRequisition.item_type === 'vendor_payment') {
				// Reject vendor payment
				const { data: paymentData, error: fetchError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.select('*')
					.eq('id', requisitionId)
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

				alert('❌ Vendor payment rejected successfully!');
			} else {
				// Get requisition data first
				const { data: reqData, error: fetchError } = await supabaseAdmin
					.from('expense_requisitions')
					.select('created_by, requisition_number, requester_name, amount, expense_category_name_en, branch_name')
					.eq('id', requisitionId)
					.single();

				if (fetchError) throw fetchError;

				// Update regular requisition
				const { error } = await supabaseAdmin
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
				
				alert('❌ Requisition rejected successfully!');
			}

			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error rejecting:', err);
			alert('Error rejecting: ' + err.message);
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
		{:else if filteredRequisitions.length === 0}
			<div class="empty-state">
				<div class="empty-icon">�</div>
				<h3>No Requisitions Found</h3>
				<p>There are no requisitions matching your filters.</p>
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
						{#each (activeSection === 'approvals' ? filteredRequisitions : filteredMyRequests) as req}
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
									<td>
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️ View
										</button>
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
									<td>
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️ View
										</button>
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
									<td>
										<button class="btn-view" on:click={() => openDetail(req)}>
											👁️ View
										</button>
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
				{/if}
			</div>

		<div class="modal-footer">
			{#if (selectedRequisition.item_type === 'requisition' && selectedRequisition.status === 'pending') || (selectedRequisition.item_type === 'payment_schedule' && (selectedRequisition.approval_status === 'pending' || !selectedRequisition.approval_status)) || (selectedRequisition.item_type === 'vendor_payment' && selectedRequisition.approval_status === 'sent_for_approval')}
					{@const canApproveThis = selectedRequisition.item_type === 'payment_schedule' 
						? selectedRequisition.approver_id === $currentUser?.id 
						: selectedRequisition.item_type === 'vendor_payment'
						? userCanApprove
						: userCanApprove}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}
					{#if !canApproveThis}
						<div class="permission-notice">
							ℹ️ You do not have permission to approve or reject this {itemTypeName}.
							<br><small>{selectedRequisition.item_type === 'payment_schedule' ? 'This schedule is assigned to a different approver.' : 'Please contact your administrator for approval permissions.'}</small>
						</div>
					{/if}
					<button
						class="btn-approve"
						on:click={() => approveRequisition(selectedRequisition.id)}
						disabled={isProcessing || !canApproveThis}
						title={!canApproveThis ? 'You need approval permissions to approve this item' : 'Approve this item'}
					>
						{isProcessing ? '⏳ Processing...' : '✅ Approve'}
					</button>
					<button
						class="btn-reject"
						on:click={() => rejectRequisition(selectedRequisition.id)}
						disabled={isProcessing || !canApproveThis}
						title={!canApproveThis ? 'You need approval permissions to reject this item' : 'Reject this item'}
					>
						{isProcessing ? '⏳ Processing...' : '❌ Reject'}
					</button>
				{:else}
					{@const itemTypeName = selectedRequisition.item_type === 'payment_schedule' ? 'payment schedule' : selectedRequisition.item_type === 'vendor_payment' ? 'vendor payment' : 'requisition'}
					<div class="status-info">
						This {itemTypeName} has been {selectedRequisition.status || selectedRequisition.approval_status}
					</div>
				{/if}
				<button class="btn-close" on:click={closeDetail}>Close</button>
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
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-view:hover {
		background: #2563eb;
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
</style>
