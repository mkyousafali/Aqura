<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { t } from '$lib/i18n';

	export let windowId: string;
	export let box: any;
	export let branch: any;
	export let user: any;

	let currencySymbolUrl = '/icons/saudi-currency.png';

	// Denomination values
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
		'coins': 1
	};

	const denomLabels: Record<string, string> = {
		'd500': '500',
		'd200': '200',
		'd100': '100',
		'd50': '50',
		'd20': '20',
		'd10': '10',
		'd5': '5',
		'd2': '2',
		'd1': '1',
		'd05': '0.5',
		'd025': '0.25',
		'coins': 'Coins'
	};

	let realCounts: Record<string, number> = {};
	Object.keys(denomValues).forEach(key => {
		realCounts[key] = undefined;
	});

	let matchStatus: 'match' | 'mismatch' | null = null;
	let displayTotal: number = 0;
	let cashierAccessCode = '';
	let cashierName = '';
	let cashierCodeValid = false;
	let supervisorAccessCode = '';
	let supervisorName = '';
	let selectedPosNumber: number | null = null;
	let isValidated = false;
	let errorMessage = '';
	let isStarting = false;
	
	// Recharge card fields
	let rechargeStartDate: string = '';
	let rechargeStartHour = '12';
	let rechargeStartMinute = '00';
	let rechargeStartAmPm = 'AM';
	let rechargeOpeningBalance: number | '' = '';
	
	// Track original values after validation to detect changes
	let originalCashierCode = '';
	let originalSupervisorCode = '';
	let originalRealCounts: Record<string, number> = {};
	let hasChangesDetected = false;
	let changeCounter = 0;

	function hasChangesAfterValidation(): boolean {
		if (!isValidated) return false;
		
		// Check if access codes changed
		if (cashierAccessCode !== originalCashierCode || supervisorAccessCode !== originalSupervisorCode) {
			return true;
		}
		
		// Check if any real counts changed
		for (const key of Object.keys(denomValues)) {
			const currentCount = Number(realCounts[key]) || 0;
			const originalCount = originalRealCounts[key] || 0;
			if (currentCount !== originalCount) {
				return true;
			}
		}
		
		return false;
	}

	// Reactive statement to track changes - use changeCounter as dependency
	$: if (changeCounter >= 0) {
		hasChangesDetected = hasChangesAfterValidation();
		// Reset validation state if changes are detected
		if (hasChangesDetected) {
			isValidated = false;
			errorMessage = '';
		}
	}

	function calculateRealTotal(): number {
		let total = 0;
		for (const key of Object.keys(denomValues)) {
			const count = Number(realCounts[key]) || 0;
			const denomValue = denomValues[key] || 0;
			total += count * denomValue;
		}
		console.log('Calculated total:', total, 'from counts:', realCounts);
		return total;
	}

	// Explicitly track realCounts changes
	$: if (realCounts) {
		displayTotal = calculateRealTotal();
	}

	$: if (box && displayTotal !== undefined) {
		const boxTotal = Number(box.total) || 0;
		// Use Math.abs for floating point comparison tolerance (0.01 = 1 cent)
		matchStatus = Math.abs(displayTotal - boxTotal) < 0.01 ? 'match' : 'mismatch';
	}

	function checkDenominationMatch(denomKey: string): 'match' | 'mismatch' | null {
		if (!isValidated || !box) return null;
		
		const realCount = realCounts[denomKey] || 0;
		let expectedCount = 0;
		
		try {
			const boxCounts = typeof box.counts === 'string' ? JSON.parse(box.counts) : box.counts;
			expectedCount = boxCounts[denomKey] || 0;
		} catch (e) {
			console.error('Error parsing box counts:', e);
		}

		return realCount === expectedCount ? 'match' : 'mismatch';
	}

	async function verifyCashierAccessCode() {
		if (!cashierAccessCode) {
			cashierCodeValid = false;
			cashierName = '';
			return;
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username, quick_access_code')
				.eq('id', user.id)
				.single();

			if (error) throw error;

			if (data && data.quick_access_code === cashierAccessCode) {
				cashierCodeValid = true;
				cashierName = data.username || '';
			} else {
				cashierCodeValid = false;
				cashierName = '';
				errorMessage = $currentLocale === 'ar' ? 'رمز الدخول لا يتطابق مع المستخدم المسجل' : 'Access code does not match logged user';
			}
		} catch (error) {
			console.error('Error verifying cashier access code:', error);
			cashierCodeValid = false;
			cashierName = '';
		}
	}

	async function lookupSupervisorAccessCode() {
		if (!supervisorAccessCode) {
			supervisorName = '';
			return;
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('username')
				.eq('quick_access_code', supervisorAccessCode)
				.single();

			if (error) throw error;

			if (data) {
				supervisorName = data.username || '';
			} else {
				supervisorName = '';
				errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
			}
		} catch (error) {
			console.error('Error looking up supervisor:', error);
			supervisorName = '';
			errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
		}
	}

	async function validateAccessCodes() {
		await verifyCashierAccessCode();
		await lookupSupervisorAccessCode();

		if (!cashierCodeValid) {
			errorMessage = $currentLocale === 'ar' ? 'رمز الوصول الخاص بالموظف غير صحيح' : 'Cashier access code is incorrect';
			return;
		}

		if (!supervisorName) {
			errorMessage = $currentLocale === 'ar' ? 'رمز الوصول الخاص بالمشرف غير صحيح' : 'Supervisor access code is incorrect';
			return;
		}

		// Validation passed - allow start even if denominations don't match
		isValidated = true;
		errorMessage = '';
		
		// Store the validated values to detect changes later
		originalCashierCode = cashierAccessCode;
		originalSupervisorCode = supervisorAccessCode;
		originalRealCounts = {};
		for (const key of Object.keys(realCounts)) {
			originalRealCounts[key] = Number(realCounts[key]) || 0;
		}
		
		// Reset the change counter so button shows as validated
		changeCounter = 0;
	}

	let saveTimeout: NodeJS.Timeout;
	let draftOperationId: string | null = null;
	
	async function saveDenominationCounts() {
		clearTimeout(saveTimeout);
		
		// Debounce saves - wait 1 second after last change before saving
		saveTimeout = setTimeout(async () => {
			try {
				const countsToSave: Record<string, number> = {};
				for (const key of Object.keys(realCounts)) {
					countsToSave[key] = Number(realCounts[key]) || 0;
				}
				
				// Build closing details with recharge card info
				const closingData = {
					counts_after: countsToSave,
					total_after: displayTotal,
					difference: displayTotal - Number(box.total),
					is_matched: Math.abs(displayTotal - Number(box.total)) < 0.01,
					// Recharge card details
					recharge_opening_balance: Number(rechargeOpeningBalance) || 0,
					recharge_transaction_start_date: rechargeStartDate,
					recharge_transaction_start_time: `${rechargeStartHour}:${rechargeStartMinute} ${rechargeStartAmPm}`
				};
				
				let error;
				
				// If we already have a draft ID, update it
				if (draftOperationId) {
					const result = await supabase
						.from('box_operations')
						.update({ closing_details: closingData })
						.eq('id', draftOperationId);
					error = result.error;
				} else {
					// Otherwise create a new draft record
					const result = await supabase
						.from('box_operations')
						.insert([{
							box_number: box.number,
							branch_id: branch.id,
							user_id: user.id,
							denomination_record_id: box.id,
							counts_before: box.counts,
							counts_after: countsToSave,
							total_before: box.total,
							total_after: displayTotal,
							difference: displayTotal - Number(box.total),
							is_matched: Math.abs(displayTotal - Number(box.total)) < 0.01,
							status: 'draft',
							start_time: new Date().toISOString(),
							closing_details: closingData
						}])
						.select('id');
					
					if (result.data && result.data[0]) {
						draftOperationId = result.data[0].id;
					}
					error = result.error;
				}
				
				if (error) console.error('Error saving closing details:', error);
			} catch (error) {
				console.error('Error saving closing details:', error);
			}
		}, 1000);
	}

	async function loadSavedCounts() {
		try {
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, counts_after')
				.eq('denomination_record_id', box.id)
				.eq('user_id', user.id)
				.eq('status', 'draft')
				.single();
			
			if (data && data.counts_after) {
				draftOperationId = data.id;
				const savedCounts = typeof data.counts_after === 'string' ? JSON.parse(data.counts_after) : data.counts_after;
				for (const key of Object.keys(realCounts)) {
					realCounts[key] = savedCounts[key] || 0;
				}
				realCounts = { ...realCounts };
			}
		} catch (error) {
			console.log('No saved counts found, starting fresh');
		}
	}

	// Load saved counts on component mount
	import { onMount } from 'svelte';
	onMount(() => {
		loadSavedCounts();
	});

	async function startOperation() {
		if (!isValidated || !selectedPosNumber || isStarting) return;

		isStarting = true;

		try {
			const countsAfter: Record<string, number> = {};
			Object.keys(denomValues).forEach(key => {
				countsAfter[key] = realCounts[key] || 0;
			});

			const realTotal = calculateRealTotal();
			const difference = realTotal - box.total;
			const isMatched = Math.abs(difference) < 0.01;

			// Build closing details with recharge card info
			const closingDetails = {
				counts_after: countsAfter,
				total_after: realTotal,
				difference: difference,
				is_matched: isMatched,
				// Recharge card details
				recharge_opening_balance: Number(rechargeOpeningBalance) || 0,
				recharge_transaction_start_date: rechargeStartDate,
				recharge_transaction_start_time: `${rechargeStartHour}:${rechargeStartMinute} ${rechargeStartAmPm}`
			};

			const { error } = await supabase
				.from('box_operations')
				.insert({
					box_number: box.number,
					branch_id: branch.id,
					user_id: user.id,
					denomination_record_id: box.id,
					counts_before: box.counts,
					counts_after: countsAfter,
					total_before: box.total,
					total_after: realTotal,
					difference: difference,
					is_matched: isMatched,
					status: 'in_use',
					start_time: new Date().toISOString(),
					closing_details: closingDetails,
					notes: JSON.stringify({
						cashier_name: cashierName,
						cashier_access_code: cashierAccessCode,
						supervisor_name: supervisorName,
						pos_number: selectedPosNumber
					})
				});

			if (error) throw error;

			// Delete draft record now that operation is complete
			if (draftOperationId) {
				await supabase
					.from('box_operations')
					.delete()
					.eq('id', draftOperationId);
			}

			window.dispatchEvent(new CustomEvent('close-window', { detail: { windowId } }));
		} catch (error) {
			console.error('Error starting operation:', error);
			errorMessage = $currentLocale === 'ar' ? 'حدث خطأ أثناء بدء العملية' : 'Error starting operation';
			isStarting = false;
		}
	}
