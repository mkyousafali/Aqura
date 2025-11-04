<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { sidebar } from '$lib/stores/sidebar';
	import { currentLocale, t } from '$lib/i18n';
	import {
		showInstallPrompt,
		isInstalled,
		initPWAInstall,
		installPWA
	} from '$lib/stores/pwaInstall';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { approvalCounts } from '$lib/stores/approvalCounts';
	
	// Component imports
	import BranchMaster from '$lib/components/admin/BranchMaster.svelte';
	import TaskMaster from '$lib/components/admin/TaskMaster.svelte';
	import HRMaster from '$lib/components/admin/HRMaster.svelte';
	import OperationsMaster from '$lib/components/admin/OperationsMaster.svelte';
	import VendorMaster from '$lib/components/admin/VendorMaster.svelte';
	import FinanceMaster from '$lib/components/admin/FinanceMaster.svelte';
	import ApprovalCenter from '$lib/components/admin/finance/ApprovalCenter.svelte';
	import UserManagement from '$lib/components/admin/UserManagement.svelte';
	import Settings from '$lib/components/admin/Settings.svelte';
	import ApprovalPermissionsManager from '$lib/components/admin/ApprovalPermissionsManager.svelte';
	import CommunicationCenter from '$lib/components/admin/CommunicationCenter.svelte';
	import StartReceiving from '$lib/components/admin/receiving/StartReceiving.svelte';
	import ScheduledPayments from '$lib/components/admin/vendor/ScheduledPayments.svelte';
	import ExpensesManager from '$lib/components/admin/finance/ExpensesManager.svelte';

	let showSettingsSubmenu = false;
	let showMasterSubmenu = false;
	let showWorkSubmenu = false;
	let hasApprovalPermission = false;
	
	// Get pending approvals count from store
	$: pendingApprovalsCount = $approvalCounts.pending;
	
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
				.from('approval_permissions')
				.select('*')
				.eq('user_id', $currentUser.id)
				.eq('is_active', true)
				.maybeSingle(); // Use maybeSingle to handle cases where user has no approval permissions

			if (!error && data) {
				// User has approval permission if ANY permission type is enabled
				hasApprovalPermission = 
					data.can_approve_requisitions ||
					data.can_approve_single_bill ||
					data.can_approve_multiple_bill ||
					data.can_approve_recurring_bill ||
					data.can_approve_vendor_payments ||
					data.can_approve_leave_requests;
			} else {
				hasApprovalPermission = false;
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

	function openApprovalPermissions() {
		const windowId = generateWindowId('approval-permissions');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Approval Permissions #${instanceNumber}`,
			component: ApprovalPermissionsManager,
			icon: '🔐',
			size: { width: 950, height: 750 },
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
		
		let scheduledPaymentsRefreshFunction = null;
		
		openWindow({
			id: windowId,
			title: `Scheduled Payments #${instanceNumber}`,
			component: ScheduledPayments,
			props: {
				setRefreshCallback: (fn) => {
					console.log('📝 [Sidebar] Refresh function registered from ScheduledPayments');
					scheduledPaymentsRefreshFunction = fn;
				},
				onRefresh: async () => {
					console.log('🔄 [Sidebar] onRefresh called from window');
					console.log('🔍 [Sidebar] scheduledPaymentsRefreshFunction:', scheduledPaymentsRefreshFunction);
					if (scheduledPaymentsRefreshFunction) {
						console.log('✅ [Sidebar] Calling ScheduledPayments refresh function');
						return await scheduledPaymentsRefreshFunction();
					} else {
						console.log('❌ [Sidebar] No refresh function available');
					}
				}
			},
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

	// Open Expense Manager window
	function openExpenseManager() {
		const windowId = generateWindowId('expense-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Expenses Manager #${instanceNumber}`,
			component: ExpensesManager,
			icon: '�',
			size: { width: 1400, height: 900 },
			position: { 
				x: 140 + (Math.random() * 100),
				y: 140 + (Math.random() * 100) 
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
				class="section-button"
				on:click={() => showMasterSubmenu = !showMasterSubmenu}
			>
				<span class="section-icon">📁</span>
				<span class="section-text">{t('nav.master') || 'Master'}</span>
				<span class="arrow" class:expanded={showMasterSubmenu}>▼</span>
			</button>
		</div>

		<!-- Master Submenu - Inline below Master button -->
		{#if showMasterSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openBranches}>
						<span class="menu-icon">🏢</span>
						<span class="menu-text">{t('admin.branchesMaster') || 'Branch Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openVendorMaster}>
						<span class="menu-icon">🏪</span>
						<span class="menu-text">Vendor Master</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openFinanceMaster}>
						<span class="menu-icon">💰</span>
						<span class="menu-text">Finance Master</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openHRMaster}>
						<span class="menu-icon">👥</span>
						<span class="menu-text">HR Master</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openOperationsMaster}>
						<span class="menu-icon">⚙️</span>
						<span class="menu-text">Operations Master</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openTaskMaster}>
						<span class="menu-icon">✅</span>
						<span class="menu-text">{t('admin.taskMaster') || 'Task Master'}</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openCommunicationCenter}>
						<span class="menu-icon">📞</span>
						<span class="menu-text">Com Center</span>
					</button>
				</div>
			</div>
		{/if}

		<!-- Work Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showWorkSubmenu = !showWorkSubmenu}
			>
				<span class="section-icon">💼</span>
				<span class="section-text">{t('nav.work') || 'Work'}</span>
				<span class="arrow" class:expanded={showWorkSubmenu}>▼</span>
			</button>
		</div>

		<!-- Work Submenu - Inline below Work button -->
		{#if showWorkSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openStartReceiving}>
						<span class="menu-icon">📦</span>
						<span class="menu-text">Start Receiving</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openScheduledPayments}>
						<span class="menu-icon">💰</span>
						<span class="menu-text">Scheduled Payments</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openExpenseManager}>
						<span class="menu-icon">💸</span>
						<span class="menu-text">Expense Manager</span>
					</button>
				</div>
			</div>
		{/if}

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
			{#if pendingApprovalsCount > 0}
				<span class="approval-badge">{pendingApprovalsCount}</span>
			{/if}
		</button>
	</div>
		<!-- Settings Section -->
		<div class="menu-section">
			<button 
				class="section-button"
				on:click={() => showSettingsSubmenu = !showSettingsSubmenu}
			>
				<span class="section-icon">⚙️</span>
				<span class="section-text">{t('nav.settings') || 'Settings'}</span>
				<span class="arrow" class:expanded={showSettingsSubmenu}>▼</span>
			</button>
		</div>

		<!-- Settings Submenu - Inline below Settings button -->
		{#if showSettingsSubmenu}
			<div class="submenu-inline">
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openSettings}>
						<span class="menu-icon">🔊</span>
						<span class="menu-text">Sound Settings</span>
					</button>
				</div>
				<div class="submenu-item-container">
					<button class="submenu-item" on:click={openUserManagement}>
						<span class="menu-icon">👤</span>
						<span class="menu-text">Users</span>
					</button>
				</div>
				{#if $currentUser?.roleType === 'Master Admin'}
					<div class="submenu-item-container">
						<button class="submenu-item" on:click={openApprovalPermissions}>
							<span class="menu-icon">🔐</span>
							<span class="menu-text">Approval Permissions</span>
						</button>
					</div>
				{/if}
			</div>
		{/if}
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
				v4.0.1
			</button>
		</div>
	</div>
</div>

<!-- Version Information Popup -->
{#if showVersionPopup}
	<div class="version-popup-overlay" on:click={closeVersionPopup}>
		<div class="version-popup" on:click|stopPropagation>
			<div class="version-popup-header">
				<h3>What's New in v4.0.1</h3>
				<button class="close-btn" on:click={closeVersionPopup}>×</button>
			</div>
			<div class="version-popup-content">
				<div class="update-section">
					<h4>🔐 Granular Approval Permissions System</h4>
					<ul>
						<li><strong>New Approval Permissions Table:</strong> Replaced single boolean with 6 permission types (Requisitions, Single Bill, Multiple Bill, Recurring Bill, Vendor Payments, Leave Requests)</li>
						<li><strong>Amount Limits per Type:</strong> Each permission type has its own approval amount limit (0 = unlimited)</li>
						<li><strong>ApprovalPermissionsManager:</strong> New Master Admin-only component for managing granular permissions</li>
						<li><strong>Auto-Hide Logic:</strong> Approvers automatically hidden from dropdown when bill amount exceeds their limit</li>
						<li><strong>Real-time Notifications:</strong> Users notified when their approval permissions are updated</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>� User Management Enhancements</h4>
					<ul>
						<li><strong>Position Column Added:</strong> Shows employee position title from hr_positions table</li>
						<li><strong>Approval UI Removed:</strong> Approval permissions now managed in dedicated component</li>
						<li><strong>Clean Interface:</strong> Removed 464 lines of approval-related code from User Management</li>
						<li><strong>Database View Integration:</strong> Uses user_management_view for efficient data retrieval</li>
						<li><strong>Position Relationship:</strong> Links users → hr_employees → hr_position_assignments → hr_positions</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>💰 Payment Scheduling Updates</h4>
					<ul>
						<li><strong>RequestGenerator:</strong> Updated to query can_approve_requisitions permission</li>
						<li><strong>SingleBillScheduling:</strong> Uses can_approve_single_bill with approval limit column</li>
						<li><strong>MultipleBillScheduling:</strong> Amount field moved above approver selection, auto-hide for over-limit approvers</li>
						<li><strong>RecurringExpenseScheduler:</strong> Step 2 removed (now 2 steps instead of 3), uses can_approve_recurring_bill</li>
						<li><strong>Employee ID Display:</strong> Fixed to show actual employee_id from hr_employees (not UUID)</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>📱 Mobile Interface Updates</h4>
					<ul>
						<li><strong>Approval Badge:</strong> Mobile layout updated to check all 6 permission types</li>
						<li><strong>Approval Center:</strong> Mobile approval center queries approval_permissions table</li>
						<li><strong>Permission Indicators:</strong> Shows if user has ANY approval permission enabled</li>
						<li><strong>Consistent Logic:</strong> Same permission checks across desktop and mobile</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>🗄️ Database Migrations</h4>
					<ul>
						<li><strong>approval_permissions.sql:</strong> Created table with 11 columns (6 permissions + 5 amount limits)</li>
						<li><strong>migrate_approval_permissions_data.sql:</strong> Migrated existing users.can_approve_payments to new table</li>
						<li><strong>fix_approval_permissions_rls.sql:</strong> RLS policies updated for custom authentication</li>
						<li><strong>remove_old_approval_columns.sql:</strong> Dropped can_approve_payments and approval_amount_limit from users table</li>
					</ul>
				</div>
				<div class="update-section">
					<h4>🎨 Code Quality Improvements</h4>
					<ul>
						<li><strong>Net Code Reduction:</strong> 743 deletions vs 346 insertions (-397 lines total)</li>
						<li><strong>Separation of Concerns:</strong> User Management focuses on users, ApprovalPermissionsManager handles approvals</li>
						<li><strong>Consistent Patterns:</strong> All scheduling forms use same approval permission query pattern</li>
						<li><strong>Type Safety:</strong> Updated TypeScript interfaces with position_title field</li>
					</ul>
				</div>
				<div class="version-info-footer">
					<p><strong>Release Date:</strong> November 3, 2025</p>
					<p><strong>Build:</strong> Production Ready</p>
					<p><strong>Version:</strong> 4.0.0 - Granular Approval Permissions & User Management Overhaul</p>
					<p><strong>Focus:</strong> Approval System Redesign, User Position Display, Permission Management, Database Optimization</p>
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

	.arrow.expanded {
		transform: rotate(180deg);
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

	/* Inline submenu below Work button */
	.submenu-inline {
		padding: 8px 0 8px 4px;
		margin-bottom: 8px;
		background: transparent; /* Changed from rgba(0, 0, 0, 0.2) to transparent */
		border-radius: 8px;
		animation: slideDown 0.2s ease;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			max-height: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			max-height: 200px;
			transform: translateY(0);
		}
	}

	/* Individual container for each submenu button */
	.submenu-item-container {
		background: rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		margin-bottom: 6px;
		padding: 2px;
		border: 1px solid rgba(255, 255, 255, 0.1);
	}

	.submenu-item-container:last-child {
		margin-bottom: 0;
	}

	.submenu-item-container:hover {
		background: rgba(255, 255, 255, 0.1);
		border-color: rgba(255, 255, 255, 0.2);
	}

	.submenu-inline .submenu-item {
		font-size: 12px;
		padding: 8px 8px 8px 6px; /* Reduced left padding from 10px to 6px */
		height: auto; /* Changed from 36px to auto to allow wrapping */
		min-height: 36px; /* Minimum height */
		width: 100%;
		background: transparent;
	}

	.submenu-inline .submenu-item:hover {
		background: transparent;
		transform: none;
	}

	.menu-icon {
		font-size: 14px;
		flex-shrink: 0;
		width: 18px;
		text-align: center;
		align-self: flex-start; /* Align icon to top when text wraps */
		margin-top: 2px;
	}

	.menu-text {
		flex: 1;
		white-space: normal; /* Changed from nowrap to normal to allow wrapping */
		overflow: visible;
		text-overflow: clip;
		font-weight: 500;
		word-wrap: break-word;
		line-height: 1.3;
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



