<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';

	// Step management
	let currentStep = 1;
	const totalSteps = 3; // Step 1: Branch & Category, Step 2: Request, Step 3: Payment Details

	// Data arrays
	let branches = [];
	let categories = [];
	let approvedRequests = [];
	let filteredCategories = [];
	let filteredRequests = [];
	let approvers = [];
	let filteredApprovers = [];

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
	let requestSearchQuery = '';
	let dateFilter = 'all'; // 'all', 'today', 'yesterday', 'range'
	let dateRangeStart = '';
	let dateRangeEnd = '';

	// Step 3 data
	let paymentMethod = 'cash'; // Only 'cash' or 'bank'
	let amount = '';
	let description = '';
	let recurringType = ''; // 'daily', 'weekly', 'monthly_date', 'monthly_day', 'yearly', 'half_yearly', 'quarterly', 'custom'
	
	// Approver selection
	let selectedApproverId = '';
	let selectedApproverName = '';
	let approverSearchQuery = '';
	
	// Recurring schedule fields
	let untilDate = ''; // For daily, weekly
	let weekday = ''; // For weekly
	let monthPosition = ''; // For monthly_date: 'start', 'middle', 'end'
	let untilMonth = ''; // For monthly options
	let dayOfMonth = ''; // For monthly_day
	let recurringMonth = ''; // For yearly, half-yearly, quarterly
	let recurringDay = ''; // For yearly, half-yearly, quarterly
	let untilYear = ''; // For yearly, half-yearly, quarterly
	let customDates = []; // For custom dates
	let showCustomDateModal = false;

	// Payment methods - only cash and bank
	const paymentMethods = [
		{ value: 'cash', label: 'Cash - نقدي' },
		{ value: 'bank', label: 'Bank - بنكي' }
	];

	// Weekdays for weekly recurring
	const weekdays = [
		{ value: '0', label: 'Sunday - الأحد' },
		{ value: '1', label: 'Monday - الاثنين' },
		{ value: '2', label: 'Tuesday - الثلاثاء' },
		{ value: '3', label: 'Wednesday - الأربعاء' },
		{ value: '4', label: 'Thursday - الخميس' },
		{ value: '5', label: 'Friday - الجمعة' },
		{ value: '6', label: 'Saturday - السبت' }
	];

	// Month positions
	const monthPositions = [
		{ value: 'start', label: 'Start of Month - بداية الشهر' },
		{ value: 'middle', label: 'Middle of Month - منتصف الشهر' },
		{ value: 'end', label: 'End of Month - نهاية الشهر' }
	];

	// Months
	const months = [
		{ value: '1', label: 'January - يناير' },
		{ value: '2', label: 'February - فبراير' },
		{ value: '3', label: 'March - مارس' },
		{ value: '4', label: 'April - أبريل' },
		{ value: '5', label: 'May - مايو' },
		{ value: '6', label: 'June - يونيو' },
		{ value: '7', label: 'July - يوليو' },
		{ value: '8', label: 'August - أغسطس' },
		{ value: '9', label: 'September - سبتمبر' },
		{ value: '10', label: 'October - أكتوبر' },
		{ value: '11', label: 'November - نوفمبر' },
		{ value: '12', label: 'December - ديسمبر' }
	];

	// Reactive variable to check if all mandatory fields are filled
	$: isFormValid = (() => {
		// Check basic required fields
		if (!amount || parseFloat(amount) <= 0) return false;
		if (!description || description.trim() === '') return false;
		if (!recurringType) return false;
		
		// Require approver only if no approved request is selected
		if (!selectedRequestId && !selectedApproverId) return false;
		
		// Validate based on recurring type
		if (recurringType === 'daily' && !untilDate) return false;
		if (recurringType === 'weekly' && (!untilDate || !weekday)) return false;
		if (recurringType === 'monthly_date' && (!monthPosition || !untilMonth)) return false;
		if (recurringType === 'monthly_day' && (!dayOfMonth || !untilMonth)) return false;
		if ((recurringType === 'yearly' || recurringType === 'half_yearly' || recurringType === 'quarterly') && 
			(!recurringMonth || !recurringDay || !untilYear)) return false;
		if (recurringType === 'custom' && customDates.length === 0) return false;
		
		return true;
	})();

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

			// Load approvers (users with can_approve_payments = true)
			const { data: approversData, error: approversError } = await supabaseAdmin
				.from('users')
				.select(`
					id,
					username,
					employee_id,
					branch_id,
					user_type,
					status,
					can_approve_payments,
					approval_amount_limit,
					hr_employees (
						name
					)
				`)
				.eq('status', 'active')
				.eq('can_approve_payments', true)
				.order('username');

			if (approversError) throw approversError;
			approvers = approversData || [];
			filteredApprovers = approvers;
		} catch (error) {
			console.error('Error loading initial data:', error);
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

	function selectCategory(category) {
		selectedCategoryId = category.id;
		selectedCategoryNameEn = category.name_en;
		selectedCategoryNameAr = category.name_ar;
	}

	function selectRequest(request) {
		selectedRequestId = request.id;
		selectedRequestNumber = request.requisition_number;
		selectedRequestAmount = parseFloat(request.amount || 0);
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

	function handleApproverSearch() {
		if (!approverSearchQuery.trim()) {
			filteredApprovers = approvers;
			return;
		}

		const query = approverSearchQuery.toLowerCase();
		filteredApprovers = approvers.filter((user) =>
			user.username?.toLowerCase().includes(query) ||
			user.employee_id?.toLowerCase().includes(query) ||
			user.hr_employees?.name?.toLowerCase().includes(query) ||
			user.id?.toLowerCase().includes(query)
		);
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

	function validateStep3() {
		if (!amount || parseFloat(amount) <= 0) {
			alert('Please enter a valid amount');
			return false;
		}
		
		if (!description || description.trim() === '') {
			alert('Please enter a description');
			return false;
		}
		
		// Require approver only if no approved request is selected
		if (!selectedRequestId && !selectedApproverId) {
			alert('Please select an approver (required when no approved request is linked)');
			return false;
		}
		
		if (!recurringType) {
			alert('Please select a recurring schedule type');
			return false;
		}

		// Validate based on recurring type
		if (recurringType === 'daily' && !untilDate) {
			alert('Please select "Until which date" for daily recurring');
			return false;
		}
		if (recurringType === 'weekly' && (!untilDate || !weekday)) {
			alert('Please select both "Until which date" and "Weekday" for weekly recurring');
			return false;
		}
		if (recurringType === 'monthly_date' && (!monthPosition || !untilMonth)) {
			alert('Please select month position and "Until which month" for monthly date recurring');
			return false;
		}
		if (recurringType === 'monthly_day' && (!dayOfMonth || !untilMonth)) {
			alert('Please select day and "Until which month" for monthly day recurring');
			return false;
		}
		if ((recurringType === 'yearly' || recurringType === 'half_yearly' || recurringType === 'quarterly') && 
			(!recurringMonth || !recurringDay || !untilYear)) {
			alert('Please fill in all required fields for the selected recurring type');
			return false;
		}
		if (recurringType === 'custom' && customDates.length === 0) {
			alert('Please select at least one custom date');
			return false;
		}

		return true;
	}

	async function nextStep() {
		if (currentStep === 1) {
			if (!validateStep1()) return;
			await loadApprovedRequests();
		}
		if (currentStep === 2) {
			// Step 2 validation is optional (request selection)
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

	function formatDateTime(dateString) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		return date.toLocaleString('en-US', {
			year: 'numeric',
			month: '2-digit',
			day: '2-digit',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function openCustomDateModal() {
		showCustomDateModal = true;
	}

	function closeCustomDateModal() {
		showCustomDateModal = false;
	}

	function addCustomDate(date) {
		if (!customDates.includes(date)) {
			customDates = [...customDates, date];
		}
	}

	function removeCustomDate(date) {
		customDates = customDates.filter(d => d !== date);
	}

	async function saveRecurringSchedule() {
		if (!validateStep3()) return;

		try {
			// Check if a pre-approved requisition is selected
			const hasApprovedRequisition = !!selectedRequestId;

			if (hasApprovedRequisition) {
				// Save directly to expense_scheduler
				await saveToExpenseScheduler();
			} else {
				// Save to non_approved_payment_scheduler and send notification
				await saveToNonApprovedScheduler();
			}
			
		} catch (error) {
			console.error('Error saving recurring schedule:', error);
			alert('❌ Error saving recurring schedule. Please try again.\n\nError: ' + error.message);
		}
	}

	async function saveToExpenseScheduler() {
		const scheduleData = {
			branch_id: parseInt(selectedBranchId),
			branch_name: selectedBranchName,
			expense_category_id: selectedCategoryId,
			expense_category_name_en: selectedCategoryNameEn,
			expense_category_name_ar: selectedCategoryNameAr,
			requisition_id: selectedRequestId,
			requisition_number: selectedRequestNumber,
			co_user_id: null,
			co_user_name: null,
			payment_method: paymentMethod,
			amount: parseFloat(amount),
			description: description || null,
			bill_type: 'no_bill',
			status: 'pending',
			is_paid: false,
			schedule_type: 'recurring',
			recurring_type: recurringType,
			approver_id: selectedApproverId,
			approver_name: selectedApproverName,
			recurring_metadata: {
				until_date: untilDate || null,
				weekday: weekday ? parseInt(weekday) : null,
				month_position: monthPosition || null,
				until_month: untilMonth || null,
				day_of_month: dayOfMonth ? parseInt(dayOfMonth) : null,
				recurring_month: recurringMonth ? parseInt(recurringMonth) : null,
				recurring_day: recurringDay ? parseInt(recurringDay) : null,
				until_year: untilYear ? parseInt(untilYear) : null,
				custom_dates: customDates.length > 0 ? customDates : null
			},
			created_by: $currentUser.id
		};

		console.log('Saving to expense_scheduler (with approved requisition):', scheduleData);

		const { data, error } = await supabaseAdmin
			.from('expense_scheduler')
			.insert([scheduleData])
			.select()
			.single();

		if (error) throw error;

		console.log('Recurring schedule saved to expense_scheduler:', data);
		
		// Generate all future occurrences immediately
		try {
			const { data: occurrencesData, error: occurrencesError } = await supabaseAdmin
				.rpc('generate_recurring_occurrences', {
					p_parent_id: data.id,
					p_source_table: 'expense_scheduler'
				});
			
			if (occurrencesError) throw occurrencesError;
			
			console.log('✅ Generated occurrences:', occurrencesData);
			alert(`✅ Recurring schedule saved successfully!\n\nSchedule ID: ${data.id}\nLinked to approved requisition: ${selectedRequestNumber}\n\nGenerated ${occurrencesData[0]?.occurrence_count || 0} occurrences`);
		} catch (occError) {
			console.error('⚠️ Error generating occurrences:', occError);
			alert(`✅ Recurring schedule saved but failed to generate occurrences.\n\nSchedule ID: ${data.id}\nError: ${occError.message}`);
		}
		
		resetForm();
	}

	async function saveToNonApprovedScheduler() {
		const scheduleData = {
			schedule_type: 'recurring',
			branch_id: parseInt(selectedBranchId),
			branch_name: selectedBranchName,
			expense_category_id: selectedCategoryId,
			expense_category_name_en: selectedCategoryNameEn,
			expense_category_name_ar: selectedCategoryNameAr,
			co_user_id: null,
			co_user_name: null,
			payment_method: paymentMethod,
			amount: parseFloat(amount),
			description: description || null,
			bill_type: 'no_bill',
			recurring_type: recurringType,
			recurring_metadata: {
				until_date: untilDate || null,
				weekday: weekday ? parseInt(weekday) : null,
				month_position: monthPosition || null,
				until_month: untilMonth || null,
				day_of_month: dayOfMonth ? parseInt(dayOfMonth) : null,
				recurring_month: recurringMonth ? parseInt(recurringMonth) : null,
				recurring_day: recurringDay ? parseInt(recurringDay) : null,
				until_year: untilYear ? parseInt(untilYear) : null,
				custom_dates: customDates.length > 0 ? customDates : null
			},
			approver_id: selectedApproverId,
			approver_name: selectedApproverName,
			approval_status: 'pending',
			created_by: $currentUser.id
		};

		console.log('Saving to non_approved_payment_scheduler (awaiting approval):', scheduleData);

		const { data, error } = await supabaseAdmin
			.from('non_approved_payment_scheduler')
			.insert([scheduleData])
			.select()
			.single();

		if (error) throw error;

		console.log('Saved to non_approved_payment_scheduler:', data);

		// Generate all future occurrences immediately
		try {
			const { data: occurrencesData, error: occurrencesError } = await supabaseAdmin
				.rpc('generate_recurring_occurrences', {
					p_parent_id: data.id,
					p_source_table: 'non_approved_payment_scheduler'
				});
			
			if (occurrencesError) throw occurrencesError;
			
			console.log('✅ Generated occurrences:', occurrencesData);
		} catch (occError) {
			console.error('⚠️ Error generating occurrences:', occError);
			// Don't fail the whole operation
		}

		// Send notification to approver
		try {
			await notificationService.createNotification({
				title: 'Recurring Payment Schedule Approval Required',
				message: `A new recurring expense schedule requires your approval.\n\nBranch: ${selectedBranchName}\nCategory: ${selectedCategoryNameEn}\nAmount: ${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nRecurring Type: ${recurringType}\nSubmitted by: ${$currentUser?.username}`,
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

		// Get occurrence count from the generated occurrences
		const { count: occurrenceCount } = await supabaseAdmin
			.from('non_approved_payment_scheduler')
			.select('*', { count: 'exact', head: true })
			.eq('schedule_type', 'single_bill')
			.eq('recurring_metadata->>parent_schedule_id', data.id.toString());

		alert(`✅ Recurring schedule submitted for approval!\n\nSchedule ID: ${data.id}\nApprover: ${selectedApproverName}\nGenerated ${occurrenceCount || 0} occurrences\n\nEach occurrence will require approval before payment.`);
		
		resetForm();
	}

	function resetForm() {
		// Reset to step 1
		currentStep = 1;
		
		// Clear all form data
		selectedBranchId = '';
		selectedBranchName = '';
		selectedCategoryId = '';
		selectedCategoryNameEn = '';
		selectedCategoryNameAr = '';
		categorySearchQuery = '';
		
		selectedRequestId = '';
		selectedRequestNumber = '';
		selectedRequestAmount = 0;
		selectedRequestRemainingBalance = 0;
		selectedRequestUsedAmount = 0;
		requestSearchQuery = '';
		dateFilter = 'all';
		dateRangeStart = '';
		dateRangeEnd = '';
		
		paymentMethod = 'cash';
		amount = '';
		description = '';
		recurringType = '';
		selectedApproverId = '';
		selectedApproverName = '';
		approverSearchQuery = '';
		untilDate = '';
		weekday = '';
		monthPosition = '';
		untilMonth = '';
		dayOfMonth = '';
		recurringMonth = '';
		recurringDay = '';
		untilYear = '';
		customDates = [];
	}

</script>

<div class="recurring-expense-scheduler">
	<!-- Progress Indicator -->
	<div class="progress-container">
		<div class="progress-bar">
			{#each Array(totalSteps) as _, index}
				<div class="progress-step" class:active={currentStep >= index + 1}>
					<div class="step-number">{index + 1}</div>
					<div class="step-label">
						{#if index === 0}Branch & Category
						{:else if index === 1}Approved Request
						{:else if index === 2}Payment & Schedule{/if}
					</div>
				</div>
				{#if index < totalSteps - 1}
					<div class="progress-line" class:active={currentStep > index + 1}></div>
				{/if}
			{/each}
		</div>
	</div>

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

	<!-- Step 2: Request Selection (No C/O User) -->
	{#if currentStep === 2}
		<div class="step-content">
			<h3 class="step-title">Select Approved Request</h3>

			<!-- Request Selection (Optional) -->
			<div class="form-group">
				<label for="requestSearch">Link to Approved Request (Optional)</label>
				
				<!-- Search and Date Filter Row -->
				<div class="filter-controls">
					<input
						id="requestSearch"
						type="text"
						class="form-input"
						placeholder="Search by request number, requester, approver, or amount..."
						bind:value={requestSearchQuery}
						on:input={handleRequestSearch}
						style="flex: 1;"
					/>
					
					<select 
						class="form-select date-filter-select" 
						bind:value={dateFilter}
						on:change={handleDateFilterChange}
					>
						<option value="all">All Dates</option>
						<option value="today">Today</option>
						<option value="yesterday">Yesterday</option>
						<option value="range">Date Range</option>
					</select>
				</div>

				<!-- Date Range Inputs -->
				{#if dateFilter === 'range'}
					<div class="date-range-inputs">
						<input
							type="date"
							class="form-input"
							placeholder="Start Date"
							bind:value={dateRangeStart}
							on:change={handleDateFilterChange}
						/>
						<span class="date-range-separator">to</span>
						<input
							type="date"
							class="form-input"
							placeholder="End Date"
							bind:value={dateRangeEnd}
							on:change={handleDateFilterChange}
						/>
					</div>
				{/if}

				{#if selectedRequestId}
					<div class="selected-info">
						✓ Selected: <strong>{selectedRequestNumber}</strong>
						<button class="btn-clear" on:click={clearRequestSelection}>Clear</button>
					</div>
				{/if}

				<div class="selection-table">
					<table>
						<thead>
							<tr>
								<th>Select</th>
								<th>Request Number</th>
								<th>Requester</th>
								<th>Approver</th>
								<th>Original Amount</th>
								<th>Remaining Balance</th>
								<th>Category</th>
								<th>Generated Date</th>
							</tr>
						</thead>
						<tbody>
							{#if filteredRequests.length > 0}
								{#each filteredRequests as request}
									<tr
										class:selected={selectedRequestId === request.id}
										on:click={() => selectRequest(request)}
									>
										<td>
											<input
												type="radio"
												name="request"
												checked={selectedRequestId === request.id}
												on:change={() => selectRequest(request)}
											/>
										</td>
										<td>{request.requisition_number}</td>
										<td>{request.requester_name}</td>
										<td>{request.approver_name || '-'}</td>
										<td>{request.amount} SAR</td>
										<td>
											<span class:text-success={parseFloat(request.remaining_balance || request.amount) > 0}
												  class:text-warning={parseFloat(request.remaining_balance || request.amount) === 0}
												  class:text-danger={parseFloat(request.remaining_balance || request.amount) < 0}>
												{parseFloat(request.remaining_balance || request.amount).toFixed(2)} SAR
											</span>
										</td>
										<td>{request.expense_category_name_en}</td>
										<td class="date-cell">{formatDateTime(request.created_at)}</td>
									</tr>
								{/each}
							{:else}
								<tr>
									<td colspan="8" class="no-data-message">
										{#if dateFilter !== 'all'}
											No approved requests found for the selected date filter
										{:else}
											No approved requests found for this branch
										{/if}
									</td>
								</tr>
							{/if}
						</tbody>
					</table>
				</div>
			</div>
		</div>
	{/if}

	<!-- Step 3: Payment Details & Recurring Schedule -->
	{#if currentStep === 3}
		<div class="step-content">
			<h3 class="step-title">Payment Details and Recurring Schedule</h3>

			<!-- Payment Method -->
			<div class="form-group">
				<label for="paymentMethod">Payment Method *</label>
				<select id="paymentMethod" class="form-select" bind:value={paymentMethod}>
					{#each paymentMethods as method}
						<option value={method.value}>{method.label}</option>
					{/each}
				</select>
			</div>

			<!-- Amount -->
			<div class="form-group">
				<label for="amount">Amount (SAR) *</label>
				<input
					id="amount"
					type="number"
					class="form-input amount-input-large"
					placeholder="0.00"
					bind:value={amount}
					step="0.01"
					min="0"
				/>
			</div>

			<!-- Description -->
			<div class="form-group">
				<label for="description">Description *</label>
				<textarea
					id="description"
					class="form-textarea"
					placeholder="Enter description..."
					bind:value={description}
					rows="3"
					required
				></textarea>
			</div>

			<!-- Approver Selection (only show if no approved request is selected) -->
			{#if !selectedRequestId}
				<div class="form-group approver-section">
					<label for="approverSearch">Select Approver * (Required for non-approved schedules)</label>
					<p class="field-hint approval-hint">⚠️ Since no approved request is selected, this schedule will require approval before posting to the expense scheduler.</p>
					
					<input
						id="approverSearch"
						type="text"
						class="form-input"
						placeholder="Search approvers by name, employee ID..."
						bind:value={approverSearchQuery}
						on:input={handleApproverSearch}
					/>

					{#if selectedApproverId}
						<div class="selected-info">
							✓ Selected: <strong>{selectedApproverName}</strong>
						</div>
					{/if}

					<div class="selection-table">
						<table>
							<thead>
								<tr>
									<th>Select</th>
									<th>Username</th>
									<th>Employee ID</th>
									<th>Employee Name</th>
									<th>Approval Limit</th>
								</tr>
							</thead>
							<tbody>
								{#if filteredApprovers.length > 0}
									{#each filteredApprovers as approver}
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
											<td>{approver.employee_id || '-'}</td>
											<td>{approver.hr_employees?.name || '-'}</td>
											<td>
												{#if approver.approval_amount_limit}
													{parseFloat(approver.approval_amount_limit).toLocaleString('en-US', { minimumFractionDigits: 2 })} SAR
												{:else}
													<span class="badge-unlimited">Unlimited</span>
												{/if}
											</td>
										</tr>
									{/each}
								{:else}
									<tr>
										<td colspan="5" class="no-data-message">No approvers found</td>
									</tr>
								{/if}
							</tbody>
						</table>
					</div>
					<p class="hint-text">
						ℹ️ An approval request will be sent to the selected approver 2 days before the recurring schedule occurs. 
						Notifications will be sent 2 days before the occurrence date.
					</p>
				</div>
			{/if}

			<!-- Recurring Type Selection -->
			<div class="form-group">
				<label for="recurringType">Recurring Schedule Type *</label>
				<select id="recurringType" class="form-select" bind:value={recurringType}>
					<option value="">-- Select Recurring Type --</option>
					<option value="daily">Daily - يومي</option>
					<option value="weekly">Weekly - أسبوعي</option>
					<option value="monthly_date">Specific Date of Every Month - تاريخ محدد من كل شهر</option>
					<option value="monthly_day">Specific Day of Every Month - يوم محدد من كل شهر</option>
					<option value="yearly">Yearly - سنوي</option>
					<option value="half_yearly">Half-Yearly - نصف سنوي</option>
					<option value="quarterly">Quarterly - ربع سنوي</option>
					<option value="custom">Custom Dates - تواريخ مخصصة</option>
				</select>
			</div>

			<!-- Daily Recurring Options -->
			{#if recurringType === 'daily'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">Daily Recurring Schedule</h4>
					<div class="form-group">
						<label for="untilDate">Until Which Date *</label>
						<input
							id="untilDate"
							type="date"
							class="form-input"
							bind:value={untilDate}
						/>
					</div>
				</div>
			{/if}

			<!-- Weekly Recurring Options -->
			{#if recurringType === 'weekly'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">Weekly Recurring Schedule</h4>
					<div class="form-row">
						<div class="form-group">
							<label for="weekday">Weekday *</label>
							<select id="weekday" class="form-select" bind:value={weekday}>
								<option value="">-- Select Weekday --</option>
								{#each weekdays as day}
									<option value={day.value}>{day.label}</option>
								{/each}
							</select>
						</div>
						<div class="form-group">
							<label for="untilDateWeekly">Until Which Date *</label>
							<input
								id="untilDateWeekly"
								type="date"
								class="form-input"
								bind:value={untilDate}
							/>
						</div>
					</div>
				</div>
			{/if}

			<!-- Monthly Date Recurring Options -->
			{#if recurringType === 'monthly_date'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">Monthly Date Recurring Schedule</h4>
					<div class="form-row">
						<div class="form-group">
							<label for="monthPosition">Month Position *</label>
							<select id="monthPosition" class="form-select" bind:value={monthPosition}>
								<option value="">-- Select Position --</option>
								{#each monthPositions as position}
									<option value={position.value}>{position.label}</option>
								{/each}
							</select>
						</div>
						<div class="form-group">
							<label for="untilMonth">Until Which Month *</label>
							<input
								id="untilMonth"
								type="month"
								class="form-input"
								bind:value={untilMonth}
							/>
						</div>
					</div>
				</div>
			{/if}

			<!-- Monthly Day Recurring Options -->
			{#if recurringType === 'monthly_day'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">Monthly Day Recurring Schedule</h4>
					<div class="form-row">
						<div class="form-group">
							<label for="dayOfMonth">Day of Month (1-31) *</label>
							<input
								id="dayOfMonth"
								type="number"
								class="form-input"
								placeholder="Enter day (1-31)"
								bind:value={dayOfMonth}
								min="1"
								max="31"
							/>
						</div>
						<div class="form-group">
							<label for="untilMonthDay">Until Which Month *</label>
							<input
								id="untilMonthDay"
								type="month"
								class="form-input"
								bind:value={untilMonth}
							/>
						</div>
					</div>
				</div>
			{/if}

			<!-- Yearly/Half-Yearly/Quarterly Recurring Options -->
			{#if recurringType === 'yearly' || recurringType === 'half_yearly' || recurringType === 'quarterly'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">
						{#if recurringType === 'yearly'}Yearly Recurring Schedule
						{:else if recurringType === 'half_yearly'}Half-Yearly Recurring Schedule
						{:else}Quarterly Recurring Schedule{/if}
					</h4>
					<div class="form-row">
						<div class="form-group">
							<label for="recurringMonth">Which Month *</label>
							<select id="recurringMonth" class="form-select" bind:value={recurringMonth}>
								<option value="">-- Select Month --</option>
								{#each months as month}
									<option value={month.value}>{month.label}</option>
								{/each}
							</select>
						</div>
						<div class="form-group">
							<label for="recurringDay">Which Date (1-31) *</label>
							<input
								id="recurringDay"
								type="number"
								class="form-input"
								placeholder="Enter date (1-31)"
								bind:value={recurringDay}
								min="1"
								max="31"
							/>
						</div>
					</div>
					<div class="form-group">
						<label for="untilYear">Until Which Year *</label>
						<input
							id="untilYear"
							type="number"
							class="form-input"
							placeholder="Enter year (e.g., 2026)"
							bind:value={untilYear}
							min={new Date().getFullYear()}
						/>
					</div>
				</div>
			{/if}

			<!-- Custom Dates Options -->
			{#if recurringType === 'custom'}
				<div class="recurring-options">
					<h4 class="recurring-subtitle">Custom Dates Recurring Schedule</h4>
					<div class="form-group">
						<label>Selected Dates ({customDates.length})</label>
						<button class="btn-add-date" on:click={openCustomDateModal}>
							+ Add Custom Dates
						</button>
						
						{#if customDates.length > 0}
							<div class="custom-dates-list">
								{#each customDates as date}
									<div class="custom-date-item">
										<span>{date}</span>
										<button class="btn-remove-date" on:click={() => removeCustomDate(date)}>×</button>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Custom Date Modal -->
	{#if showCustomDateModal}
		<div class="modal-overlay" on:click={closeCustomDateModal}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h3>Select Custom Dates</h3>
					<button class="btn-close" on:click={closeCustomDateModal}>×</button>
				</div>
				<div class="modal-body">
					<div class="form-group">
						<label for="customDatePicker">Pick Date</label>
						<input
							id="customDatePicker"
							type="date"
							class="form-input"
							on:change={(e) => {
								if (e.target.value) {
									addCustomDate(e.target.value);
									e.target.value = '';
								}
							}}
						/>
					</div>
					<p class="hint-text">Click on the date input to add multiple dates to your schedule.</p>
				</div>
				<div class="modal-footer">
					<button class="btn btn-primary" on:click={closeCustomDateModal}>Done</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Navigation Buttons -->
	<div class="navigation-buttons">
		{#if currentStep > 1}
			<button class="btn btn-secondary" on:click={previousStep}>← Previous</button>
		{/if}
		
		{#if currentStep < totalSteps}
			<button class="btn btn-primary" on:click={nextStep}>Next →</button>
		{:else}
			<button 
				class="btn btn-save" 
				on:click={saveRecurringSchedule}
				disabled={!isFormValid}
			>
				💾 Save Recurring Schedule
			</button>
		{/if}
	</div>
</div>

<style>
	.recurring-expense-scheduler {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Progress Bar */
	.progress-container {
		margin-bottom: 2rem;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		padding: 1.5rem;
	}

	.progress-bar {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.progress-step {
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

	.progress-step.active .step-number {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.step-label {
		font-size: 0.875rem;
		color: #64748b;
		font-weight: 500;
		text-align: center;
	}

	.progress-step.active .step-label {
		color: #1e293b;
		font-weight: 600;
	}

	.progress-line {
		width: 80px;
		height: 2px;
		background: #e2e8f0;
		margin: 0 1rem;
		transition: all 0.3s ease;
	}

	.progress-line.active {
		background: #10b981;
	}

	/* Content */
	.step-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 2rem;
		min-height: 500px;
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

	.parent-category-cell .parent-badge.arabic {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-unlimited {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #fef3c7;
		color: #92400e;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.no-data-message {
		text-align: center;
		color: #94a3b8;
		padding: 2rem !important;
		font-style: italic;
	}

	.date-cell {
		font-size: 0.85rem;
		color: #64748b;
		white-space: nowrap;
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

	/* Navigation Buttons */
	.navigation-buttons {
		display: flex;
		justify-content: space-between;
		margin-top: 2rem;
		gap: 1rem;
	}

	.btn {
		padding: 0.75rem 2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-secondary {
		background: #f1f5f9;
		color: #475569;
	}

	.btn-secondary:hover {
		background: #e2e8f0;
	}

	.btn-primary {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		margin-left: auto;
	}

	.btn-primary:hover {
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
		background: linear-gradient(135deg, #9ca3af 0%, #6b7280 100%);
		cursor: not-allowed;
		opacity: 0.6;
	}

	/* Recurring Options */
	.recurring-options {
		margin-top: 1.5rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #bae6fd;
		border-radius: 12px;
	}

	.recurring-subtitle {
		font-size: 1.1rem;
		font-weight: 600;
		color: #0c4a6e;
		margin: 0 0 1rem 0;
	}

	.hint-text {
		font-size: 0.875rem;
		color: #64748b;
		font-style: italic;
		margin-top: 0.5rem;
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

	/* Custom Dates */
	.btn-add-date {
		padding: 0.5rem 1rem;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		margin-top: 0.5rem;
	}

	.btn-add-date:hover {
		background: #5568d3;
		transform: translateY(-1px);
	}

	.custom-dates-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 1rem;
		padding: 1rem;
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.custom-date-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		background: #f0fdf4;
		border: 1px solid #86efac;
		border-radius: 6px;
		color: #166534;
		font-weight: 600;
	}

	.btn-remove-date {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 1rem;
		line-height: 1;
		transition: background 0.2s ease;
	}

	.btn-remove-date:hover {
		background: #dc2626;
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
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		padding: 1.5rem;
		border-bottom: 2px solid #f1f5f9;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.modal-header h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1e293b;
		margin: 0;
	}

	.btn-close {
		background: #f1f5f9;
		color: #475569;
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 1.5rem;
		line-height: 1;
		transition: all 0.2s ease;
	}

	.btn-close:hover {
		background: #e2e8f0;
		transform: rotate(90deg);
	}

	.modal-body {
		padding: 1.5rem;
		overflow-y: auto;
		flex: 1;
	}

	.modal-footer {
		padding: 1rem 1.5rem;
		border-top: 2px solid #f1f5f9;
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
	}
</style>
