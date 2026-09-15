<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { switchLocale } from '$lib/i18n';

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
	// Mode controls z-index layering, same convention as ContactInfoOverlay:
	// 'desktop' = below sidebar (1200) & taskbar (2000)
	// 'mobile'  = below header (100) & bottom-nav (1000)
	// 'cashier' = covers everything
	export let mode: 'desktop' | 'mobile' | 'cashier' = 'desktop';

	let showOverlay = false;
	let isSaving = false;
	let selected: 'en' | 'ar' | null = null;
	let lastCheckedUserId: string | null = null;

	$: if ($currentUser) {
		if ($currentUser.id && $currentUser.id !== lastCheckedUserId) {
			checkLanguage();
		}
	}

	$: if (employeeId && employeeId !== lastCheckedUserId) {
		checkLanguage();
	}

	async function checkLanguage() {
		const userId = employeeId || $currentUser?.id;
		if (!userId) return;
		if (userId === lastCheckedUserId) return;

		lastCheckedUserId = userId;

		try {
			const { data, error } = await supabase
				.from('users')
				.select('default_language')
				.eq('id', userId)
				.single();

			if (error) {
				console.error('Error checking default language:', error);
				return;
			}

			if (data && !data.default_language) {
				showOverlay = true;
			}
		} catch (err) {
			console.error('Error checking default language:', err);
		}
	}

	async function chooseLanguage(locale: 'en' | 'ar') {
		const userId = employeeId || $currentUser?.id;
		if (!userId || isSaving) return;

		selected = locale;
		isSaving = true;

		try {
			const { error } = await supabase
				.from('users')
				.update({ default_language: locale })
				.eq('id', userId);

			if (error) {
				console.error('Error saving default language:', error);
				isSaving = false;
				selected = null;
				return;
			}

			switchLocale(locale);

			// Match the app-wide convention: every existing language switch
			// (Sidebar, Taskbar, LanguageToggle, cashier toggles) reloads the
			// page after switchLocale() so the whole UI re-renders cleanly.
			setTimeout(() => {
				showOverlay = false;
				if (onComplete) onComplete();
				window.location.reload();
			}, 300);
		} catch (err) {
			console.error('Error saving default language:', err);
			isSaving = false;
			selected = null;
		}
	}
</script>

{#if showOverlay}
	<div class="lang-overlay {mode}-mode" role="dialog" tabindex="-1" use:portal>
		<div class="overlay-backdrop"></div>
		<div class="overlay-card">
			<div class="overlay-header">
				<div class="header-icon">🌐</div>
				<h2>اختر لغتك المفضلة</h2>
				<p class="header-subtitle-en">Choose your preferred language</p>
				<p class="header-note">
					يمكنك تغييرها لاحقًا من صفحة الملف الشخصي · You can change this later from your profile page
				</p>
			</div>

			<div class="lang-options">
				<button
					class="lang-btn"
					class:selected={selected === 'ar'}
					disabled={isSaving}
					on:click={() => chooseLanguage('ar')}
				>
					{#if isSaving && selected === 'ar'}
						<span class="spinner"></span>
					{:else}
						<span class="lang-flag">🇸🇦</span>
					{/if}
					<span class="lang-label">العربية</span>
				</button>
				<button
					class="lang-btn"
					class:selected={selected === 'en'}
					disabled={isSaving}
					on:click={() => chooseLanguage('en')}
				>
					{#if isSaving && selected === 'en'}
						<span class="spinner"></span>
					{:else}
						<span class="lang-flag">🇬🇧</span>
					{/if}
					<span class="lang-label">English</span>
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(.lang-overlay) {
		position: fixed;
		inset: 0;
		z-index: 99999;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: langFadeIn 0.3s ease;
		pointer-events: auto;
	}

	:global(.lang-overlay.desktop-mode) {
		z-index: 50000;
	}

	:global(.lang-overlay.mobile-mode) {
		z-index: 50000;
	}

	:global(.lang-overlay.cashier-mode) {
		z-index: 99999;
	}

	:global(.lang-overlay .overlay-backdrop) {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
	}

	:global(.lang-overlay .overlay-card) {
		position: relative;
		background: white;
		border-radius: 24px;
		padding: 40px 36px;
		max-width: 440px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 25px 60px rgba(0, 0, 0, 0.3);
		animation: langScaleIn 0.3s ease;
		text-align: center;
	}

	:global(.lang-overlay .overlay-header) {
		margin-bottom: 28px;
	}

	:global(.lang-overlay .header-icon) {
		font-size: 48px;
		margin-bottom: 12px;
	}

	:global(.lang-overlay .overlay-header h2) {
		font-size: 22px;
		font-weight: 800;
		color: #111827;
		margin: 0 0 4px 0;
		direction: rtl;
	}

	:global(.lang-overlay .header-subtitle-en) {
		font-size: 17px;
		font-weight: 700;
		color: #374151;
		margin: 0 0 12px 0;
	}

	:global(.lang-overlay .header-note) {
		font-size: 12.5px;
		color: #6b7280;
		margin: 0;
		line-height: 1.6;
	}

	:global(.lang-overlay .lang-options) {
		display: flex;
		gap: 14px;
	}

	:global(.lang-overlay .lang-btn) {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 10px;
		padding: 22px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 16px;
		background: #f9fafb;
		cursor: pointer;
		transition: all 0.2s ease;
		font-family: inherit;
	}

	:global(.lang-overlay .lang-btn:hover:not(:disabled)) {
		border-color: #059669;
		background: #f0fdf4;
		transform: translateY(-2px);
	}

	:global(.lang-overlay .lang-btn.selected) {
		border-color: #059669;
		background: #ecfdf5;
	}

	:global(.lang-overlay .lang-btn:disabled) {
		cursor: not-allowed;
		opacity: 0.8;
	}

	:global(.lang-overlay .lang-flag) {
		font-size: 34px;
		line-height: 1;
	}

	:global(.lang-overlay .lang-label) {
		font-size: 16px;
		font-weight: 700;
		color: #111827;
	}

	:global(.lang-overlay .spinner) {
		width: 28px;
		height: 28px;
		border: 3px solid rgba(5, 150, 105, 0.25);
		border-left-color: #059669;
		border-radius: 50%;
		animation: langSpin 0.8s linear infinite;
	}

	@keyframes langFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes langScaleIn {
		from { opacity: 0; transform: scale(0.9); }
		to { opacity: 1; transform: scale(1); }
	}

	@keyframes langSpin {
		to { transform: rotate(360deg); }
	}

	@media (max-width: 480px) {
		:global(.lang-overlay .overlay-card) {
			padding: 28px 20px;
			border-radius: 18px;
			width: 92%;
		}

		:global(.lang-overlay .lang-options) {
			gap: 10px;
		}

		:global(.lang-overlay .lang-btn) {
			padding: 18px 8px;
		}
	}
</style>
