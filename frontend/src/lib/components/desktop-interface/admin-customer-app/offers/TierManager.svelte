<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { currentLocale } from '$lib/i18n';

	export let tiers: any[] = [];
	export let readonly = false;

	const dispatch = createEventDispatcher();

	$: isRTL = $currentLocale === 'ar';

	function addTier() {
		if (tiers.length >= 6) {
			alert(isRTL ? 'الحد الأقصى 6 مستويات' : 'Maximum 6 tiers allowed');
			return;
		}

		const newTier = {
			tier_number: tiers.length + 1,
			min_amount: tiers.length > 0 ? (tiers[tiers.length - 1].max_amount || 0) + 0.01 : 0,
			max_amount: null,
			discount_type: 'percentage' as 'percentage' | 'fixed',
			discount_value: 0
		};

		tiers = [...tiers, newTier];
		dispatch('change', tiers);
	}

	function removeTier(index: number) {
		tiers = tiers.filter((_, i) => i !== index);
		// Renumber tiers
		tiers = tiers.map((tier, i) => ({ ...tier, tier_number: i + 1 }));
		dispatch('change', tiers);
	}

	function updateTier(index: number) {
		// Ensure proper ordering and no overlaps
		if (index > 0) {
			const prevTier = tiers[index - 1];
			if (tiers[index].min_amount <= (prevTier.max_amount || prevTier.min_amount)) {
				tiers[index].min_amount = (prevTier.max_amount || prevTier.min_amount) + 0.01;
			}
		}
		dispatch('change', tiers);
	}

	function formatAmount(amount: number | null) {
		if (amount === null || amount === undefined) return isRTL ? 'غير محدود' : 'Unlimited';
		return amount.toFixed(2);
	}
</script>

