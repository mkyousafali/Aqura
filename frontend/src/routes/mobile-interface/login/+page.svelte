<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { persistentAuthService, currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { localeData, currentLocale, switchLocale } from '$lib/i18n';
	import ChangeAccessCode from '$lib/components/shared/ChangeAccessCode.svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import { supabase } from '$lib/utils/supabase';

	let showChangeAccessCode = false;
	$: isAr = $currentLocale === 'ar';
	function toggleSiteLanguage() {
		switchLocale(isAr ? 'en' : 'ar');
	}

	// Branding - pulled from the same login_layout data BrandingManager edits, so the mobile
	// login screen automatically follows whatever colors/logo are set for the public login page.
	// Defaults below match the public login page's own fallback palette (dark green / gold / cream).
	let layout: any = null;
	const LAYOUT_CACHE_KEY = 'login_layout_cache_v1';

	$: brandPageBg = layout?.main_layout?.bg_color || '#f7f2e9';
	$: brandHeaderBg = layout?.topbar?.bg_color || '';
	$: brandPrimaryColor = layout?.main_layout?.contact_btn_color || layout?.main_layout?.headline_text_color || '#1f3d2f';
	$: brandAccentColor = layout?.main_layout?.headline_highlight_color || '#c8912f';
	$: brandLogoUrl = (layout?.topbar?.logo_enabled !== false ? layout?.topbar?.logo_url : '') || $iconUrlMap['aqura-logo'] || '/icons/Aqura logo.png';
	$: footerCopyrightText =
		layout?.footer?.[$currentLocale === 'ar' ? 'ar' : 'en']?.copyright ??
		($currentLocale === 'ar' ? '© 2026 يو مارت. جميع الحقوق محفوظة.' : '© 2026 Urban Market. All Rights Reserved.');

	function loadBrandingFromCache() {
		if (typeof window === 'undefined') return;
		try {
			const cached = window.localStorage.getItem(LAYOUT_CACHE_KEY);
			if (cached) layout = JSON.parse(cached);
		} catch (e) {
			// Ignore malformed/unavailable cache
		}
	}

	async function loadBranding() {
		try {
			const { data, error } = await supabase.rpc('get_login_layout');
			if (error) throw error;
			layout = data;
			if (typeof window !== 'undefined') {
				try {
					window.localStorage.setItem(LAYOUT_CACHE_KEY, JSON.stringify(data));
				} catch (e) {
					// Storage full/unavailable - not critical
				}
			}
		} catch (e) {
			console.error('Failed to load branding for mobile login:', e);
		}
	}

	// Helper function to get translations
	function t(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	// Quick Access form
	let quickAccessCode = '';
	let quickAccessDigits = ['', '', '', '', '', ''];
	let showAccessCode = false;
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';
	let quickAccessValid = true;

	// Animation states
	let mounted = false;
	let showContent = false;

	onMount(async () => {
		// Show cached branding instantly (if available) then revalidate in the background so
		// the mobile login screen matches the current public login page colors/logo.
		loadBrandingFromCache();
		loadBranding();

		mounted = true;
		setTimeout(() => {
			showContent = true;
			// Auto-focus first digit input after content is visible
			setTimeout(() => {
				const firstDigit = document.getElementById('digit-0') as HTMLInputElement;
				if (firstDigit) firstDigit.focus();
			}, 100);
		}, 300);

		// Check if user is already logged in
		checkExistingAuth();
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			// Ensure mobile preference is set for existing auth
			interfacePreferenceService.forceMobileInterface($currentUser.id);
			// User is already logged in, redirect to mobile dashboard
			goto('/mobile-interface');
		}
	}

	function validateQuickAccess() {
		quickAccessCode = quickAccessDigits.join('');
		const isNumeric = /^[0-9]+$/.test(quickAccessCode);
		quickAccessValid = quickAccessCode.length === 6 && isNumeric;
		return quickAccessValid;
	}

	async function handleQuickAccessLogin() {
		if (!validateQuickAccess()) {
			errorMessage = t('mobile.login.codeRequired');
			return;
		}

		isLoading = true;
		errorMessage = '';
		successMessage = '';

		// Add timeout to prevent hanging
		const timeoutMs = 15000; // Reduced to 15 seconds since auth completes quickly
		let timeoutId: NodeJS.Timeout;

		try {
			console.log('🔍 [Mobile Login] Starting quick access login with code:', quickAccessCode);
			
			const loginPromise = persistentAuthService.loginWithQuickAccess(quickAccessCode, 'mobile');
			const timeoutPromise = new Promise((_, reject) => {
				timeoutId = setTimeout(() => {
					reject(new Error(t('mobile.login.timeoutError')));
				}, timeoutMs);
			});

			const result = await Promise.race([loginPromise, timeoutPromise]) as Awaited<ReturnType<typeof persistentAuthService.loginWithQuickAccess>>;
			
			// Clear timeout if login completed
			if (timeoutId) clearTimeout(timeoutId);
			
			console.log('🔍 [Mobile Login] Login result:', result);
			
			if (result.success) {
				successMessage = t('mobile.login.accessingSystem');
				console.log('✅ [Mobile Login] Login successful, redirecting to mobile dashboard');
				
				// Store strong mobile interface preference for this user
				interfacePreferenceService.forceMobileInterface(result.user?.id);
				console.log('🔒 [Mobile Login] Mobile interface preference locked for user:', result.user?.id);
				
				// Force immediate redirect with multiple fallback methods
				console.log('🔄 [Mobile Login] Attempting navigation to /mobile...');
				
				try {
					// Primary method: SvelteKit goto
					await goto('/mobile-interface');
					console.log('✅ [Mobile Login] SvelteKit navigation successful');
				} catch (gotoError) {
					console.warn('⚠️ [Mobile Login] SvelteKit navigation failed, using window.location:', gotoError);
					
					// Fallback method: Direct window navigation
					window.location.href = '/mobile-interface';
				}
			} else {
				console.error('❌ [Mobile Login] Login failed:', result.error);
				errorMessage = result.error || t('mobile.login.invalidCode');
				// Clear digits and refocus first field on incorrect code
				quickAccessDigits = ['', '', '', '', '', ''];
				quickAccessCode = '';
				quickAccessValid = false;
				setTimeout(() => {
					const firstDigit = document.getElementById('digit-0') as HTMLInputElement;
					if (firstDigit) {
						firstDigit.value = '';
						firstDigit.focus();
					}
				}, 50);
			}

		} catch (error) {
			// Clear timeout on error
			if (timeoutId) clearTimeout(timeoutId);
			
			console.error('❌ [Mobile Login] Login error:', error);
			
			// Handle different types of errors
			if (error instanceof Error) {
				if (error.message.includes('timed out')) {
					errorMessage = t('mobile.login.timeoutError');
				} else if (error.message.includes('fetch')) {
					errorMessage = t('mobile.login.networkError');
				} else {
					errorMessage = error.message;
				}
			} else {
				errorMessage = t('mobile.login.loginFailedError');
			}
			// Clear digits and refocus first field on any error
			quickAccessDigits = ['', '', '', '', '', ''];
			quickAccessCode = '';
			quickAccessValid = false;
			setTimeout(() => {
				const firstDigit = document.getElementById('digit-0') as HTMLInputElement;
				if (firstDigit) {
					firstDigit.value = '';
					firstDigit.focus();
				}
			}, 50);
		} finally {
			// Ensure loading state is always reset
			console.log('🔍 [Mobile Login] Resetting loading state');
			isLoading = false;
			
			// Clear timeout just in case
			if (timeoutId) clearTimeout(timeoutId);
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !isLoading && quickAccessDigits.every(d => d !== '')) {
			event.preventDefault();
			handleQuickAccessLogin();
		}
	}

	// Handle quick access digit input
	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			// Take only the last digit entered
			quickAccessDigits[index] = value.slice(-1);
			input.value = quickAccessDigits[index];
			
			// Auto-focus next input if this one is filled and not the last
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
		
		// Handle backspace
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (quickAccessDigits[index] !== '') {
				// Clear current digit
				quickAccessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				// Move to previous input and clear it
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
		
		// Handle arrow keys
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
		
		// Allow only numeric input
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		// Fill digits from paste
		for (let i = 0; i < 6; i++) {
			quickAccessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = quickAccessDigits[i];
			}
		}
		
		// Focus the last filled input or first empty one
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}
		
		validateQuickAccess();
	}

	function goBackToMainLogin() {
		goto('/login');
	}
