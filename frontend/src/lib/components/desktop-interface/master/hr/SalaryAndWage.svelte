<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	let employees: any[] = [];
	let isLoading = false;
	let errorMessage = '';
	let editingBasicSalary: { [key: string]: boolean } = {};
	let basicSalaryValues: { [key: string]: string } = {};
	let paymentModeValues: { [key: string]: string } = {};
	let savingBasicSalary: { [key: string]: boolean } = {};
	let editingOtherAllowance: { [key: string]: boolean } = {};
	let otherAllowanceValues: { [key: string]: string } = {};
	let otherAllowancePaymentMode: { [key: string]: string } = {};
	let savingOtherAllowance: { [key: string]: boolean } = {};

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
				errorMessage = 'Failed to load employees';
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
			errorMessage = 'Failed to load employees';
		} finally {
			isLoading = false;
		}
	}

	async function loadBasicSalaries() {
		try {
			const { data, error } = await supabase
				.from('hr_basic_salary')
				.select('employee_id, basic_salary, payment_mode, other_allowance, other_allowance_payment_mode');

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
				});
			}
		} catch (error) {
			console.error('Error loading basic salaries:', error);
		}
	}

	function startEditBasicSalary(employeeId: string) {
		editingBasicSalary[employeeId] = true;
		if (!basicSalaryValues[employeeId]) {
			basicSalaryValues[employeeId] = '';
		}
		if (!paymentModeValues[employeeId]) {
			paymentModeValues[employeeId] = 'Bank';
		}
	}

	async function saveBasicSalary(employeeId: string) {
		const value = basicSalaryValues[employeeId];
		const paymentMode = paymentModeValues[employeeId] || 'Bank';
		
		if (!value || isNaN(parseFloat(value))) {
			return;
		}

		savingBasicSalary[employeeId] = true;

		try {
			const { error } = await supabase
				.from('hr_basic_salary')
				.upsert({
					employee_id: employeeId,
					basic_salary: parseFloat(value),
					payment_mode: paymentMode,
					updated_at: new Date().toISOString()
				}, {
					onConflict: 'employee_id'
				});

			if (error) {
				console.error('Error saving basic salary:', error);
				errorMessage = 'Failed to save basic salary';
			} else {
				editingBasicSalary[employeeId] = false;
			}
		} catch (error) {
			console.error('Error saving basic salary:', error);
			errorMessage = 'Failed to save basic salary';
		} finally {
			savingBasicSalary[employeeId] = false;
		}
	}

	function cancelEditBasicSalary(employeeId: string) {
		editingBasicSalary[employeeId] = false;
		// Reload the original value
		loadBasicSalaries();
	}

	function startEditOtherAllowance(employeeId: string) {
		editingOtherAllowance[employeeId] = true;
		if (!otherAllowanceValues[employeeId]) {
			otherAllowanceValues[employeeId] = '';
		}
		if (!otherAllowancePaymentMode[employeeId]) {
			otherAllowancePaymentMode[employeeId] = 'Bank';
		}
	}

	async function saveOtherAllowance(employeeId: string) {
		const value = otherAllowanceValues[employeeId];
		const paymentMode = otherAllowancePaymentMode[employeeId] || 'Bank';
		
		if (!value || isNaN(parseFloat(value))) {
			return;
		}

		// Check if basic salary exists
		const basicSalary = basicSalaryValues[employeeId];
		const basicPaymentMode = paymentModeValues[employeeId] || 'Bank';
		
		if (!basicSalary) {
			errorMessage = 'Please add Basic Salary first before adding Other Allowance';
			return;
		}

		savingOtherAllowance[employeeId] = true;

		try {
			const { error } = await supabase
				.from('hr_basic_salary')
				.upsert({
					employee_id: employeeId,
					basic_salary: parseFloat(basicSalary),
					payment_mode: basicPaymentMode,
					other_allowance: parseFloat(value),
					other_allowance_payment_mode: paymentMode,
					updated_at: new Date().toISOString()
				}, {
					onConflict: 'employee_id'
				});

			if (error) {
				console.error('Error saving other allowance:', error);
				errorMessage = 'Failed to save other allowance';
			} else {
				editingOtherAllowance[employeeId] = false;
			}
		} catch (error) {
			console.error('Error saving other allowance:', error);
			errorMessage = 'Failed to save other allowance';
		} finally {
			savingOtherAllowance[employeeId] = false;
		}
	}

	function cancelEditOtherAllowance(employeeId: string) {
		editingOtherAllowance[employeeId] = false;
		// Reload the original value
		loadBasicSalaries();
	}
