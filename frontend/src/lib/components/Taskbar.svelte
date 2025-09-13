<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { onMount } from 'svelte';
	import HRMaster from '$lib/components/admin/HRMaster.svelte';
	import BranchMaster from '$lib/components/admin/BranchMaster.svelte';
	import VendorMaster from '$lib/components/admin/VendorMaster.svelte';

	// Subscribe to taskbar items
	$: taskbarItems = windowManager.taskbarItems;
	$: activeWindow = windowManager.activeWindow;

	// Start menu state
	let showStartMenuDropdown = false;

	// Show current time
	let currentTime = '';
	let timeInterval: NodeJS.Timeout;

	onMount(() => {
		updateTime();
		timeInterval = setInterval(updateTime, 1000);
		
		// Add click outside listener
		document.addEventListener('click', handleClickOutside);
		
		return () => {
			if (timeInterval) clearInterval(timeInterval);
			document.removeEventListener('click', handleClickOutside);
		};
	});

	function updateTime() {
		const now = new Date();
		currentTime = now.toLocaleTimeString([], { 
			hour: '2-digit', 
			minute: '2-digit',
			hour12: false 
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

	function showStartMenu() {
		showStartMenuDropdown = !showStartMenuDropdown;
	}

	function closeStartMenu() {
		showStartMenuDropdown = false;
	}

	function openHR() {
		windowManager.openWindow({
			id: 'hr-master',
			title: 'HR Master',
			component: HRMaster,
			size: { width: 1200, height: 800 },
			icon: '👥',
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		closeStartMenu();
	}

	function openBranches() {
		windowManager.openWindow({
			id: 'branch-master',
			title: 'Branch Master',
			component: BranchMaster,
			icon: '🏢',
			size: { width: 1200, height: 800 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		closeStartMenu();
	}

	function openVendors() {
		windowManager.openWindow({
			id: 'vendor-master',
			title: 'Vendor Master',
			component: VendorMaster,
			icon: '🤝',
			size: { width: 1200, height: 800 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
		closeStartMenu();
	}

	function showDesktop() {
		windowManager.minimizeAllWindows();
		closeStartMenu();
	}

	// Close start menu when clicking outside
	function handleClickOutside(event: MouseEvent) {
		if (showStartMenuDropdown && !(event.target as Element)?.closest('.start-menu-container')) {
			closeStartMenu();
		}
	}
</script>

<div class="taskbar">
	<!-- Start Menu Container -->
	<div class="start-menu-container">
		<!-- Start Button -->
		<button 
			class="start-button" 
			class:active={showStartMenuDropdown}
			on:click={showStartMenu} 
			title="Start Menu"
		>
			<div class="aqura-logo">
				<svg viewBox="0 0 24 24" width="20" height="20">
					<circle cx="12" cy="12" r="10" fill="#f08300" />
					<text x="12" y="16" text-anchor="middle" fill="white" font-size="12" font-weight="bold">A</text>
				</svg>
			</div>
			<span>Aqura</span>
		</button>

		<!-- Start Menu Dropdown -->
		{#if showStartMenuDropdown}
			<div 
				class="start-menu" 
				role="menu" 
				tabindex="0"
				on:click|stopPropagation
				on:keydown={(e) => e.key === 'Escape' && closeStartMenu()}
			>
				<div class="start-menu-header">
					<div class="user-info">
						<div class="user-avatar">
							<span>U</span>
						</div>
						<div class="user-details">
							<div class="user-name">User</div>
							<div class="user-role">Administrator</div>
						</div>
					</div>
				</div>

				<div class="start-menu-content">
					<div class="menu-section">
						<h3 class="section-title">Applications</h3>
						<div class="menu-items">
							<button class="menu-item" on:click={openHR}>
								<span class="menu-icon">👥</span>
								<span class="menu-text">HR Master</span>
							</button>
							<button class="menu-item" on:click={openBranches}>
								<span class="menu-icon">🏢</span>
								<span class="menu-text">Branches</span>
							</button>
							<button class="menu-item" on:click={openVendors}>
								<span class="menu-icon">🤝</span>
								<span class="menu-text">Vendors</span>
							</button>
						</div>
					</div>

					<div class="menu-section">
						<h3 class="section-title">System</h3>
						<div class="menu-items">
							<button class="menu-item" on:click={showDesktop}>
								<span class="menu-icon">🖥️</span>
								<span class="menu-text">Show Desktop</span>
							</button>
							<button class="menu-item" on:click={() => alert('Settings not implemented yet')}>
								<span class="menu-icon">⚙️</span>
								<span class="menu-text">Settings</span>
							</button>
						</div>
					</div>
				</div>

				<div class="start-menu-footer">
					<div class="footer-branding">
						<span class="brand-name">Aqura</span>
						<span class="brand-version">v1.0</span>
					</div>
					<button class="logout-button" on:click={() => alert('Logout functionality not implemented yet')}>
						<span class="logout-icon">🚪</span>
						<span>Logout</span>
					</button>
				</div>
			</div>
		{/if}
	</div>

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
			class="tray-button" 
			on:click={showDesktop} 
			title="Show Desktop"
			aria-label="Show desktop"
		>
			<svg viewBox="0 0 16 16" width="16" height="16">
				<rect x="2" y="3" width="12" height="9" stroke="currentColor" stroke-width="1" fill="none" />
				<rect x="4" y="5" width="8" height="1" fill="currentColor" />
			</svg>
		</button>

		<!-- Clock -->
		<div class="clock" title={new Date().toLocaleDateString()}>
			{currentTime}
		</div>
	</div>
</div>

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

	.start-button {
		display: flex;
		align-items: center;
		gap: 10px;
		background: linear-gradient(135deg, #F59E0B 0%, #FBBF24 100%);
		color: #0B1220;
		border: none;
		border-radius: 6px;
		padding: 10px 32px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s ease;
		flex-shrink: 0;
		min-width: 160px;
	}

	.start-button:hover {
		background: linear-gradient(135deg, #D97706 0%, #F59E0B 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
	}

	.start-button:active {
		transform: translateY(0);
	}

	.aqura-logo {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 20px;
		height: 20px;
	}

	.start-logo-image {
		width: 100%;
		height: 100%;
		object-fit: contain;
		border-radius: 3px;
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
		padding: 6px 12px;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 120px;
		max-width: 200px;
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

	.clock {
		background: rgba(255, 255, 255, 0.95);
		color: #0B1220;
		padding: 6px 12px;
		border-radius: 4px;
		font-family: 'Segoe UI', monospace;
		font-size: 13px;
		font-weight: 500;
		min-width: 60px;
		text-align: center;
		border: 1px solid rgba(229, 231, 235, 0.5);
	}

	/* Start Menu Container */
	.start-menu-container {
		position: relative;
		display: flex;
		align-items: center;
	}

	.start-button.active {
		background: linear-gradient(135deg, #d97706 0%, #ca6a04 100%);
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	/* Start Menu Dropdown */
	.start-menu {
		position: absolute;
		bottom: 100%;
		left: 0;
		width: 320px;
		max-height: calc(100vh - 68px);
		background: #FFFFFF;
		border: 2px solid #4F46E5;
		border-radius: 12px 12px 0 0;
		box-shadow: 0 -8px 32px rgba(11, 18, 32, 0.4);
		z-index: 1001;
		overflow: hidden;
		backdrop-filter: blur(20px);
		animation: slideUp 0.2s ease-out;
		display: flex;
		flex-direction: column;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.start-menu-header {
		padding: 20px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-bottom: 1px solid rgba(245, 158, 11, 0.2);
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.user-avatar {
		width: 44px;
		height: 44px;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: bold;
		font-size: 18px;
		border: 2px solid rgba(255, 255, 255, 0.3);
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		color: white;
		font-weight: bold;
		font-size: 16px;
		margin-bottom: 2px;
	}

	.user-role {
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
	}

	.start-menu-content {
		padding: 12px 0;
		flex: 1;
		overflow-y: auto;
		background: #FFFFFF;
	}

	.menu-section {
		margin-bottom: 8px;
	}

	.section-title {
		padding: 8px 20px 6px;
		color: #374151;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		margin: 0;
		background: #F3F4F6;
		border-bottom: 1px solid #E5E7EB;
	}

	.menu-items {
		display: flex;
		flex-direction: column;
	}

	.menu-item {
		display: flex;
		align-items: center;
		gap: 14px;
		padding: 12px 20px;
		background: none;
		border: none;
		color: #1F2937;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: left;
		width: 100%;
		border-radius: 0;
		font-weight: 500;
	}

	.menu-item:hover {
		background: rgba(79, 70, 229, 0.08);
		color: #4F46E5;
	}

	.menu-icon {
		font-size: 18px;
		width: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		opacity: 0.9;
	}

	.menu-text {
		font-size: 14px;
		flex: 1;
		font-weight: 500;
		color: inherit;
	}

	.start-menu-footer {
		padding: 12px 20px;
		border-top: 1px solid #D1D5DB;
		background: #F3F4F6;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.footer-branding {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 4px 0;
	}

	.brand-name {
		font-weight: 700;
		font-size: 12px;
		color: #15A34A;
		letter-spacing: 0.5px;
	}

	.brand-version {
		font-size: 10px;
		color: #6B7280;
		font-weight: 500;
	}

	.logout-button {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 16px;
		background: #FFFFFF;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s ease;
		width: 100%;
		justify-content: center;
		font-weight: 600;
	}

	.logout-button:hover {
		background: #FEE2E2;
		border-color: #F87171;
		color: #DC2626;
	}

	.logout-icon {
		font-size: 16px;
	}

	/* Scrollbar styling for start menu */
	.start-menu-content::-webkit-scrollbar {
		width: 6px;
	}

	.start-menu-content::-webkit-scrollbar-track {
		background: rgba(255, 255, 255, 0.05);
	}

	.start-menu-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 3px;
	}

	.start-menu-content::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.3);
	}

	/* Responsive design */
	@media (max-width: 768px) {
		.taskbar {
			height: 44px;
			padding: 0 4px;
			gap: 4px;
		}

		.start-button {
			padding: 6px 12px;
			font-size: 13px;
		}

		.task-button {
			min-width: 100px;
			max-width: 150px;
			padding: 4px 8px;
		}

		.clock {
			padding: 4px 8px;
			font-size: 12px;
		}

		.start-menu {
			width: 280px;
			max-height: 400px;
		}

		.start-menu-header {
			padding: 16px;
		}

		.user-avatar {
			width: 36px;
			height: 36px;
			font-size: 16px;
		}

		.menu-item {
			padding: 10px 16px;
		}
	}
</style>
