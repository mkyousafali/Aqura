<script lang="ts">
	import { createEventDispatcher, onDestroy, onMount } from 'svelte';
	import { currentLocale, t } from '$lib/i18n';
	import { directOrderRpc } from '$lib/utils/directOrderApi';
	import type { DirectOrderTemplate } from '$lib/types/directOrder';

	export let canCreate = true;
	export let mobile = false;
	const dispatch = createEventDispatcher<{ select: DirectOrderTemplate }>();
	let templates: DirectOrderTemplate[] = [];
	let loading = true;
	let loadError = false;
	let hasMore = false;
	let requestId = 0;
	let controller: AbortController | undefined;
	let showForm = false;
	let shopName = '';
	let shopLocation = '';
	let selectedBranchId = '';
	let branches: { id: number; name_en: string; name_ar: string | null; location_en: string | null; location_ar: string | null }[] = [];
	let branchesLoading = false;
	let branchError = false;
	let draftId = '';
	let saving = false;
	let saveErrorKey = '';
	let saved = false;
	let downloadingId = '';
	let downloadErrorId = '';
	let downloadDone = 0;
	let downloadTotal = 0;
	let downloadController: AbortController | undefined;

	async function downloadOrder(template: DirectOrderTemplate) {
		if (downloadingId) return;
		const activeController = new AbortController();
		downloadController = activeController;
		downloadingId = template.id;
		downloadErrorId = '';
		downloadDone = 0;
		downloadTotal = 0;
		const locale = $currentLocale;
		try {
			const { downloadDirectOrderPdf } = await import('$lib/utils/directOrderPdf');
			await downloadDirectOrderPdf(template, mobile, locale, {
				signal: activeController.signal,
				onProgress: (done, total) => {
					if (!activeController.signal.aborted) { downloadDone = done; downloadTotal = total; }
				}
			});
		} catch {
			if (!activeController.signal.aborted) downloadErrorId = template.id;
		} finally {
			if (downloadController === activeController) {
				downloadingId = '';
				downloadController = undefined;
			}
		}
	}

	function showDialog(node: HTMLDialogElement) {
		node.showModal();
		return { destroy: () => node.close() };
	}

	function openForm() {
		if (!draftId) draftId = crypto.randomUUID();
		saveErrorKey = '';
		saved = false;
		showForm = true;
		void loadBranches();
	}

	function closeForm() {
		if (!saving) showForm = false;
	}

	async function loadBranches() {
		if (branchesLoading) return;
		branchesLoading = true;
		branchError = false;
		try {
			const result = await directOrderRpc(mobile, 'direct_order_branches');
			branches = result.branches || [];
		} catch {
			branches = [];
			branchError = true;
		} finally {
			branchesLoading = false;
		}
	}

	function branchLabel(branch: typeof branches[number]): string {
		const name = $currentLocale === 'ar' ? branch.name_ar || branch.name_en : branch.name_en;
		const location = $currentLocale === 'ar' ? branch.location_ar || branch.location_en : branch.location_en;
		return location ? `${name} - ${location}` : name;
	}

	function templateBranch(template: DirectOrderTemplate): string {
		return ($currentLocale === 'ar' ? template.branch_name_ar || template.branch_name_en : template.branch_name_en || template.branch_name_ar) || '—';
	}

	async function loadTemplates(more = false) {
		if (more && (loading || !hasMore)) return;
		controller?.abort();
		controller = new AbortController();
		const currentRequest = ++requestId;
		loading = true;
		loadError = false;
		try {
			const before = more ? templates[templates.length - 1]?.order_number : undefined;
			const result = await directOrderRpc(mobile, 'direct_order_list_templates', { p_before: before || null }, controller.signal);
			if (currentRequest !== requestId) return;
			if (!Array.isArray(result.templates)) throw new Error('Templates unavailable');
			templates = more ? [...templates, ...result.templates] : result.templates;
			hasMore = result.hasMore === true;
		} catch {
			if (currentRequest === requestId) loadError = true;
		} finally {
			if (currentRequest === requestId) { loading = false; controller = undefined; }
		}
	}

	async function saveTemplate() {
		if (saving) return;
		saveErrorKey = '';
		if (!shopName.trim() || !shopLocation.trim()) { saveErrorKey = 'shopDetailsRequired'; return; }
		if (!selectedBranchId) { saveErrorKey = 'templateBranchRequired'; return; }
		if (branchesLoading || branchError) { saveErrorKey = 'branchError'; return; }
		saving = true;
		try {
			const result = await directOrderRpc(mobile, 'direct_order_create_template', {
				p_id: draftId, p_shop_name: shopName.trim(), p_shop_location: shopLocation.trim(), p_branch_id: Number(selectedBranchId)
			});
			if (!result.template?.id) throw new Error('Save failed');
			showForm = false;
			draftId = '';
			shopName = '';
			shopLocation = '';
			selectedBranchId = '';
			saved = true;
			void loadTemplates();
		} catch {
			saveErrorKey = 'templateSaveError';
		} finally {
			saving = false;
		}
	}

	function createdAt(value: string) {
		return new Date(value).toLocaleString($currentLocale === 'ar' ? 'ar-SA' : 'en-GB', {
			dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Riyadh'
		});
	}

	onMount(() => { void loadTemplates(); });
	onDestroy(() => { requestId++; controller?.abort(); downloadController?.abort(); });
