<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// State variables
	let isLoading = true;
	let branches: any[] = [];
	let selectedBranch = '';
	let defaultBranchId: number | null = null;
	let isSavingDefault = false;
	let showDefaultSaved = false;

	onMount(async () => {
		await loadBranches();
		await loadUserPreferences();
		isLoading = false;
	});

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
		'd5': 0,
		'd1': 0,
		'bundle10': 0,
		'bundle5': 0,
		'mixed': 0,
		'coin50': 0,
		'coin100': 0,
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
		'd5': 5,
		'd1': 1,
		'bundle10': 1000, // 100 x 10 SAR notes
		'bundle5': 500,   // 100 x 5 SAR notes
		'mixed': 500,     // Mixed 5 & 10
		'coin50': 50,
		'coin100': 100,
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

	const denomLabels: Record<string, string> = {
		'd500': '500 SAR',
		'd200': '200 SAR',
		'd100': '100 SAR',
		'd50': '50 SAR',
		'd20': '20 SAR',
		'd5': '5 SAR',
		'd1': '1 SAR',
		'bundle10': 'Bundle 10',
		'bundle5': 'Bundle 5',
		'mixed': 'Mixed 5&10',
		'coin50': 'Coin 50',
		'coin100': 'Coin 100',
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
		'd5': counts['d5'] * denomValues['d5'],
		'd1': counts['d1'] * denomValues['d1'],
		'bundle10': counts['bundle10'] * denomValues['bundle10'],
		'bundle5': counts['bundle5'] * denomValues['bundle5'],
		'mixed': counts['mixed'] * denomValues['mixed'],
		'coin50': counts['coin50'] * denomValues['coin50'],
		'coin100': counts['coin100'] * denomValues['coin100'],
		'coins': counts['coins'] * denomValues['coins'],
		'damage': counts['damage'] * denomValues['damage']
	};

	$: grandTotal = Object.values(totals).reduce((sum, val) => sum + val, 0);

	// Calculate difference between grand total and ERP balance
	$: erpBalanceNumber = typeof erpBalance === 'string' ? (parseFloat(erpBalance) || 0) : erpBalance;
	$: difference = grandTotal - erpBalanceNumber;
</script>

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
				<div class="card-body suspends-body">
					<!-- Paid Section -->
					<div class="suspends-section">
						<div class="suspends-section-header paid">
							<span class="section-icon">💸</span>
							<span>Paid</span>
						</div>
						<div class="suspends-cards-grid">
							<div class="suspend-card">
								<p class="hint">POS Advance</p>
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
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />5</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d5')}>−</button><span class="count-value">{counts['d5']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d5')}>+</button></td><td class="total-cell">{totals['d5'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap"><img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />1</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('d1')}>−</button><span class="count-value">{counts['d1']}</span><button class="count-btn plus" on:click={() => openPopupAdd('d1')}>+</button></td><td class="total-cell">{totals['d1'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">📦 Bundle <img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />10</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('bundle10')}>−</button><span class="count-value">{counts['bundle10']}</span><button class="count-btn plus" on:click={() => openPopupAdd('bundle10')}>+</button></td><td class="total-cell">{totals['bundle10'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">📦 Bundle <img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />5</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('bundle5')}>−</button><span class="count-value">{counts['bundle5']}</span><button class="count-btn plus" on:click={() => openPopupAdd('bundle5')}>+</button></td><td class="total-cell">{totals['bundle5'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">📦 Mixed <img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />5&10</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('mixed')}>−</button><span class="count-value">{counts['mixed']}</span><button class="count-btn plus" on:click={() => openPopupAdd('mixed')}>+</button></td><td class="total-cell">{totals['mixed'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">🪙 Coin <img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />50</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('coin50')}>−</button><span class="count-value">{counts['coin50']}</span><button class="count-btn plus" on:click={() => openPopupAdd('coin50')}>+</button></td><td class="total-cell">{totals['coin50'].toLocaleString()}</td></tr>
							<tr><td><span class="nowrap">🪙 Coin <img src="/icons/saudi-currency.png" alt="SAR" class="denomination-icon" />100</span></td><td class="count-cell"><button class="count-btn minus" on:click={() => openPopupSubtract('coin100')}>−</button><span class="count-value">{counts['coin100']}</span><button class="count-btn plus" on:click={() => openPopupAdd('coin100')}>+</button></td><td class="total-cell">{totals['coin100'].toLocaleString()}</td></tr>
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
		flex: 1;
		overflow-y: auto;
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
		padding: 0.75rem;
		text-align: center;
		box-shadow: 
			0 2px 4px -1px rgba(0, 0, 0, 0.06),
			inset 0 1px 0 rgba(255, 255, 255, 0.9);
		transition: all 0.2s ease;
		min-height: 50px;
		display: flex;
		align-items: center;
		justify-content: center;
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
</style>
