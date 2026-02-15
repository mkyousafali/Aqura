<script lang="ts">
	import { t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';

	let activeTab = 'Quick Report';
	let loading = false;

	// Tab definitions
	$: tabs = [
		{ id: 'Quick Report', label: $locale === 'ar' ? 'تقرير سريع' : 'Quick Report', icon: '📋', color: 'green' },
		{ id: 'Near Expiry', label: $locale === 'ar' ? 'قرب الانتهاء' : 'Near Expiry', icon: '⏰', color: 'orange' },
		{ id: 'All Products', label: $locale === 'ar' ? 'جميع المنتجات' : 'All Products', icon: '📦', color: 'blue' },
		{ id: 'Deleted', label: $locale === 'ar' ? 'المحذوفة' : 'Deleted', icon: '🗑️', color: 'red' }
	];

	// Branch info cache
	interface BranchInfo {
		name: string;
		location: string;
	}
	let branchCache: Record<string, BranchInfo> = {};
	let employeeCache: Record<string, {name_en: string, name_ar: string}> = {};

	// Quick Report data
	interface QuickReportItem {
		barcode: string;
		product_name: string;
		product_name_en: string;
		product_name_ar: string;
		expiry_date: string;
		days_left: number;
		branch_id: string;
		branch_name: string;
		managed_by: any[];
		employee_name: string;
		status: string;
	}
	let allQuickReportItems: QuickReportItem[] = [];

	// Filters
	let selectedBranchFilter = '';
	let searchBarcode = '';
	let searchProductName = '';

	// Filtered data (reactive)
	$: filteredQuickReport = allQuickReportItems.filter(item => {
		if (selectedBranchFilter && item.branch_id !== selectedBranchFilter) return false;
		if (searchBarcode && !item.barcode.toLowerCase().includes(searchBarcode.toLowerCase())) return false;
		if (searchProductName) {
			const query = searchProductName.toLowerCase();
			if (!item.product_name.toLowerCase().includes(query) &&
				!item.product_name_en.toLowerCase().includes(query) &&
				!item.product_name_ar.toLowerCase().includes(query)) return false;
		}
		return true;
	});

	// Available branches for filter dropdown
	$: availableBranches = (() => {
		const ids = [...new Set(allQuickReportItems.map(i => i.branch_id))];
		return ids.map(id => {
			const info = branchCache[id];
			const name = info ? (info.location ? `${info.name} (${info.location})` : info.name) : id;
			return { id, name };
		}).sort((a, b) => a.name.localeCompare(b.name));
	})();

	// Near Expiry data (reuses same interface)
	let allNearExpiryItems: QuickReportItem[] = [];
	let nearExpiryLoading = false;

	// Near Expiry filters
	let neBranchFilter = '';
	let neSearchBarcode = '';
	let neSearchProductName = '';

	$: filteredNearExpiry = allNearExpiryItems.filter(item => {
		if (neBranchFilter && item.branch_id !== neBranchFilter) return false;
		if (neSearchBarcode && !item.barcode.toLowerCase().includes(neSearchBarcode.toLowerCase())) return false;
		if (neSearchProductName) {
			const query = neSearchProductName.toLowerCase();
			if (!item.product_name.toLowerCase().includes(query) &&
				!item.product_name_en.toLowerCase().includes(query) &&
				!item.product_name_ar.toLowerCase().includes(query)) return false;
		}
		return true;
	});

	$: neAvailableBranches = (() => {
		const ids = [...new Set(allNearExpiryItems.map(i => i.branch_id))];
		return ids.map(id => {
			const info = branchCache[id];
			const name = info ? (info.location ? `${info.name} (${info.location})` : info.name) : id;
			return { id, name };
		}).sort((a, b) => a.name.localeCompare(b.name));
	})();

	// Deleted products data
	interface DeletedProduct {
		barcode: string;
		product_name: string;
		product_name_en: string;
		product_name_ar: string;
		managed_by: any[];
		employee_name: string;
	}
	let allDeletedProducts: DeletedProduct[] = [];
	let deletedLoading = false;
	let deletedSearchBarcode = '';
	let deletedSearchName = '';

	// All Products data (reuses QuickReportItem) - server-side pagination + search
	let allProductsItems: QuickReportItem[] = [];
	let allProductsLoading = false;
	let apBranchFilter = '';
	let apSearchBarcode = '';
	let apSearchProductName = '';
	let apCurrentPage = 1;
	let apTotalCount = 0;
	let apPageSize = 1000;
	let apIsSearchMode = false;
	let apSearchTimer: ReturnType<typeof setTimeout> | null = null;
	let apBranchList: { id: string; name: string }[] = [];

	$: apTotalPages = Math.max(1, Math.ceil(apTotalCount / apPageSize));

	// Debounced search: when user types, wait 500ms then search server-side
	function apTriggerSearch() {
		if (apSearchTimer) clearTimeout(apSearchTimer);
		apSearchTimer = setTimeout(() => {
			loadAllProducts(1, true);
		}, 500);
	}

	// React to branch filter change (immediate, server-side)
	function apOnBranchChange() {
		loadAllProducts(1, !!(apSearchBarcode || apSearchProductName));
	}

	$: filteredDeleted = allDeletedProducts.filter(item => {
		if (deletedSearchBarcode && !item.barcode.toLowerCase().includes(deletedSearchBarcode.toLowerCase())) return false;
		if (deletedSearchName) {
			const query = deletedSearchName.toLowerCase();
			if (!item.product_name.toLowerCase().includes(query) &&
				!item.product_name_en.toLowerCase().includes(query) &&
				!item.product_name_ar.toLowerCase().includes(query)) return false;
		}
		return true;
	});

	onMount(() => {
		loadQuickReport();
	});

	function handleTabChange() {
		if (activeTab === 'Quick Report') {
			loadQuickReport();
		} else if (activeTab === 'Near Expiry') {
			loadNearExpiry();
		} else if (activeTab === 'All Products') {
			loadAllProducts(1, false);
		} else if (activeTab === 'Deleted') {
			loadDeletedProducts();
		}
	}

	async function loadNearExpiry() {
		nearExpiryLoading = true;
		try {
			const { data: rows, error } = await supabase
				.rpc('get_quick_expiry_report', { days_threshold: 15 });

			if (error) {
				console.error('Error loading near expiry:', error);
				return;
			}

			const allBranchIds = new Set<string>();
			const items: QuickReportItem[] = [];

			for (const row of rows || []) {
				const branchId = String(row.branch_id);
				allBranchIds.add(branchId);

				const productName = $locale === 'ar'
					? (row.product_name_ar || row.product_name_en || '—')
					: (row.product_name_en || row.product_name_ar || '—');

				const managed = parseManagedBy(row.managed_by);

				items.push({
					barcode: row.barcode,
					product_name: productName,
					product_name_en: row.product_name_en || '',
					product_name_ar: row.product_name_ar || '',
					expiry_date: row.expiry_date,
					days_left: row.days_left,
					branch_id: branchId,
					branch_name: '',
					managed_by: managed,
					employee_name: '',
					status: ''
				});
			}

			await loadBranchNames(Array.from(allBranchIds));

			// Resolve employee names from managed_by
			const empIds = new Set<string>();
			for (const item of items) {
				for (const entry of item.managed_by) {
					if (entry?.employee_id) empIds.add(entry.employee_id);
				}
			}
			await resolveEmployeeNames(Array.from(empIds));

			for (const item of items) {
				item.branch_name = getBranchDisplayName(item.branch_id);
				item.employee_name = getEmployeeName(item.managed_by, item.branch_id);
				item.status = getStatus(item.managed_by, item.branch_id);
			}

			// Sort by nearest expiry date, then branch
			items.sort((a, b) => {
				const daysCmp = a.days_left - b.days_left;
				if (daysCmp !== 0) return daysCmp;
				return a.branch_name.localeCompare(b.branch_name);
			});

			allNearExpiryItems = items;
		} catch (err) {
			console.error('Error loading near expiry:', err);
		} finally {
			nearExpiryLoading = false;
		}
	}

	async function loadBranchNames(branchIds: string[]) {
		const uncached = branchIds.filter(id => !branchCache[id]);
		if (uncached.length === 0) return;

		const { data: branches } = await supabase
			.from('branches')
			.select('id, name_en, name_ar, location_en, location_ar')
			.in('id', uncached);

		for (const b of branches || []) {
			const name = $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
			const location = $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
			branchCache[b.id] = { name, location };
		}
	}

	async function loadQuickReport() {
		loading = true;
		try {
			const { data: rows, error } = await supabase
				.rpc('get_quick_expiry_report', { days_threshold: 15 });

			if (error) {
				console.error('Error loading quick report:', error);
				return;
			}

			const allBranchIds = new Set<string>();
			const items: QuickReportItem[] = [];

			for (const row of rows || []) {
				const branchId = String(row.branch_id);
				allBranchIds.add(branchId);

				const productName = $locale === 'ar'
					? (row.product_name_ar || row.product_name_en || '—')
					: (row.product_name_en || row.product_name_ar || '—');

				const managed = parseManagedBy(row.managed_by);

				items.push({
					barcode: row.barcode,
					product_name: productName,
					product_name_en: row.product_name_en || '',
					product_name_ar: row.product_name_ar || '',
					expiry_date: row.expiry_date,
					days_left: row.days_left,
					branch_id: branchId,
					branch_name: '',
					managed_by: managed,
					employee_name: '',
					status: ''
				});
			}

			await loadBranchNames(Array.from(allBranchIds));

			// Resolve employee names from managed_by
			const empIds = new Set<string>();
			for (const item of items) {
				for (const entry of item.managed_by) {
					if (entry?.employee_id) empIds.add(entry.employee_id);
				}
			}
			await resolveEmployeeNames(Array.from(empIds));

			for (const item of items) {
				item.branch_name = getBranchDisplayName(item.branch_id);
				item.employee_name = getEmployeeName(item.managed_by, item.branch_id);
				item.status = getStatus(item.managed_by, item.branch_id);
			}

			// Sort by nearest expiry date, then branch
			items.sort((a, b) => {
				const daysCmp = a.days_left - b.days_left;
				if (daysCmp !== 0) return daysCmp;
				return a.branch_name.localeCompare(b.branch_name);
			});

			allQuickReportItems = items;
		} catch (err) {
			console.error('Error loading quick report:', err);
		} finally {
			loading = false;
		}
	}

	function getBranchDisplayName(branchId: string): string {
		const info = branchCache[branchId];
		if (!info) return $locale === 'ar' ? `فرع ${branchId}` : `Branch ${branchId}`;
		return info.location ? `${info.name} (${info.location})` : info.name;
	}

	function formatDate(dateStr: string): string {
		try {
			const d = new Date(dateStr);
			return d.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', {
				year: 'numeric', month: 'short', day: 'numeric'
			});
		} catch {
			return dateStr;
		}
	}

	function clearFilters() {
		selectedBranchFilter = '';
		searchBarcode = '';
		searchProductName = '';
	}

	function clearNearExpiryFilters() {
		neBranchFilter = '';
		neSearchBarcode = '';
		neSearchProductName = '';
	}

	function clearAllProductsFilters() {
		apBranchFilter = '';
		apSearchBarcode = '';
		apSearchProductName = '';
		apIsSearchMode = false;
		loadAllProducts(1, false);
	}

	async function loadAllProducts(page = 1, isSearch = false) {
		allProductsLoading = true;
		apIsSearchMode = isSearch;
		try {
			const params: Record<string, any> = {
				p_page: page,
				p_page_size: apPageSize
			};
			if (apBranchFilter) params.p_branch_id = parseInt(apBranchFilter);
			if (apSearchBarcode) params.p_search_barcode = apSearchBarcode;
			if (apSearchProductName) params.p_search_name = apSearchProductName;

			const { data: rows, error } = await supabase
				.rpc('get_all_expiry_products', params);

			if (error) {
				console.error('Error loading all products:', error);
				return;
			}

			const allBranchIds = new Set<string>();
			const items: QuickReportItem[] = [];

			// Get total_count from first row
			if (rows && rows.length > 0) {
				apTotalCount = Number(rows[0].total_count) || 0;
			} else {
				apTotalCount = 0;
			}

			for (const row of rows || []) {
				const branchId = String(row.branch_id);
				allBranchIds.add(branchId);

				const productName = $locale === 'ar'
					? (row.product_name_ar || row.product_name_en || '—')
					: (row.product_name_en || row.product_name_ar || '—');

				const managed = parseManagedBy(row.managed_by);

				items.push({
					barcode: row.barcode,
					product_name: productName,
					product_name_en: row.product_name_en || '',
					product_name_ar: row.product_name_ar || '',
					expiry_date: row.expiry_date,
					days_left: row.days_left,
					branch_id: branchId,
					branch_name: '',
					managed_by: managed,
					employee_name: '',
					status: ''
				});
			}

			await loadBranchNames(Array.from(allBranchIds));

			// Also load branch list for dropdown if not loaded yet
			if (apBranchList.length === 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar');
				if (branches) {
					apBranchList = branches.map(b => {
						const name = $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
						const loc = $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
						return { id: String(b.id), name: loc ? `${name} (${loc})` : name };
					}).sort((a, b) => a.name.localeCompare(b.name));
				}
			}

			const empIds = new Set<string>();
			for (const item of items) {
				for (const entry of item.managed_by) {
					if (entry?.employee_id) empIds.add(entry.employee_id);
				}
			}
			await resolveEmployeeNames(Array.from(empIds));

			for (const item of items) {
				item.branch_name = getBranchDisplayName(item.branch_id);
				item.employee_name = getEmployeeName(item.managed_by, item.branch_id);
				item.status = getStatus(item.managed_by, item.branch_id);
			}

			allProductsItems = items;
			apCurrentPage = page;
		} catch (err) {
			console.error('Error loading all products:', err);
		} finally {
			allProductsLoading = false;
		}
	}

	async function deleteExpiryItem(barcode: string) {
		try {
			// Fetch current managed_by and append this employee
			const { data: existing } = await supabase
				.from('erp_synced_products')
				.select('managed_by')
				.eq('barcode', barcode)
				.single();

			const currentManaged = parseManagedBy(existing?.managed_by);
			const employeeId = $currentUser?.employee_id || '';
			currentManaged.push({
				employee_id: employeeId,
				action: 'deleted',
				timestamp: new Date().toISOString()
			});

			const { error } = await supabase
				.from('erp_synced_products')
				.update({ expiry_hidden: true, managed_by: currentManaged })
				.eq('barcode', barcode);

			if (error) {
				console.error('Error hiding expiry item:', error);
				return;
			}

			// Remove from local arrays
			allQuickReportItems = allQuickReportItems.filter(i => i.barcode !== barcode);
			allNearExpiryItems = allNearExpiryItems.filter(i => i.barcode !== barcode);
			allProductsItems = allProductsItems.filter(i => i.barcode !== barcode);
		} catch (err) {
			console.error('Error hiding expiry item:', err);
		}
	}

	async function loadDeletedProducts() {
		deletedLoading = true;
		try {
			const { data: rows, error } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, managed_by')
				.eq('expiry_hidden', true)
				.order('barcode', { ascending: true });

			if (error) {
				console.error('Error loading deleted products:', error);
				return;
			}

			// Resolve employee names
			const empIds = new Set<string>();
			for (const row of rows || []) {
				const managed = parseManagedBy(row.managed_by);
				for (const entry of managed) {
					if (entry?.employee_id) empIds.add(entry.employee_id);
				}
			}
			await resolveEmployeeNames(Array.from(empIds));

			allDeletedProducts = (rows || []).map(row => {
				const managed = parseManagedBy(row.managed_by);
				return {
					barcode: row.barcode,
					product_name: $locale === 'ar'
						? (row.product_name_ar || row.product_name_en || '—')
						: (row.product_name_en || row.product_name_ar || '—'),
					product_name_en: row.product_name_en || '',
					product_name_ar: row.product_name_ar || '',
					managed_by: managed,
					employee_name: getEmployeeName(managed)
				};
			});
		} catch (err) {
			console.error('Error loading deleted products:', err);
		} finally {
			deletedLoading = false;
		}
	}

	async function undoDeleteExpiryItem(barcode: string) {
		try {
			const { error } = await supabase
				.from('erp_synced_products')
				.update({ expiry_hidden: false })
				.eq('barcode', barcode);

			if (error) {
				console.error('Error restoring expiry item:', error);
				return;
			}

			allDeletedProducts = allDeletedProducts.filter(i => i.barcode !== barcode);
		} catch (err) {
			console.error('Error restoring expiry item:', err);
		}
	}

	function clearDeletedFilters() {
		deletedSearchBarcode = '';
		deletedSearchName = '';
	}

	function parseManagedBy(val: any): any[] {
		if (!val) return [];
		if (Array.isArray(val)) return val;
		if (typeof val === 'string') {
			try { return JSON.parse(val); } catch { return []; }
		}
		return [];
	}

	async function resolveEmployeeNames(employeeIds: string[]) {
		const uncached = employeeIds.filter(id => id && !employeeCache[id]);
		if (uncached.length === 0) return;

		const { data: employees } = await supabase
			.from('hr_employee_master')
			.select('id, name_en, name_ar')
			.in('id', uncached);

		for (const emp of employees || []) {
			employeeCache[emp.id] = { name_en: emp.name_en || '', name_ar: emp.name_ar || '' };
		}
	}

	function getEmployeeName(managedBy: any[], branchId?: string): string {
		if (!managedBy || managedBy.length === 0) return '';
		// Filter entries for this specific branch
		const branchEntries = branchId
			? managedBy.filter(e => String(e?.branch_id) === String(branchId))
			: managedBy;
		if (branchEntries.length === 0) return '';
		const lastEntry = branchEntries[branchEntries.length - 1];
		const empId = lastEntry?.employee_id;
		if (!empId) return '';
		const cached = employeeCache[empId];
		if (!cached) return empId;
		return $locale === 'ar' ? (cached.name_ar || cached.name_en) : (cached.name_en || cached.name_ar);
	}

	function getStatus(managedBy: any[], branchId?: string): string {
		if (!managedBy || managedBy.length === 0) {
			return $locale === 'ar' ? 'جديد' : 'New';
		}
		// Check if any entry exists for this specific branch
		const branchEntries = branchId
			? managedBy.filter(e => String(e?.branch_id) === String(branchId))
			: managedBy;
		if (branchEntries.length === 0) {
			return $locale === 'ar' ? 'جديد' : 'New';
		}
		return $locale === 'ar' ? 'تمت المعالجة' : 'Managed';
	}

	function isClaimed(managedBy: any[], branchId: string): boolean {
		if (!managedBy || managedBy.length === 0) return false;
		return managedBy.some(e => String(e?.branch_id) === String(branchId));
	}

	// Assign popup state
	let showAssignPopup = false;
	let assignBarcode = '';
	let assignBranchId = '';
	let assignSearch = '';
	let allEmployees: {id: string, name_en: string, name_ar: string}[] = [];
	let assignLoading = false;

	$: filteredEmployees = allEmployees.filter(emp => {
		if (!assignSearch) return true;
		const q = assignSearch.toLowerCase();
		return emp.id.toLowerCase().includes(q) ||
			emp.name_en.toLowerCase().includes(q) ||
			emp.name_ar.toLowerCase().includes(q);
	});

	async function openAssignPopup(barcode: string, branchId: string) {
		assignBarcode = barcode;
		assignBranchId = branchId;
		assignSearch = '';
		showAssignPopup = true;
		if (allEmployees.length === 0) {
			assignLoading = true;
			const { data } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar')
				.order('name_en', { ascending: true });
			allEmployees = data || [];
			assignLoading = false;
		}
	}

	async function assignEmployee(employeeId: string) {
		try {
			const { data: existing } = await supabase
				.from('erp_synced_products')
				.select('managed_by')
				.eq('barcode', assignBarcode)
				.single();

			const currentManaged = parseManagedBy(existing?.managed_by);
			currentManaged.push({
				employee_id: employeeId,
				branch_id: assignBranchId,
				action: 'assigned',
				timestamp: new Date().toISOString()
			});

			const { error } = await supabase
				.from('erp_synced_products')
				.update({ managed_by: currentManaged })
				.eq('barcode', assignBarcode);

			if (error) {
				console.error('Error assigning employee:', error);
				return;
			}

			// Resolve the employee name
			await resolveEmployeeNames([employeeId]);

			// Update local data
			const updateItem = (items: QuickReportItem[]) => {
				return items.map(item => {
					if (item.barcode === assignBarcode) {
						const updated = {
							...item,
							managed_by: currentManaged,
							employee_name: getEmployeeName(currentManaged, item.branch_id),
							status: getStatus(currentManaged, item.branch_id)
						};
						return updated;
					}
					return item;
				});
			};
			allQuickReportItems = updateItem(allQuickReportItems);
			allNearExpiryItems = updateItem(allNearExpiryItems);
			allProductsItems = updateItem(allProductsItems);

			showAssignPopup = false;
		} catch (err) {
			console.error('Error assigning employee:', err);
		}
	}

	// ========== MULTI-SELECT STATE ==========
	let selectedItems: Set<string> = new Set();
	let taskItems: QuickReportItem[] = [];

	function getItemKey(item: QuickReportItem): string {
		return item.barcode + '|' + item.branch_id + '|' + item.expiry_date;
	}

	function toggleSelectItem(item: QuickReportItem) {
		const key = getItemKey(item);
		if (selectedItems.has(key)) {
			selectedItems.delete(key);
		} else {
			selectedItems.add(key);
		}
		selectedItems = new Set(selectedItems);
	}

	function isItemSelected(item: QuickReportItem): boolean {
		return selectedItems.has(getItemKey(item));
	}

	function toggleSelectAll(items: QuickReportItem[]) {
		const allSelected = items.every(i => selectedItems.has(getItemKey(i)));
		if (allSelected) {
			items.forEach(i => selectedItems.delete(getItemKey(i)));
		} else {
			items.forEach(i => selectedItems.add(getItemKey(i)));
		}
		selectedItems = new Set(selectedItems);
	}

	function isAllSelected(items: QuickReportItem[]): boolean {
		return items.length > 0 && items.every(i => selectedItems.has(getItemKey(i)));
	}

	function openBulkTaskPopup() {
		const currentItems = activeTab === 'Quick Report' ? filteredQuickReport : filteredNearExpiry;
		taskItems = currentItems.filter(i => selectedItems.has(getItemKey(i)));
		if (taskItems.length === 0) return;
		taskItem = taskItems[0];
		taskType = '';
		taskSelectedUsers = [];
		taskEmployeeSearch = '';
		taskStep = 'type';
		taskSending = false;
		showTaskPopup = true;
	}

	// ========== TASK POPUP STATE ==========
	let showTaskPopup = false;
	let taskItem: QuickReportItem | null = null;
	let taskType = '';
	let taskEmployeeSearch = '';
	let taskSelectedUsers: { user_id: string; employee_id: string; name: string }[] = [];
	let taskEmployeeList: { id: string; user_id: string; name_en: string; name_ar: string }[] = [];
	let taskLoading = false;
	let taskSending = false;
	let taskStep: 'type' | 'employees' | 'done' = 'type';

	const taskTypes = [
		{ id: 'remove_product', icon: '🗑️', en: 'Remove Product', ar: 'إزالة المنتج' },
		{ id: 'change_expiry', icon: '📅', en: 'Change Expiry Date', ar: 'تغيير تاريخ الانتهاء' },
		{ id: 'check_availability', icon: '🔍', en: 'Check Product Availability', ar: 'التحقق من توفر المنتج' }
	];

	$: filteredTaskEmployees = taskEmployeeList.filter(emp => {
		if (!taskEmployeeSearch) return true;
		const q = taskEmployeeSearch.toLowerCase();
		return emp.id.toLowerCase().includes(q) ||
			emp.name_en.toLowerCase().includes(q) ||
			emp.name_ar.toLowerCase().includes(q);
	});

	async function openTaskPopup(item: QuickReportItem) {
		taskItem = item;
		taskType = '';
		taskSelectedUsers = [];
		taskEmployeeSearch = '';
		taskStep = 'type';
		taskSending = false;
		showTaskPopup = true;
	}

	async function selectTaskType(type: string) {
		taskType = type;
		taskStep = 'employees';
		taskLoading = true;

		// If item is claimed for this branch, auto-select the claimed employee
		if (taskItem && isClaimed(taskItem.managed_by, taskItem.branch_id)) {
			const branchEntries = taskItem.managed_by.filter(
				(e: any) => String(e?.branch_id) === String(taskItem!.branch_id)
			);
			if (branchEntries.length > 0) {
				const lastEntry = branchEntries[branchEntries.length - 1];
				const empId = lastEntry?.employee_id;
				if (empId) {
					// Get user_id from hr_employee_master
					const { data: empRecord } = await supabase
						.from('hr_employee_master')
						.select('id, user_id, name_en, name_ar')
						.eq('id', empId)
						.single();

					if (empRecord?.user_id) {
						const name = $locale === 'ar'
							? (empRecord.name_ar || empRecord.name_en)
							: (empRecord.name_en || empRecord.name_ar);
						taskSelectedUsers = [{
							user_id: empRecord.user_id,
							employee_id: empRecord.id,
							name: name || empId
						}];
					}
				}
			}
		}

		// Load all employees with user_id for search/select
		if (taskEmployeeList.length === 0) {
			const { data } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar')
				.not('user_id', 'is', null)
				.order('name_en', { ascending: true });
			taskEmployeeList = data || [];
		}

		taskLoading = false;
	}

	function toggleTaskEmployee(emp: { id: string; user_id: string; name_en: string; name_ar: string }) {
		const exists = taskSelectedUsers.find(u => u.user_id === emp.user_id);
		if (exists) {
			taskSelectedUsers = taskSelectedUsers.filter(u => u.user_id !== emp.user_id);
		} else {
			const name = $locale === 'ar' ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar);
			taskSelectedUsers = [...taskSelectedUsers, {
				user_id: emp.user_id,
				employee_id: emp.id,
				name: name || emp.id
			}];
		}
	}

	function isTaskEmployeeSelected(userId: string): boolean {
		return taskSelectedUsers.some(u => u.user_id === userId);
	}

	async function sendQuickTask() {
		const items = taskItems.length > 0 ? taskItems : (taskItem ? [taskItem] : []);
		if (items.length === 0 || !taskType || taskSelectedUsers.length === 0) return;
		taskSending = true;

		try {
			const typeInfo = taskTypes.find(t => t.id === taskType);

			for (const item of items) {
				const title = $locale === 'ar'
					? `${typeInfo?.ar}: ${item.product_name_ar || item.product_name_en}`
					: `${typeInfo?.en}: ${item.product_name_en || item.product_name_ar}`;

				const description = $locale === 'ar'
					? `المنتج: ${item.product_name_ar || item.product_name_en}\nالباركود: ${item.barcode}\nالفرع: ${item.branch_name}\nتاريخ الانتهاء: ${item.expiry_date}\nالأيام المتبقية: ${item.days_left}`
					: `Product: ${item.product_name_en || item.product_name_ar}\nBarcode: ${item.barcode}\nBranch: ${item.branch_name}\nExpiry Date: ${item.expiry_date}\nDays Left: ${item.days_left}`;

				const { data: taskData, error: taskError } = await supabase
					.from('quick_tasks')
					.insert({
						title,
						description,
						price_tag: item.days_left <= 0 ? 'critical' : item.days_left <= 7 ? 'high' : 'medium',
						issue_type: taskType === 'remove_product' ? 'display' : taskType === 'check_availability' ? 'filling' : 'other',
						priority: item.days_left <= 0 ? 'urgent' : item.days_left <= 7 ? 'high' : 'medium',
						assigned_by: $currentUser?.id,
						require_task_finished: true,
						require_photo_upload: false,
						require_erp_reference: false
					})
					.select()
					.single();

				if (taskError) {
					console.error('Error creating quick task:', taskError);
					continue;
				}

				const assignments = taskSelectedUsers.map(u => ({
					quick_task_id: taskData.id,
					assigned_to_user_id: u.user_id,
					status: 'assigned',
					require_task_finished: true,
					require_photo_upload: false,
					require_erp_reference: false
				}));

				await supabase.from('quick_task_assignments').insert(assignments);
			}

			selectedItems = new Set();
			taskStep = 'done';
		} catch (err) {
			console.error('Error sending quick task:', err);
		} finally {
			taskSending = false;
		}
	}

	let copiedBarcode = '';
	async function copyToClipboard(text: string, barcode: string) {
		try {
			await navigator.clipboard.writeText(text);
			copiedBarcode = barcode;
			setTimeout(() => { copiedBarcode = ''; }, 1500);
		} catch (err) {
			console.error('Copy failed:', err);
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header/Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<!-- Refresh button -->
		<button
			class="flex items-center gap-2 px-4 py-2 text-xs font-bold uppercase rounded-xl bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-all border border-emerald-200"
			on:click={loadQuickReport}
			disabled={loading}
		>
			<span class="text-base {loading ? 'animate-spin' : ''}">🔄</span>
			{$locale === 'ar' ? 'تحديث' : 'Refresh'}
		</button>

		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id
					? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : tab.color === 'orange' ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]' : tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]')
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => {
						activeTab = tab.id;
						handleTabChange();
					}}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
					<span class="relative z-10">{tab.label}</span>

					{#if activeTab === tab.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if activeTab === 'Quick Report'}
				{#if loading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if allQuickReportItems.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">✅</div>
						<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'لا توجد منتجات تنتهي صلاحيتها خلال 15 يوم' : 'No products expiring within 15 days'}</p>
					</div>
				{:else}
					<!-- Filter Controls -->
					<div class="mb-4 flex gap-3 flex-wrap">
						<!-- Branch Filter -->
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="qr-branch-filter">
								{$locale === 'ar' ? 'الفرع' : 'Branch'}
							</label>
							<select
								id="qr-branch-filter"
								bind:value={selectedBranchFilter}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="" style="color: #000000 !important; background-color: #ffffff !important;">
									{$locale === 'ar' ? 'جميع الفروع' : 'All Branches'}
								</option>
								{#each availableBranches as branch}
									<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
										{branch.name}
									</option>
								{/each}
							</select>
						</div>
						<!-- Search by Barcode -->
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="qr-barcode-search">
								{$locale === 'ar' ? 'بحث بالباركود' : 'Search Barcode'}
							</label>
							<input
								id="qr-barcode-search"
								type="text"
								bind:value={searchBarcode}
								placeholder={$locale === 'ar' ? 'أدخل الباركود...' : 'Enter barcode...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>
						<!-- Search by Product Name -->
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="qr-name-search">
								{$locale === 'ar' ? 'بحث بالاسم' : 'Search Name'}
							</label>
							<input
								id="qr-name-search"
								type="text"
								bind:value={searchProductName}
								placeholder={$locale === 'ar' ? 'أدخل اسم المنتج...' : 'Enter product name...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>
						<!-- Clear Filters -->
						{#if selectedBranchFilter || searchBarcode || searchProductName}
							<div class="flex items-end">
								<button
									class="px-4 py-2.5 text-xs font-bold uppercase rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200"
									on:click={clearFilters}
								>
									{$locale === 'ar' ? 'مسح' : 'Clear'}
								</button>
							</div>
						{/if}
					</div>

					<!-- Results count -->
					<div class="mb-3 text-xs font-semibold text-slate-500">
						{$locale === 'ar'
							? `عرض ${filteredQuickReport.length} من ${allQuickReportItems.length} منتج`
							: `Showing ${filteredQuickReport.length} of ${allQuickReportItems.length} products`}
					</div>

						<!-- Info: How to send tasks -->
						<div class="mb-3 flex items-center gap-2 px-3 py-2 bg-indigo-50 border border-indigo-200 rounded-xl">
							<span class="text-indigo-500 text-sm">ℹ️</span>
							<span class="text-xs text-indigo-600 font-medium">
								{$locale === 'ar' ? 'حدد المنتجات باستخدام مربعات الاختيار ثم اضغط إرسال لإرسال المهام' : 'Select products using checkboxes, then press Send to send tasks'}
							</span>
						</div>

					<!-- Single Table with Branch Column -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-x-auto flex-1">
							<table class="w-full border-collapse">
								<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">#</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'الباركود' : 'Barcode'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'اسم المنتج' : 'Product Name'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'الفرع' : 'Branch'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'الأيام المتبقية' : 'Days Left'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'حذف' : 'Delete'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'مطالب به' : 'Claimed'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">
											{$locale === 'ar' ? 'الموظف' : 'Employee'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-10">
											<input type="checkbox" class="w-4 h-4 rounded accent-emerald-600 cursor-pointer" checked={isAllSelected(filteredQuickReport)} on:change={() => toggleSelectAll(filteredQuickReport)} />
										</th>
									</tr>
								</thead>
							<tbody class="divide-y divide-slate-200">
								{#if filteredQuickReport.length === 0}
									<tr>
										<td colspan="10" class="px-4 py-12 text-center text-slate-400 text-sm">
												<div class="text-4xl mb-3">🔍</div>
												{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}
											</td>
										</tr>
									{:else}
										{#each filteredQuickReport as item, index}
											<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
												<td class="px-4 py-3 text-sm font-semibold text-slate-800">{index + 1}</td>
												<td class="px-4 py-3 text-sm text-slate-700 font-mono">{item.barcode}</td>
												<td class="px-4 py-3 text-sm text-slate-700 cursor-pointer hover:bg-emerald-50 select-none transition-colors"
													title={$locale === 'ar' ? 'انقر مرتين للنسخ' : 'Double-click to copy'}
													on:dblclick={() => copyToClipboard(item.product_name, item.barcode)}
												>
													{item.product_name}
													{#if copiedBarcode === item.barcode}
														<span class="ml-2 text-xs text-emerald-600 font-bold">✅</span>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.branch_name}</td>
												<td class="px-4 py-3 text-sm text-center text-slate-700">{formatDate(item.expiry_date)}</td>
												<td class="px-4 py-3 text-sm text-center font-mono font-bold
													{item.days_left <= 0 ? 'text-red-700 bg-red-50' : item.days_left <= 7 ? 'text-red-600' : 'text-orange-600'}">
													{#if item.days_left <= 0}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-700">
															{$locale === 'ar' ? 'منتهي!' : 'EXPIRED!'}
														</span>
													{:else}
														{item.days_left} {$locale === 'ar' ? 'يوم' : item.days_left === 1 ? 'day' : 'days'}
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-center">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200 hover:shadow-md"
														on:click={() => deleteExpiryItem(item.barcode)}
													>
														🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'}
													</button>
												</td>
												<td class="px-4 py-3 text-sm text-center">
													{#if isClaimed(item.managed_by, item.branch_id)}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-blue-100 text-blue-700">
															{item.status}
														</span>
													{:else}
														<button
															class="px-3 py-1.5 text-xs font-bold rounded-lg bg-purple-50 text-purple-600 hover:bg-purple-100 transition-all border border-purple-200 hover:shadow-md"
															on:click={() => openAssignPopup(item.barcode, item.branch_id)}
														>
															👤 {$locale === 'ar' ? 'تحديد' : 'Set'}
														</button>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.employee_name || '—'}</td>
												<td class="px-4 py-3 text-sm text-center">
													<input type="checkbox" class="w-4 h-4 rounded accent-indigo-600 cursor-pointer" checked={isItemSelected(item)} on:change={() => toggleSelectItem(item)} />
												</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						</div>
					</div>
				{/if}

				<!-- Floating Selection Bar -->
				{#if selectedItems.size > 0 && activeTab === 'Quick Report'}
					<div class="sticky bottom-0 bg-gradient-to-r from-indigo-600 to-indigo-700 text-white px-6 py-3 rounded-2xl shadow-2xl flex items-center justify-between mt-3 z-20">
						<div class="flex items-center gap-3">
							<span class="text-sm font-bold">{selectedItems.size} {$locale === 'ar' ? 'محدد' : 'selected'}</span>
							<button class="text-xs text-white/70 hover:text-white underline" on:click={() => { selectedItems = new Set(); }}>
								{$locale === 'ar' ? 'إلغاء' : 'Clear'}
							</button>
						</div>
						<button
							class="px-5 py-2 bg-white text-indigo-700 rounded-xl font-bold text-sm hover:bg-indigo-50 transition-all shadow-md"
							on:click={openBulkTaskPopup}
						>
							📤 {$locale === 'ar' ? 'إرسال' : 'Send'}
						</button>
					</div>
				{/if}

			{:else if activeTab === 'Near Expiry'}
				{#if nearExpiryLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if allNearExpiryItems.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">✅</div>
						<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'لا توجد منتجات قرب الانتهاء' : 'No near-expiry products found'}</p>
					</div>
				{:else}
					<!-- Near Expiry Filter Controls -->
					<div class="mb-4 flex gap-3 flex-wrap">
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ne-branch-filter">
								{$locale === 'ar' ? 'الفرع' : 'Branch'}
							</label>
							<select
								id="ne-branch-filter"
								bind:value={neBranchFilter}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="" style="color: #000000 !important; background-color: #ffffff !important;">
									{$locale === 'ar' ? 'جميع الفروع' : 'All Branches'}
								</option>
								{#each neAvailableBranches as branch}
									<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
										{branch.name}
									</option>
								{/each}
							</select>
						</div>
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ne-barcode-search">
								{$locale === 'ar' ? 'بحث بالباركود' : 'Search Barcode'}
							</label>
							<input
								id="ne-barcode-search"
								type="text"
								bind:value={neSearchBarcode}
								placeholder={$locale === 'ar' ? 'أدخل الباركود...' : 'Enter barcode...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
							/>
						</div>
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ne-name-search">
								{$locale === 'ar' ? 'بحث بالاسم' : 'Search Name'}
							</label>
							<input
								id="ne-name-search"
								type="text"
								bind:value={neSearchProductName}
								placeholder={$locale === 'ar' ? 'أدخل اسم المنتج...' : 'Enter product name...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
							/>
						</div>
						{#if neBranchFilter || neSearchBarcode || neSearchProductName}
							<div class="flex items-end">
								<button
									class="px-4 py-2.5 text-xs font-bold uppercase rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200"
									on:click={clearNearExpiryFilters}
								>
									{$locale === 'ar' ? 'مسح' : 'Clear'}
								</button>
							</div>
						{/if}
					</div>

					<div class="mb-3 text-xs font-semibold text-slate-500">
						{$locale === 'ar'
							? `عرض ${filteredNearExpiry.length} من ${allNearExpiryItems.length} منتج`
							: `Showing ${filteredNearExpiry.length} of ${allNearExpiryItems.length} products`}
					</div>

						<!-- Info: How to send tasks -->
						<div class="mb-3 flex items-center gap-2 px-3 py-2 bg-indigo-50 border border-indigo-200 rounded-xl">
							<span class="text-indigo-500 text-sm">ℹ️</span>
							<span class="text-xs text-indigo-600 font-medium">
								{$locale === 'ar' ? 'حدد المنتجات باستخدام مربعات الاختيار ثم اضغط إرسال لإرسال المهام' : 'Select products using checkboxes, then press Send to send tasks'}
							</span>
						</div>

					<!-- Near Expiry Table -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-x-auto flex-1">
							<table class="w-full border-collapse">
								<thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">#</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'الباركود' : 'Barcode'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'اسم المنتج' : 'Product Name'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'الفرع' : 'Branch'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'الأيام المتبقية' : 'Days Left'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'حذف' : 'Delete'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'مطالب به' : 'Claimed'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">
											{$locale === 'ar' ? 'الموظف' : 'Employee'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-10">
											<input type="checkbox" class="w-4 h-4 rounded accent-orange-600 cursor-pointer" checked={isAllSelected(filteredNearExpiry)} on:change={() => toggleSelectAll(filteredNearExpiry)} />
										</th>
									</tr>
								</thead>
							<tbody class="divide-y divide-slate-200">
								{#if filteredNearExpiry.length === 0}
									<tr>
										<td colspan="10" class="px-4 py-12 text-center text-slate-400 text-sm">
												<div class="text-4xl mb-3">🔍</div>
												{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}
											</td>
										</tr>
									{:else}
										{#each filteredNearExpiry as item, index}
											<tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
												<td class="px-4 py-3 text-sm font-semibold text-slate-800">{index + 1}</td>
												<td class="px-4 py-3 text-sm text-slate-700 font-mono">{item.barcode}</td>
												<td class="px-4 py-3 text-sm text-slate-700 cursor-pointer hover:bg-orange-50 select-none transition-colors"
													title={$locale === 'ar' ? 'انقر مرتين للنسخ' : 'Double-click to copy'}
													on:dblclick={() => copyToClipboard(item.product_name, item.barcode)}
												>
													{item.product_name}
													{#if copiedBarcode === item.barcode}
														<span class="ml-2 text-xs text-emerald-600 font-bold">✅</span>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.branch_name}</td>
												<td class="px-4 py-3 text-sm text-center text-slate-700">{formatDate(item.expiry_date)}</td>
												<td class="px-4 py-3 text-sm text-center font-mono font-bold
													{item.days_left <= 0 ? 'text-red-700 bg-red-50' : item.days_left <= 7 ? 'text-red-600' : 'text-orange-600'}">
													{#if item.days_left <= 0}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-700">
															{$locale === 'ar' ? 'منتهي!' : 'EXPIRED!'}
														</span>
													{:else}
														{item.days_left} {$locale === 'ar' ? 'يوم' : item.days_left === 1 ? 'day' : 'days'}
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-center">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200 hover:shadow-md"
														on:click={() => deleteExpiryItem(item.barcode)}
													>
														🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'}
													</button>
												</td>
												<td class="px-4 py-3 text-sm text-center">
													{#if isClaimed(item.managed_by, item.branch_id)}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-blue-100 text-blue-700">
															{item.status}
														</span>
													{:else}
														<button
															class="px-3 py-1.5 text-xs font-bold rounded-lg bg-purple-50 text-purple-600 hover:bg-purple-100 transition-all border border-purple-200 hover:shadow-md"
															on:click={() => openAssignPopup(item.barcode, item.branch_id)}
														>
															👤 {$locale === 'ar' ? 'تحديد' : 'Set'}
														</button>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.employee_name || '—'}</td>
												<td class="px-4 py-3 text-sm text-center">
													<input type="checkbox" class="w-4 h-4 rounded accent-indigo-600 cursor-pointer" checked={isItemSelected(item)} on:change={() => toggleSelectItem(item)} />
												</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						</div>
					</div>
				{/if}

				<!-- Floating Selection Bar -->
				{#if selectedItems.size > 0 && activeTab === 'Near Expiry'}
					<div class="sticky bottom-0 bg-gradient-to-r from-indigo-600 to-indigo-700 text-white px-6 py-3 rounded-2xl shadow-2xl flex items-center justify-between mt-3 z-20">
						<div class="flex items-center gap-3">
							<span class="text-sm font-bold">{selectedItems.size} {$locale === 'ar' ? 'محدد' : 'selected'}</span>
							<button class="text-xs text-white/70 hover:text-white underline" on:click={() => { selectedItems = new Set(); }}>
								{$locale === 'ar' ? 'إلغاء' : 'Clear'}
							</button>
						</div>
						<button
							class="px-5 py-2 bg-white text-indigo-700 rounded-xl font-bold text-sm hover:bg-indigo-50 transition-all shadow-md"
							on:click={openBulkTaskPopup}
						>
							📤 {$locale === 'ar' ? 'إرسال' : 'Send'}
						</button>
					</div>
				{/if}

			{:else if activeTab === 'All Products'}
				<!-- All Products Filter Controls (always visible, server-side search) -->
				<div class="mb-4 flex gap-3 flex-wrap">
					<div class="flex-1 min-w-[180px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ap-branch-filter">
							{$locale === 'ar' ? 'الفرع' : 'Branch'}
						</label>
						<select
							id="ap-branch-filter"
							bind:value={apBranchFilter}
							on:change={apOnBranchChange}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="" style="color: #000000 !important; background-color: #ffffff !important;">
								{$locale === 'ar' ? 'جميع الفروع' : 'All Branches'}
							</option>
							{#each apBranchList as branch}
								<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
									{branch.name}
								</option>
							{/each}
						</select>
					</div>
					<div class="flex-1 min-w-[180px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ap-barcode-search">
							{$locale === 'ar' ? 'بحث بالباركود' : 'Search Barcode'}
						</label>
						<input
							id="ap-barcode-search"
							type="text"
							bind:value={apSearchBarcode}
							on:input={apTriggerSearch}
							placeholder={$locale === 'ar' ? 'أدخل الباركود...' : 'Enter barcode...'}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						/>
					</div>
					<div class="flex-1 min-w-[180px]">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ap-name-search">
							{$locale === 'ar' ? 'بحث بالاسم' : 'Search Name'}
						</label>
						<input
							id="ap-name-search"
							type="text"
							bind:value={apSearchProductName}
							on:input={apTriggerSearch}
							placeholder={$locale === 'ar' ? 'أدخل اسم المنتج...' : 'Enter product name...'}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						/>
					</div>
					{#if apBranchFilter || apSearchBarcode || apSearchProductName}
						<div class="flex items-end">
							<button
								class="px-4 py-2.5 text-xs font-bold uppercase rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200"
								on:click={clearAllProductsFilters}
							>
								{$locale === 'ar' ? 'مسح' : 'Clear'}
							</button>
						</div>
					{/if}
				</div>

				{#if allProductsLoading}
					<div class="flex items-center justify-center py-16">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if allProductsItems.length === 0 && !apSearchBarcode && !apSearchProductName && !apBranchFilter}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📦</div>
						<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'لا توجد منتجات بتواريخ انتهاء' : 'No products with expiry dates found'}</p>
					</div>
				{:else}
					<!-- Info bar: count + pagination -->
					<div class="mb-3 flex items-center justify-between flex-wrap gap-2">
						<div class="text-xs font-semibold text-slate-500">
							{#if apIsSearchMode}
								{$locale === 'ar'
									? `نتائج البحث: ${allProductsItems.length} منتج`
									: `Search results: ${allProductsItems.length} products`}
							{:else}
								{$locale === 'ar'
									? `عرض ${(apCurrentPage - 1) * apPageSize + 1}–${Math.min(apCurrentPage * apPageSize, apTotalCount)} من ${apTotalCount} منتج`
									: `Showing ${(apCurrentPage - 1) * apPageSize + 1}–${Math.min(apCurrentPage * apPageSize, apTotalCount)} of ${apTotalCount} products`}
							{/if}
						</div>
						{#if !apIsSearchMode && apTotalPages > 1}
							<div class="flex items-center gap-2">
								<button
									class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all border {apCurrentPage <= 1 ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed' : 'bg-blue-50 text-blue-600 border-blue-200 hover:bg-blue-100 hover:shadow-md'}"
									disabled={apCurrentPage <= 1}
									on:click={() => loadAllProducts(apCurrentPage - 1, false)}
								>
									◀ {$locale === 'ar' ? 'السابق' : 'Prev'}
								</button>
								<span class="text-xs font-bold text-slate-600 px-2">
									{$locale === 'ar'
										? `صفحة ${apCurrentPage} من ${apTotalPages}`
										: `Page ${apCurrentPage} of ${apTotalPages}`}
								</span>
								<button
									class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all border {apCurrentPage >= apTotalPages ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed' : 'bg-blue-50 text-blue-600 border-blue-200 hover:bg-blue-100 hover:shadow-md'}"
									disabled={apCurrentPage >= apTotalPages}
									on:click={() => loadAllProducts(apCurrentPage + 1, false)}
								>
									{$locale === 'ar' ? 'التالي' : 'Next'} ▶
								</button>
							</div>
						{/if}
					</div>

					<!-- All Products Table -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-x-auto flex-1">
							<table class="w-full border-collapse">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">#</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'الباركود' : 'Barcode'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'اسم المنتج' : 'Product Name'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'الفرع' : 'Branch'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expiry Date'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'الأيام المتبقية' : 'Days Left'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'حذف' : 'Delete'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'مطالب به' : 'Claimed'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
											{$locale === 'ar' ? 'الموظف' : 'Employee'}
										</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#if allProductsItems.length === 0}
										<tr>
											<td colspan="9" class="px-4 py-12 text-center text-slate-400 text-sm">
												<div class="text-4xl mb-3">🔍</div>
												{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}
											</td>
										</tr>
									{:else}
										{#each allProductsItems as item, index}
											<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
												<td class="px-4 py-3 text-sm font-semibold text-slate-800">{(apIsSearchMode ? 0 : (apCurrentPage - 1) * apPageSize) + index + 1}</td>
												<td class="px-4 py-3 text-sm text-slate-700 font-mono">{item.barcode}</td>
												<td class="px-4 py-3 text-sm text-slate-700 cursor-pointer hover:bg-blue-50 select-none transition-colors"
													title={$locale === 'ar' ? 'انقر مرتين للنسخ' : 'Double-click to copy'}
													on:dblclick={() => copyToClipboard(item.product_name, item.barcode)}
												>
													{item.product_name}
													{#if copiedBarcode === item.barcode}
														<span class="ml-2 text-xs text-emerald-600 font-bold">✅</span>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.branch_name}</td>
												<td class="px-4 py-3 text-sm text-center text-slate-700">{formatDate(item.expiry_date)}</td>
												<td class="px-4 py-3 text-sm text-center font-mono font-bold
													{item.days_left <= 0 ? 'text-red-700 bg-red-50' : item.days_left <= 7 ? 'text-red-600' : item.days_left <= 15 ? 'text-orange-600' : 'text-blue-600'}">
													{#if item.days_left <= 0}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-700">
															{$locale === 'ar' ? 'منتهي!' : 'EXPIRED!'}
														</span>
													{:else}
														{item.days_left} {$locale === 'ar' ? 'يوم' : item.days_left === 1 ? 'day' : 'days'}
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-center">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200 hover:shadow-md"
														on:click={() => deleteExpiryItem(item.barcode)}
													>
														🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'}
													</button>
												</td>
												<td class="px-4 py-3 text-sm text-center">
													{#if isClaimed(item.managed_by, item.branch_id)}
														<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-blue-100 text-blue-700">
															{item.status}
														</span>
													{:else}
														<button
															class="px-3 py-1.5 text-xs font-bold rounded-lg bg-purple-50 text-purple-600 hover:bg-purple-100 transition-all border border-purple-200 hover:shadow-md"
															on:click={() => openAssignPopup(item.barcode, item.branch_id)}
														>
															👤 {$locale === 'ar' ? 'تحديد' : 'Set'}
														</button>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.employee_name || '—'}</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						</div>
					</div>

					<!-- Bottom pagination (if many pages) -->
					{#if !apIsSearchMode && apTotalPages > 1}
						<div class="mt-3 flex items-center justify-center gap-2">
							<button
								class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all border {apCurrentPage <= 1 ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed' : 'bg-blue-50 text-blue-600 border-blue-200 hover:bg-blue-100 hover:shadow-md'}"
								disabled={apCurrentPage <= 1}
								on:click={() => loadAllProducts(apCurrentPage - 1, false)}
							>
								◀ {$locale === 'ar' ? 'السابق' : 'Prev'}
							</button>
							<span class="text-xs font-bold text-slate-600 px-2">
								{$locale === 'ar'
									? `صفحة ${apCurrentPage} من ${apTotalPages}`
									: `Page ${apCurrentPage} of ${apTotalPages}`}
							</span>
							<button
								class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all border {apCurrentPage >= apTotalPages ? 'bg-slate-100 text-slate-400 border-slate-200 cursor-not-allowed' : 'bg-blue-50 text-blue-600 border-blue-200 hover:bg-blue-100 hover:shadow-md'}"
								disabled={apCurrentPage >= apTotalPages}
								on:click={() => loadAllProducts(apCurrentPage + 1, false)}
							>
								{$locale === 'ar' ? 'التالي' : 'Next'} ▶
							</button>
						</div>
					{/if}
				{/if}

			{:else if activeTab === 'Deleted'}
				{#if deletedLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-red-200 border-t-red-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
						</div>
					</div>
				{:else if allDeletedProducts.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">{$locale === 'ar' ? 'لا توجد منتجات محذوفة' : 'No deleted products'}</p>
					</div>
				{:else}
					<!-- Deleted Filters -->
					<div class="mb-4 flex gap-3 flex-wrap">
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="del-barcode-search">
								{$locale === 'ar' ? 'بحث بالباركود' : 'Search Barcode'}
							</label>
							<input
								id="del-barcode-search"
								type="text"
								bind:value={deletedSearchBarcode}
								placeholder={$locale === 'ar' ? 'أدخل الباركود...' : 'Enter barcode...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent transition-all"
							/>
						</div>
						<div class="flex-1 min-w-[180px]">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="del-name-search">
								{$locale === 'ar' ? 'بحث بالاسم' : 'Search Name'}
							</label>
							<input
								id="del-name-search"
								type="text"
								bind:value={deletedSearchName}
								placeholder={$locale === 'ar' ? 'أدخل اسم المنتج...' : 'Enter product name...'}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent transition-all"
							/>
						</div>
						{#if deletedSearchBarcode || deletedSearchName}
							<div class="flex items-end">
								<button
									class="px-4 py-2.5 text-xs font-bold uppercase rounded-xl bg-red-50 text-red-600 hover:bg-red-100 transition-all border border-red-200"
									on:click={clearDeletedFilters}
								>
									{$locale === 'ar' ? 'مسح' : 'Clear'}
								</button>
							</div>
						{/if}
					</div>

					<div class="mb-3 text-xs font-semibold text-slate-500">
						{$locale === 'ar'
							? `عرض ${filteredDeleted.length} من ${allDeletedProducts.length} منتج`
							: `Showing ${filteredDeleted.length} of ${allDeletedProducts.length} products`}
					</div>

					<!-- Deleted Table -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-x-auto flex-1">
							<table class="w-full border-collapse">
								<thead class="sticky top-0 bg-red-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-red-400">#</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-red-400">
											{$locale === 'ar' ? 'الباركود' : 'Barcode'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-red-400">
											{$locale === 'ar' ? 'اسم المنتج' : 'Product Name'}
										</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-red-400">
											{$locale === 'ar' ? 'تراجع' : 'Undo'}
										</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-red-400">
											{$locale === 'ar' ? 'الموظف' : 'Employee'}
										</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#if filteredDeleted.length === 0}
										<tr>
											<td colspan="5" class="px-4 py-12 text-center text-slate-400 text-sm">
												<div class="text-4xl mb-3">🔍</div>
												{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}
											</td>
										</tr>
									{:else}
										{#each filteredDeleted as item, index}
											<tr class="hover:bg-red-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
												<td class="px-4 py-3 text-sm font-semibold text-slate-800">{index + 1}</td>
												<td class="px-4 py-3 text-sm text-slate-700 font-mono">{item.barcode}</td>
												<td class="px-4 py-3 text-sm text-slate-700 cursor-pointer hover:bg-red-50 select-none transition-colors"
													title={$locale === 'ar' ? 'انقر مرتين للنسخ' : 'Double-click to copy'}
													on:dblclick={() => copyToClipboard(item.product_name, item.barcode)}
												>
													{item.product_name}
													{#if copiedBarcode === item.barcode}
														<span class="ml-2 text-xs text-emerald-600 font-bold">✅</span>
													{/if}
												</td>
												<td class="px-4 py-3 text-sm text-center">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg bg-emerald-50 text-emerald-600 hover:bg-emerald-100 transition-all border border-emerald-200 hover:shadow-md"
														on:click={() => undoDeleteExpiryItem(item.barcode)}
													>
														↩️ {$locale === 'ar' ? 'تراجع' : 'Undo'}
													</button>
												</td>
												<td class="px-4 py-3 text-sm text-slate-700">{item.employee_name || '—'}</td>
											</tr>
										{/each}
									{/if}
								</tbody>
							</table>
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</div>
</div>

<!-- Assign Employee Popup -->
{#if showAssignPopup}
	<!-- svelte-ignore a11y-autofocus -->
	<!-- svelte-ignore a11y-interactive-supports-focus -->
	<div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center" role="dialog" aria-modal="true" tabindex="-1" on:click|self={() => showAssignPopup = false} on:keydown={(e) => { if (e.key === 'Escape') showAssignPopup = false; }}>
		<div class="bg-white rounded-3xl shadow-2xl w-[420px] max-h-[70vh] flex flex-col overflow-hidden border border-slate-200" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
			<!-- Header -->
			<div class="bg-purple-600 text-white px-6 py-4 flex items-center justify-between">
				<h3 class="text-sm font-black uppercase tracking-wide flex items-center gap-2">
					<span>👤</span>
					{$locale === 'ar' ? 'تعيين موظف' : 'Assign Employee'}
				</h3>
				<button
					class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-all text-lg"
					on:click={() => showAssignPopup = false}
				>✕</button>
			</div>

			<!-- Search -->
			<div class="px-5 py-3 border-b border-slate-200">
				<input
					type="text"
					bind:value={assignSearch}
					placeholder={$locale === 'ar' ? 'بحث بالاسم أو الرقم...' : 'Search by name or ID...'}
					class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
					autofocus
				/>
			</div>

			<!-- Employee List -->
			<div class="flex-1 overflow-y-auto">
				{#if assignLoading}
					<div class="flex items-center justify-center py-12">
						<div class="animate-spin w-8 h-8 border-3 border-purple-200 border-t-purple-600 rounded-full"></div>
					</div>
				{:else if filteredEmployees.length === 0}
					<div class="py-12 text-center text-slate-400 text-sm">
						<div class="text-3xl mb-2">🔍</div>
						{$locale === 'ar' ? 'لا توجد نتائج' : 'No results found'}
					</div>
				{:else}
					{#each filteredEmployees as emp}
						<button
							class="w-full px-5 py-3 flex items-center gap-3 hover:bg-purple-50 transition-colors border-b border-slate-100 text-left"
							on:click={() => assignEmployee(emp.id)}
						>
							<div class="w-9 h-9 rounded-full bg-purple-100 text-purple-600 flex items-center justify-center text-sm font-bold shrink-0">
								{(emp.name_en || emp.name_ar || '?').charAt(0).toUpperCase()}
							</div>
							<div class="flex-1 min-w-0">
								<div class="text-sm font-semibold text-slate-800 truncate">
									{$locale === 'ar' ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar)}
								</div>
								<div class="text-xs text-slate-400 font-mono">{emp.id}</div>
							</div>
						</button>
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}


{#if showTaskPopup}
<!-- svelte-ignore a11y-autofocus -->
<!-- svelte-ignore a11y-interactive-supports-focus -->
<div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" tabindex="-1" on:click|self={() => showTaskPopup = false} on:keydown={(e) => { if (e.key === 'Escape') showTaskPopup = false; }}>
	<div class="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden">

		<!-- Header -->
		<div class="bg-gradient-to-r from-indigo-600 to-indigo-700 px-6 py-4 flex items-center justify-between">
			<h3 class="text-lg font-black text-white">
				{$locale === 'ar' ? 'مهمة' : 'Task'}
			</h3>
			<button class="text-white/80 hover:text-white text-xl" on:click={() => showTaskPopup = false}>✕</button>
		</div>

		<!-- Product Info -->
		{#if taskItems.length > 1}
			<div class="px-6 py-3 bg-indigo-50 border-b border-indigo-200 flex items-center gap-3">
				<div class="w-10 h-10 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center text-lg font-bold">{taskItems.length}</div>
				<div class="text-sm font-bold text-indigo-700">
					{$locale === 'ar' ? `${taskItems.length} منتجات مختار` : `${taskItems.length} products selected`}
				</div>
			</div>
		{:else if taskItem}
			<div class="px-6 py-3 bg-slate-50 border-b border-slate-200">
				<div class="text-xs text-slate-400 font-mono">{taskItem.barcode}</div>
				<div class="text-sm font-bold text-slate-700 truncate">{$locale === 'ar' ? (taskItem.product_name_ar || taskItem.product_name_en) : (taskItem.product_name_en || taskItem.product_name_ar)}</div>
			</div>
		{/if}

		<!-- Step 1: Select Task Type -->
		{#if taskStep === 'type'}
			<div class="p-6">
				<p class="text-sm font-bold text-slate-600 mb-4">{$locale === 'ar' ? 'اختر نوع المهمة' : 'Select Task Type'}</p>
				<div class="space-y-3">
					{#each taskTypes as tt}
						<button
							class="w-full px-4 py-3 flex items-center gap-3 rounded-xl border-2 transition-all hover:shadow-md {taskType === tt.id ? 'border-indigo-500 bg-indigo-50' : 'border-slate-200 hover:border-indigo-300'}"
							on:click={() => selectTaskType(tt.id)}
						>
							<span class="text-2xl">{tt.icon}</span>
							<span class="text-sm font-bold text-slate-700">{$locale === 'ar' ? tt.ar : tt.en}</span>
						</button>
					{/each}
				</div>
			</div>

		<!-- Step 2: Select Employees -->
		{:else if taskStep === 'employees'}
			<div class="flex flex-col" style="max-height: 60vh;">
				<!-- Selected count + back -->
				<div class="px-6 py-3 border-b border-slate-200 flex items-center justify-between">
					<button
						class="text-xs font-bold text-slate-500 hover:text-indigo-600 transition-colors"
						on:click={() => { taskStep = 'type'; taskType = ''; taskSelectedUsers = []; }}
					>
						◀ {$locale === 'ar' ? 'رجوع' : 'Back'}
					</button>
					<span class="text-xs font-bold text-indigo-600">
						{taskSelectedUsers.length} {$locale === 'ar' ? 'محدد' : 'selected'}
					</span>
				</div>

				<!-- Search -->
				<div class="px-5 py-3 border-b border-slate-200">
					<input
						type="text"
						bind:value={taskEmployeeSearch}
						placeholder={$locale === 'ar' ? 'بحث...' : 'Search...'}
						class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-300 focus:border-indigo-400"
											/>
				</div>

				<!-- Employee List -->
				<div class="flex-1 overflow-y-auto">
					{#if taskLoading}
						<div class="flex items-center justify-center py-12">
							<div class="animate-spin w-8 h-8 border-3 border-indigo-200 border-t-indigo-600 rounded-full"></div>
						</div>
					{:else if filteredTaskEmployees.length === 0}
						<div class="py-12 text-center text-slate-400 text-sm">
							<div class="text-3xl mb-2">🔍</div>
							{$locale === 'ar' ? 'لا توجد نتائج' : 'No results found'}
						</div>
					{:else}
						{#each filteredTaskEmployees as emp}
							<button
								class="w-full px-5 py-3 flex items-center gap-3 hover:bg-indigo-50 transition-colors border-b border-slate-100 {isTaskEmployeeSelected(emp.user_id) ? 'bg-indigo-50' : ''}"
								on:click={() => toggleTaskEmployee(emp)}
							>
								<div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold {isTaskEmployeeSelected(emp.user_id) ? 'bg-indigo-500 text-white' : 'bg-indigo-100 text-indigo-600'}">
									{#if isTaskEmployeeSelected(emp.user_id)}
										✓
									{:else}
										{(emp.name_en || emp.name_ar || '?').charAt(0).toUpperCase()}
									{/if}
								</div>
								<div class="flex-1 min-w-0">
									<div class="text-sm font-semibold text-slate-800 truncate">
										{$locale === 'ar' ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar)}
									</div>
									<div class="text-xs text-slate-400 font-mono">{emp.id}</div>
								</div>
							</button>
						{/each}
					{/if}
				</div>

				<!-- Send Button -->
				{#if taskSelectedUsers.length > 0}
					<div class="px-6 py-4 border-t border-slate-200 bg-slate-50">
						<button
							class="w-full py-3 rounded-xl font-bold text-white text-sm transition-all {taskSending ? 'bg-slate-400 cursor-not-allowed' : 'bg-indigo-600 hover:bg-indigo-700 shadow-lg hover:shadow-xl'}"
							disabled={taskSending}
							on:click={sendQuickTask}
						>
							{#if taskSending}
								{$locale === 'ar' ? 'جاري الإرسال...' : 'Sending...'}
							{:else}
								📤 {$locale === 'ar' ? 'إرسال' : 'Send'} ({taskSelectedUsers.length})
							{/if}
						</button>
					</div>
				{/if}
			</div>

		<!-- Step 3: Done -->
		{:else if taskStep === 'done'}
			<div class="p-8 text-center">
				<div class="text-5xl mb-4">✅</div>
				<p class="text-lg font-bold text-slate-800 mb-2">{$locale === 'ar' ? 'تم إرسال المهمة' : 'Task Sent!'}</p>
				<p class="text-sm text-slate-500 mb-6">
					{$locale === 'ar' ? 'تم إرسال المهمة بنجاح' : 'Task has been sent successfully'}
				</p>
				<button
					class="px-8 py-2.5 bg-indigo-600 text-white rounded-xl font-bold text-sm hover:bg-indigo-700 transition-all"
					on:click={() => showTaskPopup = false}
				>
					{$locale === 'ar' ? 'إغلاق' : 'Close'}
				</button>
			</div>
		{/if}

	</div>
</div>
{/if}


<style>
	/* ExpiryControl styles */
</style>
