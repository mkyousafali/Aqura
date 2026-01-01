<script>
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { onMount } from 'svelte';

	let showAddBookForm = false;
	let showAddSingleVoucherForm = false;
	let bookNumber = '';
	let serialStart = '';
	let serialEnd = '';
	let voucherCount = 0;
	let perVoucherValue = '';
	let totalValue = 0;
	let serialNumber = '';
	let singleVoucherValue = '';
	let isLoading = false;
	let existingBooks = [];
	let singleVoucherMode = 'new'; // 'new' or 'existing'
	let selectedExistingBook = '';
	let subscription;

	onMount(() => {
		setupRealtimeSubscriptions();

		return () => {
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	function setupRealtimeSubscriptions() {
		subscription = supabase
			.channel('purchase_vouchers_add_changes')
			.on(
				'postgres_changes',
				{
					event: 'INSERT',
					schema: 'public',
					table: 'purchase_vouchers'
				},
				() => {
					// Refresh existing books list when new one is added
					if (showAddSingleVoucherForm && singleVoucherMode === 'existing') {
						loadExistingBooks();
					}
				}
			)
			.subscribe();
	}

	function handleAddBook() {
		showAddBookForm = true;
	}

	function handleAddSingleVoucher() {
		showAddSingleVoucherForm = true;
		loadExistingBooks();
	}

	function calculateVoucherCount() {
		const start = parseInt(serialStart) || 0;
		const end = parseInt(serialEnd) || 0;
		voucherCount = Math.abs(end - start) + 1;
		calculateTotalValue();
	}
	function calculateTotalValue() {
		const value = parseFloat(perVoucherValue) || 0;
		totalValue = voucherCount * value;
	}

	function handleSerialChange() {
		calculateVoucherCount();
	}

	function handlePerVoucherValueChange() {
		calculateTotalValue();
	}

	async function loadExistingBooks() {
		try {
			const { data, error } = await supabase
				.from('purchase_vouchers')
				.select('id, book_number')
				.order('created_at', { ascending: false })
				.limit(100);
			if (!error) {
				existingBooks = data || [];
			}
		} catch (error) {
			console.error('Error loading existing books:', error);
		}
	}

	async function handleSaveBook() {
		if (!bookNumber || !serialStart || !serialEnd || !perVoucherValue) {
			alert('Please fill in all fields');
			return;
		}

		if (!$currentUser?.id) {
			alert('User not authenticated');
			return;
		}

		isLoading = true;
		try {
			const start = parseInt(serialStart);
			const end = parseInt(serialEnd);
			const value = parseFloat(perVoucherValue);

			// Create book record with value + PV + book number format
			const pvId = `${Math.round(value)}PV${bookNumber.padStart(3, '0')}`;

			// Insert main purchase voucher record
			const { data: pvData, error: pvError } = await supabase
				.from('purchase_vouchers')
				.insert({
					id: pvId,
					book_number: bookNumber,
					serial_start: start,
					serial_end: end,
					voucher_count: voucherCount,
					per_voucher_value: value,
					total_value: totalValue,
					status: 'active',
					created_by: $currentUser.id
				})
				.select();

			if (pvError) {
				alert(`Error creating book: ${pvError.message}`);
				console.error('PV Error:', pvError);
				return;
			}

			// Create individual voucher items
			const voucherItems = [];
			for (let serial = start; serial <= end; serial++) {
				voucherItems.push({
					purchase_voucher_id: pvId,
					serial_number: serial,
					value: value,
					status: 'stocked',
					stock: 1,
					issue_type: 'not issued'
				});
			}

			const { data: itemsData, error: itemsError } = await supabase
				.from('purchase_voucher_items')
				.insert(voucherItems)
				.select();

			if (itemsError) {
				alert(`Error creating voucher items: ${itemsError.message}`);
				console.error('Items Error:', itemsError);
				return;
			}

			alert(`Book ${pvId} saved successfully with ${voucherCount} vouchers!`);
			// Reset form
			bookNumber = '';
			serialStart = '';
			serialEnd = '';
			perVoucherValue = '';
			voucherCount = 0;
			totalValue = 0;
			showAddBookForm = false;
		} catch (error) {
			console.error('Error saving book:', error);
			alert('Error saving book. Please try again.');
		} finally {
			isLoading = false;
		}
	}

	async function handleSaveSingleVoucher() {
		if (singleVoucherMode === 'new') {
			if (!bookNumber || !serialNumber || !singleVoucherValue) {
				alert('Please fill in all fields');
				return;
			}
		} else {
			if (!selectedExistingBook || !serialNumber || !singleVoucherValue) {
				alert('Please fill in all fields');
				return;
			}
		}

		if (!$currentUser?.id) {
			alert('User not authenticated');
			return;
		}

		isLoading = true;
		try {
			const serial = parseInt(serialNumber);
			const value = parseFloat(singleVoucherValue);
			let pvId;

			if (singleVoucherMode === 'new') {
				// Create new book with value + PV + book number format
				pvId = `${Math.round(value)}PV${bookNumber.padStart(3, '0')}`;

				// Insert main purchase voucher record
				const { data: pvData, error: pvError } = await supabase
					.from('purchase_vouchers')
					.insert({
						id: pvId,
						book_number: bookNumber,
						serial_start: serial,
						serial_end: serial,
						voucher_count: 1,
						per_voucher_value: value,
						total_value: value,
						status: 'active',
						created_by: $currentUser.id
					})
					.select();

				if (pvError) {
					alert(`Error creating voucher: ${pvError.message}`);
					console.error('PV Error:', pvError);
					return;
				}
			} else {
				// Add to existing book
				pvId = selectedExistingBook;

				// Check for duplicate serial number
				const { data: existingItems, error: checkError } = await supabase
					.from('purchase_voucher_items')
					.select('id')
					.eq('purchase_voucher_id', pvId)
					.eq('serial_number', serial);

				if (existingItems && existingItems.length > 0) {
					alert(`Serial number ${serial} already exists in this book!`);
					return;
				}

				// For simplicity, just fetch and update manually
				const { data: voucherData, error: fetchError } = await supabase
					.from('purchase_vouchers')
					.select('serial_start, serial_end, voucher_count, total_value')
					.eq('id', pvId)
					.single();

				if (fetchError) {
					alert(`Error fetching voucher data: ${fetchError.message}`);
					return;
				}

				// Update serial range if new serial is outside current range
				let newSerialStart = voucherData.serial_start;
				let newSerialEnd = voucherData.serial_end;

				if (serial < newSerialStart) {
					newSerialStart = serial;
				}
				if (serial > newSerialEnd) {
					newSerialEnd = serial;
				}

				const { error: updateErr } = await supabase
					.from('purchase_vouchers')
					.update({
						serial_start: newSerialStart,
						serial_end: newSerialEnd,
						voucher_count: voucherData.voucher_count + 1,
						total_value: voucherData.total_value + value
					})
					.eq('id', pvId);

				if (updateErr) {
					alert(`Error updating voucher: ${updateErr.message}`);
					return;
				}
			}

			// Create single voucher item
			const { data: itemData, error: itemError } = await supabase
				.from('purchase_voucher_items')
				.insert({
					purchase_voucher_id: pvId,
					serial_number: serial,
					value: value,
					status: 'stocked',
					stock: 1,
					issue_type: 'not issued'
				})
				.select();

			if (itemError) {
				alert(`Error creating voucher item: ${itemError.message}`);
				console.error('Item Error:', itemError);
				return;
			}

			alert(`Voucher with serial number ${serial} saved successfully!`);
			// Reset form
			bookNumber = '';
			serialNumber = '';
			singleVoucherValue = '';
			selectedExistingBook = '';
			singleVoucherMode = 'new';
			showAddSingleVoucherForm = false;
		} catch (error) {
			console.error('Error saving voucher:', error);
			alert('Error saving voucher. Please try again.');
		} finally {
			isLoading = false;
		}
	}
</script>

<div class="add-purchase-voucher">
	<div class="button-group">
		<button class="action-button" on:click={handleAddBook}>Add Book</button>
		<button class="action-button" on:click={handleAddSingleVoucher}>Add Single Voucher</button>
	</div>

	{#if showAddBookForm}
		<div class="form-section">
			<div class="form-group">
				<label for="bookNumber">Book Number</label>
				<input
					id="bookNumber"
					type="text"
					placeholder="Enter book number"
					bind:value={bookNumber}
					class="form-input"
				/>
			</div>

			<div class="form-row">
				<div class="form-group">
					<label for="serialStart">Serial Start</label>
					<input
						id="serialStart"
						type="number"
						placeholder="Start serial"
						bind:value={serialStart}
						on:input={handleSerialChange}
						class="form-input"
					/>
				</div>

				<div class="form-group">
					<label for="serialEnd">Serial End</label>
					<input
						id="serialEnd"
						type="number"
						placeholder="End serial"
						bind:value={serialEnd}
						on:input={handleSerialChange}
						class="form-input"
					/>
				</div>
			</div>

			<div class="form-group">
				<label for="voucherCount">Voucher Count</label>
				<input
					id="voucherCount"
					type="number"
					value={voucherCount}
					readonly
					class="form-input readonly"
				/>
			</div>

			<div class="form-group">
				<label for="perVoucherValue">Per Voucher Value</label>
				<input
					id="perVoucherValue"
					type="number"
					placeholder="Enter per voucher value"
					bind:value={perVoucherValue}
					on:input={handlePerVoucherValueChange}
					class="form-input"
				/>
			</div>

			<div class="form-group">
				<label for="totalValue">Total Value</label>
				<input
					id="totalValue"
					type="number"
					value={totalValue.toFixed(2)}
					readonly
					class="form-input readonly"
				/>
			</div>

			<div class="button-group form-buttons">
				<button class="action-button save-button" on:click={handleSaveBook} disabled={isLoading}>
					{isLoading ? 'Saving...' : 'Save Book'}
				</button>
				<button class="action-button cancel-button" on:click={() => showAddBookForm = false}>
					Cancel
				</button>
			</div>
		</div>
	{/if}

	{#if showAddSingleVoucherForm}
		<div class="form-section">
			<div class="form-group">
				<label>Add Mode</label>
				<div class="radio-group-inline">
					<label class="radio-label">
						<input
							type="radio"
							name="singleVoucherMode"
							value="new"
							bind:group={singleVoucherMode}
						/>
						<span>Add as New Book</span>
					</label>
					<label class="radio-label">
						<input
							type="radio"
							name="singleVoucherMode"
							value="existing"
							bind:group={singleVoucherMode}
						/>
						<span>Add to Existing Book</span>
					</label>
				</div>
			</div>

			{#if singleVoucherMode === 'new'}
				<div class="form-group">
					<label for="singleBookNumber">Book Number</label>
					<input
						id="singleBookNumber"
						type="text"
						placeholder="Enter book number"
						bind:value={bookNumber}
						class="form-input"
					/>
				</div>
			{:else}
				<div class="form-group">
					<label for="existingBook">Select Book</label>
					<select id="existingBook" bind:value={selectedExistingBook} class="form-input">
						<option value="">-- Select Existing Book --</option>
						{#each existingBooks as book (book.id)}
							<option value={book.id}>{book.id} - Book {book.book_number}</option>
						{/each}
					</select>
				</div>
			{/if}

			<div class="form-group">
				<label for="serialNumber">Serial Number</label>
				<input
					id="serialNumber"
					type="number"
					placeholder="Enter serial number"
					bind:value={serialNumber}
					class="form-input"
				/>
			</div>

			<div class="form-group">
				<label for="singleVoucherValue">Per Voucher Value</label>
				<input
					id="singleVoucherValue"
					type="number"
					placeholder="Enter voucher value"
					bind:value={singleVoucherValue}
					class="form-input"
				/>
			</div>

			<div class="button-group form-buttons">
				<button class="action-button save-button" on:click={handleSaveSingleVoucher} disabled={isLoading}>
					{isLoading ? 'Saving...' : 'Save Voucher'}
				</button>
				<button class="action-button cancel-button" on:click={() => showAddSingleVoucherForm = false}>
					Cancel
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.add-purchase-voucher {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
	}

	.button-group {
		display: flex;
		gap: 16px;
		margin-bottom: 24px;
	}

	.action-button {
		padding: 12px 24px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-button:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.action-button:active {
		transform: translateY(0);
	}

	.form-section {
		background: white;
		padding: 24px;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
	}

	.radio-group-inline {
		display: flex;
		gap: 24px;
	}

	.radio-label {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
	}

	.radio-label input {
		cursor: pointer;
	}

	.radio-label span {
		font-weight: 500;
		color: #374151;
	}

	label {
		display: block;
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 6px;
		font-size: 0.95rem;
	}

	.form-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		font-size: 0.95rem;
		transition: border-color 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input.readonly {
		background: #f1f5f9;
		color: #64748b;
		cursor: not-allowed;
	}

	.form-buttons {
		margin-top: 24px;
		justify-content: flex-start;
	}

	.save-button {
		background: #10b981;
	}

	.save-button:hover:not(:disabled) {
		background: #059669;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.save-button:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.cancel-button {
		background: #6b7280;
	}

	.cancel-button:hover {
		background: #4b5563;
		box-shadow: 0 4px 12px rgba(107, 114, 128, 0.4);
	}
</style>
