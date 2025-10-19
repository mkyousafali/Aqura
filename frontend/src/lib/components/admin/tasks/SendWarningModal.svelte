<script>
	import { supabase } from '$lib/utils/supabase';
	import WarningTemplate from './WarningTemplate.svelte';
	import { generateWarning as generateWarningApi } from '$lib/utils/warningGenerator.js';
	
	export let assignment;
	export let onClose = () => {}; // Callback for when window should close

	let selectedLanguage = 'en';
	let selectedWarningType = '';
	let fineAmount = '';
	let fineCurrency = 'USD';
	let isGenerating = false;
	let generatedWarning = '';
	let showTemplate = false;
	let warningData = null;
	let error = null;

	const languages = [
		{ code: 'en', name: 'English' },
		{ code: 'hi', name: 'Hindi' },
		{ code: 'ar', name: 'Arabic' },
		{ code: 'ur', name: 'Urdu' },
		{ code: 'ta', name: 'Tamil' },
		{ code: 'ml', name: 'Malayalam' },
		{ code: 'bn', name: 'Bengali' }
	];

	const warningTypes = [
		{
			code: 'overall_performance_no_fine',
			name: 'Overall Performance Warning (No Fine)',
			description: 'General performance warning without financial penalty',
			requiresFine: false,
			fineType: 'none'
		},
		{
			code: 'overall_performance_fine_threat',
			name: 'Overall Performance Warning (Fine Threat)',
			description: 'Performance warning with threat of future fine if repeated',
			requiresFine: true,
			fineType: 'threat'
		},
		{
			code: 'overall_performance_with_fine',
			name: 'Overall Performance Warning (With Fine)',
			description: 'Performance warning with immediate financial penalty',
			requiresFine: true,
			fineType: 'immediate'
		}
	];

	const currencies = [
		{ code: 'USD', name: 'US Dollar ($)' },
		{ code: 'EUR', name: 'Euro (€)' },
		{ code: 'GBP', name: 'British Pound (£)' },
		{ code: 'SAR', name: 'Saudi Riyal (ر.س)' },
		{ code: 'AED', name: 'UAE Dirham (د.إ)' },
		{ code: 'INR', name: 'Indian Rupee (₹)' },
		{ code: 'PKR', name: 'Pakistani Rupee (₨)' }
	];

	$: selectedWarningTypeData = warningTypes.find(wt => wt.code === selectedWarningType);
	$: showFineFields = selectedWarningTypeData?.requiresFine || false;

	async function generateWarning() {
		if (!selectedLanguage) {
			error = 'Please select a language';
			return;
		}

		if (!selectedWarningType) {
			error = 'Please select a warning type';
			return;
		}

		if (showFineFields && selectedWarningTypeData?.fineType !== 'none' && !fineAmount) {
			error = 'Please enter a fine amount';
			return;
		}

		if (showFineFields && fineAmount && (isNaN(parseFloat(fineAmount)) || parseFloat(fineAmount) <= 0)) {
			error = 'Please enter a valid fine amount';
			return;
		}

		isGenerating = true;
		error = null;

		try {
			console.log('Starting warning generation...');
			console.log('Assignment data:', assignment);
			console.log('Selected language:', selectedLanguage);
			console.log('Selected warning type:', selectedWarningType);
			console.log('Fine amount:', fineAmount);
			
			// Prepare enhanced assignment data with warning type and fine information
			const enhancedAssignment = {
				...assignment,
				warningType: selectedWarningType,
				warningTypeData: selectedWarningTypeData,
				fineAmount: showFineFields ? parseFloat(fineAmount) : null,
				fineCurrency: showFineFields ? fineCurrency : null,
				hasFine: showFineFields && selectedWarningTypeData?.fineType !== 'none',
				fineType: selectedWarningTypeData?.fineType || 'none'
			};
			
			// Use the new warning generator utility
			const result = await generateWarningApi(enhancedAssignment, selectedLanguage);
			
			if (!result.warning) {
				throw new Error('No warning content received from the server');
			}
			
			generatedWarning = result.warning;

			// Prepare warning data for template
			warningData = {
				recipientName: assignment.assigned_to || assignment.assignedToEmployee || 'Unknown Employee',
				recipientUsername: assignment.assigned_to_username || assignment.assignedTo || assignment.assigned_to || 'Unknown',
				recipientUserId: assignment.assigned_to_user_id || assignment.assignedToId || assignment.user_id || assignment.userId,
				assignedBy: assignment.assigned_by || assignment.assignedBy || 'Unknown',
				totalAssigned: assignment.total_assigned || assignment.totalAssigned || 0,
				totalCompleted: assignment.total_completed || assignment.totalCompleted || 0,
				totalOverdue: assignment.total_overdue || assignment.totalOverdue || 0,
				completionRate: (assignment.total_assigned || assignment.totalAssigned) > 0 ? 
					Math.round(((assignment.total_completed || assignment.totalCompleted) / (assignment.total_assigned || assignment.totalAssigned)) * 100) : 0,
				overdueRate: (assignment.total_assigned || assignment.totalAssigned) > 0 ? 
					Math.round(((assignment.total_overdue || assignment.totalOverdue) / (assignment.total_assigned || assignment.totalAssigned)) * 100) : 0,
				warningText: generatedWarning,
				language: selectedLanguage,
				warningType: selectedWarningType,
				warningTypeData: selectedWarningTypeData,
				fineAmount: showFineFields ? parseFloat(fineAmount) : null,
				fineCurrency: showFineFields ? fineCurrency : null,
				hasFine: showFineFields && selectedWarningTypeData?.fineType !== 'none',
				fineType: selectedWarningTypeData?.fineType || 'none',
				generatedAt: new Date().toISOString(),
				assignmentData: enhancedAssignment
			};

			showTemplate = true;
			console.log('Warning generated successfully');
		} catch (err) {
			console.error('Error generating warning:', err);
			error = `Failed to generate warning: ${err.message}`;
			
			// Provide more helpful error messages based on the error type
			if (err.message.includes('404') || err.message.includes('not found')) {
				error = 'Warning generation service is not available. Please contact your administrator.';
			} else if (err.message.includes('500')) {
				error = 'Server error occurred. Please try again later or contact support.';
			} else if (err.message.includes('network') || err.message.includes('fetch')) {
				error = 'Network error. Please check your internet connection and try again.';
			}
		} finally {
			isGenerating = false;
		}
	}

	function createWarningPrompt() {
		const languageMap = {
			'en': 'English',
			'ar': 'Arabic',
			'ur': 'Urdu',
			'hi': 'Hindi',
			'es': 'Spanish',
			'fr': 'French'
		};

		return `Generate a professional warning letter in ${languageMap[selectedLanguage]} for an employee with poor task completion performance.

Employee Details:
- Name: ${assignment.assignedToEmployee || assignment.assignedTo}
- Assigned By: ${assignment.assignedBy}
- Total Tasks Assigned: ${assignment.totalAssigned}
- Tasks Completed: ${assignment.totalCompleted}
- Overdue Tasks: ${assignment.totalOverdue}
- Completion Rate: ${assignment.totalAssigned > 0 ? Math.round((assignment.totalCompleted / assignment.totalAssigned) * 100) : 0}%

Requirements:
1. Professional and formal tone
2. Clearly state the performance issues
3. Mention specific numbers (tasks assigned, completed, overdue)
4. Request immediate improvement
5. Mention consequences if performance doesn't improve
6. Keep it concise but comprehensive
7. End with a professional closing

Please generate only the warning text content, without salutation or signature sections as those will be added separately.`;
	}

	function handleTemplateClose() {
		showTemplate = false;
	}
