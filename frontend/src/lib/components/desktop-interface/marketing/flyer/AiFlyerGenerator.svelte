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
  // Internal AI visual-direction guidance ("General Supermarket Offer", "Fruit & Vegetable
  // Offer", ...) — never printed on the flyer. Loaded from the database (not hardcoded) and
  // threaded through color options, design, artwork and Improve. See offer_context_ai_flyer_spec.md.
  let contexts: { id: string; name: string; description: string }[] = [];
  let contextId = '';
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
  let deletingId = '';
  let preview: { id: string; title: string; pages: string[]; pagePaths: string[]; context: { id: string; name: string; description: string } | null } | null = null;
  let previewBusy = false;
  // Reviewing an AI "Improve" pass before committing it — parallel to preview.pages; empty
  // means nothing has been improved yet (still showing the saved originals).
  let improvedPages: string[] = [];
  let improving = false;
  let improveError = '';
  let mounted = false;
  let themeOptions: string[] = [];
  let colorTheme = '';
  let loadingThemes = false;
  let themeError = '';
  $: if (mounted && section === 'library') loadLibrary();
  $: selectedContext = contexts.find(c => c.id === contextId) || null;
  $: completedPageCount = flyerPages.filter(p => p.status === 'done').length;
  $: allPagesDone = flyerPages.length > 0 && completedPageCount === flyerPages.length;
  onDestroy(() => { if (artworkUrl) URL.revokeObjectURL(artworkUrl); });

  onMount(async () => {
    mounted = true;
    const [offersResult, contextsResult] = await Promise.all([
      supabase.from('flyer_offers').select('id, template_name, start_date, end_date, offer_names:offer_name_id(name_en, name_ar)').eq('is_active', true).order('created_at', { ascending: false }),
      supabase.from('flyer_offer_contexts').select('id, name, description').eq('is_active', true).order('sort_order')
    ]);
    if (offersResult.error) error = `Could not load offers: ${offersResult.error.message}`;
    else offers = offersResult.data || [];
    if (!contextsResult.error) {
      contexts = contextsResult.data || [];
      // "General Supermarket Offer" is seeded first (sort_order 0) — the required default per spec,
      // since most promotions mix products from several departments.
      if (!contextId && contexts.length) contextId = contexts[0].id;
    }
  });

  function discardGeneration() {
    if (artworkUrl) URL.revokeObjectURL(artworkUrl);
    artworkUrl = '';
    snapshot = null; flyerPages = []; templatePages = []; savedId = ''; success = '';
    error = ''; themeOptions = []; colorTheme = ''; themeError = '';
  }
  function changeOffer() {
    discardGeneration();
    // Offer Name is a headline the user writes for this flyer — it must start blank, never
    // pre-filled from the offer's own stored name/template name, even though that data is
    // available here (still used elsewhere, e.g. the "Active offer" dropdown label below).
    offerName = '';
  }

  // Step 2 of "select offer → name → get options → pick a color → generate": ask the AI for a
  // handful of color themes tailored to this offer name, same endpoint the Flyer Templates
  // window uses, before any image generation runs.
  async function getColorOptions() {
    if (!offerName.trim() || loadingThemes || busy) return;
    loadingThemes = true; themeError = ''; themeOptions = []; colorTheme = '';
    try {
      const response = await fetch('/api/generate-flyer-theme-options', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ offerDescriptionAr: offerName.trim(), offerContext: selectedContext?.name, offerContextDescription: selectedContext?.description }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not get color options.');
      themeOptions = data.themes || [];
    } catch (e) { themeError = e instanceof Error ? e.message : 'Could not get color options.'; }
    finally { loadingThemes = false; }
  }

  // Isolated product photos usually carry real blank margin around the packaging (standard for
  // a product-image library) — trim it to the actual content's bounding box so the packaging
  // fills the space it's given. This keeps the ENTIRE uploaded image intact (a product shot that
  // also shows a single pack next to the carton, or a box with an attached flap, stays exactly as
  // uploaded) — an earlier version of this instead kept only the largest connected piece and
  // discarded the rest, which silently dropped real content the uploader intended to show.
  async function trimProductPhoto(blob: Blob): Promise<Blob> {
    try {
      const bitmap = await createImageBitmap(blob);
      const fullWidth = bitmap.width, fullHeight = bitmap.height;
      // Analyze at a small fixed resolution regardless of source size — finding the content
      // bounding box doesn't need full pixel precision, just needs to be fast.
      const analysisMax = 160;
      const scale = Math.min(1, analysisMax / Math.max(fullWidth, fullHeight));
      const aw = Math.max(1, Math.round(fullWidth * scale)), ah = Math.max(1, Math.round(fullHeight * scale));
      const canvas = document.createElement('canvas');
      canvas.width = aw; canvas.height = ah;
      const ctx = canvas.getContext('2d');
      if (!ctx) return blob;
      ctx.drawImage(bitmap, 0, 0, aw, ah);
      const { data } = ctx.getImageData(0, 0, aw, ah);
      const alphaThreshold = 12;
      // Content detection relies on alpha alone: these product photos already come with a real,
      // professionally pre-cut alpha channel (verified while debugging this — not flat opaque
      // white backgrounds), so a whiteness check here would wrongly exclude a product that has
      // its own white design elements (a white speech-bubble logo, highlights).
      let minX = aw, minY = ah, maxX = -1, maxY = -1;
      for (let y = 0; y < ah; y++) {
        for (let x = 0; x < aw; x++) {
          if (data[(y * aw + x) * 4 + 3] < alphaThreshold) continue;
          if (x < minX) minX = x; if (x > maxX) maxX = x;
          if (y < minY) minY = y; if (y > maxY) maxY = y;
        }
      }
      // Map the full content bounding box back to full-resolution coordinates, with padding — or,
      // if the sample was blank or the crop would be negligible, keep the photo at its original
      // extent (background removal below still applies either way).
      let cropX = 0, cropY = 0, cropWidth = fullWidth, cropHeight = fullHeight;
      if (maxX >= minX && maxY >= minY) {
        const pad = Math.round(Math.min(aw, ah) * .04);
        const px0 = Math.max(0, minX - pad), py0 = Math.max(0, minY - pad);
        const px1 = Math.min(aw - 1, maxX + pad), py1 = Math.min(ah - 1, maxY + pad);
        const fx = fullWidth / aw, fy = fullHeight / ah;
        const candidateX = Math.round(px0 * fx), candidateY = Math.round(py0 * fy);
        const candidateWidth = Math.round((px1 - px0 + 1) * fx), candidateHeight = Math.round((py1 - py0 + 1) * fy);
        if (candidateWidth >= 4 && candidateHeight >= 4) { cropX = candidateX; cropY = candidateY; cropWidth = candidateWidth; cropHeight = candidateHeight; }
      }
      const out = document.createElement('canvas');
      out.width = cropWidth; out.height = cropHeight;
      const outCtx = out.getContext('2d')!;
      outCtx.drawImage(bitmap, cropX, cropY, cropWidth, cropHeight, 0, 0, cropWidth, cropHeight);
      // Cut any remaining flat background canvas out — flood-fill from the crop's own border
      // through pixels that are near-fully opaque AND near-white. Requiring near-full opacity
      // before whiteness counts is what keeps this safe on these already-transparent photos: a
      // pixel with partial alpha is an intentional soft/anti-aliased edge from the original
      // cutout and is left completely untouched, whatever its color — reclassifying it here (an
      // earlier version of this did) risks turning a correct soft edge into a slightly-wrong hard
      // one. A pixel of the same color fully enclosed by the product (packaging highlights, white
      // text) is never reached from the border, so it's left alone too; only true surrounding
      // background goes transparent. This is what lets overlapping product boxes show through
      // each other cleanly in a layout.
      const outData = outCtx.getImageData(0, 0, cropWidth, cropHeight);
      const px = outData.data;
      const whiteThreshold = 248, opaqueThreshold = 250;
      const isBackgroundPixel = (o: number) => px[o + 3] < alphaThreshold || (px[o + 3] >= opaqueThreshold && px[o] > whiteThreshold && px[o + 1] > whiteThreshold && px[o + 2] > whiteThreshold);
      const seen = new Uint8Array(cropWidth * cropHeight);
      const queue: number[] = [];
      const seed = (idx: number) => { if (!seen[idx] && isBackgroundPixel(idx * 4)) { seen[idx] = 1; queue.push(idx); } };
      for (let x = 0; x < cropWidth; x++) { seed(x); seed((cropHeight - 1) * cropWidth + x); }
      for (let y = 0; y < cropHeight; y++) { seed(y * cropWidth); seed(y * cropWidth + cropWidth - 1); }
      let qi = 0;
      while (qi < queue.length) {
        const cur = queue[qi++];
        px[cur * 4 + 3] = 0;
        const cx = cur % cropWidth, cy = Math.floor(cur / cropWidth);
        if (cx > 0) seed(cur - 1);
        if (cx < cropWidth - 1) seed(cur + 1);
        if (cy > 0) seed(cur - cropWidth);
        if (cy < cropHeight - 1) seed(cur + cropWidth);
      }
      outCtx.putImageData(outData, 0, 0);
      return await new Promise<Blob>((resolve) => out.toBlob(result => resolve(result || blob), 'image/png'));
    } catch {
      return blob; // any failure (e.g. decoding) — fall back to the untrimmed photo, never break the render
    }
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
        const trim = image.classList.contains('product-image');
        const cacheKey = trim ? `${source}#trimmed` : source;
        if (!embeddedImages.has(cacheKey)) embeddedImages.set(cacheKey, (async () => {
          const response = await fetch(source, { signal: AbortSignal.timeout(20000) });
          if (!response.ok) throw new Error('A template or product image could not be embedded in the flyer.');
          const blob = trim ? await trimProductPhoto(await response.blob()) : await response.blob();
          return new Promise<string>((resolve, reject) => {
            const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.onerror = () => reject(new Error('Image export failed.')); reader.readAsDataURL(blob);
          });
        })());
        image.src = await embeddedImages.get(cacheKey)!;
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
      const response = await fetch('/api/ai-flyers/design', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ offerId, offerName: offerName.trim(), pageNumber, contextName: selectedContext?.name, contextDescription: selectedContext?.description, ...(snapshot ? { design: snapshot.design, revision: snapshot.revision } : {}) }), signal: AbortSignal.timeout(65000) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'AI generation failed.');
      // Drop this page's own prior contribution (if this is a retry) before re-adding it, so a
      // retried page's products/page entry replaces itself instead of duplicating.
      const priorProducts = snapshot ? snapshot.products.filter((p: any) => p.page_number !== pageNumber) : [];
      const priorPages = snapshot ? snapshot.pages.filter(pg => pg.pageNumber !== pageNumber) : [];
      snapshot = snapshot ? { ...snapshot, products: [...priorProducts, ...data.products], pages: [...priorPages, data.page] } : { ...data, pages: [data.page], context: selectedContext };
      // TEMP DEBUG: console.log is suppressed app-wide (see app.html), so this uses
      // console.warn instead — remove once the variant-card mismatch is tracked down.
      for (const slot of data.page.slots) {
        if (slot.products?.length > 1) {
          console.warn('[AI flyer] variant slot', {
            field: { x: slot.field.x, y: slot.field.y, width: slot.field.width, height: slot.field.height, pageOrder: slot.field.pageOrder },
            products: slot.products.map((p: any) => ({ barcode: p.product_barcode, name: p.product_name_en, image_url: p.image_url, offer_qty: p.offer_qty, page_number: p.page_number, page_order: p.page_order }))
          });
        }
      }
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
          body: JSON.stringify({ offerId, offerName: offerName.trim(), colorTheme, contextName: selectedContext?.name, contextDescription: selectedContext?.description }), signal: AbortSignal.timeout(285000)
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
    const result = await supabase.from('ai_generated_flyers').select('id,title,start_date,end_date,page_count,product_count,page_paths,created_at,context:snapshot->context').order('created_at', { ascending: false }).range(libraryPage * 20, libraryPage * 20 + 20);
    if (result.error) libraryError = `Could not load saved flyers: ${result.error.message}`;
    else { hasMore = result.data.length > 20; library = result.data.slice(0, 20); }
    loadingLibrary = false;
  }
  // Delete the database row first, then its page files — the storage cleanup policy only permits
  // removing a page file once no ai_generated_flyers row references it any more (see
  // 20260909_ai_generated_flyers_delete.sql), so this order must not be reversed.
  async function deleteFlyer(row: any) {
    if (deletingId || previewBusy) return;
    if (!confirm(`Delete "${row.title}"? This cannot be undone.`)) return;
    deletingId = row.id; libraryError = '';
    try {
      const result = await supabase.from('ai_generated_flyers').delete().eq('id', row.id);
      if (result.error) throw result.error;
      await supabase.storage.from(bucket).remove(row.page_paths);
      library = library.filter(r => r.id !== row.id);
    } catch (e) { libraryError = e instanceof Error ? e.message : 'Could not delete this flyer.'; }
    finally { deletingId = ''; }
  }
  async function openPreview(row: any) {
    previewBusy = true; libraryError = ''; improvedPages = []; improveError = ''; success = '';
    try {
      const result = await supabase.storage.from(bucket).createSignedUrls(row.page_paths, 3600);
      if (result.error || result.data?.some((p: any) => !p.signedUrl)) throw new Error('Could not load all saved pages.');
      preview = { id: row.id, title: row.title, pages: result.data.map((p: any) => p.signedUrl), pagePaths: row.page_paths, context: row.context || null };
    } catch (e) { libraryError = e instanceof Error ? e.message : 'Preview failed.'; }
    finally { previewBusy = false; }
  }

  // Runs every saved page through the fixed "improve, change nothing it says" AI pass — one
  // request per page, same as generation. Each page's own result replaces its placeholder in
  // improvedPages as soon as ITS OWN request finishes, instead of waiting for every page before
  // showing anything. Starting from the originals (rather than empty) keeps all pages visible
  // throughout, so a still-in-progress page just shows its unimproved original until its turn
  // comes up. Nothing in storage changes until acceptImprovement() runs.
  async function improveFlyer() {
    if (!preview || improving) return;
    improving = true; improveError = ''; improvedPages = [...preview.pages];
    try {
      for (let i = 0; i < preview.pages.length; i++) {
        progress = `Improving page ${i + 1} of ${preview.pages.length}…`;
        // Send the page's own signed Storage URL rather than uploading its bytes: this app runs on
        // Vercel, whose functions hard-cap the incoming request body at 4.5MB regardless of any
        // app-level check — a captured flyer page routinely exceeds that (worked on `vite dev`,
        // which has no such limit, but 413'd in production). The endpoint fetches the image itself
        // from Storage instead, which isn't subject to that cap.
        const response = await fetch('/api/ai-flyers/improve', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          // Reuse this flyer's own saved context (from generation) so Improve enhances it without
          // drifting into a different theme — see offer_context_ai_flyer_spec.md §9.
          body: JSON.stringify({ pageUrl: preview.pages[i], contextName: preview.context?.name, contextDescription: preview.context?.description }),
          signal: AbortSignal.timeout(285000)
        });
        // A platform-level rejection (a gateway/proxy 413, 502, etc.) never returns our own JSON
        // error shape, and .json() throwing on that would otherwise surface as an opaque "Unexpected
        // token" parse error instead of something a user can act on.
        if (!response.ok) {
          const failure = await response.json().catch(() => null);
          throw new Error(failure?.error || `Could not improve page ${i + 1} (server responded ${response.status}).`);
        }
        improvedPages[i] = URL.createObjectURL(await response.blob());
        improvedPages = [...improvedPages]; // reassign so this page's tile updates right away
      }
    } catch (e) {
      improveError = e instanceof Error ? e.message : 'Could not improve this flyer.';
      // Discard the whole attempt rather than accept a partial mix of improved and untouched
      // pages — Done should only ever mean "every page here was actually improved."
      improvedPages.forEach((url, i) => { if (url !== preview!.pages[i]) URL.revokeObjectURL(url); });
      improvedPages = [];
    } finally { improving = false; progress = ''; }
  }

  // Replaces the saved pages in storage with the reviewed improved versions, at the exact same
  // paths — the database record (title, page_count, page_paths, snapshot) is untouched, since
  // only the page images themselves changed.
  async function acceptImprovement() {
    if (!preview || !improvedPages.length || busy || improving) return;
    busy = true; error = '';
    try {
      for (let i = 0; i < improvedPages.length; i++) {
        progress = `Saving improved page ${i + 1} of ${improvedPages.length}…`;
        const result = await supabase.storage.from(bucket).upload(preview.pagePaths[i], await pageBlob(improvedPages[i]), { contentType: 'image/png', upsert: true });
        if (result.error) throw result.error;
      }
      preview.pages.forEach(url => URL.revokeObjectURL(url));
      preview = { ...preview, pages: improvedPages };
      improvedPages = [];
      success = 'Improved flyer saved.';
    } catch (e) { error = e instanceof Error ? e.message : 'Could not save the improved flyer.'; }
    finally { busy = false; progress = ''; }
  }
  function discardImprovement() {
    improvedPages.forEach(URL.revokeObjectURL);
    improvedPages = []; improveError = '';
  }
  function closePreview() {
    if (busy || improving) return;
    discardImprovement();
    preview = null;
  }
  function focusDialog(node: HTMLElement) {
    const previous = document.activeElement as HTMLElement | null;
    node.focus();
    function keydown(event: KeyboardEvent) {
      if (event.key === 'Escape') { event.preventDefault(); closePreview(); }
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
      <label>Offer context<select bind:value={contextId} disabled={busy} title={selectedContext?.description || ''}>{#each contexts as context}<option value={context.id}>{context.name}</option>{/each}</select></label>
      <button disabled={!offerId || !offerName.trim() || !contextId || busy || loadingThemes} on:click={getColorOptions}>{loadingThemes ? 'Getting options…' : 'Get Color Options'}</button>
    </div>
    {#if selectedContext}<p class="hint">Internal AI guidance only — never printed on the flyer: {selectedContext.description}</p>{/if}
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
      <div class="table-scroll"><table><thead><tr><th>Flyer</th><th>Offer dates</th><th>Products</th><th>Pages</th><th>Saved</th><th>Action</th></tr></thead><tbody>{#each library as row}<tr><td>{row.title}</td><td>{row.start_date} — {row.end_date}</td><td>{row.product_count}</td><td>{row.page_count}</td><td>{new Date(row.created_at).toLocaleString()}</td><td class="row-actions"><button disabled={previewBusy || !!deletingId} on:click={() => openPreview(row)}>Preview</button><button disabled={previewBusy || !!deletingId} on:click={() => deleteFlyer(row)}>{deletingId === row.id ? 'Deleting…' : 'Delete'}</button></td></tr>{/each}</tbody></table></div>
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
      <div class="toolbar">
        <h2>{preview.title}</h2>
        {#if improvedPages.length}
          <button class="primary" disabled={busy || improving} title={improving ? 'Wait for every page to finish improving first' : ''} on:click={acceptImprovement}>Done</button>
          <button disabled={busy || improving} on:click={discardImprovement}>Discard</button>
        {:else}
          <button disabled={busy} on:click={() => downloadPng(preview!.pages, preview!.title)}>Download PNG</button>
          <button disabled={busy} on:click={() => downloadPdf(preview!.pages, preview!.title)}>Download as PDF</button>
          <button disabled={busy || improving} on:click={improveFlyer}>{improving ? 'Improving…' : '✨ Improve'}</button>
          <button disabled={improving} on:click={closePreview}>Close</button>
        {/if}
      </div>
      {#if improvedPages.length}<p class="hint">Reviewing the improved version — press Done to replace the saved flyer, or Discard to keep the original.</p>{/if}
      {#if progress}<p role="status">{progress}</p>{/if}
      {#if error}<p class="error" role="alert">{error}</p>{/if}
      {#if improveError}<p class="error" role="alert">{improveError}</p>{/if}
      {#if success}<p class="success" role="status">{success}</p>{/if}
      <div class="saved-pages">{#each (improvedPages.length ? improvedPages : preview.pages) as page, i}<figure><img src={page} alt={`Saved flyer page ${i + 1}`} /><figcaption>Page {i + 1}</figcaption></figure>{/each}</div>
    </div>
  </div>
{/if}

<style>
  .ai-workspace{padding:24px;color:#172033;background:#f5f7fb;min-height:100%;}h2{font-size:22px;font-weight:700;margin:0;}p{margin:12px 0;color:#475569;}.toolbar{display:flex;flex-wrap:wrap;gap:12px;align-items:end;margin:18px 0;}.toolbar h2{margin-right:auto;align-self:center;}label{display:flex;flex-direction:column;gap:6px;font-size:14px;font-weight:600;flex:1;min-width:200px;}select,input{background:white;border:1px solid #cbd5e1;border-radius:8px;padding:10px;color:#172033;width:100%;}button{padding:10px 16px;border:1px solid #cbd5e1;background:white;border-radius:8px;font-weight:600;color:#172033;cursor:pointer;}button.primary{background:#4338ca;color:white;border-color:#4338ca;}button:disabled{opacity:.5;cursor:not-allowed;}.error{background:#fef2f2;color:#991b1b;padding:12px;border-radius:8px;overflow-wrap:anywhere;}.success{background:#ecfdf5;color:#065f46;padding:12px;border-radius:8px;}.hint{font-size:12px;}.theme-options{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;margin:0 0 18px;}.theme-option{display:flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid #cbd5e1;border-radius:8px;background:white;font-size:13px;font-weight:600;cursor:pointer;}.theme-option.selected{border-color:#4338ca;background:#eef2ff;color:#3730a3;}.theme-option input{margin:0;}.previews{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;}figure{margin:0;}figure img{width:100%;height:auto;background:white;box-shadow:0 2px 10px #0002;}figcaption{text-align:center;padding:8px;font-size:13px;}.tile-placeholder{aspect-ratio:2/3;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;background:white;box-shadow:0 2px 10px #0002;border-radius:4px;color:#64748b;font-size:13px;}.spinner{width:26px;height:26px;border:3px solid #c7d2fe;border-top-color:#4338ca;border-radius:50%;animation:spin 1s linear infinite;}@keyframes spin{to{transform:rotate(360deg);}}.tile-error{color:#991b1b;padding:16px;text-align:center;gap:12px;}.tile-error p{margin:0;color:inherit;}.render-host{position:fixed;left:-12000px;top:0;width:794px;pointer-events:none;}.table-scroll{overflow:auto;}.row-actions{display:flex;gap:8px;}table{width:100%;border-collapse:collapse;background:white;}th,td{padding:12px;text-align:left;border-bottom:1px solid #e2e8f0;}th{background:#eef2ff;font-size:13px;}.preview-overlay{position:fixed;inset:0;background:#0f172acc;z-index:10050;padding:24px;display:flex;justify-content:center;}.preview-dialog{background:#f5f7fb;border-radius:12px;overflow:auto;padding:24px;width:min(1050px,100%);}.saved-pages{max-width:794px;margin:auto;display:grid;gap:24px;}
</style>
