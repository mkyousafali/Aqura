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
	let dateFilter = 'all';
	let dateRangeStart = '';
	let dateRangeEnd = '';

	// Approver data
	let approvers = [];
	let filteredApprovers = [];
	let selectedApproverId = '';
	let selectedApproverName = '';
	let approverSearchQuery = '';

	// Step 3 data - Multiple Bills
	let numberOfBills = 1;
	let bills = [];
	let activeBillIndex = null;
	let saving = false;
	let successMessage = '';
	let allBillsSaved = false;
	let showWhatsAppButton = false;

	// Payment methods
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

	// Reactive total calculation - use actual remaining balance from database
	$: totalAmount = bills.reduce((sum, bill) => sum + (parseFloat(bill.amount) || 0), 0);
	$: remainingBalance = selectedRequestRemainingBalance > 0 ? selectedRequestRemainingBalance - totalAmount : 0;

	onMount(async () => {
		await loadInitialData();
	});

	async function loadInitialData() {
		try {
			const { data: branchesData, error: branchesError } = await supabaseAdmin
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

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
			const { data, error } = await supabaseAdmin
				.from('users')
				.select(`
					*,
					hr_employees (
						name
					)
				`)
				.eq('status', 'active')
				.eq('can_approve_payments', true)
				.order('username');

			if (error) throw error;
			approvers = data || [];
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
		filteredCategories = categories.filter(cat =>
			cat.name_en?.toLowerCase().includes(query) ||
			cat.name_ar?.includes(query) ||
			cat.parent_category?.name_en?.toLowerCase().includes(query) ||
			cat.parent_category?.name_ar?.includes(query)
		);
	}

	function handleRequestSearch() {
		if (!requestSearchQuery.trim()) {
			filteredRequests = applyDateFilter(approvedRequests);
			return;
		}

		const query = requestSearchQuery.toLowerCase();
		const filtered = approvedRequests.filter(req =>
			req.requisition_number?.toLowerCase().includes(query) ||
			req.requester_name?.toLowerCase().includes(query) ||
			req.approver_name?.toLowerCase().includes(query) ||
			req.amount?.toString().includes(query)
		);
		filteredRequests = applyDateFilter(filtered);
	}

	function applyDateFilter(requests) {
		if (dateFilter === 'all') return requests;

		const today = new Date();
		today.setHours(0, 0, 0, 0);

		return requests.filter(req => {
			const reqDate = new Date(req.generated_date);
			reqDate.setHours(0, 0, 0, 0);

			if (dateFilter === 'today') {
				return reqDate.getTime() === today.getTime();
			} else if (dateFilter === 'yesterday') {
				const yesterday = new Date(today);
				yesterday.setDate(yesterday.getDate() - 1);
				return reqDate.getTime() === yesterday.getTime();
			} else if (dateFilter === 'range' && dateRangeStart && dateRangeEnd) {
				const start = new Date(dateRangeStart);
				const end = new Date(dateRangeEnd);
				start.setHours(0, 0, 0, 0);
				end.setHours(23, 59, 59, 999);
				return reqDate >= start && reqDate <= end;
			}
			return true;
		});
	}

	function handleUserSearch() {
		if (!userSearchQuery.trim()) {
			filteredUsers = users;
			return;
		}

		const query = userSearchQuery.toLowerCase();
		filteredUsers = users.filter(user =>
			user.username?.toLowerCase().includes(query) ||
			user.email?.toLowerCase().includes(query)
		);
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

	function validateBillAmount(billAmount) {
		if (!billAmount || parseFloat(billAmount) <= 0) {
			return { valid: false, message: 'Please enter a valid amount' };
		}

		// Validate against remaining balance if request is selected
		if (selectedRequestId && selectedRequestRemainingBalance > 0) {
			const currentTotalWithoutThisBill = bills.reduce((sum, bill, index) => {
				// Exclude the current bill from total calculation
				if (bill.amount && index !== activeBillIndex) {
					return sum + parseFloat(bill.amount);
				}
				return sum;
			}, 0);

			const newTotal = currentTotalWithoutThisBill + parseFloat(billAmount);
			const wouldExceedBalance = newTotal > selectedRequestRemainingBalance;

			if (wouldExceedBalance) {
				const overspend = newTotal - selectedRequestRemainingBalance;
				const confirmed = window.confirm(
					`⚠️ Warning: Total bill amount (${newTotal.toFixed(2)} SAR) exceeds remaining balance (${selectedRequestRemainingBalance.toFixed(2)} SAR).\n\n` +
					`This will result in overspending by ${overspend.toFixed(2)} SAR.\n\n` +
					`Do you want to proceed anyway?`
				);
				return { valid: confirmed, message: confirmed ? '' : 'Operation cancelled by user' };
			}
		}

		return { valid: true, message: '' };
	}

	function nextStep() {
		if (currentStep === 1 && !validateStep1()) return;
		if (currentStep === 2 && !validateStep2()) return;

		if (currentStep === 2) {
			// Initialize bills when moving to step 3
			initializeBills();
		}

		currentStep++;
	}

	function previousStep() {
		if (currentStep > 1) {
			currentStep--;
		}
	}

	function handleNumberOfBillsChange() {
		const num = parseInt(String(numberOfBills)) || 1;
		if (num < 1) {
			numberOfBills = 1;
			return;
		}
		if (num > 50) {
			numberOfBills = 50;
			alert('Maximum 50 bills allowed');
			return;
		}
		initializeBills();
	}

	function initializeBills() {
		const num = parseInt(String(numberOfBills)) || 1;
		const currentBills = [...bills];
		
		bills = Array.from({ length: num }, (_, index) => {
			// Keep existing bill data if available
			if (currentBills[index]) {
				return currentBills[index];
			}
			// Create new bill template
			const newBill = createEmptyBill(index + 1);
			// Calculate due date immediately for new bills
			calculateDueDateForBill(newBill);
			return newBill;
		});
	}
	
	// Helper function to calculate due date for a bill object (not by index)
	function calculateDueDateForBill(bill) {
		if (!bill.paymentMethod) return;

		const method = paymentMethods.find(m => m.value === bill.paymentMethod);
		if (!method) return;

		// Use user-entered creditPeriod if available, otherwise use default from payment method
		const creditDays = bill.creditPeriod && parseInt(bill.creditPeriod) > 0 ? parseInt(bill.creditPeriod) : method.creditDays;
		// Use billDate if available, otherwise use current date
		const baseDate = bill.billDate ? new Date(bill.billDate) : new Date();
		baseDate.setDate(baseDate.getDate() + creditDays);
		bill.dueDate = baseDate.toISOString().split('T')[0];
	}

	function createEmptyBill(number) {
		return {
			number,
			billType: 'no_bill',
			billNumber: '',
			billDate: '',
			paymentMethod: 'advance_cash',
			dueDate: '',
			creditPeriod: '',
			amount: '',
			billFile: null,
			billFileName: '',
			billFileUrl: '',
			bankName: '',
			iban: '',
			description: '',
			saved: false,
			saving: false,
			savedRecordId: null,  // Store DB record ID for later updates
			approverId: null,  // Each bill has its own approver
			approverName: ''
		};
	}

	function selectBill(index) {
		activeBillIndex = index;
	}

	function closeBillEditor() {
		activeBillIndex = null;
	}

	function handleBillFileChange(event, billIndex) {
		const file = event.target.files[0];
		if (file) {
			const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'application/pdf'];
			
			if (!allowedTypes.includes(file.type)) {
				alert('Please upload a valid image (JPEG, PNG, GIF, WebP) or PDF file');
				event.target.value = '';
				return;
			}

			if (file.size > 50 * 1024 * 1024) {
				alert('File size must be less than 50MB');
				event.target.value = '';
				return;
			}

			bills[billIndex].billFile = file;
			bills[billIndex].billFileName = file.name;
		}
	}

	function calculateDueDate(billIndex) {
		const bill = bills[billIndex];
		calculateDueDateForBill(bill);
		bills = [...bills]; // Trigger reactivity
	}

	async function saveBill(billIndex) {
		const bill = bills[billIndex];

		// Validate approver if no request selected - use bill's own approver
		if (!selectedRequestId && !bill.approverId) {
			alert('Please select an approver for this bill');
			return;
		}

		// Validate bill amount including overspending check
		const validation = validateBillAmount(bill.amount);
		if (!validation.valid) {
			if (validation.message) alert(validation.message);
			return;
		}

		if (bill.billType !== 'no_bill' && (!bill.billNumber || !bill.billDate || !bill.billFile)) {
			alert('Please provide bill number, date, and upload bill file');
			return;
		}

		try {
			bill.saving = true;
			bills = [...bills];

			let billFileUrl = bill.billFileUrl;

			// Upload file if new file selected
			if (bill.billFile && !bill.saved) {
				const fileExt = bill.billFile.name.split('.').pop();
				const fileName = `${Date.now()}_bill${bill.number}.${fileExt}`;
				const filePath = `${selectedBranchId}/${fileName}`;

				const { data: uploadData, error: uploadError } = await supabaseAdmin
					.storage
					.from('expense-scheduler-bills')
					.upload(filePath, bill.billFile);

				if (uploadError) throw uploadError;

				const { data: urlData } = supabaseAdmin
					.storage
					.from('expense-scheduler-bills')
					.getPublicUrl(filePath);

				billFileUrl = urlData.publicUrl;
			}

			const schedulerData = {
				branch_id: parseInt(selectedBranchId),
				branch_name: selectedBranchName,
				expense_category_id: parseInt(selectedCategoryId),
				expense_category_name_en: selectedCategoryNameEn,
				expense_category_name_ar: selectedCategoryNameAr,
				requisition_id: selectedRequestId ? parseInt(selectedRequestId) : null,
				requisition_number: selectedRequestNumber || null,
				co_user_id: selectedCoUserId,
				co_user_name: selectedCoUserName,
				bill_type: bill.billType,
				bill_number: bill.billNumber || null,
				bill_date: bill.billDate || null,
				payment_method: bill.paymentMethod,
				due_date: bill.dueDate || null,
				credit_period: bill.creditPeriod ? parseInt(bill.creditPeriod) : null,
				amount: parseFloat(bill.amount),
				bill_file_url: billFileUrl || null,
				description: bill.description || null,
				bank_name: bill.bankName || null,
				iban: bill.iban || null,
				schedule_type: 'multiple_bill',
				created_by: $currentUser?.id
			};

			let data, error;

			// Save to appropriate table based on whether request is selected
			if (selectedRequestId) {
				// Has approved request - save directly to expense_scheduler
				const expenseSchedulerData = {
					...schedulerData,
					status: 'pending',
					is_paid: false
				};
				
				({ data, error } = await supabaseAdmin
					.from('expense_scheduler')
					.insert([expenseSchedulerData])
					.select());
			} else {
				// No request - save to non_approved_payment_scheduler WITH this bill's approver
				// Note: non_approved table doesn't have requisition_id/requisition_number fields
				const { requisition_id, requisition_number, ...baseData } = schedulerData;
				
				const nonApprovedData = {
					...baseData,
					approver_id: bill.approverId,
					approver_name: bill.approverName,
					approval_status: 'pending'
				};

				({ data, error} = await supabaseAdmin
					.from('non_approved_payment_scheduler')
					.insert([nonApprovedData])
					.select());
				
				// Send individual notification for this bill
				if (!error && data && data[0]) {
					try {
						await notificationService.createNotification({
							title: 'Payment Schedule Approval Required',
							message: `A new bill payment schedule requires your approval.\n\nBill ${bill.number} (${bill.billType})\nBranch: ${selectedBranchName}\nCategory: ${selectedCategoryNameEn}\nAmount: ${parseFloat(bill.amount).toFixed(2)} SAR\nC/O User: ${selectedCoUserName}\nSubmitted by: ${$currentUser?.username}`,
							type: 'approval_request',
							priority: 'high',
							target_type: 'specific_users',
							target_users: [bill.approverId]
						}, $currentUser?.id || $currentUser?.username || 'System');
						console.log(`✅ Notification sent for Bill ${bill.number} to ${bill.approverName}`);
					} catch (notifError) {
						console.error(`⚠️ Failed to send notification for Bill ${bill.number}:`, notifError);
						// Don't fail the whole operation if notification fails
					}
				}
			}

			if (error) throw error;

			bill.saved = true;
			bill.saving = false;
			bill.billFileUrl = billFileUrl;
			bills = [...bills];

			successMessage = `Bill ${bill.number} saved successfully!`;
			
			// Check if all bills are saved
			const allSaved = bills.every(b => b.saved);
			if (allSaved) {
				// All bills saved - show WhatsApp button
				allBillsSaved = true;
				showWhatsAppButton = true;
			}
			
			setTimeout(() => {
				successMessage = '';
				if (!allBillsSaved) {
					closeBillEditor();
				}
			}, 2000);

		} catch (error) {
			console.error('Error saving bill:', error);
			bill.saving = false;
			bills = [...bills];
			alert(`Error saving bill ${bill.number}: ${error.message}`);
		}
	}

	async function shareToWhatsApp() {
		try {
			// Format date
			const formattedDate = new Date().toLocaleDateString('en-US', { 
				year: 'numeric', 
				month: 'long', 
				day: 'numeric' 
			});
			
			// Get unique approvers from saved bills
			const uniqueApprovers = [...new Set(bills.filter(b => b.saved && b.approverName).map(b => b.approverName))];
			const approversList = uniqueApprovers.join(', ');
			
			// Build bilingual message - Arabic First
			let message = `*━━━━━━━━━━━━━━━━*\n`;
			message += `*جدولة فواتير متعددة | MULTIPLE BILLS SCHEDULE*\n`;
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			message += `⚠️ *تم الإنشاء تلقائياً - يرجى الموافقة من مركز الموافقات*\n`;
			message += `⚠️ *Auto-generated - Please approve from Approval Center*\n\n`;
			
			// Approver(s)
			message += `*✅ المعتمد | Approver${uniqueApprovers.length > 1 ? 's' : ''}:*\n`;
			message += `${approversList}\n\n`;
			
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			// Date
			message += `*📅 التاريخ | Date:*\n`;
			message += `${formattedDate}\n\n`;
			
			// Branch
			message += `*🏢 الفرع | Branch:*\n`;
			message += `${selectedBranchName}\n\n`;
			
			// Total Amount
			message += `*💰 المبلغ الإجمالي | Total Amount:*\n`;
			message += `${totalAmount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\n\n`;
			
			// Number of Bills
			message += `*📋 عدد الفواتير | Number of Bills:*\n`;
			message += `${numberOfBills}\n\n`;
			
			// Category
			message += `*📂 الفئة | Category:*\n`;
			message += `${selectedCategoryNameAr} | ${selectedCategoryNameEn}\n\n`;
			
			// Bill Details with Descriptions
			message += `*━━━━━━━━━━━━━━━━*\n`;
			message += `*📋 تفاصيل الفواتير | Bill Details:*\n\n`;
			
			bills.filter(b => b.saved).forEach((bill, index) => {
				message += `*Bill ${index + 1}:*\n`;
				message += `• Amount | المبلغ: ${parseFloat(bill.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\n`;
				if (bill.billType !== 'no_bill') {
					message += `• Bill Number | رقم الفاتورة: ${bill.billNumber || 'N/A'}\n`;
				}
				message += `• Type | النوع: ${bill.billType}\n`;
				message += `• Payment | الدفع: ${bill.paymentMethod}\n`;
				if (bill.approverName) {
					message += `• Approver | المعتمد: ${bill.approverName}\n`;
				}
				if (bill.description && bill.description.trim()) {
					message += `• Description | الوصف: ${bill.description}\n`;
				}
				message += `\n`;
			});
			
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			// Generated By
			message += `*👤 تم الإنشاء بواسطة | Generated By:*\n`;
			message += `${$currentUser?.username || 'System'}`;
			
			// Open WhatsApp Web with the message
			const whatsappWebUrl = `https://web.whatsapp.com/send?text=${encodeURIComponent(message)}`;
			window.open(whatsappWebUrl, '_blank');
			
		} catch (error) {
			console.error('Error sharing:', error);
			alert('Error opening WhatsApp: ' + error.message);
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
		numberOfBills = 1;
		bills = [];
		activeBillIndex = null;
		successMessage = '';
		allBillsSaved = false;
		showWhatsAppButton = false;
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		try {
			const date = new Date(dateString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			return `${day}-${month}-${year}`;
		} catch (error) {
			return 'Invalid Date';
		}
	}
</script>

<div class="multiple-bill-scheduling">
	<!-- Progress Indicator -->
	<div class="progress-indicator">
		<div class="step" class:active={currentStep >= 1} class:completed={currentStep > 1}>
			<div class="step-number">1</div>
			<div class="step-label">Branch & Category</div>
		</div>
		<div class="step-line" class:active={currentStep > 1}></div>
		<div class="step" class:active={currentStep >= 2} class:completed={currentStep > 2}>
			<div class="step-number">2</div>
			<div class="step-label">Request & User</div>
		</div>
		<div class="step-line" class:active={currentStep > 2}></div>
		<div class="step" class:active={currentStep >= 3}>
			<div class="step-number">3</div>
			<div class="step-label">Multiple Bills</div>
		</div>
	</div>

	<!-- Step 1: Branch and Category (Same as Single Bill) -->
	{#if currentStep === 1}
		<div class="step-content">
			<h2>Step 1: Select Branch and Expense Category</h2>

			<!-- Branch Selection -->
			<div class="form-group">
				<label for="branch">Branch *</label>
				<select
					id="branch"
					class="form-select"
					bind:value={selectedBranchId}
					on:change={() => {
						selectedBranchName = branches.find(b => b.id == selectedBranchId)?.name_en || '';
						loadApprovedRequests();
						loadUsers();
					}}
				>
					<option value="">Select a branch</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
			</div>

			<!-- Category Selection -->
			{#if selectedBranchId}
				<div class="form-group">
					<label for="categorySearch">Search Expense Category</label>
					<input
						id="categorySearch"
						type="text"
						class="form-input"
						bind:value={categorySearchQuery}
						on:input={handleCategorySearch}
						placeholder="Search by category name..."
					/>
				</div>

				<div class="table-container">
					<table class="data-table">
						<thead>
							<tr>
								<th>Select</th>
								<th>Category Name (EN)</th>
								<th>Category Name (AR)</th>
								<th>Parent Category</th>
							</tr>
						</thead>
						<tbody>
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
									<td>{category.name_en}</td>
									<td>{category.name_ar}</td>
									<td>
										<div class="parent-category-cell">
											{#if category.parent_category}
												<span class="parent-badge">{category.parent_category.name_en}</span>
												<span class="parent-badge arabic">{category.parent_category.name_ar}</span>
											{:else}
												N/A
											{/if}
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Step 2: Request and User (Same as Single Bill) -->
	{#if currentStep === 2}
		<div class="step-content">
			<h2>Step 2: Select Approved Request and C/O User</h2>

			<!-- Request Selection (Optional) -->
			<div class="section">
				<h3>Select Approved Request (Optional)</h3>
				
				<div class="search-filters">
					<input
						type="text"
						class="form-input"
						bind:value={requestSearchQuery}
						on:input={handleRequestSearch}
						placeholder="Search by request number, requester, approver, or amount..."
					/>

					<div class="date-filters">
						<label>
							<input type="radio" name="dateFilter" value="all" bind:group={dateFilter} on:change={handleRequestSearch} />
							All
						</label>
						<label>
							<input type="radio" name="dateFilter" value="today" bind:group={dateFilter} on:change={handleRequestSearch} />
							Today
						</label>
						<label>
							<input type="radio" name="dateFilter" value="yesterday" bind:group={dateFilter} on:change={handleRequestSearch} />
							Yesterday
						</label>
						<label>
							<input type="radio" name="dateFilter" value="range" bind:group={dateFilter} on:change={handleRequestSearch} />
							Date Range
						</label>
					</div>

					{#if dateFilter === 'range'}
						<div class="date-range-inputs">
							<input type="date" bind:value={dateRangeStart} on:change={handleRequestSearch} />
							<span>to</span>
							<input type="date" bind:value={dateRangeEnd} on:change={handleRequestSearch} />
						</div>
					{/if}
				</div>

				{#if selectedRequestId}
					<div class="selected-item">
						Selected: {selectedRequestNumber}
						<button class="btn-clear" on:click={clearRequestSelection}>Clear</button>
					</div>
				{/if}

				<div class="table-container">
					<table class="data-table">
						<thead>
							<tr>
								<th>Select</th>
								<th>Request Number</th>
								<th>Requester</th>
								<th>Approver</th>
								<th>Original Amount</th>
								<th>Remaining Balance</th>
								<th>Generated Date</th>
							</tr>
						</thead>
						<tbody>
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
									<td>{request.requester_name || 'N/A'}</td>
									<td>{request.approver_name || 'N/A'}</td>
									<td>{request.amount} SAR</td>
									<td>
										<span class:text-success={parseFloat(request.remaining_balance || request.amount) > 0}
											  class:text-warning={parseFloat(request.remaining_balance || request.amount) === 0}
											  class:text-danger={parseFloat(request.remaining_balance || request.amount) < 0}>
											{parseFloat(request.remaining_balance || request.amount).toFixed(2)} SAR
										</span>
									</td>
									<td>{formatDate(request.generated_date)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>

			<!-- User Selection (Mandatory) -->
			<div class="section">
				<h3>Select C/O User *</h3>
				
				<div class="form-group">
					<input
						type="text"
						class="form-input"
						bind:value={userSearchQuery}
						on:input={handleUserSearch}
						placeholder="Search by username or email..."
					/>
				</div>

				{#if selectedCoUserId}
					<div class="selected-item">
						Selected: {selectedCoUserName}
					</div>
				{/if}

				<div class="table-container">
					<table class="data-table">
						<thead>
							<tr>
								<th>Select</th>
								<th>Username</th>
								<th>Email</th>
								<th>Type</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredUsers as user}
								<tr
									class:selected={selectedCoUserId === user.id}
									on:click={() => selectUser(user)}
								>
									<td>
										<input
											type="radio"
											name="coUser"
											checked={selectedCoUserId === user.id}
											on:change={() => selectUser(user)}
										/>
									</td>
									<td>{user.username}</td>
									<td>{user.email || 'N/A'}</td>
									<td>
										{#if user.user_type === 'global'}
											<span class="badge-global">Global</span>
										{:else}
											Branch User
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		</div>
	{/if}

	<!-- Step 3: Multiple Bills -->
	{#if currentStep === 3}
		<div class="step-content">
			<h2>Step 3: Enter Multiple Bills</h2>

			<!-- Number of Bills Input -->
			<div class="form-group">
				<label for="numberOfBills">Number of Bills *</label>
				<input
					id="numberOfBills"
					type="number"
					class="form-input"
					bind:value={numberOfBills}
					on:change={handleNumberOfBillsChange}
					min="1"
					max="50"
				/>
				<p class="field-hint">Enter number of bills (1-50)</p>
			</div>

			<!-- Total Summary -->
			{#if bills.length > 0}
				<div class="total-summary">
					<div class="summary-row">
						<span class="summary-label">Total Bills:</span>
						<span class="summary-value">{bills.length}</span>
					</div>
					<div class="summary-row">
						<span class="summary-label">Saved Bills:</span>
						<span class="summary-value saved">{bills.filter(b => b.saved).length}</span>
					</div>
					<div class="summary-row">
						<span class="summary-label">Total Amount:</span>
						<span class="summary-value amount">{totalAmount.toFixed(2)} SAR</span>
					</div>
					{#if selectedRequestAmount > 0}
						<div class="summary-row">
							<span class="summary-label">Request Amount:</span>
							<span class="summary-value">{selectedRequestAmount.toFixed(2)} SAR</span>
						</div>
						<div class="summary-row balance-row">
							<span class="summary-label">Remaining Balance:</span>
							<span class="summary-value" class:negative={remainingBalance < 0} class:positive={remainingBalance > 0}>
								{remainingBalance.toFixed(2)} SAR
							</span>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Bill Templates Grid -->
			<div class="bills-grid">
				{#each bills as bill, index}
					<div class="bill-card" class:saved={bill.saved} class:active={activeBillIndex === index}>
						<div class="bill-card-header" on:click={() => selectBill(index)}>
							<div class="bill-title">
								<span class="bill-number">Bill {bill.number}</span>
								{#if bill.saved}
									<span class="saved-badge">✓ Saved</span>
								{/if}
							</div>
							<div class="bill-amount">
								{#if bill.amount}
									{parseFloat(bill.amount).toFixed(2)} SAR
								{:else}
									<span class="no-amount">Not entered</span>
								{/if}
							</div>
						</div>
						
						{#if bill.saved}
							<div class="bill-card-body saved-details">
								<p><strong>Type:</strong> {bill.billType}</p>
								<p><strong>Payment:</strong> {paymentMethods.find(m => m.value === bill.paymentMethod)?.label.split(' - ')[0]}</p>
								{#if bill.billNumber}<p><strong>Bill #:</strong> {bill.billNumber}</p>{/if}
								{#if bill.billDate}<p><strong>Date:</strong> {formatDate(bill.billDate)}</p>{/if}
								{#if bill.dueDate}<p><strong>Due:</strong> {formatDate(bill.dueDate)}</p>{/if}
							</div>
						{/if}
					</div>
				{/each}
			</div>

			<!-- Bill Editor Modal -->
			{#if activeBillIndex !== null}
				<div class="bill-editor-overlay" on:click={closeBillEditor}>
					<div class="bill-editor" on:click|stopPropagation>
						<div class="editor-header">
							<h3>Bill {bills[activeBillIndex].number} Details</h3>
							<button class="btn-close" on:click={closeBillEditor}>✕</button>
						</div>

						<div class="editor-body">
							<!-- Bill Type -->
							<div class="form-group">
								<label for="billType">Bill Type *</label>
								<select id="billType" class="form-select" bind:value={bills[activeBillIndex].billType} disabled={bills[activeBillIndex].saved}>
									<option value="vat_applicable">VAT Applicable</option>
									<option value="no_vat">No VAT</option>
									<option value="no_bill">No Bill</option>
								</select>
							</div>

							<!-- Bill Number, Date, Upload (if not "no_bill") -->
							{#if bills[activeBillIndex].billType !== 'no_bill'}
								<div class="form-group">
									<label for="billNumber">Bill Number *</label>
									<input
										id="billNumber"
										type="text"
										class="form-input"
										bind:value={bills[activeBillIndex].billNumber}
										disabled={bills[activeBillIndex].saved}
										placeholder="Enter bill number"
									/>
								</div>

								<div class="form-group">
									<label for="billDate">Bill Date *</label>
									<input
										id="billDate"
										type="date"
										class="form-input"
										bind:value={bills[activeBillIndex].billDate}
										disabled={bills[activeBillIndex].saved}
										on:change={() => calculateDueDate(activeBillIndex)}
									/>
								</div>

								<div class="form-group">
									<label for="billFile">Upload Bill *</label>
									<input
										id="billFile"
										type="file"
										class="form-input"
										accept="image/jpeg,image/jpg,image/png,image/gif,image/webp,application/pdf"
										on:change={(e) => handleBillFileChange(e, activeBillIndex)}
										disabled={bills[activeBillIndex].saved}
									/>
									{#if bills[activeBillIndex].billFileName}
										<div class="file-info">📄 {bills[activeBillIndex].billFileName}</div>
									{/if}
									<p class="field-hint">Supported: Images (JPEG, PNG, GIF, WebP) or PDF. Max 50MB</p>
								</div>
							{/if}

							<!-- Payment Method -->
							<div class="form-group">
								<label for="paymentMethod">Payment Method *</label>
								<select
									id="paymentMethod"
									class="form-select"
									bind:value={bills[activeBillIndex].paymentMethod}
									disabled={bills[activeBillIndex].saved}
									on:change={() => calculateDueDate(activeBillIndex)}
								>
									{#each paymentMethods as method}
										<option value={method.value}>{method.label}</option>
									{/each}
								</select>
							</div>

							<!-- Credit Period (conditional) -->
							{#if bills[activeBillIndex].paymentMethod.includes('credit')}
								<div class="form-group">
									<label for="creditPeriod">Credit Period (Days)</label>
									<input
										id="creditPeriod"
										type="number"
										class="form-input"
										bind:value={bills[activeBillIndex].creditPeriod}
										disabled={bills[activeBillIndex].saved}
										placeholder="Enter credit period in days"
										on:input={() => calculateDueDate(activeBillIndex)}
									/>
								</div>
							{/if}

							<!-- Bank Name -->
							<div class="form-group">
								<label for="bankName">Bank Name (Optional)</label>
								<input
									id="bankName"
									type="text"
									class="form-input"
									bind:value={bills[activeBillIndex].bankName}
									disabled={bills[activeBillIndex].saved}
									placeholder="Enter bank name"
								/>
							</div>

							<!-- IBAN -->
							<div class="form-group">
								<label for="iban">IBAN (Optional)</label>
								<input
									id="iban"
									type="text"
									class="form-input"
									bind:value={bills[activeBillIndex].iban}
									disabled={bills[activeBillIndex].saved}
									placeholder="Enter IBAN"
								/>
							</div>

							<!-- Due Date (Auto-calculated) -->
							{#if bills[activeBillIndex].dueDate}
								<div class="form-group">
									<label for="dueDate">Due Date (Auto-calculated)</label>
									<input
										id="dueDate"
										type="date"
										class="form-input"
										bind:value={bills[activeBillIndex].dueDate}
										disabled
									/>
								</div>
							{/if}

							<!-- Approver Selection (only if no approved request) -->
							{#if !selectedRequestId}
								<div class="form-group approver-field">
									<label for="approver">Select Approver *</label>
									<select
										id="approver"
										class="form-select"
										bind:value={bills[activeBillIndex].approverId}
										disabled={bills[activeBillIndex].saved}
										on:change={() => {
											const approver = approvers.find(a => a.id === bills[activeBillIndex].approverId);
											bills[activeBillIndex].approverName = approver?.username || '';
										}}
									>
										<option value={null}>-- Select Approver --</option>
										{#each approvers as approver}
											<option value={approver.id}>
												{approver.username} - 
												{#if approver.approval_amount_limit === 0}
													♾️ Unlimited
												{:else}
													{approver.approval_amount_limit?.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR
												{/if}
												({approver.user_type === 'global' ? 'Global' : branches.find(b => b.id === approver.branch_id)?.name_en || 'Branch'})
											</option>
										{/each}
									</select>
									<p class="field-hint">⚠️ This bill will require approval before posting to expense scheduler</p>
								</div>
							{/if}

							<!-- Amount -->
							<div class="form-group">
								<label for="amount">Amount (SAR) *</label>
								<input
									id="amount"
									type="number"
									class="form-input amount-input-large"
									bind:value={bills[activeBillIndex].amount}
									disabled={bills[activeBillIndex].saved}
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
									bind:value={bills[activeBillIndex].description}
									disabled={bills[activeBillIndex].saved}
									placeholder="Enter any additional details..."
									rows="3"
								></textarea>
							</div>

							<!-- Success Message -->
							{#if successMessage}
								<div class="success-message">
									✓ {successMessage}
								</div>
							{/if}
						</div>

						<div class="editor-footer">
							{#if !bills[activeBillIndex].saved}
								<button class="btn-save" on:click={() => saveBill(activeBillIndex)} disabled={bills[activeBillIndex].saving}>
									{bills[activeBillIndex].saving ? 'Saving...' : `Save Bill ${bills[activeBillIndex].number}`}
								</button>
							{:else}
								<button class="btn-close" on:click={closeBillEditor}>Close</button>
							{/if}
						</div>
					</div>
				</div>
			{/if}
		</div>
	{/if}

	<!-- All Bills Saved Success Message and Actions -->
	{#if allBillsSaved && currentStep === 3}
		<div class="all-saved-container">
			<div class="all-saved-message">
				✅ All {numberOfBills} bills saved successfully{!selectedRequestId ? ' and submitted for approval' : ''}!
			</div>

			<div class="total-summary">
				<div class="summary-row">
					<span class="summary-label">Total Bills:</span>
					<span class="summary-value">{bills.length}</span>
				</div>
				<div class="summary-row">
					<span class="summary-label">Total Amount:</span>
					<span class="summary-value amount">{totalAmount.toFixed(2)} SAR</span>
				</div>
				{#if !selectedRequestId}
					<div class="summary-row">
						<span class="summary-label">Approver:</span>
						<span class="summary-value"><strong>{selectedApproverName}</strong></span>
					</div>
				{/if}
			</div>
			
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
		</div>
	{/if}

	<!-- Navigation Buttons -->
	<div class="nav-buttons">
		{#if currentStep > 1}
			<button class="btn-prev" on:click={previousStep}>← Previous</button>
		{/if}
		{#if currentStep < totalSteps}
			<button class="btn-next" on:click={nextStep}>Next →</button>
		{/if}
	</div>
</div>

<style>
	.multiple-bill-scheduling {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Progress Indicator */
	.progress-indicator {
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

	.step-line.active {
		background: #10b981;
	}

	/* Step Content */
	.step-content {
		background: white;
		padding: 2rem;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		margin-bottom: 2rem;
	}

	h2 {
		color: #1e293b;
		margin-bottom: 2rem;
		font-size: 1.5rem;
	}

	h3 {
		color: #475569;
		margin: 1.5rem 0 1rem 0;
		font-size: 1.125rem;
	}

	/* Form Elements */
	.form-group {
		margin-bottom: 1.5rem;
	}

	label {
		display: block;
		margin-bottom: 0.5rem;
		color: #334155;
		font-weight: 600;
	}

	.form-input,
	.form-select,
	.form-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		transition: border-color 0.2s ease;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #667eea;
	}

	.field-hint {
		margin-top: 0.25rem;
		font-size: 0.875rem;
		color: #64748b;
	}

	.file-info {
		margin-top: 0.5rem;
		padding: 0.5rem;
		background: #f1f5f9;
		border-radius: 4px;
		font-size: 0.875rem;
	}

	/* Tables */
	.table-container {
		overflow-x: auto;
		margin-top: 1rem;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
		max-height: 400px;
		overflow-y: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.data-table th {
		background: #f8fafc;
		padding: 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #475569;
		border-bottom: 2px solid #e2e8f0;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.data-table td {
		padding: 0.75rem;
		border-bottom: 1px solid #f1f5f9;
	}

	.data-table tbody tr {
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.data-table tbody tr:hover {
		background: #f8fafc;
	}

	.data-table tr.selected {
		background: #ede9fe;
	}

	.data-table tr.selected:hover {
		background: #ddd6fe;
	}

	.parent-category-cell {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		align-items: center;
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

	.parent-badge.arabic {
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

	.selected-item {
		margin: 1rem 0;
		padding: 0.75rem 1rem;
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 8px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 600;
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

	/* Total Summary */
	.total-summary {
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #bae6fd;
		border-radius: 12px;
		padding: 1.5rem;
		margin: 1.5rem 0;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem;
		margin-bottom: 0.5rem;
		background: white;
		border-radius: 6px;
	}

	.summary-row.balance-row {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		border: 2px solid #fbbf24;
		font-weight: 700;
		font-size: 1.1rem;
	}

	.summary-label {
		color: #475569;
		font-weight: 600;
	}

	.summary-value {
		color: #0f172a;
		font-weight: 700;
	}

	.summary-value.saved {
		color: #16a34a;
	}

	.summary-value.amount {
		font-size: 1.25rem;
		color: #667eea;
	}

	.summary-value.negative {
		color: #dc2626;
	}

	.summary-value.positive {
		color: #16a34a;
	}

	/* Bills Grid */
	.bills-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
		gap: 1rem;
		margin: 2rem 0;
	}

	.bill-card {
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		overflow: hidden;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.bill-card:hover {
		border-color: #667eea;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
	}

	.bill-card.saved {
		border-color: #22c55e;
		background: #f0fdf4;
	}

	.bill-card.active {
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
	}

	.bill-card-header {
		padding: 1rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.bill-card.saved .bill-card-header {
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
	}

	.bill-title {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}

	.bill-number {
		font-weight: 700;
		font-size: 1.125rem;
	}

	.saved-badge {
		font-size: 0.75rem;
		padding: 0.25rem 0.5rem;
		background: rgba(255, 255, 255, 0.3);
		border-radius: 4px;
	}

	.bill-amount {
		font-size: 1.25rem;
		font-weight: 700;
	}

	.no-amount {
		font-size: 0.875rem;
		opacity: 0.7;
	}

	.bill-card-body {
		padding: 1rem;
	}

	.saved-details p {
		margin: 0.5rem 0;
		font-size: 0.875rem;
	}

	/* Bill Editor Modal */
	.bill-editor-overlay {
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

	.bill-editor {
		background: white;
		border-radius: 12px;
		max-width: 800px;
		width: 90%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.editor-header {
		padding: 1.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.editor-header h3 {
		margin: 0;
		color: white;
	}

	.btn-close {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 1.25rem;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.btn-close:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	.editor-body {
		padding: 2rem;
		overflow-y: auto;
		flex: 1;
	}

	.editor-footer {
		padding: 1.5rem;
		border-top: 2px solid #e2e8f0;
		display: flex;
		justify-content: flex-end;
	}

	.amount-input-large {
		font-size: 1.5rem;
		font-weight: 700;
		color: #667eea;
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
		width: 100%;
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

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	/* Search Filters */
	.search-filters {
		margin-bottom: 1rem;
	}

	.date-filters {
		display: flex;
		gap: 1.5rem;
		margin: 1rem 0;
		flex-wrap: wrap;
	}

	.date-filters label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		cursor: pointer;
	}

	.date-filters input[type="radio"] {
		cursor: pointer;
	}

	.date-range-inputs {
		display: flex;
		gap: 1rem;
		align-items: center;
		flex-wrap: wrap;
	}

	.date-range-inputs input[type="date"] {
		flex: 1;
		min-width: 150px;
	}

	.section {
		margin: 2rem 0;
		padding: 1.5rem;
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
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

	/* Approver Selection Section */
	.approver-section {
		margin-top: 1.5rem;
		padding: 1.5rem;
		background: #f8fafc;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.approval-hint {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #fef3c7;
		border-left: 3px solid #f59e0b;
		border-radius: 4px;
		margin-bottom: 1rem;
		font-size: 0.9rem;
	}

	.approver-table-container {
		margin-top: 1rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		overflow: hidden;
	}

	.approver-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.approver-table thead {
		background: #f1f5f9;
		border-bottom: 2px solid #e2e8f0;
	}

	.approver-table th {
		padding: 0.75rem;
		text-align: right;
		font-weight: 600;
		font-size: 0.9rem;
		color: #475569;
	}

	.approver-table tbody tr {
		border-bottom: 1px solid #e2e8f0;
		transition: background-color 0.2s;
		cursor: pointer;
	}

	.approver-table tbody tr:hover {
		background: #f8fafc;
	}

	.approver-table tbody tr.selected {
		background: #dbeafe;
	}

	.approver-table td {
		padding: 0.75rem;
		text-align: right;
		font-size: 0.9rem;
	}

	.approver-table .approver-radio {
		text-align: center;
	}

	.approver-table .approver-radio input[type="radio"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
	}

	.approver-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.badge-admin {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-manager {
		background: #e0e7ff;
		color: #4338ca;
	}

	/* All Saved Success Container */
	.all-saved-container {
		margin: 2rem 0;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 12px;
		border: 2px solid #22c55e;
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.1);
	}

	.all-saved-message {
		font-size: 1.1rem;
		font-weight: 600;
		color: #15803d;
		text-align: center;
		margin-bottom: 1rem;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		gap: 1rem;
		justify-content: center;
		margin-top: 1rem;
	}

	.btn-whatsapp,
	.btn-new-schedule {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.btn-whatsapp {
		background: linear-gradient(135deg, #25d366 0%, #128c7e 100%);
		color: white;
	}

	.btn-whatsapp:hover {
		background: linear-gradient(135deg, #20bd5a 0%, #0f7a6e 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(37, 211, 102, 0.3);
	}

	.whatsapp-icon {
		font-size: 1.2rem;
	}

	.btn-new-schedule {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
	}

	.btn-new-schedule:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	/* Approval Success */
	.approval-success {
		margin: 1rem 0;
		padding: 1rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 8px;
		border: 1px solid #86efac;
	}

	.approval-success .success-text {
		text-align: center;
		color: #15803d;
		font-size: 1rem;
		font-weight: 500;
		margin: 0;
	}

	.btn-submit {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 2rem;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		margin: 0 auto;
	}

	.btn-submit:hover:not(:disabled) {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.btn-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Approver Field Styling */
	.approver-field {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		padding: 1rem;
		border-radius: 8px;
		border: 2px solid #f59e0b;
	}

	.approver-field label {
		color: #92400e;
		font-weight: 600;
	}

	.approver-field .field-hint {
		color: #b45309;
		font-weight: 500;
		margin-top: 0.5rem;
	}
</style>