</script>

<!-- Warning Generation Window -->
<div class="warning-window">
	{#if !showTemplate}
		<div class="window-header">
			<h2 class="window-title">Generate Warning</h2>
			<button class="close-btn" on:click={onClose}>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
				</svg>
			</button>
		</div>

		<div class="window-body">
				<!-- Assignment Summary -->
				<div class="assignment-summary">
					<h3 class="summary-title">Assignment Summary</h3>
					<div class="summary-grid">
						<div class="summary-item">
							<span class="summary-label">Assigned To:</span>
							<span class="summary-value">{assignment.assignedToEmployee || assignment.assignedTo}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Assigned By:</span>
							<span class="summary-value">{assignment.assignedBy}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Assignment Type:</span>
							<span class="summary-value">{assignment.assignmentType || 'Individual'}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Branch:</span>
							<span class="summary-value">{assignment.branch || 'Not specified'}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Total Tasks:</span>
							<span class="summary-value">{assignment.totalAssigned}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Completed:</span>
							<span class="summary-value text-green-600">{assignment.totalCompleted}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Overdue:</span>
							<span class="summary-value text-red-600">{assignment.totalOverdue}</span>
						</div>
						<div class="summary-item">
							<span class="summary-label">Completion Rate:</span>
							<span class="summary-value">
								{assignment.totalAssigned > 0 ? Math.round((assignment.totalCompleted / assignment.totalAssigned) * 100) : 0}%
							</span>
						</div>
					</div>
				</div>

				<!-- Language Selection -->
				<div class="language-section">
					<label class="language-label">Select Language:</label>
					<select bind:value={selectedLanguage} class="language-select">
						{#each languages as language}
							<option value={language.code}>{language.name}</option>
						{/each}
					</select>
				</div>

				<!-- Warning Type Selection -->
				<div class="warning-type-section">
					<label class="warning-type-label">Select Warning Type:</label>
					<div class="warning-types-grid">
						{#each warningTypes as warningType}
							<div class="warning-type-option">
								<label class="warning-type-radio-label">
									<input 
										type="radio" 
										bind:group={selectedWarningType} 
										value={warningType.code}
										class="warning-type-radio"
									/>
									<div class="warning-type-content">
										<div class="warning-type-name">{warningType.name}</div>
										<div class="warning-type-description">{warningType.description}</div>
									</div>
								</label>
							</div>
						{/each}
					</div>
				</div>

				<!-- Fine Amount Section (Conditional) -->
				{#if showFineFields}
					<div class="fine-section">
						<h4 class="fine-section-title">
							{selectedWarningTypeData?.fineType === 'immediate' ? 'Fine Amount' : 'Potential Fine Amount'}
						</h4>
						<div class="fine-input-group">
							<div class="fine-amount-input">
								<label class="fine-label">Amount:</label>
								<input 
									type="number" 
									bind:value={fineAmount} 
									placeholder="Enter amount"
									min="0"
									step="0.01"
									class="fine-input"
								/>
							</div>
							<div class="fine-currency-select">
								<label class="currency-label">Currency:</label>
								<select bind:value={fineCurrency} class="currency-select">
									{#each currencies as currency}
										<option value={currency.code}>{currency.name}</option>
									{/each}
								</select>
							</div>
						</div>
						<div class="fine-info">
							{#if selectedWarningTypeData?.fineType === 'immediate'}
								<span class="fine-immediate">⚠️ This fine will be applied immediately upon warning issuance.</span>
							{:else if selectedWarningTypeData?.fineType === 'threat'}
								<span class="fine-threat">📋 This amount will be mentioned as a potential fine for repeated violations.</span>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Error Message -->
				{#if error}
					<div class="error-message">
						{error}
					</div>
				{/if}

				<!-- Generated Warning Preview -->
				{#if generatedWarning}
					<div class="warning-preview">
						<h4 class="preview-title">Generated Warning:</h4>
						<div class="preview-content">
							{generatedWarning}
						</div>
					</div>
				{/if}
			</div>

			<div class="window-footer">
				<button class="cancel-btn" on:click={onClose}>Cancel</button>
				<button 
					class="generate-btn" 
					on:click={generateWarning} 
					disabled={isGenerating || !selectedLanguage || !selectedWarningType || (showFineFields && !fineAmount)}
				>
					{#if isGenerating}
						<div class="loading-spinner"></div>
						Generating...
					{:else}
						Generate Warning
					{/if}
				</button>
			</div>
		{/if}
</div>

<!-- Warning Template Modal -->
{#if showTemplate && warningData}
	<WarningTemplate 
		data={warningData}
		on:close={handleTemplateClose}
	/>
{/if}

<style>
	.warning-window {
		width: 100%;
		height: 100%;
		background: white;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.window-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: white;
		flex-shrink: 0;
	}

	.window-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.window-body {
		padding: 24px;
		overflow-y: auto;
		flex: 1;
	}

	.assignment-summary {
		margin-bottom: 24px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
	}

	.summary-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 12px 0;
	}

	.summary-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.summary-label {
		font-size: 14px;
		color: #6b7280;
		font-weight: 500;
	}

	.summary-value {
		font-size: 14px;
		color: #111827;
		font-weight: 600;
	}

	.language-section {
		margin-bottom: 24px;
	}

	.language-label {
		display: block;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 8px;
	}

	.language-select {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.language-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	/* Warning Type Section Styles */
	.warning-type-section {
		margin-bottom: 24px;
	}

	.warning-type-label {
		display: block;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 12px;
	}

	.warning-types-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 12px;
	}

	.warning-type-option {
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		transition: all 0.2s ease;
	}

	.warning-type-option:hover {
		border-color: #d1d5db;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.warning-type-radio-label {
		display: block;
		cursor: pointer;
		padding: 0;
		margin: 0;
	}

	.warning-type-radio {
		display: none;
	}

	.warning-type-content {
		padding: 16px;
		transition: all 0.2s ease;
	}

	.warning-type-radio:checked + .warning-type-content {
		background: #eff6ff;
		border-left: 4px solid #3b82f6;
	}

	.warning-type-name {
		font-size: 14px;
		font-weight: 600;
		color: #111827;
		margin-bottom: 4px;
	}

	.warning-type-description {
		font-size: 12px;
		color: #6b7280;
		line-height: 1.4;
	}

	/* Fine Section Styles */
	.fine-section {
		margin-bottom: 24px;
		padding: 20px;
		background: #fefbef;
		border: 1px solid #fbbf24;
		border-radius: 8px;
	}

	.fine-section-title {
		font-size: 16px;
		font-weight: 600;
		color: #d97706;
		margin: 0 0 16px 0;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.fine-section-title::before {
		content: "💰";
		font-size: 18px;
	}

	.fine-input-group {
		display: grid;
		grid-template-columns: 2fr 1fr;
		gap: 16px;
		margin-bottom: 12px;
	}

	.fine-amount-input,
	.fine-currency-select {
		display: flex;
		flex-direction: column;
	}

	.fine-label,
	.currency-label {
		font-size: 14px;
		font-weight: 500;
		color: #92400e;
		margin-bottom: 6px;
	}

	.fine-input,
	.currency-select {
		padding: 10px 12px;
		border: 1px solid #fbbf24;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #111827;
	}

	.fine-input:focus,
	.currency-select:focus {
		outline: none;
		border-color: #d97706;
		box-shadow: 0 0 0 3px rgba(217, 119, 6, 0.1);
	}

	.fine-info {
		font-size: 13px;
		padding: 12px;
		background: rgba(251, 191, 36, 0.1);
		border-radius: 6px;
		border: 1px solid rgba(251, 191, 36, 0.3);
	}

	.fine-immediate {
		color: #dc2626;
		font-weight: 500;
	}

	.fine-threat {
		color: #d97706;
		font-weight: 500;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px;
		border-radius: 6px;
		font-size: 14px;
		margin-bottom: 16px;
	}

	.warning-preview {
		margin-bottom: 24px;
		padding: 16px;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		background: #fefefe;
	}

	.preview-title {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 12px 0;
	}

	.preview-content {
		font-size: 14px;
		line-height: 1.6;
		color: #111827;
		white-space: pre-wrap;
		max-height: 200px;
		overflow-y: auto;
		background: white;
		padding: 12px;
		border-radius: 4px;
		border: 1px solid #e5e7eb;
	}

	.window-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
		background: white;
		flex-shrink: 0;
	}

	.cancel-btn {
		padding: 8px 16px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.cancel-btn:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.generate-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.generate-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.generate-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading-spinner {
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

	@media (max-width: 768px) {
		.warning-window {
			width: 100%;
			margin: 0;
		}
		
		.summary-grid {
			grid-template-columns: 1fr;
		}
		
		.warning-types-grid {
			grid-template-columns: 1fr;
		}
		
		.fine-input-group {
			grid-template-columns: 1fr;
		}
		
		.window-footer {
			flex-direction: column;
		}
	}
</style>