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

	interface SalesData {
		branch_name: string;
		date: string;
		gross_sales: number;
		gross_bills: number;
		gross_tax: number;
		returns: number;
		return_bills: number;
		return_tax: number;
		net_sales: number;
		net_bills: number;
		net_tax: number;
		discount: number;
	}

	let erpConfigs: ERPConfig[] = [];
	let branches: any[] = [];
	let loading = false;
	let saving = false;
	let testingConnection = false;
	let fetchingSales = false;
	let showConfigForm = false;
	let selectedBranch = 0;
	let salesData: SalesData | null = null;
	let selectedDate = new Date().toISOString().split('T')[0]; // Today's date

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

	async function fetchSales() {
		if (!selectedBranch) {
			notifications.add({
				message: 'Please select a branch',
				type: 'error'
			});
			return;
		}

		const config = erpConfigs.find(c => c.branch_id === selectedBranch);
		if (!config) {
			notifications.add({
				message: 'No ERP configuration found for this branch',
				type: 'error'
			});
			return;
		}

		try {
			fetchingSales = true;
			
			// Fetch from Supabase erp_daily_sales table (synced by desktop app)
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.eq('branch_id', selectedBranch)
				.eq('sale_date', selectedDate)
				.single();

			if (error && error.code !== 'PGRST116') {
				// PGRST116 is "no rows found" error
				throw new Error(error.message);
			}

			if (data) {
				// Transform Supabase data to match expected format
				salesData = {
					branch_name: config.branch_name,
					date: data.sale_date,
					gross_sales: data.gross_amount,
					gross_bills: data.total_bills,
					gross_tax: data.tax_amount,
					returns: data.return_amount,
					return_bills: data.total_returns,
					return_tax: data.return_tax,
					net_sales: data.net_amount,
					net_bills: data.net_bills,
					net_tax: data.net_tax,
					discount: data.discount_amount
				};
				
				notifications.add({
					message: '✅ Sales data loaded from synced database',
					type: 'success'
				});
			} else {
				salesData = null;
				notifications.add({
					message: '⚠️ No sales data available for this date. Make sure the desktop sync app is running.',
					type: 'warning'
				});
			}

		} catch (error: any) {
			console.error('Error fetching sales:', error);
			salesData = null;
			notifications.add({
				message: `❌ Error loading sales data: ${error.message}`,
				type: 'error'
			});
		} finally {
			fetchingSales = false;
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

	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('en-IN', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(amount);
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
						placeholder="URBAN2_2025"
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

	<!-- Sales Fetcher -->
	<div class="sales-section">
		<h3>📊 {t('erp.salesData') || 'Get Sales Data'}</h3>
		
		<div class="sales-controls">
			<div class="form-group">
				<label for="sales-branch">{t('erp.selectBranch') || 'Select Branch'}</label>
				<select id="sales-branch" bind:value={selectedBranch}>
					<option value={0}>Choose a branch...</option>
					{#each erpConfigs.filter(c => c.is_active) as config}
						<option value={config.branch_id}>{config.branch_name}</option>
					{/each}
				</select>
			</div>

			<div class="form-group">
				<label for="sales-date">{t('erp.selectDate') || 'Select Date'}</label>
				<input 
					id="sales-date"
					type="date" 
					bind:value={selectedDate}
				/>
			</div>

			<button 
				class="btn-fetch" 
				on:click={fetchSales}
				disabled={fetchingSales || !selectedBranch}
			>
				{fetchingSales ? `⏳ ${t('erp.fetching') || 'Fetching...'}` : `📥 ${t('erp.fetchSales') || 'Get Sales'}`}
			</button>
		</div>

		<!-- Sales Data Display -->
		{#if salesData}
			<div class="sales-results">
				<h4>📈 Sales Summary - {salesData.branch_name}</h4>
				<p class="sales-date">Date: {new Date(salesData.date).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
				
				<div class="sales-grid">
					<div class="sales-card gross">
						<h5>💰 {t('erp.grossSales') || 'Gross Sales'}</h5>
						<div class="amount">{formatCurrency(salesData.gross_sales)}</div>
						<div class="details">
							<span>{t('erp.grossBills') || 'Bills'}: {salesData.gross_bills}</span>
							<span>{t('erp.grossTax') || 'Tax'}: {formatCurrency(salesData.gross_tax)}</span>
							{#if salesData.discount > 0}
								<span>{t('erp.discount') || 'Discount'}: {formatCurrency(salesData.discount)}</span>
							{/if}
						</div>
					</div>

					<div class="sales-card returns">
						<h5>🔄 {t('erp.returns') || 'Returns'}</h5>
						<div class="amount">{formatCurrency(salesData.returns)}</div>
						<div class="details">
							<span>{t('erp.returnBills') || 'Bills'}: {salesData.return_bills}</span>
							<span>{t('erp.returnTax') || 'Tax'}: {formatCurrency(salesData.return_tax)}</span>
						</div>
					</div>

					<div class="sales-card net">
						<h5>✅ {t('erp.netSales') || 'Net Sales'}</h5>
						<div class="amount">{formatCurrency(salesData.net_sales)}</div>
						<div class="details">
							<span>{t('erp.netBills') || 'Net Bills'}: {salesData.net_bills}</span>
							<span>{t('erp.netTax') || 'Net Tax'}: {formatCurrency(salesData.net_tax)}</span>
						</div>
					</div>
				</div>

				<div class="sales-summary">
					<div class="summary-row">
						<span>Return Rate:</span>
						<span>{((salesData.return_bills / salesData.gross_bills) * 100).toFixed(2)}%</span>
					</div>
					<div class="summary-row">
						<span>Average Bill Value:</span>
						<span>{formatCurrency(salesData.net_sales / salesData.net_bills)}</span>
					</div>
				</div>
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

	.sales-section {
		background: white;
		border-radius: 8px;
		padding: 2rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.sales-section h3 {
		margin-top: 0;
		margin-bottom: 1.5rem;
		color: #333;
	}

	.sales-controls {
		display: grid;
		grid-template-columns: 1fr 1fr auto;
		gap: 1rem;
		margin-bottom: 2rem;
		align-items: end;
	}

	.btn-fetch {
		background: #9C27B0;
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 1rem;
		transition: all 0.3s ease;
	}

	.btn-fetch:hover:not(:disabled) {
		background: #7B1FA2;
	}

	.btn-fetch:disabled {
		background: #ccc;
		cursor: not-allowed;
	}

	.sales-results {
		margin-top: 2rem;
		padding: 2rem;
		background: #f9f9f9;
		border-radius: 8px;
	}

	.sales-results h4 {
		margin-top: 0;
		color: #1a1a1a;
	}

	.sales-date {
		color: #666;
		margin-bottom: 1.5rem;
		font-style: italic;
	}

	.sales-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.sales-card {
		background: white;
		border-radius: 8px;
		padding: 1.5rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.sales-card.gross {
		border-left: 4px solid #4CAF50;
	}

	.sales-card.returns {
		border-left: 4px solid #FF9800;
	}

	.sales-card.net {
		border-left: 4px solid #2196F3;
	}

	.sales-card h5 {
		margin: 0 0 1rem 0;
		color: #666;
		font-size: 0.9rem;
		text-transform: uppercase;
	}

	.sales-card .amount {
		font-size: 2rem;
		font-weight: bold;
		color: #1a1a1a;
		margin-bottom: 0.5rem;
	}

	.sales-card .details {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		color: #666;
		font-size: 0.9rem;
	}

	.sales-summary {
		background: white;
		border-radius: 8px;
		padding: 1rem;
		margin-top: 1rem;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem 0;
		border-bottom: 1px solid #f0f0f0;
	}

	.summary-row:last-child {
		border-bottom: none;
	}

	.summary-row span:first-child {
		font-weight: 500;
		color: #666;
	}

	.summary-row span:last-child {
		color: #1a1a1a;
		font-weight: 600;
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
