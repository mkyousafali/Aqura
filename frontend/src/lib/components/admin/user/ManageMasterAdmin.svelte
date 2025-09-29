<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Current user context (mock)
	let currentUser = {
		id: '1',
		username: 'masteradmin',
		role_type: 'Master Admin',
		role_level: 100
	};

	// Real data from database
	let masterAdmins: Array<any> = [];

	// Load master admin users from database
	async function loadMasterAdmins() {
		try {
			const users = await userManagement.getAllUsers();
			// Filter for master admin users only
			masterAdmins = users.filter(user => 
				user.role_type === 'Master Admin'
			);
		} catch (error) {
			console.error('Error loading master admin users:', error);
		}
	}

	onMount(() => {
		loadMasterAdmins();
	});

	// System settings
	let systemSettings = {
		max_master_admins: 5,
		require_two_factor: true,
		password_expiry_days: 90,
		session_timeout_minutes: 30,
		backup_frequency: 'daily',
		audit_retention_days: 365,
		emergency_access_enabled: true
	};

	// System health metrics
	let systemHealth = {
		database_status: 'healthy',
		backup_status: 'completed',
		last_backup: '2024-01-15T02:00:00Z',
		disk_usage: 68,
		active_sessions: 23,
		failed_logins_24h: 5,
		system_uptime: '15 days, 6 hours'
	};

	// Recent system activities
	let recentActivities = [
		{
			id: '1',
			type: 'login',
			user: 'master.backup',
			action: 'Successful login',
			timestamp: '2024-01-15T14:22:00Z',
			ip: '192.168.1.100',
			severity: 'info'
		},
		{
			id: '2',
			type: 'admin_action',
			user: 'masteradmin',
			action: 'Created new admin user: admin.john',
			timestamp: '2024-01-15T10:45:00Z',
			ip: '192.168.1.101',
			severity: 'success'
		},
		{
			id: '3',
			type: 'security',
			user: 'unknown',
			action: 'Failed login attempt from suspicious IP',
			timestamp: '2024-01-15T08:15:00Z',
			ip: '203.0.113.42',
			severity: 'warning'
		},
		{
			id: '4',
			type: 'system',
			user: 'system',
			action: 'Daily backup completed successfully',
			timestamp: '2024-01-15T02:00:00Z',
			ip: 'localhost',
			severity: 'success'
		},
		{
			id: '5',
			type: 'admin_action',
			user: 'masteradmin',
			action: 'Updated system security settings',
			timestamp: '2024-01-14T16:30:00Z',
			ip: '192.168.1.101',
			severity: 'info'
		}
	];

	// State variables
	let isLoading = false;
	let errors: any = {};
	let successMessage = '';
	let activeTab = 'overview';
	let showCreateForm = false;
	let showSecuritySettings = false;

	// New Master Admin form
	let newMasterAdmin = {
		username: '',
		email: '',
		full_name: '',
		backup_email: '',
		phone: '',
		emergency_contact: '',
		require_two_factor: true,
		send_welcome_email: true
	};

	// Security settings form
	let securityForm = { ...systemSettings };

	// Computed values
	$: activeMasterAdmins = masterAdmins.filter(admin => admin.status === 'active');
	$: canCreateMore = activeMasterAdmins.length < systemSettings.max_master_admins;
	$: systemHealthStatus = getSystemHealthStatus();

	function getSystemHealthStatus() {
		const warningConditions = [
			systemHealth.disk_usage > 80,
			systemHealth.failed_logins_24h > 10,
			systemHealth.database_status !== 'healthy'
		];

		if (warningConditions.some(condition => condition)) {
			return 'warning';
		}

		return systemHealth.backup_status === 'completed' ? 'healthy' : 'error';
	}

	function formatDate(dateString: string) {
		const date = new Date(dateString);
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}

	function getActivityIcon(type: string) {
		switch (type) {
			case 'login': return '🔑';
			case 'admin_action': return '⚙️';
			case 'security': return '🔒';
			case 'system': return '🖥️';
			default: return '📋';
		}
	}

	function getActivityColor(severity: string) {
		switch (severity) {
			case 'success': return '#059669';
			case 'warning': return '#f59e0b';
			case 'error': return '#dc2626';
			default: return '#6b7280';
		}
	}

	async function handleCreateMasterAdmin() {
		// Validate form
		errors = {};
		
		if (!newMasterAdmin.username.trim()) {
			errors.username = 'Username is required';
		}
		if (!newMasterAdmin.email.trim()) {
			errors.email = 'Email is required';
		}
		if (!newMasterAdmin.full_name.trim()) {
			errors.full_name = 'Full name is required';
		}

		if (Object.keys(errors).length > 0) return;

		if (!canCreateMore) {
			errors.create = 'Maximum number of Master Administrators reached';
			return;
		}

		isLoading = true;
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 2000));

			const newId = (masterAdmins.length + 1).toString();
			const newAdmin = {
				id: newId,
				...newMasterAdmin,
				status: 'active',
				last_login: null,
				created_at: new Date().toISOString(),
				avatar_url: null,
				login_attempts: 0,
				is_locked: false,
				last_password_change: new Date().toISOString(),
				is_primary: false,
				two_factor_enabled: newMasterAdmin.require_two_factor,
				is_current_user: false
			};

			masterAdmins = [...masterAdmins, newAdmin];
			successMessage = `Master Administrator "${newMasterAdmin.username}" created successfully!`;
			
			// Reset form
			newMasterAdmin = {
				username: '',
				email: '',
				full_name: '',
				backup_email: '',
				phone: '',
				emergency_contact: '',
				require_two_factor: true,
				send_welcome_email: true
			};
			showCreateForm = false;

			// Clear success message after 3 seconds
			setTimeout(() => successMessage = '', 3000);

		} catch (error: any) {
			errors.create = error.message || 'Failed to create Master Administrator';
		} finally {
			isLoading = false;
		}
	}

	async function handleMasterAdminAction(admin: any, action: string) {
		// Prevent self-destructive actions on primary admin
		if (admin.is_primary && (action === 'deactivate' || action === 'delete')) {
			errors.action = 'Cannot deactivate or delete the primary Master Administrator';
			return;
		}

		// Check if this would leave no active Master Admins
		if (action === 'deactivate' && activeMasterAdmins.length <= 1) {
			errors.action = 'Cannot deactivate the last active Master Administrator';
			return;
		}

		isLoading = true;
		errors = {};
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 1000));

			switch (action) {
				case 'activate':
					admin.status = 'active';
					admin.is_locked = false;
					admin.login_attempts = 0;
					successMessage = `${admin.username} has been activated`;
					break;
				case 'deactivate':
					admin.status = 'inactive';
					successMessage = `${admin.username} has been deactivated`;
					break;
				case 'unlock':
					admin.is_locked = false;
					admin.login_attempts = 0;
					admin.status = 'active';
					successMessage = `${admin.username} has been unlocked`;
					break;
				case 'reset_password':
					admin.last_password_change = new Date().toISOString();
					successMessage = `Password reset email sent to ${admin.email}`;
					break;
				case 'enable_2fa':
					admin.two_factor_enabled = true;
					successMessage = `Two-factor authentication enabled for ${admin.username}`;
					break;
				case 'disable_2fa':
					admin.two_factor_enabled = false;
					successMessage = `Two-factor authentication disabled for ${admin.username}`;
					break;
				case 'make_primary':
					// Remove primary status from others
					masterAdmins.forEach(ma => ma.is_primary = false);
					admin.is_primary = true;
					successMessage = `${admin.username} is now the primary Master Administrator`;
					break;
				case 'delete':
					masterAdmins = masterAdmins.filter(ma => ma.id !== admin.id);
					successMessage = `${admin.username} has been deleted`;
					break;
			}

			// Clear success message after 3 seconds
			setTimeout(() => successMessage = '', 3000);

		} catch (error: any) {
			errors.action = error.message || 'Action failed';
		} finally {
			isLoading = false;
		}
	}

	async function handleUpdateSecuritySettings() {
		isLoading = true;
		errors = {};
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 1500));

			systemSettings = { ...securityForm };
			successMessage = 'Security settings updated successfully!';
			showSecuritySettings = false;

			// Clear success message after 3 seconds
			setTimeout(() => successMessage = '', 3000);

		} catch (error: any) {
			errors.security = error.message || 'Failed to update security settings';
		} finally {
			isLoading = false;
		}
	}

	function handleEmergencyBackup() {
		isLoading = true;
		successMessage = '';

		setTimeout(() => {
			successMessage = 'Emergency backup initiated successfully!';
			systemHealth.backup_status = 'in_progress';
			isLoading = false;

			// Simulate backup completion
			setTimeout(() => {
				systemHealth.backup_status = 'completed';
				systemHealth.last_backup = new Date().toISOString();
			}, 5000);
		}, 2000);
	}

	function editMasterAdmin(admin: any) {
		dispatch('editUser', admin);
	}

	function handleClose() {
		dispatch('close');
	}
