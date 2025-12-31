<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/utils/supabase';
	import { _, switchLocale, currentLocale } from '$lib/i18n';

	const dispatch = createEventDispatcher();

	// Props
	export let initialView: 'login' | 'register' | 'forgot' | 'loyalty' = 'login';
	export let showMask: boolean = true;

	// Component states
	let currentView: 'login' | 'register' | 'forgot' | 'loyalty' = initialView;
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Customer login form
	let customerAccessCode = '';
	let customerDigits = ['', '', '', '', '', ''];
	let accessCodeValid = true;
	let rememberDevice = false;

	// Customer registration form
	let customerName = '';
	let whatsappNumber = '';
	let nameValid = true;
	let whatsappValid = true;

	// Forgot access code form
	let forgotWhatsappNumber = '';
	let forgotWhatsappValid = true;
	let retryAfterSeconds = 0;

	// Temporary block access code - set to true to show white mask
	let blockAccessCodeInput = showMask;

	// Loyalty member login form
	let loyaltyMobileNumber = '';
	let loyaltyMobileValid = false;
	let loyaltyCardData: any = null;
	let loyaltyCardChecked = false;

	// Form validation
	function validateAccessCode() {
		customerAccessCode = customerDigits.join('');
		const isNumeric = /^[0-9]+$/.test(customerAccessCode);
		accessCodeValid = customerAccessCode.length === 6 && isNumeric;
		return accessCodeValid;
	}

	function validateName() {
		console.log('🔍 [Validation] Checking name:', customerName);
		nameValid = customerName.trim().length >= 2;
		console.log('🔍 [Validation] Name valid:', nameValid);
		return nameValid;
	}

	function validateWhatsApp() {
		console.log('🔍 [Validation] Checking WhatsApp number:', whatsappNumber);
		// Basic mobile number validation (international format)
		let cleanNumber = whatsappNumber.replace(/\D/g, '');
		console.log('🔍 [Validation] Clean number:', cleanNumber);
		
		// Add country code if not present (assuming Saudi Arabia +966)
		if (!cleanNumber.startsWith('966') && cleanNumber.length >= 8) {
			cleanNumber = '966' + cleanNumber.replace(/^0/, '');
		}
		
		console.log('🔍 [Validation] Clean number with country code:', cleanNumber);
		console.log('🔍 [Validation] Final number length:', cleanNumber.length);
		whatsappValid = cleanNumber.length >= 10 && cleanNumber.length <= 15;
		console.log('🔍 [Validation] WhatsApp valid:', whatsappValid);
		return whatsappValid;
	}

	// Handle customer access code login
	async function handleCustomerLogin() {
		if (!validateAccessCode()) {
			errorMessage = 'Please enter a valid 6-digit access code.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			console.log('🔐 [CustomerLogin] Attempting login with access code:', customerAccessCode);
			const { data, error } = await supabase.rpc('authenticate_customer_access_code', {
				p_access_code: customerAccessCode
			});

			console.log('🔐 [CustomerLogin] RPC response:', { data, error });

			if (error) {
				console.error('❌ [CustomerLogin] RPC error:', error);
				throw error;
			}

			if (data && data.success) {
				console.log('✅ [CustomerLogin] Authentication successful:', data);
				successMessage = 'Welcome! Redirecting to your customer portal...';
				
				// Store customer session (simplified for independent customers)
				localStorage.setItem('customer_session', JSON.stringify({
					customer_id: data.customer_id,
					customer_name: data.customer_name,
					whatsapp_number: data.whatsapp_number,
					registration_status: data.registration_status,
					login_time: new Date().toISOString(),
					remember_device: rememberDevice
				}));

				// Redirect to customer interface
				setTimeout(() => {
					dispatch('success', { 
						type: 'customer_login',
						customer_data: data
					});
				}, 1500);
			} else {
				console.log('❌ [CustomerLogin] Authentication failed:', data);
				errorMessage = data?.error || 'Authentication failed. Please check your access code.';
			}

		} catch (error) {
			console.error('❌ [CustomerLogin] Login error:', error);
			errorMessage = error.message || 'Login failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Handle customer registration
	async function handleCustomerRegistration() {
		console.log('🔍 [CustomerRegistration] Starting registration process');
		console.log('🔍 [CustomerRegistration] Customer name:', customerName);
		console.log('🔍 [CustomerRegistration] WhatsApp number:', whatsappNumber);
		
		const nameValid = validateName();
		const whatsappValid = validateWhatsApp();
		
		console.log('🔍 [CustomerRegistration] Name valid:', nameValid);
		console.log('🔍 [CustomerRegistration] WhatsApp valid:', whatsappValid);
		
		if (!nameValid || !whatsappValid) {
			console.error('❌ [CustomerRegistration] Validation failed');
			errorMessage = 'Please check your information and try again.';
			return;
		}

		console.log('✅ [CustomerRegistration] Validation passed, proceeding with registration');
		isLoading = true;
		errorMessage = '';

		try {
			// Format WhatsApp number
			let formattedWhatsApp = whatsappNumber.replace(/\D/g, '');
			console.log('🔍 [CustomerRegistration] Clean number:', formattedWhatsApp);
			
			if (!formattedWhatsApp.startsWith('966')) {
				formattedWhatsApp = '966' + formattedWhatsApp.replace(/^0/, '');
			}
			formattedWhatsApp = '+' + formattedWhatsApp;
			
			console.log('🔍 [CustomerRegistration] Formatted number:', formattedWhatsApp);

			const { data, error } = await supabase.rpc('create_customer_registration', {
				p_name: customerName.trim(),
				p_whatsapp_number: formattedWhatsApp
			});

			console.log('🔍 [CustomerRegistration] RPC response data:', data);
			console.log('🔍 [CustomerRegistration] RPC response error:', error);

			if (error) throw error;

			if (data && data.success) {
				console.log('✅ [CustomerRegistration] Registration successful');
				successMessage = 'Registration request submitted successfully! You will be notified when approved.';
				
				// Clear form
				customerName = '';
				whatsappNumber = '';
				
				// Switch back to login view after delay
				setTimeout(() => {
					currentView = 'login';
					successMessage = '';
				}, 3000);
			} else {
				errorMessage = data?.error || 'Registration failed. Please try again.';
			}

		} catch (error) {
			errorMessage = error.message || 'Registration failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Handle forgot access code request
	async function handleForgotAccessCode() {
		if (!validateForgotWhatsApp()) {
			errorMessage = 'Please enter a valid mobile number.';
			return;
		}

		isLoading = true;
		errorMessage = '';
		successMessage = '';

		try {
			const { data, error } = await supabase.rpc('request_new_access_code', {
				p_whatsapp_number: forgotWhatsappNumber
			});

			if (error) {
				throw error;
			}

			if (data.success) {
				successMessage = data.message;
				// Switch back to login view after successful request
				setTimeout(() => {
					currentView = 'login';
					successMessage = '';
				}, 5000);
			} else {
				errorMessage = data.error;
				if (data.retry_after_seconds) {
					retryAfterSeconds = data.retry_after_seconds;
					startRetryCountdown();
				}
			}

		} catch (error) {
			errorMessage = error.message || 'Failed to process request. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	function validateForgotWhatsApp() {
		const cleanNumber = forgotWhatsappNumber.replace(/\D/g, '');
		// Accept 9-15 digits (9 for local Saudi numbers, 10-15 for international)
		forgotWhatsappValid = cleanNumber.length >= 9 && cleanNumber.length <= 15;
		return forgotWhatsappValid;
	}

	function startRetryCountdown() {
		const interval = setInterval(() => {
			retryAfterSeconds--;
			if (retryAfterSeconds <= 0) {
				clearInterval(interval);
			}
		}, 1000);
	}

	// Handle digit input for access code
	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			customerDigits[index] = value.slice(-1);
			input.value = customerDigits[index];
			
			// Auto-focus next input
			if (index < 5 && customerDigits[index] !== '') {
				setTimeout(() => {
					const nextInput = document.getElementById(`customer-digit-${index + 1}`) as HTMLInputElement;
					if (nextInput) {
						nextInput.focus();
						nextInput.select();
					}
				}, 10);
			}
		} else {
			customerDigits[index] = '';
		}
		
		validateAccessCode();
	}

	function handleDigitKeydown(event: KeyboardEvent, index: number) {
		const input = event.target as HTMLInputElement;
		
		// Handle Enter key - trigger login if access code is complete
		if (event.key === 'Enter') {
			event.preventDefault();
			if (validateAccessCode() && customerAccessCode.length === 6) {
				handleCustomerLogin();
			}
			return;
		}
		
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (customerDigits[index] !== '') {
				customerDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				customerDigits[index - 1] = '';
				const prevInput = document.getElementById(`customer-digit-${index - 1}`) as HTMLInputElement;
				if (prevInput) {
					prevInput.value = '';
					prevInput.focus();
				}
			}
			validateAccessCode();
			return;
		}
		
		if (event.key === 'ArrowLeft' && index > 0) {
			event.preventDefault();
			const prevInput = document.getElementById(`customer-digit-${index - 1}`) as HTMLInputElement;
			if (prevInput) {
				prevInput.focus();
				prevInput.select();
			}
		} else if (event.key === 'ArrowRight' && index < 5) {
			event.preventDefault();
			const nextInput = document.getElementById(`customer-digit-${index + 1}`) as HTMLInputElement;
			if (nextInput) {
				nextInput.focus();
				nextInput.select();
			}
		}
		
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		for (let i = 0; i < 6; i++) {
			customerDigits[i] = digits[i] || '';
			const input = document.getElementById(`customer-digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = customerDigits[i];
			}
		}
		
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`customer-digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}
		
		validateAccessCode();
	}

	// Switch between login and registration
	function switchToRegister() {
		currentView = 'register';
		errorMessage = '';
		successMessage = '';
	}

	function switchToLogin() {
		currentView = 'login';
		errorMessage = '';
		successMessage = '';
	}

	function switchToLoyalty() {
		currentView = 'loyalty';
		errorMessage = '';
		successMessage = '';
	}

	// Navigate to offers page
	async function goToOffers() {
		try {
			await goto('/offers?referrer=login');
		} catch (error) {
			console.error('❌ Navigation error:', error);
		}
	}

	// Navigate to follow us page
	async function goToFollowUs() {
		try {
			await goto('/follow-us?referrer=login');
		} catch (error) {
			console.error('❌ Navigation error:', error);
		}
	}

	function backFromLoyalty() {
		currentView = 'login';
		loyaltyMobileNumber = '';
		loyaltyMobileValid = false;
		loyaltyCardData = null;
		loyaltyCardChecked = false;
		errorMessage = '';
		successMessage = '';
	}

	// Validate and check loyalty member mobile number
	async function validateLoyaltyMobile() {
		const cleanNumber = loyaltyMobileNumber.replace(/\D/g, '');
		// Saudi mobile: 0548357066 format (10 digits starting with 05)
		const isValidFormat = cleanNumber.length === 10 && cleanNumber.startsWith('05');
		
		if (!isValidFormat) {
			loyaltyMobileValid = false;
			loyaltyCardChecked = true;
			errorMessage = '';
			return false;
		}

		// Check if card number exists in privilege_cards_master
		try {
			isLoading = true;
			errorMessage = '';
			const { data, error } = await supabase
				.from('privilege_cards_master')
				.select('id, card_number')
				.eq('card_number', cleanNumber)
				.maybeSingle();

			if (error) {
				console.error('❌ [LoyaltyLogin] Error querying privilege_cards_master:', error);
				loyaltyMobileValid = false;
				loyaltyCardData = null;
				errorMessage = $_('customer.login.cardNotRegistered') || 'This card number is not registered in the loyalty program';
				loyaltyCardChecked = true;
				return false;
			}

			if (!data) {
				console.warn('⚠️ [LoyaltyLogin] Card not found in privilege_cards_master:', cleanNumber);
				loyaltyMobileValid = false;
				loyaltyCardData = null;
				errorMessage = $_('customer.login.cardNotRegistered') || 'This card number is not registered in the loyalty program';
				loyaltyCardChecked = true;
				return false;
			}

			console.log('✅ [LoyaltyLogin] Card found in privilege_cards_master:', data);

			// Card found, now get branch details - a card can have multiple branches, so get all and use the first one
			const { data: branchDataArray, error: branchError } = await supabase
				.from('privilege_cards_branch')
				.select('*')
				.eq('card_number', cleanNumber);

			if (branchError) {
				console.error('❌ [LoyaltyLogin] Error querying privilege_cards_branch:', branchError);
				loyaltyMobileValid = false;
				loyaltyCardData = null;
				errorMessage = $_('customer.login.cardNotRegistered') || 'This card number is not registered in the loyalty program';
				loyaltyCardChecked = true;
				return false;
			}

			if (!branchDataArray || branchDataArray.length === 0) {
				console.warn('⚠️ [LoyaltyLogin] No branch details found for card:', cleanNumber);
				// Even if no branch data, card exists in master - show success with basic info
				loyaltyMobileValid = true;
				loyaltyCardData = {
					card_number: cleanNumber,
					card_holder_name: null,
					card_balance: 0,
					expiry_date: null
				};
				loyaltyCardChecked = true;
				errorMessage = '';
				return true;
			}

			// Use the first branch if multiple exist
			const branchData = branchDataArray[0];
			console.log('✅ [LoyaltyLogin] Card details found:', branchData);

			loyaltyMobileValid = true;
			loyaltyCardData = branchData;
			loyaltyCardChecked = true;
			errorMessage = '';
			return true;
		} catch (error) {
			console.error('❌ [LoyaltyLogin] Error checking card:', error);
			loyaltyMobileValid = false;
			errorMessage = error.message || 'Error checking card. Please try again.';
			loyaltyCardChecked = true;
			return false;
		} finally {
			isLoading = false;
		}
	}

	// Format loyalty mobile number
	function formatLoyaltyMobileNumber(event: Event) {
		const input = event.target as HTMLInputElement;
		let value = input.value.replace(/\D/g, '');
		
		// Ensure it starts with 0
		if (value && !value.startsWith('0')) {
			value = '0' + value;
		}
		
		// Limit to 10 digits
		if (value.length > 10) {
			value = value.substring(0, 10);
		}
		
		loyaltyMobileNumber = value;
		input.value = value;
	}

	// Navigate to loyalty details page
	async function handleLoyaltyContinue() {
		if (!loyaltyCardData || !loyaltyMobileValid) {
			return;
		}

		try {
			isLoading = true;
			const cardNumber = encodeURIComponent(loyaltyCardData.card_number);
			await goto(`/loyalty/details?cardNumber=${cardNumber}&referrer=login`);
		} catch (error) {
			console.error('❌ Navigation error:', error);
			errorMessage = 'Error navigating to loyalty details page';
		} finally {
			isLoading = false;
		}
	}

	// Auto-validate when loyalty mobile number changes
	$: if (loyaltyMobileNumber && loyaltyMobileNumber.length === 10) {
		validateLoyaltyMobile();
	}

	// Format WhatsApp number as user types
	function formatWhatsAppNumber(event: Event) {
		const input = event.target as HTMLInputElement;
		let value = input.value.replace(/\D/g, '');
		
		// Saudi format: +966 5X XXX XXXX
		if (value.startsWith('966')) {
			value = value.substring(3);
		}
		if (value.startsWith('0')) {
			value = value.substring(1);
		}
		
		// Format with spaces
		if (value.length <= 9) {
			if (value.length > 1) {
				value = value.substring(0, 1) + ' ' + value.substring(1);
			}
			if (value.length > 5) {
				value = value.substring(0, 5) + ' ' + value.substring(5);
			}
		}
		
	whatsappNumber = value;
	input.value = value;
}
</script><div class="customer-login-container">	{#if currentView === 'login'}
		<!-- Customer Login Form -->
		<form class="customer-form" on:submit|preventDefault={handleCustomerLogin}>

			<!-- Follow Us Button -->
			<button type="button" class="follow-us-btn" on:click={goToFollowUs} disabled={isLoading} title={$_('customer.login.followUs') || 'Follow Us'}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
					<circle cx="9" cy="7" r="4"/>
					<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
					<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
				</svg>
				{$_('customer.login.followUs') || 'Follow Us'}
			</button>

			<!-- View Latest Offers Button -->
			<button type="button" class="view-offers-btn" on:click={goToOffers} disabled={isLoading} title={$_('customer.login.viewLatestOffers') || 'View Latest Offers'}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M6 9l6-6 6 6"/>
					<path d="M3 12h18"/>
					<path d="M9 18H6a2 2 0 0 1-2-2v-5h14v5a2 2 0 0 1-2 2h-3"/>
				</svg>
				{$_('customer.login.viewLatestOffers') || 'View Latest Offers'}
			</button>

			<!-- Loyalty Member Login Button -->
			<button type="button" class="loyalty-member-btn" on:click={switchToLoyalty} disabled={isLoading} title={$_('customer.login.loyaltyMemberLogin') || 'Loyalty Member Login'}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
					<path d="M9 10h.01"/>
					<path d="M12 10h.01"/>
					<path d="M15 10h.01"/>
				</svg>
				{$_('customer.login.loyaltyMemberLogin') || 'Loyalty Member Login'}
			</button>

			<div class="login-divider">
				<span>{$_('common.or') || 'OR'}</span>
			</div>

			<div class="access-code-section" class:blocked={blockAccessCodeInput}>
				{#if blockAccessCodeInput}
					<div class="access-code-mask">
						<div class="mask-message">
							<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>
								<path d="M12.5 7H11v6l5.2 3.2.8-1.3-4.5-2.7z"/>
							</svg>
							<h3>
								{$currentLocale === 'ar' 
									? 'قريباً: التوصيل المنزلي والاستلام من المتجر' 
									: 'Coming Soon: Home Delivery & Store Pickup'}
							</h3>
						</div>
					</div>
				{/if}
				
				<div class="form-fields">
					<div class="field-group">
						<label for="customer-access-code">{$_('customer.login.accessCode')}</label>
						<div class="customer-access-digits">
							{#each customerDigits as digit, index}
								<input 
									id="customer-digit-{index}"
									type="text" 
									class="customer-digit-input"
									class:error={!accessCodeValid && customerDigits.some(d => d !== '')}
									bind:value={customerDigits[index]}
									on:input={(e) => handleDigitInput(e, index)}
									on:keydown={(e) => handleDigitKeydown(e, index)}
									on:paste={handleDigitPaste}
									placeholder=""
									disabled={isLoading || blockAccessCodeInput}
									maxlength="1"
									autocomplete="off"
									inputmode="numeric"
									pattern="[0-9]*"
								/>
							{/each}
						</div>
						{#if !accessCodeValid && customerDigits.some(d => d !== '')}
							<span class="field-error">{$_('customer.login.errors.accessCodeLength')}</span>
						{/if}
					</div>

					<div class="form-options">
						<label class="checkbox-option">
							<input 
								type="checkbox" 
								bind:checked={rememberDevice}
								disabled={isLoading || blockAccessCodeInput}
							/>
							<span class="checkbox-mark"></span>
							{$_('common.rememberDevice')}
						</label>
					</div>
				</div>

				<button 
					type="submit" 
					class="customer-submit-btn"
					disabled={isLoading || customerDigits.some(d => d === '') || blockAccessCodeInput}
				>
					{#if isLoading}
						<span class="loading-spinner"></span>
						{$_('customer.login.loggingIn')}
					{:else}
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 12l2 2 4-4"/>
							<circle cx="12" cy="12" r="10"/>
						</svg>
						{$_('customer.login.loginButton')}
					{/if}
				</button>

				<div class="form-footer">
					<p>{$_('customer.login.forgotCredentials')}</p>
					<button type="button" class="register-link" on:click={() => currentView = 'forgot'} disabled={isLoading || blockAccessCodeInput}>
						{$_('customer.login.requestNewAccess')}
					</button>
					<p>{$_('customer.login.needNewAccount')}</p>
					<button type="button" class="register-link" on:click={switchToRegister} disabled={isLoading || blockAccessCodeInput}>
						{$_('customer.login.registerTitle')}
					</button>
				</div>
			</div>
		</form>

	{:else if currentView === 'register'}
		<!-- Customer Registration Form -->
		<form class="customer-form" on:submit|preventDefault={handleCustomerRegistration}>

			<div class="form-fields">
				<div class="field-group">
					<label for="customer-name">{$_('customer.login.customerName')}</label>
					<input 
						id="customer-name"
						type="text" 
						class="field-input"
						class:error={!nameValid}
						bind:value={customerName}
						on:input={validateName}
						placeholder={$_('customer.login.customerNamePlaceholder')}
						disabled={isLoading}
						autocomplete="name"
					/>
					{#if !nameValid}
						<span class="field-error">{$_('customer.login.errors.customerNameRequired')}</span>
					{/if}
				</div>

				<div class="field-group">
					<label for="whatsapp-number">{$_('customer.login.whatsappLabel')}</label>
					<div class="phone-input-group">
						<span class="country-code">+966</span>
						<input 
							id="whatsapp-number"
							type="tel" 
							class="field-input phone-input"
							class:error={!whatsappValid}
							bind:value={whatsappNumber}
							on:input={formatWhatsAppNumber}
							on:blur={validateWhatsApp}
							placeholder={$_('customer.login.whatsappPlaceholder')}
							disabled={isLoading}
							autocomplete="tel"
						/>
					</div>
					{#if !whatsappValid}
						<span class="field-error">{$_('customer.login.errors.invalidWhatsappFormat')}</span>
					{/if}
				</div>
			</div>

			<button 
				type="submit" 
				class="customer-submit-btn register"
				disabled={isLoading || !customerName.trim() || !whatsappNumber.trim()}
			>
				{#if isLoading}
					<span class="loading-spinner"></span>
					{$_('customer.login.registering')}
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
					</svg>
					{$_('customer.login.registerButton')}
				{/if}
			</button>

			<div class="form-footer">
				<p>{$_('customer.login.alreadyHaveAccount')}</p>
				<button type="button" class="register-link" on:click={switchToLogin} disabled={isLoading}>
					{$_('customer.login.loginButton')}
				</button>
			</div>
		</form>

	{:else if currentView === 'forgot'}
		<!-- Forgot Access Code Form -->
		<form class="customer-form" on:submit|preventDefault={handleForgotAccessCode}>

			<div class="form-fields">
				<div class="field-group">
					<label for="forgot-whatsapp">{$_('customer.login.whatsappLabel')}</label>
					<div class="phone-input-group">
						<span class="country-code">+966</span>
						<input 
							id="forgot-whatsapp"
							type="tel" 
							class="field-input phone-input"
							class:error={!forgotWhatsappValid}
							bind:value={forgotWhatsappNumber}
							on:input={() => forgotWhatsappNumber = forgotWhatsappNumber.replace(/[^\d+\s-()]/g, '')}
							on:blur={validateForgotWhatsApp}
							placeholder={$_('customer.login.whatsappPlaceholder')}
							disabled={isLoading}
							autocomplete="tel"
						/>
					</div>
					{#if !forgotWhatsappValid}
						<span class="field-error">{$_('customer.login.errors.invalidWhatsappFormat')}</span>
					{/if}
				</div>

				{#if retryAfterSeconds > 0}
					<div class="retry-info">
						<p>{$_('customer.login.errors.tooManyRequests')}</p>
					</div>
				{/if}
			</div>

			<button 
				type="submit" 
				class="customer-submit-btn forgot"
				disabled={isLoading || !forgotWhatsappNumber.trim() || retryAfterSeconds > 0}
			>
				{#if isLoading}
					<span class="loading-spinner"></span>
					{$_('customer.login.submittingRequest')}
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>
						<polyline points="16,6 12,2 8,6"/>
						<line x1="12" y1="2" x2="12" y2="15"/>
					</svg>
					{$_('customer.login.submitRequest')}
				{/if}
			</button>

			<div class="form-footer">
				<p>{$_('customer.login.alreadyHaveAccount')}</p>
				<button type="button" class="register-link" on:click={switchToLogin} disabled={isLoading}>
					{$_('customer.login.backToLogin')}
				</button>
				<p>{$_('customer.login.needNewAccount')}</p>
				<button type="button" class="register-link" on:click={switchToRegister} disabled={isLoading}>
					{$_('customer.login.registerButton')}
				</button>
			</div>
		</form>

	{:else if currentView === 'loyalty'}
		<!-- Loyalty Member Login Form -->
		<form class="customer-form loyalty-form" on:submit|preventDefault={() => {}}>

			<div class="loyalty-header">
				<button type="button" class="back-btn" on:click={backFromLoyalty} disabled={isLoading} title="Back">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M19 12H5M12 19l-7-7 7-7"/>
					</svg>
				</button>
				<h2>{$_('customer.login.loyaltyMemberTitle') || 'Loyalty Member Login'}</h2>
			</div>

			<p class="loyalty-subtitle">{$_('customer.login.loyaltyMemberSubtitle') || 'Enter your mobile number to login'}</p>

			<div class="form-fields">
				<div class="field-group">
					<label for="loyalty-mobile">{$_('customer.login.loyaltyMobileLabel') || 'Mobile Number'}</label>
					<input 
						id="loyalty-mobile"
						type="tel" 
						class="field-input"
						class:error={loyaltyCardChecked && !loyaltyMobileValid}
						bind:value={loyaltyMobileNumber}
						on:input={formatLoyaltyMobileNumber}
						on:blur={validateLoyaltyMobile}
						placeholder="05XXXXXXXX"
						disabled={isLoading}
						autocomplete="tel"
						inputmode="numeric"
					/>
					{#if loyaltyCardChecked && !loyaltyMobileValid && errorMessage}
						<span class="field-error">{errorMessage}</span>
					{/if}
				</div>
			</div>

			<button 
				type="button" 
				class="customer-submit-btn loyalty"
				disabled={isLoading || !loyaltyMobileValid}
				on:click={handleLoyaltyContinue}
			>
				{#if isLoading}
					<span class="loading-spinner"></span>
					{$_('customer.login.loyaltyLoggingIn') || 'Signing in...'}
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M9 12l2 2 4-4"/>
						<circle cx="12" cy="12" r="10"/>
					</svg>
					{$_('customer.login.loyaltySubmit') || 'Continue'}
				{/if}
			</button>
		</form>
	{/if}

	<!-- Status Messages -->
	{#if errorMessage}
		<div class="status-message error-status" role="alert">
			<div class="status-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="10"/>
					<line x1="15" y1="9" x2="9" y2="15"/>
					<line x1="9" y1="9" x2="15" y2="15"/>
				</svg>
			</div>
			<div class="status-content">
				<h4>{$_('status.error')}</h4>
				<p>{errorMessage}</p>
			</div>
		</div>
	{/if}

	{#if successMessage}
		<div class="status-message success-status" role="status">
			<div class="status-icon">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M9 12l2 2 4-4"/>
					<circle cx="12" cy="12" r="10"/>
				</svg>
			</div>
			<div class="status-content">
				<h4>{$_('status.success')}</h4>
				<p>{successMessage}</p>
			</div>
		</div>
	{/if}

	<!-- Follow Us Modal -->
</div>

<style>
	.customer-login-container {
		animation: slideInUp 0.5s ease-out;
		padding: 0;
		margin: 0;
		background: transparent;
		border: none;
		box-shadow: none;
		width: 100%;
	}

	/* RTL Support */
	:global([dir="rtl"]) .customer-login-container {
		text-align: right;
	}

	:global([dir="rtl"]) .back-btn {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"]) .back-btn svg {
		transform: scaleX(-1);
	}

	:global([dir="rtl"]) .field-group label {
		text-align: right;
	}

	:global([dir="rtl"]) .form-footer {
		text-align: right;
	}

	:global([dir="rtl"]) .phone-input-group {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"]) .country-code {
		border-radius: 0 6px 6px 0;
		border-left: 1px solid #E5E7EB;
		border-right: none;
	}

	:global([dir="rtl"]) .phone-input {
		border-radius: 6px 0 0 6px;
	}

	:global([dir="rtl"]) .customer-submit-btn svg {
		order: 1;
	}

	:global([dir="rtl"]) .status-message {
		text-align: right;
	}

	:global([dir="rtl"]) .checkbox-option {
		flex-direction: row-reverse;
		justify-content: flex-end;
	}

	:global([dir="rtl"]) .checkbox-mark {
		margin-left: 0;
		margin-right: 8px;
	}

	/* Arabic Font Support */
	:global(.font-arabic) .customer-login-container {
		font-family: 'Tajawal', 'Amiri', 'Cairo', sans-serif;
	}

	:global(.font-arabic) .field-input,
	:global(.font-arabic) .customer-digit-input {
		font-family: 'Tajawal', 'Amiri', 'Cairo', sans-serif;
	}

	@keyframes slideInUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.customer-form {
		width: 100%;
		margin: 0;
		padding: 0;
	}

	.form-fields {
		margin-bottom: 1.5rem;
	}

	.field-group {
		margin-bottom: 1.25rem;
	}

	.field-group label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.field-input {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		font-size: 1rem;
		background: #FFFFFF;
		color: #1E293B;
		transition: all 0.3s ease;
		box-sizing: border-box;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
	}

	.field-input:focus {
		outline: none;
		border-color: #8B5CF6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.field-input.error {
		border-color: #EF4444;
		background: #FEF2F2;
	}

	.field-input:disabled {
		background: #F9FAFB;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	/* Customer Access Code Digits */
	.customer-access-digits {
		display: flex;
		gap: 0.75rem;
		justify-content: center;
		align-items: center;
		margin: 0.5rem 0;
		direction: ltr;
	}

	.customer-digit-input {
		width: 48px;
		height: 48px;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		text-align: center;
		font-size: 1.25rem;
		font-weight: 600;
		font-family: 'JetBrains Mono', 'Courier New', monospace;
		background: #FFFFFF;
		color: #1E293B;
		transition: all 0.3s ease;
		box-sizing: border-box;
		padding: 0;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		touch-action: manipulation;
		direction: ltr;
	}

	.customer-digit-input:focus {
		outline: none;
		border-color: #8B5CF6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
		background: #F8FAFC;
	}

	.customer-digit-input.error {
		border-color: #EF4444;
		background: #FEF2F2;
	}

	.customer-digit-input:disabled {
		background: #F9FAFB;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	/* Phone Input Group */
	.phone-input-group {
		display: flex;
		align-items: center;
		gap: 0;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		background: #FFFFFF;
		transition: all 0.3s ease;
	}

	.phone-input-group:focus-within {
		border-color: #8B5CF6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.country-code {
		padding: 0.875rem 0.75rem;
		background: #F8FAFC;
		color: #64748B;
		font-weight: 600;
		border-right: 1px solid #E5E7EB;
		font-size: 1rem;
	}

	.phone-input {
		border: none !important;
		border-radius: 0 6px 6px 0 !important;
		box-shadow: none !important;
		flex: 1;
	}

	.phone-input:focus {
		box-shadow: none !important;
		border-color: transparent !important;
	}

	.field-error {
		color: #EF4444;
		font-size: 0.75rem;
		margin-top: 0.5rem;
		display: block;
	}

	.form-options {
		display: flex;
		justify-content: flex-start;
		align-items: center;
		margin-top: 1.5rem;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #64748B;
		cursor: pointer;
	}

	.checkbox-option input[type="checkbox"] {
		width: 18px;
		height: 18px;
		accent-color: #8B5CF6;
		margin: 0;
	}

	.customer-submit-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		box-shadow: 0 4px 14px rgba(139, 92, 246, 0.3);
		text-transform: none;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 48px;
	}

	.customer-submit-btn.register {
		background: linear-gradient(135deg, #059669 0%, #10B981 100%);
		box-shadow: 0 4px 14px rgba(5, 150, 105, 0.3);
	}

	.customer-submit-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 20px rgba(139, 92, 246, 0.4);
	}

	.customer-submit-btn.register:hover:not(:disabled) {
		background: linear-gradient(135deg, #047857 0%, #059669 100%);
		box-shadow: 0 6px 20px rgba(5, 150, 105, 0.4);
	}

	.customer-submit-btn.forgot {
		background: linear-gradient(135deg, #7C3AED 0%, #A855F7 100%);
		box-shadow: 0 4px 16px rgba(124, 58, 237, 0.3);
	}

	.customer-submit-btn.forgot:hover:not(:disabled) {
		background: linear-gradient(135deg, #6D28D9 0%, #9333EA 100%);
		box-shadow: 0 6px 20px rgba(124, 58, 237, 0.4);
	}

	.customer-submit-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.customer-submit-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.form-footer {
		text-align: center;
		margin-top: 1.5rem;
		padding-top: 1.25rem;
		border-top: 1px solid #E5E7EB;
	}

	.form-footer p {
		color: #64748B;
		font-size: 0.875rem;
		margin-bottom: 0.75rem;
	}

	.register-link {
		background: transparent;
		border: none;
		color: #8B5CF6;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	.register-link:hover:not(:disabled) {
		color: #7C3AED;
	}

	.register-link:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.loyalty-divider {
		height: 1px;
		background: #E5E7EB;
		margin: 1rem 0;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
	}

	.loyalty-divider span {
		background: white;
		padding: 0 0.75rem;
		color: #9CA3AF;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.login-divider {
		height: 1px;
		background: #E5E7EB;
		margin: 1.5rem 0;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
	}

	.login-divider span {
		background: white;
		padding: 0 0.75rem;
		color: #9CA3AF;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.loyalty-member-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: #1a1a1a;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 48px;
	}

	.loyalty-member-btn:hover:not(:disabled) {
		background: #4D5157;
	}

	.loyalty-member-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.loyalty-member-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	/* Follow Us Button Styles */
	.follow-us-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: #00CC00;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 48px;
		margin-bottom: 1rem;
	}

	.follow-us-btn:hover:not(:disabled) {
		background: #13A538;
	}

	.follow-us-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.follow-us-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	/* View Offers Button Styles */
	@keyframes heartbeat {
		0%, 100% {
			transform: scale(1);
		}
		25% {
			transform: scale(1.1);
		}
		50% {
			transform: scale(1.2);
		}
		75% {
			transform: scale(1.1);
		}
	}

	.view-offers-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: #FF5500;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 48px;
		margin-bottom: 1.5rem;
	}

	.view-offers-btn svg {
		animation: heartbeat 1.5s infinite;
	}

	.view-offers-btn:hover:not(:disabled) {
		background: #f08300;
	}

	.view-offers-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.view-offers-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	/* Loyalty Form Styles */
	.loyalty-form {
		animation: fadeIn 0.3s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	/* Card Details Section */
	.card-details-section {
		background: linear-gradient(135deg, #FEF3C7 0%, #FEF08A 100%);
		border: 1px solid #FCD34D;
		border-radius: 12px;
		padding: 1.5rem;
		margin: 1.5rem 0;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.card-detail-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 0;
		border-bottom: 1px solid rgba(252, 211, 77, 0.3);
	}

	.card-detail-item:last-child {
		border-bottom: none;
	}

	.detail-label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #92400E;
	}

	.detail-value {
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
		text-align: right;
	}

	.detail-value.amount {
		color: #F59E0B;
		font-size: 1.125rem;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.loyalty-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 1.5rem;
		position: relative;
	}

	.loyalty-header h2 {
		flex: 1;
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0;
	}

	.back-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		padding: 0;
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		color: #374151;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
	}

	.back-btn:hover:not(:disabled) {
		background: #E5E7EB;
		border-color: #D1D5DB;
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.loyalty-subtitle {
		color: #6B7280;
		font-size: 0.95rem;
		margin: 0 0 1.5rem 0;
		text-align: center;
	}

	.customer-submit-btn.loyalty {
		background: linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%);
		box-shadow: 0 4px 14px rgba(245, 158, 11, 0.3);
	}

	.customer-submit-btn.loyalty:hover:not(:disabled) {
		background: linear-gradient(135deg, #D97706 0%, #F59E0B 100%);
		box-shadow: 0 6px 20px rgba(245, 158, 11, 0.4);
	}

	.retry-info {
		background: #FEF3C7;
		border: 1px solid #F59E0B;
		border-radius: 8px;
		padding: 1rem;
		margin-top: 1rem;
		text-align: center;
	}

	.retry-info p {
		color: #92400E;
		font-size: 0.875rem;
		margin: 0;
		font-weight: 500;
	}

	/* Status Messages */
	.status-message {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		padding: 1rem 1.25rem;
		margin-top: 1.5rem;
		border-radius: 12px;
		animation: messageSlideIn 0.4s ease-out;
	}

	@keyframes messageSlideIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.error-status {
		background: #FEF2F2;
		border: 1px solid #FECACA;
		color: #DC2626;
	}

	.success-status {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		color: #16A34A;
	}

	.status-icon {
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	.status-content h4 {
		font-size: 0.875rem;
		font-weight: 600;
		margin: 0 0 0.25rem 0;
	}

	.status-content p {
		font-size: 0.875rem;
		margin: 0;
		opacity: 0.9;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.customer-access-digits {
			gap: 0.5rem;
		}

		.customer-digit-input {
			width: 44px;
			height: 44px;
			font-size: 1.2rem;
		}

		.field-input {
			font-size: 16px; /* Prevents zoom on iOS */
		}

		.form-fields {
			margin-bottom: 1.25rem;
		}
	}

	@media (max-width: 480px) {
		.customer-access-digits {
			gap: 0.375rem;
		}

		.customer-digit-input {
			width: 38px;
			height: 38px;
			font-size: 1.1rem;
		}

		.customer-submit-btn {
			min-height: 52px;
		}
	}

	@media (max-width: 375px) {
		.customer-access-digits {
			gap: 0.25rem;
		}

		.customer-digit-input {
			width: 34px;
			height: 34px;
			font-size: 1rem;
		}
	}

	/* Access Code Section with Mask */
	.access-code-section {
		position: relative;
	}

	.access-code-mask {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.95);
		border-radius: 8px;
		z-index: 50;
		pointer-events: auto;
		backdrop-filter: blur(2px);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.mask-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.5rem;
		padding: 2.5rem;
		text-align: center;
		color: #1F2937;
		background: linear-gradient(135deg, #F8F9FB 0%, #FFFFFF 100%);
		border-radius: 16px;
		box-shadow: 0 20px 40px rgba(139, 92, 246, 0.15),
			0 10px 20px rgba(0, 0, 0, 0.08);
		border: 1px solid rgba(139, 92, 246, 0.1);
		max-width: 340px;
		backdrop-filter: blur(8px);
		transform: translateY(-8px);
		animation: slideInDown 0.5s ease-out;
	}

	.mask-message svg {
		width: 56px;
		height: 56px;
		color: #8B5CF6;
		animation: bounce 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
		filter: drop-shadow(0 4px 12px rgba(139, 92, 246, 0.3));
	}

	@keyframes bounce {
		0%,
		100% {
			transform: translateY(0);
			opacity: 1;
		}
		50% {
			transform: translateY(-8px);
			opacity: 0.85;
		}
	}

	@keyframes slideInDown {
		from {
			opacity: 0;
			transform: translateY(-20px);
		}
		to {
			opacity: 1;
			transform: translateY(-8px);
		}
	}

	.mask-message h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 700;
		line-height: 1.6;
		letter-spacing: -0.3px;
		background: linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}


</style>
