<script>
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let item = null;
	export let itemId = '';
	export let windowId = '';
	export let onIssueComplete = () => {};

	let isLoading = false;
	let step = 'select-category'; // 'select-category', 'select-type', 'select-approver', or 'receipt'
	let selectedCategory = null;
	let selectedUser = null;
	let selectedRequester = null;
	let selectedIssueType = null; // Store selected issue type
	let selectedBranch = null; // For stock transfer branch selection
	let showBranchSelection = false;
	let selectedApprover = null;
	let approvers = [];
	let approverSearchQuery = '';
	let approversLoading = false;
	let users = [];
	let requesters = [];
	let branches = {};
	let positions = {}; // Map of employee_id -> position_name
	let searchQuery = '';
	let requesterSearchQuery = '';
	let usersLoading = false;
	let requestersLoading = false;
	let showUserTable = false;
	let showRequesterTable = false;
	let showAddRequesterForm = false;
	let newRequester = {
		requester_id: '',
		requester_name: '',
		contact_number: ''
	};
	let savingRequester = false;
	let filterBranch = ''; // Filter by branch
	let filterPosition = ''; // Filter by position

	async function selectCategory(category) {
		selectedCategory = category;
		if (category === 'internal') {
			// Load users and branches for internal
			await loadUsersAndBranches();
			showUserTable = true;
			showRequesterTable = false;
		} else {
			// External - load requesters
			await loadRequesters();
			showUserTable = false;
			showRequesterTable = true;
		}
	}

	async function loadUsersAndBranches() {
		usersLoading = true;
		try {
			// Load users, branches, and position-related data in parallel with optimized limits
			const [usersResult, branchesResult, assignmentsResult] = await Promise.all([
				supabase
					.from('users')
					.select('id, username, employee_id, branch_id')
					.limit(200),
				supabase
					.from('branches')
					.select('id, name_en, location_en')
					.limit(50),
				supabase
					.from('hr_position_assignments')
					.select('employee_id, hr_positions(position_title_en)')
					.eq('is_current', true)
					.limit(200)
			]);

			if (!usersResult.error && usersResult.data) {
				users = usersResult.data;
			}

			if (!branchesResult.error && branchesResult.data) {
				branches = {};
				branchesResult.data.forEach((branch) => {
					branches[branch.id] = `${branch.name_en} - ${branch.location_en}`;
				});
			}

			// Build positions map from assignments with position titles
			if (!assignmentsResult.error && assignmentsResult.data) {
				positions = {};
				assignmentsResult.data.forEach((assignment) => {
					if (assignment.hr_positions && assignment.hr_positions.position_title_en) {
						positions[assignment.employee_id] = assignment.hr_positions.position_title_en;
					}
				});
			}
		} catch (error) {
			console.error('Error loading users and branches:', error);
		} finally {
			usersLoading = false;
		}
	}

	async function loadRequesters() {
		requestersLoading = true;
		try {
			const requestersResult = await supabase
				.from('requesters')
				.select('id, requester_id, requester_name, contact_number')
				.order('requester_name', { ascending: true });

			if (!requestersResult.error && requestersResult.data) {
				requesters = requestersResult.data;
			}
		} catch (error) {
			console.error('Error loading requesters:', error);
		} finally {
			requestersLoading = false;
		}
	}

	async function loadApprovers() {
		approversLoading = true;
		try {
			// First, get user_ids from approval_permissions where can_approve_purchase_vouchers is true
			const { data: permData, error: permError } = await supabase
				.from('approval_permissions')
				.select('user_id')
				.eq('can_approve_purchase_vouchers', true)
				.eq('is_active', true);

			if (permError) {
				console.error('Error loading approval permissions:', permError);
				approvers = [];
				return;
			}

			if (!permData || permData.length === 0) {
				console.log('No users with purchase voucher approval permission found');
				approvers = [];
				return;
			}

			// Extract user IDs
			const userIds = permData.map(item => item.user_id);
			console.log('User IDs with approval permission:', userIds);

			// Now get the user details
			const { data: userData, error: userError } = await supabase
				.from('users')
				.select('id, username, employee_id, branch_id')
				.in('id', userIds);

			if (userError) {
				console.error('Error loading user details:', userError);
				approvers = [];
			} else {
				approvers = userData || [];
				console.log('Loaded approvers:', approvers);
			}
		} catch (error) {
			console.error('Error loading approvers:', error);
			approvers = [];
		} finally {
			approversLoading = false;
		}
	}

	function selectUser(user) {
		selectedUser = user;
		// Don't change step, stay in select-category to show user + issue type inline
	}

	function selectRequester(requester) {
		selectedRequester = requester;
		// Don't change step, stay in select-category to show requester + issue type inline
	}

	function selectBranch(branchId) {
		selectedBranch = branchId;
		// After branch selection for stock transfer, go to approver selection
		showBranchSelection = false;
		loadApprovers();
		step = 'select-approver';
	}

	function goBackFromBranch() {
		showBranchSelection = false;
		selectedBranch = null;
	}

	function showAddRequester() {
		showAddRequesterForm = true;
		newRequester = {
			requester_id: '',
			requester_name: '',
			contact_number: ''
		};
	}

	function cancelAddRequester() {
		showAddRequesterForm = false;
		newRequester = {
			requester_id: '',
			requester_name: '',
			contact_number: ''
		};
	}

	async function saveNewRequester() {
		if (!newRequester.requester_id || !newRequester.requester_name) {
			alert('Please fill in Requester ID and Name');
			return;
		}

		savingRequester = true;
		try {
			const { data, error } = await supabase
				.from('requesters')
				.insert([{
					requester_id: newRequester.requester_id,
					requester_name: newRequester.requester_name,
					contact_number: newRequester.contact_number || null,
					created_by: $currentUser?.id
				}])
				.select();

			if (error) {
				console.error('Error adding requester:', error);
				alert('Error adding requester: ' + error.message);
			} else {
				// Refresh requesters list
				await loadRequesters();
				showAddRequesterForm = false;
				newRequester = {
					requester_id: '',
					requester_name: '',
					contact_number: ''
				};
				alert('Requester added successfully!');
			}
		} catch (error) {
			console.error('Error:', error);
			alert('Error adding requester');
		} finally {
			savingRequester = false;
		}
	}

	function goBack() {
		if (showBranchSelection) {
			// If on branch selection, go back to issue type selection
			showBranchSelection = false;
			selectedBranch = null;
		} else if (step === 'select-approver') {
			// Go back from approver selection to category with selected user/requester
			step = 'select-category';
			selectedApprover = null;
			approverSearchQuery = '';
		} else if (step === 'receipt') {
			// Go back from receipt
			if (selectedIssueType === 'gift' || selectedIssueType === 'sales') {
				// Go back to approver selection
				step = 'select-approver';
			} else if (selectedIssueType === 'stock transfer' && selectedCategory === 'internal') {
				step = 'select-category';
				showBranchSelection = true;
			} else {
				step = 'select-category';
				selectedIssueType = null;
			}
		} else if (selectedUser) {
			// Clear selected user, go back to user table
			selectedUser = null;
			searchQuery = '';
			filterBranch = '';
			filterPosition = '';
		} else if (selectedRequester) {
			// Clear selected requester, go back to requester table
			selectedRequester = null;
			requesterSearchQuery = '';
		} else if (showUserTable && selectedCategory === 'internal') {
			// Close user table, back to category selection
			showUserTable = false;
			selectedCategory = null;
		} else if (showRequesterTable && selectedCategory === 'external') {
			// Close requester table, back to category selection
			showRequesterTable = false;
			selectedCategory = null;
		} else if (step === 'select-type') {
			// Back from type selection to category
			step = 'select-category';
			selectedCategory = null;
			showUserTable = false;
			showRequesterTable = false;
		}
	}

	$: filteredUsers = users.filter(user => {
		const matchesSearch = user.username.toLowerCase().includes(searchQuery.toLowerCase());
		const matchesBranch = !filterBranch || user.branch_id === filterBranch;
		const matchesPosition = !filterPosition || positions[user.employee_id] === filterPosition;
		return matchesSearch && matchesBranch && matchesPosition;
	});

	$: filteredRequesters = requesters.filter(requester => {
		const matchesSearch = requester.requester_name.toLowerCase().includes(requesterSearchQuery.toLowerCase()) ||
			(requester.requester_id && requester.requester_id.toLowerCase().includes(requesterSearchQuery.toLowerCase()));
		return matchesSearch;
	});

	$: filteredApprovers = approvers.filter(approver => {
		const matchesSearch = approver.username.toLowerCase().includes(approverSearchQuery.toLowerCase());
		return matchesSearch;
	});

	$: uniqueBranches = Array.from(new Set(users.map(u => u.branch_id)))
		.filter(id => id && branches[id])
		.sort((a, b) => branches[a].localeCompare(branches[b]));

	$: uniquePositions = Array.from(new Set(users.map(u => positions[u.employee_id]).filter(Boolean)))
		.sort();

	function selectApprover(approver) {
		selectedApprover = approver;
		// After selecting approver, go to receipt
		step = 'receipt';
	}

	function handleIssue(type) {
		selectedIssueType = type;
		// If stock transfer for internal, show branch selection
		if (type === 'stock transfer' && selectedCategory === 'internal') {
			showBranchSelection = true;
		} else if (type === 'gift' || type === 'sales') {
			// For gift/sales, go to approver selection
			loadApprovers();
			step = 'select-approver';
		} else {
			// For other types, go to receipt
			step = 'receipt';
		}
	}

	function printReceipt() {
		// Get the receipt container content
		const receiptContent = document.querySelector('.receipt-container');
		if (!receiptContent) return;

		// Open a new window for printing
		const printWindow = window.open('', '_blank', 'width=800,height=600');
		if (!printWindow) {
			alert('Please allow popups to print the receipt');
			return;
		}

		printWindow.document.write(`
			<!DOCTYPE html>
			<html>
			<head>
				<title>Purchase Voucher Issue Receipt</title>
				<style>
					@page {
						size: A4;
						margin: 10mm;
					}
					* {
						margin: 0;
						padding: 0;
						box-sizing: border-box;
					}
					body {
						font-family: Arial, sans-serif;
						padding: 10mm;
						background: white;
					}
					.logo-container {
						display: flex;
						justify-content: center;
						align-items: center;
						margin-bottom: 8mm;
					}
					.app-logo {
						width: 60px;
						height: 60px;
						object-fit: contain;
					}
					.receipt-header {
						text-align: center;
						margin-bottom: 8mm;
						border-bottom: 2px solid #1f2937;
						padding-bottom: 6mm;
					}
					.receipt-header h1 {
						font-size: 16px;
						font-weight: 700;
						color: #1f2937;
						margin-bottom: 4mm;
					}
					.receipt-date {
						font-size: 11px;
						color: #4b5563;
					}
					.receipt-section {
						margin-bottom: 6mm;
						padding: 4mm;
						background: #f9fafb;
						border-radius: 4px;
					}
					.receipt-section h2 {
						font-size: 12px;
						font-weight: 600;
						color: #374151;
						margin-bottom: 4mm;
						padding-bottom: 2mm;
						border-bottom: 1px solid #e5e7eb;
					}
					.detail-row {
						display: flex;
						justify-content: space-between;
						padding: 2mm 0;
						font-size: 11px;
						border-bottom: 1px dashed #e5e7eb;
					}
					.detail-row:last-child {
						border-bottom: none;
					}
					.detail-row .label {
						color: #6b7280;
						font-weight: 500;
					}
					.detail-row .value {
						color: #1f2937;
						font-weight: 600;
						text-align: right;
					}
					.signature-section {
						margin-top: 10mm;
					}
					.signature-line {
						width: 60%;
						margin: 0 auto;
						border-bottom: 1px solid #1f2937;
						height: 15mm;
					}
					.signature-label {
						text-align: center;
						font-size: 10px;
						margin-top: 2mm;
						color: #6b7280;
					}
					.timestamp {
						text-align: center;
						font-size: 9px;
						color: #6b7280;
						margin-top: 6mm;
					}
				</style>
			</head>
			<body>
				${receiptContent.innerHTML}
			</body>
			</html>
		`);

		printWindow.document.close();
		
		// Wait for content to load, then print
		printWindow.onload = function() {
			printWindow.focus();
			printWindow.print();
			printWindow.close();
		};
	}

	async function captureReceiptAsImage() {
		const receiptElement = document.querySelector('.receipt-container');
		if (!receiptElement) return null;

		try {
			// Dynamically import html2canvas
			const html2canvas = (await import('html2canvas')).default;
			
			const canvas = await html2canvas(receiptElement, {
				scale: 2, // Higher quality
				backgroundColor: '#ffffff',
				logging: false,
				useCORS: true
			});

			// Convert to blob
			return new Promise((resolve) => {
				canvas.toBlob((blob) => {
					resolve(blob);
				}, 'image/png', 0.95);
			});
		} catch (error) {
			console.error('Error capturing receipt:', error);
			return null;
		}
	}

	async function uploadReceiptImage(blob) {
		if (!blob) return null;

		const fileName = `receipt_${item.purchase_voucher_id}_${item.serial_number}_${Date.now()}.png`;
		const filePath = `single/${fileName}`;

		const { data, error } = await supabase.storage
			.from('purchase-voucher-receipts')
			.upload(filePath, blob, {
				contentType: 'image/png',
				cacheControl: '3600',
				upsert: false
			});

		if (error) {
			console.error('Error uploading receipt:', error);
			return null;
		}

		// Get public URL
		const { data: urlData } = supabase.storage
			.from('purchase-voucher-receipts')
			.getPublicUrl(filePath);

		return urlData?.publicUrl || null;
	}

	async function saveReceipt() {
		if (isLoading || !itemId || !$currentUser?.id) return;
		isLoading = true;

		try {
			// Capture receipt as image first
			const receiptBlob = await captureReceiptAsImage();
			let receiptUrl = null;

			if (receiptBlob) {
				receiptUrl = await uploadReceiptImage(receiptBlob);
			}

			const updateData = {};

			// Add receipt URL if captured
			if (receiptUrl) {
				updateData.receipt_url = receiptUrl;
			}

			if (selectedIssueType === 'gift' || selectedIssueType === 'sales') {
				// For gift/sales: Set approval_status to pending and update issue details
				updateData.approval_status = 'pending';
				updateData.issue_type = selectedIssueType;
				updateData.issued_by = $currentUser.id;
				updateData.issued_date = new Date().toISOString();
				
				// Store the approver_id
				if (selectedApprover) {
					updateData.approver_id = selectedApprover.id;
				}
				
				// Set issued_to if a user was selected
				if (selectedUser) {
					updateData.issued_to = selectedUser.id;
				}
				
				// Status stays as 'stocked', will be changed to 'issued' after approval
				// Stock stays as 1, will be set to 0 after approval
			} else if (selectedIssueType === 'stock transfer') {
				// For stock transfer: Set approval_status to pending
				// DO NOT change issue_type, issued_by, issued_date, or stock
				updateData.approval_status = 'pending';
				
				// Store the approver_id
				if (selectedApprover) {
					updateData.approver_id = selectedApprover.id;
				}
				
				// Store PENDING stock_person and stock_location - DO NOT update actual columns until approved
				if (selectedUser) {
					updateData.pending_stock_person = selectedUser.id; // Store intended stock person
				}
				if (selectedBranch) {
					updateData.pending_stock_location = selectedBranch; // Store intended location
				}
				
				// Keep current stock_location, stock_person, issue_type, issued_by, issued_date, stock unchanged until approved
			}

			// Update the voucher item
			const { error } = await supabase
				.from('purchase_voucher_items')
				.update(updateData)
				.eq('id', itemId);

			if (error) {
				console.error('Error saving voucher:', error);
				alert('Error saving voucher: ' + error.message);
			} else {
				alert('Voucher sent for approval successfully!');
				onIssueComplete();
				// Close this window
				if (windowId) {
					windowManager.closeWindow(windowId);
				}
			}
		} catch (error) {
			console.error('Error:', error);
			alert('Error saving voucher');
		} finally {
			isLoading = false;
		}
	}

	const translations = {
		en: {
			title: 'VOUCHER ISSUE RECEIPT',
			voucherDetails: 'VOUCHER DETAILS',
			issueInfo: 'ISSUE INFORMATION',
			status: 'STATUS',
			pvId: 'PV ID',
			serialNumber: 'Serial Number',
			value: 'Value',
			category: 'Category',
			issueType: 'Issue Type',
			issuedTo: 'Issued To',
			branch: 'Branch',
			position: 'Position',
			readyToIssue: 'Ready to Issue',
			timestamp: 'Timestamp',
			printReceipt: 'Print Receipt',
			saveClose: 'Save & Close'
		},
		ar: {
			title: 'إيصال إصدار القسيمة',
			voucherDetails: 'تفاصيل القسيمة',
			issueInfo: 'معلومات الإصدار',
			status: 'الحالة',
			pvId: 'معرّف المشروع',
			serialNumber: 'الرقم التسلسلي',
			value: 'القيمة',
			category: 'الفئة',
			issueType: 'نوع الإصدار',
			issuedTo: 'صادر إلى',
			branch: 'الفرع',
			position: 'المنصب',
			readyToIssue: 'جاهز للإصدار',
			timestamp: 'الوقت',
			printReceipt: 'طباعة الإيصال',
			saveClose: 'حفظ وإغلاق'
		}
	};

	function getTranslation(key) {
		return translations[language][key] || translations.en[key];
	}
