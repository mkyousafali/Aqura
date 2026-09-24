<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { localeData, _, switchLocaleManually, currentLocale } from '$lib/i18n';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import ChangeAccessCode from '$lib/components/shared/ChangeAccessCode.svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let showChangeAccessCode = false;

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
	// Keep the login method cards in code for a future UI restoration.
	const showDesktopLoginMethodCards = false;
	let loginMethod: 'username' | 'quickAccess' = 'quickAccess';
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

	let hideMobile = false;

	onMount(async () => {
		mounted = true;
		hideMobile = window.matchMedia('(min-width: 769px)').matches;
		setTimeout(() => {
			showContent = true;
		}, 300);

		checkExistingAuth();

		// Open the employee login form directly for the Desktop app/login link.
		if ($page.url.searchParams.get('mode') === 'desktop') {
			hideMobile = true;
			if (!$isAuthenticated) chooseInterface('desktop');
		}
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			goto('/');
		}
	}

	function clearForm() {
		loginMethod = 'quickAccess';
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

	function clearQuickAccessInputs() {
		for (let index = 0; index < 6; index++) {
			const input = document.getElementById(`digit-${index}`) as HTMLInputElement | null;
			if (input) input.value = '';
		}
		const firstDigit = document.getElementById('digit-0') as HTMLInputElement | null;
		firstDigit?.focus();
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
				// Clear digits and refocus first field on incorrect code
				quickAccessDigits = ['', '', '', '', '', ''];
				quickAccessCode = '';
				quickAccessValid = false;
				setTimeout(clearQuickAccessInputs, 50);
			}

		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Login failed. Please try again.';
			// Clear digits and refocus first field on any error
			quickAccessDigits = ['', '', '', '', '', ''];
			quickAccessCode = '';
			quickAccessValid = false;
			setTimeout(clearQuickAccessInputs, 50);
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
		
		// Auto-submit when all 6 digits are entered
		if (quickAccessValid && quickAccessDigits.every(d => d !== '') && !isLoading) {
			setTimeout(() => handleQuickAccessLogin(), 100);
		}
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
		if (quickAccessValid && !isLoading) setTimeout(() => handleQuickAccessLogin(), 100);
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
				<aside class="brand-panel" aria-label={$currentLocale === 'ar' ? 'بوابة أقورا المكتبية' : 'Aqura Desktop portal'}>
					<div class="brand-glow brand-glow-one"></div>
					<div class="brand-glow brand-glow-two"></div>
					<div class="brand-panel-content">
						<div class="brand-lockup">
							<div class="brand-logo-card aqura-logo-card">
								<button on:click={handleLogoClick} class="brand-logo-button" type="button" aria-label="Aqura Logo">
									<img src="/icons/Aqura logo.png" alt="Aqura" class="aqura-brand-logo" />
								</button>
							</div>
							<div class="brand-logo-card urban-logo-card">
								<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Urban Market" class="urban-brand-logo" />
							</div>
						</div>

						<div class="brand-copy">
							<span class="eyebrow">{$currentLocale === 'ar' ? 'واجهة سطح المكتب' : 'DESKTOP INTERFACE'}</span>
							<h1>{$currentLocale === 'ar' ? 'مساحة عمل واحدة. تحكّم كامل.' : 'One workspace. Complete control.'}</h1>
							<p>{$currentLocale === 'ar' ? 'إدارة أعمال آمنة وانسيابية في نظام ذكي واحد.' : 'Secure, streamlined business operations in one intelligent system.'}</p>
						</div>

						<div class="security-note">
							<span class="security-icon" aria-hidden="true">
								<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/></svg>
							</span>
							<div>
								<strong>{$currentLocale === 'ar' ? 'دخول محمي' : 'Protected access'}</strong>
								<span>{$currentLocale === 'ar' ? 'يتم التحقق من هويتك عبر نظام أقورا الآمن.' : 'Your identity is verified through Aqura secure access.'}</span>
							</div>
						</div>
					</div>
				</aside>

				<div class="login-workspace">
				<div class="logo-section">
					<div class="logo-header">
						{#if interfaceChoice === null}
							<button 
								class="header-back-btn"
								on:click={goBackToMain}
								disabled={isLoading}
								type="button"
								title="Back"
							>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
							</button>
						{:else}
							<button 
								class="header-back-btn"
								on:click={goBackToChoice}
								disabled={isLoading}
								type="button"
								title="Back"
							>
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
							</button>
						{/if}

						<button 
							class="language-toggle-main" 
							on:click={() => {
								switchLocaleManually($currentLocale === 'ar' ? 'en' : 'ar');
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
							<div class="interface-options">
								<button 
									class="interface-btn desktop-btn"
									on:click={() => chooseInterface('desktop')}
									disabled={isLoading}
									title={$currentLocale === 'ar' ? 'الإدارة' : 'Operations'}
								>
									<div class="interface-icon">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="2" y="4" width="20" height="12" rx="2"/>
											<path d="M2 16h20"/>
											<path d="M8 20h8"/>
										</svg>
									</div>
									<span class="interface-label">{$currentLocale === 'ar' ? 'الإدارة' : 'Operations'}</span>
								</button>

						{#if !hideMobile}
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
							<span class="interface-label">{$_('customer.login.interface.mobile')}</span>
						</button>
						{/if}

								<button 
									class="interface-btn cashier-btn"
									on:click={() => goto('/cashier-interface')}
									disabled={isLoading}
									type="button"
									title={$currentLocale === 'ar' ? 'أدوات الكاشير' : 'Cashier Tools'}
								>
									<div class="interface-icon">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M6 3h12l1 7H5l1-7Z"/>
											<rect x="3" y="10" width="18" height="11" rx="2"/>
											<path d="M7 14h4M7 17h4M15 14h2M15 17h2"/>
											<path d="M8 6h8"/>
										</svg>
									</div>
									<span class="interface-label">{$currentLocale === 'ar' ? 'أدوات الكاشير' : 'Cashier Tools'}</span>
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
						{#if showDesktopLoginMethodCards}
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
						{/if}

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
										<button type="button" class="eye-toggle" on:click={() => showAccessCode = !showAccessCode} aria-label={$currentLocale === 'ar' ? (showAccessCode ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور') : (showAccessCode ? 'Hide password' : 'Show password')} title={$currentLocale === 'ar' ? (showAccessCode ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور') : (showAccessCode ? 'Hide password' : 'Show password')}>
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
										<button type="button" class="eye-toggle" on:click={() => showAccessCode = !showAccessCode} aria-label={$currentLocale === 'ar' ? (showAccessCode ? 'إخفاء رمز الوصول' : 'إظهار رمز الوصول') : (showAccessCode ? 'Hide access code' : 'Show access code')} title={$currentLocale === 'ar' ? (showAccessCode ? 'إخفاء رمز الوصول' : 'إظهار رمز الوصول') : (showAccessCode ? 'Hide access code' : 'Show access code')}>
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
														class:error={!quickAccessValid && quickAccessDigits.every(d => d !== '')}
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
											{#if !quickAccessValid && quickAccessDigits.every(d => d !== '')}
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

						<!-- Change Access Code Link -->
						<button class="change-code-link" on:click={() => showChangeAccessCode = true}>
							🔑 {t('auth.changeAccessCode') || 'Change Access Code'}
						</button>
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
		</div>

		{#if showChangeAccessCode}
			<ChangeAccessCode locale={$currentLocale} on:close={() => showChangeAccessCode = false} />
		{/if}
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

	/* Light theme matching cashier login */
	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: #F9FAFB;
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	/* Background pattern */
	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(107, 114, 128, 0.08) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(156, 163, 175, 0.06) 0%, transparent 50%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236B7280' fill-opacity='0.02'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 900px;
		position: relative;
		z-index: 1;
		min-height: 0;
	}

	/* White card matching cashier */
	.login-main-card {
		background: #FFFFFF;
		border-radius: 16px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1), 0 8px 32px rgba(107, 114, 128, 0.08);
		border: 1px solid rgba(229, 231, 235, 0.8);
		overflow: hidden;
		display: flex;
		flex-direction: column;
		animation: slideInUp 0.8s ease-out;
	}

	@keyframes slideInUp {
		from {
			opacity: 0;
			transform: translateY(40px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	/* Gray gradient header matching cashier */
	.logo-section {
		padding: 1.5rem 2rem;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		position: relative;
	}

	.logo-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		max-width: 600px;
		margin: 0 auto;
		gap: 0.75rem;
	}

	/* Header back button */
	.header-back-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
	}

	.header-back-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}

	.header-back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	:global(html[dir="rtl"]) .header-back-btn svg {
		transform: scaleX(-1);
	}

	.logo {
		flex: 1;
		display: flex;
		justify-content: flex-start;
		background: white;
		padding: 0.75rem 1.25rem;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		max-width: fit-content;
	}

	.logo-image {
		height: 50px;
		width: auto;
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

	/* Language toggle matching cashier */
	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		backdrop-filter: blur(10px);
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}

	.language-toggle-main svg {
		width: 18px;
		height: 18px;
	}

	/* Auth section - light theme */
	.auth-section {
		padding: 2rem 2rem 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.interface-choice {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
	}

	.interface-options {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		justify-items: center;
		margin-top: 0.5rem;
	}

	.interface-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 1.5rem 1rem;
		background: #f9fafb;
		border: 2px solid #e5e7eb;
		border-radius: 14px;
		cursor: pointer;
		transition: all 0.3s ease;
		width: 100%;
		text-align: center;
	}

	.interface-btn:hover:not(:disabled) {
		border-color: #6b7280;
		background: #f3f4f6;
		transform: translateY(-3px);
		box-shadow: 0 8px 24px rgba(107, 114, 128, 0.15);
	}

	.interface-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.interface-icon {
		width: 52px;
		height: 52px;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
	}

	.interface-label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.customer-btn .interface-icon {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
	}

	.customer-btn:hover:not(:disabled) {
		border-color: #6b7280;
		background: #f3f4f6;
		box-shadow: 0 8px 24px rgba(107, 114, 128, 0.15);
	}

	.method-selector {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
		max-width: 500px;
		margin-left: auto;
		margin-right: auto;
	}

	.method-btn {
		display: flex;
		gap: 0.6rem;
		padding: 0.875rem;
		background: #f9fafb;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.3s ease;
		align-items: flex-start;
	}

	.method-btn:hover:not(:disabled) {
		border-color: #9ca3af;
		background: #f3f4f6;
	}

	.method-btn.active {
		border-color: #4b5563;
		background: #f3f4f6;
		box-shadow: 0 0 0 1px #4b5563;
	}

	.method-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.method-icon {
		flex-shrink: 0;
		color: #6b7280;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 0.125rem;
	}

	.method-info {
		flex: 1;
	}

	.method-info h3 {
		font-size: 0.875rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.25rem 0;
	}

	.method-info p {
		font-size: 0.8rem;
		color: #6b7280;
		margin: 0;
	}

	.auth-forms {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-width: 500px;
		margin: 0 auto;
	}

	.auth-form {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.form-header {
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.form-header h2 {
		font-size: 1.75rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.5rem 0;
	}

	.form-header p {
		font-size: 0.95rem;
		color: #6b7280;
		margin: 0;
	}

	.form-fields {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.field-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.field-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		color: #374151;
		font-size: 0.95rem;
	}

	/* Light theme inputs */
	.field-input {
		width: 100%;
		padding: 0.875rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 1rem;
		color: #111827;
		background: white;
		transition: all 0.2s ease;
		outline: none;
	}

	.field-input:focus {
		border-color: #6b7280;
		box-shadow: 0 0 0 3px rgba(107, 114, 128, 0.1);
	}

	.field-input.error {
		border-color: #ef4444;
	}

	.field-input::placeholder {
		color: #9ca3af;
	}

	.field-error {
		display: block;
		color: #ef4444;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	.label-with-toggle {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.eye-toggle {
		background: rgba(107, 114, 128, 0.08);
		border: 1px solid #E2E8F0;
		border-radius: 8px;
		padding: 0.5rem;
		cursor: pointer;
		color: #6B7280;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
	}

	.eye-toggle:hover {
		background: rgba(107, 114, 128, 0.15);
		color: #374151;
		border-color: #9ca3af;
	}

	/* Light theme digit inputs */
	.quick-access-digits {
		display: flex;
		gap: 0.625rem;
		justify-content: center;
		margin-bottom: 0.75rem;
		direction: ltr;
	}

	.digit-input {
		width: 48px;
		height: 48px;
		text-align: center;
		font-size: 1.5rem;
		font-weight: 600;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		background: white;
		color: #1f2937;
		transition: all 0.2s ease;
		outline: none;
		direction: ltr;
	}

	.digit-input:focus {
		border-color: #6b7280;
		box-shadow: 0 0 0 3px rgba(107, 114, 128, 0.1);
		background: #f9fafb;
	}

	.digit-input.error {
		border-color: #ef4444;
	}

	.digit-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.field-spacer {
		height: 1rem;
	}

	.form-options {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #374151;
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

	/* Gray gradient submit button matching cashier */
	.auth-submit-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1.05rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.auth-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 10px 25px rgba(75, 85, 99, 0.3);
	}

	.auth-submit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.change-code-link {
		background: none;
		border: none;
		color: #3b82f6;
		font-size: 13px;
		cursor: pointer;
		padding: 8px 0;
		margin-top: 12px;
		text-decoration: underline;
		transition: color 0.2s;
		display: block;
		width: 100%;
		text-align: center;
	}

	.change-code-link:hover {
		color: #1d4ed8;
	}

	.loading-spinner {
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

	/* Status messages - light theme */
	.status-message {
		display: flex;
		gap: 0.75rem;
		padding: 1rem 1.25rem;
		border-radius: 12px;
		margin-top: 0.5rem;
		align-items: flex-start;
		margin-left: 2rem;
		margin-right: 2rem;
		margin-bottom: 1.5rem;
	}

	.error-status {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
	}

	.success-status {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #16a34a;
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

	/* Responsive */
	@media (max-width: 768px) {
		.login-page {
			padding: 0.5rem;
		}

		.logo-section {
			padding: 1.25rem 1.5rem;
		}

		.auth-section {
			padding: 1.5rem;
		}

		.form-header h2 {
			font-size: 1.5rem;
		}

		.quick-access-digits {
			gap: 0.5rem;
		}

		.digit-input {
			width: 42px;
			height: 42px;
			font-size: 1.25rem;
		}

		.method-selector {
			grid-template-columns: 1fr;
		}

		.interface-options {
			grid-template-columns: 1fr 1fr;
			gap: 0.75rem;
		}
	}

	@media (max-width: 480px) {
		.login-page {
			padding: 0.5rem;
		}

		.logo-section {
			padding: 1rem;
		}

		.auth-section {
			padding: 1rem;
		}

		.interface-options {
			grid-template-columns: 1fr 1fr;
			gap: 0.5rem;
		}

		.interface-btn {
			padding: 1rem 0.5rem;
		}
	}

	/* RTL Support */
	:global(html[dir="rtl"]) .header-back-btn svg {
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

	:global(html[dir="rtl"]) .field-input[type="password"] {
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

	/* Desktop login experience */
	.login-page {
		padding: clamp(1.25rem, 3vw, 3.5rem);
		background:
			radial-gradient(circle at 8% 12%, rgba(24, 177, 224, 0.14), transparent 30%),
			radial-gradient(circle at 92% 88%, rgba(30, 78, 150, 0.12), transparent 34%),
			linear-gradient(145deg, #eef7fb 0%, #f8fbfd 44%, #edf2f8 100%);
	}

	.login-page::before {
		background-image:
			linear-gradient(rgba(11, 70, 111, 0.035) 1px, transparent 1px),
			linear-gradient(90deg, rgba(11, 70, 111, 0.035) 1px, transparent 1px);
		background-size: 44px 44px;
		mask-image: linear-gradient(to bottom right, black, transparent 72%);
	}

	.login-content {
		max-width: 1180px;
	}

	.login-main-card {
		display: grid;
		grid-template-columns: minmax(360px, 0.92fr) minmax(520px, 1.08fr);
		min-height: min(720px, calc(100dvh - 5rem));
		border: 1px solid rgba(255, 255, 255, 0.88);
		border-radius: 28px;
		background: rgba(255, 255, 255, 0.94);
		box-shadow: 0 32px 90px rgba(15, 48, 79, 0.17), 0 4px 16px rgba(15, 48, 79, 0.08);
		backdrop-filter: blur(22px);
	}

	.brand-panel {
		position: relative;
		overflow: hidden;
		min-width: 0;
		color: #fff;
		background:
			linear-gradient(155deg, rgba(5, 31, 63, 0.97) 0%, rgba(5, 58, 102, 0.98) 52%, rgba(4, 91, 125, 0.97) 100%);
	}

	.brand-panel::before {
		content: '';
		position: absolute;
		inset: 0;
		background:
			linear-gradient(125deg, transparent 0 56%, rgba(255, 255, 255, 0.055) 56% 56.4%, transparent 56.4%),
			radial-gradient(circle at 70% 22%, rgba(33, 211, 238, 0.19), transparent 24%);
	}

	.brand-glow {
		position: absolute;
		border-radius: 999px;
		filter: blur(2px);
		pointer-events: none;
	}

	.brand-glow-one {
		width: 300px;
		height: 300px;
		right: -150px;
		top: -90px;
		border: 1px solid rgba(87, 220, 244, 0.24);
		box-shadow: inset 0 0 70px rgba(18, 183, 218, 0.08);
	}

	.brand-glow-two {
		width: 460px;
		height: 460px;
		left: -300px;
		bottom: -260px;
		background: rgba(20, 184, 201, 0.12);
	}

	.brand-panel-content {
		position: relative;
		z-index: 1;
		display: flex;
		flex-direction: column;
		min-height: 100%;
		padding: clamp(2.4rem, 4vw, 4.6rem);
		box-sizing: border-box;
	}

	.brand-lockup {
		display: flex;
		align-items: center;
		gap: 1.4rem;
		width: fit-content;
		align-self: center;
	}

	.brand-logo-card {
		position: relative;
		z-index: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 112px;
		height: 96px;
		padding: 0.55rem;
		box-sizing: border-box;
		border: none;
		border-radius: 18px;
		background: #ffffff;
		box-shadow: none;
	}

	.brand-logo-card::before {
		content: '';
		position: absolute;
		inset: -4px;
		pointer-events: none;
		border: 1px solid rgba(255, 255, 255, 0.55);
		border-radius: 22px;
		background: transparent;
		box-shadow: none;
		z-index: 0;
	}

	.brand-logo-card > * {
		position: relative;
		z-index: 1;
	}

	.aqura-logo-card,
	.urban-logo-card {
		background: #ffffff;
	}

	.aqura-brand-logo {
		display: block;
		object-fit: contain;
		filter: drop-shadow(0 5px 9px rgba(0, 0, 0, 0.15));
		width: 86px;
		height: 72px;
	}

	.brand-logo-button {
		display: block;
		padding: 0;
		border: 0;
		background: transparent;
		cursor: pointer;
	}

	.urban-brand-logo {
		display: block;
		width: 86px;
		height: 72px;
		object-fit: contain;
	}

	.brand-copy {
		margin: auto 0;
		padding: 3rem 0;
	}

	.eyebrow {
		display: inline-flex;
		align-items: center;
		gap: 0.55rem;
		font-size: 0.72rem;
		font-weight: 800;
		letter-spacing: 0.18em;
		color: #75e7f4;
	}

	.eyebrow::before {
		content: '';
		width: 24px;
		height: 2px;
		border-radius: 2px;
		background: currentColor;
	}

	.brand-copy h1 {
		max-width: 470px;
		margin: 1.1rem 0 1rem;
		font-size: clamp(2.3rem, 4.1vw, 4.4rem);
		font-weight: 760;
		line-height: 1.02;
		letter-spacing: -0.045em;
		text-wrap: balance;
		animation: headlineFadeIn 5.5s cubic-bezier(0.22, 1, 0.36, 1) 0.25s infinite both;
	}

	@keyframes headlineFadeIn {
		0% {
			opacity: 0;
			transform: translateY(22px);
			filter: blur(5px);
		}
		20%,
		82% {
			opacity: 1;
			transform: translateY(0);
			filter: blur(0);
		}
		100% {
			opacity: 0;
			transform: translateY(-8px);
			filter: blur(3px);
		}
	}

	.brand-copy p {
		max-width: 430px;
		margin: 0;
		font-size: 1rem;
		line-height: 1.75;
		color: rgba(231, 248, 255, 0.76);
		animation: headlineFadeIn 5.5s cubic-bezier(0.22, 1, 0.36, 1) 0.25s infinite both;
	}

	.security-note {
		display: flex;
		align-items: center;
		gap: 0.9rem;
		padding-top: 1.5rem;
		border-top: 1px solid rgba(255, 255, 255, 0.13);
	}

	.security-icon {
		display: grid;
		place-items: center;
		width: 42px;
		height: 42px;
		border-radius: 13px;
		color: #72e7f3;
		background: rgba(31, 202, 224, 0.12);
		border: 1px solid rgba(91, 222, 239, 0.2);
		flex: 0 0 auto;
	}

	.security-icon svg {
		width: 21px;
		height: 21px;
	}

	.security-note div {
		display: grid;
		gap: 0.2rem;
	}

	.security-note strong {
		font-size: 0.86rem;
	}

	.security-note span:not(.security-icon) {
		font-size: 0.75rem;
		line-height: 1.4;
		color: rgba(227, 246, 253, 0.62);
	}

	.login-workspace {
		display: flex;
		flex-direction: column;
		min-width: 0;
		background: rgba(255, 255, 255, 0.98);
	}

	.logo-section {
		padding: 1.4rem clamp(1.7rem, 3.4vw, 3.4rem) 0;
		background: transparent;
		color: #15334d;
	}

	.logo-header {
		max-width: none;
		margin: 0;
	}

	.header-back-btn,
	.language-toggle-main {
		color: #24465f;
		background: #f3f7fa;
		border: 1px solid #dce7ed;
		box-shadow: 0 3px 10px rgba(16, 56, 84, 0.05);
	}

	.header-back-btn {
		width: 42px;
		height: 42px;
		border-radius: 13px;
	}

	.header-back-btn:hover:not(:disabled),
	.language-toggle-main:hover {
		color: #075985;
		background: #e9f7fb;
		border-color: #b8e5ed;
		transform: translateY(-1px);
	}

	.logo {
		justify-content: center;
		padding: 0;
		background: transparent;
		box-shadow: none;
	}

	.logo-image {
		height: 54px;
		max-width: 130px;
	}

	.language-toggle-main {
		min-height: 42px;
		padding: 0.58rem 0.9rem;
		border-radius: 13px;
		font-size: 0.82rem;
		font-weight: 700;
	}

	.auth-section {
		flex: 1;
		justify-content: center;
		padding: 1.8rem clamp(2.5rem, 5vw, 5.5rem) 1.2rem;
		gap: 1.25rem;
	}

	.auth-forms,
	.interface-choice {
		width: 100%;
		max-width: 510px;
	}

	.auth-form {
		gap: 1.15rem;
	}

	.form-header {
		margin-bottom: 1.25rem;
		text-align: start;
	}

	.form-header::before {
		content: '';
		display: block;
		width: 42px;
		height: 4px;
		margin-bottom: 1.25rem;
		border-radius: 99px;
		background: linear-gradient(90deg, #08b6d5, #1768b0);
	}

	.form-header h2 {
		margin-bottom: 0.55rem;
		font-size: clamp(1.9rem, 2.7vw, 2.65rem);
		font-weight: 760;
		letter-spacing: -0.035em;
		color: #102f49;
	}

	.form-header p {
		font-size: 0.98rem;
		line-height: 1.6;
		color: #688094;
	}

	.form-fields {
		gap: 1.15rem;
	}

	.field-group {
		gap: 0.75rem;
	}

	.field-group label {
		font-size: 0.78rem;
		font-weight: 750;
		letter-spacing: 0.035em;
		text-transform: uppercase;
		color: #466075;
	}

	.eye-toggle {
		width: 38px;
		height: 38px;
		justify-content: center;
		padding: 0;
		border-radius: 11px;
		color: #3e6985;
		background: #f3f8fa;
		border-color: #dce9ee;
	}

	.quick-access-digits {
		justify-content: flex-start;
		gap: clamp(0.55rem, 1vw, 0.75rem);
		margin: 0;
	}

	.digit-input {
		width: clamp(52px, 4.6vw, 61px);
		height: clamp(58px, 5.2vw, 68px);
		box-sizing: border-box;
		border: 1px solid #cbdce5;
		border-radius: 15px;
		background: #f8fbfc;
		font-size: 1.65rem;
		font-weight: 760;
		color: #123a56;
		caret-color: #089bb9;
		box-shadow: inset 0 1px 2px rgba(15, 56, 82, 0.025);
	}

	.digit-input:hover:not(:disabled) {
		border-color: #9cc8d6;
		background: #fff;
	}

	.digit-input:focus {
		border-color: #0aa8c4;
		background: #fff;
		box-shadow: 0 0 0 4px rgba(10, 168, 196, 0.13), 0 9px 24px rgba(13, 105, 139, 0.08);
		transform: translateY(-2px);
	}

	.field-spacer {
		display: none;
	}

	.checkbox-option {
		width: fit-content;
		gap: 0.7rem;
		font-size: 0.9rem;
		font-weight: 550;
		color: #425c70;
	}

	.checkbox-option input {
		width: 18px;
		height: 18px;
		accent-color: #087fa5;
	}

	.auth-submit-btn {
		min-height: 58px;
		margin-top: 0.35rem;
		border-radius: 15px;
		background: linear-gradient(115deg, #087ca5 0%, #075b91 52%, #063d70 100%);
		font-size: 1rem;
		font-weight: 760;
		letter-spacing: 0.01em;
		box-shadow: 0 13px 28px rgba(7, 91, 145, 0.22);
	}

	.auth-submit-btn:hover:not(:disabled) {
		box-shadow: 0 18px 34px rgba(7, 91, 145, 0.31);
		transform: translateY(-2px);
	}

	.auth-submit-btn:focus-visible,
	.change-code-link:focus-visible,
	.header-back-btn:focus-visible,
	.language-toggle-main:focus-visible,
	.eye-toggle:focus-visible {
		outline: 3px solid rgba(8, 162, 193, 0.25);
		outline-offset: 3px;
	}

	.change-code-link {
		width: fit-content;
		margin: 0.2rem auto 0;
		padding: 0.65rem 0.8rem;
		border-radius: 10px;
		color: #176b9e;
		font-size: 0.82rem;
		font-weight: 650;
		text-decoration: none;
	}

	.change-code-link:hover {
		color: #075985;
		background: #eef8fb;
	}

	.status-message {
		margin: 0 clamp(2.5rem, 5vw, 5.5rem) 2rem;
		border-radius: 14px;
		box-shadow: 0 8px 24px rgba(16, 58, 84, 0.07);
	}

	.interface-options {
		gap: 1rem;
	}

	.interface-btn {
		min-height: 155px;
		padding: 1.5rem;
		border: 1px solid #d8e6ec;
		border-radius: 18px;
		background: #f8fbfc;
	}

	.desktop-btn,
	.cashier-btn {
		animation: interfaceHeartbeat 2.8s ease-in-out infinite;
	}

	@keyframes interfaceHeartbeat {
		0%,
		55%,
		100% {
			transform: scale(1);
		}
		8% {
			transform: scale(1.025);
		}
		15% {
			transform: scale(1);
		}
		23% {
			transform: scale(1.018);
		}
		31% {
			transform: scale(1);
		}
	}

	.interface-btn:hover:not(:disabled) {
		animation-play-state: paused;
		border-color: #61b6cc;
		background: #f1fbfd;
		box-shadow: 0 14px 30px rgba(21, 100, 129, 0.12);
	}

	.interface-icon {
		width: 58px;
		height: 58px;
		border-radius: 16px;
		background: linear-gradient(135deg, #0aa8c4, #075b91);
		box-shadow: 0 10px 22px rgba(7, 91, 145, 0.2);
	}

	.interface-label {
		font-size: 0.94rem;
		color: #24465f;
	}

	:global(html[dir="rtl"]) .brand-panel,
	:global(html[dir="rtl"]) .login-workspace {
		direction: rtl;
	}

	:global(html[dir="rtl"]) .brand-copy h1 {
		letter-spacing: 0;
		line-height: 1.18;
	}

	:global(html[dir="rtl"]) .form-header,
	:global(html[dir="rtl"]) .form-header p {
		text-align: right;
	}

	:global(html[dir="rtl"]) .form-header::before {
		margin-left: 0;
		margin-right: 0;
	}

	:global(html[dir="rtl"]) .label-with-toggle {
		flex-direction: row;
	}

	:global(html[dir="rtl"]) .quick-access-digits {
		justify-content: flex-end;
	}

	:global(html[dir="rtl"]) .checkbox-option {
		flex-direction: row;
	}

	@media (max-width: 980px) {
		.login-page {
			padding: 1rem;
		}

		.login-main-card {
			grid-template-columns: minmax(280px, 0.75fr) minmax(480px, 1.25fr);
			min-height: min(680px, calc(100dvh - 2rem));
		}

		.brand-panel-content {
			padding: 2.2rem;
		}

		.brand-copy h1 {
			font-size: 2.55rem;
		}

		.auth-section {
			padding-inline: 2.5rem;
		}

		.status-message {
			margin-inline: 2.5rem;
		}
	}

	@media (max-width: 760px) {
		.login-main-card {
			display: flex;
			min-height: auto;
			border-radius: 22px;
		}

		.brand-panel {
			display: none;
		}

		.logo-section {
			padding: 1.1rem 1.2rem 0;
		}

		.auth-section {
			padding: 1.8rem 1.3rem 1rem;
		}

		.form-header h2 {
			font-size: 1.9rem;
		}

		.quick-access-digits {
			justify-content: center;
			gap: 0.42rem;
		}

		.digit-input {
			width: clamp(40px, 11vw, 52px);
			height: 55px;
			border-radius: 12px;
		}

		.status-message {
			margin: 0 1.3rem 1.3rem;
		}
	}

	@media (max-height: 720px) and (min-width: 761px) {
		.login-page {
			padding: 0.75rem;
		}

		.login-main-card {
			min-height: calc(100dvh - 1.5rem);
		}

		.brand-panel-content {
			padding-block: 2rem;
		}

		.brand-copy {
			padding-block: 1.5rem;
		}

		.brand-copy h1 {
			font-size: 2.5rem;
		}

		.auth-section {
			padding-block: 1rem;
		}

		.form-header {
			margin-bottom: 0.6rem;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.login-page,
		.login-main-card,
		.brand-copy h1,
		.brand-copy p,
		.desktop-btn,
		.cashier-btn,
		.digit-input,
		.auth-submit-btn,
		.header-back-btn,
		.language-toggle-main {
			animation: none;
			transition: none;
		}
	}
</style>