</script>

<section class:mobile>
	<div class="section-header">
		<h2>{t(canCreate ? 'directOrder.createOrder' : 'directOrder.manageOrder')}</h2>
		<div class="actions">
			<button class="secondary-button" type="button" disabled={loading} on:click={() => loadTemplates()}>{t('directOrder.refresh')}</button>
			{#if canCreate}<button class="primary-button" type="button" on:click={openForm}>+ {t('directOrder.createTemplate')}</button>{/if}
		</div>
	</div>
	{#if saved}<p class="saved-message" role="status">{t('directOrder.templateSaved')}</p>{/if}
	{#if downloadErrorId}<p class="error" role="alert">{t('directOrder.downloadError')}</p>{/if}
	{#if downloadingId}
		<p class="download-status" role="status" aria-live="polite">{downloadTotal > 0 ? t('directOrder.downloadProgress', { done: downloadDone, total: downloadTotal }) : t('directOrder.preparingPdf')}</p>
	{/if}
	<p class="hint">{t('directOrder.templateHint')}</p>
	{#if loadError}
		<div class="error" role="alert">
			<p>{t('directOrder.templatesError')}</p>
			<button class="secondary-button" type="button" on:click={() => loadTemplates()}>{t('directOrder.retry')}</button>
		</div>
	{/if}
	{#if loading}<p class="hint" role="status">{t('directOrder.loadingTemplates')}</p>{/if}
	{#if templates.length > 0}
		{#if mobile}
			<div class="mobile-template-list">
				{#each templates as template (template.id)}
					<article class="mobile-card">
					<button class="template-card-content" type="button" on:click={() => dispatch('select', template)} aria-label={t('directOrder.openTemplate', { number: template.order_number })}>
						<span class="card-heading"><strong>{template.shop_name || t('directOrder.legacyOrder')}</strong><span>#{template.order_number}</span></span>
						<span class="card-line"><span>{t('directOrder.shopLocation')}</span><span>{template.shop_location || '—'}</span></span>
						<span class="card-line"><span>{t('directOrder.branch')}</span><span>{templateBranch(template)}</span></span>
						<span class="card-line"><span>{t('directOrder.products')}</span><strong>{template.product_count}</strong></span>
						<span class="card-date">{createdAt(template.created_at)}</span>
					</button>
					{#if !canCreate}
						<button class="download-button" type="button" disabled={!!downloadingId} aria-busy={downloadingId === template.id} on:click={() => downloadOrder(template)}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v5h14v-5" /></svg>
							{t(downloadingId === template.id ? 'directOrder.preparingPdf' : 'directOrder.downloadOrder')}
						</button>
					{/if}
					</article>
				{/each}
			</div>
		{:else}
		<div class="table-container">
			<table>
				<thead><tr>
					<th scope="col">{t('directOrder.orderNumber')}</th>
					<th scope="col">{t('directOrder.shopName')}</th>
					<th scope="col">{t('directOrder.shopLocation')}</th>
					<th scope="col">{t('directOrder.branch')}</th>
					<th scope="col">{t('directOrder.products')}</th>
					<th scope="col">{t('directOrder.createdAt')}</th>
					{#if !canCreate}<th scope="col">{t('directOrder.downloadOrder')}</th>{/if}
				</tr></thead>
				<tbody>
					{#each templates as template (template.id)}
						<tr>
							<td><button class="template-link" type="button" on:click={() => dispatch('select', template)} aria-label={t('directOrder.openTemplate', { number: template.order_number })}>#{template.order_number}</button></td>
							<td>{template.shop_name || t('directOrder.legacyOrder')}</td>
							<td>{template.shop_location || '—'}</td>
							<td>{templateBranch(template)}</td>
							<td>{template.product_count}</td>
							<td>{createdAt(template.created_at)}</td>
							{#if !canCreate}
								<td><button class="download-button" type="button" disabled={!!downloadingId} aria-busy={downloadingId === template.id} on:click={() => downloadOrder(template)}>{t(downloadingId === template.id ? 'directOrder.preparingPdf' : 'directOrder.downloadOrder')}</button></td>
							{/if}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
		{/if}
		{#if hasMore}<button class="secondary-button load-more" type="button" disabled={loading} on:click={() => loadTemplates(true)}>{t('directOrder.loadMore')}</button>{/if}
	{:else if !loading && !loadError}
		<p class="empty-state">{t('directOrder.noTemplates')}</p>
	{/if}
</section>

{#if showForm}
	<dialog class:mobile use:showDialog aria-label={t('directOrder.createTemplate')} dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'} on:cancel|preventDefault={closeForm}>
		<form on:submit|preventDefault={saveTemplate}>
			<div class="section-header">
				<h2>{t('directOrder.createTemplate')}</h2>
				<button class="secondary-button" type="button" disabled={saving} on:click={closeForm} aria-label={t('directOrder.close')}>×</button>
			</div>
			<fieldset disabled={saving}>
				<label>
					<span>{t('directOrder.branch')} <span class="required">({t('directOrder.required')})</span></span>
					<select bind:value={selectedBranchId} disabled={branchesLoading || branchError} required>
						<option value="">{t(branchesLoading ? 'directOrder.loadingBranches' : 'directOrder.selectBranch')}</option>
						{#each branches as branch}
							<option value={String(branch.id)}>{branchLabel(branch)}</option>
						{/each}
					</select>
				</label>
				{#if branchError}
					<div class="error" role="alert">
						<p>{t('directOrder.branchError')}</p>
						<button class="secondary-button" type="button" on:click={loadBranches}>{t('directOrder.retry')}</button>
					</div>
				{:else if !branchesLoading && branches.length === 0}
					<p class="hint">{t('directOrder.noBranches')}</p>
				{/if}
				<label><span>{t('directOrder.shopName')} <span class="required">({t('directOrder.required')})</span></span><input type="text" bind:value={shopName} maxlength="200" required /></label>
				<label><span>{t('directOrder.shopLocation')} <span class="required">({t('directOrder.required')})</span></span><input type="text" bind:value={shopLocation} maxlength="500" required /></label>
			</fieldset>
			{#if saveErrorKey}<p class="error" role="alert">{t(`directOrder.${saveErrorKey}`)}</p>{/if}
			<footer>
				<button class="secondary-button" type="button" disabled={saving} on:click={closeForm}>{t('directOrder.close')}</button>
				<button class="primary-button" type="submit" disabled={saving || branchesLoading || branchError || branches.length === 0}>{t(saving ? 'directOrder.saving' : 'directOrder.saveTemplate')}</button>
			</footer>
		</form>
	</dialog>
{/if}

<style>
	.section-header, .actions { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
	.section-header { margin-bottom: 20px; }
	h2 { margin: 0; font-size: 20px; font-weight: 600; color: #1f2937; }
	.primary-button, .secondary-button { padding: 10px 16px; border: 1px solid #d1d5db; border-radius: 8px; background: white; color: #374151; font: inherit; font-weight: 600; cursor: pointer; }
	.primary-button { background: #2563eb; border-color: #2563eb; color: white; }
	button:disabled { opacity: 0.5; cursor: not-allowed; }
	button:focus-visible, input:focus-visible, select:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	.hint { color: #6b7280; font-size: 14px; }
	.saved-message { padding: 12px; border: 1px solid #bbf7d0; border-radius: 8px; background: #f0fdf4; color: #166534; }
	.download-status { color: #2563eb; font-size: 14px; }
	.download-button { position: relative; z-index: 1; display: inline-flex; align-items: center; justify-content: center; gap: 8px; min-height: 40px; padding: 8px 12px; border: 1px solid #bfdbfe; border-radius: 8px; background: #eff6ff; color: #1d4ed8; font: inherit; font-size: 14px; font-weight: 600; cursor: pointer; }
	.download-button:hover:not(:disabled) { background: #dbeafe; }
	.error { padding: 12px; border: 1px solid #fecaca; border-radius: 8px; background: #fef2f2; color: #b91c1c; }
	.error p { margin: 0 0 8px; }
	.table-container { overflow-x: auto; border: 1px solid #e5e7eb; border-radius: 10px; }
	table { width: 100%; border-collapse: collapse; font-size: 14px; }
	th, td { padding: 14px 16px; text-align: start; border-bottom: 1px solid #e5e7eb; }
	th { background: #f9fafb; color: #374151; white-space: nowrap; }
	tbody tr { position: relative; }
	tbody tr:hover, tbody tr:focus-within { background: #eff6ff; }
	tbody tr:last-child td { border-bottom: 0; }
	.template-link { padding: 0; border: 0; background: transparent; color: #2563eb; font: inherit; font-weight: 600; cursor: pointer; }
	.template-link::after { content: ''; position: absolute; inset: 0; }
	.load-more { margin-top: 16px; }
	.empty-state { padding: 48px 24px; border: 1px dashed #d1d5db; border-radius: 12px; background: #f9fafb; color: #6b7280; text-align: center; }
	dialog { box-sizing: border-box; width: calc(100% - 32px); max-width: 560px; max-height: calc(100% - 32px); padding: 24px; border: 0; border-radius: 12px; background: white; color: #1f2937; }
	dialog::backdrop { background: #0f172a99; }
	fieldset { display: flex; flex-direction: column; gap: 20px; min-width: 0; margin: 0; padding: 0; border: 0; }
	label { display: flex; flex-direction: column; gap: 8px; font-size: 14px; font-weight: 600; }
	input, select { box-sizing: border-box; width: 100%; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 8px; background: white; color: #1f2937; font: inherit; font-weight: 400; }
	.required { color: #b91c1c; font-size: 12px; font-weight: 400; }
	footer { display: flex; justify-content: flex-end; gap: 8px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #e5e7eb; }
	.mobile-template-list { display: grid; gap: 12px; }
	.mobile-card { display: flex; flex-direction: column; gap: 10px; min-width: 0; border: 1px solid #e5e7eb; border-radius: 12px; background: white; color: #1f2937; }
	.mobile-card:hover, .mobile-card:focus-within { border-color: #93c5fd; }
	.template-card-content { display: flex; flex-direction: column; gap: 10px; width: 100%; padding: 16px; border: 0; border-radius: 12px; background: transparent; color: inherit; font: inherit; text-align: start; cursor: pointer; }
	.template-card-content:hover { background: #eff6ff; }
	.mobile-card .download-button { align-self: flex-end; margin: -4px 12px 12px; }
	.card-heading { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; }
	.card-heading strong { min-width: 0; overflow-wrap: anywhere; }
	.card-heading > span { color: #2563eb; white-space: nowrap; }
	.card-line { display: flex; justify-content: space-between; gap: 16px; font-size: 14px; }
	.card-line > :first-child { color: #6b7280; flex-shrink: 0; }
	.card-line > :last-child { text-align: end; overflow-wrap: anywhere; min-width: 0; }
	.card-date { font-size: 12px; color: #6b7280; }
	.mobile .actions { width: 100%; }
	.mobile .actions .primary-button { flex: 1; }
	.mobile .primary-button, .mobile .secondary-button { min-height: 44px; }
	.mobile h2 { font-size: 18px; }
	dialog.mobile { width: calc(100% - 16px); max-height: calc(100dvh - 16px); padding: 16px; padding-bottom: max(16px, env(safe-area-inset-bottom)); }
	dialog.mobile input, dialog.mobile select { min-height: 44px; font-size: 16px; }
	dialog.mobile footer { position: sticky; bottom: 0; background: white; }
	dialog.mobile footer button { flex: 1; }
</style>
