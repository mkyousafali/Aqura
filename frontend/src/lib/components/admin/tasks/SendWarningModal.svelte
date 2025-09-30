<script>
	import { createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import WarningTemplate from './WarningTemplate.svelte';
	import { generateWarning as generateWarningApi } from '$lib/utils/warningGenerator.js';
	
	export let assignment;
	
	const dispatch = createEventDispatcher();
	
	let selectedLanguage = 'en';
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

	async function generateWarning() {
		if (!selectedLanguage) {
			error = 'Please select a language';
			return;
		}

		isGenerating = true;
		error = null;

		try {
			console.log('Starting warning generation...');
			console.log('Assignment data:', assignment);
			console.log('Selected language:', selectedLanguage);
			
			// Use the new warning generator utility
			const result = await generateWarningApi(assignment, selectedLanguage);
			
			if (!result.warning) {
				throw new Error('No warning content received from the server');
			}
			
			generatedWarning = result.warning;

			// Prepare warning data for template
			warningData = {
				recipientName: assignment.assignedToEmployee || assignment.assignedTo,
				recipientUsername: assignment.assignedTo,
				assignedBy: assignment.assignedBy,
				totalAssigned: assignment.totalAssigned,
				totalCompleted: assignment.totalCompleted,
				totalOverdue: assignment.totalOverdue,
				completionRate: assignment.totalAssigned > 0 ? 
					Math.round((assignment.totalCompleted / assignment.totalAssigned) * 100) : 0,
				overdueRate: assignment.totalAssigned > 0 ? 
					Math.round((assignment.totalOverdue / assignment.totalAssigned) * 100) : 0,
				warningText: generatedWarning,
				language: selectedLanguage,
				generatedAt: new Date().toISOString(),
				assignmentData: assignment
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

	function closeModal() {
		dispatch('close');
	}

	function handleTemplateClose() {
		showTemplate = false;
	}
</script>

<div class="modal-overlay" on:click={closeModal}>
	<div class="modal-content" on:click|stopPropagation>
		{#if !showTemplate}
			<div class="modal-header">
				<h2 class="modal-title">Generate Warning</h2>
				<button class="close-btn" on:click={closeModal}>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>

			<div class="modal-body">
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

			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeModal}>Cancel</button>
				<button 
					class="generate-btn" 
					on:click={generateWarning} 
					disabled={isGenerating || !selectedLanguage}
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
</div>

<!-- Warning Template Modal -->
{#if showTemplate && warningData}
	<WarningTemplate 
		data={warningData}
		on:close={handleTemplateClose}
	/>
{/if}

<style>
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
		border-radius: 12px;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
		width: 90%;
		max-width: 600px;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-title {
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

	.modal-body {
		padding: 24px;
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

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
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
		.modal-content {
			width: 95%;
			margin: 20px;
		}
		
		.summary-grid {
			grid-template-columns: 1fr;
		}
		
		.modal-footer {
			flex-direction: column;
		}
	}
</style>