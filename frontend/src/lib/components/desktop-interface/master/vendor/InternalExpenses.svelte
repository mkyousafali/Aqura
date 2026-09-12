<script lang="ts">
	import { onMount } from 'svelte';
	import { t, currentLocale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notificationService } from '$lib/utils/notificationManagement';

	type Tab = 'request' | 'myRequests' | 'allRequests' | 'approvers';
	let activeTab: Tab = 'request';

	// Approvers Control is restricted to Master Admin users only.
	$: isMasterAdmin = $currentUser?.isMasterAdmin === true;

	// If permissions change while this tab is active, fall back to a visible tab
	// rather than leaving a non-master-admin user stranded on a hidden panel.
	$: if (activeTab === 'approvers' && !isMasterAdmin) {
		activeTab = 'request';
	}

	// ─────────────────────────────────────────────────────────────────
	// Branch dropdown data — reuses the same `branches` table/query already
	// used by Action Follow-Ups / Start Receiving. No new schema involved.
	// ─────────────────────────────────────────────────────────────────
	let branches: any[] = [];
	let branchesLoading = false;

	async function loadBranches() {
		branchesLoading = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			branchesLoading = false;
		}
	}

	function branchLabel(b: any): string {
		const name = $currentLocale === 'ar' ? (b.name_ar || b.name_en) : b.name_en;
		const location = $currentLocale === 'ar' ? (b.location_ar || b.location_en) : b.location_en;
		return location ? `${name} - ${location}` : name;
	}

	function nextLocalId(): string {
		return typeof crypto !== 'undefined' && 'randomUUID' in crypto
			? crypto.randomUUID()
			: `local-${Date.now()}-${Math.random().toString(36).slice(2)}`;
	}

	function formatDateTime(iso: string): string {
		try {
			return new Date(iso).toLocaleString($currentLocale === 'ar' ? 'ar' : 'en-US', {
				year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
			});
		} catch {
			return iso;
		}
	}

	function statusLabel(status: string): string {
		if (status === 'approved') return t('internalExpenses.approvedStatus') || 'Approved';
		if (status === 'rejected') return t('internalExpenses.rejectedStatus') || 'Rejected';
		return t('internalExpenses.requestedForApproval') || 'Requested for Approval';
	}

	// ─────────────────────────────────────────────────────────────────
	// Internal consumption requests — backed by internal_expense_requests /
	// internal_expense_request_items via RPCs (create/get/approve/reject).
	// ─────────────────────────────────────────────────────────────────
	interface RequestItem {
		id: number;
		photo_url: string;
		quantity: number;
	}

	interface ConsumptionRequest {
		id: number;
		branch_id: number;
		branch_name: string;
		expense_category?: string;
		custom_expense_category?: string;
		requester_id: string;
		requester_name: string;
		status: 'requested' | 'approved' | 'rejected';
		approved_by_name?: string;
		rejected_by_name?: string;
		rejection_reason?: string;
		created_at: string;
		items: RequestItem[];
	}

	let requests: ConsumptionRequest[] = [];
	let requestsLoading = false;

	async function loadRequests() {
		requestsLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_internal_expense_requests');
			if (error) throw error;
			if (data?.success) requests = data.data || [];
		} catch (err) {
			console.error('Error loading internal expense requests:', err);
		} finally {
			requestsLoading = false;
		}
	}

	onMount(() => {
		loadBranches();
		loadRequests();
		loadApprovers();
	});

	// ── Add Request popup ──
	let showAddModal = false;
	let modalBranchId = '';
	const expenseCategories = ['Mess Room', 'Office', 'Cleaning', 'Guest', 'Cheese Section', 'Vegetable Section', 'Bakery Section', 'Showroom', 'Other'];
	let modalExpenseCategory = '';
	let modalCustomExpenseCategory = '';
	$: hasValidExpenseCategory = !!modalExpenseCategory && (modalExpenseCategory !== 'Other' || !!modalCustomExpenseCategory.trim());
	let pendingProducts: { id: string; file: File; photoDataUrl: string; quantity: number }[] = [];

	// Fields for the single product entry currently being filled in.
	let currentPhotoFile: File | null = null;
	let currentPhotoDataUrl = '';
	let currentQuantity = '';
	let productError = '';
	let saveError = '';
	let saving = false;

	function openAddModal() {
		modalBranchId = '';
		modalExpenseCategory = '';
		modalCustomExpenseCategory = '';
		pendingProducts = [];
		currentPhotoFile = null;
		currentPhotoDataUrl = '';
		currentQuantity = '';
		productError = '';
		saveError = '';
		showAddModal = true;
		loadBranches();
	}

	function closeAddModal() {
		if (saving) return;
		showAddModal = false;
	}

	function handlePhotoChange(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		currentPhotoFile = file;
		const reader = new FileReader();
		reader.onload = () => {
			currentPhotoDataUrl = reader.result as string;
		};
		reader.readAsDataURL(file);
		input.value = '';
	}

	function clearCurrentPhoto() {
		currentPhotoFile = null;
		currentPhotoDataUrl = '';
	}

	// Commits the in-progress photo+quantity entry into pendingProducts.
	// Returns false (and sets productError) only when there's a genuinely
	// invalid entry blocking progress; an untouched, empty entry is not an
	// error — it just means there's nothing new to add right now.
	function commitCurrentEntry(): boolean {
		productError = '';
		if (!hasValidExpenseCategory) {
			productError = 'Please select an expense category before adding products.';
			return false;
		}
		if (!currentPhotoFile && !currentQuantity) return true;

		if (!currentPhotoFile) {
			productError = t('internalExpenses.errPhotoRequired') || 'Please add a barcode photo.';
			return false;
		}
		const qty = parseFloat(currentQuantity);
		if (!currentQuantity || isNaN(qty) || qty <= 0) {
			productError = t('internalExpenses.errQuantityRequired') || 'Please enter a valid quantity.';
			return false;
		}

		pendingProducts = [
			...pendingProducts,
			{ id: nextLocalId(), file: currentPhotoFile, photoDataUrl: currentPhotoDataUrl, quantity: qty }
		];

		// Reset the entry fields so another product can be added — a single
		// request can hold an unlimited number of products.
		currentPhotoFile = null;
		currentPhotoDataUrl = '';
		currentQuantity = '';
		return true;
	}

	function addProductToList() {
		commitCurrentEntry();
	}

	function removePendingProduct(id: string) {
		pendingProducts = pendingProducts.filter(p => p.id !== id);
	}

	async function normalizePhotoForUpload(file: File): Promise<{ blob: Blob; extension: string; contentType: string }> {
		const supportedTypes: Record<string, string> = {
			'image/jpeg': 'jpg',
			'image/png': 'png',
			'image/webp': 'webp',
			'image/gif': 'gif'
		};
		if (supportedTypes[file.type]) {
			return { blob: file, extension: supportedTypes[file.type], contentType: file.type };
		}

		// Storage rejects formats such as image/x-icon. If the browser can
		// display the selected image, render it to a real PNG before uploading.
		const objectUrl = URL.createObjectURL(file);
		try {
			const image = await new Promise<HTMLImageElement>((resolve, reject) => {
				const img = new Image();
				img.onload = () => resolve(img);
				img.onerror = () => reject(new Error(`Unsupported image format: ${file.type || 'unknown'}`));
				img.src = objectUrl;
			});
			const canvas = document.createElement('canvas');
			canvas.width = image.naturalWidth || image.width;
			canvas.height = image.naturalHeight || image.height;
			const context = canvas.getContext('2d');
			if (!context || !canvas.width || !canvas.height) throw new Error('Could not process the selected image.');
			context.drawImage(image, 0, 0);
			const blob = await new Promise<Blob>((resolve, reject) => {
				canvas.toBlob(result => result ? resolve(result) : reject(new Error('Could not convert the selected image.')), 'image/png');
			});
			return { blob, extension: 'png', contentType: 'image/png' };
		} finally {
			URL.revokeObjectURL(objectUrl);
		}
	}

	async function uploadProductPhoto(file: File, index: number): Promise<string | null> {
		try {
			const normalized = await normalizePhotoForUpload(file);
			const fileName = `${Date.now()}-${index}-${Math.random().toString(36).slice(2)}.${normalized.extension}`;
			const { error } = await supabase.storage
				.from('internal-expense-photos')
				.upload(fileName, normalized.blob, { cacheControl: '3600', contentType: normalized.contentType, upsert: false });
			if (error) throw error;
			const { data } = supabase.storage.from('internal-expense-photos').getPublicUrl(fileName);
			return data.publicUrl;
		} catch (err) {
			console.error('Error uploading barcode photo:', err);
			return null;
		}
	}

	async function saveRequest() {
		saveError = '';
		if (!modalBranchId) {
			saveError = t('internalExpenses.errBranchRequired') || 'Please select a branch.';
			return;
		}
		if (!hasValidExpenseCategory) {
			saveError = modalExpenseCategory === 'Other'
				? 'Please enter the custom expense category.'
				: 'Please select an expense category.';
			return;
		}
		// Auto-commit a filled-in-but-not-yet-added entry so clicking Save
		// directly (without a separate "+ Add Product" click) still works.
		if (!commitCurrentEntry()) return;
		if (pendingProducts.length === 0) {
			saveError = t('internalExpenses.errNoProducts') || 'Please add at least one product.';
			return;
		}
		if (!$currentUser?.id) {
			saveError = 'Your session could not be verified. Please sign in again.';
			return;
		}

		saving = true;
		try {
			const uploaded = await Promise.all(pendingProducts.map((p, i) => uploadProductPhoto(p.file, i)));
			if (uploaded.some(url => !url)) {
				saveError = 'One or more photos failed to upload. Please try again.';
				return;
			}

			const branch = branches.find(b => b.id.toString() === modalBranchId);
			const items = uploaded.map((url, i) => ({ photo_url: url, quantity: pendingProducts[i].quantity }));

			const { data, error } = await supabase.rpc('create_internal_expense_request', {
				p_branch_id: parseInt(modalBranchId, 10),
				p_branch_name: branch ? branchLabel(branch) : modalBranchId,
				p_requester_id: $currentUser.id,
				p_requester_name: $currentUser.username || '—',
				p_expense_category: modalExpenseCategory,
				p_custom_expense_category: modalExpenseCategory === 'Other' ? modalCustomExpenseCategory.trim() : null,
				p_items: items
			});
			if (error) throw error;
			if (data && !data.success) {
				saveError = data.error || 'Failed to save request.';
				return;
			}

			showAddModal = false;
			await loadRequests();

			const newRequest = requests.find(r => r.id === data.data.id);
			if (newRequest) notifyApproversOfNewRequest(newRequest);
		} catch (err: any) {
			saveError = err.message || 'Failed to save request.';
		} finally {
			saving = false;
		}
	}

	// ── Photo viewer (Previous / Next through a request's product photos) ──
	let showPhotoViewer = false;
	let viewerItems: RequestItem[] = [];
	let viewerIndex = 0;

	function openPhotoViewer(request: ConsumptionRequest) {
		viewerItems = request.items;
		viewerIndex = 0;
		showPhotoViewer = true;
	}

	function closePhotoViewer() {
		showPhotoViewer = false;
	}

	function prevPhoto() {
		if (viewerIndex > 0) viewerIndex -= 1;
	}

	function nextPhoto() {
		if (viewerIndex < viewerItems.length - 1) viewerIndex += 1;
	}

	// ─────────────────────────────────────────────────────────────────
	// Approvers Control — who may send / approve internal consumption
	// requests, and for which branches. Backed by internal_expense_approvers
	// via RPCs (get/save/delete).
	// ─────────────────────────────────────────────────────────────────
	interface ApproverConfig {
		id: number;
		user_id: string;
		user_name: string;
		can_send_request: boolean;
		can_approve_request: boolean;
		branch_permission: 'all' | 'selected';
		selected_branches: string[];
	}

	let approvers: ApproverConfig[] = [];
	let approversLoading = false;

	async function loadApprovers() {
		approversLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_internal_expense_approvers');
			if (error) throw error;
			if (data?.success) approvers = data.data || [];
		} catch (err) {
			console.error('Error loading internal expense approvers:', err);
		} finally {
			approversLoading = false;
		}
	}

	// Does the current user have Approvers-Control-granted permission to
	// send requests? Master admins always can.
	$: canSendRequest = isMasterAdmin || approvers.some(a => a.user_id === $currentUser?.id && a.can_send_request);

	function myApproverConfig(): ApproverConfig | undefined {
		return approvers.find(a => a.user_id === $currentUser?.id);
	}

	// View-only permission check — does NOT grant the ability to approve/reject.
	// Approving and rejecting happens exclusively in the existing Approval
	// Center (desktop + mobile), which enforces this same eligibility
	// server-side via get_pending_internal_expense_approvals.
	function canViewBranch(branchId: number): boolean {
		if (isMasterAdmin) return true;
		const cfg = myApproverConfig();
		if (!cfg || !cfg.can_approve_request) return false;
		return cfg.branch_permission === 'all' || (cfg.selected_branches || []).map(String).includes(branchId.toString());
	}

	$: myRequests = requests.filter(r => r.requester_id === $currentUser?.id);

	// "All Requests" is a read-only oversight view — master admins see
	// everything, configured approvers see the branches they cover, and
	// everyone else sees nothing here (they still have "My Requests").
	// It never exposes approve/reject actions; those live in Approval Center.
	$: visibleAllRequests = isMasterAdmin ? requests : requests.filter(r => canViewBranch(r.branch_id));

	// ── Add / Edit Approver popup ──
	let showApproverModal = false;
	let editingApproverId: number | null = null;
	let approverUsers: any[] = [];
	let approverUsersLoading = false;
	let approverUserSearch = '';
	let selectedApproverUser: any = null;
	let modalCanSend = false;
	let modalCanApprove = false;
	let modalBranchScope: 'all' | 'selected' = 'all';
	let modalSelectedBranches: string[] = [];
	let approverError = '';
	let approverSaving = false;

	$: approverFilteredUsers = approverUserSearch
		? approverUsers.filter((u: any) => (u.name_en || '').toLowerCase().includes(approverUserSearch.toLowerCase()))
		: approverUsers;

	// Same eligible-user source as Action Follow-Ups' approver picker —
	// active employees who have a linked login (user_id).
	async function loadApproverUsers() {
		approverUsersLoading = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master_with_status')
				.select('user_id, id, name_en')
				.in('employment_status', ['Job (With Finger)', 'Remote Job'])
				.order('name_en');
			if (error) throw error;
			approverUsers = (data || []).filter((u: any) => u.user_id);
		} catch (err) {
			console.error('Error loading users:', err);
		} finally {
			approverUsersLoading = false;
		}
	}

	function openApproverModal(existing?: ApproverConfig) {
		approverError = '';
		approverUserSearch = '';
		if (existing) {
			editingApproverId = existing.id;
			selectedApproverUser = { user_id: existing.user_id, name_en: existing.user_name };
			modalCanSend = existing.can_send_request;
			modalCanApprove = existing.can_approve_request;
			modalBranchScope = existing.branch_permission;
			modalSelectedBranches = [...(existing.selected_branches || [])].map(String);
		} else {
			editingApproverId = null;
			selectedApproverUser = null;
			modalCanSend = false;
			modalCanApprove = false;
			modalBranchScope = 'all';
			modalSelectedBranches = [];
		}
		showApproverModal = true;
		loadApproverUsers();
		loadBranches();
	}

	function closeApproverModal() {
		if (approverSaving) return;
		showApproverModal = false;
	}

	function selectApproverUser(u: any) { selectedApproverUser = u; }
	function clearApproverUser() { selectedApproverUser = null; approverUserSearch = ''; }

	function toggleModalBranch(bid: string) {
		modalSelectedBranches = modalSelectedBranches.includes(bid)
			? modalSelectedBranches.filter(b => b !== bid)
			: [...modalSelectedBranches, bid];
	}

	async function saveApprover() {
		approverError = '';
		if (!selectedApproverUser) {
			approverError = t('internalExpenses.errSelectUser') || 'Please select a user.';
			return;
		}
		if (!modalCanSend && !modalCanApprove) {
			approverError = t('internalExpenses.errSelectPermission') || 'Please enable at least one permission.';
			return;
		}
		if (modalCanApprove && modalBranchScope === 'selected' && modalSelectedBranches.length === 0) {
			approverError = t('internalExpenses.errSelectBranches') || 'Please select at least one branch.';
			return;
		}

		approverSaving = true;
		try {
			const { data, error } = await supabase.rpc('save_internal_expense_approver', {
				p_user_id: selectedApproverUser.user_id,
				p_user_name: selectedApproverUser.name_en,
				p_can_send_request: modalCanSend,
				p_can_approve_request: modalCanApprove,
				p_branch_permission: modalCanApprove ? modalBranchScope : 'all',
				p_selected_branches: modalCanApprove && modalBranchScope === 'selected' ? modalSelectedBranches.map(String) : [],
				p_created_by: $currentUser?.id || null
			});
			if (error) throw error;
			if (data && !data.success) {
				approverError = data.error || 'Failed to save approver.';
				return;
			}
			showApproverModal = false;
			await loadApprovers();
		} catch (err: any) {
			approverError = err.message || 'Failed to save approver.';
		} finally {
			approverSaving = false;
		}
	}

	async function removeApprover(id: number) {
		try {
			const { error } = await supabase.rpc('delete_internal_expense_approver', { p_id: id });
			if (error) throw error;
			await loadApprovers();
		} catch (err) {
			console.error('Error removing approver:', err);
		}
	}

	function approverBranchSummary(a: ApproverConfig): string {
		if (a.branch_permission === 'all') return t('internalExpenses.allBranchesLabel') || 'All Branches';
		return (a.selected_branches || []).map(bid => {
			const b = branches.find(br => br.id.toString() === bid.toString());
			return b ? branchLabel(b) : bid;
		}).join(', ');
	}

	// ─────────────────────────────────────────────────────────────────
	// Approval notifications — routed through the existing, live
	// notification service (same call used by Action Follow-Ups'
	// PO approval notifications), so these reach the real Notification
	// Center / push channel already used across the app.
	// ─────────────────────────────────────────────────────────────────
	async function notifyApproversOfNewRequest(req: ConsumptionRequest) {
		try {
			const eligible = approvers.filter(a =>
				a.can_approve_request && (a.branch_permission === 'all' || (a.selected_branches || []).map(String).includes(req.branch_id.toString()))
			);
			if (eligible.length === 0) return;

			const productCount = req.items.length;
			await notificationService.createNotification({
				title: 'Internal Consumption Request Approval',
				message: `${req.requester_name} submitted an internal consumption request for ${req.branch_name} (${productCount} product${productCount === 1 ? '' : 's'}). Please review and approve.`,
				type: 'approval_request',
				priority: 'high',
				target_type: 'specific_users',
				target_users: eligible.map(a => a.user_id)
			}, $currentUser?.id || '');
		} catch (err) {
			console.error('Error sending internal expense approval notification:', err);
		}
	}

	// Note: there is deliberately no approve/reject logic in this component.
	// Approving and rejecting internal consumption requests — and notifying
	// the requester of that decision — happens exclusively through the
	// existing Approval Center (desktop + mobile), using the same
	// approve_internal_expense_request / reject_internal_expense_request
	// RPCs. This component only ever creates requests and displays them.
