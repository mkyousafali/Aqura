<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';

	export let user: any;
	export let branch: any;

	let supabase: any = null;
	let couponCode = '';
	let step: 'input' | 'validating' | 'details' | 'printing' = 'input';
	let loading = false;
	let error = '';
	let couponData: any = null;

	// Realtime
	let realtimeChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		setupRealtime();
	});

	onDestroy(() => {
		if (realtimeChannel && supabase) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function setupRealtime() {
		if (!supabase) return;
		realtimeChannel = supabase.channel('gift-wheel-coupon-cashier-realtime')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_coupons' }, (payload: any) => {
				// If we're viewing a coupon and it got redeemed/updated elsewhere, refresh
				if (couponData && payload.new && payload.new.code === couponData.code) {
					validateCoupon();
				}
			})
			.subscribe();
	}

	async function validateCoupon() {
		if (!couponCode.trim() || !supabase) return;

		loading = true;
		error = '';
		step = 'validating';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_validate_coupon', {
				p_code: couponCode.trim()
			});

			if (rpcError) throw rpcError;

			if (!data.valid) {
				error = data.error || 'Invalid coupon';
				step = 'input';
			} else {
				couponData = data;
				step = 'details';
			}
		} catch (err: any) {
			error = err.message || 'Validation failed';
			step = 'input';
		} finally {
			loading = false;
		}
	}

	async function printCoupon() {
		if (!couponData || !supabase) return;

		step = 'printing';

		try {
			// Mark as printed with branch_id
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_redeem_coupon', {
				p_code: couponData.code,
				p_action: 'print',
				p_branch_id: branch?.id || null
			});

			if (rpcError) throw rpcError;

			// Open print window
			const printWindow = window.open('', '_blank', 'width=400,height=600');
			if (printWindow) {
				const discountText = couponData.reward_type === 'percentage'
					? `${couponData.reward_value}% OFF`
					: `${couponData.reward_value} SAR OFF`;

				const maxDiscountHtml = couponData.max_discount
					? `<p style="font-size:14px;color:#666;">Max Discount: ${couponData.max_discount} SAR</p>`
					: '';

				printWindow.document.write(`
<!DOCTYPE html>
<html>
<head>
	<title>Gift Wheel Coupon</title>
	<style>
		body {
			font-family: 'Courier New', monospace;
			width: 280px;
			margin: 0 auto;
			padding: 20px 10px;
			text-align: center;
		}
		.divider {
			border-top: 1px dashed #000;
			margin: 10px 0;
		}
		.title {
			font-size: 18px;
			font-weight: bold;
			margin: 8px 0;
		}
		.discount {
			font-size: 32px;
			font-weight: bold;
			margin: 16px 0;
			padding: 12px;
			border: 2px dashed #000;
		}
		.code {
			font-size: 20px;
			font-weight: bold;
			letter-spacing: 2px;
			margin: 12px 0;
		}
		.info {
			font-size: 12px;
			color: #666;
			margin: 4px 0;
		}
		.note {
			font-size: 11px;
			color: #999;
			margin-top: 16px;
			font-style: italic;
		}
	</style>
</head>
<body>
	<div class="title">🎡 GIFT WHEEL COUPON</div>
	<div class="divider"></div>
	<div class="discount">${discountText}</div>
	${maxDiscountHtml}
	<div class="divider"></div>
	<p style="font-size:12px;color:#666;">Coupon Code:</p>
	<div class="code">${couponData.code}</div>
	<div class="divider"></div>
	<p class="info">Valid Until: ${couponData.expiry_date || 'N/A'}</p>
	<p class="info">Valid for next purchase only</p>
	<div class="divider"></div>
	<p class="note">Present this coupon at checkout</p>
	<script>window.onload = function() { window.print(); }</` + `script>
</body>
</html>`);
				printWindow.document.close();
			}

			step = 'details';
		} catch (err: any) {
			error = err.message || 'Print failed';
			step = 'details';
		}
	}

	function reset() {
		couponCode = '';
		step = 'input';
		error = '';
		couponData = null;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && step === 'input') {
			validateCoupon();
		}
	}
</script>

