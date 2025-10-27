<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { sidebar } from '$lib/stores/sidebar';
	import { t, currentLocale } from '$lib/i18n';
	import { showInstallPrompt, isInstalled, installPWA, initPWAInstall } from '$lib/stores/pwaInstall';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { currentUser } from '$lib/utils/persistentAuth';
	import BranchMaster from '$lib/components/admin/BranchMaster.svelte';
	import TaskMaster from '$lib/components/admin/TaskMaster.svelte';
	import HRMaster from '$lib/components/admin/HRMaster.svelte';
	import OperationsMaster from '$lib/components/admin/OperationsMaster.svelte';
	import VendorMaster from '$lib/components/admin/VendorMaster.svelte';
	import FinanceMaster from '$lib/components/admin/FinanceMaster.svelte';
	import UserManagement from '$lib/components/admin/UserManagement.svelte';
	import CommunicationCenter from '$lib/components/admin/CommunicationCenter.svelte';
	import Settings from '$lib/components/admin/Settings.svelte';
	import StartReceiving from '$lib/components/admin/receiving/StartReceiving.svelte';
	import ScheduledPayments from '$lib/components/admin/vendor/ScheduledPayments.svelte';
	import ApprovalCenter from '$lib/components/admin/finance/ApprovalCenter.svelte';

	let showMasterSubmenu = false;
	let showSettingsSubmenu = false;
	let showWorkSubmenu = false;
	let submenuTimeout: ReturnType<typeof setTimeout> | null = null;
	let masterButtonElement: HTMLButtonElement;
	let settingsButtonElement: HTMLButtonElement;
	let workButtonElement: HTMLButtonElement;
	let submenuTop = 0;
	let workSubmenuTop = 0;
	let hasApprovalPermission = false;
	
	// Version popup state
	let showVersionPopup = false;
	
	// Force reactivity when locale changes
	$: locale = $currentLocale;

	// Initialize PWA install detection
	onMount(async () => {
		initPWAInstall();
		await checkApprovalPermission();
	});

	// Check if current user has approval permissions
	async function checkApprovalPermission() {
		if (!$currentUser?.id) {
			hasApprovalPermission = false;
			return;
		}

		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('users')
				.select('can_approve_payments')
				.eq('id', $currentUser.id)
				.single();

			if (!error && data) {
				hasApprovalPermission = data.can_approve_payments || false;
			}
		} catch (err) {
			console.error('Error checking approval permission:', err);
			hasApprovalPermission = false;
		}
	}

	// Re-check approval permission when user changes
	$: if ($currentUser) {
		checkApprovalPermission();
	}

	// Switch to mobile interface
	function switchToMobileInterface() {
		if ($currentUser) {
			// Set mobile preference for this user
			interfacePreferenceService.forceMobileInterface($currentUser.id);
			console.log('🔄 Switching to mobile interface for user:', $currentUser.id);
			// Navigate to mobile interface
			goto('/mobile');
		}
	}

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
		
		openWindow({
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
		
		openWindow({
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
		
		openWindow({
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

	function openOperationsMaster() {
		const windowId = generateWindowId('operations-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Operations Master #${instanceNumber}`,
			component: OperationsMaster,
			icon: '⚙️',
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
		
		openWindow({
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

	function openFinanceMaster() {
		const windowId = generateWindowId('finance-master');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Finance Master #${instanceNumber}`,
			component: FinanceMaster,
			icon: '💰',
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

	function openApprovalCenter() {
		const windowId = generateWindowId('approval-center');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Approval Center #${instanceNumber}`,
			component: ApprovalCenter,
			icon: '✅',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function showComingSoon(section: string) {
		// You can implement a toast notification or modal here
		alert(`${section} - ${t('status.pending') || 'pending'}...`);
	}

	function openUserManagement() {
		const windowId = generateWindowId('user-management');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
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

	function openSettings() {
		const windowId = generateWindowId('settings');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Sound Settings #${instanceNumber}`,
			component: Settings,
			icon: '🔊',
			size: { width: 1000, height: 700 },
			position: { 
				x: 100 + (Math.random() * 100), 
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
		
		openWindow({
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

	// Work submenu functions
	function handleWorkMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
		// Calculate the position of the submenu
		if (workButtonElement) {
			const rect = workButtonElement.getBoundingClientRect();
			workSubmenuTop = rect.top;
		}
		showWorkSubmenu = true;
	}

	function handleWorkMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showWorkSubmenu = false;
		}, 300);
	}

	function handleWorkSubmenuMouseEnter() {
		if (submenuTimeout) {
			clearTimeout(submenuTimeout);
			submenuTimeout = null;
		}
	}

	function handleWorkSubmenuMouseLeave() {
		submenuTimeout = setTimeout(() => {
			showWorkSubmenu = false;
		}, 300);
	}

	// Open Start Receiving window
	function openStartReceiving() {
		const windowId = generateWindowId('start-receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Start Receiving #${instanceNumber}`,
			component: StartReceiving,
			icon: '📦',
			size: { width: 1200, height: 800 },
			position: { 
				x: 100 + (Math.random() * 100),
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Open Scheduled Payments window
	function openScheduledPayments() {
		const windowId = generateWindowId('scheduled-payments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Scheduled Payments #${instanceNumber}`,
			component: ScheduledPayments,
			icon: '💰',
			size: { width: 1400, height: 900 },
			position: { 
				x: 120 + (Math.random() * 100),
				y: 120 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
		});
	}

	// Show version popup with update information
	function showVersionInfo() {
		showVersionPopup = true;
	}

	// Close version popup
	function closeVersionPopup() {
		showVersionPopup = false;
	}
</script>

<div class="sidebar">
	<div class="sidebar-content">
		<!-- Interface Switch Header -->
		<div class="sidebar-header">
			<button 
				class="interface-switch-btn"
				on:click={switchToMobileInterface}
				title="Switch to Mobile Interface"
			>
				Mobile
			</button>
		</div>

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
				bind:this={workButtonElement}
				on:mouseenter={handleWorkMouseEnter}
				on:mouseleave={handleWorkMouseLeave}
			>
				<span class="section-icon">💼</span>
				<span class="section-text">{t('nav.work') || 'Work'}</span>
				<span class="submenu-arrow">▶</span>
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


	<!-- Approval Center Section (Visible to all users) -->
	<div class="menu-section">
		<button 
			class="section-button approval-button"
			on:click={openApprovalCenter}
		>
			<span class="section-icon">✅</span>
			<span class="section-text">Approvals</span>
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
		
		<!-- Version Information -->
		<div class="version-info">
			<button class="version-text" on:click={showVersionInfo} title="Click to see what's new">
				v1.4.0
			</button>
		</div>
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
		<button class="submenu-item" on:click={openFinanceMaster}>
			<span class="menu-icon">💰</span>
			<span class="menu-text">Finance Master</span>
		</button>
		<button class="submenu-item" on:click={openHRMaster}>
			<span class="menu-icon">👥</span>
			<span class="menu-text">HR Master</span>
		</button>
		<button class="submenu-item" on:click={openOperationsMaster}>
			<span class="menu-icon">⚙️</span>
			<span class="menu-text">Operations Master</span>
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
		<button class="submenu-item" on:click={openSettings}>
			<span class="menu-icon">🔊</span>
			<span class="menu-text">Sound Settings</span>
		</button>
		<button class="submenu-item" on:click={openUserManagement}>
			<span class="menu-icon">👤</span>
			<span class="menu-text">User Management</span>
		</button>
	</div>
{/if}

<!-- Work Submenu - positioned outside sidebar to overlay on top -->
{#if showWorkSubmenu}
	<div 
		role="menu"
		tabindex="-1"
		class="submenu"
		style="top: {workSubmenuTop}px;"
		on:mouseenter={handleWorkSubmenuMouseEnter}
		on:mouseleave={handleWorkSubmenuMouseLeave}
	>
		<button class="submenu-item" on:click={openStartReceiving}>
			<span class="menu-icon">📦</span>
			<span class="menu-text">Start Receiving</span>
		</button>
		<button class="submenu-item" on:click={openScheduledPayments}>
			<span class="menu-icon">💰</span>
			<span class="menu-text">Scheduled Payments</span>
		</button>
	</div>
{/if}

<!-- Version Information Popup -->
{#if showVersionPopup}
	<div class="version-popup-overlay" on:click={closeVersionPopup}>
		<div class="version-popup" on:click|stopPropagation>
			<div class="version-popup-header">
				<h3>What's New in v1.4.0</h3>
				<button class="close-btn" on:click={closeVersionPopup}>×</button>
			</div>
			<div class="version-popup-content">
				<div class="update-section">
					<h4>💰 Bill Scheduling System</h4>
					<ul>
						<li><strong>Single Bill Scheduling:</strong> Complete 3-step wizard for scheduling individual bill payments with branch, category, and request linking</li>
						<li><strong>Multiple Bill Scheduling:</strong> New feature to schedule multiple bills at once with dynamic template generation and live total tracking</li>
						<li><strong>Request Balance Tracking:</strong> Real-time balance calculation showing remaining budget when linked to expense requisitions</li>
						<li><strong>Payment Method Sync:</strong> 12 payment methods synchronized with Request Generator (advance cash/bank, credit options, stock purchase)</li>
						<li><strong>Auto-calculated Due Dates:</strong> Automatic due date calculation based on payment method and credit period (0 or 30 days)</li>
						<li><strong>50MB File Upload:</strong> Updated storage limit from 10MB to 50MB for bill attachments (images and PDFs)</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>� Multiple Bill Features</h4>
					<ul>
						<li><strong>Dynamic Bill Templates:</strong> Generate 1-50 bill templates based on user input with visual card grid display</li>
						<li><strong>Individual Bill Editor:</strong> Click-to-edit modal for each bill with complete Step 3 fields and validation</li>
						<li><strong>Separate Saving:</strong> Each bill saves independently with success confirmation and saved status badge</li>
						<li><strong>Live Total Summary:</strong> Real-time calculation of total amount across all bills with color-coded balance indicators</li>
						<li><strong>Bill Status Tracking:</strong> Visual indicators for saved vs unsaved bills with saved bill detail previews</li>
						<li><strong>Sequential Workflow:</strong> After saving, view details and select next bill for editing with smooth navigation</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>📦 Receiving Records Enhancement</h4>
					<ul>
						<li><strong>PR Excel Verification:</strong> Added checkbox feature for marking PR Excel as verified in vendor payment schedule</li>
						<li><strong>Custom Download Filenames:</strong> PR Excel downloads now use format "VendorName_DD-MM-YYYY_Amount_SAR.xlsx"</li>
						<li><strong>Verification Tracking:</strong> Tracks who verified PR Excel and when with timestamp display</li>
						<li><strong>Enhanced RLS Policies:</strong> Added missing policies for vendor_payment_schedule table operations</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>� Database & Technical Updates</h4>
					<ul>
						<li><strong>Expense Scheduler Table:</strong> New table with complete tracking for bill type, payment method, due dates, and bank details</li>
						<li><strong>Storage Bucket Creation:</strong> Created expense-scheduler-bills bucket with 50MB limit and multi-format support</li>
						<li><strong>Foreign Key Fixes:</strong> Corrected all FK constraints to point to public.users instead of auth.users</li>
						<li><strong>Missing Column Migrations:</strong> Added ALTER TABLE migrations for credit_period, bank_name, and iban fields</li>
						<li><strong>8 New Migrations:</strong> Complete migration set (050-058) for bill scheduling and PR Excel verification features</li>
					</ul>
				</div>
				<div class="version-info-footer">
					<p><strong>Release Date:</strong> October 27, 2025</p>
					<p><strong>Build:</strong> Production Ready</p>
					<p><strong>Version:</strong> 1.4.0 - Bill Scheduling System & Receiving Enhancements</p>
					<p><strong>Focus:</strong> Single & Multiple Bill Scheduling, PR Excel Verification, Storage Optimization</p>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.sidebar-header {
		padding: 0.75rem;
		margin-bottom: 0.5rem;
	}

	.interface-switch-btn {
		width: 100%;
		padding: 0.5rem 1rem;
		background: linear-gradient(145deg, #3b82f6, #2563eb);
		border: none;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		box-shadow: 
			0 2px 4px rgba(59, 130, 246, 0.3),
			inset 0 1px 0 rgba(255, 255, 255, 0.2),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
		text-shadow: 0 1px 1px rgba(0, 0, 0, 0.3);
	}

	.interface-switch-btn:hover {
		background: linear-gradient(145deg, #2563eb, #1d4ed8);
		transform: translateY(-1px);
		box-shadow: 
			0 3px 6px rgba(59, 130, 246, 0.4),
			inset 0 1px 0 rgba(255, 255, 255, 0.2),
			inset 0 -1px 0 rgba(0, 0, 0, 0.1);
	}

	.interface-switch-btn:active {
		transform: translateY(1px);
		box-shadow: 
			0 1px 2px rgba(59, 130, 246, 0.3),
			inset 0 1px 3px rgba(0, 0, 0, 0.2);
	}

	.interface-switch-btn:active {
		transform: translateY(1px);
		box-shadow: 
			0 1px 2px rgba(59, 130, 246, 0.3),
			inset 0 1px 3px rgba(0, 0, 0, 0.2);
	}

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

	/* Special styling for Approval Center button */
	.approval-button {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.3);
	}

	.approval-button:hover {
		background: rgba(16, 185, 129, 0.2);
		border-color: rgba(16, 185, 129, 0.5);
		color: #10B981;
	}

	.approval-button .section-icon {
		filter: drop-shadow(0 0 4px rgba(16, 185, 129, 0.5));
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

	/* Version Information */
	.version-info {
		margin-top: 8px;
		text-align: center;
		border-top: 1px solid rgba(74, 85, 104, 0.5);
		padding-top: 6px;
	}

	.version-text {
		background: linear-gradient(135deg, #4f46e5 0%, #3b82f6 100%);
		border: 1px solid rgba(255, 255, 255, 0.2);
		color: white;
		font-size: 11px;
		font-weight: 600;
		font-family: monospace;
		letter-spacing: 0.5px;
		cursor: pointer;
		padding: 6px 12px;
		border-radius: 6px;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
		text-transform: uppercase;
		width: 100%;
		text-align: center;
	}

	.version-text:hover {
		background: linear-gradient(135deg, #5b21b6 0%, #7c3aed 100%);
		border-color: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
	}

	.version-text:active {
		transform: translateY(0);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	/* Version Popup Styles */
	.version-popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		backdrop-filter: blur(4px);
	}

	.version-popup {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
		animation: popupSlideIn 0.3s ease;
	}

	@keyframes popupSlideIn {
		from {
			opacity: 0;
			transform: scale(0.9) translateY(-20px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	.version-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.version-popup-header h3 {
		margin: 0;
		color: #1f2937;
		font-size: 20px;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: all 0.2s ease;
		line-height: 1;
	}

	.close-btn:hover {
		color: #ef4444;
		background: rgba(239, 68, 68, 0.1);
	}

	.version-popup-content {
		padding: 20px 24px;
	}

	.update-section {
		margin-bottom: 24px;
	}

	.update-section:last-of-type {
		margin-bottom: 16px;
	}

	.update-section h4 {
		margin: 0 0 12px 0;
		color: #374151;
		font-size: 16px;
		font-weight: 600;
	}

	.update-section ul {
		margin: 0;
		padding-left: 20px;
		color: #4b5563;
		line-height: 1.6;
	}

	.update-section li {
		margin-bottom: 8px;
	}

	.update-section li strong {
		color: #1f2937;
		font-weight: 600;
	}

	.version-info-footer {
		border-top: 1px solid #e5e7eb;
		padding-top: 16px;
		margin-top: 16px;
	}

	.version-info-footer p {
		margin: 4px 0;
		color: #6b7280;
		font-size: 14px;
	}

	.version-info-footer strong {
		color: #374151;
		font-weight: 600;
	}
</style>