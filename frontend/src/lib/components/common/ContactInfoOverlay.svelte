<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { clearCashierSession } from '$lib/stores/cashierAuth';

	// Portal action: moves element to document.body so it escapes all stacking contexts
	function portal(node: HTMLElement) {
		document.body.appendChild(node);
		return {
			destroy() {
				if (node.parentNode) node.parentNode.removeChild(node);
			}
		};
	}

	// Props - for cashier interface where currentUser store is not used
	export let employeeId: string | null = null;
	export let onComplete: (() => void) | null = null;
	// Mode controls z-index layering:
	// 'desktop' = below sidebar (1200) & taskbar (2000)
	// 'mobile'  = below header (100) & bottom-nav (1000)
	// 'cashier' = covers everything
	export let mode: 'desktop' | 'mobile' | 'cashier' = 'desktop';

	let showOverlay = false;
	let waDigits: string[] = ['5', '', '', '', '', '', '', '', ''];
	let email = '';
	let whatsappError = '';
	let emailError = '';
	let isSaving = false;
	let saveSuccess = false;
	let resolvedEmployeeId: string | null = null;
	let employeeNameEn = '';
	let employeeNameAr = '';
	let privacyAccepted = false;
	let lastCheckedEmpId: string | null = null;
	let digitInputs: HTMLInputElement[] = [];

	// Compose full number from digits
	$: fullWhatsApp = '+966' + waDigits.join('');
	$: isWhatsAppValid = waDigits.every(d => /^[0-9]$/.test(d));
	$: isEmailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
	$: isFormValid = isWhatsAppValid && isEmailValid && privacyAccepted;

	function handleDigitInput(e: Event, index: number) {
		if (index === 0) return; // first digit is fixed as 5
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		if (value.length > 0) {
			waDigits[index] = value[value.length - 1];
			waDigits = [...waDigits];
			input.value = waDigits[index];
			// Auto-focus next
			if (index < 8 && digitInputs[index + 1]) {
				digitInputs[index + 1].focus();
			}
		} else {
			waDigits[index] = '';
			waDigits = [...waDigits];
		}
		whatsappError = '';
	}

	function handleDigitKeydown(e: KeyboardEvent, index: number) {
		if (index === 0) { e.preventDefault(); digitInputs[1]?.focus(); return; }
		if (e.key === 'Backspace' && !waDigits[index] && index > 1) {
			waDigits[index - 1] = '';
			waDigits = [...waDigits];
			digitInputs[index - 1]?.focus();
			e.preventDefault();
		}
		if (e.key === 'ArrowLeft' && index > 1) digitInputs[index - 1]?.focus();
		if (e.key === 'ArrowRight' && index < 8) digitInputs[index + 1]?.focus();
	}

	function handleDigitPaste(e: ClipboardEvent) {
		e.preventDefault();
		let pasted = (e.clipboardData?.getData('text') || '').replace(/[^0-9]/g, '');
		// If pasted starts with 966, skip it
		if (pasted.startsWith('966') && pasted.length > 9) pasted = pasted.slice(3);
		// If starts with 5, skip it (first digit is fixed)
		if (pasted.startsWith('5')) pasted = pasted.slice(1);
		// Fill from index 1 onward (index 0 is always '5')
		for (let i = 0; i < 8 && i < pasted.length; i++) {
			waDigits[i + 1] = pasted[i];
		}
		waDigits = [...waDigits];
		// Focus the next empty box or last
		const nextEmpty = waDigits.findIndex((d, idx) => idx > 0 && !d);
		digitInputs[nextEmpty >= 0 ? nextEmpty : 8]?.focus();
		whatsappError = '';
	}

	onMount(() => {
		checkContactInfo();
	});

	// React to currentUser changes (for desktop/mobile) — re-check when user changes
	$: if ($currentUser) {
		if ($currentUser.id && $currentUser.id !== lastCheckedEmpId) {
			checkContactInfo();
		}
	}

	// React to employeeId prop changes (for cashier)
	$: if (employeeId && employeeId !== lastCheckedEmpId) {
		checkContactInfo();
	}

	async function checkContactInfo() {
		// Use the user's UUID (not employee_id text) to find their hr_employee_master record
		const userId = employeeId || $currentUser?.id;
		if (!userId) return;
		if (userId === lastCheckedEmpId) return;

		resolvedEmployeeId = userId;
		lastCheckedEmpId = userId;

		try {
			// Query by user_id (UUID) column, not id (text like EMP001)
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar, whatsapp_number, email, privacy_policy_accepted')
				.eq('user_id', userId)
				.single();

			if (error) {
				console.error('Error checking contact info:', error);
				return;
			}

			if (data) {
				employeeNameEn = data.name_en || '';
				employeeNameAr = data.name_ar || '';
				// Show overlay if any required field is missing OR privacy not accepted
				if (!data.whatsapp_number || !data.email || !data.privacy_policy_accepted) {
					// Parse existing number into digit boxes
					if (data.whatsapp_number) {
						let raw = data.whatsapp_number.replace(/[^0-9]/g, '');
						if (raw.startsWith('966')) raw = raw.slice(3);
						// First digit is always '5'
						waDigits[0] = '5';
						for (let i = 1; i < 9; i++) {
							// skip the '5' in raw if present
							const rawIdx = raw.startsWith('5') ? i : i;
							waDigits[i] = raw[rawIdx] || '';
						}
						waDigits = [...waDigits];
					}
					email = data.email || '';
					privacyAccepted = data.privacy_policy_accepted || false;
					showOverlay = true;
				}
			}
		} catch (err) {
			console.error('Error checking contact info:', err);
		}
	}

	function validateWhatsApp(): string {
		if (waDigits.some(d => !d)) return 'Enter all 9 digits / أدخل جميع الأرقام التسعة';
		if (!waDigits.every(d => /^[0-9]$/.test(d))) return 'Digits only / أرقام فقط';
		return '';
	}

	function validateEmail(value: string): string {
		if (!value.trim()) return 'Email is required / البريد الإلكتروني مطلوب';
		if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'Enter a valid email address / أدخل بريد إلكتروني صحيح';
		return '';
	}

	async function handleLogout() {
		try {
			// Clear interface preference
			const userId = $currentUser?.id;
			if (userId) {
				interfacePreferenceService.clearPreference(userId);
			}
			// Clear cashier session if in cashier mode
			if (mode === 'cashier') {
				clearCashierSession();
			}
			// Sign out from Supabase FIRST (before touching stores)
			// so the session is actually invalidated before any navigation
			await supabase.auth.signOut();
			// Also do persistent auth service logout
			await persistentAuthService.logout();
		} catch (err) {
			console.error('Logout error:', err);
		}
		// Clear auth stores and force hard redirect
		currentUser.set(null);
		isAuthenticated.set(false);
		window.location.href = '/login';
	}

	async function handleSave() {
		whatsappError = validateWhatsApp();
		emailError = validateEmail(email);

		if (whatsappError || emailError) return;
		if (!resolvedEmployeeId) return;
		if (!privacyAccepted) return;

		isSaving = true;

		try {
			const { error } = await supabase
				.from('hr_employee_master')
				.update({
					whatsapp_number: fullWhatsApp,
					email: email.trim(),
					privacy_policy_accepted: true
				})
				.eq('user_id', resolvedEmployeeId);

			if (error) {
				console.error('Error saving contact info:', error);
				whatsappError = 'Failed to save. Please try again.';
				return;
			}

			saveSuccess = true;
			setTimeout(() => {
				showOverlay = false;
				if (onComplete) onComplete();
			}, 1200);
		} catch (err) {
			console.error('Error saving contact info:', err);
			whatsappError = 'Failed to save. Please try again.';
		} finally {
			isSaving = false;
		}
	}
