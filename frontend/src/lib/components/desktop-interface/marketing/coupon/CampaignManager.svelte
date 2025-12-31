<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';
	import { 
		getAllCampaigns, 
		createCampaign, 
		updateCampaign, 
		toggleCampaignStatus,
		deleteCampaign 
	} from '$lib/services/couponService';
	import type { CouponCampaign } from '$lib/types/coupon';

	// Props (optional)
	let { campaignId = null, onClose = null }: { campaignId?: string | null; onClose?: (() => void) | null } = $props();

	// State
	let loading = $state(false);
	let campaigns: CouponCampaign[] = $state([]);
	let showForm = $state(false);
	let editingCampaign: CouponCampaign | null = $state(null);

	// Form data
	let formData = $state({
		name_en: '',
		name_ar: '',
		campaign_code: '',
		start_date: '',
		end_date: '',
		terms_conditions_en: '',
		terms_conditions_ar: '',
		max_claims_per_customer: 1,
		is_active: true
	});

	// Date helpers for Saudi timezone (UTC+3)
	function toSaudiTimeInput(utcDateString: string | null): string {
		if (!utcDateString) return '';
		const date = new Date(utcDateString);
		const saudiTime = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
		const year = saudiTime.getFullYear();
		const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
		const day = String(saudiTime.getDate()).padStart(2, '0');
		const hours = String(saudiTime.getHours()).padStart(2, '0');
		const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
		return `${year}-${month}-${day}T${hours}:${minutes}`;
	}

	function toUTCFromSaudiInput(saudiTimeString: string): string {
		if (!saudiTimeString) return '';
		const [datePart, timePart] = saudiTimeString.split('T');
		const [year, month, day] = datePart.split('-').map(Number);
		const [hours, minutes] = timePart.split(':').map(Number);
		const saudiDate = new Date(year, month - 1, day, hours, minutes);
		const utcDate = new Date(saudiDate.getTime() - (3 * 60 * 60 * 1000));
		return utcDate.toISOString();
	}

	// Generate unique campaign code (6 characters: 2 uppercase letters + 4 numbers)
	function generateCode() {
		const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
		const numbers = '0123456789';
		
		// Generate 2 random letters
		let code = '';
		for (let i = 0; i < 2; i++) {
			code += letters.charAt(Math.floor(Math.random() * letters.length));
		}
		
		// Generate 4 random numbers
		for (let i = 0; i < 4; i++) {
			code += numbers.charAt(Math.floor(Math.random() * numbers.length));
		}
		
		formData.campaign_code = code;
	}

	// Load campaigns
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

	// Reset form
	function resetForm() {
		formData = {
			name_en: '',
			name_ar: '',
			campaign_code: '',
			start_date: '',
			end_date: '',
			terms_conditions_en: '',
			terms_conditions_ar: '',
			max_claims_per_customer: 1,
			is_active: true
		};
		editingCampaign = null;
	}

	// Open form for new campaign
	function openNewCampaignForm() {
		resetForm();
		generateCode();
		showForm = true;
	}

	// Open form for editing
	function openEditForm(campaign: CouponCampaign) {
		editingCampaign = campaign;
		formData = {
			name_en: campaign.name_en,
			name_ar: campaign.name_ar,
			campaign_code: campaign.campaign_code,
			start_date: campaign.start_date.split('T')[0],
			end_date: campaign.end_date.split('T')[0],
			terms_conditions_en: campaign.terms_conditions_en || '',
			terms_conditions_ar: campaign.terms_conditions_ar || '',
			max_claims_per_customer: campaign.max_claims_per_customer || 1,
			is_active: campaign.is_active
		};
		showForm = true;
	}

	// Cancel form
	function cancelForm() {
		showForm = false;
		resetForm();
	}

	// Save campaign
	async function saveCampaign() {
		// Validation
		if (!formData.name_en.trim() || !formData.name_ar.trim()) {
			notifications.add({
				message: t('coupon.campaignNameRequired'),
				type: 'error'
			});
			return;
		}

		if (!formData.campaign_code.trim()) {
			notifications.add({
				message: t('coupon.campaignCodeRequired'),
				type: 'error'
			});
			return;
		}

		if (!formData.start_date || !formData.end_date) {
			notifications.add({
				message: t('coupon.datesRequired'),
				type: 'error'
			});
			return;
		}

	loading = true;
	try {
		// Set start date to 00:00:00 in Saudi time (UTC+3)
		const startDate = new Date(formData.start_date + 'T00:00:00+03:00');
		// Set end date to 23:59:59 in Saudi time (UTC+3) so it expires at end of day
		const endDate = new Date(formData.end_date + 'T23:59:59+03:00');
		
		const payload = {
			name_en: formData.name_en.trim(),
			name_ar: formData.name_ar.trim(),
			campaign_code: formData.campaign_code.trim().toUpperCase(),
			start_date: startDate.toISOString(),
			end_date: endDate.toISOString(),
			terms_conditions_en: formData.terms_conditions_en.trim() || null,
			terms_conditions_ar: formData.terms_conditions_ar.trim() || null,
			max_claims_per_customer: formData.max_claims_per_customer,
			is_active: formData.is_active
		};			if (editingCampaign) {
				await updateCampaign(editingCampaign.id, payload);
				notifications.add({
					message: t('coupon.campaignUpdated'),
					type: 'success'
				});
			} else {
				await createCampaign(payload);
				notifications.add({
					message: t('coupon.campaignCreated'),
					type: 'success'
				});
			}

			showForm = false;
			resetForm();
			await loadCampaigns();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorSavingCampaign'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Toggle campaign status
	async function toggleStatus(campaign: CouponCampaign) {
		loading = true;
		try {
			await toggleCampaignStatus(campaign.id, !campaign.is_active);
			notifications.add({
				message: campaign.is_active ? t('coupon.campaignDeactivated') : t('coupon.campaignActivated'),
				type: 'success'
			});
			await loadCampaigns();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorTogglingStatus'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Delete campaign
	async function handleDelete(campaign: CouponCampaign) {
		if (!confirm(t('coupon.confirmDeleteCampaign'))) return;

		loading = true;
		try {
			await deleteCampaign(campaign.id);
			notifications.add({
				message: t('coupon.campaignDeleted'),
				type: 'success'
			});
			await loadCampaigns();
		} catch (error: any) {
			notifications.add({
				message: error.message || t('coupon.errorDeletingCampaign'),
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	// Get status badge color
	function getStatusColor(campaign: CouponCampaign): string {
		if (!campaign.is_active) return 'bg-gray-500';
		const now = new Date();
		const start = new Date(campaign.start_date);
		const end = new Date(campaign.end_date);
		if (now < start) return 'bg-yellow-500';
		if (now > end) return 'bg-red-500';
		return 'bg-green-500';
	}

	function getStatusText(campaign: CouponCampaign): string {
		if (!campaign.is_active) return t('coupon.statusInactive');
		const now = new Date();
		const start = new Date(campaign.start_date);
		const end = new Date(campaign.end_date);
		if (now < start) return t('coupon.statusScheduled');
		if (now > end) return t('coupon.statusExpired');
		return t('coupon.statusActive');
	}

	// Format date for display
	function formatDate(dateString: string): string {
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', { 
			year: 'numeric', 
			month: 'short', 
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	onMount(() => {
		loadCampaigns();
	});
</script>

<div class="flex flex-col h-full bg-gray-50">
	<!-- Header -->
	<div class="bg-white border-b border-gray-200 px-6 py-4">
		<div class="flex items-center justify-between">
			<div>
				<h2 class="text-2xl font-bold text-gray-900">{t('coupon.manageCampaigns')}</h2>
				<p class="text-sm text-gray-600 mt-1">{t('coupon.campaignDescription')}</p>
			</div>
			<button
				onclick={openNewCampaignForm}
				disabled={loading}
				class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
			>
				<span class="text-xl">➕</span>
				{t('coupon.createCampaign')}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-auto p-6">
		{#if showForm}
			<!-- Campaign Form -->
			<div class="bg-white rounded-lg shadow-sm p-6 max-w-4xl mx-auto">
				<h3 class="text-xl font-semibold mb-6">
					{editingCampaign ? t('coupon.editCampaign') : t('coupon.createCampaign')}
				</h3>

				<div class="space-y-6">
				<!-- Campaign Names -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.nameEnglish')} *
						</label>
						<input
							type="text"
							bind:value={formData.name_en}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							placeholder="Summer Sale 2025"
						/>
					</div>
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.nameArabic')} *
						</label>
						<input
							type="text"
							bind:value={formData.name_ar}
							dir="rtl"
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							placeholder="تخفيضات الصيف ٢٠٢٥"
						/>
					</div>
				</div>					<!-- Campaign Code -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.campaignCode')} *
						</label>
						<div class="flex gap-2">
							<input
								type="text"
								bind:value={formData.campaign_code}
								class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent uppercase"
								placeholder="AB1234"
								maxlength="6"
							/>
							<button
								type="button"
								onclick={generateCode}
								class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
							>
								🔄 {t('coupon.generate')}
							</button>
						</div>
					</div>

				<!-- Dates -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.startDate')} *
						</label>
						<input
							type="date"
							bind:value={formData.start_date}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
					</div>
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.endDate')} *
						</label>
						<input
							type="date"
							bind:value={formData.end_date}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
					</div>
				</div>					<!-- Max Claims -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">
							{t('coupon.maxClaimsPerCustomer')}
						</label>
						<input
							type="number"
							bind:value={formData.max_claims_per_customer}
							min="1"
							max="100"
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
					</div>

					<!-- Terms & Conditions -->
					<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
						<div>
							<label class="block text-sm font-medium text-gray-700 mb-2">
								{t('coupon.termsEnglish')}
							</label>
							<textarea
								bind:value={formData.terms_conditions_en}
								rows="4"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
								placeholder="Enter terms and conditions..."
							></textarea>
						</div>
						<div>
							<label class="block text-sm font-medium text-gray-700 mb-2">
								{t('coupon.termsArabic')}
							</label>
							<textarea
								bind:value={formData.terms_conditions_ar}
								dir="rtl"
								rows="4"
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
								placeholder="أدخل الشروط والأحكام..."
							></textarea>
						</div>
					</div>

					<!-- Active Status -->
					<div class="flex items-center gap-3">
						<input
							type="checkbox"
							id="is_active"
							bind:checked={formData.is_active}
							class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
						/>
						<label for="is_active" class="text-sm font-medium text-gray-700">
							{t('coupon.campaignActive')}
						</label>
					</div>

					<!-- Form Actions -->
					<div class="flex gap-3 pt-4 border-t">
						<button
							type="button"
							onclick={saveCampaign}
							disabled={loading}
							class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
						>
							{loading ? t('coupon.saving') : t('coupon.save')}
						</button>
						<button
							type="button"
							onclick={cancelForm}
							disabled={loading}
							class="px-6 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors disabled:opacity-50"
						>
							{t('coupon.cancel')}
						</button>
					</div>
				</div>
			</div>
		{:else}
			<!-- Campaigns List -->
			{#if loading && campaigns.length === 0}
				<div class="flex justify-center items-center py-12">
					<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
				</div>
			{:else if campaigns.length === 0}
				<div class="text-center py-12">
					<div class="text-6xl mb-4">🎁</div>
					<h3 class="text-xl font-semibold text-gray-900 mb-2">{t('coupon.noCampaigns')}</h3>
					<p class="text-gray-600">{t('coupon.createFirstCampaign')}</p>
				</div>
			{:else}
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
					{#each campaigns as campaign}
						<div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
							<!-- Status Badge -->
							<div class="px-4 py-3 bg-gray-50 border-b border-gray-200 flex items-center justify-between">
								<span class="text-sm font-semibold text-gray-700">{campaign.campaign_code}</span>
								<span class={`px-2 py-1 rounded-full text-xs font-medium text-white ${getStatusColor(campaign)}`}>
									{getStatusText(campaign)}
								</span>
							</div>

					<!-- Campaign Info -->
					<div class="p-4 space-y-3">
						<div>
							<h4 class="font-semibold text-gray-900">{campaign.name_en}</h4>
							<p class="text-sm text-gray-600" dir="rtl">{campaign.name_ar}</p>
						</div>

						<div class="text-sm text-gray-600 space-y-1">
							<div class="flex items-center gap-2">
								<span>📅</span>
								<span>{formatDate(campaign.start_date)}</span>
							</div>
							<div class="flex items-center gap-2">
								<span>⏰</span>
								<span>{formatDate(campaign.end_date)}</span>
							</div>
							<div class="flex items-center gap-2">
								<span>🎯</span>
								<span>{t('coupon.maxClaims')}: {campaign.max_claims_per_customer || 1}</span>
							</div>
						</div>								<!-- Actions -->
								<div class="flex gap-2 pt-3 border-t">
									<button
										onclick={() => openEditForm(campaign)}
										class="flex-1 px-3 py-2 bg-blue-50 text-blue-700 rounded hover:bg-blue-100 transition-colors text-sm font-medium"
									>
										✏️ {t('coupon.edit')}
									</button>
									<button
										onclick={() => toggleStatus(campaign)}
										class="flex-1 px-3 py-2 bg-gray-50 text-gray-700 rounded hover:bg-gray-100 transition-colors text-sm font-medium"
									>
										{campaign.is_active ? '⏸️' : '▶️'} {campaign.is_active ? t('coupon.deactivate') : t('coupon.activate')}
									</button>
									<button
										onclick={() => handleDelete(campaign)}
										class="px-3 py-2 bg-red-50 text-red-700 rounded hover:bg-red-100 transition-colors text-sm font-medium"
									>
										🗑️
									</button>
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}
	</div>
</div>
