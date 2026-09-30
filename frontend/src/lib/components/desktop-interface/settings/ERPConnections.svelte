<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';

	interface ERPConfig {
		id?: string;
		branch_id: number;
		branch_name: string;
		server_ip: string;
		server_name: string;
		database_name: string;
		username: string;
		password: string;
		device_id?: string;
		is_active: boolean;
		created_at?: string;
		updated_at?: string;
	}

	let erpConfigs: ERPConfig[] = [];
	let branches: any[] = [];
	let loading = false;
	let saving = false;
	let testingConnection = false;
	let showConfigForm = false;

	// Form state
	let formData: ERPConfig = {
		branch_id: 0,
		branch_name: '',
		server_ip: '',
		server_name: '',
		database_name: '',
		username: '',
		password: '',
		device_id: '',
		is_active: true
	};

	// Auto-detect device ID only
	async function detectDeviceInfo() {
		try {
			// Generate unique device ID from browser fingerprint
			const deviceId = await generateDeviceId();
			formData.device_id = deviceId;

			notifications.add({
				message: 'Device ID detected automatically',
				type: 'success'
			});
		} catch (error: any) {
			console.error('Error detecting device ID:', error);
			notifications.add({
				message: 'Could not auto-detect device ID.',
				type: 'warning'
			});
		}
	}

	// Generate unique device ID
	async function generateDeviceId(): Promise<string> {
		const data = {
			userAgent: navigator.userAgent,
			language: navigator.language,
			platform: navigator.platform,
			cores: navigator.hardwareConcurrency || 0,
			memory: (navigator as any).deviceMemory || 0,
			screen: `${screen.width}x${screen.height}x${screen.colorDepth}`,
			timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
		};

		const str = JSON.stringify(data);
		const encoder = new TextEncoder();
		const dataBuffer = encoder.encode(str);
		const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
		const hashArray = Array.from(new Uint8Array(hashBuffer));
		return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
	}

	onMount(async () => {
		await loadBranches();
		await loadERPConfigs();
		await detectDeviceInfo(); // Auto-detect device info on load
	});

	async function loadBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error: any) {
			console.error('Error loading branches:', error);
			notifications.add({
				message: t('common.error') || 'Error loading branches',
				type: 'error'
			});
		}
	}

	async function loadERPConfigs() {
		try {
			loading = true;
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_connections')
				.select('*')
				.order('branch_name');

			if (error) throw error;
			erpConfigs = data || [];
			console.log('Loaded ERP configs:', erpConfigs);
		} catch (error: any) {
			console.error('Error loading ERP configs:', error);
			notifications.add({
				message: t('common.error') || 'Error loading ERP configurations',
				type: 'error'
			});
		} finally {
			loading = false;
		}
	}

	async function saveConfig() {
		if (!formData.branch_id || !formData.server_ip || !formData.database_name) {
			notifications.add({
				message: 'Please fill in all required fields',
				type: 'error'
			});
			return;
		}

		try {
			saving = true;
			const { supabase } = await import('$lib/utils/supabase');

			// Get branch name
			const branch = branches.find(b => b.id === formData.branch_id);
			if (branch) {
				formData.branch_name = branch.name_en;
			}

			if (formData.id) {
				// Update existing
				const { error } = await supabase
					.from('erp_connections')
					.update(formData)
					.eq('id', formData.id);

				if (error) throw error;
				notifications.add({
					message: 'ERP configuration updated successfully',
					type: 'success'
				});
			} else {
				// Create new
				const { error } = await supabase
					.from('erp_connections')
					.insert(formData);

				if (error) throw error;
				notifications.add({
					message: 'ERP configuration created successfully',
					type: 'success'
				});
			}

			await loadERPConfigs();
			resetForm();
		} catch (error: any) {
			console.error('Error saving config:', error);
			notifications.add({
				message: error.message || 'Error saving configuration',
				type: 'error'
			});
		} finally {
			saving = false;
		}
	}

	async function testConnection(config: ERPConfig) {
		try {
			testingConnection = true;
			const response = await fetch('/api/erp/test-connection', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					server_ip: config.server_ip,
					database_name: config.database_name,
					username: config.username,
					password: config.password
				})
			});

			const result = await response.json();

			if (result.success) {
				notifications.add({
					message: `✅ Connected successfully to ${config.database_name}`,
					type: 'success'
				});
			} else {
				notifications.add({
					message: `❌ Connection failed: ${result.error}`,
					type: 'error'
				});
			}
		} catch (error: any) {
			console.error('Error testing connection:', error);
			notifications.add({
				message: 'Error testing connection',
				type: 'error'
			});
		} finally {
			testingConnection = false;
		}
	}

	function editConfig(config: ERPConfig) {
		formData = { ...config };
		showConfigForm = true;
	}

	async function deleteConfig(id: string) {
		if (!confirm('Are you sure you want to delete this ERP configuration?')) {
			return;
		}

		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('erp_connections')
				.delete()
				.eq('id', id);

			if (error) throw error;

			notifications.add({
				message: 'ERP configuration deleted successfully',
				type: 'success'
			});

			await loadERPConfigs();
		} catch (error: any) {
			console.error('Error deleting config:', error);
			notifications.add({
				message: error.message || 'Error deleting configuration',
				type: 'error'
			});
		}
	}

	function resetForm() {
		formData = {
			branch_id: 0,
			branch_name: '',
			server_ip: '',
			server_name: '',
			database_name: '',
			username: '',
			password: '',
			is_active: true
		};
		showConfigForm = false;
	}

