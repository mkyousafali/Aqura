<script lang="ts">
	import { translateText } from '$lib/utils/translationService';

	let unitNameEn = '';
	let unitNameAr = '';
	let barcode = '';
	let isTranslating = false;
	let translationError = '';
	let useAutoTranslate = true;

	async function handleEnglishInput() {
		if (!useAutoTranslate || !unitNameEn.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			unitNameAr = await translateText({
				text: unitNameEn,
				targetLanguage: 'ar',
				sourceLanguage: 'en'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
		} finally {
			isTranslating = false;
		}
	}

	async function handleArabicInput() {
		if (!useAutoTranslate || !unitNameAr.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			unitNameEn = await translateText({
				text: unitNameAr,
				targetLanguage: 'en',
				sourceLanguage: 'ar'
			});
		} catch (error: any) {
			translationError = error.message || 'Translation failed';
			console.error('Translation error:', error);
		} finally {
			isTranslating = false;
		}
	}

	function handleSave() {
		if (!unitNameEn.trim() || !unitNameAr.trim()) {
			alert('Please fill in both English and Arabic names');
			return;
		}

		if (!barcode.trim()) {
			alert('Please enter a barcode');
			return;
		}

		// TODO: Save base unit to database
		console.log('Saving base unit:', { unitNameEn, unitNameAr, barcode });
		
		// Dispatch event to parent component
		window.dispatchEvent(new CustomEvent('base-unit-created', {
			detail: {
				name_en: unitNameEn,
				name_ar: unitNameAr,
				barcode: barcode
			}
		}));
	}
</script>

<div class="base-unit-form-container">
	<div class="form-header">
		<h3>Create Base Unit</h3>
		<label class="toggle-container">
			<input type="checkbox" bind:checked={useAutoTranslate} />
			<span class="toggle-label">Auto-translate</span>
		</label>
	</div>

	<div class="form-content">
		<div class="form-group">
			<label for="unit-name-en">Unit Name (English)</label>
			<input
				id="unit-name-en"
				type="text"
				bind:value={unitNameEn}
				on:blur={handleEnglishInput}
				placeholder="e.g., Kilogram, Piece, Box"
				disabled={isTranslating}
			/>
		</div>

		<div class="form-group">
			<label for="unit-name-ar">Unit Name (Arabic)</label>
			<input
				id="unit-name-ar"
				type="text"
				bind:value={unitNameAr}
				on:blur={handleArabicInput}
				placeholder="مثال: كيلوغرام، قطعة، صندوق"
				disabled={isTranslating}
				dir="rtl"
			/>
		</div>

		<div class="form-group">
			<label for="barcode">Barcode</label>
			<input
				id="barcode"
				type="text"
				bind:value={barcode}
				placeholder="Enter unit barcode"
				disabled={isTranslating}
			/>
		</div>

		{#if isTranslating}
			<div class="translation-status">
				<span class="spinner">⏳</span>
				Translating...
			</div>
		{/if}

		{#if translationError}
			<div class="error-message">
				⚠️ {translationError}
			</div>
		{/if}
	</div>

	<div class="form-footer">
		<button class="save-btn" on:click={handleSave} disabled={isTranslating}>
			Save Base Unit
		</button>
	</div>
</div>

<style>
	.base-unit-form-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.form-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 2px solid #e2e8f0;
	}

	.form-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.toggle-container {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}

	.toggle-container input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
	}

	.toggle-label {
		color: #64748b;
		font-size: 0.95rem;
	}

	.form-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		color: #1e293b;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.form-group input {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 0.5rem;
		font-size: 1rem;
		transition: border-color 0.2s ease;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.form-group input:disabled {
		background: #f1f5f9;
		cursor: not-allowed;
	}

	.translation-status {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 0.5rem;
		color: #0369a1;
		font-size: 0.9rem;
	}

	.spinner {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.error-message {
		padding: 0.75rem;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 0.5rem;
		color: #dc2626;
		font-size: 0.9rem;
	}

	.form-footer {
		padding: 1.5rem;
		border-top: 2px solid #e2e8f0;
	}

	.save-btn {
		width: 100%;
		padding: 0.875rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.save-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.save-btn:disabled {
		background: #94a3b8;
		cursor: not-allowed;
	}
</style>