<div class="tier-manager" class:rtl={isRTL}>
	<div class="tier-header">
		<h4>{isRTL ? 'مستويات الخصم' : 'Discount Tiers'}</h4>
		{#if !readonly && tiers.length < 6}
			<button type="button" class="add-tier-btn" on:click={addTier}>
				+ {isRTL ? 'إضافة مستوى' : 'Add Tier'}
			</button>
		{/if}
	</div>

	{#if tiers.length === 0}
		<div class="empty-state">
			<p>{isRTL ? 'لم يتم إضافة أي مستويات بعد' : 'No tiers added yet'}</p>
			<p class="empty-hint">
				{isRTL 
					? 'أضف مستويات لتطبيق خصومات مختلفة حسب إجمالي السلة' 
					: 'Add tiers to apply different discounts based on cart total'}
			</p>
		</div>
	{:else}
		<div class="tiers-list">
			{#each tiers as tier, index (index)}
				<div class="tier-card">
					<div class="tier-number-badge">
						{isRTL ? 'المستوى' : 'Tier'} {tier.tier_number}
					</div>

					<div class="tier-inputs">
						<div class="input-group">
							<label>{isRTL ? 'من (ريال)' : 'From (SAR)'}</label>
							<input
								type="number"
								step="0.01"
								min="0"
								bind:value={tier.min_amount}
								on:blur={() => updateTier(index)}
								disabled={readonly}
								placeholder="0.00"
							/>
						</div>

						<div class="input-group">
							<label>{isRTL ? 'إلى (ريال)' : 'To (SAR)'}</label>
							<input
								type="number"
								step="0.01"
								min={tier.min_amount + 0.01}
								bind:value={tier.max_amount}
								on:blur={() => updateTier(index)}
								disabled={readonly}
								placeholder={isRTL ? 'غير محدود' : 'Unlimited'}
							/>
						</div>

						<div class="input-group">
							<label>{isRTL ? 'نوع الخصم' : 'Discount Type'}</label>
							<select bind:value={tier.discount_type} disabled={readonly} on:change={() => updateTier(index)}>
								<option value="percentage">{isRTL ? 'نسبة مئوية' : 'Percentage'}</option>
								<option value="fixed">{isRTL ? 'مبلغ ثابت' : 'Fixed Amount'}</option>
							</select>
						</div>

						<div class="input-group">
							<label>{isRTL ? 'قيمة الخصم' : 'Discount Value'}</label>
							<input
								type="number"
								step="0.01"
								min="0"
								max={tier.discount_type === 'percentage' ? 100 : undefined}
								bind:value={tier.discount_value}
								on:blur={() => updateTier(index)}
								disabled={readonly}
								placeholder="0.00"
							/>
							<span class="input-suffix">
								{tier.discount_type === 'percentage' ? '%' : isRTL ? 'ريال' : 'SAR'}
							</span>
						</div>

						{#if !readonly}
							<button
								type="button"
								class="remove-tier-btn"
								on:click={() => removeTier(index)}
								title={isRTL ? 'حذف المستوى' : 'Remove tier'}
							>
								🗑️
							</button>
						{/if}
					</div>

					<div class="tier-summary">
						{isRTL ? 'عند الشراء بقيمة' : 'When purchasing'} 
						<strong>{formatAmount(tier.min_amount)}</strong>
						{isRTL ? 'إلى' : 'to'}
						<strong>{formatAmount(tier.max_amount)}</strong>
						{isRTL ? 'ريال، احصل على خصم' : 'SAR, get'}
						<strong>
							{tier.discount_type === 'percentage' 
								? `${tier.discount_value}%` 
								: `${tier.discount_value} ${isRTL ? 'ريال' : 'SAR'}`}
						</strong>
						{tier.discount_type === 'percentage' ? '' : isRTL ? 'خصم' : 'off'}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.tier-manager {
		width: 100%;
		padding: 1rem;
		background: var(--surface-secondary, #f8f9fa);
		border-radius: 8px;
		border: 1px solid var(--border-color, #e0e0e0);
	}

	.tier-manager.rtl {
		direction: rtl;
	}

	.tier-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.tier-header h4 {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--text-primary, #1a1a1a);
	}

	.add-tier-btn {
		padding: 0.5rem 1rem;
		background: var(--primary-color, #1976d2);
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		transition: all 0.2s;
	}

	.add-tier-btn:hover {
		background: var(--primary-dark, #1565c0);
		transform: translateY(-1px);
	}

	.empty-state {
		text-align: center;
		padding: 2rem 1rem;
		color: var(--text-secondary, #666);
	}

	.empty-state p {
		margin: 0.5rem 0;
	}

	.empty-hint {
		font-size: 0.9rem;
		font-style: italic;
	}

	.tiers-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.tier-card {
		background: white;
		padding: 1rem;
		border-radius: 8px;
		border: 1px solid var(--border-color, #e0e0e0);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.tier-number-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: var(--primary-light, #e3f2fd);
		color: var(--primary-color, #1976d2);
		border-radius: 12px;
		font-size: 0.85rem;
		font-weight: 600;
		margin-bottom: 0.75rem;
	}

	.tier-inputs {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: 1rem;
		position: relative;
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		position: relative;
	}

	.input-group label {
		font-size: 0.85rem;
		font-weight: 500;
		color: var(--text-secondary, #666);
	}

	.input-group input,
	.input-group select {
		padding: 0.5rem;
		border: 1px solid var(--border-color, #e0e0e0);
		border-radius: 6px;
		font-size: 0.95rem;
		transition: border-color 0.2s;
	}

	.input-group input:focus,
	.input-group select:focus {
		outline: none;
		border-color: var(--primary-color, #1976d2);
	}

	.input-group input:disabled,
	.input-group select:disabled {
		background: var(--surface-disabled, #f5f5f5);
		cursor: not-allowed;
	}

	.input-suffix {
		position: absolute;
		right: 0.75rem;
		bottom: 0.65rem;
		color: var(--text-secondary, #666);
		font-size: 0.9rem;
		pointer-events: none;
	}

	.rtl .input-suffix {
		right: auto;
		left: 0.75rem;
	}

	.remove-tier-btn {
		padding: 0.5rem;
		background: transparent;
		border: 1px solid var(--error-color, #d32f2f);
		border-radius: 6px;
		cursor: pointer;
		font-size: 1.2rem;
		transition: all 0.2s;
		height: fit-content;
		align-self: end;
	}

	.remove-tier-btn:hover {
		background: var(--error-color, #d32f2f);
		transform: scale(1.1);
	}

	.tier-summary {
		margin-top: 0.75rem;
		padding: 0.75rem;
		background: var(--surface-tertiary, #f0f0f0);
		border-radius: 6px;
		font-size: 0.9rem;
		color: var(--text-primary, #1a1a1a);
		line-height: 1.5;
	}

	.tier-summary strong {
		color: var(--primary-color, #1976d2);
		font-weight: 600;
	}

	@media (max-width: 768px) {
		.tier-inputs {
			grid-template-columns: 1fr;
		}

		.remove-tier-btn {
			width: 100%;
		}
	}
</style>