</script>

{#if showOverlay}
	<div class="contact-overlay {mode}-mode" role="dialog" tabindex="-1" use:portal>
		<div class="overlay-backdrop"></div>
		<div class="overlay-card">
			{#if saveSuccess}
				<div class="success-container">
					<div class="success-icon">✅</div>
					<h2>تم الحفظ بنجاح</h2>
					<p>Saved Successfully!</p>
				</div>
			{:else}
				<div class="overlay-header">
					<div class="header-icon">📱</div>
					<h2>معلومات الاتصال مطلوبة</h2>
					<p class="header-subtitle-en">Contact Information Required</p>

					<!-- Employee name in both languages -->
					{#if employeeNameEn || employeeNameAr}
						<div class="employee-name-block">
							{#if employeeNameAr}
								<p class="employee-name employee-name-ar">{employeeNameAr}</p>
							{/if}
							{#if employeeNameEn}
								<p class="employee-name">{employeeNameEn}</p>
							{/if}
						</div>
					{/if}

					<!-- Instructions -->
					<div class="instructions-box">
						<p class="instruction-text instruction-text-ar">
							⚠️ للمتابعة في استخدام التطبيق، يجب عليك إدخال رقم الواتساب والبريد الإلكتروني والموافقة على سياسة الخصوصية أدناه.
						</p>
						<p class="instruction-text">
							⚠️ To continue using the app, you must provide your WhatsApp number, email address, and accept the privacy policy below.
						</p>
					</div>
				</div>

				<div class="overlay-form">
					<div class="form-group">
						<div class="field-label">
							<span class="label-icon">💬</span>
							<span>رقم الواتساب / WhatsApp Number</span>
						</div>
						<div class="wa-input-row">
							<span class="wa-prefix">+966</span>
							<div class="wa-digits">
								{#each waDigits as digit, i}
									<input
										class="wa-digit-box"
										class:has-error={whatsappError}
										class:filled={digit !== ''}
										class:fixed-digit={i === 0}
										type="tel"
										inputmode="numeric"
										maxlength="1"
										readonly={i === 0}
										tabindex={i === 0 ? -1 : 0}
										value={digit}
										bind:this={digitInputs[i]}
										on:input={(e) => handleDigitInput(e, i)}
										on:keydown={(e) => handleDigitKeydown(e, i)}
										on:paste={handleDigitPaste}
										on:focus={(e) => e.currentTarget.select()}
									/>
								{/each}
							</div>
						</div>
						{#if whatsappError}
							<span class="error-text">{whatsappError}</span>
						{/if}
					</div>

					<div class="form-group">
						<label for="overlay-email">
							<span class="label-icon">📧</span>
							<span>البريد الإلكتروني / Email</span>
						</label>
						<input
							id="overlay-email"
							type="email"
							bind:value={email}
							placeholder="employee@company.com"
							class:has-error={emailError}
							on:input={() => emailError = ''}
						/>
						{#if emailError}
							<span class="error-text">{emailError}</span>
						{/if}
					</div>

					<!-- Privacy Policy Checkbox -->
					<div class="privacy-checkbox-group">
						<p class="privacy-text-ar">
							<span>لقد قرأت وأوافق على</span>
							<a href="/privacy" target="_blank" rel="noopener noreferrer" class="privacy-link">سياسة الخصوصية</a>
						</p>
						<label class="privacy-label">
							<input
								type="checkbox"
								bind:checked={privacyAccepted}
								class="privacy-checkbox"
							/>
							<span class="privacy-text">
								I have read and accept the
								<a href="/privacy" target="_blank" rel="noopener noreferrer" class="privacy-link">Privacy Policy</a>
							</span>
						</label>
					</div>

					<!-- Save button - disabled until all fields valid & privacy accepted -->
					<button
						class="save-btn"
						on:click={handleSave}
						disabled={!isFormValid || isSaving}
					>
						{#if isSaving}
							<span class="spinner"></span>
							جاري الحفظ... / Saving...
						{:else if !isFormValid}
							🔒 أكمل البيانات ووافق على الخصوصية / Fill all fields & accept privacy
						{:else}
							💾 حفظ ومتابعة / Save & Continue
						{/if}
					</button>

					<button class="logout-btn" on:click={handleLogout} type="button">
						🚪 تسجيل الخروج / Logout
					</button>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	:global(.contact-overlay) {
		position: fixed;
		inset: 0;
		z-index: 99999;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: fadeIn 0.3s ease;
		pointer-events: auto;
	}

	:global(.contact-overlay.desktop-mode) {
		z-index: 50000;
	}

	:global(.contact-overlay.mobile-mode) {
		z-index: 50000;
	}

	:global(.contact-overlay.cashier-mode) {
		z-index: 99999;
	}

	:global(.contact-overlay .overlay-backdrop) {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
	}

	:global(.contact-overlay .overlay-card) {
		position: relative;
		background: white;
		border-radius: 24px;
		padding: 40px 36px;
		max-width: 520px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 25px 60px rgba(0, 0, 0, 0.3);
		animation: scaleIn 0.3s ease;
	}

	:global(.contact-overlay .overlay-header) {
		text-align: center;
		margin-bottom: 24px;
	}

	:global(.contact-overlay .header-icon) {
		font-size: 48px;
		margin-bottom: 12px;
	}

	:global(.contact-overlay .overlay-header h2) {
		font-size: 22px;
		font-weight: 800;
		color: #111827;
		margin: 0 0 4px 0;
		direction: rtl;
	}

	:global(.contact-overlay .header-subtitle-en) {
		font-size: 18px;
		font-weight: 700;
		color: #374151;
		margin: 0 0 12px 0;
	}

	:global(.contact-overlay .employee-name-block) {
		background: linear-gradient(135deg, #ecfdf5, #f0fdf4);
		border: 1px solid #a7f3d0;
		border-radius: 12px;
		padding: 10px 16px;
		margin-bottom: 14px;
	}

	:global(.contact-overlay .employee-name) {
		font-size: 17px;
		font-weight: 700;
		color: #059669;
		margin: 0;
		line-height: 1.5;
	}

	:global(.contact-overlay .employee-name-ar) {
		direction: rtl;
		font-size: 16px;
	}

	:global(.contact-overlay .instructions-box) {
		background: #fffbeb;
		border: 1px solid #fde68a;
		border-radius: 12px;
		padding: 12px 16px;
	}

	:global(.contact-overlay .instruction-text) {
		font-size: 13px;
		color: #92400e;
		margin: 0 0 6px 0;
		line-height: 1.6;
		font-weight: 500;
	}

	:global(.contact-overlay .instruction-text-ar) {
		direction: rtl;
		margin-bottom: 0;
	}

	:global(.contact-overlay .overlay-form) {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	:global(.contact-overlay .form-group) {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	:global(.contact-overlay .form-group label),
	:global(.contact-overlay .field-label) {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	:global(.contact-overlay .label-icon) {
		font-size: 16px;
	}

	:global(.contact-overlay .wa-input-row) {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		direction: ltr;
	}

	:global(.contact-overlay .wa-prefix) {
		font-size: 20px;
		font-weight: 800;
		color: #059669;
		background: #ecfdf5;
		border: 2px solid #a7f3d0;
		border-radius: 10px;
		padding: 6px 20px;
		white-space: nowrap;
		user-select: none;
		letter-spacing: 1px;
	}

	:global(.contact-overlay .wa-digits) {
		display: flex;
		gap: 4px;
		width: 100%;
	}

	:global(.contact-overlay .wa-digit-box) {
		flex: 1;
		min-width: 0;
		height: 44px;
		text-align: center;
		font-size: 20px;
		font-weight: 700;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
		padding: 0;
		color: #111827;
		background: white;
		box-sizing: border-box;
	}

	:global(.contact-overlay .wa-digit-box:focus) {
		border-color: #059669;
		box-shadow: 0 0 0 2px rgba(5, 150, 105, 0.2);
	}

	:global(.contact-overlay .wa-digit-box.filled) {
		border-color: #059669;
		background: #f0fdf4;
	}

	:global(.contact-overlay .wa-digit-box.has-error) {
		border-color: #ef4444;
	}

	:global(.contact-overlay .wa-digit-box.fixed-digit) {
		background: #ecfdf5;
		border-color: #059669;
		color: #059669;
		cursor: default;
		font-weight: 800;
	}

	:global(.contact-overlay .form-group input:not(.wa-digit-box)) {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		font-size: 16px;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
		box-sizing: border-box;
	}

	:global(.contact-overlay .form-group input:not(.wa-digit-box):focus) {
		border-color: #059669;
		box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.15);
	}

	:global(.contact-overlay .form-group input:not(.wa-digit-box).has-error) {
		border-color: #ef4444;
	}

	:global(.contact-overlay .error-text) {
		font-size: 12px;
		color: #ef4444;
		font-weight: 500;
	}

	:global(.contact-overlay .save-btn) {
		width: 100%;
		padding: 14px 24px;
		background: linear-gradient(135deg, #059669, #10b981);
		color: white;
		border: none;
		border-radius: 14px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		margin-top: 4px;
	}

	:global(.contact-overlay .save-btn:hover:not(:disabled)) {
		background: linear-gradient(135deg, #047857, #059669);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(5, 150, 105, 0.3);
	}

	:global(.contact-overlay .save-btn:disabled) {
		opacity: 0.7;
		cursor: not-allowed;
	}

	:global(.contact-overlay .logout-btn) {
		width: 100%;
		padding: 10px 24px;
		background: transparent;
		color: #ef4444;
		border: 1.5px solid #fca5a5;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		margin-top: 4px;
	}

	:global(.contact-overlay .logout-btn:hover) {
		background: #fef2f2;
		border-color: #ef4444;
	}

	:global(.contact-overlay .spinner) {
		width: 18px;
		height: 18px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-left-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	:global(.contact-overlay .privacy-checkbox-group) {
		background: #fffbeb;
		border: 2px solid #f59e0b;
		border-radius: 12px;
		padding: 14px 16px;
	}

	:global(.contact-overlay .privacy-label) {
		display: flex;
		align-items: flex-start;
		gap: 10px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: #1e40af;
	}

	:global(.contact-overlay .privacy-checkbox) {
		width: 24px;
		height: 24px;
		min-width: 24px;
		margin-top: 1px;
		accent-color: #059669;
		cursor: pointer;
		-webkit-appearance: checkbox;
		appearance: checkbox;
		opacity: 1;
		position: static;
		pointer-events: auto;
	}

	:global(.contact-overlay .privacy-text) {
		line-height: 1.5;
		color: #374151;
	}

	:global(.contact-overlay .privacy-text-ar) {
		font-size: 13px;
		color: #374151;
		direction: rtl;
		margin: 6px 0 0 30px;
		line-height: 1.5;
	}

	:global(.contact-overlay .privacy-link) {
		color: #2563eb;
		text-decoration: underline;
		font-weight: 600;
	}

	:global(.contact-overlay .privacy-link:hover) {
		color: #1d4ed8;
	}

	:global(.contact-overlay .success-container) {
		text-align: center;
		padding: 20px 0;
	}

	:global(.contact-overlay .success-icon) {
		font-size: 64px;
		margin-bottom: 16px;
		animation: scaleIn 0.4s ease;
	}

	:global(.contact-overlay .success-container h2) {
		font-size: 22px;
		font-weight: 800;
		color: #059669;
		margin: 0 0 4px 0;
	}

	:global(.contact-overlay .success-container p) {
		font-size: 18px;
		color: #059669;
		margin: 0;
		direction: rtl;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.9); }
		to { opacity: 1; transform: scale(1); }
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	@media (max-width: 480px) {
		:global(.contact-overlay .overlay-card) {
			padding: 20px 16px;
			border-radius: 18px;
			width: 95%;
			max-height: 95vh;
		}

		:global(.contact-overlay .overlay-header) {
			margin-bottom: 16px;
		}

		:global(.contact-overlay .header-icon) {
			font-size: 36px;
			margin-bottom: 8px;
		}

		:global(.contact-overlay .overlay-header h2) {
			font-size: 18px;
		}

		:global(.contact-overlay .header-subtitle-en) {
			font-size: 14px;
			margin-bottom: 8px;
		}

		:global(.contact-overlay .employee-name-block) {
			padding: 8px 12px;
			margin-bottom: 10px;
		}

		:global(.contact-overlay .employee-name) {
			font-size: 15px;
		}

		:global(.contact-overlay .employee-name-ar) {
			font-size: 14px;
		}

		:global(.contact-overlay .instructions-box) {
			padding: 10px 12px;
		}

		:global(.contact-overlay .instruction-text) {
			font-size: 12px;
			line-height: 1.5;
			margin-bottom: 4px;
		}

		:global(.contact-overlay .overlay-form) {
			gap: 14px;
		}

		:global(.contact-overlay .form-group label),
		:global(.contact-overlay .field-label) {
			font-size: 13px;
		}

		:global(.contact-overlay .wa-input-row) {
			gap: 5px;
		}

		:global(.contact-overlay .wa-prefix) {
			font-size: 16px;
			padding: 4px 14px;
		}

		:global(.contact-overlay .wa-digits) {
			gap: 3px;
		}

		:global(.contact-overlay .wa-digit-box) {
			height: 38px;
			font-size: 16px;
			border-radius: 6px;
			border-width: 1.5px;
		}

		:global(.contact-overlay .form-group input:not(.wa-digit-box)) {
			padding: 10px 12px;
			font-size: 14px;
			border-radius: 10px;
		}

		:global(.contact-overlay .privacy-checkbox-group) {
			padding: 10px 12px;
			border-radius: 10px;
		}

		:global(.contact-overlay .privacy-text) {
			font-size: 13px;
		}

		:global(.contact-overlay .privacy-text-ar) {
			font-size: 13px;
		}

		:global(.contact-overlay .save-btn) {
			padding: 12px 16px;
			font-size: 14px;
			border-radius: 12px;
		}

		:global(.contact-overlay .logout-btn) {
			padding: 8px 16px;
			font-size: 13px;
			border-radius: 10px;
		}
	}
</style>
