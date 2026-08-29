<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	let email = '';
	let whatsappNumber = '';
	let employeeId = '';
	let isLoading = true;
	let loadError = false;

	$: isArabic = $currentLocale === 'ar';

	onMount(loadProfile);

	async function loadProfile() {
		const userId = $currentUser?.id;
		if (!userId) {
			loadError = true;
			isLoading = false;
			return;
		}

		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, email, whatsapp_number')
				.eq('user_id', userId)
				.maybeSingle();

			if (error) throw error;
			employeeId = data?.id?.trim() || '';
			email = data?.email?.trim() || '';
			whatsappNumber = data?.whatsapp_number?.trim() || '';
		} catch (error) {
			console.error('Failed to load employee profile:', error);
			loadError = true;
		} finally {
			isLoading = false;
		}
	}
</script>

<svelte:head>
	<title>{isArabic ? 'ملفي الشخصي' : 'My Profile'} | Aqura</title>
</svelte:head>

<section class="profile-page" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="profile-card">
		<div class="profile-icon" aria-hidden="true">
			<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
				<path d="M20 21a8 8 0 0 0-16 0" />
				<circle cx="12" cy="7" r="4" />
			</svg>
		</div>
		<h2>{isArabic ? 'ملفي الشخصي' : 'My Profile'}</h2>
		<p class="subtitle">{isArabic ? 'معلومات الاتصال الخاصة بك' : 'Your contact information'}</p>

		{#if isLoading}
			<div class="loading-row" aria-live="polite">
				<span class="spinner"></span>
				<span>{isArabic ? 'جارٍ تحميل الملف الشخصي...' : 'Loading profile...'}</span>
			</div>
		{:else}
			{#if loadError}
				<p class="error-message" role="alert">{isArabic ? 'تعذر تحميل معلومات الملف الشخصي.' : 'Unable to load profile information.'}</p>
			{/if}

			<div class="field-group">
				<label for="profile-employee-id">{isArabic ? 'رقم الموظف' : 'Employee ID'}</label>
				<div class="input-wrap">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
						<rect x="3" y="4" width="18" height="16" rx="2" />
						<circle cx="8" cy="10" r="2" />
						<path d="M6 16c.7-1.3 1.7-2 3-2s2.3.7 3 2M14 9h4M14 13h4" />
					</svg>
					<input id="profile-employee-id" type="text" value={employeeId} placeholder={isArabic ? 'غير متوفر' : 'Not available'} readonly />
				</div>
			</div>

			<div class="field-group">
				<label for="profile-email">{isArabic ? 'البريد الإلكتروني' : 'Email address'}</label>
				<div class="input-wrap">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
						<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
						<polyline points="22,6 12,13 2,6" />
					</svg>
					<input id="profile-email" type="email" value={email} placeholder={isArabic ? 'غير متوفر' : 'Not available'} readonly />
				</div>
			</div>

			<div class="field-group">
				<label for="profile-whatsapp">{isArabic ? 'رقم واتساب' : 'WhatsApp number'}</label>
				<div class="input-wrap">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
						<path d="M21 11.5a8.4 8.4 0 0 1-9 8.5 8.4 8.4 0 0 1-3.8-.9L3 21l1.8-5.3A8.5 8.5 0 1 1 21 11.5z" />
						<path d="M9.4 8.5c.2 2.7 2 4.5 4.7 4.8" />
					</svg>
					<input id="profile-whatsapp" type="tel" value={whatsappNumber} placeholder={isArabic ? 'غير متوفر' : 'Not available'} readonly />
				</div>
			</div>
		{/if}
	</div>
</section>

<style>
	.profile-page {
		min-height: calc(100vh - 138px);
		padding: 20px 16px 96px;
		background: var(--mobile-bg, #f3f6fb);
	}

	.profile-card {
		max-width: 560px;
		margin: 0 auto;
		padding: 28px 20px;
		background: var(--mobile-card-bg, #fff);
		border: 1px solid var(--mobile-border, #e5e7eb);
		border-radius: 20px;
		box-shadow: 0 10px 28px rgb(15 23 42 / 8%);
	}

	.profile-icon {
		display: grid;
		place-items: center;
		width: 64px;
		height: 64px;
		margin: 0 auto 14px;
		color: var(--mobile-primary, #2563eb);
		background: color-mix(in srgb, var(--mobile-primary, #2563eb) 12%, white);
		border-radius: 50%;
	}

	h2 { margin: 0; color: var(--mobile-text, #172033); text-align: center; font-size: 1.45rem; }
	.subtitle { margin: 6px 0 28px; color: var(--mobile-text-secondary, #64748b); text-align: center; font-size: .93rem; }
	.field-group + .field-group { margin-top: 20px; }
	label { display: block; margin-bottom: 8px; color: var(--mobile-text, #334155); font-size: .86rem; font-weight: 700; }

	.input-wrap { position: relative; }
	.input-wrap svg { position: absolute; inset-inline-start: 14px; top: 50%; color: var(--mobile-text-secondary, #64748b); transform: translateY(-50%); pointer-events: none; }
	input {
		box-sizing: border-box;
		width: 100%;
		min-height: 52px;
		padding: 12px 14px;
		padding-inline-start: 46px;
		color: var(--mobile-text, #172033);
		background: var(--mobile-input-bg, #f8fafc);
		border: 1px solid var(--mobile-border, #dbe2ea);
		border-radius: 12px;
		font: inherit;
		font-weight: 500;
		outline: none;
		cursor: text;
	}
	input:focus { border-color: var(--mobile-primary, #2563eb); box-shadow: 0 0 0 3px rgb(37 99 235 / 10%); }
	input::placeholder { color: var(--mobile-text-secondary, #94a3b8); }

	.loading-row { display: flex; align-items: center; justify-content: center; gap: 10px; min-height: 124px; color: var(--mobile-text-secondary, #64748b); }
	.spinner { width: 20px; height: 20px; border: 2px solid #dbeafe; border-top-color: var(--mobile-primary, #2563eb); border-radius: 50%; animation: spin .7s linear infinite; }
	.error-message { margin: 0 0 18px; padding: 11px 12px; color: #b91c1c; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; font-size: .88rem; }
	@keyframes spin { to { transform: rotate(360deg); } }

	@media (max-width: 380px) {
		.profile-page { padding-inline: 12px; }
		.profile-card { padding-inline: 16px; }
	}
</style>
