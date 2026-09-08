<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { type FlyerSnapshot, type FlyerPage } from '$lib/utils/aiFlyer';
  import AiFlyerPage from './AiFlyerPage.svelte';

  export let section: 'generate' | 'library' = 'generate';
  const bucket = 'ai-generated-flyers';
  interface FlyerPageStatus { pageNumber: number; status: 'pending' | 'working' | 'done' | 'error'; url: string; error: string }
  let offers: any[] = [];
  let offerId = '';
  let offerName = '';
  let title = '';
  let snapshot: FlyerSnapshot | null = null;
  let templatePages: FlyerPage[] = [];
  // One entry per flyer page, tracked independently so a slow/failed page never wipes the
  // pages that already finished — the UI shows a placeholder per page and fills each in as
  // its own design+render round-trip completes, with a per-page Retry on failure.
  let flyerPages: FlyerPageStatus[] = [];
  let artworkUrl = '';
  let savedId = '';
  export let busy = false;
  let progress = '';
  let error = '';
  let success = '';
  let renderHost: HTMLDivElement;
  let library: any[] = [];
  let loadingLibrary = false;
  let libraryError = '';
  let libraryPage = 0;
  let hasMore = false;
  let preview: { title: string; pages: string[] } | null = null;
  let previewBusy = false;
  let mounted = false;
  let themeOptions: string[] = [];
  let colorTheme = '';
  let loadingThemes = false;
  let themeError = '';
  $: if (mounted && section === 'library') loadLibrary();
  $: completedPageCount = flyerPages.filter(p => p.status === 'done').length;
  $: allPagesDone = flyerPages.length > 0 && completedPageCount === flyerPages.length;
  onDestroy(() => { if (artworkUrl) URL.revokeObjectURL(artworkUrl); });

  onMount(async () => {
    mounted = true;
    const result = await supabase.from('flyer_offers').select('id, template_name, start_date, end_date, offer_names:offer_name_id(name_en, name_ar)').eq('is_active', true).order('created_at', { ascending: false });
    if (result.error) error = `Could not load offers: ${result.error.message}`;
    else offers = result.data || [];
  });

  function discardGeneration() {
    if (artworkUrl) URL.revokeObjectURL(artworkUrl);
    artworkUrl = '';
    snapshot = null; flyerPages = []; templatePages = []; savedId = ''; success = '';
    error = ''; themeOptions = []; colorTheme = ''; themeError = '';
  }
  function changeOffer() {
    discardGeneration();
    const offer = offers.find(o => o.id === offerId);
    offerName = offer?.offer_names?.name_ar || offer?.offer_names?.name_en || offer?.template_name || '';
  }

  // Step 2 of "select offer → name → get options → pick a color → generate": ask the AI for a
  // handful of color themes tailored to this offer name, same endpoint the Flyer Templates
  // window uses, before any image generation runs.
  async function getColorOptions() {
    if (!offerName.trim() || loadingThemes || busy) return;
    loadingThemes = true; themeError = ''; themeOptions = []; colorTheme = '';
    try {
      const response = await fetch('/api/generate-flyer-theme-options', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ offerDescriptionAr: offerName.trim() }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not get color options.');
      themeOptions = data.themes || [];
    } catch (e) { themeError = e instanceof Error ? e.message : 'Could not get color options.'; }
    finally { loadingThemes = false; }
  }

  async function capturePages(): Promise<string[]> {
    const { toPng } = await import('html-to-image');
    await tick();
    await document.fonts.ready;
    const elements = Array.from(renderHost.querySelectorAll<HTMLElement>('.ai-flyer-page'));
    const pages: string[] = [];
    const embeddedImages = new Map<string, Promise<string>>();
    for (const [index, element] of elements.entries()) {
      progress = `Rendering page ${templatePages[index].pageNumber} of ${snapshot?.pageCount || elements.length}…`;
      await Promise.all(Array.from(element.querySelectorAll('img')).map(async image => {
        await Promise.race([image.decode(), new Promise((_, reject) => setTimeout(() => reject(new Error('Image loading timed out.')), 20000))]);
        if (!image.naturalWidth) throw new Error('A product image could not be loaded.');
        const source = image.currentSrc || image.src;
        if (!embeddedImages.has(source)) embeddedImages.set(source, (async () => {
          const response = await fetch(source, { signal: AbortSignal.timeout(20000) });
          if (!response.ok) throw new Error('A template or product image could not be embedded in the flyer.');
          const blob = await response.blob();
          return new Promise<string>((resolve, reject) => {
            const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.onerror = () => reject(new Error('Image export failed.')); reader.readAsDataURL(blob);
          });
        })());
        image.src = await embeddedImages.get(source)!;
        await image.decode();
      }));
      // Fit text inside its existing field. Never change a slot, page or page order to make it fit.
      for (const box of element.querySelectorAll<HTMLElement>('[data-fit-text]')) {
        const content = box.firstElementChild as HTMLElement;
        let size = parseFloat(getComputedStyle(box).fontSize);
        const minimum = Math.min(size, 8);
        const overflows = () => content.getBoundingClientRect().height > box.getBoundingClientRect().height + 1 || content.scrollWidth > box.clientWidth + 1;
        while (overflows() && size > minimum) { size = Math.max(minimum, size - .5); box.style.fontSize = `${size}px`; }
        if (overflows()) throw new Error(`Page ${templatePages[index].pageNumber}: ${box.dataset.fieldLabel} is too long to fit readably. Review this page's product details. Products have not been moved.`);
      }
      // Native SVG/CSS rendering retains bevels, box shadows and product drop shadows in exports.
      pages.push(await toPng(element, { pixelRatio: 2, backgroundColor: '#ffffff', width: templatePages[index].width, height: templatePages[index].height }));
    }
    return pages;
  }

  // Designs, (for page 1 only) generates the shared artwork, and renders one page. Never
  // throws — failure is recorded on that page's own status so the run can continue to the
  // next page, and so a retry only has to redo this one page.
  async function runPage(pageNumber: number): Promise<boolean> {
    const index = pageNumber - 1;
    flyerPages[index] = { pageNumber, status: 'working', url: '', error: '' };
    flyerPages = [...flyerPages];
    try {
      progress = `Designing page ${pageNumber}${flyerPages.length > 1 ? ` of ${flyerPages.length}` : ''}…`;
      const response = await fetch('/api/ai-flyers/design', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ offerId, offerName: offerName.trim(), pageNumber, ...(snapshot ? { design: snapshot.design, revision: snapshot.revision } : {}) }), signal: AbortSignal.timeout(65000) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'AI generation failed.');
      // Drop this page's own prior contribution (if this is a retry) before re-adding it, so a
      // retried page's products/page entry replaces itself instead of duplicating.
      const priorProducts = snapshot ? snapshot.products.filter((p: any) => p.page_number !== pageNumber) : [];
      const priorPages = snapshot ? snapshot.pages.filter(pg => pg.pageNumber !== pageNumber) : [];
      snapshot = snapshot ? { ...snapshot, products: [...priorProducts, ...data.products], pages: [...priorPages, data.page] } : { ...data, pages: [data.page] };
      if (flyerPages.length !== data.pageCount) {
        // Now that the true page count is known (from page 1), expand the placeholder list —
        // preserving any page already tracked, in case this fires on a retry.
        const existing = flyerPages;
        flyerPages = Array.from({ length: data.pageCount }, (_, i) => existing[i] || { pageNumber: i + 1, status: 'pending', url: '', error: '' });
        flyerPages[index] = { pageNumber, status: 'working', url: '', error: '' };
      }
      if (pageNumber === 1 && !artworkUrl) {
        progress = 'Creating detailed market artwork with OpenAI. This can take a few minutes…';
        const art = await fetch('/api/ai-flyers/artwork', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ offerId, offerName: offerName.trim(), colorTheme }), signal: AbortSignal.timeout(285000)
        });
        if (!art.ok) { const failure = await art.json(); throw new Error(failure.error || 'Artwork generation failed.'); }
        artworkUrl = URL.createObjectURL(await art.blob());
      }
      if (snapshot) snapshot.model = `${data.model} + gpt-image-2`;
      if (!title) title = offerName.trim();
      progress = `Rendering page ${pageNumber} of ${flyerPages.length}…`;
      templatePages = [data.page];
      const [url] = await capturePages();
      flyerPages[index] = { pageNumber, status: 'done', url, error: '' };
      flyerPages = [...flyerPages];
      return true;
    } catch (e) {
      flyerPages[index] = { ...flyerPages[index], status: 'error', error: e instanceof Error ? e.message : 'Generation failed.' };
      flyerPages = [...flyerPages];
      return false;
    } finally {
      templatePages = [];
    }
  }

  function reportOutcome() {
    const failed = flyerPages.filter(p => p.status === 'error').length;
    if (failed) error = `${failed} of ${flyerPages.length} page(s) need a retry — see below. You can still download or save the pages that completed.`;
    else if (flyerPages.length) success = `${flyerPages.length} pages generated. Review the previews, then download or save.`;
  }

  async function generate() {
    if (!offerId || !offerName.trim() || !colorTheme || busy) return;
    busy = true; error = ''; success = ''; savedId = ''; title = '';
    if (artworkUrl) URL.revokeObjectURL(artworkUrl);
    artworkUrl = ''; snapshot = null;
    flyerPages = [{ pageNumber: 1, status: 'pending', url: '', error: '' }];
    try {
      // Page 1 also produces the shared artwork every other page depends on — only continue
      // to the rest of the flyer once it (and the artwork) actually succeeded.
      if (await runPage(1)) {
        for (let pageNumber = 2; pageNumber <= flyerPages.length; pageNumber++) await runPage(pageNumber);
      }
      reportOutcome();
    } finally { busy = false; progress = ''; templatePages = []; }
  }

  async function retryPage(pageNumber: number) {
    if (busy) return;
    busy = true; error = '';
    try {
      const ok = await runPage(pageNumber);
      // If page 1 had failed, the rest of the flyer was never started (see generate()) — now
      // that it (and the shared artwork) succeeded, pick up any pages still left untouched.
      if (ok && pageNumber === 1) {
        for (let n = 2; n <= flyerPages.length; n++) if (flyerPages[n - 1]?.status === 'pending') await runPage(n);
      }
      reportOutcome();
    } finally { busy = false; progress = ''; templatePages = []; }
  }

  async function pageBlob(url: string) {
    const response = await fetch(url);
    if (!response.ok) throw new Error('Could not read a flyer page.');
    return response.blob();
  }
  function download(blob: Blob, name: string) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a'); link.href = url; link.download = name; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  }
  function fileName(name: string) { return name.replace(/[<>:"/\\|?*\x00-\x1F]/g, '-').slice(0, 100) || 'AI-Flyer'; }

  async function downloadPng(pages = flyerPages.filter(p => p.status === 'done').map(p => p.url), name = title) {
    if (busy) return;
    busy = true; error = '';
    try {
      if (pages.length === 1) download(await pageBlob(pages[0]), `${fileName(name)}.png`);
      else {
        const { default: JSZip } = await import('jszip');
        const zip = new JSZip();
        for (let i = 0; i < pages.length; i++) zip.file(`page-${String(i + 1).padStart(3, '0')}.png`, await pageBlob(pages[i]));
        download(await zip.generateAsync({ type: 'blob' }), `${fileName(name)}-PNG.zip`);
      }
    } catch (e) { error = e instanceof Error ? e.message : 'Download failed.'; }
    finally { busy = false; }
  }
  async function downloadPdf(pages = flyerPages.filter(p => p.status === 'done').map(p => p.url), name = title) {
    if (busy) return;
    busy = true; error = '';
    try {
      const { jsPDF } = await import('jspdf');
      let pdf: InstanceType<typeof jsPDF> | undefined;
      for (let i = 0; i < pages.length; i++) {
        const blob = await pageBlob(pages[i]);
        const image = await createImageBitmap(blob);
        // PNGs are captured at 2x; retain each template page's original physical dimensions.
        const width = image.width / 2 * 25.4 / 96, height = image.height / 2 * 25.4 / 96;
        image.close();
        const orientation = width > height ? 'landscape' : 'portrait';
        if (!pdf) pdf = new jsPDF({ orientation, unit: 'mm', format: [width, height], compress: true });
        else pdf.addPage([width, height], orientation);
        const bytes = new Uint8Array(await blob.arrayBuffer());
        pdf.addImage(bytes, 'PNG', 0, 0, width, height, undefined, 'FAST');
      }
      if (pdf) download(pdf.output('blob'), `${fileName(name)}.pdf`);
    } catch (e) { error = e instanceof Error ? e.message : 'PDF download failed.'; }
    finally { busy = false; }
  }

  async function save() {
    if (!snapshot || !flyerPages.length || !flyerPages.every(p => p.status === 'done') || busy || savedId) return;
    busy = true; error = ''; success = '';
    const id = crypto.randomUUID();
    const paths: string[] = [];
    const completedPages = flyerPages.map(p => p.url);
    try {
      for (let i = 0; i < completedPages.length; i++) {
        progress = `Saving page ${i + 1} of ${completedPages.length}…`;
        const path = `${id}/page-${String(i + 1).padStart(3, '0')}.png`;
        const result = await supabase.storage.from(bucket).upload(path, await pageBlob(completedPages[i]), { contentType: 'image/png', upsert: false });
        if (result.error) throw result.error;
        paths.push(path);
      }
      const result = await supabase.from('ai_generated_flyers').insert({ id, offer_id: snapshot.offer.id, title: title.trim() || 'AI Flyer', start_date: snapshot.offer.start_date, end_date: snapshot.offer.end_date, page_count: paths.length, product_count: snapshot.products.length, page_paths: paths, snapshot, model: snapshot.model });
      if (result.error) throw result.error;
      savedId = id; success = 'Flyer saved. You can find it in AI Generated Flyers.';
    } catch (e) {
      // Check ambiguous network failures before removing files that a saved record may reference.
      const check = await supabase.from('ai_generated_flyers').select('id').eq('id', id).maybeSingle();
      if (check.data) { savedId = id; success = 'Flyer saved.'; }
      else {
        if (!check.error && paths.length) await supabase.storage.from(bucket).remove(paths);
        error = e instanceof Error ? e.message : (e as any)?.message || 'Save failed.';
      }
    } finally { busy = false; progress = ''; }
  }

  async function loadLibrary() {
    loadingLibrary = true; libraryError = '';
    const result = await supabase.from('ai_generated_flyers').select('id,title,start_date,end_date,page_count,product_count,page_paths,created_at').order('created_at', { ascending: false }).range(libraryPage * 20, libraryPage * 20 + 20);
    if (result.error) libraryError = `Could not load saved flyers: ${result.error.message}`;
    else { hasMore = result.data.length > 20; library = result.data.slice(0, 20); }
    loadingLibrary = false;
  }
  async function openPreview(row: any) {
    previewBusy = true; libraryError = '';
    try {
      const result = await supabase.storage.from(bucket).createSignedUrls(row.page_paths, 3600);
      if (result.error || result.data?.some((p: any) => !p.signedUrl)) throw new Error('Could not load all saved pages.');
      preview = { title: row.title, pages: result.data.map((p: any) => p.signedUrl) };
    } catch (e) { libraryError = e instanceof Error ? e.message : 'Preview failed.'; }
    finally { previewBusy = false; }
  }
  function focusDialog(node: HTMLElement) {
    const previous = document.activeElement as HTMLElement | null;
    node.focus();
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape') { event.preventDefault(); preview = null; }
      if (event.key !== 'Tab') return;
      const buttons = Array.from(node.querySelectorAll<HTMLButtonElement>('button:not(:disabled)'));
      const first = buttons[0], last = buttons[buttons.length - 1];
      if (event.shiftKey && (document.activeElement === first || document.activeElement === node)) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === node)) { event.preventDefault(); first?.focus(); }
    }
    node.addEventListener('keydown', keydown);
    return { destroy() { node.removeEventListener('keydown', keydown); previous?.focus(); } };
  }
