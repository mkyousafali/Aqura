<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	let supabase: any = null;

	// ─── Active Tab ───────────────────────────────────────────────────────────
	let activeTab: 'departments' | 'levels' | 'positions' | 'dashboard' | 'doc-expiry' = 'dashboard';

	// ─── Dropdown Data ────────────────────────────────────────────────────────
	let dropdowns: any = { branches: [], positions: [], departments: [], levels: [], employment_statuses: [] };

	// ─── DEPARTMENTS ──────────────────────────────────────────────────────────
	let depts: any[] = [];
	let deptsLoading = false;
	let deptsError = '';
	let deptsSearch = '';
	let deptsPage = 1;
	let deptsTotalCount = 0;
	const LIMIT = 50;

	// ─── LEVELS ───────────────────────────────────────────────────────────────
	let levels: any[] = [];
	let levelsLoading = false;
	let levelsError = '';
	let levelsSearch = '';
	let levelsPage = 1;
	let levelsTotalCount = 0;

	// ─── POSITIONS ────────────────────────────────────────────────────────────
	let positions: any[] = [];
	let posLoading = false;
	let posError = '';
	let posSearch = '';
	let posPage = 1;
	let posTotalCount = 0;
	let posDeptFilter: string = '';
	let posLevelFilter: string = '';

	// ─── EMPLOYEE DASHBOARD ───────────────────────────────────────────────────
	let employees: any[] = [];
	let empLoading = false;
	let empLoadingMore = false;
	let empError = '';
	let empSearch = '';
	let empPage = 1;
	let empTotalCount = 0;
	let empHasMore = false;
	let empExcludeStatuses: string[] = [];
	let empBranchFilter: number | null = null;

	// ─── MODAL STATE ──────────────────────────────────────────────────────────
	let modal: {
		open: boolean;
		type: 'dept' | 'level' | 'pos' | 'emp' | null;
		isNew: boolean;
		data: any;
		saving: boolean;
		error: string;
	} = { open: false, type: null, isNew: false, data: {}, saving: false, error: '' };

	// ─── HELPERS ──────────────────────────────────────────────────────────────
	$: lang = $locale === 'ar' ? 'ar' : 'en';
	$: isRTL = lang === 'ar';

	function locName(item: any, enKey: string, arKey: string) {
		return lang === 'ar' ? (item?.[arKey] || item?.[enKey] || '') : (item?.[enKey] || item?.[arKey] || '');
	}

	// ─── LIFECYCLE ────────────────────────────────────────────────────────────
	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await Promise.all([loadDropdowns(), loadEmployees()]);
	});

	async function loadDropdowns() {
		try {
			const { data, error } = await supabase.rpc('get_hr_dropdown_options');
			if (!error && data) dropdowns = data;
		} catch (e) { /* silent */ }
	}

	// ─── DEPARTMENTS ──────────────────────────────────────────────────────────
	async function loadDepts() {
		deptsLoading = true; deptsError = '';
		try {
			const { data, error } = await supabase.rpc('get_hr_departments_list', {
				p_search: deptsSearch.trim(),
				p_page: deptsPage,
				p_limit: LIMIT
			});
			if (error) throw error;
			depts = data || [];
			deptsTotalCount = depts[0]?.total_count ?? 0;
		} catch (e: any) {
			deptsError = e.message || $t('employeeMaster.errors.loadFailed');
		} finally { deptsLoading = false; }
	}

	async function saveDept() {
		modal.saving = true; modal.error = '';
		try {
			const args: any = {
				p_name_en: modal.data.department_name_en,
				p_name_ar: modal.data.department_name_ar,
				p_is_active: modal.data.is_active ?? true
			};
			if (!modal.isNew) args.p_id = modal.data.id;
			const { error } = await supabase.rpc('upsert_hr_department', args);
			if (error) throw error;
			closeModal();
			await Promise.all([loadDepts(), loadDropdowns()]);
		} catch (e: any) {
			modal.error = e.message || $t('employeeMaster.errors.saveFailed');
		} finally { modal.saving = false; }
	}

	// ─── LEVELS ───────────────────────────────────────────────────────────────
	async function loadLevels() {
		levelsLoading = true; levelsError = '';
		try {
			const { data, error } = await supabase.rpc('get_hr_levels_list', {
				p_search: levelsSearch.trim(),
				p_page: levelsPage,
				p_limit: LIMIT
			});
			if (error) throw error;
			levels = data || [];
			levelsTotalCount = levels[0]?.total_count ?? 0;
		} catch (e: any) {
			levelsError = e.message || $t('employeeMaster.errors.loadFailed');
		} finally { levelsLoading = false; }
	}

	async function saveLevel() {
		modal.saving = true; modal.error = '';
		try {
			const args: any = {
				p_name_en: modal.data.level_name_en,
				p_name_ar: modal.data.level_name_ar,
				p_level_order: Number(modal.data.level_order) || 1,
				p_is_active: modal.data.is_active ?? true
			};
			if (!modal.isNew) args.p_id = modal.data.id;
			const { error } = await supabase.rpc('upsert_hr_level', args);
			if (error) throw error;
			closeModal();
			await Promise.all([loadLevels(), loadDropdowns()]);
		} catch (e: any) {
			modal.error = e.message || $t('employeeMaster.errors.saveFailed');
		} finally { modal.saving = false; }
	}

	// ─── POSITIONS ────────────────────────────────────────────────────────────
	async function loadPositions() {
		posLoading = true; posError = '';
		try {
			const args: any = {
				p_search: posSearch.trim(),
				p_page: posPage,
				p_limit: LIMIT
			};
			if (posDeptFilter) args.p_department_id = posDeptFilter;
			if (posLevelFilter) args.p_level_id = posLevelFilter;
			const { data, error } = await supabase.rpc('get_hr_positions_list', args);
			if (error) throw error;
			positions = data || [];
			posTotalCount = positions[0]?.total_count ?? 0;
		} catch (e: any) {
			posError = e.message || $t('employeeMaster.errors.loadFailed');
		} finally { posLoading = false; }
	}

	async function savePosition() {
		modal.saving = true; modal.error = '';
		try {
			const args: any = {
				p_title_en: modal.data.position_title_en,
				p_title_ar: modal.data.position_title_ar,
				p_department_id: modal.data.department_id,
				p_level_id: modal.data.level_id,
				p_is_active: modal.data.is_active ?? true
			};
			if (!modal.isNew) args.p_id = modal.data.id;
			const { error } = await supabase.rpc('upsert_hr_position', args);
			if (error) throw error;
			closeModal();
			await Promise.all([loadPositions(), loadDropdowns()]);
		} catch (e: any) {
			modal.error = e.message || $t('employeeMaster.errors.saveFailed');
		} finally { modal.saving = false; }
	}

	// ─── EMPLOYEES ────────────────────────────────────────────────────────────
	async function loadEmployees(append = false) {
		if (append) { empLoadingMore = true; } else { empLoading = true; empError = ''; }
		try {
			const args: any = {
				p_search: empSearch.trim(),
				p_page: empPage,
				p_limit: LIMIT,
				p_branch_filter: empBranchFilter || null,
				p_exclude_statuses: empExcludeStatuses.length > 0 ? empExcludeStatuses : null
			};
			const { data, error } = await supabase.rpc('get_employee_master_list', args);
			if (error) throw error;
			const rows = data || [];
			if (append) {
				employees = [...employees, ...rows];
			} else {
				employees = rows;
			}
			empTotalCount = rows[0]?.total_count ?? empTotalCount;
			empHasMore = employees.length < empTotalCount;
		} catch (e: any) {
			empError = e.message || $t('employeeMaster.errors.loadFailed');
		} finally { empLoading = false; empLoadingMore = false; }
	}

	async function empLoadMore() {
		if (empLoadingMore || !empHasMore) return;
		empPage++;
		await loadEmployees(true);
	}

	function empScrollHandler(node: HTMLElement) {
		function onScroll() {
			if (node.scrollHeight - node.scrollTop - node.clientHeight < 120) {
				empLoadMore();
			}
		}
		node.addEventListener('scroll', onScroll, { passive: true });
		return { destroy() { node.removeEventListener('scroll', onScroll); } };
	}

	async function saveEmployee() {
		modal.saving = true; modal.error = '';
		try {
			const args: any = {
				p_id: modal.data.id,
				p_name_en: modal.data.name_en || null,
				p_name_ar: modal.data.name_ar || null,
				p_current_branch_id: modal.data.current_branch_id || null,
				p_current_position_id: modal.data.current_position_id || null,
				p_employment_status: modal.data.employment_status || null,
				p_whatsapp_number: modal.data.whatsapp_number || null,
				p_email: modal.data.email || null
			};
			const { error } = await supabase.rpc('update_employee_master_basic', args);
			if (error) throw error;
			closeModal();
			await loadEmployees();
		} catch (e: any) {
			modal.error = e.message || $t('employeeMaster.errors.saveFailed');
		} finally { modal.saving = false; }
	}

	// ─── MODAL HELPERS ────────────────────────────────────────────────────────
	function openNewDept() {
		modal = { open: true, type: 'dept', isNew: true, data: { department_name_en: '', department_name_ar: '', is_active: true }, saving: false, error: '' };
	}
	function openEditDept(row: any) {
		modal = { open: true, type: 'dept', isNew: false, data: { ...row }, saving: false, error: '' };
	}
	function openNewLevel() {
		modal = { open: true, type: 'level', isNew: true, data: { level_name_en: '', level_name_ar: '', level_order: 1, is_active: true }, saving: false, error: '' };
	}
	function openEditLevel(row: any) {
		modal = { open: true, type: 'level', isNew: false, data: { ...row }, saving: false, error: '' };
	}
	function openNewPos() {
		modal = { open: true, type: 'pos', isNew: true, data: { position_title_en: '', position_title_ar: '', department_id: '', level_id: '', is_active: true }, saving: false, error: '' };
	}
	function openEditPos(row: any) {
		modal = { open: true, type: 'pos', isNew: false, data: { ...row }, saving: false, error: '' };
	}
	function openEditEmp(row: any) {
		modal = { open: true, type: 'emp', isNew: false, data: { ...row }, saving: false, error: '' };
	}
	function closeModal() {
		modal = { open: false, type: null, isNew: false, data: {}, saving: false, error: '' };
		ssReset();
	}

	// ─── SEARCHABLE SELECT STATE ──────────────────────────────────────────────
	let ss: Record<string, { open: boolean; q: string }> = {
		dept: { open: false, q: '' },
		level: { open: false, q: '' },
		branch: { open: false, q: '' },
		pos: { open: false, q: '' },
		status: { open: false, q: '' },
	};
	function ssOpen(key: string) {
		Object.keys(ss).forEach(k => { if (k !== key) ss[k] = { ...ss[k], open: false }; });
		ss[key] = { ...ss[key], open: !ss[key].open };
	}
	function ssSelect(key: string) {
		ss[key] = { open: false, q: '' };
		ss = ss;
	}
	function ssReset() {
		Object.keys(ss).forEach(k => ss[k] = { open: false, q: '' });
		ss = ss;
	}
	function clickOutsideSS(node: HTMLElement, key: string) {
		const handler = (e: MouseEvent) => {
			if (!node.contains(e.target as Node)) {
				ss[key] = { ...ss[key], open: false };
				ss = ss;
			}
		};
		document.addEventListener('mousedown', handler, true);
		return { destroy() { document.removeEventListener('mousedown', handler, true); } };
	}
	function ssFilter(items: any[], q: string, labelFn: (i: any) => string) {
		if (!q.trim()) return items;
		const lq = q.toLowerCase();
		return items.filter(i => labelFn(i).toLowerCase().includes(lq));
	}

	// ─── TAB SWITCHING WITH LAZY LOAD ─────────────────────────────────────────
	async function switchTab(tab: typeof activeTab) {
		activeTab = tab;
		if (tab === 'departments' && depts.length === 0 && !deptsLoading) await loadDepts();
		if (tab === 'levels' && levels.length === 0 && !levelsLoading) await loadLevels();
		if (tab === 'positions' && positions.length === 0 && !posLoading) await loadPositions();
		if (tab === 'doc-expiry' && documentsExpiryData.length === 0 && !docExpiryLoading) await loadDocumentsExpiryData();
	}

	// ─── SEARCH DEBOUNCE ─────────────────────────────────────────────────────
	let deptsSearchTimer: any;
	let levelsSearchTimer: any;
	let posSearchTimer: any;
	let empSearchTimer: any;

	function onDeptsSearch() {
		deptsPage = 1;
		clearTimeout(deptsSearchTimer);
		deptsSearchTimer = setTimeout(loadDepts, 350);
	}
	function onLevelsSearch() {
		levelsPage = 1;
		clearTimeout(levelsSearchTimer);
		levelsSearchTimer = setTimeout(loadLevels, 350);
	}
	function onPosSearch() {
		posPage = 1;
		clearTimeout(posSearchTimer);
		posSearchTimer = setTimeout(loadPositions, 350);
	}
	function onEmpSearch() {
		empPage = 1; employees = [];
		clearTimeout(empSearchTimer);
		empSearchTimer = setTimeout(loadEmployees, 350);
	}

	// ─── PAGINATION (depts/levels/pos only) ───────────────────────────────────
	function deptsPages() { return Math.max(1, Math.ceil(deptsTotalCount / LIMIT)); }
	function levelsPages() { return Math.max(1, Math.ceil(levelsTotalCount / LIMIT)); }
	function posPages() { return Math.max(1, Math.ceil(posTotalCount / LIMIT)); }

	async function goDepts(p: number) { deptsPage = p; await loadDepts(); }
	async function goLevels(p: number) { levelsPage = p; await loadLevels(); }
	async function goPos(p: number) { posPage = p; await loadPositions(); }

	// ─── STATUS COLOR ─────────────────────────────────────────────────────────
	function statusColor(status: string) {
		switch (status) {
			case 'Job (With Finger)': return '#22c55e';
			case 'Remote Job': return '#6366f1';
			case 'Vacation': return '#f59e0b';
			case 'Resigned': return '#ef4444';
			case 'Terminated': return '#dc2626';
			default: return '#94a3b8';
		}
	}

	function statusBg(status: string) {
		switch (status) {
			case 'Job (With Finger)': return '#dcfce7';
			case 'Remote Job': return '#eef2ff';
			case 'Vacation': return '#fefce8';
			case 'Resigned': return '#fef2f2';
			case 'Terminated': return '#fef2f2';
			default: return '#f1f5f9';
		}
	}

	function formatDate(d: string) {
		if (!d) return '—';
		return new Date(d).toLocaleDateString(lang === 'ar' ? 'ar-SA' : 'en-GB', { year: 'numeric', month: 'short', day: '2-digit' });
	}

	// ─── DOCUMENTS EXPIRY & EMPLOYEE STATUS (merged from HR Dashboard) ─────────
	const DOCUMENT_TYPES_EXP = [
		{ key: 'id_expiry_date', label: 'ID', type: 'id' },
		{ key: 'health_card_expiry_date', label: 'Health Card', type: 'health_card' },
		{ key: 'driving_licence_expiry_date', label: 'Driving Licence', type: 'driving_licence' },
		{ key: 'contract_expiry_date', label: 'Contract', type: 'contract' },
		{ key: 'work_permit_expiry_date', label: 'Work Permit', type: 'work_permit' },
		{ key: 'insurance_expiry_date', label: 'Insurance', type: 'insurance' },
		{ key: 'health_educational_renewal_date', label: 'Health Educational Renewal', type: 'health_educational' },
	];
	const COLUMN_LABELS_EXP = [
		{ key: 'id', label: 'Employee ID' },
		{ key: 'name', label: 'Full Name' },
		{ key: 'nationality', label: 'Nationality' },
		{ key: 'branch', label: 'Current Branch' },
		{ key: 'doc_id', label: 'ID Expiry' },
		{ key: 'doc_health_card', label: 'Health Card' },
		{ key: 'doc_driving_licence', label: 'Driving Licence' },
		{ key: 'doc_contract', label: 'Contract' },
		{ key: 'doc_work_permit', label: 'Work Permit' },
		{ key: 'doc_insurance', label: 'Insurance' },
		{ key: 'doc_health_educational', label: 'Health Educational Renewal' }
	];
	const ACTIVE_EMP_STATUSES = ['Job (With Finger)', 'Remote Job', 'Vacation'];
	const ALL_EMP_STATUSES_LIST = ['Job (With Finger)', 'Remote Job', 'Vacation', 'Resigned', 'Terminated', 'Run Away'];
	const STATUSES_NEEDING_DATE = ['Vacation', 'Resigned', 'Terminated', 'Run Away'];
	const STATUS_ORDER_MAP: Record<string, number> = { 'Job (With Finger)': 1, 'Remote Job': 2, 'Vacation': 3, 'Resigned': 4, 'Terminated': 5, 'Run Away': 6 };

	// Documents Expiry state
	let documentsExpiryData: any[] = [];
	let docExpiryLoading = false;
	let docSearchTerm = '';
	let docSelectedBranch = '';
	let docSelectedNationality = '';
	let showColumnDropdown = false;
	let columnVisibility: Record<string, boolean> = {
		id: true, name: true, nationality: true, branch: true,
		doc_id: true, doc_health_card: true, doc_driving_licence: true,
		doc_contract: true, doc_work_permit: true, doc_insurance: true, doc_health_educational: true
	};
	let showDateModal = false;
	let modalEmpId = '';
	let modalEmpName = '';
	let modalDocType = '';
	let modalDocKey = '';
	let modalCurDate = '';
	let modalNewDate = '';
	let isSavingDate = false;

	// Employee Status state
	let employeeStatusData: any[] = [];
	let empStatusLoading = false;
	let statusSearchTerm = '';
	let statusSelBranch = '';
	let statusSelStatus = '';
	let showStatusModal = false;
	let statusModalEmpId = '';
	let statusModalEmpName = '';
	let statusModalCurStatus = '';
	let statusModalNewStatus = '';
	let statusModalEffDate = '';
	let statusModalReason = '';
	let statusModalSaving = false;

	$: docNeedsEffDate = STATUSES_NEEDING_DATE.includes(statusModalNewStatus);

	$: docUniqueBranches = [...new Map(
		documentsExpiryData.map(emp => [emp.current_branch_id, { id: emp.current_branch_id, name_en: emp.branch_name_en, name_ar: emp.branch_name_ar }])
	).values()].sort((a, b) => a.name_en.localeCompare(b.name_en));

	$: docUniqueNationalities = [...new Map(
		documentsExpiryData.map(emp => [emp.nationality_id, { id: emp.nationality_id, name_en: emp.nationality_name_en, name_ar: emp.nationality_name_ar }])
	).values()].sort((a, b) => a.name_en.localeCompare(b.name_en));

	$: docFilteredData = documentsExpiryData.filter(emp => {
		const s = docSearchTerm.toLowerCase();
		const matchesSearch = !s || emp.id.toLowerCase().includes(s) || emp.name_en.toLowerCase().includes(s) || emp.name_ar.includes(docSearchTerm);
		const matchesBranch = !docSelectedBranch || emp.current_branch_id === parseInt(docSelectedBranch);
		const matchesNat = !docSelectedNationality || emp.nationality_id === docSelectedNationality;
		return matchesSearch && matchesBranch && matchesNat;
	});

	$: docSortedData = [...docFilteredData].sort((a, b) => getDocUrgencyScore(a).score - getDocUrgencyScore(b).score);

	$: statusUniqueBranches = [...new Map(
		employeeStatusData.filter(e => e.current_branch_id).map(emp => [emp.current_branch_id, { id: emp.current_branch_id, name_en: emp.branch_name_en, name_ar: emp.branch_name_ar }])
	).values()].sort((a, b) => a.name_en.localeCompare(b.name_en));

	$: filteredStatusData = employeeStatusData.filter(emp => {
		const s = statusSearchTerm.toLowerCase();
		const matchesSearch = !s || String(emp.id||'').toLowerCase().includes(s) || (emp.name_en||'').toLowerCase().includes(s) || (emp.name_ar||'').includes(statusSearchTerm);
		const matchesBranch = !statusSelBranch || String(emp.current_branch_id) === statusSelBranch;
		const matchesStatus = !statusSelStatus || emp.employment_status === statusSelStatus;
		return matchesSearch && matchesBranch && matchesStatus;
	}).sort((a, b) => {
		const d = (STATUS_ORDER_MAP[a.employment_status] ?? 99) - (STATUS_ORDER_MAP[b.employment_status] ?? 99);
		return d !== 0 ? d : (a.name_en||'').localeCompare(b.name_en||'');
	});

	function calcDaysRemaining(expiryDate: string | null): number {
		if (!expiryDate) return -999;
		const today = new Date(); today.setHours(0, 0, 0, 0);
		return Math.ceil((new Date(expiryDate).getTime() - today.getTime()) / 86400000);
	}

	function getDocUrgencyScore(emp: any): { score: number } {
		let mostUrgent = 999999;
		if (emp.documents) {
			for (const k in emp.documents) {
				const d = emp.documents[k];
				if (d && d.daysRemaining !== undefined && d.daysRemaining !== -999 && Number(d.daysRemaining) < mostUrgent) mostUrgent = Number(d.daysRemaining);
			}
		}
		const days = mostUrgent === 999999 ? 999999 : mostUrgent;
		if (days < 0) return { score: days };
		if (days <= 30) return { score: 1000 + days };
		if (days <= 90) return { score: 2000 + days };
		return { score: 3000 + days };
	}

	function openDocDateModal(empId: string, empName: string, docType: string, docKey: string, curDate: string) {
		modalEmpId = empId; modalEmpName = empName; modalDocType = docType;
		modalDocKey = docKey; modalCurDate = curDate || ''; modalNewDate = curDate || '';
		showDateModal = true;
	}
	function closeDocDateModal() { showDateModal = false; isSavingDate = false; }

	async function saveDocDateChange() {
		if (!supabase || !modalEmpId || !modalDocKey) return;
		isSavingDate = true;
		try {
			const updateData: any = {}; updateData[modalDocKey] = modalNewDate || null;
			const { error } = await supabase.from('hr_employee_master').update(updateData).eq('id', modalEmpId);
			if (error) throw error;
			await loadDocumentsExpiryData();
			closeDocDateModal();
		} catch { alert('Failed to update date'); } finally { isSavingDate = false; }
	}

	async function loadDocumentsExpiryData() {
		docExpiryLoading = true;
		try {
			const { data: employees, error } = await supabase
				.from('hr_employee_master')
				.select(`id, name_en, name_ar, nationality_id, current_branch_id, employment_status,
					id_expiry_date, health_card_expiry_date, driving_licence_expiry_date,
					contract_expiry_date, work_permit_expiry_date, insurance_expiry_date,
					health_educational_renewal_date, branches(name_en, name_ar, location_en, location_ar)`)
				.in('employment_status', ACTIVE_EMP_STATUSES)
				.order('name_en', { ascending: true });
			if (error) throw error;
			const { data: nats } = await supabase.from('nationalities').select('id, name_en, name_ar');
			const natMap = new Map((nats || []).map((n: any) => [n.id, n]));
			documentsExpiryData = (employees || []).map((emp: any) => {
				const nat: any = natMap.get(emp.nationality_id) || { name_en: 'N/A', name_ar: 'N/A' };
				const branch = emp.branches || { name_en: 'N/A', name_ar: 'N/A', location_en: 'N/A', location_ar: 'N/A' };
				const documents: any = {};
				DOCUMENT_TYPES_EXP.forEach(dt => {
					const days = calcDaysRemaining(emp[dt.key]);
					documents[dt.type] = { label: dt.label, expiryDate: emp[dt.key], daysRemaining: days, status: days < 0 ? 'Expired' : days <= 30 ? 'Expiring Soon' : days <= 90 ? 'Warning' : 'Active' };
				});
				return {
					id: emp.id, name_en: emp.name_en || 'N/A', name_ar: emp.name_ar || 'N/A',
					nationality_id: emp.nationality_id, nationality_name_en: nat.name_en, nationality_name_ar: nat.name_ar,
					current_branch_id: emp.current_branch_id, branch_name_en: branch.name_en, branch_name_ar: branch.name_ar,
					branch_location_en: branch.location_en, branch_location_ar: branch.location_ar, documents
				};
			});
		} catch (err) { console.error('Error loading documents expiry:', err); }
		finally { docExpiryLoading = false; }
	}

	async function loadEmployeeStatusData() {
		empStatusLoading = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select(`id, name_en, name_ar, id_number, contract_expiry_date, sponsorship_status,
					work_permit_expiry_date, employment_status, whatsapp_number, email,
					current_branch_id, branches(name_en, name_ar)`)
				.order('name_en', { ascending: true });
			if (error) throw error;
			employeeStatusData = (data || []).map((emp: any) => ({ ...emp, branch_name_en: emp.branches?.name_en || '-', branch_name_ar: emp.branches?.name_ar || '-' }));
		} catch (err) { console.error('Error loading employee status:', err); }
		finally { empStatusLoading = false; }
	}

	function getStatusLabel(status: string): string {
		if (lang !== 'ar') return status || '—';
		const map: Record<string, string> = {
			'Job (With Finger)': $t('employeeMaster.empStatus.statuses.jobWithFinger'),
			'Remote Job':        $t('employeeMaster.empStatus.statuses.remoteJob'),
			'Vacation':          $t('employeeMaster.empStatus.statuses.vacation'),
			'Resigned':          $t('employeeMaster.empStatus.statuses.resigned'),
			'Terminated':        $t('employeeMaster.empStatus.statuses.terminated'),
			'Run Away':          $t('employeeMaster.empStatus.statuses.runAway'),
		};
		return map[status] || status || '—';
	}

	function getEmpStatusBadge(status: string): string {
		const badges: Record<string, string> = {
			'Job (With Finger)': 'bg-green-100 text-green-800', 'Remote Job': 'bg-blue-100 text-blue-800',
			'Vacation': 'bg-yellow-100 text-yellow-800', 'Resigned': 'bg-slate-100 text-slate-600',
			'Terminated': 'bg-red-100 text-red-800', 'Run Away': 'bg-orange-100 text-orange-800'
		};
		return badges[status] || 'bg-slate-100 text-slate-600';
	}

	function openEmpStatusModal(emp: any) {
		statusModalEmpId = emp.id;
		statusModalEmpName = lang === 'ar' ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar);
		statusModalCurStatus = emp.employment_status || '';
		statusModalNewStatus = emp.employment_status || '';
		statusModalEffDate = ''; statusModalReason = '';
		showStatusModal = true;
	}
	function closeEmpStatusModal() { showStatusModal = false; statusModalSaving = false; }

	async function saveEmpStatusChange() {
		if (!supabase || !statusModalEmpId || !statusModalNewStatus) return;
		if (STATUSES_NEEDING_DATE.includes(statusModalNewStatus) && !statusModalEffDate) { alert('Please enter an effective date.'); return; }
		statusModalSaving = true;
		try {
			const updateData: any = { employment_status: statusModalNewStatus };
			if (STATUSES_NEEDING_DATE.includes(statusModalNewStatus)) { updateData.employment_status_effective_date = statusModalEffDate; updateData.employment_status_reason = statusModalReason || null; }
			const { error } = await supabase.from('hr_employee_master').update(updateData).eq('id', statusModalEmpId);
			if (error) throw error;
			employeeStatusData = employeeStatusData.map(e => e.id === statusModalEmpId ? { ...e, employment_status: statusModalNewStatus } : e);
			closeEmpStatusModal();
		} catch { alert('Failed to update status'); } finally { statusModalSaving = false; }
	}
