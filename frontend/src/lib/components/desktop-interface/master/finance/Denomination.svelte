<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CompleteBox from './CompleteBox.svelte';
	import ClosedBoxes from './ClosedBoxes.svelte';
	import PendingToCloseBoxes from './PendingToCloseBoxes.svelte';
	import type { RealtimeChannel } from '@supabase/supabase-js';

	// State variables
	let isLoading = true;
	let branches: any[] = [];
	let selectedBranch = '';
	let defaultBranchId: number | null = null;
	let isSavingDefault = false;
	let showDefaultSaved = false;
	let isSaving = false;
	let lastSaved: Date | null = null;
	let autoSaveTimeout: ReturnType<typeof setTimeout> | null = null;

	// Realtime channel
	let realtimeChannel: RealtimeChannel | null = null;

	// Record IDs for updates
	let mainRecordId: string | null = null;
	let boxRecordIds: (string | null)[] = Array(12).fill(null);

	// Box operations tracking
	let boxOperations: Map<number, any> = new Map();
	let closedBoxesCount: number = 0;
	let pendingBoxesCount: number = 0;
	let totalAdvanceBoxIssued: number = 0;

	// Modal state variables
	let showVendorModal = false;
	let showExpensesModal = false;
	let showUserModal = false;
	let showOtherModal = false;
	let currentSection: 'paid' | 'received' = 'paid';

	// Modal form state
	let vendorSearch = '';
	let requesterSearch = '';
	let userSearch = '';
	let selectedVendor: any = null;
	let selectedRequester: any = null;
	let selectedUser: any = null;
	let modalAmount = 0;
	let modalRemarks = '';
	let applyDenomination = false;
	let modalDenominationCounts: any = {};
	let particulars = '';

	// Petty Cash Box state
	let showPettyCashForm = false;
	let pettyCashBoxNumber = '';
	let pettyCashBoxId = ''; // Store the record ID for updates
	let pettyCashCounts: any = {};
	let pettyCashNotes = '';
	let pettyCashTotal = 0; // Reactive total display
	let pettyCashBalance = 0; // Current balance to display on button
	let isSavingPettyCash = false;

	// Reactive total calculation
	$: pettyCashTotal = calculatePettyCashTotal();

	// Data for dropdowns
	let vendors: any[] = [];
	let requesters: any[] = [];
	let users: any[] = [];
	let savedTransactions: any[] = [];

	// Delete confirmation popup
	let showDeleteConfirmPopup = false;
	let deleteConfirmTransactionId = '';

	// Success/Error popup
	let showSuccessPopup = false;
	let successMessage = '';
	let successType: 'success' | 'error' = 'success';
	let successTimeout: ReturnType<typeof setTimeout> | null = null;

	// Sidebar state
	let isSidebarOpen = true;

	onMount(async () => {
		await loadBranches();
		await loadUserPreferences();
		await loadDenominationTypes();
		await loadClosedBoxesCount();
		await loadPendingBoxesCount();
		isLoading = false;
		
		// Setup realtime subscription after branch is selected
		if (selectedBranch) {
			await loadExistingRecords();
			await fetchBoxOperations();
			setupRealtimeSubscription();
		}
	});

	onDestroy(() => {
		// Cleanup realtime subscription
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}
		// Clear any pending auto-save
		if (autoSaveTimeout) {
			clearTimeout(autoSaveTimeout);
		}
	});

	// Watch for branch changes
	let previousBranch = '';
	$: if (selectedBranch && selectedBranch !== previousBranch && !isLoading) {
		previousBranch = selectedBranch;
		handleBranchChange();
	}

	// Helper function to get display name for box number
	function getBoxDisplayName(boxNum: number): string {
		if (boxNum === 10) return 'E1';
		if (boxNum === 11) return 'E2';
		if (boxNum === 12) return 'E3';
		return `BOX ${boxNum}`;
	}

	async function handleBranchChange() {
		// Reset all data first
		resetCounts();
		cashBoxData = Array.from({ length: 12 }, () => ({
			'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
			'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
			'd025': 0, 'coins': 0, 'damage': 0
		}));
		mainRecordId = null;
		boxRecordIds = Array(12).fill(null);
		lastSaved = null;
		pettyCashBoxId = ''; // Reset petty cash box ID
		
		// Load data for new branch
		await loadExistingRecords();
		await fetchBoxOperations();
		await loadOrCreatePettyCashBox();
		await loadSavedTransactions();
		setupRealtimeSubscription();
	}

	async function loadDenominationTypes() {
		try {
			const { data, error } = await supabase
				.from('denomination_types')
				.select('*')
				.eq('is_active', true)
				.order('sort_order');

			if (error) {
				console.error('Error loading denomination types:', error);
				return;
			}

			// Update denomValues and denomLabels from database
			if (data && data.length > 0) {
				data.forEach((type: any) => {
					denomValues[type.code] = type.value;
					denomLabels[type.code] = type.label;
				});
			}
		} catch (error) {
			console.error('Error loading denomination types:', error);
		}
	}

	async function loadOrCreatePettyCashBox() {
		console.log('💼 Loading or creating petty cash box for branch:', selectedBranch);
		
		if (!selectedBranch || !$currentUser?.id) {
			console.log('⚠️ Cannot load petty cash box - missing branch or user');
			return;
		}

		try {
			// Check if petty cash box already exists for this branch
			const { data: existingBox, error: fetchError } = await supabase
				.from('denomination_records')
				.select('id, box_number, counts, grand_total')
				.eq('branch_id', parseInt(selectedBranch))
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1);

			if (fetchError) {
				console.error('❌ Error fetching existing petty cash box:', fetchError);
				return;
			}

			if (existingBox && existingBox.length > 0) {
				// Load existing box
				console.log('📦 Found existing petty cash box:', existingBox[0]);
				pettyCashBoxId = existingBox[0].id;
				pettyCashBoxNumber = String(existingBox[0].box_number);
				
				// Parse counts if it's a string
				let parsedCounts = existingBox[0].counts;
				if (typeof parsedCounts === 'string') {
					try {
						parsedCounts = JSON.parse(parsedCounts);
					} catch (e) {
						console.warn('⚠️ Could not parse counts:', e);
						parsedCounts = {};
					}
				}
				
				pettyCashCounts = parsedCounts || {};
				pettyCashTotal = existingBox[0].grand_total || 0;
				pettyCashBalance = existingBox[0].grand_total || 0;
				console.log('✅ Loaded existing counts:', pettyCashCounts, 'Total:', pettyCashTotal);
			} else {
				// Create new petty cash box
				console.log('✨ Creating new petty cash box...');
				const nextBoxNum = await getNextBoxNumber();
				
				const initialCounts = Object.keys(denomLabels).reduce((acc: any, key: string) => {
					acc[key] = 0;
					return acc;
				}, {});

				const { data: newBox, error: insertError } = await supabase
					.from('denomination_records')
					.insert({
						branch_id: parseInt(selectedBranch),
						user_id: $currentUser.id,
						record_type: 'petty_cash_box',
						box_number: nextBoxNum,
						counts: initialCounts,
						grand_total: 0,
						notes: null
					})
					.select('id')
					.single();

				if (insertError) {
					console.error('❌ Error creating petty cash box:', insertError);
					return;
				}

				if (newBox) {
					pettyCashBoxId = newBox.id;
					pettyCashBoxNumber = String(nextBoxNum);
					pettyCashCounts = initialCounts;
					pettyCashTotal = 0;
					console.log('✅ New petty cash box created with ID:', newBox.id);
				}
			}
		} catch (error) {
			console.error('❌ Error in loadOrCreatePettyCashBox:', error);
		}
	}

	async function loadExistingRecords() {
		if (!selectedBranch) return;

		try {
			// Load main denomination record (most recent)
			const { data: mainData, error: mainError } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', parseInt(selectedBranch))
				.eq('record_type', 'main')
				.order('created_at', { ascending: false })
				.limit(1)
				.maybeSingle();

			if (!mainError && mainData) {
				mainRecordId = mainData.id;
				counts = mainData.counts || counts;
				erpBalance = mainData.erp_balance || '';
				counts = { ...counts }; // Trigger reactivity
			} else {
				// Reset if no record found
				mainRecordId = null;
				resetCounts();
			}

			// Load box records (most recent for each box)
			const { data: boxData, error: boxError } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', parseInt(selectedBranch))
				.eq('record_type', 'advance_box')
				.order('created_at', { ascending: false });

			if (!boxError && boxData) {
				// Reset box data first
			cashBoxData = Array.from({ length: 12 }, () => ({
				'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
				'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
				'd025': 0, 'coins': 0, 'damage': 0
			}));
			boxRecordIds = Array(12).fill(null);
				const seenBoxes = new Set<number>();
				boxData.forEach((record: any) => {
					const boxIndex = record.box_number - 1;
					if (!seenBoxes.has(boxIndex) && boxIndex >= 0 && boxIndex < 9) {
						seenBoxes.add(boxIndex);
						boxRecordIds[boxIndex] = record.id;
						cashBoxData[boxIndex] = record.counts || cashBoxData[boxIndex];
					}
				});
				cashBoxData = [...cashBoxData]; // Trigger reactivity
			}
		} catch (error) {
			console.error('Error loading existing records:', error);
		}
	}

	function resetCounts() {
		counts = {
			'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
			'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
			'd025': 0, 'coins': 0, 'damage': 0
		};
		erpBalance = '';
	}

	function setupRealtimeSubscription() {
		// Remove and unsubscribe from existing subscription
		if (realtimeChannel) {
			console.log('🧹 Cleaning up old realtime subscription');
			realtimeChannel.unsubscribe();
			realtimeChannel = null;
		}

		if (!selectedBranch) {
			console.log('⚠️ No branch selected, skipping realtime setup');
			return;
		}

		console.log('🔌 Setting up realtime subscription for branch:', selectedBranch);

		realtimeChannel = supabase
			.channel(`denomination-${selectedBranch}-${Date.now()}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_records',
					filter: `branch_id=eq.${selectedBranch}`
				},
				(payload) => {
					console.log('📡 Denomination records realtime update:', payload);
					handleRealtimeUpdate(payload);
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_transactions',
					filter: `branch_id=eq.${selectedBranch}`
				},
				async (payload) => {
					console.log('📡 Denomination transactions realtime update:', payload);
					await loadSavedTransactions();
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations',
					filter: `branch_id=eq.${selectedBranch}`
				},
				async (payload) => {
					console.log('📡 Box operations realtime update:', payload);
					await fetchBoxOperations();
					
					// Update completed operations count if status changed to/from completed
					const newRecord = payload.new;
					const oldRecord = payload.old;
					if (newRecord?.status === 'completed' || oldRecord?.status === 'completed') {
						await loadClosedBoxesCount();
					}
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations',
					filter: `status=eq.completed`
				},
				async (payload) => {
					console.log('📡 Completed box operations update:', payload);
					await loadClosedBoxesCount();
				}
			)
			.subscribe((status) => {
				console.log('📡 Realtime subscription status:', status);
			});
	}

	async function handleRealtimeUpdate(payload: any) {
		const { eventType, new: newRecord, old: oldRecord } = payload;

		console.log('📡 Realtime denomination update:', eventType, newRecord);

		if (eventType === 'INSERT' || eventType === 'UPDATE') {
			if (newRecord.record_type === 'main') {
				console.log('🔄 Updating main denomination record');
				mainRecordId = newRecord.id;
				counts = newRecord.counts || counts;
				erpBalance = newRecord.erp_balance || '';
				counts = { ...counts };
			} else if (newRecord.record_type === 'advance_box') {
				const boxIndex = newRecord.box_number - 1;
				console.log('🔄 Updating advance box:', newRecord.box_number);
				if (boxIndex >= 0 && boxIndex < 9) {
					boxRecordIds[boxIndex] = newRecord.id;
					cashBoxData[boxIndex] = newRecord.counts || cashBoxData[boxIndex];
					cashBoxData = [...cashBoxData];
				}
				// Recalculate total advance box issued amount
				await fetchAdvanceBoxTotal();
			} else if (newRecord.record_type === 'petty_cash_box') {
				console.log('🔄 Updating petty cash box - ID:', newRecord.id, 'Counts:', newRecord.counts);
				if (pettyCashBoxId === newRecord.id) {
					// Update balance display always
					pettyCashBalance = newRecord.grand_total || 0;
					
					// Update petty cash form if it's open
					if (showPettyCashForm) {
						pettyCashCounts = newRecord.counts || pettyCashCounts;
						pettyCashCounts = { ...pettyCashCounts };
						pettyCashTotal = newRecord.grand_total || calculatePettyCashTotal();
						pettyCashNotes = newRecord.notes || '';
						console.log('✅ Petty cash form updated from realtime');
					}
				}
			}
		} else if (eventType === 'DELETE') {
			// Handle deletion if needed
			console.log('🗑️ Record deleted:', oldRecord);
			
			// If an advance box was deleted, recalculate the total
			if (oldRecord?.record_type === 'advance_box') {
				await fetchAdvanceBoxTotal();
			}
		}
	}

	// Auto-save with debounce
	function triggerAutoSave() {
		if (autoSaveTimeout) {
			clearTimeout(autoSaveTimeout);
		}
		autoSaveTimeout = setTimeout(() => {
			saveMainDenomination();
		}, 1500); // Save after 1.5 seconds of inactivity
	}

	async function saveMainDenomination() {
		if (!selectedBranch || !$currentUser?.id) return;

		isSaving = true;
		try {
			const recordData = {
				branch_id: parseInt(selectedBranch),
				user_id: $currentUser.id,
				record_type: 'main',
				box_number: null,
				counts: counts,
				erp_balance: erpBalanceNumber || null,
				grand_total: grandTotal,
				difference: difference
			};

			if (mainRecordId) {
				// Update existing record
				const { error } = await supabase
					.from('denomination_records')
					.update(recordData)
					.eq('id', mainRecordId);

				if (error) {
					console.error('Error updating main denomination:', error);
				}
			} else {
				// Insert new record
				const { data, error } = await supabase
					.from('denomination_records')
					.insert(recordData)
					.select('id')
					.single();

				if (error) {
					console.error('Error saving main denomination:', error);
				} else if (data) {
					mainRecordId = data.id;
				}
			}

			lastSaved = new Date();
		} catch (error) {
			console.error('Error saving main denomination:', error);
		} finally {
			isSaving = false;
		}
	}

	async function saveBoxDenomination(boxNumber: number, boxCounts: Record<string, number>) {
		if (!selectedBranch || !$currentUser?.id) return;

		const boxIndex = boxNumber - 1;
		const boxTotal = Object.entries(boxCounts).reduce((sum, [key, count]) => sum + count * denomValues[key], 0);

		try {
			const recordData = {
				branch_id: parseInt(selectedBranch),
				user_id: $currentUser.id,
				record_type: 'advance_box',
				box_number: boxNumber,
				counts: boxCounts,
				grand_total: boxTotal
			};

			if (boxRecordIds[boxIndex]) {
				// Update existing record
				const { error } = await supabase
					.from('denomination_records')
					.update(recordData)
					.eq('id', boxRecordIds[boxIndex]);

				if (error) {
					console.error(`Error updating box ${boxNumber}:`, error);
				}
			} else {
				// Insert new record
				const { data, error } = await supabase
					.from('denomination_records')
					.insert(recordData)
					.select('id')
					.single();

				if (error) {
					console.error(`Error saving box ${boxNumber}:`, error);
				} else if (data) {
					boxRecordIds[boxIndex] = data.id;
				}
			}
		} catch (error) {
			console.error(`Error saving box ${boxNumber}:`, error);
		}
	}

	async function loadClosedBoxesCount() {
		try {
			const { count, error } = await supabase
				.from('box_operations')
				.select('*', { count: 'exact', head: true })
				.eq('status', 'completed');

			if (error) throw error;
			closedBoxesCount = count || 0;
			console.log('📦 Closed boxes count:', closedBoxesCount);
		} catch (error) {
			console.error('Error loading closed boxes count:', error);
			closedBoxesCount = 0;
		}
	}

	async function loadPendingBoxesCount() {
		try {
			let query = supabase
				.from('box_operations')
				.select('id', { count: 'exact', head: true })
				.eq('status', 'pending_close');

			if (selectedBranch) {
				query = query.eq('branch_id', parseInt(selectedBranch));
			}

			const { count, error } = await query;

			if (error) throw error;
			pendingBoxesCount = count || 0;
			console.log('⏳ Loaded pending boxes count:', pendingBoxesCount);
		} catch (error) {
			console.error('Error loading pending boxes count:', error);
			pendingBoxesCount = 0;
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.order('name_en');

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadUserPreferences() {
		if (!$currentUser?.id) return;
		
		try {
			// Use maybeSingle() instead of single() to handle 0 rows gracefully
			const { data, error } = await supabase
				.from('denomination_user_preferences')
				.select('default_branch_id')
				.eq('user_id', $currentUser.id)
				.maybeSingle();

			if (!error && data) {
				defaultBranchId = data.default_branch_id;
				if (data.default_branch_id) {
					selectedBranch = data.default_branch_id.toString();
				}
			} else if (error) {
				// Log but don't block - table might not be accessible yet
				console.log('Denomination preferences not found, using defaults:', error.message);
			}
		} catch (error) {
			// Table might not exist yet, that's okay
			console.log('User preferences not found, using defaults');
		}
	}

	async function setAsDefault() {
		if (!selectedBranch || !$currentUser?.id) return;

		isSavingDefault = true;
		try {
			const { error } = await supabase
				.from('denomination_user_preferences')
				.upsert({
					user_id: $currentUser.id,
					default_branch_id: parseInt(selectedBranch),
					updated_at: new Date().toISOString()
				}, { onConflict: 'user_id' });

			if (error) {
				console.error('Error saving default branch:', error);
				alert('Error saving default branch. Please try again.');
			} else {
				defaultBranchId = parseInt(selectedBranch);
				showDefaultSaved = true;
				setTimeout(() => {
					showDefaultSaved = false;
				}, 2000);
			}
		} catch (error) {
			console.error('Error saving default branch:', error);
		} finally {
			isSavingDefault = false;
		}
	}

	function getBranchDisplayName(branch: any) {
		return `${branch.name_en} - ${branch.location_en}`;
	}

	$: isCurrentDefault = selectedBranch && parseInt(selectedBranch) === defaultBranchId;

	// Denomination counts
	let counts: Record<string, number> = {
		'd500': 0,
		'd200': 0,
		'd100': 0,
		'd50': 0,
		'd20': 0,
		'd10': 0,
		'd5': 0,
		'd2': 0,
		'd1': 0,
		'd05': 0,
		'd025': 0,
		'coins': 0,
		'damage': 0
	};

	// Denomination values for calculating totals
	const denomValues: Record<string, number> = {
		'd500': 500,
		'd200': 200,
		'd100': 100,
		'd50': 50,
		'd20': 20,
		'd10': 10,
		'd5': 5,
		'd2': 2,
		'd1': 1,
		'd05': 0.5,
		'd025': 0.25,
		'coins': 1,
		'damage': 1
	};

	// ERP Balance for comparison
	let erpBalance: number | string = '';

	// Popup state
	let showPopup = false;
	let popupKey = '';
	let popupValue = '';
	let popupLabel = '';
	let popupMode: 'add' | 'subtract' = 'add';
	let currentCount = 0;
	let popupContext: 'main' | 'pettyCash' = 'main'; // Track which context the popup is for

	// Cash Box Denomination Modal state
	let showCashBoxModal = false;
	let selectedCashBox = 0;
	let cashBoxCounts: Record<string, number> = {
		'd500': 0,
		'd200': 0,
		'd100': 0,
		'd50': 0,
		'd20': 0,
		'd10': 0,
		'd5': 0,
		'd2': 0,
		'd1': 0,
		'd05': 0,
		'd025': 0,
		'coins': 0,
		'damage': 0
	};

	// Store each box's denomination data
	let cashBoxData: Array<Record<string, number>> = Array.from({ length: 12 }, () => ({
		'd500': 0,
		'd200': 0,
		'd100': 0,
		'd50': 0,
		'd20': 0,
		'd10': 0,
		'd5': 0,
		'd2': 0,
		'd1': 0,
		'd05': 0,
		'd025': 0,
		'coins': 0,
		'damage': 0
	}));

	// Calculate total for a cash box
	function getCashBoxTotal(boxIndex: number): number {
		const boxData = cashBoxData[boxIndex];
		return Object.entries(boxData).reduce((sum, [key, count]) => sum + count * denomValues[key], 0);
	}

	// Reactive totals for each cash box
	$: cashBoxTotals = cashBoxData.map((_, index) => getCashBoxTotal(index));

	async function fetchBoxOperations() {
		if (!selectedBranch) return;

		try {
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, box_number, branch_id, user_id, denomination_record_id, notes, status, supervisor_id, closing_details, total_before, total_after')
				.eq('branch_id', selectedBranch)
				.in('status', ['in_use', 'pending_close']);

			if (error) throw error;

			// Create a map of box_number to operation data
			boxOperations = new Map();
			if (data) {
				for (const op of data) {
					let username = '';
					let supervisorName = '';
					try {
						const notes = op.notes ? JSON.parse(op.notes) : {};
						username = notes.cashier_name || '';
						supervisorName = notes.supervisor_name || '';
					} catch (e) {
						console.error('Error parsing notes:', e);
					}
					boxOperations.set(op.box_number, { 
						...op, 
						username,
						supervisorName,
						isPendingClose: op.status === 'pending_close'
					});
				}
			}
			boxOperations = boxOperations; // Trigger reactivity
		} catch (error) {
			console.error('Error fetching box operations:', error);
		}

		// Fetch advance box total from denomination_records
		await fetchAdvanceBoxTotal();
	}

	async function fetchAdvanceBoxTotal() {
		if (!selectedBranch) return;

		try {
			const { data, error } = await supabase
				.from('denomination_records')
				.select('grand_total')
				.eq('branch_id', selectedBranch)
				.eq('record_type', 'advance_box');

			if (error) throw error;

			totalAdvanceBoxIssued = data?.reduce((sum, record) => sum + (parseFloat(record.grand_total as any) || 0), 0) || 0;
		} catch (error) {
			console.error('Error fetching advance box total:', error);
			totalAdvanceBoxIssued = 0;
		}
	}

	async function completeBoxClose(boxNumber: number) {
		try {
			const operation = boxOperations.get(boxNumber);
			if (!operation) {
				console.error('Box operation not found');
				return;
			}

			console.log('📦 Opening CompleteBox window for box:', boxNumber, 'operation:', operation.id);

			// Get the selected branch object
			const selectedBranchObj = branches.find(b => b.id.toString() === selectedBranch) || { id: selectedBranch, name: 'Unknown' };

			// Generate unique window ID
			const windowId = `complete-box-${boxNumber}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

			// Open the CompleteBox component in a new window
			openWindow({
				id: windowId,
				title: `Complete BOX ${boxNumber}`,
				component: CompleteBox,
				props: {
					windowId,
					operation,
					branch: selectedBranchObj
				},
				icon: '✓',
				size: { width: 700, height: 800 },
				position: { x: 300, y: 100 },
				resizable: true,
				minimizable: true,
				maximizable: true,
				closable: true
			});
		} catch (error) {
			console.error('Error opening complete box window:', error);
			alert('Failed to open box closing window. Please try again.');
		}
	}

	function openClosedBoxes() {
		const windowIdUnique = `closed-boxes-${Date.now()}`;
		
		openWindow({
			id: windowIdUnique,
			title: 'Closed Boxes',
			component: ClosedBoxes,
			props: {
				windowId: windowIdUnique
			},
			icon: '📋',
			size: { width: 1200, height: 700 },
			position: { x: 150, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Reload count after window opens
		setTimeout(() => {
			loadClosedBoxesCount();
		}, 500);
	}

	function openPendingBoxes() {
		const windowIdUnique = `pending-boxes-${Date.now()}`;
		
		openWindow({
			id: windowIdUnique,
			title: 'Pending to Close Boxes',
			component: PendingToCloseBoxes,
			props: {
				windowId: windowIdUnique
			},
			icon: '⏳',
			size: { width: 1200, height: 700 },
			position: { x: 150, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Reload count after window opens
		setTimeout(() => {
			loadPendingBoxesCount();
		}, 500);
	}

	function openCashBoxModal(boxNumber: number) {
		// Check if box is in use
		if (boxOperations.has(boxNumber)) {
			const operation = boxOperations.get(boxNumber);
			alert(`This box is currently in use by ${operation.username || 'another user'} in POS.`);
			return;
		}
		
		selectedCashBox = boxNumber;
		const boxIndex = boxNumber - 1;
		// Load existing box data - but convert 0s to undefined for empty display
		const boxData = cashBoxData[boxIndex];
		cashBoxCounts = {};
		for (const key of Object.keys(denomValues)) {
			cashBoxCounts[key] = (boxData[key] && boxData[key] > 0) ? boxData[key] : undefined;
		}
		showCashBoxModal = true;
	}

	function closeCashBoxModal() {
		showCashBoxModal = false;
		selectedCashBox = 0;
	}

	function saveCashBoxDenomination() {
		const boxIndex = selectedCashBox - 1;
		
		// Calculate difference between new and old values, then update
		for (const key of Object.keys(cashBoxCounts)) {
			const newAmount = cashBoxCounts[key] || 0;
			const oldAmount = cashBoxData[boxIndex][key] || 0;
			const difference = newAmount - oldAmount;
			
			if (difference !== 0) {
				// Update box data to new value
				cashBoxData[boxIndex][key] = newAmount;
				// Deduct the difference from main (positive = deduct more, negative = add back)
				counts[key] -= difference;
			}
		}
		
		// Trigger reactivity
		cashBoxData = cashBoxData;
		counts = counts;
		
		// Save to database
		saveBoxDenomination(selectedCashBox, { ...cashBoxData[boxIndex] });
		triggerAutoSave(); // Also save main denomination since counts changed
		
		closeCashBoxModal();
	}

	function handleCashBoxKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			closeCashBoxModal();
		}
	}

	// Calculate total for cash box modal input
	$: cashBoxInputTotal = Object.entries(cashBoxCounts).reduce((sum, [key, count]) => sum + ((count || 0) * (denomValues[key] || 0)), 0);

	const denomLabels: Record<string, string> = {
		'd500': '500 SAR',
		'd200': '200 SAR',
		'd100': '100 SAR',
		'd50': '50 SAR',
		'd20': '20 SAR',
		'd10': '10 SAR',
		'd5': '5 SAR',
		'd2': '2 SAR',
		'd1': '1 SAR',
		'd05': '0.5 SAR',
		'd025': '0.25 SAR',
		'coins': 'Coins',
		'damage': 'Damage'
	};

	function openPopupAdd(key: string) {
		popupKey = key;
		popupValue = '';
		popupLabel = denomLabels[key] || key;
		popupMode = 'add';
		currentCount = counts[key];
		popupContext = 'main';
		showPopup = true;
	}

	function openPopupSubtract(key: string) {
		popupKey = key;
		popupValue = '';
		currentCount = counts[key];
		popupLabel = denomLabels[key] || key;
		popupMode = 'subtract';
		popupContext = 'main';
		showPopup = true;
	}

	// Petty Cash popup functions
	function openPettyCashPopupAdd(key: string) {
		popupKey = key;
		popupValue = '';
		popupLabel = denomLabels[key] || key;
		popupMode = 'add';
		currentCount = pettyCashCounts[key] || 0;
		popupContext = 'pettyCash';
		showPopup = true;
	}

	function openPettyCashPopupSubtract(key: string) {
		popupKey = key;
		popupValue = '';
		currentCount = pettyCashCounts[key] || 0;
		popupLabel = denomLabels[key] || key;
		popupMode = 'subtract';
		popupContext = 'pettyCash';
		showPopup = true;
	}

	function closePopup() {
		showPopup = false;
		popupKey = '';
		popupValue = '';
	}

	function savePopupValue() {
		const val = parseInt(popupValue) || 0;
		if (val >= 0) {
			if (popupContext === 'main') {
				// Main denomination context
				if (popupMode === 'add') {
					counts[popupKey] = counts[popupKey] + val;
				} else {
					counts[popupKey] = Math.max(0, counts[popupKey] - val);
				}
				counts = counts;
				triggerAutoSave(); // Auto-save after change
			} else if (popupContext === 'pettyCash') {
				// Petty cash context
				if (popupMode === 'add') {
					// Add to petty cash, deduct from main
					const available = counts[popupKey] || 0;
					const toAdd = Math.min(val, available); // Can't add more than available
					if (toAdd > 0) {
						pettyCashCounts[popupKey] = (pettyCashCounts[popupKey] || 0) + toAdd;
						counts[popupKey] = counts[popupKey] - toAdd;
						pettyCashCounts = { ...pettyCashCounts };
						counts = counts;
						pettyCashTotal = calculatePettyCashTotal();
						triggerAutoSave(); // Auto-save main denomination
					}
				} else {
					// Subtract from petty cash, add back to main
					const currentPettyCash = pettyCashCounts[popupKey] || 0;
					const toRemove = Math.min(val, currentPettyCash);
					if (toRemove > 0) {
						pettyCashCounts[popupKey] = currentPettyCash - toRemove;
						counts[popupKey] = (counts[popupKey] || 0) + toRemove;
						pettyCashCounts = { ...pettyCashCounts };
						counts = counts;
						pettyCashTotal = calculatePettyCashTotal();
						triggerAutoSave(); // Auto-save main denomination
					}
				}
			}
		}
		closePopup();
	}

	function handlePopupKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			savePopupValue();
		} else if (e.key === 'Escape') {
			closePopup();
		}
	}

	function increment(key: string) {
		counts[key] = counts[key] + 1;
		counts = counts; // trigger reactivity
	}

	function decrement(key: string) {
		if (counts[key] > 0) {
			counts[key] = counts[key] - 1;
			counts = counts; // trigger reactivity
		}
	}

	function getTotal(key: string): number {
		return counts[key] * denomValues[key];
	}

	// Reactive totals for each denomination
	$: totals = {
		'd500': counts['d500'] * denomValues['d500'],
		'd200': counts['d200'] * denomValues['d200'],
		'd100': counts['d100'] * denomValues['d100'],
		'd50': counts['d50'] * denomValues['d50'],
		'd20': counts['d20'] * denomValues['d20'],
		'd10': counts['d10'] * denomValues['d10'],
		'd5': counts['d5'] * denomValues['d5'],
		'd2': counts['d2'] * denomValues['d2'],
		'd1': counts['d1'] * denomValues['d1'],
		'd05': counts['d05'] * denomValues['d05'],
		'd025': counts['d025'] * denomValues['d025'],
		'coins': counts['coins'] * denomValues['coins'],
		'damage': counts['damage'] * denomValues['damage']
	};

	$: grandTotal = Object.values(totals).reduce((sum, val) => sum + val, 0);

	// Calculate totals for paid and received sections (not applied)
	$: paidNotAppliedTotal = savedTransactions.filter(t => t.section === 'paid' && !t.apply_denomination).reduce((sum, t) => sum + t.amount, 0);
	$: receivedNotAppliedTotal = savedTransactions.filter(t => t.section === 'received' && !t.apply_denomination).reduce((sum, t) => sum + t.amount, 0);

	// Calculate difference: grand total - (ERP balance - advance cash issued - (paid total - received total))
	$: erpBalanceNumber = typeof erpBalance === 'string' ? (parseFloat(erpBalance) || 0) : erpBalance;
	$: differenceRaw = grandTotal - (erpBalanceNumber - totalAdvanceBoxIssued - (paidNotAppliedTotal - receivedNotAppliedTotal));
	$: difference = Math.round(differenceRaw);

	// Auto-save when ERP balance changes
	let prevErpBalance = erpBalance;
	$: if (erpBalance !== prevErpBalance && !isLoading && selectedBranch) {
		prevErpBalance = erpBalance;
		triggerAutoSave();
	}

	// ===== Modal Functions =====

	function openVendorModal(section: 'paid' | 'received') {
		currentSection = section;
		showVendorModal = true;
		vendorSearch = '';
		selectedVendor = null;
		loadVendors();
	}

	function openExpensesModal(section: 'paid' | 'received') {
		currentSection = section;
		showExpensesModal = true;
		requesterSearch = '';
		selectedRequester = null;
		loadRequesters();
	}

	function openUserModal(section: 'paid' | 'received') {
		currentSection = section;
		showUserModal = true;
		userSearch = '';
		selectedUser = null;
		loadUsers();
	}

	function openOtherModal(section: 'paid' | 'received') {
		currentSection = section;
		showOtherModal = true;
		particulars = '';
	}

	function closeAllModals() {
		showVendorModal = false;
		showExpensesModal = false;
		showUserModal = false;
		showOtherModal = false;
		resetModalForm();
	}

	function resetModalForm() {
		modalAmount = 0;
		modalRemarks = '';
		applyDenomination = false;
		modalDenominationCounts = {
			'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
			'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
			'd025': 0, 'coins': 0
		};
	}

	async function loadVendors() {
		try {
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, salesman_name')
				.eq('branch_id', parseInt(selectedBranch))
				.eq('status', 'Active')
				.order('vendor_name');

			if (!error) {
				vendors = data || [];
			}
		} catch (error) {
			console.error('Error loading vendors:', error);
		}
	}

	async function loadRequesters() {
		try {
			const { data, error } = await supabase
				.from('requesters')
				.select('id, requester_id, requester_name')
				.order('requester_name');

			if (!error) {
				requesters = data || [];
			}
		} catch (error) {
			console.error('Error loading requesters:', error);
		}
	}

	async function loadUsers() {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username, branch_id, user_type')
				.eq('status', 'active')
				.order('username');

			if (!error) {
				users = data || [];
			}
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	async function loadSavedTransactions() {
		if (!selectedBranch) return;

		try {
			const { data, error } = await supabase
				.from('denomination_transactions')
				.select('*')
				.eq('branch_id', parseInt(selectedBranch))
				.order('created_at', { ascending: false });

			if (!error) {
				savedTransactions = data || [];
			}
		} catch (error) {
			console.error('Error loading saved transactions:', error);
		}
	}

	async function deleteTransaction(transactionId: string) {
		deleteConfirmTransactionId = transactionId;
		showDeleteConfirmPopup = true;
	}

	async function confirmDeleteTransaction() {
		try {
			const { error } = await supabase
				.from('denomination_transactions')
				.delete()
				.eq('id', deleteConfirmTransactionId);

			if (error) {
				console.error('Error deleting transaction:', error);
				showDeleteConfirmPopup = false;
				alert('Error deleting transaction: ' + error.message);
				return;
			}

			// Reload transactions
			await loadSavedTransactions();
			showDeleteConfirmPopup = false;
		} catch (error) {
			console.error('Error deleting transaction:', error);
			showDeleteConfirmPopup = false;
			alert('Failed to delete transaction');
		}
	}

	function cancelDeleteTransaction() {
		showDeleteConfirmPopup = false;
		deleteConfirmTransactionId = '';
	}

	function showNotification(message: string, type: 'success' | 'error' = 'success', duration: number = 3000) {
		successMessage = message;
		successType = type;
		showSuccessPopup = true;

		// Auto-close after duration
		if (successTimeout) clearTimeout(successTimeout);
		successTimeout = setTimeout(() => {
			showSuccessPopup = false;
		}, duration);
	}

	function closeNotification() {
		showSuccessPopup = false;
		if (successTimeout) clearTimeout(successTimeout);
	}

	function toggleSidebar() {
		isSidebarOpen = !isSidebarOpen;
	}

	async function openPettyCashForm() {
		console.log('🔓 Opening petty cash form');
		console.log('📝 Petty Cash Box ID:', pettyCashBoxId);
		console.log('📦 Box Number:', pettyCashBoxNumber);
		
		if (!pettyCashBoxId) {
			console.error('❌ Petty cash box not initialized');
			showNotification('Petty cash box not initialized. Please try again.', 'error');
			return;
		}

		try {
			// Reload the latest data from database
			console.log('📥 Reloading petty cash data from database...');
			const { data: latestBox, error: fetchError } = await supabase
				.from('denomination_records')
				.select('counts, grand_total, notes')
				.eq('id', pettyCashBoxId)
				.single();

			if (fetchError) {
				console.error('❌ Error loading petty cash data:', fetchError);
				showNotification('Error loading petty cash data', 'error');
				return;
			}

			// Update with latest data from database
			if (latestBox) {
				let parsedCounts = latestBox.counts;
				if (typeof parsedCounts === 'string') {
					try {
						parsedCounts = JSON.parse(parsedCounts);
					} catch (e) {
						console.warn('⚠️ Could not parse counts:', e);
						parsedCounts = {};
					}
				}
				
				pettyCashCounts = parsedCounts || {};
				pettyCashTotal = latestBox.grand_total || 0;
				pettyCashNotes = latestBox.notes || '';
				console.log('✅ Loaded latest data:', pettyCashCounts, 'Total:', pettyCashTotal);
			}

			showPettyCashForm = true;
			console.log('✅ Petty cash form opened');
		} catch (error) {
			console.error('❌ Exception opening petty cash form:', error);
			showNotification('Failed to open petty cash form', 'error');
		}
	}

	function closePettyCashForm() {
		console.log('🔒 Closing petty cash form');
		showPettyCashForm = false;
		pettyCashCounts = {}; // Clear input counts
		pettyCashNotes = ''; // Clear notes
		// DO NOT clear pettyCashBoxId or pettyCashBoxNumber - keep them persistent like advance boxes
	}

	async function getNextBoxNumber(): Promise<number> {
		console.log('🔢 Getting next box number for branch:', selectedBranch);
		if (!selectedBranch) {
			console.warn('⚠️ No branch selected, returning 1');
			return 1;
		}

		try {
			// Get the highest box number already used for this branch
			const { data, error } = await supabase
				.from('denomination_records')
				.select('box_number')
				.eq('branch_id', parseInt(selectedBranch))
				.eq('record_type', 'petty_cash_box')
				.order('box_number', { ascending: false })
				.limit(1);

			console.log('📊 Query result:', { data, error });

			if (error) {
				console.error('❌ Error fetching box numbers:', error);
				return 1;
			}

			if (!data || data.length === 0) {
				console.log('ℹ️ No existing petty cash records, starting from box 1');
				return 1;
			}

			const nextBox = Math.min(data[0].box_number + 1, 12);
			console.log('✅ Next box number:', nextBox);
			return nextBox;
		} catch (err) {
			console.error('❌ Error in getNextBoxNumber:', err);
			return 1;
		}
	}

	function calculatePettyCashTotal(): number {
		return Object.entries(pettyCashCounts).reduce((sum, [key, count]: [string, any]) => {
			if (key === 'damage' || key === 'coins') return sum;
			return sum + (count * (denomValues[key] || 0));
		}, 0);
	}

	async function savePettyCashRecord() {
		console.log('💾 Starting savePettyCashRecord');
		console.log('📍 Selected Branch:', selectedBranch);
		console.log('👤 Current User:', $currentUser?.id);
		console.log('📝 Petty Cash Box ID:', pettyCashBoxId);
		console.log('📦 Current pettyCashCounts:', pettyCashCounts);

		if (!selectedBranch || !$currentUser?.id) {
			console.error('❌ Missing required data - Branch:', selectedBranch, 'User:', $currentUser?.id);
			showNotification('Branch and user must be selected', 'error');
			return;
		}

		if (!pettyCashBoxId) {
			console.error('❌ Petty cash box not initialized');
			showNotification('Please try again - petty cash box not initialized', 'error');
			return;
		}

		try {
			isSavingPettyCash = true;
			console.log('🔄 isSavingPettyCash set to true');

			const pettyCashTotal = calculatePettyCashTotal();
			console.log('💰 Petty cash total:', pettyCashTotal);
			console.log('📦 Denomination counts to save:', pettyCashCounts);

			if (pettyCashTotal <= 0) {
				console.error('❌ Invalid total, must be > 0');
				showNotification('Please enter at least one denomination', 'error');
				return;
			}

			const updateData = {
				counts: { ...pettyCashCounts },
				grand_total: pettyCashTotal,
				notes: pettyCashNotes || null,
				updated_at: new Date().toISOString()
			};

			console.log('📤 Updating petty cash box record with:', updateData);

			// Update the petty cash record (created in openPettyCashForm)
			const { error: recordError } = await supabase
				.from('denomination_records')
				.update(updateData)
				.eq('id', pettyCashBoxId);

			if (recordError) {
				console.error('❌ Database error:', recordError);
				showNotification('Error saving record: ' + recordError.message, 'error');
				return;
			}

			console.log('✅ Petty cash record updated successfully');

			// Deduct the petty cash amount from the main cash box
			console.log('💸 Deducting petty cash amounts from main cash box...');
			Object.entries(pettyCashCounts).forEach(([key, value]: [string, any]) => {
				const amount = value || 0;
				if (amount > 0) {
					counts[key] = Math.max(0, counts[key] - amount);
					console.log(`📉 Deducted ${amount} x ${denomLabels[key]} from main cash box`);
				}
			});
			counts = { ...counts };
			
			// Save the updated main cash box counts immediately (no debounce)
			await saveMainDenomination();

			// Close form and show success
			closePettyCashForm();
			showNotification(`Petty cash box #${pettyCashBoxNumber} transferred successfully!`, 'success');
			console.log('🎉 Petty cash transfer complete!');
		} catch (error) {
			console.error('❌ Exception caught:', error);
			showNotification('Failed to save petty cash record: ' + (error as any).message, 'error');
		} finally {
			isSavingPettyCash = false;
			console.log('🔄 isSavingPettyCash set to false');
		}
	}

	function addBackToMainPettyCash(key: string) {
		const amount = pettyCashCounts[key] || 0;
		if (amount > 0) {
			// Add back to main counts
			counts[key] = counts[key] + amount;
			counts = { ...counts };
			
			// Clear from petty cash
			pettyCashCounts[key] = 0;
			pettyCashCounts = { ...pettyCashCounts };
			
			// Update total
			pettyCashTotal = calculatePettyCashTotal();
			
			// Save the updated petty cash record immediately
			saveUpdatedPettyCashToDatabase();
			
			console.log(`✅ Added back ${amount} x ${denomLabels[key]} to main cash box`);
			showNotification(`Added ${amount} × ${denomLabels[key]} back to main`, 'success');
		}
	}

	async function saveUpdatedPettyCashToDatabase() {
		try {
			const updateData = {
				counts: { ...pettyCashCounts },
				grand_total: pettyCashTotal,
				notes: pettyCashNotes || null,
				updated_at: new Date().toISOString()
			};

			const { error } = await supabase
				.from('denomination_records')
				.update(updateData)
				.eq('id', pettyCashBoxId);

			if (error) {
				console.error('❌ Error saving updated petty cash:', error);
				showNotification('Error updating petty cash record', 'error');
				return;
			}

			console.log('✅ Updated petty cash record in database');
			triggerAutoSave(); // Also save main counts since they changed
		} catch (error) {
			console.error('❌ Exception saving updated petty cash:', error);
			showNotification('Failed to update petty cash record', 'error');
		}
	}

	async function saveTransaction(type: 'vendor' | 'expenses' | 'user' | 'other') {
		if (!selectedBranch || !$currentUser?.id) {
			showNotification('Branch and user must be selected', 'error');
			return;
		}

		if (modalAmount <= 0) {
			showNotification('Amount must be greater than 0', 'error');
			return;
		}

		// If denomination is applied, validate that the sum matches the amount
		if (applyDenomination) {
			const denominationTotal = Object.entries(modalDenominationCounts).reduce((sum, [key, count]: [string, any]) => {
				return sum + (count * denomValues[key]);
			}, 0);

			if (denominationTotal !== modalAmount) {
				showPopup(`Denomination total (${denominationTotal} SAR) must match the transaction amount (${modalAmount} SAR)`, 'error');
				return;
			}
		}

		try {
			let entityData: any = {};

			// Prepare entity data based on transaction type
			if (type === 'vendor' && selectedVendor) {
				entityData = { 
					erp_vendor_id: selectedVendor.erp_vendor_id, 
					vendor_name: selectedVendor.vendor_name, 
					salesman_name: selectedVendor.salesman_name 
				};
			} else if (type === 'expenses' && selectedRequester) {
				entityData = { 
					requester_id: selectedRequester.requester_id, 
					requester_name: selectedRequester.requester_name 
				};
			} else if (type === 'user' && selectedUser) {
				entityData = { 
					user_id: selectedUser.id, 
					username: selectedUser.username,
					branch_id: selectedUser.branch_id,
					user_type: selectedUser.user_type
				};
			} else if (type === 'other') {
				entityData = { particulars };
			}

			// Prepare transaction record
			const transactionData = {
				branch_id: parseInt(selectedBranch),
				section: currentSection,
				transaction_type: type,
				amount: modalAmount,
				remarks: modalRemarks || null,
				apply_denomination: applyDenomination,
				denomination_details: applyDenomination ? { ...modalDenominationCounts } : {},
				entity_data: entityData,
				created_by: $currentUser.id
			};

			// Save to database
			const { data, error } = await supabase
				.from('denomination_transactions')
				.insert(transactionData)
				.select()
				.single();

			if (error) {
				console.error('Error saving transaction:', error);
				showNotification('Error saving transaction: ' + error.message, 'error');
				return;
			}

			// If denomination was applied, adjust main counts
			if (applyDenomination) {
				Object.entries(modalDenominationCounts).forEach(([key, value]: [string, any]) => {
					if (currentSection === 'paid') {
						// For paid: deduct from main counts
						counts[key] = Math.max(0, counts[key] - value);
					} else {
						// For received: add to main counts
						counts[key] = counts[key] + value;
					}
				});
				counts = { ...counts };
				triggerAutoSave();
			}

			// Reload transactions and close modal
			await loadSavedTransactions();
			closeAllModals();
			showNotification('Transaction saved successfully!', 'success');
		} catch (error) {
			console.error('Error saving transaction:', error);
			showNotification('Failed to save transaction', 'error');
		}
	}

</script>

<!-- Cash Box Denomination Modal -->
{#if showCashBoxModal}
<div class="popup-overlay" on:click={closeCashBoxModal} on:keydown={handleCashBoxKeydown}>
	<div class="cashbox-modal" on:click|stopPropagation>
		<div class="popup-header cashbox-header">
			<span>📦 BOX {selectedCashBox} - Enter Denomination</span>
			<button class="popup-close" on:click={closeCashBoxModal}>✕</button>
		</div>
		<div class="cashbox-modal-body">
			<div class="cashbox-info">
				<span class="info-label">Available in Main:</span>
				<span class="info-value">{grandTotal.toLocaleString()} SAR</span>
			</div>
			<div class="cashbox-denomination-grid">
				{#each Object.entries(denomLabels) as [key, label]}
					<div class="cashbox-denom-row">
						<div class="denom-label">
							{#if key.startsWith('d')}
								<img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />
							{/if}
							{label}
						</div>
						<div class="denom-available">Avail: {counts[key]}</div>
						<input 
							type="number" 
							class="denom-input"
							bind:value={cashBoxCounts[key]}
							min="0"
							max={counts[key]}
							placeholder=""
						/>
						<div class="denom-subtotal">{((cashBoxCounts[key] || 0) * denomValues[key]).toLocaleString()}</div>
					</div>
				{/each}
			</div>
			<div class="cashbox-total-row">
				<span>Transfer Total:</span>
				<span class="cashbox-total-value">{cashBoxInputTotal.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR</span>
			</div>
		</div>
		<div class="popup-footer">
			<button class="popup-btn cancel" on:click={closeCashBoxModal}>Cancel</button>
			<button class="popup-btn save" on:click={saveCashBoxDenomination}>Transfer to BOX {selectedCashBox}</button>
		</div>
	</div>
</div>
{/if}

<!-- Petty Cash Popup Modal (matching advance box style) -->
{#if showPettyCashForm}
<div class="popup-overlay" on:click={closePettyCashForm} on:keydown={handleCashBoxKeydown}>
	<div class="cashbox-modal" on:click|stopPropagation>
		<div class="popup-header cashbox-header">
			<span>💰 Petty Cash - Enter Denomination</span>
			<button class="popup-close" on:click={closePettyCashForm}>✕</button>
		</div>
		<div class="cashbox-modal-body">
			<div class="cashbox-info">
				<span class="info-label">Available in Main:</span>
				<span class="info-value">{grandTotal.toLocaleString()} SAR</span>
			</div>
			<div class="cashbox-denomination-grid">
				{#each Object.entries(denomLabels) as [key, label]}
					<div class="cashbox-denom-row">
						<div class="denom-label">
							{#if key.startsWith('d')}
								<img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />
							{/if}
							{label}
						</div>
						<div class="denom-available">Avail: {counts[key]}</div>
						<div class="petty-cash-count-controls">
							<button 
								class="count-btn minus" 
								on:click={() => openPettyCashPopupSubtract(key)}
								disabled={(pettyCashCounts[key] || 0) === 0}
								title="Remove from petty cash"
							>
								−
							</button>
							<button class="count-value petty-cash-count-display" on:click={() => openPettyCashPopupAdd(key)}>
								{pettyCashCounts[key] || 0}
							</button>
							<button 
								class="count-btn plus" 
								on:click={() => openPettyCashPopupAdd(key)}
								disabled={counts[key] === 0}
								title="Add to petty cash"
							>
								+
							</button>
						</div>
						<div class="denom-subtotal">{((pettyCashCounts[key] || 0) * denomValues[key]).toLocaleString()}</div>
					</div>
				{/each}
			</div>
			<div class="cashbox-total-row">
				<span>Transfer Total:</span>
				<span class="cashbox-total-value">{pettyCashTotal.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR</span>
			</div>
			{#if pettyCashNotes}
				<div class="petty-cash-notes-display">
					<span class="notes-label">Notes:</span>
					<span class="notes-value">{pettyCashNotes}</span>
				</div>
			{/if}
		</div>
		<div class="popup-footer">
			<button class="popup-btn cancel" on:click={closePettyCashForm} disabled={isSavingPettyCash}>Cancel</button>
			<button 
				class="popup-btn save" 
				on:click={() => {
					console.log('🖱️ Save button clicked!');
					console.log('📦 pettyCashCounts:', pettyCashCounts);
					console.log('💰 Reactive Total (pettyCashTotal):', pettyCashTotal);
					console.log('📝 BoxID:', pettyCashBoxId);
					console.log('🔒 isSavingPettyCash:', isSavingPettyCash);
					console.log('✅ Calling savePettyCashRecord now...');
					savePettyCashRecord();
				}}
				disabled={pettyCashTotal <= 0 || isSavingPettyCash}
			>
				{isSavingPettyCash ? 'Saving...' : pettyCashTotal > 0 ? `💰 ${pettyCashTotal.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR` : 'Transfer to Petty Cash'}
			</button>
		</div>
	</div>
</div>
{/if}

<!-- Popup Modal -->
{#if showPopup}
<div class="popup-overlay" on:click={closePopup}>
	<div class="popup-modal {popupMode}" on:click|stopPropagation>
		<div class="popup-header {popupMode}">
			<span>{popupMode === 'add' ? '➕ Add to' : '➖ Subtract from'} {popupLabel}</span>
			<button class="popup-close" on:click={closePopup}>✕</button>
		</div>
		<div class="popup-body">
			<div class="current-count-label">Current count: <strong>{currentCount}</strong></div>
			<input 
				type="number" 
				class="popup-input" 
				bind:value={popupValue} 
				on:keydown={handlePopupKeydown}
				min="0"
				placeholder="Enter count"
				autofocus
			/>
		</div>
		<div class="popup-footer">
			<button class="popup-btn cancel" on:click={closePopup}>Cancel</button>
			<button class="popup-btn save {popupMode}" on:click={savePopupValue}>{popupMode === 'add' ? 'Add' : 'Subtract'}</button>
		</div>
	</div>
</div>
{/if}

<!-- Vendor Modal -->
{#if showVendorModal}
<div class="modal-overlay" on:click={closeAllModals}>
	<div class="modal-content" on:click|stopPropagation>
		<div class="modal-header">
			<h2>Add Vendor ({currentSection === 'paid' ? 'Paid' : 'Received'})</h2>
			<button class="modal-close" on:click={closeAllModals}>✕</button>
		</div>
		<div class="modal-body">
			<div class="form-group">
				<label>Search Vendor</label>
				<input 
					type="text" 
					bind:value={vendorSearch}
					placeholder="Search vendors..."
					class="form-input"
				/>
				<div class="dropdown-list">
					{#each vendors.filter(v => v.vendor_name.toLowerCase().includes(vendorSearch.toLowerCase())) as vendor}
						<div 
							class="dropdown-item" 
							on:click={() => selectedVendor = vendor}
							class:selected={selectedVendor?.erp_vendor_id === vendor.erp_vendor_id}
						>
							<div class="item-name">{vendor.vendor_name}</div>
							<div class="item-code">{vendor.salesman_name || 'N/A'}</div>
						</div>
					{/each}
				</div>
			</div>

			{#if selectedVendor}
				<div class="form-group">
					<label>Amount (SAR)</label>
					<input type="number" bind:value={modalAmount} placeholder="0" class="form-input" min="0" />
				</div>

				<div class="form-group">
					<label>Remarks (Optional)</label>
					<textarea bind:value={modalRemarks} placeholder="Add any notes..." class="form-input" rows="2"></textarea>
				</div>

				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={applyDenomination} />
						Apply Denomination
					</label>
				</div>

				{#if applyDenomination}
					<div class="denomination-grid">
						<h4>Enter Denominations</h4>
						{#each Object.entries(denomLabels).filter(([key]) => !key.startsWith('damage')) as [key, label]}
							<div class="denom-field">
								<label>{label}</label>
								<input 
									type="number" 
									bind:value={modalDenominationCounts[key]}
									min="0"
									max={counts[key]}
									placeholder="0"
									class="form-input"
								/>
								<small>Avail: {counts[key]}</small>
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		</div>
		<div class="modal-footer">
			<button class="btn-cancel" on:click={closeAllModals}>Cancel</button>
			<button class="btn-save" on:click={() => saveTransaction('vendor')} disabled={!selectedVendor || modalAmount <= 0}>
				Save
			</button>
		</div>
	</div>
</div>
{/if}

<!-- Expenses Modal (Paid Section Only) -->
{#if showExpensesModal}
<div class="modal-overlay" on:click={closeAllModals}>
	<div class="modal-content" on:click|stopPropagation>
		<div class="modal-header">
			<h2>Add Expenses (Paid)</h2>
			<button class="modal-close" on:click={closeAllModals}>✕</button>
		</div>
		<div class="modal-body">
			<div class="form-group">
				<label>Search Requester</label>
				<input 
					type="text" 
					bind:value={requesterSearch}
					placeholder="Search requesters..."
					class="form-input"
				/>
				<div class="dropdown-actions">
					<button class="btn-create-new" on:click={() => {/* Handle create new requester */}}>+ Create New Requester</button>
				</div>
				<div class="dropdown-list">
					{#each requesters.filter(r => r.requester_name.toLowerCase().includes(requesterSearch.toLowerCase())) as requester}
						<div 
							class="dropdown-item" 
							on:click={() => selectedRequester = requester}
							class:selected={selectedRequester?.id === requester.id}
						>
							<div class="item-name">{requester.requester_name}</div>
							<div class="item-code">{requester.requester_id}</div>
						</div>
					{/each}
				</div>
			</div>

			{#if selectedRequester}
				<div class="form-group">
					<label>Amount (SAR)</label>
					<input type="number" bind:value={modalAmount} placeholder="0" class="form-input" min="0" />
				</div>

				<div class="form-group">
					<label>Remarks (Optional)</label>
					<textarea bind:value={modalRemarks} placeholder="Add any notes..." class="form-input" rows="2"></textarea>
				</div>

				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={applyDenomination} />
						Apply Denomination
					</label>
				</div>

				{#if applyDenomination}
					<div class="denomination-grid">
						<h4>Enter Denominations</h4>
						{#each Object.entries(denomLabels).filter(([key]) => !key.startsWith('damage')) as [key, label]}
							<div class="denom-field">
								<label>{label}</label>
								<input 
									type="number" 
									bind:value={modalDenominationCounts[key]}
									min="0"
									max={counts[key]}
									placeholder="0"
									class="form-input"
								/>
								<small>Avail: {counts[key]}</small>
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		</div>
		<div class="modal-footer">
			<button class="btn-cancel" on:click={closeAllModals}>Cancel</button>
			<button class="btn-save" on:click={() => saveTransaction('expenses')} disabled={!selectedRequester || modalAmount <= 0}>
				Save
			</button>
		</div>
	</div>
</div>
{/if}

<!-- User Modal -->
{#if showUserModal}
<div class="modal-overlay" on:click={closeAllModals}>
	<div class="modal-content" on:click|stopPropagation>
		<div class="modal-header">
			<h2>Add User ({currentSection === 'paid' ? 'Paid' : 'Received'})</h2>
			<button class="modal-close" on:click={closeAllModals}>✕</button>
		</div>
		<div class="modal-body">
			<div class="form-group">
				<label>Search User</label>
				<input 
					type="text" 
					bind:value={userSearch}
					placeholder="Search users..."
					class="form-input"
				/>
				<div class="dropdown-list">
					{#each users.filter(u => u.username.toLowerCase().includes(userSearch.toLowerCase())) as user}
						<div 
							class="dropdown-item" 
							on:click={() => selectedUser = user}
							class:selected={selectedUser?.id === user.id}
						>
							<div class="item-name">{user.username}</div>
							<div class="item-code">{user.user_type === 'global' ? 'Global User' : `Branch ${user.branch_id}`}</div>
						</div>
					{/each}
				</div>
			</div>

			{#if selectedUser}
				<div class="form-group">
					<label>Amount (SAR)</label>
					<input type="number" bind:value={modalAmount} placeholder="0" class="form-input" min="0" />
				</div>

				<div class="form-group">
					<label>Remarks (Optional)</label>
					<textarea bind:value={modalRemarks} placeholder="Add any notes..." class="form-input" rows="2"></textarea>
				</div>

				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={applyDenomination} />
						Apply Denomination
					</label>
				</div>

				{#if applyDenomination}
					<div class="denomination-grid">
						<h4>Enter Denominations</h4>
						{#each Object.entries(denomLabels).filter(([key]) => !key.startsWith('damage')) as [key, label]}
							<div class="denom-field">
								<label>{label}</label>
								<input 
									type="number" 
									bind:value={modalDenominationCounts[key]}
									min="0"
									max={counts[key]}
									placeholder="0"
									class="form-input"
								/>
								<small>Avail: {counts[key]}</small>
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		</div>
		<div class="modal-footer">
			<button class="btn-cancel" on:click={closeAllModals}>Cancel</button>
			<button class="btn-save" on:click={() => saveTransaction('user')} disabled={!selectedUser || modalAmount <= 0}>
				Save
			</button>
		</div>
	</div>
</div>
{/if}

<!-- Other Modal -->
{#if showOtherModal}
<div class="modal-overlay" on:click={closeAllModals}>
	<div class="modal-content" on:click|stopPropagation>
		<div class="modal-header">
			<h2>Add Other ({currentSection === 'paid' ? 'Paid' : 'Received'})</h2>
			<button class="modal-close" on:click={closeAllModals}>✕</button>
		</div>
		<div class="modal-body">
			<div class="form-group">
				<label>Particulars</label>
				<input 
					type="text" 
					bind:value={particulars}
					placeholder="Enter description..."
					class="form-input"
				/>
			</div>

			<div class="form-group">
				<label>Amount (SAR)</label>
				<input type="number" bind:value={modalAmount} placeholder="0" class="form-input" min="0" />
			</div>

			<div class="form-group">
				<label>Remarks (Optional)</label>
				<textarea bind:value={modalRemarks} placeholder="Add any notes..." class="form-input" rows="2"></textarea>
			</div>

			<div class="form-group">
				<label class="checkbox-label">
					<input type="checkbox" bind:checked={applyDenomination} />
					Apply Denomination
				</label>
			</div>

			{#if applyDenomination}
				<div class="denomination-grid">
					<h4>Enter Denominations</h4>
					{#each Object.entries(denomLabels).filter(([key]) => !key.startsWith('damage')) as [key, label]}
						<div class="denom-field">
							<label>{label}</label>
							<input 
								type="number" 
								bind:value={modalDenominationCounts[key]}
								min="0"
								max={counts[key]}
								placeholder="0"
								class="form-input"
							/>
							<small>Avail: {counts[key]}</small>
						</div>
					{/each}
				</div>
			{/if}
		</div>
		<div class="modal-footer">
			<button class="btn-cancel" on:click={closeAllModals}>Cancel</button>
			<button class="btn-save" on:click={() => saveTransaction('other')} disabled={!particulars || modalAmount <= 0}>
				Save
			</button>
		</div>
	</div>
</div>
{/if}

<div class="denomination-container">
	{#if isLoading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading...</p>
		</div>
	{:else}
		<!-- Big Cards Row -->
		<div class="big-cards-container">
			<!-- Big Card Left -->
			<div class="card big-card">
				<!-- POS Advance Manager & POS Collection Manager Row -->
				<div class="card-body suspends-body">
					<!-- POS Advance Manager Section -->
					<div class="suspends-section">
						<div class="suspends-section-header advance-manager">
							<span class="section-icon">📤</span>
							<span>POS Advance Manager</span>
						</div>
						<div class="suspends-cards-grid">
							{#each [1, 2, 3, 10, 4, 5, 6, 11, 7, 8, 9, 12] as boxNum}
								{@const isInUse = boxOperations.has(boxNum)}
								{@const operation = boxOperations.get(boxNum)}
								<button 
									class="suspend-card clickable-box"
									class:special-box={boxNum >= 10}
									class:has-value={cashBoxTotals[boxNum - 1] > 0}
									class:in-use={isInUse}
									disabled={isInUse}
									on:click={() => openCashBoxModal(boxNum)}
								>
									<div class="box-content">
										<span class="box-label">{getBoxDisplayName(boxNum)}</span>
										{#if isInUse}
											{#if operation?.isPendingClose}
												<span class="box-status pending-close">PENDING</span>
												<span class="box-username">{operation?.username || 'User'}</span>
											{:else}
												<span class="box-status in-use">IN USE</span>
												<span class="box-username">{operation?.username || 'User'}</span>
											{/if}
										{:else if cashBoxTotals[boxNum - 1] > 0}
											<span class="box-total">{cashBoxTotals[boxNum - 1].toLocaleString()}</span>
										{:else}
											<span class="box-empty">Click to add</span>
										{/if}
									</div>
								</button>
							{/each}
						</div>
					</div>
					
					<!-- POS Collection Manager Section -->
					<div class="suspends-section">
						<div class="suspends-section-header collection-manager">
							<span class="section-icon">📥</span>
							<span>POS Collection Manager</span>
						</div>
						<div class="suspends-cards-grid">
							{#each Array.from({ length: 12 }, (_, i) => i + 1) as boxNum (boxNum)}
								{@const operation = boxOperations.get(boxNum)}
								{@const isPending = operation?.isPendingClose}
								
								{#if isPending}
									<button class="pending-box-card" on:click={() => completeBoxClose(boxNum)}>
										<div class="box-header">
											<span class="box-label">{getBoxDisplayName(boxNum)}</span>
										</div>
										<div class="box-info">
											<div class="info-row">
												<span class="value">{operation?.username || 'N/A'}</span>
											</div>
											<div class="info-row">
												<span class="value supervisor">⚡ {operation?.supervisorName || 'Waiting'}</span>
											</div>
										</div>
									</button>
								{/if}
							{/each}
						</div>
						{#if Array.from(boxOperations.values()).filter(op => op?.isPendingClose).length === 0}
							<div class="empty-state">
								<p class="hint">No pending boxes to close</p>
							</div>
						{/if}
					</div>
				</div>
				
				<div class="card-body suspends-body suspends-body-second">
					<!-- Paid Section -->
					<div class="suspends-section">
						<div class="suspends-section-header paid">
							<div class="header-left">
								<span class="section-icon">💸</span>
								<span>Paid</span>
							</div>
							<div class="header-total">
								<div class="total-breakdown">
									<span class="total-item applied">Applied: <span class="amount">{savedTransactions.filter(t => t.section === 'paid' && t.apply_denomination).reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
									<span class="total-item not-applied">Not Applied: <span class="amount">{savedTransactions.filter(t => t.section === 'paid' && !t.apply_denomination).reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
									<span class="total-item grand-total">Total: <span class="amount">{savedTransactions.filter(t => t.section === 'paid').reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
								</div>
							</div>
							<div class="action-buttons-group">
								<button class="action-btn vendor-btn" on:click={() => openVendorModal('paid')}>Vendor</button>
								<button class="action-btn expenses-btn" on:click={() => openExpensesModal('paid')}>Expenses</button>
								<button class="action-btn user-btn" on:click={() => openUserModal('paid')}>User</button>
								<button class="action-btn other-btn" on:click={() => openOtherModal('paid')}>Other</button>
							</div>
						</div>
						<!-- Paid Transactions Table -->
						<div class="transactions-table-container">
							{#if savedTransactions.filter(t => t.section === 'paid').length > 0}
								<table class="transactions-table">
									<thead>
										<tr>
											<th>Entity</th>
											<th>Type</th>
											<th>Amount</th>
											<th>Remarks</th>
											<th>Denom</th>
											<th>Date</th>
											<th>Action</th>
										</tr>
									</thead>
									<tbody>
										{#each savedTransactions.filter(t => t.section === 'paid') as transaction}
											<tr>
												<td class="entity-cell">
													{#if transaction.transaction_type === 'vendor'}
														{transaction.entity_data.vendor_name}
													{:else if transaction.transaction_type === 'expenses'}
														{transaction.entity_data.requester_name}
													{:else if transaction.transaction_type === 'user'}
														{transaction.entity_data.username}
													{:else}
														{transaction.entity_data.particulars}
													{/if}
												</td>
												<td><span class="badge badge-{transaction.transaction_type}">{transaction.transaction_type}</span></td>
												<td class="amount-cell">{transaction.amount.toLocaleString()} SAR</td>
												<td class="remarks-cell">{transaction.remarks || '-'}</td>
												<td class="denom-cell">{transaction.apply_denomination ? '✓' : '✗'}</td>
												<td class="date-cell">{new Date(transaction.created_at).toLocaleDateString()}</td>
												<td class="action-cell">
													<button class="delete-btn" on:click={() => deleteTransaction(transaction.id)} title="Delete transaction">✕</button>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							{:else}
								<div class="empty-state">No transactions yet</div>
							{/if}
						</div>
					</div>
					
					<!-- Received Section -->
					<div class="suspends-section">
						<div class="suspends-section-header received">
							<div class="header-left">
								<span class="section-icon">💰</span>
								<span>Received</span>
							</div>
							<div class="header-total">
								<div class="total-breakdown">
									<span class="total-item applied">Applied: <span class="amount">{savedTransactions.filter(t => t.section === 'received' && t.apply_denomination).reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
									<span class="total-item not-applied">Not Applied: <span class="amount">{savedTransactions.filter(t => t.section === 'received' && !t.apply_denomination).reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
									<span class="total-item grand-total">Total: <span class="amount">{savedTransactions.filter(t => t.section === 'received').reduce((sum, t) => sum + t.amount, 0).toLocaleString()}</span> SAR</span>
								</div>
							</div>
							<div class="action-buttons-group">
								<button class="action-btn vendor-btn" on:click={() => openVendorModal('received')}>Vendor</button>
								<button class="action-btn user-btn" on:click={() => openUserModal('received')}>User</button>
								<button class="action-btn other-btn" on:click={() => openOtherModal('received')}>Other</button>
							</div>
						</div>
						<!-- Received Transactions Table -->
						<div class="transactions-table-container">
							{#if savedTransactions.filter(t => t.section === 'received').length > 0}
								<table class="transactions-table">
									<thead>
										<tr>
											<th>Type</th>
											<th>Entity</th>
											<th>Amount</th>
											<th>Remarks</th>
											<th>Denom</th>
											<th>Date</th>
											<th>Action</th>
										</tr>
									</thead>
									<tbody>
										{#each savedTransactions.filter(t => t.section === 'received') as transaction}
											<tr>
												<td class="entity-cell">
													{#if transaction.transaction_type === 'vendor'}
														{transaction.entity_data.vendor_name}
													{:else if transaction.transaction_type === 'user'}
														{transaction.entity_data.username}
													{:else}
														{transaction.entity_data.particulars}
													{/if}
												</td>
												<td><span class="badge badge-{transaction.transaction_type}">{transaction.transaction_type}</span></td>
												<td class="amount-cell">{transaction.amount.toLocaleString()} SAR</td>
												<td class="remarks-cell">{transaction.remarks || '-'}</td>
												<td class="denom-cell">{transaction.apply_denomination ? '✓' : '✗'}</td>
												<td class="date-cell">{new Date(transaction.created_at).toLocaleDateString()}</td>
												<td class="action-cell">
													<button class="delete-btn" on:click={() => deleteTransaction(transaction.id)} title="Delete transaction">✕</button>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							{:else}
								<div class="empty-state">No transactions yet</div>
							{/if}
						</div>
					</div>
				</div>
			</div>
			
			<!-- Denomination Table Card -->
			<div class="card big-card">
				<div class="card-body">
					<table class="denomination-table">
						<thead>
							<tr>
								<th>Denomination</th>
								<th>Count</th>
								<th>Total</th>
							</tr>
						</thead>
						<tbody>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />500</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d500')}>−</button><span class="count-value">{counts['d500']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d500')}>+</button></td><td class="total-cell">{totals['d500'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />200</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d200')}>−</button><span class="count-value">{counts['d200']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d200')}>+</button></td><td class="total-cell">{totals['d200'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />100</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d100')}>−</button><span class="count-value">{counts['d100']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d100')}>+</button></td><td class="total-cell">{totals['d100'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />50</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d50')}>−</button><span class="count-value">{counts['d50']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d50')}>+</button></td><td class="total-cell">{totals['d50'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />20</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d20')}>−</button><span class="count-value">{counts['d20']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d20')}>+</button></td><td class="total-cell">{totals['d20'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />10</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d10')}>−</button><span class="count-value">{counts['d10']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d10')}>+</button></td><td class="total-cell">{totals['d10'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />5</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d5')}>−</button><span class="count-value">{counts['d5']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d5')}>+</button></td><td class="total-cell">{totals['d5'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />2</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d2')}>−</button><span class="count-value">{counts['d2']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d2')}>+</button></td><td class="total-cell">{totals['d2'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />1</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d1')}>−</button><span class="count-value">{counts['d1']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d1')}>+</button></td><td class="total-cell">{totals['d1'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />0.5</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d05')}>−</button><span class="count-value">{counts['d05']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d05')}>+</button></td><td class="total-cell">{totals['d05'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />0.25</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d025')}>−</button><span class="count-value">{counts['d025']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d025')}>+</button></td><td class="total-cell">{totals['d025'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">🪙 Coins</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('coins')}>−</button><span class="count-value">{counts['coins']}</span><button class="count-btn plus" on:click={() => openPopupAdd('coins')}>+</button></td><td class="total-cell">{totals['coins'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">⚠️ Damage</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('damage')}>−</button><span class="count-value">{counts['damage']}</span><button class="count-btn plus" on:click={() => openPopupAdd('damage')}>+</button></td><td class="total-cell">{totals['damage'].toLocaleString()}</td></tr>
						</tbody>
						<tfoot>
							<tr class="grand-total-row"><td colspan="2"><strong>Grand Total</strong></td><td class="total-cell"><strong>{grandTotal.toLocaleString()}</strong></td></tr>
						</tfoot>
					</table>
					
					<!-- ERP Balance and Difference Cards -->
					<div class="balance-cards-container">
						<!-- ERP Balance Card -->
						<div class="balance-card erp-card">
							<div class="balance-card-header">
								<span class="balance-icon">💰</span>
								<span>ERP Balance</span>
							</div>
							<div class="balance-card-body">
								<input 
									type="number" 
									class="erp-input" 
									bind:value={erpBalance}
									placeholder="Enter ERP balance"
								/>
							</div>
						</div>
						
						<!-- Difference Card -->
						<div class="balance-card difference-card" class:positive={difference > 0} class:negative={difference < 0} class:zero={difference === 0}>
							<div class="balance-card-header">
								<span class="balance-icon">{difference > 0 ? '📈' : difference < 0 ? '📉' : '⚖️'}</span>
								<span>Difference</span>
							</div>
							<div class="balance-card-body">
								<div class="difference-value-container">
									<span class="difference-value" class:positive={difference > 0} class:negative={difference < 0}>
										{difference > 0 ? '+' : ''}{difference.toLocaleString()}
									</span>
									{#if differenceRaw !== difference}
										<span class="exact-difference">
											Real Cash: {differenceRaw > 0 ? '+' : ''}{differenceRaw.toFixed(2)}
										</span>
									{/if}
								</div>
								<span class="difference-label">
									{#if difference > 0}
										Real Cash is Excess
									{:else if difference < 0}
										Real Cash is Short
									{:else}
										Balanced
									{/if}
								</span>
							</div>
						</div>
					</div>
					
					<!-- Petty Cash Box Card (Below ERP Balance) -->
					<div class="balance-card petty-cash-card">
						<div class="balance-card-header">
							<span class="balance-icon">💵</span>
							<span>Petty Cash</span>
						</div>
						<div class="balance-card-body">
							<div class="petty-cash-label">Petty Cash Balance</div>
							<button class="btn-open-petty-cash" on:click={openPettyCashForm}>
								<span class="balance-amount">💰 {pettyCashBalance.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR</span>
							</button>
						</div>
					</div>
				</div>
			</div>
		</div>
		
		<!-- Right Sidebar -->
		<div class="sidebar-container" class:open={isSidebarOpen}>
			<button class="sidebar-toggle" on:click={toggleSidebar}>
				{isSidebarOpen ? '▶' : '◀'}
			</button>
			{#if isSidebarOpen}
				<div class="sidebar-content">
					<!-- Branch Selection Card -->
					<div class="balance-card branch-selector-card">
						<div class="balance-card-header">
							<span class="balance-icon">📍</span>
							<span>Select Branch</span>
						</div>
						<div class="balance-card-body">
							<div class="form-group">
								<select 
									id="branch-select" 
									bind:value={selectedBranch}
									class="form-select branch-select"
								>
									<option value="">-- Select Branch --</option>
									{#each branches as branch (branch.id)}
										<option value={branch.id.toString()}>
											{getBranchDisplayName(branch)}
										</option>
									{/each}
								</select>
								
								{#if selectedBranch}
									<button 
										class="set-default-btn"
										class:is-default={isCurrentDefault}
										on:click={setAsDefault}
										disabled={isSavingDefault || isCurrentDefault}
									>
										{#if isSavingDefault}
											Saving...
										{:else if isCurrentDefault}
											✓ Default
										{:else}
											Set as Default
										{/if}
									</button>
								{/if}
								
								{#if showDefaultSaved}
									<div class="success-message">
										✓ Default branch saved successfully!
									</div>
								{/if}
							</div>
						</div>
					</div>
					
					<!-- Completed Operations Card -->
					<div class="balance-card completed-ops-card" on:click={openClosedBoxes}>
						<div class="balance-card-header">
							<span class="balance-icon">📋</span>
							<span>Completed Operations</span>
						</div>
						<div class="balance-card-body">
							<div class="closed-boxes-count-large">
								<span class="count-number">{closedBoxesCount}</span>
								<span class="count-label">Total Closed</span>
							</div>
						</div>
					</div>

					<!-- Pending to Close Card -->
					<div class="balance-card pending-ops-card" on:click={openPendingBoxes}>
						<div class="balance-card-header">
							<span class="balance-icon">⏳</span>
							<span>Pending to Close</span>
						</div>
						<div class="balance-card-body">
							<div class="closed-boxes-count-large">
								<span class="count-number">{pendingBoxesCount}</span>
								<span class="count-label">Pending Closure</span>
							</div>
						</div>
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- Delete Confirmation Popup -->
{#if showDeleteConfirmPopup}
<div class="popup-overlay" on:click={cancelDeleteTransaction} on:keydown={(e) => e.key === 'Escape' && cancelDeleteTransaction()}>
	<div class="confirm-popup" on:click|stopPropagation>
		<div class="confirm-header">
			<span>⚠️ Confirm Delete</span>
		</div>
		<div class="confirm-body">
			<p>Are you sure you want to delete this transaction?</p>
			<p style="color: #999; font-size: 0.85rem;">This action cannot be undone.</p>
		</div>
		<div class="confirm-actions">
			<button class="btn-cancel" on:click={cancelDeleteTransaction}>Cancel</button>
			<button class="btn-delete" on:click={confirmDeleteTransaction}>Delete</button>
		</div>
	</div>
</div>
{/if}

<!-- Success/Error Popup -->
{#if showSuccessPopup}
<div class="popup-overlay" on:click={closeNotification}>
	<div class="success-popup" class:error={successType === 'error'} on:click|stopPropagation>
		<div class="success-header" class:error={successType === 'error'}>
			<span class="success-icon">{successType === 'success' ? '✓' : '✕'}</span>
		</div>
		<div class="success-body">
			<p>{successMessage}</p>
		</div>
	</div>
</div>
{/if}

<style>
	.denomination-container {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: row;
		background: linear-gradient(135deg, #fef3e2 0%, #e8f5e9 50%, #fff8e1 100%);
		overflow: hidden;
		padding: 0.5rem;
		gap: 0.5rem;
	}

	/* Loading */
	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #fed7aa;
		border-top: 4px solid #f97316;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Cards Container */
	.cards-container {
		display: flex;
		gap: 0.25rem;
		flex-direction: column;
		width: auto;
		min-width: 30px;
		flex: 0 0 auto;
		overflow-y: auto;
	}

	/* Big Cards Container */
	.big-cards-container {
		display: flex;
		gap: 0.5rem;
		flex: 1;
		min-height: 0;
		min-width: 0;
	}

	.card {
		background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
		border-radius: 12px;
		box-shadow: 
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			0 2px 4px -1px rgba(0, 0, 0, 0.06),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
		flex: 0 0 auto;
		width: 100%;
		min-width: 30px;
		max-width: 100%;
		border: 1px solid rgba(249, 115, 22, 0.2);
		transition: all 0.3s ease;
		overflow: hidden;
	}

	.card:hover {
		transform: translateY(-2px);
		box-shadow: 
			0 10px 15px -3px rgba(249, 115, 22, 0.15),
			0 4px 6px -2px rgba(0, 0, 0, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
	}

	.card.closed-boxes-card {
		cursor: pointer;
		user-select: none;
	}

	.card.closed-boxes-card:hover {
		transform: translateY(-4px);
		box-shadow: 
			0 16px 32px rgba(249, 115, 22, 0.25),
			0 6px 12px rgba(0, 0, 0, 0.12),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
	}

	.card.closed-boxes-card:active {
		transform: translateY(-1px);
	}

	.closed-boxes-body {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 20px;
	}

	.card.big-card {
		flex: 1 1 calc(50% - 0.25rem);
		min-width: 0;
		max-width: none;
		display: flex;
		flex-direction: column;
		border-radius: 12px;
	}

	.big-card .card-body {
		overflow-y: auto;
		padding: 0.75rem;
	}

	.big-card .card-body.suspends-body {
		flex: 0 0 auto;
		padding: 0.5rem;
	}

	.big-card .card-body.suspends-body-second {
		flex: 1 1 auto;
		min-height: 0;
		overflow-y: auto;
		padding: 0.5rem;
	}

	.card-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid rgba(34, 197, 94, 0.2);
		background: linear-gradient(135deg, #f97316 0%, #fb923c 50%, #fdba74 100%);
		border-radius: 12px 12px 0 0;
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.3);
		min-width: 0;
		overflow: hidden;
	}

	.card-icon {
		font-size: 1.2rem;
		flex-shrink: 0;
		filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.2));
	}

	.currency-icon {
		width: 20px;
		height: 20px;
		object-fit: contain;
		filter: brightness(0) invert(1) drop-shadow(0 1px 1px rgba(0, 0, 0, 0.2));
	}

	.denomination-icon {
		width: 10px;
		height: 10px;
		object-fit: contain;
		vertical-align: middle;
		margin-right: 2px;
	}

	.nowrap {
		white-space: nowrap;
		display: inline-flex;
		align-items: center;
	}

	.card-title {
		font-size: 1rem;
		font-weight: 700;
		color: white;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		min-width: 0;
	}

	.save-status {
		margin-left: auto;
		font-size: 0.85rem;
		font-weight: 500;
	}

	.save-status .saving {
		color: #fef3c7;
		animation: pulse 1s infinite;
	}

	.save-status .saved {
		color: #bbf7d0;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.card-body {
		padding: 0.025rem;
	}

	/* Form elements */
	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.015rem;
	}

	.form-group label {
		font-size: 0.4rem;
		font-weight: 600;
		color: #166534;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.form-select {
		width: 100%;
		padding: 0rem 0.03rem;
		font-size: 0.32rem;
		border: 1px solid #86efac;
		border-radius: 1px;
		background: linear-gradient(145deg, #ffffff 0%, #f0fdf4 100%);
		color: #166534;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 
			0 1px 2px rgba(34, 197, 94, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.8);
		line-height: 1;
		height: 18px;
		overflow: hidden;
		white-space: nowrap;
		text-overflow: ellipsis;
		max-width: 95px;
	}

	.form-select:hover {
		border-color: #22c55e;
		box-shadow: 0 4px 8px rgba(34, 197, 94, 0.2);
	}

	.form-select:focus {
		outline: none;
		border-color: #16a34a;
		box-shadow: 
			0 0 0 3px rgba(34, 197, 94, 0.2),
			0 4px 8px rgba(34, 197, 94, 0.15);
	}

	.set-default-btn {
		margin-top: 0.025rem;
		padding: 0.06rem 0.2rem;
		font-size: 0.35rem;
		font-weight: 600;
		border: none;
		border-radius: 2px;
		cursor: pointer;
		transition: all 0.3s ease;
		line-height: 1;
		text-transform: uppercase;
		letter-spacing: 0.15px;
		background: linear-gradient(145deg, #22c55e 0%, #16a34a 100%);
		color: white;
		box-shadow: 
			0 4px 6px rgba(34, 197, 94, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.set-default-btn:hover:not(:disabled) {
		background: linear-gradient(145deg, #16a34a 0%, #15803d 100%);
		transform: translateY(-1px);
		box-shadow: 
			0 6px 10px rgba(34, 197, 94, 0.4),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
	}

	.set-default-btn:active:not(:disabled) {
		transform: translateY(0);
		box-shadow: 
			0 2px 4px rgba(34, 197, 94, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
	}

	.set-default-btn:disabled {
		cursor: not-allowed;
		opacity: 0.7;
	}

	.set-default-btn.is-default {
		background: linear-gradient(145deg, #f97316 0%, #ea580c 100%);
		box-shadow: 
			0 4px 6px rgba(249, 115, 22, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2);
		cursor: default;
	}

	.success-message {
		margin-top: 0.35rem;
		padding: 0.3rem 0.5rem;
		background: linear-gradient(145deg, #dcfce7 0%, #bbf7d0 100%);
		color: #166534;
		border-radius: 6px;
		font-size: 0.55rem;
		font-weight: 600;
		border: 1px solid #86efac;
		box-shadow: 0 2px 4px rgba(34, 197, 94, 0.1);
	}

	.hint {
		margin: 0;
		color: #9ca3af;
		font-size: 0.65rem;
		font-style: italic;
	}

	/* Denomination Table */
	.denomination-table {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		font-size: 1rem;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.07);
	}

	.denomination-table th,
	.denomination-table td {
		padding: 0.5rem 0.65rem;
		text-align: left;
		vertical-align: middle;
	}

	.denomination-table th {
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		font-weight: 700;
		color: white;
		font-size: 0.85rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
		border-bottom: 2px solid #15803d;
	}

	.denomination-table td {
		background: linear-gradient(145deg, #ffffff 0%, #fefefe 100%);
		border-bottom: 1px solid #e5e7eb;
		transition: all 0.2s ease;
	}

	.denomination-table tbody tr:nth-child(even) td {
		background: linear-gradient(145deg, #f0fdf4 0%, #fef3e2 100%);
	}

	.denomination-table tbody tr:hover td {
		background: linear-gradient(145deg, #fef3c7 0%, #fed7aa 100%);
		transform: scale(1.01);
	}

	.denomination-table tbody tr:first-child td {
		border-top: none;
	}

	.denomination-table tbody tr:last-child td {
		border-bottom: none;
	}

	.denomination-table tbody tr:last-child td:first-child {
		border-bottom-left-radius: 8px;
	}

	.denomination-table tbody tr:last-child td:last-child {
		border-bottom-right-radius: 8px;
	}

	/* Count cell with buttons */
	.count-cell {
		white-space: nowrap;
		text-align: center;
		vertical-align: middle;
		padding: 0.5rem 0.65rem !important;
	}

	.count-btn {
		width: 22px;
		height: 22px;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s ease;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		vertical-align: middle;
		margin: 0 8px;
	}

	.count-btn.minus {
		background: linear-gradient(145deg, #f87171 0%, #ef4444 100%);
		color: white;
		box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
	}

	.count-btn.minus:hover {
		background: linear-gradient(145deg, #ef4444 0%, #dc2626 100%);
		transform: scale(1.1);
	}

	.count-btn.plus {
		background: linear-gradient(145deg, #4ade80 0%, #22c55e 100%);
		color: white;
		box-shadow: 0 2px 4px rgba(34, 197, 94, 0.3);
	}

	.count-btn.plus:hover {
		background: linear-gradient(145deg, #22c55e 0%, #16a34a 100%);
		transform: scale(1.1);
	}

	.count-value {
		display: inline-block;
		min-width: 30px;
		text-align: center;
		font-weight: 600;
		font-size: 0.75rem;
		color: #1e293b;
	}

	button.count-value {
		background: linear-gradient(145deg, #fef3c7 0%, #fde68a 100%);
		border: 1px solid #f59e0b;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	button.count-value:hover {
		background: linear-gradient(145deg, #fde68a 0%, #fcd34d 100%);
		transform: scale(1.05);
	}

	.total-cell {
		font-weight: 600;
		color: #166534;
		text-align: right !important;
	}

	/* Grand Total Row */
	.grand-total-row td {
		background: linear-gradient(135deg, #f97316 0%, #fb923c 100%) !important;
		color: white;
		font-size: 0.75rem;
	}

	.grand-total-row .total-cell {
		color: white;
	}

	.denomination-table tfoot tr:last-child td:first-child {
		border-bottom-left-radius: 8px;
	}

	.denomination-table tfoot tr:last-child td:last-child {
		border-bottom-right-radius: 8px;
	}

	/* Popup Modal Styles */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
	}

	.popup-modal {
		background: white;
		border-radius: 16px;
		box-shadow: 
			0 25px 50px -12px rgba(0, 0, 0, 0.25),
			0 0 0 1px rgba(255, 255, 255, 0.1);
		min-width: 280px;
		max-width: 90%;
		overflow: hidden;
	}

	.popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.75rem 1rem;
		background: linear-gradient(135deg, #f97316 0%, #fb923c 100%);
		color: white;
		font-weight: 600;
		font-size: 0.85rem;
	}

	.popup-close {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 0.8rem;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.popup-close:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	.popup-body {
		padding: 1.5rem;
	}

	.current-count-label {
		text-align: center;
		margin-bottom: 0.75rem;
		font-size: 0.9rem;
		color: #64748b;
	}

	.current-count-label strong {
		color: #1e293b;
		font-size: 1.1rem;
	}

	.popup-input {
		width: 100%;
		padding: 0.75rem 1rem;
		font-size: 1.5rem;
		font-weight: 600;
		text-align: center;
		border: 2px solid #22c55e;
		border-radius: 12px;
		background: linear-gradient(145deg, #f0fdf4 0%, #dcfce7 100%);
		color: #166534;
		outline: none;
		transition: all 0.2s;
	}

	.popup-input:focus {
		border-color: #16a34a;
		box-shadow: 0 0 0 4px rgba(34, 197, 94, 0.2);
	}

	.popup-footer {
		display: flex;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #f8fafc;
		border-top: 1px solid #e5e7eb;
	}

	.popup-btn {
		flex: 1;
		padding: 0.6rem 1rem;
		font-size: 0.85rem;
		font-weight: 600;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.popup-btn.cancel {
		background: linear-gradient(145deg, #f1f5f9 0%, #e2e8f0 100%);
		color: #64748b;
	}

	.popup-btn.cancel:hover {
		background: linear-gradient(145deg, #e2e8f0 0%, #cbd5e1 100%);
	}

	.popup-btn.save {
		background: linear-gradient(145deg, #22c55e 0%, #16a34a 100%);
		color: white;
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.3);
	}

	.popup-btn.save:hover {
		background: linear-gradient(145deg, #16a34a 0%, #15803d 100%);
		transform: translateY(-1px);
	}

	.popup-btn.save.subtract {
		background: linear-gradient(145deg, #f87171 0%, #ef4444 100%);
		box-shadow: 0 4px 6px rgba(239, 68, 68, 0.3);
	}

	.popup-btn.save.subtract:hover {
		background: linear-gradient(145deg, #ef4444 0%, #dc2626 100%);
	}

	.popup-header.subtract {
		background: linear-gradient(135deg, #ef4444 0%, #f87171 100%);
	}

	/* Balance Cards Container */
	.balance-cards-container {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-top: 1rem;
		padding-top: 0.75rem;
		border-top: 2px dashed rgba(249, 115, 22, 0.3);
	}

	.balance-column-left {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		flex: 1;
	}

	.balance-column-right {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		flex: 1;
	}

	.balance-card {
		background: white;
		width: 100%;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			0 2px 4px -1px rgba(0, 0, 0, 0.06);
		transition: all 0.3s ease;
	}

	.completed-ops-card {
		cursor: pointer;
		flex: 0 0 auto;
	}

	.completed-ops-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 12px -2px rgba(0, 0, 0, 0.15);
	}

	.completed-ops-card .balance-card-header {
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
	}

	.completed-ops-card .balance-card-body {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.closed-boxes-count-large {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
	}

	.count-number {
		font-size: 2rem;
		font-weight: 700;
		color: #8b5cf6;
	}

	.count-label {
		font-size: 0.75rem;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.pending-ops-card {
		cursor: pointer;
		flex: 0 0 auto;
	}

	.pending-ops-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 12px -2px rgba(0, 0, 0, 0.15);
	}

	.pending-ops-card .balance-card-header {
		background: linear-gradient(135deg, #f59e0b 0%, #fbbf24 100%);
	}

	.pending-ops-card .balance-card-body {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.pending-ops-card .count-number {
		color: #f59e0b;
	}

	.branch-selector-card {
		flex: 0 0 auto;
		display: flex;
		flex-direction: column;
		width: 100%;
	}

	.branch-selector-card .balance-card-header {
		background: linear-gradient(135deg, #f97316 0%, #fb923c 100%);
	}

	.branch-selector-card .balance-card-body {
		padding: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		background: white;
	}

	.branch-selector-card .form-group {
		display: flex;
		flex-direction: column;
		align-items: stretch;
		gap: 0.5rem;
		width: 100%;
	}

	.branch-selector-card .form-select {
		flex: 1;
		min-width: 0;
		width: 100%;
		max-width: 100%;
		box-sizing: border-box;
		padding: 0.5rem 2.5rem 0.5rem 0.75rem;
		font-size: 0.9rem;
		font-weight: 600;
		border: 2px solid #f97316;
		border-radius: 8px;
		background: linear-gradient(145deg, #fff7ed 0%, #ffedd5 100%);
		color: #7c2d12;
		outline: none;
		transition: all 0.2s;
		appearance: none;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'%3E%3Cpath fill='%237c2d12' d='M8 12L2 6h12z'/%3E%3C/svg%3E");
		background-repeat: no-repeat;
		background-position: right 0.75rem center;
		min-height: 42px;
	}

	.branch-selector-card .form-select option {
		color: #7c2d12;
		font-size: 1rem;
		padding: 0.5rem;
		background: white;
	}

	.branch-selector-card .form-select:focus {
		border-color: #ea580c;
		box-shadow: 0 0 0 4px rgba(249, 115, 22, 0.2);
	}

	.branch-selector-card .set-default-btn {
		flex: 0 0 auto;
		white-space: nowrap;
		padding: 0.4rem 0.75rem;
		font-size: 0.8rem;
		border: 2px solid #22c55e;
		border-radius: 8px;
		background: linear-gradient(145deg, #f0fdf4 0%, #dcfce7 100%);
		color: #15803d;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 600;
	}

	.branch-selector-card .set-default-btn:hover:not(:disabled) {
		background: linear-gradient(145deg, #22c55e 0%, #16a34a 100%);
		color: white;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.3);
	}

	.branch-selector-card .set-default-btn.is-default {
		background: linear-gradient(145deg, #22c55e 0%, #16a34a 100%);
		color: white;
		border-color: #16a34a;
	}

	.branch-selector-card .set-default-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.branch-selector-card .success-message {
		padding: 0.6rem;
		background: linear-gradient(145deg, #d1fae5 0%, #a7f3d0 100%);
		border-radius: 8px;
		border: 2px solid #22c55e;
		color: #065f46;
		font-size: 0.85rem;
		text-align: center;
		font-weight: 600;
	}

	.balance-card:hover {
		transform: translateY(-2px);
		box-shadow: 
			0 10px 15px -3px rgba(0, 0, 0, 0.1),
			0 4px 6px -2px rgba(0, 0, 0, 0.05);
	}

	.balance-card-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		font-weight: 600;
		font-size: 0.8rem;
		color: white;
	}

	.erp-card .balance-card-header {
		background: linear-gradient(135deg, #3b82f6 0%, #60a5fa 100%);
	}

	.difference-card .balance-card-header {
		background: linear-gradient(135deg, #64748b 0%, #94a3b8 100%);
	}

	.difference-card.positive .balance-card-header {
		background: linear-gradient(135deg, #22c55e 0%, #4ade80 100%);
	}

	.difference-card.negative .balance-card-header {
		background: linear-gradient(135deg, #ef4444 0%, #f87171 100%);
	}

	.balance-icon {
		font-size: 0.9rem;
	}

	.balance-card-body {
		padding: 0.4rem;
		background: white;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.2rem;
	}

	.erp-input {
		width: 100%;
		padding: 0.4rem 0.6rem;
		font-size: 0.9rem;
		font-weight: 600;
		text-align: center;
		border: 2px solid #3b82f6;
		border-radius: 8px;
		background: linear-gradient(145deg, #eff6ff 0%, #dbeafe 100%);
		color: #1e40af;
		outline: none;
		transition: all 0.2s;
	}

	.erp-input:focus {
		border-color: #2563eb;
		box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.2);
	}

	.erp-input::placeholder {
		color: #93c5fd;
		font-weight: 400;
		font-size: 0.85rem;
	}

	.difference-value {
		font-size: 0.9rem;
		font-weight: 700;
		color: #64748b;
	}

	.difference-value.positive {
		color: #16a34a;
	}

	.difference-value.negative {
		color: #dc2626;
	}

	.difference-label {
		font-size: 0.55rem;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.difference-value-container {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.exact-difference {
		font-size: 0.75rem;
		color: #64748b;
		font-weight: 500;
		opacity: 0.8;
	}

	/* Suspends Section Styles */
	.suspends-body {
		display: flex;
		flex-direction: row;
		gap: 0.75rem;
		padding: 0.5rem !important;
		padding-bottom: 0.25rem !important;
		overflow: hidden;
		min-height: 0;
	}

	.suspends-body-second {
		padding-top: 0 !important;
		display: flex !important;
		flex-direction: column !important;
		gap: 0.75rem !important;
		min-height: 0;
	}

	.suspends-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		min-height: 0;
	}

	.suspends-section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 0.4rem 0.75rem;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.8rem;
		color: white;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.header-total {
		flex: 1;
		text-align: center;
		font-size: 0.9rem;
		font-weight: 700;
	}

	.total-breakdown {
		display: flex;
		gap: 1rem;
		justify-content: center;
		flex-wrap: wrap;
		align-items: center;
	}

	.total-item {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		background: rgba(255, 255, 255, 0.15);
		padding: 0.3rem 0.8rem;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.total-item.applied {
		background: rgba(34, 197, 94, 0.25);
		border: 1px solid rgba(34, 197, 94, 0.4);
	}

	.total-item.not-applied {
		background: rgba(249, 115, 22, 0.25);
		border: 1px solid rgba(249, 115, 22, 0.4);
	}

	.total-item.grand-total {
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
	}

	.total-item .amount {
		font-weight: 700;
		font-size: 0.8rem;
	}

	.total-amount {
		display: inline-block;
		background: rgba(255, 255, 255, 0.2);
		padding: 0.3rem 0.8rem;
		border-radius: 6px;
		margin-left: 0.5rem;
	}

	.action-buttons-group {
		display: flex;
		gap: 0.4rem;
		align-items: center;
	}

	.action-btn {
		background: rgba(255, 255, 255, 0.25);
		border: 1px solid rgba(255, 255, 255, 0.4);
		color: white;
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.3rem 0.6rem;
		border-radius: 5px;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
	}

	.action-btn:hover {
		background: rgba(255, 255, 255, 0.4);
		transform: translateY(-1px);
	}

	.action-btn:active {
		transform: translateY(0);
	}

	.action-btn.vendor-btn { }
	.action-btn.expenses-btn { }
	.action-btn.user-btn { }
	.action-btn.other-btn { }

	.suspends-section-header.paid {
		background: linear-gradient(135deg, #ef4444 0%, #f87171 100%);
	}

	.suspends-section-header.received {
		background: linear-gradient(135deg, #22c55e 0%, #4ade80 100%);
	}

	.suspends-section-header.advance-manager {
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
	}

	.suspends-section-header.collection-manager {
		background: linear-gradient(135deg, #3b82f6 0%, #60a5fa 100%);
	}

	.section-icon {
		font-size: 0.85rem;
	}

	.suspends-cards-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 0.5rem;
	}

	.suspend-card {
		background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
		border: 1px solid rgba(0, 0, 0, 0.08);
		border-radius: 8px;
		padding: 0.5rem;
		text-align: center;
		box-shadow: 
			0 2px 4px -1px rgba(0, 0, 0, 0.06),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
		transition: all 0.2s ease;
		min-height: 80px;
		height: 80px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-direction: column;
	}

	.suspend-card:hover {
		transform: translateY(-1px);
		box-shadow: 
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
	}

	.suspend-card .hint {
		margin: 0;
		font-size: 0.7rem;
		color: #94a3b8;
	}

	/* Clickable Box Styles */
	.suspend-card.clickable-box {
		cursor: pointer;
		border: 2px dashed #a78bfa;
		background: linear-gradient(145deg, #faf5ff 0%, #f3e8ff 100%);
		transition: all 0.2s ease;
		padding: 0.5rem;
		min-height: 70px;
		height: 70px;
	}

	.suspend-card.clickable-box.special-box {
		border: 2px solid #f87171;
		background: linear-gradient(145deg, #fecaca 0%, #fca5a5 100%);
		box-shadow: 0 4px 6px -1px rgba(239, 68, 68, 0.2), inset 0 1px 0 rgba(255, 255, 255, 0.6);
	}

	.suspend-card.clickable-box.special-box:hover {
		background: linear-gradient(145deg, #f87171 0%, #f05252 100%);
		border-color: #dc2626;
		box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.6);
	}

	.suspend-card.clickable-box:hover {
		border-color: #8b5cf6;
		background: linear-gradient(145deg, #f3e8ff 0%, #ede9fe 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px rgba(139, 92, 246, 0.2);
	}

	.suspend-card.clickable-box.has-value {
		border-style: solid;
		border-color: #8b5cf6;
		background: linear-gradient(145deg, #ede9fe 0%, #ddd6fe 100%);
	}

	.suspend-card.clickable-box.in-use {
		border-style: solid;
		border-color: #f59e0b;
		background: linear-gradient(145deg, #fef3c7 0%, #fde68a 100%);
		cursor: not-allowed;
		opacity: 1;
		min-height: 70px;
		height: 70px;
	}

	.suspend-card.clickable-box.in-use:hover {
		transform: none;
		box-shadow: none;
		background: linear-gradient(145deg, #fef3c7 0%, #fde68a 100%);
	}

	.box-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		width: 100%;
		height: 100%;
	}

	.box-label {
		font-size: 0.55rem;
		font-weight: 600;
		color: #7c3aed;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.box-total {
		font-size: 0.9rem;
		font-weight: 700;
		color: #5b21b6;
	}

	.box-empty {
		font-size: 0.65rem;
		color: #a78bfa;
		font-style: italic;
		font-weight: 500;
	}

	.box-status.in-use {
		font-size: 0.55rem;
		font-weight: 700;
		color: #d97706;
		background: #fbbf24;
		padding: 0.1rem 0.3rem;
		border-radius: 0.25rem;
		text-transform: uppercase;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.box-status.pending-close {
		font-size: 0.55rem;
		font-weight: 700;
		color: #ea580c;
		background: #fed7aa;
		padding: 0.1rem 0.3rem;
		border-radius: 0.25rem;
		text-transform: uppercase;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.box-supervisor {
		color: #ea580c;
		font-weight: 600;
		font-size: 0.7rem;
	}

	.pending-box-card {
		background: linear-gradient(135deg, #fef3c7 0%, #fed7aa 100%);
		border: 2px solid #f59e0b;
		border-radius: 0.5rem;
		padding: 0.35rem;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		height: 70px;
		min-height: 70px;
		overflow: hidden;
	}

	.pending-box-card:hover {
		background: linear-gradient(135deg, #fde68a 0%, #fecb8c 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
	}

	.pending-box-card .box-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.3rem;
	}

	.pending-box-card .box-label {
		font-size: 0.65rem;
		font-weight: 700;
		color: #92400e;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.pending-badge {
		font-size: 0.5rem;
		font-weight: 700;
		color: #ea580c;
		background: #fff7ed;
		padding: 0.15rem 0.4rem;
		border-radius: 0.25rem;
		text-transform: uppercase;
	}

	.pending-box-card .box-info {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		font-size: 0.65rem;
	}

	.pending-box-card .info-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.pending-box-card .label {
		color: #92400e;
		font-weight: 600;
	}

	.pending-box-card .value {
		color: #78350f;
		font-weight: 500;
	}

	.pending-box-card .action {
		text-align: center;
		font-size: 0.55rem;
		font-weight: 700;
		color: #ea580c;
		background: #fff7ed;
		padding: 0.2rem;
		border-radius: 0.25rem;
		text-transform: uppercase;
		letter-spacing: 0.02em;
	}

	.pending-box-card:hover .action {
		background: #f5f3ff;
		color: #7c2d12;
	}

	.box-username {
		font-size: 0.55rem;
		color: #92400e;
		font-weight: 600;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* Cash Box Modal Styles */
	.cashbox-modal {
		background: white;
		border-radius: 16px;
		box-shadow: 
			0 25px 50px -12px rgba(0, 0, 0, 0.25),
			0 0 0 1px rgba(255, 255, 255, 0.1);
		width: 450px;
		max-width: 95%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.cashbox-header {
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%) !important;
	}

	.cashbox-modal-body {
		padding: 1rem;
		overflow-y: auto;
		flex: 1;
	}

	.cashbox-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0.75rem;
		background: linear-gradient(145deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 8px;
		margin-bottom: 0.75rem;
		border: 1px solid #86efac;
	}

	.info-label {
		font-size: 0.75rem;
		color: #166534;
		font-weight: 500;
	}

	.info-value {
		font-size: 0.9rem;
		font-weight: 700;
		color: #15803d;
	}

	.cashbox-denomination-grid {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.cashbox-denom-row {
		display: grid;
		grid-template-columns: 90px 70px 120px 70px;
		gap: 0.5rem;
		align-items: center;
		padding: 0.35rem 0.5rem;
		background: #f8fafc;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.cashbox-denom-row:hover {
		background: #f1f5f9;
	}

	.petty-cash-count-controls {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
	}

	.petty-cash-count-display {
		min-width: 50px;
		text-align: center;
		font-weight: 600;
		cursor: pointer;
		border: none;
		background: transparent;
		color: #1e293b;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.petty-cash-count-display:hover {
		background: #e2e8f0;
		color: #0f172a;
	}

	.denom-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #1e293b;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.denom-available {
		font-size: 0.65rem;
		color: #64748b;
		text-align: center;
	}

	.denom-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		font-size: 0.8rem;
		font-weight: 600;
		text-align: center;
		border: 2px solid #a78bfa;
		border-radius: 6px;
		background: white;
		color: #5b21b6;
		outline: none;
		transition: all 0.2s;
	}

	.denom-input:focus {
		border-color: #8b5cf6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.2);
	}

	.denom-subtotal {
		font-size: 0.75rem;
		font-weight: 600;
		color: #166534;
		text-align: right;
	}

	.add-back-btn {
		padding: 0.25rem 0.5rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 0.65rem;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
		transition: all 0.2s ease;
	}

	.add-back-btn:hover {
		background: #dc2626;
		transform: scale(1.05);
	}

	.add-back-btn:active {
		transform: scale(0.95);
	}

	.cashbox-total-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem;
		margin-top: 0.75rem;
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
		border-radius: 8px;
		color: white;
		font-weight: 600;
	}

	.cashbox-total-value {
		font-size: 1.1rem;
		font-weight: 700;
	}

	.petty-cash-notes-display {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 0.75rem;
		margin-top: 0.75rem;
		background: #f8fafc;
		border-radius: 8px;
		border-left: 3px solid #8b5cf6;
	}

	.notes-label {
		font-size: 0.8rem;
		font-weight: 600;
		color: #475569;
	}

	.notes-value {
		font-size: 0.8rem;
		color: #64748b;
		max-width: 70%;
		text-align: right;
	}

	/* Closed Boxes Button */
	.closed-boxes-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border: none;
		border-radius: 0.75rem;
		color: white;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s;
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.75rem;
	}

	.closed-boxes-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(102, 126, 234, 0.4);
	}

	.closed-boxes-btn:active {
		transform: translateY(0);
	}

	.btn-icon {
		font-size: 1.5rem;
	}

	.btn-text {
		flex: 1;
		text-align: center;
	}

	.btn-arrow {
		font-size: 1.2rem;
		transition: transform 0.3s;
	}

	.closed-boxes-btn:hover .btn-arrow {
		transform: translateX(5px);
	}

	.closed-boxes-count {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		margin: 0.5rem 0;
		padding: 0.5rem;
		background: linear-gradient(135deg, #f97316 0%, #fb923c 100%);
		border-radius: 8px;
		box-shadow: 0 4px 8px rgba(249, 115, 22, 0.2);
	}

	.closed-boxes-count-large {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.08rem;
		padding: 0.15rem;
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		border-radius: 4px;
		box-shadow: 0 2px 4px rgba(31, 122, 58, 0.15);
	}

	.count-number {
		font-size: 0.8rem;
		font-weight: 800;
		color: white;
		line-height: 1;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.count-label {
		font-size: 0.3rem;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.95);
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	/* Modal Styles */
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
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		max-width: 600px;
		width: 90%;
		max-height: 85vh;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e2e8f0;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border-radius: 12px 12px 0 0;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.2rem;
	}

	.modal-close {
		background: none;
		border: none;
		color: white;
		font-size: 1.5rem;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: background 0.2s;
	}

	.modal-close:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.modal-body {
		padding: 1.5rem;
		flex: 1;
		overflow-y: auto;
	}

	.modal-footer {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #e2e8f0;
		background: #f8fafc;
		border-radius: 0 0 12px 12px;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 600;
		color: #1e293b;
		font-size: 0.9rem;
	}

	.form-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		font-size: 0.9rem;
		font-family: inherit;
	}

	.form-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	textarea.form-input {
		resize: vertical;
		min-height: 80px;
	}

	.dropdown-list {
		margin-top: 0.5rem;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		max-height: 200px;
		overflow-y: auto;
		background: white;
	}

	.dropdown-item {
		padding: 0.75rem;
		cursor: pointer;
		border-bottom: 1px solid #e2e8f0;
		transition: background 0.2s;
	}

	.dropdown-item:hover {
		background: #f0f4f8;
	}

	.dropdown-item.selected {
		background: #e0e7ff;
		color: #667eea;
		font-weight: 600;
	}

	.item-name {
		font-weight: 600;
		color: #1e293b;
	}

	.item-code {
		font-size: 0.8rem;
		color: #64748b;
		margin-top: 0.25rem;
	}

	.dropdown-actions {
		margin-bottom: 1rem;
	}

	.btn-create-new {
		width: 100%;
		padding: 0.75rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-create-new:hover {
		background: #059669;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: normal;
		margin-bottom: 0;
	}

	.checkbox-label input {
		cursor: pointer;
		width: 18px;
		height: 18px;
	}

	.denomination-grid {
		background: #f8fafc;
		padding: 1rem;
		border-radius: 6px;
		border: 1px solid #cbd5e1;
	}

	.denomination-grid h4 {
		margin-top: 0;
		margin-bottom: 1rem;
		color: #1e293b;
	}

	.denom-field {
		margin-bottom: 1rem;
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 0.5rem;
		align-items: end;
	}

	.denom-field label {
		grid-column: 1 / -1;
		margin-bottom: 0.25rem;
		font-size: 0.8rem;
	}

	.denom-field input {
		grid-column: 1 / 3;
		padding: 0.5rem;
		font-size: 0.85rem;
	}

	.denom-field small {
		grid-column: 3;
		font-size: 0.75rem;
		color: #64748b;
		text-align: right;
	}

	.btn-cancel,
	.btn-save {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		flex: 1;
		font-size: 0.9rem;
	}

	.btn-cancel {
		background: #e2e8f0;
		color: #64748b;
	}

	.btn-cancel:hover {
		background: #cbd5e1;
	}

	.btn-save {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.btn-save:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
	}

	.btn-save:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Transactions Table Styles */
	.transactions-table-container {
		margin-top: 0.5rem;
		border: 1px solid rgba(0, 0, 0, 0.08);
		border-radius: 6px;
		overflow-y: auto;
		max-height: 210px;
		flex: 1;
		min-height: 0;
	}

	.transactions-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.85rem;
	}

	.transactions-table thead {
		background: linear-gradient(135deg, #f0f4f8 0%, #e8eef5 100%);
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.transactions-table th {
		padding: 0.5rem 0.4rem;
		text-align: left;
		font-weight: 600;
		color: #334155;
		border-bottom: 2px solid rgba(0, 0, 0, 0.1);
		font-size: 0.75rem;
	}

	.transactions-table td {
		padding: 0.5rem 0.4rem;
		border-bottom: 1px solid rgba(0, 0, 0, 0.06);
	}

	.transactions-table tbody tr:hover {
		background: rgba(102, 126, 234, 0.05);
	}

	.transactions-table tbody tr:last-child td {
		border-bottom: none;
	}

	.badge {
		display: inline-block;
		padding: 0.4rem 0.8rem;
		border-radius: 20px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: capitalize;
		white-space: nowrap;
	}

	.badge-vendor {
		background: #fee2e2;
		color: #991b1b;
	}

	.badge-expenses {
		background: #fef3c7;
		color: #92400e;
	}

	.badge-user {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-other {
		background: #f3e8ff;
		color: #6b21a8;
	}

	.entity-cell {
		font-weight: 500;
		color: #1e293b;
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		font-size: 0.65rem;
	}

	.amount-cell {
		font-weight: 600;
		color: #10b981;
	}

	.remarks-cell {
		color: #64748b;
		max-width: 150px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		font-size: 0.8rem;
	}

	.denom-cell {
		text-align: center;
		font-weight: 600;
	}

	.date-cell {
		color: #64748b;
		font-size: 0.8rem;
	}

	.empty-state {
		padding: 2rem;
		text-align: center;
		color: #94a3b8;
		font-style: italic;
	}

	.action-cell {
		text-align: center;
		padding: 0.5rem !important;
	}

	.delete-btn {
		width: 28px;
		height: 28px;
		border-radius: 50%;
		border: none;
		background: #ef4444;
		color: white;
		font-size: 1rem;
		font-weight: bold;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
		padding: 0;
		line-height: 1;
	}

	.delete-btn:hover {
		background: #dc2626;
		transform: scale(1.15);
		box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
	}

	.delete-btn:active {
		transform: scale(0.95);
	}

	.confirm-popup {
		background: white;
		border-radius: 8px;
		padding: 0;
		width: 320px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
		z-index: 10001;
	}

	.confirm-header {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: white;
		padding: 1rem;
		border-radius: 8px 8px 0 0;
		font-weight: bold;
		font-size: 0.95rem;
	}

	.confirm-body {
		padding: 1.2rem;
		text-align: center;
	}

	.confirm-body p {
		margin: 0.5rem 0;
		font-size: 0.9rem;
	}

	.confirm-actions {
		display: flex;
		gap: 0.75rem;
		padding: 0 1.2rem 1rem 1.2rem;
		justify-content: center;
	}

	.btn-cancel,
	.btn-delete {
		flex: 1;
		padding: 0.6rem 1rem;
		border: none;
		border-radius: 4px;
		font-weight: 600;
		cursor: pointer;
		font-size: 0.85rem;
		transition: all 0.2s ease;
	}

	.btn-cancel {
		background: #e5e7eb;
		color: #374151;
	}

	.btn-cancel:hover {
		background: #d1d5db;
	}

	.btn-delete {
		background: #ef4444;
		color: white;
	}

	.btn-delete:hover {
		background: #dc2626;
	}

	.btn-delete:active {
		transform: scale(0.98);
	}

	.success-popup {
		background: white;
		border-radius: 8px;
		padding: 0;
		width: 320px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
		z-index: 10001;
		animation: slideDown 0.3s ease;
	}

	.success-popup.error {
		animation: slideDown 0.3s ease;
	}

	@keyframes slideDown {
		from {
			transform: translateY(-20px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.success-header {
		background: linear-gradient(135deg, #22c55e, #16a34a);
		color: white;
		padding: 1rem;
		border-radius: 8px 8px 0 0;
		text-align: center;
		font-weight: bold;
		font-size: 1.2rem;
	}

	.success-header.error {
		background: linear-gradient(135deg, #ef4444, #dc2626);
	}

	.success-icon {
		display: inline-block;
		width: 36px;
		height: 36px;
		line-height: 36px;
		text-align: center;
		font-size: 1.5rem;
		color: white;
	}

	.success-body {
		padding: 1.2rem;
		text-align: center;
	}

	.success-body p {
		margin: 0;
		font-size: 0.9rem;
		color: #333;
		line-height: 1.4;
	}

	/* Sidebar Styles */
	.sidebar-container {
		position: relative;
		width: 0;
		transition: width 0.3s ease;
		background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
		border-radius: 12px;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
		overflow: visible;
		border: 1px solid rgba(249, 115, 22, 0.2);
	}

	.sidebar-container.open {
		width: 320px;
		margin-left: 0.5rem;
		overflow: hidden;
	}

	.sidebar-toggle {
		position: absolute;
		left: 0;
		top: 50%;
		transform: translateY(-50%);
		width: 24px;
		height: 48px;
		background: linear-gradient(145deg, #f97316 0%, #fb923c 100%);
		border: none;
		border-radius: 4px 0 0 4px;
		color: white;
		font-size: 0.8rem;
		font-weight: bold;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: -2px 2px 4px rgba(0, 0, 0, 0.2);
		z-index: 10;
		transition: all 0.2s ease;
	}
	
	.sidebar-container.open .sidebar-toggle {
		left: -12px;
	}

	.sidebar-toggle:hover {
		background: linear-gradient(145deg, #ea580c 0%, #f97316 100%);
		box-shadow: -3px 3px 6px rgba(0, 0, 0, 0.3);
	}

	.sidebar-content {
		height: 100%;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 1rem;
		overflow-y: auto;
	}

	.sidebar-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid rgba(249, 115, 22, 0.3);
	}

	.sidebar-icon {
		font-size: 1.5rem;
	}

	.sidebar-header h3 {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 700;
		color: #1e293b;
	}

	.sidebar-body {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.sidebar-card {
		background: linear-gradient(145deg, #ffffff 0%, #fef3e2 100%);
		border-radius: 8px;
		padding: 0.75rem;
		border: 1px solid rgba(249, 115, 22, 0.2);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		transition: all 0.2s ease;
	}

	.sidebar-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(249, 115, 22, 0.15);
	}

	.sidebar-card.positive {
		background: linear-gradient(145deg, #dcfce7 0%, #bbf7d0 100%);
		border-color: rgba(34, 197, 94, 0.3);
	}

	.sidebar-card.negative {
		background: linear-gradient(145deg, #fee2e2 0%, #fecaca 100%);
		border-color: rgba(239, 68, 68, 0.3);
	}

	.sidebar-card.zero {
		background: linear-gradient(145deg, #e0e7ff 0%, #c7d2fe 100%);
		border-color: rgba(99, 102, 241, 0.3);
	}

	.sidebar-card-title {
		font-size: 0.75rem;
		font-weight: 600;
		color: #64748b;
		margin-bottom: 0.25rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.sidebar-card-value {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1e293b;
	}

	.sidebar-card-value.positive {
		color: #16a34a;
	}

	.sidebar-card-value.negative {
		color: #dc2626;
	}

	.petty-cash-card {
		margin-top: 0.75rem;
		grid-column: 1 / -1;
	}

	.petty-cash-card .balance-card-body {
		min-height: 80px;
		justify-content: center;
		padding: 0.75rem 0.4rem;
	}

	.petty-cash-card .balance-card-header {
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
	}

	.petty-cash-label {
		font-size: 0.85rem;
		font-weight: 500;
		color: #666;
		margin-bottom: 0.5rem;
		text-align: center;
	}

	/* Petty Cash Button (matching advance boxes) */
	.btn-open-petty-cash {
		width: 100%;
		padding: 0.75rem;
		background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 0.95rem;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.balance-amount {
		font-size: 1rem;
		font-weight: 700;
		color: #ffffff;
		letter-spacing: 0.5px;
	}

	.btn-open-petty-cash:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(139, 92, 246, 0.4);
	}

	.btn-open-petty-cash:active {
		transform: translateY(0);
	}
</style>
