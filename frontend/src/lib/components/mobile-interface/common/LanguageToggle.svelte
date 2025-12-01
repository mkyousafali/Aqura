<script lang="ts">
	import { currentLocale, switchLocale, localeData } from '$lib/i18n';
	import { createEventDispatcher } from 'svelte';

	const dispatch = createEventDispatcher();

	function toggleLanguage() {
		const newLocale = $currentLocale === 'en' ? 'ar' : 'en';
		switchLocale(newLocale);
		dispatch('languageChanged', { locale: newLocale });
		
		// Trigger hard refresh after a short delay to allow locale switch to complete
		setTimeout(() => {
			window.location.reload();
		}, 100);
	}

	// Show the language you can switch TO, not the current language
	$: switchToLanguageDisplay = $currentLocale === 'en' ? 'عربي' : 'English';
	$: switchToLanguageCode = $currentLocale === 'en' ? 'عر' : 'EN';

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
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
</script>

<svelte:window />

<div class="language-toggle" class:rtl={$currentLocale === 'ar'}>
	<button 
		class="language-btn" 
		on:click={toggleLanguage}
		aria-label="{getTranslation('nav.languageToggle')} - {switchToLanguageDisplay}"
		title="{getTranslation('nav.languageToggle')} ({switchToLanguageDisplay})"
	>
		<span class="switch-to-lang">{switchToLanguageDisplay}</span>
	</button>
</div>

<style>
	.language-toggle {
		position: relative;
		display: inline-block;
	}

	.language-btn {
		width: 28px;
		height: 28px;
		background: rgba(255, 255, 255, 0.1);
		color: #FFFFFF;
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 10px;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(10px);
		touch-action: manipulation;
	}

	.language-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.language-btn:active {
		transform: scale(0.95);
		background: rgba(255, 255, 255, 0.15);
	}

	.switch-to-lang {
		font-weight: 700;
		font-size: 9px;
		letter-spacing: 0.2px;
		line-height: 1;
		color: #FFFFFF;
		white-space: nowrap;
		text-transform: uppercase;
	}

	/* Mobile-specific adjustments */
	@media (max-width: 768px) {
		.switch-to-lang {
			font-size: 8px;
		}
	}

	/* RTL support */
	.rtl {
		direction: rtl;
	}

	.rtl .language-btn {
		direction: ltr; /* Keep button content LTR for mixed text */
	}

	/* Dark theme compatibility */
	@media (prefers-color-scheme: dark) {
		.language-btn {
			background: rgba(0, 0, 0, 0.2);
			border-color: rgba(255, 255, 255, 0.1);
		}

		.language-btn:hover {
			background: rgba(0, 0, 0, 0.3);
		}

		.language-btn:active {
			background: rgba(0, 0, 0, 0.25);
		}
	}

	/* Enhanced visual feedback */
	.language-btn {
		position: relative;
		overflow: hidden;
	}

	.language-btn::before {
		content: '';
		position: absolute;
		top: 0;
		left: -100%;
		width: 100%;
		height: 100%;
		background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
		transition: left 0.5s ease;
	}

	.language-btn:hover::before {
		left: 100%;
	}

	/* Accessibility */
	.language-btn:focus {
		outline: 2px solid rgba(255, 255, 255, 0.5);
		outline-offset: 2px;
	}

	.language-btn:focus:not(:focus-visible) {
		outline: none;
	}
</style>
