<script lang="ts">
	import { t } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	export let user: any;
	export let branch: any;

	let mobileNumber = '';
	let campaignCode = '';
	let step: 'input' | 'validating' | 'selectProduct' | 'claiming' | 'result' = 'input';
	let loading = false;
	let result: any = null;
	let error = '';
	let printDisabled = false;
	let availableProducts: any[] = [];
	let selectedProduct: any = null;
	let validationData: any = null;

	// Helper function to translate error messages from database
	function translateErrorMessage(message: string): string {
		if (!message) return t('coupon.notEligibleForCampaign');
		
		// Check if message contains "reached the maximum number of claims"
		if (message.includes('reached the maximum number of claims')) {
			// Extract the claim count (e.g., "3/3")
			const match = message.match(/\((\d+\/\d+)\)/);
			const claimCount = match ? match[1] : '';
			return `${t('coupon.maxClaimsReached')} ${claimCount ? `(${claimCount})` : ''}`;
		}
		
		// Check for other known error patterns
		if (message.includes('not eligible')) {
			return t('coupon.notEligibleForCampaign');
		}
		
		// Default: return translated generic message
		return t('coupon.notEligibleForCampaign');
	}

	async function validateAndClaim() {
		if (!mobileNumber || !campaignCode) {
			error = 'Please fill in all fields';
			return;
		}

		// Validate mobile format
		if (!/^05\d{8}$/.test(mobileNumber)) {
			error = 'Invalid mobile number format';
			return;
		}

		try {
			loading = true;
			error = '';
			step = 'validating';

			const codeUpper = campaignCode.toUpperCase();

			// Step 1: Validate eligibility using database function
			const { data: validation, error: validationError } = await supabase
				.rpc('validate_coupon_eligibility', {
					p_campaign_code: codeUpper,
					p_mobile_number: mobileNumber
				});

		if (validationError) {
			throw new Error(validationError.message);
		}

		if (!validation?.eligible) {
			result = {
				eligible: false,
				message: translateErrorMessage(validation?.error_message || '')
			};
			step = 'result';
			return;
		}

			// Store validation data for later use
			validationData = validation;

			// Step 2: Load all available products from campaign
			const { data: products, error: productError } = await supabase
				.from('coupon_products')
				.select('*')
				.eq('campaign_id', validation.campaign_id)
				.eq('is_active', true)
				.gt('stock_remaining', 0)
				.order('product_name_en');

			if (productError) {
				throw new Error(productError.message);
			}

			if (!products || products.length === 0) {
				throw new Error('No products with stock available for this campaign');
			}

			// Filter out any products with zero or negative stock (extra safety check)
			availableProducts = products.filter(p => p.stock_remaining > 0);
			
			if (availableProducts.length === 0) {
				throw new Error('All products are out of stock');
			}

			step = 'selectProduct';
		} catch (err: any) {
			console.error('Validation error:', err);
			error = err.message || 'Failed to validate coupon';
			step = 'input';
		} finally {
			loading = false;
		}
	}

	async function claimSelectedProduct() {
		if (!selectedProduct || !validationData) return;

		try {
			loading = true;
			step = 'claiming';

			// Claim the coupon with selected product
			const { data: claim, error: claimError } = await supabase
				.rpc('claim_coupon', {
					p_campaign_id: validationData.campaign_id,
					p_mobile_number: mobileNumber,
					p_product_id: selectedProduct.id,
					p_branch_id: branch.id,
					p_user_id: user.id
				});

			if (claimError) {
				throw new Error(claimError.message);
			}

			if (!claim?.success) {
				throw new Error(translateErrorMessage(claim?.error_message || ''));
			}

			// Success!
			result = {
				eligible: true,
				campaign_name: validationData.campaign_name,
				product: {
					name_en: selectedProduct.product_name_en,
					name_ar: selectedProduct.product_name_ar,
					barcode: selectedProduct.special_barcode,
					original_price: selectedProduct.original_price,
					offer_price: selectedProduct.offer_price,
					image_url: selectedProduct.product_image_url
				},
				claim_id: claim.claim_id,
				validity_date: claim.validity_date
			};

			step = 'result';
		} catch (err: any) {
			console.error('Claim error:', err);
			error = err.message || 'Failed to claim coupon';
			step = 'selectProduct';
		} finally {
			loading = false;
		}
	}

	function resetForm() {
		mobileNumber = '';
		campaignCode = '';
		step = 'input';
		result = null;
		error = '';
		printDisabled = false;
		availableProducts = [];
		selectedProduct = null;
		validationData = null;
	}

	function printReceipt() {
		// Disable print button
		printDisabled = true;
		
		// Create a new window with thermal receipt format
		const printWindow = window.open('', '_blank', 'width=300,height=600');
		if (!printWindow) {
			printDisabled = false;
			return;
		}

		const cashierName = user?.full_name || user?.email || 'Staff';
		const receiptHtml = `
			<!DOCTYPE html>
			<html>
			<head>
				<meta charset="UTF-8">
				<title>Coupon Receipt</title>
				<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.5/dist/JsBarcode.all.min.js"><\/script>
				<style>
					@media print {
						@page {
							size: 80mm auto;
							margin: 0;
						}
						body {
							margin: 0;
							padding: 0;
						}
					}
					body {
						font-family: 'Courier New', monospace;
						width: 80mm;
						margin: 0 auto;
						padding: 5mm;
						background: white;
						color: black;
						font-weight: bold;
					}
					.receipt {
						text-align: center;
					}
					.divider {
						border-top: 2px dashed #000;
						margin: 10px 0;
					}
					.solid-divider {
						border-top: 2px solid #000;
						margin: 10px 0;
					}
					h1 {
						font-size: 20px;
						margin: 10px 0;
						font-weight: bold;
					}
					h1.english {
						font-size: 14px;
					}
					h2 {
						font-size: 16px;
						margin: 8px 0;
						font-weight: bold;
					}
					.product-image {
						max-width: 40mm;
						max-height: 40mm;
						height: auto;
						margin: 10px auto;
						object-fit: contain;
					}
					.price-line {
						display: flex;
						justify-content: space-between;
						font-size: 14px;
						margin: 5px 0;
					}
					.savings {
						font-size: 18px;
						font-weight: bold;
						margin: 10px 0;
					}
					.barcode-section {
						margin: 15px 0;
						text-align: center;
						padding: 10px 0;
						background: white;
					}
					svg {
						max-width: 70mm;
						height: 50px;
						margin: 5px auto;
						display: block;
					}
					.barcode-number {
						font-size: 16px;
						font-weight: bold;
						letter-spacing: 2px;
						margin-top: 8px;
						font-family: 'Courier New', monospace;
					}
					.info-line {
						text-align: left;
						font-size: 12px;
						margin: 5px 0;
					}
					.terms {
						font-size: 12px;
						text-align: left;
						line-height: 1.5;
						margin: 10px 0;
					}
					.footer {
						text-align: center;
						font-size: 11px;
						margin-top: 15px;
					}
					.arabic {
						direction: rtl;
						text-align: center;
					}
				</style>
			</head>
			<body>
				<div class="receipt">
					<div class="solid-divider"></div>
					<div style="margin: 15px 0;">
						<img src="/icons/logo.png" style="max-width: 240px; height: auto; margin: 0 auto; display: block;" alt="Aqura Logo">
					</div>
					<h1 class="arabic">🎁 كوبون عرض خاص 🎁</h1>
				<h1 class="english">SPECIAL OFFER COUPON</h1>
				<div class="solid-divider"></div>					${result.product.image_url ? `<img src="${result.product.image_url}" class="product-image" alt="Product">` : ''}
					
					<h2 class="arabic">${result.product.name_ar}</h2>
					<h2>${result.product.name_en}</h2>
					
					<div style="margin: 15px 0;">
						<div class="price-line">
							<span>السعر الأصلي: | Original Price</span>
							<span>SR ${result.product.original_price?.toFixed(2) || '0.00'}</span>
						</div>
						<div class="price-line">
							<span>سعر العرض: | Offer Price</span>
							<span>SR ${result.product.offer_price?.toFixed(2) || '0.00'}</span>
						</div>
						<div class="divider"></div>
						<div class="savings">
							توفر | YOU SAVE: SR ${((result.product.original_price || 0) - (result.product.offer_price || 0)).toFixed(2)} ✨
						</div>
					</div>
					
				<div class="solid-divider"></div>
				<div class="barcode-section">
					<div style="font-size: 11px; margin-bottom: 5px; font-weight: bold;" class="arabic">امسح الباركود عند الدفع</div>
					<div style="font-size: 11px; margin-bottom: 5px; font-weight: bold;">SCAN BARCODE AT CHECKOUT</div>
					<svg id="barcode-${result.product.barcode}"></svg>
					<div class="barcode-number">${result.product.barcode}</div>
				</div>
				<div class="solid-divider"></div>
					<div class="info-line"><strong>العميل | Customer:</strong> ${mobileNumber}</div>
					<div class="info-line"><strong>صالح حتى | Valid Until:</strong> ${new Date().toLocaleDateString('en-GB')}</div>
					<div class="info-line"><strong>الحملة | Campaign:</strong> ${result.campaign_name || campaignCode}</div>
					
					<div class="divider"></div>
					
					<div class="terms">
						<strong>الشروط والأحكام | Terms & Conditions:</strong><br>
						• قدم هذا الكوبون عند الدفع | Present this coupon at checkout<br>
						• صالح لاستخدام واحد فقط | Valid for one-time use only<br>
						• لا يمكن استبداله نقداً | Cannot be exchanged for cash<br>
						• تطبق الشروط حسب الحملة | Terms apply as per campaign<br>
					</div>
					
					<div class="divider"></div>
					
					<div class="footer">
						<strong class="arabic">شكراً لتسوقكم معنا</strong><br>
						<strong>Thank you for shopping with us!</strong><br>
						<br>
						طباعة | Printed: ${new Date().toLocaleString()}<br>
						الكاشير | Cashier: ${cashierName}<br>
					</div>
					
				<div class="solid-divider"></div>
			</div>
			
			<script>
				// Generate barcode using JsBarcode library (loaded from CDN)
				window.onload = function() {
					try {
						if (window.JsBarcode) {
							JsBarcode('#barcode-${result.product.barcode}', '${result.product.barcode}', {
								format: 'CODE128',
								width: 2,
								height: 50,
								displayValue: false,
								margin: 0
							});
						}
					} catch (e) {
						console.error('Barcode generation error:', e);
					}
					
					// Print after barcode is generated
					setTimeout(function() {
						window.print();
						setTimeout(function() {
							window.close();
						}, 100);
					}, 500);
				};
			<\/script>
		</body>
		</html>
	`;		printWindow.document.write(receiptHtml);
		printWindow.document.close();
	}
