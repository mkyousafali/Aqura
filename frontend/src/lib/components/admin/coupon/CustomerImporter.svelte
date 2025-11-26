<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { getAllCampaigns, importCustomers } from '$lib/services/couponService';
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

	// Load campaigns on mount
	onMount(async () => {
		await loadCampaigns();
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
			const userId = $currentUser?.id || null;
			
			await importCustomers(selectedCampaignId, validNumbers, batchId, userId);
			
			notifications.add({
				message: t('coupon.customersImported', { count: validNumbers.length }),
				type: 'success'
			});

			// Reset form
			reset();
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

<div class="flex flex-col h-full bg-gray-50">
	<!-- Header -->
	<div class="bg-white border-b border-gray-200 px-6 py-4">
		<div class="flex items-center justify-between">
			<div>
				<h2 class="text-2xl font-bold text-gray-900">{t('coupon.importCustomers')}</h2>
				<p class="text-sm text-gray-600 mt-1">{t('coupon.customerImportDescription')}</p>
			</div>
			<button
				onclick={downloadTemplate}
				class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors flex items-center gap-2"
			>
				<span class="text-xl">📥</span>
				{t('coupon.downloadTemplate')}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-auto p-6">
		<div class="max-w-4xl mx-auto space-y-6">
			<!-- Campaign Selection -->
			<div class="bg-white rounded-lg shadow-sm p-6">
				<label class="block text-sm font-medium text-gray-700 mb-2">
					{t('coupon.selectCampaign')} *
				</label>
				<select
					bind:value={selectedCampaignId}
					disabled={loading}
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
				>
					<option value="">{t('coupon.chooseCampaign')}</option>
					{#each campaigns as campaign}
						<option value={campaign.id}>
							{campaign.name_en} ({campaign.campaign_code})
						</option>
					{/each}
				</select>
			</div>

			<!-- File Upload -->
			<div class="bg-white rounded-lg shadow-sm p-6">
				<h3 class="text-lg font-semibold mb-4">{t('coupon.uploadFile')}</h3>
				
				<div
					class="border-2 border-dashed rounded-lg p-8 text-center transition-colors {isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-blue-400'}"
					ondrop={handleDrop}
					ondragover={handleDragOver}
					ondragleave={handleDragLeave}
				>
					<div class="text-6xl mb-4">📄</div>
					<p class="text-lg font-medium text-gray-700 mb-2">
						{t('coupon.dragDropFile')}
					</p>
					<p class="text-sm text-gray-500 mb-4">
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
						class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
					>
						{t('coupon.browseFiles')}
					</button>
				</div>
			</div>

			<!-- Manual Input -->
			<div class="bg-white rounded-lg shadow-sm p-6">
				<h3 class="text-lg font-semibold mb-4">{t('coupon.manualEntry')}</h3>
				<textarea
					onchange={handleManualInput}
					rows="6"
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none font-mono text-sm"
					placeholder="0548357066&#10;0509876543&#10;0512345678"
				></textarea>
				<p class="text-xs text-gray-500 mt-2">
					{t('coupon.oneNumberPerLine')}
				</p>
			</div>

			<!-- Preview -->
			{#if showPreview}
				<div class="bg-white rounded-lg shadow-sm p-6">
					<h3 class="text-lg font-semibold mb-4">{t('coupon.importPreview')}</h3>
					
					<!-- Summary -->
					<div class="grid grid-cols-3 gap-4 mb-6">
						<div class="bg-green-50 border border-green-200 rounded-lg p-4">
							<div class="text-3xl font-bold text-green-700">{validNumbers.length}</div>
							<div class="text-sm text-green-600">{t('coupon.validNumbers')}</div>
						</div>
						<div class="bg-red-50 border border-red-200 rounded-lg p-4">
							<div class="text-3xl font-bold text-red-700">{invalidNumbers.length}</div>
							<div class="text-sm text-red-600">{t('coupon.invalidNumbers')}</div>
						</div>
						<div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
							<div class="text-3xl font-bold text-yellow-700">{duplicateNumbers.length}</div>
							<div class="text-sm text-yellow-600">{t('coupon.duplicateNumbers')}</div>
						</div>
					</div>

					<!-- Invalid Numbers List -->
					{#if invalidNumbers.length > 0}
						<div class="mb-4">
							<h4 class="font-medium text-red-700 mb-2">{t('coupon.invalidNumbersList')}:</h4>
							<div class="bg-red-50 border border-red-200 rounded p-3 max-h-32 overflow-auto">
								<div class="text-sm text-red-600 font-mono space-y-1">
									{#each invalidNumbers as num}
										<div>{num}</div>
									{/each}
								</div>
							</div>
						</div>
					{/if}

					<!-- Duplicate Numbers List -->
					{#if duplicateNumbers.length > 0}
						<div class="mb-4">
							<h4 class="font-medium text-yellow-700 mb-2">{t('coupon.duplicateNumbersList')}:</h4>
							<div class="bg-yellow-50 border border-yellow-200 rounded p-3 max-h-32 overflow-auto">
								<div class="text-sm text-yellow-600 font-mono space-y-1">
									{#each duplicateNumbers as num}
										<div>{num}</div>
									{/each}
								</div>
							</div>
						</div>
					{/if}

					<!-- Actions -->
					<div class="flex gap-3 pt-4 border-t">
						<button
							onclick={handleImport}
							disabled={importing || validNumbers.length === 0 || !selectedCampaignId}
							class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{importing ? t('coupon.importing') : t('coupon.importCustomers')} ({validNumbers.length})
						</button>
						<button
							onclick={reset}
							disabled={importing}
							class="px-6 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors disabled:opacity-50"
						>
							{t('coupon.reset')}
						</button>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>
