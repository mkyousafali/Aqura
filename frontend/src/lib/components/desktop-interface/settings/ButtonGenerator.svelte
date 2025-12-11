<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { t } from '$lib/i18n';

	let activeSection = 'code'; // 'code' or 'database'
	let loading = false;
	let message = '';
	let messageType: 'success' | 'error' | 'info' = 'success';

	// Code base data
	let codebaseSections: any[] = [];
	let codebaseLoaded = false;

	// Database data
	let databaseSections: any[] = [];
	let databaseLoaded = false;

	// Missing buttons
	let missingButtons: any[] = [];
	let showMissingModal = false;

	onMount(() => {
		// Data will be loaded when user clicks the generate buttons
	});

	async function generateFromCodebase() {
		loading = true;
		try {
			// This will be called from API endpoint to parse sidebar code
			const response = await fetch('/api/parse-sidebar');
			const data = await response.json();
			codebaseSections = data.sections || [];
			codebaseLoaded = true;
			showMessage('Code base data loaded successfully', 'success');
		} catch (error) {
			showMessage('Error loading code base data: ' + error.message, 'error');
		}
		loading = false;
	}

	async function generateFromDatabase() {
		loading = true;
		try {
			const { data: sections, error: sectionError } = await supabase
				.from('button_main_sections')
				.select('id, section_code, section_name_en, section_name_ar')
				.order('display_order');

			if (sectionError) throw sectionError;

			const { data: subsections } = await supabase
				.from('button_sub_sections')
				.select('id, main_section_id, subsection_code, subsection_name_en');

			const { data: buttons } = await supabase
				.from('sidebar_buttons')
				.select('id, main_section_id, subsection_id, button_name_en, button_code');

			// Organize data by section
			databaseSections = sections.map(section => {
				const sectionSubs = subsections.filter(s => s.main_section_id === section.id);
				const sectionButtons = buttons.filter(b => b.main_section_id === section.id);

				return {
					...section,
					subsections: sectionSubs.map(sub => ({
						...sub,
						buttons: sectionButtons.filter(b => b.subsection_id === sub.id)
					})),
					totalButtons: sectionButtons.length
				};
			});

			databaseLoaded = true;
			showMessage('Database data loaded successfully', 'success');

			// Find missing buttons (in codebase but not in database)
			detectMissingButtons();
		} catch (error) {
			showMessage('Error loading database data: ' + error.message, 'error');
		}
		loading = false;
	}

	function detectMissingButtons() {
		const codebaseButtonNames = new Set<string>();
		const databaseButtonNames = new Set<string>();

		// Collect all button names from codebase
		codebaseSections.forEach(section => {
			section.subsections.forEach((sub: any) => {
				sub.buttons.forEach((btn: any) => {
					codebaseButtonNames.add(btn.name);
				});
			});
		});

		// Collect all button names from database
		databaseSections.forEach(section => {
			section.subsections.forEach(sub => {
				sub.buttons.forEach(btn => {
					databaseButtonNames.add(btn.button_name_en);
				});
			});
		});

		// Find missing buttons by comparing button names (case-insensitive)
		missingButtons = [];
		codebaseSections.forEach(section => {
			section.subsections.forEach((sub: any) => {
				sub.buttons.forEach((btn: any) => {
					// Check if this button name exists in database (case-insensitive comparison)
					const buttonExists = Array.from(databaseButtonNames).some(
						dbName => dbName.toLowerCase() === btn.name.toLowerCase()
					);
					
					if (!buttonExists) {
						missingButtons.push({
							code: btn.code,
							name: btn.name,
							section: section.name,
							subsection: sub.name
						});
					}
				});
			});
		});

		if (missingButtons.length > 0) {
			showMissingModal = true;
		}
	}

	function closeMissingModal() {
		showMissingModal = false;
	}

	function showMessage(msg: string, type: 'success' | 'error' | 'info') {
		message = msg;
		messageType = type;
		setTimeout(() => {
			message = '';
		}, 4000);
	}
</script>