</script>

<div class="erp-connections">
	<div class="header">
		<h2>🔌 {t('erp.connections') || 'ERP Connections'}</h2>
		<button class="btn-primary" on:click={() => showConfigForm = !showConfigForm}>
			{showConfigForm ? `❌ ${t('actions.cancel') || 'Cancel'}` : `➕ ${t('erp.addConfiguration') || 'Add Configuration'}`}
		</button>
	</div>

	<!-- Configuration Form -->
	{#if showConfigForm}
		<div class="config-form">
			<h3>{formData.id ? t('erp.editConfiguration') || 'Edit Configuration' : t('erp.newConfiguration') || 'New Configuration'}</h3>
			
			<div class="form-grid">
				<div class="form-group">
					<label for="branch">{t('erp.branch') || 'Branch'} *</label>
					<select id="branch" bind:value={formData.branch_id} required>
						<option value="">{t('erp.selectBranch') || 'Select Branch'}</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en} - {branch.name_ar}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label for="device_id">{t('erp.deviceId') || 'Device ID'} ({t('common.autoDetected') || 'Auto-detected'})</label>
					<input 
						id="device_id"
						type="text" 
						bind:value={formData.device_id}
						readonly
						class="readonly"
						title="Unique device identifier - auto-generated"
					/>
					<small>🔒 {t('erp.deviceIdHint') || 'This device will be authorized to sync sales data'}</small>
				</div>

				<div class="form-group">
					<label for="server_ip">{t('erp.serverIp') || 'Server IP'} *</label>
					<input 
						id="server_ip"
						type="text" 
						bind:value={formData.server_ip}
						placeholder="e.g., 192.168.1.100"
						required
					/>
					<small>📍 Enter your local server IP address</small>
				</div>

				<div class="form-group">
					<label for="server_name">{t('erp.serverName') || 'Server Name'} *</label>
					<input 
						id="server_name"
						type="text" 
						bind:value={formData.server_name}
						placeholder="e.g., Office-PC or Branch-Server"
						required
					/>
					<small>💻 Enter a descriptive name for this server</small>
				</div>

				<div class="form-group">
					<label for="database_name">{t('erp.databaseName') || 'Database Name'} *</label>
					<input 
						id="database_name"
						type="text" 
						bind:value={formData.database_name}
						placeholder="ERP_DB"
						required
					/>
				</div>

				<div class="form-group">
					<label for="username">{t('erp.username') || 'Username'} *</label>
					<input 
						id="username"
						type="text" 
						bind:value={formData.username}
						placeholder="sa"
						required
					/>
				</div>

				<div class="form-group">
					<label for="password">{t('erp.password') || 'Password'} *</label>
					<input 
						id="password"
						type="password" 
						bind:value={formData.password}
						placeholder="••••••••"
						required
					/>
				</div>

				<div class="form-group">
					<label>
						<input type="checkbox" bind:checked={formData.is_active} />
						{t('erp.isActive') || 'Active'}
					</label>
				</div>
			</div>

			<div class="form-actions">
				<button class="btn-secondary" on:click={resetForm}>{t('actions.cancel') || 'Cancel'}</button>
				<button class="btn-primary" on:click={saveConfig} disabled={saving}>
					{saving ? `💾 ${t('erp.saving') || 'Saving...'}` : `💾 ${t('erp.saveConfiguration') || 'Save Configuration'}`}
				</button>
			</div>
		</div>
	{/if}

	<!-- Existing Configurations -->
	<div class="configs-list">
		<h3>📋 Configured Branches</h3>
		
		{#if loading}
			<div class="loading">Loading configurations...</div>
		{:else if erpConfigs.length === 0}
			<div class="empty-state">
				<p>No ERP configurations found. Add one to get started.</p>
			</div>
		{:else}
			<div class="config-cards">
				{#each erpConfigs as config}
					<div class="config-card" class:inactive={!config.is_active}>
						<div class="config-header">
							<h4>{config.branch_name}</h4>
							<span class="status" class:active={config.is_active}>
								{config.is_active ? '✅ Active' : '⭕ Inactive'}
							</span>
						</div>
						
						<div class="config-details">
							<div class="detail-row">
								<span class="label">Server IP:</span>
								<span class="value">{config.server_ip}</span>
							</div>
							<div class="detail-row">
								<span class="label">Database:</span>
								<span class="value">{config.database_name}</span>
							</div>
							<div class="detail-row">
								<span class="label">Username:</span>
								<span class="value">{config.username}</span>
							</div>
						</div>

						<div class="config-actions">
							<button 
								class="btn-test" 
								on:click={() => testConnection(config)}
								disabled={testingConnection}
							>
								🔌 Test
							</button>
							<button class="btn-edit" on:click={() => editConfig(config)}>
								✏️ Edit
							</button>
							<button class="btn-delete" on:click={() => deleteConfig(config.id!)}>
								🗑️ Delete
							</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

</div>

<style>
	.erp-connections {
		padding: 2rem;
		max-width: 1400px;
		margin: 0 auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2rem;
	}

	.header h2 {
		font-size: 1.75rem;
		color: #1a1a1a;
		margin: 0;
	}

	.config-form {
		background: white;
		border-radius: 8px;
		padding: 2rem;
		margin-bottom: 2rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.config-form h3 {
		margin-top: 0;
		margin-bottom: 1.5rem;
		color: #333;
	}

	.form-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group label {
		font-weight: 500;
		margin-bottom: 0.5rem;
		color: #333;
	}

	.form-group input,
	.form-group select {
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 1rem;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #9C27B0;
	}

	.form-group input.readonly {
		background-color: #f5f5f5;
		color: #666;
		cursor: not-allowed;
	}

	.form-group small {
		margin-top: 0.25rem;
		font-size: 0.85rem;
		color: #666;
	}

	.btn-refresh {
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 1rem;
		cursor: pointer;
		margin-bottom: 1.5rem;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn-refresh:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.btn-refresh:active {
		transform: translateY(0);
	}

	.form-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
	}

	.configs-list {
		margin-bottom: 2rem;
	}

	.configs-list h3 {
		margin-bottom: 1rem;
		color: #333;
	}

	.config-cards {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
		gap: 1.5rem;
	}

	.config-card {
		background: white;
		border-radius: 8px;
		padding: 1.5rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		border-left: 4px solid #4CAF50;
	}

	.config-card.inactive {
		border-left-color: #ccc;
		opacity: 0.7;
	}

	.config-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.config-header h4 {
		margin: 0;
		color: #1a1a1a;
	}

	.status {
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.85rem;
		background: #f0f0f0;
		color: #666;
	}

	.status.active {
		background: #e8f5e9;
		color: #4CAF50;
	}

	.config-details {
		margin-bottom: 1rem;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem 0;
		border-bottom: 1px solid #f0f0f0;
	}

	.detail-row .label {
		font-weight: 500;
		color: #666;
	}

	.detail-row .value {
		color: #1a1a1a;
		font-family: monospace;
	}

	.config-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 1rem;
	}

	.config-actions button {
		flex: 1;
		padding: 0.5rem;
		border-radius: 6px;
		border: none;
		cursor: pointer;
		font-size: 0.9rem;
		transition: all 0.3s ease;
	}

	.btn-test {
		background: #2196F3;
		color: white;
	}

	.btn-test:hover:not(:disabled) {
		background: #1976D2;
	}

	.btn-edit {
		background: #FF9800;
		color: white;
	}

	.btn-edit:hover {
		background: #F57C00;
	}

	.btn-delete {
		background: #f44336;
		color: white;
	}

	.btn-delete:hover {
		background: #d32f2f;
	}

	.btn-primary,
	.btn-secondary {
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		border: none;
		cursor: pointer;
		font-size: 1rem;
		transition: all 0.3s ease;
	}

	.btn-primary {
		background: #9C27B0;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #7B1FA2;
	}

	.btn-primary:disabled {
		background: #ccc;
		cursor: not-allowed;
	}

	.btn-secondary {
		background: #f0f0f0;
		color: #333;
	}

	.btn-secondary:hover {
		background: #e0e0e0;
	}

	.loading,
	.empty-state {
		text-align: center;
		padding: 3rem;
		color: #666;
		background: white;
		border-radius: 8px;
	}
</style>