</script>

<div class="internal-expenses-container">
	<!-- Tab Bar -->
	<div class="tab-bar">
		<button class="tab-btn" class:active={activeTab === 'request'} on:click={() => activeTab = 'request'}>
			{t('internalExpenses.requestTab') || 'Request Internal Consumption'}
		</button>
		<button class="tab-btn" class:active={activeTab === 'myRequests'} on:click={() => activeTab = 'myRequests'}>
			{t('internalExpenses.myRequestsTab') || 'My Requests'}
		</button>
		<button class="tab-btn" class:active={activeTab === 'allRequests'} on:click={() => activeTab = 'allRequests'}>
			{t('internalExpenses.allRequestsTab') || 'All Requests'}
		</button>
		{#if isMasterAdmin}
			<button class="tab-btn" class:active={activeTab === 'approvers'} on:click={() => activeTab = 'approvers'}>
				{t('internalExpenses.approversTab') || 'Approvers Control'}
			</button>
		{/if}
	</div>

	<!-- Tab Content -->
	<div class="tab-content">
		{#if activeTab === 'request'}
			<div class="tab-panel request-panel">
				<div class="panel-header">
					<h3>{t('internalExpenses.requestTab') || 'Request Internal Consumption'}</h3>
					{#if canSendRequest}
						<button class="create-btn" on:click={openAddModal}>
							+ {t('internalExpenses.add') || 'Add'}
						</button>
					{/if}
				</div>

				{#if requestsLoading}
					<div class="loading-state"><div class="spinner"></div></div>
				{:else if !canSendRequest}
					<div class="empty-state">
						<span class="empty-icon">🔒</span>
						<p>{t('internalExpenses.noSendPermission') || "You don't have permission to send internal consumption requests. Ask a Master Admin to grant access in Approvers Control."}</p>
					</div>
				{:else if requests.length === 0}
					<div class="empty-state">
						<span class="empty-icon">🧾</span>
						<p>{t('internalExpenses.noRequests') || 'No requests yet. Click + Add to create one.'}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{t('internalExpenses.branchLabel') || 'Branch'}</th>
									<th>{t('internalExpenses.productsLabel') || 'Products'}</th>
									<th>{t('internalExpenses.statusLabel') || 'Status'}</th>
									<th>{t('internalExpenses.requestedByLabel') || 'Requested By'}</th>
									<th>{t('internalExpenses.createdAtLabel') || 'Created At'}</th>
								</tr>
							</thead>
							<tbody>
								{#each requests as req, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td class="branch-name-cell">{req.branch_name}</td>
										<td>
											<button class="product-count-btn" on:click={() => openPhotoViewer(req)} title={t('internalExpenses.photoViewerTitle') || 'Product Photos'}>
												📷 {req.items.length}
											</button>
										</td>
										<td><span class="status-badge" class:requested={req.status === 'requested'} class:approved={req.status === 'approved'} class:rejected={req.status === 'rejected'}>{statusLabel(req.status)}</span></td>
										<td>{req.requester_name}</td>
										<td class="date-cell">{formatDateTime(req.created_at)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{:else if activeTab === 'myRequests'}
			<div class="tab-panel request-panel">
				<div class="panel-header">
					<h3>{t('internalExpenses.myRequestsTab') || 'My Requests'}</h3>
				</div>

				{#if requestsLoading}
					<div class="loading-state"><div class="spinner"></div></div>
				{:else if myRequests.length === 0}
					<div class="empty-state">
						<span class="empty-icon">🧾</span>
						<p>{t('internalExpenses.noMyRequests') || "You haven't created any requests yet."}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{t('internalExpenses.branchLabel') || 'Branch'}</th>
									<th>{t('internalExpenses.productsLabel') || 'Products'}</th>
									<th>{t('internalExpenses.statusLabel') || 'Status'}</th>
									<th>{t('internalExpenses.createdAtLabel') || 'Created At'}</th>
								</tr>
							</thead>
							<tbody>
								{#each myRequests as req, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td class="branch-name-cell">{req.branch_name}</td>
										<td>
											<button class="product-count-btn" on:click={() => openPhotoViewer(req)} title={t('internalExpenses.photoViewerTitle') || 'Product Photos'}>
												📷 {req.items.length}
											</button>
										</td>
										<td><span class="status-badge" class:requested={req.status === 'requested'} class:approved={req.status === 'approved'} class:rejected={req.status === 'rejected'}>{statusLabel(req.status)}</span></td>
										<td class="date-cell">{formatDateTime(req.created_at)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{:else if activeTab === 'allRequests'}
			<div class="tab-panel request-panel">
				<div class="panel-header">
					<h3>{t('internalExpenses.allRequestsTab') || 'All Requests'}</h3>
				</div>

				{#if requestsLoading}
					<div class="loading-state"><div class="spinner"></div></div>
				{:else if visibleAllRequests.length === 0}
					<div class="empty-state">
						<span class="empty-icon">🧾</span>
						<p>{t('internalExpenses.noAllRequests') || 'No requests to display.'}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{t('internalExpenses.branchLabel') || 'Branch'}</th>
									<th>{t('internalExpenses.productsLabel') || 'Products'}</th>
									<th>{t('internalExpenses.statusLabel') || 'Status'}</th>
									<th>{t('internalExpenses.requestedByLabel') || 'Requested By'}</th>
									<th>{t('internalExpenses.createdAtLabel') || 'Created At'}</th>
								</tr>
							</thead>
							<tbody>
								{#each visibleAllRequests as req, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td class="branch-name-cell">{req.branch_name}</td>
										<td>
											<button class="product-count-btn" on:click={() => openPhotoViewer(req)} title={t('internalExpenses.photoViewerTitle') || 'Product Photos'}>
												📷 {req.items.length}
											</button>
										</td>
										<td><span class="status-badge" class:requested={req.status === 'requested'} class:approved={req.status === 'approved'} class:rejected={req.status === 'rejected'}>{statusLabel(req.status)}</span></td>
										<td>{req.requester_name}</td>
										<td class="date-cell">{formatDateTime(req.created_at)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{:else if activeTab === 'approvers' && isMasterAdmin}
			<div class="tab-panel request-panel">
				<div class="panel-header">
					<h3>{t('internalExpenses.approversTab') || 'Approvers Control'}</h3>
					<button class="create-btn" on:click={() => openApproverModal()}>
						+ {t('internalExpenses.add') || 'Add'}
					</button>
				</div>

				{#if approversLoading}
					<div class="loading-state"><div class="spinner"></div></div>
				{:else if approvers.length === 0}
					<div class="empty-state">
						<span class="empty-icon">🛡️</span>
						<p>{t('internalExpenses.noApprovers') || 'No approvers configured yet. Click + Add to grant send/approve access.'}</p>
					</div>
				{:else}
					<div class="records-table-wrap">
						<table class="records-table">
							<thead>
								<tr>
									<th>#</th>
									<th>{t('internalExpenses.userLabel') || 'User'}</th>
									<th>{t('internalExpenses.canSendRequestLabel') || 'Can Send Request'}</th>
									<th>{t('internalExpenses.canApproveRequestLabel') || 'Can Approve Request'}</th>
									<th>{t('internalExpenses.branchScopeLabel') || 'Approval Scope'}</th>
									<th>{t('internalExpenses.actionsLabel') || 'Actions'}</th>
								</tr>
							</thead>
							<tbody>
								{#each approvers as a, i}
									<tr>
										<td class="num-cell">{i + 1}</td>
										<td class="branch-name-cell">{a.user_name}</td>
										<td class="num-cell">{a.can_send_request ? '✓' : '—'}</td>
										<td class="num-cell">{a.can_approve_request ? '✓' : '—'}</td>
										<td>{a.can_approve_request ? approverBranchSummary(a) : '—'}</td>
										<td class="action-cell">
											<button class="approve-btn" on:click={() => openApproverModal(a)} title={t('internalExpenses.editLabel') || 'Edit'}>✎</button>
											<button class="reject-btn" on:click={() => removeApprover(a.id)} title={t('internalExpenses.removeApproverLabel') || 'Remove'}>×</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<!-- Add Request Modal -->
{#if showAddModal}
	<div class="modal-overlay" on:click|self={closeAddModal}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{t('internalExpenses.addRequestTitle') || 'New Internal Consumption Request'}</h3>
				<button class="modal-close" on:click={closeAddModal} disabled={saving}>×</button>
			</div>
			<div class="modal-body">
				<!-- Branch -->
				<div class="form-group">
					<label for="ie-branch">{t('internalExpenses.branchLabel') || 'Branch'}</label>
					{#if branchesLoading}
						<div class="field-loading">{t('internalExpenses.loading') || 'Loading...'}</div>
					{:else}
						<select id="ie-branch" bind:value={modalBranchId} class="form-select" disabled={saving}>
							<option value="">{t('internalExpenses.selectBranch') || '-- Select Branch --'}</option>
							{#each branches as b}
								<option value={b.id.toString()}>{branchLabel(b)}</option>
							{/each}
						</select>
					{/if}
				</div>

				<!-- Expense Category -->
				<div class="form-group">
					<label for="ie-expense-category">Expense Category</label>
					<select id="ie-expense-category" bind:value={modalExpenseCategory} class="form-select" disabled={saving || !modalBranchId} on:change={() => { if (modalExpenseCategory !== 'Other') modalCustomExpenseCategory = ''; }}>
						<option value="">-- Select Expense Category --</option>
						{#each expenseCategories as category}
							<option value={category}>{category}</option>
						{/each}
					</select>
				</div>

				{#if modalExpenseCategory === 'Other'}
					<div class="form-group">
						<label for="ie-custom-expense-category">Other Category</label>
						<input id="ie-custom-expense-category" type="text" bind:value={modalCustomExpenseCategory} maxlength="100" placeholder="Enter expense category" class="form-input" disabled={saving} />
					</div>
				{/if}

				<!-- Product entry -->
				<div class="product-entry">
					{#if !hasValidExpenseCategory}
						<div class="field-hint">Select an expense category before adding products.</div>
					{/if}
					<div class="form-group">
						<label>{t('internalExpenses.barcodePhoto') || 'Barcode Photo'}</label>
						{#if currentPhotoDataUrl}
							<div class="photo-preview">
								<img src={currentPhotoDataUrl} alt="Barcode" />
								<button class="photo-remove-btn" on:click={clearCurrentPhoto} type="button">×</button>
							</div>
						{/if}
						<label class="upload-btn">
							📷 {currentPhotoDataUrl ? (t('internalExpenses.replacePhoto') || 'Replace Photo') : (t('internalExpenses.takeUploadPhoto') || 'Take / Upload Photo')}
							<input type="file" accept="image/*" capture="environment" on:change={handlePhotoChange} hidden disabled={saving || !hasValidExpenseCategory} />
						</label>
					</div>

					<div class="form-group">
						<label for="ie-qty">{t('internalExpenses.quantityLabel') || 'Quantity'}</label>
						<input id="ie-qty" type="number" min="0" step="1" bind:value={currentQuantity} placeholder={t('internalExpenses.quantityPlaceholder') || 'Enter quantity'} class="form-input" disabled={saving || !hasValidExpenseCategory} />
					</div>

					{#if productError}
						<div class="save-error">{productError}</div>
					{/if}

					<button class="add-product-btn" on:click={addProductToList} type="button" disabled={saving || !hasValidExpenseCategory}>
						+ {t('internalExpenses.addProductBtn') || 'Add Product'}
					</button>
				</div>

				<!-- Added products list -->
				<div class="form-group">
					<label>{t('internalExpenses.addedProductsTitle') || 'Added Products'} ({pendingProducts.length})</label>
					{#if pendingProducts.length === 0}
						<div class="field-hint">{t('internalExpenses.noProductsAdded') || 'No products added yet.'}</div>
					{:else}
						<div class="pending-products-list">
							{#each pendingProducts as p, i}
								<div class="pending-product-row">
									<img src={p.photoDataUrl} alt="Barcode" class="pending-thumb" />
									<span class="pending-index">#{i + 1}</span>
									<span class="pending-qty">{t('internalExpenses.quantityLabel') || 'Quantity'}: {p.quantity}</span>
									<button class="pending-remove-btn" on:click={() => removePendingProduct(p.id)} title={t('internalExpenses.removeProduct') || 'Remove'} disabled={saving}>×</button>
								</div>
							{/each}
						</div>
					{/if}
				</div>

				{#if saveError}
					<div class="save-error">{saveError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeAddModal} disabled={saving}>{t('internalExpenses.cancel') || 'Cancel'}</button>
				<button class="save-btn" on:click={saveRequest} disabled={saving}>
					{#if saving}<span class="spinner-sm"></span>{/if}
					{t('internalExpenses.save') || 'Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Photo Viewer Modal -->
{#if showPhotoViewer}
	<div class="modal-overlay" on:click|self={closePhotoViewer}>
		<div class="modal-container photo-viewer-container">
			<div class="modal-header">
				<h3>{t('internalExpenses.photoViewerTitle') || 'Product Photos'}</h3>
				<button class="modal-close" on:click={closePhotoViewer}>×</button>
			</div>
			<div class="modal-body photo-viewer-body">
				{#if viewerItems.length > 0}
					<img src={viewerItems[viewerIndex].photo_url} alt="Product" class="viewer-photo" />
					<div class="viewer-meta">
						{t('internalExpenses.quantityLabel') || 'Quantity'}: {viewerItems[viewerIndex].quantity}
					</div>
				{/if}
			</div>
			<div class="modal-footer photo-viewer-footer">
				<button class="cancel-btn" on:click={prevPhoto} disabled={viewerIndex === 0}>
					← {t('internalExpenses.previous') || 'Previous'}
				</button>
				<span class="viewer-position">
					{t('internalExpenses.photoOf', { current: viewerIndex + 1, total: viewerItems.length }) || `${viewerIndex + 1} of ${viewerItems.length}`}
				</span>
				<button class="save-btn" on:click={nextPhoto} disabled={viewerIndex >= viewerItems.length - 1}>
					{t('internalExpenses.next') || 'Next'} →
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Add / Edit Approver Modal -->
{#if showApproverModal}
	<div class="modal-overlay" on:click|self={closeApproverModal}>
		<div class="modal-container">
			<div class="modal-header">
				<h3>{t('internalExpenses.addApproverTitle') || 'Add / Edit Approver'}</h3>
				<button class="modal-close" on:click={closeApproverModal} disabled={approverSaving}>×</button>
			</div>
			<div class="modal-body">
				<!-- User -->
				<div class="form-group">
					<label>{t('internalExpenses.userLabel') || 'User'}</label>
					{#if selectedApproverUser}
						<div class="selected-vendor-bar">
							<div class="sv-info">
								<span class="sv-name">{selectedApproverUser.name_en}</span>
							</div>
							{#if !editingApproverId}
								<button class="sv-change" on:click={clearApproverUser}>{t('internalExpenses.changeLabel') || 'Change'}</button>
							{/if}
						</div>
					{:else if approverUsersLoading}
						<div class="field-loading">{t('internalExpenses.loading') || 'Loading...'}</div>
					{:else}
						<div class="vendor-selector">
							<input type="text" bind:value={approverUserSearch} placeholder={t('internalExpenses.searchUserPlaceholder') || 'Search user by name...'} class="form-input search-input" />
							<div class="vendor-list">
								{#if approverFilteredUsers.length === 0}
									<div class="no-vendors">{t('internalExpenses.noUsersFound') || 'No users found.'}</div>
								{:else}
									{#each approverFilteredUsers.slice(0, 30) as u}
										<button class="vendor-row" on:click={() => selectApproverUser(u)}>
											<span class="vr-name">{u.name_en}</span>
										</button>
									{/each}
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<!-- Can Send Request -->
				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={modalCanSend} />
						{t('internalExpenses.canSendRequestLabel') || 'Can Send Request'}
					</label>
				</div>

				<!-- Can Approve Request -->
				<div class="form-group">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={modalCanApprove} />
						{t('internalExpenses.canApproveRequestLabel') || 'Can Approve Request'}
					</label>
				</div>

				{#if modalCanApprove}
					<div class="form-group">
						<label>{t('internalExpenses.branchScopeLabel') || 'Approval Scope'}</label>
						<select bind:value={modalBranchScope} class="form-select">
							<option value="all">{t('internalExpenses.allBranchesOption') || 'Can Approve for All Branches'}</option>
							<option value="selected">{t('internalExpenses.selectedBranchesOption') || 'Can Approve for Specific Branches'}</option>
						</select>
					</div>

					{#if modalBranchScope === 'selected'}
						<div class="form-group">
							<label>{t('internalExpenses.selectBranchesLabel') || 'Select Branches'}</label>
							<div class="branch-checkboxes">
								{#each branches as b}
									<label class="branch-check-item">
										<input type="checkbox" checked={modalSelectedBranches.includes(b.id.toString())} on:change={() => toggleModalBranch(b.id.toString())} />
										{branchLabel(b)}
									</label>
								{/each}
							</div>
						</div>
					{/if}
				{/if}

				{#if approverError}
					<div class="save-error">{approverError}</div>
				{/if}
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeApproverModal} disabled={approverSaving}>{t('internalExpenses.cancel') || 'Cancel'}</button>
				<button class="save-btn" on:click={saveApprover} disabled={approverSaving}>
					{#if approverSaving}<span class="spinner-sm"></span>{/if}
					{t('internalExpenses.save') || 'Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.internal-expenses-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(135deg, #f0f4ff 0%, #e8edf8 50%, #f5f7fc 100%);
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
		color: #1e293b;
		overflow: hidden;
	}

	.tab-bar {
		display: flex;
		gap: 6px;
		padding: 16px 20px 0;
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border-bottom: 1px solid rgba(255, 255, 255, 0.5);
	}

	.tab-btn {
		padding: 10px 24px;
		border: 1px solid rgba(255, 255, 255, 0.5);
		border-bottom: none;
		border-radius: 10px 10px 0 0;
		background: rgba(255, 255, 255, 0.35);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		color: #475569;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		position: relative;
	}

	.tab-btn:hover { background: rgba(255, 255, 255, 0.55); color: #1e293b; }

	.tab-btn.active {
		background: rgba(255, 255, 255, 0.7);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		color: #3b82f6;
		font-weight: 600;
		border-color: rgba(59, 130, 246, 0.25);
		box-shadow: 0 -2px 8px rgba(59, 130, 246, 0.1);
	}

	.tab-btn.active::after {
		content: '';
		position: absolute;
		bottom: -1px; left: 0; right: 0;
		height: 2px;
		background: rgba(255, 255, 255, 0.7);
	}

	.tab-content { flex: 1; overflow: auto; padding: 20px; }

	.tab-panel { min-height: 100%; }

	.tab-panel:not(.request-panel) {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.coming-soon {
		font-size: 16px;
		font-weight: 500;
		color: #94a3b8;
	}

	/* Shared list panel (Request / My Requests / All Requests / Approvers) */
	.panel-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
	.panel-header h3 { margin: 0; font-size: 16px; color: #1e293b; }

	.create-btn {
		padding: 8px 18px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.create-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4); }

	.empty-state { text-align: center; padding: 60px 20px; opacity: 0.6; }
	.empty-icon { font-size: 48px; display: block; margin-bottom: 12px; }
	.empty-state p { font-size: 15px; color: #64748b; margin: 0; max-width: 420px; margin-inline: auto; }

	.loading-state { display: flex; align-items: center; justify-content: center; padding: 60px; }
	.spinner { width: 20px; height: 20px; border: 2px solid #e0e0e0; border-top: 2px solid #3b82f6; border-radius: 50%; animation: spin 0.7s linear infinite; }
	.spinner-sm { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.3); border-top: 2px solid white; border-radius: 50%; animation: spin 0.7s linear infinite; display: inline-block; margin-inline-end: 6px; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.records-table-wrap { overflow-x: auto; }
	.records-table { width: 100%; border-collapse: collapse; font-size: 13px; }

	.records-table thead th {
		padding: 10px 12px;
		text-align: left;
		font-weight: 600;
		color: #475569;
		background: rgba(241, 245, 249, 0.7);
		border-bottom: 2px solid rgba(226, 232, 240, 0.8);
		white-space: nowrap;
	}

	.records-table tbody td {
		padding: 10px 12px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.5);
		color: #334155;
	}

	.records-table tbody tr:hover { background: rgba(241, 245, 249, 0.5); }

	.num-cell { text-align: center; }
	.date-cell { font-size: 12px; color: #64748b; white-space: nowrap; }
	.branch-name-cell { font-weight: 500; }

	.product-count-btn {
		padding: 4px 10px;
		border: 1px solid rgba(59, 130, 246, 0.3);
		border-radius: 8px;
		background: rgba(59, 130, 246, 0.08);
		color: #2563eb;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}
	.product-count-btn:hover { background: rgba(59, 130, 246, 0.15); }

	.status-badge {
		display: inline-block; padding: 2px 10px; border-radius: 12px;
		font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px;
	}
	.status-badge.requested { background: #fef3c7; color: #92400e; }
	.status-badge.approved { background: #dcfce7; color: #166534; }
	.status-badge.rejected { background: #fee2e2; color: #991b1b; }

	/* Approve/reject (and edit/remove) action buttons */
	.action-cell { white-space: nowrap; }
	.approve-btn {
		padding: 4px 10px; border: none; border-radius: 6px;
		background: #dcfce7; color: #166534; font-weight: 700; font-size: 14px;
		cursor: pointer; margin-right: 4px; transition: all 0.15s;
	}
	.approve-btn:hover { background: #bbf7d0; }
	.approve-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.reject-btn {
		padding: 4px 10px; border: none; border-radius: 6px;
		background: #fee2e2; color: #991b1b; font-weight: 700; font-size: 14px;
		cursor: pointer; transition: all 0.15s;
	}
	.reject-btn:hover { background: #fecaca; }
	.reject-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	/* Modal */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.4);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
	}

	.modal-container {
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.7);
		border-radius: 16px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
		width: 560px;
		max-height: 85vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 18px 24px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.6);
	}

	.modal-header h3 { margin: 0; font-size: 17px; color: #1e293b; }

	.modal-close {
		width: 32px; height: 32px;
		border: none; border-radius: 8px;
		background: rgba(241, 245, 249, 0.6);
		font-size: 20px;
		color: #64748b;
		cursor: pointer;
		display: flex; align-items: center; justify-content: center;
		transition: all 0.15s;
	}

	.modal-close:hover { background: #fee2e2; color: #ef4444; }
	.modal-close:disabled { opacity: 0.5; cursor: not-allowed; }

	.modal-body {
		padding: 20px 24px;
		overflow-y: auto;
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		padding: 16px 24px;
		border-top: 1px solid rgba(226, 232, 240, 0.6);
	}

	.form-group { display: flex; flex-direction: column; gap: 6px; }
	.form-group label { font-size: 13px; font-weight: 600; color: #475569; }

	.form-select, .form-input {
		padding: 9px 12px;
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.7);
		font-size: 14px;
		color: #1e293b;
		outline: none;
		transition: border-color 0.15s, box-shadow 0.15s;
	}

	.form-select:focus, .form-input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-textarea { resize: vertical; min-height: 60px; }

	.field-hint { font-size: 13px; color: #94a3b8; font-style: italic; }
	.field-loading { font-size: 13px; color: #64748b; }

	.save-error {
		padding: 10px 14px;
		background: rgba(254, 226, 226, 0.8);
		border: 1px solid rgba(252, 165, 165, 0.6);
		border-radius: 8px;
		color: #991b1b;
		font-size: 13px;
	}

	.cancel-btn {
		padding: 9px 20px;
		background: rgba(241, 245, 249, 0.7);
		border: 1px solid rgba(203, 213, 225, 0.6);
		border-radius: 8px;
		color: #475569;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.15s;
	}

	.cancel-btn:hover { background: rgba(226, 232, 240, 0.8); }
	.cancel-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.save-btn {
		padding: 9px 24px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		border: none;
		border-radius: 8px;
		color: white;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.save-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4); }
	.save-btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

	/* Product entry block */
	.product-entry {
		display: flex;
		flex-direction: column;
		gap: 12px;
		padding: 14px;
		border: 1px dashed rgba(148, 163, 184, 0.5);
		border-radius: 10px;
		background: rgba(248, 250, 252, 0.6);
	}

	.upload-btn {
		align-self: flex-start;
		padding: 9px 16px;
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid rgba(203, 213, 225, 0.8);
		border-radius: 8px;
		color: #334155;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}
	.upload-btn:hover { background: rgba(241, 245, 249, 0.9); }

	.photo-preview {
		position: relative;
		width: 120px;
		height: 120px;
	}
	.photo-preview img {
		width: 100%; height: 100%;
		object-fit: cover;
		border-radius: 8px;
		border: 1px solid rgba(203, 213, 225, 0.8);
	}
	.photo-remove-btn {
		position: absolute;
		top: -8px; right: -8px;
		width: 22px; height: 22px;
		border-radius: 50%;
		border: none;
		background: #ef4444;
		color: white;
		font-size: 14px;
		line-height: 1;
		cursor: pointer;
		display: flex; align-items: center; justify-content: center;
	}

	.add-product-btn {
		align-self: flex-start;
		padding: 8px 16px;
		background: rgba(220, 252, 231, 0.9);
		border: 1px solid rgba(134, 239, 172, 0.7);
		border-radius: 8px;
		color: #166534;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}
	.add-product-btn:hover { background: rgba(187, 247, 208, 0.9); }
	.add-product-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.pending-products-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
		max-height: 200px;
		overflow-y: auto;
		border: 1px solid rgba(203, 213, 225, 0.5);
		border-radius: 8px;
		padding: 8px;
		background: rgba(255, 255, 255, 0.6);
	}

	.pending-product-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 6px;
		border-radius: 6px;
		background: rgba(248, 250, 252, 0.8);
	}

	.pending-thumb {
		width: 40px; height: 40px;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid rgba(203, 213, 225, 0.8);
		flex-shrink: 0;
	}

	.pending-index { font-size: 12px; color: #94a3b8; flex-shrink: 0; }
	.pending-qty { font-size: 13px; color: #334155; flex: 1; }

	.pending-remove-btn {
		width: 22px; height: 22px;
		border-radius: 50%;
		border: none;
		background: rgba(254, 226, 226, 0.9);
		color: #ef4444;
		font-size: 14px;
		line-height: 1;
		cursor: pointer;
		display: flex; align-items: center; justify-content: center;
		flex-shrink: 0;
	}
	.pending-remove-btn:hover { background: #fecaca; }
	.pending-remove-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	/* Photo viewer */
	.photo-viewer-container { width: 480px; }
	.photo-viewer-body {
		align-items: center;
		justify-content: center;
	}
	.viewer-photo {
		max-width: 100%;
		max-height: 50vh;
		border-radius: 10px;
		border: 1px solid rgba(203, 213, 225, 0.8);
		object-fit: contain;
	}
	.viewer-meta { font-size: 13px; color: #475569; }
	.photo-viewer-footer { justify-content: space-between; align-items: center; }
	.viewer-position { font-size: 13px; color: #64748b; font-weight: 600; }

	/* User search / selected-user bar (Approvers Control popup) */
	.vendor-selector { display: flex; flex-direction: column; gap: 6px; }
	.search-input { width: 100%; box-sizing: border-box; }

	.vendor-list {
		max-height: 180px;
		overflow-y: auto;
		border: 1px solid rgba(203, 213, 225, 0.5);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.6);
	}

	.vendor-row {
		display: flex;
		align-items: center;
		gap: 10px;
		width: 100%;
		padding: 8px 12px;
		border: none;
		background: none;
		cursor: pointer;
		text-align: left;
		font-size: 13px;
		border-bottom: 1px solid rgba(226, 232, 240, 0.4);
		transition: background 0.1s;
		color: #334155;
	}

	.vendor-row:hover { background: rgba(59, 130, 246, 0.08); }
	.vendor-row:last-child { border-bottom: none; }
	.vr-name { flex: 1; }

	.no-vendors { padding: 16px; text-align: center; color: #94a3b8; font-size: 13px; }

	.selected-vendor-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 12px;
		background: rgba(236, 253, 245, 0.8);
		border: 1px solid rgba(134, 239, 172, 0.6);
		border-radius: 8px;
	}

	.sv-info { display: flex; align-items: center; gap: 6px; }
	.sv-name { font-weight: 600; color: #166534; }

	.sv-change {
		padding: 4px 10px;
		background: none;
		border: 1px solid rgba(134, 239, 172, 0.6);
		border-radius: 6px;
		color: #166534;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.15s;
	}
	.sv-change:hover { background: rgba(134, 239, 172, 0.3); }

	.checkbox-label { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 14px; color: #334155; }
	.checkbox-label input[type="checkbox"] { width: 18px; height: 18px; accent-color: #3b82f6; cursor: pointer; }
	.branch-checkboxes {
		display: flex; flex-direction: column; gap: 6px; max-height: 160px; overflow-y: auto;
		padding: 8px; border: 1px solid rgba(203, 213, 225, 0.5); border-radius: 8px; background: rgba(255,255,255,0.5);
	}
	.branch-check-item { display: flex; align-items: center; gap: 6px; font-size: 13px; color: #334155; cursor: pointer; }
	.branch-check-item input[type="checkbox"] { accent-color: #3b82f6; cursor: pointer; }
</style>
