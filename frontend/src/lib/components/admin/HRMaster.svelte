<script>
		import ContactManagement from './hr/ContactManagement.svelte';
	import DocumentManagement from './hr/DocumentManagement.svelte';
	import SalaryManagement from './hr/SalaryManagement.svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
import { t, currentLocale } from '$lib/i18n';
import { get } from 'svelte/store';
import { onDestroy } from 'svelte';
	
	// Import window components (will create these)
	import UploadEmployees from './hr/UploadEmployees.svelte';
	import CreateDepartment from './hr/CreateDepartment.svelte';
	import CreateLevel from './hr/CreateLevel.svelte';
	import CreatePosition from './hr/CreatePosition.svelte';
	import ReportingMap from './hr/ReportingMap.svelte';
	import AssignPositions from './hr/AssignPositions.svelte';
	import BiometricData from './hr/BiometricData.svelte';
	import WarningMaster from './warnings/WarningMaster.svelte';

	// Track opened windows to update their titles when language changes
	let hrMasterWindowId = null; // Track the HR Master window itself
	let openedWindowIds = [];
	let locale = ''; // Track locale for reactivity

	// Subscribe to window list to track HR Master windows
	let windows = [];
	const unsubscribe = windowManager.windowList.subscribe(w => {
		windows = w;
		console.log('📋 HR Master - windows updated from store:', w.length, 'windows');
		
		// If we haven't found our own window ID yet, look for an HR Master window
		if (!hrMasterWindowId && w.length > 0) {
			const hrWindow = w.find(window => window.title?.startsWith('HR Master'));
			if (hrWindow) {
				hrMasterWindowId = hrWindow.id;
				console.log('🎯 Found HR Master window ID:', hrMasterWindowId);
			}
		}
	});

	// Force reactivity when locale changes (same pattern as Sidebar)
	$: locale = $currentLocale;

	// Update window titles whenever locale changes
	$: {
		if (locale) {
			console.log('📢 Locale changed to:', locale);
			
			// Update the main HR Master window title
			if (hrMasterWindowId) {
				const hrWindow = windows.find(w => w.id === hrMasterWindowId);
				if (hrWindow) {
					// Extract the instance number from the current title
					const match = hrWindow.title.match(/#(\d+)$/);
					const instanceNumber = match ? match[1] : '0';
					const newTitle = `${t('hr.masterTitle')} #${instanceNumber}`;
					console.log('🔄 Updating HR Master window title:', { windowId: hrMasterWindowId, newTitle, locale });
					windowManager.updateWindowTitle(hrMasterWindowId, newTitle);
				}
			}
			
			// Update titles for all tracked subwindows
			console.log('🔍 Checking openedWindowIds:', openedWindowIds.length);
			openedWindowIds.forEach(({ windowId, getTitle }) => {
				const window = windows.find(w => w.id === windowId);
				if (window) {
					const newTitle = getTitle();
					console.log('🔄 Updating window title:', { windowId, newTitle, locale });
					windowManager.updateWindowTitle(windowId, newTitle);
				} else {
					console.log('❌ Window not found in store:', windowId);
				}
			});
		}
	}
	
	onDestroy(() => {
		unsubscribe();
	});
	const dashboardButtons = [
		{
			id: 'upload-employees',
			titleKey: 'hr.masterUploadEmployees',
			descriptionKey: 'hr.masterUploadEmployeesDesc',
			icon: '👥',
			color: 'bg-green-500'
		},
		{
			id: 'create-department',
			titleKey: 'hr.masterCreateDepartment',
			descriptionKey: 'hr.masterCreateDepartmentDesc',
			icon: '🏢',
			color: 'bg-blue-500'
		},
		{
			id: 'create-level',
			titleKey: 'hr.masterCreateLevel',
			descriptionKey: 'hr.masterCreateLevelDesc',
			icon: '📊',
			color: 'bg-purple-500'
		},
		{
			id: 'create-position',
			titleKey: 'hr.masterCreatePosition',
			descriptionKey: 'hr.masterCreatePositionDesc',
			icon: '💼',
			color: 'bg-orange-500'
		},
		{
			id: 'reporting-map',
			titleKey: 'hr.masterReportingMap',
			descriptionKey: 'hr.masterReportingMapDesc',
			icon: '📈',
			color: 'bg-indigo-500'
		},
		{
			id: 'assign-positions',
			titleKey: 'hr.masterAssignPositions',
			descriptionKey: 'hr.masterAssignPositionsDesc',
			icon: '🎯',
			color: 'bg-teal-500'
		},
		{
			id: 'upload-fingerprint',
			titleKey: 'hr.masterBiometricData',
			descriptionKey: 'hr.masterBiometricDataDesc',
			icon: '👆',
			color: 'bg-red-500'
		},
		{
			id: 'contact-management',
			titleKey: 'hr.masterContactManagement',
			descriptionKey: 'hr.masterContactManagementDesc',
			icon: '📞',
			color: 'bg-yellow-500'
		},
		{
			id: 'document-management',
			titleKey: 'hr.masterDocumentManagement',
			descriptionKey: 'hr.masterDocumentManagementDesc',
			icon: '📄',
			color: 'bg-pink-500'
		},
		{
			id: 'salary-management',
			titleKey: 'hr.masterSalaryManagement',
			descriptionKey: 'hr.masterSalaryManagementDesc',
			icon: '💰',
			color: 'bg-emerald-500'
		},
		{
			id: 'warning-master',
			titleKey: 'hr.masterWarningMaster',
			descriptionKey: 'hr.masterWarningMasterDesc',
			icon: '⚠️',
			color: 'bg-amber-500'
		}
	];

	// Generate unique window ID
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openHRWindow(buttonId) {
		console.log('🔵 openHRWindow called for:', buttonId);
		const button = dashboardButtons.find(b => b.id === buttonId);
		const windowId = generateWindowId(buttonId);
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		// Create a dynamic title getter function
		const getTitle = () => {
			const title = `${t(button.titleKey)} #${instanceNumber}`;
			console.log('🎯 getTitle() called for', buttonId, ':', { titleKey: button.titleKey, title, currentLocale: $currentLocale });
			return title;
		};
		
		// Store window info for later updates
		const windowInfo = { windowId, button, instanceNumber, getTitle };
		openedWindowIds = [...openedWindowIds, windowInfo];
		console.log('📝 Window opened:', { windowId, buttonId, initialTitle: getTitle(), totalOpenWindows: openedWindowIds.length });

		let component;
		
		switch(buttonId) {
			case 'upload-employees':
				component = UploadEmployees;
				break;
			case 'create-department':
				component = CreateDepartment;
				break;
			case 'create-level':
				component = CreateLevel;
				break;
			case 'create-position':
				component = CreatePosition;
				break;
			case 'reporting-map':
				component = ReportingMap;
				break;
			case 'assign-positions':
				component = AssignPositions;
				break;
			case 'upload-fingerprint':
				component = BiometricData;
				break;
			case 'contact-management':
				component = ContactManagement;
				break;
			case 'document-management':
				component = DocumentManagement;
				break;
			case 'salary-management':
				component = SalaryManagement;
				break;
			case 'warning-master':
				component = WarningMaster;
				break;
			default:
				return;
		}

		if (showComingSoon) {
			alert(`${t(button.titleKey)} - Coming Soon!\nThis will open as a separate window component.`);
			return;
		}

		openWindow({
			id: windowId,
			title: getTitle(),
			component: component,
			icon: button.icon,
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
	}
</script>

<div class="hr-master">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">{t('hr.masterTitle')}</h1>
			<p class="subtitle">{t('hr.masterSubtitle')}</p>
		</div>
	</div>

	<!-- Dashboard Grid -->
	<div class="dashboard-grid">
		{#each dashboardButtons as button}
			<div class="dashboard-card" on:click={() => openHRWindow(button.id)}>
				<div class="card-icon {button.color}">
					<span class="icon">{button.icon}</span>
				</div>
				<div class="card-content">
					<h3 class="card-title">{t(button.titleKey)}</h3>
					<p class="card-description">{t(button.descriptionKey)}</p>
				</div>
				<div class="card-arrow">
					<span>→</span>
				</div>
			</div>
		{/each}
	</div>
</div>

<style>
	.hr-master {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		margin-bottom: 32px;
	}

	.title-section {
		text-align: center;
	}

	.title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 18px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 24px;
		max-width: 1200px;
		margin: 0 auto;
	}

	.dashboard-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
		cursor: pointer;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
		border-color: #d1d5db;
	}

	.dashboard-card::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: var(--card-color, #3b82f6);
		transition: all 0.3s ease;
	}

	.dashboard-card:hover::before {
		height: 6px;
	}

	.card-content {
		display: flex;
		flex-direction: column;
		position: relative;
		z-index: 1;
	}

	.card-icon {
		font-size: 32px;
		width: 48px;
		height: 48px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(59, 130, 246, 0.1);
		border-radius: 8px;
		flex-shrink: 0;
		margin-bottom: 16px;
	}

	.card-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.5;
	}

	.card-arrow {
		position: absolute;
		top: 50%;
		right: 20px;
		transform: translateY(-50%);
		font-size: 20px;
		color: #9ca3af;
		transition: all 0.3s ease;
	}

	.dashboard-card:hover .card-arrow {
		color: #6b7280;
		transform: translateY(-50%) translateX(4px);
	}

	/* Color variations for different cards */
	.dashboard-card:nth-child(1) { --card-color: #10b981; }
	.dashboard-card:nth-child(2) { --card-color: #3b82f6; }
	.dashboard-card:nth-child(3) { --card-color: #8b5cf6; }
	.dashboard-card:nth-child(4) { --card-color: #f59e0b; }
	.dashboard-card:nth-child(5) { --card-color: #ef4444; }
	.dashboard-card:nth-child(6) { --card-color: #06b6d4; }
	.dashboard-card:nth-child(7) { --card-color: #ec4899; }
	.dashboard-card:nth-child(8) { --card-color: #84cc16; }
	.dashboard-card:nth-child(9) { --card-color: #f97316; }
	.dashboard-card:nth-child(10) { --card-color: #10b981; }
	.dashboard-card:nth-child(11) { --card-color: #f59e0b; }

	.dashboard-card:nth-child(1) .card-icon { background: rgba(16, 185, 129, 0.1); }
	.dashboard-card:nth-child(2) .card-icon { background: rgba(59, 130, 246, 0.1); }
	.dashboard-card:nth-child(3) .card-icon { background: rgba(139, 92, 246, 0.1); }
	.dashboard-card:nth-child(4) .card-icon { background: rgba(245, 158, 11, 0.1); }
	.dashboard-card:nth-child(5) .card-icon { background: rgba(239, 68, 68, 0.1); }
	.dashboard-card:nth-child(6) .card-icon { background: rgba(6, 182, 212, 0.1); }
	.dashboard-card:nth-child(7) .card-icon { background: rgba(236, 72, 153, 0.1); }
	.dashboard-card:nth-child(8) .card-icon { background: rgba(132, 204, 22, 0.1); }
	.dashboard-card:nth-child(9) .card-icon { background: rgba(249, 115, 22, 0.1); }
	.dashboard-card:nth-child(10) .card-icon { background: rgba(16, 185, 129, 0.1); }
	.dashboard-card:nth-child(11) .card-icon { background: rgba(245, 158, 11, 0.1); }

	@media (max-width: 768px) {
		.dashboard-grid {
			grid-template-columns: 1fr;
		}
	}
</style>