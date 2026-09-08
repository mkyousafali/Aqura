<script lang="ts">
	import { onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	let guideText = '';
	let originalText = '';
	let loading = true;
	let saving = false;
	let saveStatus: 'idle' | 'saved' | 'error' = 'idle';
	let lastUpdated = '';
	let charCount = 0;

	$: isArabic = $currentLocale === 'ar';
	$: charCount = guideText.length;
	$: hasChanges = guideText !== originalText;

	onMount(async () => {
		await loadGuide();
	});

	async function loadGuide() {
		loading = true;
		try {
			const { data, error } = await supabase
				.from('ai_chat_guide')
				.select('*')
				.order('id', { ascending: true })
				.limit(1)
				.maybeSingle();

			if (error) throw error;

			if (data) {
				guideText = data.guide_text || '';
				originalText = guideText;
				lastUpdated = data.updated_at
					? new Date(data.updated_at).toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-US')
					: '';
			}
		} catch (err: any) {
			console.error('Error loading AI chat guide:', err);
		}
		loading = false;
	}

	async function saveGuide() {
		saving = true;
		saveStatus = 'idle';
		try {
			// Check if record exists
			const { data: existing } = await supabase
				.from('ai_chat_guide')
				.select('id')
				.order('id', { ascending: true })
				.limit(1)
				.maybeSingle();

			if (existing) {
				const { error } = await supabase
					.from('ai_chat_guide')
					.update({ guide_text: guideText })
					.eq('id', existing.id);
				if (error) throw error;
			} else {
				const { error } = await supabase
					.from('ai_chat_guide')
					.insert({ guide_text: guideText });
				if (error) throw error;
			}

			originalText = guideText;
			saveStatus = 'saved';
			lastUpdated = new Date().toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-US');
			setTimeout(() => (saveStatus = 'idle'), 3000);
		} catch (err: any) {
			console.error('Error saving guide:', err);
			saveStatus = 'error';
			setTimeout(() => (saveStatus = 'idle'), 5000);
		}
		saving = false;
	}

	function resetGuide() {
		guideText = originalText;
	}
</script>

<div class="guide-container" dir={isArabic ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="guide-header">
		<div class="header-title">
			<span class="header-icon">🤖</span>
			<div>
				<h2>{isArabic ? 'دليل مساعد الذكاء الاصطناعي' : 'AI Chat Assistant Guide'}</h2>
				<p class="header-subtitle">
					{isArabic
						? 'اكتب التعليمات التي يجب أن يتبعها المساعد الذكي قبل الرد على أي رسالة'
						: 'Write the instructions the AI assistant must follow before responding to any message'}
				</p>
			</div>
		</div>
		{#if lastUpdated}
			<div class="last-updated">
				<span class="update-icon">🕐</span>
				<span>{isArabic ? 'آخر تحديث:' : 'Last updated:'} {lastUpdated}</span>
			</div>
		{/if}
	</div>

	<!-- Info Banner -->
	<div class="info-banner">
		<span class="info-icon">💡</span>
		<p>
			{isArabic
				? 'هذا الدليل سيُرسل للمساعد الذكي كتعليمات أساسية. سيقرأه قبل كل رد. اكتب قواعد واضحة مثل: "أنت مساعد لشركة أكوا، أجب فقط عن أسئلة العمل"'
				: 'This guide will be sent to the AI assistant as base instructions. It reads this before every reply. Write clear rules like: "You are an Aqura company assistant, only answer work-related questions"'}
		</p>
	</div>

	<!-- Editor -->
	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<span>{isArabic ? 'جاري التحميل...' : 'Loading...'}</span>
		</div>
	{:else}
		<div class="editor-area">
			<div class="editor-toolbar">
				<span class="char-count">{charCount.toLocaleString()} {isArabic ? 'حرف' : 'characters'}</span>
				{#if hasChanges}
					<span class="unsaved-badge">{isArabic ? 'تغييرات غير محفوظة' : 'Unsaved changes'}</span>
				{/if}
			</div>
			<textarea
				bind:value={guideText}
				class="guide-textarea"
				placeholder={isArabic
					? 'اكتب دليل المساعد الذكي هنا...\n\nمثال:\n- أنت مساعد ذكي لشركة أكوا\n- أجب باحترام ومهنية\n- لا تجب عن أسئلة خارج نطاق العمل\n- استخدم اللغة العربية دائمًا'
					: 'Write the AI assistant guide here...\n\nExample:\n- You are an AI assistant for Aqura company\n- Answer respectfully and professionally\n- Do not answer questions outside work scope\n- Always use English language'}
				rows="18"
				disabled={saving}
			></textarea>
		</div>

		<!-- Actions -->
		<div class="actions-bar">
			<div class="actions-left">
				{#if saveStatus === 'saved'}
					<span class="status-msg success">✅ {isArabic ? 'تم الحفظ بنجاح' : 'Saved successfully'}</span>
				{:else if saveStatus === 'error'}
					<span class="status-msg error">❌ {isArabic ? 'خطأ في الحفظ' : 'Error saving'}</span>
				{/if}
			</div>
			<div class="actions-right">
				<button class="btn btn-secondary" on:click={resetGuide} disabled={!hasChanges || saving}>
					{isArabic ? 'تراجع' : 'Reset'}
				</button>
				<button class="btn btn-primary" on:click={saveGuide} disabled={!hasChanges || saving}>
					{#if saving}
						<span class="btn-spinner"></span>
					{/if}
					{isArabic ? 'حفظ الدليل' : 'Save Guide'}
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.guide-container {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8fafc;
		font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
		overflow-y: auto;
	}

	.guide-header {
		padding: 20px 24px;
		background: linear-gradient(135deg, #4f46e5, #7c3aed);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		flex-shrink: 0;
	}

	.header-title {
		display: flex;
		gap: 12px;
		align-items: flex-start;
	}

	.header-icon {
		font-size: 32px;
		line-height: 1;
	}

	.guide-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 700;
	}

	.header-subtitle {
		margin: 4px 0 0;
		font-size: 13px;
		opacity: 0.85;
		max-width: 500px;
	}

	.last-updated {
		font-size: 12px;
		opacity: 0.8;
		display: flex;
		align-items: center;
		gap: 4px;
		white-space: nowrap;
	}

	.update-icon {
		font-size: 14px;
	}

	.info-banner {
		display: flex;
		gap: 10px;
		padding: 12px 24px;
		background: #eff6ff;
		border-bottom: 1px solid #dbeafe;
		align-items: flex-start;
		flex-shrink: 0;
	}

	.info-icon {
		font-size: 18px;
		flex-shrink: 0;
		margin-top: 1px;
	}

	.info-banner p {
		margin: 0;
		font-size: 13px;
		color: #1e40af;
		line-height: 1.5;
	}

	.loading-state {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		color: #64748b;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e2e8f0;
		border-top-color: #7c3aed;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.editor-area {
		flex: 1;
		display: flex;
		flex-direction: column;
		padding: 16px 24px;
		gap: 8px;
		min-height: 0;
	}

	.editor-toolbar {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.char-count {
		font-size: 12px;
		color: #94a3b8;
	}

	.unsaved-badge {
		font-size: 11px;
		background: #fef3c7;
		color: #92400e;
		padding: 2px 10px;
		border-radius: 12px;
		font-weight: 600;
	}

	.guide-textarea {
		flex: 1;
		border: 1.5px solid #e2e8f0;
		border-radius: 12px;
		padding: 16px;
		font-size: 14px;
		line-height: 1.7;
		resize: none;
		outline: none;
		font-family: inherit;
		background: white;
		color: #1e293b;
		transition: border-color 0.2s, box-shadow 0.2s;
		min-height: 300px;
	}

	.guide-textarea:focus {
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.guide-textarea:disabled {
		opacity: 0.6;
		background: #f8fafc;
	}

	.guide-textarea::placeholder {
		color: #94a3b8;
	}

	.actions-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 24px;
		border-top: 1px solid #e2e8f0;
		background: white;
		flex-shrink: 0;
	}

	.actions-left {
		display: flex;
		align-items: center;
	}

	.actions-right {
		display: flex;
		gap: 10px;
	}

	.status-msg {
		font-size: 13px;
		font-weight: 600;
	}

	.status-msg.success {
		color: #16a34a;
	}

	.status-msg.error {
		color: #dc2626;
	}

	.btn {
		padding: 8px 20px;
		border-radius: 10px;
		font-size: 13.5px;
		font-weight: 600;
		cursor: pointer;
		border: none;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-secondary {
		background: #f1f5f9;
		color: #475569;
	}

	.btn-secondary:hover:not(:disabled) {
		background: #e2e8f0;
	}

	.btn-primary {
		background: linear-gradient(135deg, #4f46e5, #7c3aed);
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(124, 58, 237, 0.3);
	}

	.btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}
</style>
