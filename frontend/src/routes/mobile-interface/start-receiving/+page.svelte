<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { localeData, currentLocale } from '$lib/i18n';

	// ---- Translation helper ----
	function gt(key: string): string {
		const data = $localeData;
		const keys = key.split('.');
		let value: any = data.translations;
		for (const k of keys) {
			if (value && typeof value === 'object' && k in value) {
				value = value[k];
			} else {
				return key;
			}
		}
		return typeof value === 'string' ? value : key;
	}

	// ---- Step wizard ----
	let currentStep = 0; // 0=Branch, 1=Vendor, 2=BillInfo, 3=Finalization
	$: stepLabels = [
		gt('receiving.stepSelectBranch'),
		gt('receiving.stepSelectVendor'),
		gt('receiving.stepBillInformation'),
		gt('receiving.stepFinalization')
	];

	// ---- Alerts / toasts ----
	let toastMessage = '';
	let toastType: 'success' | 'error' | 'info' = 'info';
	let toastVisible = false;
	function showToast(msg: string, type: 'success' | 'error' | 'info' = 'info') {
		toastMessage = msg;
		toastType = type;
		toastVisible = true;
		setTimeout(() => { toastVisible = false; }, 3000);
	}

	// ---- Step 1: Branch ----
	let branches: any[] = [];
	let selectedBranch = '';
	let selectedBranchName = '';
	let selectedBranchLocation = '';
	let branchConfirmed = false;
	let isLoading = false;
	let errorMessage = '';
	let setAsDefaultBranch = false;
	let userDefaultBranchId: number | null = null;

	// Default positions
	let defaultPositionsLoading = false;
	let defaultPositionsLoaded = false;
	let defaultPositionsError = '';

	// Staff selections
	let selectedBranchManager: any = null;
	let selectedPurchasingManager: any = null;
	let selectedInventoryManager: any = null;
	let selectedAccountant: any = null;
	let selectedNightSupervisors: any[] = [];
	let selectedWarehouseHandler: any = null;
	let selectedShelfStockers: any[] = [];

	// Shelf stocker selection
	let shelfStockers: any[] = [];
	let actualShelfStockers: any[] = [];
	let filteredShelfStockers: any[] = [];
	let shelfStockersLoading = false;
	let shelfStockerSearchQuery = '';
	let showAllUsersForShelfStockers = false;

	$: allRequiredUsersSelected = selectedBranch &&
		selectedBranchManager &&
		selectedAccountant &&
		selectedPurchasingManager &&
		selectedInventoryManager &&
		selectedShelfStockers.length > 0 &&
		selectedWarehouseHandler &&
		selectedNightSupervisors.length > 0;

	// Filter shelf stockers
	$: {
		const q = shelfStockerSearchQuery.toLowerCase().trim();
		if (!q) {
			filteredShelfStockers = actualShelfStockers.length > 0 ? actualShelfStockers : shelfStockers;
		} else {
			const source = actualShelfStockers.length > 0 ? actualShelfStockers : shelfStockers;
			filteredShelfStockers = source.filter(u =>
				u.employeeName?.toLowerCase().includes(q) ||
				u.employeeId?.toLowerCase().includes(q) ||
				u.position?.toLowerCase().includes(q)
			);
		}
	}

	// ---- Step 2: Vendor ----
	let vendors: any[] = [];
	let filteredVendors: any[] = [];
	let vendorSearchQuery = '';
	let vendorSearchLower = '';
	let selectedVendor: any = null;
	let vendorLoading = false;
	let vendorError = '';

	// Vendor update popup
	let showVendorUpdatePopup = false;
	let vendorToUpdate: any = null;
	let updatedSalesmanName = '';
	let updatedSalesmanContact = '';
	let updatedVatNumber = '';
	let isUpdatingVendor = false;

	// Bill scan (OCR) state
	let billDetecting = false;
	let billScanParsing = false;
	let billScanResults: {
		companyName?: string;
		vatNumber?: string;
		billDate?: string;
		totalAmount?: string;
		billNumber?: string;
		allText?: string;
	} | null = null;
	let showBillScanResults = false;
	let billScanMatchedVendors: any[] = [];
	let billFileInput: HTMLInputElement;
	let scanVendorSearch = '';
	let filteredScanVendors: any[] = [];

	// Filter scan modal vendors
	$: {
		const sq = scanVendorSearch.toLowerCase().trim();
		if (!sq) {
			filteredScanVendors = billScanMatchedVendors;
		} else {
			filteredScanVendors = billScanMatchedVendors.filter(v =>
				v.vendor_name?.toLowerCase().includes(sq) ||
				v.erp_vendor_id?.toString().includes(sq) ||
				v.salesman_name?.toLowerCase().includes(sq) ||
				v.vat_number?.replace(/\s/g, '').includes(sq.replace(/\s/g, ''))
			);
		}
	}

	// Filter vendors reactively
	$: vendorSearchLower = vendorSearchQuery.toLowerCase().trim();
	$: filteredVendors = !vendorSearchLower
		? vendors
		: vendors.filter(v =>
			v.vendor_name?.toLowerCase().includes(vendorSearchLower) ||
			v.erp_vendor_id?.toString().includes(vendorSearchLower) ||
			v.salesman_name?.toLowerCase().includes(vendorSearchLower) ||
			v.place?.toLowerCase().includes(vendorSearchLower) ||
			(typeof v.categories === 'string' && v.categories.toLowerCase().includes(vendorSearchLower)) ||
			(Array.isArray(v.categories) && v.categories.some((c: any) => String(c).toLowerCase().includes(vendorSearchLower)))
		);
	// ---- Step 3: Bill Information ----
	let billDate = new Date().toISOString().split('T')[0];
	let billAmount = '';
	let billNumber = '';

	// Payment
	let paymentMethod = '';
	let creditPeriod = '';
	let bankName = '';
	let iban = '';
	let paymentChanged = false;

	// Helper: treat 'N/A', null, undefined as empty
	function cleanVal(v: any): string {
		if (v == null) return '';
		const s = String(v).trim();
		return (s === 'N/A' || s === 'n/a' || s === 'NA') ? '' : s;
	}
	let paymentMethodExplicitlySelected = false;

	// Due date
	let dueDate = '';
	let dueDateReady = false;

	// VAT
	let vendorVatNumber = '';
	let billVatNumber = '';
	let vatMismatchReason = '';
	$: vatNumbersMatch = vendorVatNumber && billVatNumber ? vendorVatNumber === billVatNumber : null;

	// Returns
	let returns = {
		expired: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
		nearExpiry: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
		overStock: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
		damage: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' }
	};

	$: totalReturnAmount =
		(returns.expired.hasReturn === 'yes' ? parseFloat(returns.expired.amount || '0') : 0) +
		(returns.nearExpiry.hasReturn === 'yes' ? parseFloat(returns.nearExpiry.amount || '0') : 0) +
		(returns.overStock.hasReturn === 'yes' ? parseFloat(returns.overStock.amount || '0') : 0) +
		(returns.damage.hasReturn === 'yes' ? parseFloat(returns.damage.amount || '0') : 0);

	$: finalBillAmount = parseFloat(billAmount || '0') - totalReturnAmount;

	// Reactive payment population from vendor
	$: if (selectedVendor && !paymentChanged) {
		paymentMethod = cleanVal(selectedVendor.payment_method);
		creditPeriod = cleanVal(selectedVendor.credit_period);
		bankName = cleanVal(selectedVendor.bank_name);
		iban = cleanVal(selectedVendor.iban);
		vendorVatNumber = cleanVal(selectedVendor.vat_number);
		if (paymentMethod) paymentMethodExplicitlySelected = true;
	}

	// Reactive due date calculation
	$: {
		if (billDate && paymentMethod) {
			if (paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery') {
				dueDate = billDate;
				dueDateReady = true;
			} else if ((paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit') && creditPeriod) {
				const d = new Date(billDate);
				d.setDate(d.getDate() + parseInt(creditPeriod));
				dueDate = d.toISOString().split('T')[0];
				dueDateReady = true;
			} else {
				dueDate = '';
				dueDateReady = false;
			}
		} else {
			dueDate = '';
			dueDateReady = false;
		}
	}

	// ---- Step 4: Finalization ----
	let savedReceivingId: number | null = null;
	let isSaving = false;
	let showPaymentUpdateModal = false;
	let paymentUpdateMessage = '';

	// ---- Lifecycle ----
	onMount(async () => {
		await loadBranches();
		await loadUserDefaultBranch();
	});

	// ---- Data loaders ----
	async function loadBranches() {
		try {
			isLoading = true;
			errorMessage = '';
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (err: any) {
			errorMessage = 'Failed to load branches: ' + err.message;
		} finally {
			isLoading = false;
		}
	}

	async function loadUserDefaultBranch() {
		if (!$currentUser?.id) return;
		try {
			const { data, error } = await supabase
				.from('receiving_user_defaults')
				.select('default_branch_id')
				.eq('user_id', $currentUser.id)
				.single();
			if (error && error.code !== 'PGRST116') throw error;
			if (data) {
				userDefaultBranchId = data.default_branch_id;
				selectedBranch = data.default_branch_id.toString();
				setAsDefaultBranch = true;
				confirmBranchSelection();
			}
		} catch (err) {
			console.error('Error loading default branch:', err);
		}
	}

	async function saveUserDefaultBranch(branchId: string) {
		if (!$currentUser?.id) return;
		try {
			await supabase
				.from('receiving_user_defaults')
				.upsert({ user_id: $currentUser.id, default_branch_id: parseInt(branchId) }, { onConflict: 'user_id' });
			userDefaultBranchId = parseInt(branchId);
		} catch (err) {
			console.error('Error saving default branch:', err);
		}
	}

	async function removeUserDefaultBranch() {
		if (!$currentUser?.id) return;
		try {
			await supabase.from('receiving_user_defaults').delete().eq('user_id', $currentUser.id);
			userDefaultBranchId = null;
		} catch (err) {
			console.error('Error removing default branch:', err);
		}
	}

	async function handleDefaultBranchToggle() {
		if (setAsDefaultBranch && selectedBranch) {
			await saveUserDefaultBranch(selectedBranch);
		} else {
			await removeUserDefaultBranch();
		}
	}

	function confirmBranchSelection() {
		if (!selectedBranch) return;
		const branch = branches.find(b => b.id.toString() === selectedBranch);
		if (branch) {
			const isAr = $currentLocale === 'ar';
			selectedBranchName = isAr ? (branch.name_ar || branch.name_en) : branch.name_en;
			selectedBranchLocation = isAr ? (branch.location_ar || branch.location_en) : branch.location_en;
		}
		branchConfirmed = true;
		setAsDefaultBranch = userDefaultBranchId !== null && userDefaultBranchId.toString() === selectedBranch;
		loadVendors();
		loadBranchDefaultPositions();
	}

	function changeBranch() {
		branchConfirmed = false;
		currentStep = 0;
		selectedVendor = null;
		selectedBranchManager = null;
		selectedPurchasingManager = null;
		selectedInventoryManager = null;
		selectedAccountant = null;
		selectedShelfStockers = [];
		selectedNightSupervisors = [];
		selectedWarehouseHandler = null;
		defaultPositionsLoaded = false;
	}

	async function loadBranchDefaultPositions() {
		if (!selectedBranch) return;
		try {
			defaultPositionsLoading = true;
			defaultPositionsError = '';
			defaultPositionsLoaded = false;

			const { data, error } = await supabase
				.from('branch_default_positions')
				.select('*')
				.eq('branch_id', parseInt(selectedBranch, 10))
				.maybeSingle();

			if (error) throw error;
			if (!data) {
				defaultPositionsError = $currentLocale === 'ar'
					? 'لا توجد مناصب افتراضية لهذا الفرع'
					: 'No default positions configured for this branch.';
				return;
			}

			const userIds = [
				data.branch_manager_user_id,
				data.purchasing_manager_user_id,
				data.inventory_manager_user_id,
				data.accountant_user_id,
				data.warehouse_handler_user_id,
				...(data.night_supervisor_user_ids || [])
			].filter(Boolean);

			if (userIds.length === 0) {
				defaultPositionsError = $currentLocale === 'ar'
					? 'المناصب الافتراضية مكونة لكن لا يوجد مستخدمون معينون'
					: 'Default positions configured but no users assigned.';
				return;
			}

			const { data: employees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar, id')
				.in('user_id', userIds);
			if (empError) throw empError;

			const isAr = $currentLocale === 'ar';
			const userMap: Record<string, any> = {};
			(employees || []).forEach(emp => {
				userMap[emp.user_id] = {
					id: emp.user_id,
					username: emp.id,
					employeeName: isAr ? (emp.name_ar || emp.name_en || emp.id) : (emp.name_en || emp.id),
				};
			});

			if (data.branch_manager_user_id && userMap[data.branch_manager_user_id])
				selectedBranchManager = userMap[data.branch_manager_user_id];
			if (data.purchasing_manager_user_id && userMap[data.purchasing_manager_user_id])
				selectedPurchasingManager = userMap[data.purchasing_manager_user_id];
			if (data.inventory_manager_user_id && userMap[data.inventory_manager_user_id])
				selectedInventoryManager = userMap[data.inventory_manager_user_id];
			if (data.accountant_user_id && userMap[data.accountant_user_id])
				selectedAccountant = userMap[data.accountant_user_id];
			if (data.warehouse_handler_user_id && userMap[data.warehouse_handler_user_id])
				selectedWarehouseHandler = userMap[data.warehouse_handler_user_id];
			if (data.night_supervisor_user_ids?.length > 0)
				selectedNightSupervisors = data.night_supervisor_user_ids.filter((id: string) => userMap[id]).map((id: string) => userMap[id]);

			defaultPositionsLoaded = true;
			await loadShelfStockersForSelection();
		} catch (err: any) {
			defaultPositionsError = 'Failed to load default positions: ' + err.message;
		} finally {
			defaultPositionsLoading = false;
		}
	}

	async function loadShelfStockersForSelection() {
		if (!selectedBranch) return;
		try {
			shelfStockersLoading = true;
			const { data: employees, error } = await supabase
				.from('hr_employee_master')
				.select('user_id, id, name_en, name_ar, hr_positions(position_title_en, position_title_ar)')
				.eq('current_branch_id', parseInt(selectedBranch))
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.order('name_en');
			if (error) throw error;

			const isAr = $currentLocale === 'ar';
			const all = (employees || []).map(emp => ({
				id: emp.user_id,
				employeeName: isAr ? (emp.name_ar || emp.name_en || emp.id) : (emp.name_en || emp.id),
				employeeId: emp.id,
				position: isAr
					? (emp.hr_positions?.position_title_ar || emp.hr_positions?.position_title_en || '')
					: (emp.hr_positions?.position_title_en || '')
			}));

			const stockers = all.filter(u =>
				(emp => emp.position_title_en || '')(u).toLowerCase().includes('shelf') ||
				u.position.toLowerCase().includes('shelf')
			);

			shelfStockers = all;
			actualShelfStockers = all.filter(u => {
				const posEn = (employees || []).find(e => e.user_id === u.id)?.hr_positions?.position_title_en || '';
				return posEn.toLowerCase().includes('shelf') && posEn.toLowerCase().includes('stocker');
			});
			filteredShelfStockers = actualShelfStockers.length > 0 ? actualShelfStockers : all;
			showAllUsersForShelfStockers = actualShelfStockers.length === 0;
		} catch (err) {
			console.error('Error loading shelf stockers:', err);
		} finally {
			shelfStockersLoading = false;
		}
	}

	function addShelfStocker(user: any) {
		if (!selectedShelfStockers.find(s => s.id === user.id)) {
			selectedShelfStockers = [...selectedShelfStockers, user];
		}
	}

	function removeShelfStocker(userId: string) {
		selectedShelfStockers = selectedShelfStockers.filter(s => s.id !== userId);
	}

	async function loadVendors() {
		if (!selectedBranch) return;
		try {
			vendorLoading = true;
			vendorError = '';
			const { data, error } = await supabase
				.from('vendors')
				.select('*')
				.or(`branch_id.eq.${selectedBranch},branch_id.is.null`)
				.eq('status', 'Active')
				.order('vendor_name', { ascending: true })
				.limit(10000);
			if (error) throw error;
			vendors = data || [];
			if (vendors.length === 0) {
				vendorError = $currentLocale === 'ar'
					? 'لا يوجد موردون لهذا الفرع'
					: 'No vendors assigned to this branch.';
			}
		} catch (err: any) {
			vendorError = 'Failed to load vendors: ' + err.message;
		} finally {
			vendorLoading = false;
		}
	}

	// ---- Bill Scan (OCR) Functions ----
	function startBillScan() {
		// Trigger native file picker / camera on mobile
		if (billFileInput) {
			billFileInput.value = '';
			billFileInput.click();
		}
	}

	async function handleBillFileSelected(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input?.files?.[0];
		if (!file) return;

		billDetecting = true;
		showBillScanResults = true;
		billScanParsing = true;
		billScanResults = null;
		billScanMatchedVendors = [];
		scanVendorSearch = '';

		try {
			// Convert file to base64
			const base64 = await new Promise<string>((resolve, reject) => {
				const reader = new FileReader();
				reader.onload = () => {
					const result = reader.result as string;
					resolve(result.split(',')[1]);
				};
				reader.onerror = reject;
				reader.readAsDataURL(file);
			});

			// Get Google API key from DB
			let apiKey = '';
			try {
				const { data: keyRow } = await supabase
					.from('system_api_keys')
					.select('api_key')
					.eq('service_name', 'google')
					.eq('is_active', true)
					.single();
				if (keyRow?.api_key) apiKey = keyRow.api_key;
			} catch (_) { /* fallback */ }
			if (!apiKey) {
				showToast($currentLocale === 'ar' ? 'لا يوجد مفتاح API' : 'No API key configured', 'error');
				billDetecting = false;
				return;
			}

			// Call Google Vision OCR
			const visionRes = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					requests: [{
						image: { content: base64 },
						features: [{ type: 'TEXT_DETECTION', maxResults: 50 }]
					}]
				})
			});
			const visionData = await visionRes.json();

			if (visionData.error) {
				console.error('Vision API error:', visionData.error);
				billDetecting = false;
				billScanParsing = false;
				showToast($currentLocale === 'ar' ? 'خطأ في قراءة الصورة' : 'Error reading image', 'error');
				return;
			}

			const annotations = visionData.responses?.[0]?.textAnnotations || [];
			if (annotations.length === 0) {
				billDetecting = false;
				billScanParsing = false;
				showToast($currentLocale === 'ar' ? 'لم يتم العثور على نص. حاول صورة أوضح.' : 'No text found. Try a clearer photo.', 'error');
				return;
			}

			const fullText = annotations[0]?.description || '';
			console.log('[BILL SCAN] OCR text length:', fullText.length, 'First 200 chars:', fullText.substring(0, 200));

			// Now use Gemini to parse the bill text

			const geminiRes = await fetch(
				`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						systemInstruction: { parts: [{ text: 'You are a bill/invoice data extractor. Extract structured data from OCR text of bills/invoices. Respond ONLY with valid JSON, no markdown, no explanation.' }] },
						contents: [{ role: 'user', parts: [{ text: `Extract the following from this bill/invoice text. Return a JSON object with these fields:
- "companyName": the vendor/supplier company name (not the buyer)
- "vatNumber": the VAT/tax registration number (usually 15 digits in Saudi Arabia, starts with 3)
- "billDate": the invoice/bill date in YYYY-MM-DD format
- "totalAmount": the total/net amount as a number string (without currency)
- "billNumber": the invoice/voucher number (look for Voucher Number, Invoice No, Bill No, etc.)

If a field is not found, use null. Here is the bill text:

${fullText}` }] }],
						generationConfig: { temperature: 0.1, maxOutputTokens: 500 }
					})
				}
			);

			if (geminiRes.ok) {
				const geminiData = await geminiRes.json();
				let rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';
				// Strip markdown code fences if present
				rawText = rawText.replace(/```json\s*/gi, '').replace(/```\s*/g, '').trim();
				try {
					const parsed = JSON.parse(rawText);
					console.log('[BILL SCAN] Parsed data:', parsed);
					billScanResults = {
						companyName: parsed.companyName || undefined,
						vatNumber: parsed.vatNumber || undefined,
						billDate: parsed.billDate || undefined,
						totalAmount: parsed.totalAmount || undefined,
						billNumber: parsed.billNumber || undefined,
						allText: fullText
					};
				} catch (parseErr) {
					console.error('[BILL SCAN] Failed to parse Gemini JSON:', rawText);
					billScanResults = { allText: fullText };
				}
			} else {
				console.error('[BILL SCAN] Gemini API error:', geminiRes.status);
				billScanResults = { allText: fullText };
			}

			// Always rank ALL vendors — best matches first, then the rest
			if (vendors.length > 0) {
				const scannedName = (billScanResults?.companyName || '').toLowerCase();
				const scannedVat = (billScanResults?.vatNumber || '').replace(/\s/g, '');

				const scored = vendors.map((v: any) => {
					let score = 0;
					const vName = (v.vendor_name || '').toLowerCase();
					const vVat = (v.vat_number || '').replace(/\s/g, '');

					// VAT match is strongest signal
					if (scannedVat && vVat && scannedVat === vVat) {
						score += 100;
					}
					// Name matching
					if (scannedName && vName) {
						const vWords = vName.split(/[\s\-&,]+/).filter((w: string) => w.length > 2);
						const sWords = scannedName.split(/[\s\-&,]+/).filter((w: string) => w.length > 2);
						for (const vw of vWords) {
							if (scannedName.includes(vw)) score += 10;
						}
						for (const sw of sWords) {
							if (vName.includes(sw)) score += 10;
						}
						if (vName === scannedName) score += 50;
					}

					return { ...v, _matchScore: score };
				});

				scored.sort((a: any, b: any) => b._matchScore - a._matchScore);
				billScanMatchedVendors = scored;
			}

			billDetecting = false;
			billScanParsing = false;
		} catch (err) {
			console.error('Bill scan error:', err);
			billDetecting = false;
			billScanParsing = false;
			showToast($currentLocale === 'ar' ? 'فشل مسح الفاتورة' : 'Bill scan failed', 'error');
		}
	}

	function selectScannedVendor(vendor: any) {
		// Auto-fill bill data from scan
		if (billScanResults) {
			if (billScanResults.billDate) billDate = billScanResults.billDate;
			if (billScanResults.totalAmount) billAmount = billScanResults.totalAmount;
			if (billScanResults.vatNumber) billVatNumber = billScanResults.vatNumber;
			if (billScanResults.billNumber) billNumber = billScanResults.billNumber;
		}
		showBillScanResults = false;
		selectVendor(vendor);
	}

	function closeBillScanResults() {
		showBillScanResults = false;
		scanVendorSearch = '';
	}

	async function selectVendor(vendor: any) {
		// If we have scan results, auto-fill bill fields even if user picks a different vendor
		if (billScanResults) {
			if (billScanResults.billDate) billDate = billScanResults.billDate;
			if (billScanResults.totalAmount) billAmount = billScanResults.totalAmount;
			if (billScanResults.vatNumber) billVatNumber = billScanResults.vatNumber;
			if (billScanResults.billNumber) billNumber = billScanResults.billNumber;
		}
		const missingSalesmanName = !vendor.salesman_name?.trim();
		const missingSalesmanContact = !vendor.salesman_contact?.trim();
		const missingVatNumber = !vendor.vat_number?.trim();

		if (missingSalesmanName || missingSalesmanContact || missingVatNumber) {
			vendorToUpdate = vendor;
			updatedSalesmanName = vendor.salesman_name || '';
			updatedSalesmanContact = vendor.salesman_contact || '';
			updatedVatNumber = vendor.vat_number || '';
			showVendorUpdatePopup = true;
		} else {
			selectedVendor = vendor;
			// Explicitly populate payment fields from vendor
			paymentMethod = cleanVal(vendor.payment_method);
			creditPeriod = cleanVal(vendor.credit_period);
			bankName = cleanVal(vendor.bank_name);
			iban = cleanVal(vendor.iban);
			vendorVatNumber = cleanVal(vendor.vat_number);
			if (paymentMethod) paymentMethodExplicitlySelected = true;
			paymentChanged = false;
			currentStep = 2;
		}
	}

	async function updateVendorInformation() {
		if (!vendorToUpdate) return;
		if (!updatedVatNumber?.trim()) {
			showToast(gt('receiving.vendorMissingInfo'), 'error');
			return;
		}
		isUpdatingVendor = true;
		try {
			const updateData: any = {};
			if (updatedSalesmanName !== vendorToUpdate.salesman_name)
				updateData.salesman_name = updatedSalesmanName.trim();
			if (updatedSalesmanContact !== vendorToUpdate.salesman_contact)
				updateData.salesman_contact = updatedSalesmanContact.trim();
			if (updatedVatNumber !== vendorToUpdate.vat_number)
				updateData.vat_number = updatedVatNumber.trim();

			if (Object.keys(updateData).length > 0) {
				const { error } = await supabase
					.from('vendors')
					.update(updateData)
					.eq('erp_vendor_id', vendorToUpdate.erp_vendor_id)
					.eq('branch_id', selectedBranch);
				if (error) throw error;

				const idx = vendors.findIndex(v => v.erp_vendor_id === vendorToUpdate.erp_vendor_id && v.branch_id?.toString() === selectedBranch);
				if (idx !== -1) {
					vendors[idx] = { ...vendors[idx], ...updateData };
					vendors = [...vendors];
				}
				vendorToUpdate = { ...vendorToUpdate, ...updateData };
				showToast(gt('receiving.vendorInfoUpdated'), 'success');
			}
			selectedVendor = vendorToUpdate;
			// Explicitly populate payment fields from vendor
			paymentMethod = cleanVal(vendorToUpdate.payment_method);
			creditPeriod = cleanVal(vendorToUpdate.credit_period);
			bankName = cleanVal(vendorToUpdate.bank_name);
			iban = cleanVal(vendorToUpdate.iban);
			vendorVatNumber = cleanVal(vendorToUpdate.vat_number);
			if (paymentMethod) paymentMethodExplicitlySelected = true;
			paymentChanged = false;
			showVendorUpdatePopup = false;
			vendorToUpdate = null;
			currentStep = 2;
		} catch (err: any) {
			showToast('Error: ' + err.message, 'error');
		} finally {
			isUpdatingVendor = false;
		}
	}

	function closeVendorUpdatePopup() {
		showVendorUpdatePopup = false;
		vendorToUpdate = null;
	}

	function changeVendor() {
		selectedVendor = null;
		currentStep = 1;
	}

	function handlePaymentMethodChange() {
		paymentChanged = true;
		paymentMethodExplicitlySelected = true;
		if (paymentMethod === 'Cash on Delivery') {
			creditPeriod = '';
			bankName = '';
			iban = '';
		} else if (paymentMethod === 'Bank on Delivery') {
			creditPeriod = '';
		} else if (paymentMethod === 'Cash Credit') {
			bankName = '';
			iban = '';
		}
	}

	function maskVatNumber(vatNumber: string) {
		if (!vatNumber || vatNumber.length <= 4) return vatNumber;
		return '*'.repeat(vatNumber.length - 4) + vatNumber.slice(-4);
	}

	// ---- Save ----
	async function saveReceivingData() {
		// Validate
		const missingFields: string[] = [];
		if (!billDate) missingFields.push('Bill Date');
		if (!billAmount || parseFloat(billAmount) <= 0) missingFields.push('Bill Amount');
		if (!billNumber?.trim()) missingFields.push('Bill Number');
		if (!paymentMethodExplicitlySelected) missingFields.push('Payment Method');
		if (!dueDateReady) missingFields.push('Due Date');

		if (missingFields.length > 0) {
			showToast(gt('receiving.fillRequiredFields') + ': ' + missingFields.join(', '), 'error');
			return;
		}

		if (selectedVendor?.vat_applicable === 'VAT Applicable' && billVatNumber && vatNumbersMatch === false && !vatMismatchReason.trim()) {
			showToast(gt('receiving.provideVatReason'), 'error');
			return;
		}

		isSaving = true;
		try {
			const receivingData = {
				user_id: $currentUser?.id,
				branch_id: parseInt(selectedBranch, 10),
				vendor_id: selectedVendor?.erp_vendor_id,
				bill_date: billDate,
				bill_amount: parseFloat(billAmount || '0'),
				bill_number: billNumber || null,
				payment_method: paymentMethod || selectedVendor?.payment_method || null,
				credit_period: creditPeriod || selectedVendor?.credit_period || null,
				due_date: dueDate || null,
				bank_name: bankName || selectedVendor?.bank_name || null,
				iban: iban || selectedVendor?.iban || null,
				vendor_vat_number: vendorVatNumber || selectedVendor?.vat_number || null,
				bill_vat_number: billVatNumber || null,
				vat_numbers_match: vatNumbersMatch,
				vat_mismatch_reason: vatMismatchReason || null,
				branch_manager_user_id: selectedBranchManager?.id || null,
				accountant_user_id: selectedAccountant?.id || null,
				purchasing_manager_user_id: selectedPurchasingManager?.id || null,
				shelf_stocker_user_ids: selectedShelfStockers.map(s => s.id),
				inventory_manager_user_id: selectedInventoryManager?.id || null,
				night_supervisor_user_ids: selectedNightSupervisors?.map(s => s.id) || [],
				warehouse_handler_user_ids: selectedWarehouseHandler ? [selectedWarehouseHandler.id] : [],
				expired_return_amount: returns.expired.hasReturn === 'yes' ? parseFloat(returns.expired.amount || '0') : 0,
				near_expiry_return_amount: returns.nearExpiry.hasReturn === 'yes' ? parseFloat(returns.nearExpiry.amount || '0') : 0,
				over_stock_return_amount: returns.overStock.hasReturn === 'yes' ? parseFloat(returns.overStock.amount || '0') : 0,
				damage_return_amount: returns.damage.hasReturn === 'yes' ? parseFloat(returns.damage.amount || '0') : 0,
				has_expired_returns: returns.expired.hasReturn === 'yes',
				has_near_expiry_returns: returns.nearExpiry.hasReturn === 'yes',
				has_over_stock_returns: returns.overStock.hasReturn === 'yes',
				has_damage_returns: returns.damage.hasReturn === 'yes',
				expired_erp_document_type: returns.expired.hasReturn === 'yes' ? returns.expired.erpDocumentType : null,
				expired_erp_document_number: returns.expired.hasReturn === 'yes' ? returns.expired.erpDocumentNumber : null,
				expired_vendor_document_number: returns.expired.hasReturn === 'yes' ? returns.expired.vendorDocumentNumber : null,
				near_expiry_erp_document_type: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.erpDocumentType : null,
				near_expiry_erp_document_number: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.erpDocumentNumber : null,
				near_expiry_vendor_document_number: returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.vendorDocumentNumber : null,
				over_stock_erp_document_type: returns.overStock.hasReturn === 'yes' ? returns.overStock.erpDocumentType : null,
				over_stock_erp_document_number: returns.overStock.hasReturn === 'yes' ? returns.overStock.erpDocumentNumber : null,
				over_stock_vendor_document_number: returns.overStock.hasReturn === 'yes' ? returns.overStock.vendorDocumentNumber : null,
				damage_erp_document_type: returns.damage.hasReturn === 'yes' ? returns.damage.erpDocumentType : null,
				damage_erp_document_number: returns.damage.hasReturn === 'yes' ? returns.damage.erpDocumentNumber : null,
				damage_vendor_document_number: returns.damage.hasReturn === 'yes' ? returns.damage.vendorDocumentNumber : null
			};

			// Duplicate check
			if (!savedReceivingId) {
				const { data: existing, error: dupError } = await supabase
					.from('receiving_records')
					.select('id, bill_number, bill_amount, created_at')
					.eq('vendor_id', selectedVendor?.erp_vendor_id)
					.eq('branch_id', selectedBranch)
					.eq('bill_amount', parseFloat(billAmount))
					.eq('bill_number', billNumber.trim());
				if (dupError) throw dupError;
				if (existing && existing.length > 0) {
					showToast($currentLocale === 'ar' ? 'هذه الفاتورة مسجلة مسبقاً!' : 'This bill has already been recorded!', 'error');
					isSaving = false;
					return;
				}
			}

			if (savedReceivingId) {
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update(receivingData)
					.eq('id', savedReceivingId);
				if (updateError) throw updateError;
			} else {
				const { error: insertError } = await supabase
					.from('receiving_records')
					.insert([receivingData]);
				if (insertError) throw insertError;

				// Fetch ID
				const { data: fetched, error: fetchError } = await supabase
					.from('receiving_records')
					.select('id')
					.eq('user_id', $currentUser?.id)
					.eq('vendor_id', selectedVendor?.erp_vendor_id)
					.eq('bill_date', receivingData.bill_date)
					.eq('bill_amount', receivingData.bill_amount)
					.order('created_at', { ascending: false })
					.limit(1);
				if (!fetchError && fetched?.length) {
					savedReceivingId = fetched[0].id;
				}
			}

			// Check for vendor payment changes
			const paymentMethodChanged = paymentMethod && selectedVendor?.payment_method && paymentMethod !== selectedVendor.payment_method;
			const bankNameChanged = bankName && selectedVendor?.bank_name && bankName !== selectedVendor.bank_name;
			const ibanChanged = iban && selectedVendor?.iban && iban !== selectedVendor.iban;

			if (paymentMethodChanged || bankNameChanged || ibanChanged) {
				paymentUpdateMessage = $currentLocale === 'ar'
					? 'معلومات الدفع تختلف عن الإعدادات الافتراضية للمورد. هل تريد تحديث جدول الموردين؟'
					: 'Payment information differs from vendor defaults. Update vendor table?';
				showPaymentUpdateModal = true;
			} else {
				showToast(gt('receiving.receivingSaved'), 'success');
				currentStep = 3;
			}
		} catch (err: any) {
			showToast('Error: ' + err.message, 'error');
		} finally {
			isSaving = false;
		}
	}

	async function handlePaymentUpdateConfirm() {
		showPaymentUpdateModal = false;
		try {
			const updateData: any = {};
			if (paymentMethod !== selectedVendor?.payment_method) updateData.payment_method = paymentMethod;
			if (bankName !== selectedVendor?.bank_name) updateData.bank_name = bankName;
			if (iban !== selectedVendor?.iban) updateData.iban = iban;

			await supabase
				.from('vendors')
				.update(updateData)
				.eq('erp_vendor_id', selectedVendor.erp_vendor_id)
				.eq('branch_id', selectedBranch);

			showToast($currentLocale === 'ar' ? 'تم تحديث بيانات المورد' : 'Vendor payment updated', 'success');
		} catch (err: any) {
			console.error('Error updating vendor:', err);
		}
		showToast(gt('receiving.receivingSaved'), 'success');
		currentStep = 3;
	}

	function handlePaymentUpdateCancel() {
		showPaymentUpdateModal = false;
		showToast(gt('receiving.receivingSaved'), 'success');
		currentStep = 3;
	}

	function startNewReceiving() {
		// Reset everything
		currentStep = 0;
		branchConfirmed = false;
		selectedVendor = null;
		billDate = new Date().toISOString().split('T')[0];
		billAmount = '';
		billNumber = '';
		paymentMethod = '';
		creditPeriod = '';
		bankName = '';
		iban = '';
		paymentChanged = false;
		paymentMethodExplicitlySelected = false;
		vendorVatNumber = '';
		billVatNumber = '';
		vatMismatchReason = '';
		returns = {
			expired: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
			nearExpiry: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
			overStock: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
			damage: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' }
		};
		savedReceivingId = null;
		isSaving = false;
		selectedShelfStockers = [];
		billScanResults = null;
		showBillScanResults = false;
		billScanMatchedVendors = [];
		// Re-confirm branch if it was previously confirmed
		if (selectedBranch && branches.length > 0) {
			confirmBranchSelection();
		}
	}
</script>

<div class="mobile-receiving" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Toast notification -->
	{#if toastVisible}
		<div class="toast toast-{toastType}">{toastMessage}</div>
	{/if}

	<!-- Step Indicator -->
	<div class="step-indicator">
		{#each stepLabels as label, i}
			<div class="step" class:active={i === currentStep} class:completed={i < currentStep}>
				<div class="step-circle">{i < currentStep ? '✓' : i + 1}</div>
				<span class="step-label">{label}</span>
			</div>
			{#if i < stepLabels.length - 1}
				<div class="step-line" class:completed={i < currentStep}></div>
			{/if}
		{/each}
	</div>

	<!-- ============= STEP 1: Branch & Staff ============= -->
	{#if currentStep === 0}
		<div class="step-content">
			{#if !branchConfirmed}
				<div class="card">
					<h3 class="card-title">📍 {gt('receiving.chooseBranch')}</h3>
					{#if isLoading}
						<div class="loading-spinner">{gt('receiving.loadingBranches')}</div>
					{:else if errorMessage}
						<div class="error-msg">{errorMessage}</div>
					{:else}
						<select bind:value={selectedBranch} class="mobile-select">
							<option value="">{gt('receiving.selectBranch')}</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>
									{$currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}
									{$currentLocale === 'ar' ? (branch.location_ar || branch.location_en || '') : (branch.location_en || '')}
								</option>
							{/each}
						</select>

						{#if selectedBranch}
							<label class="checkbox-row">
								<input type="checkbox" bind:checked={setAsDefaultBranch} on:change={handleDefaultBranchToggle} />
								<span>{$currentLocale === 'ar' ? 'تعيين كفرع افتراضي' : 'Set as default branch'}</span>
							</label>
							<button class="btn btn-primary full-width" on:click={confirmBranchSelection}>
								{gt('receiving.confirmBranch')}
							</button>
						{/if}
					{/if}
				</div>
			{:else}
				<!-- Branch confirmed - show summary & staff -->
				<div class="card branch-summary">
					<div class="branch-header">
						<div>
							<strong>📍 {selectedBranchName}</strong>
							{#if selectedBranchLocation}
								<span class="branch-location">{selectedBranchLocation}</span>
							{/if}
						</div>
						<button class="btn btn-sm btn-outline" on:click={changeBranch}>{gt('receiving.change')}</button>
					</div>
				</div>

				<!-- Default Positions -->
				{#if defaultPositionsLoading}
					<div class="card">
						<div class="loading-spinner">{gt('receiving.loadingPositions')}</div>
					</div>
				{:else if defaultPositionsError}
					<div class="card">
						<div class="error-msg">{defaultPositionsError}</div>
					</div>
				{:else if defaultPositionsLoaded}
					<div class="card">
						<h3 class="card-title">👥 {$currentLocale === 'ar' ? 'الطاقم المعين' : 'Assigned Staff'}</h3>
						<div class="staff-grid">
							<div class="staff-chip" class:filled={selectedBranchManager}>
								<span class="chip-label">{gt('receiving.branchMgr')}</span>
								<span class="chip-value">{selectedBranchManager?.employeeName || gt('receiving.notAssigned')}</span>
							</div>
							<div class="staff-chip" class:filled={selectedPurchasingManager}>
								<span class="chip-label">{gt('receiving.purchasing')}</span>
								<span class="chip-value">{selectedPurchasingManager?.employeeName || gt('receiving.notAssigned')}</span>
							</div>
							<div class="staff-chip" class:filled={selectedInventoryManager}>
								<span class="chip-label">{gt('receiving.inventory')}</span>
								<span class="chip-value">{selectedInventoryManager?.employeeName || gt('receiving.notAssigned')}</span>
							</div>
							<div class="staff-chip" class:filled={selectedAccountant}>
								<span class="chip-label">{gt('receiving.accountant')}</span>
								<span class="chip-value">{selectedAccountant?.employeeName || gt('receiving.notAssigned')}</span>
							</div>
							<div class="staff-chip" class:filled={selectedNightSupervisors.length > 0}>
								<span class="chip-label">{gt('receiving.nightSup')}</span>
								<span class="chip-value">{selectedNightSupervisors.length > 0 ? selectedNightSupervisors.map(s => s.employeeName).join(', ') : gt('receiving.notAssigned')}</span>
							</div>
							<div class="staff-chip" class:filled={selectedWarehouseHandler}>
								<span class="chip-label">{gt('receiving.warehouse')}</span>
								<span class="chip-value">{selectedWarehouseHandler?.employeeName || gt('receiving.notAssigned')}</span>
							</div>
						</div>
					</div>

					<!-- Shelf Stocker Selection -->
					<div class="card">
						<h3 class="card-title">🛒 {gt('receiving.selectShelfStocker')}</h3>
						{#if selectedShelfStockers.length > 0}
							<div class="selected-chips">
								{#each selectedShelfStockers as stocker}
									<div class="selected-chip">
										<span>{stocker.employeeName}</span>
										<button class="chip-remove" on:click={() => removeShelfStocker(stocker.id)}>✕</button>
									</div>
								{/each}
							</div>
						{/if}

						<input
							type="text"
							class="mobile-input"
							placeholder={gt('receiving.searchStockerPlaceholder')}
							bind:value={shelfStockerSearchQuery}
						/>

						{#if shelfStockersLoading}
							<div class="loading-spinner">{gt('receiving.loadingShelfStockers')}</div>
						{:else}
							<div class="stocker-list">
								{#each filteredShelfStockers.filter(u => !selectedShelfStockers.find(s => s.id === u.id)) as user}
									<button class="stocker-item" on:click={() => addShelfStocker(user)}>
										<div class="stocker-info">
											<span class="stocker-name">{user.employeeName}</span>
											<span class="stocker-pos">{user.position || user.employeeId}</span>
										</div>
										<span class="add-icon">+</span>
									</button>
								{/each}
								{#if filteredShelfStockers.filter(u => !selectedShelfStockers.find(s => s.id === u.id)).length === 0}
									<div class="empty-msg">{gt('receiving.noUsersMatchSearch')}</div>
								{/if}
							</div>
						{/if}
					</div>
				{/if}

				<!-- Continue button -->
				{#if allRequiredUsersSelected}
					<button class="btn btn-primary full-width sticky-bottom-btn" on:click={() => currentStep = 1}>
						{gt('receiving.continueToStep2')}
					</button>
				{:else}
					<div class="card info-card">
						<span>⚠️ {gt('receiving.selectAllStaff')}</span>
					</div>
				{/if}
			{/if}
		</div>

	<!-- ============= STEP 2: Vendor Selection ============= -->
	{:else if currentStep === 1}
		<div class="step-content">
			{#if selectedVendor}
				<!-- Vendor already selected, show summary -->
				<div class="card vendor-summary">
					<div class="vendor-header">
						<div>
							<strong>{selectedVendor.vendor_name}</strong>
							<span class="vendor-detail">ID: {selectedVendor.erp_vendor_id}</span>
							{#if selectedVendor.salesman_name}
								<span class="vendor-detail">👤 {selectedVendor.salesman_name}</span>
							{/if}
						</div>
						<button class="btn btn-sm btn-outline" on:click={changeVendor}>{gt('receiving.changeVendor')}</button>
					</div>
				</div>
			{:else}
				<!-- Vendor search -->
				<div class="card">
					<button class="btn btn-sm btn-outline mb-2" on:click={() => currentStep = 0}>
						{gt('receiving.backToBranch')}
					</button>
					<div class="search-row">
						<input
							type="text"
							class="mobile-input flex-1"
							placeholder={gt('receiving.searchVendorPlaceholder')}
							bind:value={vendorSearchQuery}
							on:input={(e) => vendorSearchQuery = e.currentTarget.value}
						/>
						<button type="button" class="scan-bill-btn" on:click|preventDefault={startBillScan} title={$currentLocale === 'ar' ? 'مسح الفاتورة' : 'Scan Bill'}>
							<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
								<circle cx="12" cy="13" r="4"/>
							</svg>
						</button>
					</div>
					{#if vendorLoading}
						<div class="loading-spinner">{gt('receiving.loadingVendors')}</div>
					{:else if vendorError}
						<div class="error-msg">{vendorError}</div>
					{:else}
						<div class="vendor-count">
							{gt('receiving.showingVendors').replace('{shown}', filteredVendors.length.toString()).replace('{total}', vendors.length.toString())}
						</div>
						<div class="vendor-list">
							{#each filteredVendors as vendor}
								<button class="vendor-card" on:click={() => selectVendor(vendor)}>
									<div class="vendor-main">
										<span class="vendor-name">{vendor.vendor_name}</span>
										<span class="vendor-id">#{vendor.erp_vendor_id}</span>
									</div>
									<div class="vendor-meta">
										{#if vendor.salesman_name}
											<span>👤 {vendor.salesman_name}</span>
										{/if}
										{#if vendor.place}
											<span>📍 {vendor.place}</span>
										{/if}
										{#if vendor.payment_method}
											<span>💳 {vendor.payment_method}</span>
										{/if}
									</div>
								</button>
							{/each}
							{#if filteredVendors.length === 0}
								<div class="empty-msg">{gt('receiving.noVendorsMatch')}</div>
							{/if}
						</div>
					{/if}
				</div>
			{/if}
		</div>

	<!-- ============= STEP 3: Bill Information ============= -->
	{:else if currentStep === 2}
		<div class="step-content">
			<div class="card">
				<button class="btn btn-sm btn-outline mb-2" on:click={() => currentStep = 1}>
					{gt('receiving.back')}
				</button>

				<h3 class="card-title">📋 {gt('receiving.billInformation')} {selectedVendor?.vendor_name}</h3>

				<!-- Bill basics -->
				<div class="form-group">
					<label>{gt('receiving.billDate')}</label>
					<input type="date" class="mobile-input" bind:value={billDate} />
				</div>
				<div class="form-row">
					<div class="form-group flex-1">
						<label>{gt('receiving.amount')} (SAR)</label>
						<input type="number" class="mobile-input" bind:value={billAmount} placeholder="0.00" inputmode="decimal" />
					</div>
					<div class="form-group flex-1">
						<label>{gt('receiving.billNumber')}</label>
						<input type="text" class="mobile-input" bind:value={billNumber} placeholder={gt('receiving.billNumberPlaceholder')} />
					</div>
				</div>
			</div>

			<!-- Return Processing -->
			<div class="card">
				<h3 class="card-title">🔄 {gt('receiving.returnPolicy')}</h3>
				{#each [
					{ key: 'expired', label: gt('receiving.expiredLabel') },
					{ key: 'nearExpiry', label: gt('receiving.nearExpiryLabel') },
					{ key: 'overStock', label: gt('receiving.overStockLabel') },
					{ key: 'damage', label: gt('receiving.damageLabel') }
				] as returnType}
					<div class="return-row">
						<div class="return-header">
							<span class="return-label">{returnType.label}</span>
							<div class="toggle-group">
								<button
									class="toggle-btn"
									class:active={returns[returnType.key].hasReturn === 'yes'}
									on:click={() => { returns[returnType.key].hasReturn = 'yes'; returns = returns; }}
								>{gt('receiving.yes')}</button>
								<button
									class="toggle-btn"
									class:active={returns[returnType.key].hasReturn === 'no'}
									on:click={() => { returns[returnType.key].hasReturn = 'no'; returns[returnType.key].amount = ''; returns = returns; }}
								>{gt('receiving.no')}</button>
							</div>
						</div>
						{#if returns[returnType.key].hasReturn === 'yes'}
							<div class="return-details">
								<input type="number" class="mobile-input" placeholder={gt('receiving.amount')} bind:value={returns[returnType.key].amount} inputmode="decimal" />
								<div class="form-row mt-1">
									<select class="mobile-select flex-1" bind:value={returns[returnType.key].erpDocumentType}>
										<option value="">{gt('receiving.erpDocType')}</option>
										<option value="GRR">{gt('receiving.grr')}</option>
										<option value="PRI">{gt('receiving.pri')}</option>
									</select>
									<input type="text" class="mobile-input flex-1" placeholder={gt('receiving.erpDocNumber')} bind:value={returns[returnType.key].erpDocumentNumber} />
								</div>
								<input type="text" class="mobile-input mt-1" placeholder={gt('receiving.vendorDocNumber')} bind:value={returns[returnType.key].vendorDocumentNumber} />
							</div>
						{/if}
					</div>
				{/each}

				<!-- Summary -->
				{#if totalReturnAmount > 0}
					<div class="bill-summary">
						<div class="summary-row">
							<span>{gt('receiving.bill')}</span>
							<span>SAR {parseFloat(billAmount || '0').toFixed(2)}</span>
						</div>
						<div class="summary-row returns-row">
							<span>{gt('receiving.returns')}</span>
							<span>-SAR {totalReturnAmount.toFixed(2)}</span>
						</div>
						<div class="summary-row final-row">
							<span>{gt('receiving.final')}</span>
							<span>SAR {finalBillAmount.toFixed(2)}</span>
						</div>
					</div>
				{/if}
			</div>

			<!-- Payment -->
			<div class="card">
				<h3 class="card-title">💳 {gt('receiving.payment')}</h3>
				<!-- DEBUG: remove after testing -->
				<div style="font-size:0.65rem; color:#94a3b8; background:#1e293b; padding:0.3rem; border-radius:0.3rem; margin-bottom:0.5rem; word-break:break-all;">
					PM: "{paymentMethod}" | CP: "{creditPeriod}" | DB_PM: "{selectedVendor?.payment_method}" | DB_CP: "{selectedVendor?.credit_period}"
				</div>
				<div class="form-group">
					<label>{gt('receiving.method')}</label>
					<div class="payment-grid">
						{#each [
							{ value: 'Cash on Delivery', label: gt('receiving.cashOnDelivery') },
							{ value: 'Bank on Delivery', label: gt('receiving.bankOnDelivery') },
							{ value: 'Cash Credit', label: gt('receiving.cashCredit') },
							{ value: 'Bank Credit', label: gt('receiving.bankCredit') }
						] as pm}
							<button
								class="payment-btn"
								class:active={paymentMethod === pm.value}
								on:click={() => { paymentMethod = pm.value; handlePaymentMethodChange(); }}
							>{pm.label}</button>
						{/each}
					</div>
				</div>

				{#if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
					<div class="form-group">
						<label>{gt('receiving.creditDays')}</label>
						<input type="number" class="mobile-input" bind:value={creditPeriod} placeholder={gt('receiving.daysPlaceholder')} inputmode="numeric" />
					</div>
				{/if}

				{#if paymentMethod === 'Bank on Delivery' || paymentMethod === 'Bank Credit'}
					<div class="form-row">
						<div class="form-group flex-1">
							<label>{gt('receiving.bank')}</label>
							<input type="text" class="mobile-input" bind:value={bankName} placeholder={gt('receiving.bankNamePlaceholder')} />
						</div>
						<div class="form-group flex-1">
							<label>{gt('receiving.ibanLabel')}</label>
							<input type="text" class="mobile-input" bind:value={iban} placeholder={gt('receiving.ibanPlaceholder')} />
						</div>
					</div>
				{/if}

				<!-- Due Date -->
				{#if dueDate}
					<div class="due-date-display">
						<span class="due-label">{gt('receiving.dueDate')}:</span>
						<span class="due-value">{dueDate}</span>
					</div>
				{/if}
			</div>

			<!-- VAT Verification -->
			{#if selectedVendor?.vat_applicable === 'VAT Applicable'}
				<div class="card">
					<h3 class="card-title">🔍 {gt('receiving.vatVerification')}</h3>
					<div class="form-group">
						<label>{gt('receiving.vendorVat')}</label>
						<div class="vat-display">{vendorVatNumber ? maskVatNumber(vendorVatNumber) : gt('receiving.noVatOnFile')}</div>
					</div>
					<div class="form-group">
						<label>{gt('receiving.billVat')}</label>
						<input type="text" class="mobile-input" bind:value={billVatNumber} placeholder={gt('receiving.vatFromBill')} />
					</div>
					{#if billVatNumber}
						{#if vatNumbersMatch}
							<div class="vat-status match">✅ {gt('receiving.vatMatch')}</div>
						{:else}
							<div class="vat-status mismatch">⚠️ {gt('receiving.vatMismatch')}</div>
							<div class="form-group">
								<label>{gt('receiving.reason')}</label>
								<textarea class="mobile-input" bind:value={vatMismatchReason} placeholder={gt('receiving.vatMismatchPlaceholder')} rows="2"></textarea>
							</div>
						{/if}
					{/if}
				</div>
			{/if}

			<!-- Save Button -->
			<button
				class="btn btn-primary full-width sticky-bottom-btn"
				on:click={saveReceivingData}
				disabled={isSaving || !billDate || !billAmount || !billNumber?.trim() || !paymentMethodExplicitlySelected || !dueDateReady}
			>
				{#if isSaving}
					{$currentLocale === 'ar' ? 'جاري الحفظ...' : 'Saving...'}
				{:else}
					{gt('receiving.saveContinueCert')}
				{/if}
			</button>
		</div>

	<!-- ============= STEP 4: Finalization ============= -->
	{:else if currentStep === 3}
		<div class="step-content">
			<div class="card success-card">
				<div class="success-icon">✅</div>
				<h3>{$currentLocale === 'ar' ? 'تم حفظ الاستلام بنجاح!' : 'Receiving Saved Successfully!'}</h3>
				<div class="success-details">
					<div class="detail-row">
						<span>{gt('receiving.vendorName')}:</span>
						<strong>{selectedVendor?.vendor_name}</strong>
					</div>
					<div class="detail-row">
						<span>{gt('receiving.billNumber')}:</span>
						<strong>{billNumber}</strong>
					</div>
					<div class="detail-row">
						<span>{gt('receiving.amount')}:</span>
						<strong>SAR {parseFloat(billAmount || '0').toFixed(2)}</strong>
					</div>
					{#if totalReturnAmount > 0}
						<div class="detail-row">
							<span>{gt('receiving.returns')}:</span>
							<strong>-SAR {totalReturnAmount.toFixed(2)}</strong>
						</div>
						<div class="detail-row final">
							<span>{gt('receiving.final')}:</span>
							<strong>SAR {finalBillAmount.toFixed(2)}</strong>
						</div>
					{/if}
					<div class="detail-row">
						<span>{gt('receiving.paymentMethod')}:</span>
						<strong>{paymentMethod}</strong>
					</div>
					<div class="detail-row">
						<span>{gt('receiving.dueDate')}:</span>
						<strong>{dueDate}</strong>
					</div>
					{#if savedReceivingId}
						<div class="detail-row">
							<span>ID:</span>
							<strong>#{savedReceivingId}</strong>
						</div>
					{/if}
				</div>

				<button class="btn btn-primary full-width mt-3" on:click={startNewReceiving}>
					{$currentLocale === 'ar' ? '➕ بدء استلام جديد' : '➕ Start New Receiving'}
				</button>
			</div>
		</div>
	{/if}

	<!-- ====== Vendor Update Popup ====== -->
	{#if showVendorUpdatePopup}
		<div class="modal-overlay" on:click={closeVendorUpdatePopup}>
			<div class="modal-content" on:click|stopPropagation>
				<h3>{gt('receiving.updateVendorInfo')}</h3>
				<p class="modal-desc">{gt('receiving.vendorMissingInfo')}</p>
				<div class="form-group">
					<label>{gt('receiving.salesmanName')}</label>
					<input type="text" class="mobile-input" bind:value={updatedSalesmanName} />
				</div>
				<div class="form-group">
					<label>{gt('receiving.salesmanContact')}</label>
					<input type="tel" class="mobile-input" bind:value={updatedSalesmanContact} />
				</div>
				<div class="form-group">
					<label>{gt('receiving.vatNumber')} *</label>
					<input type="text" class="mobile-input" bind:value={updatedVatNumber} />
				</div>
				<div class="modal-actions">
					<button class="btn btn-outline" on:click={closeVendorUpdatePopup}>{gt('mobile.cancel')}</button>
					<button class="btn btn-primary" on:click={updateVendorInformation} disabled={isUpdatingVendor}>
						{isUpdatingVendor ? '...' : ($currentLocale === 'ar' ? 'تحديث والمتابعة' : 'Update & Continue')}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- ====== Payment Update Modal ====== -->
	{#if showPaymentUpdateModal}
		<div class="modal-overlay" on:click={handlePaymentUpdateCancel}>
			<div class="modal-content" on:click|stopPropagation>
				<h3>{$currentLocale === 'ar' ? 'تحديث بيانات الدفع' : 'Update Payment Info'}</h3>
				<p class="modal-desc">{paymentUpdateMessage}</p>
				<div class="modal-actions">
					<button class="btn btn-outline" on:click={handlePaymentUpdateCancel}>
						{$currentLocale === 'ar' ? 'لا، الاستلام فقط' : 'No, receiving only'}
					</button>
					<button class="btn btn-primary" on:click={handlePaymentUpdateConfirm}>
						{$currentLocale === 'ar' ? 'نعم، تحديث المورد' : 'Yes, update vendor'}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- ====== Hidden Bill Scanner File Input ====== -->
	<input
		type="file"
		accept="image/*"
		capture="environment"
		bind:this={billFileInput}
		on:change={handleBillFileSelected}
		style="display:none"
	/>

	<!-- ====== Bill Scan Results Modal ====== -->
	{#if showBillScanResults}
		<div class="modal-overlay" on:click={closeBillScanResults}>
			<div class="modal-content scan-results-modal" on:click|stopPropagation>
				<h3>📋 {$currentLocale === 'ar' ? 'نتائج مسح الفاتورة' : 'Bill Scan Results'}</h3>

				{#if billScanParsing}
					<div class="scan-parsing">
						<span class="scan-spinner"></span>
						<span>{$currentLocale === 'ar' ? 'جاري تحليل الفاتورة...' : 'Analyzing bill...'}</span>
					</div>
				{:else if billScanResults}
					<!-- Extracted data -->
					<div class="scan-data-card">
						{#if billScanResults.companyName}
							<div class="scan-data-row">
								<span class="scan-data-label">🏢 {$currentLocale === 'ar' ? 'اسم الشركة' : 'Company'}</span>
								<span class="scan-data-value">{billScanResults.companyName}</span>
							</div>
						{/if}
						{#if billScanResults.vatNumber}
							<div class="scan-data-row">
								<span class="scan-data-label">🔢 {$currentLocale === 'ar' ? 'الرقم الضريبي' : 'VAT Number'}</span>
								<span class="scan-data-value mono">{billScanResults.vatNumber}</span>
							</div>
						{/if}
						{#if billScanResults.billDate}
							<div class="scan-data-row">
								<span class="scan-data-label">📅 {$currentLocale === 'ar' ? 'تاريخ الفاتورة' : 'Bill Date'}</span>
								<span class="scan-data-value">{billScanResults.billDate}</span>
							</div>
						{/if}
						{#if billScanResults.totalAmount}
							<div class="scan-data-row">
								<span class="scan-data-label">💰 {$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</span>
								<span class="scan-data-value">SAR {billScanResults.totalAmount}</span>
							</div>
						{/if}
						{#if billScanResults.billNumber}
							<div class="scan-data-row">
								<span class="scan-data-label">🧾 {$currentLocale === 'ar' ? 'رقم الفاتورة' : 'Bill Number'}</span>
								<span class="scan-data-value">{billScanResults.billNumber}</span>
							</div>
						{/if}
						{#if !billScanResults.companyName && !billScanResults.vatNumber && !billScanResults.billDate && !billScanResults.totalAmount && !billScanResults.billNumber}
							<div class="scan-data-row">
								<span class="scan-data-label">{$currentLocale === 'ar' ? 'لم يتم استخراج بيانات' : 'No data extracted'}</span>
							</div>
						{/if}
					</div>

					<!-- All vendors ranked by match score -->
					{#if billScanMatchedVendors.length > 0}
						<h4 class="scan-section-title">{$currentLocale === 'ar' ? '🎯 اختر المورد' : '🎯 Select Vendor'}</h4>
						<input
							type="text"
							class="mobile-input scan-vendor-search"
							placeholder={$currentLocale === 'ar' ? '🔍 ابحث عن مورد...' : '🔍 Search vendor...'}
							bind:value={scanVendorSearch}
						/>
						<div class="scan-vendor-list">
							{#each filteredScanVendors as vendor}
								<button class="vendor-card" on:click={() => selectScannedVendor(vendor)}>
									<div class="vendor-main">
										<span class="vendor-name">{vendor.vendor_name}</span>
										<span class="vendor-id">#{vendor.erp_vendor_id}</span>
									</div>
									<div class="vendor-meta">
										{#if vendor._matchScore >= 100}
											<span class="match-badge vat-match">✓ {$currentLocale === 'ar' ? 'تطابق ض.ق.م' : 'VAT Match'}</span>
										{:else if vendor._matchScore >= 10}
											<span class="match-badge name-match">≈ {$currentLocale === 'ar' ? 'تطابق الاسم' : 'Name Match'}</span>
										{/if}
										{#if vendor.salesman_name}
											<span>👤 {vendor.salesman_name}</span>
										{/if}
									</div>
								</button>
							{/each}
						</div>
					{:else}
						<div class="scan-no-match">
							<span>🔍 {$currentLocale === 'ar' ? 'لا يوجد موردون. ابحث يدوياً.' : 'No vendors loaded. Search manually.'}</span>
						</div>
					{/if}

					<div class="modal-actions">
						<button class="btn btn-outline full-width" on:click={closeBillScanResults}>
							{$currentLocale === 'ar' ? 'بحث يدوي' : 'Search Manually'}
						</button>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.mobile-receiving {
		padding: 0.75rem;
		padding-bottom: 5rem;
		min-height: 100%;
		background: #F8FAFC;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	/* Toast */
	.toast {
		position: fixed;
		top: 3.5rem;
		left: 50%;
		transform: translateX(-50%);
		z-index: 9999;
		padding: 0.6rem 1.25rem;
		border-radius: 0.5rem;
		font-size: 0.8rem;
		font-weight: 500;
		color: #fff;
		animation: slideDown 0.3s ease;
		max-width: 90%;
		text-align: center;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}
	.toast-success { background: #10B981; }
	.toast-error { background: #EF4444; }
	.toast-info { background: #3B82F6; }

	@keyframes slideDown {
		from { opacity: 0; transform: translateX(-50%) translateY(-20px); }
		to { opacity: 1; transform: translateX(-50%) translateY(0); }
	}

	/* Step Indicator */
	.step-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		padding: 0.75rem 0.25rem;
		margin-bottom: 0.5rem;
		overflow-x: auto;
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
	}
	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
		min-width: 3.75rem;
	}
	.step-circle {
		width: 1.75rem;
		height: 1.75rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.7rem;
		font-weight: 700;
		background: #E5E7EB;
		color: #9CA3AF;
		border: 2px solid #D1D5DB;
		transition: all 0.3s ease;
	}
	.step.active .step-circle {
		background: #3B82F6;
		color: #fff;
		border-color: #3B82F6;
		box-shadow: 0 0 8px rgba(59, 130, 246, 0.3);
	}
	.step.completed .step-circle {
		background: #10B981;
		color: #fff;
		border-color: #10B981;
	}
	.step-label {
		font-size: 0.6rem;
		color: #9CA3AF;
		text-align: center;
		line-height: 1.2;
	}
	.step.active .step-label { color: #3B82F6; font-weight: 600; }
	.step.completed .step-label { color: #10B981; }
	.step-line {
		flex: 1;
		height: 2px;
		background: #E5E7EB;
		margin-bottom: 1.125rem;
		min-width: 0.75rem;
	}
	.step-line.completed { background: #10B981; }

	/* Cards */
	.card {
		background: white;
		border-radius: 0.75rem;
		padding: 1rem;
		margin-bottom: 0.75rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
		border: 1px solid #E5E7EB;
	}
	.card-title {
		font-size: 0.9rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.75rem 0;
	}

	/* Branch */
	.branch-summary { padding: 0.75rem 1rem; }
	.branch-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.5rem;
	}
	.branch-header strong { color: #111827; font-size: 0.85rem; }
	.branch-location { display: block; color: #6B7280; font-size: 0.75rem; margin-top: 0.125rem; }

	/* Staff grid */
	.staff-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
	}
	.staff-chip {
		background: #F9FAFB;
		border-radius: 0.5rem;
		padding: 0.5rem 0.625rem;
		border: 1px solid #E5E7EB;
	}
	.staff-chip.filled {
		border-color: #10B981;
		background: #ECFDF5;
	}
	.chip-label {
		display: block;
		font-size: 0.6rem;
		color: #6B7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 0.125rem;
	}
	.chip-value {
		display: block;
		font-size: 0.75rem;
		color: #111827;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* Selected chips */
	.selected-chips {
		display: flex;
		flex-wrap: wrap;
		gap: 0.375rem;
		margin-bottom: 0.625rem;
	}
	.selected-chip {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		background: #EFF6FF;
		border: 1px solid #BFDBFE;
		border-radius: 1.25rem;
		padding: 0.25rem 0.625rem;
		font-size: 0.75rem;
		color: #1D4ED8;
	}
	.chip-remove {
		background: none;
		border: none;
		color: #EF4444;
		cursor: pointer;
		font-size: 0.85rem;
		padding: 0;
		line-height: 1;
	}

	/* Stocker list */
	.stocker-list {
		max-height: 15.625rem;
		overflow-y: auto;
		border-radius: 0.5rem;
		margin-top: 0.5rem;
		border: 1px solid #E5E7EB;
	}
	.stocker-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		padding: 0.625rem 0.75rem;
		background: white;
		border: none;
		border-bottom: 1px solid #F3F4F6;
		color: #111827;
		cursor: pointer;
		text-align: start;
	}
	.stocker-item:last-child { border-bottom: none; }
	.stocker-item:active { background: #F3F4F6; }
	.stocker-info { display: flex; flex-direction: column; gap: 0.125rem; }
	.stocker-name { font-size: 0.8rem; font-weight: 500; color: #111827; }
	.stocker-pos { font-size: 0.7rem; color: #6B7280; }
	.add-icon {
		font-size: 1.25rem;
		color: #3B82F6;
		font-weight: 700;
	}

	/* Vendor list */
	.vendor-count {
		font-size: 0.7rem;
		color: #6B7280;
		margin: 0.375rem 0;
	}
	.vendor-list {
		max-height: 55vh;
		overflow-y: auto;
	}
	.vendor-card {
		display: block;
		width: 100%;
		padding: 0.75rem;
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 0.625rem;
		margin-bottom: 0.5rem;
		cursor: pointer;
		text-align: start;
		color: #111827;
		transition: border-color 0.2s;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
	}
	.vendor-card:active { border-color: #3B82F6; background: #F0F9FF; }
	.vendor-main {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.375rem;
	}
	.vendor-name { font-size: 0.85rem; font-weight: 600; color: #111827; }
	.vendor-id { font-size: 0.7rem; color: #9CA3AF; }
	.vendor-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		font-size: 0.7rem;
		color: #6B7280;
	}
	.vendor-summary { padding: 0.75rem 1rem; }
	.vendor-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.5rem;
	}
	.vendor-header strong { color: #111827; font-size: 0.85rem; }
	.vendor-detail { display: block; font-size: 0.75rem; color: #6B7280; margin-top: 0.125rem; }

	/* Form */
	.form-group {
		margin-bottom: 0.75rem;
	}
	.form-group label {
		display: block;
		font-size: 0.75rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.25rem;
	}
	.form-row {
		display: flex;
		gap: 0.5rem;
	}
	.flex-1 { flex: 1; }
	.mt-1 { margin-top: 0.375rem; }
	.mt-3 { margin-top: 1rem; }
	.mb-2 { margin-bottom: 0.5rem; }

	.mobile-input, .mobile-select {
		width: 100%;
		padding: 0.6rem 0.75rem;
		background: white;
		border: 1px solid #D1D5DB;
		border-radius: 0.5rem;
		color: #111827;
		font-size: 0.85rem;
		outline: none;
		-webkit-appearance: none;
		appearance: none;
		box-sizing: border-box;
	}
	.mobile-input:focus, .mobile-select:focus {
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.15);
	}
	.mobile-input::placeholder { color: #9CA3AF; }
	.mobile-select {
		padding-right: 1.875rem;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='%236B7280' viewBox='0 0 16 16'%3E%3Cpath d='M8 11L3 6h10z'/%3E%3C/svg%3E");
		background-repeat: no-repeat;
		background-position: right 0.625rem center;
	}
	textarea.mobile-input {
		resize: vertical;
		min-height: 3.125rem;
	}

	/* Buttons */
	.btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.375rem;
		padding: 0.6rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		border: none;
		transition: all 0.2s;
	}
	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.btn-primary {
		background: #007bff;
		color: #fff;
	}
	.btn-primary:active:not(:disabled) { background: #0069d9; }
	.btn-outline {
		background: transparent;
		color: #6B7280;
		border: 1px solid #D1D5DB;
	}
	.btn-outline:active { background: #F3F4F6; }
	.btn-sm {
		padding: 0.375rem 0.75rem;
		font-size: 0.75rem;
	}
	.full-width { width: 100%; }

	.sticky-bottom-btn {
		position: sticky;
		bottom: 0;
		z-index: 10;
		margin-top: 0.5rem;
		box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.08);
	}

	/* Return rows */
	.return-row {
		padding: 0.625rem 0;
		border-bottom: 1px solid #F3F4F6;
	}
	.return-row:last-child { border-bottom: none; }
	.return-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	.return-label {
		font-size: 0.8rem;
		color: #374151;
		font-weight: 500;
	}
	.toggle-group {
		display: flex;
		gap: 0.25rem;
	}
	.toggle-btn {
		padding: 0.25rem 0.75rem;
		border-radius: 0.375rem;
		border: 1px solid #D1D5DB;
		background: white;
		color: #6B7280;
		font-size: 0.75rem;
		cursor: pointer;
		font-weight: 500;
	}
	.toggle-btn.active {
		background: #3B82F6;
		color: #fff;
		border-color: #3B82F6;
	}
	.return-details {
		margin-top: 0.5rem;
		padding: 0.5rem;
		background: #F9FAFB;
		border-radius: 0.5rem;
		border: 1px solid #E5E7EB;
	}

	/* Bill summary */
	.bill-summary {
		margin-top: 0.75rem;
		padding: 0.625rem 0.75rem;
		background: #F9FAFB;
		border-radius: 0.5rem;
		border: 1px solid #E5E7EB;
	}
	.summary-row {
		display: flex;
		justify-content: space-between;
		padding: 0.25rem 0;
		font-size: 0.8rem;
		color: #6B7280;
	}
	.returns-row { color: #EF4444; }
	.final-row {
		color: #059669;
		font-weight: 700;
		font-size: 0.85rem;
		border-top: 1px solid #E5E7EB;
		margin-top: 0.25rem;
		padding-top: 0.375rem;
	}

	/* Payment grid */
	.payment-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.375rem;
	}
	.payment-btn {
		padding: 0.625rem 0.5rem;
		border-radius: 0.5rem;
		border: 1px solid #D1D5DB;
		background: white;
		color: #6B7280;
		font-size: 0.75rem;
		cursor: pointer;
		text-align: center;
		font-weight: 500;
		transition: all 0.2s;
	}
	.payment-btn.active {
		background: #EFF6FF;
		color: #1D4ED8;
		border-color: #3B82F6;
	}
	.payment-btn:active { background: #F3F4F6; }

	/* Due date */
	.due-date-display {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.625rem 0.75rem;
		background: #ECFDF5;
		border: 1px solid #A7F3D0;
		border-radius: 0.5rem;
		margin-top: 0.5rem;
	}
	.due-label { font-size: 0.8rem; color: #374151; }
	.due-value { font-size: 0.85rem; color: #059669; font-weight: 600; }

	/* VAT */
	.vat-display {
		padding: 0.625rem 0.75rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 0.5rem;
		font-size: 0.85rem;
		color: #374151;
		font-family: monospace;
		letter-spacing: 1px;
	}
	.vat-status {
		padding: 0.5rem 0.75rem;
		border-radius: 0.5rem;
		font-size: 0.8rem;
		font-weight: 500;
		margin-bottom: 0.5rem;
	}
	.vat-status.match {
		background: #ECFDF5;
		color: #059669;
	}
	.vat-status.mismatch {
		background: #FEF2F2;
		color: #DC2626;
	}

	/* Success card (Step 4) */
	.success-card {
		text-align: center;
		padding: 1.5rem 1rem;
	}
	.success-icon {
		font-size: 3rem;
		margin-bottom: 0.75rem;
	}
	.success-card h3 {
		color: #059669;
		font-size: 1.1rem;
		margin: 0 0 1rem;
	}
	.success-details {
		text-align: start;
		background: #F9FAFB;
		border-radius: 0.625rem;
		padding: 0.75rem;
		border: 1px solid #E5E7EB;
	}
	.detail-row {
		display: flex;
		justify-content: space-between;
		padding: 0.375rem 0;
		font-size: 0.8rem;
		color: #6B7280;
		border-bottom: 1px solid #F3F4F6;
	}
	.detail-row:last-child { border-bottom: none; }
	.detail-row strong { color: #111827; }
	.detail-row.final strong { color: #059669; }

	/* Modals */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 100;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.modal-content {
		background: white;
		border-radius: 1rem;
		padding: 1.25rem;
		width: 100%;
		max-width: 25rem;
		max-height: 80vh;
		overflow-y: auto;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
	}
	.modal-content h3 {
		color: #111827;
		font-size: 1rem;
		margin: 0 0 0.5rem;
	}
	.modal-desc {
		color: #6B7280;
		font-size: 0.8rem;
		margin-bottom: 1rem;
		line-height: 1.5;
	}
	.modal-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 1rem;
	}
	.modal-actions .btn { flex: 1; }

	/* Utility */
	.loading-spinner {
		text-align: center;
		padding: 1.25rem;
		color: #6B7280;
		font-size: 0.8rem;
	}
	.error-msg {
		color: #DC2626;
		font-size: 0.8rem;
		padding: 0.5rem 0.75rem;
		background: #FEF2F2;
		border-radius: 0.5rem;
		border: 1px solid #FECACA;
	}
	.empty-msg {
		text-align: center;
		padding: 1.25rem;
		color: #9CA3AF;
		font-size: 0.8rem;
	}
	.info-card {
		background: #FFFBEB;
		border-color: #FDE68A;
		color: #92400E;
		font-size: 0.8rem;
		text-align: center;
	}
	.checkbox-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.625rem 0;
		color: #374151;
		font-size: 0.8rem;
		cursor: pointer;
	}
	.checkbox-row input[type="checkbox"] {
		accent-color: #3B82F6;
		width: 1.125rem;
		height: 1.125rem;
	}

	.step-content {
		animation: fadeIn 0.25s ease;
	}

	@keyframes fadeIn {
		from { opacity: 0; transform: translateY(0.5rem); }
		to { opacity: 1; transform: translateY(0); }
	}

	/* Search row with scan button */
	.search-row {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.scan-bill-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2.75rem;
		height: 2.75rem;
		border-radius: 0.5rem;
		border: 1px solid #3B82F6;
		background: #EFF6FF;
		color: #3B82F6;
		cursor: pointer;
		flex-shrink: 0;
		transition: all 0.2s;
	}
	.scan-bill-btn:active {
		background: #DBEAFE;
		transform: scale(0.95);
	}

	/* Spinner */
	.scan-spinner {
		display: inline-block;
		width: 1rem;
		height: 1rem;
		border: 2px solid rgba(147, 197, 253, 0.3);
		border-top-color: #93C5FD;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Scan results modal */
	.scan-results-modal {
		max-width: 22rem;
	}
	.scan-parsing {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 2rem 1rem;
		color: #6B7280;
		font-size: 0.85rem;
	}
	.scan-parsing .scan-spinner {
		border-color: rgba(107, 114, 128, 0.3);
		border-top-color: #3B82F6;
	}
	.scan-data-card {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 0.625rem;
		padding: 0.75rem;
		margin-bottom: 0.75rem;
	}
	.scan-data-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.375rem 0;
		border-bottom: 1px solid #DCFCE7;
	}
	.scan-data-row:last-child { border-bottom: none; }
	.scan-data-label {
		font-size: 0.75rem;
		color: #374151;
		font-weight: 500;
	}
	.scan-data-value {
		font-size: 0.8rem;
		color: #111827;
		font-weight: 600;
		text-align: end;
		max-width: 60%;
		word-break: break-word;
	}
	.scan-data-value.mono {
		font-family: monospace;
		letter-spacing: 0.5px;
	}
	.scan-section-title {
		font-size: 0.85rem;
		color: #111827;
		margin: 0.5rem 0;
		font-weight: 600;
	}
	.scan-vendor-search {
		margin-bottom: 0.5rem;
		font-size: 0.85rem;
	}
	.scan-vendor-list {
		max-height: 35vh;
		overflow-y: auto;
	}
	.match-badge {
		display: inline-block;
		padding: 0.125rem 0.5rem;
		border-radius: 1rem;
		font-size: 0.65rem;
		font-weight: 600;
	}
	.match-badge.vat-match {
		background: #ECFDF5;
		color: #059669;
		border: 1px solid #A7F3D0;
	}
	.match-badge.name-match {
		background: #EFF6FF;
		color: #2563EB;
		border: 1px solid #BFDBFE;
	}
	.scan-no-match {
		text-align: center;
		padding: 1rem;
		color: #9CA3AF;
		font-size: 0.8rem;
		background: #F9FAFB;
		border-radius: 0.5rem;
		border: 1px solid #E5E7EB;
		margin-bottom: 0.75rem;
	}
</style>
