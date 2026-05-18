<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	export let branch: any;
	export let user: any;

	let supabase: any = null;

	// ── State ──────────────────────────────────────────────────────────────────
	type RedeemStep = 'input' | 'validating' | 'valid' | 'redeeming' | 'done' | 'error';
	let redeemStep: RedeemStep = 'input';

	let voucherCode = '';
	let redeemBillNumber = '';
	let redeemAmount: number | null = null;
	let voucherInfo: any = null;
	let errorMessage = '';
	let successInfo: any = null;

	let rtChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		setupRealtime();
	});

	onDestroy(() => {
		if (rtChannel && supabase) supabase.removeChannel(rtChannel);
	});

	function setupRealtime() {
		rtChannel = supabase
			.channel('sb-redemption-rt')
			.on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'surprise_box_vouchers' }, () => {
				// If currently showing a valid voucher, re-validate it
				if (redeemStep === 'valid' && voucherCode) validateCode();
			})
			.subscribe();
	}

	async function validateCode() {
		if (!voucherCode.trim()) return;
		redeemStep = 'validating';
		errorMessage = '';
		voucherInfo = null;
		try {
			const { data, error } = await supabase.rpc('surprise_box_validate_voucher', {
				p_code: voucherCode.trim().toUpperCase()
			});
			if (error) throw error;
			if (!data.valid) {
				const reasons: Record<string, string> = {
					not_found:       'Voucher code not found.',
					already_redeemed:'This voucher has already been redeemed.',
					expired:         'This voucher has expired.',
					cancelled:       'This voucher has been cancelled.'
				};
				errorMessage = reasons[data.reason] || 'Invalid voucher.';
				redeemStep = 'error';
				return;
			}
			voucherInfo = data;
			redeemStep = 'valid';
		} catch {
			errorMessage = 'Connection error. Please try again.';
			redeemStep = 'error';
		}
	}

	async function redeemVoucher() {
		redeemStep = 'redeeming';
		try {
			const { data, error } = await supabase.rpc('surprise_box_redeem_voucher', {
				p_code: voucherCode.trim().toUpperCase(),
				p_redeemed_bill_number: redeemBillNumber.trim() || null,
				p_redeemed_amount: redeemAmount || null
			});
			if (error) throw error;
			if (!data.success) {
				const reasons: Record<string, string> = {
					not_found:  'Voucher not found.',
					redeemed:   'Already redeemed.',
					expired:    'Voucher expired.',
					cancelled:  'Voucher cancelled.'
				};
				errorMessage = reasons[data.reason] || 'Redemption failed.';
				redeemStep = 'error';
				return;
			}
			successInfo = data;
			redeemStep = 'done';
		} catch {
			errorMessage = 'Connection error. Please try again.';
			redeemStep = 'error';
		}
	}

	function reset() {
		redeemStep = 'input';
		voucherCode = '';
		redeemBillNumber = '';
		redeemAmount = null;
		voucherInfo = null;
		errorMessage = '';
		successInfo = null;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') validateCode();
	}
</script>

