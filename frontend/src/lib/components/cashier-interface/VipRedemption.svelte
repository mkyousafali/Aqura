<script lang="ts">
	import { onMount } from 'svelte';
	import { cashierUser } from '$lib/stores/cashierAuth';
	import { _ as t, t as tr } from '$lib/i18n';

	export let user: any;
	export let branch: any;
	// Passed from RedemptionWindow (realtime-managed)
	export let campaignActive: boolean | null = null;
	export let posterPath: string = '';
	export let posterMimeType: string = '';

	let supabase: any = null;

	// Poster URL derived reactively from props
	$: posterUrl = (posterPath && supabase)
		? supabase.storage.from('offer-pdfs').getPublicUrl(posterPath).data.publicUrl
		: null;
	$: posterIsImage = posterMimeType.startsWith('image/');

	// Form state
	let mobileInput = '';
	let step: 'idle' | 'looking' | 'found' | 'saving' | 'done' | 'error' = 'idle';
	let lookupError = '';

	// Customer found
	let foundCustomer: any = null;

	// Bill fields
	let billNumber = '';
	let billAmount = '';
	let discountedValue = '';
	let saveError = '';

	// ──────────────────────────────────────────
	// Phone normalisation: 0548357066 → 966548357066
	// ──────────────────────────────────────────
	function normalisePhone(raw: string): string {
		const digits = raw.replace(/\D/g, '');
		if (digits.startsWith('966')) return digits;
		if (digits.startsWith('0')) return '966' + digits.slice(1);
		return '966' + digits;
	}

	function validatePhone(raw: string): boolean {
		const digits = raw.replace(/\D/g, '');
		return digits.length >= 9 && digits.length <= 12;
	}

	// ──────────────────────────────────────────
	// Init supabase (no campaign loading — parent owns it)
	// ──────────────────────────────────────────
	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
	});

	// ──────────────────────────────────────────
	// Step 1 – Look up customer
	// ──────────────────────────────────────────
	async function lookupCustomer() {
		lookupError = '';
		if (!validatePhone(mobileInput)) {
			lookupError = tr('coupon.vipInvalidPhone');
			return;
		}

		const normalised = normalisePhone(mobileInput);
		step = 'looking';

		try {
			// Check today's redemption first (fast path)
			const today = new Date().toISOString().split('T')[0];
			const { data: existing } = await supabase
				.from('vip_redemptions')
				.select('id, redeemed_at')
				.eq('whatsapp_number', normalised)
				.eq('redeemed_date', today)
				.maybeSingle();

			if (existing) {
				lookupError = '\u26a0\ufe0f ' + tr('coupon.vipAlreadyUsed');
				step = 'error';
				return;
			}

			// Look up customer
			const { data: customer, error } = await supabase
				.from('customers')
				.select('id, name, whatsapp_number')
				.eq('whatsapp_number', normalised)
				.maybeSingle();

			if (error) throw error;

			if (!customer) {
				lookupError = '\u274c ' + tr('coupon.vipNotFound');
				step = 'error';
				return;
			}

			foundCustomer = customer;
			step = 'found';
		} catch (err: any) {
			lookupError = 'Error looking up customer: ' + (err.message || err);
			step = 'error';
		}
	}

	// ──────────────────────────────────────────
	// Step 2 – Save redemption
	// ──────────────────────────────────────────
	async function saveRedemption() {
		saveError = '';

		if (!billNumber.trim()) { saveError = 'Bill number is required.'; return; }
		const amountNum = parseFloat(billAmount);
		const discountNum = parseFloat(discountedValue);
		if (isNaN(amountNum) || amountNum <= 0) { saveError = 'Enter a valid bill amount.'; return; }
		if (isNaN(discountNum) || discountNum < 0) { saveError = 'Enter a valid discount value.'; return; }
		if (discountNum > amountNum) { saveError = 'Discount cannot exceed bill amount.'; return; }

		step = 'saving';

		const normalised = normalisePhone(mobileInput);
		const today = new Date().toISOString().split('T')[0];
		const currentUser = $cashierUser || user;

		try {
			const { error } = await supabase
				.from('vip_redemptions')
				.insert({
					customer_id:     foundCustomer.id,
					whatsapp_number: normalised,
					bill_number:     billNumber.trim(),
					bill_amount:     amountNum,
					discounted_value: discountNum,
					redeemed_date:   today,
					cashier_id:      currentUser?.id || currentUser?.username || null,
					branch_id:       branch?.id || null,
				});

			if (error) {
				// Unique constraint violation = already redeemed today
				if (error.code === '23505') {
					saveError = '⚠️ This customer has already used VIP Redemption today.';
					step = 'found';
					return;
				}
				throw error;
			}

			step = 'done';
		} catch (err: any) {
			saveError = 'Failed to save: ' + (err.message || err);
			step = 'found';
		}
	}

	// ──────────────────────────────────────────
	// Reset form
	// ──────────────────────────────────────────
	function reset() {
		mobileInput = '';
		billNumber = '';
		billAmount = '';
		discountedValue = '';
		foundCustomer = null;
		lookupError = '';
		saveError = '';
		step = 'idle';
	}
