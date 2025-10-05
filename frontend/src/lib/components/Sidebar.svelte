<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { sidebar } from '$lib/stores/sidebar';
	import { t, currentLocale } from '$lib/i18n';
	import { showInstallPrompt, isInstalled, installPWA, initPWAInstall } from '$lib/stores/pwaInstall';
	import { onMount } from 'svelte';
	import BranchMaster from '$lib/components/admin/BranchMaster.svelte';
	import TaskMaster from '$lib/components/admin/TaskMaster.svelte';
	import HRMaster from '$lib/components/admin/HRMaster.svelte';
	import VendorMaster from '$lib/components/admin/VendorMaster.svelte';
	import UserManagement from '$lib/components/admin/UserManagement.svelte';
	import CommunicationCenter from '$lib/components/admin/CommunicationCenter.svelte';

	let showMasterSubmenu = false;
	let showSettingsSubmenu = false;
	let submenuTimeout: ReturnType<typeof setTimeout> | null = null;
	let masterButtonElement: HTMLButtonElement;
	let settingsButtonElement: HTMLButtonElement;
	let submenuTop = 0;
	
	// Force reactivity when locale changes
	$: locale = $currentLocale;

	// Initialize PWA install detection
	onMount(() => {
		initPWAInstall();
	});

	// Handle PWA installation
	async function handlePWAInstall() {
		try {
			const success = await installPWA();
			if (success) {
				console.log('PWA installed successfully');
			} else {
				console.log('PWA installation instructions shown');
			}
		} catch (error) {
			console.error('Error installing PWA:', error);
			// The installPWA function already handles showing appropriate instructions
		}
	}

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openBranches() {
		const windowId = generateWindowId('branch-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `${t('admin.branchesMaster') || 'Branch Master'} #${instanceNumber}`,
			component: BranchMaster,
			icon: '🏢',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function openTaskMaster() {
		const windowId = generateWindowId('task-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `${t('admin.taskMaster') || 'Task Master'} #${instanceNumber}`,
			component: TaskMaster,
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function openHRMaster() {
		const windowId = generateWindowId('hr-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `HR Master #${instanceNumber}`,
			component: HRMaster,
			icon: '👥',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function openVendorMaster() {
		const windowId = generateWindowId('vendor-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Vendor Master #${instanceNumber}`,
			component: VendorMaster,
			icon: '🏪',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), // Slightly offset each new window
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function showComingSoon(section: string) {
		// You can implement a toast notification or modal here
		alert(`${section} - ${t('status.pending') || 'pending'}...`);
	}

	function openUserManagement() {
		const windowId = generateWindowId('user-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `User Management #${instanceNumber}`,
			component: UserManagement,
			icon: '👤',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showSettingsSubmenu = false;
	}

	function openCommunicationCenter() {
		const windowId = generateWindowId('communication-center');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Communication Center #${instanceNumber}`,
			component: CommunicationCenter,
			icon: '📞',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		showMasterSubmenu = false;
	}

	function handleMasterMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
		// Calculate the position of the submenu
		if (masterButtonElement) {
			const rect = masterButtonElement.getBoundingClientRect();
			submenuTop = rect.top;
		}
		showMasterSubmenu = true;
	}

	function handleMasterMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showMasterSubmenu = false;
		}, 300);
	}

	function handleSubmenuMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
	}

	function handleSubmenuMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showMasterSubmenu = false;
		}, 300);
	}

	function handleSettingsMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
		// Calculate the position of the submenu
		if (settingsButtonElement) {
			const rect = settingsButtonElement.getBoundingClientRect();
			submenuTop = rect.top;
		}
		showSettingsSubmenu = true;
	}

	function handleSettingsMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showSettingsSubmenu = false;
		}, 300);
	}

	function handleSettingsSubmenuMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
	}

	function handleSettingsSubmenuMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showSettingsSubmenu = false;
		}, 300);
	}
</script>

