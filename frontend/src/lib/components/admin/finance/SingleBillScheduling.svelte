<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

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
	let selectedCoUserId = '';
	let selectedCoUserName = '';
	let requestSearchQuery = '';
	let userSearchQuery = '';
	let dateFilter = 'all'; // 'all', 'today', 'yesterday', 'range'
	let dateRangeStart = '';
	let dateRangeEnd = '';

	// Reactive balance calculation
	$: balance = selectedRequestAmount > 0 && amount ? selectedRequestAmount - parseFloat(amount || 0) : 0;

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
		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	async function loadApprovedRequests() {
		if (!selectedBranchId) return;

		try {
			const { data, error } = await supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('status', 'approved')
				.order('created_at', { ascending: false });

			if (error) throw error;
			approvedRequests = data || [];
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

	function selectCategory(category) {
		selectedCategoryId = category.id;
		selectedCategoryNameEn = category.name_en;
		selectedCategoryNameAr = category.name_ar;
	}

	function selectRequest(request) {
		selectedRequestId = request.id;
		selectedRequestNumber = request.requisition_number;
		selectedRequestAmount = parseFloat(request.amount || 0);
	}

	function clearRequestSelection() {
		selectedRequestId = '';
		selectedRequestNumber = '';
		selectedRequestAmount = 0;
	}

	function selectUser(user) {
		selectedCoUserId = user.id;
		selectedCoUserName = user.username;
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
		if (!billDate || !paymentMethod) return;

		const selectedMethod = paymentMethods.find((m) => m.value === paymentMethod);
		if (!selectedMethod) return;

		const creditDays = selectedMethod.creditDays;
		const baseDate = new Date(billDate);
		baseDate.setDate(baseDate.getDate() + creditDays);

		dueDate = baseDate.toISOString().split('T')[0];
	}

	$: if (billDate && paymentMethod) {
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

			// Prepare data
			const schedulerData = {
				branch_id: parseInt(selectedBranchId),
				branch_name: selectedBranchName,
				expense_category_id: selectedCategoryId,
				expense_category_name_en: selectedCategoryNameEn,
				expense_category_name_ar: selectedCategoryNameAr,
				requisition_id: selectedRequestId || null,
				requisition_number: selectedRequestNumber || null,
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
				status: 'pending',
				is_paid: false,
				created_by: $currentUser.id
			};

			const { data, error } = await supabaseAdmin
				.from('expense_scheduler')
				.insert([schedulerData])
				.select()
				.single();

			if (error) throw error;

			successMessage = `Bill scheduled successfully! ID: ${data.id}`;
			
			// Reset form after 2 seconds
			setTimeout(() => {
				resetForm();
			}, 2000);
		} catch (error) {
			console.error('Error saving scheduler:', error);
			alert('Error saving bill schedule. Please try again.');
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
		selectedCoUserId = '';
		selectedCoUserName = '';
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
				<h3 class="step-title">Select Approved Request and C/O User</h3>

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
									<th>Amount</th>
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
											<td>{request.expense_category_name_en}</td>
											<td class="date-cell">{formatDateTime(request.created_at)}</td>
										</tr>
									{/each}
								{:else}
									<tr>
										<td colspan="7" class="no-data-message">
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

				<!-- Request Amount & Balance Info (if request is selected) -->
				{#if selectedRequestId && selectedRequestAmount > 0}
					<div class="request-amount-info">
						<div class="info-card">
							<div class="info-row">
								<span class="info-label">Request Amount:</span>
								<span class="info-value">{selectedRequestAmount.toFixed(2)} SAR</span>
							</div>
							<div class="info-row">
								<span class="info-label">Entering Amount:</span>
								<span class="info-value">{amount ? parseFloat(amount).toFixed(2) : '0.00'} SAR</span>
							</div>
							<div class="info-row balance-row">
								<span class="info-label">Balance:</span>
								<span class="info-value" class:negative={balance < 0} class:positive={balance > 0}>
									{balance.toFixed(2)} SAR
								</span>
							</div>
						</div>
						<p class="info-note">* This information is for reference purposes only</p>
					</div>
				{/if}

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

				<!-- Success Message -->
				{#if successMessage}
					<div class="success-message">
						✓ {successMessage}
					</div>
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
						Saving...
					{:else}
						💾 Save Bill Schedule
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
</style>
