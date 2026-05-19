<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { _, currentLocale, switchLocale } from '$lib/i18n';
	import { sanitizeText } from '$lib/utils/sanitize';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let cardNumber = $page.url.searchParams.get('cardNumber') || '';
	let cardDataArray: any[] = [];
	let locale = 'en';

	async function loadCardData() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Fetch all branches for this card
			const { data: branchDataArray, error: cardError } = await supabase
				.from('privilege_cards_branch')
				.select('*')
				.eq('card_number', cardNumber);

			if (cardError) {
				console.error('Error loading card data:', cardError);
				return;
			}

			if (!branchDataArray || branchDataArray.length === 0) {
				console.error('No card data found');
				return;
			}

			// Process each branch to get branch names
			const processedData = await Promise.all(branchDataArray.map(async (cardDataResult) => {
				if (cardDataResult && cardDataResult.branch_id) {
					// The privilege_cards_branch.branch_id is actually the erp_branch_id
					// So we need to find the erp_connections record with this erp_branch_id
					const { data: erpData, error: erpError } = await supabase
						.from('erp_connections')
						.select('branch_id')
						.eq('erp_branch_id', cardDataResult.branch_id)
						.maybeSingle();

					if (erpData && erpData.branch_id) {
						// Always fetch from branches table to get the language-specific name
						const { data: branchData, error: branchError } = await supabase
							.from('branches')
							.select('name_en, name_ar, location_en, location_ar')
							.eq('id', erpData.branch_id)
							.maybeSingle();

						if (branchData) {
							// Select the name and location based on current locale
							let branchName = locale === 'ar' ? branchData.name_ar : branchData.name_en;
							const branchLocation = locale === 'ar' ? branchData.location_ar : branchData.location_en;
							if (branchName) {
								// Sanitize the branch name to remove offensive content
								branchName = sanitizeText(branchName);
								cardDataResult.branch_name = branchLocation
									? `${branchName} - ${branchLocation}`
									: branchName;
							}
						}
					}
				}
				return cardDataResult;
			}));

			console.log('📦 Final card data:', processedData);
			cardDataArray = processedData;
		} catch (error) {
			console.error('Error:', error);
		}
	}

	$: if (cardNumber && locale) {
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

	{#if cardDataArray && cardDataArray.length > 0}
		<div class="card-container">
			<!-- Card Header (Shared) -->
			<div class="loyalty-card">
				<div class="card-header">
					<div class="card-title"></div>
					<div class="card-icons">
						<div class="app-logo">
							<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura Logo" />
						</div>
					</div>
				</div>

				<div class="card-body">
					<!-- Card Number (Show Once) -->
					<div class="card-number-section">
						<span class="label">{$_('customer.login.cardNumber') || 'Card Number'}</span>
						<span class="card-number font-mono">{convertToLocaleNumbers(maskCardNumber(cardDataArray[0].card_number))}</span>
					</div>
				</div>
			</div>

			<!-- Branch Details (One Card per Branch) -->
			{#each cardDataArray as cardData (cardData.id)}
				<div class="loyalty-card">
					<div class="card-header">
						<div class="card-title">
							<h2>{$_('customer.login.branchDetails') || 'Branch Details'}</h2>
							{#if cardData.branch_name}
							<p class="branch-title" title={cardData.branch_name}>{cardData.branch_name}</p>
							{/if}
						</div>
					</div>

					<div class="card-body">
						<!-- Main Balance Focus -->
						<div class="balance-section">
							<div class="balance-content">
								<span class="balance-label">{$_('customer.login.availableBalance') || 'Available Balance'}</span>
								<span class="balance-amount">{convertToLocaleNumbers(String(cardData.card_balance || 0))}</span>
								<span class="points-label">{$_('customer.login.points') || 'Points'}</span>
							</div>
						</div>

						<!-- Mini Stat Cards Grid -->
						<div class="stats-grid">
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.totalRedemptions') || 'Total Redemptions'}</span>
								<span class="stat-value">{convertToLocaleNumbers(String(cardData.total_redemptions || 0))}</span>
							</div>
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.redemptionCount') || 'Redemption Count'}</span>
								<span class="stat-value">{convertToLocaleNumbers(String(cardData.redemption_count || 0))}</span>
							</div>
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.lastSyncAt') || 'Last Updated'}</span>
								<span class="stat-value-small">{cardData.last_sync_at ? formatDateWithTime(cardData.last_sync_at) : 'N/A'}</span>
							</div>
						</div>
					</div>

					<div class="card-footer">
						<p>{$_('customer.login.loyaltyCardFooter') || 'Thank you for being a valued member'}</p>
					</div>
				</div>
			{/each}
		</div>
	{:else}
		<div class="loading">
			<p>{$_('common.loading') || 'Loading...'}</p>
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

