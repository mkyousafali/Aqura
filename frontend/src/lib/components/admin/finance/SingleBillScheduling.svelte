<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';

	// Step management
	let currentStep = 1;
	const totalSteps = 3;

	// Data arrays
	let branches = [];
	let categories = [];
	let approvedRequests = [];
	let users = [];
	let filteredCategories = [];
	let filteredUsers = [];
	let filteredRequests = [];

	// Step 1 data
	let selectedBranchId = '';
	let selectedBranchName = '';
	let selectedCategoryId = '';
	let selectedCategoryNameEn = '';
	let selectedCategoryNameAr = '';
	let categorySearchQuery = '';

	// Step 2 data
	let selectedRequestId = '';
	let selectedRequestNumber = '';
	let selectedRequestAmount = 0;
	let selectedRequestRemainingBalance = 0;
	let selectedRequestUsedAmount = 0;
	let selectedCoUserId = '';
	let selectedCoUserName = '';
	let requestSearchQuery = '';
	let userSearchQuery = '';
	let dateFilter = 'all'; // 'all', 'today', 'yesterday', 'range'
	let dateRangeStart = '';
	let dateRangeEnd = '';

	// Approver data (needed when no approved request is selected)
	let approvers = [];
	let filteredApprovers = [];
	let selectedApproverId = '';
	let selectedApproverName = '';
	let approverSearchQuery = '';

	// Reactive balance calculation - use actual remaining balance from database
	$: balance = selectedRequestRemainingBalance > 0 && amount ? selectedRequestRemainingBalance - parseFloat(amount || 0) : 0;

	// Step 3 data
	let billType = 'no_bill'; // 'vat_applicable', 'no_vat', 'no_bill'
	let billNumber = '';
	let billDate = '';
	let paymentMethod = 'advance_cash';
	let amount = '';
	let dueDate = '';
	let description = '';
	let creditPeriod = '';
	let bankName = '';
	let iban = '';
	let billFile = null;
	let billFileName = '';
	let uploading = false;
	let saving = false;
	let successMessage = '';
	let savedScheduleId = '';
	let savedScheduleData = null;
	let showWhatsAppButton = false;

	// Payment methods (from RequestGenerator)
	const paymentMethods = [
		{ value: 'advance_cash', label: 'Advance Cash - سلفة نقدية', creditDays: 0 },
		{ value: 'advance_bank', label: 'Advance Bank - سلفة بنكية', creditDays: 0 },
		{ value: 'advance_cash_credit', label: 'Advance Cash Credit - سلفة ائتمان نقدي', creditDays: 30 },
		{ value: 'advance_bank_credit', label: 'Advance Bank Credit - سلفة ائتمان بنكي', creditDays: 30 },
		{ value: 'cash', label: 'Cash - نقدي', creditDays: 0 },
		{ value: 'bank', label: 'Bank - بنكي', creditDays: 0 },
		{ value: 'cash_credit', label: 'Cash Credit - ائتمان نقدي', creditDays: 30 },
		{ value: 'bank_credit', label: 'Bank Credit - ائتمان بنكي', creditDays: 30 },
		{ value: 'stock_purchase_advance_cash', label: 'Stock Purchase Advance Cash - شراء مخزون سلفة نقدية', creditDays: 0 },
		{ value: 'stock_purchase_advance_bank', label: 'Stock Purchase Advance Bank - شراء مخزون سلفة بنكية', creditDays: 0 },
		{ value: 'stock_purchase_cash', label: 'Stock Purchase Cash - شراء مخزون نقدي', creditDays: 0 },
		{ value: 'stock_purchase_bank', label: 'Stock Purchase Bank - شراء مخزون بنكي', creditDays: 0 }
	];

	onMount(async () => {
		await loadInitialData();
	});

	async function loadInitialData() {
		try {
			// Load branches
			const { data: branchesData, error: branchesError } = await supabaseAdmin
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// Load categories with parent category info
			const { data: categoriesData, error: categoriesError } = await supabaseAdmin
				.from('expense_sub_categories')
				.select(`
					*,
					parent_category:expense_parent_categories(
						id,
						name_en,
						name_ar
					)
				`)
				.eq('is_active', true)
				.order('name_en');

			if (categoriesError) throw categoriesError;
			categories = categoriesData || [];
			filteredCategories = categories;

			// Load approvers
			await loadApprovers();
		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	async function loadApprovers() {
		try {
			// Load users with single bill approval permissions from approval_permissions table
			const { data: approvalPermsData } = await supabaseAdmin
				.from('approval_permissions')
				.select('user_id, single_bill_amount_limit, can_approve_single_bill')
				.eq('is_active', true)
				.eq('can_approve_single_bill', true);

			// Get user IDs with single bill approval permissions
			const approverUserIds = approvalPermsData?.map(p => p.user_id) || [];
			
			if (approverUserIds.length === 0) {
				console.warn('No users with single bill approval permissions found');
				approvers = [];
				filteredApprovers = [];
				return;
			}

			// Load user details for those with permissions
			const { data, error } = await supabaseAdmin
				.from('users')
				.select(`
					*,
					hr_employees (
						name
					)
				`)
				.eq('status', 'active')
				.in('id', approverUserIds)
				.order('username');

			if (error) throw error;

			// Merge approval limits with user data
			approvers = (data || []).map(user => {
				const approvalPerm = approvalPermsData?.find(p => p.user_id === user.id);
				return {
					...user,
					approval_amount_limit: approvalPerm?.single_bill_amount_limit || 0,
					can_approve_payments: true // For backward compatibility
				};
			});
			filteredApprovers = approvers;
		} catch (error) {
			console.error('Error loading approvers:', error);
		}
	}

	async function loadApprovedRequests() {
		if (!selectedBranchId) return;

		try {
			const { data, error } = await supabaseAdmin
				.from('expense_requisitions')
				.select('*, used_amount, remaining_balance')
				.eq('branch_id', selectedBranchId)
				.eq('status', 'approved')
				.eq('is_active', true)
				.order('created_at', { ascending: false });

			if (error) throw error;
			
			// Filter out requests with zero remaining balance
			const allRequests = data || [];
			approvedRequests = allRequests.filter(request => {
				const remainingBalance = parseFloat(request.remaining_balance || request.amount || 0);
				return remainingBalance > 0;
			});
			
			filteredRequests = approvedRequests;
		} catch (error) {
			console.error('Error loading approved requests:', error);
		}
	}

	async function loadUsers() {
		if (!selectedBranchId) return;

		try {
			const { data, error } = await supabaseAdmin
				.from('users')
				.select('*')
				.or(`branch_id.eq.${selectedBranchId},user_type.eq.global`)
				.eq('status', 'active')
				.order('username');

			if (error) throw error;
			users = data || [];
			filteredUsers = users;
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	function handleCategorySearch() {
		if (!categorySearchQuery.trim()) {
			filteredCategories = categories;
			return;
		}

		const query = categorySearchQuery.toLowerCase();
		filteredCategories = categories.filter(
			(cat) =>
				cat.name_en?.toLowerCase().includes(query) ||
				cat.name_ar?.toLowerCase().includes(query)
		);
	}

	function handleRequestSearch() {
		if (!requestSearchQuery.trim()) {
			filteredRequests = approvedRequests;
			applyDateFilter();
			return;
		}

		const query = requestSearchQuery.toLowerCase();
		filteredRequests = approvedRequests.filter(
			(req) =>
				req.requisition_number?.toLowerCase().includes(query) ||
				req.requester_name?.toLowerCase().includes(query) ||
				req.approver_name?.toLowerCase().includes(query) ||
				req.amount?.toString().includes(query)
		);
		applyDateFilter();
	}

	function applyDateFilter() {
		let tempFiltered = filteredRequests;

		if (dateFilter === 'today') {
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			tempFiltered = filteredRequests.filter((req) => {
				const reqDate = new Date(req.created_at);
				reqDate.setHours(0, 0, 0, 0);
				return reqDate.getTime() === today.getTime();
			});
		} else if (dateFilter === 'yesterday') {
			const yesterday = new Date();
			yesterday.setDate(yesterday.getDate() - 1);
			yesterday.setHours(0, 0, 0, 0);
			tempFiltered = filteredRequests.filter((req) => {
				const reqDate = new Date(req.created_at);
				reqDate.setHours(0, 0, 0, 0);
				return reqDate.getTime() === yesterday.getTime();
			});
		} else if (dateFilter === 'range' && dateRangeStart && dateRangeEnd) {
			const startDate = new Date(dateRangeStart);
			const endDate = new Date(dateRangeEnd);
			startDate.setHours(0, 0, 0, 0);
			endDate.setHours(23, 59, 59, 999);
			tempFiltered = filteredRequests.filter((req) => {
				const reqDate = new Date(req.created_at);
				return reqDate >= startDate && reqDate <= endDate;
			});
		}

		filteredRequests = tempFiltered;
	}

	function handleDateFilterChange() {
		filteredRequests = approvedRequests;
		if (requestSearchQuery.trim()) {
			handleRequestSearch();
		} else {
			applyDateFilter();
		}
	}

	function handleUserSearch() {
		if (!userSearchQuery.trim()) {
			filteredUsers = users;
			return;
		}

		const query = userSearchQuery.toLowerCase();
		filteredUsers = users.filter((user) => user.username?.toLowerCase().includes(query));
	}

	function handleApproverSearch() {
		if (!approverSearchQuery.trim()) {
			filteredApprovers = approvers;
			return;
		}

		const query = approverSearchQuery.toLowerCase();
		filteredApprovers = approvers.filter((user) => user.username?.toLowerCase().includes(query));
	}

	function selectCategory(category) {
		selectedCategoryId = category.id;
		selectedCategoryNameEn = category.name_en;
		selectedCategoryNameAr = category.name_ar;
	}

	function selectRequest(request) {
		selectedRequestId = request.id;
		selectedRequestNumber = request.requisition_number;
		selectedRequestAmount = parseFloat(request.amount || 0);
		// Also track actual remaining balance from database
		selectedRequestRemainingBalance = parseFloat(request.remaining_balance || request.amount || 0);
		selectedRequestUsedAmount = parseFloat(request.used_amount || 0);
	}

	function clearRequestSelection() {
		selectedRequestId = '';
		selectedRequestNumber = '';
		selectedRequestAmount = 0;
		selectedRequestRemainingBalance = 0;
		selectedRequestUsedAmount = 0;
	}

	function selectUser(user) {
		selectedCoUserId = user.id;
		selectedCoUserName = user.username;
	}

	function selectApprover(user) {
		selectedApproverId = user.id;
		selectedApproverName = user.username;
	}

	function validateStep1() {
		if (!selectedBranchId) {
			alert('Please select a branch');
			return false;
		}
		if (!selectedCategoryId) {
			alert('Please select an expense category');
			return false;
		}
		return true;
	}

	function validateStep2() {
		if (!selectedCoUserId) {
			alert('Please select a c/o user');
			return false;
		}
		return true;
	}

	function validateStep3() {
		if (!amount || parseFloat(amount) <= 0) {
			alert('Please enter a valid amount');
			return false;
		}

		// Require approver (now always required)
		if (!selectedApproverId) {
			alert('Please select an approver');
			return false;
		}

		if (billType === 'vat_applicable' || billType === 'no_vat') {
			if (!billNumber) {
				alert('Please enter a bill number');
				return false;
			}
			if (!billFile) {
				alert('Please upload a bill file');
				return false;
			}
		}

		return true;
	}

	async function nextStep() {
		if (currentStep === 1) {
			if (!validateStep1()) return;
			await loadApprovedRequests();
			await loadUsers();
		} else if (currentStep === 2) {
			if (!validateStep2()) return;
		}

		if (currentStep < totalSteps) {
			currentStep++;
		}
	}

	function previousStep() {
		if (currentStep > 1) {
			currentStep--;
		}
	}

	function handleBranchChange() {
		selectedBranchName = branches.find((b) => b.id === parseInt(selectedBranchId))?.name_en || '';
	}

	function handleBillFileChange(event) {
		const file = event.target.files[0];
		if (file) {
			// Validate file type
			const allowedTypes = [
				'image/jpeg',
				'image/jpg',
				'image/png',
				'image/gif',
				'image/webp',
				'application/pdf'
			];
			if (!allowedTypes.includes(file.type)) {
				alert('Please upload a valid image (JPEG, PNG, GIF, WebP) or PDF file');
				event.target.value = '';
				return;
			}

		// Validate file size (50MB)
		if (file.size > 50 * 1024 * 1024) {
			alert('File size must be less than 50MB');
			event.target.value = '';
			return;
		}			billFile = file;
			billFileName = file.name;
		}
	}

	function calculateDueDate() {
		if (!paymentMethod) return;

		const selectedMethod = paymentMethods.find((m) => m.value === paymentMethod);
		if (!selectedMethod) return;

		// Use user-entered creditPeriod if available, otherwise use default from payment method
		const creditDays = creditPeriod && parseInt(creditPeriod) > 0 ? parseInt(creditPeriod) : selectedMethod.creditDays;
		// Use billDate if available, otherwise use current date
		const baseDate = billDate ? new Date(billDate) : new Date();
		baseDate.setDate(baseDate.getDate() + creditDays);

		dueDate = baseDate.toISOString().split('T')[0];
	}

	// Recalculate due date when payment method changes or bill date changes
	$: if (paymentMethod) {
		calculateDueDate();
	}
	
	// Also recalculate when billDate changes (for bills with dates)
	$: if (billDate && paymentMethod) {
		calculateDueDate();
	}
	
	// Recalculate when creditPeriod changes
	$: if (creditPeriod && paymentMethod) {
		calculateDueDate();
	}

	async function uploadBillFile() {
		if (!billFile) return null;

		try {
			uploading = true;
			const timestamp = Date.now();
			const fileName = `${timestamp}_${billFile.name}`;
			const filePath = `${selectedBranchId}/${fileName}`;

			const { data, error } = await supabaseAdmin.storage
				.from('expense-scheduler-bills')
				.upload(filePath, billFile);

			if (error) throw error;

			// Get public URL
			const { data: urlData } = supabaseAdmin.storage
				.from('expense-scheduler-bills')
				.getPublicUrl(filePath);

			return urlData.publicUrl;
		} catch (error) {
			console.error('Error uploading bill file:', error);
			throw error;
		} finally {
			uploading = false;
		}
	}

	async function saveScheduler() {
		if (!validateStep3()) return;

		try {
			// Always save to non_approved_payment_scheduler and send notification
			await saveToNonApprovedScheduler();
		} catch (error) {
			console.error('Error saving scheduler:', error);
			alert('Error saving bill schedule. Please try again.');
		}
	}

	async function saveToNonApprovedScheduler() {
		try {
			saving = true;
			successMessage = '';

			// Upload bill file if applicable
			let billFileUrl = null;
			if (billType === 'vat_applicable' || billType === 'no_vat') {
				billFileUrl = await uploadBillFile();
			}

			// Get selected method credit days
			const selectedMethod = paymentMethods.find((m) => m.value === paymentMethod);
			const creditPeriod = selectedMethod?.creditDays || 0;

			// Prepare data for non-approved scheduler
			const schedulerData = {
				schedule_type: 'single_bill',
				branch_id: parseInt(selectedBranchId),
				branch_name: selectedBranchName,
				expense_category_id: selectedCategoryId,
				expense_category_name_en: selectedCategoryNameEn,
				expense_category_name_ar: selectedCategoryNameAr,
				co_user_id: selectedCoUserId,
				co_user_name: selectedCoUserName,
				bill_type: billType,
				bill_number: billNumber || null,
				bill_date: billDate || null,
				payment_method: paymentMethod,
				due_date: dueDate || null,
				credit_period: creditPeriod ? parseInt(creditPeriod) : creditPeriod,
				amount: parseFloat(amount),
				bill_file_url: billFileUrl,
				description: description || null,
				bank_name: bankName || null,
				iban: iban || null,
				approver_id: selectedApproverId,
				approver_name: selectedApproverName,
				approval_status: 'pending',
				created_by: $currentUser.id
			};

			const { data, error } = await supabaseAdmin
				.from('non_approved_payment_scheduler')
				.insert([schedulerData])
				.select()
				.single();

			if (error) throw error;

			// Store schedule data for WhatsApp sharing
			savedScheduleId = data.id;
			savedScheduleData = data;
			showWhatsAppButton = true;

			// Send notification to approver
			try {
				await notificationService.createNotification({
					title: 'Payment Schedule Approval Required',
					message: `A new single bill payment schedule requires your approval.\n\nBranch: ${selectedBranchName}\nCategory: ${selectedCategoryNameEn}\nC/O User: ${selectedCoUserName}\nAmount: ${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nBill Type: ${billType}\nSubmitted by: ${$currentUser?.username}`,
					type: 'approval_request',
					priority: 'high',
					target_type: 'specific_users',
					target_users: [selectedApproverId]
				}, $currentUser?.id || $currentUser?.username || 'System');
				console.log('✅ Notification sent to approver:', selectedApproverName);
			} catch (notifError) {
				console.error('⚠️ Failed to send notification:', notifError);
				// Don't fail the whole operation if notification fails
			}

			successMessage = `✅ Bill schedule submitted for approval!\n\nSchedule ID: ${data.id}\nApprover: ${selectedApproverName}\n\nThe schedule will be posted to the expense scheduler after approval.`;
			
			// Don't auto-reset if WhatsApp button should be shown
			if (!showWhatsAppButton) {
				setTimeout(() => {
					resetForm();
				}, 2000);
			}
		} catch (error) {
			console.error('Error saving to non-approved scheduler:', error);
			throw error;
		} finally {
			saving = false;
		}
	}

	function resetForm() {
		currentStep = 1;
		selectedBranchId = '';
		selectedBranchName = '';
		selectedCategoryId = '';
		selectedCategoryNameEn = '';
		selectedCategoryNameAr = '';
		selectedRequestId = '';
		selectedRequestNumber = '';
		selectedRequestAmount = 0;
		selectedRequestRemainingBalance = 0;
		selectedRequestUsedAmount = 0;
		selectedCoUserId = '';
		selectedCoUserName = '';
		selectedApproverId = '';
		selectedApproverName = '';
		approverSearchQuery = '';
		billType = 'no_bill';
		billNumber = '';
		billDate = '';
		paymentMethod = 'advance_cash';
		amount = '';
		dueDate = '';
		description = '';
		creditPeriod = '';
		bankName = '';
		iban = '';
		billFile = null;
		billFileName = '';
		categorySearchQuery = '';
		requestSearchQuery = '';
		userSearchQuery = '';
		dateFilter = 'all';
		dateRangeStart = '';
		dateRangeEnd = '';
		successMessage = '';
		showWhatsAppButton = false;
		savedScheduleId = '';
		savedScheduleData = null;
	}

	async function shareToWhatsApp() {
		try {
			// Format date
			const formattedDate = new Date().toLocaleDateString('en-US', { 
				year: 'numeric', 
				month: 'long', 
				day: 'numeric' 
			});
			
			// Build bilingual message - Arabic First
			let message = `*━━━━━━━━━━━━━━━━*\n`;
			message += `*جدولة فاتورة | BILL SCHEDULE*\n`;
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			message += `⚠️ *تم الإنشاء تلقائياً - يرجى الموافقة من مركز الموافقات*\n`;
			message += `⚠️ *Auto-generated - Please approve from Approval Center*\n\n`;
			
			// Approver
			message += `*✅ المعتمد | Approver:*\n`;
			message += `${selectedApproverName}\n\n`;
			
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			// Date
			message += `*📅 التاريخ | Date:*\n`;
			message += `${formattedDate}\n\n`;
			
			// Branch
			message += `*🏢 الفرع | Branch:*\n`;
			message += `${selectedBranchName}\n\n`;
			
			// Amount
			message += `*💰 المبلغ | Amount:*\n`;
			message += `${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\n\n`;
			
			// Category
			message += `*📂 الفئة | Category:*\n`;
			message += `${selectedCategoryNameAr} | ${selectedCategoryNameEn}\n\n`;
			
			// Description / Notes (if available)
			if (description && description.trim()) {
				message += `*📝 الوصف / الملاحظات | Description / Notes:*\n`;
				message += `${description}\n\n`;
			}
			
			// Schedule Number
			message += `*📋 رقم الجدولة | Schedule No:*\n`;
			message += `${savedScheduleId}\n\n`;
			
			// Generated By
			message += `*👤 تم الإنشاء بواسطة | Generated By:*\n`;
			message += `${$currentUser?.username || 'System'}\n\n`;
			
			// Bill File (if available)
			if (savedScheduleData?.bill_file_url) {
				message += `*📄 عرض المستند | View Document:*\n`;
				message += `${savedScheduleData.bill_file_url}`;
			}
			
			// Open WhatsApp Web with the message
			const whatsappWebUrl = `https://web.whatsapp.com/send?text=${encodeURIComponent(message)}`;
			window.open(whatsappWebUrl, '_blank');
			
		} catch (error) {
			console.error('Error sharing:', error);
			alert('Error opening WhatsApp: ' + error.message);
		}
	}

	function formatDate(dateString) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}-${month}-${year}`;
	}

	function formatDateTime(dateString) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		
		let hours = date.getHours();
		const minutes = String(date.getMinutes()).padStart(2, '0');
		const ampm = hours >= 12 ? 'PM' : 'AM';
		hours = hours % 12;
		hours = hours ? hours : 12; // 0 should be 12
		const hoursStr = String(hours).padStart(2, '0');
		
		return `${day}-${month}-${year} ${hoursStr}:${minutes} ${ampm}`;
	}
</script>

<div class="single-bill-scheduling">
	<div class="header">
		<h2 class="title">Single Bill Scheduling</h2>
		<p class="subtitle">Schedule a one-time payment for a single bill</p>
	</div>

	<!-- Progress Steps -->
	<div class="progress-steps">
		<div class="step" class:active={currentStep === 1} class:completed={currentStep > 1}>
			<div class="step-number">1</div>
			<div class="step-label">Branch & Category</div>
		</div>
		<div class="step-line" class:completed={currentStep > 1}></div>
		<div class="step" class:active={currentStep === 2} class:completed={currentStep > 2}>
			<div class="step-number">2</div>
			<div class="step-label">Request & User</div>
		</div>
		<div class="step-line" class:completed={currentStep > 2}></div>
		<div class="step" class:active={currentStep === 3} class:completed={currentStep > 3}>
			<div class="step-number">3</div>
			<div class="step-label">Bill Details</div>
		</div>
	</div>

	<div class="content">
		<!-- Step 1: Branch & Category -->
		{#if currentStep === 1}
			<div class="step-content">
				<h3 class="step-title">Select Branch and Expense Category</h3>

				<!-- Branch Selection -->
				<div class="form-group">
					<label for="branch">Branch *</label>
					<select
						id="branch"
						class="form-select"
						bind:value={selectedBranchId}
						on:change={handleBranchChange}
					>
						<option value="">-- Select Branch --</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en}</option>
						{/each}
					</select>
				</div>

				<!-- Category Selection -->
				<div class="form-group">
					<label for="categorySearch">Expense Category *</label>
					<input
						id="categorySearch"
						type="text"
						class="form-input"
						placeholder="Search categories..."
						bind:value={categorySearchQuery}
						on:input={handleCategorySearch}
					/>

					{#if selectedCategoryId}
						<div class="selected-info">
							✓ Selected: <strong>{selectedCategoryNameEn}</strong>
							{#if selectedCategoryNameAr}
								<span class="arabic">({selectedCategoryNameAr})</span>
							{/if}
						</div>
					{/if}

					<div class="selection-table">
						<table>
							<thead>
								<tr>
									<th>Select</th>
									<th>Parent Category</th>
									<th>Category Name (EN)</th>
									<th>Category Name (AR)</th>
								</tr>
							</thead>
							<tbody>
								{#if filteredCategories.length > 0}
									{#each filteredCategories as category}
										<tr
											class:selected={selectedCategoryId === category.id}
											on:click={() => selectCategory(category)}
										>
											<td>
												<input
													type="radio"
													name="category"
													checked={selectedCategoryId === category.id}
													on:change={() => selectCategory(category)}
												/>
											</td>
											<td>
												{#if category.parent_category}
													<div class="parent-category-cell">
														<span class="parent-badge">{category.parent_category.name_en}</span>
														<span class="parent-badge arabic">{category.parent_category.name_ar}</span>
													</div>
												{:else}
													-
												{/if}
											</td>
											<td>{category.name_en}</td>
											<td class="arabic">{category.name_ar || '-'}</td>
										</tr>
									{/each}
								{:else}
									<tr>
										<td colspan="4" class="no-data-message">No categories found</td>
									</tr>
								{/if}
							</tbody>
						</table>
					</div>
				</div>
			</div>
		{/if}

		<!-- Step 2: Request & User -->
		{#if currentStep === 2}
			<div class="step-content">
				<h3 class="step-title">Select C/O User</h3>

				<!-- C/O User Selection (Mandatory) -->
				<div class="form-group">
					<label for="userSearch">C/O User *</label>
					<input
						id="userSearch"
						type="text"
						class="form-input"
						placeholder="Search users..."
						bind:value={userSearchQuery}
						on:input={handleUserSearch}
					/>

					{#if selectedCoUserId}
						<div class="selected-info">
							✓ Selected: <strong>{selectedCoUserName}</strong>
						</div>
					{/if}

					<div class="selection-table">
						<table>
							<thead>
								<tr>
									<th>Select</th>
									<th>Username</th>
									<th>User Type</th>
									<th>Branch</th>
									<th>Approval Limit</th>
								</tr>
							</thead>
							<tbody>
								{#if filteredUsers.length > 0}
									{#each filteredUsers as user}
										<tr
											class:selected={selectedCoUserId === user.id}
											on:click={() => selectUser(user)}
										>
											<td>
												<input
													type="radio"
													name="user"
													checked={selectedCoUserId === user.id}
													on:change={() => selectUser(user)}
												/>
											</td>
											<td>{user.username}</td>
											<td>
												<span class="badge">{user.user_type}</span>
											</td>
											<td>
												{#if user.user_type === 'global'}
													<span class="badge-global">Global</span>
												{:else}
													{branches.find((b) => b.id === user.branch_id)?.name_en || '-'}
												{/if}
											</td>
										</tr>
									{/each}
								{:else}
									<tr>
										<td colspan="4" class="no-data-message">No users found</td>
									</tr>
								{/if}
							</tbody>
						</table>
					</div>
				</div>
			</div>
		{/if}

		<!-- Step 3: Bill Details -->
		{#if currentStep === 3}
			<div class="step-content">
				<h3 class="step-title">Enter Bill Details and Payment Information</h3>

				<!-- Bill Type Selection -->
				<div class="form-group">
					<label for="billType">Bill Type *</label>
					<select id="billType" class="form-select" bind:value={billType}>
						<option value="no_bill">No Bill</option>
						<option value="vat_applicable">VAT-Applicable Bill</option>
						<option value="no_vat">No-VAT Bill</option>
					</select>
				</div>

				<!-- Conditional Bill Fields -->
				{#if billType === 'vat_applicable' || billType === 'no_vat'}
					<div class="conditional-fields">
						<div class="form-row">
							<div class="form-group">
								<label for="billNumber">Bill Number *</label>
								<input
									id="billNumber"
									type="text"
									class="form-input"
									bind:value={billNumber}
									placeholder="Enter bill number"
								/>
							</div>

							<div class="form-group">
								<label for="billDate">Bill Date *</label>
								<input id="billDate" type="date" class="form-input" bind:value={billDate} />
							</div>
						</div>

						<!-- Bill File Upload -->
						<div class="form-group">
							<label for="billFile">Upload Bill *</label>
							<input
								id="billFile"
								type="file"
								class="form-input"
								accept="image/*,.pdf"
								on:change={handleBillFileChange}
							/>
						{#if billFileName}
							<div class="file-info">📄 {billFileName}</div>
						{/if}
						<p class="field-hint">Supported: Images (JPEG, PNG, GIF, WebP) or PDF. Max 50MB</p>
					</div>
				</div>
			{/if}				<!-- Payment Method -->
				<div class="form-group">
					<label for="paymentMethod">Payment Method *</label>
					<select id="paymentMethod" class="form-select" bind:value={paymentMethod}>
						{#each paymentMethods as method}
							<option value={method.value}>
								{method.label} {method.creditDays > 0 ? `(${method.creditDays} days)` : ''}
							</option>
						{/each}
					</select>
				</div>

				<!-- Credit Period (for credit payment methods) -->
				{#if paymentMethod.includes('credit')}
					<div class="conditional-fields">
						<div class="form-group">
							<label for="creditPeriod">Credit Period (Days) *</label>
							<input
								id="creditPeriod"
								type="number"
								class="form-input"
								bind:value={creditPeriod}
								placeholder="Enter credit period in days"
								min="1"
							/>
							<p class="field-hint">Number of days until payment is due</p>
						</div>
					</div>
				{/if}

				<!-- Bank Details (Optional) -->
				<div class="form-group">
					<label for="bankName">Bank Name (Optional)</label>
					<input
						id="bankName"
						type="text"
						class="form-input"
						bind:value={bankName}
						placeholder="Enter bank name"
					/>
				</div>

				<div class="form-group">
					<label for="iban">IBAN (Optional)</label>
					<input
						id="iban"
						type="text"
						class="form-input"
						bind:value={iban}
						placeholder="Enter IBAN"
					/>
				</div>

				<!-- Due Date (Auto-calculated) -->
				{#if dueDate}
					<div class="form-group">
						<label for="dueDate">Due Date (Auto-calculated)</label>
						<input id="dueDate" type="date" class="form-input" bind:value={dueDate} readonly />
					</div>
				{/if}

				<!-- Amount -->
				<div class="form-group">
					<label for="amount">Amount (SAR) *</label>
					<input
						id="amount"
						type="number"
						class="form-input amount-input-large"
						bind:value={amount}
						placeholder="0.00"
						step="0.01"
						min="0"
					/>
				</div>

				<!-- Description -->
				<div class="form-group">
					<label for="description">Description / Notes</label>
					<textarea
						id="description"
						class="form-textarea"
						bind:value={description}
						placeholder="Enter any additional details..."
						rows="4"
					></textarea>
				</div>

				<!-- Approver Selection (Required for all schedules) -->
				<div class="form-group approver-section">
					<label for="approverSearch">Select Approver * (Required)</label>
					<p class="field-hint approval-hint">⚠️ This schedule will require approval before posting to the expense scheduler.</p>						<input
							id="approverSearch"
							type="text"
							class="form-input"
							placeholder="Search approvers by username..."
							bind:value={approverSearchQuery}
							on:input={handleApproverSearch}
						/>

						{#if selectedApproverId}
							<div class="selected-info">
								✓ Selected Approver: <strong>{selectedApproverName}</strong>
							</div>
						{/if}

						<div class="selection-table">
							<table>
								<thead>
									<tr>
										<th>Select</th>
										<th>Username</th>
										<th>User Type</th>
										<th>Branch</th>
										<th>Approval Limit</th>
									</tr>
								</thead>
								<tbody>
									{#if filteredApprovers.length > 0}
										{#each filteredApprovers as approver}
											{@const billAmount = parseFloat(amount) || 0}
											{@const isOverLimit = billAmount > 0 && approver.approval_amount_limit > 0 && approver.approval_amount_limit < billAmount}
											{#if !isOverLimit}
											<tr
												class:selected={selectedApproverId === approver.id}
												on:click={() => selectApprover(approver)}
											>
												<td>
													<input
														type="radio"
														name="approver"
														checked={selectedApproverId === approver.id}
														on:change={() => selectApprover(approver)}
													/>
												</td>
												<td>{approver.username}</td>
												<td>
													<span class="badge">{approver.user_type}</span>
												</td>
												<td>
													{#if approver.user_type === 'global'}
														<span class="badge-global">Global</span>
													{:else}
														{branches.find((b) => b.id === approver.branch_id)?.name_en || '-'}
													{/if}
												</td>
												<td>
													{#if approver.approval_amount_limit && approver.approval_amount_limit > 0}
														{approver.approval_amount_limit.toLocaleString()} SAR
													{:else}
														<span class="badge-unlimited">Unlimited</span>
													{/if}
												</td>
											</tr>
											{/if}
										{/each}
									{:else}
										<tr>
											<td colspan="5" class="no-data-message">No approvers found</td>
										</tr>
									{/if}
								</tbody>
							</table>
						</div>
					</div>

				<!-- Success Message -->
				{#if successMessage}
					<div class="success-message">
						✓ {successMessage}
					</div>
					
					<!-- WhatsApp Share Button -->
					{#if showWhatsAppButton}
						<div class="action-buttons">
							<button class="btn-whatsapp" on:click={shareToWhatsApp}>
								<span class="whatsapp-icon">📱</span>
								Share via WhatsApp
							</button>
							<button class="btn-new-schedule" on:click={resetForm}>
								<span>➕</span>
								New Schedule
							</button>
						</div>
					{/if}
				{/if}
			</div>
		{/if}

		<!-- Navigation Buttons -->
		<div class="nav-buttons">
			{#if currentStep > 1}
				<button class="btn-prev" on:click={previousStep}>← Previous</button>
			{/if}

			{#if currentStep < totalSteps}
				<button class="btn-next" on:click={nextStep}>Next →</button>
			{:else}
				<button class="btn-save" on:click={saveScheduler} disabled={saving || uploading}>
					{#if saving || uploading}
						Submitting...
					{:else if selectedRequestId}
						✅ Post to Expense Scheduler
					{:else}
						📤 Submit for Approval
					{/if}
				</button>
			{/if}
		</div>
	</div>
</div>

<style>
	.single-bill-scheduling {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 1.5rem;
	}

	.title {
		font-size: 1.75rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 0.5rem 0;
	}

	.subtitle {
		font-size: 1rem;
		color: #64748b;
		margin: 0;
	}

	/* Progress Steps */
	.progress-steps {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
	}

	.step-number {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: #e2e8f0;
		color: #64748b;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 1rem;
		transition: all 0.3s ease;
	}

	.step.active .step-number {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.step.completed .step-number {
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 0.875rem;
		color: #64748b;
		font-weight: 500;
	}

	.step.active .step-label {
		color: #1e293b;
		font-weight: 600;
	}

	.step-line {
		width: 80px;
		height: 2px;
		background: #e2e8f0;
		margin: 0 1rem;
		transition: all 0.3s ease;
	}

	.step-line.completed {
		background: #10b981;
	}

	/* Content */
	.content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 2rem;
		min-height: 500px;
	}

	.step-content {
		animation: fadeIn 0.3s ease;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.step-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 1.5rem 0;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid #f1f5f9;
	}

	/* Form Elements */
	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	label {
		display: block;
		font-weight: 600;
		color: #334155;
		margin-bottom: 0.5rem;
		font-size: 0.9rem;
	}

	.form-input,
	.form-select,
	.form-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		font-size: 0.95rem;
		transition: all 0.2s ease;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.form-textarea {
		resize: vertical;
		font-family: inherit;
	}

	.amount-input-large {
		font-size: 1.5rem;
		font-weight: 600;
		text-align: right;
		color: #667eea;
	}

	.field-hint {
		font-size: 0.8rem;
		color: #64748b;
		margin-top: 0.25rem;
		font-style: italic;
	}

	.approval-hint {
		background: #fef3c7;
		border: 1px solid #f59e0b;
		color: #92400e;
		padding: 0.75rem;
		border-radius: 6px;
		font-weight: 600;
		margin-bottom: 0.75rem;
		font-style: normal;
	}

	.approver-section {
		background: #fffbeb;
		border: 2px solid #fbbf24;
		padding: 1.5rem;
		border-radius: 12px;
		margin-top: 2rem;
	}

	.file-info {
		margin-top: 0.5rem;
		padding: 0.5rem;
		background: #f1f5f9;
		border-radius: 4px;
		font-size: 0.875rem;
		color: #475569;
	}

	.conditional-fields {
		padding: 1rem;
		background: #f8fafc;
		border-radius: 8px;
		margin-bottom: 1rem;
	}

	.filter-controls {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 0.5rem;
	}

	.date-filter-select {
		width: 180px;
		flex-shrink: 0;
	}

	.date-range-inputs {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
		padding: 0.75rem;
		background: #f8fafc;
		border-radius: 6px;
	}

	.date-range-inputs input {
		flex: 1;
		margin-bottom: 0;
	}

	.date-range-separator {
		color: #64748b;
		font-weight: 600;
		padding: 0 0.5rem;
	}

	.date-cell {
		font-size: 0.85rem;
		color: #64748b;
		white-space: nowrap;
	}

	/* Selection Tables */
	.selection-table {
		max-height: 400px;
		overflow-y: auto;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		margin-top: 0.5rem;
	}

	.selection-table table {
		width: 100%;
		border-collapse: collapse;
	}

	.selection-table thead {
		position: sticky;
		top: 0;
		background: #f8fafc;
		z-index: 1;
	}

	.selection-table th {
		padding: 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #475569;
		border-bottom: 2px solid #e2e8f0;
		font-size: 0.875rem;
	}

	.selection-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #f1f5f9;
	}

	.selection-table tbody tr {
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.selection-table tbody tr:hover {
		background: #f8fafc;
	}

	.selection-table tbody tr.selected {
		background: #ede9fe;
	}

	.arabic {
		direction: rtl;
		font-family: 'Arial', sans-serif;
	}

	.selected-info {
		padding: 0.75rem;
		background: #f0fdf4;
		border: 1px solid #86efac;
		border-radius: 6px;
		color: #166534;
		margin: 0.5rem 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.btn-clear {
		padding: 0.25rem 0.75rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s ease;
	}

	.btn-clear:hover {
		background: #dc2626;
	}

	.badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #e0e7ff;
		color: #3730a3;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: capitalize;
	}

	.parent-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #e0e7ff;
		color: #3730a3;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.parent-category-cell {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}

	.parent-category-cell .parent-badge {
		width: fit-content;
	}

	.parent-category-cell .parent-badge.arabic {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-global {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #fef3c7;
		color: #92400e;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.badge-unlimited {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: linear-gradient(135deg, #a855f7, #ec4899);
		color: white;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 700;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	.no-data-message {
		text-align: center;
		color: #94a3b8;
		padding: 2rem !important;
		font-style: italic;
	}

	/* Navigation Buttons */
	.nav-buttons {
		display: flex;
		justify-content: space-between;
		margin-top: 2rem;
		padding-top: 1.5rem;
		border-top: 2px solid #f1f5f9;
	}

	.btn-prev,
	.btn-next,
	.btn-save {
		padding: 0.75rem 2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-prev {
		background: #f1f5f9;
		color: #475569;
	}

	.btn-prev:hover {
		background: #e2e8f0;
	}

	.btn-next {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		margin-left: auto;
	}

	.btn-next:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
	}

	.btn-save {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		margin-left: auto;
	}

	.btn-save:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.btn-save:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.success-message {
		padding: 1rem;
		background: #d1fae5;
		border: 1px solid #10b981;
		border-radius: 8px;
		color: #065f46;
		font-weight: 600;
		text-align: center;
		animation: fadeIn 0.3s ease;
	}

	.action-buttons {
		margin-top: 1rem;
		display: flex;
		gap: 0.75rem;
	}

	.btn-whatsapp {
		flex: 1;
		padding: 0.875rem 1.5rem;
		background: linear-gradient(135deg, #25d366 0%, #128c7e 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		box-shadow: 0 2px 8px rgba(37, 211, 102, 0.3);
	}

	.btn-whatsapp:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(37, 211, 102, 0.4);
	}

	.btn-whatsapp:active {
		transform: translateY(0);
	}

	.whatsapp-icon {
		font-size: 1.25rem;
	}

	.btn-new-schedule {
		flex: 1;
		padding: 0.875rem 1.5rem;
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.btn-new-schedule:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.btn-new-schedule:active {
		transform: translateY(0);
	}

	/* Request Amount Info */
	.request-amount-info {
		margin-top: 1.5rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #bae6fd;
		border-radius: 12px;
	}

	.info-card {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem;
		background: white;
		border-radius: 6px;
	}

	.info-row.balance-row {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		border: 2px solid #fbbf24;
		font-weight: 700;
		font-size: 1.1rem;
	}

	.info-row.balance-row .info-value.warning {
		background: linear-gradient(135deg, #fecaca 0%, #f87171 100%);
		border: 2px solid #ef4444;
		color: #dc2626;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
	}

	.info-value.used-amount {
		color: #dc2626;
		font-weight: 600;
	}

	.info-value.available-balance {
		color: #059669;
		font-weight: 600;
	}

	.overspend-warning {
		font-size: 0.8rem;
		background: #fee2e2;
		color: #dc2626;
		padding: 0.1rem 0.3rem;
		border-radius: 3px;
		margin-left: 0.5rem;
	}

	.info-label {
		color: #475569;
		font-weight: 600;
	}

	.info-value {
		color: #0f172a;
		font-weight: 700;
		font-size: 1.05rem;
	}

	.info-value.negative {
		color: #dc2626;
	}

	.info-value.positive {
		color: #16a34a;
	}

	.info-note {
		margin-top: 0.75rem;
		color: #64748b;
		font-size: 0.875rem;
		font-style: italic;
		text-align: center;
	}

	/* Balance status colors */
	.text-success {
		color: #16a34a;
		font-weight: 600;
	}

	.text-warning {
		color: #d97706;
		font-weight: 600;
	}

	.text-danger {
		color: #dc2626;
		font-weight: 600;
	}
</style>
