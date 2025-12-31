<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { _ } from '$lib/i18n';

	interface Customer {
		id: string;
		name: string;
		access_code?: string;
		whatsapp_number: string;
		registration_status: 'pending' | 'approved' | 'rejected' | 'suspended';
		registration_notes?: string;
		approved_by?: string;
		approved_at?: string;
		access_code_generated_at?: string;
		last_access_code_request?: string;
		access_code_request_count?: number;
		access_code_regeneration_count?: number;
		rejection_notes?: string;
		last_login_at?: string;
		created_at: string;
		updated_at: string;
	}

	interface AccessCodeRequest {
		id: string;
		customer_id: string;
		whatsapp_number: string;
		customer_name: string;
		request_type: 'account_recovery' | 'access_code_request';
		verification_status: 'pending' | 'verified' | 'rejected' | 'processed';
		verification_notes?: string;
		processed_by?: string;
		processed_at?: string;
		created_at: string;
		updated_at: string;
	}

	interface AccessCode {
		id: string;
		customer_id: string;
		old_access_code?: string;
		new_access_code: string;
		generated_by: string;
		reason: string;
		notes?: string;
		created_at: string;
		customer?: {
			id: string;
			name: string;
		};
		generated_by_user?: {
			username: string;
		};
	}

	let customers: Customer[] = [];
	let accessCodeRequests: AccessCodeRequest[] = [];
	let accessCodes: AccessCode[] = [];
	let loading = true;
	let showGenerateModal = false;
	let selectedCustomer: Customer | null = null;
	let newAccessCode = '';
	let showResolvedRequests = false;
	let stats = {
		accessCodeRequests: 0,
		accountRecoveryRequests: 0,
		processedRequests: 0
	};

	onMount(() => {
		loadData();
	});

	async function loadData() {
		loading = true;
		try {
			await Promise.all([
				loadCustomers(),
				loadAccessCodeRequests(),
				loadAccessCodes(),
				loadStats()
			]);
		} catch (error) {
			console.error('Error loading recovery data:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load customer recovery data'
			});
		} finally {
			loading = false;
		}
	}

	async function loadCustomers() {
		const { data, error } = await supabase
			.from('customers')
			.select('*')
			.order('created_at', { ascending: false });

		if (error) {
			console.error('Error loading customers:', error);
			throw error;
		}

		customers = data || [];
	}

	async function loadAccessCodeRequests() {
		let query = supabase
			.from('customer_recovery_requests')
			.select('*');
			
		if (!showResolvedRequests) {
			query = query.eq('verification_status', 'pending');
		}
		
		const { data, error } = await query.order('created_at', { ascending: false });

		if (error) {
			console.error('Error loading access code requests:', error);
			throw error;
		}

		accessCodeRequests = data || [];
	}

	async function markAsResolved(requestId: string) {
		try {
			const { error } = await supabase
				.from('customer_recovery_requests')
				.update({
					verification_status: 'processed',
					processed_by: $currentUser?.id,
					processed_at: new Date().toISOString(),
					verification_notes: 'Marked as resolved by admin'
				})
				.eq('id', requestId);

			if (error) {
				console.error('Error marking request as resolved:', error);
				throw error;
			}

			notifications.add({
				type: 'success',
				message: 'Request marked as resolved successfully'
			});

			// Reload data to update the interface
			await loadData();
		} catch (error) {
			console.error('Error marking request as resolved:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to mark request as resolved: ' + (error.message || error)
			});
		}
	}

	async function loadAccessCodes() {
		const { data, error } = await supabase
			.from('customer_access_code_history')
			.select(`
				*,
				customer:customers(id, name),
				generated_by_user:users!customer_access_code_history_generated_by_fkey(username)
			`)
			.order('created_at', { ascending: false });

		if (error) {
			console.error('Error loading access codes:', error);
			throw error;
		}

		accessCodes = data || [];
	}

	async function loadStats() {
		const requestsStats = await supabase
			.from('customer_recovery_requests')
			.select('request_type, verification_status, created_at');

		const requests = requestsStats.data || [];

		// Get requests from last 7 days
		const oneWeekAgo = new Date();
		oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

		stats.accessCodeRequests = requests.filter(r => r.request_type === 'access_code_request' && r.verification_status === 'pending').length;
		stats.accountRecoveryRequests = requests.filter(r => r.request_type === 'account_recovery' && r.verification_status === 'pending').length;
		stats.processedRequests = requests.filter(r => 
			r.verification_status === 'processed' && 
			new Date(r.created_at) >= oneWeekAgo
		).length;
	}

	async function generateNewAccessCode(customer: Customer) {
		try {
			const { data, error } = await supabase.rpc('generate_new_customer_access_code', {
				p_customer_id: customer.id,
				p_admin_user_id: $currentUser?.id,
				p_notes: 'Access code regenerated via admin interface'
			});

			if (error) {
				console.error('Database error:', error);
				throw error;
			}

			console.log('Function result:', data);
			const result = data;
			if (result && result.success) {
				newAccessCode = result.access_code;
				selectedCustomer = customer;
				showGenerateModal = true;
				await loadData();
			} else {
				console.error('Function returned error:', result);
				throw new Error(result?.error || 'Unknown error occurred');
			}
		} catch (error) {
			console.error('Error generating access code:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to generate new access code: ' + (error.message || error)
			});
		}
	}

	function shareViaWhatsApp(customer: Customer, accessCode: string) {
		const customerName = customer.name;
		
		const message = `Hello ${customerName}!

Your Aqura customer login credentials:
• Name: ${customerName}
• Access Code: ${accessCode}

You can now login using these credentials on the customer portal.

Thank you for using Aqura!`;

		const whatsappUrl = `https://wa.me/${customer.whatsapp_number.replace(/\D/g, '')}?text=${encodeURIComponent(message)}`;
		window.open(whatsappUrl, '_blank');
	}

	function formatWhatsApp(number: string): string {
		const cleaned = number.replace(/\D/g, '');
		if (cleaned.length === 10) {
			return cleaned.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
		}
		return number;
	}

	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleString();
	}

	function closeModal() {
		showGenerateModal = false;
		selectedCustomer = null;
		newAccessCode = '';
	}

	// Helper functions
	function getCustomerName(customer: Customer): string {
		return customer.name || 'Unknown Customer';
	}

	function getCustomerUsername(customer: Customer): string {
		return customer.name || 'Unknown';
	}

	function getCustomerEmail(customer: Customer): string {
		return 'N/A'; // Email not available in current schema
	}

	function getRequestCustomerName(request: AccessCodeRequest): string {
		return request.customer_name || 'Unknown Customer';
	}

	function getRequestUsername(request: AccessCodeRequest): string {
		return request.customer_name || 'Unknown';
	}

	function getRequestWhatsApp(request: AccessCodeRequest): string {
		return request.whatsapp_number || '';
	}

	function getRequestCustomerId(request: AccessCodeRequest): string {
		return request.customer_id || '';
	}
