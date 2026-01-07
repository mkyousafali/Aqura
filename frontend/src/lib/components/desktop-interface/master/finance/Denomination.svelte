<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CompleteBox from './CompleteBox.svelte';
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
	let boxRecordIds: (string | null)[] = Array(9).fill(null);

	// Box operations tracking
	let boxOperations: Map<number, any> = new Map();

	onMount(async () => {
		await loadBranches();
		await loadUserPreferences();
		await loadDenominationTypes();
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

	async function handleBranchChange() {
		// Reset all data first
		resetCounts();
		cashBoxData = Array.from({ length: 9 }, () => ({
			'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
			'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
			'd025': 0, 'coins': 0, 'damage': 0
		}));
		mainRecordId = null;
		boxRecordIds = Array(9).fill(null);
		lastSaved = null;
		
		// Load data for new branch
		await loadExistingRecords();
		await fetchBoxOperations();
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
				cashBoxData = Array.from({ length: 9 }, () => ({
					'd500': 0, 'd200': 0, 'd100': 0, 'd50': 0, 'd20': 0,
					'd10': 0, 'd5': 0, 'd2': 0, 'd1': 0, 'd05': 0,
					'd025': 0, 'coins': 0, 'damage': 0
				}));
				boxRecordIds = Array(9).fill(null);

				// Populate from database (get most recent for each box)
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
			realtimeChannel.unsubscribe();
		}

		if (!selectedBranch) return;

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
					console.log('Realtime update:', payload);
					handleRealtimeUpdate(payload);
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
					console.log('Box operations update:', payload);
					await fetchBoxOperations();
				}
			)
			.subscribe();
	}

	function handleRealtimeUpdate(payload: any) {
		const { eventType, new: newRecord, old: oldRecord } = payload;

		if (eventType === 'INSERT' || eventType === 'UPDATE') {
			if (newRecord.record_type === 'main') {
				// Don't update if it's our own save (check by ID)
				if (newRecord.id !== mainRecordId) {
					mainRecordId = newRecord.id;
					counts = newRecord.counts || counts;
					erpBalance = newRecord.erp_balance || '';
					counts = { ...counts };
				}
			} else if (newRecord.record_type === 'advance_box') {
				const boxIndex = newRecord.box_number - 1;
				if (boxIndex >= 0 && boxIndex < 9 && newRecord.id !== boxRecordIds[boxIndex]) {
					boxRecordIds[boxIndex] = newRecord.id;
					cashBoxData[boxIndex] = newRecord.counts || cashBoxData[boxIndex];
					cashBoxData = [...cashBoxData];
				}
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
	let cashBoxData: Array<Record<string, number>> = Array.from({ length: 9 }, () => ({
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
				.select('id, box_number, user_id, notes, status, supervisor_id, closing_details, total_before, total_after')
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
	}

	async function completeBoxClose(boxNumber: number) {
		try {
			const operation = boxOperations.get(boxNumber);
			if (!operation) {
				console.error('Box operation not found');
				return;
			}

			console.log('📦 Opening CompleteBox window for box:', boxNumber, 'operation:', operation.id);

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
					branch: { id: selectedBranch }
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

	function openCashBoxModal(boxNumber: number) {
		// Check if box is in use
		if (boxOperations.has(boxNumber)) {
			const operation = boxOperations.get(boxNumber);
			alert(`This box is currently in use by ${operation.username || 'another user'} in POS.`);
			return;
		}
		
		selectedCashBox = boxNumber;
		const boxIndex = boxNumber - 1;
		// Load existing box data as current counts
		cashBoxCounts = { ...cashBoxData[boxIndex] };
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
	$: cashBoxInputTotal = Object.entries(cashBoxCounts).reduce((sum, [key, count]) => sum + count * denomValues[key], 0);

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
		showPopup = true;
	}

	function openPopupSubtract(key: string) {
		popupKey = key;
		popupValue = '';
		currentCount = counts[key];
		popupLabel = denomLabels[key] || key;
		popupMode = 'subtract';
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
			if (popupMode === 'add') {
				counts[popupKey] = counts[popupKey] + val;
			} else {
				counts[popupKey] = Math.max(0, counts[popupKey] - val);
			}
			counts = counts;
			triggerAutoSave(); // Auto-save after change
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

	// Calculate difference between grand total and ERP balance
	$: erpBalanceNumber = typeof erpBalance === 'string' ? (parseFloat(erpBalance) || 0) : erpBalance;
	$: difference = grandTotal - erpBalanceNumber;

	// Auto-save when ERP balance changes
	let prevErpBalance = erpBalance;
	$: if (erpBalance !== prevErpBalance && !isLoading && selectedBranch) {
		prevErpBalance = erpBalance;
		triggerAutoSave();
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
							placeholder="0"
						/>
						<div class="denom-subtotal">{((cashBoxCounts[key] || 0) * denomValues[key]).toLocaleString()}</div>
					</div>
				{/each}
			</div>
			<div class="cashbox-total-row">
				<span>Transfer Total:</span>
				<span class="cashbox-total-value">{cashBoxInputTotal.toLocaleString()} SAR</span>
			</div>
		</div>
		<div class="popup-footer">
			<button class="popup-btn cancel" on:click={closeCashBoxModal}>Cancel</button>
			<button class="popup-btn save" on:click={saveCashBoxDenomination}>Transfer to BOX {selectedCashBox}</button>
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

<div class="denomination-container">
	{#if isLoading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading...</p>
		</div>
	{:else}
		<!-- Two Cards Layout -->
		<div class="cards-container">
			<!-- Branch Selection Card -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">📍</span>
					<span class="card-title">Select Branch</span>
				</div>
				<div class="card-body">
					<div class="form-group">
						<label for="branch-select">Branch</label>
						<select 
							id="branch-select" 
							bind:value={selectedBranch}
							class="form-select"
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
			
			<!-- Blank Card 1 -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">1️⃣</span>
					<span class="card-title">Card 1</span>
				</div>
				<div class="card-body">
					<p class="hint">Content will be added here.</p>
				</div>
			</div>
			
			<!-- Blank Card 2 -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">2️⃣</span>
					<span class="card-title">Card 2</span>
				</div>
				<div class="card-body">
					<p class="hint">Content will be added here.</p>
				</div>
			</div>
			
			<!-- Blank Card 3 -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">3️⃣</span>
					<span class="card-title">Card 3</span>
				</div>
				<div class="card-body">
					<p class="hint">Content will be added here.</p>
				</div>
			</div>
			
			<!-- Blank Card 4 -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">4️⃣</span>
					<span class="card-title">Card 4</span>
				</div>
				<div class="card-body">
					<p class="hint">Content will be added here.</p>
				</div>
			</div>
			
			<!-- Blank Card 5 -->
			<div class="card">
				<div class="card-header">
					<span class="card-icon">5️⃣</span>
					<span class="card-title">Card 5</span>
				</div>
				<div class="card-body">
					<p class="hint">Content will be added here.</p>
				</div>
			</div>
		</div>
		
		<!-- Big Cards Row -->
		<div class="big-cards-container">
			<!-- Big Card Left -->
			<div class="card big-card">
				<div class="card-header">
					<span class="card-icon">⏸️</span>
					<span class="card-title">Suspends</span>
				</div>
				
				<!-- POS Advance Manager & POS Collection Manager Row -->
				<div class="card-body suspends-body">
					<!-- POS Advance Manager Section -->
					<div class="suspends-section">
						<div class="suspends-section-header advance-manager">
							<span class="section-icon">📤</span>
							<span>POS Advance Manager</span>
						</div>
						<div class="suspends-cards-grid">
							{#each [1, 2, 3, 4, 5, 6, 7, 8, 9] as boxNum}
								{@const isInUse = boxOperations.has(boxNum)}
								{@const operation = boxOperations.get(boxNum)}
								<button 
									class="suspend-card clickable-box"
									class:has-value={cashBoxTotals[boxNum - 1] > 0}
									class:in-use={isInUse}
									disabled={isInUse}
									on:click={() => openCashBoxModal(boxNum)}
								>
									<div class="box-content">
										<span class="box-label">BOX {boxNum}</span>
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
							{#each Array.from({ length: 9 }, (_, i) => i + 1) as boxNum (boxNum)}
								{@const operation = boxOperations.get(boxNum)}
								{@const isPending = operation?.isPendingClose}
								
								{#if isPending}
									<button class="pending-box-card" on:click={() => completeBoxClose(boxNum)}>
										<div class="box-header">
											<span class="box-label">BOX {boxNum}</span>
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
							<span class="section-icon">💸</span>
							<span>Paid</span>
						</div>
						<div class="suspends-cards-grid">
							<div class="suspend-card">
								<p class="hint">Card 1</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 2</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 3</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 4</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 5</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 6</p>
							</div>
						</div>
					</div>
					
					<!-- Received Section -->
					<div class="suspends-section">
						<div class="suspends-section-header received">
							<span class="section-icon">💰</span>
							<span>Received</span>
						</div>
						<div class="suspends-cards-grid">
							<div class="suspend-card">
								<p class="hint">Card 1</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 2</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 3</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 4</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 5</p>
							</div>
							<div class="suspend-card">
								<p class="hint">Card 6</p>
							</div>
						</div>
					</div>
				</div>
			</div>
			
			<!-- Denomination Table Card -->
			<div class="card big-card">
				<div class="card-header">
					<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
					<span class="card-title">Denomination</span>
					<div class="save-status">
						{#if isSaving}
							<span class="saving">💾 Saving...</span>
						{:else if lastSaved}
							<span class="saved">✓ Saved {lastSaved.toLocaleTimeString()}</span>
						{/if}
					</div>
				</div>
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
								<span class="difference-value" class:positive={difference > 0} class:negative={difference < 0}>
									{difference > 0 ? '+' : ''}{difference.toLocaleString()}
								</span>
								<span class="difference-label">
									{#if difference > 0}
										Over (Counted > ERP)
									{:else if difference < 0}
										Short (ERP > Counted)
									{:else}
										Balanced
									{/if}
								</span>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.denomination-container {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, #fef3e2 0%, #e8f5e9 50%, #fff8e1 100%);
		overflow: hidden;
		padding: 0.5rem;
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
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	/* Big Cards Container */
	.big-cards-container {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.5rem;
		flex: 1;
		min-height: 0;
	}

	.card {
		background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
		border-radius: 12px;
		box-shadow: 
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			0 2px 4px -1px rgba(0, 0, 0, 0.06),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
		flex: 1;
		min-width: 180px;
		max-width: 250px;
		border: 1px solid rgba(249, 115, 22, 0.2);
		transition: all 0.3s ease;
	}

	.card:hover {
		transform: translateY(-2px);
		box-shadow: 
			0 10px 15px -3px rgba(249, 115, 22, 0.15),
			0 4px 6px -2px rgba(0, 0, 0, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
	}

	.card.big-card {
		flex: 1 1 calc(50% - 0.25rem);
		min-width: 0;
		max-width: none;
		display: flex;
		flex-direction: column;
	}

	.big-card .card-body {
		overflow-y: auto;
	}

	.big-card .card-body.suspends-body {
		flex: 0 0 auto;
	}

	.card-header {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.4rem 0.6rem;
		border-bottom: 1px solid rgba(34, 197, 94, 0.2);
		background: linear-gradient(135deg, #f97316 0%, #fb923c 50%, #fdba74 100%);
		border-radius: 12px 12px 0 0;
		box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.3);
	}

	.card-icon {
		font-size: 0.7rem;
		filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.2));
	}

	.currency-icon {
		width: 13px;
		height: 13px;
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
		font-size: 0.7rem;
		font-weight: 700;
		color: white;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.save-status {
		margin-left: auto;
		font-size: 0.6rem;
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
		padding: 0.6rem;
	}

	/* Form elements */
	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.form-group label {
		font-size: 0.65rem;
		font-weight: 600;
		color: #166534;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.form-select {
		width: 100%;
		padding: 0.35rem 0.5rem;
		font-size: 0.7rem;
		border: 2px solid #86efac;
		border-radius: 8px;
		background: linear-gradient(145deg, #ffffff 0%, #f0fdf4 100%);
		color: #166534;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 
			0 2px 4px rgba(34, 197, 94, 0.1),
			inset 0 1px 0 rgba(255, 255, 255, 0.8);
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
		margin-top: 0.35rem;
		padding: 0.35rem 0.6rem;
		font-size: 0.6rem;
		font-weight: 600;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.3s ease;
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
		font-size: 0.7rem;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.07);
	}

	.denomination-table th,
	.denomination-table td {
		padding: 0.4rem 0.5rem;
		text-align: left;
	}

	.denomination-table th {
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		font-weight: 700;
		color: white;
		font-size: 0.65rem;
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
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
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
		display: flex;
		gap: 0.75rem;
		margin-top: 1rem;
		padding-top: 0.75rem;
		border-top: 2px dashed rgba(249, 115, 22, 0.3);
	}

	.balance-card {
		flex: 1;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			0 2px 4px -1px rgba(0, 0, 0, 0.06);
		transition: all 0.3s ease;
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
		padding: 0.75rem;
		background: white;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
	}

	.erp-input {
		width: 100%;
		padding: 0.6rem 0.75rem;
		font-size: 1.1rem;
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
		font-size: 1.3rem;
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
		font-size: 0.7rem;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	/* Suspends Section Styles */
	.suspends-body {
		display: flex;
		flex-direction: row;
		gap: 0.75rem;
		padding: 0.5rem !important;
		padding-bottom: 0.25rem !important;
	}

	.suspends-body-second {
		padding-top: 0 !important;
	}

	.suspends-section {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.suspends-section-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.4rem 0.75rem;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.8rem;
		color: white;
	}

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
		grid-template-columns: repeat(3, 1fr);
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
		grid-template-columns: 90px 70px 70px 70px;
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
</style>