</script>

<div class="ai-workspace">
  {#if section === 'generate'}
    <h2>Generate With AI</h2>
    <p>Select an offer, enter its headline, then get AI color options for the artwork before generating. All pages share the same artwork and follow the offer’s page order.</p>
    <div class="toolbar">
      <label>Active offer<select bind:value={offerId} on:change={changeOffer} disabled={busy}><option value="">Select an offer</option>{#each offers as offer}<option value={offer.id}>{offer.offer_names?.name_en || offer.offer_names?.name_ar || offer.template_name} · {offer.start_date} — {offer.end_date}</option>{/each}</select></label>
      <label>Offer name<input bind:value={offerName} on:input={discardGeneration} maxlength="200" disabled={busy} placeholder="Enter the offer headline" /></label>
      <button disabled={!offerName.trim() || busy || loadingThemes} on:click={getColorOptions}>{loadingThemes ? 'Getting options…' : 'Get Color Options'}</button>
    </div>
    {#if themeError}<p class="error" role="alert">{themeError}</p>{/if}
    {#if themeOptions.length}
      <div class="theme-options" role="radiogroup" aria-label="Color theme">
        {#each themeOptions as theme}
          <label class="theme-option" class:selected={colorTheme === theme}>
            <input type="radio" name="color-theme" value={theme} bind:group={colorTheme} disabled={busy} />
            <span>{theme}</span>
          </label>
        {/each}
      </div>
      <div class="toolbar">
        <button class="primary" disabled={!offerId || !offerName.trim() || !colorTheme || busy} on:click={generate}>{busy && progress ? 'Generating…' : 'Generate with AI'}</button>
      </div>
    {/if}
    {#if completedPageCount}
      <div class="toolbar"><label>Flyer name<input bind:value={title} maxlength="200" disabled={busy || !!savedId} /></label><button disabled={busy} on:click={() => downloadPng()}>Download PNG</button><button disabled={busy} on:click={() => downloadPdf()}>Download as PDF</button><button class="primary" disabled={busy || !!savedId || !allPagesDone} title={allPagesDone ? '' : 'Retry the failed page(s) below first'} on:click={save}>{savedId ? 'Saved' : 'Save'}</button></div>
      <p class="hint">Multiple PNG pages download together in a ZIP file. Downloads/Save only include completed pages{allPagesDone ? '' : ' — Save is disabled until every page is done'}.</p>
    {/if}
  {:else}
    <div class="toolbar"><h2>AI Generated Flyers</h2><button disabled={loadingLibrary} on:click={loadLibrary}>Refresh</button></div>
    {#if libraryError}<p class="error" role="alert">{libraryError}</p>{/if}
    {#if loadingLibrary}<p>Loading saved flyers…</p>{:else if !library.length && !libraryError}<p>No AI flyers have been saved yet.</p>{:else}
      <div class="table-scroll"><table><thead><tr><th>Flyer</th><th>Offer dates</th><th>Products</th><th>Pages</th><th>Saved</th><th>Action</th></tr></thead><tbody>{#each library as row}<tr><td>{row.title}</td><td>{row.start_date} — {row.end_date}</td><td>{row.product_count}</td><td>{row.page_count}</td><td>{new Date(row.created_at).toLocaleString()}</td><td><button disabled={previewBusy} on:click={() => openPreview(row)}>Preview</button></td></tr>{/each}</tbody></table></div>
      <div class="toolbar"><button disabled={!libraryPage || loadingLibrary} on:click={() => { libraryPage--; loadLibrary(); }}>Previous</button><span>Page {libraryPage + 1}</span><button disabled={!hasMore || loadingLibrary} on:click={() => { libraryPage++; loadLibrary(); }}>Next</button></div>
    {/if}
  {/if}
  {#if progress}<p role="status">{progress}</p>{/if}
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if success && section === 'generate'}<p class="success" role="status">{success}</p>{/if}
  {#if section === 'generate' && flyerPages.length}
    <div class="previews">
      {#each flyerPages as page (page.pageNumber)}
        <figure>
          {#if page.status === 'done'}
            <img src={page.url} alt={`Generated flyer page ${page.pageNumber}`} />
          {:else if page.status === 'error'}
            <div class="tile-placeholder tile-error">
              <p>⚠️ {page.error}</p>
              <button disabled={busy} on:click={() => retryPage(page.pageNumber)}>Retry page {page.pageNumber}</button>
            </div>
          {:else}
            <div class="tile-placeholder">
              {#if page.status === 'working'}<span class="spinner" aria-hidden="true"></span><p>Generating…</p>{:else}<p>Waiting…</p>{/if}
            </div>
          {/if}
          <figcaption>Page {page.pageNumber}</figcaption>
        </figure>
      {/each}
    </div>
  {/if}
</div>

{#if snapshot && templatePages.length}<div class="render-host" bind:this={renderHost} aria-hidden="true">{#each templatePages as page}<AiFlyerPage {snapshot} {page} {artworkUrl} />{/each}</div>{/if}
{#if preview}
  <div class="preview-overlay" role="presentation">
    <div class="preview-dialog" role="dialog" aria-modal="true" aria-label={preview.title} tabindex="-1" use:focusDialog>
      <div class="toolbar"><h2>{preview.title}</h2><button disabled={busy} on:click={() => downloadPng(preview!.pages, preview!.title)}>Download PNG</button><button disabled={busy} on:click={() => downloadPdf(preview!.pages, preview!.title)}>Download as PDF</button><button on:click={() => preview = null}>Close</button></div>
      {#if error}<p class="error" role="alert">{error}</p>{/if}
      <div class="saved-pages">{#each preview.pages as page, i}<figure><img src={page} alt={`Saved flyer page ${i + 1}`} /><figcaption>Page {i + 1}</figcaption></figure>{/each}</div>
    </div>
  </div>
{/if}

<style>
  .ai-workspace{padding:24px;color:#172033;background:#f5f7fb;min-height:100%;}h2{font-size:22px;font-weight:700;margin:0;}p{margin:12px 0;color:#475569;}.toolbar{display:flex;flex-wrap:wrap;gap:12px;align-items:end;margin:18px 0;}.toolbar h2{margin-right:auto;align-self:center;}label{display:flex;flex-direction:column;gap:6px;font-size:14px;font-weight:600;flex:1;min-width:200px;}select,input{background:white;border:1px solid #cbd5e1;border-radius:8px;padding:10px;color:#172033;width:100%;}button{padding:10px 16px;border:1px solid #cbd5e1;background:white;border-radius:8px;font-weight:600;color:#172033;cursor:pointer;}button.primary{background:#4338ca;color:white;border-color:#4338ca;}button:disabled{opacity:.5;cursor:not-allowed;}.error{background:#fef2f2;color:#991b1b;padding:12px;border-radius:8px;overflow-wrap:anywhere;}.success{background:#ecfdf5;color:#065f46;padding:12px;border-radius:8px;}.hint{font-size:12px;}.theme-options{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;margin:0 0 18px;}.theme-option{display:flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid #cbd5e1;border-radius:8px;background:white;font-size:13px;font-weight:600;cursor:pointer;}.theme-option.selected{border-color:#4338ca;background:#eef2ff;color:#3730a3;}.theme-option input{margin:0;}.previews{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;}figure{margin:0;}figure img{width:100%;height:auto;background:white;box-shadow:0 2px 10px #0002;}figcaption{text-align:center;padding:8px;font-size:13px;}.tile-placeholder{aspect-ratio:2/3;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;background:white;box-shadow:0 2px 10px #0002;border-radius:4px;color:#64748b;font-size:13px;}.spinner{width:26px;height:26px;border:3px solid #c7d2fe;border-top-color:#4338ca;border-radius:50%;animation:spin 1s linear infinite;}@keyframes spin{to{transform:rotate(360deg);}}.tile-error{color:#991b1b;padding:16px;text-align:center;gap:12px;}.tile-error p{margin:0;color:inherit;}.render-host{position:fixed;left:-12000px;top:0;width:794px;pointer-events:none;}.table-scroll{overflow:auto;}table{width:100%;border-collapse:collapse;background:white;}th,td{padding:12px;text-align:left;border-bottom:1px solid #e2e8f0;}th{background:#eef2ff;font-size:13px;}.preview-overlay{position:fixed;inset:0;background:#0f172acc;z-index:10050;padding:24px;display:flex;justify-content:center;}.preview-dialog{background:#f5f7fb;border-radius:12px;overflow:auto;padding:24px;width:min(1050px,100%);}.saved-pages{max-width:794px;margin:auto;display:grid;gap:24px;}
</style>
