<script lang="ts">
	import { createClient } from '@supabase/supabase-js';

	export let windowId: string;
	export let operation: any;
	export let branch: any;

	let currencySymbolUrl = '/icons/saudi-currency.png';

	// Parse notes JSON to get names and POS number
	let operationData: any = {};
	let selectedPosNumber = 1;
	
	console.log('📦 CloseBox received operation:', operation);
	
	try {
		if (operation?.notes) {
			operationData = typeof operation.notes === 'string' 
				? JSON.parse(operation.notes) 
				: operation.notes;
			selectedPosNumber = operationData.pos_number || 1;
		}
	} catch (e) {
		console.error('Error parsing operation notes:', e);
	}
	
	console.log('📝 Parsed operation data:', operationData);

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

	// Closing cash counts - load from operation data
	let closingCounts: Record<string, number> = {};
	let closingDetails: any = {};
	
	// Ensure closingCounts is always initialized properly
	function initializeClosingCounts() {
		console.log('🔄 Initializing closing counts from operation:', operation);
		
		// Try to load from closing_details (the JSON saved data)
		if (operation?.closing_details) {
			const details = typeof operation.closing_details === 'string' 
				? JSON.parse(operation.closing_details)
				: operation.closing_details;
			
			closingDetails = details;
			closingCounts = { ...details.closing_counts || {} };
			
			// Load supervisor info
			supervisorName = details.supervisor_name || '';
			supervisorCode = '';
			
			// Load bank reconciliation
			madaAmount = details.bank_mada || '';
			visaAmount = details.bank_visa || '';
			masterCardAmount = details.bank_mastercard || '';
			googlePayAmount = details.bank_google_pay || '';
			otherAmount = details.bank_other || '';
			
			// Load ERP details
			systemCashSales = details.system_cash_sales || '';
			systemCardSales = details.system_card_sales || '';
			systemReturn = details.system_return || '';
			
			// Load recharge details
			openingBalance = details.recharge_opening_balance || '';
			closeBalance = details.recharge_close_balance || '';
			
			// Load recharge card transaction dates and times
			startDateInput = details.recharge_transaction_start_date || '';
			startTimeInput = details.recharge_transaction_start_time || '';
			endDateInput = details.recharge_transaction_end_date || '';
			endTimeInput = details.recharge_transaction_end_time || '';
			
			// Parse time if available
			if (startTimeInput) {
				const [time, period] = startTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				startHour = hour || '12';
				startMinute = minute || '00';
				startAmPm = period || 'AM';
			}
			if (endTimeInput) {
				const [time, period] = endTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				endHour = hour || '12';
				endMinute = minute || '00';
				endAmPm = period || 'AM';
			}
			
			// Load vouchers
			vouchers = details.vouchers || [];
			
			console.log('✅ Loaded ALL closing details:', closingCounts, closingDetails);
		} else if (operation?.counts_after) {
			closingCounts = { ...operation.counts_after };
			console.log('✅ Loaded closing counts from counts_after:', closingCounts);
		} else {
			// Initialize with zeros
			closingCounts = {};
			Object.keys(denomValues).forEach(key => {
				closingCounts[key] = 0;
			});
			console.log('⚠️ No closing data found, initialized with zeros');
		}
	}
	
	// Initialize on mount
	$: if (operation) {
		initializeClosingCounts();
	}

	// Calculate total
	$: closingTotal = Object.keys(closingCounts).reduce((sum, key) => {
		const count = closingCounts[key] || 0;
		const denomValue = denomValues[key] || 0;
		return sum + (count * denomValue);
	}, 0);

	// Calculate cash sales (closing total - checked amount)
	$: cashSales = closingTotal - (operation?.total_after || 0);

	// Purchase vouchers
	let vouchers: Array<{serial: string, amount: number}> = [];
	let newVoucherSerial = '';
	let newVoucherAmount: number | '' = '';

	function addVoucher() {
		if (newVoucherSerial && newVoucherAmount) {
			// Check for duplicates (same serial and amount)
			const isDuplicate = vouchers.some(v => 
				v.serial === newVoucherSerial && v.amount === Number(newVoucherAmount)
			);
			
			if (isDuplicate) {
				alert('This voucher (same serial and amount) already exists!');
				return;
			}

			vouchers = [...vouchers, {
				serial: newVoucherSerial,
				amount: Number(newVoucherAmount)
			}];
			newVoucherSerial = '';
			newVoucherAmount = '';
		}
	}

	function removeVoucher(index: number) {
		vouchers = vouchers.filter((_, i) => i !== index);
	}

	// Calculate vouchers total
	$: vouchersTotal = vouchers.reduce((sum, v) => sum + v.amount, 0);

	// Calculate total cash sales (cash sales + vouchers - recharge sales)
	$: totalCashSales = (cashSales + vouchersTotal) - (Number(sales) || 0);

	// Bank reconciliation payment methods
	let madaAmount: number | '' = '';
	let visaAmount: number | '' = '';
	let masterCardAmount: number | '' = '';
	let googlePayAmount: number | '' = '';
	let otherAmount: number | '' = '';

	// Calculate bank reconciliation total
	$: bankTotal = (Number(madaAmount) || 0) + (Number(visaAmount) || 0) + (Number(masterCardAmount) || 0) + (Number(googlePayAmount) || 0) + (Number(otherAmount) || 0);

	// Calculate total sales (total cash sales + total bank sales)
	$: totalSales = totalCashSales + bankTotal;

	// System sales
	let systemCashSales: number | '' = '';
	let systemCardSales: number | '' = '';
	let systemReturn: number | '' = '';

	// Calculate system sales totals
	$: totalSystemCashSales = (Number(systemCashSales) || 0) - (Number(systemReturn) || 0);
	$: totalSystemSales = totalSystemCashSales + (Number(systemCardSales) || 0);

	// Time format conversion for 12-hour format
	let startDateInput = '';
	let startTimeInput = '';
	let startHour = '12';
	let startMinute = '00';
	let startAmPm = 'AM';
	let startHourOpen = false;
	let startMinuteOpen = false;

	let endDateInput = '';
	let endTimeInput = '';
	let endHour = '12';
	let endMinute = '00';
	let endAmPm = 'AM';
	let endHourOpen = false;
	let endMinuteOpen = false;

	// Recharge card balance fields
	let openingBalance: number | '' = '';
	let closeBalance: number | '' = '';
	let sales: number | '' = '';

	// Auto-calculate sales
	$: sales = (Number(openingBalance) || 0) - (Number(closeBalance) || 0);

	// Differences fields
	let differenceInCashSales: number = 0;
	let differenceInCardSales: number = 0;

	// Auto-calculate difference in cash sales (total cash sales - (system cash sales - returns))
	$: differenceInCashSales = Math.round((totalCashSales - ((Number(systemCashSales) || 0) - (Number(systemReturn) || 0))) * 100) / 100;

	// Auto-calculate difference in card sales (bank total - system card sales)
	$: differenceInCardSales = Math.round((bankTotal - (Number(systemCardSales) || 0)) * 100) / 100;

	// Auto-calculate total difference
	$: totalDifference = Math.round((differenceInCashSales + differenceInCardSales) * 100) / 100;

	// Supervisor code
	let supervisorCode: string = '';
	let supervisorName: string = '';
	let supervisorCodeError: string = '';
	let closingSaved: boolean = false;

	const supabase = createClient(
		import.meta.env.VITE_SUPABASE_URL,
		import.meta.env.VITE_SUPABASE_ANON_KEY
	);

	async function verifySupervisorCode() {
		supervisorCodeError = '';
		supervisorName = '';

		if (!supervisorCode) {
			return;
		}

		// Get cashier name from operation notes
		let cashierName = '';
		try {
			if (operation?.notes) {
				const notes = typeof operation.notes === 'string' 
					? JSON.parse(operation.notes) 
					: operation.notes;
				cashierName = notes.cashier_name || '';
			}
		} catch (e) {
			// Ignore parsing errors
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('username')
				.eq('quick_access_code', supervisorCode)
				.single();

			if (error) throw error;

			if (data) {
				const verifiedName = data.username || '';
				
				// Don't allow supervisor to be same person as cashier
				if (verifiedName === cashierName) {
					supervisorName = '';
					supervisorCodeError = 'Supervisor must be different from cashier';
					return;
				}
				
				supervisorName = verifiedName;
				supervisorCodeError = '';
			} else {
				supervisorName = '';
				supervisorCodeError = 'Invalid supervisor code';
			}
		} catch (error) {
			console.error('Error verifying supervisor code:', error);
			supervisorName = '';
			supervisorCodeError = 'Invalid supervisor code';
		}
	}

	// Auto-verify supervisor code as user types
	$: if (supervisorCode) {
		verifySupervisorCode();
	} else {
		supervisorName = '';
		supervisorCodeError = '';
	}

	async function saveSupervisorCode() {
		if (!supervisorName) {
			return;
		}

		try {
			// Get supervisor user ID
			const { data: supervisorData, error: supervisorError } = await supabase
				.from('users')
				.select('id')
				.eq('quick_access_code', supervisorCode)
				.single();

			if (supervisorError) throw supervisorError;
			const supervisorUserId = supervisorData?.id;

			// Prepare closing details
			const closingData = {
				supervisor_name: supervisorName,
				supervisor_id: supervisorUserId,
				closing_start_date: new Date().toISOString().split('T')[0],
				closing_start_time: startHour && startMinute ? `${startHour}:${startMinute} ${startAmPm}` : null,
				closing_end_date: new Date().toISOString().split('T')[0],
				closing_end_time: endHour && endMinute ? `${endHour}:${endMinute} ${endAmPm}` : null,
				
				// Recharge cards
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				recharge_transaction_start_date: startDateInput,
				recharge_transaction_start_time: startTimeInput || `${startHour}:${startMinute} ${startAmPm}`,
				recharge_transaction_end_date: endDateInput,
				recharge_transaction_end_time: endTimeInput || `${endHour}:${endMinute} ${endAmPm}`,
				
				// Bank reconciliation
				bank_mada: madaAmount || 0,
				bank_visa: visaAmount || 0,
				bank_mastercard: masterCardAmount || 0,
				bank_google_pay: googlePayAmount || 0,
				bank_other: otherAmount || 0,
				bank_total: bankTotal,
				
				// ERP details
				system_cash_sales: systemCashSales || 0,
				system_card_sales: systemCardSales || 0,
				system_return: systemReturn || 0,
				
				// Differences
				difference_cash_sales: differenceInCashSales,
				difference_card_sales: differenceInCardSales,
				total_difference: totalDifference,
				
				// Sales totals
				total_cash_sales: totalCashSales,
				vouchers_total: vouchersTotal,
				total_system_cash_sales: totalSystemCashSales,
				total_sales: totalSales,
				total_system_sales: totalSystemSales
			};

			// Update box operation with closing details
			// First, try updating without status to isolate the issue
			const updatePayload = {
				closing_details: closingData,
				supervisor_id: supervisorUserId,
				supervisor_verified_at: new Date().toISOString(),
				end_time: new Date().toISOString(),
				// Also update individual fields for easy querying
				difference_cash_sales: differenceInCashSales,
				difference_card_sales: differenceInCardSales,
				total_difference: totalDifference,
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				bank_mada: madaAmount || 0,
				bank_visa: visaAmount || 0,
				bank_mastercard: masterCardAmount || 0,
				bank_google_pay: googlePayAmount || 0,
				bank_other: otherAmount || 0,
				bank_total: bankTotal,
				system_cash_sales: systemCashSales || 0,
				system_card_sales: systemCardSales || 0,
				system_return: systemReturn || 0
			};

			const { error: updateError } = await supabase
				.from('box_operations')
				.update(updatePayload)
				.eq('id', operation.id);

			if (updateError) {
				console.error('Update error:', updateError);
				throw updateError;
			}

			console.log('Closing box details saved successfully');

			// Now try to update the status separately
			// Include updated_at in the update to ensure trigger fires
			const { error: statusError } = await supabase
				.from('box_operations')
				.update({ 
					status: 'pending_close',
					updated_at: new Date().toISOString()
				})
				.eq('id', operation.id);

			if (statusError) {
				console.error('Status update error:', statusError);
				console.error('Status error code:', statusError.code);
				console.error('Status error message:', statusError.message);
				// Don't throw - the details were saved, just status update failed
				// Try alternative: use raw SQL via RPC if available
			} else {
				console.log('Status updated to pending_close');
			}

			closingSaved = true;
			
			// Show success message
			alert('Box closing saved! Pending final close from POS Collection Manager');
		} catch (error) {
			console.error('Error saving closing box:', error);
			supervisorCodeError = 'Error saving closing box: ' + (error.message || 'Unknown error');
		}
	}

	const hours = Array.from({ length: 12 }, (_, i) => (i + 1).toString().padStart(2, '0'));
	const minutes = Array.from({ length: 60 }, (_, i) => i.toString().padStart(2, '0'));

	function updateStartTime() {
		startTimeInput = `${startHour}:${startMinute} ${startAmPm}`;
	}

	function updateEndTime() {
		endTimeInput = `${endHour}:${endMinute} ${endAmPm}`;
	}