</script>

<svelte:head>
	<title>{t('mobile.login.title')} - {t('app.name')}</title>
	<meta name="description" content="{t('mobile.login.footer')}" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content={brandPrimaryColor} />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

<div
	class="mobile-login-page"
	class:mounted
	class:rtl={$currentLocale === 'ar'}
	style="--brand-bg: {brandPageBg}; --brand-primary: {brandPrimaryColor}; --brand-accent: {brandAccentColor}; {brandHeaderBg ? `--brand-header-bg: ${brandHeaderBg};` : ''}"
>
	{#if showContent}
		<!-- Top Bar -->
		<div class="mobile-header">
			<button class="back-btn" on:click={goBackToMainLogin} disabled={isLoading} aria-label="{t('nav.goBack')}">
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M19 12H5M12 19l-7-7 7-7"/>
				</svg>
			</button>
			
			<div class="language-toggle-container">
				<button class="lang-toggle-btn" on:click={toggleSiteLanguage}>{isAr ? 'English' : 'العربية'}</button>
			</div>
		</div>

		<div class="mobile-login-content">
			<!-- Logo Card -->
			<div class="logo-card">
				<img src={brandLogoUrl} alt="Logo" class="logo-image" />
				<p class="app-description">{t('app.description')}</p>
			</div>

			<!-- Quick Access Form -->
			<div class="mobile-auth-section">
				<div class="auth-heading">
					<h1 class="page-title">{t('mobile.login.quickAccess')}</h1>
					<p class="page-subtitle">{t('mobile.login.subtitle')}</p>
				</div>
				<form class="mobile-auth-form" on:submit|preventDefault={handleQuickAccessLogin}>
					<div class="form-fields">
						<div class="field-group">
							<label class="field-label" for="digit-0">{t('mobile.login.accessCode')}</label>
							<div class="digits-with-toggle">
							<div class="quick-access-digits">
								{#each quickAccessDigits as digit, index}
									<input 
										id="digit-{index}"
										type={showAccessCode ? 'text' : 'password'} 
										class="digit-input"
										class:error={!quickAccessValid && quickAccessDigits.every(d => d !== '')}
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
							<button type="button" class="eye-toggle" on:click={() => showAccessCode = !showAccessCode} tabindex="-1">
								{#if showAccessCode}
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
								{:else}
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
								{/if}
							</button>
						</div>
						{#if !quickAccessValid && quickAccessDigits.every(d => d !== '')}
							<span class="field-error">{t('mobile.login.invalidDigitError')}</span>
						{/if}
						</div>
					</div>

					<button 
						type="submit" 
						class="mobile-submit-btn"
						disabled={isLoading || quickAccessDigits.some(d => d === '')}
					>
						{#if isLoading}
							<span class="loading-spinner"></span>
							{t('mobile.login.accessingSystem')}
						{:else}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M9 12l2 2 4-4"/>
								<circle cx="12" cy="12" r="10"/>
							</svg>
							{t('mobile.login.accessButton')}
						{/if}
					</button>
				</form>

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
							<h4>{t('mobile.login.accessDenied')}</h4>
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
							<h4>{t('mobile.login.accessGranted')}</h4>
							<p>{successMessage}</p>
						</div>
					</div>
				{/if}
				<!-- Change Access Code Button -->
				<button class="change-code-link" on:click={() => showChangeAccessCode = true}>
					🔑 {t('auth.changeAccessCode') || 'Change Access Code'}
				</button>
				<p class="secure-footnote">🔒 {t('mobile.login.secureLogin')}</p>
			</div>
		</div>

		<footer class="mobile-footer" style={layout?.footer?.bg_color ? `background: ${layout.footer.bg_color}` : undefined}>
			<span>{footerCopyrightText}</span>
			<a href="/privacy">{isAr ? 'سياسة الخصوصية' : 'Privacy Policy'}</a>
		</footer>
	{/if}

	{#if showChangeAccessCode}
		<ChangeAccessCode locale={$currentLocale} on:close={() => showChangeAccessCode = false} />
	{/if}
</div>

<style>
	.change-code-link {
		background: none;
		border: none;
		color: var(--brand-primary, #1f3d2f);
		font-size: 13px;
		cursor: pointer;
		padding: 8px 0;
		margin-top: 12px;
		text-decoration: underline;
		transition: color 0.2s;
		align-self: center;
	}

	.change-code-link:hover {
		color: var(--brand-accent, #c8912f);
	}

	/* Mobile-first login page - mirrors the public login page's cream + green/gold palette,
	   driven by CSS vars set from BrandingManager (falls back to the same defaults as /login). */
	.mobile-login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		background: var(--brand-bg, #f7f2e9);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
		color: #2a2a2a;
		-webkit-overflow-scrolling: touch;
	}

	.mobile-login-page::before {
		content: '';
		position: fixed;
		inset: 0;
		z-index: 0;
		pointer-events: none;
		background:
			radial-gradient(circle at 12% 10%, color-mix(in srgb, var(--brand-primary, #1f3d2f) 35%, transparent), transparent 40%),
			radial-gradient(circle at 88% 12%, color-mix(in srgb, var(--brand-accent, #c8912f) 35%, transparent), transparent 40%),
			radial-gradient(circle at 20% 90%, color-mix(in srgb, var(--brand-accent, #c8912f) 18%, transparent), transparent 45%);
		filter: blur(60px);
	}

	.mobile-login-page.mounted {
		opacity: 1;
	}

	.mobile-login-content {
		position: relative;
		z-index: 1;
	}

	.mobile-login-content {
		width: 100%;
		max-width: 480px;
		margin: 0 auto;
		padding: 0.35rem 0.5rem 0.5rem;
		flex: 1;
		display: flex;
		flex-direction: column;
	}

	.mobile-footer {
		position: relative;
		z-index: 1;
		width: 100%;
		background: rgba(17, 17, 17, 0.6);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border-top: 1px solid rgba(255, 255, 255, 0.08);
		color: #cfcfcf;
		padding: 0.9rem 1rem;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
		font-size: 0.7rem;
	}

	.mobile-footer a {
		color: #b8b8b8;
		text-decoration: none;
		white-space: nowrap;
	}

	.mobile-footer a:hover {
		color: #ffffff;
	}

	/* Header Section - dark gradient card matching the public login page's top bar */
	.mobile-header {
		text-align: center;
		width: 100%;
		position: sticky;
		top: 0;
		z-index: 20;
		background: var(--brand-header-bg, linear-gradient(180deg, rgba(50, 50, 50, 0.92) 0%, rgba(10, 10, 10, 0.95) 55%, rgba(0, 0, 0, 0.97) 100%));
		border-radius: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		height: 52px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
		color: #ffffff;
	}

	.back-btn {
		position: absolute;
		top: 50%;
		left: 0.65rem;
		transform: translateY(-50%);
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.4rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 6px;
		color: white;
		font-size: 0.76rem;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		backdrop-filter: blur(10px);
	}

	.back-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-50%) translateX(-2px);
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.language-toggle-container {
		position: absolute;
		top: 50%;
		right: 0.65rem;
		transform: translateY(-50%);
		z-index: 10;
	}

	.lang-toggle-btn {
		background: rgba(255, 255, 255, 0.1);
		border: 1.5px solid rgba(255, 255, 255, 0.35);
		border-radius: 20px;
		color: #ffffff;
		font-size: 0.72rem;
		font-weight: 600;
		padding: 0.3rem 0.7rem;
		cursor: pointer;
		transition: background 0.2s;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
	}

	.lang-toggle-btn:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.logo-card {
		position: relative;
		z-index: 2;
		width: calc(100% - 2rem);
		max-width: 260px;
		margin: 0.5rem auto 0.6rem;
		background: #ffffff;
		border: 1px solid color-mix(in srgb, var(--brand-accent, #c8912f) 30%, transparent);
		border-radius: 16px;
		padding: 0.9rem 1rem 0.75rem;
		text-align: center;
		box-shadow: 0 16px 32px -10px rgba(0, 0, 0, 0.22), 0 2px 8px rgba(0, 0, 0, 0.08);
	}

	.logo-image {
		width: 100%;
		max-width: 180px;
		height: auto;
		object-fit: contain;
		margin: 0 auto;
		display: block;
	}

	.app-name {
		font-size: 1.5rem;
		font-weight: 800;
		margin: 0.4rem 0 0.15rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
		color: #ffffff;
		letter-spacing: -0.02em;
	}

	.app-description {
		font-size: 0.76rem;
		opacity: 0.8;
		font-weight: 400;
		margin: 0.3rem 0 0;
		color: #4b5563;
	}

	.page-title {
		font-size: 1.15rem;
		font-weight: 700;
		margin-bottom: 0.2rem;
		color: var(--brand-primary, #1f3d2f);
		letter-spacing: -0.01em;
	}

	.page-subtitle {
		font-size: 0.8rem;
		opacity: 0.75;
		font-weight: 400;
		color: #4b5563;
	}

	.auth-heading {
		text-align: center;
		margin-bottom: 0.85rem;
	}

	.field-label {
		display: block;
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--brand-primary, #1f3d2f);
		opacity: 0.75;
		margin-bottom: 0.4rem;
		text-align: center;
	}

	.secure-footnote {
		text-align: center;
		font-size: 0.7rem;
		color: #6b7280;
		margin-top: 0.6rem;
		opacity: 0.85;
	}

	/* Auth Section */
	.mobile-auth-section {
		display: flex;
		flex-direction: column;
	}

	.mobile-auth-form {
		position: relative;
		background: rgba(255, 255, 255, 0.92);
		backdrop-filter: blur(20px);
		border: 1px solid color-mix(in srgb, var(--brand-primary, #1f3d2f) 12%, transparent);
		border-radius: 16px;
		padding: 1.1rem 1rem 0.9rem;
		margin-bottom: 0.6rem;
		box-shadow: 0 16px 32px -8px rgba(0, 0, 0, 0.14), 0 2px 8px rgba(0, 0, 0, 0.06);
		color: #2a2a2a;
		overflow: hidden;
	}

	.mobile-auth-form::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, var(--brand-primary, #1f3d2f), var(--brand-accent, #c8912f));
	}

	/* Form fields */
	.form-fields {
		margin-bottom: 0.4rem;
	}

	.field-group {
		margin-bottom: 0.2rem;
	}

	/* Quick Access Digits */
	.quick-access-digits {
		display: flex;
		gap: 0.4rem;
		justify-content: center;
		align-items: center;
		margin: 0.2rem 0;
		direction: ltr;
	}

	.digit-input {
		width: 40px;
		height: 48px;
		border: 1.5px solid color-mix(in srgb, var(--brand-primary, #1f3d2f) 30%, transparent);
		border-radius: 6px;
		text-align: center;
		font-size: 1.1rem;
		font-weight: 600;
		font-family: 'JetBrains Mono', 'Courier New', monospace;
		background: rgba(255, 255, 255, 0.6);
		color: var(--brand-primary, #1f3d2f);
		transition: all 0.3s ease;
		box-sizing: border-box;
		padding: 0;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		touch-action: manipulation;
		direction: ltr;
	}

	.digit-input:focus {
		outline: none;
		border-color: var(--brand-accent, #c8912f);
		background: rgba(255, 255, 255, 0.9);
		box-shadow: 0 0 0 2px color-mix(in srgb, var(--brand-accent, #c8912f) 30%, transparent);
	}

	.digit-input.error {
		border-color: #EF4444;
		background: rgba(239, 68, 68, 0.1);
	}

	.digit-input:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.digit-input::placeholder {
		color: rgba(31, 61, 47, 0.4);
		font-weight: 400;
	}

	.field-error {
		color: #DC2626;
		font-size: 0.68rem;
		margin-top: 0.3rem;
		display: block;
		text-align: center;
	}

	.digits-with-toggle {
		display: flex;
		align-items: center;
		gap: 0.4rem;
	}

	.digits-with-toggle .quick-access-digits {
		flex: 1;
	}

	.eye-toggle {
		background: rgba(255, 255, 255, 0.5);
		border: 1px solid color-mix(in srgb, var(--brand-primary, #1f3d2f) 25%, transparent);
		border-radius: 6px;
		padding: 0.4rem;
		cursor: pointer;
		color: var(--brand-primary, #1f3d2f);
		opacity: 0.7;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		touch-action: manipulation;
	}

	.eye-toggle:hover {
		background: rgba(255, 255, 255, 0.8);
		opacity: 1;
	}

	/* Submit button - matches the public login page's .btn-primary style */
	.mobile-submit-btn {
		width: 100%;
		padding: 0.6rem 0.75rem;
		background: var(--brand-primary, #1f3d2f);
		color: #ffffff;
		border: 1.5px solid var(--brand-primary, #1f3d2f);
		border-radius: 8px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
		min-height: 40px;
	}

	.mobile-submit-btn:hover:not(:disabled) {
		background: var(--brand-accent, #c8912f);
		border-color: var(--brand-accent, #c8912f);
		color: #161616;
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
	}

	.mobile-submit-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.mobile-submit-btn:disabled {
		background: color-mix(in srgb, var(--brand-primary, #1f3d2f) 35%, transparent);
		border-color: transparent;
		color: rgba(255, 255, 255, 0.8);
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.loading-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.35);
		border-top: 2px solid #ffffff;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Status messages */
	.status-message {
		display: flex;
		align-items: flex-start;
		gap: 0.4rem;
		padding: 0.5rem 0.6rem;
		margin-bottom: 0.4rem;
		border-radius: 6px;
		animation: messageSlideIn 0.4s ease-out;
		backdrop-filter: blur(20px);
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
		background: rgba(239, 68, 68, 0.2);
		border: 1px solid rgba(239, 68, 68, 0.3);
		color: #FCA5A5;
	}

	.success-status {
		background: rgba(34, 197, 94, 0.2);
		border: 1px solid rgba(34, 197, 94, 0.3);
		color: #86EFAC;
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
		font-size: 0.72rem;
		margin: 0;
		opacity: 0.9;
	}

	.error-status,
	.success-status {
		color: #2a2a2a;
	}

	.error-status .status-icon,
	.error-status h4 {
		color: #B91C1C;
	}

	.success-status .status-icon,
	.success-status h4 {
		color: #15803D;
	}

	/* Responsive adjustments */
	@media (min-width: 601px) {
		.mobile-login-content {
			max-width: 420px;
			justify-content: center;
			padding: 1.5rem 1rem;
		}

		.mobile-auth-form {
			padding: 1.5rem 1.4rem 1.2rem;
			box-shadow: 0 24px 48px -12px rgba(0, 0, 0, 0.18), 0 4px 12px rgba(0, 0, 0, 0.08);
		}

		.logo-card {
			max-width: 280px;
		}
	}

	@media (max-width: 480px) {
		.mobile-login-content {
			padding: 0.5rem 0.4rem;
		}

		.mobile-auth-form {
			padding: 0.75rem 0.5rem;
		}

		.digit-input {
			width: 36px;
			height: 44px;
			font-size: 1rem;
		}

		.quick-access-digits {
			gap: 0.3rem;
		}

		.app-name {
			font-size: 1.25rem;
		}

		.app-description {
			font-size: 0.72rem;
			margin-bottom: 0.3rem;
		}

		.page-title {
			font-size: 1rem;
		}

		.page-subtitle {
			font-size: 0.72rem;
		}

		.logo-card {
			max-width: 220px;
			padding: 0.7rem 0.8rem 0.6rem;
			margin: 0.9rem auto 1.1rem;
		}

		.logo-image {
			max-width: 150px;
		}
	}

	@media (max-width: 375px) {
		.digit-input {
			width: 32px;
			height: 40px;
			font-size: 0.9rem;
		}

		.quick-access-digits {
			gap: 0.25rem;
		}
	}

	/* Landscape mode adjustments */
	@media (orientation: landscape) and (max-height: 500px) {
		.mobile-login-content {
			padding: 0.4rem;
		}

		.mobile-header {
			height: 44px;
		}

		.logo-card {
			max-width: 190px;
			padding: 0.5rem 0.7rem 0.45rem;
			margin: 0.6rem auto 0.8rem;
		}

		.logo-image {
			max-width: 130px;
		}

		.mobile-auth-form {
			padding: 0.6rem 0.5rem;
		}
	}

	/* RTL Support */
	.mobile-login-page.rtl {
		direction: rtl;
	}

	.mobile-login-page.rtl .mobile-header {
		text-align: center;
	}

	.mobile-login-page.rtl .back-btn {
		left: auto;
		right: 0.65rem;
	}

	.mobile-login-page.rtl .language-toggle-container {
		right: auto;
		left: 0.65rem;
	}

	.mobile-login-page.rtl .form-header h2,
	.mobile-login-page.rtl .form-header p {
		text-align: center;
	}

	.mobile-login-page.rtl .app-name,
	.mobile-login-page.rtl .app-description,
	.mobile-login-page.rtl .page-title,
	.mobile-login-page.rtl .page-subtitle {
		text-align: center;
	}
</style>
