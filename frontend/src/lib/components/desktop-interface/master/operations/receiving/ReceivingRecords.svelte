<script>
	import { onMount } from 'svelte';
	import { _ as t, t as tFn, currentLocale } from '$lib/i18n';
	import { compressImage } from '$lib/utils/imageCompression';
	import XLSX from 'xlsx-js-style';
	import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';
	import ManualScheduling from '$lib/components/desktop-interface/master/finance/ManualScheduling.svelte';
	import PriceVerifier from './PriceVerifier.svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { realtimeService } from '$lib/utils/realtimeService';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ReceivingRecordsPermissionsModal from './ReceivingRecordsPermissionsModal.svelte';

	// State for receiving records
	let receivingRecords = []; // Current page records
	let allLoadedRecords = []; // All records loaded so far (accumulates as user scrolls)
	let paginatedRecords = [];
	let archivedRecords = [];
	let branches = [];
	let loading = false;
	let uploadingBillId = null;
	// AI "Check" on the Original Bill document — the AI extracts the document's
	// values and also judges whether each matches the record. Pressing "Done" in
	// the popup persists the verdict to receiving_records.original_bill_check_result
	// (mirrors the erp_check_result pattern below), which then drives the
	// Matched/Recheck status shown in the Original Bill cell.
	let checkingBillId = null;
	let showBillCheckModal = false;
	let billCheckResult = null;
	let billCheckRecord = null;
	let savingBillCheck = false;
	let originalBillCheckStatus = {}; // record.id -> 'matched' | 'mismatch'
	let originalBillCheckResult = {}; // record.id -> persisted payload
	let manualVerified = false; // "Manual Verification" checkbox in the Unmatched section
	let uploadingExcelId = null;
	let generatingCertificateId = null;
	let updatingBillId = null;
	let deletingRecordId = null;
	let showArchived = false; // Toggle for archived records
	let selectedBranchFilter = ''; // Filter by branch
	let selectedPrExcelFilter = ''; // Filter by PR Excel verification ('' = all, 'verified', 'unverified')
	let vendorSearchTerm = ''; // Search by vendor name
	let selectedErpRefFilter = ''; // Filter by ERP invoice reference ('' = all, 'entered', 'not_entered')
	let erpReferenceSearchTerm = ''; // Search by ERP invoice reference number
	let erpCheckStatusFilter = ''; // '' | 'mismatch' | 'not_found' — filters rows by their persisted erp_check_result.status
	let erpMismatchCount = 0;
	let erpNotFoundCount = 0;
	let billDateFilterMode = ''; // '' = any date, 'specific' = one date, 'period' = date range
	let billDateFrom = '';
	let billDateTo = '';
	let selectedDueFilter = ''; // Filter by due date ('' = all, '7', '15', '30')

	// Pagination state (disabled UI but optimized loading)
	let currentPage = 1;
	let pageSize = 500; // Load 500 records at once via RPC
	let totalPages = 1;
	let totalRecords = 0;

	// Real-time subscription unsubscribe functions
	let unsubscribeReceivingRecords = null;
	let unsubscribePaymentSchedule = null;

	// Check if current user is master admin
	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	// Certificate generation state
	let showCertificateModal = false;
	let selectedRecordForCertificate = null;

	// ERP Reference popup state
	let showErpPopup = false;
	let selectedRecord = null;
	let erpReferenceValue = '';
	let updatingErp = false;

	// Live ERP existence check (Purchase Invoice lookup via branch tunnel)
	let erpConnections = []; // erp_connections rows: branch_id, tunnel_url, erp_branch_id
	let erpCheckStatus = {}; // record.id -> 'checking' | 'found' | 'not_found' | 'error'
	let erpCheckResult = {}; // record.id -> { grandTotal, partyName, transactionDate } | { error }

	// Button permissions (gates editing an already-entered ERP number — same access as the
	// Vendor Records window, mirroring the isButtonAllowed pattern used in Sidebar.svelte/Taskbar.svelte)
	let allowedButtonCodes = new Set();
	let buttonPermissionsLoaded = false;

	async function loadButtonPermissions() {
		if (!$currentUser?.id) {
			allowedButtonCodes = new Set();
			buttonPermissionsLoaded = false;
			return;
		}
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_code')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true);
			if (error) throw error;
			allowedButtonCodes = new Set((permissions || []).map((p) => p.button_code));
			buttonPermissionsLoaded = true;
		} catch (err) {
			console.error('Error loading button permissions:', err);
			allowedButtonCodes = new Set();
			buttonPermissionsLoaded = true;
		}
	}

	function isButtonAllowed(buttonCode) {
		if (!buttonPermissionsLoaded) return false;
		if ($currentUser?.isMasterAdmin) return true;
		return allowedButtonCodes.has(buttonCode);
	}

	$: if ($currentUser) {
		loadButtonPermissions();
	}
	// Referencing the args directly (not just calling isButtonAllowed) so Svelte's reactive
	// dependency tracking actually re-runs this once the async permission load resolves.
	$: canEditErpReference = buttonPermissionsLoaded && ($currentUser?.isMasterAdmin || allowedButtonCodes.has('VENDOR_RECORDS') || !!receivingPermRow?.can_edit_erp_reference);

	// Per-user grants for the Edit/Delete buttons in the Actions column, from the
	// dedicated receiving_records_permissions table (managed via the "Edit
	// Permission" popup, Master Admin only). Master Admin always bypasses this.
	let receivingPermRow = null;
	let showPermissionsModal = false;

	async function loadReceivingRecordsPermission() {
		if (!$currentUser?.id) {
			receivingPermRow = null;
			return;
		}
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('receiving_records_permissions')
				.select('can_edit_erp_reference, can_edit_record, can_delete')
				.eq('user_id', $currentUser.id)
				.maybeSingle();
			if (error) throw error;
			receivingPermRow = data || null;
		} catch (err) {
			console.error('Error loading receiving records permissions:', err);
			receivingPermRow = null;
		}
	}

	$: if ($currentUser) {
		loadReceivingRecordsPermission();
	}

	$: canEditRecord = isMasterAdmin || !!receivingPermRow?.can_edit_record;
	$: canDeleteRecord = isMasterAdmin || !!receivingPermRow?.can_delete;

	// Record edit popup state (Master Admin only)
	let showEditPopup = false;
	let editingRecord = null;
	let editForm = null;
	let editVendors = []; // Vendors available for editForm.branch_id, so the vendor can be re-selected
	let editVendorsLoading = false;
	let editVendorsError = '';
	let editVendorSearchTerm = '';
	// Only search results (typed term required) are listed in a table; the current selection is
	// shown separately as a card, not buried inside a giant dropdown/list.
	$: editSearchResults = (() => {
		const tokens = editVendorSearchTerm.trim().toLowerCase().split(/\s+/).filter(Boolean);
		if (!tokens.length) return [];
		return editVendors
			.filter((v) => {
				const name = (v.vendor_name || '').toLowerCase();
				const id = String(v.erp_vendor_id ?? '');
				// AND across words: each additional word narrows the results (as expected), instead
				// of broadening them — "al marai" must match both "al" and "marai", not just either.
				return tokens.every((tok) => name.includes(tok) || id.includes(tok));
			})
			.slice(0, 50);
	})();
	// The currently selected vendor's display info — prefers the loaded editVendors list (has
	// fresh vat_number), falling back to the record's own joined vendor so the card still shows
	// correctly before editVendors finishes loading.
	$: editSelectedVendorInfo = editForm?.vendor_id
		? editVendors.find((v) => String(v.erp_vendor_id) === String(editForm.vendor_id)) ||
		  (String(editingRecord?.vendor_id) === String(editForm.vendor_id)
				? { erp_vendor_id: editingRecord?.vendor_id, vendor_name: editingRecord?.vendors?.vendor_name, vat_number: editingRecord?.vendors?.vat_number }
				: null)
		: null;

	function selectEditVendor(v) {
		editForm.vendor_id = String(v.erp_vendor_id);
		editVendorSearchTerm = '';
	}
	let savingEdit = false;
	let editError = '';
	let editScheduleCount = 0;

	const PAYMENT_METHODS = ['Cash on Delivery', 'Bank on Delivery', 'Cash Credit', 'Bank Credit'];

	onMount(() => {
		loadBranches();
		loadErpConnections();
		loadReceivingRecords();
		loadErpCheckCounts();
		setupRealtimeSubscriptions();
		
		return () => {
			if (unsubscribeReceivingRecords) {
				unsubscribeReceivingRecords();
			}
			if (unsubscribePaymentSchedule) {
				unsubscribePaymentSchedule();
			}
		};
	});

	// Badge counts for the Mismatch/Not Found filter buttons — independent of the currently applied
	// filters/pagination, so the counts stay meaningful even while one of them is active.
	async function loadErpCheckCounts() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const [mismatchResult, notFoundResult] = await Promise.all([
				supabase.rpc('get_receiving_records_with_details', { p_limit: 1, p_erp_check_status_filter: 'mismatch' }),
				supabase.rpc('get_receiving_records_with_details', { p_limit: 1, p_erp_check_status_filter: 'not_found' })
			]);
			erpMismatchCount = mismatchResult.data?.[0]?.total_count || 0;
			erpNotFoundCount = notFoundResult.data?.[0]?.total_count || 0;
		} catch (err) {
			console.error('Error loading ERP check counts:', err);
		}
	}

	function toggleErpCheckStatusFilter(status) {
		erpCheckStatusFilter = erpCheckStatusFilter === status ? '' : status;
		onFilterChange();
	}

	async function setupRealtimeSubscriptions() {
		try {
			console.log('📡 Setting up real-time subscriptions for receiving records table...');

			// Subscribe to receiving_records changes
			unsubscribeReceivingRecords = realtimeService.subscribeToReceivingRecordsChanges(
				async (payload) => {
					console.log('🔔 Real-time receiving record update:', {
						event: payload.eventType,
						recordId: payload.new?.id || payload.old?.id
					});

					// Handle different event types
					if (payload.eventType === 'INSERT') {
						console.log('✨ New record inserted, fetching details...');
						// Fetch just the new record via RPC instead of full reload
						try {
							const { supabase } = await import('$lib/utils/supabase');
							const newId = payload.new?.id;
							if (!newId) { await loadReceivingRecords(); return; }
							
							// Fetch the single new record with all joined details
							const { data: records, error } = await supabase
								.rpc('get_receiving_records_with_details', {
									p_limit: 500,
									p_offset: 0,
									p_branch_id: null,
									p_vendor_search: null,
									p_pr_excel_filter: null,
									p_erp_ref_filter: null
								});
							
							if (error || !records) { await loadReceivingRecords(); return; }
							
							const newRec = records.find(r => r.id === newId);
							if (!newRec) { await loadReceivingRecords(); return; }
							
							// Transform to nested shape
							const newRecord = {
								id: newRec.id,
								bill_number: newRec.bill_number,
								vendor_id: newRec.vendor_id,
								branch_id: newRec.branch_id,
								bill_date: newRec.bill_date,
								bill_amount: newRec.bill_amount,
								created_at: newRec.created_at,
								user_id: newRec.user_id,
								original_bill_url: newRec.original_bill_url,
								erp_purchase_invoice_reference: newRec.erp_purchase_invoice_reference,
								certificate_url: newRec.certificate_url,
								due_date: newRec.due_date,
								pr_excel_file_url: newRec.pr_excel_file_url,
								final_bill_amount: newRec.final_bill_amount,
								payment_method: newRec.payment_method,
								credit_period: newRec.credit_period,
								bank_name: newRec.bank_name,
								iban: newRec.iban,
								branches: newRec.branch_name_en ? {
									name_en: newRec.branch_name_en,
									name_ar: newRec.branch_name_ar || newRec.branch_name_en,
									location_en: newRec.branch_location_en || '',
									location_ar: newRec.branch_location_ar || newRec.branch_location_en || ''
								} : null,
								vendors: newRec.vendor_name ? { erp_vendor_id: newRec.vendor_id, vendor_name: newRec.vendor_name, vat_number: newRec.vat_number, branch_id: newRec.branch_id } : null,
								users: newRec.username ? {
									username: newRec.username,
									hr_employees: {
										name: newRec.user_display_name || newRec.username,
										name_en: newRec.user_display_name_en || newRec.user_display_name || newRec.username,
										name_ar: newRec.user_display_name_ar || newRec.user_display_name || newRec.username
									}
								} : null,
								schedule_status: newRec.is_scheduled ? {
									receiving_record_id: newRec.id,
									is_paid: newRec.is_paid,
									pr_excel_verified: newRec.pr_excel_verified,
									pr_excel_verified_by: newRec.pr_excel_verified_by,
									pr_excel_verified_date: newRec.pr_excel_verified_date
								} : null,
								is_scheduled: newRec.is_scheduled,
								is_paid: newRec.is_paid,
								has_multiple_schedules: false,
								pr_excel_verified: newRec.pr_excel_verified,
								pr_excel_verified_by: newRec.pr_excel_verified_by,
								pr_excel_verified_date: newRec.pr_excel_verified_date
							};

							// Prepend to arrays (newest first) and avoid duplicates
							if (!receivingRecords.some(r => r.id === newId)) {
								receivingRecords = [newRecord, ...receivingRecords];
								allLoadedRecords = [newRecord, ...allLoadedRecords];
								totalRecords += 1;
								updatePaginatedRecords();
								seedErpCheckState([newRecord]);
								seedOriginalBillCheckState([newRecord]);
								console.log('✅ New record added to table without full reload');
							}
						} catch (err) {
							console.error('Error fetching new record, falling back to full reload:', err);
							await loadReceivingRecords();
						}
					} else if (payload.eventType === 'UPDATE') {
						console.log('📝 Record updated, refreshing...');
						// Update the specific record in the local arrays
						const updatedRecord = payload.new;
						const index = receivingRecords.findIndex(r => r.id === updatedRecord.id);
						if (index !== -1) {
							receivingRecords[index] = { ...receivingRecords[index], ...updatedRecord };
						}
						const allIndex = allLoadedRecords.findIndex(r => r.id === updatedRecord.id);
						if (allIndex !== -1) {
							allLoadedRecords[allIndex] = { ...allLoadedRecords[allIndex], ...updatedRecord };
						}
						updatePaginatedRecords();
					} else if (payload.eventType === 'DELETE') {
						console.log('🗑️ Record deleted, updating list...');
						// Remove the deleted record from local arrays
						receivingRecords = receivingRecords.filter(r => r.id !== payload.old?.id);
						allLoadedRecords = allLoadedRecords.filter(r => r.id !== payload.old?.id);
						updatePaginatedRecords();
					}
				}
			);

			// Subscribe to vendor_payment_schedule changes
			unsubscribePaymentSchedule = realtimeService.subscribeToVendorPaymentScheduleChanges(
				(payload) => {
					const receivingRecordId = payload.new?.receiving_record_id || payload.old?.receiving_record_id;
					console.log('💳 Real-time payment schedule update:', {
						event: payload.eventType,
						receivingRecordId: receivingRecordId,
						newData: payload.new
					});

					// Update the specific record's verification status from the payment schedule change
					if (payload.eventType === 'UPDATE' && payload.new) {
						const recordIndex = receivingRecords.findIndex(r => r.id === receivingRecordId);
						if (recordIndex !== -1) {
							console.log('📝 Updating verification status for record:', receivingRecordId);
							// Update verification status from the payment schedule
							receivingRecords[recordIndex].pr_excel_verified = payload.new.pr_excel_verified;
							receivingRecords[recordIndex].pr_excel_verified_by = payload.new.pr_excel_verified_by;
							receivingRecords[recordIndex].pr_excel_verified_date = payload.new.pr_excel_verified_date;
							if (receivingRecords[recordIndex].schedule_status) {
								receivingRecords[recordIndex].schedule_status.pr_excel_verified = payload.new.pr_excel_verified;
								receivingRecords[recordIndex].schedule_status.pr_excel_verified_by = payload.new.pr_excel_verified_by;
								receivingRecords[recordIndex].schedule_status.pr_excel_verified_date = payload.new.pr_excel_verified_date;
							}
							receivingRecords = [...receivingRecords]; // Trigger reactivity
						}
						// Also update in allLoadedRecords
						const allIndex = allLoadedRecords.findIndex(r => r.id === receivingRecordId);
						if (allIndex !== -1) {
							allLoadedRecords[allIndex].pr_excel_verified = payload.new.pr_excel_verified;
							allLoadedRecords[allIndex].pr_excel_verified_by = payload.new.pr_excel_verified_by;
							allLoadedRecords[allIndex].pr_excel_verified_date = payload.new.pr_excel_verified_date;
							if (allLoadedRecords[allIndex].schedule_status) {
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified = payload.new.pr_excel_verified;
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified_by = payload.new.pr_excel_verified_by;
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified_date = payload.new.pr_excel_verified_date;
							}
						}
						updatePaginatedRecords();
					}
				}
			);

			console.log('✅ Real-time subscriptions setup complete');
		} catch (error) {
			console.error('❌ Error setting up real-time subscriptions:', error);
		}
	}

	// Load all branches for filter dropdown
	async function loadBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (!error && data) {
				branches = data;
			}
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	// Load ERP tunnel connections so the ERP Check button can query each branch's live SQL Server
	async function loadErpConnections() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_connections')
				.select('branch_id, tunnel_url, erp_branch_id')
				.eq('is_active', true);
			if (!error && data) {
				erpConnections = data;
			}
		} catch (err) {
			console.error('Error loading ERP connections:', err);
		}
	}

	// Vendor IDs can legitimately diverge (duplicate/renamed ERP ledgers for the same real vendor,
	// e.g. "HADI MADKHALI" vs "HADI MADKHALI(SAMTAH)") while still being the same business — so the
	// vendor match decision compares NAMES (parenthetical suffixes stripped, tokenized) instead of IDs.
	function normalizeVendorNameTokens(name) {
		if (!name) return [];
		return name
			.toString()
			.toLowerCase()
			.replace(/\([^)]*\)/g, ' ')
			.replace(/[^\p{L}\p{N}\s]/gu, ' ')
			.split(/\s+/)
			.filter((t) => t.length >= 2);
	}

	function vendorNamesMatch(nameA, nameB) {
		const tokensA = new Set(normalizeVendorNameTokens(nameA));
		const tokensB = new Set(normalizeVendorNameTokens(nameB));
		if (tokensA.size === 0 || tokensB.size === 0) return false;
		let overlap = 0;
		for (const t of tokensA) if (tokensB.has(t)) overlap++;
		return overlap / Math.min(tokensA.size, tokensB.size) >= 0.8;
	}

	// Confirms whether record.erp_purchase_invoice_reference (a VoucherNumber typed in by staff)
	// actually exists as a Purchase Invoice (PI) in that branch's own ERP SQL Server, live over the
	// tunnel, AND that its vendor NAME (not the ERP ledger ID) and amount (±1 tolerance)
	// both match this receiving record — a voucher number alone can exist but belong to a different vendor/amount.
	// VoucherNumber is NOT guaranteed unique per branch (each counter/terminal keeps its own sequence,
	// and VAT vs non-VAT-form entries can independently reuse the same number) — so every matching row
	// is fetched and each is tried in turn, instead of trusting whichever one a bare TOP 1 happens to return.
	// The verdict is persisted to receiving_records.erp_check_result (jsonb) so it survives reloads.
	function evaluateErpCandidate(row, record) {
		const erpVendorId = String(row.VendorId ?? '').trim();
		const localVendorId = String(record.vendor_id ?? '').trim();
		const erpAmount = parseFloat(row.GrandTotal) || 0;
		// final_bill_amount can be a discounted/adjusted figure that legitimately differs from
		// the ERP's GrandTotal, while bill_amount (the original entered total) is often the closer
		// match — check against both and accept whichever is within tolerance.
		const billAmount = parseFloat(record.bill_amount ?? 0) || 0;
		const finalAmount = parseFloat(record.final_bill_amount ?? record.bill_amount ?? 0) || 0;
		const diffFromBill = erpAmount - billAmount;
		const diffFromFinal = erpAmount - finalAmount;
		const AMOUNT_TOLERANCE = 1;
		const matchesBill = Math.abs(diffFromBill) <= AMOUNT_TOLERANCE;
		const matchesFinal = Math.abs(diffFromFinal) <= AMOUNT_TOLERANCE;
		const amountMatches = matchesBill || matchesFinal;
		const useBill = Math.abs(diffFromBill) <= Math.abs(diffFromFinal);
		const amountDiff = useBill ? diffFromBill : diffFromFinal;
		const amountSource = useBill ? 'Bill' : 'Final';
		// Step 1: exact vendor ID match. Step 2 (fallback, only when IDs differ): vendor NAME
		// match — catches duplicate/renamed ERP ledgers for the same real vendor.
		const vendorIdMatches = erpVendorId !== '' && erpVendorId === localVendorId;
		const vendorNameMatches = !vendorIdMatches && vendorNamesMatch(record.vendors?.vendor_name, row.PartyName);
		const vendorMatches = vendorIdMatches || vendorNameMatches;
		const vendorMatchedVia = vendorIdMatches ? 'id' : (vendorNameMatches ? 'name' : null);
		// VoucherForm is blank for non-VAT entries and 'VAT' for VAT-form invoices.
		const vatStatus = (row.VoucherForm || '').trim().toUpperCase() === 'VAT' ? 'VAT' : 'No VAT';
		return {
			status: vendorMatches && amountMatches ? 'matched' : 'mismatch',
			grandTotal: erpAmount, amountDiff, amountSource, erpVendorId, localVendorId,
			vendorMatches, vendorIdMatches, vendorNameMatches, vendorMatchedVia, amountMatches,
			partyName: row.PartyName, localVendorName: record.vendors?.vendor_name || null, vatStatus
		};
	}

	async function checkErpInvoice(record) {
		const ref = (record.erp_purchase_invoice_reference || '').toString().trim();
		if (!ref) return;

		const conn = erpConnections.find((c) => String(c.branch_id) === String(record.branch_id) && c.tunnel_url);
		if (!conn) {
			erpCheckStatus = { ...erpCheckStatus, [record.id]: 'error' };
			erpCheckResult = { ...erpCheckResult, [record.id]: { error: 'No ERP tunnel configured for this branch' } };
			return;
		}

		erpCheckStatus = { ...erpCheckStatus, [record.id]: 'checking' };
		try {
			const safeRef = ref.replace(/'/g, "''");
			const sql = `SELECT m.InvTransactionMasterID, m.GrandTotal, m.PartyName, m.TransactionDate, m.VoucherForm, l.LedgerCode AS VendorId FROM InvTransactionMaster m LEFT JOIN AccLedgers l ON l.LedgerID = m.LedgerID AND l.BranchID = m.BranchID WHERE m.VoucherType='PI' AND CAST(m.VoucherNumber AS VARCHAR(50))='${safeRef}' AND m.BranchID=${conn.erp_branch_id} AND m.IsActive=1`;
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', tunnelUrl: conn.tunnel_url, sql })
			});
			const data = await response.json();
			if (!data.success) throw new Error(data.error || 'Query failed');

			const rows = data.recordset || [];
			if (rows.length === 0) {
				const payload = { status: 'not_found', checkedAt: new Date().toISOString() };
				erpCheckStatus = { ...erpCheckStatus, [record.id]: 'not_found' };
				erpCheckResult = { ...erpCheckResult, [record.id]: payload };
				await persistErpCheckResult(record.id, payload);
				return;
			}

			const candidates = rows.map((row) => evaluateErpCandidate(row, record));
			// Prefer a fully-matched candidate; otherwise report whichever is closest on amount,
			// so the mismatch reason shown is the most plausible one, not an arbitrary row.
			const best = candidates.find((c) => c.status === 'matched') ||
				candidates.reduce((a, b) => (Math.abs(b.amountDiff) < Math.abs(a.amountDiff) ? b : a));

			const payload = {
				...best,
				candidateCount: rows.length,
				checkedAt: new Date().toISOString()
			};
			erpCheckStatus = { ...erpCheckStatus, [record.id]: payload.status };
			erpCheckResult = { ...erpCheckResult, [record.id]: payload };
			await persistErpCheckResult(record.id, payload);
		} catch (err) {
			console.error('ERP check failed:', err);
			erpCheckStatus = { ...erpCheckStatus, [record.id]: 'error' };
			erpCheckResult = { ...erpCheckResult, [record.id]: { error: err.message || 'Check failed' } };
		}
	}

	// Writes the latest ERP check verdict back to receiving_records.erp_check_result (jsonb) and
	// mirrors it into the in-memory record arrays so it round-trips without needing a full reload.
	async function persistErpCheckResult(recordId, payload) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('receiving_records')
				.update({ erp_check_result: payload })
				.eq('id', recordId);
			if (error) throw error;

			const patch = (records) => records.map((r) => (r.id === recordId ? { ...r, erp_check_result: payload } : r));
			receivingRecords = patch(receivingRecords);
			allLoadedRecords = patch(allLoadedRecords);
			paginatedRecords = patch(paginatedRecords);
			archivedRecords = patch(archivedRecords);
		} catch (err) {
			console.error('Failed to persist ERP check result:', err);
		}
	}

	// Seeds the client-side check-status maps from each record's persisted erp_check_result,
	// so a previously "Matched" record shows that way immediately without a fresh live query.
	function seedErpCheckState(records) {
		let statusChanged = false;
		let resultChanged = false;
		const nextStatus = { ...erpCheckStatus };
		const nextResult = { ...erpCheckResult };
		for (const record of records) {
			if (record.erp_check_result && nextStatus[record.id] === undefined) {
				nextStatus[record.id] = record.erp_check_result.status;
				nextResult[record.id] = record.erp_check_result;
				statusChanged = true;
				resultChanged = true;
			}
		}
		if (statusChanged) erpCheckStatus = nextStatus;
		if (resultChanged) erpCheckResult = nextResult;
	}

	async function loadReceivingRecords() {
		loading = true;
		try {
			const startTime = performance.now();
			
			console.log('📋 Starting RPC-based receiving records load (500 per page)...');
			
			// Reset loaded records and filters
			allLoadedRecords = [];
			selectedBranchFilter = '';
			selectedPrExcelFilter = '';
			vendorSearchTerm = '';
			selectedErpRefFilter = '';
			erpReferenceSearchTerm = '';
			erpCheckStatusFilter = '';
			billDateFilterMode = '';
			billDateFrom = '';
			billDateTo = '';
			currentPage = 1;

			// Load first page via RPC (count is returned from RPC itself)
			await loadPageData(1);
			loading = false; // Table displays immediately
			
			const endTime = performance.now();
			console.log(`✅ First batch (${pageSize} records) loaded via RPC in ${(endTime - startTime).toFixed(0)}ms`);
		} catch (err) {
			console.error('Error in loadReceivingRecords:', err);
			receivingRecords = [];
			allLoadedRecords = [];
			loading = false;
		}
	}

	// Load data for a specific page using RPC (with server-side filters)
	async function loadPageData(pageNum) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const startIdx = (pageNum - 1) * pageSize;

			// Build RPC params with filters
			const rpcParams = {
				p_limit: pageSize,
				p_offset: startIdx,
				p_branch_id: selectedBranchFilter || null,
				p_vendor_search: vendorSearchTerm?.trim() || null,
				p_pr_excel_filter: selectedPrExcelFilter || null,
				p_erp_ref_filter: selectedErpRefFilter || null
			};
			const erpReferenceSearch = erpReferenceSearchTerm?.trim();
			if (erpReferenceSearch) {
				rpcParams.p_erp_reference_search = erpReferenceSearch;
			}
			if (erpCheckStatusFilter) {
				rpcParams.p_erp_check_status_filter = erpCheckStatusFilter;
			}
			if (billDateFilterMode === 'specific' && billDateFrom) {
				rpcParams.p_bill_date_from = billDateFrom;
				rpcParams.p_bill_date_to = billDateFrom;
			} else if (billDateFilterMode === 'period') {
				if (billDateFrom) rpcParams.p_bill_date_from = billDateFrom;
				if (billDateTo) rpcParams.p_bill_date_to = billDateTo;
			}
			const hasEnhancedFilters = Boolean(
				erpReferenceSearch || rpcParams.p_bill_date_from || rpcParams.p_bill_date_to || erpCheckStatusFilter
			);

			console.log(`📄 Loading page ${pageNum} via RPC (offset: ${startIdx}, limit: ${pageSize}, filters: ${JSON.stringify(rpcParams)})...`);
			
			// Single RPC call - all JOINs + filters done server-side
			let { data: records, error: rpcError } = await supabase
				.rpc('get_receiving_records_with_details', rpcParams);

			// Keep the records window usable while the ERP-search migration is being deployed.
			// The legacy RPC has six parameters and cannot accept p_erp_reference_search.
			if (rpcError?.code === 'PGRST202' && hasEnhancedFilters) {
				console.warn('Enhanced receiving-record filters are not deployed yet; using the legacy RPC fallback.');
				const legacyParams = { ...rpcParams };
				delete legacyParams.p_erp_reference_search;
				delete legacyParams.p_bill_date_from;
				delete legacyParams.p_bill_date_to;
				delete legacyParams.p_erp_check_status_filter;
				const legacyResult = await supabase.rpc('get_receiving_records_with_details', legacyParams);
				const fallbackMatches = legacyResult.data?.filter((record) =>
					(!erpReferenceSearch || String(record.erp_purchase_invoice_reference || '')
						.toLowerCase().includes(erpReferenceSearch.toLowerCase())) &&
					(!rpcParams.p_bill_date_from || record.bill_date >= rpcParams.p_bill_date_from) &&
					(!rpcParams.p_bill_date_to || record.bill_date <= rpcParams.p_bill_date_to) &&
					(!erpCheckStatusFilter || record.erp_check_result?.status === erpCheckStatusFilter)
				) || [];
				records = fallbackMatches.map((record) => ({
					...record,
					total_count: fallbackMatches.length
				}));
				rpcError = legacyResult.error;
			}

			if (rpcError) {
				console.error(`❌ Error loading page ${pageNum}:`, rpcError);
				throw rpcError;
			}

			if (!records || records.length === 0) {
				console.log(`📊 No records on page ${pageNum}`);
				totalRecords = 0;
				totalPages = 1;
				receivingRecords = [];
				allLoadedRecords = [];
				paginatedRecords = [];
				return;
			}

			// Extract total count from first record (returned by RPC)
			totalRecords = records[0]?.total_count || records.length;
			totalPages = Math.ceil(totalRecords / pageSize);
			console.log(`📊 Loaded ${records.length} records for page ${pageNum} via RPC (total matching: ${totalRecords}, pages: ${totalPages})`);

			// Transform flat RPC response into nested shape the template expects
			const recordsWithDetails = records.map(record => ({
				id: record.id,
				bill_number: record.bill_number,
				vendor_id: record.vendor_id,
				branch_id: record.branch_id,
				bill_date: record.bill_date,
				bill_amount: record.bill_amount,
				created_at: record.created_at,
				user_id: record.user_id,
				original_bill_url: record.original_bill_url,
				erp_purchase_invoice_reference: record.erp_purchase_invoice_reference,
				certificate_url: record.certificate_url,
				due_date: record.due_date,
				pr_excel_file_url: record.pr_excel_file_url,
				final_bill_amount: record.final_bill_amount,
				payment_method: record.payment_method,
				credit_period: record.credit_period,
				bank_name: record.bank_name,
				iban: record.iban,
				// Nested objects for template compatibility
				branches: record.branch_name_en ? {
					name_en: record.branch_name_en,
					name_ar: record.branch_name_ar || record.branch_name_en,
					location_en: record.branch_location_en || '',
					location_ar: record.branch_location_ar || record.branch_location_en || ''
				} : null,
				vendors: record.vendor_name ? { erp_vendor_id: record.vendor_id, vendor_name: record.vendor_name, vat_number: record.vat_number, branch_id: record.branch_id } : null,
				users: record.username ? {
					username: record.username,
					hr_employees: {
						name: record.user_display_name || record.username,
						name_en: record.user_display_name_en || record.user_display_name || record.username,
						name_ar: record.user_display_name_ar || record.user_display_name || record.username
					}
				} : null,
				// Payment schedule data
				schedule_status: record.is_scheduled ? {
					receiving_record_id: record.id,
					is_paid: record.is_paid,
					pr_excel_verified: record.pr_excel_verified,
					pr_excel_verified_by: record.pr_excel_verified_by,
					pr_excel_verified_date: record.pr_excel_verified_date
				} : null,
				is_scheduled: record.is_scheduled,
				is_paid: record.is_paid,
				has_multiple_schedules: false,
				pr_excel_verified: record.pr_excel_verified,
				pr_excel_verified_by: record.pr_excel_verified_by,
				pr_excel_verified_date: record.pr_excel_verified_date,
				erp_check_result: record.erp_check_result,
				original_bill_check_result: record.original_bill_check_result
			}));

			receivingRecords = recordsWithDetails;
			allLoadedRecords = recordsWithDetails;
			updatePaginatedRecords();
			seedErpCheckState(recordsWithDetails);
			seedOriginalBillCheckState(recordsWithDetails);
			console.log(`✅ Page ${pageNum} loaded via RPC (${recordsWithDetails.length} records shown)`);
		} catch (err) {
			console.error(`Error loading page ${pageNum}:`, err);
			receivingRecords = [];
			paginatedRecords = [];
		}
	}

	// Load archived records on-demand
	async function loadArchivedRecords() {
		try {
			const startTime = performance.now();
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('📦 Loading archived records on-demand...');
			
		const { data: records, error: recordsError } = await supabase
			.from('receiving_records')
			.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban, erp_check_result, original_bill_check_result')
			.order('created_at', { ascending: false })
			.limit(200);			if (recordsError) throw recordsError;

			if (!records || records.length === 0) {
				const endTime = performance.now();
				console.log(`✅ No archived records found in ${(endTime - startTime).toFixed(0)}ms`);
				return;
			}

			// Fetch details in bulk for archived records
			const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))];
			const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
			const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))];

			const [branchResult, vendorResult, userResult] = await Promise.all([
				supabase.from('branches').select('id, name_en, location_en').in('id', uniqueBranchIds),
				supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact, branch_id').in('erp_vendor_id', uniqueVendorIds),
				supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
			]);

			const branchMap = new Map(branchResult.data?.map(b => [b.id, b]) || []);
			const vendorMap = new Map();
			vendorResult.data?.forEach(vendor => {
				const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
				vendorMap.set(key, vendor);
			});
			const userMap = new Map(userResult.data?.map(u => [u.id, u]) || []);

			const recordsWithDetails = records.map(record => ({
				...record,
				branches: branchMap.get(record.branch_id),
				vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
				users: userMap.get(record.user_id)
			}));

			archivedRecords = recordsWithDetails;
			seedErpCheckState(recordsWithDetails);
			seedOriginalBillCheckState(recordsWithDetails);
			const endTime = performance.now();
			console.log(`✅ Archived records loaded in ${(endTime - startTime).toFixed(0)}ms (${recordsWithDetails.length} records)`);
		} catch (error) {
			console.error('Error loading archived records:', error);
		}
	}

	// Reactive: Load archived records when toggle is checked
	$: if (showArchived && archivedRecords.length === 0) {
		loadArchivedRecords();
	}


	// Load paginated data for filtered results - optimized to load only needed records
	// Filter loading function - currently disabled, will be implemented later
	// All filtering will use the initial loading system
	async function loadFilteredPageData(pageNum, filterCriteria) {
		console.log(`📄 Filter loading disabled - using initial loading system instead`);
		return;
	}

	// Update paginated records - handles client-side filtering for due dates
	function updatePaginatedRecords() {
		let filtered = [...allLoadedRecords];
		
		if (selectedDueFilter) {
			const maxDays = parseInt(selectedDueFilter);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			
			filtered = filtered.filter(record => {
				// Skip paid records for due-in filter
				const isPaid = record.is_paid || record.schedule_status?.is_paid || record.payment_method?.toLowerCase()?.includes('on delivery');
				if (isPaid) return false;
				
				if (!record.due_date) return false;
				
				const dueDate = new Date(record.due_date);
				dueDate.setHours(0, 0, 0, 0);
				const diffTime = dueDate.getTime() - today.getTime();
				const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
				
				// Show records due within the next X days (including today)
				return diffDays >= 0 && diffDays <= maxDays;
			});
		}

		paginatedRecords = filtered;
		console.log(`📄 Showing ${paginatedRecords.length} records`);
	}

	// Debounce timer for vendor search
	let vendorSearchTimer = null;

	// Server-side filter reload helper
	async function reloadWithFilters() {
		currentPage = 1;
		loading = true;
		await loadPageData(1);
		loading = false;
	}

	// Called by on:change on select filters
	function onFilterChange() {
		reloadWithFilters();
	}

	// Called by on:input on vendor search (debounced)
	function onVendorSearchInput() {
		if (vendorSearchTimer) clearTimeout(vendorSearchTimer);
		vendorSearchTimer = setTimeout(() => {
			reloadWithFilters();
		}, 500);
	}

	function applyErpReferenceSearch() {
		reloadWithFilters();
	}

	function onErpReferenceSearchKeydown(event) {
		if (event.key === 'Enter') {
			event.preventDefault();
			applyErpReferenceSearch();
		}
	}

	function onBillDateModeChange() {
		if (!billDateFilterMode) {
			billDateFrom = '';
			billDateTo = '';
			reloadWithFilters();
		} else if (billDateFilterMode === 'specific') {
			billDateTo = '';
		}
	}

	function applyBillDateFilter() {
		if (billDateFilterMode === 'specific' && !billDateFrom) return;
		if (billDateFilterMode === 'period' && !billDateFrom && !billDateTo) return;
		reloadWithFilters();
	}

	// Filter values change - do NOT apply filters automatically
	// Filters only apply when user explicitly clicks "Load Records" button

	function viewCertificate(certificateUrl) {
		if (certificateUrl) {
			window.open(certificateUrl, '_blank');
		}
	}

	function viewOriginalBill(billUrl) {
		if (billUrl) {
			window.open(billUrl, '_blank');
		}
	}

	// Helper function to check if file is PDF
	function isPdfFile(url) {
		if (!url) return false;
		return url.toLowerCase().includes('.pdf');
	}

	// Helper function to get file extension
	function getFileExtension(url) {
		if (!url) return '';
		return url.split('.').pop().toLowerCase();
	}

	async function uploadOriginalBill(recordId) {
		uploadingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Compress image files before upload (skip PDFs)
				let uploadFile = file;
				let fileExt = file.name.split('.').pop();
				if (file.type.startsWith('image/')) {
					try {
						const compressed = await compressImage(file);
						const res = await fetch(compressed);
						const blob = await res.blob();
						uploadFile = new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), { type: 'image/jpeg' });
						fileExt = 'jpg';
					} catch { /* fallback to original */ }
				}
				const fileName = `${recordId}_original_bill_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, uploadFile);

				if (uploadError) {
					console.error('Error uploading file:', uploadError);
					alert(tFn('receiving.records.errorUploadFile'));
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ original_bill_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert(tFn('receiving.records.errorSaveFileRef'));
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();

			} catch (error) {
				console.error('Error in upload process:', error);
				alert(tFn('receiving.records.errorUploadFile'));
			} finally {
				uploadingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	async function updateOriginalBill(recordId) {
		updatingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				updatingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Compress image files before upload (skip PDFs)
				let uploadFile = file;
				let fileExt = file.name.split('.').pop();
				if (file.type.startsWith('image/')) {
					try {
						const compressed = await compressImage(file);
						const res = await fetch(compressed);
						const blob = await res.blob();
						uploadFile = new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), { type: 'image/jpeg' });
						fileExt = 'jpg';
					} catch { /* fallback to original */ }
				}
				const fileName = `${recordId}_original_bill_updated_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, uploadFile);

				if (uploadError) {
					console.error('Error uploading updated file:', uploadError);
					alert(tFn('receiving.records.errorUploadFile'));
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the new file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({
						original_bill_url: publicUrl,
						updated_at: new Date().toISOString()
					})
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert(tFn('receiving.records.errorSaveFileRef'));
					return;
				}

				// Show success message
				alert(tFn('receiving.records.billUpdatedSuccess'));

				// Reload records to show updated data
				await loadReceivingRecords();

			} catch (error) {
				console.error('Error in update process:', error);
				alert(tFn('receiving.records.errorUpdateFile'));
			} finally {
				updatingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	// Writes an AI Bill Check verdict back to receiving_records.original_bill_check_result (jsonb)
	// and mirrors it into the in-memory record arrays + status maps so the Original Bill cell
	// updates immediately, without needing a full reload. Shared by the auto-save that runs right
	// after every Check/Recheck completes, and by "Done" (which re-saves with whatever the Manual
	// Verification checkbox is currently set to).
	//
	// Vendor match is decided by VAT number (the authoritative identifier), not the name —
	// result.vendorMatches already folds that rule in (see /api/check-original-bill). A name
	// mismatch alongside a matched VAT still shows up via vendorNameMatches for review, it just
	// doesn't block the overall vendor (or bill) match on its own.
	async function persistBillCheckResult(record, result, manuallyVerifiedFlag) {
		const aiAllMatch = result.vendorMatches === true
			&& result.billAmountMatches === true
			&& result.billDateMatches === true;
		const payload = {
			vendorName: result.vendorName,
			vendorVatNumber: result.vendorVatNumber,
			billAmountIncludingVat: result.billAmountIncludingVat,
			billDate: result.billDate,
			billDateIso: result.billDateIso,
			vendorNameMatches: result.vendorNameMatches,
			vendorVatMatches: result.vendorVatMatches,
			vendorMatches: result.vendorMatches,
			billAmountMatches: result.billAmountMatches,
			billDateMatches: result.billDateMatches,
			manuallyVerified: manuallyVerifiedFlag,
			manuallyVerifiedBy: manuallyVerifiedFlag ? ($currentUser?.username || $currentUser?.id || null) : null,
			manuallyVerifiedAt: manuallyVerifiedFlag ? new Date().toISOString() : null,
			status: (aiAllMatch || manuallyVerifiedFlag) ? 'matched' : 'mismatch',
			checkedAt: new Date().toISOString()
		};

		const { supabase } = await import('$lib/utils/supabase');
		const { error } = await supabase
			.from('receiving_records')
			.update({ original_bill_check_result: payload })
			.eq('id', record.id);
		if (error) throw error;

		originalBillCheckStatus = { ...originalBillCheckStatus, [record.id]: payload.status };
		originalBillCheckResult = { ...originalBillCheckResult, [record.id]: payload };

		const patch = (records) => records.map((r) => (r.id === record.id ? { ...r, original_bill_check_result: payload } : r));
		receivingRecords = patch(receivingRecords);
		allLoadedRecords = patch(allLoadedRecords);
		paginatedRecords = patch(paginatedRecords);
		archivedRecords = patch(archivedRecords);

		return payload;
	}

	// Runs the AI check and auto-saves the result the moment it comes back — no "Done" press
	// needed for the result itself to be persisted. Used both for the first Check from the table
	// row and for "Recheck" inside the already-open popup (which just calls this again on the same
	// record — the popup re-renders with the fresh result since billCheckResult/billCheckRecord
	// are reassigned here).
	async function checkOriginalBill(record) {
		if (!record.original_bill_url || checkingBillId) return;
		checkingBillId = record.id;
		try {
			const response = await fetch('/api/check-original-bill', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					url: record.original_bill_url,
					localVendorName: record.vendors?.vendor_name || null,
					localVendorVat: record.vendors?.vat_number || null,
					localBillAmount: parseFloat(record.final_bill_amount ?? record.bill_amount ?? 0) || 0,
					// Raw ISO (YYYY-MM-DD, as stored) — the server compares this against the AI's
					// own ISO-normalized read of the document with a plain string equality, not an
					// AI judgment call, so it needs to be in the same unambiguous format.
					localBillDate: record.bill_date || null
				})
			});
			const data = await response.json();
			if (!response.ok) throw new Error(data.error || 'Failed to check bill');
			billCheckResult = data;
			billCheckRecord = record;
			manualVerified = false;
			showBillCheckModal = true;

			try {
				await persistBillCheckResult(record, data, false);
			} catch (saveErr) {
				console.error('Failed to auto-save AI bill check result:', saveErr);
				alert(`AI check completed, but saving the result failed: ${saveErr?.message || saveErr}`);
			}
		} catch (err) {
			alert(`Error checking original bill: ${err?.message || err}`);
		} finally {
			checkingBillId = null;
		}
	}

	function closeBillCheckModal() {
		showBillCheckModal = false;
		billCheckResult = null;
		billCheckRecord = null;
		manualVerified = false;
	}

	// Reopens the popup showing the already-persisted verdict (Matched or Unmatched), without
	// re-running the AI check — purely for review. Recheck (inside the popup) is what triggers a
	// fresh AI call from here.
	function openSavedBillCheck(record) {
		const saved = originalBillCheckResult[record.id];
		if (!saved) return;
		billCheckResult = saved;
		billCheckRecord = record;
		manualVerified = !!saved.manuallyVerified;
		showBillCheckModal = true;
	}

	// "Done" — re-saves the currently displayed result together with whatever the Manual
	// Verification checkbox is set to right now (the AI-only result was already auto-saved by
	// checkOriginalBill; this is what lets a manual override on top of it actually persist).
	async function saveBillCheckResult() {
		if (!billCheckRecord || !billCheckResult || savingBillCheck) return;
		savingBillCheck = true;
		try {
			await persistBillCheckResult(billCheckRecord, billCheckResult, manualVerified);
			closeBillCheckModal();
		} catch (err) {
			alert(`Error saving bill check result: ${err?.message || err}`);
		} finally {
			savingBillCheck = false;
		}
	}

	// Seeds the client-side status maps from each record's persisted original_bill_check_result,
	// so a previously "Matched"/mismatched record shows that way immediately without re-checking.
	function seedOriginalBillCheckState(records) {
		let statusChanged = false;
		let resultChanged = false;
		const nextStatus = { ...originalBillCheckStatus };
		const nextResult = { ...originalBillCheckResult };
		for (const record of records) {
			if (record.original_bill_check_result && nextStatus[record.id] === undefined) {
				nextStatus[record.id] = record.original_bill_check_result.status;
				nextResult[record.id] = record.original_bill_check_result;
				statusChanged = true;
				resultChanged = true;
			}
		}
		if (statusChanged) originalBillCheckStatus = nextStatus;
		if (resultChanged) originalBillCheckResult = nextResult;
	}

	async function uploadPRExcel(recordId) {
		uploadingExcelId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.xlsx,.xls,.csv';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingExcelId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_pr_excel_${Date.now()}.${fileExt}`;

				// Upload file to pr-excel-files storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('pr-excel-files')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading PR Excel file:', uploadError);
					alert(tFn('receiving.records.errorUploadPrExcel'));
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('pr-excel-files')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ pr_excel_file_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record with PR Excel:', updateError);
					alert(tFn('receiving.records.errorSavePrExcelRef'));
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();
				alert(tFn('receiving.records.prExcelUploadSuccess'));

			} catch (error) {
				console.error('Error in PR Excel upload process:', error);
				alert(tFn('receiving.records.errorUploadPrExcel'));
			} finally {
				uploadingExcelId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	// Handle PR Excel verification
	async function handlePRExcelVerification(recordId, isVerified) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('Updating PR Excel verification:', { recordId, isVerified, userId: $currentUser?.id });
			
			const verifiedDate = isVerified ? new Date().toISOString() : null;
			const updateData = {
				pr_excel_verified: isVerified,
				pr_excel_verified_by: isVerified ? $currentUser?.id : null,
				pr_excel_verified_date: verifiedDate
			};

			// Update ALL payment schedules for this receiving record
			// This is important for split payments where there might be multiple schedules
			const { data: scheduleData, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.update(updateData)
				.eq('receiving_record_id', recordId)
				.select();

			if (scheduleError) {
				console.error('Supabase error updating payment schedules:', scheduleError);
				throw scheduleError;
			}

			console.log('✅ Update successful for payment schedules:', scheduleData);

			// Verify we have a payment schedule for this record
			if (!scheduleData || scheduleData.length === 0) {
				console.warn(`No payment schedules found for receiving record ${recordId}`);
				alert(tFn('receiving.records.noPaymentSchedules'));
				return;
			}

			// Update local state to reflect changes immediately
			receivingRecords = receivingRecords.map(record => {
				if (record.id === recordId) {
					return {
						...record,
						pr_excel_verified: isVerified,
						pr_excel_verified_by: isVerified ? $currentUser?.id : null,
						pr_excel_verified_date: verifiedDate,
						schedule_status: record.schedule_status ? {
							...record.schedule_status,
							pr_excel_verified: isVerified,
							pr_excel_verified_by: isVerified ? $currentUser?.id : null,
							pr_excel_verified_date: verifiedDate
						} : null
					};
				}
				return record;
			});

			// Update the display
			updatePaginatedRecords();
			
		} catch (error) {
			console.error('Error updating PR Excel verification:', error);
			alert(tFn('receiving.records.errorUpdateVerification', { error: error.message }));
		}
	}

	// Fast lookup for locale-aware branch display
	$: branchMap = new Map(branches.map(b => [b.id, b]));

	function getBranchName(record, locale) {
		const b = branchMap.get(record.branch_id);
		if (locale === 'ar') {
			return record.branches?.name_ar || b?.name_ar || record.branches?.name_en || b?.name_en || tFn('receiving.records.naText');
		}
		return record.branches?.name_en || b?.name_en || tFn('receiving.records.naText');
	}

	function getBranchLocation(record, locale) {
		const b = branchMap.get(record.branch_id);
		if (locale === 'ar') {
			return record.branches?.location_ar || b?.location_ar || record.branches?.location_en || b?.location_en || '';
		}
		return record.branches?.location_en || b?.location_en || '';
	}

	function getReceivedByName(record, locale) {
		const employee = record.users?.hr_employees;
		if (locale === 'ar') {
			return employee?.name_ar || employee?.name_en || employee?.name || record.users?.username || tFn('receiving.records.naText');
		}
		return employee?.name_en || employee?.name || record.users?.username || tFn('receiving.records.naText');
	}

	function translatePaymentMethod(method) {
		if (!method) return tFn('receiving.records.naText');
		const map = {
			'Cash on Delivery': 'receiving.cashOnDelivery',
			'Bank on Delivery': 'receiving.bankOnDelivery',
			'Cash Credit':      'receiving.cashCredit',
			'Bank Credit':      'receiving.bankCredit',
		};
		const key = map[method];
		return key ? tFn(key) : method;
	}

	// Helper function to format dates as dd/mm/yyyy
	function formatDate(dateString) {
		if (!dateString) return tFn('receiving.records.naText');
		try {
			const date = new Date(dateString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return tFn('receiving.records.invalidDate');
		}
	}

	// Download empty XLSX template for receiving
	function downloadReceivingTemplate() {
		const headers = ['Barcode', 'Product Name_En', 'Product Name_Ar', 'Received Qty', 'Free Qty', 'Unit', 'Cost', 'Sales Price'];
		// Each column gets its own professional light color
		const headerColors = [
			'D6E4F0', // Barcode - soft blue
			'E2EFDA', // Product Name_En - soft green
			'FCE4D6', // Product Name_Ar - soft peach
			'DAEEF3', // Received Qty - soft cyan
			'E4DFEC', // Free Qty - soft lavender
			'FFF2CC', // Unit - soft yellow
			'D9E2F3', // Cost - soft steel blue
			'E2F0D9', // Sales Price - soft mint
		];
		const border = {
			top: { style: 'thin', color: { rgb: '999999' } },
			bottom: { style: 'thin', color: { rgb: '999999' } },
			left: { style: 'thin', color: { rgb: '999999' } },
			right: { style: 'thin', color: { rgb: '999999' } }
		};
		const ws = XLSX.utils.aoa_to_sheet([headers]);
		// Apply individual header styles per column
		headers.forEach((_, i) => {
			const cell = XLSX.utils.encode_cell({ r: 0, c: i });
			if (ws[cell]) {
				ws[cell].s = {
					fill: { fgColor: { rgb: headerColors[i] } },
					font: { bold: true, color: { rgb: '333333' }, sz: 11, name: 'Calibri' },
					alignment: { horizontal: 'center', vertical: 'center' },
					border
				};
			}
		});
		// Set column widths
		ws['!cols'] = [
			{ wch: 18 }, // Barcode
			{ wch: 30 }, // Product Name_En
			{ wch: 30 }, // Product Name_Ar
			{ wch: 14 }, // Received Qty
			{ wch: 12 }, // Free Qty
			{ wch: 10 }, // Unit
			{ wch: 18 }, // Cost
			{ wch: 14 }, // Sales Price
		];
		// Set row height for header
		ws['!rows'] = [{ hpt: 28 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Receiving Template');
		XLSX.writeFile(wb, 'Receiving_Template.xlsx');
	}

	// Helper function to calculate days remaining to due date
	function getDaysRemaining(dueDateString) {
		if (!dueDateString) return tFn('receiving.records.naText');
		try {
			const dueDate = new Date(dueDateString);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			dueDate.setHours(0, 0, 0, 0);

			const diffTime = dueDate.getTime() - today.getTime();
			const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			return tFn('receiving.records.daysText', { n: diffDays });
		} catch (error) {
			return tFn('receiving.records.invalidDate');
		}
	}

	// Helper function to format date and time as dd/mm/yyyy HH:mm
	function formatDateTime(dateTimeString) {
		if (!dateTimeString) return 'N/A';
		try {
			const date = new Date(dateTimeString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			const hours = date.getHours().toString().padStart(2, '0');
			const minutes = date.getMinutes().toString().padStart(2, '0');
			return `${day}/${month}/${year} ${hours}:${minutes}`;
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Generate PR Excel filename with vendor name, bill date, and amount
	function getPRExcelFileName(record) {
		try {
			const vendorName = (record.vendors?.vendor_name || 'Unknown_Vendor')
				.replace(/[^a-zA-Z0-9\u0600-\u06FF\s]/g, '') // Remove special characters but keep Arabic
				.replace(/\s+/g, '_') // Replace spaces with underscores
				.substring(0, 50); // Limit length
			
			const billDate = record.bill_date 
				? formatDate(record.bill_date).replace(/\//g, '-') 
				: 'No_Date';
			
			const amount = record.final_bill_amount || record.bill_amount || 0;
			const amountFormatted = parseFloat(amount).toFixed(2);
			
			// Get file extension from URL
			const url = record.pr_excel_file_url;
			const urlParts = url.split('.');
			const extension = urlParts[urlParts.length - 1].split('?')[0] || 'xlsx';
			
			return `${vendorName}_${billDate}_${amountFormatted}_SAR.${extension}`;
		} catch (error) {
			console.error('Error generating PR Excel filename:', error);
			return 'PR_Excel.xlsx';
		}
	}

	// Download PR Excel with custom filename
	async function downloadPRExcel(record) {
		try {
			const fileName = getPRExcelFileName(record);
			
			// Fetch the file
			const response = await fetch(record.pr_excel_file_url);
			if (!response.ok) throw new Error('Failed to fetch file');
			
			// Get the blob
			const blob = await response.blob();
			
			// Create download link
			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = fileName;
			document.body.appendChild(link);
			link.click();
			
			// Cleanup
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Error downloading PR Excel:', error);
			// Fallback to opening in new tab
			window.open(record.pr_excel_file_url, '_blank');
		}
	}

	// ERP Invoice Reference Functions
	function openErpPopup(record) {
		selectedRecord = record;
		erpReferenceValue = record.erp_purchase_invoice_reference || '';
		showErpPopup = true;
	}

	function closeErpPopup() {
		showErpPopup = false;
		selectedRecord = null;
		erpReferenceValue = '';
		updatingErp = false;
	}

	async function updateErpReference() {
		if (!selectedRecord || !erpReferenceValue?.trim()) return;

		try {
			updatingErp = true;
			
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					receivingRecordId: selectedRecord.id,
					erpReference: erpReferenceValue.trim()
				})
			});

			if (!response.ok) {
				const error = await response.text();
				throw new Error(error);
			}

			// Update the record in our local data
			const updatedRecords = receivingRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);
			receivingRecords = updatedRecords;

			closeErpPopup();
			alert(tFn('receiving.records.erpUpdatedSuccess'));
		} catch (error) {
			console.error('Error updating ERP reference:', error);
			alert(tFn('receiving.records.erpUpdateFailed', { error: error.message }));
		} finally {
			updatingErp = false;
		}
	}

	async function generateCertificate(record) {
		selectedRecordForCertificate = record;
		showCertificateModal = true;
	}

	function closeCertificateModal() {
		showCertificateModal = false;
		selectedRecordForCertificate = null;
	}

	function handleCertificateGenerated() {
		// Reload records to show the updated certificate
		loadReceivingRecords();
		closeCertificateModal();
	}

	// ---- Master Admin record editing ----

	// Dates come back as ISO/timestamp strings; <input type="date"> needs yyyy-mm-dd
	function toDateInput(value) {
		if (!value) return '';
		const d = new Date(value);
		if (isNaN(d.getTime())) return '';
		return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
	}

	async function openEditPopup(record) {
		if (!isMasterAdmin && !canEditRecord) return;

		editingRecord = record;
		editError = '';
		editScheduleCount = 0;
		editVendorSearchTerm = '';
		editForm = {
			bill_number: record.bill_number || '',
			bill_date: toDateInput(record.bill_date),
			branch_id: record.branch_id != null ? String(record.branch_id) : '',
			vendor_id: record.vendor_id != null ? String(record.vendor_id) : '',
			payment_method: record.payment_method || '',
			credit_period: record.credit_period ?? '',
			due_date: toDateInput(record.due_date),
			bill_amount: record.bill_amount ?? '',
			final_bill_amount: record.final_bill_amount ?? '',
			bank_name: record.bank_name || '',
			iban: record.iban || ''
		};
		showEditPopup = true;
		loadEditVendors(editForm.branch_id);

		// A split payment has several schedule rows; the amount must not be
		// copied onto each of them, so find out how many are linked first.
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('id, is_paid')
				.eq('receiving_record_id', record.id);
			if (!error && data) {
				editScheduleCount = data.filter(s => !s.is_paid).length;
			}
		} catch (err) {
			console.error('Error loading linked payment schedules:', err);
		}
	}

	// Vendors are branch-scoped — reload the pickable list whenever the branch changes, and drop the
	// current selection since a vendor_id from the old branch may not exist for the new one.
	async function loadEditVendors(branchId) {
		editVendorsError = '';
		if (!branchId) { editVendors = []; editVendorsError = 'No branch selected — pick a branch first.'; return; }
		editVendorsLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, vat_number')
				.eq('branch_id', branchId)
				.order('vendor_name');
			if (error) throw error;
			editVendors = data || [];
			if (editVendors.length === 0) editVendorsError = 'No vendors found for this branch.';
		} catch (err) {
			console.error('Error loading vendors for edit popup:', err);
			editVendors = [];
			editVendorsError = `Failed to load vendors: ${err.message || err}`;
		} finally {
			editVendorsLoading = false;
		}
	}

	function onEditBranchChange() {
		if (editForm) editForm.vendor_id = '';
		editVendorSearchTerm = '';
		loadEditVendors(editForm?.branch_id);
	}

	function closeEditPopup() {
		if (savingEdit) return;
		showEditPopup = false;
		editingRecord = null;
		editForm = null;
		editError = '';
	}

	async function saveRecordEdit() {
		if ((!isMasterAdmin && !canEditRecord) || !editingRecord || !editForm) return;

		const billAmount = parseFloat(editForm.bill_amount);
		const finalAmount = parseFloat(editForm.final_bill_amount);

		if (!editForm.bill_number?.trim()) {
			editError = tFn('receiving.records.editBillNumberRequired');
			return;
		}
		if (!editForm.branch_id) {
			editError = tFn('receiving.records.editBranchRequired');
			return;
		}
		if (!editForm.vendor_id) {
			editError = tFn('receiving.records.editVendorRequired');
			return;
		}
		if (isNaN(billAmount) || billAmount < 0 || isNaN(finalAmount) || finalAmount < 0) {
			editError = tFn('receiving.records.editAmountInvalid');
			return;
		}

		try {
			savingEdit = true;
			editError = '';
			const { supabase } = await import('$lib/utils/supabase');

			const creditPeriod = editForm.credit_period === '' ? null : parseInt(editForm.credit_period);
			const selectedVendor = editVendors.find((v) => String(v.erp_vendor_id) === String(editForm.vendor_id));

			const recordUpdate = {
				bill_number: editForm.bill_number.trim(),
				bill_date: editForm.bill_date || null,
				branch_id: editForm.branch_id,
				vendor_id: editForm.vendor_id,
				payment_method: editForm.payment_method || null,
				credit_period: isNaN(creditPeriod) ? null : creditPeriod,
				due_date: editForm.due_date || null,
				bill_amount: billAmount,
				final_bill_amount: finalAmount,
				bank_name: editForm.bank_name?.trim() || null,
				iban: editForm.iban?.trim() || null
			};

			const { error: recordError } = await supabase
				.from('receiving_records')
				.update(recordUpdate)
				.eq('id', editingRecord.id);

			if (recordError) throw recordError;

			// Keep unpaid payment schedules in step with the record. Paid ones are
			// left alone so settled history is not rewritten.
			const scheduleUpdate = {
				bill_number: recordUpdate.bill_number,
				bill_date: recordUpdate.bill_date,
				branch_id: recordUpdate.branch_id,
				vendor_id: recordUpdate.vendor_id,
				vendor_name: selectedVendor?.vendor_name || null,
				vat_number: selectedVendor?.vat_number || null,
				payment_method: recordUpdate.payment_method,
				bank_name: recordUpdate.bank_name,
				iban: recordUpdate.iban
			};

			// Only push the amount down when a single schedule covers the whole
			// bill — with a split the per-row amounts are intentionally different.
			if (editScheduleCount === 1) {
				scheduleUpdate.bill_amount = billAmount;
				scheduleUpdate.final_bill_amount = finalAmount;
			}

			const { error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.update(scheduleUpdate)
				.eq('receiving_record_id', editingRecord.id)
				.eq('is_paid', false);

			if (scheduleError) {
				console.error('Record saved but payment schedule sync failed:', scheduleError);
			}

			// Reflect the change locally without a full reload
			const applyEdit = (r) => (r.id === editingRecord.id ? {
				...r, ...recordUpdate,
				vendors: selectedVendor ? { erp_vendor_id: selectedVendor.erp_vendor_id, vendor_name: selectedVendor.vendor_name, vat_number: selectedVendor.vat_number, branch_id: recordUpdate.branch_id } : r.vendors
			} : r);
			receivingRecords = receivingRecords.map(applyEdit);
			allLoadedRecords = allLoadedRecords.map(applyEdit);
			archivedRecords = archivedRecords.map(applyEdit);
			updatePaginatedRecords();

			showEditPopup = false;
			editingRecord = null;
			editForm = null;
			alert(tFn('receiving.records.editSuccess'));
		} catch (error) {
			console.error('Error updating receiving record:', error);
			editError = tFn('receiving.records.editFailed', { error: error.message });
		} finally {
			savingEdit = false;
		}
	}

	async function deleteReceivingRecord(recordId) {
		if (!isMasterAdmin && !canDeleteRecord) {
			alert(tFn('receiving.records.onlyMasterAdmin'));
			return;
		}

		const record = receivingRecords.find(r => r.id === recordId);
		const confirmMessage = tFn('receiving.records.confirmDelete', {
			bill: record?.bill_number || tFn('receiving.records.naText'),
			vendor: record?.vendors?.vendor_name || tFn('receiving.records.naText')
		});

		if (!confirm(confirmMessage)) {
			return;
		}

		try {
			deletingRecordId = recordId;
			const { supabase } = await import('$lib/utils/supabase');

			const { error } = await supabase
				.from('receiving_records')
				.delete()
				.eq('id', recordId);

			if (error) throw error;

			// Remove from local arrays
			receivingRecords = receivingRecords.filter(r => r.id !== recordId);
			allLoadedRecords = allLoadedRecords.filter(r => r.id !== recordId);
			updatePaginatedRecords();

			alert(tFn('receiving.records.deleteSuccess'));
		} catch (error) {
			console.error('Error deleting receiving record:', error);
			alert(tFn('receiving.records.deleteFailed', { error: error.message }));
		} finally {
			deletingRecordId = null;
		}
	}
</script>

<!-- Receiving Records Window Content -->
<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">

	{#if isMasterAdmin}
		<div class="px-8 pt-6 flex justify-end">
			<button
				type="button"
				on:click={() => (showPermissionsModal = true)}
				class="inline-flex items-center gap-2 px-4 py-2 text-sm font-bold text-white bg-indigo-600 rounded-xl hover:bg-indigo-700 transition-colors"
				title="Manage which users can edit the ERP reference, edit records, or delete records"
			>
				🔐 {$t('receiving.records.editPermissionBtn')}
			</button>
		</div>
	{/if}

	<!-- Filter Controls -->
	<div class="px-8 pt-6">
		<div class="mb-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7 gap-3 items-start">
			<div class="min-w-0">
				<label for="branch-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.dashboard.filterByBranch')}</label>
				<select id="branch-filter" bind:value={selectedBranchFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">{$t('receiving.dashboard.allBranches')}</option>
					{#each branches as branch}
						<option value={branch.id}>
							{$currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}
							-
							{$currentLocale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en}
						</option>
					{/each}
				</select>
			</div>
			<div class="min-w-0">
				<label for="pr-excel-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.prExcelStatus')}</label>
				<select id="pr-excel-filter" bind:value={selectedPrExcelFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">{$t('receiving.records.allRecords')}</option>
					<option value="verified">{$t('receiving.records.verified')}</option>
					<option value="unverified">{$t('receiving.records.unverified')}</option>
				</select>
			</div>
			<div class="min-w-0">
				<label for="vendor-search" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.searchVendor')}</label>
				<input
					id="vendor-search"
					type="text"
					bind:value={vendorSearchTerm}
					on:input={onVendorSearchInput}
					placeholder={$t('receiving.records.typeVendorName')}
					class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all"
				/>
			</div>
			<div class="min-w-0">
				<label for="erp-ref-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.erpInvoiceRef')}</label>
				<select id="erp-ref-filter" bind:value={selectedErpRefFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">{$t('receiving.records.allRecords')}</option>
					<option value="entered">{$t('receiving.records.entered')}</option>
					<option value="not_entered">{$t('receiving.records.notEntered')}</option>
				</select>
			</div>
			<div class="min-w-0">
				<label for="erp-reference-search" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.searchErpReference')}</label>
				<div class="flex gap-2">
					<input
						id="erp-reference-search"
						type="search"
						bind:value={erpReferenceSearchTerm}
						on:keydown={onErpReferenceSearchKeydown}
						placeholder={$t('receiving.records.typeErpReference')}
						class="min-w-0 flex-1 px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all"
					/>
					<button
						type="button"
						on:click={applyErpReferenceSearch}
						disabled={loading}
						class="px-4 py-2.5 text-sm font-bold text-white bg-emerald-600 rounded-xl hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
					>
						{$t('receiving.records.search')}
					</button>
				</div>
			</div>
			<div class="min-w-0">
				<label class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.erpCheckIssuesLabel')}</label>
				<div class="flex gap-2">
					<button
						type="button"
						on:click={() => toggleErpCheckStatusFilter('mismatch')}
						disabled={loading}
						title="Show only rows whose persisted ERP Check is Mismatch"
						class="flex-1 px-3 py-2.5 text-sm font-bold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed {erpCheckStatusFilter === 'mismatch' ? 'text-white bg-amber-500 hover:bg-amber-600' : 'text-amber-700 bg-amber-50 border border-amber-200 hover:bg-amber-100'}"
					>
						⚠️ {erpMismatchCount}
					</button>
					<button
						type="button"
						on:click={() => toggleErpCheckStatusFilter('not_found')}
						disabled={loading}
						title="Show only rows whose persisted ERP Check is Not Found"
						class="flex-1 px-3 py-2.5 text-sm font-bold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed {erpCheckStatusFilter === 'not_found' ? 'text-white bg-red-600 hover:bg-red-700' : 'text-red-700 bg-red-50 border border-red-200 hover:bg-red-100'}"
					>
						⚠️ {erpNotFoundCount}
					</button>
				</div>
			</div>
			<div class="min-w-0">
				<label for="bill-date-mode" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('receiving.records.billDateFilter')}</label>
				<div class="flex gap-2">
					<select id="bill-date-mode" bind:value={billDateFilterMode} on:change={onBillDateModeChange} class="w-full min-w-0 px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none">
						<option value="">{$t('receiving.records.anyDate')}</option>
						<option value="specific">{$t('receiving.records.specificDate')}</option>
						<option value="period">{$t('receiving.records.datePeriod')}</option>
					</select>
					{#if billDateFilterMode}
						<input aria-label={$t('receiving.records.dateFrom')} type="date" bind:value={billDateFrom} class="min-w-0 px-3 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none" />
						{#if billDateFilterMode === 'period'}
							<input aria-label={$t('receiving.records.dateTo')} type="date" bind:value={billDateTo} min={billDateFrom || undefined} class="min-w-0 px-3 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 focus:ring-2 focus:ring-emerald-500 outline-none" />
						{/if}
						<button type="button" on:click={applyBillDateFilter} disabled={loading} class="px-4 py-2.5 text-sm font-bold text-white bg-emerald-600 rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors">{$t('receiving.records.apply')}</button>
					{/if}
				</div>
			</div>
			<div class="min-w-0">
				<label for="due-in-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">{$t('vendorPaymentFilters.dueIn')}</label>
				<select id="due-in-filter" bind:value={selectedDueFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">{$t('vendorPaymentFilters.anyTime')}</option>
					<option value="7">{$t('vendorPaymentFilters.days7')}</option>
					<option value="15">{$t('vendorPaymentFilters.days15')}</option>
					<option value="30">{$t('vendorPaymentFilters.days30')}</option>
				</select>
			</div>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 px-8 pb-6 relative overflow-hidden flex flex-col">
		<!-- Decorative blurred circles -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] pointer-events-none"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col w-full">
			<!-- Table Container (glassmorphism card) -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="spinner"></div>
				<p class="ml-4 text-slate-500">{$t('receiving.records.loadingRecords')}</p>
			</div>
		{:else if paginatedRecords.length === 0}
			<div class="flex items-center justify-center py-20">
				<p class="text-slate-500 text-lg">{$t('receiving.records.noRecordsFound')}</p>
			</div>
		{:else}
			<!-- Table scroll wrapper -->
			<div class="overflow-x-auto flex-1">
				<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
					<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colNo')}</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colCertificate')}</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colOriginalBill')}</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colPrExcel')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colBillInfo')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colVendorDetails')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colBranch')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colPaymentInfo')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colDaysToDue')}</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colAmounts')}</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colErpCheck')}</th>
							{#if isMasterAdmin || canEditRecord || canDeleteRecord}
								<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('receiving.records.colActions')}</th>
							{/if}
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
				
				{#each paginatedRecords as record, index}
					<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
					<td class="px-3 py-3 text-sm text-center font-semibold text-slate-500">
						{index + 1 + (currentPage - 1) * pageSize}
					</td>
					<td class="px-3 py-3 text-sm text-center">
							{#if record.certificate_url}
								<div class="certificate-thumbnail" on:click={() => viewCertificate(record.certificate_url)}>
									<img src={record.certificate_url} alt="Certificate" loading="lazy" />
									<div class="thumbnail-overlay">
										<span>🔍</span>
									</div>
								</div>
							{:else}
								<div class="generate-certificate-container">
									{#if generatingCertificateId === record.id}
										<div class="generating-indicator">
											<div class="spinner-small"></div>
											<small>{$t('receiving.records.generating')}</small>
										</div>
									{:else}
										<button class="generate-certificate-btn" on:click={() => generateCertificate(record)}>
											<span>📜</span>
											<small>{$t('receiving.records.generateCertificate')}</small>
										</button>
									{/if}
								</div>
							{/if}
					</td>
					<td class="px-3 py-3 text-sm text-center">
							{#if record.original_bill_url}
								<div class="original-bill-with-update">
									<div class="certificate-thumbnail" on:click={() => viewOriginalBill(record.original_bill_url)}>
										{#if isPdfFile(record.original_bill_url)}
											<div class="pdf-thumbnail">
												<div class="pdf-icon">📄</div>
												<div class="pdf-label">PDF</div>
											</div>
										{:else}
											<img src={record.original_bill_url} alt="Original Bill" loading="lazy" />
										{/if}
										<div class="thumbnail-overlay">
											<span>🔍</span>
										</div>
									</div>
									<div class="original-bill-actions">
										<div class="update-bill-section">
											{#if updatingBillId === record.id}
												<div class="updating-indicator">
													<div class="spinner-small"></div>
													<small>{$t('receiving.records.updating')}</small>
												</div>
											{:else}
												<button class="update-bill-btn" on:click={() => updateOriginalBill(record.id)} title="Upload updated version">
													<span>🔄</span>
													<small>{$t('receiving.records.update')}</small>
												</button>
											{/if}
										</div>
										<div class="check-bill-section">
											{#if originalBillCheckStatus[record.id] === 'matched'}
												<button
													class="check-bill-btn check-bill-matched"
													on:click={() => openSavedBillCheck(record)}
													title={originalBillCheckResult[record.id]?.manuallyVerified ? 'AI Bill Check: manually verified as matched — click to review' : 'AI Bill Check: everything matched — click to review'}
												>
													<span>✅</span>
													<small>Matched</small>
												</button>
											{:else if originalBillCheckStatus[record.id] === 'mismatch'}
												<button
													class="check-bill-btn check-bill-mismatch"
													on:click={() => openSavedBillCheck(record)}
													title="AI Bill Check: unmatched — click to review (Recheck is inside the popup)"
												>
													<span>⚠️</span>
													<small>Unmatched</small>
												</button>
											{:else}
												<button
													class="check-bill-btn"
													on:click={() => checkOriginalBill(record)}
													disabled={checkingBillId === record.id}
													title="Extract Vendor Name, Bill Amount (incl. VAT) and Bill Date from this document using AI"
												>
													<span>{checkingBillId === record.id ? '⏳' : '🔍✨'}</span>
													<small>Check</small>
												</button>
											{/if}
										</div>
									</div>
								</div>
							{:else}
								<div class="upload-bill-container">
									{#if uploadingBillId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>{$t('receiving.records.uploading')}</small>
										</div>
									{:else}
										<button class="upload-bill-btn" on:click={() => uploadOriginalBill(record.id)}>
											<span>📎</span>
											<small>{$t('receiving.records.originalBillNotUploaded')}</small>
										</button>
									{/if}
								</div>
							{/if}
					</td>
					<td class="px-3 py-3 text-sm text-center">
							{#if record.pr_excel_file_url}
								<div class="excel-file-container">
									<button 
										class="excel-file-link"
										on:click={() => openWindow({
											id: `price-verifier-${record.id}`,
											title: 'Price Verifier',
											component: PriceVerifier,
											props: { record },
											icon: '🔍',
											size: { width: 1000, height: 700 },
											minSize: { width: 600, height: 400 },
											position: { x: 150, y: 100 }
										})}
									>
										<div class="excel-icon">📊</div>
										<small>{$t('receiving.records.prExcelLabel')}</small>
									</button>
									{#if record.pr_excel_verified}
										<span class="text-green-600 text-lg" title="Verified">✓</span>
									{:else}
										<label class="verification-checkbox">
											<input
												type="checkbox"
												checked={false}
												on:change={(e) => handlePRExcelVerification(record.id, e.target.checked)}
											/>
											<span class="checkbox-label">{$t('receiving.records.verify')}</span>
										</label>
									{/if}
									<button class="update-bill-btn" on:click={() => uploadPRExcel(record.id)} title="Upload updated PR Excel">
										<span>🔄</span>
										<small>{$t('receiving.records.update')}</small>
									</button>
								</div>
							{:else}
								<div class="upload-excel-container">
									{#if uploadingExcelId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>{$t('receiving.records.uploading')}</small>
										</div>
									{:else}
										<div class="flex items-center gap-1.5" style="height: 50px;">
											<button class="upload-excel-btn" style="flex: 1; height: 100%;" on:click={() => uploadPRExcel(record.id)}>
												<span>📊</span>
												<small>{$t('receiving.records.upload')}</small>
											</button>
											<button class="upload-excel-btn" style="flex: 1; height: 100%; background: #f0fdf4; border-color: #10b981; color: #047857;" on:click={downloadReceivingTemplate} title="Download empty PR Excel template">
												<span>📥</span>
												<small>{$t('receiving.records.downloadTemplate')}</small>
											</button>
										</div>
									{/if}
								</div>
							{/if}
						</td>
						
						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">#{record.bill_number || $t('receiving.records.naText')}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.billDateLabel')} {formatDate(record.bill_date)}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.receivedLabel')} {formatDate(record.created_at)}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.byLabel')} {getReceivedByName(record, $currentLocale)}</div>
							</div>
						</td>

						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">{record.vendors?.vendor_name || $t('receiving.records.naText')}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.idLabel')} {record.vendors?.erp_vendor_id || $t('receiving.records.naText')}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.vatLabel')} {record.vendors?.vat_number || $t('receiving.records.naText')}</div>
							</div>
						</td>

						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div>{getBranchName(record, $currentLocale)}</div>
								{#if getBranchLocation(record, $currentLocale)}
									<div class="text-xs text-slate-400">{getBranchLocation(record, $currentLocale)}</div>
								{/if}
							</div>
						</td>

						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">{translatePaymentMethod(record.payment_method)}</div>
								<div class="text-xs text-slate-400">{$t('receiving.records.dueLabel')} {formatDate(record.due_date)}</div>
								{#if record.credit_period}
									<div class="text-xs text-slate-400">{$t('receiving.records.daysText', { n: record.credit_period })}</div>
								{/if}
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-left text-slate-700">
							<div>
								{#if record.payment_method?.toLowerCase()?.includes('on delivery') || record.is_paid || record.schedule_status?.is_paid}
									<div class="text-xs text-emerald-600">{$t('receiving.records.paid')}</div>
								{:else if record.is_scheduled || record.schedule_status}
									<div class:text-red-600={record.due_date && getDaysRemaining(record.due_date).includes('-')}>{getDaysRemaining(record.due_date)}</div>
									<div class="text-xs text-blue-600">📅 {record.has_multiple_schedules ? $t('receiving.records.splitScheduled') : $t('receiving.records.scheduled')}</div>
								{:else}
									<div class:text-red-600={record.due_date && getDaysRemaining(record.due_date).includes('-')}>{getDaysRemaining(record.due_date)}</div>
									<button
										class="text-xs text-white bg-orange-500 hover:bg-orange-600 px-2 py-0.5 rounded cursor-pointer border-none transition-colors duration-200"
										title="Schedule payment for this record"
										on:click={() => openWindow({
											id: `manual-scheduling-${Date.now()}`,
											title: 'Manual Scheduling',
											component: ManualScheduling,
											props: {},
											icon: '📅',
											size: { width: 900, height: 650 },
											minSize: { width: 600, height: 400 },
											position: { x: 140, y: 140 }
										})}
									>
										{$t('receiving.records.scheduleBtn')}
									</button>
								{/if}
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-left text-slate-700">
							<div>
								<div>{$t('receiving.records.billLabel')} {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
								<div class="font-bold text-emerald-700">{$t('receiving.records.finalLabel')} {parseFloat(record.final_bill_amount || 0).toFixed(2)}</div>
								{#if record.erp_purchase_invoice_reference}
									{#if canEditErpReference}
										<div
											class="text-xs text-slate-500 cursor-pointer hover:text-emerald-600"
											on:dblclick={() => openErpPopup(record)}
											title="Double-click to edit ERP invoice reference"
										>{$t('receiving.records.erpLabel')} {record.erp_purchase_invoice_reference}</div>
									{:else}
										<div class="text-xs text-slate-500">{$t('receiving.records.erpLabel')} {record.erp_purchase_invoice_reference}</div>
									{/if}
								{:else}
									<button
										class="text-xs text-red-400 hover:text-red-600 cursor-pointer bg-transparent border-none p-0 text-left"
										on:click={() => openErpPopup(record)}
										title="Click to enter ERP invoice reference"
									>
										{$t('receiving.records.erpNotEntered')}
									</button>
								{/if}
							</div>
						</td>

						<td class="px-3 py-3 text-sm text-center">
							{#if !record.erp_purchase_invoice_reference}
								<span class="text-xs text-slate-400">—</span>
							{:else if erpCheckStatus[record.id] === 'checking'}
								<div class="spinner-small mx-auto"></div>
							{:else if erpCheckStatus[record.id] === 'matched'}
								<div class="text-xs text-emerald-600 font-bold">✅ {$t('receiving.records.erpCheckMatched')} <span class="font-semibold text-slate-500">({erpCheckResult[record.id]?.vatStatus || 'No VAT'})</span></div>
								<div class="text-xs text-slate-400" title={`Local: ${erpCheckResult[record.id]?.localVendorName || '-'} / ERP: ${erpCheckResult[record.id]?.partyName || '-'}`}>
									{$t('receiving.records.idLabel')} {erpCheckResult[record.id]?.erpVendorId}{erpCheckResult[record.id]?.vendorMatchedVia === 'name' ? ` (≠ ${erpCheckResult[record.id]?.localVendorId}, matched by name)` : ''}
								</div>
								<div class="text-xs text-slate-500">
									{parseFloat(erpCheckResult[record.id]?.grandTotal || 0).toFixed(2)}{Math.abs(erpCheckResult[record.id]?.amountDiff || 0) < 0.005 ? ' ✓' : ` (Δ ${erpCheckResult[record.id]?.amountDiff > 0 ? '+' : ''}${parseFloat(erpCheckResult[record.id]?.amountDiff || 0).toFixed(2)})`} vs {erpCheckResult[record.id]?.amountSource}
								</div>
								{#if erpCheckResult[record.id]?.candidateCount > 1}
									<div class="text-xs text-slate-400" title="This voucher number has multiple ERP rows (e.g. different counters/VAT forms) — the matching one was picked automatically">{erpCheckResult[record.id]?.candidateCount} vouchers found, best pick used</div>
								{/if}
							{:else if erpCheckStatus[record.id] === 'mismatch'}
								<div class="text-xs text-red-600 font-bold">❌ {$t('receiving.records.erpCheckMismatch')}</div>
								{#if !erpCheckResult[record.id]?.vendorMatches}
									<div class="text-xs text-slate-500" title={`Local: ${erpCheckResult[record.id]?.localVendorName || '-'} / ERP: ${erpCheckResult[record.id]?.partyName || '-'}`}>
										{$t('receiving.records.idLabel')} {erpCheckResult[record.id]?.erpVendorId} ≠ {erpCheckResult[record.id]?.localVendorId} (name also differs)
									</div>
								{/if}
								<div class="text-xs text-slate-500">
									{parseFloat(erpCheckResult[record.id]?.grandTotal || 0).toFixed(2)}{erpCheckResult[record.id]?.amountMatches ? ` ✓ vs ${erpCheckResult[record.id]?.amountSource}` : ` (Δ ${erpCheckResult[record.id]?.amountDiff > 0 ? '+' : ''}${parseFloat(erpCheckResult[record.id]?.amountDiff || 0).toFixed(2)} vs ${erpCheckResult[record.id]?.amountSource})`}
								</div>
								{#if erpCheckResult[record.id]?.candidateCount > 1}
									<div class="text-xs text-slate-400" title="This voucher number has multiple ERP rows (e.g. different counters/VAT forms) — none of them matched">{erpCheckResult[record.id]?.candidateCount} vouchers found, none matched</div>
								{/if}
								<button class="text-xs text-slate-400 underline bg-transparent border-none cursor-pointer" on:click={() => checkErpInvoice(record)}>{$t('receiving.records.erpCheckRecheck')}</button>
							{:else if erpCheckStatus[record.id] === 'not_found'}
								<div class="text-xs text-red-600 font-bold mb-1">❌ {$t('receiving.records.erpCheckNotFound')}</div>
								<button class="text-xs text-slate-400 underline bg-transparent border-none cursor-pointer" on:click={() => checkErpInvoice(record)}>{$t('receiving.records.erpCheckRecheck')}</button>
							{:else if erpCheckStatus[record.id] === 'error'}
								<div class="text-xs text-orange-600 font-bold mb-1" title={erpCheckResult[record.id]?.error || ''}>⚠️ {$t('receiving.records.erpCheckError')}</div>
								<button class="text-xs text-slate-400 underline bg-transparent border-none cursor-pointer" on:click={() => checkErpInvoice(record)}>{$t('receiving.records.erpCheckRecheck')}</button>
							{:else}
								<button
									class="text-xs text-white bg-indigo-600 hover:bg-indigo-700 px-2 py-1 rounded cursor-pointer border-none transition-colors duration-200"
									on:click={() => checkErpInvoice(record)}
									title="Check if this ERP number exists as a Purchase Invoice (PI) with a matching vendor and amount"
								>
									🔍 {$t('receiving.records.erpCheckButton')}
								</button>
							{/if}
						</td>
						
						{#if isMasterAdmin || canEditRecord || canDeleteRecord}
							<td class="px-3 py-3 text-sm text-center">
								{#if deletingRecordId === record.id}
									<div class="deleting-indicator">
										<div class="spinner-small"></div>
										<small>{$t('receiving.records.deleting')}</small>
									</div>
								{:else}
									<div class="inline-flex items-center gap-1.5">
										{#if isMasterAdmin || canEditRecord}
											<button
												class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
												on:click={() => openEditPopup(record)}
												title={$t('receiving.records.editRecordTooltip')}
											>
												✏️
											</button>
										{/if}
										{#if isMasterAdmin || canDeleteRecord}
											<button
												class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
												on:click={() => deleteReceivingRecord(record.id)}
												title="Delete this receiving record"
											>
												🗑️
											</button>
										{/if}
									</div>
								{/if}
							</td>
						{/if}
					</tr>
				{/each}
					</tbody>
				</table>
			</div>
		{/if}

		<!-- Footer -->
		<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold flex items-center justify-between">
			<span>{$t('receiving.records.footerInfo', { total: totalRecords, current: currentPage, pages: totalPages, showing: paginatedRecords.length })}</span>
			{#if totalPages > 1}
				<div class="flex items-center gap-2">
					<button
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage = 1; loading = true; loadPageData(1).then(() => loading = false); }}
						disabled={currentPage <= 1 || loading}
					>{$t('receiving.records.first')}</button>
					<button
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage--; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage <= 1 || loading}
					>{$t('receiving.records.prev')}</button>
					<span class="px-3 py-1.5 text-sm font-bold text-slate-700">{$t('receiving.records.pageOf', { current: currentPage, total: totalPages })}</span>
					<button
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage++; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage >= totalPages || loading}
					>{$t('receiving.records.next')}</button>
					<button
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage = totalPages; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage >= totalPages || loading}
					>{$t('receiving.records.last')}</button>
				</div>
			{/if}
		</div>
			</div>
		</div>
	</div>
</div>

<!-- ERP Invoice Reference Popup -->
{#if showErpPopup}
	<div class="erp-popup-overlay" on:click={closeErpPopup}>
		<div class="erp-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>{$t('receiving.records.enterErpTitle')}</h3>
				<button class="erp-popup-close" on:click={closeErpPopup}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<p>{$t('receiving.records.recordLabel')} {selectedRecord?.bill_number || $t('receiving.records.naText')}</p>
				<p>{$t('receiving.records.vendorLabel')} {selectedRecord?.vendor_name || $t('receiving.records.naText')}</p>
				<div class="erp-input-group">
					<label for="erpRef">{$t('receiving.records.erpRefLabel')}</label>
					<input
						id="erpRef"
						type="text"
						bind:value={erpReferenceValue}
						placeholder={$t('receiving.records.erpRefPlaceholder')}
						class="erp-input"
						disabled={updatingErp}
					/>
				</div>
			</div>
			<div class="erp-popup-actions">
				<button
					class="erp-btn-cancel"
					on:click={closeErpPopup}
					disabled={updatingErp}
				>
					{$t('receiving.records.cancel')}
				</button>
				<button
					class="erp-btn-save"
					on:click={updateErpReference}
					disabled={updatingErp || !erpReferenceValue?.trim()}
				>
					{#if updatingErp}
						<div class="spinner-small"></div>
						{$t('receiving.records.updating')}
					{:else}
						{$t('receiving.records.saveReference')}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Permission Popup (Master Admin only) -->
<ReceivingRecordsPermissionsModal bind:show={showPermissionsModal} on:close={() => (showPermissionsModal = false)} />

<!-- Edit Record Popup (Master Admin only) -->
{#if showEditPopup && editForm}
	<div class="erp-popup-overlay" on:click={closeEditPopup}>
		<div class="erp-popup-modal edit-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>{$t('receiving.records.editRecordTitle')}</h3>
				<button class="erp-popup-close" on:click={closeEditPopup}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<div class="edit-section-title">{$t('receiving.records.colVendorDetails')}</div>
				<div class="erp-input-group">
					<label>{$t('receiving.records.editVendor')}</label>
					{#if editSelectedVendorInfo}
						<div class="edit-vendor-card">
							<div>
								<div class="edit-vendor-card-name">{editSelectedVendorInfo.vendor_name || $t('receiving.records.naText')}</div>
								<div class="edit-vendor-card-meta">{$t('receiving.records.idLabel')} {editSelectedVendorInfo.erp_vendor_id} · {$t('receiving.records.vatLabel')} {editSelectedVendorInfo.vat_number || $t('receiving.records.naText')}</div>
							</div>
						</div>
					{:else}
						<div class="edit-vendor-card edit-vendor-card-empty">{$t('receiving.records.naText')}</div>
					{/if}
					<input
						id="edit-vendor-search"
						type="text"
						class="erp-input"
						style="margin-top: 8px;"
						bind:value={editVendorSearchTerm}
						placeholder={$t('receiving.records.typeVendorName')}
						disabled={savingEdit}
					/>
					{#if editVendorsLoading}
						<div class="text-xs text-slate-400" style="margin-top: 4px;">Loading vendors…</div>
					{:else if editVendorsError}
						<div class="text-xs text-red-500" style="margin-top: 4px;">{editVendorsError}</div>
					{:else if editVendorSearchTerm.trim()}
						<div class="edit-vendor-results">
							<table class="edit-vendor-results-table">
								<thead>
									<tr>
										<th>{$t('receiving.records.editVendor')}</th>
										<th>{$t('receiving.records.idLabel')}</th>
										<th>{$t('receiving.records.vatLabel')}</th>
									</tr>
								</thead>
								<tbody>
									{#each editSearchResults as v}
										<tr class="edit-vendor-result-row" on:click={() => selectEditVendor(v)}>
											<td>{v.vendor_name}</td>
											<td>{v.erp_vendor_id}</td>
											<td>{v.vat_number || $t('receiving.records.naText')}</td>
										</tr>
									{:else}
										<tr><td colspan="3" class="edit-vendor-no-results">{$t('receiving.records.naText')}</td></tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				</div>

				<div class="edit-section-title">{$t('receiving.records.colBillInfo')}</div>
				<div class="edit-grid">
					<div class="erp-input-group">
						<label for="edit-bill-number">{$t('receiving.records.editBillNumber')}</label>
						<input id="edit-bill-number" type="text" class="erp-input" bind:value={editForm.bill_number} disabled={savingEdit} />
					</div>
					<div class="erp-input-group">
						<label for="edit-bill-date">{$t('receiving.records.editBillDate')}</label>
						<input id="edit-bill-date" type="date" class="erp-input" bind:value={editForm.bill_date} disabled={savingEdit} />
					</div>
				</div>

				<div class="edit-section-title">{$t('receiving.records.colBranch')}</div>
				<div class="erp-input-group">
					<label for="edit-branch">{$t('receiving.records.editBranch')}</label>
					<select id="edit-branch" class="erp-input" bind:value={editForm.branch_id} on:change={onEditBranchChange} disabled={savingEdit}>
						{#each branches as branch}
							<option value={String(branch.id)}>
								{$currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}
								{#if branch.location_en} - {$currentLocale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en}{/if}
							</option>
						{/each}
					</select>
				</div>

				<div class="edit-section-title">{$t('receiving.records.colPaymentInfo')}</div>
				<div class="edit-grid">
					<div class="erp-input-group">
						<label for="edit-payment-method">{$t('receiving.records.editPaymentMethod')}</label>
						<select id="edit-payment-method" class="erp-input" bind:value={editForm.payment_method} disabled={savingEdit}>
							<option value="">{$t('receiving.records.naText')}</option>
							{#each PAYMENT_METHODS as method}
								<option value={method}>{translatePaymentMethod(method)}</option>
							{/each}
						</select>
					</div>
					<div class="erp-input-group">
						<label for="edit-credit-period">{$t('receiving.records.editCreditPeriod')}</label>
						<input id="edit-credit-period" type="number" min="0" class="erp-input" bind:value={editForm.credit_period} disabled={savingEdit} />
					</div>
					<div class="erp-input-group">
						<label for="edit-due-date">{$t('receiving.records.editDueDate')}</label>
						<input id="edit-due-date" type="date" class="erp-input" bind:value={editForm.due_date} disabled={savingEdit} />
					</div>
					<div class="erp-input-group">
						<label for="edit-bank-name">{$t('receiving.records.editBankName')}</label>
						<input id="edit-bank-name" type="text" class="erp-input" bind:value={editForm.bank_name} disabled={savingEdit} />
					</div>
					<div class="erp-input-group edit-span-2">
						<label for="edit-iban">{$t('receiving.records.editIban')}</label>
						<input id="edit-iban" type="text" class="erp-input" bind:value={editForm.iban} disabled={savingEdit} />
					</div>
				</div>

				<div class="edit-section-title">{$t('receiving.records.colAmounts')}</div>
				<div class="edit-grid">
					<div class="erp-input-group">
						<label for="edit-bill-amount">{$t('receiving.records.editBillAmount')}</label>
						<input id="edit-bill-amount" type="number" step="0.01" min="0" class="erp-input" bind:value={editForm.bill_amount} disabled={savingEdit} />
					</div>
					<div class="erp-input-group">
						<label for="edit-final-amount">{$t('receiving.records.editFinalAmount')}</label>
						<input id="edit-final-amount" type="number" step="0.01" min="0" class="erp-input" bind:value={editForm.final_bill_amount} disabled={savingEdit} />
					</div>
				</div>

				{#if editScheduleCount > 1}
					<div class="edit-note">{$t('receiving.records.editSplitNote')}</div>
				{:else if editScheduleCount === 0}
					<div class="edit-note">{$t('receiving.records.editNoScheduleNote')}</div>
				{/if}

				{#if editError}
					<div class="edit-error">{editError}</div>
				{/if}
			</div>
			<div class="erp-popup-actions">
				<button class="erp-btn-cancel" on:click={closeEditPopup} disabled={savingEdit}>
					{$t('receiving.records.cancel')}
				</button>
				<button class="erp-btn-save" on:click={saveRecordEdit} disabled={savingEdit}>
					{#if savingEdit}
						<div class="spinner-small"></div>
						{$t('receiving.records.updating')}
					{:else}
						{$t('receiving.records.editSave')}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Certificate Generation Modal -->
{#if showCertificateModal && selectedRecordForCertificate}
	<ClearanceCertificateManager
		receivingRecord={selectedRecordForCertificate}
		show={true}
		on:certificateGenerated={handleCertificateGenerated}
		on:close={closeCertificateModal}
	/>
{/if}

<!-- AI Original Bill Check Popup — AI extracts the document's values and judges the match itself -->
{#if showBillCheckModal && billCheckResult}
	{@const aiAllMatch = billCheckResult.vendorMatches === true && billCheckResult.billAmountMatches === true && billCheckResult.billDateMatches === true}
	{@const vendorNameMismatchOnly = billCheckResult.vendorMatches === true && billCheckResult.vendorNameMatches === false}
	{@const rechecking = checkingBillId === billCheckRecord?.id}
	<div class="erp-popup-overlay" on:click={closeBillCheckModal}>
		<div class="erp-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>🔍✨ AI Bill Check{#if billCheckRecord}&nbsp;— #{billCheckRecord.bill_number || $t('receiving.records.naText')}{/if}</h3>
				<button class="erp-popup-close" on:click={closeBillCheckModal}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<p style="font-size: 12px; color: #6b7280; margin-top: -4px;">Extracted directly from the Original Bill document by AI, which also judges whether each value matches what's already on file. The vendor is verified by VAT Number — a matching VAT number is enough even if the Vendor Name is worded differently. Press Done to save this result.</p>
				{#if billCheckResult.manuallyVerified}
					<p style="font-size: 12px; color: #065f46; background: #d1fae5; border: 1px solid #10b981; border-radius: 6px; padding: 6px 10px; margin: 0;">
						✅ Manually verified{#if billCheckResult.manuallyVerifiedBy} by {billCheckResult.manuallyVerifiedBy}{/if}{#if billCheckResult.manuallyVerifiedAt} on {formatDate(billCheckResult.manuallyVerifiedAt)}{/if} — treated as Matched despite the AI mismatch below.
					</p>
				{/if}
				<div class="erp-input-group">
					<label>Vendor Name</label>
					<p style="font-weight: 700; font-size: 15px; margin: 4px 0 0;">{billCheckResult.vendorName || '—'}</p>
					<p style="font-size: 12px; color: #9ca3af; margin: 2px 0 0;">
						{#if billCheckResult.vendorNameMatches === true}✅{:else if vendorNameMismatchOnly}⚠️{:else if billCheckResult.vendorNameMatches === false}❌{/if}
						Receiving Record: {billCheckRecord?.vendors?.vendor_name || $t('receiving.records.naText')}
					</p>
					{#if vendorNameMismatchOnly}
						<p style="font-size: 12px; color: #b45309; background: #fffbeb; border: 1px solid #fde68a; border-radius: 6px; padding: 4px 8px; margin: 4px 0 0;">
							⚠️ Vendor Name does not match exactly — VAT number matched, so the vendor is still treated as Matched. Please review the name difference.
						</p>
					{/if}
				</div>
				<div class="erp-input-group">
					<label>Vendor VAT Number</label>
					<p style="font-weight: 700; font-size: 15px; margin: 4px 0 0;">{billCheckResult.vendorVatNumber || '—'}</p>
					<p style="font-size: 12px; color: #9ca3af; margin: 2px 0 0;">
						{#if billCheckResult.vendorVatMatches === true}✅{:else if billCheckResult.vendorVatMatches === false}❌{/if}
						Receiving Record: {billCheckRecord?.vendors?.vat_number || $t('receiving.records.naText')}
					</p>
				</div>
				<div class="erp-input-group">
					<label>Bill Amount (incl. VAT)</label>
					<p style="font-weight: 700; font-size: 15px; margin: 4px 0 0;">{billCheckResult.billAmountIncludingVat || '—'}</p>
					<p style="font-size: 12px; color: #9ca3af; margin: 2px 0 0;">
						{#if billCheckResult.billAmountMatches === true}✅{:else if billCheckResult.billAmountMatches === false}❌{/if}
						Receiving Record: {parseFloat(billCheckRecord?.final_bill_amount ?? billCheckRecord?.bill_amount ?? 0).toFixed(2)}
					</p>
				</div>
				<div class="erp-input-group">
					<label>Bill Date</label>
					<p style="font-weight: 700; font-size: 15px; margin: 4px 0 0;">{billCheckResult.billDate || '—'}</p>
					<p style="font-size: 12px; color: #9ca3af; margin: 2px 0 0;">
						{#if billCheckResult.billDateMatches === true}✅{:else if billCheckResult.billDateMatches === false}❌{/if}
						Receiving Record: {formatDate(billCheckRecord?.bill_date)}
					</p>
				</div>
				{#if !aiAllMatch}
					<div class="erp-input-group manual-verify-box">
						<label style="display: flex; align-items: flex-start; gap: 8px; cursor: pointer; font-weight: 600; color: #9a3412;">
							<input type="checkbox" bind:checked={manualVerified} style="margin-top: 2px;" />
							<span>Manual Verification — I've reviewed the bill myself and confirm the information above is correct despite the AI mismatch. Pressing Done will mark this record as Matched.</span>
						</label>
					</div>
				{/if}
			</div>
			<div class="erp-popup-actions">
				<button class="erp-btn-cancel" on:click={closeBillCheckModal} disabled={savingBillCheck || rechecking}>{$t('receiving.records.cancel')}</button>
				<button class="erp-btn-cancel" on:click={() => checkOriginalBill(billCheckRecord)} disabled={savingBillCheck || rechecking} title="Run the AI check again and auto-save the new result">
					{#if rechecking}
						<div class="spinner-small"></div>
						Rechecking…
					{:else}
						🔄 Recheck
					{/if}
				</button>
				<button class="erp-btn-save" on:click={saveBillCheckResult} disabled={savingBillCheck || rechecking}>
					{#if savingBillCheck}
						<div class="spinner-small"></div>
						{$t('receiving.records.updating')}
					{:else}
						Done
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	/* Spinner animations */
	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-left: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Certificate styles */
	.certificate-thumbnail {
		width: 80px;
		height: 60px;
		border-radius: 8px;
		overflow: hidden;
		cursor: pointer;
		position: relative;
		border: 2px solid #e2e8f0;
		transition: all 0.2s ease;
	}

	.certificate-thumbnail:hover {
		border-color: #3b82f6;
		transform: scale(1.05);
	}

	.certificate-thumbnail img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumbnail-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
		font-size: 20px;
	}

	.certificate-thumbnail:hover .thumbnail-overlay {
		opacity: 1;
	}

	.generate-certificate-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.generate-certificate-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0f9ff;
		border: 2px dashed #3b82f6;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #1d4ed8;
		font-size: 10px;
		padding: 4px;
	}

	.generate-certificate-btn:hover {
		background: #dbeafe;
		border-color: #2563eb;
		color: #1e40af;
		transform: scale(1.02);
	}

	.generate-certificate-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	.generating-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
		font-size: 10px;
	}

	.deleting-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		color: #6b7280;
		font-size: 9px;
		min-width: 50px;
	}

	/* ERP Popup Styles */
	.erp-popup-overlay {
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

	.erp-popup-modal {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow: hidden;
	}

	.erp-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.erp-popup-header h3 {
		margin: 0;
		color: #111827;
		font-size: 18px;
		font-weight: 600;
	}

	.erp-popup-close {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.erp-popup-close:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.erp-popup-content {
		padding: 24px;
	}

	.erp-popup-content p {
		margin: 0 0 16px 0;
		color: #6b7280;
		font-size: 14px;
	}

	.erp-input-group {
		margin-top: 20px;
	}

	.erp-input-group label {
		display: block;
		margin-bottom: 8px;
		color: #374151;
		font-weight: 500;
		font-size: 14px;
	}

	.manual-verify-box {
		background: #fff7ed;
		border: 1px solid #fed7aa;
		border-radius: 8px;
		padding: 10px 12px;
	}

	.manual-verify-box label {
		margin-bottom: 0;
		font-size: 13px;
	}

	.erp-input {
		width: 100%;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.2s ease;
		box-sizing: border-box;
	}

	.erp-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.erp-input:disabled {
		background: #f9fafb;
		color: #6b7280;
		cursor: not-allowed;
	}

	.erp-popup-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	/* Edit Record popup - wider, scrollable, two-column form */
	.edit-popup-modal {
		max-width: 640px;
	}

	.edit-popup-modal .erp-popup-content {
		max-height: 62vh;
		overflow-y: auto;
	}

	.edit-section-title {
		margin-top: 20px;
		padding-bottom: 6px;
		border-bottom: 1px solid #e5e7eb;
		color: #047857;
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.edit-grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 0 16px;
	}

	.edit-span-2 {
		grid-column: 1 / -1;
	}

	.edit-vendor-card {
		display: flex;
		align-items: center;
		padding: 10px 14px;
		border: 1px solid #a7f3d0;
		border-radius: 8px;
		background: #ecfdf5;
	}

	.edit-vendor-card-empty {
		color: #9ca3af;
		font-style: italic;
	}

	.edit-vendor-card-name {
		font-weight: 700;
		color: #065f46;
		font-size: 14px;
	}

	.edit-vendor-card-meta {
		margin-top: 2px;
		font-size: 12px;
		color: #6b7280;
	}

	.edit-vendor-results {
		margin-top: 8px;
		max-height: 220px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.edit-vendor-results-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.edit-vendor-results-table thead th {
		position: sticky;
		top: 0;
		background: #f3f4f6;
		text-align: left;
		padding: 8px 10px;
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		color: #6b7280;
		border-bottom: 1px solid #e5e7eb;
	}

	.edit-vendor-result-row {
		cursor: pointer;
		border-bottom: 1px solid #f3f4f6;
	}

	.edit-vendor-result-row:hover {
		background: #eff6ff;
	}

	.edit-vendor-result-row td {
		padding: 8px 10px;
	}

	.edit-vendor-no-results {
		padding: 12px;
		text-align: center;
		color: #9ca3af;
	}

	.edit-note {
		margin-top: 16px;
		padding: 10px 12px;
		border-radius: 8px;
		background: #fffbeb;
		border: 1px solid #fde68a;
		color: #92400e;
		font-size: 13px;
	}

	.edit-error {
		margin-top: 16px;
		padding: 10px 12px;
		border-radius: 8px;
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #b91c1c;
		font-size: 13px;
	}

	.erp-btn-cancel,
	.erp-btn-save {
		padding: 10px 20px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: 1px solid;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.erp-btn-cancel {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.erp-btn-cancel:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.erp-btn-save {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.erp-btn-save:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.erp-btn-save:disabled,
	.erp-btn-cancel:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.upload-bill-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.upload-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f8fafc;
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #6b7280;
		font-size: 12px;
		padding: 4px;
	}

	.upload-bill-btn:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
		color: #3b82f6;
		transform: scale(1.02);
	}

	.upload-bill-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	/* Original Bill with Update Button Styles */
	.original-bill-with-update {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 8px;
		width: 100%;
		justify-content: space-between;
	}

	.original-bill-actions {
		display: flex;
		flex-direction: column;
		gap: 4px;
		flex-shrink: 0;
	}

	.update-bill-section {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.update-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #fef3c7;
		border: 1px solid #f59e0b;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #92400e;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	.update-bill-btn:hover {
		background: #fbbf24;
		color: #78350f;
		transform: scale(1.05);
		border-color: #d97706;
	}

	.update-bill-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.check-bill-section {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.check-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #ede9fe;
		border: 1px solid #8b5cf6;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #5b21b6;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	.check-bill-btn:hover:not(:disabled) {
		background: #ddd6fe;
		color: #4c1d95;
		transform: scale(1.05);
		border-color: #7c3aed;
	}

	.check-bill-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.check-bill-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.check-bill-btn.check-bill-matched {
		background: #d1fae5;
		border-color: #10b981;
		color: #065f46;
	}

	.check-bill-btn.check-bill-matched:hover:not(:disabled) {
		background: #a7f3d0;
		color: #064e3b;
		border-color: #059669;
	}

	.check-bill-btn.check-bill-mismatch {
		background: #fee2e2;
		border-color: #ef4444;
		color: #991b1b;
	}

	.check-bill-btn.check-bill-mismatch:hover:not(:disabled) {
		background: #fecaca;
		color: #7f1d1d;
		border-color: #dc2626;
	}

	.updating-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		color: #6b7280;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	/* PR Excel Upload Styles */
	.upload-excel-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 50px;
	}

	.upload-excel-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 50px;
		background: #f0f9ff;
		border: 2px dashed #0ea5e9;
		border-radius: 6px;
		color: #0369a1;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
	}

	.upload-excel-btn:hover {
		background: #e0f2fe;
		border-color: #0284c7;
		transform: scale(1.02);
	}

	.upload-excel-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.excel-file-container {
		display: flex;
		flex-direction: row;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 50px;
		gap: 6px;
	}

	.verification-checkbox {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		padding: 0.25rem 0.5rem;
		background: #f8fafc;
		border: 1px solid #cbd5e1;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.verification-checkbox:hover {
		background: #f1f5f9;
		border-color: #94a3b8;
	}

	.verification-checkbox input[type="checkbox"] {
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.verification-checkbox input[type="checkbox"]:checked + .checkbox-label {
		color: #16a34a;
		font-weight: 600;
	}

	.checkbox-label {
		font-size: 0.75rem;
		color: #475569;
		user-select: none;
	}

	.excel-file-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 50px;
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 6px;
		color: #15803d;
		text-decoration: none;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px 8px;
		cursor: pointer;
	}

	.excel-file-link:hover {
		background: #dcfce7;
		border-color: #16a34a;
		transform: scale(1.02);
	}

	.excel-icon {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.uploading-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
		font-size: 10px;
	}

	.spinner-small {
		width: 16px;
		height: 16px;
		border: 2px solid #fde68a;
		border-left: 2px solid #f59e0b;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 2px;
	}

	.pdf-thumbnail {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border-radius: 6px;
		position: relative;
	}

	.pdf-icon {
		font-size: 24px;
		margin-bottom: 2px;
	}

	.pdf-label {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.5px;
	}

</style>





