<script>
	import { onMount } from 'svelte';

	// Props passed from parent
	export let employee = null;
	export let onClose = () => {};
	export let mockEmployeesData = []; // Reference to main data array

	// State management
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Salary data structure
	let salaryData = {
		basicSalary: 0,
		bonus: { amount: 0, enabled: false },
		foodAllowance: { amount: 0, enabled: false },
		accommodationAllowance: { amount: 0, enabled: false },
		travelAllowance: { amount: 0, enabled: false },
		otherAllowances: [
			{ name: '', amount: 0, enabled: false },
			{ name: '', amount: 0, enabled: false },
			{ name: '', amount: 0, enabled: false },
			{ name: '', amount: 0, enabled: false }
		],
		cuttings: [
			{ 
				name: '', 
				amount: 0, 
				enabled: false,
				applicationType: 'single',
				singleMonth: '',
				startMonth: '',
				endMonth: ''
			},
			{ 
				name: '', 
				amount: 0, 
				enabled: false,
				applicationType: 'single',
				singleMonth: '',
				startMonth: '',
				endMonth: ''
			},
			{ 
				name: '', 
				amount: 0, 
				enabled: false,
				applicationType: 'single',
				singleMonth: '',
				startMonth: '',
				endMonth: ''
			},
			{ 
				name: '', 
				amount: 0, 
				enabled: false,
				applicationType: 'single',
				singleMonth: '',
				startMonth: '',
				endMonth: ''
			}
		]
	};

	onMount(() => {
		if (employee) {
			loadEmployeeSalary();
		}
	});

	function loadEmployeeSalary() {
		// Load existing salary data if available
		const salary = employee.salary || {};
		salaryData = {
			basicSalary: salary.basicSalary || 0,
			bonus: { amount: salary.bonus?.amount || 0, enabled: salary.bonus?.enabled || false },
			foodAllowance: { amount: salary.foodAllowance?.amount || 0, enabled: salary.foodAllowance?.enabled || false },
			accommodationAllowance: { amount: salary.accommodationAllowance?.amount || 0, enabled: salary.accommodationAllowance?.enabled || false },
			travelAllowance: { amount: salary.travelAllowance?.amount || 0, enabled: salary.travelAllowance?.enabled || false },
			otherAllowances: [
				{ name: salary.otherAllowances?.[0]?.name || '', amount: salary.otherAllowances?.[0]?.amount || 0, enabled: salary.otherAllowances?.[0]?.enabled || false },
				{ name: salary.otherAllowances?.[1]?.name || '', amount: salary.otherAllowances?.[1]?.amount || 0, enabled: salary.otherAllowances?.[1]?.enabled || false },
				{ name: salary.otherAllowances?.[2]?.name || '', amount: salary.otherAllowances?.[2]?.amount || 0, enabled: salary.otherAllowances?.[2]?.enabled || false },
				{ name: salary.otherAllowances?.[3]?.name || '', amount: salary.otherAllowances?.[3]?.amount || 0, enabled: salary.otherAllowances?.[3]?.enabled || false }
			],
			cuttings: [
				{ 
					name: salary.cuttings?.[0]?.name || '', 
					amount: salary.cuttings?.[0]?.amount || 0, 
					enabled: salary.cuttings?.[0]?.enabled || false,
					applicationType: salary.cuttings?.[0]?.applicationType || 'single',
					singleMonth: salary.cuttings?.[0]?.singleMonth || getCurrentMonth(),
					startMonth: salary.cuttings?.[0]?.startMonth || '',
					endMonth: salary.cuttings?.[0]?.endMonth || ''
				},
				{ 
					name: salary.cuttings?.[1]?.name || '', 
					amount: salary.cuttings?.[1]?.amount || 0, 
					enabled: salary.cuttings?.[1]?.enabled || false,
					applicationType: salary.cuttings?.[1]?.applicationType || 'single',
					singleMonth: salary.cuttings?.[1]?.singleMonth || getCurrentMonth(),
					startMonth: salary.cuttings?.[1]?.startMonth || '',
					endMonth: salary.cuttings?.[1]?.endMonth || ''
				},
				{ 
					name: salary.cuttings?.[2]?.name || '', 
					amount: salary.cuttings?.[2]?.amount || 0, 
					enabled: salary.cuttings?.[2]?.enabled || false,
					applicationType: salary.cuttings?.[2]?.applicationType || 'single',
					singleMonth: salary.cuttings?.[2]?.singleMonth || getCurrentMonth(),
					startMonth: salary.cuttings?.[2]?.startMonth || '',
					endMonth: salary.cuttings?.[2]?.endMonth || ''
				},
				{ 
					name: salary.cuttings?.[3]?.name || '', 
					amount: salary.cuttings?.[3]?.amount || 0, 
					enabled: salary.cuttings?.[3]?.enabled || false,
					applicationType: salary.cuttings?.[3]?.applicationType || 'single',
					singleMonth: salary.cuttings?.[3]?.singleMonth || getCurrentMonth(),
					startMonth: salary.cuttings?.[3]?.startMonth || '',
					endMonth: salary.cuttings?.[3]?.endMonth || ''
				}
			]
		};
	}

	function getCurrentMonth() {
		const now = new Date();
		const year = now.getFullYear();
		const month = String(now.getMonth() + 1).padStart(2, '0');
		return `${month}-${year}`;
	}

	function calculateTotalAllowances() {
		let total = salaryData.basicSalary;
		
		if (salaryData.bonus.enabled) total += salaryData.bonus.amount;
		if (salaryData.foodAllowance.enabled) total += salaryData.foodAllowance.amount;
		if (salaryData.accommodationAllowance.enabled) total += salaryData.accommodationAllowance.amount;
		if (salaryData.travelAllowance.enabled) total += salaryData.travelAllowance.amount;
		
		salaryData.otherAllowances.forEach(allowance => {
			if (allowance.enabled && allowance.name) {
				total += allowance.amount;
			}
		});

		return total;
	}

	function calculateTotalCuttings() {
		let total = 0;
		
		salaryData.cuttings.forEach(cutting => {
			if (cutting.enabled && cutting.name) {
				total += cutting.amount;
			}
		});

		return total;
	}

	function calculateNetSalary() {
		return calculateTotalAllowances() - calculateTotalCuttings();
	}

	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-SA', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(amount);
	}

	function validateMonthFormat(month) {
		if (!month) return true;
		const regex = /^\d{2}-\d{4}$/;
		return regex.test(month);
	}

	function validateDateRange(cutting) {
		if (cutting.applicationType === 'single') return true;
		
		if (!cutting.startMonth || !cutting.endMonth) {
			return false;
		}

		const [startMonth, startYear] = cutting.startMonth.split('-').map(Number);
		const [endMonth, endYear] = cutting.endMonth.split('-').map(Number);
		
		const startDate = new Date(startYear, startMonth - 1);
		const endDate = new Date(endYear, endMonth - 1);
		
		return endDate >= startDate;
	}

	async function saveSalary() {
		if (!employee) return;

		// Validate inputs
		if (salaryData.basicSalary <= 0) {
			errorMessage = 'Basic salary must be greater than 0';
			return;
		}

		// Validate each cutting's application period
		for (let i = 0; i < salaryData.cuttings.length; i++) {
			const cutting = salaryData.cuttings[i];
			
			// Only validate if cutting is enabled and has a name
			if (cutting.enabled && cutting.name) {
				if (cutting.applicationType === 'single') {
					if (!cutting.singleMonth || !validateMonthFormat(cutting.singleMonth)) {
						errorMessage = `Please enter a valid month for cutting "${cutting.name}" in MM-YYYY format`;
						return;
					}
				} else {
					if (!cutting.startMonth || !cutting.endMonth) {
						errorMessage = `Please enter both start and end months for cutting "${cutting.name}"`;
						return;
					}
					
					if (!validateMonthFormat(cutting.startMonth) || !validateMonthFormat(cutting.endMonth)) {
						errorMessage = `Please enter valid months for cutting "${cutting.name}" in MM-YYYY format`;
						return;
					}

					if (!validateDateRange(cutting)) {
						errorMessage = `End month must be equal to or after start month for cutting "${cutting.name}"`;
						return;
					}
				}
			}
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 1500));

			// Prepare salary data
			const updatedSalary = {
				...salaryData,
				lastUpdated: new Date().toISOString(),
				updatedBy: 'Current User' // In real app, this would be from auth context
			};

			// Update the employee object
			employee.salary = updatedSalary;

			// Also update in the main data array if provided
			if (mockEmployeesData && Array.isArray(mockEmployeesData)) {
				const mainEmployeeIndex = mockEmployeesData.findIndex(emp => emp.id === employee.id);
				if (mainEmployeeIndex !== -1) {
					mockEmployeesData[mainEmployeeIndex] = {
						...mockEmployeesData[mainEmployeeIndex],
						salary: updatedSalary
					};
				}
			}

			successMessage = `Salary updated successfully for ${employee.name_en}`;
			
			// Close window after 2 seconds
			setTimeout(() => {
				onClose();
			}, 2000);

		} catch (error) {
			errorMessage = 'Failed to save salary information';
		} finally {
			isLoading = false;
		}
	}