</script>

<div class="close-box-container">
	<div class="top-info-row">
		<div class="info-group">
			<span class="info-label">Cashier (Started):</span>
			<span class="info-value">{operationData.cashier_name || 'N/A'}</span>
		</div>
		<div class="info-group">
			<span class="info-label">Supervisor (Checked):</span>
			<span class="info-value">{operationData.supervisor_name || 'N/A'}</span>
		</div>
		<div class="info-group">
			<span class="info-label">Amount Issued:</span>
			<div class="info-value">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{(operation?.total_before || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		<div class="info-group">
			<span class="info-label">Amount Checked:</span>
			<div class="info-value">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{(operation?.total_after || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		<div class="info-group">
			<span class="info-label">POS Number:</span>
			<div class="pos-display-inline">POS {selectedPosNumber}</div>
		</div>
	</div>

	<div class="two-cards-row">
		<div class="half-card split-card">
			<div class="split-section">
				<div class="card-number">7</div>
				<div class="card-header-text">Closing Details Entered</div>
				<div class="closing-cash-grid-2row">
					{#each Object.entries(denomLabels) as [key, label] (key)}
						<div class="denom-input-group">
							<label>
								{#if label !== 'Coins'}
									<span>{label}</span>
									<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
								{:else}
									{label}
								{/if}
							</label>
							<div class="denom-input-wrapper">
								<input
									type="number"
									min="0"
									readonly
									value={closingCounts[key] || ''}
								/>
								{#if closingCounts[key] > 0}
									<div class="denom-total">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon-tiny" />
										{((closingCounts[key] || 0) * denomValues[key]).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
									</div>
								{/if}
							</div>
						</div>
					{/each}
				</div>
				<div class="closing-total">
					<span class="label">Closing Total:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{closingTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="cash-sales">
					<span class="label">Cash Sales (as per Closing Count):</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{cashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-cash-sales">
					<span class="label">Total Cash Sales:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalCashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-bank-sales">
					<span class="label">Total Bank Sales:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-sales">
					<span class="label">Total Sales:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section">
				<div class="card-number">8</div>
				<div class="card-header-text">Sales through Purchase Voucher</div>
				
				<!-- Input row hidden for read-only view -->

				{#if vouchers.length > 0}
					<div class="vouchers-table">
						<table>
							<thead>
								<tr>
									<th>Serial</th>
									<th>Amount</th>
								</tr>
							</thead>
							<tbody>
								{#each vouchers as voucher, index (index)}
									<tr>
										<td>{voucher.serial}</td>
										<td>
											<div class="amount-cell">
												<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
												<span>{voucher.amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<div class="vouchers-total">
						<span class="label">Vouchers Total:</span>
						<div class="amount">
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
							<span>{vouchersTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						</div>
					</div>
				{/if}
			</div>
		</div>
		<div class="half-card split-card">
			<div class="split-section">
				<div class="card-number">9</div>
				<div class="card-header-text">Bank Reconciliation</div>
				
				<div class="bank-fields-row">
					<div class="bank-input-group">
						<label>Mada</label>
						<input
							type="number"
							bind:value={madaAmount}
							readonly
							min="0"
							step="0.01"
							class="bank-input"
						/>
					</div>
					<div class="bank-input-group">
						<label>Visa</label>
						<input
							type="number"
							bind:value={visaAmount}
							readonly
							min="0"
							step="0.01"
							class="bank-input"
						/>
					</div>
					<div class="bank-input-group">
						<label>MasterCard</label>
						<input
							type="number"
							bind:value={masterCardAmount}
							readonly

							min="0"
							step="0.01"
							class="bank-input"
						/>
					</div>
					<div class="bank-input-group">
						<label>Google Pay</label>
						<input
							type="number"
							bind:value={googlePayAmount}

							min="0"
							step="0.01"
							class="bank-input"
						/>
					</div>
					<div class="bank-input-group">
						<label>Other</label>
						<input
							type="number"
							bind:value={otherAmount}

							min="0"
							step="0.01"
							class="bank-input"
						/>
					</div>
				</div>

				<div class="bank-total">
					<span class="label">Bank Total:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section">
				<div class="card-number">10</div>
				<div class="card-header-text">ERP Closing Details</div>
				
				<div class="system-sales-row">
					<div class="system-input-group">
						<label>Cash Sales</label>
						<input
							type="number"
							bind:value={systemCashSales}
							readonly
							min="0"
							step="0.01"
							class="system-input"
						/>
					</div>
					<div class="system-input-group">
						<label>Card Sales</label>
						<input
							type="number"
							bind:value={systemCardSales}
							readonly
							min="0"
							step="0.01"
							class="system-input"
						/>
					</div>
					<div class="system-input-group">
						<label>Return</label>
						<input
							type="number"
							bind:value={systemReturn}
							readonly
							min="0"
							step="0.01"
							class="system-input"
						/>
					</div>
				</div>

				<div class="system-total-1">
					<span class="label">Total ERP Cash Sales:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSystemCashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>

				<div class="system-total-2">
					<span class="label">Total ERP Sales:</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSystemSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section recharge-card-section-11">
				<div class="card-number">11</div>
				<div class="card-header-text">Recharge Cards</div>
				
				<div class="date-time-row">
					<div class="date-time-group">
						<label>Start Date</label>
						<input type="date" class="date-time-input" bind:value={startDateInput} />
					</div>
					<div class="date-time-group">
						<label>Start Time</label>
						<div class="digital-time-picker">
							<button 
								class="time-display-btn"
								on:click={() => startHourOpen = !startHourOpen}
							>
								<span class="time-value">{startHour}:{startMinute}</span>
								<span class="ampm-value">{startAmPm}</span>
							</button>
							{#if startHourOpen}
								<div class="picker-popup">
									<div class="picker-controls">
										<div class="picker-column">
											<label class="picker-label">Hour</label>
											<div class="dropdown-popup hours-popup">
												{#each hours as hour}
													<div 
														class="popup-option"
														class:selected={startHour === hour}
														on:click={() => { startHour = hour; updateStartTime(); }}
													>
														{hour}
													</div>
												{/each}
											</div>
										</div>
										<div class="picker-column">
											<label class="picker-label">Minute</label>
											<div class="dropdown-popup minutes-popup">
												{#each minutes as minute}
													<div 
														class="popup-option"
														class:selected={startMinute === minute}
														on:click={() => { startMinute = minute; updateStartTime(); }}
													>
														{minute}
													</div>
												{/each}
											</div>
										</div>
										<div class="picker-column">
											<label class="picker-label">Period</label>
											<select bind:value={startAmPm} on:change={updateStartTime} class="ampm-select-popup">
												<option>AM</option>
												<option>PM</option>
											</select>
										</div>
									</div>
									<button class="close-picker-btn" on:click={() => startHourOpen = false}>Done</button>
								</div>
							{/if}
						</div>
					</div>
					<div class="date-time-group">
						<label>End Date</label>
						<input type="date" class="date-time-input" bind:value={endDateInput} />
					</div>
					<div class="date-time-group">
						<label>End Time</label>
						<div class="digital-time-picker">
							<button 
								class="time-display-btn"
								on:click={() => endHourOpen = !endHourOpen}
							>
								<span class="time-value">{endHour}:{endMinute}</span>
								<span class="ampm-value">{endAmPm}</span>
							</button>
							{#if endHourOpen}
								<div class="picker-popup">
									<div class="picker-controls">
										<div class="picker-column">
											<label class="picker-label">Hour</label>
											<div class="dropdown-popup hours-popup">
												{#each hours as hour}
													<div 
														class="popup-option"
														class:selected={endHour === hour}
														on:click={() => { endHour = hour; updateEndTime(); }}
													>
														{hour}
													</div>
												{/each}
											</div>
										</div>
										<div class="picker-column">
											<label class="picker-label">Minute</label>
											<div class="dropdown-popup minutes-popup">
												{#each minutes as minute}
													<div 
														class="popup-option"
														class:selected={endMinute === minute}
														on:click={() => { endMinute = minute; updateEndTime(); }}
													>
														{minute}
													</div>
												{/each}
											</div>
										</div>
										<div class="picker-column">
											<label class="picker-label">Period</label>
											<select bind:value={endAmPm} on:change={updateEndTime} class="ampm-select-popup">
												<option>AM</option>
												<option>PM</option>
											</select>
										</div>
									</div>
									<button class="close-picker-btn" on:click={() => endHourOpen = false}>Done</button>
								</div>
							{/if}
						</div>
					</div>
				</div>
				
				<div class="balance-row">
					<div class="balance-group">
						<label>Opening Balance</label>
						<input
							type="number"
							bind:value={openingBalance}
							readonly
							placeholder="0.00"
							min="0"
							step="0.01"
							class="balance-input"
						/>
					</div>
					<div class="balance-group">
						<label>Close Balance</label>
						<input
							type="number"
							bind:value={closeBalance}
							readonly
							placeholder="0.00"
							min="0"
							step="0.01"
							class="balance-input"
						/>
					</div>
					<div class="balance-group">
						<label>Sales</label>
						<input
							type="number"
							value={sales}
							placeholder="0.00"
							disabled
							class="balance-input balance-input-disabled"
						/>
					</div>
				</div>
			</div>
			<div class="split-section">
				<div class="card-number">12</div>
				
				<div class="sub-cards-row">
					<div class="sub-card">
						<div class="sub-card-content">
							<div class="difference-row">
								<div class="difference-group">
									<label>Cash Sales</label>
									<input
										type="number"
										value={differenceInCashSales}
										disabled
										class="difference-input difference-input-disabled"
									/>
									<span class="difference-label" class:badge-short={differenceInCashSales < 0} class:badge-excess={differenceInCashSales > 0} class:badge-match={differenceInCashSales === 0}>
										{differenceInCashSales < 0 ? 'Short' : differenceInCashSales > 0 ? 'Excess' : 'Match'}
									</span>
								</div>
								<div class="difference-group">
									<label>Card Sales</label>
									<input
										type="number"
										value={differenceInCardSales}
										disabled
										class="difference-input difference-input-disabled"
									/>
									<span class="difference-label" class:badge-short={differenceInCardSales < 0} class:badge-excess={differenceInCardSales > 0} class:badge-match={differenceInCardSales === 0}>
										{differenceInCardSales < 0 ? 'Short' : differenceInCardSales > 0 ? 'Excess' : 'Match'}
									</span>
								</div>
							</div>
							<div style="display: flex; flex-direction: column; gap: 0.15rem; margin-top: 0.3rem;">
								<input
									type="number"
									value={totalDifference}
									disabled
									class="difference-input difference-input-disabled"
								/>
								<span class="difference-label" class:badge-short={totalDifference < 0} class:badge-excess={totalDifference > 0} class:badge-match={totalDifference === 0}>
									{totalDifference < 0 ? 'Short' : totalDifference > 0 ? 'Excess' : 'Match'}
								</span>
							</div>
						</div>
					</div>
					<div class="sub-card">
						<div class="sub-card-content" style="gap: 0.3rem;">
							{#if supervisorName}
								<input
									type="text"
									class="supervisor-code-input"
									value={supervisorName}
									readonly
								/>
							{:else}
								<input
									type="password"
									placeholder="Supervisor Code"
									bind:value={supervisorCode}
									class="supervisor-code-input"
								/>
							{/if}
							{#if supervisorCodeError && !supervisorName}
								<div style="font-size: 0.6rem; color: #dc2626; font-weight: 600; text-align: center;">
									{supervisorCodeError}
								</div>
							{/if}
							{#if supervisorName && !closingSaved}
								<div style="font-size: 0.6rem; color: #15803d; font-weight: 600; text-align: center;">
									✓ Verified
								</div>
							{/if}
							<button
								on:click={saveSupervisorCode}
								class="save-button"
								disabled={true}
							>
								{closingSaved ? '✓ Closed' : 'Close'}
							</button>
							{#if closingSaved}
								<div style="font-size: 0.6rem; color: #15803d; font-weight: 600; text-align: center;">
									Pending final close in POS
								</div>
							{/if}
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.close-box-container {
		width: 100%;
		height: 100%;
		background: white;
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.top-info-row {
		display: flex;
		gap: 2rem;
		padding: 1rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #86efac;
		border-radius: 0.75rem;
		box-shadow: 0 4px 6px -1px rgba(34, 197, 94, 0.1);
		flex-wrap: wrap;
	}

	.info-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
	}

	.info-value {
		font-size: 0.875rem;
		font-weight: 600;
		color: #166534;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.pos-display-inline {
		padding: 0.25rem 0.75rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 700;
		display: inline-block;
	}

	.two-cards-row {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		flex: 1;
		min-height: 0;
	}

	.half-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 1rem;
		height: 100%;
		position: relative;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.split-card {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 0;
		overflow-y: auto;
	}

	.split-section {
		flex: 1;
		min-height: 200px;
		background: white;
		border: 1px solid #e5e7eb;
		padding: 1rem;
		position: relative;
		border-radius: 0.5rem;
		display: flex;
		flex-direction: column;
	}

	.split-section:nth-child(1) {
		flex: 1;
		min-height: 200px;
	}

	.split-section:nth-child(2) {
		flex: 0.6;
		min-height: 140px;
	}

	.split-section:nth-child(3) {
		flex: 0.7;
		min-height: 130px;
	}

	.split-section:nth-child(4) {
		flex: 0.7;
		min-height: 130px;
	}

	/* Recharge Cards Card 11 Styling */
	.recharge-card-section-11 {
		flex: 0.7 !important;
		min-height: 120px !important;
		border: 3px solid #ea580c !important;
		padding: 0.5rem !important;
	}

	.date-time-row {
		display: flex;
		gap: 0.25rem;
		flex: 1;
		align-items: flex-end;
	}

	.date-time-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		min-width: 0;
		height: 100%;
	}

	.date-time-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		flex-shrink: 0;
	}

	.date-time-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		flex: 1;
		box-sizing: border-box;
	}

	.date-time-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.time-input-wrapper {
		display: flex;
		gap: 0.25rem;
		align-items: stretch;
	}

	.time-12h {
		flex: 1 !important;
	}

	.ampm-select {
		flex: 0.6;
		padding: 0.3rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		cursor: pointer;
	}

	.ampm-select:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.digital-time-picker {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		position: relative;
		flex: 1;
	}

	.time-display-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		background: #fef3c7;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 700;
		color: #92400e;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
		flex: 1;
		box-sizing: border-box;
		justify-content: center;
	}

	.time-display-btn:hover {
		background: #fed7aa;
		border-color: #f97316;
	}

	.time-value {
		font-family: 'Courier New', monospace;
		font-size: 0.8rem;
		letter-spacing: 0.05em;
	}

	.ampm-value {
		font-size: 0.6rem;
		margin-left: 0.2rem;
	}

	.picker-popup {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		margin-top: 0.3rem;
		background: white;
		border: 2px solid #f97316;
		border-radius: 0.5rem;
		padding: 0.5rem;
		z-index: 20;
		box-shadow: 0 8px 16px rgba(249, 115, 22, 0.3);
	}

	.picker-controls {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.picker-label {
		display: block;
		font-size: 0.6rem;
		font-weight: 700;
		color: #92400e;
		margin-bottom: 0.2rem;
		text-align: center;
	}

	.close-picker-btn {
		width: 100%;
		padding: 0.3rem 0.5rem;
		background: #f97316;
		border: none;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 700;
		color: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-picker-btn:hover {
		background: #ea580c;
	}

	.picker-row {
		display: flex;
		gap: 0.2rem;
		align-items: center;
		position: relative;
	}

	.picker-column {
		position: relative;
		flex: 1;
	}

	.picker-btn {
		width: 100%;
		padding: 0.3rem 0.25rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		background: white;
		font-size: 0.65rem;
		font-weight: 700;
		color: #92400e;
		cursor: pointer;
		transition: all 0.2s;
		font-family: 'Courier New', monospace;
	}

	.picker-btn:hover {
		background: #fef3c7;
		border-color: #f97316;
	}

	.picker-btn:active {
		transform: scale(0.95);
	}

	.colon {
		font-size: 0.7rem;
		font-weight: 700;
		color: #92400e;
		margin-top: 0.3rem;
	}

	.dropdown-popup {
		position: relative;
		background: white;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		max-height: 120px;
		overflow-y: auto;
		z-index: 10;
	}

	.hours-popup {
		width: 100%;
	}

	.minutes-popup {
		width: 100%;
	}

	.popup-option {
		padding: 0.25rem 0.3rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		cursor: pointer;
		text-align: center;
		transition: all 0.15s;
		border-bottom: 1px solid #fed7aa;
		font-family: 'Courier New', monospace;
	}

	.popup-option:last-child {
		border-bottom: none;
	}

	.popup-option:hover {
		background: #fef3c7;
	}

	.popup-option.selected {
		background: #f97316;
		color: white;
		font-weight: 700;
	}

	.ampm-select-popup {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		cursor: pointer;
	}

	.ampm-select-popup:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.balance-row {
		display: flex;
		gap: 0.25rem;
		flex: 1;
		align-items: flex-end;
	}

	.balance-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		min-width: 0;
		height: 100%;
	}

	.balance-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		flex-shrink: 0;
	}

	.balance-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		flex: 1;
		box-sizing: border-box;
	}

	.balance-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.balance-input-disabled {
		background: #f3f4f6;
		color: #6b7280;
		border-color: #e5e7eb;
		cursor: not-allowed;
	}

	.balance-input-disabled:focus {
		outline: none;
		border-color: #e5e7eb;
		box-shadow: none;
	}

	.sub-cards-row {
		display: flex;
		gap: 0.5rem;
		flex: 1;
	}

	.sub-card {
		flex: 1;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #86efac;
		border-radius: 0.5rem;
		padding: 0.75rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.sub-card-header {
		font-size: 0.7rem;
		font-weight: 700;
		color: #166534;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.sub-card-content {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		flex: 1;
	}

	.difference-row {
		display: flex;
		gap: 0.3rem;
		flex: 1;
	}

	.difference-group {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		flex: 1;
	}

	.difference-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #166534;
	}

	.difference-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #86efac;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #166534;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.difference-input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2);
	}

	.difference-input-disabled {
		background: #f3f4f6;
		color: #6b7280;
		border-color: #e5e7eb;
		cursor: not-allowed;
	}

	.difference-input-disabled:focus {
		outline: none;
		border-color: #e5e7eb;
		box-shadow: none;
	}

	.difference-label {
		font-size: 0.55rem;
		font-weight: 700;
		text-align: center;
		padding: 0.1rem 0.2rem;
		border-radius: 0.25rem;
	}

	.badge-short {
		color: #7f1d1d;
		background: #fee2e2;
	}

	.badge-excess {
		color: #92400e;
		background: #fef3c7;
	}

	.badge-match {
		color: #15803d;
		background: #dcfce7;
	}

	.supervisor-code-input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 2px solid #ea580c;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #000;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.supervisor-code-input::placeholder {
		color: #9ca3af;
	}

	.supervisor-code-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.save-button {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #ea580c;
		border-radius: 0.25rem;
		background: #ea580c;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.save-button:hover {
		background: #d94800;
		border-color: #d94800;
	}

	.save-button:active {
		transform: scale(0.98);
	}

	.save-button:disabled {
		background: #cbd5e1;
		border-color: #cbd5e1;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.save-button:disabled:hover {
		background: #cbd5e1;
		border-color: #cbd5e1;
	}

	/* Right column specific sizes */
	.half-card:last-child .split-section:nth-child(1) {
		flex: 0.6;
		min-height: 130px;
	}

	.half-card:last-child .split-section:nth-child(2) {
		flex: 0.8;
		min-height: 150px;
	}

	.half-card:last-child .split-section:nth-child(3) {
		flex: 1.1;
		min-height: 210px;
	}

	.split-section:first-child {
		border-radius: 0.5rem 0.5rem 0 0;
	}

	.split-section:last-child {
		border-radius: 0 0 0.5rem 0.5rem;
	}

	.split-section:only-child {
		border-radius: 0.5rem;
	}

	.blank-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		position: relative;
		padding: 1rem;
	}

	.info-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 0.75rem;
		position: relative;
	}

	.card-number {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
		background: #3b82f6;
		color: white;
		width: 1.25rem;
		height: 1.25rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.625rem;
		font-weight: 700;
		z-index: 1;
	}

	.card-header-text {
		font-size: 0.7rem;
		font-weight: 600;
		color: #1f2937;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 0.5rem;
	}

	.card-content-center {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 0.5rem;
		padding: 0.5rem;
	}

	.pos-label {
		font-size: 0.625rem;
		color: #6b7280;
		font-weight: 500;
	}

	.pos-display {
		padding: 0.375rem 0.75rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 700;
	}

	.card-content {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-row {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.info-row .label {
		font-size: 0.625rem;
		color: #6b7280;
		font-weight: 500;
	}

	.info-row .value {
		font-size: 0.75rem;
		color: #1f2937;
		font-weight: 600;
	}

	.amount-value {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		color: #1f2937;
		font-weight: 600;
	}

	.currency-icon {
		width: 0.375rem;
		height: 0.375rem;
		object-fit: contain;
	}

	.closing-cash-grid-2row {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.4rem;
		margin-bottom: 1rem;
	}

	.denom-input-group {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 0.3rem;
	}

	.denom-input-wrapper {
		flex: 1;
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 0.4rem;
		min-width: 0;
	}

	.denom-total {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.55rem;
		font-weight: 600;
		color: #059669;
		white-space: nowrap;
		flex-shrink: 0;
	}

	.currency-icon-tiny {
		width: 0.65rem;
		height: 0.65rem;
		object-fit: contain;
	}

	.denom-input-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #ea580c;
		display: flex;
		align-items: center;
		gap: 0.2rem;
		white-space: nowrap;
		flex-shrink: 0;
		min-width: 2.5rem;
		justify-content: flex-start;
	}

	.denom-input-wrapper input {
		flex: 0 0 auto;
		min-width: 0;
		width: 3.5rem;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1fae5;
		border-radius: 0.375rem;
		font-size: 0.65rem;
		background: white;
		font-weight: 600;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(34, 197, 94, 0.1);
		transition: all 0.2s;
	}

	.denom-input-wrapper input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.15);
		transform: translateY(-1px);
	}

	.currency-icon-small {
		width: 0.4rem;
		height: 0.4rem;
		object-fit: contain;
	}

	.closing-total {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #1e40af;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.closing-total .label {
		font-size: 0.65rem;
	}

	.closing-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.cash-sales {
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #166534;
		border: 2px solid #86efac;
		box-shadow: 0 4px 6px -1px rgba(34, 197, 94, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.cash-sales .label {
		font-size: 0.65rem;
	}

	.cash-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.voucher-input-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.4rem;
	}

	.voucher-serial-input {
		flex: 1.5;
		padding: 0.2rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.voucher-serial-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.voucher-amount-input {
		flex: 1;
		padding: 0.2rem 0.3rem;
		border: 2px solid #d1fae5;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.voucher-amount-input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2);
	}

	.add-voucher-btn {
		width: 1.5rem;
		height: 1.5rem;
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		border: none;
		border-radius: 0.25rem;
		color: white;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.3);
		transition: all 0.2s;
	}

	.add-voucher-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 8px rgba(34, 197, 94, 0.4);
	}

	.add-voucher-btn:active {
		transform: translateY(0);
	}

	.vouchers-table {
		max-height: 150px;
		overflow-y: auto;
		margin-bottom: 0.5rem;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		flex: 1;
	}

	.vouchers-table table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.65rem;
	}

	.vouchers-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.vouchers-table th {
		padding: 0.25rem 0.35rem;
		text-align: left;
		font-weight: 700;
		color: #6b7280;
		border-bottom: 1px solid #e5e7eb;
	}

	.vouchers-table td {
		padding: 0.25rem 0.35rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.vouchers-table tbody tr:hover {
		background: #f9fafb;
	}

	.amount-cell {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-weight: 600;
		color: #166534;
	}

	.remove-btn {
		background: #fee2e2;
		border: none;
		color: #dc2626;
		width: 1.25rem;
		height: 1.25rem;
		border-radius: 0.25rem;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.remove-btn:hover {
		background: #fecaca;
		transform: scale(1.1);
	}

	.vouchers-total {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		padding: 0.35rem 0.5rem;
		border-radius: 0.375rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #92400e;
		border: 2px solid #fcd34d;
		box-shadow: 0 4px 6px -1px rgba(245, 158, 11, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.vouchers-total .label {
		font-size: 0.7rem;
	}

	.vouchers-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.8rem;
	}

	.total-cash-sales {
		background: linear-gradient(135deg, #fed7aa 0%, #fdba74 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #9a3412;
		border: 2px solid #fb923c;
		box-shadow: 0 6px 8px -1px rgba(249, 115, 22, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-cash-sales .label {
		font-size: 0.65rem;
	}

	.total-cash-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.total-bank-sales {
		background: linear-gradient(135deg, #e0e7ff 0%, #c7d2fe 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #3730a3;
		border: 2px solid #a5b4fc;
		box-shadow: 0 6px 8px -1px rgba(79, 70, 229, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-bank-sales .label {
		font-size: 0.65rem;
	}

	.total-bank-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.total-sales {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #065f46;
		border: 2px solid #6ee7b7;
		box-shadow: 0 6px 8px -1px rgba(16, 185, 129, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-sales .label {
		font-size: 0.65rem;
	}

	.total-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	/* Bank Reconciliation Styles */
	.bank-fields-row {
		display: flex;
		gap: 0.35rem;
		margin-bottom: 0.75rem;
		flex-wrap: nowrap;
	}

	.bank-input-group {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.bank-input-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.bank-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #bfdbfe;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #1e40af;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		min-width: 0;
	}

	.bank-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.bank-total {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 0.35rem 0.5rem;
		border-radius: 0.375rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #1e40af;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.bank-total .label {
		font-size: 0.7rem;
	}

	.bank-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.8rem;
	}

	/* System Sales Styles */
	.system-sales-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.75rem;
	}

	.system-input-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.system-input-group label {
		font-size: 0.65rem;
		font-weight: 700;
		color: #1f2937;
	}

	.system-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #e9d5ff;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #7c3aed;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		min-width: 0;
	}

	.system-input:focus {
		outline: none;
		border-color: #a855f7;
		box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.1);
	}

	.system-total-1 {
		background: linear-gradient(135deg, #fce7f3 0%, #fbcfe8 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #be185d;
		border: 2px solid #f9a8d4;
		box-shadow: 0 4px 6px -1px rgba(219, 39, 119, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.system-total-1 .label {
		font-size: 0.65rem;
	}

	.system-total-1 .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.system-total-2 {
		background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #7c3aed;
		border: 2px solid #c4b5fd;
		box-shadow: 0 4px 6px -1px rgba(124, 58, 237, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.system-total-2 .label {
		font-size: 0.65rem;
	}

	.system-total-2 .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	/* Recharge Cards Styles */
	.recharge-cards-container {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex: 1;
	}

	.recharge-card-section {
		flex: 1;
		padding: 0.5rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #7dd3fc;
		border-radius: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.recharge-card-section.closing-section {
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
		border-color: #86efac;
	}

	.recharge-card-title {
		font-size: 0.65rem;
		font-weight: 700;
		color: #0c4a6e;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.recharge-card-section.closing-section .recharge-card-title {
		color: #166534;
	}

	.recharge-input-row {
		display: flex;
		gap: 0.3rem;
		flex: 1;
	}

	.recharge-serial-input {
		flex: 1.5;
		padding: 0.3rem 0.4rem;
		border: 2px solid #7dd3fc;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #0c4a6e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.recharge-serial-input:focus {
		outline: none;
		border-color: #0ea5e9;
		box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.2);
	}

	.recharge-amount-input {
		flex: 1;
		padding: 0.3rem 0.4rem;
		border: 2px solid #7dd3fc;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #0c4a6e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.recharge-amount-input:focus {
		outline: none;
		border-color: #0ea5e9;
		box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.2);
	}

	.closing-recharge-status {
		display: flex;
		align-items: center;
		justify-content: center;
		flex: 1;
		padding: 0.5rem;
	}

	.status-label {
		font-size: 0.7rem;
		font-weight: 700;
		color: #166534;
		background: white;
		padding: 0.3rem 0.5rem;
		border-radius: 0.375rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}
</style>