</script>

<div class="issue-modal">
	<div class="content">
		{#if step === 'select-category'}
			<h3>Issue Voucher</h3>
			<div class="details">
				<p><span class="label">PV ID:</span> <strong>{item.purchase_voucher_id}</strong></p>
				<p><span class="label">Serial:</span> <strong>{item.serial_number}</strong></p>
				<p><span class="label">Value:</span> <strong>{item.value}</strong></p>
				<p class="type-label">Select category:</p>
			</div>
			<div class="buttons">
				<button class="btn-internal" on:click={() => selectCategory('internal')}>Internal</button>
				<button class="btn-external" on:click={() => selectCategory('external')}>External</button>
			</div>

			{#if showUserTable}
				{#if selectedUser}
					<!-- Show selected user info and issue type -->
					<div class="selected-info">
						<p class="selected-label">Selected User:</p>
						<div class="user-card">
							<div class="user-detail">
								<span class="detail-label">Username:</span>
								<span class="detail-value">{selectedUser.username}</span>
							</div>
							<div class="user-detail">
								<span class="detail-label">Branch:</span>
								<span class="detail-value">{branches[selectedUser.branch_id] || 'N/A'}</span>
							</div>
							<div class="user-detail">
								<span class="detail-label">Position:</span>
								<span class="detail-value">{positions[selectedUser.employee_id] || 'N/A'}</span>
							</div>
						</div>
					</div>

					{#if showBranchSelection}
						<!-- Branch selection for stock transfer -->
						<p class="type-label">Select transfer branch:</p>
						<div class="users-table-container">
							<table class="users-table">
								<thead>
									<tr>
										<th>Branch Name</th>
										<th>Action</th>
									</tr>
								</thead>
								<tbody>
									{#each Object.entries(branches) as [branchId, branchName] (branchId)}
										<tr>
											<td>{branchName}</td>
											<td>
												<button class="btn-select" on:click={() => selectBranch(branchId)}>
													Select
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<button class="btn-back" on:click={goBackFromBranch}>Back to Issue Type</button>
					{:else}
						<p class="type-label">Select issue type:</p>
						<div class="buttons three-col">
							<button class="btn-gift" on:click={() => handleIssue('gift')}>Gift</button>
							<button class="btn-sales" on:click={() => handleIssue('sales')}>Sales</button>
							<button class="btn-transfer" on:click={() => handleIssue('stock transfer')}>Stock Transfer</button>
						</div>
						<button class="btn-back" on:click={goBack}>Back to User Selection</button>
					{/if}
				{:else}
					<!-- Show user selection table -->
					<div class="search-section">
						<input
							type="text"
							placeholder="Search users..."
							bind:value={searchQuery}
							class="search-input"
							disabled={usersLoading}
						/>
						<select bind:value={filterBranch} class="filter-select" disabled={usersLoading}>
							<option value="">All Branches</option>
							{#each uniqueBranches as branchId}
								<option value={branchId}>{branches[branchId]}</option>
							{/each}
						</select>
						<select bind:value={filterPosition} class="filter-select" disabled={usersLoading}>
							<option value="">All Positions</option>
							{#each uniquePositions as position}
								<option value={position}>{position}</option>
							{/each}
						</select>
					</div>
					{#if usersLoading}
						<p class="loading">Loading users...</p>
					{:else if filteredUsers.length === 0}
						<p class="no-data">No users found</p>
					{:else}
						<div class="users-table-container">
							<table class="users-table">
								<thead>
									<tr>
										<th>Username</th>
										<th>Branch</th>
										<th>Position</th>
										<th>Action</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredUsers as user (user.id)}
										<tr>
											<td>{user.username}</td>
											<td>{branches[user.branch_id] || 'N/A'}</td>
											<td>{positions[user.employee_id] || 'N/A'}</td>
											<td>
												<button class="btn-select" on:click={() => selectUser(user)}>
													Select
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
					<button class="btn-back" on:click={goBack}>Back to Category</button>
				{/if}
			{/if}

			{#if showRequesterTable}
				{#if selectedRequester}
					<!-- Show selected requester info and issue type -->
					<div class="selected-info">
						<p class="selected-label">Selected Requester:</p>
						<div class="user-card">
							<div class="user-detail">
								<span class="detail-label">Requester ID:</span>
								<span class="detail-value">{selectedRequester.requester_id}</span>
							</div>
							<div class="user-detail">
								<span class="detail-label">Name:</span>
								<span class="detail-value">{selectedRequester.requester_name}</span>
							</div>
							<div class="user-detail">
								<span class="detail-label">Contact Number:</span>
								<span class="detail-value">{selectedRequester.contact_number || 'N/A'}</span>
							</div>
						</div>
					</div>

					<p class="type-label">Select issue type:</p>
					<div class="buttons">
						<button class="btn-gift" on:click={() => handleIssue('gift')}>Gift</button>
						<button class="btn-sales" on:click={() => handleIssue('sales')}>Sales</button>
					</div>
					<button class="btn-back" on:click={goBack}>Back to Requester Selection</button>
				{:else}
					<!-- Show requester selection table -->
					{#if showAddRequesterForm}
						<!-- Add New Requester Form -->
						<div class="add-requester-form">
							<h4>Add New Requester</h4>
							<div class="form-group">
								<label>Requester ID <span class="required">*</span></label>
								<input
									type="text"
									bind:value={newRequester.requester_id}
									placeholder="Enter requester ID"
									class="form-input"
									disabled={savingRequester}
								/>
							</div>
							<div class="form-group">
								<label>Requester Name <span class="required">*</span></label>
								<input
									type="text"
									bind:value={newRequester.requester_name}
									placeholder="Enter requester name"
									class="form-input"
									disabled={savingRequester}
								/>
							</div>
							<div class="form-group">
								<label>Contact Number</label>
								<input
									type="text"
									bind:value={newRequester.contact_number}
									placeholder="Enter contact number"
									class="form-input"
									disabled={savingRequester}
								/>
							</div>
							<div class="form-actions">
								<button class="btn-cancel" on:click={cancelAddRequester} disabled={savingRequester}>
									Cancel
								</button>
								<button class="btn-save" on:click={saveNewRequester} disabled={savingRequester}>
									{#if savingRequester}
										Saving...
									{:else}
										Save Requester
									{/if}
								</button>
							</div>
						</div>
					{:else}
						<div class="search-section">
							<input
								type="text"
								placeholder="Search by name or ID..."
								bind:value={requesterSearchQuery}
								class="search-input"
								disabled={requestersLoading}
							/>
							<button class="btn-add-requester" on:click={showAddRequester} disabled={requestersLoading}>
								➕ Add New
							</button>
						</div>
					
					{#if !requestersLoading && requesters.length > 0}
						<div class="count-info">
							<span class="count-label">Total Requesters:</span>
							<span class="count-value">{requesters.length}</span>
							{#if requesterSearchQuery}
								<span class="count-separator">|</span>
								<span class="count-label">Filtered:</span>
								<span class="count-value">{filteredRequesters.length}</span>
							{/if}
						</div>
					{/if}
					
					{#if requestersLoading}
						<p class="loading">Loading requesters...</p>
					{:else if filteredRequesters.length === 0}
						<p class="no-data">No requesters found</p>
					{:else}
						<div class="users-table-container">
							<table class="users-table">
								<thead>
									<tr>
										<th>Requester ID</th>
										<th>Name</th>
										<th>Contact Number</th>
										<th>Action</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredRequesters as requester (requester.id)}
										<tr>
											<td>{requester.requester_id}</td>
											<td>{requester.requester_name}</td>
											<td>{requester.contact_number || 'N/A'}</td>
											<td>
												<button class="btn-select" on:click={() => selectRequester(requester)}>
													Select
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
					{/if}
				{/if}
			{/if}
			<button class="btn-back" on:click={goBack}>Back to Category</button>
		{/if}
	</div>
	{#if step === 'select-approver'}
		<!-- Approver Selection Step -->
		<div class="content">
			<h3>Select Approver</h3>
			<div class="details">
				<p><span class="label">PV ID:</span> <strong>{item.purchase_voucher_id}</strong></p>
				<p><span class="label">Serial:</span> <strong>{item.serial_number}</strong></p>
				<p><span class="label">Value:</span> <strong>{item.value}</strong></p>
				<p><span class="label">Issue Type:</span> <strong class="issue-type-badge">{selectedIssueType}</strong></p>
			</div>

			{#if selectedApprover}
				<!-- Show selected approver -->
				<div class="selected-info">
					<p class="selected-label">Selected Approver:</p>
					<div class="user-card">
						<div class="user-detail">
							<span class="detail-label">Username:</span>
							<span class="detail-value">{selectedApprover.username}</span>
						</div>
						<div class="user-detail">
							<span class="detail-label">Branch:</span>
							<span class="detail-value">{branches[selectedApprover.branch_id] || 'N/A'}</span>
						</div>
					</div>
				</div>
				<button class="btn-proceed" on:click={() => step = 'receipt'}>
					Proceed to Receipt
				</button>
				<button class="btn-back" on:click={goBack}>Change Approver</button>
			{:else}
				<!-- Show approver selection table -->
				<div class="search-section" style="grid-template-columns: 1fr;">
					<input
						type="text"
						placeholder="Search approvers..."
						bind:value={approverSearchQuery}
						class="search-input"
						disabled={approversLoading}
					/>
				</div>

				{#if approversLoading}
					<p class="loading">Loading approvers...</p>
				{:else if filteredApprovers.length === 0}
					<p class="no-data">No approvers found</p>
				{:else}
					<div class="users-table-container">
						<table class="users-table">
							<thead>
								<tr>
									<th>Username</th>
									<th>Branch</th>
									<th>Action</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredApprovers as approver (approver.id)}
									<tr>
										<td>{approver.username}</td>
										<td>{branches[approver.branch_id] || 'N/A'}</td>
										<td>
											<button class="btn-select" on:click={() => selectApprover(approver)}>
												Select
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
				<button class="btn-back" on:click={goBack}>Back</button>
			{/if}
		</div>
	{/if}
	{#if step === 'receipt'}
		<!-- Full-Page A4 Receipt - Bilingual -->
		<div class="receipt-page">
			<div class="receipt-container">
				<!-- App Logo - Centered -->
				<div class="logo-container">
					<img src="/icons/logo.png" alt="App Logo" class="app-logo" />
				</div>

				<!-- Header - Bilingual -->
				<div class="receipt-header">
					<h1>إيصال إصدار قسيمة الشراء / PURCHASE VOUCHER ISSUE RECEIPT</h1>
					<p class="receipt-date">Date / التاريخ: {new Date().toLocaleDateString()}</p>
				</div>

			<!-- Voucher Details Section - Bilingual -->
			<div class="receipt-section">
				<h2>تفاصيل القسيمة / VOUCHER DETAILS</h2>
				
				<!-- Voucher Table -->
				<div style="margin-top: 4mm; overflow-x: auto;">
					<table style="width: 100%; border-collapse: collapse; font-size: 9px;">
						<thead>
							<tr style="background: #f3f4f6; border-bottom: 2px solid #1f2937;">
								<th style="padding: 4mm 2mm; text-align: left; font-weight: 600;">PV ID</th>
								<th style="padding: 4mm 2mm; text-align: left; font-weight: 600;">الرقم التسلسلي / Serial</th>
								<th style="padding: 4mm 2mm; text-align: right; font-weight: 600;">القيمة / Value</th>
							</tr>
						</thead>
						<tbody>
							<tr style="border-bottom: 1px solid #e5e7eb;">
								<td style="padding: 3mm 2mm;">{item.purchase_voucher_id}</td>
								<td style="padding: 3mm 2mm;">{item.serial_number}</td>
								<td style="padding: 3mm 2mm; text-align: right;">{item.value}</td>
							</tr>
						</tbody>
						<tfoot>
							<tr style="background: #1f2937; color: white; font-weight: 700;">
								<td colspan="2" style="padding: 4mm 2mm; text-align: left;">المجموع / TOTAL</td>
								<td style="padding: 4mm 2mm; text-align: right;">{item.value}</td>
							</tr>
						</tfoot>
					</table>
				</div>
			</div>

			<!-- Issue Information Section - Bilingual -->
			<div class="receipt-section">
				<h2>معلومات الإصدار / ISSUE INFORMATION</h2>
				<div class="detail-row">
					<span class="label">الفئة / Category:</span>
					<span class="value">{selectedCategory.toUpperCase()}</span>
				</div>
				<div class="detail-row">
					<span class="label">نوع الإصدار / Issue Type:</span>
					<span class="value">{selectedIssueType.toUpperCase()}</span>
				</div>
				{#if selectedUser}
					<div class="detail-row">
						<span class="label">المتلقي / Receiver:</span>
						<span class="value">{selectedUser.username}</span>
					</div>
					<div class="detail-row">
						<span class="label">اسم الفرع / Branch Name:</span>
						<span class="value">{branches[selectedUser.branch_id] || 'N/A'}</span>
					</div>
					{#if selectedIssueType === 'stock transfer' && selectedBranch}
						<div class="detail-row">
							<span class="label">فرع النقل / Transfer To Branch:</span>
							<span class="value">{branches[selectedBranch] || 'N/A'}</span>
						</div>
					{/if}
				{/if}
				{#if selectedRequester}
					<div class="detail-row">
						<span class="label">المتلقي / Receiver:</span>
						<span class="value">{selectedRequester.requester_name}</span>
					</div>
					<div class="detail-row">
						<span class="label">رقم المتلقي / Requester ID:</span>
						<span class="value">{selectedRequester.requester_id}</span>
					</div>
					<div class="detail-row">
						<span class="label">رقم الاتصال / Contact Number:</span>
						<span class="value">{selectedRequester.contact_number || 'N/A'}</span>
					</div>
				{/if}
			<div class="detail-row">
				<span class="label">الصادر من / Issuer:</span>
				<span class="value">{$currentUser?.username || 'N/A'}</span>
			</div>
		</div>

		<!-- Signature Section -->
		<div class="receipt-section signature-section">
			<div style="display: flex; justify-content: space-between; margin-bottom: 12mm;">
				<div style="flex: 1;">
					<div class="signature-line"></div>
					<p style="margin: 4mm 0 0 0; font-size: 10px; text-align: center;">توقيع المتلقي / Receiver Signature</p>
				</div>
			</div>
		</div>

		<!-- Timestamp -->
		<div style="text-align: center; font-size: 9px; color: #6b7280; margin-top: 6mm;">
			Timestamp / الوقت: {new Date().toLocaleString()}
		</div>
	</div>

	<!-- Action Buttons -->
	<div class="receipt-actions">
		<button class="btn-print" on:click={printReceipt} disabled={isLoading}>
			🖨️ Print Receipt
		</button>
		<button class="btn-save" on:click={saveReceipt} disabled={isLoading}>
			{#if isLoading}
				Saving...
			{:else}
				💾 Save & Close
			{/if}
		</button>
	</div>
</div>
		{/if}
	</div>
	
	<style>
	.issue-modal {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
	}

	.content {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
	}

	.content h3 {
		margin: 0 0 20px 0;
		font-size: 20px;
		font-weight: 600;
		color: #1f2937;
	}

	.details {
		margin-bottom: 24px;
	}

	.details p {
		margin: 12px 0;
		color: #4b5563;
		font-size: 14px;
	}

	.label {
		font-weight: 600;
		color: #374151;
	}

	.type-label {
		margin-top: 20px;
		font-weight: 600;
		color: #1f2937;
	}

	.buttons {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 12px;
		margin-bottom: 16px;
	}

	.buttons.three-col {
		grid-template-columns: repeat(3, 1fr);
	}

	.search-section {
		margin-bottom: 16px;
		display: grid;
		grid-template-columns: 2fr 1fr 1fr;
		gap: 10px;
	}

	.search-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-input:disabled {
		background: #f3f4f6;
		color: #9ca3af;
	}

	.filter-select {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		background-color: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-select:hover:not(:disabled) {
		border-color: #9ca3af;
		background-color: #f9fafb;
	}

	.filter-select:disabled {
		background-color: #f3f4f6;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.selected-info {
		background: #ecfdf5;
		border: 1px solid #86efac;
		border-radius: 8px;
		padding: 12px;
		margin-bottom: 16px;
	}

	.selected-label {
		margin: 0 0 8px 0;
		font-weight: 600;
		color: #374151;
		font-size: 13px;
	}

	.user-card {
		background: white;
		border-radius: 6px;
		padding: 12px;
		border: 1px solid #dcfce7;
	}

	.user-detail {
		display: flex;
		justify-content: space-between;
		padding: 6px 0;
		font-size: 13px;
	}

	.detail-label {
		font-weight: 600;
		color: #6b7280;
		min-width: 80px;
	}

	.detail-value {
		color: #374151;
	}

	.count-info {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		margin-bottom: 16px;
		font-size: 14px;
	}

	.count-label {
		font-weight: 600;
		color: #0369a1;
	}

	.count-value {
		font-weight: 700;
		color: #0c4a6e;
		font-size: 16px;
	}

	.count-separator {
		color: #94a3b8;
		font-weight: 600;
	}

	.btn-add-requester {
		padding: 10px 20px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.btn-add-requester:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.btn-add-requester:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.add-requester-form {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
		margin-bottom: 16px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.add-requester-form h4 {
		margin: 0 0 16px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1f2937;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 6px;
		font-size: 13px;
		font-weight: 600;
		color: #374151;
	}

	.required {
		color: #ef4444;
	}

	.form-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input:disabled {
		background: #f3f4f6;
		color: #9ca3af;
		cursor: not-allowed;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 20px;
	}

	.btn-cancel {
		padding: 10px 20px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-save {
		padding: 10px 20px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-save:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.btn-save:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-proceed {
		width: 100%;
		padding: 12px 20px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		margin-bottom: 12px;
	}

	.btn-proceed:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.issue-type-badge {
		padding: 4px 12px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.users-table-container {
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		margin-bottom: 16px;
		max-height: 400px;
		overflow-y: auto;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.users-table thead {
		background: #f3f4f6;
		position: sticky;
		top: 0;
	}

	.users-table th {
		padding: 12px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	.users-table td {
		padding: 12px;
		border-bottom: 1px solid #e5e7eb;
	}

	.users-table tbody tr:hover {
		background: #f9fafb;
	}

	.btn-select {
		padding: 6px 12px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-select:hover {
		background: #059669;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		background: #ef4444;
		color: white;
	}

	.status-badge.active {
		background: #10b981;
		color: white;
	}

	.loading, .no-data {
		padding: 20px;
		text-align: center;
		color: #6b7280;
		font-size: 14px;
	}

	.receipt {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 24px;
		margin-bottom: 20px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.receipt-header {
		text-align: center;
		border-bottom: 2px solid #f3f4f6;
		padding-bottom: 16px;
		margin-bottom: 20px;
	}

	.receipt-header h2 {
		margin: 0 0 8px 0;
		color: #1f2937;
		font-size: 18px;
		font-weight: 700;
	}

	.receipt-date {
		margin: 0;
		color: #6b7280;
		font-size: 13px;
	}

	.receipt-section {
		margin-bottom: 20px;
	}

	.receipt-section h4 {
		margin: 0 0 12px 0;
		color: #374151;
		font-size: 14px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 8px;
	}

	.receipt-row {
		display: flex;
		justify-content: space-between;
		padding: 8px 0;
		font-size: 13px;
		border-bottom: 1px solid #f3f4f6;
	}

	.receipt-row .label {
		font-weight: 600;
		color: #6b7280;
		min-width: 150px;
	}

	.receipt-row .value {
		color: #374151;
		text-align: right;
		flex: 1;
	}

	.receipt-footer {
		background: #ecfdf5;
		border: 1px solid #86efac;
		border-radius: 6px;
		padding: 12px;
		margin-top: 20px;
		text-align: center;
	}

	.receipt-footer p {
		margin: 6px 0;
		color: #15803d;
		font-size: 13px;
		font-weight: 600;
	}

	.timestamp {
		color: #6b7280 !important;
		font-weight: normal !important;
		font-size: 12px !important;
	}

	.receipt-actions {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
	}

	.btn-print {
		flex: 1;
		min-width: 120px;
		padding: 12px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-print:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-save {
		flex: 1;
		min-width: 120px;
		padding: 12px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-save:hover {
		background: #059669;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.category-display {
		margin-bottom: 20px;
		padding: 12px;
		background: #f0f9ff;
		border-left: 4px solid #0284c7;
		border-radius: 4px;
	}

	.selected-category, .selected-user {
		margin: 6px 0;
		color: #0284c7;
		font-weight: 600;
		font-size: 13px;
	}

	.type-label {
		margin: 20px 0 16px 0;
		font-weight: 600;
		color: #1f2937;
		display: block;
	}

	button {
		padding: 12px 16px;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s;
		color: white;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.btn-internal {
		background: #3b82f6;
	}

	.btn-internal:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.btn-external {
		background: #ef4444;
	}

	.btn-external:hover {
		background: #dc2626;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3);
	}

	.btn-gift {
		background: #8b5cf6;
	}

	.btn-gift:hover {
		background: #7c3aed;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
	}

	.btn-sales {
		background: #06b6d4;
	}

	.btn-sales:hover {
		background: #0891b2;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(6, 182, 212, 0.3);
	}

	.btn-transfer {
		background: #10b981;
	}

	.btn-transfer:hover {
		background: #059669;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.btn-back {
		width: 100%;
		background: #6b7280;
		margin-top: 16px;
	}

	.btn-back:hover {
		background: #4b5563;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(107, 114, 128, 0.3);
	}

	/* Receipt Full-Page A4 Layout */
	.receipt-page {
		width: 100%;
		height: 100%;
		padding: 0;
		background: white;
		display: flex;
		flex-direction: column;
		position: relative;
	}

	.receipt-container {
		flex: 1;
		width: 190mm;
		max-width: 100%;
		height: 277mm;
		margin: 0 auto;
		padding: 10mm;
		background: white;
		box-sizing: border-box;
		page-break-inside: avoid;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		font-family: 'Arial', sans-serif;
		font-size: 11px;
		line-height: 1.4;
	}

	.logo-container {
		display: flex;
		justify-content: center;
		align-items: center;
		margin-bottom: 8mm;
	}

	.app-logo {
		height: 50px;
		width: auto;
		object-fit: contain;
	}

	.receipt-header {
		text-align: center;
		margin-bottom: 8mm;
		padding-bottom: 6mm;
		border-bottom: 2px solid #667eea;
	}

	.receipt-header h1 {
		margin: 0 0 4mm 0;
		font-size: 18px;
		font-weight: 700;
		color: #1f2937;
	}

	.receipt-date {
		margin: 0;
		font-size: 11px;
		color: #6b7280;
	}

	.receipt-section {
		margin-bottom: 6mm;
		padding-bottom: 6mm;
		border-bottom: 1px solid #e5e7eb;
	}

	.receipt-section:last-of-type {
		margin-bottom: 0;
		border-bottom: none;
	}

	.receipt-section h2 {
		margin: 0 0 4mm 0;
		font-size: 11px;
		font-weight: 700;
		color: #1f2937;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		padding: 3mm 0;
		border-bottom: 1px solid #f3f4f6;
		font-size: 10px;
	}

	.detail-row:last-child {
		border-bottom: none;
	}

	.detail-row .label {
		font-weight: 600;
		color: #4b5563;
		flex: 1;
	}

	.detail-row .value {
		color: #1f2937;
		text-align: right;
		flex: 1;
		font-weight: 500;
	}

	.detail-row .value.success {
		color: #059669;
		font-weight: 700;
	}

	.receipt-footer {
		text-align: center;
		margin-top: auto;
		padding-top: 6mm;
		border-top: 1px solid #e5e7eb;
		color: #6b7280;
		font-size: 10px;
		font-style: italic;
	}

	.receipt-footer p {
		margin: 0;
	}

	.signature-section {
		margin-bottom: 0;
		border-bottom: none;
	}

	.signature-line {
		height: 30px;
		border-bottom: 1px solid #1f2937;
		margin-top: 8mm;
		margin-bottom: 4mm;
	}

	.signature-section {
		margin-bottom: 0;
		border-bottom: none;
	}

	.signature-line {
		height: 30px;
		border-bottom: 1px solid #1f2937;
		margin-top: 8mm;
		margin-bottom: 4mm;
	}

	.receipt-actions {
		display: flex;
		gap: 12px;
		padding: 16px 24px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		justify-content: center;
	}

	.btn-print, .btn-save {
		padding: 12px 24px;
		font-size: 14px;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: white;
		min-width: 150px;
	}

	.btn-print {
		background: #0284c7;
	}

	.btn-print:hover:not(:disabled) {
		background: #0369a1;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(2, 132, 199, 0.3);
	}

	.btn-save {
		background: #059669;
	}

	.btn-save:hover:not(:disabled) {
		background: #047857;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(5, 150, 105, 0.3);
	}

	.btn-print:disabled, .btn-save:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	@media print {
		* {
			-webkit-print-color-adjust: exact !important;
			print-color-adjust: exact !important;
		}

		body, html {
			margin: 0 !important;
			padding: 0 !important;
		}

		.issue-modal {
			position: fixed !important;
			top: 0 !important;
			left: 0 !important;
			width: 100% !important;
			height: 100% !important;
			padding: 0 !important;
			margin: 0 !important;
			background: white !important;
			z-index: 999999 !important;
		}

		.content {
			display: none !important;
		}

		.receipt-page {
			display: block !important;
			visibility: visible !important;
			position: absolute !important;
			top: 0 !important;
			left: 0 !important;
			width: 100% !important;
			height: auto !important;
			padding: 0 !important;
			margin: 0 !important;
			background: white !important;
		}

		.language-toggle {
			display: none !important;
		}

		.receipt-actions {
			display: none !important;
		}

		.receipt-container {
			display: block !important;
			visibility: visible !important;
			width: 210mm !important;
			min-height: 297mm !important;
			margin: 0 auto !important;
			padding: 10mm !important;
			background: white !important;
			page-break-inside: avoid;
		}

		@page {
			size: A4;
			margin: 0;
		}
	}
</style>