</script>

<div class="salary-wage-container">
	<div class="header">
		<h2>Salary and Wage Management</h2>
	</div>

	{#if errorMessage}
		<div class="error-message">{errorMessage}</div>
	{/if}

	{#if isLoading}
		<div class="loading">Loading...</div>
	{:else}
		<div class="table-container">
			<table>
				<thead>
					<tr>
						<th>ID</th>
						<th>Name</th>
						<th>Branch</th>
						<th>Nationality</th>
						<th>ID Number</th>
						<th>Bank Information</th>
						<th>Basic Salary</th>
						<th>Other Allowance</th>
						<th>Total Salary</th>
					</tr>
				</thead>
				<tbody>
					{#each employees as employee}
						<tr>
							<td>{employee.id}</td>
							<td>
								<div class="name-cell">
									<div class="name-ar">{employee.name_ar || '-'}</div>
									<div class="name-en">{employee.name_en || '-'}</div>
								</div>
							</td>
							<td>
								<div class="name-cell">
									<div class="name-ar">
										{#if employee.branches}
											{employee.branches.name_ar || '-'}
											{#if employee.branches.location_ar}
												<span class="location">({employee.branches.location_ar})</span>
											{/if}
										{:else}
											-
										{/if}
									</div>
									<div class="name-en">
										{#if employee.branches}
											{employee.branches.name_en || '-'}
											{#if employee.branches.location_en}
												<span class="location">({employee.branches.location_en})</span>
											{/if}
										{:else}
											-
										{/if}
									</div>
								</div>
							</td>
							<td>
								<div class="name-cell">
									<div class="name-ar">{employee.nationalities?.name_ar || '-'}</div>
									<div class="name-en">{employee.nationalities?.name_en || '-'}</div>
								</div>
							</td>
							<td>{employee.id_number || '-'}</td>
							<td>
								<div class="name-cell">
									<div class="name-ar">{employee.bank_name || '-'}</div>
									<div class="name-en">{employee.iban || '-'}</div>
								</div>
							</td>
							<td>
								<div class="salary-cell">
									{#if editingBasicSalary[employee.id]}
										<input 
											type="number" 
											bind:value={basicSalaryValues[employee.id]}
											placeholder="Enter salary"
											class="salary-input"
											on:keypress={(e) => {
												if (e.key === 'Enter') {
													saveBasicSalary(employee.id);
												}
											}}
										/>
										<select 
											bind:value={paymentModeValues[employee.id]}
											class="payment-mode-select"
										>
											<option value="Bank">Bank</option>
											<option value="Cash">Cash</option>
										</select>
										<div class="salary-actions">
											<button 
												class="save-btn"
												on:click={() => saveBasicSalary(employee.id)}
												disabled={savingBasicSalary[employee.id]}
											>
												{savingBasicSalary[employee.id] ? 'Saving...' : 'Save'}
											</button>
											<button 
												class="cancel-btn"
												on:click={() => cancelEditBasicSalary(employee.id)}
												disabled={savingBasicSalary[employee.id]}
											>
												Cancel
											</button>
										</div>
									{:else if basicSalaryValues[employee.id]}
										<div class="salary-display">
											<div class="salary-info">
												<span class="salary-amount">{parseFloat(basicSalaryValues[employee.id]).toLocaleString()} SAR</span>
												<span class="payment-mode-badge">{paymentModeValues[employee.id] || 'Bank'}</span>
											</div>
											<button 
												class="edit-btn"
												on:click={() => startEditBasicSalary(employee.id)}
											>
												Edit
											</button>
										</div>
									{:else}
										<button 
											class="add-btn"
											on:click={() => startEditBasicSalary(employee.id)}
										>
											+ Add Salary
										</button>
									{/if}
								</div>
							</td>
							<td>
								<div class="salary-cell">
									{#if editingOtherAllowance[employee.id]}
										<input 
											type="number" 
											bind:value={otherAllowanceValues[employee.id]}
											placeholder="Enter allowance"
											class="salary-input"
											on:keypress={(e) => {
												if (e.key === 'Enter') {
													saveOtherAllowance(employee.id);
												}
											}}
										/>
										<select 
											bind:value={otherAllowancePaymentMode[employee.id]}
											class="payment-mode-select"
										>
											<option value="Bank">Bank</option>
											<option value="Cash">Cash</option>
										</select>
										<div class="salary-actions">
											<button 
												class="save-btn"
												on:click={() => saveOtherAllowance(employee.id)}
												disabled={savingOtherAllowance[employee.id]}
											>
												{savingOtherAllowance[employee.id] ? 'Saving...' : 'Save'}
											</button>
											<button 
												class="cancel-btn"
												on:click={() => cancelEditOtherAllowance(employee.id)}
												disabled={savingOtherAllowance[employee.id]}
											>
												Cancel
											</button>
										</div>
									{:else if otherAllowanceValues[employee.id]}
										<div class="salary-display">
											<div class="salary-info">
												<span class="salary-amount">{parseFloat(otherAllowanceValues[employee.id]).toLocaleString()} SAR</span>
												<span class="payment-mode-badge">{otherAllowancePaymentMode[employee.id] || 'Bank'}</span>
											</div>
											<button 
												class="edit-btn"
												on:click={() => startEditOtherAllowance(employee.id)}
											>
												Edit
											</button>
										</div>
									{:else}
										<button 
											class="add-btn"
											on:click={() => startEditOtherAllowance(employee.id)}
										>
											+ Add Allowance
										</button>
									{/if}
								</div>
							</td>
							<td>
								<div class="total-salary-cell">
									{#if basicSalaryValues[employee.id] || otherAllowanceValues[employee.id]}
										{@const basicVal = parseFloat(basicSalaryValues[employee.id]) || 0}
										{@const otherVal = parseFloat(otherAllowanceValues[employee.id]) || 0}
										{@const total = basicVal + otherVal}
										<span class="total-amount">{total.toLocaleString()} SAR</span>
									{:else}
										<span class="no-salary">-</span>
									{/if}
								</div>
							</td>
						</tr>
					{/each}
					{#if employees.length === 0}
						<tr>
							<td colspan="9" class="no-data">No employees found</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	{/if}
</div>

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
	}

	h2 {
		margin: 0;
		font-size: 1.5rem;
		color: #333;
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

	.no-data {
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

	.salary-cell {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.salary-input {
		padding: 0.5rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
		width: 150px;
	}

	.salary-input:focus {
		outline: none;
		border-color: #80bdff;
		box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
	}

	.payment-mode-select {
		padding: 0.5rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
		width: 150px;
	}

	.payment-mode-select:focus {
		outline: none;
		border-color: #80bdff;
		box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
	}

	.salary-actions {
		display: flex;
		gap: 0.5rem;
	}

	.save-btn, .cancel-btn, .edit-btn, .add-btn {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 4px;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.save-btn {
		background: #28a745;
		color: white;
	}

	.save-btn:hover:not(:disabled) {
		background: #218838;
	}

	.cancel-btn {
		background: #6c757d;
		color: white;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #5a6268;
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
		padding: 0.5rem 1rem;
	}

	.add-btn:hover {
		background: #138496;
	}

	.save-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.salary-display {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.salary-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.salary-amount {
		font-weight: 600;
		color: #28a745;
		font-size: 1rem;
	}

	.payment-mode-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		background: #e7f3ff;
		color: #0056b3;
	}

	.total-salary-cell {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.total-amount {
		font-weight: 700;
		color: #0056b3;
		font-size: 1.1rem;
		background: #f0f8ff;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		border: 2px solid #0056b3;
	}

	.no-salary {
		color: #6c757d;
		font-style: italic;
	}
</style>
