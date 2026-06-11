<script>
	import { onMount, tick } from 'svelte';
	import { t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import EditVendor from './EditVendor.svelte';

	// Debounce utility for search
	let searchTimeout;
	function debounce(func, wait) {
		return function executedFunction(...args) {
			const later = () => {
				clearTimeout(searchTimeout);
				func(...args);
			};
			clearTimeout(searchTimeout);
			searchTimeout = setTimeout(later, wait);
		};
	}

	// State management
	let totalVendors = 0;
	let vendors = [];
	let filteredVendors = [];
	let displayedVendors = []; // For virtual scrolling
	let searchQuery = '';
	let isLoading = true;
	let error = null;
	let loadingProgress = 0; // Track loading progress

	// Branch filtering
	let branches = [];
	let selectedBranch = '';
	let loadingBranches = false;
	let branchFilterMode = 'all'; // 'all', 'branch', 'unassigned'

	// Column visibility management
	let showColumnSelector = false;
	let visibleColumns = {
		erp_vendor_id: true,
		vendor_name: true,
		branch_name: true, // Add branch column
		salesman_name: true,
		salesman_contact: false,
		supervisor_name: false,
		supervisor_contact: false,
		vendor_contact: true,
		payment_method: true,
		payment_priority: true,
		credit_period: false,
		bank_name: false,
		iban: false,
		last_visit: false,
		place: true,
		location: true,
		categories: true,
		delivery_modes: true,
		return_expired: false,
		return_near_expiry: false,
		return_over_stock: false,
		return_damage: false,
		no_return: false,
		vat_status: false,
		vat_number: false,
		status: true,
		actions: true
	};

	// Column definitions
	let columnDefinitions = [];
	$: columnDefinitions = [
		{ key: 'erp_vendor_id', label: t('vendorManagement.erpVendorId') },
		{ key: 'vendor_name', label: t('vendorManagement.vendorName') },
		{ key: 'branch_name', label: t('vendorManagement.branch') },
		{ key: 'salesman_name', label: t('vendorManagement.salesmanName') },
		{ key: 'salesman_contact', label: t('vendorManagement.salesmanContact') },
		{ key: 'supervisor_name', label: t('vendorManagement.supervisorName') },
		{ key: 'supervisor_contact', label: t('vendorManagement.supervisorContact') },
		{ key: 'vendor_contact', label: t('vendorManagement.vendorContact') },
		{ key: 'payment_method', label: t('vendorManagement.paymentMethod') },
		{ key: 'payment_priority', label: t('vendorManagement.paymentPriority') },
		{ key: 'credit_period', label: t('vendorManagement.creditPeriod') },
		{ key: 'bank_name', label: t('vendorManagement.bankName') },
		{ key: 'iban', label: t('vendorManagement.iban') },
		{ key: 'last_visit', label: t('vendorManagement.lastVisit') },
		{ key: 'place', label: t('vendorManagement.place') },
		{ key: 'location', label: t('vendorManagement.location') },
		{ key: 'categories', label: t('vendorManagement.categories') },
		{ key: 'delivery_modes', label: t('vendorManagement.deliveryModes') },
		{ key: 'return_expired', label: t('vendorManagement.returnExpired') },
		{ key: 'return_near_expiry', label: t('vendorManagement.returnNearExpiry') },
		{ key: 'return_over_stock', label: t('vendorManagement.returnOverStock') },
		{ key: 'return_damage', label: t('vendorManagement.returnDamage') },
		{ key: 'no_return', label: t('vendorManagement.noReturn') },
		{ key: 'vat_status', label: t('vendorManagement.vatStatus') },
		{ key: 'vat_number', label: t('vendorManagement.vatNumber') },
		{ key: 'status', label: t('vendorManagement.status') },
		{ key: 'actions', label: t('vendorManagement.actions') }
	];

	// Load vendor data on component mount
	// Reactive statements
	$: if (branchFilterMode === 'all') {
		selectedBranch = null;
		loadVendors();
	} else if (branchFilterMode === 'unassigned') {
		selectedBranch = null;
		loadVendors();
	} else if (branchFilterMode === 'branch') {
		// Reset vendors when switching to branch mode
		if (!selectedBranch) {
			vendors = [];
			filteredVendors = [];
			totalVendors = 0;
		} else {
			loadVendors();
		}
	}

	// Load vendors when branch selection changes (only for branch mode)
	$: if (branchFilterMode === 'branch' && selectedBranch) {
		loadVendors();
	}

	onMount(async () => {
		await loadBranches();
		await loadVendors();
	});

	// Load branches from database
	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		} finally {
			loadingBranches = false;
		}
	}

	// Load vendors from database using a dedicated RPC for faster loading
	async function loadVendors() {
		try {
			isLoading = true;
			error = null;
			loadingProgress = 0;

			if (branchFilterMode === 'branch' && !selectedBranch) {
				vendors = [];
				filteredVendors = [];
				displayedVendors = [];
				totalVendors = 0;
				isLoading = false;
				return;
			}

			const branchId = branchFilterMode === 'branch' ? selectedBranch ?? null : null;
			const searchTerm = searchQuery?.trim() || null;

			const { data, error: rpcError } = await supabase.rpc('get_vendor_management_list', {
				p_branch_id: branchId,
				p_mode: branchFilterMode,
				p_search: searchTerm
			});

			if (rpcError) {
				console.error('❌ RPC vendor load error:', rpcError);
				throw rpcError;
			}

			const rpcVendors = (data || []).map((vendor) => ({
				...vendor,
				branches: vendor.branch_id
					? {
						id: vendor.branch_id,
						name_en: vendor.branch_name_en,
						name_ar: vendor.branch_name_ar
					}
					: null
			}));

			vendors = rpcVendors;
			filteredVendors = vendors;
			displayedVendors = filteredVendors.slice(0, 100);
			totalVendors = rpcVendors.length;
			loadingProgress = 100;

			console.log(`✅ RPC loaded ${vendors.length} vendors (total: ${totalVendors})`);

		} catch (err) {
			console.error('❌ Error loading vendors:', err);
			error = err.message;
		} finally {
			isLoading = false;
		}
	}

	// Optimized search functionality with debouncing
	function handleSearch() {
		if (!searchQuery.trim()) {
			filteredVendors = vendors;
			displayedVendors = filteredVendors.slice(0, 100);
		} else {
			const query = searchQuery.toLowerCase();
			// Optimized search - check most common fields first
			filteredVendors = vendors.filter(vendor => {
				// Quick checks on main fields first
				if (vendor.erp_vendor_id?.toString().includes(query)) return true;
				if (vendor.vendor_name?.toLowerCase().includes(query)) return true;
				if (vendor.salesman_name?.toLowerCase().includes(query)) return true;
				if (vendor.vendor_contact_number?.toLowerCase().includes(query)) return true;
				if (vendor.payment_method?.toLowerCase().includes(query)) return true;
				if (vendor.place?.toLowerCase().includes(query)) return true;
				if (vendor.status?.toLowerCase().includes(query)) return true;
				
				// Check arrays only if needed
				if (vendor.categories?.some(cat => cat.toLowerCase().includes(query))) return true;
				if (vendor.delivery_modes?.some(mode => mode.toLowerCase().includes(query))) return true;
				
				return false;
			});
			displayedVendors = filteredVendors.slice(0, 100);
		}
		console.log(`Search results: ${filteredVendors.length} vendors found`);
	}

	// Debounced search
	const debouncedSearch = debounce(handleSearch, 300);

	// Reactive search with debouncing
	$: if (searchQuery !== undefined) {
		debouncedSearch();
	}

	// Load more vendors function for lazy loading
	function loadMoreVendors() {
		const currentLength = displayedVendors.length;
		const nextBatch = filteredVendors.slice(currentLength, currentLength + 100);
		if (nextBatch.length > 0) {
			displayedVendors = [...displayedVendors, ...nextBatch];
			console.log(`Loaded ${nextBatch.length} more vendors, total displayed: ${displayedVendors.length}`);
		}
	}

	// Handle scroll for lazy loading
	function handleTableScroll(event) {
		const element = event.target;
		const scrolledToBottom = element.scrollHeight - element.scrollTop <= element.clientHeight + 100;
		
		if (scrolledToBottom && displayedVendors.length < filteredVendors.length) {
			loadMoreVendors();
		}
	}

	// Refresh data
	async function refreshData() {
		await loadVendors();
	}

	// Generate unique window ID
	function generateWindowId() {
		return `edit-vendor-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function normalizeLabel(value) {
		return String(value ?? '')
			.toLowerCase()
			.trim()
			.replace(/[_\-\/]+/g, ' ')
			.replace(/\s+/g, ' ');
	}

	function getLocalizedBranchName(branch) {
		if (!branch) return t('vendorManagement.unassigned');
		return $locale === 'ar' ? (branch.name_ar || branch.name_en || t('vendorManagement.unassigned')) : (branch.name_en || branch.name_ar || t('vendorManagement.unassigned'));
	}

	function getLocalizedPaymentMethod(method) {
		if (!method) return t('vendorManagement.noMethod');

		const normalized = normalizeLabel(method);
		const methodMap = {
			'cash on delivery': t('vendorManagement.paymentMethods.cashOnDelivery'),
			'bank on delivery': t('vendorManagement.paymentMethods.bankOnDelivery'),
			'cash credit': t('vendorManagement.paymentMethods.cashCredit'),
			'bank credit': t('vendorManagement.paymentMethods.bankCredit')
		};

		return methodMap[normalized] || String(method).trim();
	}

	function getLocalizedPriorityLabel(priority) {
		if (!priority) return t('vendorManagement.normalPriority');

		const normalized = normalizeLabel(priority);
		const labelMap = {
			'most': t('vendorManagement.priorityMost'),
			'medium': t('vendorManagement.priorityMedium'),
			'normal': t('vendorManagement.normalPriority'),
			'low': t('vendorManagement.priorityLow')
		};

		return labelMap[normalized] || String(priority).trim();
	}

	function getLocalizedCategoryLabel(category) {
		if (!category) return category;

		const normalized = normalizeLabel(category);
		const categoryMap = {
			'daily fresh': t('vendors.dailyFresh'),
			'wholesaler': t('vendors.wholesaler'),
			'company distributor': t('vendors.companyDistributor'),
			'sales van': t('vendors.salesVan'),
			'maintenance related': t('vendors.maintenanceRelated')
		};

		return categoryMap[normalized] || String(category).trim();
	}

	function getLocalizedDeliveryModeLabel(mode) {
		if (!mode) return mode;

		const normalized = normalizeLabel(mode);
		const deliveryMap = {
			'direct pick up': t('vendors.directPickUp'),
			'delivery on site': t('vendors.deliveryOnSite'),
			'delivery to parcel companies': t('vendors.deliveryToParcelCompanies')
		};

		return deliveryMap[normalized] || String(mode).trim();
	}

	function getLocalizedReturnPolicyLabel(value) {
		if (!value) return t('vendorManagement.notSet');

		const normalized = normalizeLabel(value);
		const policyMap = {
			'can return': t('vendorEdit.returnPolicyOptions.canReturn'),
			'cannot return': t('vendorEdit.returnPolicyOptions.cannotReturn'),
			'canreturn': t('vendorEdit.returnPolicyOptions.canReturn'),
			'cannotreturn': t('vendorEdit.returnPolicyOptions.cannotReturn')
		};

		return policyMap[normalized] || String(value).trim();
	}

	function getLocalizedVatStatusLabel(value) {
		if (!value) return t('vendorManagement.notSet');

		const normalized = normalizeLabel(value);
		const vatMap = {
			'vat applicable': t('vendorManagement.vatApplicable'),
			'no vat': t('vendorManagement.noVat')
		};

		return vatMap[normalized] || String(value).trim();
	}

	// Open edit vendor window
	function openEditWindow(vendor) {
		const windowId = generateWindowId();
		
		openWindow({
			id: windowId,
			title: `${t('vendorEdit.title')} - ${vendor.vendor_name}`,
			component: EditVendor,
			icon: '✏️',
			size: { width: 800, height: 600 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				vendor: vendor,
				onSave: async (updatedVendor) => {
					console.log('Vendor updated:', updatedVendor);
					try {
						// Update local vendor data with proper reactivity using both erp_vendor_id and branch_id
						const index = vendors.findIndex(v => 
							v.erp_vendor_id === updatedVendor.erp_vendor_id && 
							v.branch_id === vendor.branch_id // Use original branch_id to find the vendor
						);
						if (index !== -1) {
							vendors[index] = { ...updatedVendor };
							vendors = [...vendors]; // Trigger reactivity
							console.log('Vendor updated in local array:', vendors[index]);
							handleSearch(); // Refresh filtered data
						} else {
							console.warn('Vendor not found in local array for update');
							// Reload all vendors as fallback
							await loadVendors();
						}
						// Close the edit window
						windowManager.closeWindow(windowId);
						alert('Vendor updated successfully!');
					} catch (error) {
						console.error('Error updating vendor in UI:', error);
						alert('Vendor updated but there was an issue refreshing the display.');
					}
				},
				onCancel: () => {
					// Close the edit window
					windowManager.closeWindow(windowId);
				}
			}
		});
	}

	// Open create vendor window
	function openCreateVendor() {
		const windowId = generateWindowId();
		
		openWindow({
			id: windowId,
			title: t('admin.createVendor'),
			component: EditVendor,
			icon: '➕',
			size: { width: 800, height: 600 },
			position: { 
				x: 150 + (Math.random() * 50),
				y: 150 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				vendor: {
					// Initialize with empty vendor object with mandatory fields
					erp_vendor_id: '',
					vendor_name: '',
					// All other fields optional - set defaults
					salesman_name: '',
					salesman_contact: '',
					supervisor_name: '',
					supervisor_contact: '',
					vendor_contact: '',
					payment_method: '',
					credit_period: '',
					bank_name: '',
					iban: '',
					last_visit: '',
					place: '',
					location: '',
					categories: [],
					delivery_modes: [],
					status: 'Active',
					// Return policy defaults
					return_expired_products: '',
					return_expired_note: '',
					return_near_expiry_products: '',
					return_near_expiry_note: '',
					return_over_stock: '',
					return_over_stock_note: '',
					return_damage_products: '',
					return_damage_note: '',
					no_return: false,
					// VAT defaults
					vat_applicable: 'VAT Applicable',
					vat_number: '',
					no_vat_note: ''
				},
				isCreating: true, // Flag to indicate creation mode
				onSave: (newVendor) => {
					// Add new vendor to local data
					vendors = [...vendors, newVendor];
					totalVendors++;
					handleSearch(); // Refresh filtered data
					// Close the create window
					windowManager.closeWindow(windowId);
					alert('Vendor created successfully!');
				},
				onCancel: () => {
					// Close the create window
					windowManager.closeWindow(windowId);
				}
			}
		});
	}

	// Update vendor status
	async function updateVendorStatus(vendorId, newStatus) {
		try {
			const { error } = await supabase
				.from('vendors')
				.update({ 
					status: newStatus,
					updated_at: new Date().toISOString()
				})
				.eq('erp_vendor_id', vendorId);

			if (error) throw error;

			// Update local vendor data
			const index = vendors.findIndex(v => v.erp_vendor_id === vendorId);
			if (index !== -1) {
				vendors[index].status = newStatus;
				vendors[index].updated_at = new Date().toISOString();
				handleSearch(); // Refresh filtered data
			}

			// Show success message
			alert(`Vendor status updated to ${newStatus} successfully!`);
		} catch (err) {
			console.error('Error updating vendor status:', err);
			alert('Failed to update vendor status. Please try again.');
		}
	}

	// Cycle vendor status: Active → Blacklist → Deactivate → Active
	async function cycleVendorStatus(vendorId, currentStatus) {
		let nextStatus;
		
		switch (currentStatus) {
			case 'Active':
				nextStatus = 'Blacklisted';
				break;
			case 'Blacklisted':
				nextStatus = 'Deactivated';
				break;
			case 'Deactivated':
				nextStatus = 'Active';
				break;
			default:
				nextStatus = 'Blacklisted'; // Default to blacklist if unknown status
		}
		
		await updateVendorStatus(vendorId, nextStatus);
	}

	// Share location function
	async function shareLocation(locationLink, vendorName) {
		try {
			// Check if Web Share API is supported
			if (navigator.share) {
				await navigator.share({
					title: `${vendorName} Location`,
					text: `Location for vendor: ${vendorName}`,
					url: locationLink
				});
			} else {
				// Fallback: Copy to clipboard
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			}
		} catch (error) {
			// Manual fallback if clipboard fails
			try {
				await navigator.clipboard.writeText(locationLink);
				alert(`Location link copied to clipboard!\n\nVendor: ${vendorName}\nLocation: ${locationLink}`);
			} catch (clipboardError) {
				// Ultimate fallback - show link in a prompt
				prompt(`Copy this location link:\n\nVendor: ${vendorName}`, locationLink);
			}
		}
	}

	// Toggle column visibility
	function toggleColumn(columnKey) {
		visibleColumns[columnKey] = !visibleColumns[columnKey];
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}

	// Show/hide all columns
	function toggleAllColumns(show) {
		for (let key in visibleColumns) {
			if (key !== 'vendor_name' && key !== 'actions') { // Always keep vendor name and actions
				visibleColumns[key] = show;
			}
		}
		visibleColumns = { ...visibleColumns }; // Trigger reactivity
	}
</script>

<div class="manage-vendor">
	<!-- Unified Top Control Card -->
	<div class="top-controls-card">
		<button class="create-btn" on:click={openCreateVendor}>
			➕ {t('admin.createVendor')}
		</button>
		<button class="refresh-btn" on:click={refreshData} disabled={isLoading}>
			🔄 {t('common.refresh')}
		</button>

		<div class="v-divider"></div>

		<div class="filter-group">
			<label class="filter-chip" class:chip-active={branchFilterMode === 'all'}>
				<input type="radio" bind:group={branchFilterMode} value="all" />
				<span>{t('vendorManagement.allVendors', { count: totalVendors })}</span>
			</label>
			<label class="filter-chip" class:chip-active={branchFilterMode === 'branch'}>
				<input type="radio" bind:group={branchFilterMode} value="branch" />
				<span>{t('vendorManagement.byBranch')}</span>
			</label>
			<label class="filter-chip" class:chip-active={branchFilterMode === 'unassigned'}>
				<input type="radio" bind:group={branchFilterMode} value="unassigned" />
				<span>{t('vendorManagement.unassignedVendors')}</span>
			</label>
			{#if branchFilterMode === 'branch'}
				{#if loadingBranches}
					<span class="loading-hint">{t('vendorManagement.loadingBranches')}</span>
				{:else}
					<select bind:value={selectedBranch} class="branch-select">
						<option value="">{t('vendorManagement.chooseBranch')}</option>
						{#each branches as branch}
							<option value={branch.id}>
								{branch.name_en} ({branch.name_ar}) - {branch.location_en}
							</option>
						{/each}
					</select>
				{/if}
			{/if}
		</div>

		<div class="v-divider"></div>

		<div class="search-wrapper">
			<span class="search-icon-inner">🔍</span>
			<input
				type="text"
				placeholder={t('vendorManagement.searchPlaceholder')}
				bind:value={searchQuery}
				class="search-input"
			/>
			{#if searchQuery}
				<button class="clear-search-btn-inner" on:click={() => searchQuery = ''}>×</button>
			{/if}
		</div>

		<div class="v-divider"></div>

		<div class="column-selector-wrapper">
			<button class="columns-btn" on:click={() => showColumnSelector = !showColumnSelector}>
				🏷️ {t('vendorManagement.showHideColumns')} <span class="arrow">{showColumnSelector ? '▲' : '▼'}</span>
			</button>
			{#if showColumnSelector}
				<div class="column-dropdown">
					<div class="col-controls">
						<button class="ctrl-btn" on:click={() => toggleAllColumns(true)}>✅ {t('vendorManagement.showAll')}</button>
						<button class="ctrl-btn" on:click={() => toggleAllColumns(false)}>❌ {t('vendorManagement.hideAll')}</button>
					</div>
					<div class="column-list">
						{#each columnDefinitions as column}
							<label class="column-item">
								<input type="checkbox" checked={visibleColumns[column.key]} on:change={() => toggleColumn(column.key)} />
								<span>{column.label}</span>
							</label>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Status bar -->
	<div class="status-bar">
		{#if branchFilterMode === 'branch' && !selectedBranch}
			<span>{t('vendorManagement.selectBranchHint')}</span>
		{:else}
			<span>
				{t('vendorManagement.showingVendors', { shown: displayedVendors.length, total: filteredVendors.length })}
				{#if filteredVendors.length < totalVendors}
					&nbsp;({t('vendorManagement.filteredFrom', { total: totalVendors })})
				{/if}
			</span>
		{/if}
	</div>

	<!-- Table Section -->
	<div class="table-card">
		{#if error}
			<div class="state-box error-state">
				<span class="state-icon">⚠️</span>
				<p>{t('vendorManagement.errorLoading')}: {error}</p>
				<button class="action-state-btn" on:click={refreshData}>{t('common.tryAgain')}</button>
			</div>
		{:else if isLoading}
			<div class="state-box loading-state">
				<div class="loading-spinner">⏳</div>
				<p>{t('vendorManagement.loadingVendors')}</p>
				{#if loadingProgress > 0}
					<div class="progress-bar">
						<div class="progress-fill" style="width: {loadingProgress}%"></div>
					</div>
					<p class="progress-text">{Math.round(loadingProgress)}% loaded</p>
				{/if}
			</div>
		{:else if filteredVendors.length === 0}
			<div class="state-box empty-state">
				{#if searchQuery}
					<span class="state-icon">🔍</span>
					<h3>{t('vendorManagement.noVendorsFound')}</h3>
					<p>{t('vendorManagement.noVendorsMatch')}</p>
					<button class="action-state-btn" on:click={() => searchQuery = ''}>{t('vendorManagement.clearSearch')}</button>
				{:else}
					<span class="state-icon">📝</span>
					<h3>{t('vendorManagement.noVendorsYet')}</h3>
					<p>{t('vendorManagement.uploadVendorData')}</p>
				{/if}
			</div>
		{:else}
			<div class="vendor-table" on:scroll={handleTableScroll}>
				<table>
					<thead>
						<tr>
							{#if visibleColumns.erp_vendor_id}<th>{t('vendorManagement.erpVendorId')}</th>{/if}
							{#if visibleColumns.vendor_name}<th>{t('vendorManagement.vendorName')}</th>{/if}
							{#if visibleColumns.branch_name}<th>{t('vendorManagement.branch')}</th>{/if}
							{#if visibleColumns.salesman_name}<th>{t('vendorManagement.salesmanName')}</th>{/if}
							{#if visibleColumns.salesman_contact}<th>{t('vendorManagement.salesmanContact')}</th>{/if}
							{#if visibleColumns.supervisor_name}<th>{t('vendorManagement.supervisorName')}</th>{/if}
							{#if visibleColumns.supervisor_contact}<th>{t('vendorManagement.supervisorContact')}</th>{/if}
							{#if visibleColumns.vendor_contact}<th>{t('vendorManagement.vendorContact')}</th>{/if}
							{#if visibleColumns.payment_method}<th>{t('vendorManagement.paymentMethod')}</th>{/if}
							{#if visibleColumns.payment_priority}<th>{t('vendorManagement.paymentPriority')}</th>{/if}
							{#if visibleColumns.credit_period}<th>{t('vendorManagement.creditPeriod')}</th>{/if}
							{#if visibleColumns.bank_name}<th>{t('vendorManagement.bankName')}</th>{/if}
							{#if visibleColumns.iban}<th>{t('vendorManagement.iban')}</th>{/if}
							{#if visibleColumns.last_visit}<th>{t('vendorManagement.lastVisit')}</th>{/if}
							{#if visibleColumns.place}<th>{t('vendorManagement.place')}</th>{/if}
							{#if visibleColumns.location}<th>{t('vendorManagement.location')}</th>{/if}
							{#if visibleColumns.categories}<th>{t('vendorManagement.categories')}</th>{/if}
							{#if visibleColumns.delivery_modes}<th>{t('vendorManagement.deliveryModes')}</th>{/if}
							{#if visibleColumns.status}<th>{t('vendorManagement.status')}</th>{/if}
							{#if visibleColumns.actions}<th>{t('vendorManagement.actions')}</th>{/if}
						</tr>
					</thead>
					<tbody>
						{#each displayedVendors as vendor}
							<tr>
								{#if visibleColumns.erp_vendor_id}
									<td class="vendor-id">{vendor.erp_vendor_id}</td>
								{/if}
								{#if visibleColumns.vendor_name}
									<td class="vendor-name">{vendor.vendor_name}</td>
								{/if}
								{#if visibleColumns.branch_name}
									<td class="branch-name">
										{#if vendor.branches?.name_en || vendor.branches?.name_ar}
											<span class="branch-assigned">{getLocalizedBranchName(vendor.branches)}</span>
										{:else}
											<span class="branch-unassigned">{t('vendorManagement.unassigned')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.salesman_name}
									<td class="vendor-data">
										{#if vendor.salesman_name}
											{vendor.salesman_name}
										{:else}
											<span class="no-data">{t('vendorManagement.noSalesman')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.salesman_contact}
									<td class="vendor-data">
										{#if vendor.salesman_contact}
											{vendor.salesman_contact}
										{:else}
											<span class="no-data">{t('vendorManagement.noContact')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.supervisor_name}
									<td class="vendor-data">
										{#if vendor.supervisor_name}
											{vendor.supervisor_name}
										{:else}
											<span class="no-data">{t('vendorManagement.noSupervisor')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.supervisor_contact}
									<td class="vendor-data">
										{#if vendor.supervisor_contact}
											{vendor.supervisor_contact}
										{:else}
											<span class="no-data">{t('vendorManagement.noContact')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vendor_contact}
									<td class="vendor-data">
										{#if vendor.vendor_contact_number}
											{vendor.vendor_contact_number}
										{:else}
											<span class="no-data">{t('vendorManagement.noContact')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.payment_method}
									<td class="payment-method">
										{#if vendor.payment_method}
											{#if vendor.payment_method.includes(',')}
												<!-- Multiple payment methods -->
												<div class="payment-methods-list">
													{#each vendor.payment_method.split(',').map(m => m.trim()) as method}
														<span class="payment-method-tag">{getLocalizedPaymentMethod(method)}</span>
													{/each}
												</div>
											{:else}
												<!-- Single payment method -->
												{getLocalizedPaymentMethod(vendor.payment_method)}
											{/if}
										{:else}
											<span class="no-data">{t('vendorManagement.noMethod')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.payment_priority}
									<td class="payment-priority">
										{#if vendor.payment_priority}
											<span class="priority-badge priority-{vendor.payment_priority.toLowerCase()}">
												{getLocalizedPriorityLabel(vendor.payment_priority)}
											</span>
										{:else}
											<span class="priority-badge priority-normal">{t('vendorManagement.normalPriority')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.credit_period}
									<td class="credit-period">
										{#if vendor.payment_method && (vendor.payment_method.includes('Cash Credit') || vendor.payment_method.includes('Bank Credit')) && vendor.credit_period}
											{vendor.credit_period} {t('vendorManagement.days')}
										{:else}
											<span class="no-data">{t('vendorManagement.noCreditPeriod')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.bank_name}
									<td class="bank-info">
										{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.bank_name}
											{vendor.bank_name}
										{:else}
											<span class="no-data">{t('vendorManagement.noBank')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.iban}
									<td class="bank-info">
										{#if vendor.payment_method && (vendor.payment_method.includes('Bank on Delivery') || vendor.payment_method.includes('Bank Credit')) && vendor.iban}
											{vendor.iban}
										{:else}
											<span class="no-data">{t('vendorManagement.noIban')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.last_visit}
									<td class="last-visit">
										{#if vendor.last_visit}
											{new Date(vendor.last_visit).toLocaleDateString('en-US', { 
												year: 'numeric', 
												month: 'short', 
												day: 'numeric',
												hour: '2-digit',
												minute: '2-digit'
											})}
										{:else}
											<span class="no-visit">{t('vendorManagement.neverVisited')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.place}
									<td class="vendor-place">
										{#if vendor.place}
											<span class="place-text">📍 {vendor.place}</span>
										{:else}
											<span class="no-place">{t('vendorManagement.noPlace')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.location}
									<td class="vendor-location">
										{#if vendor.location_link}
											<div class="location-actions">
												<a 
													href={vendor.location_link} 
													target="_blank" 
													rel="noopener noreferrer"
													class="location-link"
												>
													🗺️ {t('vendorManagement.openMap')}
												</a>
												<button 
													class="share-location-btn"
													on:click={() => shareLocation(vendor.location_link, vendor.vendor_name)}
													title="Share Location"
												>
													📤 {t('vendorManagement.share')}
												</button>
											</div>
										{:else}
											<span class="no-location">{t('vendorManagement.noLocation')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.categories}
									<td class="vendor-categories">
										{#if vendor.categories && vendor.categories.length > 0}
											<div class="category-badges">
												{#each vendor.categories as category}
													<span class="category-badge">{getLocalizedCategoryLabel(category)}</span>
												{/each}
											</div>
										{:else}
											<span class="no-categories">{t('vendorManagement.noCategories')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.delivery_modes}
									<td class="vendor-delivery-modes">
										{#if vendor.delivery_modes && vendor.delivery_modes.length > 0}
											<div class="delivery-mode-badges">
												{#each vendor.delivery_modes as mode}
													<span class="delivery-mode-badge">{getLocalizedDeliveryModeLabel(mode)}</span>
												{/each}
											</div>
										{:else}
											<span class="no-delivery-modes">{t('vendorManagement.noDeliveryModes')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_expired}
									<td class="return-policy-cell">
										{#if vendor.return_expired_products}
											<span class="return-policy-badge {vendor.return_expired_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_expired_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_near_expiry}
									<td class="return-policy-cell">
										{#if vendor.return_near_expiry_products}
											<span class="return-policy-badge {vendor.return_near_expiry_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_near_expiry_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_over_stock}
									<td class="return-policy-cell">
										{#if vendor.return_over_stock}
											<span class="return-policy-badge {vendor.return_over_stock === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_over_stock}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.return_damage}
									<td class="return-policy-cell">
										{#if vendor.return_damage_products}
											<span class="return-policy-badge {vendor.return_damage_products === 'Can Return' ? 'can-return' : 'cannot-return'}">
												{vendor.return_damage_products}
											</span>
										{:else}
											<span class="no-policy">Not set</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.no_return}
									<td class="return-policy-cell">
										{#if vendor.no_return}
											<span class="return-policy-badge no-return-badge">🚫 {t('vendorManagement.noReturns')}</span>
										{:else}
											<span class="return-policy-badge returns-accepted">✅ {t('vendorManagement.returnsOk')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vat_status}
									<td class="vat-cell">
										{#if vendor.vat_applicable}
											<span class="vat-badge {vendor.vat_applicable === 'VAT Applicable' ? 'vat-applicable' : 'no-vat'}">
												{vendor.vat_applicable === 'VAT Applicable' ? `💰 ${t('vendorManagement.vatApplicable')}` : `🚫 ${t('vendorManagement.noVat')}`}
											</span>
										{:else}
											<span class="no-vat-info">{t('vendorManagement.notSet')}</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.vat_number}
									<td class="vat-number-cell">
										{#if vendor.vat_applicable === 'VAT Applicable' && vendor.vat_number}
											<span class="vat-number">{vendor.vat_number}</span>
										{:else if vendor.vat_applicable === 'No VAT' && vendor.no_vat_note}
											<span class="no-vat-note" title={vendor.no_vat_note}>📝 {t('vendorManagement.noteAvailable')}</span>
										{:else}
											<span class="no-vat-info">-</span>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.status}
									<td class="status-cell">
										{#if vendor.status === 'Active'}
											<button class="status-cycle-btn status-active" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
												✅ {t('vendorManagement.active')}
											</button>
										{:else if vendor.status === 'Deactivated'}
											<button class="status-cycle-btn status-deactivated" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
												🚫 {t('vendorManagement.deactivated')}
											</button>
										{:else if vendor.status === 'Blacklisted'}
											<button class="status-cycle-btn status-blacklisted" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
												⚫ {t('vendorManagement.blacklisted')}
											</button>
										{:else}
											<button class="status-cycle-btn status-active" on:click={() => cycleVendorStatus(vendor.erp_vendor_id, vendor.status || 'Active')}>
												✅ {t('vendorManagement.active')}
											</button>
										{/if}
									</td>
								{/if}
								{#if visibleColumns.actions}
									<td class="action-buttons">
										<button class="edit-btn" on:click={() => openEditWindow(vendor)}>✏️ {t('vendorManagement.edit')}</button>
									</td>
								{/if}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>
</div>

<style>
	/* ===================== BASE ===================== */
	.manage-vendor {
		padding: 0.75rem 1rem;
		background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
		height: 100%;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		gap: 0.55rem;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	/* ===================== TOP CONTROL CARD ===================== */
	.top-controls-card {
		display: flex;
		align-items: center;
		gap: 0.55rem;
		flex-wrap: wrap;
		background: rgba(255, 255, 255, 0.72);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.9);
		border-radius: 14px;
		padding: 0.65rem 1rem;
		box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08), inset 0 1px 0 rgba(255, 255, 255, 0.95);
		flex-shrink: 0;
	}

	.create-btn {
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		border: 1px solid rgba(16, 185, 129, 0.4);
		padding: 0.45rem 0.9rem;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.82rem;
		white-space: nowrap;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.22);
	}
	.create-btn:hover {
		background: linear-gradient(135deg, #059669, #047857);
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
	}

	.refresh-btn {
		background: rgba(99, 102, 241, 0.08);
		color: #4f46e5;
		border: 1px solid rgba(99, 102, 241, 0.25);
		padding: 0.45rem 0.9rem;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.82rem;
		white-space: nowrap;
		transition: all 0.2s;
	}
	.refresh-btn:hover:not(:disabled) {
		background: rgba(99, 102, 241, 0.15);
		color: #3730a3;
		transform: translateY(-1px);
	}
	.refresh-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.v-divider {
		width: 1px;
		height: 28px;
		background: rgba(0, 0, 0, 0.08);
		flex-shrink: 0;
	}

	/* Filter group */
	.filter-group {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		flex-wrap: wrap;
	}

	.filter-chip {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.35rem 0.75rem;
		border-radius: 20px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		color: #64748b;
		border: 1px solid rgba(0, 0, 0, 0.1);
		background: rgba(255, 255, 255, 0.5);
		transition: all 0.2s;
		white-space: nowrap;
		user-select: none;
	}
	.filter-chip:hover {
		color: #1e293b;
		border-color: rgba(59, 130, 246, 0.3);
		background: rgba(59, 130, 246, 0.06);
	}
	.filter-chip.chip-active {
		background: rgba(59, 130, 246, 0.1);
		border-color: rgba(59, 130, 246, 0.4);
		color: #1d4ed8;
	}
	.filter-chip input[type="radio"] {
		display: none;
	}

	.loading-hint {
		color: #94a3b8;
		font-size: 0.8rem;
		font-style: italic;
	}

	.branch-select {
		background: rgba(255, 255, 255, 0.8);
		color: #1e293b;
		border: 1px solid rgba(0, 0, 0, 0.12);
		border-radius: 8px;
		padding: 0.35rem 0.7rem;
		font-size: 0.82rem;
		cursor: pointer;
		outline: none;
		max-width: 220px;
		transition: border-color 0.2s;
	}
	.branch-select:focus {
		border-color: rgba(59, 130, 246, 0.5);
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}
	.branch-select option {
		background: white;
		color: #1e293b;
	}

	/* Search */
	.search-wrapper {
		display: flex;
		align-items: center;
		position: relative;
		flex: 1;
		min-width: 180px;
		max-width: 300px;
	}
	.search-icon-inner {
		position: absolute;
		left: 0.6rem;
		font-size: 0.85rem;
		color: #94a3b8;
		pointer-events: none;
	}
	.search-input {
		width: 100%;
		padding: 0.42rem 2rem 0.42rem 2rem;
		background: rgba(255, 255, 255, 0.75);
		border: 1px solid rgba(0, 0, 0, 0.1);
		border-radius: 8px;
		color: #1e293b;
		font-size: 0.82rem;
		outline: none;
		transition: all 0.2s;
	}
	.search-input::placeholder {
		color: #b0bec5;
	}
	.search-input:focus {
		border-color: rgba(59, 130, 246, 0.45);
		background: white;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}
	.clear-search-btn-inner {
		position: absolute;
		right: 0.5rem;
		background: rgba(0, 0, 0, 0.08);
		color: #64748b;
		border: none;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 13px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
		line-height: 1;
	}
	.clear-search-btn-inner:hover {
		background: rgba(0, 0, 0, 0.15);
		color: #1e293b;
	}

	/* Column selector */
	.column-selector-wrapper {
		position: relative;
	}
	.columns-btn {
		background: rgba(59, 130, 246, 0.08);
		color: #1d4ed8;
		border: 1px solid rgba(59, 130, 246, 0.25);
		padding: 0.45rem 0.9rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.82rem;
		font-weight: 600;
		white-space: nowrap;
		display: flex;
		align-items: center;
		gap: 0.35rem;
		transition: all 0.2s;
	}
	.columns-btn:hover {
		background: rgba(59, 130, 246, 0.15);
		color: #1e40af;
	}
	.arrow {
		font-size: 0.68rem;
	}

	.column-dropdown {
		position: absolute;
		top: calc(100% + 6px);
		right: 0;
		background: rgba(255, 255, 255, 0.97);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(0, 0, 0, 0.1);
		border-radius: 12px;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
		z-index: 1000;
		min-width: 240px;
		max-height: 380px;
		overflow-y: auto;
	}
	.col-controls {
		padding: 0.7rem;
		border-bottom: 1px solid rgba(0, 0, 0, 0.06);
		display: flex;
		gap: 0.5rem;
	}
	.ctrl-btn {
		flex: 1;
		background: #f8fafc;
		color: #475569;
		border: 1px solid #e2e8f0;
		padding: 0.38rem 0.5rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.78rem;
		transition: all 0.2s;
	}
	.ctrl-btn:hover {
		background: #f1f5f9;
		color: #1e293b;
		border-color: #cbd5e1;
	}
	.column-list {
		padding: 0.4rem;
	}
	.column-item {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.45rem 0.7rem;
		border-radius: 6px;
		cursor: pointer;
		transition: background 0.15s;
		color: #374151;
		font-size: 0.82rem;
	}
	.column-item:hover {
		background: #f8fafc;
		color: #1e293b;
	}
	.column-item input[type="checkbox"] {
		width: 14px;
		height: 14px;
		accent-color: #3b82f6;
		flex-shrink: 0;
	}

	/* ===================== STATUS BAR ===================== */
	.status-bar {
		font-size: 0.76rem;
		color: #94a3b8;
		padding: 0 0.3rem;
		flex-shrink: 0;
	}

	/* ===================== TABLE CARD ===================== */
	.table-card {
		background: rgba(255, 255, 255, 0.75);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.9);
		border-radius: 14px;
		overflow: hidden;
		flex: 1;
		display: flex;
		flex-direction: column;
		box-shadow: 0 4px 20px rgba(59, 130, 246, 0.07);
		min-height: 0;
	}

	.vendor-table {
		overflow: auto;
		flex: 1;
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		position: sticky;
		top: 0;
		z-index: 10;
	}

	th {
		padding: 0.7rem 0.875rem;
		text-align: left;
		font-weight: 600;
		font-size: 0.74rem;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		background: rgba(241, 245, 249, 0.95);
		border-bottom: 1px solid #e2e8f0;
		border-right: 1px solid #f1f5f9;
		white-space: nowrap;
		backdrop-filter: blur(10px);
	}
	th:last-child {
		border-right: none;
	}

	td {
		padding: 0.6rem 0.875rem;
		border-bottom: 1px solid #f1f5f9;
		border-right: 1px solid #f8fafc;
		color: #374151;
		font-size: 0.84rem;
		vertical-align: middle;
	}
	td:last-child {
		border-right: none;
	}

	tbody tr {
		transition: background 0.15s;
	}
	tbody tr:hover {
		background: rgba(59, 130, 246, 0.03);
	}
	tbody tr:last-child td {
		border-bottom: none;
	}

	/* ===================== TABLE CELL STYLES ===================== */
	.vendor-id {
		font-weight: 700;
		color: #2563eb;
		font-family: 'Courier New', monospace;
		font-size: 0.84rem;
	}

	.vendor-name {
		font-weight: 600;
		color: #1e293b;
	}

	.vendor-data {
		color: #64748b;
		font-size: 0.82rem;
	}

	.no-data {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.74rem;
	}

	/* Branch */
	.branch-name {
		font-weight: 500;
	}
	.branch-assigned {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
		padding: 0.18rem 0.55rem;
		border-radius: 6px;
		font-size: 0.78rem;
		display: inline-block;
	}
	.branch-unassigned {
		background: #fef9c3;
		color: #854d0e;
		border: 1px solid #fde68a;
		padding: 0.18rem 0.55rem;
		border-radius: 6px;
		font-size: 0.78rem;
		font-style: italic;
		display: inline-block;
	}

	/* Payment */
	.payment-method {
		font-size: 0.82rem;
	}
	.payment-methods-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.2rem;
	}
	.payment-method-tag {
		background: #dbeafe;
		color: #1e40af;
		padding: 0.1rem 0.42rem;
		border-radius: 10px;
		font-size: 0.71rem;
		font-weight: 500;
		white-space: nowrap;
		border: 1px solid #bfdbfe;
	}

	.payment-priority {
		text-align: center;
	}
	.priority-badge {
		display: inline-block;
		padding: 0.2rem 0.58rem;
		border-radius: 10px;
		font-size: 0.71rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.priority-most {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fecaca;
	}
	.priority-medium {
		background: #ffedd5;
		color: #c2410c;
		border: 1px solid #fed7aa;
	}
	.priority-normal {
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #bfdbfe;
	}
	.priority-low {
		background: #f8fafc;
		color: #94a3b8;
		border: 1px solid #e2e8f0;
	}

	.credit-period {
		color: #059669;
		font-size: 0.82rem;
		font-weight: 500;
	}
	.bank-info {
		font-size: 0.79rem;
		color: #475569;
		max-width: 120px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.last-visit {
		font-size: 0.77rem;
		color: #64748b;
		white-space: nowrap;
	}
	.no-visit {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.72rem;
	}

	/* Place & Location */
	.vendor-place, .vendor-location {
		padding: 0.5rem 0.875rem;
	}
	.place-text {
		font-size: 0.79rem;
		color: #475569;
	}
	.no-place, .no-location {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.72rem;
	}
	.location-actions {
		display: flex;
		flex-direction: column;
		gap: 0.22rem;
		align-items: center;
	}
	.location-link {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.28rem 0.55rem;
		background: #dbeafe;
		color: #1d4ed8;
		text-decoration: none;
		border-radius: 4px;
		font-size: 0.72rem;
		font-weight: 500;
		transition: all 0.2s;
		border: 1px solid #bfdbfe;
		white-space: nowrap;
	}
	.location-link:hover {
		background: #bfdbfe;
		color: #1e40af;
	}
	.share-location-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.22rem 0.48rem;
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
		border-radius: 4px;
		font-size: 0.7rem;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}
	.share-location-btn:hover {
		background: #bbf7d0;
		color: #14532d;
	}

	/* Categories & Delivery */
	.vendor-categories, .vendor-delivery-modes {
		max-width: 200px;
	}
	.category-badges, .delivery-mode-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.2rem;
	}
	.category-badge {
		background: #e0f2fe;
		color: #0369a1;
		padding: 0.1rem 0.38rem;
		border-radius: 4px;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
		border: 1px solid #bae6fd;
	}
	.no-categories, .no-delivery-modes {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.72rem;
	}
	.delivery-mode-badge {
		background: #fef9c3;
		color: #a16207;
		padding: 0.1rem 0.38rem;
		border-radius: 4px;
		font-size: 0.7rem;
		font-weight: 500;
		white-space: nowrap;
		border: 1px solid #fde68a;
	}

	/* Return policy */
	.return-policy-cell {
		text-align: center;
	}
	.return-policy-badge {
		display: inline-block;
		padding: 0.18rem 0.55rem;
		border-radius: 10px;
		font-size: 0.71rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.can-return {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}
	.cannot-return {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fecaca;
	}
	.no-return-badge {
		background: #f8fafc;
		color: #64748b;
		border: 1px solid #e2e8f0;
	}
	.returns-accepted {
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #bfdbfe;
	}
	.no-policy {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.72rem;
	}

	/* VAT */
	.vat-cell, .vat-number-cell {
		text-align: center;
	}
	.vat-badge {
		display: inline-block;
		padding: 0.18rem 0.55rem;
		border-radius: 10px;
		font-size: 0.71rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.vat-applicable {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}
	.no-vat {
		background: #f8fafc;
		color: #64748b;
		border: 1px solid #e2e8f0;
	}
	.vat-number {
		font-family: monospace;
		font-weight: 600;
		color: #374151;
		background: #f8fafc;
		padding: 0.18rem 0.42rem;
		border-radius: 4px;
		border: 1px solid #e2e8f0;
		font-size: 0.79rem;
	}
	.no-vat-note {
		color: #7c3aed;
		cursor: help;
		text-decoration: underline;
		font-size: 0.72rem;
	}
	.no-vat-info {
		color: #cbd5e1;
		font-style: italic;
		font-size: 0.72rem;
	}

	/* Status buttons */
	.status-cell {
		text-align: center;
	}
	.action-buttons {
		display: flex;
		gap: 0.4rem;
		justify-content: center;
		align-items: center;
	}
	.edit-btn, .status-cycle-btn {
		padding: 0.28rem 0.62rem;
		border: 1px solid transparent;
		border-radius: 6px;
		font-size: 0.74rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		white-space: nowrap;
	}
	.edit-btn {
		background: #dbeafe;
		color: #1d4ed8;
		border-color: #bfdbfe;
	}
	.edit-btn:hover {
		background: #bfdbfe;
		color: #1e40af;
		transform: translateY(-1px);
	}
	.status-cycle-btn:hover {
		transform: translateY(-1px);
	}
	.status-active {
		background: #dcfce7;
		color: #166534;
		border-color: #bbf7d0;
	}
	.status-active:hover {
		background: #bbf7d0;
	}
	.status-blacklisted {
		background: #fee2e2;
		color: #991b1b;
		border-color: #fecaca;
	}
	.status-blacklisted:hover {
		background: #fecaca;
	}
	.status-deactivated {
		background: #ffedd5;
		color: #c2410c;
		border-color: #fed7aa;
	}
	.status-deactivated:hover {
		background: #fed7aa;
	}

	/* ===================== STATE BOXES ===================== */
	.state-box {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		text-align: center;
		color: #64748b;
		gap: 0.4rem;
	}
	.state-icon {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
		display: block;
	}
	.error-state {
		color: #dc2626;
	}
	.state-box h3 {
		color: #1e293b;
		margin: 0;
		font-size: 1.05rem;
	}
	.state-box p {
		color: #64748b;
		margin: 0;
		font-size: 0.88rem;
	}
	.action-state-btn {
		margin-top: 0.5rem;
		background: #dbeafe;
		color: #1d4ed8;
		border: 1px solid #bfdbfe;
		padding: 0.48rem 1.2rem;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		font-size: 0.875rem;
		transition: all 0.2s;
	}
	.action-state-btn:hover {
		background: #bfdbfe;
		color: #1e40af;
	}

	.loading-state {
		gap: 0.5rem;
	}
	.loading-spinner {
		font-size: 2.5rem;
		animation: spin 2s linear infinite;
	}
	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}
	.progress-bar {
		width: 260px;
		height: 5px;
		background: #e2e8f0;
		border-radius: 3px;
		overflow: hidden;
		margin: 0.3rem 0;
	}
	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6, #60a5fa);
		transition: width 0.3s ease;
		border-radius: 3px;
	}
	.progress-text {
		font-size: 0.8rem;
		color: #94a3b8;
	}

	/* ===================== RESPONSIVE ===================== */
	@media (max-width: 768px) {
		.manage-vendor {
			padding: 0.5rem;
		}
		.top-controls-card {
			gap: 0.4rem;
			padding: 0.5rem 0.75rem;
		}
		.v-divider {
			display: none;
		}
		.search-wrapper {
			min-width: 140px;
			max-width: 100%;
		}
		td, th {
			padding: 0.48rem 0.55rem;
			font-size: 0.77rem;
		}
	}
</style>