</script>

<div class="vip-container">
	{#if campaignActive === null}
		<div class="status-box info">⏳ {$t('coupon.vipCheckingCampaign')}</div>

	{:else if !campaignActive}
		<div class="status-box inactive">
			<div class="status-icon">🔒</div>
			<div class="status-title">{$t('coupon.vipCampaignInactive')}</div>
			<div class="status-sub">{$t('coupon.vipCampaignInactiveSub')}</div>
		</div>

	{:else if step === 'done'}
		<div class="done-card">
			<div class="done-icon">✅</div>
		<div class="done-title">{$t('coupon.vipRedemptionSaved')}</div>
		<div class="done-details">
			<span>{$t('coupon.vipCustomer')}: <strong>{foundCustomer?.name || normalisePhone(mobileInput)}</strong></span>
			<span>{$t('coupon.vipBillNo')}: <strong>{billNumber}</strong></span>
			<span>{$t('coupon.vipDiscount')}: <strong>SAR {parseFloat(discountedValue).toFixed(2)}</strong></span>
		</div>
		<button class="btn-primary" on:click={reset}>{$t('coupon.vipNewRedemption')}</button>
		</div>

	{:else}
		<div class="split-layout">
			<!-- LEFT: Instruction Poster -->
			<div class="poster-col">
				{#if posterUrl}
					{#if posterIsImage}
						<img src={posterUrl} alt="VIP Instructions" class="poster-img" />
					{:else}
						<div class="poster-pdf-wrap">
							<span class="poster-pdf-icon">📄</span>
							<a href={posterUrl} target="_blank" rel="noopener noreferrer" class="poster-link">
								{$t('cashierInterface.vipRedemptionTab')}
							</a>
						</div>
					{/if}
				{:else}
						<div class="poster-missing">📋 {$t('coupon.vipNoPoster')}</div>
				{/if}
			</div>

			<!-- RIGHT: Redemption Form -->
			<div class="form-col">
				<!-- Phone lookup section -->
				<div class="section">
					<label class="field-label" for="vip-mobile">{$t('coupon.vipCustomerMobile')}</label>
					<div class="input-row">
						<input
							id="vip-mobile"
							class="field-input"
							type="tel"
							placeholder="e.g. 0548357066"
							bind:value={mobileInput}
							disabled={step === 'found' || step === 'looking' || step === 'saving'}
							on:keydown={(e) => e.key === 'Enter' && step === 'idle' && lookupCustomer()}
						/>
						{#if step === 'idle' || step === 'error'}
							<button class="btn-primary" on:click={lookupCustomer} disabled={!mobileInput.trim()}>
								{$t('coupon.vipLookUp')}
							</button>
						{:else if step === 'found' || step === 'saving'}
							<button class="btn-secondary" on:click={reset}>{$t('coupon.vipChange')}</button>
						{/if}
					</div>
					{#if lookupError}
						<div class="error-msg">{lookupError}</div>
					{/if}
				</div>

				<!-- Customer found — show bill fields -->
				{#if step === 'found' || step === 'saving'}
					<div class="customer-banner">
						👤 <strong>{foundCustomer?.name || $t('coupon.vipCustomer')}</strong>
						<span class="phone-badge">{normalisePhone(mobileInput)}</span>
					</div>

					<div class="section">
						<label class="field-label" for="vip-bill-number">{$t('coupon.vipBillNumber')}</label>
						<input
							id="vip-bill-number"
							class="field-input"
							type="text"
							placeholder="e.g. INV-0001"
							bind:value={billNumber}
							disabled={step === 'saving'}
						/>
					</div>

					<div class="two-col">
						<div class="section">
							<label class="field-label" for="vip-bill-amount">{$t('coupon.vipBillAmount')}</label>
							<input
								id="vip-bill-amount"
								class="field-input"
								type="number"
								min="0"
								step="0.01"
								placeholder="0.00"
								bind:value={billAmount}
								disabled={step === 'saving'}
							/>
						</div>
						<div class="section">
							<label class="field-label" for="vip-discount">{$t('coupon.vipDiscountedValue')}</label>
							<input
								id="vip-discount"
								class="field-input"
								type="number"
								min="0"
								step="0.01"
								placeholder="0.00"
								bind:value={discountedValue}
								disabled={step === 'saving'}
							/>
						</div>
					</div>

					{#if saveError}
						<div class="error-msg">{saveError}</div>
					{/if}

					<button
						class="btn-primary btn-full"
						on:click={saveRedemption}
						disabled={step === 'saving'}
					>
						{step === 'saving' ? $t('coupon.vipSaving') : '💎 ' + $t('coupon.vipSave')}
					</button>
				{/if}

				{#if step === 'looking'}
					<div class="status-box info">🔍 {$t('coupon.vipLookingUp')}</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.vip-container {
		padding: 1rem 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		height: 100%;
		box-sizing: border-box;
	}

	.split-layout {
		display: grid;
		grid-template-columns: 3fr 2fr;
		gap: 1.5rem;
		align-items: start;
		flex: 1;
	}

	.poster-col {
		display: flex;
		flex-direction: column;
		position: sticky;
		top: 0;
	}

	.form-col {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		justify-content: center;
		align-self: center;
	}

	.section { display: flex; flex-direction: column; gap: 0.4rem; }

	.two-col {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.field-label {
		font-size: 0.82rem;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.field-input {
		width: 100%;
		padding: 0.65rem 0.85rem;
		border: 1.5px solid #cbd5e1;
		border-radius: 8px;
		font-size: 1rem;
		color: #1e293b;
		background: #fff;
		outline: none;
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.field-input:focus { border-color: #3b82f6; }
	.field-input:disabled { background: #f1f5f9; color: #94a3b8; }

	.input-row {
		display: flex;
		gap: 0.6rem;
		align-items: center;
	}
	.input-row .field-input { flex: 1; }

	.btn-primary {
		padding: 0.65rem 1.25rem;
		background: #f97316;
		color: #fff;
		border: none;
		border-radius: 8px;
		font-weight: 700;
		font-size: 0.92rem;
		cursor: pointer;
		transition: background 0.15s, transform 0.1s;
		white-space: nowrap;
	}
	.btn-primary:hover:not(:disabled) { background: #ea580c; transform: translateY(-1px); }
	.btn-primary:disabled { opacity: 0.55; cursor: not-allowed; }

	.btn-secondary {
		padding: 0.65rem 1rem;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.9rem;
		cursor: pointer;
		white-space: nowrap;
	}
	.btn-secondary:hover { background: #cbd5e1; }

	.btn-full { width: 100%; padding: 0.8rem; font-size: 1rem; }

	.error-msg {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 0.6rem 0.9rem;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.status-box {
		border-radius: 10px;
		padding: 1rem 1.25rem;
		font-size: 0.95rem;
	}
	.status-box.info { background: #eff6ff; color: #1d4ed8; border: 1px solid #bfdbfe; }

	.status-box.inactive {
		background: #fafafa;
		border: 2px dashed #e2e8f0;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		padding: 2.5rem 1.5rem;
		gap: 0.5rem;
	}
	.status-icon { font-size: 2.5rem; }
	.status-title { font-size: 1.15rem; font-weight: 700; color: #475569; }
	.status-sub { color: #94a3b8; font-size: 0.9rem; }

	.customer-banner {
		background: #f0fdf4;
		border: 1.5px solid #86efac;
		border-radius: 8px;
		padding: 0.65rem 1rem;
		display: flex;
		align-items: center;
		gap: 0.6rem;
		font-size: 0.95rem;
		color: #166534;
	}
	.phone-badge {
		margin-left: auto;
		background: #dcfce7;
		color: #15803d;
		padding: 0.2rem 0.6rem;
		border-radius: 20px;
		font-size: 0.82rem;
		font-weight: 600;
	}

	.poster-img {
		width: 100%;
		height: auto;
		max-height: calc(100vh - 140px);
		object-fit: contain;
		border-radius: 12px;
		border: 1.5px solid #e2e8f0;
		background: #f8fafc;
		display: block;
	}
	.poster-pdf-wrap {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 3rem 1.5rem;
		border: 1.5px solid #e2e8f0;
		border-radius: 12px;
		background: #f8fafc;
		text-align: center;
	}
	.poster-pdf-icon { font-size: 3.5rem; }
	.poster-link {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #eff6ff;
		color: #2563eb;
		font-weight: 600;
		font-size: 0.9rem;
		text-decoration: none;
		border-radius: 10px;
	}
	.poster-link:hover { background: #dbeafe; }
	.poster-missing {
		background: #f8fafc;
		border: 1px dashed #cbd5e1;
		border-radius: 8px;
		padding: 0.75rem 1rem;
		font-size: 0.85rem;
		color: #94a3b8;
		text-align: center;
	}

	.done-card {
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 14px;
		padding: 2rem 1.5rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		text-align: center;
	}
	.done-icon { font-size: 3rem; }
	.done-title { font-size: 1.25rem; font-weight: 700; color: #166534; }
	.done-details {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		color: #374151;
		font-size: 0.95rem;
	}
</style>
