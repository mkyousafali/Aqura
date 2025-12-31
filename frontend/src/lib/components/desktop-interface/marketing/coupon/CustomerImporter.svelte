<script lang="ts">
	import { onMount } from 'svelte';
	import { get } from 'svelte/store';
	import { t } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { getAllCampaigns, importCustomers, getEligibleCustomers, deleteEligibleCustomer } from '$lib/services/couponService';
	import type { CouponCampaign } from '$lib/types/coupon';

	// Props
	let { campaignId = null, onClose = null }: { campaignId?: string | null; onClose?: (() => void) | null } = $props();

	// State
	let loading = $state(false);
	let campaigns: CouponCampaign[] = $state([]);
	let selectedCampaignId = $state(campaignId || '');
	let mobileNumbers: string[] = $state([]);
	let validNumbers: string[] = $state([]);
	let invalidNumbers: string[] = $state([]);
	let duplicateNumbers: string[] = $state([]);
	let fileInput: HTMLInputElement | null = $state(null);
	let isDragging = $state(false);
	let showPreview = $state(false);
	let importing = $state(false);
	let importedCustomers: any[] = $state([]);
	let loadingImported = $state(false);
	let showAddNumberModal = $state(false);
	let newNumber = $state('');
	let deletingCustomerId: string | null = $state(null);

	// Reactive current user - subscribe to store changes
	let currentUserData = $state(null);
	
	// Load campaigns on mount
	onMount(async () => {
		// Subscribe to currentUser store
		const unsubscribe = currentUser.subscribe(value => {
			currentUserData = value;
			console.log('🔐 [CustomerImporter] Current user updated:', value);
			console.log('🔐 [CustomerImporter] Role type:', value?.roleType);
		});
		
		await loadCampaigns();
		
		return unsubscribe;
	});

	async function loadCampaigns() {
		loading = true;
		try {
			campaigns = await getAllCampaigns();
		} catch (error) {
			notifications.add({
				message: t('coupon.errorLoadingCampaigns'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Load imported customers for selected campaign
	async function loadImportedCustomers() {
		if (!selectedCampaignId) {
			importedCustomers = [];
			return;
		}

		loadingImported = true;
		try {
			const customers = await getEligibleCustomers(selectedCampaignId);
			importedCustomers = customers;
		} catch (error) {
			console.error('Error loading imported customers:', error);
			importedCustomers = [];
		} finally {
			loadingImported = false;
		}
	}

	// Saudi mobile number validation
	function isValidSaudiMobile(mobile: string): boolean {
		// Remove spaces, dashes, and parentheses
		const cleaned = mobile.replace(/[\s\-()]/g, '');
		
		// Saudi format: 
		// - 05XXXXXXXX (10 digits, starts with 05) - MOST COMMON
		// - 5XXXXXXXX (9 digits, starts with 5)
		// - +9665XXXXXXXX (with country code)
		// - 9665XXXXXXXX (without + sign)
		const patterns = [
			/^05\d{8}$/,         // 05XXXXXXXX (10 digits) - PRIMARY FORMAT
			/^5\d{8}$/,          // 5XXXXXXXX (9 digits)
			/^\+9665\d{8}$/,     // +9665XXXXXXXX
			/^9665\d{8}$/        // 9665XXXXXXXX
		];
		
		return patterns.some(pattern => pattern.test(cleaned));
	}

	// Normalize mobile number to standard 05XXXXXXXX format
	function normalizeMobile(mobile: string): string {
		const cleaned = mobile.replace(/[\s\-()]/g, '');
		
		// If already in 05XXXXXXXX format, return as is
		if (/^05\d{8}$/.test(cleaned)) {
			return cleaned;
		}
		
		// If starts with +966, convert to 05XXXXXXXX
		if (cleaned.startsWith('+9665')) {
			return '0' + cleaned.substring(4);
		}
		
		// If starts with 966, convert to 05XXXXXXXX
		if (cleaned.startsWith('9665')) {
			return '0' + cleaned.substring(3);
		}
		
		// If starts with 5 (9 digits), add 0
		if (/^5\d{8}$/.test(cleaned)) {
			return '0' + cleaned;
		}
		
		return cleaned;
	}

	// Handle file selection
	function handleFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		if (target.files && target.files[0]) {
			processFile(target.files[0]);
		}
	}

	// Handle drag and drop
	function handleDrop(event: DragEvent) {
		event.preventDefault();
		isDragging = false;
		
		if (event.dataTransfer?.files && event.dataTransfer.files[0]) {
			processFile(event.dataTransfer.files[0]);
		}
	}

	function handleDragOver(event: DragEvent) {
		event.preventDefault();
		isDragging = true;
	}

	function handleDragLeave() {
		isDragging = false;
	}

	// Process uploaded file
	async function processFile(file: File) {
		if (!file.name.endsWith('.csv') && !file.name.endsWith('.txt') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
			notifications.add({
				message: t('coupon.invalidFileFormat'),
				type: 'error'
			});
			return;
		}

		loading = true;
		try {
			const text = await file.text();
			const lines = text.split(/\r?\n/).filter(line => line.trim());
			
			// Extract mobile numbers from each line
			const numbers = lines.map(line => {
				// Try to extract mobile number from CSV or plain text
				const match = line.match(/[+]?[0-9]{9,13}/);
				return match ? match[0] : line.trim();
			}).filter(n => n);

			validateNumbers(numbers);
			showPreview = true;
		} catch (error) {
			notifications.add({
				message: t('coupon.errorReadingFile'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Validate mobile numbers
	function validateNumbers(numbers: string[]) {
		const valid: string[] = [];
		const invalid: string[] = [];
		const seen = new Set<string>();
		const duplicates: string[] = [];

		numbers.forEach(num => {
			const normalized = normalizeMobile(num);
			
			if (!isValidSaudiMobile(num)) {
				invalid.push(num);
			} else if (seen.has(normalized)) {
				duplicates.push(num);
			} else {
				seen.add(normalized);
				valid.push(normalized);
			}
		});

		validNumbers = valid;
		invalidNumbers = invalid;
		duplicateNumbers = duplicates;
		mobileNumbers = valid;
	}

	// Handle manual input
	function handleManualInput(event: Event) {
		const textarea = event.target as HTMLTextAreaElement;
		const text = textarea.value;
		const lines = text.split(/\r?\n/).filter(line => line.trim());
		
		validateNumbers(lines);
		showPreview = true;
	}

	// Add single number manually
	async function handleAddNumber() {
		if (!selectedCampaignId) {
			notifications.add({
				message: t('coupon.selectCampaignFirst'),
				type: 'error'
			});
			return;
		}

		if (!newNumber.trim()) {
			notifications.add({
				message: t('coupon.enterMobileNumber'),
				type: 'error'
			});
			return;
		}

		if (!isValidSaudiMobile(newNumber)) {
			notifications.add({
				message: t('coupon.invalidMobileNumber'),
				type: 'error'
			});
			return;
		}

		const normalized = normalizeMobile(newNumber);
		
		try {
			const batchId = crypto.randomUUID();
			const userId = get(currentUser)?.id || null;
			
			await importCustomers(selectedCampaignId, [normalized], batchId, userId);
			
			notifications.add({
				message: t('coupon.customerAdded'),
				type: 'success'
			});

			newNumber = '';
			showAddNumberModal = false;
			await loadImportedCustomers();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorAddingCustomer'),
				type: 'error'
			});
		}
	}

	// Delete customer from campaign
	async function handleDeleteCustomer(customerId: string) {
		if (!get(currentUser)?.isMasterAdmin) {
			notifications.add({
				message: t('coupon.notAuthorized'),
				type: 'error'
			});
			return;
		}

		deletingCustomerId = customerId;
		try {
			await deleteEligibleCustomer(customerId);
			
			notifications.add({
				message: t('coupon.customerDeleted'),
				type: 'success'
			});

			await loadImportedCustomers();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorDeletingCustomer'),
				type: 'error'
			});
		} finally {
			deletingCustomerId = null;
		}
	}

	// Import customers
	async function handleImport() {
		if (!selectedCampaignId) {
			notifications.add({
				message: t('coupon.selectCampaignFirst'),
				type: 'error'
			});
			return;
		}

		if (validNumbers.length === 0) {
			notifications.add({
				message: t('coupon.noValidNumbers'),
				type: 'error'
			});
			return;
		}

		importing = true;
		try {
			// Generate UUID for batch
			const batchId = crypto.randomUUID();
			const userId = get(currentUser)?.id || null;
			
			await importCustomers(selectedCampaignId, validNumbers, batchId, userId);
			
			notifications.add({
				message: t('coupon.customersImported', { count: validNumbers.length }),
				type: 'success'
			});

			// Reset form and reload imported customers
			reset();
			await loadImportedCustomers();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorImportingCustomers'),
				type: 'error'
			});
		} finally {
			importing = false;
		}
	}

	// Reset form
	function reset() {
		mobileNumbers = [];
		validNumbers = [];
		invalidNumbers = [];
		duplicateNumbers = [];
		showPreview = false;
		if (fileInput) fileInput.value = '';
	}

	// Download template
	function downloadTemplate() {
		// Add header and format numbers with leading apostrophe to preserve leading zeros in Excel
		const csv = 'mobile_number\n\'0548357066\n\'0509876543\n\'0512345678\n\'0556789012';
		const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = 'customer_mobile_template.csv';
		a.click();
		URL.revokeObjectURL(url);
	}
</script>

<div class="flex flex-col w-full h-screen bg-gradient-to-br from-gray-50 to-gray-100 overflow-hidden">
	<!-- Header -->
	<div class="bg-white border-b border-gray-200 px-8 py-6 shadow-sm flex-shrink-0">
		<div class="flex items-center justify-between gap-6 w-full">
			<div class="bg-gradient-to-br from-red-50 to-orange-50 border-l-4 border-orange-500 px-6 py-4 rounded-xl flex-1 min-w-0">
				<h1 class="text-3xl font-bold text-gray-900">{t('coupon.importCustomers')}</h1>
				<p class="text-sm text-gray-600 mt-2 font-medium">{t('coupon.customerImportDescription')}</p>
			</div>
			<button
				onclick={downloadTemplate}
				class="px-6 py-3 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-300 flex items-center gap-2 whitespace-nowrap font-semibold flex-shrink-0"
			>
				<span class="text-xl">⬇️</span>
				{t('coupon.downloadTemplate')}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-hidden p-8 w-full">
		<div class="w-full h-full flex flex-col">
			<!-- Campaign Selection -->
			<div class="mb-8 flex-shrink-0">
				<label class="block text-sm font-bold text-gray-700 mb-3 uppercase tracking-wider">
					📋 {t('coupon.selectCampaign')} *
				</label>
				<select
					bind:value={selectedCampaignId}
					disabled={loading}
					onchange={loadImportedCustomers}
					class="w-full max-w-2xl px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent disabled:opacity-50 font-medium text-gray-700 bg-white shadow-sm hover:shadow-md transition-shadow"
				>
					<option value="">{t('coupon.chooseCampaign')}</option>
					{#each campaigns as campaign}
						<option value={campaign.id}>
							{campaign.name_en} ({campaign.campaign_code})
						</option>
					{/each}
				</select>
			</div>

			<!-- Two Horizontal Sections -->
			<div class="flex-1 grid grid-cols-3 gap-8 min-w-0 w-full overflow-hidden">
				<!-- Section 1: Import Section (Takes 2 columns) -->
				<div class="col-span-2 space-y-8 overflow-y-auto pr-4 min-w-0">
					<!-- File Upload -->
					<div class="flex-shrink-0">
						<label class="block text-sm font-bold text-gray-700 mb-3 uppercase tracking-wider">
							📄 {t('coupon.uploadFile')}
						</label>
						<div
							class="border-2 border-dashed rounded-2xl p-12 text-center transition-all duration-300 w-full {isDragging ? 'border-orange-500 bg-orange-50 scale-105' : 'border-gray-300 hover:border-orange-400 hover:bg-orange-50 bg-white'}"
							ondrop={handleDrop}
							ondragover={handleDragOver}
							ondragleave={handleDragLeave}
						>
							<div class="text-7xl mb-6 animate-bounce">{isDragging ? '✨' : '📁'}</div>
							<p class="text-xl font-bold text-gray-900 mb-2">
								{isDragging ? 'Drop your file here!' : t('coupon.dragDropFile')}
							</p>
							<p class="text-sm text-gray-600 mb-6 font-medium">
								{t('coupon.supportedFormats')}: CSV, TXT, XLS, XLSX
							</p>
							<input
								type="file"
								bind:this={fileInput}
								onchange={handleFileSelect}
								accept=".csv,.txt,.xls,.xlsx"
								class="hidden"
							/>
							<button
								onclick={() => fileInput?.click()}
								class="px-8 py-3 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-300 font-semibold"
							>
								📤 {t('coupon.browseFiles')}
							</button>
						</div>
					</div>

					<!-- Manual Input -->
					<div class="flex-shrink-0">
						<label class="block text-sm font-bold text-gray-700 mb-3 uppercase tracking-wider">
							✍️ {t('coupon.manualEntry')}
						</label>
						<textarea
							onchange={handleManualInput}
							rows="8"
							class="w-full px-5 py-4 border border-gray-300 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent resize-none font-mono text-sm shadow-sm hover:shadow-md transition-shadow bg-white"
							placeholder="0548357066&#10;0509876543&#10;0512345678"
						></textarea>
						<p class="text-xs text-gray-500 mt-3 font-medium">
							💡 {t('coupon.oneNumberPerLine')}
						</p>
					</div>

					<!-- Preview -->
					{#if showPreview}
						<div class="animate-in fade-in-50 duration-500 flex-shrink-0">
							<label class="block text-sm font-bold text-gray-700 mb-3 uppercase tracking-wider">
								✅ {t('coupon.importPreview')}
							</label>
							
							<!-- Summary -->
							<div class="grid grid-cols-3 gap-4 mb-6">
								<div class="bg-gradient-to-br from-green-50 to-green-100 border-2 border-green-300 rounded-xl p-6 hover:shadow-lg transition-shadow">
									<div class="text-4xl font-bold text-green-700">{validNumbers.length}</div>
									<div class="text-sm text-green-700 font-semibold mt-2">✔️ {t('coupon.validNumbers')}</div>
								</div>
								<div class="bg-gradient-to-br from-red-50 to-red-100 border-2 border-red-300 rounded-xl p-6 hover:shadow-lg transition-shadow">
									<div class="text-4xl font-bold text-red-700">{invalidNumbers.length}</div>
									<div class="text-sm text-red-700 font-semibold mt-2">❌ {t('coupon.invalidNumbers')}</div>
								</div>
								<div class="bg-gradient-to-br from-yellow-50 to-yellow-100 border-2 border-yellow-300 rounded-xl p-6 hover:shadow-lg transition-shadow">
									<div class="text-4xl font-bold text-yellow-700">{duplicateNumbers.length}</div>
									<div class="text-sm text-yellow-700 font-semibold mt-2">⚠️ {t('coupon.duplicateNumbers')}</div>
								</div>
							</div>

							<!-- Invalid Numbers List -->
							{#if invalidNumbers.length > 0}
								<div class="mb-6">
									<h4 class="font-bold text-red-700 mb-3 text-sm">❌ {t('coupon.invalidNumbersList')}:</h4>
									<div class="bg-red-50 border-2 border-red-200 rounded-xl p-4 max-h-40 overflow-auto">
										<div class="text-sm text-red-700 font-mono space-y-2">
											{#each invalidNumbers as num}
												<div class="flex items-center gap-2">
													<span class="text-red-500">•</span>
													<span>{num}</span>
												</div>
											{/each}
										</div>
									</div>
								</div>
							{/if}

							<!-- Duplicate Numbers List -->
							{#if duplicateNumbers.length > 0}
								<div class="mb-6">
									<h4 class="font-bold text-yellow-700 mb-3 text-sm">⚠️ {t('coupon.duplicateNumbersList')}:</h4>
									<div class="bg-yellow-50 border-2 border-yellow-200 rounded-xl p-4 max-h-40 overflow-auto">
										<div class="text-sm text-yellow-700 font-mono space-y-2">
											{#each duplicateNumbers as num}
												<div class="flex items-center gap-2">
													<span class="text-yellow-500">•</span>
													<span>{num}</span>
												</div>
											{/each}
										</div>
									</div>
								</div>
							{/if}

							<!-- Actions -->
							<div class="flex gap-4 pt-4 border-t border-gray-200">
								<button
									onclick={handleImport}
									disabled={importing || validNumbers.length === 0 || !selectedCampaignId}
									class="flex-1 px-6 py-3 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-xl hover:shadow-lg hover:scale-105 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed font-bold"
								>
									{importing ? '⏳ ' + t('coupon.importing') : '🚀 ' + t('coupon.importCustomers')} ({validNumbers.length})
								</button>
								<button
									onclick={reset}
									disabled={importing}
									class="px-6 py-3 bg-gray-200 text-gray-700 rounded-xl hover:bg-gray-300 transition-all duration-300 disabled:opacity-50 font-semibold"
								>
									↻ {t('coupon.reset')}
								</button>
							</div>
						</div>
					{/if}
				</div>

				<!-- Section 2: Imported Customers List -->
				<div class="col-span-1 flex flex-col min-w-0 w-full overflow-hidden h-full">
					<div class="flex items-center justify-between gap-3 mb-3 flex-shrink-0">
						<label class="block text-sm font-bold text-gray-700 uppercase tracking-wider flex-1">
							📊 {t('coupon.importedCustomers')}
						</label>
						<button
							onclick={() => showAddNumberModal = true}
							disabled={!selectedCampaignId}
							class="px-3 py-2 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-lg hover:shadow-lg transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed font-bold text-lg leading-none"
							title="Add number manually"
						>
							+
						</button>
					</div>
					<div class="bg-white rounded-2xl shadow-md hover:shadow-lg transition-shadow p-6 flex-1 flex flex-col overflow-y-auto min-w-0">
						{#if !selectedCampaignId}
							<div class="text-center py-12 text-gray-500 flex-1 flex items-center justify-center">
								<div>
									<div class="text-4xl mb-3">🎯</div>
									<p class="text-sm font-medium">{t('coupon.selectCampaignToView')}</p>
								</div>
							</div>
						{:else if loadingImported}
							<div class="text-center py-12 flex-1 flex items-center justify-center">
								<div>
									<div class="inline-block animate-spin text-4xl mb-3">⏳</div>
									<p class="text-sm text-gray-600 font-medium">{t('coupon.loading')}</p>
								</div>
							</div>
						{:else if importedCustomers.length === 0}
							<div class="text-center py-12 text-gray-500 flex-1 flex items-center justify-center">
								<div>
									<div class="text-4xl mb-3">📭</div>
									<p class="text-sm font-medium">{t('coupon.noCustomersImported')}</p>
								</div>
							</div>
						{:else}
							<div class="flex-1 flex flex-col overflow-hidden min-w-0">
								<div class="bg-gradient-to-r from-blue-50 to-blue-100 border-2 border-blue-300 rounded-xl p-4 mb-4 flex-shrink-0">
									<p class="text-sm font-bold text-blue-700">
										✔️ {t('coupon.totalImported')}: <span class="text-lg">{importedCustomers.length}</span>
									</p>
								</div>
								<div class="flex-1 overflow-y-auto space-y-2 pr-2 min-w-0">
									{#each importedCustomers as customer, idx}
										<div class="flex items-center gap-3 p-2 rounded-lg hover:bg-orange-50 transition-colors duration-300 flex-shrink-0 {idx % 2 === 0 ? 'bg-gray-50' : 'bg-white'} min-w-0 group">
										<span class="text-sm font-bold text-orange-500 flex-shrink-0">✔️</span>
										<span class="font-mono text-xs text-gray-700 flex-1 truncate">{customer.mobile_number || customer.phone || 'N/A'}</span>
										{#if currentUserData?.isMasterAdmin}
											<button
												onclick={() => handleDeleteCustomer(customer.id)}
													disabled={deletingCustomerId === customer.id}
													class="text-xs text-red-500 hover:text-red-700 hover:bg-red-100 px-2 py-1 rounded transition-all duration-300 disabled:opacity-50 flex-shrink-0 font-semibold"
													title="Delete customer"
												>
													{deletingCustomerId === customer.id ? '⏳' : '✕'}
											</button>
										{:else}
											<span class="text-xs text-gray-400 flex-shrink-0">{currentUserData?.isMasterAdmin ? 'Master Admin' : currentUserData?.isAdmin ? 'Admin' : 'User'}</span>
										{/if}
										<span class="text-xs text-gray-400 font-semibold flex-shrink-0">{idx + 1}</span>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<!-- Add Number Modal -->
{#if showAddNumberModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
		<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 animate-in fade-in zoom-in duration-300">
			<h3 class="text-2xl font-bold text-gray-900 mb-6">➕ {t('coupon.addCustomer')}</h3>
			
			<div class="space-y-4 mb-6">
				<div>
					<label class="block text-sm font-bold text-gray-700 mb-2">📱 {t('coupon.mobileNumber')} *</label>
					<input
						type="text"
						bind:value={newNumber}
						placeholder="05XXXXXXXX"
						class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent font-mono text-sm"
						onkeydown={(e) => e.key === 'Enter' && handleAddNumber()}
					/>
					<p class="text-xs text-gray-500 mt-2 font-medium">
						💡 {t('coupon.saudiFormatExample')}: 05XXXXXXXX
					</p>
				</div>
			</div>

			<div class="flex gap-3">
				<button
					onclick={handleAddNumber}
					class="flex-1 px-6 py-3 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-xl hover:shadow-lg transition-all duration-300 font-bold"
				>
					✅ {t('coupon.add')}
				</button>
				<button
					onclick={() => {
						showAddNumberModal = false;
						newNumber = '';
					}}
					class="flex-1 px-6 py-3 bg-gray-200 text-gray-700 rounded-xl hover:bg-gray-300 transition-all duration-300 font-semibold"
				>
					✕ {t('coupon.cancel')}
				</button>
			</div>
		</div>
	</div>
{/if}
