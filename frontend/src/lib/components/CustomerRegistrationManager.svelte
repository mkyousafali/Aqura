<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	// Component state
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Data
	let pendingRegistrations = [];
	let recentRegistrations = [];
	let accessCodeRequests = [];
	let currentUser = null;

	// Filters and pagination
	let searchTerm = '';
	let statusFilter = 'all'; // all, pending, approved, rejected
	let currentPage = 1;
	let itemsPerPage = 10;

	// Modals
	let showApprovalModal = false;
	let showShareModal = false;
	let showGenerateCodeModal = false;
	let selectedRegistration = null;
	let approvalNotes = '';
	let generatedAccessCode = '';
	let generateCodeNotes = '';

	onMount(async () => {
		await getCurrentUser();
		await loadRegistrations();
	});

	async function getCurrentUser() {
		const { data: { user } } = await supabase.auth.getUser();
		if (user) {
			const { data } = await supabase
				.from('users')
				.select('id, name, username')
				.eq('auth_user_id', user.id)
				.single();
			currentUser = data;
		}
	}

	async function loadRegistrations() {
		isLoading = true;
		errorMessage = '';

		try {
			await Promise.all([
				loadRegistrationsData(),
				loadAccessCodeRequests()
			]);
		} catch (error) {
			errorMessage = error.message || 'Failed to load data';
		} finally {
			isLoading = false;
		}
	}

	async function loadRegistrationsData() {
		const { data, error } = await supabase
			.from('customers')
			.select(`
					id,
					access_code,
					whatsapp_number,
					registration_status,
					registration_notes,
					created_at,
					approved_at,
					approved_by,
					last_login_at,
					users!inner(
						id,
						name,
						username,
						email,
						status
					),
					approved_by_user:users!customers_approved_by_fkey(
						name,
						username
					)
				`)
				.order('created_at', { ascending: false });

			if (error) throw error;

		const registrations = data || [];
		
		pendingRegistrations = registrations.filter(r => r.registration_status === 'pending');
		recentRegistrations = registrations.filter(r => r.registration_status !== 'pending');
	}

	async function loadAccessCodeRequests() {
		const { data, error } = await supabase
			.from('customers')
			.select(`
				id,
				access_code,
				whatsapp_number,
				last_access_code_request,
				access_code_request_count,
				users!inner(
					id,
					name,
					username,
					status
				)
			`)
			.not('last_access_code_request', 'is', null)
			.eq('registration_status', 'approved')
			.order('last_access_code_request', { ascending: false });

		if (error) throw error;
		accessCodeRequests = data || [];
	}	async function openApprovalModal(registration) {
		selectedRegistration = registration;
		approvalNotes = registration.registration_notes || '';
		generatedAccessCode = '';
		showApprovalModal = true;
	}

	async function approveRegistration() {
		if (!selectedRegistration || !currentUser) return;

		isLoading = true;
		errorMessage = '';

		try {
			const { data, error } = await supabase.rpc('approve_customer_registration', {
				customer_id: selectedRegistration.id,
				approved_by_id: currentUser.id,
				approval_notes: approvalNotes || null
			});

			if (error) throw error;

			generatedAccessCode = data.access_code;
			successMessage = 'Registration approved successfully!';
			
			await loadRegistrations();
			
			// Auto-open share modal after approval
			setTimeout(() => {
				closeApprovalModal();
				openShareModal(selectedRegistration);
			}, 1500);

		} catch (error) {
			errorMessage = error.message || 'Failed to approve registration';
		} finally {
			isLoading = false;
		}
	}

	async function rejectRegistration() {
		if (!selectedRegistration || !currentUser) return;

		isLoading = true;
		errorMessage = '';

		try {
			const { error } = await supabase
				.from('customers')
				.update({
					registration_status: 'rejected',
					approved_by: currentUser.id,
					approved_at: new Date().toISOString(),
					rejection_notes: approvalNotes || null
				})
				.eq('id', selectedRegistration.id);

			if (error) throw error;

			successMessage = 'Registration rejected';
			await loadRegistrations();
			closeApprovalModal();

			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to reject registration';
		} finally {
			isLoading = false;
		}
	}

	function openShareModal(registration) {
		selectedRegistration = registration;
		showShareModal = true;
	}

	function closeApprovalModal() {
		showApprovalModal = false;
		selectedRegistration = null;
		approvalNotes = '';
		generatedAccessCode = '';
	}

	function closeShareModal() {
		showShareModal = false;
		selectedRegistration = null;
	}

	async function shareViaWhatsApp(registration) {
		if (!registration?.whatsapp_number || !registration?.access_code) return;

		const phone = registration.whatsapp_number.replace(/\D/g, '');
		const customerName = registration.users?.name || 'Customer';
		const accessCode = registration.access_code;
		
		const message = encodeURIComponent(
			`🎉 Welcome to Aqura, ${customerName}!\n\n` +
			`Your account has been approved and your access code is:\n\n` +
			`*${accessCode}*\n\n` +
			`You can now log in to the customer portal using this 6-digit code.\n\n` +
			`Visit: ${window.location.origin}/login\n\n` +
			`Thank you for choosing Aqura! 🚀`
		);

		const whatsappUrl = `https://wa.me/${phone}?text=${message}`;
		window.open(whatsappUrl, '_blank');

		// Log the share action
		try {
			await supabase
				.from('customer_notifications')
				.insert({
					customer_id: registration.id,
					type: 'access_code_shared',
					title: 'Access Code Shared',
					message: 'Access code shared via WhatsApp',
					sent_by: currentUser?.id
				});
		} catch (error) {
			console.error('Failed to log share action:', error);
		}

		successMessage = 'WhatsApp message opened successfully!';
		setTimeout(() => {
			successMessage = '';
		}, 3000);
	}

	function copyAccessCode(accessCode) {
		navigator.clipboard.writeText(accessCode).then(() => {
			successMessage = 'Access code copied to clipboard!';
			setTimeout(() => {
				successMessage = '';
			}, 2000);
		}).catch(() => {
			errorMessage = 'Failed to copy access code';
			setTimeout(() => {
				errorMessage = '';
			}, 3000);
		});
	}

	function openGenerateCodeModal(registration) {
		selectedRegistration = registration;
		generateCodeNotes = '';
		generatedAccessCode = '';
		showGenerateCodeModal = true;
	}

	function closeGenerateCodeModal() {
		showGenerateCodeModal = false;
		selectedRegistration = null;
		generateCodeNotes = '';
		generatedAccessCode = '';
	}

	async function generateNewAccessCode() {
		if (!selectedRegistration || !currentUser) return;

		isLoading = true;
		errorMessage = '';

		try {
			const { data, error } = await supabase.rpc('generate_new_customer_access_code', {
				p_customer_id: selectedRegistration.id,
				p_admin_user_id: currentUser.id,
				p_notes: generateCodeNotes || null
			});

			if (error) throw error;

			if (data.success) {
				generatedAccessCode = data.new_access_code;
				successMessage = 'New access code generated successfully!';
				
				await loadRegistrations();
				
				setTimeout(() => {
					successMessage = '';
				}, 3000);
			} else {
				errorMessage = data.error;
			}

		} catch (error) {
			errorMessage = error.message || 'Failed to generate new access code';
		} finally {
			isLoading = false;
		}
	}

	// Filter and pagination logic
	$: filteredRegistrations = (() => {
		let filtered = [...pendingRegistrations, ...recentRegistrations];

		// Apply search filter
		if (searchTerm) {
			filtered = filtered.filter(reg => 
				reg.users?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				reg.users?.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				reg.whatsapp_number?.includes(searchTerm) ||
				reg.access_code?.includes(searchTerm.toUpperCase())
			);
		}

		// Apply status filter
		if (statusFilter !== 'all') {
			filtered = filtered.filter(reg => reg.registration_status === statusFilter);
		}

		return filtered;
	})();

	$: totalPages = Math.ceil(filteredRegistrations.length / itemsPerPage);
	$: paginatedRegistrations = filteredRegistrations.slice(
		(currentPage - 1) * itemsPerPage,
		currentPage * itemsPerPage
	);

	function formatDate(dateString) {
		if (!dateString) return 'Not set';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getStatusColor(status) {
		switch (status) {
			case 'pending': return 'text-yellow-600 bg-yellow-100';
			case 'approved': return 'text-green-600 bg-green-100';
			case 'rejected': return 'text-red-600 bg-red-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function getStatusIcon(status) {
		switch (status) {
			case 'pending': return '⏳';
			case 'approved': return '✅';
			case 'rejected': return '❌';
			default: return '❓';
		}
	}
</script>

<div class="customer-registration-manager">
	<div class="header">
		<h1>Customer Registration Manager</h1>
		<p>Review and approve customer registration requests</p>
	</div>

	<!-- Statistics Cards -->
	<div class="stats-grid">
		<div class="stat-card pending">
			<div class="stat-icon">⏳</div>
			<div class="stat-content">
				<div class="stat-number">{pendingRegistrations.length}</div>
				<div class="stat-label">Pending Approvals</div>
			</div>
		</div>
		<div class="stat-card approved">
			<div class="stat-icon">✅</div>
			<div class="stat-content">
				<div class="stat-number">{recentRegistrations.filter(r => r.registration_status === 'approved').length}</div>
				<div class="stat-label">Approved</div>
			</div>
		</div>
		<div class="stat-card rejected">
			<div class="stat-icon">❌</div>
			<div class="stat-content">
				<div class="stat-number">{recentRegistrations.filter(r => r.registration_status === 'rejected').length}</div>
				<div class="stat-label">Rejected</div>
			</div>
		</div>
		<div class="stat-card total">
			<div class="stat-icon">👥</div>
			<div class="stat-content">
				<div class="stat-number">{pendingRegistrations.length + recentRegistrations.length}</div>
				<div class="stat-label">Total Registrations</div>
			</div>
		</div>
		<div class="stat-card requests">
			<div class="stat-icon">🔑</div>
			<div class="stat-content">
				<div class="stat-number">{accessCodeRequests.length}</div>
				<div class="stat-label">Code Requests</div>
			</div>
		</div>
	</div>

	<!-- Controls -->
	<div class="controls">
		<div class="search-section">
			<div class="search-input-group">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="11" cy="11" r="8"/>
					<path d="M21 21l-4.35-4.35"/>
				</svg>
				<input 
					type="text" 
					placeholder="Search registrations..." 
					bind:value={searchTerm}
					class="search-input"
				/>
			</div>
		</div>

		<div class="filter-section">
			<select bind:value={statusFilter} class="status-filter">
				<option value="all">All Statuses</option>
				<option value="pending">Pending</option>
				<option value="approved">Approved</option>
				<option value="rejected">Rejected</option>
			</select>
		</div>

		<div class="action-section">
			<button class="refresh-btn" on:click={loadRegistrations} disabled={isLoading}>
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="23 4 23 10 17 10"/>
					<polyline points="1 20 1 14 7 14"/>
					<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"/>
				</svg>
				Refresh
			</button>
		</div>
	</div>

	<!-- Registration List -->
	<div class="registrations-container">
		{#if pendingRegistrations.length > 0}
			<div class="section-header">
				<h2>⏳ Pending Approvals ({pendingRegistrations.length})</h2>
			</div>
			<div class="registrations-grid">
				{#each pendingRegistrations as registration}
					<div class="registration-card pending">
						<div class="card-header">
							<div class="user-info">
								<div class="user-avatar">
									{registration.users?.name?.charAt(0)?.toUpperCase() || 'C'}
								</div>
								<div class="user-details">
									<div class="user-name">{registration.users?.name || 'Unknown'}</div>
									<div class="user-username">@{registration.users?.username || 'unknown'}</div>
								</div>
							</div>
							<div class="status-badge {getStatusColor(registration.registration_status)}">
								{getStatusIcon(registration.registration_status)} {registration.registration_status}
							</div>
						</div>

						<div class="card-content">
							<div class="info-row">
								<span class="info-label">WhatsApp:</span>
								<span class="info-value">{registration.whatsapp_number || 'Not provided'}</span>
							</div>
							<div class="info-row">
								<span class="info-label">Registered:</span>
								<span class="info-value">{formatDate(registration.created_at)}</span>
							</div>
							{#if registration.registration_notes}
								<div class="info-row notes">
									<span class="info-label">Notes:</span>
									<span class="info-value">{registration.registration_notes}</span>
								</div>
							{/if}
						</div>

						<div class="card-actions">
							<button 
								class="action-btn approve-btn"
								on:click={() => openApprovalModal(registration)}
								disabled={isLoading}
							>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M9 12l2 2 4-4"/>
									<circle cx="12" cy="12" r="10"/>
								</svg>
								Review
							</button>
						</div>
					</div>
				{/each}
			</div>
		{/if}

		{#if recentRegistrations.length > 0}
			<div class="section-header">
				<h2>📋 Recent Registrations ({recentRegistrations.length})</h2>
			</div>
			<div class="registrations-grid">
				{#each paginatedRegistrations.filter(r => r.registration_status !== 'pending') as registration}
					<div class="registration-card {registration.registration_status}">
						<div class="card-header">
							<div class="user-info">
								<div class="user-avatar">
									{registration.users?.name?.charAt(0)?.toUpperCase() || 'C'}
								</div>
								<div class="user-details">
									<div class="user-name">{registration.users?.name || 'Unknown'}</div>
									<div class="user-username">@{registration.users?.username || 'unknown'}</div>
								</div>
							</div>
							<div class="status-badge {getStatusColor(registration.registration_status)}">
								{getStatusIcon(registration.registration_status)} {registration.registration_status}
							</div>
						</div>

						<div class="card-content">
							{#if registration.access_code}
								<div class="info-row access-code-row">
									<span class="info-label">Access Code:</span>
									<div class="access-code-group">
										<code class="access-code">{registration.access_code}</code>
										<button 
											class="copy-btn"
											on:click={() => copyAccessCode(registration.access_code)}
											title="Copy access code"
										>
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
												<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
											</svg>
										</button>
									</div>
								</div>
							{/if}
							<div class="info-row">
								<span class="info-label">WhatsApp:</span>
								<span class="info-value">{registration.whatsapp_number || 'Not provided'}</span>
							</div>
							<div class="info-row">
								<span class="info-label">Approved:</span>
								<span class="info-value">{formatDate(registration.approved_at)}</span>
							</div>
							{#if registration.approved_by_user}
								<div class="info-row">
									<span class="info-label">Approved by:</span>
									<span class="info-value">{registration.approved_by_user.name}</span>
								</div>
							{/if}
							{#if registration.last_login_at}
								<div class="info-row">
									<span class="info-label">Last login:</span>
									<span class="info-value">{formatDate(registration.last_login_at)}</span>
								</div>
							{/if}
						</div>

						{#if registration.registration_status === 'approved' && registration.whatsapp_number}
							<div class="card-actions">
								<button 
									class="action-btn share-btn"
									on:click={() => openShareModal(registration)}
									disabled={isLoading}
								>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>
										<polyline points="16,6 12,2 8,6"/>
										<line x1="12" y1="2" x2="12" y2="15"/>
									</svg>
									Share Code
								</button>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}

		<!-- Empty State -->
		{#if filteredRegistrations.length === 0 && !isLoading}
			<div class="empty-state">
				<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
					<circle cx="8.5" cy="7" r="4"/>
					<line x1="20" y1="8" x2="20" y2="14"/>
					<line x1="23" y1="11" x2="17" y2="11"/>
				</svg>
				<h3>No registrations found</h3>
				<p>No customer registrations match your current filters</p>
			</div>
		{/if}

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="pagination">
				<button 
					class="pagination-btn"
					disabled={currentPage === 1}
					on:click={() => currentPage = Math.max(1, currentPage - 1)}
				>
					Previous
				</button>
				<span class="pagination-info">
					Page {currentPage} of {totalPages}
				</span>
				<button 
					class="pagination-btn"
					disabled={currentPage === totalPages}
					on:click={() => currentPage = Math.min(totalPages, currentPage + 1)}
				>
					Next
				</button>
			</div>
		{/if}
	</div>

	<!-- Access Code Requests -->
	{#if accessCodeRequests.length > 0}
		<div class="registrations-container">
			<div class="section-header">
				<h2>🔑 Access Code Requests ({accessCodeRequests.length})</h2>
			</div>
			<div class="registrations-grid">
				{#each accessCodeRequests as customer}
					<div class="registration-card request">
						<div class="card-header">
							<div class="user-info">
								<div class="user-avatar">
									{customer.users?.name?.charAt(0)?.toUpperCase() || 'C'}
								</div>
								<div class="user-details">
									<div class="user-name">{customer.users?.name || 'Unknown'}</div>
									<div class="user-username">@{customer.users?.username || 'unknown'}</div>
								</div>
							</div>
							<div class="status-badge requests">
								🔑 Code Request
							</div>
						</div>

						<div class="card-content">
							<div class="info-row">
								<span class="info-label">Current Code:</span>
								<div class="access-code-group">
									<code class="access-code">{customer.access_code}</code>
									<button 
										class="copy-btn"
										on:click={() => copyAccessCode(customer.access_code)}
										title="Copy access code"
									>
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
											<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
										</svg>
									</button>
								</div>
							</div>
							<div class="info-row">
								<span class="info-label">WhatsApp:</span>
								<span class="info-value">{customer.whatsapp_number || 'Not provided'}</span>
							</div>
							<div class="info-row">
								<span class="info-label">Last Request:</span>
								<span class="info-value">{formatDate(customer.last_access_code_request)}</span>
							</div>
							<div class="info-row">
								<span class="info-label">Request Count:</span>
								<span class="info-value">{customer.access_code_request_count || 0}</span>
							</div>
						</div>

						<div class="card-actions">
							<button 
								class="action-btn generate-btn"
								on:click={() => openGenerateCodeModal(customer)}
								disabled={isLoading}
							>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
								</svg>
								Generate New Code
							</button>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Status Messages -->
	{#if errorMessage}
		<div class="status-message error" role="alert">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="12" cy="12" r="10"/>
				<line x1="15" y1="9" x2="9" y2="15"/>
				<line x1="9" y1="9" x2="15" y2="15"/>
			</svg>
			{errorMessage}
		</div>
	{/if}

	{#if successMessage}
		<div class="status-message success" role="status">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M9 12l2 2 4-4"/>
				<circle cx="12" cy="12" r="10"/>
			</svg>
			{successMessage}
		</div>
	{/if}

	<!-- Loading Overlay -->
	{#if isLoading}
		<div class="loading-overlay">
			<div class="loading-spinner"></div>
		</div>
	{/if}
</div>

<!-- Approval Modal -->
{#if showApprovalModal && selectedRegistration}
	<div class="modal-overlay" on:click={closeApprovalModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Review Registration: {selectedRegistration.users?.name}</h3>
				<button class="modal-close" on:click={closeApprovalModal}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="modal-body">
				<div class="registration-details">
					<div class="detail-row">
						<span class="detail-label">Name:</span>
						<span class="detail-value">{selectedRegistration.users?.name || 'Unknown'}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Username:</span>
						<span class="detail-value">@{selectedRegistration.users?.username || 'unknown'}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">WhatsApp:</span>
						<span class="detail-value">{selectedRegistration.whatsapp_number || 'Not provided'}</span>
					</div>
					<div class="detail-row">
						<span class="detail-label">Registered:</span>
						<span class="detail-value">{formatDate(selectedRegistration.created_at)}</span>
					</div>
					{#if selectedRegistration.registration_notes}
						<div class="detail-row">
							<span class="detail-label">Registration Notes:</span>
							<span class="detail-value">{selectedRegistration.registration_notes}</span>
						</div>
					{/if}
				</div>

				<div class="approval-notes">
					<label for="approval-notes">Approval Notes (Optional):</label>
					<textarea 
						id="approval-notes"
						bind:value={approvalNotes}
						placeholder="Add any notes about this approval/rejection..."
						rows="3"
					></textarea>
				</div>

				{#if generatedAccessCode}
					<div class="generated-code">
						<div class="code-display">
							<span class="code-label">Generated Access Code:</span>
							<code class="access-code large">{generatedAccessCode}</code>
						</div>
						<p class="code-info">This access code has been generated and saved. The customer can use it to log in.</p>
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn btn-secondary" on:click={closeApprovalModal}>
					Cancel
				</button>
				<button 
					class="btn btn-danger" 
					on:click={rejectRegistration}
					disabled={isLoading}
				>
					Reject
				</button>
				<button 
					class="btn btn-success" 
					on:click={approveRegistration}
					disabled={isLoading}
				>
					Approve & Generate Code
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Share Modal -->
{#if showShareModal && selectedRegistration}
	<div class="modal-overlay" on:click={closeShareModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Share Access Code</h3>
				<button class="modal-close" on:click={closeShareModal}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="modal-body">
				<div class="share-details">
					<div class="customer-info">
						<div class="customer-avatar">
							{selectedRegistration.users?.name?.charAt(0)?.toUpperCase() || 'C'}
						</div>
						<div class="customer-details">
							<div class="customer-name">{selectedRegistration.users?.name}</div>
							<div class="customer-phone">{selectedRegistration.whatsapp_number}</div>
						</div>
					</div>

					<div class="access-code-display">
						<div class="code-label">Access Code:</div>
						<div class="code-group">
							<code class="access-code xlarge">{selectedRegistration.access_code}</code>
							<button 
								class="copy-btn large"
								on:click={() => copyAccessCode(selectedRegistration.access_code)}
								title="Copy access code"
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
									<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
								</svg>
							</button>
						</div>
					</div>
				</div>

				<div class="share-message-preview">
					<div class="preview-label">WhatsApp Message Preview:</div>
					<div class="message-preview">
						🎉 Welcome to Aqura, {selectedRegistration.users?.name || 'Customer'}!<br><br>
						Your account has been approved and your access code is:<br><br>
						<strong>{selectedRegistration.access_code}</strong><br><br>
						You can now log in to the customer portal using this 6-digit code.<br><br>
						Visit: {window.location.origin}/login<br><br>
						Thank you for choosing Aqura! 🚀
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn btn-secondary" on:click={closeShareModal}>
					Close
				</button>
				<button 
					class="btn btn-whatsapp" 
					on:click={() => shareViaWhatsApp(selectedRegistration)}
				>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
					</svg>
					Send via WhatsApp
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Generate Code Modal -->
{#if showGenerateCodeModal && selectedRegistration}
	<div class="modal-overlay" on:click={closeGenerateCodeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Generate New Access Code</h3>
				<button class="modal-close" on:click={closeGenerateCodeModal}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="modal-body">
				<div class="customer-details">
					<div class="customer-info">
						<div class="customer-avatar">
							{selectedRegistration.users?.name?.charAt(0)?.toUpperCase() || 'C'}
						</div>
						<div class="customer-details">
							<div class="customer-name">{selectedRegistration.users?.name}</div>
							<div class="customer-phone">{selectedRegistration.whatsapp_number}</div>
						</div>
					</div>

					<div class="current-code-display">
						<div class="code-label">Current Access Code:</div>
						<div class="code-group">
							<code class="access-code xlarge">{selectedRegistration.access_code}</code>
							<button 
								class="copy-btn large"
								on:click={() => copyAccessCode(selectedRegistration.access_code)}
								title="Copy current access code"
							>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
									<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
								</svg>
							</button>
						</div>
					</div>
				</div>

				<div class="generate-notes">
					<label for="generate-notes">Notes (Optional):</label>
					<textarea 
						id="generate-notes"
						bind:value={generateCodeNotes}
						placeholder="Reason for generating new access code..."
						rows="3"
					></textarea>
				</div>

				{#if generatedAccessCode}
					<div class="generated-code">
						<div class="code-display">
							<span class="code-label">New Access Code Generated:</span>
							<div class="code-group">
								<code class="access-code xlarge new">{generatedAccessCode}</code>
								<button 
									class="copy-btn large"
									on:click={() => copyAccessCode(generatedAccessCode)}
									title="Copy new access code"
								>
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
										<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
									</svg>
								</button>
							</div>
						</div>
						<p class="code-info">This new access code has been saved. The customer can now use it to log in.</p>
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn btn-secondary" on:click={closeGenerateCodeModal}>
					{generatedAccessCode ? 'Close' : 'Cancel'}
				</button>
				{#if !generatedAccessCode}
					<button 
						class="btn btn-primary" 
						on:click={generateNewAccessCode}
						disabled={isLoading}
					>
						{#if isLoading}
							<span class="loading-spinner"></span>
							Generating...
						{:else}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
							</svg>
							Generate New Code
						{/if}
					</button>
				{:else}
					<button 
						class="btn btn-whatsapp" 
						on:click={() => {
							const updatedRegistration = { ...selectedRegistration, access_code: generatedAccessCode };
							shareViaWhatsApp(updatedRegistration);
						}}
					>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
						</svg>
						Share New Code
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.customer-registration-manager {
		padding: 2rem;
		max-width: 1200px;
		margin: 0 auto;
		position: relative;
	}

	.header {
		margin-bottom: 2rem;
	}

	.header h1 {
		font-size: 2rem;
		font-weight: 700;
		color: #1E293B;
		margin-bottom: 0.5rem;
	}

	.header p {
		color: #64748B;
		font-size: 1rem;
	}

	/* Statistics Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
		margin-bottom: 2rem;
	}

	.stat-card {
		background: #FFFFFF;
		border-radius: 12px;
		padding: 1.5rem;
		border: 1px solid #E5E7EB;
		display: flex;
		align-items: center;
		gap: 1rem;
		transition: all 0.3s ease;
	}

	.stat-card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
	}

	.stat-card.pending {
		border-left: 4px solid #F59E0B;
	}

	.stat-card.approved {
		border-left: 4px solid #10B981;
	}

	.stat-card.rejected {
		border-left: 4px solid #EF4444;
	}

	.stat-card.total {
		border-left: 4px solid #6366F1;
	}

	.stat-card.requests {
		border-left: 4px solid #F59E0B;
	}

	.stat-icon {
		font-size: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 60px;
		height: 60px;
		background: #F8FAFC;
		border-radius: 50%;
	}

	.stat-content {
		flex: 1;
	}

	.stat-number {
		font-size: 2rem;
		font-weight: 700;
		color: #1E293B;
		line-height: 1;
	}

	.stat-label {
		color: #64748B;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	/* Controls */
	.controls {
		display: flex;
		gap: 1rem;
		margin-bottom: 2rem;
		align-items: center;
		background: #FFFFFF;
		padding: 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.search-section {
		flex: 1;
		max-width: 400px;
	}

	.search-input-group {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-input-group svg {
		position: absolute;
		left: 0.75rem;
		color: #9CA3AF;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 0.75rem 0.75rem 2.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: #FFFFFF;
		transition: all 0.3s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.filter-section {
		flex-shrink: 0;
	}

	.status-filter {
		padding: 0.75rem 1rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: #FFFFFF;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.status-filter:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.action-section {
		flex-shrink: 0;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #15A34A;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #166534;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Registrations Container */
	.registrations-container {
		background: #FFFFFF;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		overflow: hidden;
	}

	.section-header {
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1E293B;
		margin: 0;
	}

	/* Registration Cards */
	.registrations-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
		gap: 1rem;
		padding: 1.5rem;
	}

	.registration-card {
		background: #FFFFFF;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 1.5rem;
		transition: all 0.3s ease;
	}

	.registration-card:hover {
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.registration-card.pending {
		border-left: 4px solid #F59E0B;
	}

	.registration-card.approved {
		border-left: 4px solid #10B981;
	}

	.registration-card.rejected {
		border-left: 4px solid #EF4444;
	}

	.registration-card.request {
		border-left: 4px solid #F59E0B;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1rem;
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex: 1;
	}

	.user-avatar {
		width: 40px;
		height: 40px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		font-weight: 600;
		color: #1E293B;
		font-size: 0.875rem;
	}

	.user-username {
		color: #64748B;
		font-size: 0.75rem;
		margin-top: 0.125rem;
	}

	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: capitalize;
		flex-shrink: 0;
	}

	.card-content {
		margin-bottom: 1rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.5rem;
		gap: 0.5rem;
	}

	.info-row.notes {
		flex-direction: column;
		align-items: stretch;
		gap: 0.25rem;
	}

	.info-label {
		font-weight: 500;
		color: #64748B;
		font-size: 0.75rem;
		flex-shrink: 0;
	}

	.info-value {
		color: #1E293B;
		font-size: 0.75rem;
		text-align: right;
		word-break: break-word;
	}

	.info-row.notes .info-value {
		text-align: left;
		background: #F8FAFC;
		padding: 0.5rem;
		border-radius: 6px;
		font-style: italic;
	}

	.access-code-row {
		align-items: center;
	}

	.access-code-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.access-code {
		background: #F3F4F6;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-family: 'JetBrains Mono', monospace;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.access-code.large {
		font-size: 1.125rem;
		padding: 0.5rem 0.75rem;
	}

	.access-code.xlarge {
		font-size: 1.5rem;
		padding: 0.75rem 1rem;
		background: #F0FDF4;
		color: #15A34A;
		border: 2px solid #BBF7D0;
	}

	.access-code.xlarge.new {
		background: #FEF3C7;
		color: #D97706;
		border: 2px solid #FCD34D;
		animation: newCodePulse 1s ease-in-out;
	}

	@keyframes newCodePulse {
		0%, 100% { transform: scale(1); }
		50% { transform: scale(1.05); }
	}

	.copy-btn {
		background: #F1F5F9;
		border: none;
		padding: 0.25rem;
		border-radius: 4px;
		cursor: pointer;
		color: #64748B;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.copy-btn:hover {
		background: #E2E8F0;
		color: #475569;
	}

	.copy-btn.large {
		padding: 0.5rem;
	}

	.card-actions {
		display: flex;
		gap: 0.5rem;
	}

	.action-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		flex: 1;
		justify-content: center;
	}

	.approve-btn {
		background: #3B82F6;
		color: white;
	}

	.approve-btn:hover:not(:disabled) {
		background: #2563EB;
	}

	.share-btn {
		background: #10B981;
		color: white;
	}

	.share-btn:hover:not(:disabled) {
		background: #059669;
	}

	.generate-btn {
		background: #F59E0B;
		color: white;
	}

	.generate-btn:hover:not(:disabled) {
		background: #D97706;
	}

	.action-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Empty State */
	.empty-state {
		text-align: center;
		padding: 3rem 2rem;
		color: #64748B;
	}

	.empty-state svg {
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 1.125rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: #374151;
	}

	.empty-state p {
		font-size: 0.875rem;
	}

	/* Pagination */
	.pagination {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.pagination-btn {
		padding: 0.5rem 1rem;
		background: #FFFFFF;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		color: #374151;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #F9FAFB;
		border-color: #9CA3AF;
	}

	.pagination-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pagination-info {
		font-size: 0.875rem;
		color: #64748B;
	}

	/* Status Messages */
	.status-message {
		position: fixed;
		top: 2rem;
		right: 2rem;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.25rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		z-index: 1000;
		animation: slideInRight 0.3s ease-out;
	}

	@keyframes slideInRight {
		from {
			opacity: 0;
			transform: translateX(100%);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.status-message.error {
		background: #FEF2F2;
		border: 1px solid #FECACA;
		color: #DC2626;
	}

	.status-message.success {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		color: #16A34A;
	}

	/* Loading Overlay */
	.loading-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #E5E7EB;
		border-top: 4px solid #15A34A;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.modal-content {
		background: #FFFFFF;
		border-radius: 12px;
		width: 100%;
		max-width: 600px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.modal-header h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1E293B;
	}

	.modal-close {
		background: none;
		border: none;
		color: #64748B;
		cursor: pointer;
		padding: 0.25rem;
		border-radius: 4px;
		transition: all 0.3s ease;
	}

	.modal-close:hover {
		background: #F1F5F9;
		color: #374151;
	}

	.modal-body {
		padding: 1.5rem;
	}

	.registration-details {
		background: #F8FAFC;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1.5rem;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.75rem;
	}

	.detail-row:last-child {
		margin-bottom: 0;
	}

	.detail-label {
		font-weight: 500;
		color: #64748B;
		font-size: 0.875rem;
	}

	.detail-value {
		color: #1E293B;
		font-size: 0.875rem;
		text-align: right;
	}

	.approval-notes {
		margin-bottom: 1.5rem;
	}

	.approval-notes label {
		display: block;
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
		margin-bottom: 0.5rem;
	}

	.approval-notes textarea {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		resize: vertical;
		min-height: 80px;
	}

	.approval-notes textarea:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.generated-code {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 8px;
		padding: 1rem;
		text-align: center;
	}

	.code-display {
		margin-bottom: 0.75rem;
	}

	.code-label {
		font-weight: 500;
		color: #166534;
		font-size: 0.875rem;
		margin-bottom: 0.5rem;
		display: block;
	}

	.code-info {
		color: #16A34A;
		font-size: 0.75rem;
		margin: 0;
	}

	/* Share Modal Specific */
	.share-details {
		margin-bottom: 1.5rem;
	}

	.customer-info {
		display: flex;
		align-items: center;
		gap: 1rem;
		background: #F8FAFC;
		padding: 1rem;
		border-radius: 8px;
		margin-bottom: 1.5rem;
	}

	.customer-avatar {
		width: 50px;
		height: 50px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: 600;
		font-size: 1.125rem;
	}

	.customer-details {
		flex: 1;
	}

	.customer-name {
		font-weight: 600;
		color: #1E293B;
		font-size: 1rem;
	}

	.customer-phone {
		color: #64748B;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	.access-code-display {
		text-align: center;
	}

	.code-group {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		margin-top: 0.5rem;
	}

	.share-message-preview {
		margin-top: 1.5rem;
	}

	.preview-label {
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
		margin-bottom: 0.75rem;
	}

	.message-preview {
		background: #F8FAFC;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		padding: 1rem;
		font-size: 0.875rem;
		line-height: 1.6;
		color: #374151;
		font-family: system-ui, -apple-system, sans-serif;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		padding: 1.5rem;
		border-top: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.btn {
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		border: none;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn-secondary {
		background: #F1F5F9;
		color: #475569;
	}

	.btn-secondary:hover {
		background: #E2E8F0;
	}

	.btn-success {
		background: #10B981;
		color: white;
	}

	.btn-success:hover:not(:disabled) {
		background: #059669;
	}

	.btn-danger {
		background: #EF4444;
		color: white;
	}

	.btn-danger:hover:not(:disabled) {
		background: #DC2626;
	}

	.btn-whatsapp {
		background: #25D366;
		color: white;
	}

	.btn-whatsapp:hover {
		background: #22C55E;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.customer-registration-manager {
			padding: 1rem;
		}

		.stats-grid {
			grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		}

		.controls {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.search-section {
			max-width: none;
		}

		.registrations-grid {
			grid-template-columns: 1fr;
			padding: 1rem;
		}

		.registration-card {
			padding: 1rem;
		}

		.card-header {
			flex-direction: column;
			gap: 0.75rem;
			align-items: stretch;
		}

		.user-info {
			justify-content: flex-start;
		}

		.status-badge {
			align-self: flex-start;
		}

		.info-row {
			flex-direction: column;
			gap: 0.25rem;
		}

		.info-value {
			text-align: left;
		}

		.modal-content {
			margin: 1rem;
		}

		.modal-footer {
			flex-direction: column;
		}

		.btn {
			justify-content: center;
		}

		.status-message {
			position: relative;
			top: auto;
			right: auto;
			margin: 1rem 0;
		}
	}
</style>