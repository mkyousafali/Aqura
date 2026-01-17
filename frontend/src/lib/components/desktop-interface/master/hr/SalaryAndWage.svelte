<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, _ as t } from '$lib/i18n';

	let employees: any[] = [];
	let filteredEmployees: any[] = [];
	let isLoading = false;
	let errorMessage = '';
	let searchQuery = '';
	let statusFilter = '';
	let branchFilter = '';
	let nationalityFilter = '';
	
	let availableBranches: any[] = [];
	let availableNationalities: any[] = [];
	let availableEmploymentStatuses: string[] = ['Job (With Finger)', 'Job (No Finger)', 'Remote Job', 'Vacation', 'Resigned', 'Terminated', 'Run Away'];

	let basicSalaryValues: { [key: string]: string } = {};
	let paymentModeValues: { [key: string]: string } = {};
	let otherAllowanceValues: { [key: string]: string } = {};
	let otherAllowancePaymentMode: { [key: string]: string } = {};
	let accommodationValues: { [key: string]: string } = {};
	let accommodationPaymentMode: { [key: string]: string } = {};
	let accommodationIsPercentage: { [key: string]: boolean } = {};
	let accommodationPercentage: { [key: string]: string } = {};
	let foodValues: { [key: string]: string } = {};
	let foodPaymentMode: { [key: string]: string } = {};
	let foodIsPercentage: { [key: string]: boolean } = {};
	let foodPercentage: { [key: string]: string } = {};
	let travelValues: { [key: string]: string } = {};
	let travelPaymentMode: { [key: string]: string } = {};
	let travelIsPercentage: { [key: string]: boolean } = {};
	let travelPercentage: { [key: string]: string } = {};
	let gosiValues: { [key: string]: string } = {};
	let gosiIsPercentage: { [key: string]: boolean } = {};
	let gosiPercentage: { [key: string]: string } = {};

	$: filteredEmployees = employees.filter(emp => {
		const matchesSearch = 
			!searchQuery || 
			emp.name_en?.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.name_ar?.includes(searchQuery) ||
			emp.id?.toLowerCase().includes(searchQuery.toLowerCase());
		
		const matchesStatus = !statusFilter || emp.employment_status === statusFilter;
		const matchesBranch = !branchFilter || String(emp.current_branch_id) === String(branchFilter);
		const matchesNationality = !nationalityFilter || String(emp.nationality_id) === String(nationalityFilter);
		
		return matchesSearch && matchesStatus && matchesBranch && matchesNationality;
	});

	// Modal state
	let showModal = false;
	let currentEmployeeId = '';
	let currentEmployee: any = null;
	let isSaving = false;

	onMount(async () => {
		await Promise.all([
			loadEmployees(),
			loadBasicSalaries(),
			loadFilterData()
		]);
	});

	async function loadFilterData() {
		try {
			const [branchesRes, nationalitiesRes] = await Promise.all([
				supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').order('name_en'),
				supabase.from('nationalities').select('id, name_en, name_ar').order('name_en')
			]);

			if (branchesRes.data) availableBranches = branchesRes.data;
			if (nationalitiesRes.data) availableNationalities = nationalitiesRes.data;
		} catch (error) {
			console.error('Error loading filter data:', error);
		}
	}

	async function loadEmployees() {
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					name_en,
					name_ar,
					nationality_id,
					employment_status,
					sponsorship_status,
					id_number,
					current_branch_id,
					bank_name,
					iban,
					nationalities (
						name_en,
						name_ar
					),
					branches:current_branch_id (
						name_en,
						name_ar,
						location_en,
						location_ar
					)
				`)
				.order('id');

			if (error) {
				console.error('Error loading employees:', error);
				errorMessage = $t('hr.salary.failedToLoadEmployees');
				return;
			}
			
			// Sort employees using the same logic as ShiftAndDayOff
			const employmentStatusOrder: { [key: string]: number } = {
				'Job (With Finger)': 1,
				'Job (No Finger)': 2,
				'Remote Job': 3,
				'Vacation': 4,
				'Resigned': 5,
				'Terminated': 6,
				'Run Away': 7
			};

			employees = (data || []).sort((a, b) => {
				// 1. Sort by employment status
				const statusOrderA = employmentStatusOrder[a.employment_status] || 99;
				const statusOrderB = employmentStatusOrder[b.employment_status] || 99;
				if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;

				// 2. Sort by nationality (Saudi Arabia first)
				const nationalityNameA = a.nationalities?.name_en || '';
				const nationalityNameB = b.nationalities?.name_en || '';
				const isSaudiA = nationalityNameA.toLowerCase().includes('saudi') ? 0 : 1;
				const isSaudiB = nationalityNameB.toLowerCase().includes('saudi') ? 0 : 1;
				if (isSaudiA !== isSaudiB) return isSaudiA - isSaudiB;

				// 3. Sort by sponsorship status
				const isSponsoredA = (a.sponsorship_status === true || a.sponsorship_status === 'true' || a.sponsorship_status === 'yes' || a.sponsorship_status === 'Yes' || a.sponsorship_status === '1') ? 0 : 1;
				const isSponsoredB = (b.sponsorship_status === true || b.sponsorship_status === 'true' || b.sponsorship_status === 'yes' || b.sponsorship_status === 'Yes' || b.sponsorship_status === '1') ? 0 : 1;
				if (isSponsoredA !== isSponsoredB) return isSponsoredA - isSponsoredB;

				// 4. Sort by numeric ID
				const numA = parseInt(a.id?.toString().replace(/\D/g, '') || '0') || 0;
				const numB = parseInt(b.id?.toString().replace(/\D/g, '') || '0') || 0;
				if (numA !== numB) return numA - numB;

				// 5. Alphabetical nationality fallback
				return nationalityNameA.localeCompare(nationalityNameB);
			});
		} catch (error) {
			console.error('Error loading employees:', error);
			errorMessage = $t('hr.salary.failedToLoadEmployees');
		} finally {
			isLoading = false;
		}
	}

	async function loadBasicSalaries() {
		try {
			const { data, error } = await supabase
				.from('hr_basic_salary')
				.select('employee_id, basic_salary, payment_mode, other_allowance, other_allowance_payment_mode, accommodation_allowance, accommodation_payment_mode, food_allowance, food_payment_mode, travel_allowance, travel_payment_mode, gosi_deduction');

			if (error) {
				console.error('Error loading basic salaries:', error);
				return;
			}

			// Map basic salaries and payment modes to employee IDs
			if (data) {
				data.forEach(item => {
					basicSalaryValues[item.employee_id] = item.basic_salary?.toString() || '';
					paymentModeValues[item.employee_id] = item.payment_mode || 'Bank';
					otherAllowanceValues[item.employee_id] = item.other_allowance?.toString() || '';
					otherAllowancePaymentMode[item.employee_id] = item.other_allowance_payment_mode || 'Bank';
					accommodationValues[item.employee_id] = item.accommodation_allowance?.toString() || '';
					accommodationPaymentMode[item.employee_id] = item.accommodation_payment_mode || 'Bank';
					foodValues[item.employee_id] = item.food_allowance?.toString() || '';
					foodPaymentMode[item.employee_id] = item.food_payment_mode || 'Bank';
					travelValues[item.employee_id] = item.travel_allowance?.toString() || '';
					travelPaymentMode[item.employee_id] = item.travel_payment_mode || 'Bank';
					gosiValues[item.employee_id] = item.gosi_deduction?.toString() || '';
				});
			}
		} catch (error) {
			console.error('Error loading basic salaries:', error);
		}
	}

	function openModal(employeeId: string) {
		currentEmployeeId = employeeId;
		currentEmployee = employees.find(emp => emp.id === employeeId);
		
		// Initialize values if not present
		if (!basicSalaryValues[employeeId]) basicSalaryValues[employeeId] = '';
		if (!paymentModeValues[employeeId]) paymentModeValues[employeeId] = 'Bank';
		if (!otherAllowanceValues[employeeId]) otherAllowanceValues[employeeId] = '';
		if (!otherAllowancePaymentMode[employeeId]) otherAllowancePaymentMode[employeeId] = 'Bank';
		if (!accommodationValues[employeeId]) accommodationValues[employeeId] = '';
		if (!accommodationPaymentMode[employeeId]) accommodationPaymentMode[employeeId] = 'Bank';
		if (accommodationIsPercentage[employeeId] === undefined) accommodationIsPercentage[employeeId] = false;
		if (!accommodationPercentage[employeeId]) accommodationPercentage[employeeId] = '';
		if (!foodValues[employeeId]) foodValues[employeeId] = '';
		if (!foodPaymentMode[employeeId]) foodPaymentMode[employeeId] = 'Bank';
		if (foodIsPercentage[employeeId] === undefined) foodIsPercentage[employeeId] = false;
		if (!foodPercentage[employeeId]) foodPercentage[employeeId] = '';
		if (!travelValues[employeeId]) travelValues[employeeId] = '';
		if (!travelPaymentMode[employeeId]) travelPaymentMode[employeeId] = 'Bank';
		if (travelIsPercentage[employeeId] === undefined) travelIsPercentage[employeeId] = false;
		if (!travelPercentage[employeeId]) travelPercentage[employeeId] = '';
		if (!gosiValues[employeeId]) gosiValues[employeeId] = '';
		if (gosiIsPercentage[employeeId] === undefined) gosiIsPercentage[employeeId] = true;
		if (!gosiPercentage[employeeId]) gosiPercentage[employeeId] = '';
		
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		currentEmployeeId = '';
		currentEmployee = null;
	}

	async function saveAllSalaryData() {
		const employeeId = currentEmployeeId;
		const basicSalary = basicSalaryValues[employeeId];
		
		// Allow zero but not empty or invalid values
		if (basicSalary === '' || basicSalary === null || basicSalary === undefined || isNaN(parseFloat(basicSalary))) {
			errorMessage = $t('hr.salary.invalidBasicSalary');
			return;
		}
		
		isSaving = true;
		errorMessage = '';
		
		try {
			// Calculate final values
			const basicVal = parseFloat(basicSalary);
			const otherVal = parseFloat(otherAllowanceValues[employeeId]) || 0;
			
			let accomVal = 0;
			if (accommodationIsPercentage[employeeId]) {
				const percentage = parseFloat(accommodationPercentage[employeeId]) || 0;
				accomVal = (basicVal * percentage) / 100;
			} else {
				accomVal = parseFloat(accommodationValues[employeeId]) || 0;
			}
			
			let foodVal = 0;
			if (foodIsPercentage[employeeId]) {
				const percentage = parseFloat(foodPercentage[employeeId]) || 0;
				foodVal = (basicVal * percentage) / 100;
			} else {
				foodVal = parseFloat(foodValues[employeeId]) || 0;
			}
			
			let travelVal = 0;
			if (travelIsPercentage[employeeId]) {
				const percentage = parseFloat(travelPercentage[employeeId]) || 0;
				travelVal = (basicVal * percentage) / 100;
			} else {
				travelVal = parseFloat(travelValues[employeeId]) || 0;
			}
			
			let gosiVal = 0;
			if (gosiIsPercentage[employeeId]) {
				const percentage = parseFloat(gosiPercentage[employeeId]) || 0;
				const baseForGosi = basicVal + accomVal;
				gosiVal = (baseForGosi * percentage) / 100;
			} else {
				gosiVal = parseFloat(gosiValues[employeeId]) || 0;
			}
			
			const totalSalary = basicVal + otherVal + accomVal + foodVal + travelVal - gosiVal;
			
			// Update state with calculated values
			accommodationValues[employeeId] = accomVal.toString();
			foodValues[employeeId] = foodVal.toString();
			travelValues[employeeId] = travelVal.toString();
			gosiValues[employeeId] = gosiVal.toString();
			
			const { error } = await supabase
				.from('hr_basic_salary')
				.upsert({
					employee_id: employeeId,
					basic_salary: basicVal,
					payment_mode: paymentModeValues[employeeId] || 'Bank',
					other_allowance: otherVal,
					other_allowance_payment_mode: otherAllowancePaymentMode[employeeId] || 'Bank',
					accommodation_allowance: accomVal,
					accommodation_payment_mode: accommodationPaymentMode[employeeId] || 'Bank',
					food_allowance: foodVal,
					food_payment_mode: foodPaymentMode[employeeId] || 'Bank',
					travel_allowance: travelVal,
					travel_payment_mode: travelPaymentMode[employeeId] || 'Bank',
					gosi_deduction: gosiVal,
					total_salary: totalSalary,
					updated_at: new Date().toISOString()
				}, {
					onConflict: 'employee_id'
				});
			
			if (error) {
				console.error('Error saving salary data:', error);
				errorMessage = $t('hr.salary.failedToSave');
			} else {
				closeModal();
			}
		} catch (error) {
			console.error('Error saving salary data:', error);
			errorMessage = $t('hr.salary.failedToSave');
		} finally {
			isSaving = false;
		}
	}

	function getTotalSalary(employeeId: string): number {
		const basicVal = parseFloat(basicSalaryValues[employeeId]) || 0;
		const otherVal = parseFloat(otherAllowanceValues[employeeId]) || 0;
		const accomVal = parseFloat(accommodationValues[employeeId]) || 0;
		const foodVal = parseFloat(foodValues[employeeId]) || 0;
		const travelVal = parseFloat(travelValues[employeeId]) || 0;
		const gosiVal = parseFloat(gosiValues[employeeId]) || 0;
		return basicVal + otherVal + accomVal + foodVal + travelVal - gosiVal;
	}

	function getModalTotalPreview(): number {
		if (!currentEmployeeId) return 0;
		
		const basicVal = parseFloat(basicSalaryValues[currentEmployeeId]) || 0;
		const otherVal = parseFloat(otherAllowanceValues[currentEmployeeId]) || 0;
		
		let accomVal = 0;
		if (accommodationIsPercentage[currentEmployeeId]) {
			const percentage = parseFloat(accommodationPercentage[currentEmployeeId]) || 0;
			accomVal = (basicVal * percentage) / 100;
		} else {
			accomVal = parseFloat(accommodationValues[currentEmployeeId]) || 0;
		}
		
		let foodVal = 0;
		if (foodIsPercentage[currentEmployeeId]) {
			const percentage = parseFloat(foodPercentage[currentEmployeeId]) || 0;
			foodVal = (basicVal * percentage) / 100;
		} else {
			foodVal = parseFloat(foodValues[currentEmployeeId]) || 0;
		}
		
		let travelVal = 0;
		if (travelIsPercentage[currentEmployeeId]) {
			const percentage = parseFloat(travelPercentage[currentEmployeeId]) || 0;
			travelVal = (basicVal * percentage) / 100;
		} else {
			travelVal = parseFloat(travelValues[currentEmployeeId]) || 0;
		}
		
		let gosiVal = 0;
		if (gosiIsPercentage[currentEmployeeId]) {
			const percentage = parseFloat(gosiPercentage[currentEmployeeId]) || 0;
			const baseForGosi = basicVal + accomVal;
			gosiVal = (baseForGosi * percentage) / 100;
		} else {
			gosiVal = parseFloat(gosiValues[currentEmployeeId]) || 0;
		}
		
		return basicVal + otherVal + accomVal + foodVal + travelVal - gosiVal;
	}

	function getEmploymentStatusText(status: string) {
		if (!status) return $t('employeeFiles.statuses.unknown');
		
		switch (status) {
			case 'Job (With Finger)': return $t('employeeFiles.statuses.jobWithFinger');
			case 'Job (No Finger)': return $t('employeeFiles.statuses.jobNoFinger');
			case 'Remote Job': return $t('employeeFiles.statuses.remoteJob');
			case 'Vacation': return $t('employeeFiles.statuses.vacation');
			case 'Resigned': return $t('employeeFiles.statuses.resigned');
			case 'Terminated': return $t('employeeFiles.statuses.terminated');
			case 'Run Away': return $t('employeeFiles.statuses.escape');
			default: return status;
		}
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'Job (With Finger)': return 'status-job-finger';
			case 'Job (No Finger)': return 'status-job-no-finger';
			case 'Remote Job': return 'status-remote';
			case 'Vacation': return 'status-vacation';
			case 'Resigned': return 'status-resigned';
			case 'Terminated': return 'status-terminated';
			case 'Run Away': return 'status-escape';
			default: return 'status-unknown';
		}
	}

	function getNationalityColor(id: string) {
		switch (id?.toUpperCase()) {
			case 'SA': return 'nat-sa';
			case 'IND': return 'nat-ind';
			case 'BAN': return 'nat-ban';
			case 'YEM': return 'nat-yem';
			case 'EGY': return 'nat-egy';
			case 'PAK': return 'nat-pak';
			case 'PHI': return 'nat-phi';
			case 'SUD': return 'nat-sud';
			default: return 'nat-default';
		}
	}

	function getSponsorshipStatusDisplay(status: any) {
		const isSponsored = status === true || status === 'true' || status === 'yes' || status === 'Yes' || status === '1';
		if (isSponsored) {
			return { color: 'bg-green-100 text-green-700', text: $t('common.yes') || 'Yes' };
		} else {
			return { color: 'bg-red-100 text-red-700', text: $t('common.no') || 'No' };
		}
	}
</script>

<div class="salary-wage-container">
	<div class="header">
		<h2>{$t('hr.salary.title')}</h2>
		<button class="refresh-btn" on:click={() => { loadEmployees(); loadBasicSalaries(); }} disabled={isLoading}>
			{isLoading ? $t('common.loading') : `🔄 ${$t('hr.salary.refresh')}`}
		</button>
	</div>

	{#if errorMessage}
		<div class="error-message">{errorMessage}</div>
	{/if}

	{#if isLoading}
		<div class="loading">{$t('common.loading')}</div>
	{:else}
		<!-- Filter Controls -->
		<div class="mb-4 flex gap-3">
			<!-- Branch Filter -->
			<div class="flex-1">
				<label for="branch-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.filter_branch')}</label>
				<select 
					id="branch-filter"
					bind:value={branchFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
					style="color: #000000 !important; background-color: #ffffff !important;"
				>
					<option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
					{#each availableBranches as branch}
						<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
							{$currentLocale === 'ar' 
								? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
								: `${branch.name_en || branch.branch_name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
						</option>
					{/each}
				</select>
			</div>

			<!-- Nationality Filter -->
			<div class="flex-1">
				<label for="nationality-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.filter_nationality')}</label>
				<select 
					id="nationality-filter"
					bind:value={nationalityFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
					style="color: #000000 !important; background-color: #ffffff !important;"
				>
					<option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
					{#each availableNationalities as nationality}
						<option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
							{$currentLocale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
						</option>
					{/each}
				</select>
			</div>

			<!-- Employment Status Filter -->
			<div class="flex-1">
				<label for="status-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeFiles.employmentStatus')}</label>
				<select 
					id="status-filter"
					bind:value={statusFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
					style="color: #000000 !important; background-color: #ffffff !important;"
				>
					<option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
					{#each availableEmploymentStatuses as status}
						<option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusText(status)}</option>
					{/each}
				</select>
			</div>

			<!-- Employee Search -->
			<div class="flex-1">
				<label for="employee-search" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.search_employee')}</label>
				<input 
					id="employee-search"
					type="text"
					bind:value={searchQuery}
					placeholder={$t('hr.shift.search_placeholder')}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
				/>
			</div>
		</div>

		<div class="table-container bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
			<div class="overflow-x-auto flex-1">
				<table class="w-full border-collapse">
					<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.id')}</th>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.name')}</th>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.branch')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('employeeFiles.employmentStatus')}</th>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.nationality')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.sponsorship')}</th>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.idNumber')}</th>
							<th class="px-4 py-3 {$currentLocale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.bankInfo')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.basicSalary')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.otherAllowance')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.accommodation')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.foodAllowance')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.travel')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.gosiDeduction')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.totalSalary')}</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.salary.actions')}</th>
						</tr>
					</thead>
				<tbody class="divide-y divide-slate-200">
					{#each filteredEmployees as employee, index}
						<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
							<td class="px-4 py-3 text-sm font-semibold text-slate-800">{employee.id}</td>
							<td class="px-4 py-3 text-sm text-slate-700">
								<div class="name-cell">
									{#if $currentLocale === 'ar'}
										<div class="name-ar font-semibold">{employee.name_ar || '-'}</div>
									{:else}
										<div class="name-en font-semibold">{employee.name_en || '-'}</div>
									{/if}
								</div>
							</td>
							<td class="px-4 py-3 text-sm text-slate-700">
								<div class="name-cell">
									{#if employee.branches}
										{#if $currentLocale === 'ar'}
											<div class="name-ar">
												{employee.branches.name_ar || '-'}
												{#if employee.branches.location_ar}
													<span class="location text-xs text-slate-500">({employee.branches.location_ar})</span>
												{/if}
											</div>
										{:else}
											<div class="name-en">
												{employee.branches.name_en || '-'}
												{#if employee.branches.location_en}
													<span class="location text-xs text-slate-500">({employee.branches.location_en})</span>
												{/if}
											</div>
										{/if}
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</div>
							</td>
							<td class="px-4 py-3 text-sm text-center">
								<span class="inline-flex items-center px-2 py-1 rounded text-xs font-semibold {getStatusColor(employee.employment_status || 'unknown')}">
									{getEmploymentStatusText(employee.employment_status)}
								</span>
							</td>
							<td class="px-4 py-3 text-sm text-slate-700">
								<div class="flex justify-start">
									{#if employee.nationality_id}
										<span class="inline-flex items-center px-2.5 py-1 rounded text-xs font-bold {getNationalityColor(employee.nationality_id)}">
											{$currentLocale === 'ar' ? (employee.nationalities?.name_ar || '-') : (employee.nationalities?.name_en || '-')}
										</span>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</div>
							</td>
							<td class="px-4 py-3 text-sm text-center">
								{#if employee.sponsorship_status !== null && employee.sponsorship_status !== undefined}
									{@const sponsorship = getSponsorshipStatusDisplay(employee.sponsorship_status)}
									<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {sponsorship.color}">
										{sponsorship.text}
									</span>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-slate-700">{employee.id_number || '-'}</td>
							<td class="px-4 py-3 text-sm text-slate-700">
								<div class="name-cell">
									<div class="text-xs font-semibold">{employee.bank_name || '-'}</div>
									<div class="text-[10px] text-slate-500 font-mono">{employee.iban || '-'}</div>
								</div>
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if basicSalaryValues[employee.id]}
									<div class="flex flex-col items-center">
										<span class="font-bold text-slate-800">{parseFloat(basicSalaryValues[employee.id]).toLocaleString()}</span>
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">{paymentModeValues[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if otherAllowanceValues[employee.id] && parseFloat(otherAllowanceValues[employee.id]) > 0}
									<div class="flex flex-col items-center">
										<span class="font-bold text-slate-800">{parseFloat(otherAllowanceValues[employee.id]).toLocaleString()}</span>
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">{otherAllowancePaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if accommodationValues[employee.id] && parseFloat(accommodationValues[employee.id]) > 0}
									<div class="flex flex-col items-center">
										<span class="font-bold text-slate-800">{parseFloat(accommodationValues[employee.id]).toLocaleString()}</span>
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">{accommodationPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if foodValues[employee.id] && parseFloat(foodValues[employee.id]) > 0}
									<div class="flex flex-col items-center">
										<span class="font-bold text-slate-800">{parseFloat(foodValues[employee.id]).toLocaleString()}</span>
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">{foodPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if travelValues[employee.id] && parseFloat(travelValues[employee.id]) > 0}
									<div class="flex flex-col items-center">
										<span class="font-bold text-slate-800">{parseFloat(travelValues[employee.id]).toLocaleString()}</span>
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">{travelPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if gosiValues[employee.id] && parseFloat(gosiValues[employee.id]) > 0}
									<span class="font-bold text-red-600">-{parseFloat(gosiValues[employee.id]).toLocaleString()}</span>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center font-mono">
								{#if getTotalSalary(employee.id) > 0}
									{@const total = getTotalSalary(employee.id)}
									<span class="font-black text-emerald-700 text-base">{total.toLocaleString()}</span>
								{:else}
									<span class="text-slate-400">-</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-sm text-center">
								{#if basicSalaryValues[employee.id]}
									<button 
										class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200"
										on:click={() => openModal(employee.id)}
									>
										✏️ {$t('hr.salary.edit')}
									</button>
								{:else}
									<button 
										class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-600 text-white font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200"
										on:click={() => openModal(employee.id)}
									>
										+
									</button>
								{/if}
							</td>
						</tr>
					{/each}
					{#if filteredEmployees.length === 0}
						<tr>
							<td colspan="11" class="px-4 py-12 text-center text-slate-500 italic">{$t('hr.salary.noEmployeesFound')}</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
		
		<!-- Footer with row count -->
		<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold rounded-b-[2.5rem]">
			{$t('hr.shift.showing_employees', { count: filteredEmployees.length })}
		</div>
	</div>
{/if}
</div>

<!-- Modal -->
{#if showModal && currentEmployee}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{$t('hr.salary.editSalaryFor')} { $currentLocale === 'ar' ? currentEmployee.name_ar : currentEmployee.name_en }</h3>
				<button class="close-btn" on:click={closeModal}>&times;</button>
			</div>
			
			<div class="modal-body">
				{#if errorMessage}
					<div class="error-message">{errorMessage}</div>
				{/if}

				<!-- Basic Salary -->
				<div class="form-group">
					<label>{$t('hr.salary.basicSalary')} *</label>
					<div class="input-row">
						<input 
							type="number" 
							bind:value={basicSalaryValues[currentEmployeeId]}
							placeholder={$t('hr.salary.basicSalary')}
							class="form-input"
						/>
						<select bind:value={paymentModeValues[currentEmployeeId]} class="form-select">
							<option value="Bank">{$t('hr.salary.bank')}</option>
							<option value="Cash">{$t('hr.salary.cash')}</option>
						</select>
					</div>
				</div>

				<!-- Other Allowance -->
				<div class="form-group">
					<label>{$t('hr.salary.otherAllowance')}</label>
					<div class="input-row">
						<input 
							type="number" 
							bind:value={otherAllowanceValues[currentEmployeeId]}
							placeholder={$t('hr.salary.otherAllowance')}
							class="form-input"
						/>
						<select bind:value={otherAllowancePaymentMode[currentEmployeeId]} class="form-select">
							<option value="Bank">{$t('hr.salary.bank')}</option>
							<option value="Cash">{$t('hr.salary.cash')}</option>
						</select>
					</div>
				</div>

				<!-- Accommodation Allowance -->
				<div class="form-group">
					<label>
						{$t('hr.salary.accommodation')}
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								bind:checked={accommodationIsPercentage[currentEmployeeId]}
							/>
							<span>{$t('hr.salary.usePercentageOfBasic')}</span>
						</label>
					</label>
					<div class="input-row">
						{#if accommodationIsPercentage[currentEmployeeId]}
							<div class="percentage-input-wrapper">
								<input 
									type="number" 
									bind:value={accommodationPercentage[currentEmployeeId]}
									placeholder="%"
									class="form-input percentage-input"
									min="0"
									max="100"
								/>
								<span class="percentage-symbol">%</span>
								{#if accommodationPercentage[currentEmployeeId] && basicSalaryValues[currentEmployeeId]}
									{@const calculated = (parseFloat(basicSalaryValues[currentEmployeeId]) * parseFloat(accommodationPercentage[currentEmployeeId])) / 100}
									<span class="calculated-preview">= {calculated.toLocaleString()} {$t('common.sar')}</span>
								{/if}
							</div>
						{:else}
							<input 
								type="number" 
								bind:value={accommodationValues[currentEmployeeId]}
								placeholder={$t('hr.salary.accommodation')}
								class="form-input"
							/>
						{/if}
						<select bind:value={accommodationPaymentMode[currentEmployeeId]} class="form-select">
							<option value="Bank">{$t('hr.salary.bank')}</option>
							<option value="Cash">{$t('hr.salary.cash')}</option>
						</select>
					</div>
				</div>

				<!-- Food Allowance -->
				<div class="form-group">
					<label>
						{$t('hr.salary.foodAllowance')}
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								bind:checked={foodIsPercentage[currentEmployeeId]}
							/>
							<span>{$t('hr.salary.usePercentageOfBasic')}</span>
						</label>
					</label>
					<div class="input-row">
						{#if foodIsPercentage[currentEmployeeId]}
							<div class="percentage-input-wrapper">
								<input 
									type="number" 
									bind:value={foodPercentage[currentEmployeeId]}
									placeholder="%"
									class="form-input percentage-input"
									min="0"
									max="100"
								/>
								<span class="percentage-symbol">%</span>
								{#if foodPercentage[currentEmployeeId] && basicSalaryValues[currentEmployeeId]}
									{@const calculated = (parseFloat(basicSalaryValues[currentEmployeeId]) * parseFloat(foodPercentage[currentEmployeeId])) / 100}
									<span class="calculated-preview">= {calculated.toLocaleString()} {$t('common.sar')}</span>
								{/if}
							</div>
						{:else}
							<input 
								type="number" 
								bind:value={foodValues[currentEmployeeId]}
								placeholder={$t('hr.salary.foodAllowance')}
								class="form-input"
							/>
						{/if}
						<select bind:value={foodPaymentMode[currentEmployeeId]} class="form-select">
							<option value="Bank">{$t('hr.salary.bank')}</option>
							<option value="Cash">{$t('hr.salary.cash')}</option>
						</select>
					</div>
				</div>

				<!-- Travel Allowance -->
				<div class="form-group">
					<label>
						{$t('hr.salary.travel')}
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								bind:checked={travelIsPercentage[currentEmployeeId]}
							/>
							<span>{$t('hr.salary.usePercentageOfBasic')}</span>
						</label>
					</label>
					<div class="input-row">
						{#if travelIsPercentage[currentEmployeeId]}
							<div class="percentage-input-wrapper">
								<input 
									type="number" 
									bind:value={travelPercentage[currentEmployeeId]}
									placeholder="%"
									class="form-input percentage-input"
									min="0"
									max="100"
								/>
								<span class="percentage-symbol">%</span>
								{#if travelPercentage[currentEmployeeId] && basicSalaryValues[currentEmployeeId]}
									{@const calculated = (parseFloat(basicSalaryValues[currentEmployeeId]) * parseFloat(travelPercentage[currentEmployeeId])) / 100}
									<span class="calculated-preview">= {calculated.toLocaleString()} {$t('common.sar')}</span>
								{/if}
							</div>
						{:else}
							<input 
								type="number" 
								bind:value={travelValues[currentEmployeeId]}
								placeholder={$t('hr.salary.travel')}
								class="form-input"
							/>
						{/if}
						<select bind:value={travelPaymentMode[currentEmployeeId]} class="form-select">
							<option value="Bank">{$t('hr.salary.bank')}</option>
							<option value="Cash">{$t('hr.salary.cash')}</option>
						</select>
					</div>
				</div>

				<!-- GOSI Deduction -->
				<div class="form-group">
					<label>
						{$t('hr.salary.gosiDeduction')}
						<label class="checkbox-label">
							<input 
								type="checkbox" 
								bind:checked={gosiIsPercentage[currentEmployeeId]}
							/>
							<span>{$t('hr.salary.usePercentageOfBasicAndAccom')}</span>
						</label>
					</label>
					<div class="input-row">
						{#if gosiIsPercentage[currentEmployeeId]}
							<div class="percentage-input-wrapper">
								<input 
									type="number" 
									bind:value={gosiPercentage[currentEmployeeId]}
									placeholder="%"
									class="form-input percentage-input"
									min="0"
									max="100"
								/>
								<span class="percentage-symbol">%</span>
								{#if gosiPercentage[currentEmployeeId] && basicSalaryValues[currentEmployeeId]}
									{@const basicVal = parseFloat(basicSalaryValues[currentEmployeeId]) || 0}
									{@const accomVal = accommodationIsPercentage[currentEmployeeId] ? (basicVal * (parseFloat(accommodationPercentage[currentEmployeeId]) || 0)) / 100 : parseFloat(accommodationValues[currentEmployeeId]) || 0}
									{@const baseForGosi = basicVal + accomVal}
									{@const calculated = (baseForGosi * parseFloat(gosiPercentage[currentEmployeeId])) / 100}
									<span class="calculated-preview deduction">= {calculated.toLocaleString()} {$t('common.sar')}</span>
								{/if}
							</div>
						{:else}
							<input 
								type="number" 
								bind:value={gosiValues[currentEmployeeId]}
								placeholder={$t('hr.salary.gosiDeduction')}
								class="form-input"
							/>
						{/if}
					</div>
				</div>

				<!-- Total Preview -->
				<div class="total-preview">
					<span class="total-label">{$t('hr.salary.totalSalary')}:</span>
					<span class="total-value">{getModalTotalPreview().toLocaleString()} {$t('common.sar')}</span>
				</div>
			</div>

			<div class="modal-footer">
				<button class="cancel-modal-btn" on:click={closeModal} disabled={isSaving}>
					{$t('hr.salary.cancel')}
				</button>
				<button class="save-modal-btn" on:click={saveAllSalaryData} disabled={isSaving}>
					{isSaving ? $t('hr.salary.saving') : $t('hr.salary.saveAll')}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.salary-wage-container {
		padding: 1.5rem;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f5f5f5;
	}

	.header {
		margin-bottom: 1.5rem;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 2rem;
	}

	.search-filters {
		display: flex;
		gap: 1rem;
		align-items: center;
	}

	.filter-input {
		padding: 0.5rem 1rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
		width: 250px;
	}

	.filter-select {
		padding: 0.5rem 1rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
		background-color: white !important;
		color: #333 !important;
	}

	h2 {
		margin: 0;
		font-size: 1.5rem;
		color: #333;
	}

	.refresh-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 4px;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
		background: #17a2b8;
		color: white;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #138496;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.error-message {
		background: #fee;
		color: #c33;
		padding: 1rem;
		border-radius: 4px;
		margin-bottom: 1rem;
	}

	.loading {
		text-align: center;
		padding: 2rem;
		color: #666;
	}

	.status-chip {
		display: inline-block;
		padding: 0.25rem 0.6rem;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 600;
		text-align: center;
		white-space: nowrap;
	}

	.status-job-finger { background-color: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
	.status-job-no-finger { background-color: #f0f9ff; color: #0284c7; border: 1px solid #bae6fd; }
	.status-remote { background-color: #f5f3ff; color: #7c3aed; border: 1px solid #ddd6fe; }
	.status-vacation { background-color: #f0fdf4; color: #16a34a; border: 1px solid #bbf7d0; }
	.status-resigned { background-color: #fffaf5; color: #d97706; border: 1px solid #fed7aa; }
	.status-terminated { background-color: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
	.status-escape { background-color: #fff1f2; color: #e11d48; border: 1px solid #fecdd3; }
	.status-unknown { background-color: #f8fafc; color: #64748b; border: 1px solid #e2e8f0; }

	/* Nationality Badges */
	.nat-sa { background-color: #f0fdf4; color: #166534; border: 1px solid #bbf7d0; }
	.nat-ind { background-color: #ecfeff; color: #0891b2; border: 1px solid #cffafe; }
	.nat-ban { background-color: #fffbeb; color: #d97706; border: 1px solid #fef3c7; }
	.nat-yem { background-color: #fff1f2; color: #e11d48; border: 1px solid #ffe4e6; }
	.nat-egy { background-color: #f5f3ff; color: #6d28d9; border: 1px solid #ede9fe; }
	.nat-pak { background-color: #f0f9ff; color: #0369a1; border: 1px solid #e0f2fe; }
	.nat-phi { background-color: #fdf2f8; color: #be185d; border: 1px solid #fce7f3; }
	.nat-sud { background-color: #fafaf9; color: #44403c; border: 1px solid #f5f5f4; }
	.nat-default { background-color: #f8fafc; color: #475569; border: 1px solid #e2e8f0; }

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
	}

	.modal-content {
		background: white;
		border-radius: 8px;
		width: 90%;
		max-width: 600px;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
	}

	.modal-header {
		padding: 1.5rem;
		border-bottom: 1px solid #dee2e6;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1.25rem;
		color: #333;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		color: #6c757d;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		color: #333;
	}

	.modal-body {
		padding: 1.5rem;
		overflow-y: auto;
		flex: 1;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.5rem;
		font-weight: 600;
		color: #495057;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 400;
		font-size: 0.875rem;
		cursor: pointer;
	}

	.checkbox-label input[type="checkbox"] {
		cursor: pointer;
	}

	.input-row {
		display: flex;
		gap: 0.75rem;
		align-items: flex-start;
	}

	.form-input {
		flex: 1;
		padding: 0.75rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
	}

	.form-input:focus {
		outline: none;
		border-color: #80bdff;
		box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
	}

	.form-select {
		padding: 0.75rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
		min-width: 100px;
	}

	.form-select:focus {
		outline: none;
		border-color: #80bdff;
		box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
	}

	.percentage-input-wrapper {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.percentage-input {
		width: 100px !important;
		flex: none;
	}

	.percentage-symbol {
		font-weight: 600;
		color: #495057;
	}

	.calculated-preview {
		font-size: 0.875rem;
		color: #28a745;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		background: #e7f9e7;
		border-radius: 4px;
	}

	.calculated-preview.deduction {
		color: #dc3545;
		background: #ffe7e7;
	}

	.total-preview {
		margin-top: 2rem;
		padding: 1rem;
		background: #f0f8ff;
		border: 2px solid #0056b3;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.total-label {
		font-weight: 600;
		color: #495057;
		font-size: 1rem;
	}

	.total-value {
		font-weight: 700;
		color: #0056b3;
		font-size: 1.25rem;
	}

	.modal-footer {
		padding: 1rem 1.5rem;
		border-top: 1px solid #dee2e6;
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
	}

	.cancel-modal-btn, .save-modal-btn {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 4px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.cancel-modal-btn {
		background: #6c757d;
		color: white;
	}

	.cancel-modal-btn:hover:not(:disabled) {
		background: #5a6268;
	}

	.save-modal-btn {
		background: #28a745;
		color: white;
	}

	.save-modal-btn:hover:not(:disabled) {
		background: #218838;
	}

	.cancel-modal-btn:disabled, .save-modal-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