</script>

<!-- ============================================================ -->
<!-- MAIN CONTAINER -->
<!-- ============================================================ -->
<div class="em-root" dir={isRTL ? 'rtl' : 'ltr'}>

	<!-- TABS -->
	<div class="em-tabs">
		<button class="em-tab" class:active={activeTab === 'dashboard'} on:click={() => switchTab('dashboard')}>
			<span>📋</span> {$t('employeeMaster.tabs.dashboard')}
		</button>
		<button class="em-tab" class:active={activeTab === 'departments'} on:click={() => switchTab('departments')}>
			<span>🏢</span> {$t('employeeMaster.tabs.departments')}
		</button>
		<button class="em-tab" class:active={activeTab === 'levels'} on:click={() => switchTab('levels')}>
			<span>📊</span> {$t('employeeMaster.tabs.levels')}
		</button>
		<button class="em-tab" class:active={activeTab === 'positions'} on:click={() => switchTab('positions')}>
			<span>💼</span> {$t('employeeMaster.tabs.positions')}
		</button>
		<button class="em-tab" class:active={activeTab === 'doc-expiry'} on:click={() => switchTab('doc-expiry')}>
		<span>📄</span> {$t('employeeMaster.tabs.docExpiry')}
	</button>
	</div>

	<!-- ── DASHBOARD TAB ── -->
	{#if activeTab === 'dashboard'}
	<div class="em-panel">
		<!-- Controls -->
		<div class="em-controls-wrap">
			<div class="em-controls">
				<div class="em-search-wrap">
					<span class="em-search-icon">🔍</span>
					<input class="em-search" type="search"
						placeholder={$t('employeeMaster.searchPlaceholder')}
						bind:value={empSearch}
						on:input={onEmpSearch}
					/>
				</div>
				<select class="em-filter" bind:value={empBranchFilter} on:change={() => { empPage = 1; employees = []; loadEmployees(); }}>
					<option value={null}>{$t('employeeMaster.allBranches')}</option>
					{#each dropdowns.branches || [] as b}
						<option value={b.id}>{locName(b, 'name_en', 'name_ar')}</option>
					{/each}
				</select>
				<button class="em-btn-clear" on:click={() => { empSearch=''; empExcludeStatuses=[]; empBranchFilter=null; empPage=1; employees=[]; loadEmployees(); }}>
					↺ {$t('employeeMaster.clearFilters')}
				</button>
				<span class="em-count">{empTotalCount} {$t('employeeMaster.employees')}</span>
			</div>
			<!-- Status exclude checkboxes row -->
			{#if (dropdowns.employment_statuses || []).length > 0}
			<div class="em-status-toggles">
				<span class="em-status-label">{$t('employeeMaster.allStatuses')}:</span>
				{#each dropdowns.employment_statuses as s}
					{@const excluded = empExcludeStatuses.includes(s)}
					<label
						class="em-status-chk"
						class:excluded
						style="--sbg:{statusBg(s)};--sfg:{statusColor(s)}"
						title={excluded ? 'Click to show' : 'Click to hide'}
					>
						<input
							type="checkbox"
							checked={!excluded}
							on:change={() => {
								if (excluded) {
									empExcludeStatuses = empExcludeStatuses.filter(x => x !== s);
								} else {
									empExcludeStatuses = [...empExcludeStatuses, s];
								}
								empPage = 1; employees = [];
								loadEmployees();
							}}
						/>
						<span class="em-chk-dot" style="background:{excluded ? '#cbd5e1' : statusBg(s)};border-color:{excluded ? '#94a3b8' : statusColor(s)}"></span>
						<span class="em-chk-name" style="color:{excluded ? '#94a3b8' : statusColor(s)};text-decoration:{excluded ? 'line-through' : 'none'}">{getStatusLabel(s)}</span>
					</label>
				{/each}
			</div>
			{/if}
		</div>

		<!-- Table -->
		{#if empLoading}
			<div class="em-state em-loading"><div class="em-spinner"></div> {$t('employeeMaster.loading')}</div>
		{:else if empError}
			<div class="em-state em-error">⚠️ {empError}</div>
		{:else if employees.length === 0}
			<div class="em-state em-empty">👤 {$t('employeeMaster.noEmployees')}</div>
		{:else}
		<div class="em-table-wrap" use:empScrollHandler>
			<table class="em-table">
				<thead>
					<tr>
						<th style="width:42px;text-align:center">#</th>
						<th style="min-width:160px">{$t('employeeMaster.cols.name')}</th>
						<th style="min-width:160px">{$t('employeeMaster.cols.branch')}</th>
						<th style="min-width:140px">{$t('employeeMaster.cols.position')}</th>
						<th style="min-width:130px">{$t('employeeMaster.cols.status')}</th>
						<th style="min-width:160px">{$t('employeeMaster.cols.contact')}</th>
						<th style="min-width:80px">{$t('employeeMaster.cols.actions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each employees as emp, i (emp.id)}
					<tr on:dblclick={() => openEditEmp(emp)} title={$t('employeeMaster.dblClickEdit')}>
						<td style="text-align:center;color:#94a3b8;font-size:12px;font-weight:600">{i + 1}</td>
						<td class="em-cell-name">
							<strong>{lang === 'ar' ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar)}</strong>
							<span class="em-cell-empid">{emp.id}</span>
						</td>
						<td class="em-cell-branch">
							<span class="em-branch-name">{lang === 'ar' ? (emp.branch_name_ar || emp.branch_name_en) : (emp.branch_name_en || emp.branch_name_ar)}</span>
							{#if emp.branch_location_en || emp.branch_location_ar}
								<span class="em-branch-loc">{lang === 'ar' ? (emp.branch_location_ar || emp.branch_location_en) : (emp.branch_location_en || emp.branch_location_ar)}</span>
							{/if}
						</td>
						<td>{lang === 'ar' ? (emp.position_title_ar || emp.position_title_en || '—') : (emp.position_title_en || emp.position_title_ar || '—')}</td>
						<td>
							<span class="em-badge" style="background:{statusBg(emp.employment_status)};color:{statusColor(emp.employment_status)}">
								{getStatusLabel(emp.employment_status || '—')}
							</span>
						</td>
						<td class="em-cell-contact">
							{#if emp.whatsapp_number}<span>📱 {emp.whatsapp_number}</span>{/if}
							{#if emp.email}<span class="em-email">✉️ {emp.email}</span>{/if}
							{#if !emp.whatsapp_number && !emp.email}<span class="em-muted">—</span>{/if}
						</td>
						<td>
							<button class="em-btn-edit" on:click={() => openEditEmp(emp)}>✏️ {$t('employeeMaster.edit')}</button>
						</td>
					</tr>
					{/each}
				</tbody>
			</table>
			{#if empLoadingMore}
				<div class="em-state em-loading" style="padding:10px"><div class="em-spinner"></div></div>
			{/if}
		</div>
		{/if}
	</div>
	{/if}

	<!-- ── DEPARTMENTS TAB ── -->
	{#if activeTab === 'departments'}
	<div class="em-panel">
		<div class="em-controls">
			<div class="em-search-wrap">
				<span class="em-search-icon">🔍</span>
				<input class="em-search" type="search"
					placeholder={$t('employeeMaster.searchPlaceholder')}
					bind:value={deptsSearch}
					on:input={onDeptsSearch}
				/>
			</div>
			<button class="em-btn-add" on:click={openNewDept}>+ {$t('employeeMaster.addDepartment')}</button>
			<span class="em-count">{deptsTotalCount} {$t('employeeMaster.total')}</span>
		</div>

		{#if deptsLoading}
			<div class="em-state em-loading"><div class="em-spinner"></div> {$t('employeeMaster.loading')}</div>
		{:else if deptsError}
			<div class="em-state em-error">⚠️ {deptsError}</div>
		{:else if depts.length === 0}
			<div class="em-state em-empty">🏢 {$t('employeeMaster.noDepartments')}</div>
		{:else}
		<div class="em-table-wrap">
			<table class="em-table">
				<thead>
					<tr>
						<th>{$t('employeeMaster.cols.nameAr')}</th>
						<th>{$t('employeeMaster.cols.nameEn')}</th>
						<th>{$t('employeeMaster.cols.status')}</th>
						<th>{$t('employeeMaster.cols.created')}</th>
						<th>{$t('employeeMaster.cols.actions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each depts as d (d.id)}
					<tr on:dblclick={() => openEditDept(d)} title={$t('employeeMaster.dblClickEdit')}>
						<td><strong>{d.department_name_ar}</strong></td>
						<td>{d.department_name_en}</td>
						<td>
							<span class="em-badge" style="background:{d.is_active ? '#dcfce7' : '#fee2e2'};color:{d.is_active ? '#166534' : '#991b1b'}">
								{d.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}
							</span>
						</td>
						<td class="em-muted">{formatDate(d.created_at)}</td>
						<td><button class="em-btn-edit" on:click={() => openEditDept(d)}>✏️ {$t('employeeMaster.edit')}</button></td>
					</tr>
					{/each}
				</tbody>
			</table>
		</div>
		<div class="em-pagination">
			<button disabled={deptsPage <= 1} on:click={() => goDepts(deptsPage - 1)}>‹</button>
			<span>{$t('employeeMaster.page')} {deptsPage} / {deptsPages()}</span>
			<button disabled={deptsPage >= deptsPages()} on:click={() => goDepts(deptsPage + 1)}>›</button>
		</div>
		{/if}
	</div>
	{/if}

	<!-- ── LEVELS TAB ── -->
	{#if activeTab === 'levels'}
	<div class="em-panel">
		<div class="em-controls">
			<div class="em-search-wrap">
				<span class="em-search-icon">🔍</span>
				<input class="em-search" type="search"
					placeholder={$t('employeeMaster.searchPlaceholder')}
					bind:value={levelsSearch}
					on:input={onLevelsSearch}
				/>
			</div>
			<button class="em-btn-add" on:click={openNewLevel}>+ {$t('employeeMaster.addLevel')}</button>
			<span class="em-count">{levelsTotalCount} {$t('employeeMaster.total')}</span>
		</div>

		{#if levelsLoading}
			<div class="em-state em-loading"><div class="em-spinner"></div> {$t('employeeMaster.loading')}</div>
		{:else if levelsError}
			<div class="em-state em-error">⚠️ {levelsError}</div>
		{:else if levels.length === 0}
			<div class="em-state em-empty">📊 {$t('employeeMaster.noLevels')}</div>
		{:else}
		<div class="em-table-wrap">
			<table class="em-table">
				<thead>
					<tr>
						<th>{$t('employeeMaster.cols.order')}</th>
						<th>{$t('employeeMaster.cols.nameAr')}</th>
						<th>{$t('employeeMaster.cols.nameEn')}</th>
						<th>{$t('employeeMaster.cols.status')}</th>
						<th>{$t('employeeMaster.cols.created')}</th>
						<th>{$t('employeeMaster.cols.actions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each levels as l (l.id)}
					<tr on:dblclick={() => openEditLevel(l)} title={$t('employeeMaster.dblClickEdit')}>
						<td class="em-order-badge"><span>{l.level_order}</span></td>
						<td><strong>{l.level_name_ar}</strong></td>
						<td>{l.level_name_en}</td>
						<td>
							<span class="em-badge" style="background:{l.is_active ? '#dcfce7' : '#fee2e2'};color:{l.is_active ? '#166534' : '#991b1b'}">
								{l.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}
							</span>
						</td>
						<td class="em-muted">{formatDate(l.created_at)}</td>
						<td><button class="em-btn-edit" on:click={() => openEditLevel(l)}>✏️ {$t('employeeMaster.edit')}</button></td>
					</tr>
					{/each}
				</tbody>
			</table>
		</div>
		<div class="em-pagination">
			<button disabled={levelsPage <= 1} on:click={() => goLevels(levelsPage - 1)}>‹</button>
			<span>{$t('employeeMaster.page')} {levelsPage} / {levelsPages()}</span>
			<button disabled={levelsPage >= levelsPages()} on:click={() => goLevels(levelsPage + 1)}>›</button>
		</div>
		{/if}
	</div>
	{/if}

	<!-- ── POSITIONS TAB ── -->
	{#if activeTab === 'positions'}
	<div class="em-panel">
		<div class="em-controls">
			<div class="em-search-wrap">
				<span class="em-search-icon">🔍</span>
				<input class="em-search" type="search"
					placeholder={$t('employeeMaster.searchPlaceholder')}
					bind:value={posSearch}
					on:input={onPosSearch}
				/>
			</div>
			<select class="em-filter" bind:value={posDeptFilter} on:change={() => { posPage = 1; loadPositions(); }}>
				<option value="">{$t('employeeMaster.allDepts')}</option>
				{#each dropdowns.departments || [] as d}
					<option value={d.id}>{locName(d, 'name_en', 'name_ar')}</option>
				{/each}
			</select>
			<select class="em-filter" bind:value={posLevelFilter} on:change={() => { posPage = 1; loadPositions(); }}>
				<option value="">{$t('employeeMaster.allLevels')}</option>
				{#each dropdowns.levels || [] as l}
					<option value={l.id}>{locName(l, 'name_en', 'name_ar')}</option>
				{/each}
			</select>
			<button class="em-btn-add" on:click={openNewPos}>+ {$t('employeeMaster.addPosition')}</button>
			<span class="em-count">{posTotalCount} {$t('employeeMaster.total')}</span>
		</div>

		{#if posLoading}
			<div class="em-state em-loading"><div class="em-spinner"></div> {$t('employeeMaster.loading')}</div>
		{:else if posError}
			<div class="em-state em-error">⚠️ {posError}</div>
		{:else if positions.length === 0}
			<div class="em-state em-empty">💼 {$t('employeeMaster.noPositions')}</div>
		{:else}
		<div class="em-table-wrap">
			<table class="em-table">
				<thead>
					<tr>
						<th>{$t('employeeMaster.cols.nameAr')}</th>
						<th>{$t('employeeMaster.cols.nameEn')}</th>
						<th>{$t('employeeMaster.cols.department')}</th>
						<th>{$t('employeeMaster.cols.level')}</th>
						<th>{$t('employeeMaster.cols.status')}</th>
						<th>{$t('employeeMaster.cols.actions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each positions as p (p.id)}
					<tr on:dblclick={() => openEditPos(p)} title={$t('employeeMaster.dblClickEdit')}>
						<td><strong>{p.position_title_ar}</strong></td>
						<td>{p.position_title_en}</td>
						<td>{lang === 'ar' ? (p.department_name_ar || p.department_name_en) : (p.department_name_en || p.department_name_ar)}</td>
						<td>{lang === 'ar' ? (p.level_name_ar || p.level_name_en) : (p.level_name_en || p.level_name_ar)}</td>
						<td>
							<span class="em-badge" style="background:{p.is_active ? '#dcfce7' : '#fee2e2'};color:{p.is_active ? '#166534' : '#991b1b'}">
								{p.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}
							</span>
						</td>
						<td><button class="em-btn-edit" on:click={() => openEditPos(p)}>✏️ {$t('employeeMaster.edit')}</button></td>
					</tr>
					{/each}
				</tbody>
			</table>
		</div>
		<div class="em-pagination">
			<button disabled={posPage <= 1} on:click={() => goPos(posPage - 1)}>‹</button>
			<span>{$t('employeeMaster.page')} {posPage} / {posPages()}</span>
			<button disabled={posPage >= posPages()} on:click={() => goPos(posPage + 1)}>›</button>
		</div>
		{/if}
	</div>
	{/if}

	<!-- ============================================================ -->
	<!-- DOCUMENTS EXPIRY TAB -->
<!-- ============================================================ -->
	{#if activeTab === 'doc-expiry'}
	<div class="em-panel" style="overflow:auto; padding:0; gap:0;">
	<!-- Filters -->
	<div class="flex flex-wrap gap-3 p-4 bg-white border-b border-slate-200">
		<input type="text" bind:value={docSearchTerm} placeholder={$t('employeeMaster.docExpiry.searchPlaceholder')} class="border border-slate-300 rounded-lg px-3 py-2 text-sm flex-1 min-w-[160px] focus:outline-none focus:ring-2 focus:ring-violet-400" />
		<select bind:value={docSelectedBranch} class="border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
			<option value="">{$t('employeeMaster.docExpiry.allBranches')}</option>
			{#each docUniqueBranches as b}
				<option value={b.id}>{lang === 'ar' ? b.name_ar : b.name_en}</option>
			{/each}
		</select>
		<select bind:value={docSelectedNationality} class="border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
			<option value="">{$t('employeeMaster.docExpiry.allNationalities')}</option>
			{#each docUniqueNationalities as n}
				<option value={n.id}>{lang === 'ar' ? n.name_ar : n.name_en}</option>
			{/each}
		</select>
		<div class="relative">
			<button on:click={() => showColumnDropdown = !showColumnDropdown} class="border border-slate-300 rounded-lg px-3 py-2 text-sm bg-white hover:bg-slate-50 flex items-center gap-2">
				🔧 {$t('employeeMaster.docExpiry.columns')} <span class="text-xs text-slate-500">{Object.values(columnVisibility).filter(Boolean).length}/{COLUMN_LABELS_EXP.length}</span>
			</button>
			{#if showColumnDropdown}
			<div class="absolute top-10 right-0 bg-white border border-slate-200 rounded-xl shadow-xl z-50 p-3 min-w-[220px]">
				{#each COLUMN_LABELS_EXP as col}
				<label class="flex items-center gap-2 py-1 px-2 rounded hover:bg-slate-50 cursor-pointer text-sm">
					<input type="checkbox" bind:checked={columnVisibility[col.key]} class="rounded" />
					{col.label}
				</label>
				{/each}
			</div>
			{/if}
		</div>
		<span class="text-sm text-slate-500 self-center">{docSortedData.length} {$t('employeeMaster.docExpiry.employees')}</span>
		<button on:click={loadDocumentsExpiryData} class="border border-violet-300 text-violet-700 rounded-lg px-3 py-2 text-sm hover:bg-violet-50">↻ {$t('employeeMaster.docExpiry.refresh')}</button>
	</div>
	<!-- Table -->
	{#if docExpiryLoading}
		<div class="flex items-center justify-center p-16 text-slate-500">{$t('employeeMaster.docExpiry.loading')}</div>
	{:else}
	<div class="overflow-x-auto">
		<table class="em-table">
			<thead>
				<tr>
					{#if columnVisibility.id}<th>{$t('employeeMaster.docExpiry.colId')}</th>{/if}
					{#if columnVisibility.name}<th>{$t('employeeMaster.docExpiry.colName')}</th>{/if}
					{#if columnVisibility.nationality}<th>{$t('employeeMaster.docExpiry.colNationality')}</th>{/if}
					{#if columnVisibility.branch}<th>{$t('employeeMaster.docExpiry.colBranch')}</th>{/if}
					{#if columnVisibility.doc_id}<th style="text-align:center">{$t('employeeMaster.docExpiry.colIdExpiry')}</th>{/if}
					{#if columnVisibility.doc_health_card}<th style="text-align:center">{$t('employeeMaster.docExpiry.colHealthCard')}</th>{/if}
					{#if columnVisibility.doc_driving_licence}<th style="text-align:center">{$t('employeeMaster.docExpiry.colDrivingLicence')}</th>{/if}
					{#if columnVisibility.doc_contract}<th style="text-align:center">{$t('employeeMaster.docExpiry.colContract')}</th>{/if}
					{#if columnVisibility.doc_work_permit}<th style="text-align:center">{$t('employeeMaster.docExpiry.colWorkPermit')}</th>{/if}
					{#if columnVisibility.doc_insurance}<th style="text-align:center">{$t('employeeMaster.docExpiry.colInsurance')}</th>{/if}
					{#if columnVisibility.doc_health_educational}<th style="text-align:center">{$t('employeeMaster.docExpiry.colHealthEdu')}</th>{/if}
				</tr>
			</thead>
			<tbody>
				{#each docSortedData as emp}
				{@const docs = emp.documents}
				<tr>
					{#if columnVisibility.id}<td style="font-family:monospace;font-size:11px;color:#64748b">{emp.id}</td>{/if}
					{#if columnVisibility.name}<td style="font-weight:500">{lang === 'ar' ? emp.name_ar : emp.name_en}</td>{/if}
					{#if columnVisibility.nationality}<td>{lang === 'ar' ? emp.nationality_name_ar : emp.nationality_name_en}</td>{/if}
					{#if columnVisibility.branch}<td>{lang === 'ar' ? emp.branch_name_ar : emp.branch_name_en}</td>{/if}
					{#each [
						{ col: 'doc_id', type: 'id', key: 'id_expiry_date' },
						{ col: 'doc_health_card', type: 'health_card', key: 'health_card_expiry_date' },
						{ col: 'doc_driving_licence', type: 'driving_licence', key: 'driving_licence_expiry_date' },
						{ col: 'doc_contract', type: 'contract', key: 'contract_expiry_date' },
						{ col: 'doc_work_permit', type: 'work_permit', key: 'work_permit_expiry_date' },
						{ col: 'doc_insurance', type: 'insurance', key: 'insurance_expiry_date' },
						{ col: 'doc_health_educational', type: 'health_educational', key: 'health_educational_renewal_date' }
					] as d}
						{#if columnVisibility[d.col]}
						{@const doc = docs[d.type]}
						<td style="text-align:center">
							{#if doc}
								{@const days = doc.daysRemaining}
								<button
									on:click={() => openDocDateModal(emp.id, lang === 'ar' ? emp.name_ar : emp.name_en, doc.label, d.key, doc.expiryDate)}
									class="inline-flex flex-col items-center gap-0.5 rounded-lg px-2 py-1 text-xs font-medium transition-all hover:opacity-80 cursor-pointer border-0 {
										days === -999 ? 'bg-slate-100 text-slate-400' :
										days < 0 ? 'bg-red-100 text-red-700' :
										days <= 30 ? 'bg-orange-100 text-orange-700' :
										days <= 90 ? 'bg-yellow-100 text-yellow-700' :
										'bg-green-100 text-green-700'}"
								>
									{#if days === -999}
										<span>N/A</span>
									{:else}
										<span>{formatDate(doc.expiryDate)}</span>
										<span class="text-[10px]">{days < 0 ? `${Math.abs(days)}${$t('employeeMaster.docExpiry.daysAgo')}` : `${days}${$t('employeeMaster.docExpiry.daysLeft')}`}</span>
									{/if}
								</button>
							{:else}<span class="text-slate-300">—</span>{/if}
						</td>
						{/if}
					{/each}
				</tr>
				{/each}
				{#if docSortedData.length === 0}
				<tr><td colspan="15" class="text-center py-12 text-slate-400">{$t('employeeMaster.docExpiry.noEmployees')}</td></tr>
				{/if}
			</tbody>
		</table>
	</div>
	{/if}
	</div>
	{/if}
</div>

<!-- ============================================================ -->
<!-- MODAL -->
<!-- ============================================================ -->
{#if modal.open}
<div class="em-overlay" on:click|self={closeModal} role="dialog" aria-modal="true">
	<div class="em-modal" dir={isRTL ? 'rtl' : 'ltr'}>

		<!-- Modal Header -->
		<div class="em-modal-header">
			<h2 class="em-modal-title">
				{#if modal.type === 'dept'}
					{modal.isNew ? $t('employeeMaster.modal.newDept') : $t('employeeMaster.modal.editDept')}
				{:else if modal.type === 'level'}
					{modal.isNew ? $t('employeeMaster.modal.newLevel') : $t('employeeMaster.modal.editLevel')}
				{:else if modal.type === 'pos'}
					{modal.isNew ? $t('employeeMaster.modal.newPos') : $t('employeeMaster.modal.editPos')}
				{:else}
					{$t('employeeMaster.modal.editEmp')}
				{/if}
			</h2>
			<button class="em-modal-close" on:click={closeModal}>✕</button>
		</div>

		<!-- Modal Body -->
		<div class="em-modal-body">

			<!-- ── Department Form ── -->
			{#if modal.type === 'dept'}
			<div class="em-form-grid">
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameAr')} *</label>
					<input type="text" bind:value={modal.data.department_name_ar} placeholder={$t('employeeMaster.fields.nameArPlaceholder')} dir="rtl" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameEn')} *</label>
					<input type="text" bind:value={modal.data.department_name_en} placeholder={$t('employeeMaster.fields.nameEnPlaceholder')} />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.active')}</label>
					<label class="em-toggle">
						<input type="checkbox" bind:checked={modal.data.is_active} />
						<span class="em-toggle-slider"></span>
						<span class="em-toggle-label">{modal.data.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}</span>
					</label>
				</div>
			</div>
			{/if}

			<!-- ── Level Form ── -->
			{#if modal.type === 'level'}
			<div class="em-form-grid">
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameAr')} *</label>
					<input type="text" bind:value={modal.data.level_name_ar} placeholder={$t('employeeMaster.fields.nameArPlaceholder')} dir="rtl" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameEn')} *</label>
					<input type="text" bind:value={modal.data.level_name_en} placeholder={$t('employeeMaster.fields.nameEnPlaceholder')} />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.levelOrder')} *</label>
					<input type="number" bind:value={modal.data.level_order} min="1" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.active')}</label>
					<label class="em-toggle">
						<input type="checkbox" bind:checked={modal.data.is_active} />
						<span class="em-toggle-slider"></span>
						<span class="em-toggle-label">{modal.data.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}</span>
					</label>
				</div>
			</div>
			{/if}

			<!-- ── Position Form ── -->
			{#if modal.type === 'pos'}
			<div class="em-form-grid">
				<div class="em-field">
					<label>{$t('employeeMaster.fields.titleAr')} *</label>
					<input type="text" bind:value={modal.data.position_title_ar} placeholder={$t('employeeMaster.fields.titleArPlaceholder')} dir="rtl" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.titleEn')} *</label>
					<input type="text" bind:value={modal.data.position_title_en} placeholder={$t('employeeMaster.fields.titleEnPlaceholder')} />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.department')} *</label>
					<div class="em-ss" use:clickOutsideSS={'dept'}>
						<button type="button" class="em-ss-trigger" on:click={() => ssOpen('dept')}>
							<span class="em-ss-val">{(dropdowns.departments||[]).find(d=>d.id===modal.data.department_id) ? locName((dropdowns.departments||[]).find(d=>d.id===modal.data.department_id), 'name_en', 'name_ar') : $t('employeeMaster.selectDept')}</span>
							<span class="em-ss-arrow" class:open={ss.dept.open}>▾</span>
						</button>
						{#if ss.dept.open}
						<div class="em-ss-panel">
							<input class="em-ss-search" type="text" bind:value={ss.dept.q} placeholder="{$t('employeeMaster.searchPlaceholder')}" autofocus />
							<div class="em-ss-list">
								<button type="button" class="em-ss-opt" class:selected={!modal.data.department_id} on:click={() => { modal.data.department_id=''; ssSelect('dept'); }}>{$t('employeeMaster.selectDept')}</button>
								{#each ssFilter(dropdowns.departments||[], ss.dept.q, d=>locName(d,'name_en','name_ar')) as d (d.id)}
									<button type="button" class="em-ss-opt" class:selected={modal.data.department_id===d.id} on:click={() => { modal.data.department_id=d.id; ssSelect('dept'); }}>{locName(d,'name_en','name_ar')}</button>
								{/each}
							</div>
						</div>
						{/if}
					</div>
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.level')} *</label>
					<div class="em-ss" use:clickOutsideSS={'level'}>
						<button type="button" class="em-ss-trigger" on:click={() => ssOpen('level')}>
							<span class="em-ss-val">{(dropdowns.levels||[]).find(l=>l.id===modal.data.level_id) ? locName((dropdowns.levels||[]).find(l=>l.id===modal.data.level_id),'name_en','name_ar')+' (#'+((dropdowns.levels||[]).find(l=>l.id===modal.data.level_id)||{}).order+')' : $t('employeeMaster.selectLevel')}</span>
							<span class="em-ss-arrow" class:open={ss.level.open}>▾</span>
						</button>
						{#if ss.level.open}
						<div class="em-ss-panel">
							<input class="em-ss-search" type="text" bind:value={ss.level.q} placeholder="{$t('employeeMaster.searchPlaceholder')}" autofocus />
							<div class="em-ss-list">
								<button type="button" class="em-ss-opt" class:selected={!modal.data.level_id} on:click={() => { modal.data.level_id=''; ssSelect('level'); }}>{$t('employeeMaster.selectLevel')}</button>
								{#each ssFilter(dropdowns.levels||[], ss.level.q, l=>locName(l,'name_en','name_ar')) as l (l.id)}
									<button type="button" class="em-ss-opt" class:selected={modal.data.level_id===l.id} on:click={() => { modal.data.level_id=l.id; ssSelect('level'); }}>{locName(l,'name_en','name_ar')} (#{l.order})</button>
								{/each}
							</div>
						</div>
						{/if}
					</div>
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.active')}</label>
					<label class="em-toggle">
						<input type="checkbox" bind:checked={modal.data.is_active} />
						<span class="em-toggle-slider"></span>
						<span class="em-toggle-label">{modal.data.is_active ? $t('employeeMaster.active') : $t('employeeMaster.inactive')}</span>
					</label>
				</div>
			</div>
			{/if}

			<!-- ── Employee Form ── -->
			{#if modal.type === 'emp'}
			<div class="em-form-grid">
				<div class="em-field em-field-readonly">
					<label>{$t('employeeMaster.fields.empId')}</label>
					<input type="text" value={modal.data.id} readonly disabled />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameAr')}</label>
					<input type="text" bind:value={modal.data.name_ar} placeholder={$t('employeeMaster.fields.nameArPlaceholder')} dir="rtl" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.nameEn')}</label>
					<input type="text" bind:value={modal.data.name_en} placeholder={$t('employeeMaster.fields.nameEnPlaceholder')} />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.branch')}</label>
					<div class="em-ss" use:clickOutsideSS={'branch'}>
						<button type="button" class="em-ss-trigger" on:click={() => ssOpen('branch')}>
							<span class="em-ss-val">{(dropdowns.branches||[]).find(b=>b.id===modal.data.current_branch_id) ? locName((dropdowns.branches||[]).find(b=>b.id===modal.data.current_branch_id),'name_en','name_ar') : $t('employeeMaster.selectBranch')}</span>
							<span class="em-ss-arrow" class:open={ss.branch.open}>▾</span>
						</button>
						{#if ss.branch.open}
						<div class="em-ss-panel">
							<input class="em-ss-search" type="text" bind:value={ss.branch.q} placeholder="{$t('employeeMaster.searchPlaceholder')}" autofocus />
							<div class="em-ss-list">
								<button type="button" class="em-ss-opt" class:selected={!modal.data.current_branch_id} on:click={() => { modal.data.current_branch_id=null; ssSelect('branch'); }}>{$t('employeeMaster.selectBranch')}</button>
								{#each ssFilter(dropdowns.branches||[], ss.branch.q, b=>locName(b,'name_en','name_ar')) as b (b.id)}
									<button type="button" class="em-ss-opt" class:selected={modal.data.current_branch_id===b.id} on:click={() => { modal.data.current_branch_id=b.id; ssSelect('branch'); }}>{locName(b,'name_en','name_ar')}</button>
								{/each}
							</div>
						</div>
						{/if}
					</div>
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.position')}</label>
					<div class="em-ss" use:clickOutsideSS={'pos'}>
						<button type="button" class="em-ss-trigger" on:click={() => ssOpen('pos')}>
							<span class="em-ss-val">{(dropdowns.positions||[]).find(p=>p.id===modal.data.current_position_id) ? locName((dropdowns.positions||[]).find(p=>p.id===modal.data.current_position_id),'title_en','title_ar') : $t('employeeMaster.noPosition')}</span>
							<span class="em-ss-arrow" class:open={ss.pos.open}>▾</span>
						</button>
						{#if ss.pos.open}
						<div class="em-ss-panel">
							<input class="em-ss-search" type="text" bind:value={ss.pos.q} placeholder="{$t('employeeMaster.searchPlaceholder')}" autofocus />
							<div class="em-ss-list">
								<button type="button" class="em-ss-opt" class:selected={!modal.data.current_position_id} on:click={() => { modal.data.current_position_id=null; ssSelect('pos'); }}>{$t('employeeMaster.noPosition')}</button>
								{#each ssFilter(dropdowns.positions||[], ss.pos.q, p=>locName(p,'title_en','title_ar')) as p (p.id)}
									<button type="button" class="em-ss-opt" class:selected={modal.data.current_position_id===p.id} on:click={() => { modal.data.current_position_id=p.id; ssSelect('pos'); }}>{locName(p,'title_en','title_ar')}</button>
								{/each}
							</div>
						</div>
						{/if}
					</div>
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.status')}</label>
					<div class="em-ss" use:clickOutsideSS={'status'}>
						<button type="button" class="em-ss-trigger" on:click={() => ssOpen('status')}>
							<span class="em-ss-val" style="color:{modal.data.employment_status ? statusColor(modal.data.employment_status) : 'inherit'}">{modal.data.employment_status || '—'}</span>
							<span class="em-ss-arrow" class:open={ss.status.open}>▾</span>
						</button>
						{#if ss.status.open}
						<div class="em-ss-panel">
							<input class="em-ss-search" type="text" bind:value={ss.status.q} placeholder="{$t('employeeMaster.searchPlaceholder')}" autofocus />
							<div class="em-ss-list">
								{#each ssFilter(dropdowns.all_statuses||[], ss.status.q, s=>s) as s}
									<button type="button" class="em-ss-opt em-ss-opt-status" class:selected={modal.data.employment_status===s} style="--sbg:{statusBg(s)};--sfg:{statusColor(s)}" on:click={() => { modal.data.employment_status=s; ssSelect('status'); }}>{s}</button>
								{/each}
							</div>
						</div>
						{/if}
					</div>
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.whatsapp')}</label>
					<input type="text" bind:value={modal.data.whatsapp_number} placeholder="+966 5x xxx xxxx" />
				</div>
				<div class="em-field">
					<label>{$t('employeeMaster.fields.email')}</label>
					<input type="email" bind:value={modal.data.email} placeholder="email@domain.com" />
				</div>
			</div>
			{/if}

			<!-- Error -->
			{#if modal.error}
				<div class="em-modal-error">⚠️ {modal.error}</div>
			{/if}
		</div>

		<!-- Modal Footer -->
		<div class="em-modal-footer">
			<button class="em-btn-cancel" on:click={closeModal} disabled={modal.saving}>
				{$t('employeeMaster.modal.cancel')}
			</button>
			<button class="em-btn-save" disabled={modal.saving}
				on:click={() => {
					if (modal.type === 'dept') saveDept();
					else if (modal.type === 'level') saveLevel();
					else if (modal.type === 'pos') savePosition();
					else if (modal.type === 'emp') saveEmployee();
				}}
			>
				{#if modal.saving}
					<span class="em-spinner-sm"></span> {$t('employeeMaster.modal.saving')}
				{:else}
					✓ {$t('employeeMaster.modal.save')}
				{/if}
			</button>
		</div>
	</div>
</div>
{/if}

<!-- ============================================================ -->
<!-- DATE EDIT MODAL (Documents Expiry) -->
<!-- ============================================================ -->
{#if showDateModal}
<div class="em-overlay" on:click|self={closeDocDateModal} role="dialog" aria-modal="true">
	<div class="em-modal" style="max-width:440px;">
		<div class="em-modal-header">
			<h2 class="em-modal-title">{$t('employeeMaster.docExpiry.editTitle')}</h2>
			<button class="em-modal-close" on:click={closeDocDateModal}>✕</button>
		</div>
		<div class="em-modal-body">
			<p class="text-sm text-slate-500 mb-4"><strong>{modalEmpName}</strong> — {modalDocType}</p>
			<div class="em-field">
				<label>{$t('employeeMaster.docExpiry.currentDate')}</label>
				<input type="text" value={formatDate(modalCurDate)} readonly class="bg-slate-50 text-slate-500 cursor-not-allowed" />
			</div>
			<div class="em-field">
				<label>{$t('employeeMaster.docExpiry.newDate')} *</label>
				<input type="date" bind:value={modalNewDate} />
			</div>
		</div>
		<div class="em-modal-footer">
			<button class="em-btn-cancel" on:click={closeDocDateModal}>{$t('employeeMaster.docExpiry.cancel')}</button>
			<button class="em-btn-save" on:click={saveDocDateChange} disabled={isSavingDate}>
				{isSavingDate ? $t('employeeMaster.docExpiry.saving') : $t('employeeMaster.docExpiry.save')}
			</button>
		</div>
	</div>
</div>
{/if}

<!-- ============================================================ -->
<!-- STATUS CHANGE MODAL (Employee Status) -->
<!-- ============================================================ -->
{#if showStatusModal}
<div class="em-overlay" on:click|self={closeEmpStatusModal} role="dialog" aria-modal="true">
	<div class="em-modal" style="max-width:480px;">
		<div class="em-modal-header">
			<h2 class="em-modal-title">{$t('employeeMaster.empStatus.changeTitle')}</h2>
			<button class="em-modal-close" on:click={closeEmpStatusModal}>✕</button>
		</div>
		<div class="em-modal-body">
			<p class="text-sm text-slate-500 mb-4"><strong>{statusModalEmpName}</strong></p>
			<div class="em-field">
				<label>{$t('employeeMaster.empStatus.currentStatus')}</label>
				<input type="text" value={statusModalCurStatus} readonly class="bg-slate-50 text-slate-500 cursor-not-allowed" />
			</div>
			<div class="em-field">
				<label>{$t('employeeMaster.empStatus.newStatus')} *</label>
				<select bind:value={statusModalNewStatus}>
					<option value="">{$t('employeeMaster.empStatus.selectStatus')}</option>
					{#each ALL_EMP_STATUSES_LIST as s}
						<option value={s}>{s}</option>
					{/each}
				</select>
			</div>
			{#if docNeedsEffDate}
			<div class="em-field">
				<label>{$t('employeeMaster.empStatus.effectiveDate')} *</label>
				<input type="date" bind:value={statusModalEffDate} />
			</div>
			<div class="em-field">
				<label>{$t('employeeMaster.empStatus.reason')}</label>
				<input type="text" bind:value={statusModalReason} placeholder={$t('employeeMaster.empStatus.reasonPlaceholder')} />
			</div>
			{/if}
		</div>
		<div class="em-modal-footer">
			<button class="em-btn-cancel" on:click={closeEmpStatusModal}>{$t('employeeMaster.empStatus.cancel')}</button>
			<button class="em-btn-save" on:click={saveEmpStatusChange} disabled={statusModalSaving}>
				{statusModalSaving ? $t('employeeMaster.empStatus.saving') : $t('employeeMaster.empStatus.save')}
			</button>
		</div>
	</div>
</div>
{/if}

<style>
/* ── Root ── */
.em-root {
	display: flex;
	flex-direction: column;
	height: 100%;
	background: linear-gradient(135deg, #f5f3ff 0%, #faf5ff 50%, #fff7ed 100%);
	font-family: 'Segoe UI', system-ui, sans-serif;
	color: #1e293b;
	overflow: hidden;
}

/* ── Header ── */
.em-header {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 16px 20px 10px;
	background: rgba(255,255,255,0.8);
	backdrop-filter: blur(12px);
	border-bottom: 1px solid rgba(139,92,246,0.15);
}
.em-header-left { display: flex; align-items: center; gap: 12px; }
.em-header-icon { font-size: 28px; }
.em-title {
	margin: 0;
	font-size: 18px;
	font-weight: 700;
	background: linear-gradient(135deg, #7c3aed, #f97316);
	-webkit-background-clip: text;
	-webkit-text-fill-color: transparent;
}
.em-subtitle { margin: 0; font-size: 12px; color: #64748b; }

/* ── Tabs ── */
.em-tabs {
	display: flex;
	gap: 2px;
	padding: 10px 20px 0;
	background: rgba(255,255,255,0.6);
	backdrop-filter: blur(8px);
	border-bottom: 1px solid rgba(139,92,246,0.12);
}
.em-tab {
	display: flex; align-items: center; gap: 6px;
	padding: 8px 18px;
	border: none;
	border-radius: 8px 8px 0 0;
	font-size: 13px;
	font-weight: 500;
	cursor: pointer;
	transition: all 0.2s;
	opacity: 0.7;
}
/* Dashboard – red */
.em-tabs .em-tab:nth-child(1)       { background: #fca5a5; color: #7f1d1d; }
.em-tabs .em-tab:nth-child(1):hover { background: #f87171; color: #fff; opacity: 1; }
.em-tabs .em-tab:nth-child(1).active{ background: #dc2626; color: #fff; opacity: 1; box-shadow: 0 2px 8px rgba(220,38,38,0.35); border-bottom: 2px solid #991b1b; font-weight: 700; }
/* Departments – orange */
.em-tabs .em-tab:nth-child(2)       { background: #fdba74; color: #7c2d12; }
.em-tabs .em-tab:nth-child(2):hover { background: #fb923c; color: #fff; opacity: 1; }
.em-tabs .em-tab:nth-child(2).active{ background: #ea580c; color: #fff; opacity: 1; box-shadow: 0 2px 8px rgba(234,88,12,0.35); border-bottom: 2px solid #9a3412; font-weight: 700; }
/* Levels – green */
.em-tabs .em-tab:nth-child(3)       { background: #86efac; color: #14532d; }
.em-tabs .em-tab:nth-child(3):hover { background: #4ade80; color: #fff; opacity: 1; }
.em-tabs .em-tab:nth-child(3).active{ background: #16a34a; color: #fff; opacity: 1; box-shadow: 0 2px 8px rgba(22,163,74,0.35); border-bottom: 2px solid #14532d; font-weight: 700; }
/* Positions – lavender */
.em-tabs .em-tab:nth-child(4)       { background: #c4b5fd; color: #4c1d95; }
.em-tabs .em-tab:nth-child(4):hover { background: #a78bfa; color: #fff; opacity: 1; }
.em-tabs .em-tab:nth-child(4).active{ background: #7c3aed; color: #fff; opacity: 1; box-shadow: 0 2px 8px rgba(124,58,237,0.35); border-bottom: 2px solid #4c1d95; font-weight: 700; }
/* Documents Expiry – yellow / red text */
.em-tabs .em-tab:nth-child(5)       { background: #fef08a; color: #b91c1c; }
.em-tabs .em-tab:nth-child(5):hover { background: #fde047; color: #991b1b; opacity: 1; }
.em-tabs .em-tab:nth-child(5).active{ background: #facc15; color: #991b1b; opacity: 1; box-shadow: 0 2px 8px rgba(250,204,21,0.45); border-bottom: 2px solid #b45309; font-weight: 700; }

/* ── Panel ── */
.em-panel {
	flex: 1;
	display: flex;
	flex-direction: column;
	overflow: hidden;
	padding: 14px 20px;
	gap: 12px;
}

/* ── Controls ── */
.em-controls-wrap {
	display: flex;
	flex-direction: column;
	gap: 8px;
}
.em-controls {
	display: flex;
	align-items: center;
	gap: 8px;
	flex-wrap: wrap;
}
.em-status-toggles {
	display: flex;
	align-items: center;
	gap: 6px;
	flex-wrap: wrap;
	padding: 6px 0 2px;
}
.em-status-label {
	font-size: 11px;
	font-weight: 600;
	color: #64748b;
	text-transform: uppercase;
	letter-spacing: 0.05em;
	white-space: nowrap;
}
/* ── Searchable Select ── */
.em-ss {
	position: relative;
	width: 100%;
}
.em-ss-trigger {
	width: 100%;
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 8px;
	padding: 8px 12px;
	border: 1.5px solid rgba(139,92,246,0.25);
	border-radius: 8px;
	background: rgba(255,255,255,0.95);
	font-size: 13px;
	cursor: pointer;
	text-align: start;
	transition: border-color 0.18s;
}
.em-ss-trigger:hover { border-color: #7c3aed; }
.em-ss-val {
	flex: 1;
	overflow: hidden;
	text-overflow: ellipsis;
	white-space: nowrap;
	color: #334155;
}
.em-ss-arrow {
	color: #94a3b8;
	font-size: 11px;
	transition: transform 0.18s;
	flex-shrink: 0;
}
.em-ss-arrow.open { transform: rotate(180deg); color: #7c3aed; }
.em-ss-panel {
	position: absolute;
	z-index: 999;
	top: calc(100% + 4px);
	left: 0;
	right: 0;
	background: #fff;
	border: 1.5px solid rgba(124,58,237,0.3);
	border-radius: 10px;
	box-shadow: 0 8px 24px rgba(0,0,0,0.13);
	overflow: hidden;
}
.em-ss-search {
	width: 100%;
	padding: 9px 12px;
	border: none;
	border-bottom: 1px solid #e2e8f0;
	outline: none;
	font-size: 13px;
	background: #f8f9ff;
	box-sizing: border-box;
}
.em-ss-list {
	max-height: 200px;
	overflow-y: auto;
	padding: 4px 0;
}
.em-ss-opt {
	width: 100%;
	text-align: start;
	padding: 8px 14px;
	border: none;
	background: transparent;
	font-size: 13px;
	cursor: pointer;
	color: #334155;
	transition: background 0.12s;
	display: block;
}
.em-ss-opt:hover { background: #f1f0ff; }
.em-ss-opt.selected { background: #ede9fe; color: #7c3aed; font-weight: 600; }
.em-ss-opt-status {
	background: var(--sbg, #f1f5f9);
	color: #334155;
}
.em-ss-opt-status:hover { filter: brightness(0.96); }
.em-ss-opt-status.selected {
	outline: 2px solid #7c3aed;
	outline-offset: -2px;
	font-weight: 700;
}
.em-status-chk {
	display: inline-flex;
	align-items: center;
	gap: 6px;
	padding: 5px 11px 5px 8px;
	border-radius: 20px;
	border: 1.5px solid var(--sfg, #94a3b8);
	background: var(--sbg, #f1f5f9);
	font-size: 12px;
	font-weight: 500;
	cursor: pointer;
	transition: all 0.18s ease;
	white-space: nowrap;
	user-select: none;
}
.em-status-chk input[type="checkbox"] {
	display: none;
}
.em-status-chk:hover { filter: brightness(0.95); }
.em-status-chk.excluded {
	border-color: #cbd5e1;
	background: #f8fafc;
	opacity: 0.65;
}
.em-chk-dot {
	width: 10px;
	height: 10px;
	border-radius: 50%;
	border: 1.5px solid;
	flex-shrink: 0;
	transition: background 0.15s, border-color 0.15s;
}
.em-chk-name {
	transition: color 0.15s;
	font-size: 12px;
}
.em-search-wrap {
	position: relative;
	flex: 1;
	min-width: 180px;
	max-width: 320px;
}
.em-search-icon {
	position: absolute;
	left: 10px;
	top: 50%;
	transform: translateY(-50%);
	font-size: 14px;
	pointer-events: none;
}
[dir="rtl"] .em-search-icon { left: auto; right: 10px; }
.em-search {
	width: 100%;
	padding: 8px 10px 8px 34px;
	border: 1.5px solid rgba(139,92,246,0.25);
	border-radius: 8px;
	background: rgba(255,255,255,0.9);
	font-size: 13px;
	outline: none;
	transition: border-color 0.2s;
}
[dir="rtl"] .em-search { padding: 8px 34px 8px 10px; }
.em-search:focus { border-color: #7c3aed; }
.em-filter {
	padding: 8px 10px;
	border: 1.5px solid rgba(139,92,246,0.25);
	border-radius: 8px;
	background: rgba(255,255,255,0.9);
	font-size: 13px;
	outline: none;
	cursor: pointer;
	transition: border-color 0.2s;
}
.em-filter:focus { border-color: #7c3aed; }
.em-btn-add {
	padding: 8px 16px;
	background: linear-gradient(135deg, #7c3aed, #9333ea);
	color: white;
	border: none;
	border-radius: 8px;
	font-size: 13px;
	font-weight: 600;
	cursor: pointer;
	transition: opacity 0.2s;
}
.em-btn-add:hover { opacity: 0.9; }
.em-btn-clear {
	padding: 8px 12px;
	background: rgba(241,245,249,0.9);
	color: #64748b;
	border: 1.5px solid #e2e8f0;
	border-radius: 8px;
	font-size: 12px;
	cursor: pointer;
}
.em-btn-clear:hover { background: #f1f5f9; color: #334155; }
.em-count {
	margin-left: auto;
	font-size: 12px;
	color: #64748b;
	background: rgba(139,92,246,0.08);
	padding: 4px 10px;
	border-radius: 20px;
}
[dir="rtl"] .em-count { margin-left: 0; margin-right: auto; }

/* ── State Messages ── */
.em-state {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 10px;
	padding: 48px 20px;
	font-size: 15px;
	border-radius: 12px;
}
.em-loading { color: #7c3aed; background: rgba(139,92,246,0.05); }
.em-error { color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; }
.em-empty { color: #64748b; background: rgba(241,245,249,0.8); }

/* ── Spinner ── */
.em-spinner {
	width: 20px; height: 20px;
	border: 3px solid rgba(124,58,237,0.2);
	border-top-color: #7c3aed;
	border-radius: 50%;
	animation: em-spin 0.8s linear infinite;
}
.em-spinner-sm {
	display: inline-block;
	width: 14px; height: 14px;
	border: 2px solid rgba(255,255,255,0.4);
	border-top-color: white;
	border-radius: 50%;
	animation: em-spin 0.8s linear infinite;
	vertical-align: middle;
}
@keyframes em-spin { to { transform: rotate(360deg); } }

/* ── Table ── */
.em-table-wrap {
	flex: 1;
	overflow: auto;
	border-radius: 12px;
	background: rgba(255,255,255,0.85);
	backdrop-filter: blur(8px);
	border: 1px solid rgba(139,92,246,0.12);
	box-shadow: 0 4px 20px rgba(0,0,0,0.06);
}
.em-table {
	width: 100%;
	border-collapse: collapse;
	font-size: 13px;
}
.em-table thead th {
	padding: 11px 14px;
	text-align: start;
	font-size: 11px;
	font-weight: 700;
	text-transform: uppercase;
	letter-spacing: 0.05em;
	color: #5b21b6;
	background: #ede9fe;
	border-bottom: 2px solid #c4b5fd;
	white-space: nowrap;
	position: sticky;
	top: 0;
	z-index: 2;
}
.em-table tbody tr {
	border-bottom: 1px solid #e2e8f0;
	transition: background 0.15s;
	cursor: pointer;
}
.em-table tbody tr:nth-child(odd)  { background: #fff7ed; }
.em-table tbody tr:nth-child(even) { background: #f5f3ff; }
.em-table tbody tr:hover { background: #dcfce7; }
.em-table tbody td {
	padding: 10px 14px;
	color: #334155;
	vertical-align: middle;
}
.em-cell-name strong { display: block; font-weight: 600; }
.em-cell-empid {
	display: inline-block;
	font-size: 11px;
	color: #7c3aed;
	background: rgba(139,92,246,0.08);
	padding: 1px 5px;
	border-radius: 4px;
	margin-top: 2px;
}
.em-branch-name { display: block; font-weight: 500; }
.em-branch-loc { display: block; font-size: 11px; color: #94a3b8; margin-top: 1px; }
.em-cell-contact { font-size: 12px; }
.em-cell-contact span { display: block; }
.em-email { color: #64748b; }
.em-muted { color: #94a3b8; font-size: 12px; }
.em-order-badge span {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 28px; height: 28px;
	border-radius: 50%;
	background: linear-gradient(135deg, #7c3aed, #a855f7);
	color: white;
	font-size: 12px;
	font-weight: 700;
}

/* ── Badge ── */
.em-badge {
	display: inline-block;
	padding: 3px 10px;
	border-radius: 20px;
	font-size: 11px;
	font-weight: 600;
	white-space: nowrap;
}

/* ── Buttons ── */
.em-btn-edit {
	padding: 5px 12px;
	background: rgba(139,92,246,0.1);
	color: #7c3aed;
	border: 1px solid rgba(139,92,246,0.2);
	border-radius: 6px;
	font-size: 12px;
	cursor: pointer;
	transition: all 0.2s;
}
.em-btn-edit:hover { background: #7c3aed; color: white; }

/* ── Pagination ── */
.em-pagination {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 12px;
	padding: 8px 0;
	font-size: 13px;
	color: #475569;
}
.em-pagination button {
	width: 30px; height: 30px;
	border: 1.5px solid rgba(139,92,246,0.3);
	border-radius: 8px;
	background: white;
	color: #7c3aed;
	font-size: 16px;
	cursor: pointer;
	display: flex; align-items: center; justify-content: center;
	transition: all 0.2s;
}
.em-pagination button:disabled { opacity: 0.3; cursor: default; }
.em-pagination button:not(:disabled):hover { background: #7c3aed; color: white; }

/* ── Overlay ── */
.em-overlay {
	position: fixed;
	inset: 0;
	background: rgba(15,23,42,0.45);
	backdrop-filter: blur(4px);
	z-index: 9999;
	display: flex;
	align-items: center;
	justify-content: center;
	padding: 8px;
}

/* ── Modal ── */
.em-modal {
	background: white;
	border-radius: 16px;
	width: 100%;
	max-width: 1200px;
	height: 75vh;
	max-height: 75vh;
	display: flex;
	flex-direction: column;
	box-shadow: 0 25px 60px rgba(0,0,0,0.2);
	overflow: hidden;
}
.em-modal-header {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 18px 22px;
	background: linear-gradient(135deg, rgba(237,233,254,0.9), rgba(255,247,237,0.9));
	border-bottom: 1px solid rgba(139,92,246,0.15);
}
.em-modal-title {
	margin: 0;
	font-size: 16px;
	font-weight: 700;
	color: #1e293b;
}
.em-modal-close {
	width: 32px; height: 32px;
	border: none;
	border-radius: 8px;
	background: rgba(0,0,0,0.06);
	color: #64748b;
	font-size: 16px;
	cursor: pointer;
	display: flex; align-items: center; justify-content: center;
	transition: background 0.2s;
}
.em-modal-close:hover { background: #fee2e2; color: #dc2626; }
.em-modal-body {
	flex: 1;
	overflow-y: auto;
	padding: 20px 22px;
}
.em-modal-footer {
	display: flex;
	justify-content: flex-end;
	gap: 10px;
	padding: 14px 22px;
	border-top: 1px solid #f1f5f9;
	background: #fafafa;
}

/* ── Form ── */
.em-form-grid {
	display: grid;
	grid-template-columns: 1fr 1fr;
	gap: 14px;
}
.em-field {
	display: flex;
	flex-direction: column;
	gap: 5px;
}
.em-field label {
	font-size: 12px;
	font-weight: 600;
	color: #475569;
	text-transform: uppercase;
	letter-spacing: 0.04em;
}
.em-field input,
.em-field select {
	padding: 9px 12px;
	border: 1.5px solid #e2e8f0;
	border-radius: 8px;
	font-size: 13px;
	background: white;
	outline: none;
	transition: border-color 0.2s;
	color: #1e293b;
}
.em-field input:focus,
.em-field select:focus { border-color: #7c3aed; }
.em-field-readonly input {
	background: #f8fafc;
	color: #94a3b8;
	cursor: not-allowed;
}

/* ── Toggle ── */
.em-toggle {
	display: flex !important;
	flex-direction: row !important;
	align-items: center;
	gap: 10px;
	cursor: pointer;
}
.em-toggle input { display: none; }
.em-toggle-slider {
	width: 40px; height: 22px;
	background: #e2e8f0;
	border-radius: 11px;
	position: relative;
	transition: background 0.2s;
	flex-shrink: 0;
}
.em-toggle-slider::after {
	content: '';
	position: absolute;
	width: 16px; height: 16px;
	border-radius: 50%;
	background: white;
	top: 3px; left: 3px;
	transition: transform 0.2s;
	box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}
.em-toggle input:checked ~ .em-toggle-slider { background: #22c55e; }
.em-toggle input:checked ~ .em-toggle-slider::after { transform: translateX(18px); }
.em-toggle-label { font-size: 13px; color: #475569; }

/* ── Modal Error ── */
.em-modal-error {
	margin-top: 12px;
	padding: 10px 14px;
	background: #fef2f2;
	border: 1px solid #fecaca;
	border-radius: 8px;
	color: #dc2626;
	font-size: 13px;
}

/* ── Buttons ── */
.em-btn-cancel {
	padding: 9px 20px;
	background: white;
	color: #64748b;
	border: 1.5px solid #e2e8f0;
	border-radius: 8px;
	font-size: 13px;
	cursor: pointer;
	transition: all 0.2s;
}
.em-btn-cancel:hover:not(:disabled) { border-color: #94a3b8; color: #334155; }
.em-btn-save {
	padding: 9px 22px;
	background: linear-gradient(135deg, #7c3aed, #9333ea);
	color: white;
	border: none;
	border-radius: 8px;
	font-size: 13px;
	font-weight: 600;
	cursor: pointer;
	display: flex; align-items: center; gap: 6px;
	transition: opacity 0.2s;
}
.em-btn-save:hover:not(:disabled) { opacity: 0.9; }
.em-btn-save:disabled, .em-btn-cancel:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