</script>

{#if employee}
	<div class="employee-salary">
		<!-- Header -->
		<div class="salary-header">
			<div class="employee-info">
				<h3>Salary & Wage Management</h3>
				<div class="employee-details">
					<span class="employee-id-badge">{employee.employee_id}</span>
					<span class="employee-name">{employee.name_en}</span>
					<span class="employee-position">({employee.position})</span>
				</div>
			</div>
		</div>

		<!-- Content -->
		<div class="salary-content">
			<!-- Salary & Allowances Section -->
			<div class="salary-section">
				<h4 class="section-title">
					<span class="section-icon">💰</span>
					Salary & Allowances
				</h4>
				
				<div class="salary-grid">
					<!-- Basic Salary -->
					<div class="salary-item basic-salary">
						<label class="salary-label">Basic Salary <span class="required">*</span></label>
						<div class="input-group">
							<span class="currency-symbol">SAR</span>
							<input 
								type="number" 
								bind:value={salaryData.basicSalary}
								min="0"
								step="0.01"
								disabled={isLoading}
								class="salary-input"
								placeholder="0.00"
							>
						</div>
					</div>

					<!-- Bonus -->
					<div class="salary-item">
						<div class="allowance-header">
							<label class="salary-label">Bonus</label>
							<label class="toggle-container">
								<input 
									type="checkbox" 
									bind:checked={salaryData.bonus.enabled}
									disabled={isLoading}
									class="toggle-checkbox"
								>
								<span class="toggle-slider"></span>
							</label>
						</div>
						<div class="input-group" class:disabled={!salaryData.bonus.enabled}>
							<span class="currency-symbol">SAR</span>
							<input 
								type="number" 
								bind:value={salaryData.bonus.amount}
								min="0"
								step="0.01"
								disabled={isLoading || !salaryData.bonus.enabled}
								class="salary-input"
								placeholder="0.00"
							>
						</div>
					</div>

					<!-- Food Allowance -->
					<div class="salary-item">
						<div class="allowance-header">
							<label class="salary-label">Food Allowance</label>
							<label class="toggle-container">
								<input 
									type="checkbox" 
									bind:checked={salaryData.foodAllowance.enabled}
									disabled={isLoading}
									class="toggle-checkbox"
								>
								<span class="toggle-slider"></span>
							</label>
						</div>
						<div class="input-group" class:disabled={!salaryData.foodAllowance.enabled}>
							<span class="currency-symbol">SAR</span>
							<input 
								type="number" 
								bind:value={salaryData.foodAllowance.amount}
								min="0"
								step="0.01"
								disabled={isLoading || !salaryData.foodAllowance.enabled}
								class="salary-input"
								placeholder="0.00"
							>
						</div>
					</div>

					<!-- Accommodation Allowance -->
					<div class="salary-item">
						<div class="allowance-header">
							<label class="salary-label">Accommodation Allowance</label>
							<label class="toggle-container">
								<input 
									type="checkbox" 
									bind:checked={salaryData.accommodationAllowance.enabled}
									disabled={isLoading}
									class="toggle-checkbox"
								>
								<span class="toggle-slider"></span>
							</label>
						</div>
						<div class="input-group" class:disabled={!salaryData.accommodationAllowance.enabled}>
							<span class="currency-symbol">SAR</span>
							<input 
								type="number" 
								bind:value={salaryData.accommodationAllowance.amount}
								min="0"
								step="0.01"
								disabled={isLoading || !salaryData.accommodationAllowance.enabled}
								class="salary-input"
								placeholder="0.00"
							>
						</div>
					</div>

					<!-- Travel Allowance -->
					<div class="salary-item">
						<div class="allowance-header">
							<label class="salary-label">Travel Allowance</label>
							<label class="toggle-container">
								<input 
									type="checkbox" 
									bind:checked={salaryData.travelAllowance.enabled}
									disabled={isLoading}
									class="toggle-checkbox"
								>
								<span class="toggle-slider"></span>
							</label>
						</div>
						<div class="input-group" class:disabled={!salaryData.travelAllowance.enabled}>
							<span class="currency-symbol">SAR</span>
							<input 
								type="number" 
								bind:value={salaryData.travelAllowance.amount}
								min="0"
								step="0.01"
								disabled={isLoading || !salaryData.travelAllowance.enabled}
								class="salary-input"
								placeholder="0.00"
							>
						</div>
					</div>
				</div>

				<!-- Other Allowances -->
				<div class="other-allowances">
					<h5 class="subsection-title">Other Allowances</h5>
					<div class="allowance-rows">
						{#each salaryData.otherAllowances as allowance, index}
							<div class="allowance-row">
								<div class="row-number">{index + 1}</div>
								<div class="allowance-name">
									<label class="input-label">Allowance Name</label>
									<input 
										type="text" 
										bind:value={allowance.name}
										disabled={isLoading}
										class="text-input"
										placeholder="Enter allowance name"
									>
								</div>
								<div class="allowance-amount">
									<label class="input-label">Amount</label>
									<div class="input-group" class:disabled={!allowance.enabled}>
										<span class="currency-symbol">SAR</span>
										<input 
											type="number" 
											bind:value={allowance.amount}
											min="0"
											step="0.01"
											disabled={isLoading || !allowance.enabled}
											class="salary-input"
											placeholder="0.00"
										>
									</div>
								</div>
								<div class="allowance-toggle">
									<label class="input-label">Enable</label>
									<label class="toggle-container">
										<input 
											type="checkbox" 
											bind:checked={allowance.enabled}
											disabled={isLoading}
											class="toggle-checkbox"
										>
										<span class="toggle-slider small"></span>
									</label>
								</div>
							</div>
						{/each}
					</div>
				</div>
			</div>

			<!-- Cuttings Section -->
			<div class="cuttings-section">
				<h4 class="section-title">
					<span class="section-icon">✂️</span>
					Cuttings (Deductions)
				</h4>
				
				<div class="cutting-rows">
					{#each salaryData.cuttings as cutting, index}
						<div class="cutting-row-container">
							<div class="cutting-row">
								<div class="row-number">{index + 1}</div>
								<div class="cutting-name">
									<label class="input-label">Cutting Name / For</label>
									<input 
										type="text" 
										bind:value={cutting.name}
										disabled={isLoading}
										class="text-input"
										placeholder="Enter cutting name"
									>
								</div>
								<div class="cutting-amount">
									<label class="input-label">Amount</label>
									<div class="input-group" class:disabled={!cutting.enabled}>
										<span class="currency-symbol">SAR</span>
										<input 
											type="number" 
											bind:value={cutting.amount}
											min="0"
											step="0.01"
											disabled={isLoading || !cutting.enabled}
											class="salary-input"
											placeholder="0.00"
										>
									</div>
								</div>
								<div class="cutting-toggle">
									<label class="input-label">Enable</label>
									<label class="toggle-container">
										<input 
											type="checkbox" 
											bind:checked={cutting.enabled}
											disabled={isLoading}
											class="toggle-checkbox"
										>
										<span class="toggle-slider small"></span>
									</label>
								</div>
							</div>

							<!-- Application Period for this cutting -->
							{#if cutting.enabled && cutting.name}
								<div class="cutting-period">
									<h5 class="period-title">
										<span class="period-icon">📅</span>
										Application Period for "{cutting.name}"
									</h5>

									<div class="period-selection">
										<div class="selection-type">
											<label class="radio-container">
												<input 
													type="radio" 
													bind:group={cutting.applicationType}
													value="single"
													disabled={isLoading}
													class="radio-input"
												>
												<span class="radio-mark"></span>
												<span class="radio-label">Single Month</span>
											</label>
											<label class="radio-container">
												<input 
													type="radio" 
													bind:group={cutting.applicationType}
													value="multiple"
													disabled={isLoading}
													class="radio-input"
												>
												<span class="radio-mark"></span>
												<span class="radio-label">Multiple Months</span>
											</label>
										</div>

										{#if cutting.applicationType === 'single'}
											<div class="single-month">
												<label class="input-label">Month (MM-YYYY)</label>
												<input 
													type="text" 
													bind:value={cutting.singleMonth}
													disabled={isLoading}
													class="month-input"
													placeholder="09-2025"
													pattern="\d{2}-\d{4}"
												>
											</div>
										{:else}
											<div class="multiple-months">
												<div class="month-range">
													<div class="start-month">
														<label class="input-label">Start Month (MM-YYYY)</label>
														<input 
															type="text" 
															bind:value={cutting.startMonth}
															disabled={isLoading}
															class="month-input"
															placeholder="01-2025"
															pattern="\d{2}-\d{4}"
														>
													</div>
													<div class="end-month">
														<label class="input-label">End Month (MM-YYYY)</label>
														<input 
															type="text" 
															bind:value={cutting.endMonth}
															disabled={isLoading}
															class="month-input"
															placeholder="12-2025"
															pattern="\d{2}-\d{4}"
														>
													</div>
												</div>
											</div>
										{/if}
									</div>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			</div>

			<!-- Summary -->
			<div class="salary-summary">
				<h4 class="section-title">
					<span class="section-icon">📊</span>
					Salary Summary
				</h4>
				
				<div class="summary-grid">
					<div class="summary-item">
						<span class="summary-label">Total Allowances:</span>
						<span class="summary-value positive">{formatCurrency(calculateTotalAllowances())}</span>
					</div>
					<div class="summary-item">
						<span class="summary-label">Total Cuttings:</span>
						<span class="summary-value negative">-{formatCurrency(calculateTotalCuttings())}</span>
					</div>
					<div class="summary-item total">
						<span class="summary-label">Net Salary:</span>
						<span class="summary-value net">{formatCurrency(calculateNetSalary())}</span>
					</div>
				</div>
			</div>

			<!-- Messages -->
			{#if errorMessage}
				<div class="error-message">
					<strong>Error:</strong> {errorMessage}
				</div>
			{/if}

			{#if successMessage}
				<div class="success-message">
					<strong>Success:</strong> {successMessage}
				</div>
			{/if}

			<!-- Action Buttons -->
			<div class="salary-actions">
				<button 
					type="button"
					class="cancel-btn"
					on:click={onClose}
					disabled={isLoading}
				>
					Cancel
				</button>
				<button 
					class="save-btn"
					on:click={saveSalary}
					disabled={isLoading}
				>
					{#if isLoading}
						<span class="spinner"></span>
						Saving...
					{:else}
						<span class="icon">💾</span>
						Save Salary
					{/if}
				</button>
			</div>
		</div>
	</div>
{:else}
	<div class="no-employee">
		<p>No employee selected</p>
	</div>
{/if}

<style>
	.employee-salary {
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.salary-header {
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.employee-info h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.employee-details {
		display: flex;
		align-items: center;
		gap: 12px;
		flex-wrap: wrap;
	}

	.employee-id-badge {
		background: #3b82f6;
		color: white;
		padding: 4px 8px;
		border-radius: 6px;
		font-family: 'Courier New', monospace;
		font-weight: 600;
		font-size: 12px;
	}

	.employee-name {
		font-weight: 500;
		color: #111827;
	}

	.employee-position {
		color: #6b7280;
		font-size: 14px;
	}

	.salary-content {
		padding: 24px;
		max-width: 1000px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.salary-section, .cuttings-section, .salary-summary {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 24px;
	}

	.section-title {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.section-icon {
		font-size: 20px;
	}

	.salary-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 20px;
		margin-bottom: 24px;
	}

	.salary-item {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
	}

	.basic-salary {
		border-color: #10b981;
		background: #f0fdf4;
	}

	.allowance-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
	}

	.salary-label {
		font-weight: 500;
		color: #374151;
		font-size: 14px;
		display: block;
		margin-bottom: 8px;
	}

	.required {
		color: #ef4444;
	}

	.input-group {
		position: relative;
		display: flex;
		align-items: center;
	}

	.input-group.disabled {
		opacity: 0.5;
	}

	.currency-symbol {
		position: absolute;
		left: 12px;
		font-weight: 600;
		color: #6b7280;
		font-size: 14px;
		z-index: 1;
	}

	.salary-input {
		width: 100%;
		padding: 10px 12px 10px 45px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: all 0.2s;
	}

	.salary-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.salary-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.toggle-container {
		display: inline-block;
		position: relative;
		cursor: pointer;
	}

	.toggle-checkbox {
		display: none;
	}

	.toggle-slider {
		display: block;
		width: 44px;
		height: 24px;
		background: #e5e7eb;
		border-radius: 12px;
		position: relative;
		transition: all 0.2s;
	}

	.toggle-slider.small {
		width: 36px;
		height: 20px;
		border-radius: 10px;
	}

	.toggle-slider::before {
		content: '';
		position: absolute;
		top: 2px;
		left: 2px;
		width: 20px;
		height: 20px;
		background: white;
		border-radius: 50%;
		transition: all 0.2s;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
	}

	.toggle-slider.small::before {
		width: 16px;
		height: 16px;
	}

	.toggle-checkbox:checked + .toggle-slider {
		background: #10b981;
	}

	.toggle-checkbox:checked + .toggle-slider::before {
		transform: translateX(20px);
	}

	.toggle-checkbox:checked + .toggle-slider.small::before {
		transform: translateX(16px);
	}

	.other-allowances, .cutting-rows {
		margin-top: 20px;
	}

	.subsection-title {
		font-size: 16px;
		font-weight: 500;
		color: #374151;
		margin: 0 0 16px 0;
	}

	.allowance-rows, .cutting-rows {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.allowance-row, .cutting-row {
		display: grid;
		grid-template-columns: 40px 1fr 200px 80px;
		gap: 16px;
		align-items: end;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
	}

	.cutting-row-container {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.cutting-period {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 16px;
		margin-left: 68px; /* Align with content after row number */
	}

	.period-title {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin: 0 0 12px 0;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.period-icon {
		font-size: 14px;
	}

	.period-selection {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.row-number {
		background: #6366f1;
		color: white;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 14px;
	}

	.input-label {
		font-weight: 500;
		color: #374151;
		font-size: 12px;
		display: block;
		margin-bottom: 4px;
	}

	.text-input, .month-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: all 0.2s;
	}

	.text-input:focus, .month-input:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.text-input:disabled, .month-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.selection-type {
		display: flex;
		gap: 24px;
	}

	.radio-container {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
	}

	.radio-input {
		display: none;
	}

	.radio-mark {
		width: 20px;
		height: 20px;
		border: 2px solid #d1d5db;
		border-radius: 50%;
		position: relative;
		transition: all 0.2s;
	}

	.radio-input:checked + .radio-mark {
		border-color: #6366f1;
		background: #6366f1;
	}

	.radio-input:checked + .radio-mark::after {
		content: '';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 8px;
		height: 8px;
		background: white;
		border-radius: 50%;
	}

	.radio-label {
		font-weight: 500;
		color: #374151;
	}

	.single-month, .multiple-months {
		margin-top: 16px;
	}

	.month-range {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
	}

	.summary-grid {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.summary-item.total {
		background: #f0f9ff;
		border-color: #3b82f6;
		font-weight: 600;
	}

	.summary-label {
		color: #374151;
		font-weight: 500;
	}

	.summary-value {
		font-weight: 600;
		font-size: 16px;
	}

	.summary-value.positive {
		color: #10b981;
	}

	.summary-value.negative {
		color: #ef4444;
	}

	.summary-value.net {
		color: #3b82f6;
		font-size: 18px;
	}

	.error-message, .success-message {
		padding: 12px 16px;
		border-radius: 8px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
	}

	.success-message {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #059669;
	}

	.salary-actions {
		display: flex;
		gap: 16px;
		justify-content: flex-end;
		padding-top: 24px;
		border-top: 1px solid #e5e7eb;
		margin-top: 16px;
	}

	.cancel-btn, .save-btn {
		padding: 12px 24px;
		border-radius: 8px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.save-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.save-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.save-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.icon {
		font-size: 14px;
	}

	.no-employee {
		padding: 48px;
		text-align: center;
		color: #6b7280;
	}

	@media (max-width: 1024px) {
		.salary-grid {
			grid-template-columns: 1fr;
		}

		.allowance-row, .cutting-row {
			grid-template-columns: 1fr;
			gap: 12px;
		}

		.row-number {
			width: 24px;
			height: 24px;
			font-size: 12px;
		}

		.month-range {
			grid-template-columns: 1fr;
		}
	}

	@media (max-width: 768px) {
		.salary-content {
			padding: 16px;
		}

		.employee-details {
			flex-direction: column;
			align-items: flex-start;
			gap: 8px;
		}

		.salary-actions {
			flex-direction: column;
		}

		.selection-type {
			flex-direction: column;
			gap: 12px;
		}
	}
</style>