</script>

<div class="manage-master-admin">
	<div class="header">
		<h1 class="title">Master Administrator Control Center</h1>
		<p class="subtitle">Ultimate system control and oversight</p>
	</div>

	<!-- Tab Navigation -->
	<div class="tab-nav">
		<button 
			class="tab-btn" 
			class:active={activeTab === 'overview'}
			on:click={() => activeTab = 'overview'}
		>
			🏠 Overview
		</button>
		<button 
			class="tab-btn" 
			class:active={activeTab === 'admins'}
			on:click={() => activeTab = 'admins'}
		>
			👑 Master Admins
		</button>
		<button 
			class="tab-btn" 
			class:active={activeTab === 'security'}
			on:click={() => activeTab = 'security'}
		>
			🔒 Security
		</button>
		<button 
			class="tab-btn" 
			class:active={activeTab === 'audit'}
			on:click={() => activeTab = 'audit'}
		>
			📋 Audit Log
		</button>
	</div>

	<!-- Overview Tab -->
	{#if activeTab === 'overview'}
		<div class="tab-content">
			<!-- System Health Cards -->
			<div class="health-cards">
				<div class="health-card" class:warning={systemHealthStatus === 'warning'} class:error={systemHealthStatus === 'error'}>
					<div class="card-header">
						<h3>System Health</h3>
						<span class="health-indicator" class:healthy={systemHealthStatus === 'healthy'} class:warning={systemHealthStatus === 'warning'} class:error={systemHealthStatus === 'error'}>
							{systemHealthStatus === 'healthy' ? '🟢' : systemHealthStatus === 'warning' ? '🟡' : '🔴'}
						</span>
					</div>
					<div class="health-metrics">
						<div class="metric">
							<span class="label">Database:</span>
							<span class="value">{systemHealth.database_status}</span>
						</div>
						<div class="metric">
							<span class="label">Last Backup:</span>
							<span class="value">{formatDate(systemHealth.last_backup)}</span>
						</div>
						<div class="metric">
							<span class="label">Uptime:</span>
							<span class="value">{systemHealth.system_uptime}</span>
						</div>
					</div>
				</div>

				<div class="health-card">
					<div class="card-header">
						<h3>Usage Metrics</h3>
						<span class="metric-icon">📊</span>
					</div>
					<div class="usage-metrics">
						<div class="usage-item">
							<div class="usage-header">
								<span>Disk Usage</span>
								<span>{systemHealth.disk_usage}%</span>
							</div>
							<div class="usage-bar">
								<div class="usage-fill" style="width: {systemHealth.disk_usage}%" class:warning={systemHealth.disk_usage > 80}></div>
							</div>
						</div>
						<div class="metric">
							<span class="label">Active Sessions:</span>
							<span class="value">{systemHealth.active_sessions}</span>
						</div>
						<div class="metric">
							<span class="label">Failed Logins (24h):</span>
							<span class="value" class:warning={systemHealth.failed_logins_24h > 5}>{systemHealth.failed_logins_24h}</span>
						</div>
					</div>
				</div>

				<div class="health-card">
					<div class="card-header">
						<h3>Master Admins</h3>
						<span class="admin-count">{activeMasterAdmins.length}/{systemSettings.max_master_admins}</span>
					</div>
					<div class="admin-summary">
						{#each activeMasterAdmins as admin}
							<div class="admin-item">
								<div class="admin-info">
									<span class="admin-name">{admin.username}</span>
									{#if admin.is_primary}
										<span class="primary-badge">PRIMARY</span>
									{/if}
								</div>
								<div class="admin-status">
									{#if admin.two_factor_enabled}
										<span class="security-badge">🔐 2FA</span>
									{/if}
									{#if admin.is_current_user}
										<span class="current-badge">YOU</span>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>
			</div>

			<!-- Quick Actions -->
			<div class="quick-actions">
				<h3>Emergency Actions</h3>
				<div class="action-buttons">
					<button class="emergency-btn backup" on:click={handleEmergencyBackup} disabled={isLoading}>
						💾 Emergency Backup
					</button>
					<button class="emergency-btn security" on:click={() => showSecuritySettings = true}>
						🔒 Security Settings
					</button>
					<button class="emergency-btn create" on:click={() => showCreateForm = true} disabled={!canCreateMore}>
						👑 Create Master Admin
					</button>
				</div>
			</div>

			<!-- Recent Activities Preview -->
			<div class="activity-preview">
				<div class="section-header">
					<h3>Recent System Activities</h3>
					<button class="view-all-btn" on:click={() => activeTab = 'audit'}>View All →</button>
				</div>
				<div class="activity-list">
					{#each recentActivities.slice(0, 5) as activity}
						<div class="activity-item">
							<span class="activity-icon">{getActivityIcon(activity.type)}</span>
							<div class="activity-details">
								<p class="activity-action">{activity.action}</p>
								<div class="activity-meta">
									<span class="activity-user">{activity.user}</span>
									<span class="activity-time">{formatDate(activity.timestamp)}</span>
								</div>
							</div>
							<span class="activity-severity" style="color: {getActivityColor(activity.severity)}">●</span>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{/if}

	<!-- Master Admins Tab -->
	{#if activeTab === 'admins'}
		<div class="tab-content">
			<div class="section-header">
				<h3>Master Administrator Accounts</h3>
				<button class="create-btn" on:click={() => showCreateForm = true} disabled={!canCreateMore}>
					➕ Create New Master Admin
				</button>
			</div>

			<div class="admins-grid">
				{#each masterAdmins as admin}
					<div class="admin-card" class:current={admin.is_current_user} class:primary={admin.is_primary} class:inactive={admin.status !== 'active'}>
						<div class="admin-header">
							<div class="admin-avatar">
								{#if admin.avatar_url}
									<img src={admin.avatar_url} alt="Avatar" class="avatar-image">
								{:else}
									<div class="avatar-placeholder">
										<span class="avatar-icon">👤</span>
									</div>
								{/if}
							</div>
							<div class="admin-basic-info">
								<h4 class="admin-username">{admin.username}</h4>
								<p class="admin-fullname">{admin.full_name}</p>
								<p class="admin-email">{admin.email}</p>
							</div>
							<div class="admin-badges">
								{#if admin.is_primary}
									<span class="badge primary">PRIMARY</span>
								{/if}
								{#if admin.is_current_user}
									<span class="badge current">YOU</span>
								{/if}
								{#if admin.status === 'active'}
									<span class="badge active">ACTIVE</span>
								{:else}
									<span class="badge inactive">INACTIVE</span>
								{/if}
							</div>
						</div>

						<div class="admin-details">
							<div class="detail-row">
								<span class="label">Last Login:</span>
								<span class="value">{admin.last_login ? formatDate(admin.last_login) : 'Never'}</span>
							</div>
							<div class="detail-row">
								<span class="label">Created:</span>
								<span class="value">{formatDate(admin.created_at)}</span>
							</div>
							<div class="detail-row">
								<span class="label">Two-Factor:</span>
								<span class="value" class:enabled={admin.two_factor_enabled}>
									{admin.two_factor_enabled ? '🔐 Enabled' : '❌ Disabled'}
								</span>
							</div>
							<div class="detail-row">
								<span class="label">Login Attempts:</span>
								<span class="value" class:warning={admin.login_attempts > 0}>{admin.login_attempts}</span>
							</div>
						</div>

						<div class="admin-actions">
							<button class="action-btn edit" on:click={() => editMasterAdmin(admin)}>
								✏️ Edit
							</button>
							
							<div class="dropdown">
								<button class="dropdown-btn">⋮</button>
								<div class="dropdown-content">
									{#if admin.status === 'active'}
										{#if !admin.is_primary && !(admin.is_current_user && activeMasterAdmins.length <= 1)}
											<button on:click={() => handleMasterAdminAction(admin, 'deactivate')}>
												❌ Deactivate
											</button>
										{/if}
									{:else}
										<button on:click={() => handleMasterAdminAction(admin, 'activate')}>
											✅ Activate
										</button>
									{/if}

									{#if admin.is_locked}
										<button on:click={() => handleMasterAdminAction(admin, 'unlock')}>
											🔓 Unlock
										</button>
									{/if}

									<button on:click={() => handleMasterAdminAction(admin, 'reset_password')}>
										🔐 Reset Password
									</button>

									{#if admin.two_factor_enabled}
										<button on:click={() => handleMasterAdminAction(admin, 'disable_2fa')}>
											❌ Disable 2FA
										</button>
									{:else}
										<button on:click={() => handleMasterAdminAction(admin, 'enable_2fa')}>
											🔐 Enable 2FA
										</button>
									{/if}

									{#if !admin.is_primary}
										<button on:click={() => handleMasterAdminAction(admin, 'make_primary')}>
											👑 Make Primary
										</button>
									{/if}

									{#if !admin.is_primary && !admin.is_current_user}
										<button on:click={() => handleMasterAdminAction(admin, 'delete')} class="danger">
											🗑️ Delete
										</button>
									{/if}
								</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Security Tab -->
	{#if activeTab === 'security'}
		<div class="tab-content">
			<div class="security-settings">
				<h3>System Security Configuration</h3>
				
				<div class="settings-form">
					<div class="form-row">
						<div class="form-group">
							<label for="max-admins">Maximum Master Admins</label>
							<input
								id="max-admins"
								type="number"
								bind:value={securityForm.max_master_admins}
								min="1"
								max="10"
								class="form-input"
							>
						</div>
						<div class="form-group">
							<label for="password-expiry">Password Expiry (Days)</label>
							<input
								id="password-expiry"
								type="number"
								bind:value={securityForm.password_expiry_days}
								min="30"
								max="365"
								class="form-input"
							>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="session-timeout">Session Timeout (Minutes)</label>
							<input
								id="session-timeout"
								type="number"
								bind:value={securityForm.session_timeout_minutes}
								min="5"
								max="480"
								class="form-input"
							>
						</div>
						<div class="form-group">
							<label for="audit-retention">Audit Retention (Days)</label>
							<input
								id="audit-retention"
								type="number"
								bind:value={securityForm.audit_retention_days}
								min="90"
								max="2555"
								class="form-input"
							>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="backup-frequency">Backup Frequency</label>
							<select id="backup-frequency" bind:value={securityForm.backup_frequency} class="form-select">
								<option value="hourly">Hourly</option>
								<option value="daily">Daily</option>
								<option value="weekly">Weekly</option>
							</select>
						</div>
					</div>

					<div class="checkbox-group">
						<label class="checkbox-label">
							<input
								type="checkbox"
								bind:checked={securityForm.require_two_factor}
								class="form-checkbox"
							>
							Require Two-Factor Authentication for all Master Admins
						</label>
						<label class="checkbox-label">
							<input
								type="checkbox"
								bind:checked={securityForm.emergency_access_enabled}
								class="form-checkbox"
							>
							Enable Emergency Access Override
						</label>
					</div>

					<div class="form-actions">
						<button 
							class="save-btn" 
							on:click={handleUpdateSecuritySettings}
							disabled={isLoading}
						>
							{#if isLoading}
								<span class="spinner"></span>
								Updating...
							{:else}
								💾 Save Security Settings
							{/if}
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Audit Log Tab -->
	{#if activeTab === 'audit'}
		<div class="tab-content">
			<div class="audit-log">
				<h3>System Audit Log</h3>
				<div class="audit-list">
					{#each recentActivities as activity}
						<div class="audit-item">
							<div class="audit-icon" style="color: {getActivityColor(activity.severity)}">
								{getActivityIcon(activity.type)}
							</div>
							<div class="audit-content">
								<div class="audit-header">
									<span class="audit-action">{activity.action}</span>
									<span class="audit-timestamp">{formatDate(activity.timestamp)}</span>
								</div>
								<div class="audit-meta">
									<span class="audit-user">User: {activity.user}</span>
									<span class="audit-ip">IP: {activity.ip}</span>
									<span class="audit-type">Type: {activity.type}</span>
								</div>
							</div>
							<div class="audit-severity" style="background: {getActivityColor(activity.severity)}">
								{activity.severity}
							</div>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{/if}

	<!-- Create Master Admin Modal -->
	{#if showCreateForm}
		<div class="modal-overlay" role="dialog" aria-modal="true" on:click={() => showCreateForm = false} on:keydown={(e) => e.key === 'Escape' && (showCreateForm = false)}>
			<div class="modal-content" role="document" on:click|stopPropagation on:keydown|stopPropagation>
				<div class="modal-header">
					<h2>Create New Master Administrator</h2>
					<button class="close-btn" on:click={() => showCreateForm = false}>×</button>
				</div>
				
				<form on:submit|preventDefault={handleCreateMasterAdmin} class="create-form">
					<div class="form-row">
						<div class="form-group">
							<label for="new-username">Username *</label>
							<input
								id="new-username"
								type="text"
								bind:value={newMasterAdmin.username}
								class="form-input"
								class:error={errors.username}
								required
							>
							{#if errors.username}
								<span class="error-message">{errors.username}</span>
							{/if}
						</div>
						<div class="form-group">
							<label for="new-fullname">Full Name *</label>
							<input
								id="new-fullname"
								type="text"
								bind:value={newMasterAdmin.full_name}
								class="form-input"
								class:error={errors.full_name}
								required
							>
							{#if errors.full_name}
								<span class="error-message">{errors.full_name}</span>
							{/if}
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="new-email">Primary Email *</label>
							<input
								id="new-email"
								type="email"
								bind:value={newMasterAdmin.email}
								class="form-input"
								class:error={errors.email}
								required
							>
							{#if errors.email}
								<span class="error-message">{errors.email}</span>
							{/if}
						</div>
						<div class="form-group">
							<label for="new-backup-email">Backup Email</label>
							<input
								id="new-backup-email"
								type="email"
								bind:value={newMasterAdmin.backup_email}
								class="form-input"
							>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="new-phone">Phone Number</label>
							<input
								id="new-phone"
								type="tel"
								bind:value={newMasterAdmin.phone}
								class="form-input"
								placeholder="+1-234-567-8900"
							>
						</div>
						<div class="form-group">
							<label for="new-emergency">Emergency Contact Email</label>
							<input
								id="new-emergency"
								type="email"
								bind:value={newMasterAdmin.emergency_contact}
								class="form-input"
							>
						</div>
					</div>

					<div class="checkbox-group">
						<label class="checkbox-label">
							<input
								type="checkbox"
								bind:checked={newMasterAdmin.require_two_factor}
								class="form-checkbox"
							>
							Require Two-Factor Authentication
						</label>
						<label class="checkbox-label">
							<input
								type="checkbox"
								bind:checked={newMasterAdmin.send_welcome_email}
								class="form-checkbox"
							>
							Send Welcome Email with Login Instructions
						</label>
					</div>

					{#if errors.create}
						<div class="error-banner">
							{errors.create}
						</div>
					{/if}

					<div class="modal-actions">
						<button type="button" class="cancel-btn" on:click={() => showCreateForm = false}>
							Cancel
						</button>
						<button type="submit" class="create-btn" disabled={isLoading}>
							{#if isLoading}
								<span class="spinner"></span>
								Creating...
							{:else}
								👑 Create Master Admin
							{/if}
						</button>
					</div>
				</form>
			</div>
		</div>
	{/if}

	<!-- Messages -->
	{#if errors.action || errors.security}
		<div class="error-banner">
			<strong>Error:</strong> {errors.action || errors.security}
		</div>
	{/if}

	{#if successMessage}
		<div class="success-banner">
			<strong>Success:</strong> {successMessage}
		</div>
	{/if}

	<!-- Close Button -->
	<div class="window-actions">
		<button class="close-window-btn" on:click={handleClose}>
			Close Control Center
		</button>
	</div>
</div>

<style>
	.manage-master-admin {
		height: 100%;
		background: #0f172a;
		color: #e2e8f0;
		display: flex;
		flex-direction: column;
		padding: 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 24px;
	}

	.title {
		font-size: 32px;
		font-weight: 800;
		color: #f1f5f9;
		margin: 0 0 8px 0;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
	}

	.subtitle {
		font-size: 16px;
		color: #94a3b8;
		margin: 0;
	}

	.tab-nav {
		display: flex;
		gap: 4px;
		margin-bottom: 24px;
		background: #1e293b;
		padding: 4px;
		border-radius: 8px;
	}

	.tab-btn {
		flex: 1;
		padding: 12px 16px;
		background: none;
		border: none;
		color: #94a3b8;
		font-weight: 500;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.tab-btn:hover {
		color: #e2e8f0;
		background: #334155;
	}

	.tab-btn.active {
		background: #3b82f6;
		color: white;
	}

	.tab-content {
		flex: 1;
		overflow-y: auto;
	}

	.health-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 20px;
		margin-bottom: 32px;
	}

	.health-card {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 20px;
	}

	.health-card.warning {
		border-color: #f59e0b;
	}

	.health-card.error {
		border-color: #ef4444;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.card-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #f1f5f9;
		margin: 0;
	}

	.health-indicator, .metric-icon, .admin-count {
		font-size: 20px;
	}

	.health-metrics, .usage-metrics, .admin-summary {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.metric {
		display: flex;
		justify-content: space-between;
	}

	.metric .label {
		color: #94a3b8;
		font-size: 14px;
	}

	.metric .value {
		color: #e2e8f0;
		font-size: 14px;
		font-weight: 500;
	}

	.metric .value.warning {
		color: #fbbf24;
	}

	.usage-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.usage-header {
		display: flex;
		justify-content: space-between;
		font-size: 14px;
	}

	.usage-bar {
		height: 6px;
		background: #374151;
		border-radius: 3px;
		overflow: hidden;
	}

	.usage-fill {
		height: 100%;
		background: #3b82f6;
		border-radius: 3px;
		transition: all 0.3s;
	}

	.usage-fill.warning {
		background: #f59e0b;
	}

	.admin-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 0;
		border-bottom: 1px solid #374151;
	}

	.admin-info {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.admin-name {
		font-weight: 500;
		color: #e2e8f0;
	}

	.primary-badge, .current-badge, .security-badge {
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.primary-badge {
		background: #fbbf24;
		color: #92400e;
	}

	.current-badge {
		background: #10b981;
		color: #064e3b;
	}

	.security-badge {
		background: #3b82f6;
		color: white;
	}

	.quick-actions {
		margin-bottom: 32px;
	}

	.quick-actions h3 {
		color: #f1f5f9;
		margin-bottom: 16px;
	}

	.action-buttons {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
	}

	.emergency-btn {
		padding: 12px 20px;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		border: none;
		transition: all 0.2s;
	}

	.emergency-btn.backup {
		background: #0891b2;
		color: white;
	}

	.emergency-btn.security {
		background: #dc2626;
		color: white;
	}

	.emergency-btn.create {
		background: #7c3aed;
		color: white;
	}

	.emergency-btn:hover:not(:disabled) {
		transform: translateY(-2px);
	}

	.emergency-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.activity-preview {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 20px;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.section-header h3 {
		color: #f1f5f9;
		margin: 0;
	}

	.view-all-btn, .create-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s;
	}

	.view-all-btn:hover, .create-btn:hover {
		background: #2563eb;
	}

	.activity-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.activity-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		background: #334155;
		border-radius: 8px;
	}

	.activity-icon {
		font-size: 18px;
	}

	.activity-details {
		flex: 1;
	}

	.activity-action {
		color: #e2e8f0;
		margin: 0 0 4px 0;
		font-weight: 500;
	}

	.activity-meta {
		display: flex;
		gap: 12px;
		font-size: 12px;
		color: #94a3b8;
	}

	.activity-severity {
		font-size: 12px;
	}

	.admins-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
		gap: 20px;
	}

	.admin-card {
		background: #1e293b;
		border: 2px solid #334155;
		border-radius: 12px;
		padding: 20px;
		transition: all 0.2s;
	}

	.admin-card.current {
		border-color: #10b981;
		box-shadow: 0 0 20px rgba(16, 185, 129, 0.2);
	}

	.admin-card.primary {
		border-color: #fbbf24;
		box-shadow: 0 0 20px rgba(251, 191, 36, 0.2);
	}

	.admin-card.inactive {
		opacity: 0.6;
		border-color: #6b7280;
	}

	.admin-header {
		display: flex;
		gap: 16px;
		margin-bottom: 16px;
	}

	.admin-avatar {
		width: 60px;
		height: 60px;
		flex-shrink: 0;
	}

	.avatar-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
		border: 2px solid #334155;
	}

	.avatar-placeholder {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		border: 2px solid #334155;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #374151;
	}

	.avatar-icon {
		font-size: 24px;
	}

	.admin-basic-info {
		flex: 1;
	}

	.admin-username {
		color: #f1f5f9;
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 4px 0;
	}

	.admin-fullname {
		color: #cbd5e1;
		margin: 0 0 4px 0;
	}

	.admin-email {
		color: #94a3b8;
		font-size: 14px;
		margin: 0;
	}

	.admin-badges {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.badge {
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		text-align: center;
	}

	.badge.primary {
		background: #fbbf24;
		color: #92400e;
	}

	.badge.current {
		background: #10b981;
		color: #064e3b;
	}

	.badge.active {
		background: #059669;
		color: white;
	}

	.badge.inactive {
		background: #6b7280;
		color: white;
	}

	.admin-details {
		display: flex;
		flex-direction: column;
		gap: 8px;
		margin-bottom: 16px;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		font-size: 14px;
	}

	.detail-row .label {
		color: #94a3b8;
	}

	.detail-row .value {
		color: #e2e8f0;
	}

	.detail-row .value.enabled {
		color: #10b981;
	}

	.detail-row .value.warning {
		color: #fbbf24;
	}

	.admin-actions {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.action-btn.edit {
		background: #f59e0b;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-btn.edit:hover {
		background: #d97706;
	}

	.dropdown {
		position: relative;
	}

	.dropdown-btn {
		background: #374151;
		border: 1px solid #4b5563;
		border-radius: 4px;
		padding: 8px 12px;
		color: #e2e8f0;
		cursor: pointer;
		font-size: 16px;
	}

	.dropdown:hover .dropdown-content {
		display: block;
	}

	.dropdown-content {
		display: none;
		position: absolute;
		right: 0;
		top: 100%;
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 6px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
		z-index: 10;
		min-width: 180px;
	}

	.dropdown-content button {
		display: block;
		width: 100%;
		padding: 8px 12px;
		text-align: left;
		border: none;
		background: none;
		color: #e2e8f0;
		cursor: pointer;
		font-size: 12px;
		transition: background-color 0.2s;
	}

	.dropdown-content button:hover {
		background: #334155;
	}

	.dropdown-content button.danger {
		color: #fca5a5;
	}

	.dropdown-content button.danger:hover {
		background: #7f1d1d;
	}

	.security-settings {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 24px;
	}

	.security-settings h3 {
		color: #f1f5f9;
		margin-bottom: 20px;
	}

	.settings-form {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		color: #cbd5e1;
		font-weight: 500;
		font-size: 14px;
	}

	.form-input, .form-select {
		padding: 10px 12px;
		border: 1px solid #4b5563;
		border-radius: 6px;
		background: #374151;
		color: #e2e8f0;
		font-size: 14px;
	}

	.form-input:focus, .form-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input.error {
		border-color: #ef4444;
	}

	.checkbox-group {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #cbd5e1;
		cursor: pointer;
	}

	.form-checkbox {
		width: 16px;
		height: 16px;
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
	}

	.save-btn {
		background: #059669;
		color: white;
		border: none;
		padding: 12px 24px;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.save-btn:hover:not(:disabled) {
		background: #047857;
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.audit-log {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 24px;
	}

	.audit-log h3 {
		color: #f1f5f9;
		margin-bottom: 20px;
	}

	.audit-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.audit-item {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 16px;
		background: #334155;
		border-radius: 8px;
	}

	.audit-icon {
		font-size: 18px;
		margin-top: 2px;
	}

	.audit-content {
		flex: 1;
	}

	.audit-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 4px;
	}

	.audit-action {
		color: #e2e8f0;
		font-weight: 500;
		line-height: 1.4;
	}

	.audit-timestamp {
		color: #94a3b8;
		font-size: 12px;
		white-space: nowrap;
	}

	.audit-meta {
		display: flex;
		gap: 16px;
		font-size: 12px;
		color: #94a3b8;
	}

	.audit-severity {
		padding: 4px 8px;
		border-radius: 4px;
		color: white;
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		height: fit-content;
	}

	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 50;
	}

	.modal-content {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 0;
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #334155;
	}

	.modal-header h2 {
		color: #f1f5f9;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		color: #94a3b8;
		font-size: 24px;
		cursor: pointer;
		padding: 0;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.create-form {
		padding: 24px;
	}

	.modal-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 24px;
	}

	.cancel-btn {
		background: #6b7280;
		color: white;
		border: none;
		padding: 10px 20px;
		border-radius: 6px;
		cursor: pointer;
	}

	.error-message {
		color: #fca5a5;
		font-size: 12px;
		margin-top: 4px;
	}

	.error-banner {
		background: #7f1d1d;
		color: #fca5a5;
		padding: 12px 16px;
		border-radius: 8px;
		margin: 16px 0;
		border: 1px solid #991b1b;
	}

	.success-banner {
		background: #064e3b;
		color: #a7f3d0;
		padding: 12px 16px;
		border-radius: 8px;
		margin: 16px 0;
		border: 1px solid #059669;
	}

	.window-actions {
		text-align: center;
		margin-top: 24px;
	}

	.close-window-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 12px 24px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-window-btn:hover {
		background: #4b5563;
		transform: translateY(-1px);
	}

	.spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.admins-grid {
			grid-template-columns: 1fr;
		}

		.health-cards {
			grid-template-columns: 1fr;
		}

		.action-buttons {
			flex-direction: column;
		}
	}
</style>