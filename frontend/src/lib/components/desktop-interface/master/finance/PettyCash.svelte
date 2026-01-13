<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface Branch {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		is_active: boolean;
	}

	interface BoxOperation {
		id: string;
		box_number: number;
		total_after: number;
		start_time: string;
		user_id: string;
		status: string;
		closing_details: {
			cash_sales?: number;
			bank_total?: number;
			total_sales?: number;
			closing_total?: number;
			bank_mada?: number;
			bank_visa?: number;
			bank_mastercard?: number;
			bank_google_pay?: number;
			bank_other?: number;
		} | null;
		hr_employee_master?: {
			name_en: string;
			name_ar: string;
		};
	}

	let branches: Branch[] = [];
	let selectedBranchId: number | null = null;
	let defaultBranchId: number | null = null;
	let loading = true;
	let saving = false;
	let successMessage = '';
	let errorMessage = '';
	let availableBoxes: BoxOperation[] = [];
	let loadingBoxes = false;
	let employeeMap: Map<string, string> = new Map();
	let selectedBox: BoxOperation | null = null;
	let pettyCashBalance = 0;
	let loadingPettyCash = false;
	let branchesChannel: any;
	let boxesChannel: any;
	let pettyCashChannel: any;
	let transferQuantities: Record<string, number> = {};
	let savingTransfer = false;
	let transferMessage = '';
	let transferError = '';
	let exceedMessage = '';

	onMount(async () => {
		try {
			// Fetch all active branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar, is_active')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// Set up real-time listener for branches
			branchesChannel = supabase
				.channel('branches-changes')
				.on(
					'postgres_changes',
					{ event: '*', schema: 'public', table: 'branches' },
					async (payload) => {
						console.log('Branch update:', payload);
						// Refresh branches list
						const { data: updatedBranches } = await supabase
							.from('branches')
							.select('id, name_en, name_ar, location_en, location_ar, is_active')
							.eq('is_active', true)
							.order('name_en');
						if (updatedBranches) {
							branches = updatedBranches;
						}
					}
				)
				.subscribe();

			// Fetch user's default branch preference
			if ($currentUser?.id) {
				const { data: prefData, error: prefError } = await supabase
					.from('denomination_user_preferences')
					.select('default_branch_id')
					.eq('user_id', $currentUser.id)
					.single();

				if (prefData) {
					defaultBranchId = prefData.default_branch_id;
					selectedBranchId = prefData.default_branch_id;
					if (selectedBranchId) {
						await loadAvailableBoxes();
						setupBoxesRealtime();
						await loadPettyCashBalance();
						setupPettyCashRealtime();
					}
				}
			}
		} catch (err) {
			console.error('Error loading branch data:', err);
			errorMessage = 'Failed to load branches';
		} finally {
			loading = false;
		}

		return () => {
			// Cleanup subscriptions on unmount
			if (branchesChannel) {
				supabase.removeChannel(branchesChannel);
			}
			if (boxesChannel) {
				supabase.removeChannel(boxesChannel);
			}
			if (pettyCashChannel) {
				supabase.removeChannel(pettyCashChannel);
			}
		};
	});

	$: if (selectedBranchId) {
		loadAvailableBoxes();
		loadPettyCashBalance();
		setupBoxesRealtime();
		setupPettyCashRealtime();
	}

	// Validate transfer quantities
	$: {
		exceedMessage = '';
		if (selectedBox?.closing_details?.closing_counts) {
			for (const [key, qty] of Object.entries(transferQuantities)) {
				const availableCount = selectedBox.closing_details.closing_counts[key] || 0;
				if (qty > availableCount) {
					exceedMessage = `⚠️ Cannot transfer more than available. ${getDenominationLabel(key)}: only ${availableCount} available, you entered ${qty}`;
					break;
				}
			}
		}
	}

	function setupBoxesRealtime() {
		// Clean up old subscription
		if (boxesChannel) {
			supabase.removeChannel(boxesChannel);
		}

		if (!selectedBranchId) return;

		// Set up real-time listener for box operations
		boxesChannel = supabase
			.channel(`boxes-${selectedBranchId}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations',
					filter: `branch_id=eq.${selectedBranchId}`
				},
				async (payload) => {
					console.log('Box operation update:', payload);
					// Refresh available boxes
					await loadAvailableBoxes();
				}
			)
			.subscribe();
	}

	function setupPettyCashRealtime() {
		// Clean up old subscription
		if (pettyCashChannel) {
			supabase.removeChannel(pettyCashChannel);
		}

		if (!selectedBranchId) return;

		// Set up real-time listener for petty cash records
		pettyCashChannel = supabase
			.channel(`petty-cash-${selectedBranchId}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_records',
					filter: `branch_id=eq.${selectedBranchId}`
				},
				async (payload) => {
					console.log('Petty cash update:', payload);
					// Update balance if it's a petty_cash_box record
					if (payload.new?.record_type === 'petty_cash_box') {
						pettyCashBalance = payload.new.grand_total || 0;
					} else if (payload.old?.record_type === 'petty_cash_box' && !payload.new) {
						// Record was deleted
						await loadPettyCashBalance();
					}
				}
			)
			.subscribe();
	}

	$: if (selectedBranchId) {
		loadAvailableBoxes();
		loadPettyCashBalance();
	}

	async function loadPettyCashBalance() {
		if (!selectedBranchId) return;
		
		try {
			loadingPettyCash = true;
			const { data: pettyCash, error } = await supabase
				.from('denomination_records')
				.select('grand_total')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			if (error && error.code !== 'PGRST116') {
				console.error('Error loading petty cash balance:', error);
				pettyCashBalance = 0;
			} else {
				pettyCashBalance = pettyCash?.grand_total || 0;
			}
		} catch (err) {
			console.error('Exception loading petty cash balance:', err);
			pettyCashBalance = 0;
		} finally {
			loadingPettyCash = false;
		}
	}

	async function setDefaultBranch() {
		if (!selectedBranchId || !$currentUser?.id) {
			errorMessage = 'Please select a branch first';
			return;
		}

		saving = true;
		successMessage = '';
		errorMessage = '';

		try {
			// Check if preference record exists
			const { data: existingPrefs } = await supabase
				.from('denomination_user_preferences')
				.select('id')
				.eq('user_id', $currentUser.id)
				.single();

			if (existingPrefs) {
				// Update existing preference
				const { error } = await supabase
					.from('denomination_user_preferences')
					.update({ default_branch_id: selectedBranchId, updated_at: new Date().toISOString() })
					.eq('user_id', $currentUser.id);

				if (error) throw error;
			} else {
				// Create new preference
				const { error } = await supabase
					.from('denomination_user_preferences')
					.insert({
						user_id: $currentUser.id,
						default_branch_id: selectedBranchId
					});

				if (error) throw error;
			}

			defaultBranchId = selectedBranchId;
			successMessage = 'Default branch set successfully!';
			await loadAvailableBoxes();
			setTimeout(() => (successMessage = ''), 3000);
		} catch (err) {
			console.error('Error setting default branch:', err);
			errorMessage = 'Failed to set default branch';
		} finally {
			saving = false;
		}
	}

	async function loadAvailableBoxes() {
		if (!selectedBranchId) {
			availableBoxes = [];
			return;
		}

		loadingBoxes = true;
		try {
			// First, fetch all employees to build a mapping
			const { data: employees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar');

			if (empError) throw empError;

			// Build employee map
			employeeMap = new Map();
			if (employees) {
				employees.forEach((emp) => {
					employeeMap.set(emp.user_id, emp.name_en);
				});
			}

			// Then fetch box operations
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, box_number, total_after, start_time, user_id, status, closing_details')
				.eq('branch_id', selectedBranchId)
				.eq('status', 'pending_close')
				.order('box_number', { ascending: true });

			if (error) throw error;
			availableBoxes = data || [];
		} catch (err) {
			console.error('Error loading available boxes:', err);
		} finally {
			loadingBoxes = false;
		}
	}

	function getBranchDisplay(branchId: number | null) {
		if (!branchId) return 'No default branch set';
		const branch = branches.find(b => b.id === branchId);
		return branch ? `${branch.name_en} - ${branch.location_en}` : 'Unknown';
	}

	function formatCurrency(value: number) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR'
		}).format(value);
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getDenominationLabel(key: string): string {
		const labels: Record<string, string> = {
			d500: '500 SR',
			d200: '200 SR',
			d100: '100 SR',
			d50: '50 SR',
			d20: '20 SR',
			d10: '10 SR',
			d5: '5 SR',
			d2: '2 SR',
			d1: '1 SR',
			d025: '0.25 SR',
			d05: '0.50 SR',
			coins: 'Coins'
		};
		return labels[key] || key;
	}

	function selectBox(box: BoxOperation) {
		selectedBox = selectedBox?.id === box.id ? null : box;
		if (selectedBox) {
			transferQuantities = {};
			transferMessage = '';
			transferError = '';
		}
	}

	async function saveTransferToPettyCash() {
		if (!selectedBox || !selectedBranchId || !$currentUser?.id) return;

		// Validate quantities don't exceed available counts
		for (const [key, qty] of Object.entries(transferQuantities)) {
			const availableCount = selectedBox.closing_details?.closing_counts[key] || 0;
			if (qty > availableCount) {
				transferError = `Cannot transfer more than available. ${getDenominationLabel(key)}: available ${availableCount}, requested ${qty}`;
				return;
			}
		}

		// Calculate total to transfer
		const totalToTransfer = Object.entries(transferQuantities).reduce((sum, [key, qty]) => {
			if (key !== 'coins' && qty > 0) {
				return sum + parseFloat(key.replace('d', '')) * qty;
			}
			return sum;
		}, 0);

		if (totalToTransfer <= 0) {
			transferError = 'Please enter quantities to transfer';
			return;
		}

		savingTransfer = true;
		transferMessage = '';
		transferError = '';

		try {
			// Get current petty cash record
			const { data: currentRecord } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			// Build new counts with transferred amounts added
			const newCounts = currentRecord?.counts || {};
			Object.entries(transferQuantities).forEach(([key, qty]) => {
				if (qty > 0) {
					newCounts[key] = (newCounts[key] || 0) + qty;
				}
			});

			// Calculate new grand total
			let newGrandTotal = 0;
			Object.entries(newCounts).forEach(([key, count]) => {
				if (key !== 'coins') {
					newGrandTotal += parseFloat(key.replace('d', '')) * count;
				}
			});

			// Update or create petty cash record
			if (currentRecord?.id) {
				const { error } = await supabase
					.from('denomination_records')
					.update({
						counts: newCounts,
						grand_total: newGrandTotal,
						updated_at: new Date().toISOString()
					})
					.eq('id', currentRecord.id);

				if (error) throw error;
			} else {
				const { error } = await supabase
					.from('denomination_records')
					.insert({
						branch_id: selectedBranchId,
						record_type: 'petty_cash_box',
						counts: newCounts,
						grand_total: newGrandTotal,
						created_by: $currentUser.id
					});

				if (error) throw error;
			}

			transferMessage = `✅ Successfully transferred ${formatCurrency(totalToTransfer)} to petty cash!`;
			transferQuantities = {};
			await loadPettyCashBalance();
			setTimeout(() => {
				transferMessage = '';
			}, 3000);
		} catch (err) {
			console.error('Error transferring to petty cash:', err);
			transferError = 'Failed to transfer to petty cash';
		} finally {
			savingTransfer = false;
		}
	}

	function calculateDenominationTotal(): number {
		if (!selectedBox?.closing_details?.closing_counts) return 0;
		
		let total = 0;
		Object.entries(selectedBox.closing_details.closing_counts).forEach(([key, count]) => {
			if (key !== 'coins') {
				total += parseFloat(key.replace('d', '')) * count;
			}
		});
		return total;
	}

	function getBoxDenominationTotal(box: BoxOperation): number {
		if (!box?.closing_details?.closing_counts) return 0;
		
		let total = 0;
		Object.entries(box.closing_details.closing_counts).forEach(([key, count]) => {
			if (key !== 'coins') {
				total += parseFloat(key.replace('d', '')) * count;
			}
		});
		return total;
	}
