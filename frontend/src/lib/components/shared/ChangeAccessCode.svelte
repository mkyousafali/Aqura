<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	const dispatch = createEventDispatcher();

	// Props
	export let locale: string = 'en';

	// Translation helper
	function t(en: string, ar: string): string {
		return locale === 'ar' ? ar : en;
	}

	// Steps: 'identity' -> 'otp' -> 'newCode' -> 'success'
	let step: 'identity' | 'otp' | 'newCode' | 'success' = 'identity';

	// Identity form
	let email = '';
	let whatsappNumber = '';

	// OTP
	let otpDigits = ['', '', '', '', '', ''];
	let otpTimer = 300; // 5 minutes in seconds
	let otpInterval: any = null;

	// New code
	let newCodeDigits = ['', '', '', '', '', ''];
	let confirmCodeDigits = ['', '', '', '', '', ''];
	let checkingAvailability = false;
	let codeAvailable: boolean | null = null;

	// State
	let loading = false;
	let error = '';
	let successMsg = '';
	let tempOtpDisplay = ''; // Temporary: shows OTP when WhatsApp delivery fails

	// Saved for OTP verification
	let savedEmail = '';
	let savedWhatsapp = '';

	onMount(() => {
		return () => {
			if (otpInterval) clearInterval(otpInterval);
		};
	});

	// ─── Step 1: Request OTP ───────────────────────────────

	async function requestOTP() {
		error = '';
		
		if (!email.trim()) {
			error = t('Email is required', 'البريد الإلكتروني مطلوب');
			return;
		}
		if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
			error = t('Invalid email format', 'صيغة البريد الإلكتروني غير صحيحة');
			return;
		}
		if (!whatsappNumber.trim()) {
			error = t('WhatsApp number is required', 'رقم الواتساب مطلوب');
			return;
		}

		loading = true;
		try {
			// Call RPC to validate identity and generate OTP
			const { data, error: rpcError } = await supabase.rpc('request_access_code_change', {
				p_email: email.trim(),
				p_whatsapp: whatsappNumber.trim()
			});

			if (rpcError) {
				error = t('Server error. Please try again.', 'خطأ في الخادم. يرجى المحاولة مرة أخرى.');
				console.error('RPC error:', rpcError);
				return;
			}

			if (!data || !data.success) {
				error = data?.message || t('Verification failed', 'فشل التحقق');
				return;
			}

			// Send OTP via WhatsApp using whatsapp-manage edge function
			const otp = data.otp;
			const targetPhone = data.whatsapp_number;

			let whatsappSent = false;
			try {
				// First get default WA account
				const { data: waAccount } = await supabase
					.from('wa_accounts')
					.select('id')
					.eq('is_default', true)
					.eq('is_active', true)
					.single();

				if (waAccount) {
					// Try sending as template first (requires approved template)
					const { data: waResult, error: waError } = await supabase.functions.invoke('whatsapp-manage', {
						body: {
							action: 'send_template',
							account_id: waAccount.id,
							to: targetPhone,
							template_name: 'aqura_otp_verification',
							language: locale === 'ar' ? 'ar' : 'en',
							components: [
								{
									type: 'body',
									parameters: [
										{ type: 'text', text: otp }
									]
								},
								{
									type: 'button',
									sub_type: 'url',
									index: 0,
									parameters: [
										{ type: 'text', text: otp }
									]
								}
							]
						}
					});

					if (waError) {
						console.warn('Template send failed, trying plain text:', waError);
						// Fallback: try plain text (works within 24h window)
						const { data: fallbackResult, error: fallbackError } = await supabase.functions.invoke('whatsapp-manage', {
							body: {
								action: 'send_message',
								account_id: waAccount.id,
								to: targetPhone,
								type: 'text',
								text: locale === 'ar'
									? `رمز التحقق الخاص بك في أكورا هو: *${otp}*\nينتهي هذا الرمز خلال 5 دقائق.\nلا تشاركه مع أي شخص.`
									: `Your Aqura verification code is: *${otp}*\nThis code expires in 5 minutes.\nDo not share it with anyone.`
							}
						});
						if (!fallbackError) whatsappSent = true;
						console.log('Plain text fallback result:', fallbackResult, fallbackError);
					} else {
						whatsappSent = true;
						console.log('Template message sent:', waResult);
					}
				} else {
					console.warn('No default WA account found, OTP not sent via WhatsApp');
				}
			} catch (waErr) {
				console.error('WhatsApp send error (OTP still valid):', waErr);
			}

			// If WhatsApp failed, show OTP in the UI as temporary fallback
			if (!whatsappSent) {
				tempOtpDisplay = otp;
			}

			// Save for later verification
			savedEmail = email.trim();
			savedWhatsapp = whatsappNumber.trim();

			// Start OTP timer
			otpTimer = 300;
			if (otpInterval) clearInterval(otpInterval);
			otpInterval = setInterval(() => {
				otpTimer--;
				if (otpTimer <= 0) {
					clearInterval(otpInterval);
					error = t('OTP expired. Please request a new one.', 'انتهت صلاحية الرمز. يرجى طلب رمز جديد.');
				}
			}, 1000);

			step = 'otp';
		} catch (err: any) {
			error = err.message || t('An error occurred', 'حدث خطأ');
		} finally {
			loading = false;
		}
	}

	// ─── Step 2: Verify OTP → go to new code ────────────────

	function getOtpCode(): string {
		return otpDigits.join('');
	}

	function verifyOTPFormat(): boolean {
		const code = getOtpCode();
		return /^[0-9]{6}$/.test(code);
	}

	async function verifyOTP() {
		error = '';
		if (!verifyOTPFormat()) {
			error = t('Please enter the 6-digit OTP', 'يرجى إدخال الرمز المكون من 6 أرقام');
			return;
		}
		// OTP is verified in the final step along with code change
		step = 'newCode';
	}

	// ─── Step 3: Check availability & submit new code ───────

	function getNewCode(): string {
		return newCodeDigits.join('');
	}

	function getConfirmCode(): string {
		return confirmCodeDigits.join('');
	}

	async function checkCodeAvailability() {
		const code = getNewCode();
		if (code.length !== 6 || !/^[0-9]{6}$/.test(code)) {
			codeAvailable = null;
			return;
		}

		checkingAvailability = true;
		try {
			const { data, error: err } = await supabase.rpc('is_quick_access_code_available', {
				p_quick_access_code: code
			});
			if (err) {
				codeAvailable = null;
			} else {
				codeAvailable = data;
			}
		} catch {
			codeAvailable = null;
		} finally {
			checkingAvailability = false;
		}
	}

	async function submitNewCode() {
		error = '';
		const newCode = getNewCode();
		const confirmCode = getConfirmCode();

		if (newCode.length !== 6 || !/^[0-9]{6}$/.test(newCode)) {
			error = t('New access code must be 6 digits', 'رمز الوصول الجديد يجب أن يكون 6 أرقام');
			return;
		}

		if (newCode !== confirmCode) {
			error = t('Access codes do not match', 'رموز الوصول غير متطابقة');
			return;
		}

		if (codeAvailable === false) {
			error = t('This code is already in use', 'هذا الرمز مستخدم بالفعل');
			return;
		}

		loading = true;
		try {
			const { data, error: rpcError } = await supabase.rpc('verify_otp_and_change_access_code', {
				p_email: savedEmail,
				p_whatsapp: savedWhatsapp,
				p_otp: getOtpCode(),
				p_new_code: newCode
			});

			if (rpcError) {
				error = t('Server error. Please try again.', 'خطأ في الخادم. يرجى المحاولة مرة أخرى.');
				console.error('RPC error:', rpcError);
				return;
			}

			if (!data || !data.success) {
				error = data?.message || t('Failed to change access code', 'فشل في تغيير رمز الوصول');
				return;
			}

			if (otpInterval) clearInterval(otpInterval);
			step = 'success';
		} catch (err: any) {
			error = err.message || t('An error occurred', 'حدث خطأ');
		} finally {
			loading = false;
		}
	}

	// ─── Digit input handlers ───────────────────────────────

	function handleDigitInput(e: Event, index: number, digits: string[], fieldPrefix: string) {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		digits[index] = value.slice(-1);
		
		if (value && index < 5) {
			const next = document.getElementById(`${fieldPrefix}-${index + 1}`) as HTMLInputElement;
			if (next) next.focus();
		}

		// Trigger reactivity
		if (fieldPrefix === 'otp') otpDigits = [...digits];
		else if (fieldPrefix === 'new-code') {
			newCodeDigits = [...digits];
			// Auto-check availability when all 6 digits entered
			if (getNewCode().length === 6) checkCodeAvailability();
		}
		else if (fieldPrefix === 'confirm-code') confirmCodeDigits = [...digits];
	}

	function handleDigitKeydown(e: KeyboardEvent, index: number, digits: string[], fieldPrefix: string) {
		if (e.key === 'Backspace' && !digits[index] && index > 0) {
			const prev = document.getElementById(`${fieldPrefix}-${index - 1}`) as HTMLInputElement;
			if (prev) {
				prev.focus();
				digits[index - 1] = '';
				if (fieldPrefix === 'otp') otpDigits = [...digits];
				else if (fieldPrefix === 'new-code') newCodeDigits = [...digits];
				else if (fieldPrefix === 'confirm-code') confirmCodeDigits = [...digits];
			}
		}
	}

	function handleDigitPaste(e: ClipboardEvent, digits: string[], fieldPrefix: string) {
		e.preventDefault();
		const text = (e.clipboardData?.getData('text') || '').replace(/[^0-9]/g, '').slice(0, 6);
		for (let i = 0; i < 6; i++) {
			digits[i] = text[i] || '';
		}
		if (fieldPrefix === 'otp') otpDigits = [...digits];
		else if (fieldPrefix === 'new-code') {
			newCodeDigits = [...digits];
			if (getNewCode().length === 6) checkCodeAvailability();
		}
		else if (fieldPrefix === 'confirm-code') confirmCodeDigits = [...digits];

		// Focus last filled or next empty
		const focusIdx = Math.min(text.length, 5);
		const el = document.getElementById(`${fieldPrefix}-${focusIdx}`) as HTMLInputElement;
		if (el) el.focus();
	}

	function formatTimer(seconds: number): string {
		const m = Math.floor(seconds / 60);
		const s = seconds % 60;
		return `${m}:${s.toString().padStart(2, '0')}`;
	}

	function handleClose() {
		dispatch('close');
	}

	function goBack() {
		error = '';
		if (step === 'otp') step = 'identity';
		else if (step === 'newCode') step = 'otp';
		else if (step === 'success') {
			dispatch('close');
		}
	}