<div class="sidebar">
	<div class="sidebar-content">
		<!-- Master Section -->
		<div class="menu-section">
			<button 
				bind:this={masterButtonElement}
				class="section-button master-button"
				on:mouseenter={handleMasterMouseEnter}
				on:mouseleave={handleMasterMouseLeave}
			>
				<span class="section-icon">📁</span>
				<span class="section-text">{t('nav.master') || 'Master'}</span>
				<span class="arrow">▶</span>
			</button>
		</div>

		<!-- Work Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showComingSoon(t('nav.work') || 'Work')}
			>
				<span class="section-icon">💼</span>
				<span class="section-text">{t('nav.work') || 'Work'}</span>
			</button>
		</div>

		<!-- Reports Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showComingSoon(t('nav.reports') || 'Reports')}
			>
				<span class="section-icon">📊</span>
				<span class="section-text">{t('nav.reports') || 'Reports'}</span>
			</button>
		</div>

		<!-- Settings Section -->
		<div class="menu-section">
			<button 
				bind:this={settingsButtonElement}
				class="section-button master-button"
				on:mouseenter={handleSettingsMouseEnter}
				on:mouseleave={handleSettingsMouseLeave}
			>
				<span class="section-icon">⚙️</span>
				<span class="section-text">{t('nav.settings') || 'Settings'}</span>
				<span class="arrow">▶</span>
			</button>
		</div>
	</div>

	<!-- Sidebar Footer with PWA Install Button -->
	<div class="sidebar-footer">
		{#if $isInstalled}
			<div class="pwa-installed">
				<span class="pwa-icon">✅</span>
				<span class="pwa-text">App Installed</span>
			</div>
		{:else if $showInstallPrompt}
			<button 
				class="pwa-install-button"
				on:click={handlePWAInstall}
				title="Install Aqura App"
			>
				<span class="pwa-icon">📱</span>
				<span class="pwa-text">Install App</span>
			</button>
		{:else}
			<button 
				class="pwa-install-button pwa-not-supported"
				on:click={handlePWAInstall}
				title="PWA Installation (Browser dependent)"
			>
				<span class="pwa-icon">📱</span>
				<span class="pwa-text">Install App</span>
			</button>
		{/if}
	</div>
</div>

<!-- Master Submenu - positioned outside sidebar to overlay on top -->
{#if showMasterSubmenu}
	<div 
		role="menu"
		tabindex="-1"
		class="submenu"
		style="top: {submenuTop}px;"
		on:mouseenter={handleSubmenuMouseEnter}
		on:mouseleave={handleSubmenuMouseLeave}
	>
		<button class="submenu-item" on:click={openBranches}>
			<span class="menu-icon">🏢</span>
			<span class="menu-text">{t('admin.branchesMaster') || 'Branch Master'}</span>
		</button>
		<button class="submenu-item" on:click={openVendorMaster}>
			<span class="menu-icon">🏪</span>
			<span class="menu-text">Vendor Master</span>
		</button>
		<button class="submenu-item" on:click={openHRMaster}>
			<span class="menu-icon">👥</span>
			<span class="menu-text">HR Master</span>
		</button>
		<button class="submenu-item" on:click={openTaskMaster}>
			<span class="menu-icon">📋</span>
			<span class="menu-text">{t('admin.taskMaster') || 'Task Master'}</span>
		</button>
		<button class="submenu-item" on:click={openCommunicationCenter}>
			<span class="menu-icon">📞</span>
			<span class="menu-text">Communication Center</span>
		</button>
	</div>
{/if}

<!-- Settings Submenu - positioned outside sidebar to overlay on top -->
{#if showSettingsSubmenu}
	<div 
		role="menu"
		tabindex="-1"
		class="submenu"
		style="top: {submenuTop}px;"
		on:mouseenter={handleSettingsSubmenuMouseEnter}
		on:mouseleave={handleSettingsSubmenuMouseLeave}
	>
		<button class="submenu-item" on:click={openUserManagement}>
			<span class="menu-icon">👤</span>
			<span class="menu-text">User Management</span>
		</button>
	</div>
{/if}

<style>
	.sidebar {
		position: fixed;
		left: 0;
		top: 0;
		bottom: 56px; /* Fixed taskbar height */
		width: 140px;
		background: linear-gradient(180deg, #2d3748 0%, #1a202c 100%);
		color: white;
		display: flex;
		flex-direction: column;
		box-shadow: 2px 0 10px rgba(0, 0, 0, 0.3);
		z-index: 1200;
		border-right: 1px solid #4a5568;
	}

	.sidebar-content {
		flex: 1;
		padding: 15px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 15px;
		/* Reserve space for footer */
		padding-bottom: 60px;
	}

	.menu-section {
		display: flex;
		flex-direction: column;
		position: relative;
		margin-bottom: 8px; /* Consistent spacing between sections */
	}

	.section-button {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 10px;
		background: none;
		border: none;
		color: #e2e8f0;
		cursor: pointer;
		border-radius: 8px;
		transition: all 0.2s ease;
		font-size: 12px;
		width: 100%;
		height: 44px; /* Fixed height for all buttons */
		text-align: left;
	}

	.section-button:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
		transform: translateX(2px);
	}

	.section-button:active {
		transform: translateX(2px) scale(0.98);
	}

	.section-icon {
		font-size: 16px;
		flex-shrink: 0;
		width: 20px; /* Fixed width for consistent alignment */
		height: 16px; /* Fixed height */
		text-align: center;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.section-text {
		flex: 1;
		white-space: nowrap;
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
	}

	.arrow {
		font-size: 10px;
		opacity: 0.7;
		transition: transform 0.2s ease;
		flex-shrink: 0;
	}

	.master-button:hover .arrow {
		transform: rotate(90deg);
	}

	.submenu {
		position: fixed;
		left: 140px;
		top: 0;
		min-width: 200px;
		background: linear-gradient(180deg, #374151 0%, #1f2937 100%);
		border: 1px solid #4b5563;
		border-radius: 8px;
		box-shadow: 4px 0 20px rgba(0, 0, 0, 0.4);
		padding: 8px;
		z-index: 9999;
		animation: slideIn 0.2s ease;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateX(-10px);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.submenu-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		background: none;
		border: none;
		color: #e2e8f0;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s ease;
		font-size: 13px;
		width: 100%;
		height: 40px; /* Fixed height for submenu items */
		text-align: left;
		margin-bottom: 2px;
	}

	.submenu-item:hover {
		background: rgba(255, 255, 255, 0.15);
		color: white;
		transform: translateX(2px);
	}

	.submenu-item:last-child {
		margin-bottom: 0;
	}

	.menu-text {
		flex: 1;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* Scrollbar styling */
	.sidebar-content::-webkit-scrollbar {
		width: 6px;
	}

	.sidebar-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.sidebar-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 3px;
	}

	.sidebar-content::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	/* Sidebar Footer */
	.sidebar-footer {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		padding: 10px 15px;
		border-top: 1px solid #4a5568;
		background: rgba(0, 0, 0, 0.3);
		backdrop-filter: blur(10px);
	}

	.pwa-install-button {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
		border: none;
		color: white;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s ease;
		font-size: 11px;
		width: 100%;
		height: 36px;
		text-align: center;
		font-weight: 500;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.pwa-install-button:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
	}

	.pwa-install-button:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.pwa-not-supported {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		opacity: 0.7;
	}

	.pwa-not-supported:hover {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		opacity: 0.8;
	}

	.pwa-installed {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		padding: 8px 12px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		border-radius: 6px;
		color: white;
		font-size: 11px;
		font-weight: 500;
		opacity: 0.8;
	}

	.pwa-icon {
		font-size: 14px;
		flex-shrink: 0;
	}

	.pwa-text {
		font-weight: 500;
		white-space: nowrap;
	}
</style>