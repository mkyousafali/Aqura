<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { _, switchLocale, currentLocale } from '$lib/i18n';

	const dispatch = createEventDispatcher();

	// Props
	export let initialView: 'login' | 'register' | 'forgot' = 'login';

	// Component states
	let currentView: 'login' | 'register' | 'forgot' = initialView;
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
</script><div class="customer-login-container">
	<!-- Language Toggle Button -->
	<div class="language-toggle-wrapper">
		<button 
			type="button"
			class="language-toggle-btn" 
			on:click={() => {
				switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
				setTimeout(() => {
					window.location.reload();
				}, 100);
			}}
			title={$_('nav.languageToggle')}
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="12" cy="12" r="10"/>
				<path d="M8 12h8"/>
				<path d="M12 8v8"/>
			</svg>
			{$currentLocale === 'ar' ? 'English' : 'العربية'}
		</button>
	</div>

	{#if currentView === 'login'}
		<!-- Customer Login Form -->
		<form class="customer-form" on:submit|preventDefault={handleCustomerLogin}>

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
								disabled={isLoading}
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
							disabled={isLoading}
						/>
						<span class="checkbox-mark"></span>
						{$_('common.rememberDevice')}
					</label>
				</div>
			</div>

			<button 
				type="submit" 
				class="customer-submit-btn"
				disabled={isLoading || customerDigits.some(d => d === '')}
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
				<button type="button" class="register-link" on:click={() => currentView = 'forgot'} disabled={isLoading}>
					{$_('customer.login.requestNewAccess')}
				</button>
				<p>{$_('customer.login.needNewAccount')}</p>
				<button type="button" class="register-link" on:click={switchToRegister} disabled={isLoading}>
					{$_('customer.login.registerTitle')}
				</button>
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

	.language-toggle-wrapper {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 1.5rem;
	}

	.language-toggle-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		background: #F8FAFC;
		border: 1px solid #CBD5E1;
		border-radius: 8px;
		color: #475569;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.language-toggle-btn:hover {
		background: #F1F5F9;
		border-color: #94A3B8;
		color: #334155;
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
</style>

