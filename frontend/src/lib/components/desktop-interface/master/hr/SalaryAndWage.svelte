<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, _ as t } from '$lib/i18n';

	let employees: any[] = [];
	let isLoading = false;
	let errorMessage = '';
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

	// Modal state
	let showModal = false;
	let currentEmployeeId = '';
	let currentEmployee: any = null;
	let isSaving = false;

	onMount(async () => {
		await loadEmployees();
		await loadBasicSalaries();
	});

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
			
			// Sort numerically by extracting the number from the ID
			employees = (data || []).sort((a, b) => {
				const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
				const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
				return numA - numB;
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
		<div class="table-container">
			<table>
				<thead>
					<tr>
						<th>{$t('hr.salary.id')}</th>
						<th>{$t('hr.salary.name')}</th>
						<th>{$t('hr.salary.branch')}</th>
						<th>{$t('hr.salary.nationality')}</th>
						<th>{$t('hr.salary.sponsorship')}</th>
						<th>{$t('hr.salary.idNumber')}</th>
						<th>{$t('hr.salary.bankInfo')}</th>
						<th>{$t('hr.salary.basicSalary')}</th>
						<th>{$t('hr.salary.otherAllowance')}</th>
						<th>{$t('hr.salary.accommodation')}</th>
						<th>{$t('hr.salary.foodAllowance')}</th>
						<th>{$t('hr.salary.travel')}</th>
						<th>{$t('hr.salary.gosiDeduction')}</th>
						<th>{$t('hr.salary.totalSalary')}</th>
						<th>{$t('hr.salary.actions')}</th>
					</tr>
				</thead>
				<tbody>
					{#each employees as employee}
						<tr>
							<td>{employee.id}</td>
							<td>
								<div class="name-cell">
									{#if $currentLocale === 'ar'}
										<div class="name-ar">{employee.name_ar || '-'}</div>
									{:else}
										<div class="name-en">{employee.name_en || '-'}</div>
									{/if}
								</div>
							</td>
							<td>
								<div class="name-cell">
									{#if employee.branches}
										{#if $currentLocale === 'ar'}
											<div class="name-ar">
												{employee.branches.name_ar || '-'}
												{#if employee.branches.location_ar}
													<span class="location">({employee.branches.location_ar})</span>
												{/if}
											</div>
										{:else}
											<div class="name-en">
												{employee.branches.name_en || '-'}
												{#if employee.branches.location_en}
													<span class="location">({employee.branches.location_en})</span>
												{/if}
											</div>
										{/if}
									{:else}
										-
									{/if}
								</div>
							</td>
							<td>
								<div class="name-cell">
									{#if $currentLocale === 'ar'}
										<div class="name-ar">{employee.nationalities?.name_ar || '-'}</div>
									{:else}
										<div class="name-en">{employee.nationalities?.name_en || '-'}</div>
									{/if}
								</div>
							</td>
							<td>
								{#if employee.sponsorship_status !== null && employee.sponsorship_status !== undefined}
									<span class="status-badge {employee.sponsorship_status ? 'active' : 'inactive'}">
										{employee.sponsorship_status ? $t('hr.salary.active') : $t('hr.salary.inactive')}
									</span>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>{employee.id_number || '-'}</td>
							<td>
								<div class="name-cell">
									<div class="name-ar">{employee.bank_name || '-'}</div>
									<div class="name-en">{employee.iban || '-'}</div>
								</div>
							</td>
							<td>
								{#if basicSalaryValues[employee.id]}
									<div class="value-display">
										<span class="amount">{parseFloat(basicSalaryValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
										<span class="badge">{paymentModeValues[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if otherAllowanceValues[employee.id]}
									<div class="value-display">
										<span class="amount">{parseFloat(otherAllowanceValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
										<span class="badge">{otherAllowancePaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if accommodationValues[employee.id]}
									<div class="value-display">
										<span class="amount">{parseFloat(accommodationValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
										<span class="badge">{accommodationPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if foodValues[employee.id]}
									<div class="value-display">
										<span class="amount">{parseFloat(foodValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
										<span class="badge">{foodPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if travelValues[employee.id]}
									<div class="value-display">
										<span class="amount">{parseFloat(travelValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
										<span class="badge">{travelPaymentMode[employee.id] === 'Bank' ? $t('hr.salary.bank') : $t('hr.salary.cash')}</span>
									</div>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if gosiValues[employee.id]}
									<span class="deduction-amount">-{parseFloat(gosiValues[employee.id]).toLocaleString()} {$t('common.sar')}</span>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if getTotalSalary(employee.id) > 0}
									{@const total = getTotalSalary(employee.id)}
									<span class="total-amount">{total.toLocaleString()} {$t('common.sar')}</span>
								{:else}
									<span class="no-data">-</span>
								{/if}
							</td>
							<td>
								{#if basicSalaryValues[employee.id]}
									<button class="edit-btn" on:click={() => openModal(employee.id)}>
										{$t('hr.salary.edit')}
									</button>
								{:else}
									<button class="add-btn" on:click={() => openModal(employee.id)}>
										+ {$t('hr.salary.add')}
									</button>
								{/if}
							</td>
						</tr>
					{/each}
					{#if employees.length === 0}
						<tr>
							<td colspan="15" class="no-data-row">{$t('hr.salary.noEmployeesFound')}</td>
						</tr>
					{/if}
				</tbody>
			</table>
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

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		position: sticky;
		top: 0;
		background: #f8f9fa;
		z-index: 1;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #495057;
		border-bottom: 2px solid #dee2e6;
		white-space: nowrap;
	}

	td {
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #dee2e6;
		color: #212529;
	}

	tbody tr:hover {
		background: #f8f9fa;
	}

	.no-data-row {
		text-align: center;
		color: #6c757d;
		font-style: italic;
		padding: 2rem !important;
	}

	.name-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.name-ar {
		font-weight: 500;
		color: #212529;
	}

	.name-en {
		font-size: 0.875rem;
		color: #6c757d;
	}

	.location {
		font-weight: normal;
		opacity: 0.8;
	}

	.value-display {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.amount {
		font-weight: 600;
		color: #28a745;
		font-size: 0.9rem;
	}

	.badge {
		display: inline-block;
		padding: 0.125rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		background: #e7f3ff;
		color: #0056b3;
		width: fit-content;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-badge.active {
		background: #d4edda;
		color: #155724;
		border: 1px solid #c3e6cb;
	}

	.status-badge.inactive {
		background: #f8d7da;
		color: #721c24;
		border: 1px solid #f5c6cb;
	}

	.deduction-amount {
		font-weight: 600;
		color: #dc3545;
		font-size: 0.9rem;
	}

	.total-amount {
		font-weight: 700;
		color: #0056b3;
		font-size: 1rem;
	}

	.no-data {
		color: #6c757d;
		font-style: italic;
	}

	.edit-btn, .add-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 4px;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
	}

	.edit-btn {
		background: #007bff;
		color: white;
	}

	.edit-btn:hover {
		background: #0056b3;
	}

	.add-btn {
		background: #17a2b8;
		color: white;
	}

	.add-btn:hover {
		background: #138496;
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