</script>

<div class="counter-check-container">
	<div class="pos-number-section">
		<div class="access-code-group">
			<label>{t('pos.posNumber') || 'POS Number'}</label>
			<select bind:value={selectedPosNumber} class="pos-number-select">
				<option value={null} disabled selected>{$currentLocale === 'ar' ? 'اختر نقطة بيع' : 'Select POS'}</option>
				<option value={1}>POS 1</option>
				<option value={2}>POS 2</option>
				<option value={3}>POS 3</option>
				<option value={4}>POS 4</option>
				<option value={5}>POS 5</option>
				<option value={6}>POS 6</option>
				<option value={7}>POS 7</option>
				<option value={8}>POS 8</option>
				<option value={9}>POS 9</option>
			</select>
		</div>
	</div>

	{#if selectedPosNumber !== null}
	<div class="section">
		<h3>{t('pos.enterRealCount') || 'ENTER REAL COUNT'}</h3>
		<div class="real-count-inputs">
			{#each Object.entries(denomLabels) as [key, label] (key)}
				<div class="input-group">
					<label>
						{#if label !== 'Coins'}
							<span>{label}</span>
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						{:else}
							{label}
						{/if}
					</label>
					<div class="input-with-status">
						<input
							type="number"
							min="0"
							step="1"
							placeholder=""
							bind:value={realCounts[key]}
							on:input={() => {
								realCounts = { ...realCounts };
								changeCounter++;
								saveDenominationCounts();
							}}
						/>
						{#if realCounts[key] > 0 && box && isValidated}
							<div class="status-indicator">
								{#if checkDenominationMatch(key) === 'match'}
									<span class="status-icon match">✓</span>
								{:else if checkDenominationMatch(key) === 'mismatch'}
									<span class="status-icon mismatch">✗</span>
								{/if}
							</div>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	</div>

	<div class={`total-match-status ${matchStatus || ''}`}>
		<div class="status-row">
			<span class="label">{t('pos.realTotal') || 'Real Total'}:</span>
			<div class="amount">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{displayTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		<div class="status-row">
			<span class="label">{t('pos.box') || 'Box'} {t('common.total') || 'Total'}:</span>
			<div class="amount">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{box.total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		{#if matchStatus === 'match'}
			<div class="match-indicator match">
				<span class="icon">✓</span>
				<span class="text">{t('pos.matched') || 'MATCHED'}</span>
			</div>
		{:else if matchStatus === 'mismatch'}
			<div class="match-indicator mismatch">
				<span class="icon">✗</span>
				<span class="text">{t('pos.notMatched') || 'NOT MATCHED'}</span>
				<div class="difference">
					{t('pos.difference') || 'Difference'}: 
					<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
					<span style="color: {displayTotal - box.total > 0 ? '#16a34a' : '#dc2626'};">
						{(displayTotal - box.total) > 0 ? '+' : ''}{(displayTotal - box.total).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
					</span>
				</div>
			</div>
		{/if}
	</div>

	<!-- Recharge Card Section -->
	<div class="recharge-section">
		<div class="section-header">
			{$currentLocale === 'ar' ? 'بطاقات الشحن' : 'RECHARGE CARDS'}
		</div>
		<div class="recharge-grid">
			<div class="input-group">
				<label>{$currentLocale === 'ar' ? 'تاريخ البداية' : 'Start Date'}</label>
				<input
					type="date"
					bind:value={rechargeStartDate}
					on:change={() => saveDenominationCounts()}
					class="recharge-input"
				/>
			</div>
			<div class="input-group">
				<label>{$currentLocale === 'ar' ? 'وقت البداية' : 'Start Time'}</label>
				<div class="time-inputs">
					<input
						type="number"
						min="1"
						max="12"
						bind:value={rechargeStartHour}
						on:change={() => saveDenominationCounts()}
						placeholder="HH"
						class="time-input"
					/>
					<span class="time-separator">:</span>
					<input
						type="number"
						min="0"
						max="59"
						bind:value={rechargeStartMinute}
						on:change={() => saveDenominationCounts()}
						placeholder="MM"
						class="time-input"
					/>
					<select bind:value={rechargeStartAmPm} on:change={() => saveDenominationCounts()} class="time-select">
						<option value="AM">AM</option>
						<option value="PM">PM</option>
					</select>
				</div>
			</div>
			<div class="input-group">
				<label>
					{$currentLocale === 'ar' ? 'رصيد البداية' : 'Opening Balance'}
					<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				</label>
				<input
					type="number"
					step="0.01"
					placeholder="0.00"
					bind:value={rechargeOpeningBalance}
					on:input={() => saveDenominationCounts()}
					class="recharge-input"
				/>
			</div>
		</div>
	</div>

	<div class="access-codes-section">
		<div class="signature-header">
			{$currentLocale === 'ar' ? 'التوقيع الإلكتروني' : 'ELECTRONIC SIGNATURE'}
		</div>
		<div class="access-code-row">
			<div class="access-code-group">
				<label>{t('pos.cashierAccessCode') || 'Cashier Access Code'}</label>
				<input
					type="password"
					placeholder={t('pos.enterCashierAccessCode') || 'Enter cashier access code'}
					bind:value={cashierAccessCode}
					on:input={() => changeCounter++}
					on:blur={verifyCashierAccessCode}
				/>
			</div>
			{#if cashierCodeValid && cashierName}
				<div class="verified-name-display-inline">✓ {cashierName}</div>
			{/if}
		</div>

		<div class="access-code-row">
			<div class="access-code-group">
				<label>{t('pos.supervisorAccessCode') || 'Supervisor Access Code'}</label>
				<input
					type="password"
					placeholder={t('pos.enterSupervisorAccessCode') || 'Enter supervisor access code'}
					bind:value={supervisorAccessCode}
					on:input={() => changeCounter++}
					on:blur={lookupSupervisorAccessCode}
				/>
			</div>
			{#if supervisorName}
				<div class="verified-name-display-inline">✓ {supervisorName}</div>
			{/if}
		</div>
	</div>

	<div class="modal-footer">
		<button class="btn-validate" on:click={validateAccessCodes} disabled={isValidated && !hasChangesDetected}>
			{isValidated && !hasChangesDetected ? ($currentLocale === 'ar' ? '✓ تم التحقق' : '✓ Validated') : ($currentLocale === 'ar' ? 'التحقق' : 'Validate')}
		</button>
		<button class="btn-primary" on:click={startOperation} disabled={isStarting || !isValidated}>
			{isStarting ? (t('common.starting') || 'Starting...') : (t('common.start') || 'Start')}
		</button>
	</div>
	{/if}
</div>

{#if errorMessage}
	<div class="error-overlay">
		<div class="error-popup">
			<div class="error-header">
				<span class="error-icon">⚠️</span>
				<h3>Error</h3>
			</div>
			<p class="error-text">{errorMessage}</p>
			<button class="btn-close-error" on:click={() => errorMessage = ''}>Close</button>
		</div>
	</div>
{/if}

<style>
	.counter-check-container {
		width: 100%;
		height: 100%;
		background: white;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		overflow-y: auto;
	}

	.pos-number-section {
		margin-bottom: 0.5rem;
	}

	.section {
		background: white;
		border-radius: 0.5rem;
	}

	.section h3 {
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		margin-bottom: 0.75rem;
		letter-spacing: 1px;
	}

	.real-count-inputs {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.75rem;
		padding: 1rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-radius: 0.5rem;
		border: 2px solid #86efac;
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.input-group label {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
	}

	.currency-icon {
		width: 14px;
		height: 14px;
		object-fit: contain;
	}

	.input-with-status {
		position: relative;
	}

	.input-with-status input {
		width: 100%;
		padding: 0.4rem 2rem 0.4rem 0.5rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.status-indicator {
		position: absolute;
		right: 0.5rem;
		top: 50%;
		transform: translateY(-50%);
	}

	.status-icon {
		font-size: 1rem;
		font-weight: bold;
	}

	.status-icon.match {
		color: #16a34a;
	}

	.status-icon.mismatch {
		color: #dc2626;
	}

	.total-match-status {
		padding: 0.5rem 1rem;
		border-top: 1px solid #e5e7eb;
		margin-bottom: 0.25rem;
	}

	.status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
		font-size: 0.875rem;
	}

	.status-row .label {
		font-weight: 600;
		color: #4b5563;
	}

	.status-row .amount {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-weight: 700;
		color: #1f2937;
	}

	.match-indicator {
		margin-top: 0.75rem;
		padding: 0.75rem;
		border-radius: 0.5rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 700;
	}

	.match-indicator.match {
		background: #dcfce7;
		color: #16a34a;
		border: 2px solid #86efac;
	}

	.match-indicator.mismatch {
		background: #fee2e2;
		color: #dc2626;
		border: 2px solid #fca5a5;
		flex-direction: column;
		align-items: flex-start;
	}

	.match-indicator .icon {
		font-size: 1.25rem;
	}

	.match-indicator .text {
		font-size: 0.875rem;
	}

	.difference {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		margin-top: 0.25rem;
	}

	.currency-icon-small {
		width: 12px;
		height: 12px;
	}

	.access-codes-section {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #fff7ed 0%, #ffedd5 100%);
		border-radius: 0.5rem;
		margin-top: 0.125rem;
		border: 2px solid #fed7aa;
		box-shadow: 0 4px 6px -1px rgba(249, 115, 22, 0.1), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.signature-header {
		grid-column: 1 / -1;
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		letter-spacing: 1px;
		padding-bottom: 0.5rem;
		margin-bottom: 0.15rem;
		border-bottom: 1px solid #fed7aa;
	}

	.access-code-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.access-code-group label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
		letter-spacing: 0.5px;
	}

	.access-code-group input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.access-code-row {
		display: flex;
		align-items: flex-start;
		gap: 0.5rem;
		margin-bottom: 0.3rem;
	}

	.access-code-row .access-code-group {
		flex: 1;
	}

	.verified-name-display {
		margin-top: 0.25rem;
		padding: 0.25rem 0.5rem;
		background: #dcfce7;
		border: 1px solid #86efac;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		color: #16a34a;
		font-weight: 600;
		text-align: center;
	}

	.verified-name-display-inline {
		font-size: 0.7rem;
		color: #16a34a;
		font-weight: 600;
		white-space: nowrap;
		padding-top: 0.3rem;
		padding-right: 0.25rem;
	}

	.pos-number-select {
		padding: 0.3rem 0.4rem;
		border: 2px solid #22c55e;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #166534;
		background: white;
	}

	.modal-footer {
		display: flex;
		gap: 0.5rem;
		justify-content: flex-end;
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
	}

	.btn-validate,
	.btn-primary {
		padding: 0.5rem 1.5rem;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
		border: none;
		font-size: 0.875rem;
	}

	.btn-validate {
		background: #10b981;
		color: white;
	}

	.btn-validate:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.error-overlay {
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

	.error-popup {
		background: white;
		padding: 1.5rem;
		border-radius: 0.5rem;
		max-width: 400px;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
	}

	.error-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.error-icon {
		font-size: 1.5rem;
	}

	.error-text {
		margin-bottom: 1rem;
		color: #4b5563;
	}

	.btn-close-error {
		width: 100%;
		padding: 0.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
	}

	.recharge-section {
		padding: 0.75rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border-radius: 0.5rem;
		border: 2px solid #7dd3fc;
		margin-top: 0.5rem;
	}

	.section-header {
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		letter-spacing: 1px;
		padding-bottom: 0.5rem;
		margin-bottom: 0.5rem;
		border-bottom: 1px solid #7dd3fc;
	}

	.recharge-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
	}

	.recharge-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.time-inputs {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		width: 100%;
	}

	.time-input {
		width: 80px;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		text-align: center;
		font-weight: 600;
	}

	.time-select {
		flex: 1;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
	}

	.time-separator {
		font-weight: bold;
		color: #4b5563;
		font-size: 0.875rem;
	}</style>