<div class="sbr" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>

	<!-- Input -->
	{#if redeemStep === 'input' || redeemStep === 'error'}
		<div class="sbr-card">
			<div class="sbr-icon">🎁</div>
			<h2 class="sbr-title">
				{$locale === 'ar' ? 'استبدال قسيمة صندوق المفاجآت' : 'Surprise Box Voucher Redemption'}
			</h2>

			<div class="sbr-field">
				<label class="sbr-label">
					{$locale === 'ar' ? 'رمز القسيمة' : 'Voucher Code'}
				</label>
				<input
					class="sbr-input sbr-input--code"
					type="text"
					bind:value={voucherCode}
					placeholder="e.g. A1B2C3D4E5F6"
					on:keydown={handleKeydown}
					autocomplete="off"
					autocapitalize="characters"
				/>
			</div>

			{#if errorMessage}
				<div class="sbr-error">{errorMessage}</div>
			{/if}

			<button
				class="sbr-btn sbr-btn--primary"
				disabled={!voucherCode.trim()}
				on:click={validateCode}
			>
				{$locale === 'ar' ? '🔍 تحقق من الرمز' : '🔍 Validate Code'}
			</button>
		</div>

	<!-- Validating -->
	{:else if redeemStep === 'validating'}
		<div class="sbr-center">
			<div class="sbr-spinner"></div>
			<p class="sbr-loading">{$locale === 'ar' ? 'جار التحقق…' : 'Validating…'}</p>
		</div>

	<!-- Valid — show details and confirm redemption -->
	{:else if redeemStep === 'valid'}
		<div class="sbr-card">
			<div class="sbr-valid-banner">
				✅ {$locale === 'ar' ? 'قسيمة صحيحة!' : 'Valid Voucher!'}
			</div>

			<div class="sbr-voucher-details">
				<div class="sbr-detail-row">
					<span class="sbr-detail-label">{$locale === 'ar' ? 'الرمز' : 'Code'}</span>
					<code class="sbr-detail-value">{voucherCode.toUpperCase()}</code>
				</div>
				<div class="sbr-detail-row sbr-detail-row--highlight">
					<span class="sbr-detail-label">{$locale === 'ar' ? 'قيمة القسيمة' : 'Voucher Value'}</span>
					<span class="sbr-detail-value sbr-value--big">{voucherInfo.voucher_value} SAR</span>
				</div>
				<div class="sbr-detail-row">
					<span class="sbr-detail-label">{$locale === 'ar' ? 'الجائزة' : 'Reward'}</span>
					<span class="sbr-detail-value">
						{$locale === 'ar' ? (voucherInfo.label_ar || voucherInfo.label_en) : (voucherInfo.label_en || voucherInfo.label_ar)}
					</span>
				</div>
				<div class="sbr-detail-row">
					<span class="sbr-detail-label">{$locale === 'ar' ? 'رقم الفاتورة الأصلية' : 'Original Bill #'}</span>
					<span class="sbr-detail-value">{voucherInfo.bill_number || '—'}</span>
				</div>
				<div class="sbr-detail-row">
					<span class="sbr-detail-label">{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expires'}</span>
					<span class="sbr-detail-value">{voucherInfo.expires_at}</span>
				</div>
			</div>

			<div class="sbr-redeem-section">
				<p class="sbr-redeem-label">{$locale === 'ar' ? 'بيانات الفاتورة الحالية (اختياري)' : 'Current Bill Details (optional)'}</p>
				<div class="sbr-row2">
					<div class="sbr-field">
						<label class="sbr-label">{$locale === 'ar' ? 'رقم الفاتورة' : 'Bill Number'}</label>
						<input class="sbr-input" type="text" bind:value={redeemBillNumber} placeholder="e.g. 00123" />
					</div>
					<div class="sbr-field">
						<label class="sbr-label">{$locale === 'ar' ? 'مبلغ الفاتورة (ريال)' : 'Bill Amount (SAR)'}</label>
						<input class="sbr-input" type="number" min="0" step="0.01" bind:value={redeemAmount} />
					</div>
				</div>
			</div>

			<div class="sbr-actions">
				<button class="sbr-btn sbr-btn--success" on:click={redeemVoucher}>
					✅ {$locale === 'ar' ? 'تأكيد الاستبدال' : 'Confirm Redemption'}
				</button>
				<button class="sbr-btn sbr-btn--ghost" on:click={reset}>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
			</div>
		</div>

	<!-- Redeeming -->
	{:else if redeemStep === 'redeeming'}
		<div class="sbr-center">
			<div class="sbr-spinner"></div>
			<p class="sbr-loading">{$locale === 'ar' ? 'جار الاستبدال…' : 'Processing redemption…'}</p>
		</div>

	<!-- Done -->
	{:else if redeemStep === 'done'}
		<div class="sbr-card sbr-card--success">
			<div class="sbr-done-icon">🎉</div>
			<h2 class="sbr-done-title">{$locale === 'ar' ? 'تم الاستبدال بنجاح!' : 'Redeemed Successfully!'}</h2>
			<div class="sbr-done-value">{successInfo?.voucher_value} SAR</div>
			<div class="sbr-done-label">
				{$locale === 'ar' ? (successInfo?.label_ar || successInfo?.label_en) : (successInfo?.label_en || successInfo?.label_ar)}
			</div>
			<p class="sbr-done-code">{voucherCode.toUpperCase()}</p>
			<button class="sbr-btn sbr-btn--primary" on:click={reset}>
				{$locale === 'ar' ? 'قسيمة جديدة' : 'New Redemption'}
			</button>
		</div>
	{/if}
</div>

<style>
	.sbr {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
		padding: 1.5rem;
		align-items: center;
		justify-content: center;
		overflow-y: auto;
	}

	.sbr-card {
		background: #ffffff;
		border: 1px solid #e2e8f0;
		border-radius: 16px;
		padding: 2rem;
		width: 100%;
		max-width: 480px;
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
		box-shadow: 0 4px 24px rgba(0,0,0,0.06);
	}
	.sbr-card--success {
		border-color: #86efac;
		background: linear-gradient(135deg, #f0fdf4, #dcfce7);
		align-items: center;
		text-align: center;
	}

	.sbr-icon { font-size: 2.5rem; text-align: center; }
	.sbr-title { font-size: 1.1rem; font-weight: 800; color: #1e293b; margin: 0; text-align: center; }

	/* ── Fields ──────────────────────────────────────────────────────────────── */
	.sbr-field { display: flex; flex-direction: column; gap: 0.3rem; }
	.sbr-label { font-size: 0.82rem; color: #64748b; font-weight: 600; }
	.sbr-input {
		background: #f8fafc;
		border: 2px solid #e2e8f0;
		border-radius: 10px;
		color: #1e293b;
		padding: 0.65rem 0.9rem;
		font-size: 0.95rem;
		outline: none;
		width: 100%;
		box-sizing: border-box;
		transition: border-color 0.2s;
	}
	.sbr-input:focus { border-color: #7c3aed; }
	.sbr-input--code { font-family: monospace; font-size: 1.1rem; font-weight: 700; letter-spacing: 0.05rem; text-transform: uppercase; }

	/* ── Voucher details ─────────────────────────────────────────────────────── */
	.sbr-valid-banner {
		background: #f0fdf4;
		border: 1px solid #86efac;
		border-radius: 10px;
		padding: 0.65rem 1rem;
		color: #15803d;
		font-weight: 700;
		font-size: 1rem;
		text-align: center;
	}
	.sbr-voucher-details {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		overflow: hidden;
	}
	.sbr-detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.65rem 1rem;
		border-bottom: 1px solid #f1f5f9;
		gap: 1rem;
	}
	.sbr-detail-row:last-child { border-bottom: none; }
	.sbr-detail-row--highlight { background: #fdf4ff; }
	.sbr-detail-label { font-size: 0.82rem; color: #64748b; font-weight: 600; flex-shrink: 0; }
	.sbr-detail-value { font-size: 0.9rem; color: #1e293b; font-weight: 600; text-align: end; }
	.sbr-value--big { font-size: 1.4rem; font-weight: 900; color: #7c3aed; }

	/* ── Redeem section ──────────────────────────────────────────────────────── */
	.sbr-redeem-section { display: flex; flex-direction: column; gap: 0.75rem; }
	.sbr-redeem-label { font-size: 0.85rem; color: #64748b; font-weight: 600; margin: 0; }
	.sbr-row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }

	/* ── Buttons ─────────────────────────────────────────────────────────────── */
	.sbr-actions { display: flex; flex-direction: column; gap: 0.65rem; }
	.sbr-btn {
		width: 100%;
		padding: 0.8rem 1.25rem;
		border-radius: 10px;
		border: none;
		font-size: 0.95rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.15s;
	}
	.sbr-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.sbr-btn--primary { background: #7c3aed; color: #fff; }
	.sbr-btn--primary:hover:not(:disabled) { background: #6d28d9; }
	.sbr-btn--success { background: #16a34a; color: #fff; }
	.sbr-btn--success:hover:not(:disabled) { background: #15803d; }
	.sbr-btn--ghost { background: #f1f5f9; border: 1px solid #e2e8f0; color: #64748b; }
	.sbr-btn--ghost:hover:not(:disabled) { background: #e2e8f0; }

	/* ── Error ───────────────────────────────────────────────────────────────── */
	.sbr-error {
		background: #fef2f2;
		border: 1px solid #fca5a5;
		border-radius: 8px;
		padding: 0.6rem 0.9rem;
		color: #dc2626;
		font-size: 0.88rem;
	}

	/* ── Center ──────────────────────────────────────────────────────────────── */
	.sbr-center { display: flex; flex-direction: column; align-items: center; gap: 1rem; padding: 3rem 0; }
	.sbr-loading { color: #64748b; font-size: 0.95rem; }

	/* ── Spinner ─────────────────────────────────────────────────────────────── */
	.sbr-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(124,58,237,0.15);
		border-top-color: #7c3aed;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ── Done ────────────────────────────────────────────────────────────────── */
	.sbr-done-icon { font-size: 3rem; }
	.sbr-done-title { font-size: 1.3rem; font-weight: 800; color: #15803d; margin: 0; }
	.sbr-done-value { font-size: 2rem; font-weight: 900; color: #7c3aed; }
	.sbr-done-label { font-size: 1rem; color: #334155; }
	.sbr-done-code { font-family: monospace; font-size: 0.9rem; color: #64748b; }
</style>
