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
	let bookSearchQuery = '';
	let showBookDropdown = false;

	$: filteredBooks = existingBooks.filter(book => {
		if (!bookSearchQuery) return true;
		const q = bookSearchQuery.toLowerCase();
		return book.id.toLowerCase().includes(q) || 
			(book.book_number && book.book_number.toString().toLowerCase().includes(q));
	});

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
		showAddSingleVoucherForm = false;
	}

	function handleAddSingleVoucher() {
		showAddSingleVoucherForm = true;
		showAddBookForm = false;
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
				.order('created_at', { ascending: false });
			if (!error) {
				existingBooks = data || [];
			}
		} catch (error) {
			console.error('Error loading existing books:', error);
		}
	}

	function selectBook(book) {
		selectedExistingBook = book.id;
		bookSearchQuery = `${book.id} - Book ${book.book_number}`;
		showBookDropdown = false;
	}

	function handleBookSearchFocus() {
		showBookDropdown = true;
	}

	function handleBookSearchBlur() {
		// Delay to allow click on dropdown item
		setTimeout(() => { showBookDropdown = false; }, 200);
	}

	function clearBookSelection() {
		selectedExistingBook = '';
		bookSearchQuery = '';
		showBookDropdown = true;
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
				if (pvError.code === '23505' || pvError.message?.includes('duplicate')) {
					alert(`Error: Purchase Voucher "${pvId}" already exists!\n\nPlease use a different book number.`);
				} else {
					alert(`Error creating book: ${pvError.message}`);
				}
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
			bookSearchQuery = '';
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

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header Bar with Action Buttons -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">➕</span>
			<div>
				<h2 class="text-base font-black text-slate-800 uppercase tracking-wide">Add Purchase Vouchers</h2>
				<p class="text-[11px] text-slate-500">Create new voucher books or add individual vouchers</p>
			</div>
		</div>

		<!-- Action Buttons -->
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden {!showAddBookForm && !showAddSingleVoucherForm ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200 hover:bg-indigo-700 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={handleAddBook}
			>
				<span class="text-base filter drop-shadow-sm">📖</span>
				<span>Add Book</span>
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden {!showAddBookForm && !showAddSingleVoucherForm ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={handleAddSingleVoucher}
			>
				<span class="text-base filter drop-shadow-sm">🎫</span>
				<span>Add Single Voucher</span>
			</button>
		</div>
	</div>

	<!-- Main Content -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-cyan-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-2xl mx-auto">

			<!-- Add Book Form -->
			{#if showAddBookForm}
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
					<h3 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
						<span class="w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center text-xl">📖</span>
						Create New Voucher Book
					</h3>

					<div class="space-y-5">
						<!-- Book Number -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-bookNumber">Book Number</label>
							<input
								id="apv-bookNumber"
								type="text"
								placeholder="Enter book number (e.g., 001)"
								bind:value={bookNumber}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
							/>
						</div>

						<!-- Serial Range -->
						<div class="grid grid-cols-2 gap-4">
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-serialStart">Serial Start</label>
								<input
									id="apv-serialStart"
									type="number"
									placeholder="Start serial"
									bind:value={serialStart}
									on:input={handleSerialChange}
									class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
								/>
							</div>
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-serialEnd">Serial End</label>
								<input
									id="apv-serialEnd"
									type="number"
									placeholder="End serial"
									bind:value={serialEnd}
									on:input={handleSerialChange}
									class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
								/>
							</div>
						</div>

						<!-- Voucher Count (readonly) -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-voucherCount">Voucher Count</label>
							<input
								id="apv-voucherCount"
								type="number"
								value={voucherCount}
								readonly
								class="w-full px-4 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-600 cursor-not-allowed"
							/>
						</div>

						<!-- Per Voucher Value -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-perVoucherValue">Per Voucher Value</label>
							<input
								id="apv-perVoucherValue"
								type="number"
								placeholder="Enter per voucher value"
								bind:value={perVoucherValue}
								on:input={handlePerVoucherValueChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
							/>
						</div>

						<!-- Total Value (readonly) -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-totalValue">Total Value</label>
							<input
								id="apv-totalValue"
								type="number"
								value={totalValue.toFixed(2)}
								readonly
								class="w-full px-4 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-600 cursor-not-allowed font-bold"
							/>
						</div>

						<!-- Action Buttons -->
						<div class="flex gap-3 pt-4">
							<button
								class="flex-1 px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-lg shadow-indigo-200"
								on:click={handleSaveBook}
								disabled={isLoading}
							>
								{isLoading ? '💫 Saving...' : '💾 Save Book'}
							</button>
							<button
								class="flex-1 px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
								on:click={() => { showAddBookForm = false; bookNumber = ''; serialStart = ''; serialEnd = ''; perVoucherValue = ''; }}
							>
								Cancel
							</button>
						</div>
					</div>
				</div>
			{/if}

			<!-- Add Single Voucher Form -->
			{#if showAddSingleVoucherForm}
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
					<h3 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
						<span class="w-10 h-10 rounded-lg bg-emerald-100 flex items-center justify-center text-xl">🎫</span>
						Add Single Voucher
					</h3>

					<div class="space-y-5">
						<!-- Mode Selection -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-3 uppercase tracking-wide">Mode</label>
							<div class="flex gap-4">
								<label class="flex items-center gap-2 cursor-pointer">
									<input
										type="radio"
										name="singleVoucherMode"
										value="new"
										bind:group={singleVoucherMode}
										class="w-4 h-4 cursor-pointer rounded accent-emerald-500"
									/>
									<span class="text-sm font-medium text-slate-700">Add as New Book</span>
								</label>
								<label class="flex items-center gap-2 cursor-pointer">
									<input
										type="radio"
										name="singleVoucherMode"
										value="existing"
										bind:group={singleVoucherMode}
										class="w-4 h-4 cursor-pointer rounded accent-emerald-500"
									/>
									<span class="text-sm font-medium text-slate-700">Add to Existing Book</span>
								</label>
							</div>
						</div>

						<!-- Conditional: Book Number (for new mode) -->
						{#if singleVoucherMode === 'new'}
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-singleBookNumber">Book Number</label>
								<input
									id="apv-singleBookNumber"
									type="text"
									placeholder="Enter book number"
									bind:value={bookNumber}
									class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
								/>
							</div>
						{:else}
							<!-- Searchable Dropdown (for existing mode) -->
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Select Book</label>
								<div class="relative">
									<input
										type="text"
										placeholder="Search voucher books..."
										bind:value={bookSearchQuery}
										on:focus={handleBookSearchFocus}
										on:blur={handleBookSearchBlur}
										class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
										autocomplete="off"
									/>
									{#if selectedExistingBook}
										<button
											class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-red-500 text-lg transition-colors"
											on:click={clearBookSelection}
											type="button"
										>
											&times;
										</button>
									{/if}
									{#if showBookDropdown && filteredBooks.length > 0}
										<div class="absolute top-full left-0 right-0 mt-1 max-h-48 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-lg z-50">
											{#each filteredBooks as book (book.id)}
												<button
													class="w-full px-4 py-2.5 text-left text-sm text-slate-700 hover:bg-emerald-50 border-b border-slate-100 last:border-b-0 transition-colors {selectedExistingBook === book.id ? 'bg-emerald-100 font-semibold text-emerald-800' : ''}"
													on:mousedown|preventDefault={() => selectBook(book)}
													type="button"
												>
													{book.id} <span class="text-slate-500">— Book {book.book_number}</span>
												</button>
											{/each}
										</div>
									{:else if showBookDropdown && filteredBooks.length === 0}
										<div class="absolute top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-lg z-50 p-3 text-center text-sm text-slate-500">
											No books found
										</div>
									{/if}
								</div>
							</div>
						{/if}

						<!-- Serial Number -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-serialNumber">Serial Number</label>
							<input
								id="apv-serialNumber"
								type="number"
								placeholder="Enter serial number"
								bind:value={serialNumber}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>

						<!-- Voucher Value -->
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="apv-singleVoucherValue">Per Voucher Value</label>
							<input
								id="apv-singleVoucherValue"
								type="number"
								placeholder="Enter voucher value"
								bind:value={singleVoucherValue}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>

						<!-- Action Buttons -->
						<div class="flex gap-3 pt-4">
							<button
								class="flex-1 px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-lg shadow-emerald-200"
								on:click={handleSaveSingleVoucher}
								disabled={isLoading}
							>
								{isLoading ? '💫 Saving...' : '💾 Save Voucher'}
							</button>
							<button
								class="flex-1 px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
								on:click={() => { showAddSingleVoucherForm = false; bookNumber = ''; serialNumber = ''; singleVoucherValue = ''; selectedExistingBook = ''; bookSearchQuery = ''; singleVoucherMode = 'new'; }}
							>
								Cancel
							</button>
						</div>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}
</style>