</script>

<div class="petty-cash-container">
	<div class="cards-grid">
		<!-- Card 1: Branch Selection -->
		<div class="card card-1">
			<div class="card-header">
				<h2>💼 Card 1</h2>
				<span class="card-number">1</span>
			</div>
			<div class="card-content">
				<div class="section-title">Branch Selection</div>

				{#if loading}
					<div class="loading">Loading branches...</div>
				{:else}
					<div class="form-group">
						<label for="branch-select">Select Branch:</label>
						<select
							id="branch-select"
							bind:value={selectedBranchId}
							class="branch-select"
							disabled={saving}
						>
							<option value={null}>-- Select a Branch --</option>
							{#each branches as branch (branch.id)}
								<option value={branch.id}>
									{branch.name_en} - {branch.location_en}
								</option>
							{/each}
						</select>
					</div>

					<div class="default-branch-info">
						<div class="info-label">Current Default:</div>
						<div class="info-value">{getBranchDisplay(defaultBranchId)}</div>
					</div>

					<button
						on:click={setDefaultBranch}
						disabled={saving || !selectedBranchId}
						class="set-default-btn"
					>
						{#if saving}
							<span class="spinner"></span> Setting...
						{:else}
							⭐ Set as Default Branch
						{/if}
					</button>

					{#if successMessage}
						<div class="success-message">{successMessage}</div>
					{/if}

					{#if errorMessage}
						<div class="error-message">{errorMessage}</div>
					{/if}
				{/if}
			</div>
		</div>

		<!-- Card 2: Blank -->
		<div class="card card-2">
			<div class="card-header">
				<h2>� Card 2</h2>
				<span class="card-number">2</span>
			</div>
			<div class="card-content">
				<div class="section-title">Available Cash Boxes</div>

				{#if !selectedBranchId}
					<div class="no-branch-message">
						<p>Select a branch in Card 1 to view available cash boxes</p>
					</div>
				{:else if loadingBoxes}
					<div class="loading">Loading boxes...</div>
				{:else if availableBoxes.length === 0}
					<div class="no-boxes-message">
						<p>No pending boxes for this branch</p>
					</div>
				{:else}
					<div class="boxes-list">
						{#each availableBoxes as box (box.id)}
							<div class="box-item" on:click={() => selectBox(box)} style="cursor: pointer;">
								<div class="box-number-badge">Box {box.box_number}</div>
								<div class="box-info">
									<div class="box-cashier">👤 {employeeMap.get(box.user_id) || 'Unknown'}</div>
									<div class="box-total">
										{#if box.closing_details?.closing_counts}
											{formatCurrency(getBoxDenominationTotal(box))}
										{:else}
											{formatCurrency(box.total_after)}
										{/if}
									</div>
									<div class="box-time">{formatDate(box.start_time)}</div>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>

		<!-- Card 3: Petty Cash Balance -->
		<div class="card card-3">
			<div class="card-header">
				<h2>💰 Card 3</h2>
				<span class="card-number">3</span>
			</div>
			<div class="card-content">
				<div class="section-title">Petty Cash Balance</div>

				{#if !selectedBranchId}
					<div class="no-branch-message">
						<p>Select a branch in Card 1 to view petty cash balance</p>
					</div>
				{:else if loadingPettyCash}
					<div class="loading">Loading balance...</div>
				{:else}
					<div class="petty-cash-display">
						<div class="balance-label">Current Balance</div>
						<div class="balance-amount">
							💵 {pettyCashBalance.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>

	<!-- Denominations Table -->
	{#if selectedBox && selectedBox.closing_details?.closing_counts}
		<div class="denominations-section">
			<div class="table-header">
				<h3>📊 Denominations - Box {selectedBox.box_number} ({employeeMap.get(selectedBox.user_id) || 'Unknown'})</h3>
				<button class="close-btn" on:click={() => (selectedBox = null)}>✕</button>
			</div>
			<div class="table-wrapper">
				<table class="denominations-table">
					<thead>
						<tr>
							<th>Denomination</th>
							<th>Count</th>
							<th>Amount</th>
							<th>Transfer Qty</th>
							<th>Transfer Amount</th>
						</tr>
					</thead>
					<tbody>
						{#each Object.entries(selectedBox.closing_details.closing_counts) as [key, count]}
							<tr>
								<td>{getDenominationLabel(key)}</td>
								<td class="count-col">{count}</td>
								<td class="amount-col">
									{#if key === 'coins'}
										—
									{:else}
										{formatCurrency(
											parseFloat(key.replace('d', '')) * count
										)}
									{/if}
								</td>
								<td class="transfer-col">
									{#if key !== 'coins' && count > 0}
										<input
											type="number"
											min="0"
											max={count}
											bind:value={transferQuantities[key]}
											placeholder="0"
											class="transfer-input"
											disabled={savingTransfer}
										/>
									{:else}
										<span class="disabled-text">—</span>
									{/if}
								</td>
								<td class="transfer-amount-col">
									{#if key === 'coins'}
										—
									{:else if transferQuantities[key] > 0}
										{formatCurrency(
											parseFloat(key.replace('d', '')) * (transferQuantities[key] || 0)
										)}
									{:else}
										—
									{/if}
								</td>
							</tr>
						{/each}
						<tr class="total-row">
							<td colspan="2" style="font-weight: 600; color: #333;">💵 Cash Total</td>
							<td class="amount-col" style="font-weight: 700; color: #2e7d32;">
								{formatCurrency(calculateDenominationTotal())}
							</td>
							<td class="transfer-col" style="font-weight: 600; color: #1976d2;">Transfer Total</td>
							<td class="transfer-amount-col" style="font-weight: 700; color: #1976d2;">
								{formatCurrency(
									Object.entries(transferQuantities).reduce((sum, [key, qty]) => {
										if (key !== 'coins' && qty > 0) {
											return sum + parseFloat(key.replace('d', '')) * qty;
										}
										return sum;
									}, 0)
								)}
							</td>
						</tr>
					</tbody>
				</table>
			</div>

			{#if Object.values(transferQuantities).some(v => v > 0)}
				<div class="transfer-actions">
					{#if exceedMessage}
						<div class="warning-message">{exceedMessage}</div>
					{/if}
					<button
						on:click={saveTransferToPettyCash}
						disabled={savingTransfer || exceedMessage}
						class="save-transfer-btn"
					>
						{#if savingTransfer}
							<span class="spinner"></span> Saving...
						{:else}
							💾 Save Transfer to Petty Cash
						{/if}
					</button>
					{#if transferMessage}
						<div class="success-message transfer-message">{transferMessage}</div>
					{/if}
					{#if transferError}
						<div class="error-message transfer-message">{transferError}</div>
					{/if}
				</div>
			{/if}
		</div>
	{/if}


</div>
<style>
	.petty-cash-container {
		padding: 24px;
		height: 100%;		width: 100%;
		background: linear-gradient(135deg, #f5f5f5 0%, #fafafa 100%);
		overflow-y: auto;
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 16px;
		max-width: 100%;
		margin: 0 auto;
	}

	.card {
		background: white;
		border-radius: 16px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
		overflow: hidden;
		transition: all 0.3s ease;
		transform: perspective(1000px) rotateY(0deg);
		border: 2px solid transparent;
	}

	.card:hover {
		transform: perspective(1000px) translateY(-8px);
		box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
	}

	.card-1 {
		border-color: #ff9800;
		background: linear-gradient(135deg, #fff8f0 0%, #fff 100%);
	}

	.card-1:hover {
		box-shadow: 0 12px 32px rgba(255, 152, 0, 0.25);
	}

	.card-2 {
		border-color: #4caf50;
		background: linear-gradient(135deg, #f1f8f4 0%, #fff 100%);
	}

	.card-2:hover {
		box-shadow: 0 12px 32px rgba(76, 175, 80, 0.25);
	}

	.card-3 {
		border-color: #2196f3;
		background: linear-gradient(135deg, #f0f7ff 0%, #fff 100%);
	}

	.card-3:hover {
		box-shadow: 0 12px 32px rgba(33, 150, 243, 0.25);
	}

	.card-header {
		padding: 6px 8px;
		background: linear-gradient(135deg, #fff 0%, #fafafa 100%);
		border-bottom: 2px solid rgba(0, 0, 0, 0.05);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.card-header h2 {
		margin: 0;
		font-size: 11px;
		font-weight: 600;
		color: #333;
	}

	.card-number {
		background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
		color: white;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 10px;
		box-shadow: 0 4px 8px rgba(255, 152, 0, 0.3);
	}

	.card-2 .card-number {
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		box-shadow: 0 4px 8px rgba(76, 175, 80, 0.3);
	}

	.card-3 .card-number {
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
	}

	.card-content {
		padding: 12px;
		min-height: 150px;
		display: flex;
		flex-direction: column;
	}

	.section-title {
		font-size: 10px;
		font-weight: 600;
		color: #ff9800;
		margin-bottom: 6px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.form-group {
		margin-bottom: 6px;
	}

	.form-group label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		color: #555;
		margin-bottom: 3px;
	}

	.branch-select {
		width: 100%;
		padding: 4px 6px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 9px;
		background-color: white;
		color: #333;
		cursor: pointer;
		transition: all 0.3s ease;
		font-family: inherit;
	}

	.branch-select:hover:not(:disabled) {
		border-color: #ff9800;
		box-shadow: 0 2px 8px rgba(255, 152, 0, 0.15);
	}

	.branch-select:focus {
		outline: none;
		border-color: #ff9800;
		box-shadow: 0 0 0 3px rgba(255, 152, 0, 0.1);
	}

	.branch-select:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.default-branch-info {
		background: linear-gradient(135deg, #fff9c4 0%, #fffde7 100%);
		padding: 6px;
		border-radius: 4px;
		margin-bottom: 6px;
		border-left: 3px solid #fbc02d;
	}

	.info-label {
		font-size: 8px;
		color: #f57f17;
		font-weight: 600;
		text-transform: uppercase;
		margin-bottom: 2px;
	}

	.info-value {
		font-size: 9px;
		color: #333;
		font-weight: 500;
	}

	.set-default-btn {
		padding: 4px 8px;
		background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		box-shadow: 0 4px 12px rgba(255, 152, 0, 0.3);
		margin-bottom: 6px;
	}

	.set-default-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(255, 152, 0, 0.4);
	}

	.set-default-btn:active:not(:disabled) {
		transform: translateY(0px);
		box-shadow: 0 2px 8px rgba(255, 152, 0, 0.3);
	}

	.set-default-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.spinner {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.loading {
		padding: 10px 5px;
		text-align: center;
		color: #999;
		font-size: 9px;
	}

	.success-message {
		padding: 6px 8px;
		background-color: #c8e6c9;
		color: #2e7d32;
		border-radius: 4px;
		border-left: 3px solid #4caf50;
		font-size: 8px;
		font-weight: 500;
		animation: slideIn 0.3s ease;
	}

	.error-message {
		padding: 6px 8px;
		background-color: #ffcdd2;
		color: #c62828;
		border-radius: 4px;
		border-left: 3px solid #f44336;
		font-size: 8px;
		font-weight: 500;
		animation: slideIn 0.3s ease;
	}

	.warning-message {
		padding: 10px 12px;
		background-color: #fff3cd;
		color: #856404;
		border-radius: 6px;
		border-left: 4px solid #ffc107;
		font-size: 12px;
		font-weight: 500;
		margin-bottom: 12px;
		animation: slideIn 0.3s ease;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(-8px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		font-size: 9px;
		color: #999;
		font-weight: 500;
	}

	.no-branch-message,
	.no-boxes-message {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		text-align: center;
	}

	.no-branch-message p,
	.no-boxes-message p {
		font-size: 10px;
		color: #999;
		margin: 0;
	}

	.boxes-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
		max-height: 140px;
		overflow-y: auto;
	}

	.box-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px;
		background: linear-gradient(135deg, #e8f5e9 0%, #f1f8f4 100%);
		border-radius: 6px;
		border-left: 3px solid #4caf50;
	}

	.box-number-badge {
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 9px;
		font-weight: 600;
		min-width: 50px;
		text-align: center;
		box-shadow: 0 2px 4px rgba(76, 175, 80, 0.2);
	}

	.box-info {
		flex: 1;
	}

	.box-cashier {
		font-size: 9px;
		font-weight: 600;
		color: #333;
		margin-bottom: 2px;
	}

	.box-total {
		font-size: 10px;
		font-weight: 600;
		color: #2e7d32;
	}

	.box-breakdown {
		display: flex;
		gap: 6px;
		margin-top: 2px;
		flex-wrap: wrap;
	}

	.breakdown-item {
		font-size: 8px;
		color: #555;
		background: white;
		padding: 2px 4px;
		border-radius: 3px;
		white-space: nowrap;
	}

	.box-time {
		font-size: 8px;
		color: #999;
		margin-top: 2px;
	}

	/* Denominations Table Styles */
	.denominations-section {
		margin-top: 24px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		animation: slideIn 0.3s ease;
	}

	.table-header {
		padding: 16px;
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.table-header h3 {
		margin: 0;
		font-size: 14px;
		font-weight: 600;
	}

	.close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.table-wrapper {
		padding: 16px;
		overflow-x: auto;
	}

	.denominations-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	.denominations-table thead {
		background: #f5f5f5;
		border-bottom: 2px solid #4caf50;
	}

	.denominations-table th {
		padding: 10px;
		text-align: left;
		font-weight: 600;
		color: #333;
	}

	.denominations-table td {
		padding: 10px;
		border-bottom: 1px solid #e0e0e0;
		color: #555;
	}

	.denominations-table tr:hover {
		background: #fafafa;
	}

	.count-col {
		text-align: center;
		font-weight: 500;
		color: #2e7d32;
	}

	.amount-col {
		text-align: right;
		font-weight: 600;
		color: #1976d2;
	}

	.total-row {
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-top: 2px solid #4caf50;
		border-bottom: 2px solid #4caf50;
		font-weight: 600;
	}

	.total-row td {
		padding: 12px 10px;
	}

	.transfer-col {
		text-align: center;
		padding: 10px 5px;
	}

	.disabled-text {
		color: #ccc;
		font-weight: 500;
	}

	.transfer-input {
		width: 60px;
		padding: 6px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 12px;
		text-align: center;
		transition: all 0.3s ease;
	}

	.transfer-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
	}

	.transfer-input:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.transfer-amount-col {
		text-align: right;
		font-weight: 600;
		color: #1976d2;
	}

	.transfer-actions {
		padding: 16px;
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-top: 2px solid #2196f3;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.save-transfer-btn {
		padding: 10px 16px;
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3);
	}

	.save-transfer-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(33, 150, 243, 0.4);
	}

	.save-transfer-btn:active:not(:disabled) {
		transform: translateY(0px);
		box-shadow: 0 2px 8px rgba(33, 150, 243, 0.3);
	}

	.save-transfer-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.transfer-message {
		margin: 0;
	}

	.petty-cash-display {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-radius: 8px;
		text-align: center;
	}

	.balance-label {
		font-size: 0.9rem;
		color: #666;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.balance-amount {
		font-size: 1.75rem;
		font-weight: 700;
		color: #2196f3;
		line-height: 1.2;
	}
</style>
