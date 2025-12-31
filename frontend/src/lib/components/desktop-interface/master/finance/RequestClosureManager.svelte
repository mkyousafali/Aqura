<script>
	import { onMount, createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { windowManager } from '$lib/stores/windowManager';

	const dispatch = createEventDispatcher();

	// Props
	export let preSelectedRequestId = null; // If provided, auto-select and skip to step 2
	export let windowId = null; // Window ID for auto-closing when opened as window

	// Step management
	let currentStep = 1;
	const totalSteps = 3;

	// Data arrays
	let approvedRequests = [];
	let filteredRequests = [];
	let categories = [];
	let filteredCategories = [];
	let users = [];
	let filteredUsers = [];

	// Step 1 - Request Selection
	let selectedRequestId = '';
	let selectedRequestNumber = '';
	let selectedRequestAmount = 0;
	let selectedRequestBranchId = '';
	let selectedRequestBranchName = '';
	let requestSearchQuery = '';

	// Step 2 - Bill Count
	let numberOfBills = 1;

	// Step 3 - Bill Details
	let bills = [];
	let activeBillIndex = null;
	let saving = false;
	let successMessage = '';
	let allBillsSaved = false;

	// Balance handling
	let totalBillsAmount = 0;
	let remainingBalance = 0;
	let balanceAction = 'keep'; // 'keep' or 'writeoff'
	let writeOffReason = '';

	// Payment methods - matching scheduler format
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

	// Bill types - matching scheduler format
	const billTypes = [
		{ value: 'vat_applicable', label: 'VAT Applicable - خاضع لضريبة القيمة المضافة' },
		{ value: 'no_vat', label: 'No VAT - بدون ضريبة' },
		{ value: 'no_bill', label: 'No Bill - بدون فاتورة' }
	];

	// Reactive calculations
	$: totalBillsAmount = bills.reduce((sum, bill) => sum + (parseFloat(bill.amount) || 0), 0);
	$: remainingBalance = selectedRequestAmount - totalBillsAmount;
	$: isOverspending = totalBillsAmount > selectedRequestAmount;

	onMount(async () => {
		await loadInitialData();
		
		// If a request is pre-selected, auto-select it and move to step 2
		if (preSelectedRequestId) {
			await autoSelectRequest(preSelectedRequestId);
		}
	});

	async function autoSelectRequest(requestId) {
		try {
			const request = approvedRequests.find(r => r.id === requestId);
			if (request) {
				selectedRequestId = request.id;
				selectedRequestNumber = request.requisition_number;
				selectedRequestAmount = parseFloat(request.remaining_balance || request.amount);
				selectedRequestBranchId = request.branch_id;
				selectedRequestBranchName = request.branch_name;
				
				// Load users for this branch
				await loadUsers();
				
				// Don't load existing bills - start fresh for adding new bills
				// The remaining balance already reflects what's been paid
				
				// Automatically move to step 2
				currentStep = 2;
			}
		} catch (error) {
			console.error('Error auto-selecting request:', error);
		}
	}

	async function loadExistingBills(requestId) {
		try {
			// Load existing bills from expense_scheduler (closed_requisition_bill type)
			const { data: existingBills, error } = await supabase
				.from('expense_scheduler')
				.select('*')
				.eq('requisition_id', requestId)
				.eq('schedule_type', 'closed_requisition_bill')
				.order('created_at');

			if (error) throw error;

			if (existingBills && existingBills.length > 0) {
				// Set the number of bills
				numberOfBills = existingBills.length;
				
				// Populate bills array with existing data
				bills = existingBills.map((existingBill, index) => ({
					number: index + 1,
					billType: existingBill.bill_type || 'vat_applicable',
					billNumber: existingBill.bill_number || '',
					billDate: existingBill.bill_date || '',
					billFile: null,
					billFileUrl: existingBill.bill_file_url || '',
					amount: existingBill.amount || 0,
					paymentMethod: existingBill.payment_method || 'cash',
					bankName: existingBill.bank_name || '',
					iban: existingBill.iban || '',
					paidDate: existingBill.due_date || '',
					categoryId: existingBill.expense_category_id || '',
					categoryNameEn: existingBill.expense_category_name_en || '',
					categoryNameAr: existingBill.expense_category_name_ar || '',
					parentCategoryId: null,
					parentCategoryName: '',
					coUserId: existingBill.co_user_id || null,
					coUserName: existingBill.co_user_name || '',
					description: existingBill.description || '',
					notes: existingBill.notes || '',
					saved: true,
					saving: false
				}));

				// Update allBillsSaved flag
				allBillsSaved = bills.every(b => b.saved);
			}
		} catch (error) {
			console.error('Error loading existing bills:', error);
		}
	}

	async function loadInitialData() {
		try {
			// Load all active requests (approved or closed)
			const { data: requestsData, error: requestsError } = await supabase
				.from('expense_requisitions')
				.select(`
					*,
					branches(name_en)
				`)
				.eq('is_active', true)
				.in('status', ['approved', 'closed'])
				.order('created_at', { ascending: false });

			if (requestsError) throw requestsError;
			
			// For each request, calculate remaining balance from expense_scheduler
			const requestsWithBalance = await Promise.all((requestsData || []).map(async (req) => {
				// Get the original scheduler entry (unpaid expense_requisition type)
				const { data: schedulerData } = await supabase
					.from('expense_scheduler')
					.select('amount, is_paid')
					.eq('requisition_id', req.id)
					.eq('schedule_type', 'expense_requisition')
					.maybeSingle();
				
				// The remaining balance is the amount in the unpaid scheduler entry
				const remainingBalance = schedulerData && !schedulerData.is_paid 
					? parseFloat(schedulerData.amount || 0) 
					: 0;
				
				return {
					...req,
					remaining_balance: remainingBalance,
					branch_name: req.branches?.name_en || 'N/A'
				};
			}));
			
			// Filter to only show requests with remaining balance
			approvedRequests = requestsWithBalance.filter(req => {
				const remainingBalance = parseFloat(req.remaining_balance || 0);
				return req.status === 'approved' || (req.status === 'closed' && remainingBalance > 0);
			});
			
			filteredRequests = approvedRequests;

			// Load categories
			const { data: categoriesData, error: categoriesError } = await supabase
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

	async function loadUsers() {
		if (!selectedRequestBranchId) return;

		try {
			const { data, error } = await supabase
				.from('users')
				.select('*')
				.or(`branch_id.eq.${selectedRequestBranchId},user_type.eq.global`)
				.eq('status', 'active')
				.order('username');

			if (error) throw error;
			users = data || [];
			filteredUsers = users;
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	function handleRequestSearch() {
		if (!requestSearchQuery.trim()) {
			filteredRequests = approvedRequests;
			return;
		}

		const query = requestSearchQuery.toLowerCase();
		filteredRequests = approvedRequests.filter(req =>
			req.requisition_number?.toLowerCase().includes(query) ||
			req.requester_name?.toLowerCase().includes(query) ||
			req.amount?.toString().includes(query) ||
			req.branches?.name_en?.toLowerCase().includes(query)
		);
	}

	function selectRequest(request) {
		selectedRequestId = request.id;
		selectedRequestNumber = request.requisition_number;
		selectedRequestAmount = parseFloat(request.remaining_amount || request.amount || 0);
		selectedRequestBranchId = request.branch_id;
		selectedRequestBranchName = request.branches?.name_en || '';
		loadUsers();
	}

	function validateStep1() {
		if (!selectedRequestId) {
			alert('Please select a request to close');
			return false;
		}
		return true;
	}

	function validateStep2() {
		if (!numberOfBills || numberOfBills < 1) {
			alert('Please enter the number of bills (minimum 1)');
			return false;
		}
		if (numberOfBills > 50) {
			alert('Maximum 50 bills allowed');
			return false;
		}
		return true;
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
			return createEmptyBill(index + 1);
		});
	}

	function createEmptyBill(number) {
		return {
			number,
			billType: 'vat_applicable',
			paymentMethod: 'cash',
			amount: '',
			billNumber: '',
			billDate: new Date().toISOString().split('T')[0],
			billFile: null,
			billFileName: '',
			billFileUrl: '',
			paidDate: new Date().toISOString().split('T')[0],
			bankName: '',
			iban: '',
			coUserId: '',
			coUserName: '',
			categoryId: '',
			categoryNameEn: '',
			categoryNameAr: '',
			parentCategoryId: '',
			parentCategoryName: '',
			description: '',
			notes: '',
			categorySearchQuery: '',
			coSearchQuery: '',
			saved: false,
			saving: false
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

	function handleCategorySearch(billIndex) {
		const bill = bills[billIndex];
		if (!bill.categorySearchQuery.trim()) {
			filteredCategories = categories;
			return;
		}

		const query = bill.categorySearchQuery.toLowerCase();
		filteredCategories = categories.filter(cat =>
			cat.name_en?.toLowerCase().includes(query) ||
			cat.name_ar?.includes(query) ||
			cat.parent_category?.name_en?.toLowerCase().includes(query) ||
			cat.parent_category?.name_ar?.includes(query)
		);
	}

	function selectCategory(billIndex, category) {
		const bill = bills[billIndex];
		bill.categoryId = category.id;
		bill.categoryNameEn = category.name_en;
		bill.categoryNameAr = category.name_ar;
		bill.parentCategoryId = category.parent_category?.id || null;
		bill.parentCategoryName = category.parent_category?.name_en || '';
		bills = [...bills];
	}

	function handleCoSearch(billIndex) {
		const bill = bills[billIndex];
		if (!bill.coSearchQuery.trim()) {
			filteredUsers = users;
			return;
		}

		const query = bill.coSearchQuery.toLowerCase();
		filteredUsers = users.filter(user =>
			user.username?.toLowerCase().includes(query) ||
			user.email?.toLowerCase().includes(query)
		);
	}

	function selectCoUser(billIndex, user) {
		const bill = bills[billIndex];
		bill.coUserId = user.id;
		bill.coUserName = user.username;
		bills = [...bills];
	}

	async function saveBill(billIndex) {
		const bill = bills[billIndex];

		// Validate required fields
		if (!bill.billType) {
			alert('Please select a bill type');
			return;
		}

		// Validate bill-specific fields (only if not no_bill)
		if (bill.billType !== 'no_bill') {
			if (!bill.billNumber || bill.billNumber.trim() === '') {
				alert('Please enter a bill number');
				return;
			}
			if (!bill.billDate) {
				alert('Please select a bill date');
				return;
			}
			if (!bill.billFile && !bill.billFileUrl) {
				alert('Please upload a bill file');
				return;
			}
		}

		if (!bill.amount || parseFloat(bill.amount) <= 0) {
			alert('Please enter a valid amount');
			return;
		}
		if (!bill.paymentMethod) {
			alert('Please select a payment method');
			return;
		}
		if (!bill.paidDate) {
			alert('Please select a paid date');
			return;
		}
		if (!bill.categoryId) {
			alert('Please select an expense category');
			return;
		}

		// Check for overspending
		if (isOverspending) {
			const overspend = totalBillsAmount - selectedRequestAmount;
			const confirmed = window.confirm(
				`⚠️ Warning: Total bills amount (${totalBillsAmount.toFixed(2)} SAR) exceeds request amount (${selectedRequestAmount.toFixed(2)} SAR).\n\n` +
				`This will result in overspending by ${overspend.toFixed(2)} SAR.\n\n` +
				`Do you want to proceed anyway?`
			);
			if (!confirmed) return;
		}

		try {
			bill.saving = true;
			bills = [...bills];

			let billFileUrl = bill.billFileUrl;

		// Upload file if provided
		if (bill.billFile && !bill.saved) {
			const fileExt = bill.billFile.name.split('.').pop();
			const fileName = `${Date.now()}_bill${bill.number}.${fileExt}`;
			const filePath = `${selectedRequestBranchId}/request_closures/${fileName}`;

			const { data: uploadData, error: uploadError } = await supabase
				.storage
				.from('expense-scheduler-bills')
				.upload(filePath, bill.billFile);

			if (uploadError) throw uploadError;

			const { data: urlData } = supabase
				.storage
				.from('expense-scheduler-bills')
				.getPublicUrl(filePath);

			billFileUrl = urlData.publicUrl;
		}			// Save bill - only work with expense_scheduler table
			if (!bill.saved) {
				// 1. Create new scheduler entry for this closed bill (marked as PAID)
				const closedBillEntry = {
					branch_id: parseInt(selectedRequestBranchId),
					branch_name: selectedRequestBranchName,
					expense_category_id: parseInt(bill.categoryId),
					expense_category_name_en: bill.categoryNameEn,
					expense_category_name_ar: bill.categoryNameAr || '',
					requisition_id: parseInt(selectedRequestId),
					requisition_number: selectedRequestNumber,
					co_user_id: bill.coUserId || null,
					co_user_name: bill.coUserName || null,
					bill_type: bill.billType,
					bill_number: bill.billNumber || null,
					bill_date: bill.billDate || null,
					bill_file_url: billFileUrl || null,
					payment_method: bill.paymentMethod,
					bank_name: bill.bankName || null,
					iban: bill.iban || null,
					due_date: bill.paidDate,
					amount: parseFloat(bill.amount),
					description: bill.description || null,
					notes: bill.notes || null,
					schedule_type: 'closed_requisition_bill',
					status: 'paid',
					is_paid: true,
					paid_date: new Date().toISOString(),
					created_by: $currentUser?.id
				};

				const { error: insertError } = await supabase
					.from('expense_scheduler')
					.insert([closedBillEntry]);

				if (insertError) throw insertError;

				// 2. Update original scheduler entry to reduce amount
				const { data: originalScheduler } = await supabase
					.from('expense_scheduler')
					.select('*')
					.eq('requisition_id', selectedRequestId)
					.eq('schedule_type', 'expense_requisition')
					.eq('is_paid', false)
					.maybeSingle();

				if (originalScheduler) {
					const newAmount = parseFloat(originalScheduler.amount) - parseFloat(bill.amount);
					if (newAmount > 0) {
						// Update amount to remaining balance
						await supabase
							.from('expense_scheduler')
							.update({ 
								amount: newAmount,
								status: 'pending',
								updated_at: new Date().toISOString()
							})
							.eq('id', originalScheduler.id);
					} else {
						// Fully closed - mark original as paid
						await supabase
							.from('expense_scheduler')
							.update({ 
								amount: 0,
								status: 'paid',
								is_paid: true,
								paid_date: new Date().toISOString(),
								updated_at: new Date().toISOString()
							})
							.eq('id', originalScheduler.id);
					}
				}

				// 3. Update used_amount and remaining_balance in expense_requisitions
				const currentUsedAmount = totalBillsAmount - parseFloat(bill.amount || 0);
				const newUsedAmount = currentUsedAmount + parseFloat(bill.amount);
				const newRemainingBalance = selectedRequestAmount - newUsedAmount;

				const { error: updateError } = await supabase
					.from('expense_requisitions')
					.update({ 
						used_amount: newUsedAmount,
						remaining_balance: newRemainingBalance
						// Status remains 'approved' until request is fully closed with write-off decision
					})
					.eq('id', selectedRequestId);

				if (updateError) throw updateError;
			}

			// Update bill in local array
			bill.billFileUrl = billFileUrl;
			bill.saved = true;
			bill.saving = false;
			bills = [...bills];

			// Send notification to C/O user if selected
			if (bill.coUserId) {
				try {
					await notificationService.createNotification({
						title: 'Requisition Bill Closed',
						message: `A bill has been closed for requisition ${selectedRequestNumber}.\n\nBill Amount: ${parseFloat(bill.amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR\nPayment Method: ${bill.paymentMethod}\nPaid Date: ${bill.paidDate}\nClosed by: ${$currentUser?.username}`,
						type: 'info',
						priority: 'medium',
						target_type: 'specific_users',
						target_users: [bill.coUserId]
					}, $currentUser?.id || $currentUser?.username || 'System');
					console.log('✅ Notification sent to C/O user:', bill.coUserName);
				} catch (notifError) {
					console.error('⚠️ Failed to send notification to C/O user:', notifError);
					// Don't fail the whole operation if notification fails
				}
			}

			successMessage = `Bill ${bill.number} saved successfully!`;
			
			// Check if all bills are saved
			const allSaved = bills.every(b => b.saved);
			if (allSaved) {
				allBillsSaved = true;
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

	async function closeRequest() {
		if (!allBillsSaved) {
			alert('Please save all bills before closing the request');
			return;
		}

		// Validate balance handling if there's a remaining balance
		if (remainingBalance > 0 && balanceAction === 'writeoff' && !writeOffReason.trim()) {
			alert('Please provide a reason for writing off the balance');
			return;
		}

		const confirmed = window.confirm(
			`Are you sure you want to close this request?\n\n` +
			`Request: ${selectedRequestNumber}\n` +
			`Request Amount: ${selectedRequestAmount.toFixed(2)} SAR\n` +
			`Bills Amount: ${totalBillsAmount.toFixed(2)} SAR\n` +
			`Remaining Balance: ${remainingBalance.toFixed(2)} SAR\n` +
			`${remainingBalance > 0 ? `\nBalance Action: ${balanceAction === 'keep' ? 'Keep in Request' : 'Write Off'}` : ''}`
		);

		if (!confirmed) return;

		try {
			saving = true;

		// 1. Handle based on balance action
		if (remainingBalance > 0 && balanceAction === 'writeoff') {
			// WRITE-OFF: Mark everything as closed and paid
			
			// Mark original scheduler entry as fully paid
			const { data: originalScheduler } = await supabase
				.from('expense_scheduler')
				.select('*')
				.eq('requisition_id', selectedRequestId)
				.eq('schedule_type', 'expense_requisition')
				.eq('is_paid', false)
				.maybeSingle();

			if (originalScheduler) {
				await supabase
					.from('expense_scheduler')
					.update({ 
						amount: 0,
						status: 'paid',
						is_paid: true,
						paid_date: new Date().toISOString(),
						description: `Write-off: ${writeOffReason}`,
						updated_at: new Date().toISOString()
					})
					.eq('id', originalScheduler.id);
			}

			// Close the request completely
			const { error: updateError } = await supabase
				.from('expense_requisitions')
				.update({
					status: 'closed',
					is_active: false,
					remaining_balance: 0,
					used_amount: selectedRequestAmount,
					description: `Closed with write-off: ${remainingBalance.toFixed(2)} SAR. Reason: ${writeOffReason}`
				})
				.eq('id', selectedRequestId);

			if (updateError) throw updateError;
			
		} else {
			// KEEP BALANCE: Request stays approved and active for future bills
			// No need to update request status - it stays 'approved' and 'is_active=true'
			// Only the scheduler entry (already updated in saveBill) shows the remaining balance
		}

		// 2. Success notification
		const isFullyClosed = (remainingBalance === 0) || (remainingBalance > 0 && balanceAction === 'writeoff');
		
		await notificationService.createNotification({
			title: isFullyClosed ? 'Request Closed Successfully' : 'Bills Saved Successfully',
			message: `Request ${selectedRequestNumber} ${isFullyClosed ? 'has been closed' : 'updated'} with ${numberOfBills} bill(s).\n\nTotal Amount: ${totalBillsAmount.toFixed(2)} SAR\n${remainingBalance > 0 ? `Remaining Balance: ${remainingBalance.toFixed(2)} SAR (${balanceAction === 'keep' ? 'kept for future bills' : 'written off'})` : ''}`,
			type: 'success',
			priority: 'medium',
			target_type: 'specific_users',
			target_users: [$currentUser?.id]
		}, $currentUser?.id || 'System');

		alert(isFullyClosed ? 'Request closed successfully!' : 'Bills saved successfully! Request remains open for additional bills.');

			dispatch('close'); // Notify parent to close modal and refresh
			
			// If opened as a window, close it automatically
			if (windowId) {
				setTimeout(() => {
					windowManager.closeWindow(windowId);
				}, 1000); // Small delay to show success message
			}
			
			resetForm();

		} catch (error) {
			console.error('Error closing request:', error);
		alert(`Error closing request: ${error.message}`);
	} finally {
		saving = false;
	}
}	function resetForm() {
		currentStep = 1;
		selectedRequestId = '';
		selectedRequestNumber = '';
		selectedRequestAmount = 0;
		selectedRequestBranchId = '';
		selectedRequestBranchName = '';
		numberOfBills = 1;
		bills = [];
		activeBillIndex = null;
		successMessage = '';
		allBillsSaved = false;
		balanceAction = 'keep';
		writeOffReason = '';
		requestSearchQuery = '';
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

	function formatCurrency(amount) {
		return parseFloat(amount || 0).toLocaleString('en-US', { 
			minimumFractionDigits: 2, 
			maximumFractionDigits: 2 
		});
	}
</script>

<div class="request-closure-manager">
	<!-- Progress Indicator -->
	<div class="progress-indicator">
		<div class="step" class:active={currentStep >= 1} class:completed={currentStep > 1}>
			<div class="step-number">1</div>
			<div class="step-label">Select Request</div>
		</div>
		<div class="step-line" class:active={currentStep > 1}></div>
		<div class="step" class:active={currentStep >= 2} class:completed={currentStep > 2}>
			<div class="step-number">2</div>
			<div class="step-label">Number of Bills</div>
		</div>
		<div class="step-line" class:active={currentStep > 2}></div>
		<div class="step" class:active={currentStep >= 3}>
			<div class="step-number">3</div>
			<div class="step-label">Bill Details</div>
		</div>
	</div>

	<!-- Step 1: Request Selection -->
	{#if currentStep === 1}
		<div class="step-content">
			<h2>Step 1: Select Request to Close</h2>

			<!-- Search -->
			<div class="form-group">
				<label for="requestSearch">Search Request</label>
				<input
					id="requestSearch"
					type="text"
					class="form-input"
					bind:value={requestSearchQuery}
					on:input={handleRequestSearch}
					placeholder="Search by request number, requester, amount..."
				/>
			</div>

			<!-- Requests Table -->
			<div class="table-container">
				<table class="data-table">
					<thead>
						<tr>
							<th>Select</th>
							<th>Request #</th>
							<th>Branch</th>
							<th>Requester</th>
							<th>Total Amount</th>
							<th>Used Amount</th>
							<th>Remaining</th>
							<th>Status</th>
							<th>Due Date</th>
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
								<td>{request.branches?.name_en || 'N/A'}</td>
								<td>{request.requester_name}</td>
								<td class="amount">{formatCurrency(request.amount)}</td>
								<td class="amount">{formatCurrency(request.used_amount || 0)}</td>
								<td class="amount" style="color: #059669; font-weight: 600;">{formatCurrency(request.remaining_balance || 0)}</td>
								<td>
									<span class="status-badge" class:status-approved={request.status === 'approved'} class:status-closed={request.status === 'closed'}>
										{request.status === 'approved' ? 'Approved' : 'Partially Closed'}
									</span>
								</td>
								<td>{formatDate(request.due_date)}</td>
							</tr>
						{/each}
						{#if filteredRequests.length === 0}
							<tr>
								<td colspan="9" class="no-data">No requests with remaining balance found</td>
							</tr>
						{/if}
					</tbody>
				</table>
			</div>

			<!-- Navigation -->
			<div class="navigation-buttons">
				<button 
					type="button" 
					class="btn-primary" 
					on:click={nextStep}
					disabled={!selectedRequestId}
				>
					Next Step →
				</button>
			</div>
		</div>
	{/if}

	<!-- Step 2: Number of Bills -->
	{#if currentStep === 2}
		<div class="step-content">
			<h2>Step 2: Enter Number of Bills</h2>

			<!-- Selected Request Info -->
			<div class="info-card">
				<h3>Selected Request</h3>
				<p><strong>Request #:</strong> {selectedRequestNumber}</p>
				<p><strong>Branch:</strong> {selectedRequestBranchName}</p>
				<p><strong>Amount:</strong> {formatCurrency(selectedRequestAmount)} SAR</p>
			</div>

			<!-- Number of Bills -->
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
					placeholder="Enter number of bills (1-50)"
				/>
				<small>Enter the total number of bills for this request closure</small>
			</div>

			<!-- Navigation -->
			<div class="navigation-buttons">
				<button 
					type="button" 
					class="btn-secondary" 
					on:click={previousStep}
				>
					← Previous
				</button>
				<button 
					type="button" 
					class="btn-primary" 
					on:click={nextStep}
					disabled={!numberOfBills || numberOfBills < 1}
				>
					Next Step →
				</button>
			</div>
		</div>
	{/if}

	<!-- Step 3: Bill Details -->
	{#if currentStep === 3}
		<div class="step-content">
			<h2>Step 3: Enter Bill Details</h2>

			<!-- Request Summary Info Card -->
			<div class="summary-info-card">
				<div class="summary-grid">
					<div class="summary-item">
						<span class="summary-label">Total Bills:</span>
						<span class="summary-value">{bills.length}</span>
					</div>
					<div class="summary-item">
						<span class="summary-label">Saved Bills:</span>
						<span class="summary-value saved-count">{bills.filter(b => b.saved).length}</span>
					</div>
					<div class="summary-item">
						<span class="summary-label">Total Amount:</span>
						<span class="summary-value">{formatCurrency(totalBillsAmount)} SAR</span>
					</div>
					<div class="summary-item">
						<span class="summary-label">Request Amount:</span>
						<span class="summary-value">{formatCurrency(selectedRequestAmount)} SAR</span>
					</div>
					<div class="summary-item full-width" class:warning-bg={remainingBalance !== 0}>
						<span class="summary-label">Remaining Balance:</span>
						<span class="summary-value" class:warning-text={remainingBalance !== 0}>
							{formatCurrency(Math.abs(remainingBalance))} SAR {remainingBalance < 0 ? '(Overspending)' : ''}
						</span>
					</div>
				</div>
			</div>

			<!-- Bills as Card Buttons -->
			<div class="bills-card-grid">
				{#each bills as bill, index}
					<button
						class="bill-card-button"
						class:saved={bill.saved}
						class:active={activeBillIndex === index}
						on:click={() => selectBill(index)}
					>
						<div class="bill-card-title">Bill {bill.number}</div>
						<div class="bill-card-status">
							{#if bill.saved}
								<span class="status-text saved">✓ Saved</span>
								<span class="bill-card-amount">{formatCurrency(bill.amount || 0)} SAR</span>
							{:else}
								<span class="status-text">Not entered</span>
							{/if}
						</div>
					</button>
				{/each}
			</div>

			<!-- Bill Details Form (shown when a bill is selected) -->
			{#if activeBillIndex !== null}
				{@const bill = bills[activeBillIndex]}
				<div class="bill-form-container">
					<h3>Bill {bill.number} Details</h3>
					
					<div class="bill-form-grid">
						<!-- Bill Type -->
						<div class="form-group">
							<label>Bill Type *</label>
							<select class="form-select" bind:value={bill.billType}>
								{#each billTypes as type}
									<option value={type.value}>{type.label}</option>
								{/each}
							</select>
						</div>

						<!-- Payment Method -->
						<div class="form-group">
							<label>Payment Method *</label>
							<select class="form-select" bind:value={bill.paymentMethod}>
								{#each paymentMethods as method}
									<option value={method.value}>{method.label}</option>
								{/each}
							</select>
						</div>

						<!-- Bill Number (only if not no_bill) -->
						{#if bill.billType !== 'no_bill'}
							<div class="form-group">
								<label>Bill Number *</label>
								<input
									type="text"
									class="form-input"
									bind:value={bill.billNumber}
									placeholder="Enter bill number"
								/>
							</div>

							<!-- Bill Date -->
							<div class="form-group">
								<label>Bill Date *</label>
								<input
									type="date"
									class="form-input"
									bind:value={bill.billDate}
								/>
							</div>
						{/if}

						<!-- Amount -->
						<div class="form-group">
							<label>Amount (SAR) *</label>
							<input
								type="number"
								class="form-input"
								bind:value={bill.amount}
								on:input={() => bills = bills}
								step="0.01"
								min="0"
								placeholder="Enter amount"
							/>
						</div>

						<!-- Paid Date -->
						<div class="form-group">
							<label>Paid Date *</label>
							<input
								type="date"
								class="form-input"
								bind:value={bill.paidDate}
							/>
						</div>

						<!-- Bank Details (if applicable) -->
						{#if bill.paymentMethod && (bill.paymentMethod.includes('bank') || bill.paymentMethod.includes('cheque'))}
							<div class="form-group">
								<label>Bank Name</label>
								<input
									type="text"
									class="form-input"
									bind:value={bill.bankName}
									placeholder="Enter bank name"
								/>
							</div>

							<div class="form-group">
								<label>IBAN</label>
								<input
									type="text"
									class="form-input"
									bind:value={bill.iban}
									placeholder="Enter IBAN"
								/>
							</div>
						{/if}

						<!-- Bill File Upload (only if not no_bill) -->
						{#if bill.billType !== 'no_bill'}
							<div class="form-group full-width">
								<label>Upload Bill File *</label>
								<input
									type="file"
									class="form-input"
									accept="image/*,application/pdf"
									on:change={(e) => handleBillFileChange(e, activeBillIndex)}
								/>
								{#if bill.billFileName}
									<small class="file-name">Selected: {bill.billFileName}</small>
								{/if}
							</div>
					{/if}

					<!-- Expense Category Selection with Table View -->
					<div class="form-group full-width category-section">
						<label>Expense Category *</label>
						
						<!-- Search Input -->
						<input
							type="text"
							class="form-input"
							bind:value={bill.categorySearchQuery}
							on:input={() => handleCategorySearch(activeBillIndex)}
							placeholder="Search by category name..."
						/>

						<!-- Selected Category Display -->
						{#if bill.categoryId}
							<div class="selected-category-display">
								<strong>Selected:</strong> {bill.categoryNameEn} - {bill.categoryNameAr}
								{#if bill.parentCategoryName}
									<span class="parent-badge">{bill.parentCategoryName}</span>
								{/if}
							</div>
						{/if}

						<!-- Category Table -->
						<div class="category-table-container">
							<table class="category-table">
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
											class:selected={bill.categoryId === category.id}
											on:click={() => selectCategory(activeBillIndex, category)}
										>
											<td>
												<input
													type="radio"
													name="category-{activeBillIndex}"
													checked={bill.categoryId === category.id}
													on:change={() => selectCategory(activeBillIndex, category)}
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
					</div>

					<!-- C/O User Selection with Table View -->
					<div class="form-group full-width user-section">
						<label>C/O User (optional)</label>
						
						<!-- Search Input -->
						<input
							type="text"
							class="form-input"
							bind:value={bill.coSearchQuery}
							on:input={() => handleCoSearch(activeBillIndex)}
							placeholder="Search by username or email..."
						/>

						<!-- Selected User Display -->
						{#if bill.coUserId}
							<div class="selected-user-display">
								<strong>Selected:</strong> {bill.coUserName}
							</div>
						{/if}

						<!-- User Table -->
						<div class="user-table-container">
							<table class="user-table">
								<thead>
									<tr>
										<th>Select</th>
										<th>Username</th>
										<th>Email</th>
										<th>Branch</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredUsers as user}
										<tr
											class:selected={bill.coUserId === user.id}
											on:click={() => selectCoUser(activeBillIndex, user)}
										>
											<td>
												<input
													type="radio"
													name="couser-{activeBillIndex}"
													checked={bill.coUserId === user.id}
													on:change={() => selectCoUser(activeBillIndex, user)}
												/>
											</td>
											<td>{user.username}</td>
											<td>{user.email}</td>
											<td>{user.branch_name || 'N/A'}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>

					<!-- Description -->
					<div class="form-group full-width">
						<label>Description</label>
						<textarea
							class="form-textarea"
							bind:value={bill.description}
							rows="2"
							placeholder="Enter description..."
						/>
					</div>

					<!-- Notes -->
					<div class="form-group full-width">
						<label>Notes</label>
						<textarea
							class="form-textarea"
							bind:value={bill.notes}
							rows="2"
							placeholder="Enter additional notes..."
						/>
					</div>
				</div>
							<!-- Bill Actions -->
							<div class="bill-actions">
								<button
									type="button"
									class="btn-secondary"
									on:click={closeBillEditor}
								>
									Cancel
								</button>
								<button
									type="button"
									class="btn-primary"
									on:click={() => saveBill(activeBillIndex)}
									disabled={bill.saving}
								>
									{bill.saving ? 'Saving...' : bill.saved ? 'Update Bill' : 'Save Bill'}
								</button>
							</div>
						</div>
					{/if}			<!-- Balance Handling -->
			{#if remainingBalance > 0}
				<div class="balance-handling">
					<h3>Remaining Balance: {formatCurrency(remainingBalance)} SAR</h3>
					<div class="form-group">
						<label>What would you like to do with the remaining balance?</label>
						<div class="radio-group">
							<label class="radio-label">
								<input
									type="radio"
									bind:group={balanceAction}
									value="keep"
								/>
								<span>Keep balance in request for future use</span>
							</label>
							<label class="radio-label">
								<input
									type="radio"
									bind:group={balanceAction}
									value="writeoff"
								/>
								<span>Write off the balance</span>
							</label>
						</div>
					</div>

					{#if balanceAction === 'writeoff'}
						<div class="form-group">
							<label>Write-off Reason *</label>
							<textarea
								class="form-textarea"
								bind:value={writeOffReason}
								rows="3"
								placeholder="Please explain why you're writing off this balance..."
							/>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Success Message -->
			{#if successMessage}
				<div class="success-message">{successMessage}</div>
			{/if}

			<!-- Navigation -->
			<div class="navigation-buttons">
				<button 
					type="button" 
					class="btn-secondary" 
					on:click={previousStep}
					disabled={saving}
				>
					← Previous
				</button>
				<button 
					type="button" 
					class="btn-success" 
					on:click={closeRequest}
					disabled={!allBillsSaved || saving}
				>
					{saving ? 'Processing...' : 'Close Request'}
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.request-closure-manager {
		padding: 2rem;
		max-width: 1400px;
		margin: 0 auto;
	}

	.progress-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 3rem;
		padding: 2rem 0;
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
	}

	.step-number {
		width: 50px;
		height: 50px;
		border-radius: 50%;
		background: #e0e0e0;
		color: #666;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 1.2rem;
		transition: all 0.3s;
	}

	.step.active .step-number {
		background: #4f46e5;
		color: white;
	}

	.step.completed .step-number {
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 0.9rem;
		color: #666;
		font-weight: 500;
	}

	.step.active .step-label {
		color: #4f46e5;
		font-weight: 600;
	}

	.step-line {
		width: 100px;
		height: 3px;
		background: #e0e0e0;
		margin: 0 1rem;
		transition: all 0.3s;
	}

	.step-line.active {
		background: #10b981;
	}

	.step-content {
		background: white;
		border-radius: 12px;
		padding: 2rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.step-content h2 {
		margin-bottom: 2rem;
		color: #1f2937;
		font-size: 1.5rem;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #374151;
	}

	.form-input,
	.form-select,
	.form-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 1rem;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #4f46e5;
	}

	.form-textarea {
		resize: vertical;
		font-family: inherit;
	}

	.form-group small {
		display: block;
		margin-top: 0.5rem;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.table-container {
		max-height: 500px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		margin-bottom: 2rem;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
	}

	.data-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.data-table th,
	.data-table td {
		padding: 1rem;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
	}

	.data-table th {
		font-weight: 600;
		color: #374151;
	}

	.data-table tbody tr {
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.data-table tbody tr:hover {
		background: #f9fafb;
	}

	.data-table tbody tr.selected {
		background: #ede9fe;
	}

	.data-table .amount {
		font-weight: 600;
		color: #059669;
	}

	.data-table .no-data {
		text-align: center;
		color: #9ca3af;
		padding: 2rem;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.status-badge.status-approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.status-closed {
		background: #fef3c7;
		color: #92400e;
	}

	.info-card {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.info-card.warning {
		background: #fef3c7;
		border-color: #fcd34d;
	}

	.info-card h3 {
		margin-bottom: 1rem;
		color: #1f2937;
	}

	.info-card p {
		margin: 0.5rem 0;
		color: #374151;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem 0;
		border-bottom: 1px solid #e5e7eb;
	}

	.summary-row:last-child {
		border-bottom: none;
		font-weight: 600;
		font-size: 1.1rem;
	}

	.summary-row .amount {
		font-weight: 600;
		color: #059669;
	}

	.summary-row .amount.overspend {
		color: #dc2626;
	}

	.summary-row .amount.negative {
		color: #dc2626;
	}

	/* Summary Info Card - Matching Scheduler Design */
	.summary-info-card {
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
		border: 1px solid #bfdbfe;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		position: sticky;
		top: 0;
		z-index: 10;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.summary-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
	}

	.summary-item.full-width {
		grid-column: 1 / -1;
		padding: 1rem;
		border-radius: 6px;
	}

	.summary-item.warning-bg {
		background: #fef3c7;
		border: 1px solid #fcd34d;
	}

	.summary-label {
		font-weight: 500;
		color: #475569;
	}

	.summary-value {
		font-weight: 600;
		color: #1e293b;
		font-size: 1.1rem;
	}

	.summary-value.saved-count {
		color: #059669;
	}

	.summary-value.warning-text {
		color: #dc2626;
	}

	/* Bills as Card Buttons - Matching Scheduler Design */
	.bills-card-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 1rem;
		margin-bottom: 2rem;
	}

	.bill-card-button {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
		color: white;
		border: none;
		border-radius: 12px;
		padding: 1.5rem 1rem;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		box-shadow: 0 4px 6px rgba(139, 92, 246, 0.3);
	}

	.bill-card-button:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 12px rgba(139, 92, 246, 0.4);
	}

	.bill-card-button.active {
		background: linear-gradient(135deg, #4f46e5 0%, #4338ca 100%);
		box-shadow: 0 6px 16px rgba(79, 70, 229, 0.5);
		transform: scale(1.05);
	}

	.bill-card-button.saved {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		box-shadow: 0 4px 6px rgba(16, 185, 129, 0.3);
	}

	.bill-card-button.saved:hover {
		box-shadow: 0 6px 12px rgba(16, 185, 129, 0.4);
	}

	.bill-card-title {
		font-size: 1.1rem;
		font-weight: 600;
	}

	.bill-card-status {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
	}

	.bill-card-status .status-text {
		font-size: 0.875rem;
		opacity: 0.9;
	}

	.bill-card-status .status-text.saved {
		font-weight: 600;
	}

	.bill-card-amount {
		font-size: 1rem;
		font-weight: 700;
		background: rgba(255, 255, 255, 0.2);
		padding: 0.25rem 0.75rem;
		border-radius: 6px;
		margin-top: 0.25rem;
	}

	/* Bill Form Container */
	.bill-form-container {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 2rem;
		margin-bottom: 2rem;
	}

	.bill-form-container h3 {
		margin-bottom: 1.5rem;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid #e5e7eb;
	}

	.bill-form-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1.5rem;
	}

	.bill-form-grid .form-group.full-width {
		grid-column: 1 / -1;
	}

	.bill-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 1.5rem;
		padding-top: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.selected-item {
		margin-top: 0.5rem;
		padding: 0.75rem;
		background: #ede9fe;
		border: 1px solid #c4b5fd;
		border-radius: 6px;
		color: #5b21b6;
		font-weight: 500;
	}

	.dropdown-list {
		position: absolute;
		z-index: 10;
		width: 100%;
		max-height: 200px;
		overflow-y: auto;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		margin-top: 0.25rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.dropdown-item {
		padding: 0.75rem;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.dropdown-item:hover {
		background: #f3f4f6;
	}

	.dropdown-item small {
		display: block;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.file-name {
		display: block;
		margin-top: 0.5rem;
		color: #059669;
		font-size: 0.875rem;
	}

	/* Category Table Styles */
	.category-section {
		margin-top: 1.5rem;
	}

	.selected-category-display {
		margin-top: 0.75rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #ede9fe 0%, #ddd6fe 100%);
		border: 1px solid #c4b5fd;
		border-radius: 6px;
		color: #5b21b6;
		font-weight: 500;
	}

	.category-table-container {
		margin-top: 1rem;
		max-height: 400px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.category-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.category-table thead {
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
		z-index: 1;
	}

	.category-table thead th {
		padding: 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #d1d5db;
		font-size: 0.875rem;
	}

	.category-table tbody tr {
		cursor: pointer;
		transition: background-color 0.2s;
		border-bottom: 1px solid #f3f4f6;
	}

	.category-table tbody tr:hover {
		background: #f9fafb;
	}

	.category-table tbody tr.selected {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
	}

	.category-table tbody td {
		padding: 0.75rem;
		color: #1f2937;
		font-size: 0.875rem;
	}

	.category-table tbody td:first-child {
		width: 60px;
		text-align: center;
	}

	.category-table input[type="radio"] {
		cursor: pointer;
		width: 18px;
		height: 18px;
	}

	.parent-category-cell {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}

	.parent-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
		border: 1px solid #d1d5db;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		color: #4b5563;
	}

	.parent-badge.arabic {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		border-color: #fbbf24;
		color: #92400e;
	}

	/* User Table Styles */
	.user-section {
		margin-top: 1.5rem;
	}

	.selected-user-display {
		margin-top: 0.75rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		border: 1px solid #93c5fd;
		border-radius: 6px;
		color: #1e40af;
		font-weight: 500;
	}

	.user-table-container {
		margin-top: 1rem;
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.user-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.user-table thead {
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
		z-index: 1;
	}

	.user-table thead th {
		padding: 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #d1d5db;
		font-size: 0.875rem;
	}

	.user-table tbody tr {
		cursor: pointer;
		transition: background-color 0.2s;
		border-bottom: 1px solid #f3f4f6;
	}

	.user-table tbody tr:hover {
		background: #f9fafb;
	}

	.user-table tbody tr.selected {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
	}

	.user-table tbody td {
		padding: 0.75rem;
		color: #1f2937;
		font-size: 0.875rem;
	}

	.user-table tbody td:first-child {
		width: 60px;
		text-align: center;
	}

	.user-table input[type="radio"] {
		cursor: pointer;
		width: 18px;
		height: 18px;
	}

	.balance-handling {
		background: #fef3c7;
		border: 2px solid #fcd34d;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.balance-handling h3 {
		margin-bottom: 1rem;
		color: #92400e;
	}

	.radio-group {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		margin-top: 0.5rem;
	}

	.radio-label {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.radio-label:hover {
		background: #f9fafb;
	}

	.radio-label input[type="radio"] {
		cursor: pointer;
	}

	.success-message {
		padding: 1rem;
		background: #d1fae5;
		border: 1px solid #10b981;
		border-radius: 8px;
		color: #065f46;
		font-weight: 500;
		margin-bottom: 1.5rem;
		text-align: center;
	}

	.navigation-buttons {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 2rem;
	}

	.btn-primary,
	.btn-secondary,
	.btn-success {
		padding: 0.75rem 2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-primary {
		background: #4f46e5;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #4338ca;
	}

	.btn-primary:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.btn-secondary {
		background: #6b7280;
		color: white;
	}

	.btn-secondary:hover:not(:disabled) {
		background: #4b5563;
	}

	.btn-success {
		background: #10b981;
		color: white;
	}

	.btn-success:hover:not(:disabled) {
		background: #059669;
	}

	.btn-success:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}
</style>
