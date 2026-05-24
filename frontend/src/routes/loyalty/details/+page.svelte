<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { _, currentLocale, switchLocale } from '$lib/i18n';
	import { sanitizeText } from '$lib/utils/sanitize';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let cardNumber = $page.url.searchParams.get('cardNumber') || '';
	let locale = 'en';

	interface CustomerData {
		card_number: string;
		final_loyalty_point_balance: number;
		loyalty_total_purchases: number;
		updated_at: string;
		name: string;
		tier_name: string;
		tier_name_ar: string;
		tier_color: string;
		min_redeem_points: number;
		tier_purchase_from: number;
		tier_purchase_to: number | null;
		next_tier_name: string;
		next_tier_name_ar: string;
		next_tier_color: string;
		next_tier_purchase_from: number | null;
	}
	let customerData: CustomerData | null = null;
	let loadError = '';
	let loading = true;

	async function loadCardData() {
		loading = true;
		loadError = '';
		customerData = null;
		try {
			const { supabase } = await import('$lib/utils/supabase');

			// Get mobile from privilege_cards_branch using card_number
			const { data: cardRow, error: cardError } = await supabase
				.from('privilege_cards_branch')
				.select('mobile, card_number')
				.eq('card_number', cardNumber)
				.not('mobile', 'is', null)
				.limit(1)
				.maybeSingle();

			if (cardError) throw cardError;
			if (!cardRow || !cardRow.mobile) {
				loadError = 'Card not found';
				return;
			}

			// Look up customer by mobile
			const { data: customer, error: custError } = await supabase
				.from('customers')
				.select('name, final_loyalty_point_balance, loyalty_total_purchases, updated_at, loyalty_tier_id, loyalty_tier_name, loyalty_tier_name_ar')
				.eq('whatsapp_number', cardRow.mobile)
				.eq('is_deleted', false)
				.maybeSingle();

			if (custError) throw custError;

			// Fetch current tier details
			let tierColor = '#94a3b8';
			let minRedeemPoints = 5;
			let tierPurchaseFrom = 0;
			let tierPurchaseTo: number | null = null;
			let tierSortOrder = 1;
			if (customer?.loyalty_tier_id) {
				const { data: tier } = await supabase
					.from('loyalty_tiers')
					.select('color, min_redeem_points, total_purchase_from, total_purchase_to, sort_order')
					.eq('id', customer.loyalty_tier_id)
					.maybeSingle();
				if (tier) {
					tierColor = tier.color ?? tierColor;
					minRedeemPoints = tier.min_redeem_points ?? minRedeemPoints;
					tierPurchaseFrom = Number(tier.total_purchase_from ?? 0);
					tierPurchaseTo = tier.total_purchase_to ? Number(tier.total_purchase_to) : null;
					tierSortOrder = tier.sort_order ?? 1;
				}
			}

			// Fetch next tier
			let nextTierName = '';
			let nextTierNameAr = '';
			let nextTierColor = '#e2e8f0';
			let nextTierPurchaseFrom: number | null = null;
			const { data: nextTier } = await supabase
				.from('loyalty_tiers')
				.select('name, name_ar, color, total_purchase_from')
				.eq('is_active', true)
				.eq('sort_order', tierSortOrder + 1)
				.maybeSingle();
			if (nextTier) {
				nextTierName = nextTier.name ?? '';
				nextTierNameAr = nextTier.name_ar ?? '';
				nextTierColor = nextTier.color ?? nextTierColor;
				nextTierPurchaseFrom = nextTier.total_purchase_from ? Number(nextTier.total_purchase_from) : null;
			}

			customerData = {
				card_number: cardRow.card_number,
				final_loyalty_point_balance: customer?.final_loyalty_point_balance ?? 0,
				loyalty_total_purchases: Number(customer?.loyalty_total_purchases ?? 0),
				updated_at: customer?.updated_at ?? '',
				name: customer?.name ?? '',
				tier_name: customer?.loyalty_tier_name ?? '',
				tier_name_ar: customer?.loyalty_tier_name_ar ?? '',
				tier_color: tierColor,
				min_redeem_points: minRedeemPoints,
				tier_purchase_from: tierPurchaseFrom,
				tier_purchase_to: tierPurchaseTo,
				next_tier_name: nextTierName,
				next_tier_name_ar: nextTierNameAr,
				next_tier_color: nextTierColor,
				next_tier_purchase_from: nextTierPurchaseFrom,
			};
		} catch (error: any) {
			loadError = error?.message || 'Failed to load card data';
		} finally {
			loading = false;
		}
	}

	function getTierGradient(color: string): string {
		// Create a rich gradient from the tier color
		return `linear-gradient(135deg, ${color}ee 0%, ${color}99 50%, ${color}cc 100%)`;
	}

	function lightenColor(hex: string): string {
		// Return a slightly transparent version for shine effect
		return hex + '33';
	}

	$: if (cardNumber) {
		loadCardData();
	}

	$: locale = $currentLocale;

	function convertToLocaleNumbers(value: string): string {
		if (locale === 'ar') {
			const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
			return value.replace(/\d/g, (digit) => arabicDigits[parseInt(digit)]);
		}
		return value;
	}

	function formatCardNumber(cardNum: string): string {
		// Format card number with spacing: 0500 4915 49
		return cardNum.replace(/(\d{4})/g, '$1 ').trim();
	}

	function maskCardNumber(cardNum: string): string {
		// Show only last 4 digits, mask the rest with stars
		// e.g., 0500491549 -> **** **** 49
		if (cardNum.length <= 4) return cardNum;
		const lastFour = cardNum.slice(-4);
		const masked = '*'.repeat(cardNum.length - 4) + lastFour;
		return formatCardNumber(masked);
	}

	function formatDateWithTime(dateString: string): string {
		const date = new Date(dateString);
		let day = String(date.getDate()).padStart(2, '0');
		let month = String(date.getMonth() + 1).padStart(2, '0');
		let year = String(date.getFullYear());
		const time = date.toLocaleTimeString(locale === 'ar' ? 'ar-SA' : 'en-US');
		
		let formattedDate = `${day}/${month}/${year} ${time}`;
		
		// Convert to Arabic numerals if in Arabic locale
		if (locale === 'ar') {
			const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
			formattedDate = formattedDate.replace(/\d/g, (digit) => arabicDigits[parseInt(digit)]);
		}
		
		return formattedDate;
	}
	function goBack() {
		const referrerQuery = $page.url.searchParams.get('referrer');
		if (referrerQuery === 'login') {
			goto('/login');
		} else {
			goto('/customer-interface');
		}
	}
