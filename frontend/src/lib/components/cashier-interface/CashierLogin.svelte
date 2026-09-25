<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import { setCashierAuth, claimWindowsCashierSession } from '$lib/stores/cashierAuth';
	import { isWindowsApp } from '$lib/utils/cashierDevice';
	import { t, currentLocale, switchLocaleManually } from '$lib/i18n';
	import ChangeAccessCode from '$lib/components/shared/ChangeAccessCode.svelte';

	const dispatch = createEventDispatcher();

	let showChangeAccessCode = false;

	let accessCode = '';
	let accessDigits = ['', '', '', '', '', ''];
	let selectedBranchId = '';
	let branches: any[] = [];
	let loading = false;
	let loadingBranches = true;
	let error = '';
	let step: 'accessCode' | 'branch' = 'accessCode';
	let authenticatedUser: any = null;
	let showAccessCode = false;
	let assignedBranchId = '';
	let allowBranchChange = false;
	let showSessionConfirmation = false;

	$: selectedBranch = branches.find(branch => String(branch.id) === String(selectedBranchId));
	$: assignedBranch = branches.find(branch => String(branch.id) === String(assignedBranchId));
	$: cashierDisplayName = $currentLocale === 'ar'
		? authenticatedUser?.name_ar || authenticatedUser?.name_en || authenticatedUser?.username
		: authenticatedUser?.name_en || authenticatedUser?.name_ar || authenticatedUser?.username;

	onMount(() => {
		setTimeout(() => {
			const firstDigit = document.getElementById('digit-0') as HTMLInputElement;
			if (firstDigit) firstDigit.focus();
		}, 300);
	});

	// Load branches on mount
	async function loadBranches() {
		try {
			loadingBranches = true;
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_ar, name_en, location_ar, location_en')
				.eq('is_active', true)
				.order('name_en');
			
			if (branchError) throw branchError;
			branches = data || [];
			selectAssignedBranch();
		} catch (err: any) {
			console.error('Error loading branches:', err);
			error = 'Failed to load branches';
		} finally {
			loadingBranches = false;
		}
	}

	function selectAssignedBranch() {
		if (!assignedBranchId || selectedBranchId) return;
		const branch = branches.find(item => String(item.id) === String(assignedBranchId));
		if (branch) selectedBranchId = String(branch.id);
	}

	loadBranches();

	async function handleAccessCodeSubmit() {
		accessCode = accessDigits.join('');
		
		if (accessCode.length !== 6 || !/^[0-9]+$/.test(accessCode)) {
			error = t('coupon.invalidAccessCode');
			return;
		}

		try {
			loading = true;
			error = '';

			// Authenticate with quick access code via RPC (bcrypt verification)
			const { data: verifyResult, error: verifyError } = await supabase.rpc('verify_quick_access_code', {
				p_code: accessCode
			});

			if (verifyError || !verifyResult || !verifyResult.success) {
				error = 'Invalid access code';
				accessDigits = ['', '', '', '', '', ''];
				accessCode = '';
				return;
			}

			const userData = verifyResult.user;

			// Check cashier permission
			const { data: permissionData, error: permissionError } = await supabase
				.from('interface_permissions')
				.select('cashier_enabled')
				.eq('user_id', userData.id)
				.single();

			if (permissionError || !permissionData || permissionData.cashier_enabled !== true) {
				error = t('auth.cashierAccessDenied') || 'Access denied. Cashier permission is disabled for this user.';
				accessDigits = ['', '', '', '', '', ''];
				accessCode = '';
				return;
			}

			// Employee master is linked directly to users through user_id.
			let employeeNameEn = userData.username;
			let employeeNameAr = userData.username;
			let employeeBranchId = userData.branch_id;
			const { data: employeeData } = await supabase
				.from('hr_employee_master')
				.select('name_en, name_ar, current_branch_id')
				.eq('user_id', userData.id)
				.maybeSingle();

			if (employeeData) {
				employeeNameEn = employeeData.name_en || employeeData.name_ar || userData.username;
				employeeNameAr = employeeData.name_ar || employeeData.name_en || userData.username;
				employeeBranchId = employeeData.current_branch_id ?? employeeBranchId;
			}

			authenticatedUser = {
				...userData,
				name_en: employeeNameEn,
				name_ar: employeeNameAr,
				full_name: $currentLocale === 'ar' ? employeeNameAr : employeeNameEn,
				employeeName: $currentLocale === 'ar' ? employeeNameAr : employeeNameEn,
				name: $currentLocale === 'ar' ? employeeNameAr : employeeNameEn,
				role: 'Cashier'
			};
			assignedBranchId = employeeBranchId == null ? '' : String(employeeBranchId);
			selectedBranchId = '';
			allowBranchChange = !assignedBranchId;
			selectAssignedBranch();
			step = 'branch';
		} catch (err: any) {
			console.error('Login error:', err);
			error = 'Login failed. Please try again.';
			accessDigits = ['', '', '', '', '', ''];
			accessCode = '';
		} finally {
			loading = false;
		}
	}

	async function handleBranchSelect() {
		if (!selectedBranchId) {
			error = t('coupon.selectBranch');
			return;
		}

		const selectedBranch = branches.find(b => String(b.id) === String(selectedBranchId));
		if (!selectedBranch) {
			error = t('coupon.invalidBranchSelection');
			return;
		}

		error = '';
		showSessionConfirmation = true;
	}

	async function proceedWithCashierSession() {
		const selectedBranch = branches.find(b => String(b.id) === String(selectedBranchId));
		if (!selectedBranch) {
			showSessionConfirmation = false;
			error = t('coupon.invalidBranchSelection');
			return;
		}

		// Windows app only: claim single-device session (kicks any prior PC).
		// PWA / web users skip this step and remain unrestricted.
		let sessionToken: string | null = null;
		if (isWindowsApp() && authenticatedUser?.id) {
			try {
				loading = true;
				sessionToken = await claimWindowsCashierSession(authenticatedUser.id);
				if (!sessionToken) {
					error = 'Failed to register this device. Please try again.';
					return;
				}
			} catch (e) {
				console.error('claimWindowsCashierSession error:', e);
				error = 'Failed to register this device. Please try again.';
				return;
			} finally {
				loading = false;
			}
		}

		// Dispatch login success event (page calls setCashierAuth with token)
		dispatch('loginSuccess', {
			user: authenticatedUser,
			branch: selectedBranch,
			sessionToken
		});
	}

	function logoutFromConfirmation() {
		showSessionConfirmation = false;
		goBack();
	}

	function goBack() {
		step = 'accessCode';
		error = '';
		accessDigits = ['', '', '', '', '', ''];
		accessCode = '';
		selectedBranchId = '';
		assignedBranchId = '';
		allowBranchChange = false;
		showSessionConfirmation = false;
		authenticatedUser = null;
	}

	function handleDigitInput(event: Event, index: number) {
		const input = event.target as HTMLInputElement;
		const value = input.value.replace(/\D/g, '');
		
		if (value.length > 0) {
			accessDigits[index] = value.slice(-1);
			input.value = accessDigits[index];

			// Match the Desktop login: submit automatically when the sixth digit is entered.
			if (accessDigits.every(digit => digit !== '') && !loading) {
				void handleAccessCodeSubmit();
				return;
			}
			
			// Auto-focus next input
			if (index < 5 && accessDigits[index] !== '') {
				setTimeout(() => {
					const nextInput = document.getElementById(`digit-${index + 1}`) as HTMLInputElement;
					if (nextInput) {
						nextInput.focus();
						nextInput.select();
					}
				}, 10);
			}
		} else {
			accessDigits[index] = '';
		}
	}

	function handleDigitKeydown(event: KeyboardEvent, index: number) {
		const input = event.target as HTMLInputElement;
		
		// Handle Enter key - submit form if all digits are filled
		if (event.key === 'Enter') {
			event.preventDefault();
			const allFilled = accessDigits.every(d => d !== '');
			if (allFilled && !loading) {
				handleAccessCodeSubmit();
			}
			return;
		}
		
		if (event.key === 'Backspace') {
			event.preventDefault();
			if (accessDigits[index] !== '') {
				accessDigits[index] = '';
				input.value = '';
			} else if (index > 0) {
				accessDigits[index - 1] = '';
				const prevInput = document.getElementById(`digit-${index - 1}`) as HTMLInputElement;
				if (prevInput) {
					prevInput.value = '';
					prevInput.focus();
				}
			}
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
		
		if (!/[0-9]/.test(event.key) && !['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter'].includes(event.key)) {
			event.preventDefault();
		}
	}

	function handleDigitPaste(event: ClipboardEvent) {
		event.preventDefault();
		const pastedText = event.clipboardData?.getData('text') || '';
		const digits = pastedText.replace(/\D/g, '').slice(0, 6);
		
		for (let i = 0; i < 6; i++) {
			accessDigits[i] = digits[i] || '';
			const input = document.getElementById(`digit-${i}`) as HTMLInputElement;
			if (input) {
				input.value = accessDigits[i];
			}
		}
		
		const lastFilledIndex = digits.length - 1;
		const targetIndex = Math.min(Math.max(lastFilledIndex + 1, 0), 5);
		const targetInput = document.getElementById(`digit-${targetIndex}`) as HTMLInputElement;
		if (targetInput) {
			targetInput.focus();
		}

		if (digits.length === 6 && !loading) {
			void handleAccessCodeSubmit();
		}
	}
</script>

<div class="cashier-login-page mounted" inert={showSessionConfirmation} aria-hidden={showSessionConfirmation}>
	<div class="login-content">
		<div class="login-main-card">
			<aside class="cashier-brand-panel" aria-label={$currentLocale === 'ar' ? 'بوابة عمليات الكاشير' : 'Aqura Cashier Operations portal'}>
				<div class="cashier-brand-content">
					<div class="cashier-brand-lockup">
						<div class="cashier-marquee-track">
							{#each [0, 1, 2, 3] as copy}
								<div class="cashier-marquee-group" aria-hidden={copy === 0 ? undefined : 'true'}>
									<div class="cashier-logo-card"><img src="/icons/Aqura logo.png" alt={copy === 0 ? 'Aqura' : ''} /></div>
									<div class="cashier-logo-card"><img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt={copy === 0 ? 'Urban Market' : ''} /></div>
								</div>
							{/each}
						</div>
					</div>
					<div class="cashier-brand-copy">
						<span>{$currentLocale === 'ar' ? 'واجهة الكاشير' : 'CASHIER INTERFACE'}</span>
						<h1>{$currentLocale === 'ar' ? 'أدوات الكاشير. مساحة عمل واحدة.' : 'Cashier tools. One secure workspace.'}</h1>
						<p>{$currentLocale === 'ar' ? 'إدارة الصناديق وطلبات الفكة وعمليات الاستبدال بسهولة وأمان.' : 'Manage counters, change requests, and redemptions with clarity and control.'}</p>
					</div>
					<div class="cashier-security-note">
						<span class="cashier-security-icon" aria-hidden="true">
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/></svg>
						</span>
						<div>
							<strong>{$currentLocale === 'ar' ? 'دخول محمي' : 'Protected access'}</strong>
							<span>{$currentLocale === 'ar' ? 'يتم التحقق من هويتك عبر نظام أقورا الآمن.' : 'Your identity is verified through Aqura secure access.'}</span>
						</div>
					</div>
				</div>
			</aside>
			<div class="cashier-login-workspace">
			<!-- Logo Section with Language Toggle -->
			<div class="logo-section">
				<div class="logo-header">
					<button type="button" class="header-back-btn" on:click={() => goto('/login')} aria-label={$currentLocale === 'ar' ? 'رجوع' : 'Back'}>
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
					</button>
					<button 
						class="language-toggle-main" 
						on:click={() => {
							switchLocaleManually($currentLocale === 'ar' ? 'en' : 'ar');
							setTimeout(() => {
								window.location.reload();
							}, 100);
						}}
						title={t('nav.languageToggle') || 'Switch Language'}
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

			<!-- Main Content -->
			<div class="login-container">
				{#if step === 'accessCode'}
					<!-- Access Code Step -->
					<form class="auth-form" on:submit|preventDefault={handleAccessCodeSubmit}>
						<div class="form-header">
							<h2>{t('auth.quickAccess') || 'Quick Access'}</h2>
							<p>{t('coupon.accessCodeInstructions') || 'Enter your 6-digit security code to access the cashier interface'}</p>
						</div>

						<div class="form-fields">
							<div class="field-group">
								<label for="accessCode">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
										<circle cx="12" cy="16" r="1"/>
										<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
									</svg>
									{t('auth.accessCode') || 'Security Code'}
								</label>
								<div class="digits-with-toggle">
									<div class="quick-access-digits">
										{#each accessDigits as digit, index}
											<input 
												id="digit-{index}"
												type={showAccessCode ? 'text' : 'password'} 
												class="digit-input"
											class:error={error && accessDigits.some(d => d !== '')}
											bind:value={accessDigits[index]}
											on:input={(e) => handleDigitInput(e, index)}
											on:keydown={(e) => handleDigitKeydown(e, index)}
											on:paste={handleDigitPaste}
											placeholder=""
											disabled={loading}
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
								{#if error}
									<span class="field-error">{error}</span>
								{/if}
							</div>

							<!-- Spacer -->
							<div class="field-spacer"></div>
						</div>

						<button 
							type="submit" 
							class="auth-submit-btn"
							disabled={loading || accessDigits.some(d => d === '')}
						>
							{#if loading}
								<span class="loading-spinner"></span>
								{t('auth.loggingIn') || 'Signing In...'}
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
									<polyline points="10,17 15,12 10,7"/>
									<line x1="15" y1="12" x2="3" y2="12"/>
								</svg>
								{t('auth.continueLogin') || 'Continue to System'}
							{/if}
						</button>
					</form>

					<!-- Change Access Code Link -->
					<button class="change-code-link" on:click={() => showChangeAccessCode = true}>
						🔑 {t('auth.changeAccessCode') || 'Change Access Code'}
					</button>

				{:else}
					<!-- Branch Selection Step -->
					<form class="auth-form" on:submit|preventDefault={handleBranchSelect}>
						<div class="form-header">
							<button type="button" class="back-btn" on:click={goBack}>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M19 12H5M12 19l-7-7 7-7"/>
								</svg>
								{t('common.back') || 'Back'}
							</button>
							<h2>{t('coupon.selectBranch') || 'Select Branch'}</h2>
							<p>{t('coupon.chooseBranchLocation') || 'Choose your branch location to continue'}</p>
						</div>

						<!-- User Info Card -->
						<div class="user-info-card">
							<div class="user-avatar">
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
									<circle cx="12" cy="7" r="4"/>
								</svg>
							</div>
							<div class="user-details">
								<div class="user-name">{cashierDisplayName}</div>
								<div class="user-role">{t('coupon.cashier') || 'Cashier'}</div>
							</div>
						</div>

						<div class="form-fields">
							{#if assignedBranch && !allowBranchChange}
								<div class="assigned-branch-card">
									<div>
										<span class="assigned-branch-label">{$currentLocale === 'ar' ? 'الفرع المعيّن' : 'Assigned Branch'}</span>
										<strong>{$currentLocale === 'ar' ? assignedBranch.name_ar : assignedBranch.name_en}</strong>
										{#if $currentLocale === 'ar' ? assignedBranch.location_ar : assignedBranch.location_en}
											<small>{$currentLocale === 'ar' ? assignedBranch.location_ar : assignedBranch.location_en}</small>
										{/if}
									</div>
									<button type="button" class="change-branch-btn" on:click={() => allowBranchChange = true}>
										{$currentLocale === 'ar' ? 'تغيير الفرع' : 'Change Branch'}
									</button>
								</div>
							{:else}
							<div class="field-group">
								<label for="branch">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
										<circle cx="12" cy="10" r="3"/>
									</svg>
									{t('coupon.branch') || 'Branch Location'}
								</label>
								<select 
									id="branch"
									class="field-input"
									bind:value={selectedBranchId}
									disabled={loading || loadingBranches}
									on:keydown={(e) => {
										if (e.key === 'Enter' && selectedBranchId && !loading && !loadingBranches) {
											e.preventDefault();
											handleBranchSelect();
										}
									}}
								>
								<option value="">{loadingBranches ? (t('common.loading') || 'Loading...') : (t('coupon.selectBranch') || 'Select a branch')}</option>
								{#each branches as branch}
									<option value={branch.id}>
										{#if $currentLocale === 'ar'}
											{branch.name_ar} {branch.location_ar ? `- ${branch.location_ar}` : ''}
										{:else}
											{branch.name_en} {branch.location_en ? `- ${branch.location_en}` : ''}
										{/if}
									</option>
								{/each}
								</select>
								{#if error}
									<span class="field-error">{error}</span>
								{/if}
							</div>
							{/if}
						</div>

						<button 
							type="submit" 
							class="auth-submit-btn"
							disabled={loading || !selectedBranchId || loadingBranches}
						>
							{#if loading}
								<span class="loading-spinner"></span>
								{t('common.loading') || 'Loading...'}
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
									<polyline points="10,17 15,12 10,7"/>
									<line x1="15" y1="12" x2="3" y2="12"/>
								</svg>
								{t('coupon.startCashier') || 'Start Cashier Session'}
							{/if}
						</button>
					</form>
				{/if}
			</div>

			<!-- Footer -->
			<div class="login-footer">
				<p>{t('app.shortName')} - {t('app.description')}</p>
			</div>
			</div>
		</div>
	</div>
</div>

{#if showSessionConfirmation && selectedBranch}
	<div class="confirmation-backdrop" role="presentation">
		<div
			class="confirmation-modal"
			role="dialog"
			aria-modal="true"
			dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}
			aria-labelledby="session-confirmation-title"
			aria-describedby="session-confirmation-description"
		>
			<div class="confirmation-icon" aria-hidden="true">✓</div>
			<h2 id="session-confirmation-title">
				{$currentLocale === 'ar' ? 'تأكيد جلسة الكاشير' : 'Confirm Cashier Session'}
			</h2>
			<p id="session-confirmation-description">
				{$currentLocale === 'ar'
					? 'يرجى تأكيد هذه التفاصيل قبل بدء جلسة الكاشير.'
					: 'Please confirm these details before starting your session.'}
			</p>

			<dl class="confirmation-details">
				<div>
					<dt>{$currentLocale === 'ar' ? 'اسم الكاشير' : 'Cashier name'}</dt>
					<dd>{cashierDisplayName}</dd>
				</div>
				<div>
					<dt>{$currentLocale === 'ar' ? 'الفرع المحدد' : 'Selected branch'}</dt>
					<dd>{$currentLocale === 'ar' ? selectedBranch.name_ar : selectedBranch.name_en}</dd>
				</div>
				<div>
					<dt>{$currentLocale === 'ar' ? 'موقع الفرع' : 'Branch Location'}</dt>
					<dd>{($currentLocale === 'ar' ? selectedBranch.location_ar : selectedBranch.location_en) || '—'}</dd>
				</div>
			</dl>

			{#if error}
				<div class="confirmation-error" role="alert">{error}</div>
			{/if}

			<div class="confirmation-actions">
				<button type="button" class="modal-btn proceed-btn" on:click={proceedWithCashierSession} disabled={loading}>
					{loading
						? ($currentLocale === 'ar' ? 'جارٍ البدء…' : 'Starting…')
						: ($currentLocale === 'ar' ? 'متابعة' : 'Proceed')}
				</button>
				<button type="button" class="modal-btn back-modal-btn" on:click={() => { showSessionConfirmation = false; error = ''; }} disabled={loading}>
					{$currentLocale === 'ar' ? 'رجوع' : 'Go Back'}
				</button>
				<button type="button" class="modal-btn logout-btn" on:click={logoutFromConfirmation} disabled={loading}>
					{$currentLocale === 'ar' ? 'تسجيل الخروج' : 'Logout'}
				</button>
			</div>
		</div>
	</div>
{/if}

{#if showChangeAccessCode}
	<ChangeAccessCode locale={$currentLocale} on:close={() => showChangeAccessCode = false} />
{/if}

<style>
	.assigned-branch-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 1rem 1.25rem;
		border: 2px solid #d1fae5;
		border-radius: 10px;
		background: #f0fdf4;
	}

	.assigned-branch-card > div {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.assigned-branch-label,
	.assigned-branch-card small {
		color: #64748b;
		font-size: 0.8rem;
	}

	.assigned-branch-card strong {
		color: #14532d;
		font-size: 1rem;
	}

	.change-branch-btn {
		flex: 0 0 auto;
		padding: 0.65rem 0.9rem;
		border: 1px solid #6b7280;
		border-radius: 8px;
		background: white;
		color: #374151;
		font-weight: 600;
		cursor: pointer;
	}

	.confirmation-backdrop {
		position: fixed;
		inset: 0;
		z-index: 10000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: rgba(15, 23, 42, 0.72);
		backdrop-filter: blur(4px);
	}

	.confirmation-modal {
		width: min(100%, 520px);
		padding: 2rem;
		border-radius: 16px;
		background: white;
		box-shadow: 0 24px 60px rgba(0, 0, 0, 0.3);
		text-align: center;
	}

	.confirmation-icon {
		display: grid;
		place-items: center;
		width: 52px;
		height: 52px;
		margin: 0 auto 1rem;
		border-radius: 50%;
		background: #dcfce7;
		color: #15803d;
		font-size: 1.6rem;
		font-weight: 800;
	}

	.confirmation-modal h2 { margin: 0 0 0.5rem; color: #111827; }
	.confirmation-modal > p { margin: 0 0 1.5rem; color: #6b7280; }

	.confirmation-details {
		margin: 0 0 1.5rem;
		border: 1px solid #e5e7eb;
		border-radius: 10px;
		overflow: hidden;
		text-align: left;
	}

	.confirmation-modal[dir="rtl"] .confirmation-details {
		text-align: right;
	}

	.confirmation-details div {
		display: grid;
		grid-template-columns: 42% 1fr;
		gap: 1rem;
		padding: 0.9rem 1rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.confirmation-details div:last-child { border-bottom: 0; }
	.confirmation-details dt { color: #6b7280; font-size: 0.875rem; }
	.confirmation-details dd { margin: 0; color: #111827; font-weight: 650; }
	.confirmation-error { margin-bottom: 1rem; color: #b91c1c; font-size: 0.9rem; }

	.confirmation-actions {
		display: grid;
		grid-template-columns: 1.2fr 1fr 1fr;
		gap: 0.75rem;
	}

	.modal-btn {
		padding: 0.8rem 1rem;
		border-radius: 8px;
		font-weight: 700;
		cursor: pointer;
	}

	.modal-btn:disabled { opacity: 0.55; cursor: not-allowed; }
	.proceed-btn { border: 1px solid #15803d; background: #15803d; color: white; }
	.back-modal-btn { border: 1px solid #9ca3af; background: white; color: #374151; }
	.logout-btn { border: 1px solid #dc2626; background: white; color: #dc2626; }

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

	/* Full-page login layout matching desktop interface */
	.cashier-login-page {
		width: 100%;
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: #F9FAFB;
		position: relative;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* Background pattern */
	.cashier-login-page::before {
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

	.cashier-login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 900px;
		position: relative;
		z-index: 1;
	}

	/* Main card */
	.login-main-card {
		background: #FFFFFF;
		border-radius: 16px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1), 0 8px 32px rgba(107, 114, 128, 0.08);
		border: 1px solid rgba(229, 231, 235, 0.8);
		overflow: hidden;
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

	/* Logo section with gray gradient matching original cashier style */
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

	/* Language toggle button */
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

	/* Main content container */
	.login-container {
		padding: 3rem 2rem;
	}

	/* Auth form */
	.auth-form {
		max-width: 500px;
		margin: 0 auto;
	}

	.form-header {
		text-align: center;
		margin-bottom: 2.5rem;
		position: relative;
	}

	.back-btn {
		position: absolute;
		left: -2rem;
		right: auto;
		top: 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: none;
		border: none;
		color: #6b7280;
		font-size: 0.95rem;
		cursor: pointer;
		padding: 0.5rem;
		transition: color 0.2s ease;
	}

	/* RTL support for back button */
	[dir="rtl"] .back-btn {
		left: auto;
		right: -2rem;
		flex-direction: row-reverse;
	}

	.back-btn:hover {
		color: #374151;
	}

	.form-header h2 {
		font-size: 1.75rem;
		color: #111827;
		margin: 0 0 0.5rem 0;
		font-weight: 700;
	}

	.form-header p {
		color: #6b7280;
		font-size: 0.95rem;
		margin: 0;
	}

	/* User info card */
	.user-info-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.25rem;
		background: #f9fafb;
		border-radius: 12px;
		margin-bottom: 2rem;
		border: 1px solid #e5e7eb;
	}

	.user-avatar {
		width: 50px;
		height: 50px;
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		font-weight: 600;
		color: #111827;
		margin-bottom: 0.25rem;
		font-size: 1.05rem;
	}

	.user-role {
		font-size: 0.875rem;
		color: #6b7280;
	}

	/* Form fields */
	.form-fields {
		margin-bottom: 2rem;
	}

	.field-group {
		margin-bottom: 1.5rem;
	}

	.field-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.75rem;
		font-size: 0.95rem;
	}

	.field-group label svg {
		color: #6b7280;
	}

	/* Quick access digits */
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

	/* Field input (select) */
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

	.field-input option {
		color: #111827;
		background: white;
	}

	.field-input:focus {
		border-color: #6b7280;
		box-shadow: 0 0 0 3px rgba(107, 114, 128, 0.1);
	}

	.field-input:disabled {
		background: #f9fafb;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.field-error {
		display: block;
		color: #ef4444;
		font-size: 0.875rem;
		margin-top: 0.5rem;
	}

	.digits-with-toggle {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.digits-with-toggle .quick-access-digits {
		flex: 1;
	}

	.eye-toggle {
		background: rgba(99, 102, 241, 0.08);
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
		background: rgba(99, 102, 241, 0.15);
		color: #4F46E5;
		border-color: #C7D2FE;
	}

	.field-spacer {
		height: 3rem;
	}

	/* Submit button */
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

	/* Footer */
	.login-footer {
		padding: 1.5rem 2rem;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		text-align: center;
	}

	.login-footer p {
		color: #6b7280;
		font-size: 0.875rem;
		margin: 0;
	}

	/* Premium split-screen POS login */
	.cashier-login-page {
		padding: clamp(1rem, 3vw, 3rem);
		background:
			linear-gradient(rgba(8, 145, 178, 0.035) 1px, transparent 1px),
			linear-gradient(90deg, rgba(8, 145, 178, 0.035) 1px, transparent 1px),
			radial-gradient(circle at 12% 15%, rgba(34, 211, 238, 0.13), transparent 28%),
			#f6fafc;
		background-size: 32px 32px, 32px 32px, auto, auto;
	}

	.login-content { max-width: 1180px; }

	.login-main-card {
		display: grid;
		grid-template-columns: minmax(360px, 0.92fr) minmax(520px, 1.08fr);
		min-height: min(720px, calc(100dvh - 5rem));
		border-radius: 28px;
		border-color: rgba(255, 255, 255, 0.88);
		box-shadow: 0 32px 90px rgba(15, 48, 79, 0.17), 0 4px 16px rgba(15, 48, 79, 0.08);
	}

	.cashier-brand-panel {
		position: relative;
		overflow: hidden;
		color: white;
		background: linear-gradient(155deg, rgba(5, 31, 63, 0.97) 0%, rgba(5, 58, 102, 0.98) 52%, rgba(4, 91, 125, 0.97) 100%);
	}

	.cashier-brand-panel::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(125deg, transparent 0 56%, rgba(255, 255, 255, 0.055) 56% 56.4%, transparent 56.4%), radial-gradient(circle at 70% 22%, rgba(33, 211, 238, 0.19), transparent 24%);
		pointer-events: none;
	}

	.cashier-brand-content {
		position: relative;
		z-index: 1;
		display: flex;
		flex-direction: column;
		min-height: 100%;
		padding: clamp(2.4rem, 4vw, 4.6rem);
		box-sizing: border-box;
	}

	.cashier-brand-lockup {
		width: 100%;
		overflow: hidden;
		padding-block: 6px;
		direction: ltr;
		-webkit-mask-image: linear-gradient(90deg, transparent 0, #000 12%, #000 88%, transparent 100%);
		mask-image: linear-gradient(90deg, transparent 0, #000 12%, #000 88%, transparent 100%);
	}

	.cashier-marquee-track {
		display: flex;
		width: max-content;
		animation: cashierBrandMarquee 28s linear infinite;
	}

	.cashier-brand-lockup:hover .cashier-marquee-track {
		animation-play-state: paused;
	}

	.cashier-marquee-group {
		display: flex;
		flex-shrink: 0;
		align-items: center;
		gap: 1.4rem;
		padding-inline: 0.7rem;
	}

	@keyframes cashierBrandMarquee {
		from { transform: translateX(0); }
		to { transform: translateX(-50%); }
	}

	@media (prefers-reduced-motion: reduce) {
		.cashier-marquee-track { animation: none; }
	}

	.cashier-logo-card {
		display: grid;
		place-items: center;
		width: 112px;
		height: 96px;
		padding: 0.55rem;
		box-sizing: border-box;
		border-radius: 18px;
		background: white;
		outline: 1px solid rgba(255, 255, 255, 0.55);
		outline-offset: 4px;
	}

	.cashier-logo-card img { width: 86px; height: 72px; object-fit: contain; }

	.cashier-brand-copy { margin: auto 0; padding: 3rem 0; }
	.cashier-brand-copy > span { display: inline-flex; align-items: center; gap: .55rem; color: #75e7f4; font-size: .72rem; font-weight: 800; letter-spacing: .18em; }
	.cashier-brand-copy > span::before { content: ''; width: 24px; height: 2px; border-radius: 2px; background: currentColor; }
	.cashier-brand-copy h1 {
		max-width: 470px;
		margin: 1.1rem 0 1rem;
		font-size: clamp(2.3rem, 4.1vw, 4.4rem);
		font-weight: 760;
		line-height: 1.02;
		letter-spacing: -0.045em;
		animation: cashierCopyFade 5.5s cubic-bezier(0.22, 1, 0.36, 1) infinite both;
	}
	.cashier-brand-copy p {
		max-width: 430px;
		margin: 0;
		color: rgba(231, 248, 255, 0.78);
		line-height: 1.75;
		animation: cashierCopyFade 5.5s cubic-bezier(0.22, 1, 0.36, 1) infinite both;
	}
	.cashier-security-note { display: flex; align-items: center; gap: .9rem; padding-top: 1.5rem; border-top: 1px solid rgba(255,255,255,.13); }
	.cashier-security-icon { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 13px; color: #72e7f3; background: rgba(31,202,224,.12); border: 1px solid rgba(91,222,239,.2); flex: 0 0 auto; }
	.cashier-security-icon svg { width: 21px; height: 21px; }
	.cashier-security-note > div { display: grid; gap: .2rem; }
	.cashier-security-note strong { font-size: .86rem; }
	.cashier-security-note > div span { font-size: .75rem; line-height: 1.4; color: rgba(227,246,253,.62); }

	@keyframes cashierCopyFade {
		0% { opacity: 0; transform: translateY(20px); filter: blur(4px); }
		20%, 82% { opacity: 1; transform: translateY(0); filter: blur(0); }
		100% { opacity: 0; transform: translateY(-8px); filter: blur(3px); }
	}

	.cashier-login-workspace { display: flex; flex-direction: column; min-width: 0; background: rgba(255,255,255,.98); }
	.logo-section { padding: 1.4rem clamp(1.7rem, 3vw, 3rem) 0; background: transparent; color: #15334d; }
	.logo-header { justify-content: space-between; max-width: none; }
	.header-back-btn, .language-toggle-main { color: #24465f; background: #f3f7fa; border: 1px solid #dce7ed; box-shadow: 0 3px 10px rgba(16,56,84,.05); }
	.header-back-btn { display: grid; place-items: center; width: 42px; height: 42px; padding: 0; border-radius: 13px; cursor: pointer; }
	.language-toggle-main:hover { color: #075985; background: #e9f7fb; border-color: #b8e5ed; }
	.language-toggle-main { min-height: 42px; padding: .58rem .9rem; border-radius: 13px; font-size: .82rem; font-weight: 700; }
	.login-container { flex: 1; display: flex; flex-direction: column; justify-content: center; padding: 1.8rem clamp(2.5rem, 5vw, 5.5rem) 1.2rem; }
	.auth-form { width: 100%; max-width: 510px; }
	.form-header { margin-bottom: 1.25rem; text-align: start; }
	.form-header::before { content: ''; display: block; width: 42px; height: 4px; margin-bottom: 1.25rem; border-radius: 99px; background: linear-gradient(90deg,#08b6d5,#1768b0); }
	.form-header h2 { margin-bottom: .55rem; font-size: clamp(1.9rem,2.7vw,2.65rem); font-weight: 760; letter-spacing: -.035em; color: #102f49; }
	.form-header p { font-size: .98rem; line-height: 1.6; color: #688094; }
	.field-group label { font-size: .78rem; font-weight: 750; letter-spacing: .035em; text-transform: uppercase; color: #466075; }
	.quick-access-digits { justify-content: flex-start; gap: clamp(.55rem,1vw,.75rem); margin: 0; }
	.digit-input { width: clamp(52px,4.6vw,61px); height: clamp(58px,5.2vw,68px); box-sizing: border-box; border: 1px solid #cbdce5; border-radius: 15px; background: #f8fbfc; font-size: 1.65rem; font-weight: 760; color: #123a56; }
	.eye-toggle { width: 38px; height: 38px; justify-content: center; padding: 0; border-radius: 11px; color: #3e6985; background: #f3f8fa; border-color: #dce9ee; }
	.field-spacer { display: none; }
	.auth-submit-btn { min-height: 58px; margin-top: .35rem; border-radius: 15px; background: linear-gradient(115deg,#087ca5 0%,#075b91 52%,#063d70 100%); font-size: 1rem; font-weight: 760; box-shadow: 0 13px 28px rgba(7,91,145,.22); }
	.digit-input:focus, .field-input:focus { border-color: #08a6c1; box-shadow: 0 0 0 4px rgba(8,166,193,.12); }
	.change-code-link { width: fit-content; margin: .2rem auto 0; padding: .65rem .8rem; border-radius: 10px; color: #176b9e; font-size: .82rem; font-weight: 650; text-decoration: none; }
	.login-footer { display: none; }

	:global(html[dir="rtl"]) .cashier-brand-copy { text-align: right; }
	:global(html[dir="rtl"]) .header-back-btn svg { transform: scaleX(-1); }

	@media (max-width: 980px) {
		.login-main-card { grid-template-columns: 1fr; min-height: auto; }
		.cashier-brand-panel { display: none; }
	}

	/* Responsive */
	@media (max-width: 768px) {
		.confirmation-modal {
			padding: 1.5rem;
		}

		.confirmation-actions {
			grid-template-columns: 1fr;
		}

		.assigned-branch-card {
			align-items: stretch;
			flex-direction: column;
		}

		.cashier-login-page {
			padding: 0.5rem;
		}

		.logo-section {
			padding: 2rem 1.5rem 1.5rem;
		}

		.logo-icon {
			font-size: 3rem;
		}

		.system-title {
			font-size: 1.5rem;
		}

		.login-container {
			padding: 2rem 1.5rem;
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

		.back-btn {
			position: static;
			margin-bottom: 1rem;
		}
	}
</style>

