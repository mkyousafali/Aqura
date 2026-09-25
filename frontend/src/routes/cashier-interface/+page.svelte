<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { beforeNavigate } from '$app/navigation';
	import CashierLogin from '$lib/components/cashier-interface/CashierLogin.svelte';
	import CashierInterface from '$lib/components/cashier-interface/CashierInterface.svelte';
	import { 
		initCashierSession, 
		setCashierAuth, 
		clearCashierSession,
		isCashierAuthenticated,
		startCashierSessionGuard,
		stopCashierSessionGuard,
		releaseWindowsCashierSession
	} from '$lib/stores/cashierAuth';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import ContactInfoOverlay from '$lib/components/common/ContactInfoOverlay.svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, switchLocale, hasManualLocaleOverride } from '$lib/i18n';
	import { onNativeLogout } from '$lib/utils/nativeShell';
	import { get } from 'svelte/store';

	function syncAccountLanguage(user: any) {
		if (hasManualLocaleOverride()) return;
		if (user?.default_language && user.default_language !== get(currentLocale)) {
			switchLocale(user.default_language);
		}
	}

	let isLoggedIn = false;
	let cashierUser: any = null;
	let selectedBranch: any = null;
	let kickedNotice = '';
	let removeNativeLogout: (() => void) | null = null;
	const INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000;
	let inactivityTimer: ReturnType<typeof setTimeout> | null = null;
	let lastActivityReset = 0;
	let showInactivityPrompt = false;
	let showReauthentication = false;
	let reauthDigits = ['', '', '', '', '', ''];
	let reauthError = '';
	let reauthLoading = false;

	function clearInactivityTimer() {
		if (inactivityTimer) {
			clearTimeout(inactivityTimer);
			inactivityTimer = null;
		}
	}

	function scheduleInactivityPrompt() {
		clearInactivityTimer();
		if (!isLoggedIn || showInactivityPrompt) return;
		lastActivityReset = Date.now();
		inactivityTimer = setTimeout(() => {
			showInactivityPrompt = true;
			showReauthentication = false;
			reauthDigits = ['', '', '', '', '', ''];
			reauthError = '';
		}, INACTIVITY_TIMEOUT_MS);
	}

	function recordCashierActivity() {
		if (!isLoggedIn || showInactivityPrompt || Date.now() - lastActivityReset < 1000) return;
		scheduleInactivityPrompt();
	}

	onMount(() => {
		// The Windows Cashier app asks for a logout when its window is closed: reuse the normal
		// handleLogout() so the device binding is released and the session is cleared.
		removeNativeLogout = onNativeLogout(handleLogout);

		// Clear any desktop authentication when entering cashier interface
		currentUser.set(null);
		isAuthenticated.set(false);
		
		// Try to restore cashier session from sessionStorage
		const session = initCashierSession();
		
		if (session) {
			cashierUser = session.user;
			selectedBranch = session.branch;
			isLoggedIn = true;
			syncAccountLanguage(cashierUser);
			// Restored a Windows session — re-arm the guard
			startCashierSessionGuard(handleForcedLogout);
			scheduleInactivityPrompt();
		}

		window.addEventListener('pointerdown', recordCashierActivity, true);
		window.addEventListener('pointermove', recordCashierActivity, true);
		window.addEventListener('keydown', recordCashierActivity, true);
		window.addEventListener('touchstart', recordCashierActivity, true);
		window.addEventListener('scroll', recordCashierActivity, true);

	});

	onDestroy(() => {
		if (removeNativeLogout) removeNativeLogout();
		stopCashierSessionGuard();
		clearInactivityTimer();
		if (typeof window !== 'undefined') {
			window.removeEventListener('pointerdown', recordCashierActivity, true);
			window.removeEventListener('pointermove', recordCashierActivity, true);
			window.removeEventListener('keydown', recordCashierActivity, true);
			window.removeEventListener('touchstart', recordCashierActivity, true);
			window.removeEventListener('scroll', recordCashierActivity, true);
		}
	});

	// Leaving the cashier interface (back to interface selection, main login, etc.)
	// must end the session — otherwise it silently restores from sessionStorage
	// if the user returns to /cashier-interface without logging in again.
	//
	// beforeNavigate also fires for a plain page reload / tab close (type 'leave', since the
	// browser is about to unload the document) — that is NOT the user leaving the cashier
	// interface, it's how the language toggle applies its change, so `to` won't resolve to an
	// in-app route and must not be treated as "navigating away".
	beforeNavigate(({ to, type }) => {
		if (type === 'leave' || !to) return;
		const stayingInCashier = to.url.pathname.startsWith('/cashier-interface');
		if (isLoggedIn && !stayingInCashier) {
			releaseWindowsCashierSession();
			stopCashierSessionGuard();
			clearCashierSession();
			isLoggedIn = false;
			cashierUser = null;
			selectedBranch = null;
			currentUser.set(null);
			isAuthenticated.set(false);
		}
	});

	function handleForcedLogout() {
		clearInactivityTimer();
		showInactivityPrompt = false;
		kickedNotice = 'You have been signed out: this account was just used to log in on another Windows device.';
		clearCashierSession();
		isLoggedIn = false;
		cashierUser = null;
		selectedBranch = null;
		currentUser.set(null);
		isAuthenticated.set(false);
	}

	function handleLoginSuccess(event: CustomEvent) {
		cashierUser = event.detail.user;
		selectedBranch = event.detail.branch;
		const sessionToken = event.detail.sessionToken ?? null;
		isLoggedIn = true;
		kickedNotice = '';

		// Save to cashier auth stores and sessionStorage
		setCashierAuth(cashierUser, selectedBranch, sessionToken);
		syncAccountLanguage(cashierUser);

		// Start single-device guard (no-op outside the Windows app)
		startCashierSessionGuard(handleForcedLogout);
		scheduleInactivityPrompt();
	}

	async function handleLogout() {
		clearInactivityTimer();
		showInactivityPrompt = false;
		showReauthentication = false;
		// Best-effort: release the Windows binding so the slot is freed
		await releaseWindowsCashierSession();

		stopCashierSessionGuard();
		isLoggedIn = false;
		cashierUser = null;
		selectedBranch = null;

		// Clear cashier session
		clearCashierSession();

		// Also ensure desktop auth is cleared
		currentUser.set(null);
		isAuthenticated.set(false);
	}

	async function beginReauthentication() {
		showReauthentication = true;
		reauthDigits = ['', '', '', '', '', ''];
		reauthError = '';
		await tick();
		(document.getElementById('reauth-digit-0') as HTMLInputElement | null)?.focus();
	}

	async function verifyReauthentication() {
		const code = reauthDigits.join('');
		if (code.length !== 6 || reauthLoading) return;
		reauthLoading = true;
		reauthError = '';
		try {
			const { data, error } = await supabase.rpc('verify_quick_access_code', { p_code: code });
			if (error || !data?.success || String(data.user?.id) !== String(cashierUser?.id)) {
				throw new Error('invalid');
			}
			showInactivityPrompt = false;
			showReauthentication = false;
			reauthDigits = ['', '', '', '', '', ''];
			scheduleInactivityPrompt();
		} catch {
			reauthError = $currentLocale === 'ar' ? 'رمز الوصول غير صحيح لهذا المستخدم.' : 'The access code does not match this cashier.';
			reauthDigits = ['', '', '', '', '', ''];
			await tick();
			(document.getElementById('reauth-digit-0') as HTMLInputElement | null)?.focus();
		} finally {
			reauthLoading = false;
		}
	}

	function handleReauthInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const digit = input.value.replace(/\D/g, '').slice(-1);
		reauthDigits[index] = digit;
		input.value = digit;
		if (digit && index < 5) {
			(document.getElementById(`reauth-digit-${index + 1}`) as HTMLInputElement | null)?.focus();
		}
		if (reauthDigits.every(value => value !== '')) void verifyReauthentication();
	}

	function handleReauthKeydown(event: KeyboardEvent, index: number) {
		if (event.key === 'Enter') {
			event.preventDefault();
			void verifyReauthentication();
			return;
		}
		if (event.key === 'Backspace' && !reauthDigits[index] && index > 0) {
			(document.getElementById(`reauth-digit-${index - 1}`) as HTMLInputElement | null)?.focus();
		}
	}

	function handleReauthPaste(event: ClipboardEvent) {
		event.preventDefault();
		const digits = (event.clipboardData?.getData('text') || '').replace(/\D/g, '').slice(0, 6);
		reauthDigits = Array.from({ length: 6 }, (_, index) => digits[index] || '');
		if (digits.length === 6) void verifyReauthentication();
	}