</script>

<div class="customer-account-recovery-manager">
	<div class="header">
		<h2>{$_('admin.accountRecovery') || 'Customer Account Recovery Manager'}</h2>
		<div class="header-controls">
			<label class="toggle-container">
				<input 
					type="checkbox" 
					bind:checked={showResolvedRequests}
					on:change={loadData}
				/>
				<span class="toggle-label">{$_('common.showResolved') || 'Show Resolved Requests'}</span>
			</label>
			<button class="refresh-btn" on:click={loadData} disabled={loading}>
				{loading ? ($_('admin.loading') || 'Loading...') : ($_('common.refresh') || 'Refresh')}
			</button>
		</div>
	</div>

	<!-- Statistics Cards -->
	<div class="stats-grid">
		<div class="stat-card requests">
			<div class="stat-number">{stats.accountRecoveryRequests}</div>
			<div class="stat-label">{$_('admin.unresolvedAccountRecovery') || 'Pending Recovery Requests'}</div>
		</div>
		<div class="stat-card recovery">
			<div class="stat-number">{stats.accessCodeRequests}</div>
			<div class="stat-label">{$_('common.requests') || 'Access Code Requests'}</div>
		</div>
		<div class="stat-card processed">
			<div class="stat-number">{stats.processedRequests || 0}</div>
			<div class="stat-label">{$_('common.processedThisWeek') || 'Processed This Week'}</div>
		</div>
	</div>

	{#if loading}
		<div class="loading">{$_('admin.loading') || 'Loading customer data...'}</div>
	{:else}
		<!-- Account Recovery Requests -->
		{#if accessCodeRequests.filter(r => r.request_type === 'account_recovery').length > 0}
			<div class="section">
				<h3>🔐 {$_('admin.accountRecovery') || 'Account Recovery Requests'}</h3>
				<div class="table-container">
					<table class="requests-table">
						<thead>
							<tr>
								<th>{$_('admin.customer') || 'Customer'}</th>
								<th>{$_('admin.whatsapp') || 'WhatsApp'}</th>
								<th>{$_('common.time') || 'Request Time'}</th>
								<th>{$_('admin.status') || 'Status'}</th>
								<th>{$_('admin.actions') || 'Actions'}</th>
							</tr>
						</thead>
						<tbody>
							{#each accessCodeRequests.filter(r => r.request_type === 'account_recovery') as request}
								<tr class="recovery-request" class:resolved={request.verification_status === 'processed'}>
									<td>
										<div class="customer-info">
											<div class="name">{getRequestCustomerName(request)}</div>
											{#if request.verification_status === 'pending'}
												<span class="verification-badge">⚠️ {$_('common.verificationRequired') || 'Verification Required'}</span>
											{:else if request.verification_status === 'processed'}
												<span class="resolved-badge">✅ {$_('common.resolved') || 'Resolved'}</span>
											{/if}
										</div>
									</td>
									<td>{formatWhatsApp(getRequestWhatsApp(request))}</td>
									<td>{formatDate(request.created_at)}</td>
									<td>
										<span class="status-badge" 
											class:pending={request.verification_status === 'pending'}
											class:processed={request.verification_status === 'processed'}
										>
											{request.verification_status}
										</span>
									</td>
									<td>
										{#if request.verification_status === 'pending'}
											<div class="action-buttons">
												<button 
													class="contact-btn"
													on:click={() => {
														const whatsapp = getRequestWhatsApp(request);
														if (whatsapp) {
															const verifyMessage = `Hello! I received your account recovery request for Aqura customer portal. Could you please confirm your identity by telling me your full name and any other details you remember about your account?`;
															const whatsappUrl = `https://wa.me/${whatsapp.replace(/\D/g, '')}?text=${encodeURIComponent(verifyMessage)}`;
															window.open(whatsappUrl, '_blank');
														}
													}}
												>
													🔍 {$_('common.verifyIdentity') || 'Verify Identity'}
												</button>
												<button 
													class="share-btn"
													on:click={() => {
														const customerId = getRequestCustomerId(request);
														const customer = customers.find(c => c.id === customerId);
														if (customer && customer.access_code) {
															shareViaWhatsApp(customer, customer.access_code);
														} else if (customer) {
															generateNewAccessCode(customer);
														}
													}}
												>
													📤 {$_('common.generateShare') || 'Generate & Share Code'}
												</button>
												<button 
													class="resolve-btn"
													on:click={() => markAsResolved(request.id)}
												>
													✅ {$_('common.markResolved') || 'Mark as Resolved'}
												</button>
											</div>
										{:else}
											<span class="resolved-indicator">{$_('common.requestResolved') || 'Request resolved'}</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}

		<!-- Access Code Requests -->
		{#if accessCodeRequests.filter(r => r.request_type === 'access_code_request').length > 0}
			<div class="section">
				<h3>🔑 {$_('admin.customerAccountRecoveryManager.accessCodeRequests') || 'Access Code Requests'}</h3>
				<div class="table-container">
					<table class="requests-table">
						<thead>
							<tr>
								<th>{$_('admin.customer') || 'Customer'}</th>
								<th>{$_('admin.whatsapp') || 'WhatsApp'}</th>
								<th>{$_('common.time') || 'Request Time'}</th>
								<th>{$_('admin.status') || 'Status'}</th>
								<th>{$_('admin.actions') || 'Actions'}</th>
							</tr>
						</thead>
						<tbody>
							{#each accessCodeRequests.filter(r => r.request_type === 'access_code_request') as request}
								<tr class:resolved={request.verification_status === 'processed'}>
									<td>{getRequestCustomerName(request)}</td>
									<td>{formatWhatsApp(getRequestWhatsApp(request))}</td>
									<td>{formatDate(request.created_at)}</td>
									<td>
										<span class="status-badge" 
											class:pending={request.verification_status === 'pending'}
											class:processed={request.verification_status === 'processed'}
										>
											{request.verification_status}
										</span>
									</td>
									<td>
										{#if request.verification_status === 'pending'}
											<button 
												class="generate-btn"
												on:click={() => {
													const customerId = getRequestCustomerId(request);
													const customer = customers.find(c => c.id === customerId);
													if (customer) generateNewAccessCode(customer);
												}}
											>
												Generate New Code
											</button>
											<button 
												class="resolve-btn"
												on:click={() => markAsResolved(request.id)}
											>
												✅ {$_('common.markResolved') || 'Mark as Resolved'}
											</button>
										{:else}
											<span class="resolved-indicator">{$_('common.requestResolved') || 'Request resolved'}</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{/if}
</div>

<!-- Generate Access Code Modal -->
{#if showGenerateModal && selectedCustomer}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{$_('admin.customerAccountRecoveryManager.newAccessCodeGenerated') || 'New Access Code Generated'}</h3>
				<button class="close-btn" on:click={closeModal}>×</button>
			</div>
			<div class="modal-content">
				<div class="customer-details">
					<h4>{getCustomerName(selectedCustomer)}</h4>
					<p><strong>{$_('admin.customerAccountRecoveryManager.username') || 'Username'}:</strong> {getCustomerUsername(selectedCustomer)}</p>
					<p><strong>{$_('admin.whatsapp') || 'WhatsApp'}:</strong> {formatWhatsApp(selectedCustomer.whatsapp_number)}</p>
				</div>
				<div class="access-code-display">
					<label>{$_('admin.customerAccountRecoveryManager.newAccessCode') || 'New Access Code'}:</label>
					<div class="code-container">
						<code class="access-code">{newAccessCode}</code>
						<button 
							class="copy-btn"
							on:click={() => {
								navigator.clipboard.writeText(newAccessCode);
								notifications.add({
									type: 'success',
									message: $_('admin.customerAccountRecoveryManager.accessCodeCopied') || 'Access code copied to clipboard'
								});
							}}
						>
							📋 {$_('admin.customerAccountRecoveryManager.copy') || 'Copy'}
						</button>
					</div>
				</div>
				<div class="modal-actions">
					<button 
						class="whatsapp-share-btn"
						on:click={() => {
							shareViaWhatsApp(selectedCustomer, newAccessCode);
							closeModal();
						}}
					>
						📱 {$_('admin.customerAccountRecoveryManager.shareViaWhatsapp') || 'Share via WhatsApp'}
					</button>
					<button class="close-modal-btn" on:click={closeModal}>
						{$_('admin.customerAccountRecoveryManager.close') || 'Close'}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.customer-account-recovery-manager {
		padding: 20px;
		max-width: 1400px;
		margin: 0 auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 30px;
	}

	.header h2 {
		color: #2c3e50;
		font-size: 28px;
		margin: 0;
	}

	.header-controls {
		display: flex;
		align-items: center;
		gap: 20px;
	}

	.toggle-container {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
	}

	.toggle-container input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
	}

	.toggle-label {
		font-size: 14px;
		color: #5d6d7e;
		font-weight: 500;
		cursor: pointer;
		user-select: none;
	}

	.refresh-btn {
		background: #3498db;
		color: white;
		border: none;
		padding: 10px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
	}

	.refresh-btn:hover {
		background: #2980b9;
	}

	.refresh-btn:disabled {
		background: #bdc3c7;
		cursor: not-allowed;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
		margin-bottom: 30px;
	}

	.stat-card {
		background: white;
		padding: 20px;
		border-radius: 10px;
		box-shadow: 0 2px 10px rgba(0,0,0,0.1);
		text-align: center;
		border-left: 4px solid #3498db;
	}

	.stat-card.approved {
		border-left-color: #27ae60;
	}

	.stat-card.pending {
		border-left-color: #f39c12;
	}

	.stat-card.rejected {
		border-left-color: #e74c3c;
	}

	.stat-card.processed {
		border-left-color: #27ae60;
	}

	.stat-card.requests {
		border-left-color: #e74c3c;
	}

	.stat-card.recovery {
		border-left-color: #9b59b6;
	}

	.stat-number {
		font-size: 36px;
		font-weight: bold;
		color: #2c3e50;
		margin-bottom: 5px;
	}

	.stat-label {
		color: #7f8c8d;
		font-size: 14px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.section {
		margin-bottom: 40px;
	}

	.section h3 {
		color: #2c3e50;
		margin-bottom: 20px;
		font-size: 22px;
		border-bottom: 2px solid #ecf0f1;
		padding-bottom: 10px;
	}

	.table-container {
		background: white;
		border-radius: 10px;
		overflow: hidden;
		box-shadow: 0 2px 10px rgba(0,0,0,0.1);
	}

	.requests-table, .customers-table {
		width: 100%;
		border-collapse: collapse;
	}

	.requests-table th, .customers-table th {
		background: #34495e;
		color: white;
		padding: 15px;
		text-align: left;
		font-weight: 600;
	}

	.requests-table td, .customers-table td {
		padding: 15px;
		border-bottom: 1px solid #ecf0f1;
		vertical-align: middle;
	}

	.requests-table tr:hover, .customers-table tr:hover {
		background: #f8f9fa;
	}

	.recovery-request {
		background: #fef7e0;
	}

	.recovery-request:hover {
		background: #fef0cd;
	}

	.recovery-request.resolved {
		background: #f0f9ff;
		opacity: 0.7;
	}

	.recovery-request.resolved:hover {
		background: #e0f2fe;
		opacity: 0.8;
	}

	.resolved {
		background: #f0f9ff !important;
		opacity: 0.7;
	}

	.resolved:hover {
		background: #e0f2fe !important;
		opacity: 0.8;
	}

	.customer-info {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.customer-info .name {
		font-weight: 600;
		color: #2c3e50;
	}

	.verification-badge {
		background: #f39c12;
		color: white;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		align-self: flex-start;
	}

	.resolved-badge {
		background: #27ae60;
		color: white;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		align-self: flex-start;
	}

	.resolved-indicator {
		color: #27ae60;
		font-style: italic;
		font-size: 14px;
	}

	.status-badge {
		padding: 6px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-badge.approved {
		background: #d5edda;
		color: #155724;
	}

	.status-badge.pending {
		background: #fff3cd;
		color: #856404;
	}

	.status-badge.rejected {
		background: #f8d7da;
		color: #721c24;
	}

	.status-badge.processed {
		background: #d1ecf1;
		color: #0c5460;
	}

	.request-count {
		background: #e9ecef;
		padding: 4px 8px;
		border-radius: 12px;
		font-weight: 600;
		font-size: 12px;
	}

	.request-count.high {
		background: #f8d7da;
		color: #721c24;
	}

	.action-buttons {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	.approve-btn, .generate-btn, .contact-btn, .share-btn, .resolve-btn {
		padding: 8px 16px;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.approve-btn {
		background: #27ae60;
		color: white;
	}

	.approve-btn:hover {
		background: #229954;
	}

	.generate-btn {
		background: #3498db;
		color: white;
	}

	.generate-btn:hover {
		background: #2980b9;
	}

	.contact-btn {
		background: #f39c12;
		color: white;
	}

	.contact-btn:hover {
		background: #e67e22;
	}

	.share-btn {
		background: #27ae60;
		color: white;
	}

	.share-btn:hover {
		background: #229954;
	}

	.resolve-btn {
		background: #8e44ad;
		color: white;
	}

	.resolve-btn:hover {
		background: #7d3c98;
	}

	.pending {
		background: #fef9e7;
	}

	.rejected {
		background: #fdf2f2;
	}

	.loading {
		text-align: center;
		padding: 60px;
		color: #7f8c8d;
		font-size: 18px;
	}

	.no-requests {
		text-align: center;
		padding: 40px;
		background: white;
		border-radius: 10px;
		box-shadow: 0 2px 10px rgba(0,0,0,0.1);
	}

	.no-requests h3 {
		color: #2c3e50;
		margin-bottom: 10px;
	}

	.no-requests p {
		color: #7f8c8d;
		font-style: italic;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal {
		background: white;
		border-radius: 10px;
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #ecf0f1;
	}

	.modal-header h3 {
		margin: 0;
		color: #2c3e50;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		cursor: pointer;
		color: #7f8c8d;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		color: #2c3e50;
	}

	.modal-content {
		padding: 20px;
	}

	.customer-details {
		margin-bottom: 20px;
		padding: 15px;
		background: #f8f9fa;
		border-radius: 8px;
	}

	.customer-details h4 {
		margin: 0 0 10px 0;
		color: #2c3e50;
	}

	.customer-details p {
		margin: 5px 0;
		color: #5d6d7e;
	}

	.access-code-display {
		margin-bottom: 20px;
	}

	.access-code-display label {
		display: block;
		margin-bottom: 8px;
		font-weight: 600;
		color: #2c3e50;
	}

	.code-container {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.access-code {
		background: #2c3e50;
		color: #ecf0f1;
		padding: 15px 20px;
		border-radius: 8px;
		font-size: 24px;
		font-weight: bold;
		letter-spacing: 2px;
		flex: 1;
		text-align: center;
	}

	.copy-btn {
		background: #95a5a6;
		color: white;
		border: none;
		padding: 10px 15px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 12px;
	}

	.copy-btn:hover {
		background: #7f8c8d;
	}

	.modal-actions {
		display: flex;
		gap: 10px;
		justify-content: flex-end;
	}

	.whatsapp-share-btn {
		background: #25d366;
		color: white;
		border: none;
		padding: 12px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
	}

	.whatsapp-share-btn:hover {
		background: #128c7e;
	}

	.close-modal-btn {
		background: #95a5a6;
		color: white;
		border: none;
		padding: 12px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
	}

	.close-modal-btn:hover {
		background: #7f8c8d;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.customer-account-recovery-manager {
			padding: 15px;
		}

		.stats-grid {
			grid-template-columns: 1fr;
		}

		.table-container {
			overflow-x: auto;
		}

		.requests-table, .customers-table {
			min-width: 800px;
		}

		.modal {
			width: 95%;
			margin: 10px;
		}

		.action-buttons {
			flex-direction: column;
		}

		.modal-actions {
			flex-direction: column;
		}
	}
</style>
