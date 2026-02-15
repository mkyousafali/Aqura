<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	interface EmployeeClaim {
		employee_id: string;
		name: string;
		product_count: number;
		branch_counts: Record<number, number>;
		products: { barcode: string; product_name: string; branch_id: number; claimed_at: string }[];
	}

	let claims: EmployeeClaim[] = [];
	let loading = true;
	let error = '';

	// Tabs
	let activeTab: 'claimed' | 'in_process' = 'claimed';

	// In-process products
	interface InProcessProduct {
		barcode: string;
		product_name: string;
		employee_id: string;
		employee_name: string;
		branch_id: number;
		claimed_at: string;
		moved_at: string;
	}
	let inProcessProducts: InProcessProduct[] = [];
	let inProcessLoading = false;
	let inProcessSearch = '';
	let inProcessFilterBranch = '';

	// In-process grouped by employee (like claims)
	interface InProcessEmployeeClaim {
		employee_id: string;
		name: string;
		product_count: number;
		branch_counts: Record<number, number>;
		products: InProcessProduct[];
	}
	let inProcessClaims: InProcessEmployeeClaim[] = [];
	let selectedInProcessEmployee: InProcessEmployeeClaim | null = null;
	let inProcessDetailSearch = '';
	let inProcessDetailFilterBranch = '';
	let inProcessSortBy: 'name' | 'count' = 'count';
	let inProcessSortDir: 'asc' | 'desc' = 'desc';

	// Filters
	let searchQuery = '';
	let filterBranch = '';
	let sortBy: 'name' | 'count' = 'count';
	let sortDir: 'asc' | 'desc' = 'desc';

	// Detail view
	let selectedEmployee: EmployeeClaim | null = null;

	// Branch cache
	let branchCache: Record<number, { name: string; location: string }> = {};

	onMount(() => {
		loadClaims();
		loadInProcess();
	});

	async function loadClaims() {
		loading = true;
		error = '';
		try {
			// Fetch all products that have managed_by entries
			const { data: products, error: err } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, managed_by')
				.not('managed_by', 'eq', '[]');

			if (err) throw err;

			// Parse managed_by and aggregate by employee
			const employeeMap = new Map<string, { 
				products: { barcode: string; product_name: string; branch_id: number; claimed_at: string }[];
				branch_counts: Record<number, number>;
			}>();
			const branchIds = new Set<number>();

			for (const p of products || []) {
				let managedBy: { branch_id: number; claimed_at: string; employee_id: string }[] = [];
				try {
					managedBy = typeof p.managed_by === 'string' ? JSON.parse(p.managed_by) : (p.managed_by || []);
				} catch { continue; }

				if (!Array.isArray(managedBy)) continue;

				const productName = $locale === 'ar' ? (p.product_name_ar || p.product_name_en || '') : (p.product_name_en || p.product_name_ar || '');

				for (const entry of managedBy) {
					if (!entry.employee_id) continue;
					if (entry.branch_id) branchIds.add(entry.branch_id);

					if (!employeeMap.has(entry.employee_id)) {
						employeeMap.set(entry.employee_id, { products: [], branch_counts: {} });
					}
					const emp = employeeMap.get(entry.employee_id)!;
					emp.products.push({
						barcode: p.barcode,
						product_name: productName,
						branch_id: entry.branch_id,
						claimed_at: entry.claimed_at || ''
					});
					emp.branch_counts[entry.branch_id] = (emp.branch_counts[entry.branch_id] || 0) + 1;
				}
			}

			// Fetch employee names from hr_employee_master
			const empIds = [...employeeMap.keys()];
			const nameMap: Record<string, string> = {};
			if (empIds.length > 0) {
				const { data: employees } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.in('id', empIds);
				for (const e of employees || []) {
					nameMap[e.id] = $locale === 'ar' ? (e.name_ar || e.name_en || e.id) : (e.name_en || e.name_ar || e.id);
				}
			}

			// Fetch branch names
			const uncachedBranches = [...branchIds].filter(id => !branchCache[id]);
			if (uncachedBranches.length > 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.in('id', uncachedBranches);
				for (const b of branches || []) {
					const name = $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
					const location = $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
					branchCache[b.id] = { name, location };
				}
			}

			// Build final array
			claims = [...employeeMap.entries()].map(([empId, data]) => ({
				employee_id: empId,
				name: nameMap[empId] || empId,
				product_count: data.products.length,
				branch_counts: data.branch_counts,
				products: data.products
			}));

		} catch (err: any) {
			console.error('Error loading product claims:', err);
			error = err?.message || 'Failed to load data';
		} finally {
			loading = false;
		}
	}

	async function loadInProcess() {
		inProcessLoading = true;
		try {
			const { data: products, error: err } = await supabase
				.from('erp_synced_products')
				.select('barcode, product_name_en, product_name_ar, in_process')
				.not('in_process', 'eq', '[]');
			if (err) throw err;

			const rows: InProcessProduct[] = [];
			const empIdsNeeded = new Set<string>();
			const branchIdsNeeded = new Set<number>();

			for (const p of products || []) {
				let entries: any[] = [];
				try { entries = typeof p.in_process === 'string' ? JSON.parse(p.in_process) : (p.in_process || []); } catch { continue; }
				if (!Array.isArray(entries)) continue;

				const productName = $locale === 'ar' ? (p.product_name_ar || p.product_name_en || '') : (p.product_name_en || p.product_name_ar || '');

				for (const entry of entries) {
					if (!entry.employee_id) continue;
					empIdsNeeded.add(entry.employee_id);
					if (entry.branch_id) branchIdsNeeded.add(entry.branch_id);
					rows.push({
						barcode: p.barcode,
						product_name: productName,
						employee_id: entry.employee_id,
						employee_name: '',
						branch_id: entry.branch_id,
						claimed_at: entry.claimed_at || '',
						moved_at: entry.moved_at || ''
					});
				}
			}

			// Fetch employee names
			const uncachedEmps = [...empIdsNeeded].filter(id => !userNameCache[id]);
			if (uncachedEmps.length > 0) {
				const { data: employees } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.in('id', uncachedEmps);
				for (const e of employees || []) {
					userNameCache[e.id] = $locale === 'ar' ? (e.name_ar || e.name_en || e.id) : (e.name_en || e.name_ar || e.id);
				}
			}

			// Fetch branches
			const uncachedBr = [...branchIdsNeeded].filter(id => !branchCache[id]);
			if (uncachedBr.length > 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.in('id', uncachedBr);
				for (const b of branches || []) {
					const name = $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar);
					const location = $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '');
					branchCache[b.id] = { name, location };
				}
			}

			// Enrich names
			for (const row of rows) {
				row.employee_name = userNameCache[row.employee_id] || row.employee_id;
			}

			inProcessProducts = rows;

			// Group by employee (like claims)
			const empMap = new Map<string, InProcessEmployeeClaim>();
			for (const row of rows) {
				if (!empMap.has(row.employee_id)) {
					empMap.set(row.employee_id, {
						employee_id: row.employee_id,
						name: row.employee_name,
						product_count: 0,
						branch_counts: {},
						products: []
					});
				}
				const emp = empMap.get(row.employee_id)!;
				emp.products.push(row);
				emp.product_count++;
				emp.branch_counts[row.branch_id] = (emp.branch_counts[row.branch_id] || 0) + 1;
			}
			inProcessClaims = [...empMap.values()];

			// Update selected employee if still viewing one
			if (selectedInProcessEmployee) {
				const updated = inProcessClaims.find(c => c.employee_id === selectedInProcessEmployee!.employee_id);
				selectedInProcessEmployee = updated || null;
			}
		} catch (err: any) {
			console.error('Error loading in-process products:', err);
		} finally {
			inProcessLoading = false;
		}
	}

	let userNameCache: Record<string, string> = {};

	function getBranchDisplay(branchId: number): string {
		const b = branchCache[branchId];
		if (!b) return `#${branchId}`;
		return b.location ? `${b.name} — ${b.location}` : b.name;
	}

	function formatDate(dateStr: string) {
		if (!dateStr) return '—';
		const d = new Date(dateStr);
		return d.toLocaleDateString($locale === 'ar' ? 'ar-u-ca-gregory' : 'en-US', {
			year: 'numeric', month: 'short', day: 'numeric',
			hour: '2-digit', minute: '2-digit'
		});
	}

	// All unique branch names for filter
	$: allBranches = (() => {
		const set = new Set<number>();
		for (const c of claims) {
			for (const bid of Object.keys(c.branch_counts)) set.add(Number(bid));
		}
		return [...set].map(id => ({ id, display: getBranchDisplay(id) }));
	})();

	$: filteredClaims = claims.filter(c => {
		if (filterBranch) {
			const bid = Number(filterBranch);
			if (!c.branch_counts[bid]) return false;
		}
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			if (
				!c.name.toLowerCase().includes(q) &&
				!c.employee_id.toLowerCase().includes(q)
			) return false;
		}
		return true;
	}).sort((a, b) => {
		if (sortBy === 'count') {
			return sortDir === 'desc' ? b.product_count - a.product_count : a.product_count - b.product_count;
		}
		const cmp = a.name.localeCompare(b.name);
		return sortDir === 'desc' ? -cmp : cmp;
	});

	function clearFilters() {
		searchQuery = '';
		filterBranch = '';
	}

	$: hasActiveFilters = searchQuery || filterBranch;

	// In-process filters
	$: inProcessBranches = (() => {
		const set = new Set<number>();
		for (const p of inProcessProducts) if (p.branch_id) set.add(p.branch_id);
		return [...set].map(id => ({ id, display: getBranchDisplay(id) }));
	})();

	$: filteredInProcess = inProcessProducts.filter(p => {
		if (inProcessFilterBranch && String(p.branch_id) !== inProcessFilterBranch) return false;
		if (inProcessSearch.trim()) {
			const q = inProcessSearch.trim().toLowerCase();
			if (
				!p.barcode.toLowerCase().includes(q) &&
				!p.product_name.toLowerCase().includes(q) &&
				!p.employee_name.toLowerCase().includes(q) &&
				!p.employee_id.toLowerCase().includes(q)
			) return false;
		}
		return true;
	});

	// In-process claims filtered + sorted (main table)
	$: filteredInProcessClaims = inProcessClaims.filter(c => {
		if (inProcessFilterBranch) {
			const bid = Number(inProcessFilterBranch);
			if (!c.branch_counts[bid]) return false;
		}
		if (inProcessSearch.trim()) {
			const q = inProcessSearch.trim().toLowerCase();
			if (!c.name.toLowerCase().includes(q) && !c.employee_id.toLowerCase().includes(q)) return false;
		}
		return true;
	}).sort((a, b) => {
		if (inProcessSortBy === 'count') {
			return inProcessSortDir === 'desc' ? b.product_count - a.product_count : a.product_count - b.product_count;
		}
		const cmp = a.name.localeCompare(b.name);
		return inProcessSortDir === 'desc' ? -cmp : cmp;
	});

	function toggleInProcessSort(col: 'name' | 'count') {
		if (inProcessSortBy === col) {
			inProcessSortDir = inProcessSortDir === 'asc' ? 'desc' : 'asc';
		} else {
			inProcessSortBy = col;
			inProcessSortDir = col === 'count' ? 'desc' : 'asc';
		}
	}

	// In-process detail products filtered
	$: inProcessDetailProducts = selectedInProcessEmployee ? selectedInProcessEmployee.products.filter(p => {
		if (inProcessDetailFilterBranch && String(p.branch_id) !== inProcessDetailFilterBranch) return false;
		if (inProcessDetailSearch.trim()) {
			const q = inProcessDetailSearch.trim().toLowerCase();
			if (!p.barcode.toLowerCase().includes(q) && !p.product_name.toLowerCase().includes(q)) return false;
		}
		return true;
	}) : [];

	function toggleSort(col: 'name' | 'count') {
		if (sortBy === col) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = col;
			sortDir = col === 'count' ? 'desc' : 'asc';
		}
	}

	// Detail view: filter products by branch
	let detailFilterBranch = '';
	let detailSearch = '';

	let processingTransfer = false;

	// Assign modal state
	let showAssignModal = false;
	let assignItem: any = null; // the item being assigned (from main or detail table)
	let assignIsMainTable = false;
	let assignEmployeeSearch = '';
	let assignSelectedEmployee: { id: string; name: string } | null = null;
	let assignEmployeeList: { id: string; name: string }[] = [];
	let assignEmployeeLoading = false;
	let assignProcessing = false;

	async function loadAssignEmployees() {
		assignEmployeeLoading = true;
		try {
			const { data: employees, error: err } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar')
				.order('id');
			if (err) throw err;
			assignEmployeeList = (employees || []).map(e => ({
				id: e.id,
				name: $locale === 'ar' ? (e.name_ar || e.name_en || e.id) : (e.name_en || e.name_ar || e.id)
			}));
		} catch (err: any) {
			console.error('Error loading employees:', err);
		} finally {
			assignEmployeeLoading = false;
		}
	}

	$: filteredAssignEmployees = assignEmployeeList.filter(e => {
		if (!assignEmployeeSearch.trim()) return true;
		const q = assignEmployeeSearch.trim().toLowerCase();
		return e.id.toLowerCase().includes(q) || e.name.toLowerCase().includes(q);
	});

	async function processTransfer(item: any) {
		// Determine if called from main table (EmployeeClaim with employee_id + products[])
		// or from detail table (single product with barcode + branch_id)
		const isMainTable = Array.isArray(item.products);
		const employeeId = isMainTable ? item.employee_id : selectedEmployee?.employee_id;
		if (!employeeId) return;

		const barcodes: string[] = isMainTable
			? item.products.map((p: any) => p.barcode)
			: [item.barcode];

		const confirmMsg = $locale === 'ar'
			? `هل تريد نقل ${barcodes.length} منتج من المطالبات إلى قيد المعالجة؟`
			: `Move ${barcodes.length} product(s) from managed to in-process?`;
		if (!confirm(confirmMsg)) return;

		processingTransfer = true;
		try {
			// Fetch current data for all affected products
			const { data: products, error: fetchErr } = await supabase
				.from('erp_synced_products')
				.select('barcode, managed_by, in_process')
				.in('barcode', barcodes);
			if (fetchErr) throw fetchErr;

			for (const prod of products || []) {
				let managedBy: any[] = [];
				let inProcess: any[] = [];
				try { managedBy = typeof prod.managed_by === 'string' ? JSON.parse(prod.managed_by) : (prod.managed_by || []); } catch { managedBy = []; }
				try { inProcess = typeof prod.in_process === 'string' ? JSON.parse(prod.in_process) : (prod.in_process || []); } catch { inProcess = []; }

				// Find the employee's entry in managed_by
				const entryIndex = managedBy.findIndex((e: any) => e.employee_id === employeeId);
				if (entryIndex === -1) continue;

				// Move entry: copy to in_process, remove from managed_by
				const entry = { ...managedBy[entryIndex], moved_at: new Date().toISOString() };
				inProcess.push(entry);
				managedBy.splice(entryIndex, 1);

				const { error: updateErr } = await supabase
					.from('erp_synced_products')
					.update({ managed_by: managedBy, in_process: inProcess })
					.eq('barcode', prod.barcode);
				if (updateErr) throw updateErr;
			}

			// Refresh data
			await loadClaims();
			await loadInProcess();
			// If in detail view and all products moved, go back to list
			if (selectedEmployee && isMainTable) {
				selectedEmployee = null;
			} else if (selectedEmployee && !isMainTable) {
				// Update selected employee from refreshed claims
				const updated = claims.find(c => c.employee_id === employeeId);
				selectedEmployee = updated || null;
			}
		} catch (err: any) {
			console.error('Transfer error:', err);
			alert(($locale === 'ar' ? 'فشل النقل: ' : 'Transfer failed: ') + (err?.message || ''));
		} finally {
			processingTransfer = false;
		}
	}

	function processManages(item: any) {
		managesItem = item;
		managesIsMainTable = Array.isArray(item.products);
		showManagesModal = true;
	}

	// Manages modal state
	let showManagesModal = false;
	let managesItem: any = null;
	let managesIsMainTable = false;

	// Manage Branch modal state
	let showManageBranchModal = false;
	let manageBranchSaving = false;
	let manageBranchAllBranches: { id: number; name: string; location: string }[] = [];
	let manageBranchAllLoading = false;
	let manageBranchEmployeeBranches: { id: number; count: number; toId: number | null }[] = [];

	function manageBranch() {
		// Close manages modal, open manage branch modal
		showManagesModal = false;

		if (managesIsMainTable && managesItem) {
			// Main table: employee has multiple branches — each gets its own "to" dropdown
			const branchCounts: Record<number, number> = managesItem.branch_counts || {};
			manageBranchEmployeeBranches = Object.entries(branchCounts).map(([id, count]) => ({
				id: Number(id),
				count: count as number,
				toId: null
			}));
		} else if (managesItem) {
			// Detail table: single product, one branch
			manageBranchEmployeeBranches = [{ id: managesItem.branch_id, count: 1, toId: null }];
		}

		showManageBranchModal = true;
		if (manageBranchAllBranches.length === 0) {
			loadAllBranches();
		}
	}

	async function loadAllBranches() {
		manageBranchAllLoading = true;
		try {
			const { data, error: err } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.order('id');
			if (err) throw err;
			manageBranchAllBranches = (data || []).map(b => ({
				id: b.id,
				name: $locale === 'ar' ? (b.name_ar || b.name_en) : (b.name_en || b.name_ar),
				location: $locale === 'ar' ? (b.location_ar || b.location_en || '') : (b.location_en || b.location_ar || '')
			}));
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			manageBranchAllLoading = false;
		}
	}

	async function saveManageBranch() {
		if (!managesItem) return;

		// Only process branches that have a "to" selected and it's different from "from"
		const changes = manageBranchEmployeeBranches.filter(b => b.toId !== null && b.toId !== b.id);
		if (changes.length === 0) return;

		const employeeId = managesIsMainTable ? managesItem.employee_id : (selectedEmployee?.employee_id || '');
		if (!employeeId) return;

		// Collect all barcodes that need updating (products matching any changed branch)
		const changedFromIds = new Set(changes.map(c => c.id));
		let barcodes: string[] = [];
		if (managesIsMainTable) {
			barcodes = managesItem.products
				.filter((p: any) => changedFromIds.has(p.branch_id))
				.map((p: any) => p.barcode);
		} else {
			barcodes = [managesItem.barcode];
		}

		if (barcodes.length === 0) return;

		// Build a fromId → toId lookup
		const branchChangeMap = new Map<number, number>();
		for (const c of changes) {
			branchChangeMap.set(c.id, c.toId!);
		}

		manageBranchSaving = true;
		try {
			const { data: products, error: fetchErr } = await supabase
				.from('erp_synced_products')
				.select('barcode, managed_by')
				.in('barcode', barcodes);
			if (fetchErr) throw fetchErr;

			for (const prod of products || []) {
				let managedBy: any[] = [];
				try { managedBy = typeof prod.managed_by === 'string' ? JSON.parse(prod.managed_by) : (prod.managed_by || []); } catch { managedBy = []; }

				let changed = false;
				for (let i = 0; i < managedBy.length; i++) {
					if (managedBy[i].employee_id === employeeId && branchChangeMap.has(managedBy[i].branch_id)) {
						managedBy[i].branch_id = branchChangeMap.get(managedBy[i].branch_id);
						changed = true;
					}
				}
				if (!changed) continue;

				const { error: updateErr } = await supabase
					.from('erp_synced_products')
					.update({ managed_by: managedBy })
					.eq('barcode', prod.barcode);
				if (updateErr) throw updateErr;
			}

			// Refresh
			await loadClaims();
			await loadInProcess();
			if (selectedEmployee) {
				const updated = claims.find(c => c.employee_id === employeeId);
				selectedEmployee = updated || null;
			}

			showManageBranchModal = false;
			managesItem = null;
		} catch (err: any) {
			console.error('Manage branch error:', err);
			alert(($locale === 'ar' ? 'فشل تغيير الفرع: ' : 'Branch change failed: ') + (err?.message || ''));
		} finally {
			manageBranchSaving = false;
		}
	}

	// Unclaim modal state
	let showUnclaimModal = false;
	let unclaimBranches: { id: number; count: number }[] = [];
	let unclaimSelectedBranch: number | null = null;
	let unclaimProcessing = false;

	function markAsUnclaim() {
		showManagesModal = false;

		if (managesIsMainTable && managesItem) {
			// Main table: check how many branches
			const branchCounts: Record<number, number> = managesItem.branch_counts || {};
			const branches = Object.entries(branchCounts).map(([id, count]) => ({
				id: Number(id),
				count: count as number
			}));

			if (branches.length > 1) {
				// Multiple branches → show picker
				unclaimBranches = branches;
				unclaimSelectedBranch = null;
				showUnclaimModal = true;
				return;
			}
			// Single branch → unclaim directly
			executeUnclaim(managesItem.employee_id, branches.length === 1 ? branches[0].id : null);
		} else if (managesItem) {
			// Detail table: single product → unclaim directly
			executeUnclaim(selectedEmployee?.employee_id || '', managesItem.branch_id);
		}
	}

	async function confirmUnclaim() {
		if (unclaimSelectedBranch === null || !managesItem) return;
		const employeeId = managesIsMainTable ? managesItem.employee_id : (selectedEmployee?.employee_id || '');
		await executeUnclaim(employeeId, unclaimSelectedBranch);
		showUnclaimModal = false;
	}

	async function executeUnclaim(employeeId: string, branchId: number | null) {
		if (!employeeId || !managesItem) return;

		// Get barcodes to update
		let barcodes: string[] = [];
		if (managesIsMainTable) {
			barcodes = branchId !== null
				? managesItem.products.filter((p: any) => p.branch_id === branchId).map((p: any) => p.barcode)
				: managesItem.products.map((p: any) => p.barcode);
		} else {
			barcodes = [managesItem.barcode];
		}

		if (barcodes.length === 0) return;

		unclaimProcessing = true;
		try {
			const { data: products, error: fetchErr } = await supabase
				.from('erp_synced_products')
				.select('barcode, managed_by')
				.in('barcode', barcodes);
			if (fetchErr) throw fetchErr;

			for (const prod of products || []) {
				let managedBy: any[] = [];
				try { managedBy = typeof prod.managed_by === 'string' ? JSON.parse(prod.managed_by) : (prod.managed_by || []); } catch { managedBy = []; }

				// Remove the employee's entry for this branch
				managedBy = managedBy.filter((e: any) => {
					if (e.employee_id !== employeeId) return true;
					if (branchId !== null && e.branch_id !== branchId) return true;
					return false;
				});

				const { error: updateErr } = await supabase
					.from('erp_synced_products')
					.update({ managed_by: managedBy })
					.eq('barcode', prod.barcode);
				if (updateErr) throw updateErr;
			}

			// Refresh
			await loadClaims();
			await loadInProcess();
			if (selectedEmployee) {
				const updated = claims.find(c => c.employee_id === employeeId);
				selectedEmployee = updated || null;
			}

			managesItem = null;
		} catch (err: any) {
			console.error('Unclaim error:', err);
			alert(($locale === 'ar' ? 'فشل إلغاء المطالبة: ' : 'Unclaim failed: ') + (err?.message || ''));
		} finally {
			unclaimProcessing = false;
		}
	}

	function processAssign(item: any) {
		// Open assign modal
		assignItem = item;
		assignIsMainTable = Array.isArray(item.products);
		assignSelectedEmployee = null;
		assignEmployeeSearch = '';
		showAssignModal = true;
		if (assignEmployeeList.length === 0) {
			loadAssignEmployees();
		}
	}

	async function confirmAssign() {
		if (!assignSelectedEmployee || !assignItem) return;

		const newEmployeeId = assignSelectedEmployee.id;
		const oldEmployeeId = assignIsMainTable ? assignItem.employee_id : (selectedInProcessEmployee?.employee_id || assignItem.employee_id);
		if (!oldEmployeeId) return;

		const barcodes: string[] = assignIsMainTable
			? assignItem.products.map((p: any) => p.barcode)
			: [assignItem.barcode];

		assignProcessing = true;
		try {
			// Fetch current data for all affected products
			const { data: products, error: fetchErr } = await supabase
				.from('erp_synced_products')
				.select('barcode, managed_by, in_process')
				.in('barcode', barcodes);
			if (fetchErr) throw fetchErr;

			for (const prod of products || []) {
				let managedBy: any[] = [];
				let inProcess: any[] = [];
				try { managedBy = typeof prod.managed_by === 'string' ? JSON.parse(prod.managed_by) : (prod.managed_by || []); } catch { managedBy = []; }
				try { inProcess = typeof prod.in_process === 'string' ? JSON.parse(prod.in_process) : (prod.in_process || []); } catch { inProcess = []; }

				// Find the old employee's entry in in_process
				const entryIndex = inProcess.findIndex((e: any) => e.employee_id === oldEmployeeId);
				if (entryIndex === -1) continue;

				// Create new entry with new employee_id, add to managed_by
				const newEntry = {
					...inProcess[entryIndex],
					employee_id: newEmployeeId,
					claimed_at: new Date().toISOString()
				};
				delete newEntry.moved_at;
				managedBy.push(newEntry);

				// Remove from in_process
				inProcess.splice(entryIndex, 1);

				const { error: updateErr } = await supabase
					.from('erp_synced_products')
					.update({ managed_by: managedBy, in_process: inProcess })
					.eq('barcode', prod.barcode);
				if (updateErr) throw updateErr;
			}

			// Close modal and refresh
			showAssignModal = false;
			assignItem = null;
			await loadClaims();
			await loadInProcess();

			// Update detail view if applicable
			if (selectedInProcessEmployee && assignIsMainTable) {
				selectedInProcessEmployee = null;
			} else if (selectedInProcessEmployee && !assignIsMainTable) {
				const updated = inProcessClaims.find(c => c.employee_id === oldEmployeeId);
				selectedInProcessEmployee = updated || null;
			}
		} catch (err: any) {
			console.error('Assign error:', err);
			alert(($locale === 'ar' ? 'فشل التعيين: ' : 'Assign failed: ') + (err?.message || ''));
		} finally {
			assignProcessing = false;
		}
	}

	$: detailProducts = selectedEmployee ? selectedEmployee.products.filter(p => {
		if (detailFilterBranch && String(p.branch_id) !== detailFilterBranch) return false;
		if (detailSearch.trim()) {
			const q = detailSearch.trim().toLowerCase();
			if (!p.barcode.toLowerCase().includes(q) && !p.product_name.toLowerCase().includes(q)) return false;
		}
		return true;
	}) : [];
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">👤</span>
			<h2 class="text-lg font-bold text-slate-800">{$t('nav.productClaimManager') || 'Product Claim Manager'}</h2>
			<span class="text-xs font-semibold bg-violet-100 text-violet-600 px-3 py-1 rounded-full">{claims.length} {$locale === 'ar' ? 'موظف' : 'employees'}</span>
		</div>
		<div class="flex items-center gap-2">
			{#if !selectedEmployee && !selectedInProcessEmployee}
				<!-- Tabs -->
				<div class="flex bg-slate-100 rounded-xl p-0.5 gap-0.5">
					<button
						class="px-4 py-2 rounded-xl text-xs font-bold transition-all {activeTab === 'claimed' ? 'bg-white text-violet-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}"
						on:click={() => activeTab = 'claimed'}
					>
						📦 {$locale === 'ar' ? 'المطالبات' : 'Claimed'}
						<span class="ml-1 text-[10px] bg-violet-100 text-violet-600 px-1.5 py-0.5 rounded-full">{claims.length}</span>
					</button>
					<button
						class="px-4 py-2 rounded-xl text-xs font-bold transition-all {activeTab === 'in_process' ? 'bg-white text-amber-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}"
						on:click={() => activeTab = 'in_process'}
					>
						⏳ {$locale === 'ar' ? 'قيد المعالجة' : 'In Process'}
						<span class="ml-1 text-[10px] bg-amber-100 text-amber-600 px-1.5 py-0.5 rounded-full">{inProcessClaims.length}</span>
					</button>
				</div>
				{#if activeTab === 'claimed'}
				<!-- Search -->
				<div class="relative min-w-[160px] max-w-[240px]">
					<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
					<input type="text" bind:value={searchQuery} placeholder={$locale === 'ar' ? 'بحث...' : 'Search...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-violet-400 focus:border-transparent transition-all" />
				</div>
				<!-- Branch filter -->
				<select bind:value={filterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-400 min-w-[110px]">
					<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
					{#each allBranches as b}
						<option value={String(b.id)}>{b.display}</option>
					{/each}
				</select>
				{#if hasActiveFilters}
					<button on:click={clearFilters} class="px-3 py-2 bg-violet-50 hover:bg-violet-100 text-violet-600 rounded-xl text-xs font-bold transition-all">✕ {$locale === 'ar' ? 'مسح' : 'Clear'}</button>
				{/if}
				<span class="text-[10px] text-slate-400 font-semibold">{filteredClaims.length} / {claims.length}</span>
				{:else}
				<!-- In Process filters -->
				<div class="relative min-w-[160px] max-w-[240px]">
					<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
					<input type="text" bind:value={inProcessSearch} placeholder={$locale === 'ar' ? 'بحث...' : 'Search...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all" />
				</div>
				<select bind:value={inProcessFilterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-amber-400 min-w-[110px]">
					<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
					{#each inProcessBranches as b}
						<option value={String(b.id)}>{b.display}</option>
					{/each}
				</select>
				{#if inProcessSearch || inProcessFilterBranch}
					<button on:click={() => { inProcessSearch = ''; inProcessFilterBranch = ''; }} class="px-3 py-2 bg-amber-50 hover:bg-amber-100 text-amber-600 rounded-xl text-xs font-bold transition-all">✕ {$locale === 'ar' ? 'مسح' : 'Clear'}</button>
				{/if}
				<span class="text-[10px] text-slate-400 font-semibold">{filteredInProcessClaims.length} / {inProcessClaims.length}</span>
				{/if}
			{/if}
			<button
				class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
				on:click={loadClaims}
			>
				<span>🔄</span>
				{$t('finance.assets.refresh')}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-hidden p-6">
		{#if selectedEmployee}
			<!-- Detail View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				<div class="flex items-center justify-between mb-6">
					<div class="flex items-center gap-3">
						<button
							class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600"
							on:click={() => { selectedEmployee = null; detailFilterBranch = ''; detailSearch = ''; }}
						>←</button>
						<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
							<span>👤</span> {selectedEmployee.name}
						</h3>
						<span class="text-xs px-3 py-1 rounded-full border font-bold bg-violet-100 text-violet-700 border-violet-200">{selectedEmployee.employee_id}</span>
						<span class="text-xs px-3 py-1 rounded-full border font-bold bg-emerald-100 text-emerald-700 border-emerald-200">{selectedEmployee.product_count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
					</div>
					<div class="flex items-center gap-2">
						<!-- Detail search -->
						<div class="relative min-w-[160px] max-w-[220px]">
							<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
							<input type="text" bind:value={detailSearch} placeholder={$locale === 'ar' ? 'بحث بالباركود...' : 'Search barcode...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-violet-400 focus:border-transparent transition-all" />
						</div>
						<!-- Detail branch filter -->
						<select bind:value={detailFilterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-400 min-w-[110px]">
							<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
							{#each Object.keys(selectedEmployee.branch_counts) as bid}
								<option value={bid}>{getBranchDisplay(Number(bid))}</option>
							{/each}
						</select>
						<span class="text-[10px] text-slate-400 font-semibold">{detailProducts.length} / {selectedEmployee.product_count}</span>
					</div>
				</div>

				<!-- Branch Summary Cards -->
				<div class="flex flex-wrap gap-3 mb-5">
					{#each Object.entries(selectedEmployee.branch_counts) as [bid, count]}
						<div class="bg-slate-50 rounded-xl px-4 py-2.5 flex items-center gap-2 border border-slate-100">
							<span class="text-sm">🏪</span>
							<div>
								<span class="text-[10px] text-slate-400 font-bold uppercase block">{getBranchDisplay(Number(bid))}</span>
								<span class="text-sm font-bold text-slate-800">{count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
							</div>
						</div>
					{/each}
				</div>

				<!-- Products Table -->
				<div class="flex-1 overflow-auto">
					<table class="w-full text-xs border-collapse border border-slate-300">
						<thead class="sticky top-0 z-10">
							<tr class="bg-violet-600 text-white">
								<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">#</th>
								<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode') || 'Barcode'}</th>
								<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName') || 'Product Name'}</th>
								<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.branch') || 'Branch'}</th>
							<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'تاريخ المطالبة' : 'Claimed At'}</th>
						<th class="border-r border-violet-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'إدارة' : 'Manages'}</th>
						<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'نقل' : 'Transfer'}</th>
							</tr>
						</thead>
						<tbody>
							{#each detailProducts as prod, i}
								<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
									<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{prod.barcode}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{prod.product_name || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 text-slate-600">{getBranchDisplay(prod.branch_id)}</td>
							<td class="border-r border-slate-300 py-2 px-3 text-slate-500 text-[10px]">{formatDate(prod.claimed_at)}</td>
							<td class="border-r border-slate-300 py-2 px-3 text-center">
								<button
									class="px-3 py-1.5 bg-teal-50 hover:bg-teal-100 rounded-lg transition-all text-teal-700 hover:text-teal-900 text-[10px] font-bold whitespace-nowrap border border-teal-200"
									on:click|stopPropagation={() => processManages(prod)}
								>
									{$locale === 'ar' ? 'معالجة' : 'Process'}
								</button>
							</td>
							<td class="py-2 px-3 text-center">
								<button
									class="px-3 py-1.5 bg-violet-50 hover:bg-violet-100 rounded-lg transition-all text-violet-700 hover:text-violet-900 text-[10px] font-bold whitespace-nowrap border border-violet-200 disabled:opacity-50 disabled:cursor-not-allowed"
									on:click|stopPropagation={() => processTransfer(prod)}
									disabled={processingTransfer}
								>
									{processingTransfer ? '...' : ($locale === 'ar' ? 'معالجة' : 'Process')}
								</button>
							</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{:else if activeTab === 'claimed'}
			<!-- List View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				{#if loading}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4 animate-bounce">👤</div>
						<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading') || 'Loading...'}</p>
					</div>
				{:else if error}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">❌</div>
						<p class="text-red-500 font-semibold">{error}</p>
					</div>
				{:else if claims.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد مطالبات منتجات' : 'No product claims found'}</p>
					</div>
				{:else if filteredClaims.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">🔍</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}</p>
						<button on:click={clearFilters} class="mt-3 px-4 py-2 bg-violet-50 hover:bg-violet-100 text-violet-600 rounded-xl text-xs font-bold transition-all">{$locale === 'ar' ? 'مسح الفلاتر' : 'Clear Filters'}</button>
					</div>
				{:else}
					<!-- Summary Cards -->
					<div class="flex flex-wrap gap-3 mb-5">
						<div class="bg-gradient-to-br from-violet-50 to-violet-100 rounded-xl px-5 py-3 border border-violet-200 min-w-[140px]">
							<span class="text-[10px] text-violet-500 font-bold uppercase block">{$locale === 'ar' ? 'إجمالي الموظفين' : 'Total Employees'}</span>
							<span class="text-2xl font-black text-violet-700">{filteredClaims.length}</span>
						</div>
						<div class="bg-gradient-to-br from-emerald-50 to-emerald-100 rounded-xl px-5 py-3 border border-emerald-200 min-w-[140px]">
							<span class="text-[10px] text-emerald-500 font-bold uppercase block">{$locale === 'ar' ? 'إجمالي المنتجات المُدارة' : 'Total Products Managed'}</span>
							<span class="text-2xl font-black text-emerald-700">{filteredClaims.reduce((sum, c) => sum + c.product_count, 0)}</span>
						</div>
					</div>

					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-violet-600 text-white">
									<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">#</th>
									<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'رقم الموظف' : 'Employee ID'}</th>
									<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold cursor-pointer select-none hover:bg-violet-700 transition-colors" on:click={() => toggleSort('name')}>
										{$locale === 'ar' ? 'اسم الموظف' : 'Employee Name'}
										{#if sortBy === 'name'}<span class="ml-1">{sortDir === 'asc' ? '▲' : '▼'}</span>{/if}
									</th>
									<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold cursor-pointer select-none hover:bg-violet-700 transition-colors" on:click={() => toggleSort('count')}>
										{$locale === 'ar' ? 'عدد المنتجات' : 'Product Count'}
										{#if sortBy === 'count'}<span class="ml-1">{sortDir === 'asc' ? '▲' : '▼'}</span>{/if}
									</th>
							<th class="border-r border-violet-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'الفروع' : 'Branches'}</th>
							<th class="border-r border-violet-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'إدارة' : 'Manages'}</th>
							<th class="border-r border-violet-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'نقل' : 'Transfer'}</th>
							<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'تفاصيل' : 'Details'}</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredClaims as claim, i}
									<tr class="border-b border-slate-300 hover:bg-violet-50/50 cursor-pointer {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}" on:click={() => selectedEmployee = claim}>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-mono text-violet-700 font-bold">{claim.employee_id}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-800">{claim.name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<span class="inline-flex items-center gap-1 bg-emerald-50 text-emerald-700 px-2.5 py-1 rounded-lg font-bold text-[11px] border border-emerald-200">
												📦 {claim.product_count}
											</span>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<div class="flex flex-wrap gap-1">
												{#each Object.entries(claim.branch_counts) as [bid, count]}
													<span class="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-semibold border border-slate-200">
														{getBranchDisplay(Number(bid))} ({count})
													</span>
												{/each}
											</div>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											<button
												class="px-3 py-1.5 bg-teal-50 hover:bg-teal-100 rounded-lg transition-all text-teal-700 hover:text-teal-900 text-[10px] font-bold whitespace-nowrap border border-teal-200"
												on:click|stopPropagation={() => processManages(claim)}
											>
												{$locale === 'ar' ? 'معالجة' : 'Process'}
											</button>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											<button
												class="px-3 py-1.5 bg-violet-50 hover:bg-violet-100 rounded-lg transition-all text-violet-700 hover:text-violet-900 text-[10px] font-bold whitespace-nowrap border border-violet-200 disabled:opacity-50 disabled:cursor-not-allowed"
												on:click|stopPropagation={() => processTransfer(claim)}
												disabled={processingTransfer}
											>
												{processingTransfer ? '...' : ($locale === 'ar' ? 'معالجة' : 'Process')}
											</button>
										</td>
										<td class="py-2.5 px-3 text-center">
											<button
												class="px-3 py-1.5 bg-violet-50 hover:bg-violet-100 rounded-lg transition-all text-violet-700 hover:text-violet-900 text-[10px] font-bold whitespace-nowrap"
												on:click|stopPropagation={() => selectedEmployee = claim}
											>
												{$locale === 'ar' ? 'عرض المنتجات' : 'View Products'}
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{:else if activeTab === 'in_process'}
			{#if selectedInProcessEmployee}
				<!-- In Process Detail View -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
					<div class="flex items-center justify-between mb-6">
						<div class="flex items-center gap-3">
							<button
								class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600"
								on:click={() => { selectedInProcessEmployee = null; inProcessDetailFilterBranch = ''; inProcessDetailSearch = ''; }}
							>←</button>
							<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
								<span>⏳</span> {selectedInProcessEmployee.name}
							</h3>
							<span class="text-xs px-3 py-1 rounded-full border font-bold bg-amber-100 text-amber-700 border-amber-200">{selectedInProcessEmployee.employee_id}</span>
							<span class="text-xs px-3 py-1 rounded-full border font-bold bg-emerald-100 text-emerald-700 border-emerald-200">{selectedInProcessEmployee.product_count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
						</div>
						<div class="flex items-center gap-2">
							<div class="relative min-w-[160px] max-w-[220px]">
								<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
								<input type="text" bind:value={inProcessDetailSearch} placeholder={$locale === 'ar' ? 'بحث بالباركود...' : 'Search barcode...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all" />
							</div>
							<select bind:value={inProcessDetailFilterBranch} class="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 focus:outline-none focus:ring-2 focus:ring-amber-400 min-w-[110px]">
								<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
								{#each Object.keys(selectedInProcessEmployee.branch_counts) as bid}
									<option value={bid}>{getBranchDisplay(Number(bid))}</option>
								{/each}
							</select>
							<span class="text-[10px] text-slate-400 font-semibold">{inProcessDetailProducts.length} / {selectedInProcessEmployee.product_count}</span>
						</div>
					</div>

					<!-- Branch Summary Cards -->
					<div class="flex flex-wrap gap-3 mb-5">
						{#each Object.entries(selectedInProcessEmployee.branch_counts) as [bid, count]}
							<div class="bg-amber-50 rounded-xl px-4 py-2.5 flex items-center gap-2 border border-amber-100">
								<span class="text-sm">🏪</span>
								<div>
									<span class="text-[10px] text-slate-400 font-bold uppercase block">{getBranchDisplay(Number(bid))}</span>
									<span class="text-sm font-bold text-slate-800">{count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
								</div>
							</div>
						{/each}
					</div>

					<!-- In Process Products Table -->
					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-amber-600 text-white">
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">#</th>
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode') || 'Barcode'}</th>
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName') || 'Product Name'}</th>
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.branch') || 'Branch'}</th>
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'تاريخ المطالبة' : 'Claimed At'}</th>
									<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'تاريخ النقل' : 'Moved At'}</th>
									<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'تعيين' : 'Assign'}</th>
								</tr>
							</thead>
							<tbody>
								{#each inProcessDetailProducts as prod, i}
									<tr class="border-b border-slate-300 hover:bg-amber-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
										<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{prod.barcode}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{prod.product_name || '—'}</td>
										<td class="border-r border-slate-300 py-2 px-3 text-slate-600">{getBranchDisplay(prod.branch_id)}</td>
										<td class="border-r border-slate-300 py-2 px-3 text-slate-500 text-[10px]">{formatDate(prod.claimed_at)}</td>
										<td class="border-r border-slate-300 py-2 px-3 text-slate-500 text-[10px]">{formatDate(prod.moved_at)}</td>
										<td class="py-2 px-3 text-center">
											<button
												class="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 rounded-lg transition-all text-amber-700 hover:text-amber-900 text-[10px] font-bold whitespace-nowrap border border-amber-200"
												on:click|stopPropagation={() => processAssign(prod)}
											>
												{$locale === 'ar' ? 'معالجة' : 'Process'}
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{:else}
				<!-- In Process Main Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
					{#if inProcessLoading}
						<div class="flex-1 flex flex-col items-center justify-center">
							<div class="text-5xl mb-4 animate-bounce">⏳</div>
							<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading') || 'Loading...'}</p>
						</div>
					{:else if inProcessClaims.length === 0}
						<div class="flex-1 flex flex-col items-center justify-center">
							<div class="text-5xl mb-4">📭</div>
							<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد منتجات قيد المعالجة' : 'No in-process products'}</p>
						</div>
					{:else if filteredInProcessClaims.length === 0}
						<div class="flex-1 flex flex-col items-center justify-center">
							<div class="text-5xl mb-4">🔍</div>
							<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}</p>
							<button on:click={() => { inProcessSearch = ''; inProcessFilterBranch = ''; }} class="mt-3 px-4 py-2 bg-amber-50 hover:bg-amber-100 text-amber-600 rounded-xl text-xs font-bold transition-all">{$locale === 'ar' ? 'مسح الفلاتر' : 'Clear Filters'}</button>
						</div>
					{:else}
						<!-- Summary -->
						<div class="flex flex-wrap gap-3 mb-5">
							<div class="bg-gradient-to-br from-amber-50 to-amber-100 rounded-xl px-5 py-3 border border-amber-200 min-w-[140px]">
								<span class="text-[10px] text-amber-500 font-bold uppercase block">{$locale === 'ar' ? 'إجمالي الموظفين' : 'Total Employees'}</span>
								<span class="text-2xl font-black text-amber-700">{filteredInProcessClaims.length}</span>
							</div>
							<div class="bg-gradient-to-br from-emerald-50 to-emerald-100 rounded-xl px-5 py-3 border border-emerald-200 min-w-[140px]">
								<span class="text-[10px] text-emerald-500 font-bold uppercase block">{$locale === 'ar' ? 'إجمالي المنتجات قيد المعالجة' : 'Total Products In Process'}</span>
								<span class="text-2xl font-black text-emerald-700">{filteredInProcessClaims.reduce((sum, c) => sum + c.product_count, 0)}</span>
							</div>
						</div>

						<div class="flex-1 overflow-auto">
							<table class="w-full text-xs border-collapse border border-slate-300">
								<thead class="sticky top-0 z-10">
									<tr class="bg-amber-600 text-white">
										<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">#</th>
										<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'رقم الموظف' : 'Employee ID'}</th>
										<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold cursor-pointer select-none hover:bg-amber-700 transition-colors" on:click={() => toggleInProcessSort('name')}>
											{$locale === 'ar' ? 'اسم الموظف' : 'Employee Name'}
											{#if inProcessSortBy === 'name'}<span class="ml-1">{inProcessSortDir === 'asc' ? '▲' : '▼'}</span>{/if}
										</th>
										<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold cursor-pointer select-none hover:bg-amber-700 transition-colors" on:click={() => toggleInProcessSort('count')}>
											{$locale === 'ar' ? 'عدد المنتجات' : 'Product Count'}
											{#if inProcessSortBy === 'count'}<span class="ml-1">{inProcessSortDir === 'asc' ? '▲' : '▼'}</span>{/if}
										</th>
										<th class="border-r border-amber-500 py-2.5 px-3 text-left font-bold">{$locale === 'ar' ? 'الفروع' : 'Branches'}</th>								<th class="border-r border-amber-500 py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'تعيين' : 'Assign'}</th>										<th class="py-2.5 px-3 text-center font-bold">{$locale === 'ar' ? 'تفاصيل' : 'Details'}</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredInProcessClaims as claim, i}
										<tr class="border-b border-slate-300 hover:bg-amber-50/50 cursor-pointer {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}" on:click={() => selectedInProcessEmployee = claim}>
											<td class="border-r border-slate-300 py-2.5 px-3 text-slate-400 font-mono">{i + 1}</td>
											<td class="border-r border-slate-300 py-2.5 px-3 font-mono text-amber-700 font-bold">{claim.employee_id}</td>
											<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-800">{claim.name}</td>
											<td class="border-r border-slate-300 py-2.5 px-3">
												<span class="inline-flex items-center gap-1 bg-amber-50 text-amber-700 px-2.5 py-1 rounded-lg font-bold text-[11px] border border-amber-200">
													📦 {claim.product_count}
												</span>
											</td>
											<td class="border-r border-slate-300 py-2.5 px-3">
												<div class="flex flex-wrap gap-1">
													{#each Object.entries(claim.branch_counts) as [bid, count]}
														<span class="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-semibold border border-slate-200">
															{getBranchDisplay(Number(bid))} ({count})
														</span>
													{/each}
												</div>
											</td>
											<td class="border-r border-slate-300 py-2.5 px-3 text-center">
												<button
													class="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 rounded-lg transition-all text-amber-700 hover:text-amber-900 text-[10px] font-bold whitespace-nowrap border border-amber-200"
													on:click|stopPropagation={() => processAssign(claim)}
												>
													{$locale === 'ar' ? 'معالجة' : 'Process'}
												</button>
											</td>
											<td class="py-2.5 px-3 text-center">
												<button
													class="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 rounded-lg transition-all text-amber-700 hover:text-amber-900 text-[10px] font-bold whitespace-nowrap"
													on:click|stopPropagation={() => selectedInProcessEmployee = claim}
												>
													{$locale === 'ar' ? 'عرض المنتجات' : 'View Products'}
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{/if}
				</div>
			{/if}
		{/if}
	</div>
</div>

<!-- Assign Employee Modal -->
{#if showAssignModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/40 backdrop-blur-sm" on:click={() => { showAssignModal = false; assignItem = null; }}>
		<div class="bg-white rounded-2xl shadow-2xl w-[480px] max-h-[600px] flex flex-col overflow-hidden border border-slate-200" on:click|stopPropagation dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
			<!-- Modal Header -->
			<div class="px-6 py-4 bg-amber-50 border-b border-amber-200 flex items-center justify-between">
				<div class="flex items-center gap-2">
					<span class="text-xl">👤</span>
					<h3 class="text-base font-bold text-amber-800">{$locale === 'ar' ? 'تعيين إلى موظف' : 'Assign to Employee'}</h3>
				</div>
				<button class="p-1.5 hover:bg-amber-100 rounded-lg transition-all text-amber-500 hover:text-amber-700" on:click={() => { showAssignModal = false; assignItem = null; }}>✕</button>
			</div>

			<!-- Info -->
			<div class="px-6 py-3 bg-slate-50 border-b border-slate-200 text-xs text-slate-600">
				{#if assignIsMainTable && assignItem}
					<span class="font-bold text-amber-700">{assignItem.product_count || assignItem.products?.length || 0}</span> {$locale === 'ar' ? 'منتج من' : 'product(s) from'} <span class="font-bold">{assignItem.name || assignItem.employee_id}</span>
				{:else if assignItem}
					<span class="font-bold text-emerald-700">{assignItem.barcode}</span> — {assignItem.product_name || ''}
				{/if}
			</div>

			<!-- Search -->
			<div class="px-6 py-3 border-b border-slate-100">
				<div class="relative">
					<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
					<input
						type="text"
						bind:value={assignEmployeeSearch}
						placeholder={$locale === 'ar' ? 'بحث بالاسم أو الرقم...' : 'Search by name or ID...'}
						class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all"
					/>
				</div>
			</div>

			<!-- Employee List -->
			<div class="flex-1 overflow-auto px-3 py-2 min-h-[200px] max-h-[320px]">
				{#if assignEmployeeLoading}
					<div class="flex items-center justify-center py-8">
						<div class="text-3xl animate-bounce">👤</div>
					</div>
				{:else if filteredAssignEmployees.length === 0}
					<div class="flex items-center justify-center py-8 text-slate-400 text-xs font-semibold">
						{$locale === 'ar' ? 'لا توجد نتائج' : 'No results found'}
					</div>
				{:else}
					{#each filteredAssignEmployees as emp}
						<button
							class="w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-left transition-all mb-1 {assignSelectedEmployee?.id === emp.id ? 'bg-amber-100 border-amber-300 border-2 shadow-sm' : 'hover:bg-slate-50 border border-transparent'}"
							on:click={() => assignSelectedEmployee = emp}
						>
							<div class="w-8 h-8 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 font-bold text-xs flex-shrink-0">
								{emp.id.replace(/\D/g, '').slice(-2) || '?'}
							</div>
							<div class="flex-1 min-w-0">
								<div class="text-xs font-bold text-slate-800 truncate">{emp.name}</div>
								<div class="text-[10px] text-slate-400 font-mono">{emp.id}</div>
							</div>
							{#if assignSelectedEmployee?.id === emp.id}
								<span class="text-amber-600 text-sm">✓</span>
							{/if}
						</button>
					{/each}
				{/if}
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex items-center justify-between">
				<div class="text-xs text-slate-500">
					{#if assignSelectedEmployee}
						<span class="font-bold text-amber-700">{assignSelectedEmployee.name}</span> <span class="text-slate-400">({assignSelectedEmployee.id})</span>
					{:else}
						{$locale === 'ar' ? 'اختر موظفاً' : 'Select an employee'}
					{/if}
				</div>
				<div class="flex items-center gap-2">
					<button
						class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-600 rounded-xl text-xs font-bold transition-all"
						on:click={() => { showAssignModal = false; assignItem = null; }}
					>
						{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
					</button>
					<button
						class="px-5 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-bold transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
						disabled={!assignSelectedEmployee || assignProcessing}
						on:click={confirmAssign}
					>
						{assignProcessing ? '...' : ($locale === 'ar' ? 'تعيين' : 'Assign')}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<!-- Manage Branch Modal -->
{#if showManageBranchModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click={() => { showManageBranchModal = false; managesItem = null; }}>
		<div class="bg-white rounded-2xl shadow-2xl w-[500px] max-w-[95vw] overflow-hidden" on:click|stopPropagation>
			<!-- Header -->
			<div class="bg-gradient-to-r from-teal-500 to-teal-600 px-6 py-4 flex items-center justify-between">
				<div class="flex items-center gap-2">
					<span class="text-2xl">🏪</span>
					<h3 class="text-white font-bold text-lg">{$locale === 'ar' ? 'إدارة الفرع' : 'Manage Branch'}</h3>
				</div>
				<button class="text-white/80 hover:text-white text-xl font-bold" on:click={() => { showManageBranchModal = false; managesItem = null; }}>✕</button>
			</div>

			<!-- Info -->
			<div class="px-6 py-3 border-b border-gray-100 bg-teal-50/50">
				{#if managesIsMainTable && managesItem}
					<p class="text-sm text-gray-600">
						<span class="font-semibold text-teal-700">{managesItem.employee_id}</span> — {managesItem.name}
					</p>
				{:else if managesItem}
					<p class="text-sm text-gray-600">
						<span class="font-semibold text-teal-700">{managesItem.barcode}</span> — {managesItem.product_name}
					</p>
				{/if}
			</div>

			<!-- Branch Cards with individual To dropdowns -->
			<div class="px-6 pt-4 pb-4 flex flex-col gap-3 max-h-[400px] overflow-y-auto">
				{#if manageBranchAllLoading}
					<div class="text-xs text-gray-400 py-4 text-center">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading branches...'}</div>
				{:else}
					{#each manageBranchEmployeeBranches as branch, idx}
						<div class="border-2 {branch.toId !== null && branch.toId !== branch.id ? 'border-teal-400 bg-teal-50/30' : 'border-gray-200'} rounded-xl p-3 transition-all">
							<!-- From label -->
							<div class="flex items-center justify-between mb-2">
								<div class="flex items-center gap-2">
									<span class="text-xs font-bold text-gray-400 uppercase">{$locale === 'ar' ? 'من' : 'From'}</span>
									<span class="text-sm font-bold text-teal-700">
										{branchCache[branch.id] ? `${branchCache[branch.id].name}${branchCache[branch.id].location ? ' — ' + branchCache[branch.id].location : ''}` : `#${branch.id}`}
									</span>
								</div>
								<span class="text-[10px] bg-teal-100 text-teal-600 px-2 py-0.5 rounded-full font-bold">{branch.count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
							</div>
							<!-- To dropdown -->
							<div class="flex items-center gap-2">
								<span class="text-xs font-bold text-gray-400 uppercase whitespace-nowrap">{$locale === 'ar' ? 'إلى' : 'To'}</span>
								<select
									class="flex-1 px-2 py-1.5 border border-gray-200 rounded-lg text-xs focus:border-teal-400 focus:ring-1 focus:ring-teal-100 outline-none transition-all bg-white"
									bind:value={manageBranchEmployeeBranches[idx].toId}
								>
									<option value={null}>{$locale === 'ar' ? '-- لا تغيير --' : '-- No Change --'}</option>
									{#each manageBranchAllBranches.filter(b => b.id !== branch.id) as toBranch}
										<option value={toBranch.id}>{toBranch.name}{toBranch.location ? ` — ${toBranch.location}` : ''}</option>
									{/each}
								</select>
							</div>
						</div>
					{/each}
				{/if}
			</div>

			<!-- Footer -->
			<div class="px-6 py-3 bg-gray-50 border-t border-gray-100 flex justify-between items-center">
				<button
					class="px-5 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-xl text-xs font-bold transition-all"
					on:click={() => { showManageBranchModal = false; managesItem = null; }}
				>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
				<button
					class="px-6 py-2 bg-teal-500 hover:bg-teal-600 text-white rounded-xl text-xs font-bold transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
					disabled={!manageBranchEmployeeBranches.some(b => b.toId !== null && b.toId !== b.id) || manageBranchSaving}
					on:click={saveManageBranch}
				>
					{manageBranchSaving ? '...' : ($locale === 'ar' ? 'حفظ' : 'Save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Manages Modal -->
{#if showManagesModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click={() => showManagesModal = false}>
		<div class="bg-white rounded-2xl shadow-2xl w-[420px] max-w-[95vw] overflow-hidden" on:click|stopPropagation>
			<!-- Header -->
			<div class="bg-gradient-to-r from-teal-500 to-teal-600 px-6 py-4 flex items-center justify-between">
				<div class="flex items-center gap-2">
					<span class="text-2xl">⚙️</span>
					<h3 class="text-white font-bold text-lg">{$locale === 'ar' ? 'إدارة' : 'Manages'}</h3>
				</div>
				<button class="text-white/80 hover:text-white text-xl font-bold" on:click={() => showManagesModal = false}>✕</button>
			</div>

			<!-- Info -->
			<div class="px-6 py-4 border-b border-gray-100">
				{#if managesIsMainTable && managesItem}
					<p class="text-sm text-gray-600">
						<span class="font-semibold text-teal-700">{managesItem.employeeId}</span> — {managesItem.name}
						<span class="text-xs text-gray-400 {$locale === 'ar' ? 'mr-2' : 'ml-2'}">({managesItem.count} {$locale === 'ar' ? 'منتج' : 'products'})</span>
					</p>
				{:else if managesItem}
					<p class="text-sm text-gray-600">
						<span class="font-semibold text-teal-700">{managesItem.barcode}</span> — {managesItem.product_name_en}
					</p>
				{/if}
			</div>

			<!-- Action Buttons -->
			<div class="px-6 py-6 flex flex-col gap-3">
				<button
					class="w-full flex items-center justify-center gap-2 px-6 py-3.5 bg-teal-500 hover:bg-teal-600 text-white rounded-xl text-sm font-bold transition-all shadow-sm"
					on:click={manageBranch}
				>
					<span class="text-lg">🏪</span>
					{$locale === 'ar' ? 'إدارة الفرع' : 'Manage Branch'}
				</button>
				<button
					class="w-full flex items-center justify-center gap-2 px-6 py-3.5 bg-red-500 hover:bg-red-600 text-white rounded-xl text-sm font-bold transition-all shadow-sm"
					on:click={markAsUnclaim}
				>
					<span class="text-lg">❌</span>
					{$locale === 'ar' ? 'إلغاء المطالبة' : 'Mark as Unclaim'}
				</button>
			</div>

			<!-- Cancel -->
			<div class="px-6 py-3 bg-gray-50 border-t border-gray-100 flex justify-end">
				<button
					class="px-5 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-xl text-xs font-bold transition-all"
					on:click={() => showManagesModal = false}
				>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Unclaim Branch Picker Modal -->
{#if showUnclaimModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click={() => { showUnclaimModal = false; managesItem = null; }}>
		<div class="bg-white rounded-2xl shadow-2xl w-[420px] max-w-[95vw] overflow-hidden" on:click|stopPropagation>
			<!-- Header -->
			<div class="bg-gradient-to-r from-red-500 to-red-600 px-6 py-4 flex items-center justify-between">
				<div class="flex items-center gap-2">
					<span class="text-2xl">❌</span>
					<h3 class="text-white font-bold text-lg">{$locale === 'ar' ? 'إلغاء المطالبة' : 'Unclaim'}</h3>
				</div>
				<button class="text-white/80 hover:text-white text-xl font-bold" on:click={() => { showUnclaimModal = false; managesItem = null; }}>✕</button>
			</div>

			<!-- Info -->
			<div class="px-6 py-3 border-b border-gray-100 bg-red-50/50">
				{#if managesItem}
					<p class="text-sm text-gray-600">
						<span class="font-semibold text-red-700">{managesItem.employee_id}</span> — {managesItem.name}
					</p>
					<p class="text-xs text-gray-400 mt-1">{$locale === 'ar' ? 'اختر الفرع لإلغاء المطالبة' : 'Select branch to unclaim'}</p>
				{/if}
			</div>

			<!-- Branch Cards -->
			<div class="px-6 py-4 flex flex-col gap-2">
				{#each unclaimBranches as branch}
					<button
						class="w-full flex items-center justify-between px-4 py-3 rounded-xl border-2 transition-all text-sm {unclaimSelectedBranch === branch.id ? 'border-red-500 bg-red-50 text-red-700 shadow-sm' : 'border-gray-200 bg-white text-gray-600 hover:border-red-300'}"
						on:click={() => unclaimSelectedBranch = branch.id}
					>
						<span class="font-bold">
							{branchCache[branch.id] ? `${branchCache[branch.id].name}${branchCache[branch.id].location ? ' — ' + branchCache[branch.id].location : ''}` : `#${branch.id}`}
						</span>
						<span class="text-[10px] {unclaimSelectedBranch === branch.id ? 'bg-red-200 text-red-700' : 'bg-gray-100 text-gray-500'} px-2 py-0.5 rounded-full font-bold">{branch.count} {$locale === 'ar' ? 'منتج' : 'products'}</span>
					</button>
				{/each}
			</div>

			<!-- Footer -->
			<div class="px-6 py-3 bg-gray-50 border-t border-gray-100 flex justify-between items-center">
				<button
					class="px-5 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-xl text-xs font-bold transition-all"
					on:click={() => { showUnclaimModal = false; managesItem = null; }}
				>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
				<button
					class="px-6 py-2 bg-red-500 hover:bg-red-600 text-white rounded-xl text-xs font-bold transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
					disabled={unclaimSelectedBranch === null || unclaimProcessing}
					on:click={confirmUnclaim}
				>
					{unclaimProcessing ? '...' : ($locale === 'ar' ? 'إلغاء المطالبة' : 'Unclaim')}
				</button>
			</div>
		</div>
	</div>
{/if}