</script>

<svelte:head>
	<title>Loyalty Member Details - Aqura Management System</title>
	<meta name="description" content="Loyalty Member Details" />
</svelte:head>

<div class="loyalty-details-page">
	<!-- Ambient floating background shapes -->
	<div class="ambient-bg" aria-hidden="true">
		<div class="ambient-shape shape-1"></div>
		<div class="ambient-shape shape-2"></div>
		<div class="ambient-shape shape-3"></div>
		<div class="ambient-shape shape-4"></div>
	</div>

	<div class="loyalty-header">
		<button type="button" class="back-btn" on:click={goBack} title="Back">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<h1>{$_('customer.login.loyaltyDetails') || 'Loyalty Member Details'}</h1>
		<button 
			type="button" 
			class="language-btn" 
			on:click={() => switchLocale($currentLocale === 'en' ? 'ar' : 'en')}
			title="Toggle Language"
		>
			{$currentLocale === 'en' ? 'العربية' : 'English'}
		</button>
	</div>

	{#if loading}
		<div class="loading">
			<p>{$_('common.loading') || 'Loading...'}</p>
		</div>
	{:else if loadError}
		<div class="loading">
			<p>⚠️ {loadError}</p>
		</div>
	{:else if customerData}
		<div class="card-container">

			<!-- ── Physical Membership Card ─────────────────────────────── -->
			<div
				class="membership-card"
				style="background: {getTierGradient(customerData.tier_color)};"
			>
				<!-- Shine overlay -->
				<div class="mc-shine"></div>
				<!-- Decorative circles -->
				<div class="mc-circle mc-circle--1" style="background: {lightenColor(customerData.tier_color)};"></div>
				<div class="mc-circle mc-circle--2" style="background: {lightenColor(customerData.tier_color)};"></div>

				<div class="mc-top">
					<div class="mc-logo">
						<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura" />
					</div>
					{#if customerData.tier_name}
						<div class="mc-tier-badge">
							{locale === 'ar' && customerData.tier_name_ar ? customerData.tier_name_ar : customerData.tier_name}
						</div>
					{/if}
				</div>

				<div class="mc-middle">
					<div class="mc-chip">
						<div class="mc-chip-lines">
							<div></div><div></div><div></div>
						</div>
					</div>
					<div class="mc-points">
						<span class="mc-points-label">{$_('customer.login.availableBalance') || 'Points Balance'}</span>
						<span class="mc-points-value">{convertToLocaleNumbers(Number(customerData.final_loyalty_point_balance) % 1 === 0 ? Number(customerData.final_loyalty_point_balance).toFixed(0) : Number(customerData.final_loyalty_point_balance).toFixed(2))}</span>
						<span class="mc-points-unit">{$_('customer.login.points') || 'pts'}</span>
					</div>
				</div>

				<div class="mc-bottom">
					<div class="mc-bottom-left">
						<div class="mc-card-number">{convertToLocaleNumbers(maskCardNumber(customerData.card_number))}</div>
						{#if customerData.name}
							<div class="mc-holder">{customerData.name}</div>
						{/if}
					</div>
					<div class="mc-bottom-right">
						<span class="mc-updated-label">{$_('customer.login.lastSyncAt') || 'Last Updated'}</span>
						<span class="mc-updated-value">{customerData.updated_at ? formatDateWithTime(customerData.updated_at) : 'N/A'}</span>
					</div>
				</div>
			</div>

			<!-- ── Redemption Pipeline ───────────────────────────────────── -->
			{#if customerData}
				{@const pts = Number(customerData.final_loyalty_point_balance)}
				{@const minRedeem = customerData.min_redeem_points}
				{@const canRedeem = pts >= minRedeem}
				{@const redeemPct = Math.min(100, (pts / minRedeem) * 100)}
				{@const purchases = customerData.loyalty_total_purchases}
				{@const tierFrom = customerData.tier_purchase_from}
				{@const tierTo = customerData.tier_purchase_to}
				{@const tierPct = tierTo ? Math.min(100, ((purchases - tierFrom) / (tierTo - tierFrom)) * 100) : 100}

				<!-- Card 1: Points Redemption -->
				<div class="rd-card rd-card--redemption">
					<div class="rd-card-header">
						<span class="rd-card-title">{$_('customer.login.availableBalance') || 'Points Balance'}</span>
						<span class="rd-badge" class:rd-badge--green={canRedeem} class:rd-badge--red={!canRedeem}>
							{canRedeem ? ($_('customer.login.rdCanRedeem') || 'Ready') : ($_('customer.login.rdNeed') || 'Need') + ` ${(minRedeem - pts).toFixed(2)} ${$_('customer.login.rdMorePts') || 'more pts'}`}
						</span>
					</div>
					<div class="rd-track">
						<div class="rd-fill" style="width: {redeemPct}%;"></div>
						<div class="rd-marker" style="left: {redeemPct}%;"></div>
					</div>
					<div class="rd-label-row">
						<span class="rd-val">{pts % 1 === 0 ? pts.toFixed(0) : pts.toFixed(2)} {$_('customer.login.points') || 'pts'}</span>
						<span class="rd-val rd-val--dim">{$_('customer.login.rdPtsMin') || 'min'}: {minRedeem}</span>
					</div>
				</div>

				<!-- Card 2: Tier Progress -->
				{#if customerData.next_tier_name}
					<div class="rd-card rd-card--tier">
						<div class="rd-card-header">
							<span class="rd-card-title">{$_('customer.login.rdTierProgress') || 'Tier Progress'}</span>
							<span class="rd-tier-label">
								{locale === 'ar' && customerData.tier_name_ar ? customerData.tier_name_ar : customerData.tier_name}
								→
								{locale === 'ar' && customerData.next_tier_name_ar ? customerData.next_tier_name_ar : customerData.next_tier_name}
							</span>
						</div>
						<div class="rd-track rd-track--tier">
							<div class="rd-fill rd-fill--tier" style="width: {tierPct}%;"></div>
							<div class="rd-marker rd-marker--tier" style="left: {tierPct}%;"></div>
							<div class="rd-beacon"></div>
						</div>
						<div class="rd-label-row">
							<span class="rd-val">{tierPct.toFixed(1)}%</span>
							<span class="rd-val rd-val--dim">{(100 - tierPct).toFixed(1)}% {$_('customer.login.rdToGo') || 'to go'}</span>
						</div>
					</div>
				{/if}

			{/if}

		</div>
	{/if}
</div>

<style>
	/* ── Brand Variables ──────────────────────────────────────────────────── */
	:root {
		--brand-green: #10b981;
		--brand-green-light: #34d399;
		--brand-orange: #f97316;
		--brand-orange-light: #fb923c;
		--brand-pink: #ec4899;
		--brand-pink-light: #f472b6;
		--brand-lavender: #8b5cf6;
		--brand-lavender-light: #a78bfa;
		--bg-offwhite: #f1f5f9;
	}

	/* ── RTL Support ──────────────────────────────────────────────────────── */
	:global(html[dir='rtl']) .loyalty-header,
	:global(html[dir='rtl']) .card-header,
	:global(html[dir='rtl']) .stats-grid {
		direction: rtl;
		text-align: right;
	}

	/* ── Page Root ────────────────────────────────────────────────────────── */
	.loyalty-details-page {
		position: relative;
		min-height: 100vh;
		background: var(--bg-offwhite);
		padding: 1rem;
		padding-top: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
		overflow-x: hidden;
	}

	/* ── Ambient Floating Background ──────────────────────────────────────── */
	.ambient-bg {
		position: fixed;
		inset: 0;
		pointer-events: none;
		z-index: 0;
		overflow: hidden;
	}

	.ambient-shape {
		position: absolute;
		filter: blur(80px);
		opacity: 0.35;
		border-radius: 50%;
	}

	.shape-1 { width: 350px; height: 350px; background: var(--brand-orange-light); top: -100px; right: -50px; animation: drift 20s ease-in-out infinite alternate; }
	.shape-2 { width: 300px; height: 300px; background: var(--brand-pink-light); top: 30%; left: -100px; animation: drift 25s ease-in-out infinite alternate-reverse; }
	.shape-3 { width: 400px; height: 400px; background: var(--brand-lavender-light); bottom: -100px; right: 10%; animation: drift 22s ease-in-out infinite alternate; }
	.shape-4 { width: 300px; height: 300px; background: var(--brand-green-light); top: 55%; right: -50px; animation: drift 18s ease-in-out infinite alternate-reverse; }

	@keyframes drift {
		0%   { transform: translate(0, 0) scale(1) rotate(0deg); }
		100% { transform: translate(50px, 40px) scale(1.1) rotate(15deg); }
	}

	/* ── Header Bar ───────────────────────────────────────────────────────── */
	.loyalty-header {
		position: relative;
		z-index: 10;
		display: flex;
		align-items: center;
		gap: 1rem;
		background: rgba(255, 255, 255, 0.75);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		padding: 1.25rem 1.5rem;
		border-radius: 24px;
		border: 1px solid rgba(255, 255, 255, 0.85);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.06);
		max-width: 600px;
		margin: 0 auto;
		width: 100%;
		box-sizing: border-box;
	}

	.loyalty-header h1 {
		flex: 1;
		margin: 0;
		font-size: 1.25rem;
		font-weight: 800;
		color: #1e293b;
		text-align: center;
	}

	/* ── Back Button ──────────────────────────────────────────────────────── */
	.back-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		min-width: 40px;
		padding: 0;
		background: rgba(241, 245, 249, 0.9);
		border: 1px solid rgba(226, 232, 240, 0.8);
		color: #374151;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
		touch-action: manipulation;
	}

	.back-btn:hover { background: #e2e8f0; transform: translateY(-1px); }
	.back-btn:active { transform: translateY(0); background: #cbd5e1; }

	/* ── Language Button ──────────────────────────────────────────────────── */
	.language-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.5rem 1.125rem;
		background: linear-gradient(135deg, var(--brand-orange) 0%, var(--brand-orange-light) 100%);
		border: none;
		color: white;
		border-radius: 20px;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
		font-size: 0.85rem;
		font-weight: 700;
		min-height: 40px;
		touch-action: manipulation;
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.3);
	}

	.language-btn:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(249, 115, 22, 0.4); }
	.language-btn:active { transform: translateY(0); }

	/* ── Card Container ───────────────────────────────────────────────────── */
	.card-container {
		position: relative;
		z-index: 10;
		max-width: 600px;
		margin: 0 auto;
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		animation: fadeIn 0.4s ease-out;
		box-sizing: border-box;
	}

	@keyframes fadeIn {
		from { opacity: 0; transform: translateY(12px); }
		to   { opacity: 1; transform: translateY(0); }
	}

	/* ── Loyalty Card ─────────────────────────────────────────────────────── */
	.loyalty-card {
		background: rgba(255, 255, 255, 0.78);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border-radius: 24px;
		overflow: hidden;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.07);
		border: 1px solid rgba(255, 255, 255, 0.85);
		display: flex;
		flex-direction: column;
	}

	/* ── Card Header ──────────────────────────────────────────────────────── */
	.card-header {
		padding: 1.5rem;
		display: flex;
		align-items: center;
		gap: 1.25rem;
		background: linear-gradient(135deg, rgba(249, 250, 251, 0.9) 0%, rgba(241, 245, 249, 0.9) 100%);
		border-bottom: 1px solid rgba(226, 232, 240, 0.7);
	}

	.card-icons { display: flex; align-items: center; gap: 1rem; flex-shrink: 0; }

	.app-logo {
		width: 72px;
		height: 56px;
		background: white;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		padding: 8px;
		box-shadow: 0 8px 24px rgba(16, 185, 129, 0.18);
		border: 2px solid rgba(16, 185, 129, 0.15);
		transition: all 0.3s ease;
	}

	.app-logo:hover { transform: translateY(-3px); box-shadow: 0 12px 30px rgba(16, 185, 129, 0.28); }

	.app-logo img { width: 100%; height: 100%; object-fit: contain; }

	.card-title { flex: 1; }

	.card-title h2 {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 700;
		color: #1e293b;
	}

	.branch-title {
		margin: 0.35rem 0 0;
		font-size: 0.875rem;
		color: #475569;
		font-weight: 500;
		line-height: 1.4;
	}

	/* ── Card Body ────────────────────────────────────────────────────────── */
	.card-body {
		padding: 1.75rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		flex: 1;
	}

	/* ── Card Number ──────────────────────────────────────────────────────── */
	.card-number-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.label {
		font-size: 0.75rem;
		color: #64748b;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.card-number {
		font-size: 1.2rem;
		font-weight: 700;
		letter-spacing: 0.15em;
		color: #1e293b;
	}

	/* ── Balance Section ──────────────────────────────────────────────────── */
	.balance-section {
		background: linear-gradient(135deg, rgba(16, 185, 129, 0.06) 0%, rgba(52, 211, 153, 0.04) 100%);
		padding: 2rem;
		border-radius: 20px;
		border: 2px solid rgba(16, 185, 129, 0.15);
		text-align: center;
		animation: slideDown 0.5s ease-out 0.1s backwards;
	}

	@keyframes slideDown {
		from { opacity: 0; transform: translateY(-10px); }
		to   { opacity: 1; transform: translateY(0); }
	}

	.balance-content { display: flex; flex-direction: column; gap: 0.75rem; }

	.balance-label {
		font-size: 0.8rem;
		color: #64748b;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.balance-amount {
		font-size: 3rem;
		font-weight: 800;
		background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-light) 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		line-height: 1;
	}

	.points-label {
		font-size: 0.9rem;
		color: var(--brand-green);
		font-weight: 700;
	}

	/* ── Stats Grid ───────────────────────────────────────────────────────── */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.875rem;
	}

	.stat-card {
		background: rgba(255, 255, 255, 0.8);
		padding: 1.25rem 0.875rem;
		border-radius: 16px;
		border: 1px solid rgba(226, 232, 240, 0.8);
		display: flex;
		flex-direction: column;
		gap: 0.625rem;
		text-align: center;
		transition: all 0.2s ease;
		animation: slideUp 0.5s ease-out backwards;
		animation-delay: var(--delay, 0.2s);
	}

	.stat-card:nth-child(1) { --delay: 0.15s; }
	.stat-card:nth-child(2) { --delay: 0.2s; }
	.stat-card:nth-child(3) { --delay: 0.25s; }

	@keyframes slideUp {
		from { opacity: 0; transform: translateY(10px); }
		to   { opacity: 1; transform: translateY(0); }
	}

	.stat-card:hover {
		border-color: var(--brand-orange-light);
		box-shadow: 0 4px 16px rgba(249, 115, 22, 0.1);
		transform: translateY(-2px);
	}

	.stat-label {
		font-size: 0.68rem;
		color: #64748b;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.4px;
	}

	.stat-value {
		font-size: 1.5rem;
		font-weight: 800;
		background: linear-gradient(135deg, var(--brand-orange) 0%, var(--brand-orange-light) 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.stat-value-small {
		font-size: 0.78rem;
		color: #1e293b;
		font-weight: 600;
	}

	/* ── Card Footer ──────────────────────────────────────────────────────── */
	.card-footer {
		padding: 1.25rem 1.75rem;
		text-align: center;
		background: linear-gradient(135deg, rgba(16, 185, 129, 0.04) 0%, rgba(52, 211, 153, 0.02) 100%);
		border-top: 1px solid rgba(226, 232, 240, 0.6);
		font-size: 0.85rem;
		color: #64748b;
	}

	.card-footer p { margin: 0; font-weight: 500; line-height: 1.5; }

	/* ── Physical Membership Card ─────────────────────────────────────────── */
	.membership-card {
		position: relative;
		z-index: 10;
		max-width: 600px;
		margin: 0 auto;
		width: 100%;
		aspect-ratio: 1.586 / 1;
		border-radius: 24px;
		padding: 1.5rem;
		box-sizing: border-box;
		display: flex;
		flex-direction: column;
		justify-content: space-between;
		overflow: hidden;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25), 0 8px 20px rgba(0, 0, 0, 0.15);
		animation: fadeIn 0.5s ease-out;
	}

	/* Shine streak */
	.mc-shine {
		position: absolute;
		top: -40%;
		left: -30%;
		width: 80%;
		height: 180%;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.18) 50%, transparent 60%);
		transform: rotate(15deg);
		pointer-events: none;
	}

	/* Decorative circles */
	.mc-circle {
		position: absolute;
		border-radius: 50%;
		pointer-events: none;
	}
	.mc-circle--1 {
		width: 220px;
		height: 220px;
		bottom: -80px;
		right: -60px;
	}
	.mc-circle--2 {
		width: 140px;
		height: 140px;
		top: -50px;
		left: 40%;
	}

	.mc-top {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		position: relative;
		z-index: 2;
	}

	.mc-logo {
		width: 64px;
		height: 44px;
		background: rgba(255,255,255,0.2);
		backdrop-filter: blur(8px);
		border-radius: 12px;
		padding: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 1px solid rgba(255,255,255,0.35);
	}
	.mc-logo img { width: 100%; height: 100%; object-fit: contain; filter: brightness(0) invert(1); }

	.mc-tier-badge {
		background: rgba(255,255,255,0.25);
		backdrop-filter: blur(8px);
		border: 1px solid rgba(255,255,255,0.4);
		color: white;
		font-size: 0.78rem;
		font-weight: 800;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		padding: 5px 14px;
		border-radius: 20px;
	}

	/* Chip */
	/* Middle row: chip + points */
	.mc-middle {
		position: relative;
		z-index: 2;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.mc-chip {
		width: 48px;
		height: 36px;
		background: linear-gradient(135deg, #fde68a, #fbbf24, #f59e0b);
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 2px 8px rgba(0,0,0,0.2);
		flex-shrink: 0;
	}
	.mc-chip-lines {
		display: flex;
		flex-direction: column;
		gap: 4px;
		width: 70%;
	}
	.mc-chip-lines div {
		height: 2px;
		background: rgba(146, 86, 0, 0.4);
		border-radius: 2px;
	}

	/* Points inside card */
	.mc-points {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
	}
	.mc-points-label {
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: rgba(255,255,255,0.75);
	}
	.mc-points-value {
		font-size: 1.8rem;
		font-weight: 800;
		color: white;
		line-height: 1.1;
		text-shadow: 0 2px 8px rgba(0,0,0,0.2);
	}
	.mc-points-unit {
		font-size: 0.7rem;
		font-weight: 600;
		color: rgba(255,255,255,0.7);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	/* Bottom row: number+name left, last-updated right */
	.mc-bottom {
		position: relative;
		z-index: 2;
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
	}
	.mc-bottom-left { display: flex; flex-direction: column; gap: 4px; }
	.mc-bottom-right { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; }

	.mc-updated-label {
		font-size: 0.62rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: rgba(255,255,255,0.65);
	}
	.mc-updated-value {
		font-size: 0.72rem;
		font-weight: 600;
		color: rgba(255,255,255,0.9);
	}

	.mc-card-number {
		font-size: 1.15rem;
		font-weight: 700;
		letter-spacing: 0.18em;
		color: white;
		text-shadow: 0 1px 4px rgba(0,0,0,0.3);
		font-family: 'Courier New', monospace;
		margin-bottom: 6px;
	}
	.mc-holder {
		font-size: 0.85rem;
		font-weight: 600;
		color: rgba(255,255,255,0.85);
		text-transform: uppercase;
		letter-spacing: 0.08em;
	}

	/* ── Redemption Pipeline Cards ────────────────────────────────────────── */
	.rd-card {
		max-width: 600px;
		margin: 0.75rem auto 0;
		width: 100%;
		border-radius: 18px;
		padding: 1rem 1.25rem 1.1rem;
		display: flex;
		flex-direction: column;
		gap: 0.65rem;
		box-sizing: border-box;
		color: white;
		box-shadow: 0 4px 20px rgba(0,0,0,0.12);
	}

	/* Card 1 — orange → pink */
	.rd-card--redemption {
		background: linear-gradient(135deg, #f97316 0%, #ec4899 100%);
	}

	/* Card 2 — lavender → indigo */
	.rd-card--tier {
		background: linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%);
	}

	.rd-card-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		/* inherits RTL/LTR from parent — title on reading-start, badge on reading-end */
	}
	.rd-card-title {
		font-size: 0.72rem;
		font-weight: 800;
		text-transform: uppercase;
		letter-spacing: 0.1em;
		color: rgba(255,255,255,0.75);
	}
	.rd-badge {
		font-size: 0.72rem;
		font-weight: 700;
		padding: 3px 10px;
		border-radius: 20px;
		border: 1px solid rgba(255,255,255,0.4);
		background: rgba(255,255,255,0.15);
		backdrop-filter: blur(4px);
		white-space: nowrap;
	}
	.rd-badge--green { background: rgba(34,197,94,0.3); border-color: #22c55e; }
	.rd-badge--red   { background: rgba(248,113,113,0.25); border-color: #f87171; }

	.rd-tier-label {
		font-size: 0.75rem;
		font-weight: 700;
		color: rgba(255,255,255,0.9);
		letter-spacing: 0.03em;
	}

	/* Track */
	.rd-track {
		position: relative;
		height: 10px;
		background: rgba(255,255,255,0.2);
		border-radius: 99px;
		overflow: visible;
		direction: ltr; /* force LTR so fill always goes left → right */
	}
	.rd-track--tier { background: rgba(255,255,255,0.2); }

	.rd-fill {
		height: 100%;
		border-radius: 99px;
		background: white;
		position: relative;
		transition: width 0.7s cubic-bezier(0.4, 0, 0.2, 1);
	}
	.rd-fill::after {
		content: '';
		position: absolute;
		inset: 0;
		border-radius: 99px;
		background: linear-gradient(180deg, rgba(255,255,255,0.5) 0%, transparent 100%);
	}
	.rd-fill--tier { background: rgba(255,255,255,0.9); }

	/* Marker dot */
	.rd-marker {
		position: absolute;
		top: 50%;
		transform: translate(-50%, -50%);
		width: 16px;
		height: 16px;
		background: white;
		border-radius: 50%;
		border: 3px solid rgba(255,255,255,0.5);
		box-shadow: 0 0 0 3px rgba(255,255,255,0.2);
		z-index: 2;
	}
	.rd-marker--tier { border-color: rgba(255,255,255,0.6); }

	/* Beacon at far right */
	.rd-beacon {
		position: absolute;
		top: 50%;
		right: 0;
		transform: translate(50%, -50%);
		width: 14px;
		height: 14px;
		border-radius: 50%;
		background: rgba(255,255,255,0.5);
		border: 2px solid white;
	}

	.rd-label-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		direction: ltr; /* keep values aligned with the bar (start = left) */
	}
	.rd-val {
		font-size: 0.82rem;
		font-weight: 700;
		color: white;
	}
	.rd-val--dim {
		color: rgba(255,255,255,0.7);
		font-weight: 600;
	}

	/* ── Loading State ────────────────────────────────────────────────────── */
	.loading {
		position: relative;
		z-index: 10;
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		color: #64748b;
		font-size: 1.1rem;
	}

	/* ── Mobile Responsive ────────────────────────────────────────────────── */
	@media (max-width: 768px) {
		.loyalty-details-page {
			padding: 0.75rem;
			padding-top: 1rem;
			gap: 1rem;
		}

		.loyalty-header {
			border-radius: 18px;
			padding: 1rem 1.25rem;
		}

		.card-container { gap: 0.875rem; }

		.loyalty-card { border-radius: 20px; }

		.app-logo { width: 60px; height: 48px; }

		.card-header { padding: 1.25rem; }

		.card-body { padding: 1.5rem; gap: 1.25rem; }

		.balance-amount { font-size: 2.5rem; }

		.stats-grid { gap: 0.625rem; }

		.stat-card { padding: 1rem 0.625rem; border-radius: 14px; }

		.stat-label { font-size: 0.63rem; }

		.stat-value { font-size: 1.25rem; }

		.stat-value-small { font-size: 0.72rem; }

		.card-footer { padding: 1rem 1.5rem; }

		.card-number { font-size: 1.1rem; }

		.branch-title { font-size: 0.8rem; }
	}

	@media (max-width: 480px) {
		.loyalty-details-page { padding: 0.5rem; padding-top: 0.75rem; }

		.loyalty-header {
			border-radius: 14px;
			padding: 0.875rem 1rem;
			flex-wrap: wrap;
		}

		.loyalty-header h1 { font-size: 1.05rem; }

		.back-btn, .language-btn { min-height: 36px; height: 36px; }

		.language-btn { font-size: 0.75rem; padding: 0.4rem 0.875rem; }

		.balance-amount { font-size: 2rem; }

		.balance-section { padding: 1.5rem 1rem; border-radius: 16px; }

		.stats-grid { grid-template-columns: 1fr; gap: 0.5rem; }

		.stat-card { flex-direction: row; justify-content: space-between; align-items: center; text-align: left; padding: 0.875rem 1rem; }

		.stat-value { font-size: 1.25rem; }

		.card-number { font-size: 0.95rem; }
	}

	/* Touch Feedback */
	@media (hover: none) {
		.back-btn:active,
		.language-btn:active,
		.stat-card:active { opacity: 0.8; }
	}
</style>