</script>

<div class="change-access-modal" class:rtl={locale === 'ar'}>
	<div class="modal-backdrop" on:click={handleClose}></div>
	<div class="modal-content">
		<!-- Header -->
		<div class="modal-header">
			{#if step !== 'identity' && step !== 'success'}
				<button class="back-btn" on:click={goBack}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M19 12H5M12 19l-7-7 7-7"/>
					</svg>
				</button>
			{/if}
			<h2 class="modal-title">
				{#if step === 'identity'}
					🔑 {t('Change Access Code', 'تغيير رمز الوصول')}
				{:else if step === 'otp'}
					📱 {t('Enter OTP', 'أدخل رمز التحقق')}
				{:else if step === 'newCode'}
					🔐 {t('New Access Code', 'رمز الوصول الجديد')}
				{:else}
					✅ {t('Success', 'تم بنجاح')}
				{/if}
			</h2>
			<button class="close-btn" on:click={handleClose}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
				</svg>
			</button>
		</div>

		<!-- Progress Steps -->
		{#if step !== 'success'}
			<div class="progress-steps">
				<div class="step" class:active={step === 'identity'} class:completed={step !== 'identity'}>
					<div class="step-dot">1</div>
					<span>{t('Verify', 'التحقق')}</span>
				</div>
				<div class="step-line" class:completed={step !== 'identity'}></div>
				<div class="step" class:active={step === 'otp'} class:completed={step === 'newCode'}>
					<div class="step-dot">2</div>
					<span>{t('OTP', 'الرمز')}</span>
				</div>
				<div class="step-line" class:completed={step === 'newCode'}></div>
				<div class="step" class:active={step === 'newCode'}>
					<div class="step-dot">3</div>
					<span>{t('New Code', 'رمز جديد')}</span>
				</div>
			</div>
		{/if}

		<div class="modal-body">
			<!-- Error -->
			{#if error}
				<div class="error-banner">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
					</svg>
					{error}
				</div>
			{/if}

			<!-- Step 1: Identity Verification -->
			{#if step === 'identity'}
				<p class="step-description">
					{t('Enter your registered email and WhatsApp number to receive a verification code.', 'أدخل بريدك الإلكتروني ورقم الواتساب المسجل لتلقي رمز التحقق.')}
				</p>

				<div class="form-group">
					<label for="change-email">{t('Email Address', 'البريد الإلكتروني')}</label>
					<input
						id="change-email"
						type="email"
						bind:value={email}
						placeholder={t('your.email@example.com', 'your.email@example.com')}
						disabled={loading}
						autocomplete="email"
					/>
				</div>

				<div class="form-group">
					<label for="change-whatsapp">{t('WhatsApp Number', 'رقم الواتساب')}</label>
					<input
						id="change-whatsapp"
						type="tel"
						bind:value={whatsappNumber}
						placeholder={t('+966501234567', '+966501234567')}
						disabled={loading}
						autocomplete="tel"
					/>
				</div>

				<button class="primary-btn" on:click={requestOTP} disabled={loading}>
					{#if loading}
						<span class="spinner"></span>
						{t('Sending...', 'جارٍ الإرسال...')}
					{:else}
						{t('Send OTP via WhatsApp', 'إرسال رمز التحقق عبر واتساب')}
					{/if}
				</button>

			<!-- Step 2: OTP Verification -->
			{:else if step === 'otp'}
				<p class="step-description">
					{t('Enter the 6-digit code sent to your WhatsApp.', 'أدخل الرمز المكون من 6 أرقام المرسل إلى واتسابك.')}
				</p>

				{#if tempOtpDisplay}
					<div class="temp-otp-notice">
						<span>⚠️ {t('WhatsApp delivery failed. Your code is:', 'فشل إرسال الواتساب. رمزك هو:')}</span>
						<strong class="temp-otp-code">{tempOtpDisplay}</strong>
					</div>
				{/if}

				<div class="otp-timer" class:expired={otpTimer <= 0}>
					{#if otpTimer > 0}
						⏱️ {t('Expires in', 'ينتهي خلال')} {formatTimer(otpTimer)}
					{:else}
						⚠️ {t('OTP Expired', 'انتهت صلاحية الرمز')}
					{/if}
				</div>

				<div class="digit-row">
					{#each otpDigits as digit, i}
						<input
							id="otp-{i}"
							type="text"
							inputmode="numeric"
							pattern="[0-9]*"
							maxlength="1"
							class="digit-box"
							bind:value={otpDigits[i]}
							on:input={(e) => handleDigitInput(e, i, otpDigits, 'otp')}
							on:keydown={(e) => handleDigitKeydown(e, i, otpDigits, 'otp')}
							on:paste={(e) => handleDigitPaste(e, otpDigits, 'otp')}
							disabled={loading || otpTimer <= 0}
							autocomplete="one-time-code"
						/>
					{/each}
				</div>

				<button class="primary-btn" on:click={verifyOTP} disabled={loading || otpTimer <= 0 || otpDigits.join('').length !== 6}>
					{t('Verify OTP', 'تحقق من الرمز')}
				</button>

				{#if otpTimer <= 0}
					<button class="secondary-btn" on:click={() => { step = 'identity'; error = ''; }}>
						{t('Request New OTP', 'طلب رمز جديد')}
					</button>
				{/if}

			<!-- Step 3: New Access Code -->
			{:else if step === 'newCode'}
				<p class="step-description">
					{t('Enter your new 6-digit access code.', 'أدخل رمز الوصول الجديد المكون من 6 أرقام.')}
				</p>

				<div class="form-group">
					<label>{t('New Access Code', 'رمز الوصول الجديد')}</label>
					<div class="digit-row">
						{#each newCodeDigits as digit, i}
							<input
								id="new-code-{i}"
								type="text"
								inputmode="numeric"
								pattern="[0-9]*"
								maxlength="1"
								class="digit-box"
								bind:value={newCodeDigits[i]}
								on:input={(e) => handleDigitInput(e, i, newCodeDigits, 'new-code')}
								on:keydown={(e) => handleDigitKeydown(e, i, newCodeDigits, 'new-code')}
								on:paste={(e) => handleDigitPaste(e, newCodeDigits, 'new-code')}
								disabled={loading}
							/>
						{/each}
					</div>
					{#if checkingAvailability}
						<span class="availability checking">⏳ {t('Checking...', 'جارٍ التحقق...')}</span>
					{:else if codeAvailable === true}
						<span class="availability available">✅ {t('Code is available', 'الرمز متاح')}</span>
					{:else if codeAvailable === false}
						<span class="availability taken">❌ {t('Code is already in use', 'الرمز مستخدم بالفعل')}</span>
					{/if}
				</div>

				<div class="form-group">
					<label>{t('Confirm Access Code', 'تأكيد رمز الوصول')}</label>
					<div class="digit-row">
						{#each confirmCodeDigits as digit, i}
							<input
								id="confirm-code-{i}"
								type="text"
								inputmode="numeric"
								pattern="[0-9]*"
								maxlength="1"
								class="digit-box"
								bind:value={confirmCodeDigits[i]}
								on:input={(e) => handleDigitInput(e, i, confirmCodeDigits, 'confirm-code')}
								on:keydown={(e) => handleDigitKeydown(e, i, confirmCodeDigits, 'confirm-code')}
								on:paste={(e) => handleDigitPaste(e, confirmCodeDigits, 'confirm-code')}
								disabled={loading}
							/>
						{/each}
					</div>
				</div>

				<button 
					class="primary-btn" 
					on:click={submitNewCode} 
					disabled={loading || codeAvailable === false || newCodeDigits.join('').length !== 6 || confirmCodeDigits.join('').length !== 6}
				>
					{#if loading}
						<span class="spinner"></span>
						{t('Changing...', 'جارٍ التغيير...')}
					{:else}
						{t('Change Access Code', 'تغيير رمز الوصول')}
					{/if}
				</button>

			<!-- Step 4: Success -->
			{:else if step === 'success'}
				<div class="success-section">
					<div class="success-icon">✅</div>
					<h3>{t('Access Code Changed!', 'تم تغيير رمز الوصول!')}</h3>
					<p>{t('Your access code has been changed successfully. You can now use your new code to log in.', 'تم تغيير رمز الوصول بنجاح. يمكنك الآن استخدام رمزك الجديد لتسجيل الدخول.')}</p>
					<button class="primary-btn" on:click={handleClose}>
						{t('Done', 'تم')}
					</button>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.change-access-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 10000;
		display: flex;
		align-items: center;
		justify-content: center;
		font-family: 'Inter', 'Segoe UI', sans-serif;
	}

	.change-access-modal.rtl {
		direction: rtl;
	}

	.modal-backdrop {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
	}

	.modal-content {
		position: relative;
		background: #fff;
		border-radius: 16px;
		width: 92%;
		max-width: 420px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		animation: slideUp 0.3s ease;
	}

	@keyframes slideUp {
		from { transform: translateY(30px); opacity: 0; }
		to { transform: translateY(0); opacity: 1; }
	}

	.modal-header {
		display: flex;
		align-items: center;
		padding: 16px 20px;
		border-bottom: 1px solid #e2e8f0;
		gap: 8px;
	}

	.modal-title {
		flex: 1;
		font-size: 16px;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.back-btn, .close-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 4px;
		color: #64748b;
		border-radius: 6px;
		display: flex;
		align-items: center;
	}

	.back-btn:hover, .close-btn:hover {
		background: #f1f5f9;
		color: #1e293b;
	}

	/* Progress Steps */
	.progress-steps {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 16px 20px 8px;
		gap: 4px;
	}

	.step {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		opacity: 0.4;
		transition: all 0.3s;
	}

	.step.active, .step.completed {
		opacity: 1;
	}

	.step-dot {
		width: 28px;
		height: 28px;
		border-radius: 50%;
		background: #e2e8f0;
		color: #64748b;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 12px;
		font-weight: 700;
		transition: all 0.3s;
	}

	.step.active .step-dot {
		background: #3b82f6;
		color: white;
	}

	.step.completed .step-dot {
		background: #10b981;
		color: white;
	}

	.step span {
		font-size: 10px;
		color: #64748b;
		font-weight: 500;
	}

	.step-line {
		width: 40px;
		height: 2px;
		background: #e2e8f0;
		margin-bottom: 18px;
		transition: background 0.3s;
	}

	.step-line.completed {
		background: #10b981;
	}

	/* Body */
	.modal-body {
		padding: 20px;
	}

	.step-description {
		color: #64748b;
		font-size: 13px;
		line-height: 1.5;
		margin: 0 0 16px;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		font-size: 12px;
		font-weight: 600;
		color: #475569;
		margin-bottom: 6px;
	}

	.form-group input[type="email"],
	.form-group input[type="tel"] {
		width: 100%;
		padding: 10px 12px;
		border: 1.5px solid #e2e8f0;
		border-radius: 8px;
		font-size: 14px;
		color: #1e293b;
		transition: border-color 0.2s;
		box-sizing: border-box;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	/* Digit inputs */
	.digit-row {
		display: flex;
		gap: 8px;
		justify-content: center;
		margin: 12px 0;
	}

	.digit-box {
		width: 44px;
		height: 52px;
		text-align: center;
		font-size: 22px;
		font-weight: 700;
		border: 2px solid #e2e8f0;
		border-radius: 10px;
		color: #1e293b;
		background: #f8fafc;
		transition: all 0.2s;
	}

	.digit-box:focus {
		outline: none;
		border-color: #3b82f6;
		background: white;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
	}

	.digit-box:disabled {
		opacity: 0.5;
	}

	/* OTP Timer */
	.otp-timer {
		text-align: center;
		font-size: 14px;
		font-weight: 600;
		color: #3b82f6;
		margin-bottom: 12px;
	}

	.otp-timer.expired {
		color: #ef4444;
	}

	/* Temp OTP Display (fallback when WhatsApp fails) */
	.temp-otp-notice {
		background: #fef3c7;
		border: 1px solid #f59e0b;
		border-radius: 8px;
		padding: 12px 16px;
		margin-bottom: 12px;
		text-align: center;
		font-size: 13px;
		color: #92400e;
	}

	.temp-otp-code {
		display: block;
		font-size: 24px;
		letter-spacing: 6px;
		color: #d97706;
		margin-top: 6px;
	}

	/* Availability */
	.availability {
		display: block;
		font-size: 12px;
		margin-top: 6px;
		font-weight: 500;
	}

	.availability.checking { color: #f59e0b; }
	.availability.available { color: #10b981; }
	.availability.taken { color: #ef4444; }

	/* Buttons */
	.primary-btn {
		width: 100%;
		padding: 12px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: background 0.2s;
		margin-top: 8px;
	}

	.primary-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.primary-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.secondary-btn {
		width: 100%;
		padding: 10px;
		background: transparent;
		color: #3b82f6;
		border: 1.5px solid #3b82f6;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		margin-top: 8px;
		transition: background 0.2s;
	}

	.secondary-btn:hover {
		background: #eff6ff;
	}

	/* Error banner */
	.error-banner {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 12px;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		color: #dc2626;
		font-size: 13px;
		margin-bottom: 12px;
	}

	/* Success */
	.success-section {
		text-align: center;
		padding: 20px 0;
	}

	.success-icon {
		font-size: 48px;
		margin-bottom: 12px;
	}

	.success-section h3 {
		color: #10b981;
		font-size: 18px;
		margin: 0 0 8px;
	}

	.success-section p {
		color: #64748b;
		font-size: 13px;
		line-height: 1.5;
		margin: 0 0 20px;
	}

	/* Spinner */
	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Mobile responsive */
	@media (max-width: 480px) {
		.modal-content {
			width: 96%;
			border-radius: 12px;
		}

		.digit-box {
			width: 38px;
			height: 46px;
			font-size: 18px;
		}

		.digit-row {
			gap: 6px;
		}
	}
</style>
