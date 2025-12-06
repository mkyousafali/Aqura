<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { supabase } from '$lib/utils/supabase';
	import WarningListView from '$lib/components/desktop-interface/master/warnings/WarningListView.svelte';
	import WarningStatistics from '$lib/components/desktop-interface/master/warnings/WarningStatistics.svelte';
	import ActiveFinesView from '$lib/components/desktop-interface/master/warnings/ActiveFinesView.svelte';
	import TaskStatusView from '$lib/components/desktop-interface/master/tasks/TaskStatusView.svelte';

	// Warning statistics
	let warningStats = {
		total_warnings: 0,
		active_warnings: 0,
		resolved_warnings: 0,
		total_fines: 0,
		total_fine_amount: 0,
		pending_fines: 0,
		paid_fines: 0
	};

	let isLoading = true;

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Fetch warning statistics from Supabase
	async function fetchWarningStatistics() {
		try {
			isLoading = true;
			console.log('🔍 Fetching warning statistics...');
			
			// First, let's try to get ALL records to see what's in the database
			console.log('🔍 Testing: Getting ALL warning records first...');
			let { data: allWarnings, error: allError } = await supabase
				.from('employee_warnings')
				.select('warning_status, has_fine, fine_amount, fine_status, is_deleted, id, warning_type, username, created_at');

			console.log('📊 ALL warnings in database:', allWarnings);
			console.log('❌ All warnings error:', allError);

			// Now try with the is_deleted filter
			let { data: warnings, error: warningsError } = await supabase
				.from('employee_warnings')
				.select('warning_status, has_fine, fine_amount, fine_status, is_deleted, id, warning_type')
				.or('is_deleted.is.null,is_deleted.eq.false');

			console.log('📊 Filtered warnings (is_deleted=false OR null):', warnings);

			// If regular client fails, try admin client
			if (warningsError || !warnings || warnings.length === 0) {
				console.log('🔄 Regular client failed or returned no data, trying admin client...');
				const adminResult = await supabase
					.from('employee_warnings')
					.select('warning_status, has_fine, fine_amount, fine_status, is_deleted, id, warning_type')
					.or('is_deleted.is.null,is_deleted.eq.false');
				
				warnings = adminResult.data;
				warningsError = adminResult.error;
				console.log('📊 Admin client warnings:', warnings);
			}

			console.log('📊 Raw warnings data:', warnings);
			console.log('❌ Warnings error:', warningsError);

			if (warningsError) {
				console.error('Error fetching warnings:', warningsError);
				console.error('Error details:', warningsError.message);
				return;
			}

			// Calculate statistics
			const stats = {
				total_warnings: warnings?.length || 0,
				active_warnings: warnings?.filter(w => w.warning_status === 'active').length || 0,
				resolved_warnings: warnings?.filter(w => w.warning_status === 'resolved').length || 0,
				total_fines: warnings?.filter(w => w.has_fine === true).length || 0,
				total_fine_amount: warnings
					?.filter(w => w.has_fine === true && w.fine_amount)
					.reduce((sum, w) => sum + (parseFloat(w.fine_amount) || 0), 0) || 0,
				pending_fines: warnings?.filter(w => w.has_fine === true && w.fine_status === 'pending').length || 0,
				paid_fines: warnings?.filter(w => w.has_fine === true && w.fine_status === 'paid').length || 0
			};

			console.log('📈 Calculated stats:', stats);
			warningStats = stats;
		} catch (error) {
			console.error('Error fetching warning statistics:', error);
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		fetchWarningStatistics();
		// Refresh statistics every 60 seconds
		const interval = setInterval(fetchWarningStatistics, 60000);
		return () => clearInterval(interval);
	});

	function openWarningList() {
		const windowId = generateWindowId('warning-list');
		
		openWindow({
			id: windowId,
			title: 'Warning Records',
			component: WarningListView,
			icon: '📋',
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
	}

	function openWarningStatistics() {
		const windowId = generateWindowId('warning-stats');
		
		openWindow({
			id: windowId,
			title: 'Warning Statistics & Reports',
			component: WarningStatistics,
			icon: '📊',
			size: { width: 1000, height: 700 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openActiveFines() {
		const windowId = generateWindowId('active-fines');
		
		openWindow({
			id: windowId,
			title: 'Active Fines Management',
			component: ActiveFinesView,
			icon: '💰',
			size: { width: 1100, height: 750 },
			position: { 
				x: 80 + (Math.random() * 100), 
				y: 80 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function refreshData() {
		fetchWarningStatistics();
	}

	function openTaskStatus() {
		const windowId = generateWindowId('task-status');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Task Status #${instanceNumber}`,
			component: TaskStatusView,
			icon: '📊',
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
	}
</script>

<div class="warning-master-dashboard">
	<!-- Dashboard Header -->
	<div class="header">
		<div class="title-section">
			<div class="flex items-center justify-center space-x-3 mb-4">
				<div class="bg-orange-100 p-3 rounded-lg">
					<svg class="w-8 h-8 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 18.5c-.77.833.192 2.5 1.732 2.5z"/>
					</svg>
				</div>
			</div>
			<h1 class="title">Warning Master Dashboard</h1>
			<p class="subtitle">Employee Warning Management System</p>
			<button
				on:click={refreshData}
				class="refresh-btn"
				title="Refresh Data"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				Refresh
			</button>
		</div>
	</div>

	<!-- Statistics Overview -->
	<div class="stats-grid">
		<div class="stat-card">
			<div class="stat-icon bg-blue-100">
				<span class="icon text-blue-600">📋</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.total_warnings}</div>
				<div class="stat-label">Total Warnings</div>
			</div>
		</div>

		<div class="stat-card">
			<div class="stat-icon bg-yellow-100">
				<span class="icon text-yellow-600">🟡</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.active_warnings}</div>
				<div class="stat-label">Active Warnings</div>
			</div>
		</div>

		<div class="stat-card">
			<div class="stat-icon bg-green-100">
				<span class="icon text-green-600">✅</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.resolved_warnings}</div>
				<div class="stat-label">Resolved Warnings</div>
			</div>
		</div>

		<div class="stat-card">
			<div class="stat-icon bg-red-100">
				<span class="icon text-red-600">💰</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.total_fines}</div>
				<div class="stat-label">Total Fines</div>
			</div>
		</div>

		<div class="stat-card">
			<div class="stat-icon bg-purple-100">
				<span class="icon text-purple-600">💵</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.total_fine_amount.toFixed(2)}</div>
				<div class="stat-label">Total Fine Amount</div>
			</div>
		</div>

		<div class="stat-card">
			<div class="stat-icon bg-orange-100">
				<span class="icon text-orange-600">⏳</span>
			</div>
			<div class="stat-content">
				<div class="stat-value">{warningStats.pending_fines}</div>
				<div class="stat-label">Pending Fines</div>
			</div>
		</div>
	</div>

	<!-- Dashboard Actions -->
	<div class="dashboard-grid">
		<div class="dashboard-card" on:click={openWarningList}>
			<div class="card-icon bg-blue-100">
				<span class="icon text-blue-600">📋</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Warning Records</h3>
				<p class="card-description">View, manage, and track all employee warnings</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openWarningStatistics}>
			<div class="card-icon bg-purple-100">
				<span class="icon text-purple-600">📊</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Statistics & Reports</h3>
				<p class="card-description">Generate reports and analyze warning trends</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openActiveFines}>
			<div class="card-icon bg-red-100">
				<span class="icon text-red-600">💰</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Fine Management</h3>
				<p class="card-description">Track and manage employee fines and payments</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openTaskStatus}>
			<div class="card-icon bg-indigo-100">
				<span class="icon text-indigo-600">📊</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Task Status</h3>
				<p class="card-description">Monitor task progress, send reminders, and generate warnings</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>


	</div>

	<!-- Quick Info Section -->
	<div class="features-section">
		<div class="features-header">
			<h3>Warning System Features</h3>
		</div>
		<div class="features-grid">
			<div class="feature-item">
				<div class="feature-icon">⚠️</div>
				<div class="feature-content">
					<h4>Performance Warnings</h4>
					<p>Track employee performance warnings with detailed records</p>
				</div>
			</div>
			<div class="feature-item">
				<div class="feature-icon">💰</div>
				<div class="feature-content">
					<h4>Fine Management</h4>
					<p>Manage financial penalties, record payments, and generate receipts</p>
				</div>
			</div>
			<div class="feature-item">
				<div class="feature-icon">📊</div>
				<div class="feature-content">
					<h4>Analytics & Reports</h4>
					<p>Generate comprehensive reports and trend analysis</p>
				</div>
			</div>
			<div class="feature-item">
				<div class="feature-icon">🔄</div>
				<div class="feature-content">
					<h4>Status Tracking</h4>
					<p>Monitor warning resolution and follow-up actions</p>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.warning-master-dashboard {
		padding: 24px;
		background: white;
		min-height: 100vh;
		overflow-y: auto;
	}

	.header {
		text-align: center;
		margin-bottom: 32px;
	}

	.title-section {
		position: relative;
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
		margin: 0 0 24px 0;
	}

	.refresh-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.refresh-btn:hover {
		background: #2563eb;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
		margin-bottom: 32px;
	}

	.stat-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
		display: flex;
		align-items: center;
		gap: 16px;
		transition: all 0.2s ease;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.stat-icon {
		width: 48px;
		height: 48px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 20px;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 24px;
		font-weight: 700;
		color: #111827;
		margin-bottom: 4px;
	}

	.stat-label {
		font-size: 14px;
		color: #6b7280;
		font-weight: 500;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 24px;
		margin-bottom: 32px;
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
		background: #f59e0b;
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
		top: 24px;
		right: 24px;
		font-size: 20px;
		color: #d1d5db;
		transition: all 0.3s ease;
	}

	.dashboard-card:hover .card-arrow {
		color: #f59e0b;
		transform: translateX(4px);
	}

	.features-section {
		background: #f8fafc;
		border-radius: 12px;
		padding: 24px;
		margin-top: 32px;
	}

	.features-header {
		text-align: center;
		margin-bottom: 24px;
	}

	.features-header h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.features-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 20px;
	}

	.feature-item {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 16px;
		background: white;
		border-radius: 8px;
	}

	.feature-icon {
		font-size: 24px;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #fff7ed;
		border-radius: 8px;
		flex-shrink: 0;
	}

	.feature-content h4 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.feature-content p {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.4;
	}

	@media (max-width: 768px) {
		.dashboard-grid, .stats-grid {
			grid-template-columns: 1fr;
		}
		
		.features-grid {
			grid-template-columns: 1fr;
		}
	}
</style>