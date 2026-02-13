<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { localeData, _, switchLocale, currentLocale } from '$lib/i18n';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';

	function t(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let interfaceChoice: 'desktop' | 'mobile' | null = null;
	let loginMethod: 'username' | 'quickAccess' = 'username';
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	let username = '';
	let password = '';
	let rememberMe = false;

	let quickAccessCode = '';
	let quickAccessDigits = ['', '', '', '', '', ''];

	let usernameValid = true;
	let passwordValid = true;
	let quickAccessValid = true;

	let mounted = false;
	let showContent = false;
	let logoClickCount = 0;
	let showCustomerButton = false;
	let showAccessCode = false;

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		checkExistingAuth();
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			goto('/');
		}
	}

	function clearForm() {
		loginMethod = 'username';
		username = '';
		password = '';
		quickAccessCode = '';
		quickAccessDigits = ['', '', '', '', '', ''];
		errorMessage = '';
		successMessage = '';
		usernameValid = true;
		passwordValid = true;
		quickAccessValid = true;
	}

	function chooseInterface(choice: 'desktop' | 'mobile') {
		if (choice === 'mobile') {
			goto('/mobile-interface/login');
		} else {
			interfaceChoice = 'desktop';
			clearForm();
			loginMethod = 'quickAccess';
			tick().then(() => {
				setTimeout(() => {
					const firstDigit = document.getElementById('digit-0') as HTMLInputElement;
					if (firstDigit) firstDigit.focus();
				}, 100);
			});
		}
	}

	function goBackToChoice() {
		interfaceChoice = null;
		clearForm();
	}

	function goBackToMain() {
		goto('/login');
	}

	function handleLogoClick() {
		logoClickCount++;
		if (logoClickCount === 10) {
			showCustomerButton = true;
		} else if (logoClickCount > 10) {
			logoClickCount = 0;
			showCustomerButton = false;
		}
	}

	function validateUsername() {
		usernameValid = username.length >= 3;
		return usernameValid;
	}

	function validatePassword() {
		passwordValid = password.length >= 6;
		return passwordValid;
	}

	function validateQuickAccess() {
		quickAccessCode = quickAccessDigits.join('');
		const isNumeric = /^[0-9]+$/.test(quickAccessCode);
		quickAccessValid = quickAccessCode.length === 6 && isNumeric;
		return quickAccessValid;
	}

	async function handleUsernameLogin() {
		if (!validateUsername() || !validatePassword()) {
			errorMessage = 'Please check your credentials and try again.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const result = await persistentAuthService.login(username, password);
			
			if (result.success) {
				successMessage = 'Login successful! Redirecting...';
				
				setTimeout(() => {
					goto('/');
				}, 1500);
			} else {
				errorMessage = result.error || 'Login failed. Please try again.';
			}

		} catch (error) {
			errorMessage = error.message || 'Login failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	async function handleQuickAccessLogin() {
		if (!validateQuickAccess()) {
			errorMessage = 'Please enter a valid 6-digit access code.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const result = await persistentAuthService.loginWithQuickAccess(quickAccessCode, 'desktop');
			
			if (result.success) {
				successMessage = 'Quick access successful! Redirecting...';
				
				setTimeout(() => {
					goto('/');
				}, 1500);
			} else {
				errorMessage = result.error || 'Quick access login failed. Please try again.';
			}

		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Login failed. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !isLoading) {
			if (loginMethod === 'username') {
				handleUsernameLogin();
			} else {
				handleQuickAccessLogin();
			}
		}
	}

	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			quickAccessDigits[index] = value.slice(-1);
			input.value = quickAccessDigits[index];
			
			if (index < 5 && quickAccessDigits[index] !== '') {
				setTimeout(() => {
					const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
					if (nextInput) {
						nextInput.focus();
						nextInput.select();
					}
				}, 10);
			}
		} else {
			quickAccessDigits[index] = '';
		}
		
		validateQuickAccess();
	}

	function handleDigitKeydown(event: KeyboardEvent, index: number) {
		const input = event.target as HTMLInputElement;
		
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (quickAccessDigits[index] !== '') {
				quickAccessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				quickAccessDigits[index - 1] = '';
				const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
				if (prevInput) {
					prevInput.value = '';
					prevInput.focus();
				}
			}
			validateQuickAccess();
			return;
		}
		
		if (event.key === 'ArrowLeft' && index > 0) {
			event.preventDefault();
			const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
			if (prevInput) {
				prevInput.focus();
				prevInput.select();
			}
		} else if (event.key === 'ArrowRight' && index < 5) {
			event.preventDefault();
			const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
			if (nextInput) {
				nextInput.focus();
				nextInput.select();
			}
		}
		
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		for (let i = 0; i < 6; i++) {
			quickAccessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = quickAccessDigits[i];
			}
		}
		
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}
		
		validateQuickAccess();
	}
