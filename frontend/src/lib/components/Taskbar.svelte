<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { currentLocale, switchLocale, getAvailableLocales } from '$lib/i18n';
	import { t } from '$lib/i18n';
	import { onMount } from 'svelte';

	// Subscribe to taskbar items
	$: taskbarItems = windowManager.taskbarItems;
	$: activeWindow = windowManager.activeWindow;

	// Language data
	$: availableLocales = getAvailableLocales();
	$: currentLang = $currentLocale;

	// Taskbar expansion state
	let isExpanded = false;

	// Show current time and date
	let currentTime = '';
	let currentDate = '';
	let timeInterval: NodeJS.Timeout;

	onMount(() => {
		updateTime();
		timeInterval = setInterval(updateTime, 1000);
		
		return () => {
			if (timeInterval) clearInterval(timeInterval);
		};
	});

	function updateTime() {
		const now = new Date();
		currentTime = now.toLocaleTimeString([], { 
			hour: '2-digit', 
			minute: '2-digit',
			hour12: true 
		});
		currentDate = now.toLocaleDateString('en-GB', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
	}

	function activateWindow(windowId: string) {
		const window = windowManager.getWindow(windowId);
		if (!window) return;

		if (window.state === 'minimized' || !window.isActive) {
			windowManager.activateWindow(windowId);
		} else {
			// If window is already active, minimize it
			windowManager.minimizeWindow(windowId);
		}
	}

	function showDesktop() {
		// Toggle expansion instead of just minimizing windows
		isExpanded = !isExpanded;
		
		// If expanding, also minimize all windows
		if (isExpanded) {
			const windows = windowManager.windowList;
			windows.forEach(window => {
				if (window.state !== 'minimized') {
					windowManager.minimizeWindow(window.id);
				}
			});
		}
	}

	function toggleLanguage() {
		// Switch between English and Arabic
		const nextLocale = currentLang === 'en' ? 'ar' : 'en';
		switchLocale(nextLocale);
	}

	function getLanguageDisplayName(locale: string): string {
		const localeData = availableLocales.find(l => l.code === locale);
		return localeData?.name || locale.toUpperCase();
	}
</script>

<div class="taskbar">
	<!-- Window Tasks -->
	<div class="task-list">
		{#each $taskbarItems as item (item.windowId)}
			<button
				class="task-button"
				class:active={item.isActive}
				class:minimized={item.isMinimized}
				on:click={() => activateWindow(item.windowId)}
				title={item.title}
			>
				{#if item.icon}
					<img src={item.icon} alt="" class="task-icon" />
				{/if}
				<span class="task-title">{item.title}</span>
			</button>
		{/each}
	</div>

	<!-- System Tray -->
	<div class="system-tray">
		<!-- Show Desktop Button -->
		<button 
			class="tray-button desktop-button" 
			class:active={isExpanded}
			on:click={showDesktop} 
			title={isExpanded ? "Hide Extended View" : "Show Desktop & Extend"}
			aria-label={isExpanded ? "Hide extended view" : "Show desktop and extend taskbar"}
		>
			<svg viewBox="0 0 16 16" width="16" height="16">
				<rect x="2" y="3" width="12" height="9" stroke="currentColor" stroke-width="1" fill="none" />
				<rect x="4" y="5" width="8" height="1" fill="currentColor" />
				{#if isExpanded}
					<path d="M6 6 L10 6 M8 4 L8 8" stroke="currentColor" stroke-width="1"/>
				{/if}
			</svg>
		</button>
	</div>
</div>

<!-- Extended System Tray Overlay - positioned above taskbar -->
{#if isExpanded}
	<div class="extended-overlay">
		<div class="extended-menu">
			<!-- Language Toggle -->
			<button 
				class="language-toggle" 
				on:click={toggleLanguage}
				title="Switch Language / تبديل اللغة"
				aria-label="Switch language"
			>
				<span class="language-text">{getLanguageDisplayName(currentLang)}</span>
			</button>

			<!-- User Information -->
			<div class="user-info-taskbar">
				<div class="user-avatar-taskbar">
					<span>U</span>
				</div>
				<div class="user-details-taskbar">
					<div class="user-name-taskbar">{t('nav.user') || 'User'}</div>
					<div class="user-role-taskbar">{t('admin.title') || 'Administrator'}</div>
				</div>
			</div>

			<!-- Clock -->
			<div class="clock" title={new Date().toLocaleDateString()}>
				{currentTime}
			</div>

			<!-- Date -->
			<div class="date" title="Current date">
				{currentDate}
			</div>
		</div>
	</div>
{/if}

<style>
	.taskbar {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		height: 56px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-top: 2px solid rgba(245, 158, 11, 0.3);
		display: flex;
		align-items: center;
		padding: 0 8px;
		gap: 8px;
		z-index: 2000;
		box-shadow: 
			0 -4px 20px rgba(11, 18, 32, 0.2),
			0 -1px 3px rgba(245, 158, 11, 0.2);
		backdrop-filter: blur(10px);
	}

	.task-list {
		display: flex;
		gap: 4px;
		flex: 1;
		overflow-x: auto;
		padding: 0 8px;
	}

	.task-list::-webkit-scrollbar {
		display: none;
	}

	.task-button {
		display: flex;
		align-items: center;
		gap: 6px;
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		border: 1px solid rgba(229, 231, 235, 0.8);
		border-radius: 4px;
		padding: 6px 8px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 100px;
		max-width: 180px;
		flex-shrink: 0;
	}

	.task-button:hover {
		background: #FFFFFF;
		border-color: #4F46E5;
		color: #4F46E5;
	}

	.task-button.active {
		background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%);
		color: white;
		border-color: #4338CA;
	}

	.task-button.minimized {
		background: rgba(255, 255, 255, 0.6);
		color: #6B7280;
		font-style: italic;
	}

	.task-icon {
		width: 16px;
		height: 16px;
		flex-shrink: 0;
	}

	.task-title {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.system-tray {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-shrink: 0;
	}

	.desktop-button {
		/* Always show first */
	}

	.desktop-button.active {
		background: rgba(255, 255, 255, 0.4);
		color: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
	}

	/* Extended Overlay Menu */
	.extended-overlay {
		position: fixed;
		bottom: 56px; /* Position above taskbar */
		right: 8px; /* Align with system tray area */
		z-index: 3000; /* Above taskbar */
		animation: slideUp 0.3s ease;
	}

	.extended-menu {
		background: linear-gradient(135deg, #374151 0%, #1f2937 100%);
		border: 1px solid #4b5563;
		border-radius: 12px 12px 12px 4px; /* Rounded except bottom-right */
		box-shadow: 0 -8px 32px rgba(0, 0, 0, 0.4);
		padding: 8px;
		display: flex;
		flex-direction: column;
		gap: 6px;
		width: 120px; /* Fixed width to accommodate all elements */
		backdrop-filter: blur(10px);
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.tray-button {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.tray-button:hover {
		background: rgba(255, 255, 255, 0.3);
		color: white;
	}

	.language-toggle {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 32px;
		padding: 0 8px;
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		border: 1px solid rgba(229, 231, 235, 0.5);
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 12px;
		font-weight: 500;
		width: 100px; /* Fixed width for consistency */
	}

	.language-toggle:hover {
		background: #FFFFFF;
		border-color: #4F46E5;
		color: #4F46E5;
	}

	.language-text {
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.user-info-taskbar {
		display: flex;
		align-items: center;
		gap: 8px;
		background: rgba(255, 255, 255, 0.95);
		border: 1px solid rgba(229, 231, 235, 0.5);
		border-radius: 4px;
		padding: 0 8px;
		height: 32px; /* Same height as language toggle */
		width: 100px; /* Fixed width same as language toggle */
	}

	.user-avatar-taskbar {
		width: 24px;
		height: 24px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 10px;
		color: white;
		flex-shrink: 0;
	}

	.user-details-taskbar {
		min-width: 0;
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.user-name-taskbar {
		font-weight: 500;
		font-size: 11px;
		color: #0B1220;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		line-height: 1.2;
	}

	.user-role-taskbar {
		font-size: 9px;
		color: #6B7280;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		line-height: 1.2;
	}

	.clock {
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		padding: 0 8px;
		border-radius: 4px; /* Full border radius for independent element */
		font-family: 'Segoe UI', monospace;
		font-size: 12px;
		font-weight: 500;
		height: 32px; /* Full height like other elements */
		text-align: center;
		border: 1px solid rgba(229, 231, 235, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100px; /* Same width as other elements */
	}

	.date {
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		padding: 0 8px;
		border-radius: 4px; /* Full border radius for independent element */
		font-family: 'Segoe UI', monospace;
		font-size: 11px;
		font-weight: 500;
		height: 32px; /* Same height as other elements */
		text-align: center;
		border: 1px solid rgba(229, 231, 235, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100px; /* Same width as other elements */
	}

	/* Responsive design */
	@media (max-width: 768px) {
		.taskbar {
			height: 44px;
			padding: 0 4px;
			gap: 4px;
		}

		.task-button {
			min-width: 100px;
			max-width: 150px;
			padding: 4px 8px;
		}

		.extended-overlay {
			bottom: 44px; /* Mobile taskbar height */
			right: 4px;
		}

		.extended-menu {
			width: 100px; /* Smaller width for mobile to accommodate 80px elements + padding */
			padding: 6px;
			gap: 4px;
		}

		.clock {
			padding: 0 4px;
			font-size: 10px;
			height: 28px; /* Consistent mobile height */
			width: 80px; /* Mobile width */
		}

		.date {
			padding: 0 4px;
			font-size: 9px;
			height: 28px; /* Same as other elements on mobile */
			width: 80px; /* Mobile width */
		}

		.user-info-taskbar {
			width: 80px; /* Same as clock-section on mobile */
			height: 28px; /* Same as clock on mobile */
		}

		.language-toggle {
			width: 80px; /* Same as other elements on mobile */
			height: 28px; /* Consistent mobile height */
		}
	}
</style>