<div class="button-generator-window">
	{#if message}
		<div class="message" class:error={messageType === 'error'}>
			{message}
		</div>
	{/if}

	<div class="header">
		<h2>Button Generator</h2>
		<p class="subtitle">Compare Code Base vs Database Structure</p>
	</div>

	<div class="sections-container">
		<!-- Section 1: Code Base -->
		<div class="section">
			<div class="section-header">
				<h3>📄 Section 1: Code Base</h3>
				<button 
					class="generate-btn"
					on:click={generateFromCodebase}
					disabled={loading}
				>
					{loading && activeSection === 'code' ? 'Generating...' : '▶ Generate'}
				</button>
			</div>

			{#if codebaseLoaded && codebaseSections.length > 0}
				<div class="data-container">
					<div class="summary-box">
						<div class="summary-item">
							<span class="label">📋 Sections:</span>
							<span class="value">{codebaseSections.length}</span>
						</div>
						<div class="summary-item">
							<span class="label">📑 Subsections:</span>
							<span class="value">{codebaseSections.reduce((sum, s) => sum + s.subsections.length, 0)}</span>
						</div>
						<div class="summary-item">
							<span class="label">🔘 Buttons:</span>
							<span class="value">{codebaseSections.reduce((sum, s) => sum + s.totalButtons, 0)}</span>
						</div>
					</div>
					<div class="sections-list">
						{#each codebaseSections as section}
							<div class="section-item">
								<div class="section-title">
									{section.name}
									<span class="badge">{section.subsections.length} subs</span>
								</div>
								<div class="subsections">
									{#each section.subsections as subsection}
										<div class="subsection-item">
											<span class="sub-name">{subsection.name}</span>
											<span class="sub-count">[{subsection.buttonCount}]</span>
										</div>
									{/each}
								</div>
							</div>
						{/each}
					</div>
				</div>
			{:else if !codebaseLoaded}
				<div class="empty-state">
					<p>👉 Click "Generate" button to load data from code base</p>
				</div>
			{/if}
		</div>

		<!-- Section 2: Database -->
		<div class="section">
			<div class="section-header">
				<h3>🗄️ Section 2: Database</h3>
				{#if codebaseLoaded}
					<button 
						class="generate-btn"
						on:click={generateFromDatabase}
						disabled={loading}
					>
						{loading && activeSection === 'database' ? 'Generating...' : '▶ Generate'}
					</button>
				{/if}
			</div>

			{#if databaseLoaded && databaseSections.length > 0}
				<div class="data-container">
					<div class="summary-box">
						<div class="summary-item">
							<span class="label">📋 Sections:</span>
							<span class="value">{databaseSections.length}</span>
						</div>
						<div class="summary-item">
							<span class="label">📑 Subsections:</span>
							<span class="value">{databaseSections.reduce((sum, s) => sum + s.subsections.length, 0)}</span>
						</div>
						<div class="summary-item">
							<span class="label">🔘 Buttons:</span>
							<span class="value">{databaseSections.reduce((sum, s) => sum + s.totalButtons, 0)}</span>
						</div>
					</div>
					<div class="sections-list">
						{#each databaseSections as section}
							<div class="section-item">
								<div class="section-title">
									{section.section_name_en}
									<span class="badge">{section.subsections.length} subs</span>
								</div>
								<div class="subsections">
									{#each section.subsections as subsection}
										<div class="subsection-item">
											<span class="sub-name">{subsection.subsection_name_en}</span>
											<span class="sub-count">[{subsection.buttons.length}]</span>
										</div>
									{/each}
								</div>
							</div>
						{/each}
					</div>
				</div>
			{:else if !databaseLoaded}
				<div class="empty-state">
					<p>👉 Click "Generate" button to load data from database</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Missing Buttons Modal -->
{#if showMissingModal}
	<div class="modal-overlay" on:click={closeMissingModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>⚠️ Missing Buttons in Database</h3>
				<button class="close-btn" on:click={closeMissingModal}>✕</button>
			</div>
			<div class="modal-body">
				<p class="info-text">Found <strong>{missingButtons.length}</strong> button(s) in codebase but missing from database:</p>
				<div class="missing-list">
					{#each missingButtons as button, index}
						<div class="missing-item">
							<div class="item-number">{index + 1}</div>
							<div class="item-details">
								<div class="item-header">
									<span class="item-code">{button.code}</span>
									<span class="item-name">{button.name}</span>
								</div>
								<div class="item-location">
									<span class="location-tag">{button.section}</span>
									<span class="location-tag">{button.subsection}</span>
								</div>
							</div>
						</div>
					{/each}
				</div>
			</div>
			<div class="modal-footer">
				<button class="close-modal-btn" on:click={closeMissingModal}>Close</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.button-generator-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f9fafb;
		border-radius: 8px;
		overflow: hidden;
	}

	.message {
		padding: 12px 16px;
		background: #d1fae5;
		color: #065f46;
		border-bottom: 1px solid #a7f3d0;
		font-size: 14px;

		&.error {
			background: #fee2e2;
			color: #7f1d1d;
			border-color: #fca5a5;
		}
	}

	.header {
		padding: 20px;
		background: white;
		border-bottom: 2px solid #e5e7eb;
	}

	.header h2 {
		margin: 0 0 8px 0;
		color: #1f2937;
		font-size: 24px;
		font-weight: 600;
	}

	.subtitle {
		margin: 0;
		color: #6b7280;
		font-size: 14px;
	}

	.sections-container {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		padding: 20px;
		flex: 1;
		overflow: hidden;
	}

	.section {
		display: flex;
		flex-direction: column;
		background: white;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px;
		background: #f3f4f6;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-header h3 {
		margin: 0;
		color: #1f2937;
		font-size: 16px;
		font-weight: 600;
	}

	.generate-btn {
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;

		&:hover:not(:disabled) {
			background: #2563eb;
		}

		&:disabled {
			opacity: 0.6;
			cursor: not-allowed;
		}
	}

	.data-container {
		flex: 1;
		overflow-y: auto;
		padding: 16px;
	}

	.summary-box {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 12px;
		margin-bottom: 20px;
		padding: 16px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 8px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.summary-item {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding: 12px;
		background: rgba(255, 255, 255, 0.1);
		border-radius: 6px;
		text-align: center;
		backdrop-filter: blur(10px);
	}

	.summary-item .label {
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.summary-item .value {
		color: white;
		font-size: 24px;
		font-weight: 700;
		line-height: 1;
	}

	.info-box {
		padding: 12px;
		background: #eff6ff;
		border-left: 4px solid #3b82f6;
		border-radius: 4px;
		margin-bottom: 16px;
	}

	.info-box p {
		margin: 4px 0;
		color: #1e40af;
		font-size: 13px;
		font-weight: 500;
	}

	.sections-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.section-item {
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		padding: 12px;
		background: #f9fafb;
	}

	.section-title {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 10px;
		font-weight: 600;
		color: #1f2937;
		font-size: 14px;
	}

	.badge {
		padding: 2px 8px;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.subsections {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding-left: 12px;
		border-left: 2px solid #d1d5db;
	}

	.subsection-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 13px;
		padding: 4px 0;
	}

	.sub-name {
		color: #4b5563;
		font-weight: 500;
	}

	.sub-count {
		background: #f3f4f6;
		color: #6b7280;
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 12px;
	}

	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #9ca3af;
		font-size: 14px;
		text-align: center;
	}

	/* Scrollbar styling */
	.data-container::-webkit-scrollbar {
		width: 8px;
	}

	.data-container::-webkit-scrollbar-track {
		background: #f3f4f6;
	}

	.data-container::-webkit-scrollbar-thumb {
		background: #d1d5db;
		border-radius: 4px;

		&:hover {
			background: #9ca3af;
		}
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
		border-radius: 12px;
		box-shadow: 0 20px 25px rgba(0, 0, 0, 0.15);
		max-width: 600px;
		width: 90%;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		background: #fef2f2;
		border-bottom: 2px solid #fca5a5;
	}

	.modal-header h3 {
		margin: 0;
		color: #7f1d1d;
		font-size: 18px;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #7f1d1d;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;

		&:hover {
			background: rgba(127, 29, 29, 0.1);
			border-radius: 4px;
		}
	}

	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 20px;
	}

	.info-text {
		margin: 0 0 16px 0;
		color: #374151;
		font-size: 14px;
	}

	.missing-list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.missing-item {
		display: flex;
		gap: 12px;
		padding: 12px;
		background: #fef2f2;
		border: 1px solid #fca5a5;
		border-radius: 6px;
	}

	.item-number {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		background: #fee2e2;
		border-radius: 50%;
		color: #991b1b;
		font-weight: 600;
		font-size: 14px;
		flex-shrink: 0;
	}

	.item-details {
		flex: 1;
	}

	.item-header {
		display: flex;
		gap: 10px;
		align-items: baseline;
		margin-bottom: 6px;
	}

	.item-code {
		color: #991b1b;
		font-size: 13px;
		font-weight: 700;
		font-family: monospace;
	}

	.item-name {
		color: #7f1d1d;
		font-size: 13px;
		font-weight: 500;
	}

	.item-location {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
	}

	.location-tag {
		display: inline-block;
		background: white;
		color: #7f1d1d;
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		border: 1px solid #fca5a5;
	}

	.modal-footer {
		padding: 16px 20px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		display: flex;
		justify-content: flex-end;
		gap: 10px;
	}

	.close-modal-btn {
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;

		&:hover {
			background: #2563eb;
		}
	}

	/* Modal scrollbar */
	.modal-body::-webkit-scrollbar {
		width: 8px;
	}

	.modal-body::-webkit-scrollbar-track {
		background: #f3f4f6;
	}

	.modal-body::-webkit-scrollbar-thumb {
		background: #d1d5db;
		border-radius: 4px;

		&:hover {
			background: #9ca3af;
		}
	}
</style>