</script>

<svelte:head>
	<title>Employee Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			<div class="login-main-card">
				<div class="logo-section">
					<div class="logo-header">
						<div class="logo">
							<button 
								on:click={handleLogoClick}
								class="logo-btn"
								type="button"
								title="Logo"
								aria-label="Aqura Logo"
							>
								<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
							</button>
						</div>
						<button 
							class="language-toggle-main" 
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
				</div>

				<div class="auth-section">
					{#if interfaceChoice === null}
						<div class="interface-choice">
							<button 
								class="back-btn-top"
								on:click={goBackToMain}
								disabled={isLoading}
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.back')}
							</button>

							<div class="interface-options">
								<button 
									class="interface-btn desktop-btn"
									on:click={() => chooseInterface('desktop')}
									disabled={isLoading}
									title={$_('customer.login.interface.desktop')}
								>
									<div class="interface-icon">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="2" y="4" width="20" height="12" rx="2"/>
											<path d="M2 16h20"/>
											<path d="M8 20h8"/>
										</svg>
									</div>
									<span class="interface-label">{$_('common.users')}</span>
								</button>

								<button 
									class="interface-btn mobile-btn"
									on:click={() => chooseInterface('mobile')}
									disabled={isLoading}
									title={$_('customer.login.interface.mobile')}
								>
									<div class="interface-icon">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="5" y="2" width="14" height="20" rx="2"/>
											<path d="M12 18h.01"/>
										</svg>
									</div>
									<span class="interface-label">{$_('common.users')}</span>
								</button>

								<button 
									class="interface-btn cashier-btn"
									on:click={() => goto('/cashier-interface')}
									disabled={isLoading}
									type="button"
									title={$_('coupon.cashier') || 'Cashier'}
								>
									<div class="interface-icon">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
											<circle cx="8.5" cy="8.5" r="1.5"/>
											<polyline points="21 15 16 10 5 21"/>
											<line x1="10" y1="18" x2="18" y2="10"/>
										</svg>
									</div>
									<span class="interface-label">{$_('coupon.cashier') || 'Cashier'}</span>
								</button>

								{#if showCustomerButton}
									<button 
										class="interface-btn customer-btn"
										on:click={() => goto('/customer-interface/login')}
										disabled={isLoading}
										type="button"
										title="Customer Login"
									>
										<div class="interface-icon">
											<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<circle cx="12" cy="12" r="9"/>
												<circle cx="12" cy="12" r="1"/>
												<path d="M12 8v-1"/>
												<path d="M12 17v1"/>
												<path d="M16 12h1"/>
												<path d="M7 12h-1"/>
											</svg>
										</div>
										<span class="interface-label">Customer</span>
									</button>
								{/if}
							</div>
						</div>
					{:else}
						<div class="desktop-login-header">
							<button 
								class="back-btn"
								on:click={goBackToChoice}
								disabled={isLoading}
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.backToInterfaceChoice')}
							</button>
						</div>

						<div class="method-selector">
							<button 
								class="method-btn" 
								class:active={loginMethod === 'username'}
								on:click={() => loginMethod = 'username'}
								disabled={isLoading}
							>
								<div class="method-icon">
									<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
										<circle cx="12" cy="7" r="4"/>
									</svg>
								</div>
								<div class="method-info">
									<h3>{t('common.usernameAndPassword')}</h3>
									<p>{t('common.traditionalLoginMethod')}</p>
								</div>
							</button>

							<button 
								class="method-btn" 
								class:active={loginMethod === 'quickAccess'}
								on:click={() => loginMethod = 'quickAccess'}
								disabled={isLoading}
							>
								<div class="method-icon">
									<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
										<circle cx="12" cy="16" r="1"/>
										<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
									</svg>
								</div>
								<div class="method-info">
									<h3>{t('common.quickAccessCode')}</h3>
									<p>{t('common.sixDigitSecureAccess')}</p>
								</div>
							</button>
						</div>

						<div class="auth-forms">
							{#if loginMethod === 'username'}
								<form class="auth-form" on:submit|preventDefault={handleUsernameLogin}>
									<div class="form-header">
										<h2>{t('common.welcomeBack')}</h2>
										<p>{t('common.enterCredentials')}</p>
									</div>

									<div class="form-fields">
										<div class="field-group">
											<label for="username">{t('common.username')}</label>
											<input 
												id="username"
												type="text" 
												class="field-input"
												class:error={!usernameValid}
												bind:value={username}
												on:input={validateUsername}
												placeholder={t('common.enterUsername')}
												disabled={isLoading}
												autocomplete="username"
											/>
											{#if !usernameValid}
												<span class="field-error">{t('common.usernameMustBeThreeCharacters')}</span>
											{/if}
										</div>

										<div class="field-group">
											<div class="label-with-toggle">
										<label for="password">{t('common.password')}</label>
										<button type="button" class="eye-toggle" on:click={() => showAccessCode = !showAccessCode} tabindex="-1">
											{#if showAccessCode}
												<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
											{:else}
												<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
											{/if}
										</button>
									</div>
											<input 
												id="password"
												type={showAccessCode ? 'text' : 'password'} 
												class="field-input"
												class:error={!passwordValid}
												bind:value={password}
												on:input={validatePassword}
												placeholder={t('common.enterPassword')}
												disabled={isLoading}
												autocomplete="current-password"
											/>
											{#if !passwordValid}
												<span class="field-error">{t('common.passwordMustBeSixCharacters')}</span>
											{/if}
										</div>

										<div class="form-options">
											<label class="checkbox-option">
												<input 
													type="checkbox" 
													bind:checked={rememberMe}
													disabled={isLoading}
												/>
												<span class="checkbox-mark"></span>
												{t('common.rememberMeThirtyDays')}
											</label>
										</div>
									</div>

									<button 
										type="submit" 
										class="auth-submit-btn"
										disabled={isLoading || !username || !password}
									>
										{#if isLoading}
											<span class="loading-spinner"></span>
											{t('common.signingIn')}
										{:else}
											<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
												<polyline points="10,17 15,12 10,7"/>
												<line x1="15" y1="12" x2="3" y2="12"/>
											</svg>
											{t('common.signInToSystem')}
										{/if}
									</button>
								</form>
							{:else}
								<form class="auth-form" on:submit|preventDefault={handleQuickAccessLogin}>
									<div class="form-header">
										<h2>{t('common.quickAccess')}</h2>
										<p>{t('common.enterSixDigitSecurityCode')}</p>
									</div>

									<div class="form-fields">
										<div class="field-group">
											<div class="label-with-toggle">
										<label for="quickAccess">{t('common.securityCode')}</label>
										<button type="button" class="eye-toggle" on:click={() => showAccessCode = !showAccessCode} tabindex="-1">
											{#if showAccessCode}
												<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
											{:else}
												<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
											{/if}
										</button>
									</div>
											<div class="quick-access-digits">
												{#each quickAccessDigits as digit, index}
													<input 
														id="digit-{index}"
														type={showAccessCode ? 'text' : 'password'} 
														class="digit-input"
														class:error={!quickAccessValid && quickAccessDigits.some(d => d !== '')}
														bind:value={quickAccessDigits[index]}
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
											{#if !quickAccessValid && quickAccessDigits.some(d => d !== '')}
												<span class="field-error">{t('common.enterValidSixDigitCode')}</span>
											{/if}
										</div>

										<div class="field-spacer"></div>

										<div class="form-options">
											<label class="checkbox-option">
												<input 
													type="checkbox" 
													bind:checked={rememberMe}
													disabled={isLoading}
												/>
												<span class="checkbox-mark"></span>
												{t('common.rememberThisDevice')}
											</label>
										</div>
									</div>

									<button 
										type="submit" 
										class="auth-submit-btn"
										disabled={isLoading || quickAccessDigits.some(d => d === '')}
									>
										{#if isLoading}
											<span class="loading-spinner"></span>
											Accessing...
										{:else}
											<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M9 12l2 2 4-4"/>
												<path d="M21 12c-1 0-3-1-3-3s2-3 3-3 3 1 3 3-2 3-3 3"/>
												<path d="M3 12c1 0 3-1 3-3s-2-3-3-3-3 1-3 3 2 3 3 3"/>
												<path d="M12 3c0 1-1 3-3 3s-3-2-3-3 1-3 3-3 3 2 3 3"/>
												<path d="M12 21c0-1 1-3 3-3s3 2 3 3-1 3-3 3-3-2-3-3"/>
											</svg>
											{t('common.accessSystem')}
										{/if}
									</button>
								</form>
							{/if}
						</div>
					{/if}
				</div>

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
							<h4>{t('common.authenticationFailed')}</h4>
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
							<h4>{t('common.accessGranted')}</h4>
							<p>{successMessage}</p>
						</div>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	:global(html) {
		touch-action: manipulation;
		-webkit-text-size-adjust: 100%;
		overflow-x: hidden;
		height: 100%;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
		min-height: 100vh;
		min-height: 100dvh;
		height: 100%;
		-webkit-overflow-scrolling: touch;
		position: relative;
	}

	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1.5rem;
		background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(ellipse at 20% 50%, rgba(99, 102, 241, 0.15) 0%, transparent 50%),
			radial-gradient(ellipse at 80% 20%, rgba(139, 92, 246, 0.1) 0%, transparent 50%),
			radial-gradient(ellipse at 50% 80%, rgba(59, 130, 246, 0.08) 0%, transparent 50%);
		z-index: 0;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 480px;
		position: relative;
		z-index: 1;
		min-height: 0;
	}

	.login-main-card {
		background: rgba(255, 255, 255, 0.08);
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border-radius: 20px;
		border: 1px solid rgba(255, 255, 255, 0.12);
		box-shadow: 
			0 20px 60px rgba(0, 0, 0, 0.3),
			0 0 0 1px rgba(255, 255, 255, 0.05) inset;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.logo-section {
		color: white;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1.5rem 1rem;
		gap: 0.5rem;
	}

	.logo-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		width: 100%;
	}

	.logo {
		width: 100px;
		height: 65px;
		background: rgba(255, 255, 255, 0.95);
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 8px 32px rgba(0, 0, 0, 0.2),
			0 0 0 1px rgba(255, 255, 255, 0.1);
		animation: logoFloat 4s ease-in-out infinite;
	}

	@keyframes logoFloat {
		0%, 100% { transform: translateY(0); }
		50% { transform: translateY(-4px); }
	}

	.logo-image {
		width: 90px;
		height: 55px;
		border-radius: 8px;
		object-fit: contain;
	}

	.logo-btn {
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.2s ease;
	}

	.logo-btn:hover {
		transform: scale(1.05);
	}

	.logo-btn:active {
		transform: scale(0.98);
	}

	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.75rem;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.15);
		color: rgba(255, 255, 255, 0.8);
		border-radius: 20px;
		cursor: pointer;
		font-size: 0.72rem;
		font-weight: 500;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.15);
		border-color: rgba(255, 255, 255, 0.25);
		color: white;
	}

	.auth-section {
		padding: 1.25rem 1.5rem 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.interface-choice {
		width: 100%;
	}

	.back-btn-top {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.1);
		color: rgba(255, 255, 255, 0.7);
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.72rem;
		font-weight: 500;
		transition: all 0.3s ease;
		margin-bottom: 0.5rem;
	}

	.back-btn-top:hover {
		background: rgba(255, 255, 255, 0.12);
		border-color: rgba(255, 255, 255, 0.2);
		color: white;
	}

	.interface-options {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.75rem;
		justify-items: center;
		margin-top: 0.5rem;
	}

	.interface-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1.25rem 1rem;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 14px;
		cursor: pointer;
		transition: all 0.3s ease;
		width: 100%;
		text-align: center;
	}

	.interface-btn:hover:not(:disabled) {
		border-color: rgba(99, 102, 241, 0.5);
		background: rgba(99, 102, 241, 0.1);
		transform: translateY(-3px);
		box-shadow: 0 8px 24px rgba(99, 102, 241, 0.15);
	}

	.interface-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.interface-icon {
		width: 48px;
		height: 48px;
		background: linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(139, 92, 246, 0.15));
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #a5b4fc;
	}

	.interface-label {
		font-size: 0.78rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.customer-btn .interface-icon {
		background: linear-gradient(135deg, rgba(139, 92, 246, 0.2), rgba(168, 85, 247, 0.15));
		color: #c4b5fd;
	}

	.customer-btn:hover:not(:disabled) {
		border-color: rgba(139, 92, 246, 0.5);
		background: rgba(139, 92, 246, 0.1);
		box-shadow: 0 8px 24px rgba(139, 92, 246, 0.15);
	}

	.desktop-login-header {
		margin-bottom: 0.4rem;
	}

	.back-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.1);
		color: rgba(255, 255, 255, 0.7);
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.72rem;
		font-weight: 500;
		transition: all 0.3s ease;
	}

	.back-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.12);
		border-color: rgba(255, 255, 255, 0.2);
		color: white;
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.method-selector {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.4rem;
		margin-bottom: 0.5rem;
	}

	.method-btn {
		display: flex;
		gap: 0.4rem;
		padding: 0.6rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px;
		cursor: pointer;
		transition: all 0.3s ease;
		align-items: flex-start;
	}

	.method-btn:hover:not(:disabled) {
		border-color: rgba(99, 102, 241, 0.4);
		background: rgba(99, 102, 241, 0.08);
	}

	.method-btn.active {
		border-color: rgba(99, 102, 241, 0.6);
		background: rgba(99, 102, 241, 0.12);
		box-shadow: 0 0 20px rgba(99, 102, 241, 0.1);
	}

	.method-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.method-icon {
		flex-shrink: 0;
		color: #a5b4fc;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 0.125rem;
	}

	.method-info {
		flex: 1;
	}

	.method-info h3 {
		font-size: 0.76rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin: 0 0 0.15rem 0;
	}

	.method-info p {
		font-size: 0.68rem;
		color: rgba(255, 255, 255, 0.5);
		margin: 0;
	}

	.auth-forms {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.auth-form {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-header {
		text-align: center;
		margin-bottom: 0.25rem;
	}

	.form-header h2 {
		font-size: 1rem;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.95);
		margin: 0 0 0.25rem 0;
	}

	.form-header p {
		font-size: 0.76rem;
		color: rgba(255, 255, 255, 0.5);
		margin: 0;
	}

	.form-fields {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.field-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.field-group label {
		font-size: 0.76rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
	}

	.field-input {
		padding: 0.5rem 0.7rem;
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 8px;
		font-size: 0.82rem;
		transition: all 0.3s ease;
		background: rgba(255, 255, 255, 0.06);
		color: white;
	}

	.field-input:focus {
		outline: none;
		border-color: rgba(99, 102, 241, 0.6);
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
		background: rgba(255, 255, 255, 0.1);
	}

	.field-input.error {
		border-color: #f87171;
		background: rgba(248, 113, 113, 0.08);
	}

	.field-input::placeholder {
		color: rgba(255, 255, 255, 0.3);
	}

	.field-error {
		font-size: 0.75rem;
		color: #DC2626;
	}

	.label-with-toggle {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.eye-toggle {
		background: none;
		border: none;
		padding: 0.15rem;
		cursor: pointer;
		color: rgba(255, 255, 255, 0.5);
		transition: color 0.2s ease;
		display: flex;
		align-items: center;
	}

	.eye-toggle:hover {
		color: rgba(255, 255, 255, 0.85);
	}

	.quick-access-digits {
		display: grid;
		grid-template-columns: repeat(6, 1fr);
		gap: 0.4rem;
		direction: ltr;
	}

	.digit-input {
		width: 100%;
		padding: 0.5rem 0;
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 8px;
		font-size: 1.1rem;
		font-weight: 600;
		text-align: center;
		transition: all 0.3s ease;
		background: rgba(255, 255, 255, 0.06);
		color: white;
		direction: ltr !important;
	}

	.digit-input:focus {
		outline: none;
		border-color: rgba(99, 102, 241, 0.6);
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
		background: rgba(255, 255, 255, 0.1);
	}

	.digit-input.error {
		border-color: #f87171;
		background: rgba(248, 113, 113, 0.08);
	}

	.field-spacer {
		height: 0;
	}

	.form-options {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.76rem;
		color: rgba(255, 255, 255, 0.7);
		cursor: pointer;
		user-select: none;
	}

	.checkbox-option input {
		width: 16px;
		height: 16px;
		cursor: pointer;
	}

	.checkbox-mark {
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	.auth-submit-btn {
		padding: 0.6rem 0.75rem;
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		min-height: 40px;
		box-shadow: 0 4px 15px rgba(99, 102, 241, 0.3);
	}

	.auth-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(99, 102, 241, 0.4);
	}

	.auth-submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading-spinner {
		display: inline-block;
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.status-message {
		display: flex;
		gap: 0.4rem;
		padding: 0.6rem 0.75rem;
		border-radius: 10px;
		margin-top: 0.4rem;
		align-items: flex-start;
		margin-left: 1.5rem;
		margin-right: 1.5rem;
		margin-bottom: 1rem;
	}

	.error-status {
		background: rgba(248, 113, 113, 0.1);
		border: 1px solid rgba(248, 113, 113, 0.25);
		color: #fca5a5;
	}

	.success-status {
		background: rgba(74, 222, 128, 0.1);
		border: 1px solid rgba(74, 222, 128, 0.25);
		color: #86efac;
	}

	.status-icon {
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	.status-content h4 {
		font-size: 0.76rem;
		font-weight: 600;
		margin: 0 0 0.15rem 0;
	}

	.status-content p {
		font-size: 0.76rem;
		margin: 0;
		opacity: 0.9;
	}

	@media (max-width: 1024px) {
		.login-page {
			padding: 1rem;
			align-items: center;
		}

		.login-content {
			max-width: 440px;
		}
	}

	@media (max-width: 768px) {
		.login-main-card {
			border-radius: 16px;
		}

		.logo-section {
			padding: 1.5rem 1rem 0.75rem;
		}

		.logo {
			width: 90px;
			height: 58px;
		}

		.logo-image {
			width: 65px;
			height: 38px;
		}

		.auth-section {
			padding: 1rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
			gap: 0.3rem;
			margin-bottom: 0.5rem;
		}

		.method-btn {
			padding: 0.5rem;
			gap: 0.25rem;
		}

		.form-header {
			margin-bottom: 0.3rem;
		}

		.form-header h2 {
			font-size: 0.9rem;
		}

		.field-group {
			margin-bottom: 0.3rem;
		}
	}

	@media (max-width: 480px) {
		.login-page {
			padding: 0.75rem;
		}

		.login-content {
			max-width: 100%;
		}

		.login-main-card {
			border-radius: 14px;
		}

		.logo-section {
			padding: 1.25rem 0.75rem 0.5rem;
		}

		.logo {
			width: 80px;
			height: 52px;
		}

		.logo-image {
			width: 58px;
			height: 34px;
		}

		.auth-section {
			padding: 0.75rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
		}

		.method-btn {
			padding: 0.4rem;
		}

		.interface-options {
			grid-template-columns: 1fr 1fr;
			gap: 0.5rem;
		}

		.interface-btn {
			padding: 1rem 0.5rem;
		}
	}

	@media (max-width: 320px) {
		.login-page {
			padding: 0.5rem;
		}

		.logo {
			width: 70px;
			height: 46px;
		}

		.logo-image {
			width: 50px;
			height: 30px;
		}
	}

	@media (orientation: landscape) and (max-height: 500px) {
		.login-page {
			padding: 0.75rem;
			align-items: flex-start;
		}

		.login-main-card {
			display: flex;
			flex-direction: row;
		}

		.logo-section {
			flex: 0 0 200px;
			padding: 1rem;
		}

		.auth-section {
			flex: 1;
			padding: 1rem;
		}
	}

	/* RTL Support */
	:global(html[dir="rtl"]) .back-btn-top {
		flex-direction: row-reverse;
	}

	:global(html[dir="rtl"]) .back-btn-top svg {
		transform: scaleX(-1);
	}

	:global(html[dir="rtl"]) .method-btn {
		text-align: right;
	}

	:global(html[dir="rtl"]) .method-info {
		text-align: right;
	}

	:global(html[dir="rtl"]) .form-header {
		direction: rtl;
	}

	:global(html[dir="rtl"]) .field-group {
		text-align: right;
	}

	:global(html[dir="rtl"]) .field-group label {
		text-align: right;
	}

	:global(html[dir="rtl"]) .field-input {
		text-align: right;
		direction: rtl;
	}

	:global(html[dir="rtl"]) .field-input[type="password"],
	:global(html[dir="rtl"]) .field-input[inputmode="numeric"] {
		direction: ltr;
		text-align: left;
	}

	:global(html[dir="rtl"]) .quick-access-digits {
		direction: ltr !important;
	}

	:global(html[dir="rtl"]) .digit-input {
		direction: ltr !important;
		text-align: center !important;
	}

	:global(html[dir="rtl"]) .checkbox-option {
		flex-direction: row-reverse;
	}

	:global(html[dir="rtl"]) .auth-submit-btn {
		flex-direction: row-reverse;
	}

	:global(html[dir="rtl"]) .status-message {
		flex-direction: row-reverse;
		text-align: right;
	}

	:global(html[dir="rtl"]) .language-toggle-main {
		flex-direction: row-reverse;
	}

	:global(html[dir="rtl"]) .interface-btn {
		direction: rtl;
	}
</style>