<div class="gift-wheel-coupon">
	<div class="coupon-header">
		<span class="header-icon">🎡</span>
		<h2>Gift Wheel Coupon</h2>
	</div>

	{#if step === 'input' || step === 'validating'}
		<div class="input-section">
			{#if error}
				<div class="error-msg">{error}</div>
			{/if}

			<div class="input-field">
				<label>Coupon Code</label>
				<input
					type="text"
					bind:value={couponCode}
					on:keydown={handleKeydown}
					placeholder="Enter 6-digit coupon code"
					disabled={loading}
					autofocus
				/>
			</div>

			<button
				class="btn-validate"
				on:click={validateCoupon}
				disabled={loading || !couponCode.trim()}
			>
				{#if loading}
					<span class="spinner"></span> Validating...
				{:else}
					🔍 Validate Coupon
				{/if}
			</button>
		</div>

	{:else if step === 'details' || step === 'printing'}
		<div class="details-section">
			<div class="coupon-details">
				<div class="detail-badge">
					{#if couponData.reward_type === 'percentage'}
						<span class="badge-value">{couponData.reward_value}%</span>
						<span class="badge-label">OFF</span>
					{:else}
						<span class="badge-value">{couponData.reward_value}</span>
						<span class="badge-label">SAR OFF</span>
					{/if}
				</div>

				<div class="detail-rows">
					<div class="detail-row">
						<span class="detail-key">Code</span>
						<span class="detail-val code-val">{couponData.code}</span>
					</div>
					<div class="detail-row">
						<span class="detail-key">Reward</span>
						<span class="detail-val">{couponData.reward_label}</span>
					</div>
					{#if couponData.max_discount}
						<div class="detail-row">
							<span class="detail-key">Max Discount</span>
							<span class="detail-val">{couponData.max_discount} SAR</span>
						</div>
					{/if}
					<div class="detail-row">
						<span class="detail-key">Expiry</span>
						<span class="detail-val">{couponData.expiry_date || 'N/A'}</span>
					</div>
					<div class="detail-row">
						<span class="detail-key">Status</span>
						<span class="detail-val status" class:printed={couponData.status === 'printed'}>
							{couponData.status}
						</span>
					</div>
				</div>
			</div>

			<div class="action-buttons">
				<button class="btn-print" on:click={printCoupon} disabled={step === 'printing'}>
					{#if step === 'printing'}
						<span class="spinner"></span> Printing...
					{:else}
						🖨️ Print Coupon
					{/if}
				</button>
				<button class="btn-back" on:click={reset}>
					← New Code
				</button>
			</div>

			{#if error}
				<div class="error-msg">{error}</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.gift-wheel-coupon {
		width: 100%;
		height: 100%;
		background: #0f172a;
		color: #e2e8f0;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
		display: flex;
		flex-direction: column;
		overflow-y: auto;
	}

	.coupon-header {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 16px 20px;
		background: #1e293b;
		border-bottom: 1px solid #334155;
	}

	.header-icon {
		font-size: 24px;
	}

	.coupon-header h2 {
		margin: 0;
		font-size: 18px;
		color: #fbbf24;
	}

	.input-section {
		padding: 24px 20px;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.error-msg {
		background: rgba(239, 68, 68, 0.15);
		border: 1px solid rgba(239, 68, 68, 0.3);
		color: #fca5a5;
		padding: 10px 14px;
		border-radius: 8px;
		font-size: 13px;
	}

	.input-field {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.input-field label {
		font-size: 13px;
		color: #94a3b8;
		font-weight: 500;
	}

	.input-field input {
		padding: 12px 14px;
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 8px;
		color: #e2e8f0;
		font-size: 16px;
		font-family: monospace;
		letter-spacing: 1px;
		outline: none;
		text-transform: uppercase;
	}

	.input-field input:focus {
		border-color: #fbbf24;
		box-shadow: 0 0 0 2px rgba(251, 191, 36, 0.2);
	}

	.input-field input:disabled {
		opacity: 0.5;
	}

	.btn-validate {
		padding: 12px 20px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: #fff;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.btn-validate:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.btn-validate:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Details */
	.details-section {
		padding: 20px;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.coupon-details {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		overflow: hidden;
	}

	.detail-badge {
		background: linear-gradient(135deg, rgba(251, 191, 36, 0.2), rgba(245, 158, 11, 0.1));
		padding: 20px;
		text-align: center;
		border-bottom: 1px solid #334155;
	}

	.badge-value {
		font-size: 36px;
		font-weight: 800;
		color: #fbbf24;
	}

	.badge-label {
		font-size: 16px;
		font-weight: 600;
		color: #fbbf24;
		margin-left: 4px;
	}

	.detail-rows {
		padding: 12px 16px;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		padding: 8px 0;
		border-bottom: 1px solid rgba(51, 65, 85, 0.5);
	}

	.detail-row:last-child {
		border-bottom: none;
	}

	.detail-key {
		font-size: 13px;
		color: #64748b;
	}

	.detail-val {
		font-size: 13px;
		font-weight: 600;
		color: #e2e8f0;
	}

	.code-val {
		font-family: monospace;
		color: #10b981;
		letter-spacing: 1px;
	}

	.status {
		text-transform: uppercase;
		font-size: 11px;
		padding: 2px 8px;
		border-radius: 4px;
		background: rgba(16, 185, 129, 0.2);
		color: #34d399;
	}

	.status.printed {
		background: rgba(59, 130, 246, 0.2);
		color: #60a5fa;
	}

	.action-buttons {
		display: flex;
		gap: 10px;
	}

	.btn-print {
		flex: 1;
		padding: 12px 20px;
		background: linear-gradient(135deg, #10b981, #059669);
		color: #fff;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.btn-print:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.btn-print:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-back {
		padding: 12px 20px;
		background: #1e293b;
		color: #94a3b8;
		border: 1px solid #334155;
		border-radius: 8px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-back:hover {
		background: #334155;
		color: #e2e8f0;
	}

	.spinner {
		display: inline-block;
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.2);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
