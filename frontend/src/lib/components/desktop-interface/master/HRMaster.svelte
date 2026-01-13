<script>
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { t, currentLocale } from '$lib/i18n';
	import { get } from 'svelte/store';
	import { onDestroy, onMount } from 'svelte';

	console.log('🎯 HRMaster component loaded');

	onMount(() => {
		console.log('✅ HRMaster mounted successfully');
	});

	// Track opened windows to update their titles when language changes
	let openedWindowIds = [];
	
	onDestroy(() => {
		console.log('🧹 HRMaster destroyed');
	});
	
	const dashboardButtons = [
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
		const title = `${t(button.titleKey)} #${instanceNumber}`;
		
		// Load component asynchronously without blocking UI
		loadComponentAndOpenWindow(buttonId, windowId, title, button);
	}

	async function loadComponentAndOpenWindow(buttonId, windowId, title, button) {
		let component;
		
		// Dynamically import components to avoid loading everything at once
		switch(buttonId) {
			case 'create-department':
				const { default: CreateDepartment } = await import('$lib/components/desktop-interface/master/hr/CreateDepartment.svelte');
				component = CreateDepartment;
				break;
			case 'create-level':
				const { default: CreateLevel } = await import('$lib/components/desktop-interface/master/hr/CreateLevel.svelte');
				component = CreateLevel;
				break;
			case 'create-position':
				const { default: CreatePosition } = await import('$lib/components/desktop-interface/master/hr/CreatePosition.svelte');
				component = CreatePosition;
				break;
			case 'reporting-map':
				const { default: ReportingMap } = await import('$lib/components/desktop-interface/master/hr/ReportingMap.svelte');
				component = ReportingMap;
				break;
			case 'assign-positions':
				const { default: AssignPositions } = await import('$lib/components/desktop-interface/master/hr/AssignPositions.svelte');
				component = AssignPositions;
				break;
		default:
			return;
		}

		openWindow({
			id: windowId,
			title: title,
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