</script>

<div class="coupon-redemption">
	{#if step === 'input'}
		<!-- Input Form -->
		<div class="redemption-form">
			<div class="form-header">
				<h2>{t('coupon.redeemCoupon') || 'Redeem Coupon'}</h2>
				<p>{t('coupon.enterDetailsToValidate') || 'Enter customer details to validate and claim coupon'}</p>
			</div>

			{#if error}
				<div class="error-message">
					⚠️ {error}
				</div>
			{/if}

		<form on:submit|preventDefault={validateAndClaim} autocomplete="off">
			<div class="form-group">
				<label for="mobile">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/>
						<line x1="12" y1="18" x2="12.01" y2="18"/>
					</svg>
					{t('customer.mobileNumber') || 'Customer Mobile Number'}
				</label>
				<input
					id="mobile"
					name="mobile"
					type="tel"
					bind:value={mobileNumber}
					placeholder="05XXXXXXXX"
					pattern="05\d{'{8}'}"
					maxlength="10"
					required
					autofocus
					disabled={loading}
					autocomplete="off"
				/>
				<small>{t('coupon.saudiMobileFormat') || 'Format: 05XXXXXXXX (10 digits)'}</small>
			</div>

			<div class="form-group">
				<label for="campaign">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/>
						<line x1="7" y1="7" x2="7.01" y2="7"/>
					</svg>
					{t('coupon.campaignCode') || 'Campaign Code'}
				</label>
				<input
					id="campaign"
					name="campaign"
					type="text"
					bind:value={campaignCode}
					placeholder="AB1234"
					pattern="[A-Za-z]{'{2}'}[0-9]{'{4}'}"
					maxlength="6"
					required
					disabled={loading}
					autocomplete="off"
					style="text-transform: uppercase;"
				/>
				<small>{t('coupon.campaignCodeFormat') || 'Format: 2 letters + 4 numbers (e.g., AB1234)'}</small>
			</div>				<button type="submit" class="validate-btn" disabled={loading}>
					{#if loading}
						<span class="spinner"></span>
						{t('common.validating') || 'Validating...'}
					{:else}
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"/>
						</svg>
						{t('coupon.validateAndClaim') || 'Validate & Claim'}
					{/if}
				</button>
			</form>

			<!-- Instructions -->
			<div class="instructions">
				<h3>{t('coupon.instructions') || 'Instructions'}</h3>
				<ul>
					<li>{t('coupon.instruction1') || 'Enter customer mobile number (10 digits starting with 05)'}</li>
					<li>{t('coupon.instruction2') || 'Enter the campaign code provided by management'}</li>
					<li>{t('coupon.instruction3') || 'Click Validate & Claim to check eligibility'}</li>
				<li>{t('coupon.instruction4') || 'If eligible, select a product from the available options'}</li>
					<li>{t('coupon.instruction5') || 'Print the receipt and give the product to customer'}</li>
				</ul>
			</div>
		</div>

	{:else if step === 'validating'}
		<!-- Validating State -->
		<div class="validating-state">
			<div class="spinner-large"></div>
			<h2>{t('common.validating') || 'Validating...'}</h2>
			<p>{t('coupon.checkingEligibility') || 'Checking customer eligibility'}</p>
		</div>

	{:else if step === 'selectProduct'}
		<!-- Product Selection State -->
		<div class="product-selection">
			<div class="selection-header">
				<h2>{t('coupon.selectProduct') || 'Select Product'}</h2>
				<p>{t('coupon.chooseProductForCustomer') || 'Choose a product to give to the customer'}</p>
				{#if validationData?.campaign_name}
					<p class="campaign-name">{validationData.campaign_name}</p>
				{/if}
			</div>

			{#if error}
				<div class="error-message">
					⚠️ {error}
				</div>
			{/if}

			<div class="products-grid">
				{#each availableProducts.filter(p => p.stock_remaining > 0) as product}
					<div 
						class="product-option" 
						class:selected={selectedProduct?.id === product.id}
						class:low-stock={product.stock_remaining <= 5}
						on:click={() => selectedProduct = product}
						on:keydown={(e) => e.key === 'Enter' && (selectedProduct = product)}
						role="button"
						tabindex="0"
					>
						{#if product.product_image_url}
							<img src={product.product_image_url} alt={product.product_name_en} class="product-thumb" />
						{:else}
							<div class="product-thumb-placeholder">🎁</div>
						{/if}
						<div class="product-info">
							<h3>{product.product_name_en}</h3>
							<h4>{product.product_name_ar}</h4>
							{#if product.original_price && product.offer_price}
								<div class="product-pricing">
									<span class="original-price">{product.original_price.toFixed(2)} SAR</span>
									<span class="offer-price">{product.offer_price.toFixed(2)} SAR</span>
								</div>
							{/if}
							<div class="stock-info" class:low-stock-badge={product.stock_remaining <= 5}>
								{t('coupon.stockRemaining') || 'Stock'}: {product.stock_remaining}
								{#if product.stock_remaining <= 5}
									⚠️
								{/if}
							</div>
						</div>
						{#if selectedProduct?.id === product.id}
							<div class="selected-badge">✓</div>
						{/if}
					</div>
				{/each}
			</div>

			<div class="selection-actions">
				<button class="cancel-btn" on:click={resetForm}>
					{t('common.cancel') || 'Cancel'}
				</button>
				<button 
					class="confirm-btn" 
					on:click={claimSelectedProduct}
					disabled={!selectedProduct || loading}
				>
					{#if loading}
						<span class="spinner"></span>
						{t('common.processing') || 'Processing...'}
					{:else}
						{t('coupon.confirmSelection') || 'Confirm Selection'}
					{/if}
				</button>
			</div>
		</div>

	{:else if step === 'claiming'}
		<!-- Claiming State -->
		<div class="validating-state">
			<div class="spinner-large"></div>
			<h2>{t('coupon.claiming') || 'Claiming Coupon...'}</h2>
			<p>{t('coupon.processingClaim') || 'Processing your claim, please wait'}</p>
		</div>

	{:else if step === 'result'}
		<!-- Result State -->
		<div class="result-state">
			{#if result?.eligible}
				<div class="success-result">
					<div class="success-icon">✅</div>
					<h2>{t('coupon.eligible') || 'Eligible!'}</h2>
					<p>{t('coupon.customerIsEligible') || 'Customer is eligible for this campaign'}</p>
					{#if result.campaign_name}
						<p class="campaign-name">{result.campaign_name}</p>
					{/if}

					<div class="product-card">
						{#if result.product.image_url}
							<img src={result.product.image_url} alt={result.product.name_en} class="product-image" />
						{:else}
							<div class="product-icon">🎁</div>
						{/if}
						<div class="product-details">
							<h3>{result.product.name_en}</h3>
							<h4>{result.product.name_ar}</h4>
							{#if result.product.original_price && result.product.offer_price}
								<div class="product-prices">
									<span class="original-price">{result.product.original_price.toFixed(2)} SAR</span>
									<span class="offer-price">{result.product.offer_price.toFixed(2)} SAR</span>
									<span class="savings">Save {(result.product.original_price - result.product.offer_price).toFixed(2)} SAR</span>
								</div>
							{/if}
							<div class="barcode">{t('coupon.barcode') || 'Barcode'}: {result.product.barcode}</div>
						</div>
					</div>

					<div class="action-buttons">
						<button class="print-btn" on:click={printReceipt} disabled={printDisabled}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="6 9 6 2 18 2 18 9"/>
								<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
								<rect x="6" y="14" width="12" height="8"/>
							</svg>
							{printDisabled ? (t('common.printed') || 'Printed') : (t('common.print') || 'Print Receipt')}
						</button>
						<button class="new-btn" on:click={resetForm}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="12" y1="5" x2="12" y2="19"/>
								<line x1="5" y1="12" x2="19" y2="12"/>
							</svg>
							{t('coupon.newRedemption') || 'New Redemption'}
						</button>
					</div>
				</div>
			{:else}
			<div class="error-result">
				<div class="error-icon">❌</div>
				<h2>{t('coupon.notEligible') || 'Not Eligible'}</h2>
				<p>{result?.message || t('coupon.notEligibleForCampaign')}</p>

				<button class="retry-btn" on:click={resetForm}>
					{t('common.tryAgain') || 'Try Again'}
				</button>
			</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.coupon-redemption {
		width: 100%;
		height: 100%;
		padding: 2rem;
		overflow-y: auto;
		background: #f9fafb;
	}

	.redemption-form {
		max-width: 600px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		padding: 2rem;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.form-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.form-header h2 {
		font-size: 1.75rem;
		color: #111827;
		margin: 0 0 0.5rem 0;
	}

	.form-header p {
		color: #6b7280;
		margin: 0;
	}

	.error-message {
		background: #fee2e2;
		color: #dc2626;
		padding: 1rem;
		border-radius: 8px;
		margin-bottom: 1.5rem;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.form-group input {
		width: 100%;
		padding: 0.75rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 1rem;
		transition: border-color 0.2s;
	}

	.form-group input:focus {
		outline: none;
		border-color: #6b7280;
	}

	.form-group input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.form-group small {
		display: block;
		color: #6b7280;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	.validate-btn {
		width: 100%;
		padding: 1rem;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1.05rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.validate-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(75, 85, 99, 0.3);
	}

	.validate-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.instructions {
		margin-top: 2rem;
		padding: 1.5rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.instructions h3 {
		font-size: 1.1rem;
		color: #111827;
		margin: 0 0 1rem 0;
	}

	.instructions ul {
		margin: 0;
		padding-left: 1.5rem;
		color: #4b5563;
	}

	.instructions li {
		margin-bottom: 0.5rem;
		line-height: 1.5;
	}

	.validating-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		text-align: center;
	}

	.spinner-large {
		width: 64px;
		height: 64px;
		border: 4px solid #e5e7eb;
		border-top: 4px solid #4b5563;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 2rem;
	}

	.result-state {
		max-width: 600px;
		margin: 0 auto;
	}

	.success-result,
	.error-result {
		background: white;
		border-radius: 12px;
		padding: 3rem 2rem;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		text-align: center;
	}

	.success-icon,
	.error-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.success-result h2 {
		font-size: 2rem;
		color: #059669;
		margin: 0 0 0.5rem 0;
	}

	.error-result h2 {
		font-size: 2rem;
		color: #dc2626;
		margin: 0 0 0.5rem 0;
	}

	.success-result p,
	.error-result p {
		color: #6b7280;
		margin: 0 0 2rem 0;
	}

	.product-card {
		background: #f9fafb;
		border-radius: 12px;
		padding: 2rem;
		margin: 2rem 0;
		display: flex;
		align-items: center;
		gap: 1.5rem;
	}

	.product-icon {
		font-size: 3rem;
	}

	.product-image {
		width: 120px;
		height: 120px;
		object-fit: contain;
		border-radius: 8px;
	}

	.product-details {
		flex: 1;
		text-align: left;
	}

	.product-details h3 {
		font-size: 1.25rem;
		color: #111827;
		margin: 0 0 0.25rem 0;
	}

	.product-details h4 {
		font-size: 1.1rem;
		color: #6b7280;
		margin: 0 0 0.75rem 0;
	}

	.campaign-name {
		font-size: 0.95rem;
		color: #059669;
		font-weight: 600;
		margin-bottom: 1rem;
	}

	.product-prices {
		display: flex;
		gap: 1rem;
		align-items: center;
		margin-bottom: 0.75rem;
		flex-wrap: wrap;
	}

	.original-price {
		text-decoration: line-through;
		color: #9ca3af;
		font-size: 0.95rem;
	}

	.offer-price {
		color: #059669;
		font-size: 1.25rem;
		font-weight: 700;
	}

	.savings {
		background: #dcfce7;
		color: #16a34a;
		padding: 0.25rem 0.75rem;
		border-radius: 4px;
		font-size: 0.85rem;
		font-weight: 600;
	}

	.barcode {
		font-family: 'Courier New', monospace;
		font-size: 1rem;
		color: #4b5563;
		padding: 0.5rem 1rem;
		background: white;
		border-radius: 4px;
		display: inline-block;
	}

	.action-buttons {
		display: flex;
		gap: 1rem;
	}

	.print-btn,
	.new-btn,
	.retry-btn {
		flex: 1;
		padding: 1rem;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.print-btn {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		color: white;
	}

	.print-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		opacity: 0.7;
	}

	.print-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(5, 150, 105, 0.3);
	}

	.new-btn {
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
	}

	.retry-btn {
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		width: 100%;
	}

	.print-btn:hover:not(:disabled),
	.new-btn:hover,
	.retry-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(0, 0, 0, 0.2);
	}

	/* Product Selection Styles */
	.product-selection {
		max-width: 1200px;
		margin: 0 auto;
	}

	.selection-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.selection-header h2 {
		font-size: 1.75rem;
		color: #111827;
		margin: 0 0 0.5rem 0;
	}

	.selection-header p {
		color: #6b7280;
		margin: 0.25rem 0;
	}

	.products-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
		max-height: 500px;
		overflow-y: auto;
		padding: 0.5rem;
	}

	.product-option {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		cursor: pointer;
		transition: all 0.2s;
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
	}

	.product-option:hover {
		border-color: #4b5563;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		transform: translateY(-2px);
	}

	.product-option.selected {
		border-color: #059669;
		background: #f0fdf4;
		box-shadow: 0 4px 12px rgba(5, 150, 105, 0.2);
	}

	.product-thumb,
	.product-thumb-placeholder {
		width: 120px;
		height: 120px;
		object-fit: contain;
		border-radius: 8px;
		margin-bottom: 1rem;
	}

	.product-thumb-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		font-size: 3rem;
	}

	.product-info {
		width: 100%;
	}

	.product-info h3 {
		font-size: 1.1rem;
		color: #111827;
		margin: 0 0 0.25rem 0;
		font-weight: 600;
	}

	.product-info h4 {
		font-size: 0.95rem;
		color: #6b7280;
		margin: 0 0 0.75rem 0;
		font-weight: 400;
	}

	.product-pricing {
		display: flex;
		gap: 0.75rem;
		align-items: center;
		justify-content: center;
		margin-bottom: 0.5rem;
	}

	.product-pricing .original-price {
		text-decoration: line-through;
		color: #9ca3af;
		font-size: 0.9rem;
	}

	.product-pricing .offer-price {
		color: #059669;
		font-size: 1.1rem;
		font-weight: 700;
	}

	.stock-info {
		font-size: 0.85rem;
		color: #6b7280;
		background: #f9fafb;
		padding: 0.25rem 0.75rem;
		border-radius: 4px;
		display: inline-block;
	}

	.stock-info.low-stock-badge {
		background: #fef3c7;
		color: #92400e;
		font-weight: 600;
	}

	.product-option.low-stock {
		border-color: #fbbf24;
	}

	.selected-badge {
		position: absolute;
		top: 10px;
		right: 10px;
		background: #059669;
		color: white;
		width: 30px;
		height: 30px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.2rem;
		font-weight: bold;
	}

	.selection-actions {
		display: flex;
		gap: 1rem;
		justify-content: center;
	}

	.cancel-btn,
	.confirm-btn {
		padding: 1rem 2rem;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		transition: all 0.2s;
	}

	.cancel-btn {
		background: #f3f4f6;
		color: #374151;
	}

	.cancel-btn:hover {
		background: #e5e7eb;
	}

	.confirm-btn {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		color: white;
	}

	.confirm-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(5, 150, 105, 0.3);
	}

	.confirm-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	@media print {
		.action-buttons {
			display: none;
		}
	}
</style>
