<script lang="ts">
  import { onDestroy } from 'svelte';
  import { currentLocale, t } from '$lib/i18n';
  import { resolveStorageUrl, supabase } from '$lib/utils/supabase';

  interface Product {
    id: string;
    barcode: string;
    product_name_en: string | null;
    product_name_ar: string | null;
    image_url: string | null;
  }

  const searchId = `poster-product-search-${Math.random().toString(36).slice(2)}`;
  const resultLimit = 30;
  let searchQuery = '';
  let results: Product[] = [];
  let selectedProducts: Product[] = [];
  let searching = false;
  let searchFailed = false;
  let hasSearched = false;
  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  let controller: AbortController | undefined;
  let requestId = 0;
  let failedImages = new Set<string>();
  let generatingProductId: string | null = null;
  let posterUrls: Record<string, string> = {};
  let posterErrors: Record<string, { code: string; detail?: string }> = {};
  let previewProductId: string | null = null;
  let generationController: AbortController | undefined;
  let destroyed = false;

  $: selectedIds = new Set(selectedProducts.map(product => product.id));
  $: previewProduct = selectedProducts.find(product => product.id === previewProductId) || null;

  function scheduleSearch(delay = 300) {
    clearTimeout(searchTimer);
    controller?.abort();
    const currentRequest = ++requestId;
    results = [];
    searchFailed = false;
    hasSearched = false;
    const term = searchQuery.trim();
    searching = Boolean(term);
    if (!term) return;
    searchTimer = setTimeout(() => searchProducts(term, currentRequest), delay);
  }

  async function searchProducts(term: string, currentRequest: number) {
    controller = new AbortController();
    // Quote the filter value so punctuation stays part of the search term.
    const pattern = `%${term.replace(/[\\%_]/g, '\\$&')}%`;
    const value = `"${pattern.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;

    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, barcode, product_name_en, product_name_ar, image_url')
        .or(`product_name_en.ilike.${value},product_name_ar.ilike.${value},barcode.ilike.${value}`)
        .order('product_name_en', { ascending: true })
        .order('id', { ascending: true })
        .limit(resultLimit)
        .abortSignal(controller.signal);

      if (currentRequest !== requestId) return;
      if (error) throw error;
      results = data || [];
      hasSearched = true;
    } catch {
      if (currentRequest === requestId) searchFailed = true;
    } finally {
      if (currentRequest === requestId) searching = false;
    }
  }

  function toggleProduct(product: Product) {
    if (generatingProductId === product.id) return;
    if (selectedIds.has(product.id)) {
      selectedProducts = selectedProducts.filter(selected => selected.id !== product.id);
      if (posterUrls[product.id]) URL.revokeObjectURL(posterUrls[product.id]);
      const { [product.id]: removedUrl, ...remainingUrls } = posterUrls;
      posterUrls = remainingUrls;
      const { [product.id]: removedError, ...remainingErrors } = posterErrors;
      posterErrors = remainingErrors;
      if (previewProductId === product.id) previewProductId = null;
      return;
    }

    selectedProducts = [...selectedProducts, product];
    searchQuery = '';
    scheduleSearch(0);
  }

  function markImageFailed(id: string) {
    failedImages = new Set([...failedImages, id]);
  }

  async function generatePoster(product: Product) {
    if (generatingProductId) return;
    previewProductId = product.id;
    if (!product.product_name_ar?.trim() || !product.image_url) {
      posterErrors = { ...posterErrors, [product.id]: { code: product.image_url ? 'missingArabicName' : 'missingProductImage' } };
      return;
    }
    generatingProductId = product.id;
    const { [product.id]: previousError, ...remainingErrors } = posterErrors;
    posterErrors = remainingErrors;
    generationController = new AbortController();
    const timeout = setTimeout(() => generationController?.abort(), 290_000);
    try {
      const response = await fetch('/api/posters/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ productId: product.id }),
        signal: generationController.signal
      });
      if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        const codes = new Set([
          'accessDenied', 'signInRequired', 'productLoadError', 'brandingLoadError',
          'missingApiKey', 'missingArabicName', 'missingProductImage', 'missingBrandLogo',
          'assetLoadError', 'invalidImage', 'alreadyGenerating', 'generationError',
          'unexpectedSize', 'generationTimeout', 'fontLoadError'
        ]);
        if (!destroyed) posterErrors = { ...posterErrors, [product.id]: {
          code: codes.has(error.code) ? error.code : 'generationError',
          detail: typeof error.detail === 'string' ? error.detail : undefined
        } };
        return;
      }
      if (!response.headers.get('content-type')?.startsWith('image/')) throw new Error('Invalid poster response');
      const image = await response.blob();
      if (destroyed) return;
      if (posterUrls[product.id]) URL.revokeObjectURL(posterUrls[product.id]);
      posterUrls = { ...posterUrls, [product.id]: URL.createObjectURL(image) };
      previewProductId = product.id;
    } catch (error) {
      if (!destroyed) posterErrors = { ...posterErrors, [product.id]: {
        code: error instanceof Error && error.name === 'AbortError' ? 'generationTimeout' : 'generationError'
      } };
    } finally {
      clearTimeout(timeout);
      if (!destroyed) generatingProductId = null;
    }
  }

  onDestroy(() => {
    destroyed = true;
    ++requestId;
    clearTimeout(searchTimer);
    controller?.abort();
    generationController?.abort();
    Object.values(posterUrls).forEach(url => URL.revokeObjectURL(url));
  });
</script>

{#key $currentLocale}
  <div class="availability">
    <div class="products-panel">
    <form on:submit|preventDefault={() => scheduleSearch(0)}>
      <label for={searchId}>{t('posters.searchProducts')}</label>
      <input
        id={searchId}
        type="search"
        value={searchQuery}
        on:input={(event) => {
          searchQuery = event.currentTarget.value;
          scheduleSearch();
        }}
        placeholder={t('posters.searchPlaceholder')}
        maxlength="120"
        autocomplete="off"
      />
    </form>

    <div class="search-status" role="status" aria-live="polite">
      {#if searching}
        <p>{t('posters.searching')}</p>
      {:else if searchFailed}
        <p class="error">{t('posters.searchError')}</p>
        <button type="button" class="retry" on:click={() => scheduleSearch(0)}>{t('posters.retry')}</button>
      {:else if hasSearched && results.length === 0}
        <p>{t('posters.noProducts')}</p>
      {:else if !searchQuery.trim() && selectedProducts.length === 0}
        <p>{t('posters.searchHint')}</p>
      {/if}
    </div>

    {#each [
      { key: 'results', title: 'posters.searchResults', products: results, isSelection: false },
      { key: 'selected', title: 'posters.selectedProducts', products: selectedProducts, isSelection: true }
    ] as productTable (productTable.key)}
      {#if productTable.products.length > 0}
        <h3>
          {t(productTable.title)}
          {#if productTable.isSelection}({selectedProducts.length}){/if}
        </h3>
        <div class="table-container">
          <table aria-label={t(productTable.title)}>
            <thead>
              <tr>
                <th scope="col">{t('posters.image')}</th>
                <th scope="col">{t('posters.englishName')}</th>
                <th scope="col">{t('posters.arabicName')}</th>
                <th scope="col">{t('posters.barcode')}</th>
                <th scope="col">{t('posters.action')}</th>
              </tr>
            </thead>
            <tbody>
              {#each productTable.products as product (product.id)}
                <tr class:selected={!productTable.isSelection && selectedIds.has(product.id)}>
                  <td class="image-cell">
                    <div class="image-box">
                      {#if product.image_url && !failedImages.has(product.id)}
                        <img src={resolveStorageUrl(product.image_url, 'flyer-product-images')} alt={product.product_name_en || product.product_name_ar || product.barcode} loading="lazy" on:error={() => markImageFailed(product.id)} />
                      {:else}
                        <span class="no-image">{t('posters.noImage')}</span>
                      {/if}
                    </div>
                  </td>
                  <td class="name" lang="en" dir="ltr">{product.product_name_en || '—'}</td>
                  <td class="name" lang="ar" dir="rtl">{product.product_name_ar || '—'}</td>
                  <td class="barcode" dir="ltr">{product.barcode}</td>
                  <td class="action-cell">
                    {#if productTable.isSelection}
                      <div class="row-actions">
                      <button
                        type="button"
                        class="generate-poster"
                        disabled={generatingProductId !== null}
                        aria-busy={generatingProductId === product.id}
                        on:click={() => generatePoster(product)}
                      >
                        {t(generatingProductId === product.id ? 'posters.generatingPoster' : posterUrls[product.id] ? 'posters.regeneratePoster' : 'posters.generatePoster')}
                      </button>
                      {#if posterUrls[product.id]}
                        <button type="button" class="preview-button" aria-expanded={previewProductId === product.id} on:click={() => previewProductId = previewProductId === product.id ? null : product.id}>
                          {t(previewProductId === product.id ? 'posters.hidePreview' : 'posters.previewPoster')}
                        </button>
                        <a class="download-poster" href={posterUrls[product.id]} download={`availability-${product.id}.png`}>{t('posters.downloadPoster')}</a>
                      {/if}
                      <button type="button" class="remove" disabled={generatingProductId === product.id} on:click={() => toggleProduct(product)} aria-label={`${t('posters.removeProduct')}: ${product.product_name_en || product.product_name_ar || product.barcode}`}>
                        {t('posters.removeProduct')}
                      </button>
                      </div>
                    {:else}
                      <button
                        type="button"
                        class="select-product"
                        aria-pressed={selectedIds.has(product.id)}
                        aria-label={`${t(selectedIds.has(product.id) ? 'posters.selected' : 'posters.selectProduct')}: ${product.product_name_en || product.product_name_ar || product.barcode}`}
                        on:click={() => toggleProduct(product)}
                      >
                        {t(selectedIds.has(product.id) ? 'posters.selected' : 'posters.selectProduct')}
                      </button>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        {#if !productTable.isSelection && results.length === resultLimit}
          <p class="hint">{t('posters.refineSearch')}</p>
        {/if}
      {/if}
    {/each}
    </div>

    <section class="result-panel" aria-label={t('posters.posterResult')} aria-busy={previewProductId !== null && generatingProductId === previewProductId}>
      <h3>{t('posters.posterResult')}</h3>
      {#if previewProduct}
        <div class="preview-product-name">
          <span lang="en" dir="ltr">{previewProduct.product_name_en || '—'}</span>
          <span lang="ar" dir="rtl">{previewProduct.product_name_ar || '—'}</span>
        </div>
        {#if generatingProductId === previewProduct.id}
          <p class="generation-status" role="status">{t('posters.generatingHint')}</p>
        {/if}
        {#if posterErrors[previewProduct.id]}
          <div class="error" role="alert">
            <p>{t(`posters.${posterErrors[previewProduct.id].code}`)}</p>
            {#if posterErrors[previewProduct.id].detail}<p>{posterErrors[previewProduct.id].detail}</p>{/if}
          </div>
        {/if}
        {#if posterUrls[previewProduct.id]}
          <img class="poster-preview" src={posterUrls[previewProduct.id]} alt={`${t('posters.previewPoster')}: ${previewProduct.product_name_ar || previewProduct.product_name_en || previewProduct.barcode}`} width="1152" height="2048" />
          <a class="download-poster" href={posterUrls[previewProduct.id]} download={`availability-${previewProduct.id}.png`}>{t('posters.downloadPoster')}</a>
        {/if}
      {:else}
        <div class="preview-empty"><p>{t('posters.posterResultHint')}</p></div>
      {/if}
    </section>
  </div>
{/key}

<style>
  .availability { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 1.25rem; color: #334155; }
  .products-panel, .result-panel { flex: 1 1 420px; min-width: 0; }
  .result-panel { box-sizing: border-box; padding: 1.25rem; position: sticky; top: 0; border: 1px solid #e2e8f0; border-radius: 10px; background: white; }
  .result-panel h3 { margin-top: 0; }
  .preview-product-name { display: flex; flex-direction: column; gap: 0.35rem; font-weight: 500; overflow-wrap: anywhere; }
  .preview-empty { display: flex; align-items: center; justify-content: center; min-height: 480px; color: #64748b; text-align: center; }
  .generation-status { padding: 1rem; border-radius: 8px; background: #fff7ed; color: #9a5100; }
  label { display: block; margin-bottom: 0.5rem; font-weight: 600; }
  input { width: 100%; box-sizing: border-box; padding: 0.8rem 1rem; border: 1px solid #cbd5e1; border-radius: 8px; background: white; color: #0f172a; font: inherit; }
  input:focus-visible, button:focus-visible { outline: 2px solid #f08300; outline-offset: 2px; }
  .search-status, .hint { font-size: 0.9rem; color: #64748b; }
  h3 { margin: 1.5rem 0 0.75rem; font-size: 1rem; font-weight: 600; }
  .table-container { max-width: 100%; overflow-x: auto; border: 1px solid #e2e8f0; border-radius: 10px; background: white; }
  table { width: 100%; min-width: 650px; border-collapse: collapse; text-align: start; }
  th, td { padding: 0.75rem 1rem; text-align: start; vertical-align: middle; }
  th { background: #f1f5f9; color: #475569; font-size: 0.85rem; font-weight: 600; }
  td { border-top: 1px solid #e2e8f0; }
  tbody tr:hover { background: #f8fafc; }
  tbody tr.selected { background: #fff7ed; }
  .image-cell { width: 72px; }
  .action-cell { width: 1%; white-space: nowrap; }
  .row-actions { display: flex; flex-direction: column; align-items: flex-start; gap: 0.5rem; }
  .row-actions button, .row-actions a { margin-inline-end: 0; }
  .image-box { display: flex; align-items: center; justify-content: center; width: 64px; height: 64px; border-radius: 6px; background: #f1f5f9; overflow: hidden; }
  img { width: 100%; height: 100%; object-fit: contain; }
  .no-image { padding: 0.25rem; color: #64748b; font-size: 0.75rem; text-align: center; }
  .name { min-width: 150px; max-width: 340px; font-weight: 500; overflow-wrap: anywhere; }
  .barcode { color: #64748b; font-size: 0.8rem; overflow-wrap: anywhere; }
  .select-product { padding: 0.4rem 0.75rem; border: 1px solid #f08300; border-radius: 6px; background: #fff7ed; color: #c46600; font: inherit; font-size: 0.85rem; cursor: pointer; }
  .select-product[aria-pressed="true"] { background: #ffedd5; font-weight: 600; }
  .generate-poster { margin-inline-end: 0.75rem; padding: 0.4rem 0.75rem; border: 1px solid #f08300; border-radius: 6px; background: #f08300; color: white; font: inherit; font-size: 0.85rem; }
  button:disabled { opacity: 0.6; cursor: not-allowed; }
  .preview-button, .download-poster { display: inline-block; margin-inline-end: 0.75rem; border: 0; background: transparent; padding: 0.25rem 0; color: #c46600; font: inherit; font-size: 0.85rem; cursor: pointer; }
  .download-poster { text-decoration: underline; }
  .download-poster:focus-visible { outline: 2px solid #f08300; outline-offset: 2px; }
  .poster-preview { display: block; width: 100%; max-width: 420px; height: auto; aspect-ratio: 9 / 16; margin: 1rem auto; border-radius: 8px; box-shadow: 0 8px 24px #0f172a26; }
  .result-panel p { margin: 0.5rem 0; overflow-wrap: anywhere; }
  .remove, .retry { align-self: flex-start; border: 0; background: transparent; padding: 0.25rem 0; font: inherit; font-size: 0.85rem; cursor: pointer; color: #c46600; }
  .remove, .error { color: #b91c1c; }
</style>
