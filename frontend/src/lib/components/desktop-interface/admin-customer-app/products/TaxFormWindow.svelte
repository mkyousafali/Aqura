<script lang="ts">
	import { translateText } from '$lib/utils/translationService';

	let taxNameEn = '';
	let taxNameAr = '';
	let percentage = '';
	let isTranslating = false;
	let translationError = '';
	let useAutoTranslate = false;

	async function handleEnglishInput() {
		if (!useAutoTranslate || !taxNameEn.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			taxNameAr = await translateText({
				text: taxNameEn,
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
		if (!useAutoTranslate || !taxNameAr.trim()) {
			return;
		}

		isTranslating = true;
		translationError = '';

		try {
			taxNameEn = await translateText({
				text: taxNameAr,
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

	function toggleAutoTranslate() {
		useAutoTranslate = !useAutoTranslate;
	}

	async function handleSave() {
		if (!taxNameEn.trim() || !taxNameAr.trim()) {
			alert('Please fill in both English and Arabic tax names');
			return;
		}

		if (!percentage || parseFloat(percentage) < 0 || parseFloat(percentage) > 100) {
			alert('Please enter a valid percentage between 0 and 100');
			return;
		}

		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			const { data, error } = await supabase
				.from('tax_categories')
				.insert([
					{
						name_en: taxNameEn.trim(),
						name_ar: taxNameAr.trim(),
						percentage: parseFloat(percentage)
					}
				])
				.select()
				.single();

			if (error) throw error;

			// Dispatch event
			window.dispatchEvent(new CustomEvent('tax-created', { detail: data }));

			alert('Tax category created successfully!');
			
			// Reset form
			taxNameEn = '';
			taxNameAr = '';
			percentage = '';
		} catch (error: any) {
			console.error('Error saving tax:', error);
			alert('Failed to save tax: ' + error.message);
		}
	}
</script>

<div class="tax-form-container">
	<div class="form-content">
		<div class="info-card">
			<div class="card-header">
				<h4 class="card-title">Tax Category Details</h4>
				<button
					class="translate-card-btn"
					class:active={useAutoTranslate}
					on:click={toggleAutoTranslate}
					title={useAutoTranslate ? 'Auto-translate: ON' : 'Auto-translate: OFF'}
					type="button"
				>
					{#if useAutoTranslate}
						🔄
					{:else}
						⭕
					{/if}
				</button>
			</div>

			<div class="form-group">
				<label for="tax-name-en">English Name</label>
				<input
					id="tax-name-en"
					type="text"
					bind:value={taxNameEn}
					on:blur={handleEnglishInput}
					placeholder="e.g. VAT, Sales Tax"
					disabled={isTranslating}
				/>
			</div>

			<div class="form-group">
				<label for="tax-name-ar">Arabic Name</label>
				<input
					id="tax-name-ar"
					type="text"
					bind:value={taxNameAr}
					on:blur={handleArabicInput}
					placeholder="مثال: ضريبة القيمة المضافة"
					disabled={isTranslating}
					dir="rtl"
				/>
			</div>

			<div class="form-group">
				<label for="percentage">Percentage (%)</label>
				<input
					id="percentage"
					type="number"
					bind:value={percentage}
					placeholder="e.g. 15"
					step="0.01"
					min="0"
					max="100"
					disabled={isTranslating}
				/>
				<p class="helper-text">Enter the tax percentage (0-100)</p>
			</div>
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
			Save Tax Category
		</button>
	</div>
</div>

<style>
	.tax-form-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
	}

	.form-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.info-card {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		padding: 1.5rem;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		border-bottom: 2px solid #e2e8f0;
		padding-bottom: 0.75rem;
	}

	.card-title {
		margin: 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.translate-card-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		background: #94a3b8;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1.2rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.translate-card-btn.active {
		background: #10b981;
	}

	.translate-card-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.translate-card-btn.active:hover {
		background: #059669;
	}

	.translate-card-btn:not(.active):hover {
		background: #64748b;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
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

	.helper-text {
		margin: 0.5rem 0 0 0;
		font-size: 0.85rem;
		color: #64748b;
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
		margin-top: 1rem;
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
		margin-top: 1rem;
	}

	.form-footer {
		padding: 1.5rem;
		border-top: 2px solid #e2e8f0;
	}

	.save-btn {
		width: 100%;
		padding: 0.875rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.save-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.save-btn:disabled {
		background: #94a3b8;
		cursor: not-allowed;
	}
</style>