</script>

<svelte:head>
	<title>Cashier Interface - Coupon System</title>
</svelte:head>

<div class="cashier-page">
	{#if !isLoggedIn}
		{#if kickedNotice}
			<div class="kicked-banner">
				<span>⚠️ {kickedNotice}</span>
				<button type="button" on:click={() => (kickedNotice = '')} aria-label="Dismiss">✕</button>
			</div>
		{/if}
		<CashierLogin on:loginSuccess={handleLoginSuccess} />
	{:else}
		<CashierInterface 
			user={cashierUser}
			branch={selectedBranch}
			on:logout={handleLogout}
		/>
		<!-- Contact Info Overlay - blocks until WhatsApp & email are provided -->
		<ContactInfoOverlay mode="cashier" employeeId={cashierUser?.id} />
	{/if}

</div>

{#if showInactivityPrompt}
	<div class="inactivity-backdrop" role="presentation">
		<div class="inactivity-dialog" role="dialog" tabindex="-1" aria-modal="true" aria-labelledby="inactivity-title" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
			<div class="inactivity-icon" aria-hidden="true">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
			</div>
			<h2 id="inactivity-title">{$currentLocale === 'ar' ? 'تم إيقاف الجلسة مؤقتاً' : 'Session paused'}</h2>
			<p>{$currentLocale === 'ar' ? 'لم يتم رصد أي نشاط لمدة 3 دقائق. اختر المتابعة أو تسجيل الخروج.' : 'No activity was detected for 3 minutes. Continue securely or log out.'}</p>

			{#if showReauthentication}
				<div class="reauth-section">
					<div class="reauth-label">{$currentLocale === 'ar' ? 'أدخل رمز الوصول المكوّن من 6 أرقام' : 'Enter your 6-digit access code'}</div>
					<div class="reauth-digits" dir="ltr">
						{#each reauthDigits as digit, index}
							<input
								id="reauth-digit-{index}"
								type="password"
								value={digit}
								maxlength="1"
								inputmode="numeric"
								pattern="[0-9]*"
								autocomplete="off"
								disabled={reauthLoading}
								on:input={(event) => handleReauthInput(event, index)}
								on:keydown={(event) => handleReauthKeydown(event, index)}
								on:paste={handleReauthPaste}
							/>
						{/each}
					</div>
					{#if reauthError}<div class="reauth-error" role="alert">{reauthError}</div>{/if}
					<button class="unlock-btn" type="button" on:click={verifyReauthentication} disabled={reauthLoading || reauthDigits.some(value => value === '')}>
						{reauthLoading ? ($currentLocale === 'ar' ? 'جارٍ التحقق…' : 'Verifying…') : ($currentLocale === 'ar' ? 'فتح الجلسة' : 'Unlock session')}
					</button>
				</div>
			{:else}
				<div class="inactivity-actions">
					<button class="continue-btn" type="button" on:click={beginReauthentication}>{$currentLocale === 'ar' ? 'متابعة الجلسة' : 'Continue session'}</button>
					<button class="inactivity-logout-btn" type="button" on:click={handleLogout}>{$currentLocale === 'ar' ? 'تسجيل الخروج' : 'Log out'}</button>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.cashier-page {
		width: 100%;
		min-height: 100vh;
	}

	.inactivity-backdrop {
		position: fixed;
		inset: 0;
		z-index: 10000;
		display: grid;
		place-items: center;
		padding: 1.25rem;
		background: rgba(4, 22, 39, 0.72);
		backdrop-filter: blur(10px);
	}

	.inactivity-dialog {
		width: min(100%, 480px);
		padding: 2.2rem;
		box-sizing: border-box;
		border: 1px solid rgba(255, 255, 255, 0.8);
		border-radius: 24px;
		background: #ffffff;
		box-shadow: 0 28px 80px rgba(0, 20, 38, 0.35);
		text-align: center;
	}

	.inactivity-icon {
		display: grid;
		place-items: center;
		width: 62px;
		height: 62px;
		margin: 0 auto 1.1rem;
		border-radius: 18px;
		color: #087ca5;
		background: #e9f8fb;
		border: 1px solid #c4e9f0;
	}

	.inactivity-icon svg { width: 31px; height: 31px; }
	.inactivity-dialog h2 { margin: 0 0 .65rem; color: #102f49; font-size: 1.65rem; }
	.inactivity-dialog > p { margin: 0 auto 1.5rem; max-width: 390px; color: #60798b; line-height: 1.6; }

	.inactivity-actions { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; }
	.inactivity-actions button, .unlock-btn {
		min-height: 48px;
		padding: .8rem 1rem;
		border-radius: 12px;
		font-size: .95rem;
		font-weight: 750;
		cursor: pointer;
	}
	.continue-btn, .unlock-btn { border: 0; color: white; background: linear-gradient(115deg, #087ca5, #075b91); }
	.inactivity-logout-btn { border: 1px solid #d8e3e9; color: #40596c; background: #f7fafb; }

	.reauth-section { display: grid; gap: 1rem; }
	.reauth-label { color: #405c71; font-size: .85rem; font-weight: 700; }
	.reauth-digits { display: flex; justify-content: center; gap: .55rem; }
	.reauth-digits input {
		width: 50px;
		height: 58px;
		box-sizing: border-box;
		border: 1px solid #cbdce5;
		border-radius: 13px;
		background: #f8fbfc;
		text-align: center;
		font-size: 1.5rem;
		font-weight: 750;
		outline: none;
	}
	.reauth-digits input:focus { border-color: #0aa8c4; background: white; box-shadow: 0 0 0 4px rgba(10, 168, 196, .13); }
	.reauth-error { color: #b42318; font-size: .84rem; }
	.unlock-btn:disabled { opacity: .5; cursor: not-allowed; }

	@media (max-width: 560px) {
		.inactivity-dialog { padding: 1.5rem; }
		.inactivity-actions { grid-template-columns: 1fr; }
		.reauth-digits { gap: .35rem; }
		.reauth-digits input { width: 42px; height: 52px; }
	}

	.kicked-banner {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 200;
		background: #b91c1c;
		color: #fff;
		padding: 10px 16px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		font-size: 14px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
	}
	.kicked-banner button {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.5);
		color: #fff;
		padding: 2px 10px;
		border-radius: 4px;
		cursor: pointer;
	}

	.break-qr-fixed {
		position: fixed;
		top: 12px;
		right: 12px;
		z-index: 100;
	}

	.break-qr-container {
		background: white;
		border-radius: 14px;
		padding: 10px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 5px;
		animation: qrPulse 10s ease-in-out infinite;
	}

	.break-qr-img {
		width: 140px;
		height: 140px;
		border-radius: 6px;
		display: block;
	}

	.break-qr-label {
		font-size: 0.6rem;
		color: #64748b;
		font-weight: 500;
		letter-spacing: 0.3px;
	}

	@keyframes qrPulse {
		0%, 100% { box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2); }
		50% { box-shadow: 0 4px 25px rgba(34, 197, 94, 0.35); }
	}
</style>
