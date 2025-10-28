<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import html2canvas from 'html2canvas';
	import { notificationService } from '$lib/utils/notificationManagement';

	// Step management
	let currentStep = 1;
	const totalSteps = 3;

	// Data arrays
	let branches = [];
	let users = [];
	let parentCategories = [];
	let subCategories = [];
	let filteredUsers = [];
	let filteredCategories = [];
	let requesters = [];
	let filteredRequesters = [];

	// Step 1 data
	let selectedBranchId = '';
	let selectedApproverId = '';
	let selectedApproverName = '';
	let selectedCategoryId = '';
	let selectedCategoryName = { en: '', ar: '' };
	let userSearchQuery = '';
	let categorySearchQuery = '';
	let categoryParentFilter = '';
	let amount = ''; // Moved to Step 1

	// Step 2 data
	let requesterId = '';
	let requesterName = '';
	let requesterContact = '';
	let selectedRequesterId = '';
	let requesterSearchQuery = '';
	let showNewRequesterFields = false;
	let isNewRequester = false;
	let vatApplicable = false;
	let paymentCategory = 'advance_cash';
	let description = '';
	let creditPeriod = '';
	let bankName = '';
	let iban = '';

	// Step 3 data
	let requisitionNumber = '';
	let generatedTemplate = null;
	let templateGenerated = false;
	let isSaving = false;
	let savingProgress = 0;
	let savingStatus = '';
	let savedImageUrl = '';
	let showTemplateModal = false;

	// Payment categories
	const paymentCategories = [
		{ value: 'advance_cash', label: 'Advance Cash - سلفة نقدية' },
		{ value: 'advance_bank', label: 'Advance Bank - سلفة بنكية' },
		{ value: 'advance_cash_credit', label: 'Advance Cash Credit - سلفة ائتمان نقدي' },
		{ value: 'advance_bank_credit', label: 'Advance Bank Credit - سلفة ائتمان بنكي' },
		{ value: 'cash', label: 'Cash - نقدي' },
		{ value: 'bank', label: 'Bank - بنكي' },
		{ value: 'cash_credit', label: 'Cash Credit - ائتمان نقدي' },
		{ value: 'bank_credit', label: 'Bank Credit - ائتمان بنكي' },
		{ value: 'stock_purchase_advance_cash', label: 'Stock Purchase Advance Cash - شراء مخزون سلفة نقدية' },
		{ value: 'stock_purchase_advance_bank', label: 'Stock Purchase Advance Bank - شراء مخزون سلفة بنكية' },
		{ value: 'stock_purchase_cash', label: 'Stock Purchase Cash - شراء مخزون نقدي' },
		{ value: 'stock_purchase_bank', label: 'Stock Purchase Bank - شراء مخزون بنكي' }
	];

	onMount(async () => {
		await loadInitialData();
	});

	async function loadInitialData() {
		try {
			// Load branches
			const { data: branchData } = await supabaseAdmin
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');
			branches = branchData || [];

		// Load users with approval permissions only
		const { data: userData } = await supabaseAdmin
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
		users = userData || [];
		filteredUsers = users;			// Load categories
			const { data: parentData } = await supabaseAdmin
				.from('expense_parent_categories')
				.select('*')
				.order('name_en');
			parentCategories = parentData || [];

			const { data: subData } = await supabaseAdmin
				.from('expense_sub_categories')
				.select(`
					*,
					expense_parent_categories (
						id,
						name_en,
						name_ar
					)
				`)
				.order('name_en');
			subCategories = subData || [];
			filteredCategories = subCategories;

			// Load requesters
			const { data: requesterData } = await supabaseAdmin
				.from('requesters')
				.select('*')
				.order('requester_name');
			requesters = requesterData || [];
			filteredRequesters = requesters;

		} catch (err) {
			console.error('Error loading data:', err);
			alert('Error loading data: ' + err.message);
		}
	}

	function handleUserSearch() {
		const query = userSearchQuery.toLowerCase();
		
		let filtered = users;
		
		// Filter by search query only (show all users regardless of amount)
		if (query) {
			filtered = filtered.filter(user =>
				user.username?.toLowerCase().includes(query) ||
				user.employee_id?.toLowerCase().includes(query) ||
				user.hr_employees?.name?.toLowerCase().includes(query) ||
				user.id?.toLowerCase().includes(query)
			);
		}
		
		filteredUsers = filtered;
	}

	function handleCategorySearch() {
		const query = categorySearchQuery.toLowerCase();
		let baseCategories = subCategories;

		// Apply parent filter first
		if (categoryParentFilter) {
			const parentId = parseInt(categoryParentFilter);
			baseCategories = subCategories.filter(cat => cat.parent_category_id === parentId);
		}

		// Apply search
		if (query) {
			filteredCategories = baseCategories.filter(cat =>
				cat.name_en.toLowerCase().includes(query) ||
				cat.name_ar.toLowerCase().includes(query) ||
				cat.expense_parent_categories?.name_en.toLowerCase().includes(query) ||
				cat.expense_parent_categories?.name_ar.toLowerCase().includes(query)
			);
		} else {
			filteredCategories = baseCategories;
		}
	}

	function selectApprover(user) {
		selectedApproverId = user.id;
		selectedApproverName = user.username;
	}

	function selectCategory(category) {
		selectedCategoryId = category.id;
		selectedCategoryName = {
			en: category.name_en,
			ar: category.name_ar
		};
	}

	// Requester management functions
	function handleRequesterSearch() {
		const query = requesterSearchQuery.toLowerCase();
		if (query) {
			filteredRequesters = requesters.filter(req =>
				req.requester_id.toLowerCase().includes(query) ||
				req.requester_name.toLowerCase().includes(query) ||
				(req.contact_number && req.contact_number.includes(query))
			);
		} else {
			filteredRequesters = requesters;
		}
		
		// Show new requester fields if there's a search query but no exact matches
		const hasExactMatch = requesters.some(req => 
			req.requester_id.toLowerCase() === query ||
			req.requester_name.toLowerCase() === query
		);
		
		showNewRequesterFields = query.length > 0 && filteredRequesters.length === 0;
		isNewRequester = showNewRequesterFields;
		
		// If user is typing a new requester, pre-fill the fields
		if (showNewRequesterFields) {
			// Don't auto-fill if it looks like an ID or name
			if (query.length > 2) {
				if (query.includes(' ')) {
					// Looks like a name
					requesterName = requesterSearchQuery;
					requesterId = '';
				} else {
					// Looks like an ID
					requesterId = requesterSearchQuery;
					requesterName = '';
				}
			}
		}
	}

	function selectRequester(requester) {
		selectedRequesterId = requester.id;
		requesterId = requester.requester_id;
		requesterName = requester.requester_name;
		requesterContact = requester.contact_number || '';
		requesterSearchQuery = requester.requester_name;
		showNewRequesterFields = false;
		isNewRequester = false;
	}

	function clearRequesterSelection() {
		selectedRequesterId = '';
		requesterId = '';
		requesterName = '';
		requesterContact = '';
		requesterSearchQuery = '';
		showNewRequesterFields = false;
		isNewRequester = false;
	}

	async function saveNewRequester() {
		if (!requesterId.trim() || !requesterName.trim()) {
			alert('Please fill in Requester ID and Name');
			return;
		}

		try {
			// Check if current user exists in users table
			let createdByUserId = null;
			if ($currentUser?.id) {
				try {
					const { data: userExists } = await supabaseAdmin
						.from('users')
						.select('id')
						.eq('id', $currentUser.id)
						.single();
					
					if (userExists) {
						createdByUserId = $currentUser.id;
					}
				} catch (userCheckError) {
					console.warn('User not found in users table, saving requester without created_by reference');
				}
			}

			const { data, error } = await supabaseAdmin
				.from('requesters')
				.insert([{
					requester_id: requesterId.trim(),
					requester_name: requesterName.trim(),
					contact_number: requesterContact.trim() || null,
					created_by: createdByUserId // Will be null if user not found in users table
				}])
				.select()
				.single();

			if (error) {
				if (error.code === '23505') { // Unique constraint violation
					alert('A requester with this ID already exists');
				} else {
					throw error;
				}
				return;
			}

			// Add to local array and update filtered list
			requesters = [...requesters, data];
			filteredRequesters = requesters;
			
			// Select the new requester
			selectRequester(data);
			
			alert('Requester saved successfully!');
			
		} catch (err) {
			console.error('Error saving requester:', err);
			alert('Error saving requester: ' + err.message);
		}
	}

	function validateStep1() {
		if (!selectedBranchId) {
			alert('Please select a branch');
			return false;
		}
		if (!amount || parseFloat(amount) <= 0) {
			alert('Please enter a valid amount');
			return false;
		}
		if (!selectedApproverId) {
			alert('Please select an approver');
			return false;
		}
		if (!selectedCategoryId) {
			alert('Please select an expense category');
			return false;
		}
		return true;
	}

	function validateStep2() {
		if (!requesterId.trim()) {
			alert('Please select a requester or enter requester ID');
			return false;
		}
		if (!requesterName.trim()) {
			alert('Please select a requester or enter requester name');
			return false;
		}
		// Contact number is optional now
		// Validate credit period for credit payment methods
		if ((paymentCategory === 'advance_cash_credit' || paymentCategory === 'advance_bank_credit' || paymentCategory === 'cash_credit' || paymentCategory === 'bank_credit') && (!creditPeriod || parseInt(creditPeriod) <= 0)) {
			alert('Please enter a valid credit period');
			return false;
		}
		// Bank details are optional - no validation required
		if (!description.trim()) {
			alert('Please enter requisition description');
			return false;
		}
		return true;
	}

	function nextStep() {
		if (currentStep === 1 && !validateStep1()) return;
		if (currentStep === 2 && !validateStep2()) return;
		
		if (currentStep === 2) {
			generateRequisitionNumber();
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

	function generateRequisitionNumber() {
		const date = new Date();
		const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');
		const randomNum = Math.floor(1000 + Math.random() * 9000);
		requisitionNumber = `REQ-${dateStr}-${randomNum}`;
	}

	function generateTemplate() {
		templateGenerated = true;
		showTemplateModal = true;
	}

	function closeTemplateModal() {
		showTemplateModal = false;
	}

	function getBranchName() {
		const branch = branches.find(b => b.id == selectedBranchId);
		return branch ? `${branch.name_en} - ${branch.name_ar}` : '';
	}

	async function saveRequisition() {
		try {
			isSaving = true;
			savingProgress = 0;
			savingStatus = 'Preparing template...';

			// Step 1: Capture template (0-30%)
			savingProgress = 10;
			const template = document.getElementById('requisition-template');
			
			savingProgress = 20;
			savingStatus = 'Capturing image...';
			const canvas = await html2canvas(template, {
				scale: 2,
				backgroundColor: '#ffffff',
				logging: false
			});
			
			savingProgress = 30;
			savingStatus = 'Converting to image...';

			// Step 2: Convert to blob (30-40%)
			const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
			savingProgress = 40;
			savingStatus = 'Uploading image...';
			
			// Step 3: Upload to storage (40-70%)
			const fileName = `${requisitionNumber}.png`;
			const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
				.from('requisition-images')
				.upload(fileName, blob, {
					contentType: 'image/png',
					upsert: true
				});

			if (uploadError) throw uploadError;
			savingProgress = 70;
			savingStatus = 'Getting image URL...';

			// Step 4: Get public URL (70-80%)
			const { data: urlData } = supabaseAdmin.storage
				.from('requisition-images')
				.getPublicUrl(fileName);

			savedImageUrl = urlData.publicUrl;
			savingProgress = 80;
			savingStatus = 'Saving to database...';

			// Step 5: Save requisition to database (80-100%)
			const { error: dbError } = await supabaseAdmin
				.from('expense_requisitions')
				.insert({
					requisition_number: requisitionNumber,
					branch_id: parseInt(selectedBranchId),
					branch_name: getBranchName(),
					approver_id: selectedApproverId || null,
					approver_name: selectedApproverName,
					expense_category_id: parseInt(selectedCategoryId),
					expense_category_name_en: selectedCategoryName.en,
					expense_category_name_ar: selectedCategoryName.ar,
					requester_id: requesterId, // This is employee ID as text
					requester_name: requesterName,
					requester_contact: requesterContact,
					requester_ref_id: selectedRequesterId || null, // Reference to requesters table
					vat_applicable: vatApplicable,
					amount: parseFloat(amount),
					payment_category: paymentCategory,
					credit_period: creditPeriod ? parseInt(creditPeriod) : null,
					bank_name: bankName || null,
					iban: iban || null,
					description: description,
					status: 'pending',
					image_url: savedImageUrl,
					created_by: $currentUser?.id || requesterId
				});			if (dbError) throw dbError;
			
			savingProgress = 95;
			savingStatus = 'Sending notification to approver...';
			
			// Send notification to the selected approver
			try {
				if (selectedApproverId && selectedApproverName) {
					await notificationService.createNotification({
						title: 'New Expense Requisition for Approval',
						message: `A new expense requisition (${requisitionNumber}) has been submitted for your approval by ${$currentUser?.username || requesterName}. Branch: ${getBranchName()}, Amount: ${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR, Category: ${selectedCategoryName.en}`,
						type: 'info',
						priority: parseFloat(amount) > 10000 ? 'high' : 'medium',
						target_type: 'specific_users',
						target_users: [selectedApproverId]
					}, $currentUser?.id || $currentUser?.username || 'System');
					
					console.log('✅ Notification sent to approver:', selectedApproverName);
				}
			} catch (notifError) {
				console.error('❌ Failed to send notification to approver:', notifError);
				// Don't throw error - notification failure shouldn't stop requisition creation
			}
			
			savingProgress = 100;
			savingStatus = 'Completed!';
			
			// Small delay to show 100% before closing
			await new Promise(resolve => setTimeout(resolve, 500));

			alert('✅ Requisition saved successfully!');
			
		} catch (err) {
			console.error('Error saving requisition:', err);
			savingStatus = 'Error: ' + err.message;
			alert('Error saving requisition: ' + err.message);
		} finally {
			isSaving = false;
			savingProgress = 0;
			savingStatus = '';
		}
	}

	async function shareToWhatsApp() {
		try {
			// Get payment category label
			const paymentLabel = paymentCategories.find(c => c.value === paymentCategory)?.label || paymentCategory;
			
			// Format date
			const formattedDate = new Date().toLocaleDateString('en-US', { 
				year: 'numeric', 
				month: 'long', 
				day: 'numeric' 
			});
			
			// Build comprehensive bilingual message
			let message = `*━━━━━━━━━━━━━━━━*\n`;
			message += `*EXPENSE REQUISITION*\n`;
			message += `*طلب مصروف*\n`;
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			
			// Requisition Number
			message += `*📋 Requisition No. / رقم الطلب:*\n`;
			message += `${requisitionNumber}\n\n`;
			
			// Branch
			message += `*🏢 Branch / الفرع:*\n`;
			message += `${getBranchName()}\n\n`;
			
			// Date
			message += `*📅 Date / التاريخ:*\n`;
			message += `${formattedDate}\n\n`;
			
			// Approver
			message += `*✅ Approver / المعتمد:*\n`;
			message += `${selectedApproverName}\n\n`;
			
			// Category
			message += `*📂 Category / الفئة:*\n`;
			message += `${selectedCategoryName.en} / ${selectedCategoryName.ar}\n\n`;
			
			// Generated By
			message += `*👤 Generated By / تم الإنشاء بواسطة:*\n`;
			message += `${$currentUser?.username || 'System'}\n\n`;
			
			// Amount
			message += `*💰 Amount / المبلغ:*\n`;
			message += `*${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR*\n`;
			message += vatApplicable ? `✅ VAT Applicable / ضريبة القيمة المضافة قابلة للتطبيق\n\n` : `❌ VAT Not Applicable / ضريبة القيمة المضافة غير قابلة للتطبيق\n\n`;
			
			// Requester Information Section
			message += `*━━━ REQUESTER INFO / معلومات مقدم الطلب ━━━*\n\n`;
			
			// Requester ID
			message += `*🆔 ID / الرقم:*\n`;
			message += `${requesterId}\n\n`;
			
			// Requester Name
			message += `*👨‍💼 Name / الاسم:*\n`;
			message += `${requesterName}\n\n`;
			
			// Contact
			message += `*📞 Contact / الاتصال:*\n`;
			message += `${requesterContact}\n\n`;
			
			// Payment Method
			message += `*💳 Payment Method / طريقة الدفع:*\n`;
			message += `${paymentLabel}\n\n`;
			
			// Bank Name (if provided)
			if (bankName) {
				message += `*🏦 Bank Name / اسم البنك:*\n`;
				message += `${bankName}\n\n`;
			}
			
			// IBAN (if provided)
			if (iban) {
				message += `*💼 IBAN / الآيبان:*\n`;
				message += `${iban}\n\n`;
			}
			
			// Credit Period (if applicable)
			if (creditPeriod) {
				message += `*⏱️ Credit Period / فترة الائتمان:*\n`;
				message += `${creditPeriod} Days / أيام\n\n`;
			}
			
			// Description
			if (description) {
				message += `*━━━ DESCRIPTION / الوصف ━━━*\n\n`;
				message += `${description}\n\n`;
			}
			
			// Image Link
			message += `*━━━━━━━━━━━━━━━━*\n\n`;
			message += `📄 *View Full Document / عرض المستند الكامل:*\n`;
			message += `${savedImageUrl}`;
			
			// Open WhatsApp Web with the comprehensive message
			const whatsappWebUrl = `https://web.whatsapp.com/send?text=${encodeURIComponent(message)}`;
			window.open(whatsappWebUrl, '_blank');
			
		} catch (error) {
			console.error('Error sharing:', error);
			alert('Error opening WhatsApp: ' + error.message);
		}
	}

	function handlePrintTemplate() {
		// Get the template element
		const template = document.getElementById('requisition-template');
		if (!template) return;

		// Create a new window for printing
		const printWindow = window.open('', '_blank', 'width=800,height=600');
		if (!printWindow) return;

		// Write the template content to the new window
		printWindow.document.write(`
			<!DOCTYPE html>
			<html>
			<head>
				<title>Requisition ${requisitionNumber}</title>
				<style>
					@page {
						size: A4;
						margin: 15mm;
					}
					* {
						margin: 0;
						padding: 0;
						box-sizing: border-box;
					}
					body {
						font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
						background: white;
						padding: 0;
						margin: 0;
					}
					.requisition-template {
						background: white;
						border: 2px solid #e5e7eb;
						border-radius: 8px;
						padding: 20px;
						max-width: 100%;
						margin: 0;
						height: 100%;
					}
					.template-header {
						display: flex;
						justify-content: space-between;
						align-items: center;
						margin-bottom: 15px;
						padding-bottom: 12px;
						border-bottom: 2px solid #3b82f6;
					}
					.logo-section {
						display: flex;
						align-items: center;
						gap: 10px;
					}
					.app-logo {
						width: 45px;
						height: 45px;
						border-radius: 8px;
						object-fit: contain;
					}
					.app-info {
						display: flex;
						flex-direction: column;
						gap: 2px;
					}
					.app-name-en {
						font-size: 18px;
						font-weight: 700;
						color: #1e293b;
						line-height: 1;
					}
					.app-name-ar {
						font-size: 14px;
						font-weight: 600;
						color: #64748b;
						direction: rtl;
						line-height: 1;
					}
					.req-number {
						text-align: right;
					}
					.req-label {
						font-size: 9px;
						color: #6b7280;
						font-weight: 600;
						text-transform: uppercase;
						white-space: nowrap;
					}
					.req-value {
						font-size: 13px;
						font-weight: 700;
						color: #3b82f6;
						margin-top: 3px;
					}
					.template-title-section {
						text-align: center;
						margin-bottom: 15px;
					}
					.template-title {
						font-size: 20px;
						font-weight: 700;
						color: #1e293b;
						margin-bottom: 4px;
					}
					.template-subtitle {
						font-size: 16px;
						font-weight: 600;
						color: #6b7280;
						direction: rtl;
					}
					.template-section {
						margin-bottom: 12px;
						padding: 12px;
						background: #f9fafb;
						border-radius: 6px;
					}
					.section-title {
						font-size: 13px;
						font-weight: 700;
						color: #374151;
						margin-bottom: 10px;
						display: flex;
						justify-content: space-between;
						align-items: center;
						border-bottom: 1px solid #e5e7eb;
						padding-bottom: 6px;
					}
					.title-en {
						text-transform: uppercase;
						letter-spacing: 0.03em;
						font-size: 12px;
					}
					.title-ar {
						direction: rtl;
						font-size: 12px;
					}
					.info-grid {
						display: grid;
						grid-template-columns: repeat(2, 1fr);
						gap: 10px;
					}
					.info-item {
						background: white;
						padding: 8px;
						border-radius: 4px;
						border: 1px solid #e5e7eb;
					}
					.info-label {
						display: flex;
						justify-content: space-between;
						align-items: center;
						margin-bottom: 4px;
					}
					.label-en {
						font-weight: 600;
						color: #6b7280;
						font-size: 10px;
						text-transform: uppercase;
					}
					.label-ar {
						font-weight: 600;
						color: #6b7280;
						font-size: 9px;
						direction: rtl;
					}
					.info-value {
						color: #1e293b;
						font-size: 11px;
						font-weight: 500;
					}
					.amount-highlight {
						font-size: 14px;
						font-weight: 700;
						color: #059669;
						font-family: 'Courier New', monospace;
					}
					.description-box {
						background: white;
						padding: 10px;
						border-radius: 4px;
						min-height: 50px;
						font-size: 11px;
						line-height: 1.4;
						color: #1e293b;
						white-space: pre-wrap;
						border: 1px solid #e5e7eb;
					}
					.template-footer {
						display: grid;
						grid-template-columns: 1fr 1fr;
						gap: 30px;
						margin-top: 30px;
						padding-top: 20px;
						border-top: 2px dashed #d1d5db;
					}
					.signature-section {
						text-align: center;
					}
					.signature-line {
						border-top: 2px solid #1e293b;
						margin-bottom: 8px;
						padding-top: 40px;
					}
					.signature-label {
						font-weight: 600;
						color: #374151;
						font-size: 11px;
						display: flex;
						flex-direction: column;
						gap: 3px;
						align-items: center;
					}
					.signature-label .label-en {
						text-transform: uppercase;
						font-size: 10px;
					}
					.signature-label .label-ar {
						direction: rtl;
						font-size: 10px;
					}
					.print-btn {
						display: none;
					}
					@media print {
						body {
							padding: 0;
							margin: 0;
						}
						.requisition-template {
							border: 1px solid #000;
							box-shadow: none;
							border-radius: 0;
							page-break-inside: avoid;
						}
					}
				</style>
			</head>
			<body>
				${template.outerHTML}
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

	function resetForm() {
		currentStep = 1;
		selectedBranchId = '';
		selectedApproverId = '';
		selectedApproverName = '';
		selectedCategoryId = '';
		selectedCategoryName = { en: '', ar: '' };
		requesterId = '';
		requesterName = '';
		requesterContact = '';
		vatApplicable = false;
		amount = '';
		paymentCategory = 'advance_cash';
		description = '';
		creditPeriod = '';
		bankName = '';
		iban = '';
		savedImageUrl = '';
		templateGenerated = false;
		showTemplateModal = false;
		requisitionNumber = '';
	}
</script>

<div class="request-generator">
	<div class="header">
		<h1 class="title">📝 Requisition Generator</h1>
		<p class="subtitle">Generate professional expense requisitions</p>
	</div>

	<!-- Progress Steps -->
	<div class="progress-steps">
		<div class="step {currentStep >= 1 ? 'active' : ''} {currentStep > 1 ? 'completed' : ''}">
			<div class="step-number">{currentStep > 1 ? '✓' : '1'}</div>
			<div class="step-label">Selection</div>
		</div>
		<div class="step-line {currentStep > 1 ? 'completed' : ''}"></div>
		<div class="step {currentStep >= 2 ? 'active' : ''} {currentStep > 2 ? 'completed' : ''}">
			<div class="step-number">{currentStep > 2 ? '✓' : '2'}</div>
			<div class="step-label">Details</div>
		</div>
		<div class="step-line {currentStep > 2 ? 'completed' : ''}"></div>
		<div class="step {currentStep >= 3 ? 'active' : ''}">
			<div class="step-number">3</div>
			<div class="step-label">Generate</div>
		</div>
	</div>

	<div class="content">
		<!-- Step 1: Selection -->
		{#if currentStep === 1}
			<div class="step-content">
				<h2 class="step-title">Step 1: Selection</h2>

				<!-- Branch Selection -->
				<div class="form-group">
					<label>Branch *</label>
					<select bind:value={selectedBranchId} class="form-select">
						<option value="">Select branch...</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en} - {branch.name_ar}</option>
						{/each}
					</select>
				</div>

				<!-- Amount Input -->
				<div class="form-group">
					<label>Requisition Amount (SAR) *</label>
					<input 
						type="number" 
						bind:value={amount} 
						on:input={handleUserSearch}
						placeholder="Enter amount to filter approvers..." 
						step="0.01" 
						min="0"
						class="form-input amount-input-large" 
					/>
					{#if amount && parseFloat(amount) > 0}
						<div class="amount-info">
							💡 Approvers with insufficient limits will be <strong>disabled</strong>. Only users with limits of <strong>{parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2 })} SAR</strong> or more (or unlimited) can be selected.
						</div>
					{/if}
				</div>

				<!-- Approver Selection -->
				<div class="form-group">
					<label>Choose Approver *</label>
					<input
						type="text"
						bind:value={userSearchQuery}
						on:input={handleUserSearch}
						placeholder="Search users..."
						class="form-input"
					/>
					<div class="selection-table">
						<table>
							<thead>
								<tr>
									<th>Select</th>
									<th>Username</th>
									<th>Employee Name</th>
									<th>Type</th>
									<th>Branch</th>
									<th>Approval Limit</th>
								</tr>
							</thead>
							<tbody>
								{#if filteredUsers.length === 0}
									<tr>
										<td colspan="6" class="no-data-message">
											<div class="empty-state">
												<span class="empty-icon">🔒</span>
												<p>No users with approval permissions found.</p>
												<p class="empty-hint">Please contact your administrator to set up approval permissions.</p>
											</div>
										</td>
									</tr>
								{:else}
									{#each filteredUsers as user}
										{@const requestAmount = parseFloat(amount) || 0}
										{@const isOverLimit = requestAmount > 0 && user.approval_amount_limit > 0 && user.approval_amount_limit < requestAmount}
										<tr 
											class:selected={selectedApproverId === user.id}
											class:disabled={isOverLimit}
											on:click={() => !isOverLimit && selectApprover(user)}
										>
											<td>
												<input 
													type="radio" 
													checked={selectedApproverId === user.id}
													disabled={isOverLimit}
													on:click={() => !isOverLimit && selectApprover(user)}
												/>
											</td>
											<td>{user.username}</td>
											<td>{user.hr_employees?.name || 'N/A'}</td>
											<td>{user.user_type}</td>
											<td>{branches.find(b => b.id === user.branch_id)?.name_en || 'Global'}</td>
											<td class="approval-limit-display">
												{#if user.approval_amount_limit === 0}
													<span class="unlimited-badge">♾️ Unlimited</span>
												{:else if isOverLimit}
													<span class="over-limit-badge">⚠️ {user.approval_amount_limit?.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR</span>
												{:else}
													<span class="limit-amount">{user.approval_amount_limit?.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR</span>
												{/if}
											</td>
										</tr>
									{/each}
								{/if}
							</tbody>
						</table>
					</div>
					{#if selectedApproverName}
						<div class="selected-info">Selected: <strong>{selectedApproverName}</strong></div>
					{/if}
				</div>

				<!-- Category Selection -->
				<div class="form-group">
					<label>Expense Category *</label>
					<div class="filter-row">
						<input
							type="text"
							bind:value={categorySearchQuery}
							on:input={handleCategorySearch}
							placeholder="Search categories..."
							class="form-input"
						/>
						<select bind:value={categoryParentFilter} on:change={handleCategorySearch} class="form-select">
							<option value="">All Parents</option>
							{#each parentCategories as parent}
								<option value={parent.id}>{parent.name_en}</option>
							{/each}
						</select>
					</div>
					<div class="selection-table">
						<table>
							<thead>
								<tr>
									<th>Select</th>
									<th>Parent Category</th>
									<th>English Name</th>
									<th>Arabic Name</th>
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
												checked={selectedCategoryId === category.id}
												on:click={() => selectCategory(category)}
											/>
										</td>
										<td><span class="parent-badge">{category.expense_parent_categories?.name_en}</span></td>
										<td>{category.name_en}</td>
										<td class="arabic">{category.name_ar}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
					{#if selectedCategoryName.en}
						<div class="selected-info">Selected: <strong>{selectedCategoryName.en} - {selectedCategoryName.ar}</strong></div>
					{/if}
				</div>
			</div>
		{/if}

		<!-- Step 2: Details -->
		{#if currentStep === 2}
			<div class="step-content">
				<h2 class="step-title">Step 2: Expense Details</h2>

				<!-- Requester Selection -->
				<div class="form-group requester-dropdown-container">
					<label>Select or Add Requester *</label>
					<input 
						type="text" 
						bind:value={requesterSearchQuery} 
						on:input={handleRequesterSearch}
						placeholder="Search by ID, name, or contact..." 
						class="form-input search-input" 
					/>
					
					{#if requesterSearchQuery && filteredRequesters.length > 0}
						<div class="dropdown-list">
							{#each filteredRequesters as requester}
								<div class="dropdown-item" on:click={() => selectRequester(requester)}>
									<div class="requester-info">
										<strong>{requester.requester_name}</strong>
										<span class="requester-id">ID: {requester.requester_id}</span>
										{#if requester.contact_number}
											<span class="requester-contact">📞 {requester.contact_number}</span>
										{/if}
									</div>
								</div>
							{/each}
						</div>
					{/if}

					{#if requesterSearchQuery && filteredRequesters.length === 0}
						<div class="no-results">
							No matching requesters found. Fill in the details below to add a new requester.
						</div>
					{/if}

					{#if selectedRequesterId}
						<div class="selected-requester">
							✓ Selected: <strong>{requesterName}</strong> (ID: {requesterId})
							<button type="button" class="btn-clear" on:click={clearRequesterSelection}>Clear</button>
						</div>
					{/if}
				</div>

				<!-- New Requester Fields (shown when no match found) -->
				{#if showNewRequesterFields || (requesterSearchQuery && filteredRequesters.length === 0)}
					<div class="new-requester-section">
						<h3>Add New Requester</h3>
						<div class="form-row">
							<div class="form-group">
								<label>Requester ID *</label>
								<input 
									type="text" 
									bind:value={requesterId} 
									placeholder="Enter requester ID" 
									class="form-input" 
								/>
								{#if requesterId && requesterName}
									<button type="button" class="save-field-btn" on:click={saveNewRequester}>
										💾 Save Requester
									</button>
								{/if}
							</div>

							<div class="form-group">
								<label>Requester Name *</label>
								<input 
									type="text" 
									bind:value={requesterName} 
									placeholder="Enter requester name" 
									class="form-input" 
								/>
							</div>
						</div>

						<div class="form-group">
							<label>Contact Number</label>
							<input 
								type="tel" 
								bind:value={requesterContact} 
								placeholder="Enter contact number" 
								class="form-input" 
							/>
						</div>
					</div>
				{/if}

				<div class="form-group">
					<label>Payment Category *</label>
					<select bind:value={paymentCategory} class="form-select">
						{#each paymentCategories as cat}
							<option value={cat.value}>{cat.label}</option>
						{/each}
					</select>
				</div>

				<!-- Conditional fields based on payment category -->
				{#if paymentCategory === 'advance_cash_credit' || paymentCategory === 'advance_bank_credit' || paymentCategory === 'cash_credit' || paymentCategory === 'bank_credit'}
					<div class="form-group conditional-field">
						<label>Credit Period (Days) *</label>
						<input 
							type="number" 
							bind:value={creditPeriod} 
							placeholder="Enter credit period in days" 
							min="1"
							class="form-input" 
						/>
						<div class="field-hint">💡 Number of days until payment is due</div>
					</div>
				{/if}

				{#if paymentCategory === 'advance_bank' || paymentCategory === 'advance_bank_credit' || paymentCategory === 'bank' || paymentCategory === 'bank_credit' || paymentCategory === 'stock_purchase_advance_bank' || paymentCategory === 'stock_purchase_bank'}
					<div class="form-row conditional-field">
						<div class="form-group">
							<label>Bank Name (Optional)</label>
							<input 
								type="text" 
								bind:value={bankName} 
								placeholder="Enter bank name (optional)" 
								class="form-input" 
							/>
						</div>
						<div class="form-group">
							<label>IBAN (Optional)</label>
							<input 
								type="text" 
								bind:value={iban} 
								placeholder="SAxxxxxxxxxxxxxxxxxx (optional)" 
								class="form-input" 
							/>
						</div>
					</div>
				{/if}

				<div class="form-group">
					<label class="toggle-label">
						<input type="checkbox" bind:checked={vatApplicable} />
						<span>VAT Applicable</span>
					</label>
					<div class="field-hint">ℹ️ Check this box if VAT is applicable to this requisition (for record-keeping and filtering purposes only)</div>
				</div>

				<!-- Show selected amount -->
				<div class="selected-amount-display">
					<div class="amount-label">Requisition Amount:</div>
					<div class="amount-value">{parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR</div>
				</div>

				<div class="form-group">
					<label>Requisition Description *</label>
					<textarea 
						bind:value={description} 
						placeholder="Enter detailed description of the expense requisition..."
						rows="6"
						class="form-textarea"
					></textarea>
				</div>
			</div>
		{/if}

	<!-- Step 3: Generate -->
	{#if currentStep === 3}
		<div class="step-content">
			<h2 class="step-title">Step 3: Generate Requisition</h2>

			{#if !templateGenerated}
				<!-- Generate Button -->
				<div class="generate-section">
					<div class="generate-placeholder">
						<div class="placeholder-icon">📄</div>
						<h3>Generate Requisition Template</h3>
						<p>Click the button below to generate a professional requisition document</p>
					</div>

					<button class="btn-generate" on:click={generateTemplate}>
						🎨 Generate Request
					</button>
				</div>
			{:else}
				<!-- Success Message -->
				<div class="success-section">
					<div class="success-icon">✅</div>
					<h3>Requisition Generated Successfully!</h3>
					<p>Your requisition number: <strong>{requisitionNumber}</strong></p>
					<button class="btn-view" on:click={() => showTemplateModal = true}>
						�️ View Requisition
					</button>

					{#if savedImageUrl}
						<div class="action-buttons">
							<button class="btn-whatsapp" on:click={shareToWhatsApp}>
								<span>📱</span>
								Share to WhatsApp
							</button>
							<button class="btn-reset" on:click={resetForm}>
								Create New Requisition
							</button>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}		<!-- Navigation Buttons -->
		<div class="nav-buttons">
			{#if currentStep > 1 && !savedImageUrl}
				<button class="btn-prev" on:click={previousStep}>← Previous</button>
			{/if}
			{#if currentStep < totalSteps}
				<button class="btn-next" on:click={nextStep}>Next →</button>
			{/if}
		</div>
	</div>
</div>

<!-- Template Modal -->
{#if showTemplateModal}
	<div class="modal-overlay" on:click={closeTemplateModal} role="button" tabindex="0" on:keydown={(e) => e.key === 'Escape' && closeTemplateModal()}>
		<div class="modal-content" on:click|stopPropagation role="dialog" tabindex="-1" aria-modal="true" aria-labelledby="modal-title">
			<!-- Modal Header -->
			<div class="modal-header">
				<div>
					<h2 id="modal-title" class="modal-title">Expense Requisition</h2>
					<p class="modal-subtitle">Review and save your requisition</p>
				</div>
				<div class="modal-header-actions">
					<button class="btn-print-header" on:click={handlePrintTemplate} title="Print Requisition">
						🖨️ Print
					</button>
					<button class="modal-close" on:click={closeTemplateModal}>×</button>
				</div>
			</div>

			<!-- Modal Body -->
			<div class="modal-body">
				<!-- Requisition Template -->
				<div id="requisition-template" class="requisition-template">
					<!-- Header with Logo and App Name -->
					<div class="template-header">
						<div class="logo-section">
							<img src="/icons/icon-192x192.png" alt="Logo" class="app-logo" />
							<div class="app-info">
								<div class="app-name-en">Aqura</div>
								<div class="app-name-ar">أكورا</div>
							</div>
						</div>
						<div class="req-number">
							<div class="req-label">Requisition No. / رقم الطلب</div>
							<div class="req-value">{requisitionNumber}</div>
						</div>
					</div>

					<!-- Title -->
					<div class="template-title-section">
						<div class="template-title">EXPENSE REQUISITION</div>
						<div class="template-subtitle">طلب مصروف</div>
					</div>

					<!-- Top Section: Branch, Date, Approver, Category, Generated By -->
					<div class="template-section info-grid">
						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Branch</span>
								<span class="label-ar">الفرع</span>
							</div>
							<div class="info-value">{getBranchName()}</div>
						</div>

						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Date</span>
								<span class="label-ar">التاريخ</span>
							</div>
							<div class="info-value">{new Date().toLocaleDateString()}</div>
						</div>

						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Approver</span>
								<span class="label-ar">المعتمد</span>
							</div>
							<div class="info-value">{selectedApproverName}</div>
						</div>

						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Category</span>
								<span class="label-ar">الفئة</span>
							</div>
							<div class="info-value">{selectedCategoryName.en} / {selectedCategoryName.ar}</div>
						</div>

						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Generated By</span>
								<span class="label-ar">تم الإنشاء بواسطة</span>
							</div>
							<div class="info-value">{$currentUser?.username || 'Unknown'}</div>
						</div>

						<div class="info-item">
							<div class="info-label">
								<span class="label-en">Amount</span>
								<span class="label-ar">المبلغ</span>
							</div>
							<div class="info-value amount-highlight">{parseFloat(amount).toFixed(2)} SAR</div>
						</div>
					</div>

					<!-- Requester Information -->
					<div class="template-section">
						<h3 class="section-title">
							<span class="title-en">Requester Information</span>
							<span class="title-ar">معلومات مقدم الطلب</span>
						</h3>
						<div class="info-grid">
							<div class="info-item">
								<div class="info-label">
									<span class="label-en">ID</span>
									<span class="label-ar">الرقم</span>
								</div>
								<div class="info-value">{requesterId}</div>
							</div>
							<div class="info-item">
								<div class="info-label">
									<span class="label-en">Name</span>
									<span class="label-ar">الاسم</span>
								</div>
								<div class="info-value">{requesterName}</div>
							</div>
							<div class="info-item">
								<div class="info-label">
									<span class="label-en">Contact</span>
									<span class="label-ar">الاتصال</span>
								</div>
								<div class="info-value">{requesterContact}</div>
							</div>
							<div class="info-item">
								<div class="info-label">
									<span class="label-en">Payment Method</span>
									<span class="label-ar">طريقة الدفع</span>
								</div>
								<div class="info-value">{paymentCategories.find(c => c.value === paymentCategory)?.label}</div>
							</div>
							{#if bankName}
								<div class="info-item">
									<div class="info-label">
										<span class="label-en">Bank Name</span>
										<span class="label-ar">اسم البنك</span>
									</div>
									<div class="info-value">{bankName}</div>
								</div>
							{/if}
							{#if iban}
								<div class="info-item">
									<div class="info-label">
										<span class="label-en">IBAN</span>
										<span class="label-ar">الآيبان</span>
									</div>
									<div class="info-value">{iban}</div>
								</div>
							{/if}
							{#if creditPeriod}
								<div class="info-item">
									<div class="info-label">
										<span class="label-en">Credit Period</span>
										<span class="label-ar">فترة الائتمان</span>
									</div>
									<div class="info-value">{creditPeriod} Days / أيام</div>
								</div>
							{/if}
							<div class="info-item">
								<div class="info-label">
									<span class="label-en">VAT Status</span>
									<span class="label-ar">حالة الضريبة</span>
								</div>
								<div class="info-value">{vatApplicable ? '✅ Applicable / قابل للتطبيق' : '❌ Not Applicable / غير قابل للتطبيق'}</div>
							</div>
						</div>
					</div>

					<!-- Description -->
					<div class="template-section">
						<h3 class="section-title">
							<span class="title-en">Description</span>
							<span class="title-ar">الوصف</span>
						</h3>
						<div class="description-box">
							{description}
						</div>
					</div>

					<!-- Signature Area -->
					<div class="template-footer">
						<div class="signature-section">
							<div class="signature-line"></div>
							<div class="signature-label">
								<span class="label-en">Requester Signature</span>
								<span class="label-ar">توقيع مقدم الطلب</span>
							</div>
						</div>
						<div class="signature-section">
							<div class="signature-line"></div>
							<div class="signature-label">
								<span class="label-en">Approver Signature</span>
								<span class="label-ar">توقيع المعتمد</span>
							</div>
						</div>
					</div>
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="modal-footer">
				{#if !savedImageUrl}
					<button class="btn-save" on:click={saveRequisition} disabled={isSaving}>
						{isSaving ? '💾 Saving...' : '💾 Save Requisition'}
					</button>
					
					<!-- Progress Indicator -->
					{#if isSaving}
						<div class="saving-progress">
							<div class="progress-bar-container">
								<div class="progress-bar" style="width: {savingProgress}%"></div>
							</div>
							<div class="progress-text">{savingProgress}% - {savingStatus}</div>
						</div>
					{/if}
				{:else}
					<div class="save-success">✅ Saved successfully!</div>
					<button class="btn-close-modal" on:click={closeTemplateModal}>
						Close
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.request-generator {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 2rem;
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

	/* Progress Steps */
	.progress-steps {
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 3rem;
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}

	.step-number {
		width: 50px;
		height: 50px;
		border-radius: 50%;
		background: #e5e7eb;
		color: #6b7280;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 700;
		font-size: 18px;
		transition: all 0.3s ease;
	}

	.step.active .step-number {
		background: #3b82f6;
		color: white;
	}

	.step.completed .step-number {
		background: #10b981;
		color: white;
	}

	.step-label {
		font-size: 13px;
		font-weight: 600;
		color: #6b7280;
	}

	.step.active .step-label {
		color: #3b82f6;
	}

	.step-line {
		width: 100px;
		height: 3px;
		background: #e5e7eb;
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
		min-height: 600px;
		display: flex;
		flex-direction: column;
	}

	.step-content {
		flex: 1;
	}

	.step-title {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 2rem;
		padding-bottom: 1rem;
		border-bottom: 2px solid #e5e7eb;
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

	.filter-row {
		display: grid;
		grid-template-columns: 1fr 300px;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	label {
		display: block;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
		font-size: 14px;
	}

	.form-input,
	.form-select,
	.form-textarea {
		width: 100%;
		padding: 10px 14px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: border-color 0.2s ease;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-textarea {
		resize: vertical;
		font-family: inherit;
	}

	/* Conditional Fields */
	.conditional-field {
		background: #f0f9ff;
		border-left: 4px solid #3b82f6;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 1.5rem;
	}

	.conditional-field label {
		color: #1e40af;
	}

	.field-hint {
		margin-top: 8px;
		font-size: 13px;
		color: #3b82f6;
		font-style: italic;
	}

	/* Amount Input in Step 1 */
	.amount-input-large {
		font-size: 20px !important;
		font-weight: 700;
		padding: 16px !important;
		text-align: right;
		font-family: 'Courier New', monospace;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #3b82f6 !important;
	}

	.amount-input-large:focus {
		background: white;
		box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.15) !important;
	}

	.amount-info {
		margin-top: 10px;
		padding: 12px;
		background: #dbeafe;
		border-left: 4px solid #3b82f6;
		border-radius: 6px;
		color: #1e40af;
		font-size: 14px;
		line-height: 1.5;
	}

	.amount-info strong {
		font-weight: 700;
		color: #1e3a8a;
	}

	/* Selected Amount Display in Step 2 */
	.selected-amount-display {
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #059669;
		border-radius: 12px;
		padding: 20px;
		margin-bottom: 1.5rem;
		text-align: center;
	}

	.amount-label {
		font-size: 14px;
		font-weight: 600;
		color: #065f46;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 8px;
	}

	.amount-value {
		font-size: 32px;
		font-weight: 700;
		color: #059669;
		font-family: 'Courier New', monospace;
	}

	.toggle-label {
		display: flex;
		align-items: center;
		gap: 10px;
		cursor: pointer;
		user-select: none;
	}

	.toggle-label input[type="checkbox"] {
		width: 20px;
		height: 20px;
		cursor: pointer;
	}

	/* Selection Tables */
	.selection-table {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		margin-top: 0.5rem;
	}

	.selection-table table {
		width: 100%;
		border-collapse: collapse;
	}

	.selection-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.selection-table th {
		padding: 12px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
	}

	.selection-table td {
		padding: 10px 12px;
		font-size: 14px;
		border-bottom: 1px solid #f3f4f6;
	}

	.selection-table tbody tr {
		cursor: pointer;
		transition: background-color 0.2s ease;
	}

	.selection-table tbody tr:hover {
		background: #f9fafb;
	}

	.selection-table tbody tr.selected {
		background: #dbeafe;
	}

	.selection-table tbody tr.disabled {
		opacity: 0.5;
		cursor: not-allowed;
		background: #fef2f2;
	}

	.selection-table tbody tr.disabled:hover {
		background: #fef2f2;
	}

	.selection-table tbody tr.disabled input[type="radio"] {
		cursor: not-allowed;
	}

	.parent-badge {
		display: inline-block;
		padding: 4px 10px;
		background: #e0e7ff;
		color: #4338ca;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.arabic {
		direction: rtl;
		text-align: right;
	}

	.selected-info {
		margin-top: 10px;
		padding: 10px;
		background: #dcfce7;
		border-radius: 6px;
		color: #166534;
		font-size: 14px;
	}

	/* Approval Limit Display */
	.approval-limit-display {
		text-align: center;
		font-weight: 600;
	}

	.unlimited-badge {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 4px 12px;
		background: linear-gradient(135deg, #a855f7, #ec4899);
		color: white;
		border-radius: 12px;
		font-size: 13px;
		font-weight: 700;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	.limit-amount {
		display: inline-block;
		padding: 4px 12px;
		background: #dcfce7;
		color: #059669;
		border-radius: 12px;
		font-size: 13px;
		font-weight: 700;
		font-family: 'Courier New', monospace;
	}

	.over-limit-badge {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 4px 12px;
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
		border-radius: 12px;
		font-size: 13px;
		font-weight: 700;
		font-family: 'Courier New', monospace;
	}

	/* Empty State */
	.no-data-message {
		padding: 40px 20px !important;
	}

	.empty-state {
		text-align: center;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		display: block;
		margin-bottom: 16px;
	}

	.empty-state p {
		margin: 8px 0;
		font-size: 16px;
		font-weight: 600;
		color: #374151;
	}

	.empty-hint {
		font-size: 14px !important;
		font-weight: 400 !important;
		color: #9ca3af !important;
	}

	/* Requisition Template */
	.requisition-template {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 40px;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
	}

	.template-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 25px;
		padding-bottom: 20px;
		border-bottom: 3px solid #3b82f6;
	}

	.logo-section {
		display: flex;
		align-items: center;
		gap: 15px;
	}

	.app-logo {
		width: 60px;
		height: 60px;
		border-radius: 12px;
		object-fit: contain;
	}

	.app-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.app-name-en {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		line-height: 1;
	}

	.app-name-ar {
		font-size: 18px;
		font-weight: 600;
		color: #64748b;
		direction: rtl;
		line-height: 1;
	}

	.req-number {
		text-align: right;
	}

	.req-label {
		font-size: 11px;
		color: #6b7280;
		font-weight: 600;
		text-transform: uppercase;
		white-space: nowrap;
	}

	.req-value {
		font-size: 16px;
		font-weight: 700;
		color: #3b82f6;
		margin-top: 4px;
	}

	.template-title-section {
		text-align: center;
		margin-bottom: 25px;
	}

	.template-title {
		font-size: 26px;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 6px;
	}

	.template-subtitle {
		font-size: 20px;
		font-weight: 600;
		color: #6b7280;
		direction: rtl;
	}

	.template-section {
		margin-bottom: 20px;
		padding: 18px;
		background: #f9fafb;
		border-radius: 8px;
	}

	.section-title {
		font-size: 16px;
		font-weight: 700;
		color: #374151;
		margin-bottom: 15px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-bottom: 2px solid #e5e7eb;
		padding-bottom: 8px;
	}

	.title-en {
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.title-ar {
		direction: rtl;
		font-size: 15px;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 15px;
	}

	.info-item {
		background: white;
		padding: 12px;
		border-radius: 6px;
		border: 1px solid #e5e7eb;
	}

	.info-label {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 6px;
	}

	.label-en {
		font-weight: 600;
		color: #6b7280;
		font-size: 12px;
		text-transform: uppercase;
	}

	.label-ar {
		font-weight: 600;
		color: #6b7280;
		font-size: 11px;
		direction: rtl;
	}

	.info-value {
		color: #1e293b;
		font-size: 14px;
		font-weight: 500;
	}

	.amount-highlight {
		font-size: 18px;
		font-weight: 700;
		color: #059669;
		font-family: 'Courier New', monospace;
	}

	.description-box {
		background: white;
		padding: 15px;
		border-radius: 6px;
		min-height: 80px;
		font-size: 14px;
		line-height: 1.6;
		color: #1e293b;
		white-space: pre-wrap;
		border: 1px solid #e5e7eb;
	}

	/* Generated By Section */
	.generated-by-section {
		background: linear-gradient(135deg, #f8fafc, #e0f2fe);
		border: 1px solid #bae6fd;
		padding: 12px 20px !important;
		margin-top: 20px;
	}

	.generated-by {
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 13px;
		justify-content: center;
	}

	.generated-label {
		font-weight: 600;
		color: #0369a1;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.generated-value {
		font-weight: 700;
		color: #0c4a6e;
		background: white;
		padding: 4px 12px;
		border-radius: 6px;
		border: 1px solid #bae6fd;
	}

	.generated-separator {
		color: #0891b2;
		font-weight: 600;
	}

	.generated-date {
		color: #0369a1;
		font-style: italic;
		font-size: 12px;
	}

	.template-footer {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 40px;
		margin-top: 50px;
		padding-top: 30px;
		border-top: 2px dashed #d1d5db;
	}

	.signature-section {
		text-align: center;
	}

	.signature-line {
		border-top: 2px solid #1e293b;
		margin-bottom: 12px;
		padding-top: 60px;
	}

	.signature-label {
		font-weight: 600;
		color: #374151;
		font-size: 13px;
		display: flex;
		flex-direction: column;
		gap: 4px;
		align-items: center;
	}

	.signature-label .label-en {
		text-transform: uppercase;
		font-size: 12px;
	}

	.signature-label .label-ar {
		direction: rtl;
		font-size: 12px;
	}

	/* Template Actions */
	.template-actions {
		display: flex;
		gap: 1rem;
		justify-content: center;
		align-items: center;
		margin-top: 2rem;
	}

	.btn-save,
	.btn-whatsapp,
	.btn-reset {
		padding: 14px 28px;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 15px;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-save {
		background: #3b82f6;
		color: white;
	}

	.btn-save:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 10px 15px -3px rgba(59, 130, 246, 0.3);
	}

	.btn-save:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.btn-whatsapp {
		background: #25d366;
		color: white;
	}

	.btn-whatsapp:hover {
		background: #1da851;
		transform: translateY(-2px);
		box-shadow: 0 10px 15px -3px rgba(37, 211, 102, 0.3);
	}

	.btn-reset {
		background: #6b7280;
		color: white;
	}

	.btn-reset:hover {
		background: #4b5563;
	}

	.success-message {
		padding: 12px 24px;
		background: #dcfce7;
		color: #166534;
		border-radius: 8px;
		font-weight: 600;
		font-size: 15px;
	}

	/* Navigation Buttons */
	.nav-buttons {
		display: flex;
		justify-content: space-between;
		margin-top: 2rem;
		padding-top: 2rem;
		border-top: 2px solid #e5e7eb;
	}

	.btn-prev,
	.btn-next {
		padding: 12px 24px;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-prev {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-prev:hover {
		background: #e5e7eb;
	}

	.btn-next {
		background: #3b82f6;
		color: white;
		margin-left: auto;
	}

	.btn-next:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	/* Step 3 Generate Section */
	.generate-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2rem;
		padding: 3rem 2rem;
	}

	.generate-placeholder {
		text-align: center;
		max-width: 500px;
	}

	.placeholder-icon {
		font-size: 80px;
		margin-bottom: 1.5rem;
		opacity: 0.8;
	}

	.generate-placeholder h3 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.75rem;
	}

	.generate-placeholder p {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	.btn-generate {
		padding: 18px 48px;
		background: linear-gradient(135deg, #3b82f6, #8b5cf6);
		color: white;
		border: none;
		border-radius: 12px;
		font-weight: 700;
		font-size: 18px;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 10px 25px -5px rgba(59, 130, 246, 0.4);
	}

	.btn-generate:hover {
		transform: translateY(-3px);
		box-shadow: 0 15px 35px -5px rgba(59, 130, 246, 0.5);
	}

	.btn-generate:active {
		transform: translateY(-1px);
	}

	/* Success Section */
	.success-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.5rem;
		padding: 3rem 2rem;
		text-align: center;
	}

	.success-icon {
		font-size: 80px;
		animation: scaleIn 0.5s ease-out;
	}

	@keyframes scaleIn {
		from {
			transform: scale(0);
		}
		to {
			transform: scale(1);
		}
	}

	.success-section h3 {
		font-size: 1.75rem;
		font-weight: 700;
		color: #059669;
		margin: 0;
	}

	.success-section p {
		color: #64748b;
		font-size: 1.125rem;
		margin: 0;
	}

	.success-section p strong {
		color: #3b82f6;
		font-weight: 700;
	}

	.btn-view {
		padding: 14px 32px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-view:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(59, 130, 246, 0.3);
	}

	.action-buttons {
		display: flex;
		gap: 1rem;
		margin-top: 1rem;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		animation: fadeIn 0.2s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.modal-content {
		background: white;
		border-radius: 16px;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
		max-width: 900px;
		width: 90%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		animation: slideUp 0.3s ease-out;
	}

	@keyframes slideUp {
		from {
			transform: translateY(20px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		background: linear-gradient(135deg, #3b82f6, #8b5cf6);
		color: white;
		border-radius: 16px 16px 0 0;
	}

	.modal-header-actions {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.btn-print-header {
		padding: 10px 20px;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: all 0.2s ease;
		backdrop-filter: blur(10px);
	}

	.btn-print-header:hover {
		background: rgba(255, 255, 255, 0.3);
		border-color: rgba(255, 255, 255, 0.5);
		transform: translateY(-2px);
	}

	.btn-print-header:active {
		transform: translateY(0);
	}

	.modal-title {
		font-size: 1.5rem;
		font-weight: 700;
		margin: 0;
	}

	.modal-subtitle {
		font-size: 0.875rem;
		margin: 0.25rem 0 0 0;
		opacity: 0.9;
	}

	.modal-close {
		background: none;
		border: none;
		color: white;
		font-size: 2.5rem;
		line-height: 1;
		cursor: pointer;
		padding: 0;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.modal-close:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.modal-body {
		overflow-y: auto;
		padding: 2rem;
		flex: 1;
	}

	.modal-footer {
		padding: 1.5rem 2rem;
		border-top: 2px solid #e5e7eb;
		display: flex;
		gap: 1rem;
		justify-content: center;
		align-items: center;
		flex-direction: column;
		background: #f9fafb;
		border-radius: 0 0 16px 16px;
	}

	.saving-progress {
		width: 100%;
		max-width: 400px;
		margin-top: 1rem;
	}

	.progress-bar-container {
		width: 100%;
		height: 30px;
		background: #e5e7eb;
		border-radius: 15px;
		overflow: hidden;
		position: relative;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.progress-bar {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6 0%, #2563eb 50%, #1d4ed8 100%);
		transition: width 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: flex-end;
		padding-right: 10px;
		color: white;
		font-weight: 600;
		font-size: 12px;
		position: relative;
		overflow: hidden;
	}

	.progress-bar::after {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: linear-gradient(
			90deg,
			transparent,
			rgba(255, 255, 255, 0.3),
			transparent
		);
		animation: shimmer 2s infinite;
	}

	@keyframes shimmer {
		0% {
			transform: translateX(-100%);
		}
		100% {
			transform: translateX(100%);
		}
	}

	.progress-text {
		margin-top: 8px;
		text-align: center;
		font-size: 13px;
		font-weight: 600;
		color: #374151;
	}

	.save-success {
		padding: 10px 20px;
		background: #dcfce7;
		color: #059669;
		border-radius: 8px;
		font-weight: 600;
		font-size: 15px;
	}

	.btn-close-modal {
		padding: 12px 28px;
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 15px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-close-modal:hover {
		background: #4b5563;
	}

	/* Print Styles */
	@media print {
		.no-print,
		.print-btn,
		.modal-overlay,
		.modal-header,
		.modal-footer,
		.template-actions {
			display: none !important;
		}

		.requisition-template {
			box-shadow: none;
			border: 1px solid #000;
			page-break-inside: avoid;
		}

		body {
			background: white;
		}
	}

	/* Requester Dropdown Styles */
	.requester-dropdown-container {
		position: relative;
	}

	.search-input {
		position: relative;
		width: 100%;
	}

	.dropdown-list {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
		max-height: 200px;
		overflow-y: auto;
		z-index: 1000;
		margin-top: 4px;
	}

	.dropdown-item {
		padding: 12px;
		cursor: pointer;
		border-bottom: 1px solid #f1f5f9;
		transition: background-color 0.2s;
	}

	.dropdown-item:hover {
		background-color: #f8fafc;
	}

	.dropdown-item:last-child {
		border-bottom: none;
	}

	.requester-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.requester-id, .requester-contact {
		font-size: 0.875rem;
		color: #64748b;
	}

	.no-results {
		padding: 12px;
		color: #64748b;
		font-style: italic;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		margin-top: 4px;
		text-align: center;
	}

	.selected-requester {
		background: #f0f9ff;
		border: 1px solid #0ea5e9;
		border-radius: 6px;
		padding: 12px;
		margin-top: 8px;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.btn-clear {
		background: #ef4444;
		color: white;
		border: none;
		padding: 4px 8px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
	}

	.btn-clear:hover {
		background: #dc2626;
	}

	.new-requester-section {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 20px;
		margin-top: 16px;
	}

	.new-requester-section h3 {
		margin: 0 0 16px 0;
		color: #334155;
		font-size: 1.125rem;
	}

	.save-field-btn {
		background: #10b981;
		color: white;
		border: none;
		padding: 6px 12px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		margin-top: 8px;
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.save-field-btn:hover {
		background: #059669;
	}
</style>
