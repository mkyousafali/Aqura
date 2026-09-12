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
  let preview: { id: string; title: string; pages: string[]; pagePaths: string[]; startDate: string; endDate: string; context: { id: string; name: string; description: string } | null; publications: FlyerPublication[] } | null = null;
  let previewBusy = false;
  // Publish: links a saved flyer to real, scheduled row(s) in view_offer — the same table the
  // Login page, Offers page and the WhatsApp Live Chat AI already read live offers from. A flyer
  // can be published to several branches at once, independently — each is one row in
  // ai_flyer_publications, carrying which of the flyer's pages that branch's publication covers.
  interface PublishedOffer { status: 'published' | 'unpublished' | 'expired'; start_date: string; start_time: string; end_date: string; end_time: string }
  interface FlyerPublication { branch_id: number; page_paths: string[]; offer: PublishedOffer }
  let branches: { id: number; name_en: string; name_ar: string; location_en: string; location_ar: string }[] = [];
  // publishingBranchId: the branch this dialog session is editing (null while adding a new one).
  let publishTarget: { id: string; title: string; pagePaths: string[]; startDate: string; endDate: string; publishingBranchId: number | null; publications: FlyerPublication[] } | null = null;
  let publishing = false;
  let publishError = '';
  let unpublishingKey: string | null = null; // `${flyerId}:${branchId}` of the publication currently being unpublished
  let publishBranchId = '';
  let publishOfferName = '';
  let publishStartDate = '', publishStartDateDisplay = '';
  let publishStartHour = '12', publishStartMinute = '00', publishStartPeriod = 'AM';
  let publishEndDate = '', publishEndDateDisplay = '';
  let publishEndHour = '11', publishEndMinute = '59', publishEndPeriod = 'PM';
  // Page checklist in the Publish dialog — parallel arrays to publishTarget.pagePaths.
  let publishPageChecked: boolean[] = [];
  let publishPageThumbs: string[] = [];
  // Reviewing an AI "Improve" pass before committing it — parallel to preview.pages; empty
  // means nothing has been improved yet (still showing the saved originals).
  let improvedPages: string[] = [];
  let improving = false;
  let improveError = '';
  // Region Edit: regenerates one small, user-drawn box on a single saved page, instead of the
  // whole page (see /api/ai-flyers/edit-region). editIndex is which page in preview.pages/pagePaths
  // is being edited (null = the edit overlay is closed). Box coordinates are always kept in the
  // page image's own real pixel space (not on-screen CSS px) — toEditDisplayBox() converts to
  // on-screen px only for rendering the drawn rectangle.
  let editIndex: number | null = null;
  let editImgEl: HTMLImageElement;
  let editDrawing = false;
  let editDragStartReal: { x: number; y: number } | null = null;
  let editBox: { x: number; y: number; width: number; height: number } | null = null;
  let editInstruction = '';
  let editBusy = false;
  let editError = '';
  // Set once an edit comes back from the AI — the full composited page, awaiting Accept/Discard,
  // same review-before-commit shape as the Improve flow.
  let editResultUrl = '';
  const editInstructionChips = ['أضف شارة عرض', 'غيّر الكمية إلى 1 فقط', 'احذف هذه الشارة', 'صحّح هذا النص', 'غيّر منطقة السعر فقط', 'غيّر شكل الشارة'];
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
    // One RPC round trip instead of three separate table reads.
    const { data, error: initError } = await supabase.rpc('get_ai_flyer_generator_init_data');
    if (initError || !data?.success) {
      error = `Could not load offers: ${initError?.message || data?.error || 'unknown error'}`;
      return;
    }
    offers = data.offers || [];
    contexts = data.contexts || [];
    // "General Supermarket Offer" is seeded first (sort_order 0) — the required default per spec,
    // since most promotions mix products from several departments.
    if (!contextId && contexts.length) contextId = contexts[0].id;
    branches = data.branches || [];
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
  // Shared by the Download-as-PDF button and Publish (which needs the PDF bytes to store, not
  // hand to the browser) — one PDF page per flyer page, sized to that page's real dimensions.
  async function buildPdfBlob(pages: string[]): Promise<Blob | null> {
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
    return pdf ? pdf.output('blob') : null;
  }
  async function downloadPdf(pages = flyerPages.filter(p => p.status === 'done').map(p => p.url), name = title) {
    if (busy) return;
    busy = true; error = '';
    try {
      const pdf = await buildPdfBlob(pages);
      if (pdf) download(pdf, `${fileName(name)}.pdf`);
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
      await saveFlyerRecord(id, paths);
      savedId = id; success = 'Flyer saved. You can find it in AI Generated Flyers.';
    } catch (e) {
      if (paths.length) await supabase.storage.from(bucket).remove(paths);
      error = e instanceof Error ? e.message : (e as any)?.message || 'Save failed.';
    } finally { busy = false; progress = ''; }
  }

  // create_ai_generated_flyer inserts with ON CONFLICT (id) DO NOTHING, so it's safe to retry
  // with the same client-generated id — a retry after an ambiguous network failure either
  // confirms the first attempt already landed or completes it, instead of erroring. One retry
  // replaces the old "check if it already landed" follow-up query.
  async function saveFlyerRecord(id: string, paths: string[], retried = false): Promise<void> {
    try {
      const { data, error: rpcError } = await supabase.rpc('create_ai_generated_flyer', {
        p_id: id,
        p_offer_id: snapshot!.offer.id,
        p_title: title.trim() || 'AI Flyer',
        p_start_date: snapshot!.offer.start_date,
        p_end_date: snapshot!.offer.end_date,
        p_page_count: paths.length,
        p_product_count: snapshot!.products.length,
        p_page_paths: paths,
        p_snapshot: snapshot,
        p_model: snapshot!.model
      });
      if (rpcError) throw rpcError;
      if (!data?.success) throw new Error(data?.error || 'Save failed.');
    } catch (e) {
      if (retried) throw e;
      await saveFlyerRecord(id, paths, true);
    }
  }

  // get_ai_flyer_library excludes any flyer whose every publication has already expired (still
  // shows one that was never published, or still has a live/paused publication) — filtered and
  // paginated server-side, so "has more" stays correct instead of a client-side filter shrinking
  // an already-sliced page.
  async function loadLibrary() {
    loadingLibrary = true; libraryError = ''; success = '';
    const { data, error: rpcError } = await supabase.rpc('get_ai_flyer_library', { p_page: libraryPage, p_page_size: 20 });
    if (rpcError || !data?.success) libraryError = `Could not load saved flyers: ${rpcError?.message || data?.error || 'unknown error'}`;
    else { hasMore = !!data.has_more; library = data.data || []; }
    loadingLibrary = false;
  }
  // A flyer can be published to several branches at once — one badge per publication, instead of
  // one badge per flyer. Published / Unpublished / Expired — same 4-state idea as the status pill
  // already used for customer-app offers (OfferManagement.svelte); no publications at all just
  // shows nothing (the row/dialog falls back to "Not Published" text elsewhere).
  function publicationStatusBadge(pub: FlyerPublication): { text: string; cls: string } {
    const status = pub.offer?.status;
    if (status === 'published') return { text: 'Published', cls: 'status-published' };
    if (status === 'unpublished') return { text: 'Unpublished', cls: 'status-unpublished' };
    if (status === 'expired') return { text: 'Expired', cls: 'status-expired' };
    return { text: status || '', cls: 'status-none' };
  }
  function branchLabel(branchId: number): string {
    const b = branches.find(x => x.id === branchId);
    return b ? (b.location_en ? `${b.name_en} — ${b.location_en}` : b.name_en) : `Branch ${branchId}`;
  }
  // Delete the database row first, then its page files — the storage cleanup policy only permits
  // removing a page file once no ai_generated_flyers row references it any more (see
  // 20260909_ai_generated_flyers_delete.sql), so this order must not be reversed.
  async function deleteFlyer(row: any) {
    if (deletingId || previewBusy) return;
    if (!confirm(`Delete "${row.title}"? This cannot be undone.`)) return;
    deletingId = row.id; libraryError = '';
    try {
      const { data, error: rpcError } = await supabase.rpc('delete_ai_generated_flyer', { p_id: row.id });
      if (rpcError) throw rpcError;
      if (!data?.success) throw new Error(data?.error || 'Delete failed.');
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
      preview = { id: row.id, title: row.title, pages: result.data.map((p: any) => p.signedUrl), pagePaths: row.page_paths, startDate: row.start_date, endDate: row.end_date, context: row.context || null, publications: row.publications || [] };
    } catch (e) { libraryError = e instanceof Error ? e.message : 'Preview failed.'; }
    finally { previewBusy = false; }
  }

  // Date/time conversion helpers — same shape as AddOfferDialog.svelte's (that dialog owns the
  // only other start/end date+time UI in this app), duplicated here rather than shared since
  // that's the existing convention (ViewOfferManager.svelte also keeps its own copy).
  function toISODate(displayDate: string): string {
    if (!displayDate) return '';
    const parts = displayDate.split('/');
    if (parts.length !== 3) return displayDate;
    const [day, month, year] = parts;
    return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
  }
  function toDisplayDate(isoDate: string): string {
    if (!isoDate) return '';
    const [year, month, day] = isoDate.split('-');
    return `${day}/${month}/${year}`;
  }
  // Read-only admin-UI display (offer dropdown, library table) — dd-mm-yyyy / 12-hour, distinct
  // from toDisplayDate above (which feeds the editable Publish date inputs and must stay
  // slash-separated to match toISODate's parsing).
  function formatDisplayDate(isoDate: string): string {
    if (!isoDate) return '';
    const [year, month, day] = isoDate.split('-');
    return `${day}-${month}-${year}`;
  }
  function formatDisplayDateTime(isoTimestamp: string): string {
    if (!isoTimestamp) return '';
    const d = new Date(isoTimestamp);
    const day = String(d.getDate()).padStart(2, '0');
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const year = d.getFullYear();
    let hours = d.getHours();
    const minutes = String(d.getMinutes()).padStart(2, '0');
    const period = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12; if (hours === 0) hours = 12;
    return `${day}-${month}-${year}, ${String(hours).padStart(2, '0')}:${minutes} ${period}`;
  }
  function convert12HourTo24Hour(hour: string, period: string): string {
    let h = parseInt(hour, 10);
    if (period === 'PM' && h !== 12) h += 12;
    if (period === 'AM' && h === 12) h = 0;
    return String(h).padStart(2, '0');
  }
  function to12Hour(time24: string): [string, string, string] {
    if (!time24) return ['12', '00', 'AM'];
    const [hStr, mStr] = time24.split(':');
    let h = parseInt(hStr, 10);
    const period = h >= 12 ? 'PM' : 'AM';
    if (h === 0) h = 12; else if (h > 12) h -= 12;
    return [String(h).padStart(2, '0'), (mStr || '00').padStart(2, '0'), period];
  }

  // Publish: opens with sensible defaults. Passing an existing branchId edits that branch's own
  // publication (its saved schedule + exactly the pages it currently includes, so "Republish"
  // mostly means "confirm"); omitting it starts a fresh publication to a NEW branch (every page
  // checked by default) — the flyer's other branches, if any, are left completely untouched
  // either way, since each is its own row in ai_flyer_publications.
  // Accepts either a library row (page_paths/start_date/end_date) or the open preview object
  // (pagePaths/startDate/endDate) — both carry the same flyer, just under different field names.
  function openPublishDialog(row: any, branchId: number | null = null) {
    publishError = '';
    const pagePaths: string[] = row.page_paths || row.pagePaths;
    const startDate = row.start_date || row.startDate;
    const endDate = row.end_date || row.endDate;
    const publications: FlyerPublication[] = row.publications || [];
    publishTarget = { id: row.id, title: row.title, pagePaths, startDate, endDate, publishingBranchId: branchId, publications };
    publishOfferName = row.title;
    const existing = branchId != null ? publications.find(p => p.branch_id === branchId) : undefined;
    if (existing) {
      publishBranchId = String(branchId);
      publishStartDate = existing.offer.start_date; publishStartDateDisplay = toDisplayDate(existing.offer.start_date);
      [publishStartHour, publishStartMinute, publishStartPeriod] = to12Hour(existing.offer.start_time);
      publishEndDate = existing.offer.end_date; publishEndDateDisplay = toDisplayDate(existing.offer.end_date);
      [publishEndHour, publishEndMinute, publishEndPeriod] = to12Hour(existing.offer.end_time);
      publishPageChecked = pagePaths.map(p => existing.page_paths.includes(p));
    } else {
      publishBranchId = '';
      publishStartDate = startDate; publishStartDateDisplay = toDisplayDate(startDate);
      publishStartHour = '12'; publishStartMinute = '00'; publishStartPeriod = 'AM';
      publishEndDate = endDate; publishEndDateDisplay = toDisplayDate(endDate);
      publishEndHour = '11'; publishEndMinute = '59'; publishEndPeriod = 'PM';
      publishPageChecked = pagePaths.map(() => true);
    }
    publishPageThumbs = pagePaths.map(() => '');
    loadPublishPageThumbs(pagePaths);
  }
  async function loadPublishPageThumbs(pagePaths: string[]) {
    try {
      const result = await supabase.storage.from(bucket).createSignedUrls(pagePaths, 3600);
      if (!result.error) publishPageThumbs = (result.data || []).map((p: any) => p?.signedUrl || '');
    } catch { /* thumbnails are a nice-to-have, never block the dialog */ }
  }
  function closePublishDialog() {
    if (publishing) return;
    publishTarget = null; publishError = ''; publishPageChecked = []; publishPageThumbs = [];
  }

  // Publishing needs an actual stored PDF/thumbnail (not the 1-hour signed URLs the flyer's own
  // private bucket hands out) — builds one via the same logic as Download-as-PDF, from only the
  // CHECKED pages, then uploads it to the public offer-pdfs bucket AddOfferDialog.svelte already
  // uses, and finally calls the publish_ai_flyer RPC to do the view_offer insert/update + link +
  // log atomically for this one branch, leaving any of the flyer's other branch publications
  // (if any) completely untouched.
  async function submitPublish() {
    if (!publishTarget || publishing) return;
    if (!publishBranchId || !publishOfferName.trim() || !publishStartDate || !publishEndDate) {
      publishError = 'Please fill in the branch, offer name and both dates.';
      return;
    }
    if (!publishPageChecked.some(Boolean)) {
      publishError = 'Select at least one page to publish.';
      return;
    }
    const startTime24 = convert12HourTo24Hour(publishStartHour, publishStartPeriod) + ':' + publishStartMinute;
    const endTime24 = convert12HourTo24Hour(publishEndHour, publishEndPeriod) + ':' + publishEndMinute;
    if (new Date(`${publishStartDate}T${startTime24}`) >= new Date(`${publishEndDate}T${endTime24}`)) {
      publishError = 'End date/time must be after start date/time.';
      return;
    }

    publishing = true; publishError = '';
    try {
      // Reuse the open preview's signed page URLs when publishing from there; otherwise fetch
      // fresh ones (the flyer's own bucket is private — there's no other way to read a page).
      const allPageUrls = preview && preview.id === publishTarget.id ? preview.pages : await (async () => {
        const result = await supabase.storage.from(bucket).createSignedUrls(publishTarget!.pagePaths, 3600);
        if (result.error || result.data?.some((p: any) => !p.signedUrl)) throw new Error("Could not read this flyer's pages.");
        return result.data.map((p: any) => p.signedUrl as string);
      })();
      const selectedPagePaths = publishTarget.pagePaths.filter((_, i) => publishPageChecked[i]);
      const pageUrls = allPageUrls.filter((_, i) => publishPageChecked[i]);

      const pdfBlob = await buildPdfBlob(pageUrls);
      if (!pdfBlob) throw new Error('Could not build a PDF from this flyer.');
      const thumbBlob = await pageBlob(pageUrls[0]);

      // File names include the branch, since the same flyer can now be published to several
      // branches at once — each needs its own stored PDF/thumbnail, not a shared one.
      const pdfPath = `ai-flyer-${publishTarget.id}-${publishBranchId}.pdf`;
      const thumbPath = `ai-flyer-thumb-${publishTarget.id}-${publishBranchId}.png`;
      const [pdfUpload, thumbUpload] = await Promise.all([
        supabase.storage.from('offer-pdfs').upload(pdfPath, pdfBlob, { contentType: 'application/pdf', upsert: true }),
        supabase.storage.from('offer-pdfs').upload(thumbPath, thumbBlob, { contentType: 'image/png', upsert: true })
      ]);
      if (pdfUpload.error) throw pdfUpload.error;
      if (thumbUpload.error) throw thumbUpload.error;
      const fileUrl = supabase.storage.from('offer-pdfs').getPublicUrl(pdfPath).data.publicUrl;
      const thumbnailUrl = supabase.storage.from('offer-pdfs').getPublicUrl(thumbPath).data.publicUrl;

      const rpc = await supabase.rpc('publish_ai_flyer', {
        p_flyer_id: publishTarget.id,
        p_branch_id: Number(publishBranchId),
        p_offer_name: publishOfferName.trim(),
        p_start_date: publishStartDate,
        p_start_time: startTime24,
        p_end_date: publishEndDate,
        p_end_time: endTime24,
        p_file_url: fileUrl,
        p_thumbnail_url: thumbnailUrl,
        p_page_paths: selectedPagePaths
      });
      if (rpc.error) throw rpc.error;

      const publishedId = publishTarget.id;
      publishTarget = null; publishPageChecked = []; publishPageThumbs = [];
      await loadLibrary();
      success = 'Flyer published.';
      if (preview && preview.id === publishedId) preview = { ...preview, publications: library.find(r => r.id === publishedId)?.publications || [] };
    } catch (e) {
      publishError = e instanceof Error ? e.message : 'Could not publish this flyer.';
    } finally { publishing = false; }
  }

  async function unpublishFlyer(row: any, branchId: number) {
    const key = `${row.id}:${branchId}`;
    if (unpublishingKey) return;
    if (!confirm(`Unpublish "${row.title}" from ${branchLabel(branchId)}? It stops showing on the Login/Offers pages and stops being sent by the WhatsApp AI immediately for that branch.`)) return;
    unpublishingKey = key; libraryError = '';
    try {
      const result = await supabase.rpc('unpublish_ai_flyer', { p_flyer_id: row.id, p_branch_id: branchId });
      if (result.error) throw result.error;
      await loadLibrary();
      success = 'Flyer unpublished.';
      if (preview && preview.id === row.id) preview = { ...preview, publications: library.find(r => r.id === row.id)?.publications || [] };
    } catch (e) { libraryError = e instanceof Error ? e.message : 'Could not unpublish this flyer.'; }
    finally { unpublishingKey = null; }
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
    if (busy || improving || editBusy) return;
    discardImprovement();
    closeRegionEdit();
    preview = null;
  }

  // ─── Region Edit: regenerate one drawn box on one page, not the whole page ─────────────────
  function loadImageEl(src: string): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Could not load an image.'));
      img.src = src;
    });
  }
  const EDIT_MIN_BOX = 12; // real image px — smaller than this is treated as an accidental click, not a drawn box

  function openRegionEdit(index: number) {
    if (busy || improving || editBusy || improvedPages.length) return;
    editIndex = index; editBox = null; editInstruction = ''; editError = ''; editResultUrl = '';
  }
  function closeRegionEdit() {
    if (editBusy) return;
    if (editResultUrl) URL.revokeObjectURL(editResultUrl);
    editIndex = null; editBox = null; editDrawing = false; editDragStartReal = null;
    editInstruction = ''; editError = ''; editResultUrl = '';
  }
  // Cancels only the current box/result, keeping the overlay open on the same page so the user
  // can immediately draw the next one — the "select another area and make the next change" step.
  function resetEditBox() {
    if (editResultUrl) URL.revokeObjectURL(editResultUrl);
    editBox = null; editDrawing = false; editDragStartReal = null; editInstruction = ''; editError = ''; editResultUrl = '';
  }

  // Converts a pointer event to the page image's own real pixel space, regardless of how large
  // the <img> is actually rendered on screen (it's shown scaled-to-fit, not at 1:1).
  function editPointToReal(e: PointerEvent): { x: number; y: number } {
    const rect = editImgEl.getBoundingClientRect();
    const scaleX = editImgEl.naturalWidth / rect.width, scaleY = editImgEl.naturalHeight / rect.height;
    return {
      x: Math.max(0, Math.min(editImgEl.naturalWidth, (e.clientX - rect.left) * scaleX)),
      y: Math.max(0, Math.min(editImgEl.naturalHeight, (e.clientY - rect.top) * scaleY))
    };
  }
  // The inverse — real image px back to on-screen CSS px — so the drawn-box overlay div lines up
  // with the image exactly as it's currently displayed.
  function toEditDisplayBox(box: { x: number; y: number; width: number; height: number }) {
    const rect = editImgEl.getBoundingClientRect();
    const scaleX = rect.width / editImgEl.naturalWidth, scaleY = rect.height / editImgEl.naturalHeight;
    return { left: box.x * scaleX, top: box.y * scaleY, width: box.width * scaleX, height: box.height * scaleY };
  }

  function startEditBox(e: PointerEvent) {
    if (editBusy || editResultUrl || !editImgEl?.naturalWidth) return;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    editDragStartReal = editPointToReal(e);
    editBox = { x: editDragStartReal.x, y: editDragStartReal.y, width: 0, height: 0 };
    editDrawing = true;
  }
  function moveEditBox(e: PointerEvent) {
    if (!editDrawing || !editDragStartReal) return;
    const cur = editPointToReal(e);
    editBox = {
      x: Math.min(editDragStartReal.x, cur.x), y: Math.min(editDragStartReal.y, cur.y),
      width: Math.abs(cur.x - editDragStartReal.x), height: Math.abs(cur.y - editDragStartReal.y)
    };
  }
  function endEditBox() {
    if (!editDrawing) return;
    editDrawing = false;
    // Too small to be a deliberate box — treat as an accidental click, not a selection.
    if (!editBox || editBox.width < EDIT_MIN_BOX || editBox.height < EDIT_MIN_BOX) editBox = null;
  }

  async function cropRegionDataUrl(imgUrl: string, box: { x: number; y: number; width: number; height: number }): Promise<string> {
    const img = await pageBlob(imgUrl).then(b => loadImageEl(URL.createObjectURL(b)));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(box.width)); canvas.height = Math.max(1, Math.round(box.height));
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(img, box.x, box.y, box.width, box.height, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/png');
  }
  // Pastes the AI's edited crop back onto the full page at the exact drawn-box coordinates —
  // force-fit to the box's own dimensions (drawImage's scaling form) regardless of whatever
  // resolution the AI actually returned, so the result always lands pixel-exact on the box.
  async function compositeEditedRegion(fullImgUrl: string, box: { x: number; y: number; width: number; height: number }, editedBlob: Blob): Promise<string> {
    const [fullImg, editedImg] = await Promise.all([
      pageBlob(fullImgUrl).then(b => loadImageEl(URL.createObjectURL(b))),
      loadImageEl(URL.createObjectURL(editedBlob))
    ]);
    const canvas = document.createElement('canvas');
    canvas.width = fullImg.naturalWidth; canvas.height = fullImg.naturalHeight;
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(fullImg, 0, 0);
    ctx.drawImage(editedImg, 0, 0, editedImg.naturalWidth, editedImg.naturalHeight, box.x, box.y, box.width, box.height);
    return canvas.toDataURL('image/png');
  }

  async function submitRegionEdit() {
    if (editIndex === null || !editBox || !editInstruction.trim() || editBusy || !preview) return;
    editBusy = true; editError = '';
    try {
      const pageUrl = preview.pages[editIndex];
      const cropUrl = await cropRegionDataUrl(pageUrl, editBox);
      const response = await fetch('/api/ai-flyers/edit-region', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ imageDataUrl: cropUrl, instruction: editInstruction.trim(), contextName: preview.context?.name, contextDescription: preview.context?.description }),
        signal: AbortSignal.timeout(110000)
      });
      if (!response.ok) {
        const failure = await response.json().catch(() => null);
        throw new Error(failure?.error || `Could not edit this region (server responded ${response.status}).`);
      }
      const editedBlob = await response.blob();
      editResultUrl = await compositeEditedRegion(pageUrl, editBox, editedBlob);
    } catch (e) { editError = e instanceof Error ? e.message : 'Could not edit this region.'; }
    finally { editBusy = false; }
  }
  async function acceptRegionEdit() {
    if (editIndex === null || !editResultUrl || !preview || editBusy) return;
    editBusy = true; editError = '';
    try {
      const path = preview.pagePaths[editIndex];
      const result = await supabase.storage.from(bucket).upload(path, await pageBlob(editResultUrl), { contentType: 'image/png', upsert: true });
      if (result.error) throw result.error;
      const newPages = [...preview.pages];
      newPages[editIndex] = editResultUrl; // keep using the local composited data URL — no need to re-sign
      preview = { ...preview, pages: newPages };
      // Ready for the next box on this same page, per "select another area and make the next change."
      editBox = null; editInstruction = ''; editResultUrl = '';
    } catch (e) { editError = e instanceof Error ? e.message : 'Could not save this edit.'; }
    finally { editBusy = false; }
  }
  function discardRegionEdit() {
    resetEditBox();
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
      <label>Active offer<select bind:value={offerId} on:change={changeOffer} disabled={busy}><option value="">Select an offer</option>{#each offers as offer}<option value={offer.id}>{offer.offer_names?.name_en || offer.offer_names?.name_ar || offer.template_name} · {formatDisplayDate(offer.start_date)} — {formatDisplayDate(offer.end_date)}</option>{/each}</select></label>
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
      <div class="table-scroll"><table><thead><tr><th>Flyer</th><th>Offer dates</th><th>Products</th><th>Pages</th><th>Saved</th><th>Published to</th><th>Action</th></tr></thead><tbody>{#each library as row}<tr><td>{row.title}</td><td>{formatDisplayDate(row.start_date)} — {formatDisplayDate(row.end_date)}</td><td>{row.product_count}</td><td>{row.page_count}</td><td>{formatDisplayDateTime(row.created_at)}</td><td class="pub-chips"><div class="pub-chips">{#if row.publications?.length}{#each row.publications as pub (pub.branch_id)}<span class="status-badge {publicationStatusBadge(pub).cls}">{branchLabel(pub.branch_id)}: {publicationStatusBadge(pub).text}{#if pub.offer?.status === 'published'}<button type="button" class="chip-x" title={`Unpublish from ${branchLabel(pub.branch_id)}`} disabled={previewBusy || !!deletingId || unpublishingKey === `${row.id}:${pub.branch_id}`} on:click={() => unpublishFlyer(row, pub.branch_id)}>✕</button>{/if}</span>{/each}{:else}<span class="status-badge status-none">Not Published</span>{/if}</div></td><td><div class="row-actions"><button disabled={previewBusy || !!deletingId} on:click={() => openPreview(row)}>Preview</button><button disabled={previewBusy || !!deletingId} on:click={() => openPublishDialog(row)}>Publish</button><button disabled={previewBusy || !!deletingId} on:click={() => deleteFlyer(row)}>{deletingId === row.id ? 'Deleting…' : 'Delete'}</button></div></td></tr>{/each}</tbody></table></div>
      <div class="toolbar"><button disabled={!libraryPage || loadingLibrary} on:click={() => { libraryPage--; loadLibrary(); }}>Previous</button><span>Page {libraryPage + 1}</span><button disabled={!hasMore || loadingLibrary} on:click={() => { libraryPage++; loadLibrary(); }}>Next</button></div>
    {/if}
  {/if}
  {#if progress}<p role="status">{progress}</p>{/if}
  {#if error}<p class="error" role="alert">{error}</p>{/if}
  {#if success}<p class="success" role="status">{success}</p>{/if}
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
        {#if !improvedPages.length}
          <div class="pub-chips">{#if preview.publications.length}{#each preview.publications as pub (pub.branch_id)}<span class="status-badge {publicationStatusBadge(pub).cls}">{branchLabel(pub.branch_id)}: {publicationStatusBadge(pub).text}{#if pub.offer?.status === 'published'}<button type="button" class="chip-x" title={`Unpublish from ${branchLabel(pub.branch_id)}`} disabled={busy || improving || unpublishingKey === `${preview.id}:${pub.branch_id}`} on:click={() => unpublishFlyer(preview!, pub.branch_id)}>✕</button>{/if}</span>{/each}{:else}<span class="status-badge status-none">Not Published</span>{/if}</div>
        {/if}
        {#if improvedPages.length}
          <button class="primary" disabled={busy || improving} title={improving ? 'Wait for every page to finish improving first' : ''} on:click={acceptImprovement}>Done</button>
          <button disabled={busy || improving} on:click={discardImprovement}>Discard</button>
        {:else}
          <button disabled={busy} on:click={() => downloadPng(preview!.pages, preview!.title)}>Download PNG</button>
          <button disabled={busy} on:click={() => downloadPdf(preview!.pages, preview!.title)}>Download as PDF</button>
          <button disabled={busy || improving} on:click={improveFlyer}>{improving ? 'Improving…' : '✨ Improve'}</button>
          <button disabled={busy || improving} on:click={() => openPublishDialog(preview)}>Publish</button>
          <button disabled={improving} on:click={closePreview}>Close</button>
        {/if}
      </div>
      {#if improvedPages.length}<p class="hint">Reviewing the improved version — press Done to replace the saved flyer, or Discard to keep the original.</p>{/if}
      {#if progress}<p role="status">{progress}</p>{/if}
      {#if error}<p class="error" role="alert">{error}</p>{/if}
      {#if improveError}<p class="error" role="alert">{improveError}</p>{/if}
      {#if success}<p class="success" role="status">{success}</p>{/if}
      <div class="saved-pages">{#each (improvedPages.length ? improvedPages : preview.pages) as page, i}<figure><img src={page} alt={`Saved flyer page ${i + 1}`} /><figcaption>Page {i + 1}{#if !improvedPages.length}<button class="edit-page-btn" disabled={busy || improving} on:click={() => openRegionEdit(i)}>Edit</button>{/if}</figcaption></figure>{/each}</div>
    </div>
  </div>
{/if}
{#if preview && editIndex !== null}
  <div class="preview-overlay" role="presentation">
    <div class="preview-dialog edit-region-dialog" role="dialog" aria-modal="true" aria-label={`Edit page ${editIndex + 1}`} tabindex="-1">
      <div class="toolbar">
        <h2>Edit page {editIndex + 1}</h2>
        <p class="hint">Draw a box around the exact area to change, then describe the change. Only that area is regenerated.</p>
        <button disabled={editBusy} on:click={closeRegionEdit}>Close</button>
      </div>
      <div
        class="edit-canvas"
        on:pointerdown={startEditBox}
        on:pointermove={moveEditBox}
        on:pointerup={endEditBox}
        on:pointercancel={endEditBox}
      >
        <img bind:this={editImgEl} src={preview.pages[editIndex]} alt={`Page ${editIndex + 1}`} draggable="false" />
        {#if editBox}
          {@const d = toEditDisplayBox(editBox)}
          <div class="edit-box" style="left:{d.left}px;top:{d.top}px;width:{d.width}px;height:{d.height}px;"></div>
        {/if}
        {#if editResultUrl}<img class="edit-result-overlay" src={editResultUrl} alt="Edited result preview" draggable="false" />{/if}
      </div>
      {#if editError}<p class="error" role="alert">{editError}</p>{/if}
      {#if editBox && !editDrawing}
        <div class="edit-panel">
          {#if editResultUrl}
            <p class="hint">Reviewing this change — Accept to save it and pick another area, or Discard to try again.</p>
            <div class="toolbar">
              <button class="primary" disabled={editBusy} on:click={acceptRegionEdit}>{editBusy ? 'Saving…' : 'Accept'}</button>
              <button disabled={editBusy} on:click={discardRegionEdit}>Discard</button>
            </div>
          {:else}
            <div class="edit-chips">{#each editInstructionChips as chip}<button type="button" disabled={editBusy} on:click={() => (editInstruction = chip)}>{chip}</button>{/each}</div>
            <label>Instruction<textarea bind:value={editInstruction} maxlength="300" rows="2" disabled={editBusy} placeholder="e.g. أضف شارة 1 كرتون"></textarea></label>
            <div class="toolbar">
              <button class="primary" disabled={editBusy || !editInstruction.trim()} on:click={submitRegionEdit}>{editBusy ? 'Applying…' : 'Apply'}</button>
              <button disabled={editBusy} on:click={resetEditBox}>Cancel</button>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
{/if}
{#if publishTarget}
  <div class="preview-overlay" role="presentation">
    <div class="preview-dialog publish-dialog" role="dialog" aria-modal="true" aria-label={`Publish ${publishTarget.title}`} tabindex="-1">
      <h2>Publish "{publishTarget.title}"</h2>
      <p class="hint">Sets when this flyer appears on the Login/Offers pages and is sent by the WhatsApp AI — it disappears automatically at the end date/time, or immediately if you Unpublish it.</p>
      <div class="form-grid">
        <label>Branch
          <select bind:value={publishBranchId} disabled={publishing}>
            <option value="">Select a branch</option>
            {#each branches as b}<option value={b.id}>{b.name_en}{b.location_en ? ` — ${b.location_en}` : ''}</option>{/each}
          </select>
        </label>
        <label>Offer name<input bind:value={publishOfferName} maxlength="255" disabled={publishing} /></label>
        <label>Start date
          <input type="text" placeholder="dd/mm/yyyy" bind:value={publishStartDateDisplay} on:blur={() => (publishStartDate = toISODate(publishStartDateDisplay))} disabled={publishing} />
        </label>
        <label>Start time
          <div class="time-input-group">
            <input type="number" min="1" max="12" bind:value={publishStartHour} class="hour-input" disabled={publishing} />
            <span class="time-separator">:</span>
            <input type="number" min="0" max="59" bind:value={publishStartMinute} class="minute-input" disabled={publishing} />
            <select bind:value={publishStartPeriod} class="period-select" disabled={publishing}><option value="AM">AM</option><option value="PM">PM</option></select>
          </div>
        </label>
        <label>End date
          <input type="text" placeholder="dd/mm/yyyy" bind:value={publishEndDateDisplay} on:blur={() => (publishEndDate = toISODate(publishEndDateDisplay))} disabled={publishing} />
        </label>
        <label>End time
          <div class="time-input-group">
            <input type="number" min="1" max="12" bind:value={publishEndHour} class="hour-input" disabled={publishing} />
            <span class="time-separator">:</span>
            <input type="number" min="0" max="59" bind:value={publishEndMinute} class="minute-input" disabled={publishing} />
            <select bind:value={publishEndPeriod} class="period-select" disabled={publishing}><option value="AM">AM</option><option value="PM">PM</option></select>
          </div>
        </label>
      </div>
      <p class="hint">Pages to include for this branch — uncheck any you don't want in the published PDF.</p>
      <div class="publish-pages">
        {#each publishTarget.pagePaths as path, i (path)}
          <label class="publish-page" class:unchecked={!publishPageChecked[i]}>
            <input type="checkbox" bind:checked={publishPageChecked[i]} disabled={publishing} />
            {#if publishPageThumbs[i]}<img src={publishPageThumbs[i]} alt={`Page ${i + 1}`} />{:else}<span class="publish-page-loading">…</span>{/if}
            <span>Page {i + 1}</span>
          </label>
        {/each}
      </div>
      {#if publishError}<p class="error" role="alert">{publishError}</p>{/if}
      <div class="toolbar">
        <button class="primary" disabled={publishing} on:click={submitPublish}>{publishing ? 'Publishing…' : 'Publish'}</button>
        <button disabled={publishing} on:click={closePublishDialog}>Cancel</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .ai-workspace{padding:24px;color:#172033;background:#f5f7fb;min-height:100%;}h2{font-size:22px;font-weight:700;margin:0;}p{margin:12px 0;color:#475569;}.toolbar{display:flex;flex-wrap:wrap;gap:12px;align-items:end;margin:18px 0;}.toolbar h2{margin-right:auto;align-self:center;}label{display:flex;flex-direction:column;gap:6px;font-size:14px;font-weight:600;flex:1;min-width:200px;}select,input{background:white;border:1px solid #cbd5e1;border-radius:8px;padding:10px;color:#172033;width:100%;}button{padding:10px 16px;border:1px solid #cbd5e1;background:white;border-radius:8px;font-weight:600;color:#172033;cursor:pointer;}button.primary{background:#4338ca;color:white;border-color:#4338ca;}button:disabled{opacity:.5;cursor:not-allowed;}.error{background:#fef2f2;color:#991b1b;padding:12px;border-radius:8px;overflow-wrap:anywhere;}.success{background:#ecfdf5;color:#065f46;padding:12px;border-radius:8px;}.hint{font-size:12px;}.theme-options{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;margin:0 0 18px;}.theme-option{display:flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid #cbd5e1;border-radius:8px;background:white;font-size:13px;font-weight:600;cursor:pointer;}.theme-option.selected{border-color:#4338ca;background:#eef2ff;color:#3730a3;}.theme-option input{margin:0;}.previews{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;}figure{margin:0;}figure img{width:100%;height:auto;background:white;box-shadow:0 2px 10px #0002;}figcaption{text-align:center;padding:8px;font-size:13px;}.tile-placeholder{aspect-ratio:2/3;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;background:white;box-shadow:0 2px 10px #0002;border-radius:4px;color:#64748b;font-size:13px;}.spinner{width:26px;height:26px;border:3px solid #c7d2fe;border-top-color:#4338ca;border-radius:50%;animation:spin 1s linear infinite;}@keyframes spin{to{transform:rotate(360deg);}}.tile-error{color:#991b1b;padding:16px;text-align:center;gap:12px;}.tile-error p{margin:0;color:inherit;}.render-host{position:fixed;left:-12000px;top:0;width:794px;pointer-events:none;}.table-scroll{overflow:auto;border:1px solid #e2e8f0;border-radius:10px;}
table{width:100%;border-collapse:collapse;background:white;}
th,td{padding:12px;text-align:left;border-bottom:1px solid #e2e8f0;vertical-align:middle;}
th{background:#16a34a;color:white;font-size:13px;font-weight:700;white-space:nowrap;}
tbody tr:last-child td{border-bottom:none;}
tbody tr:hover{background:#f8fafc;}
td.pub-chips{max-width:320px;}
th:last-child,td:last-child{white-space:nowrap;width:1%;}
.row-actions{display:flex;gap:8px;}.preview-overlay{position:fixed;inset:0;background:#0f172acc;z-index:10050;padding:24px;display:flex;justify-content:center;}.preview-dialog{background:#f5f7fb;border-radius:12px;overflow:auto;padding:24px;width:min(1050px,100%);}.saved-pages{max-width:794px;margin:auto;display:grid;gap:24px;}.status-badge{display:inline-block;padding:4px 10px;border-radius:999px;font-size:12px;font-weight:700;white-space:nowrap;}.status-badge.status-none{background:#e2e8f0;color:#475569;}.status-badge.status-published{background:#dcfce7;color:#166534;}.status-badge.status-unpublished{background:#fef3c7;color:#92400e;}.status-badge.status-expired{background:#fee2e2;color:#991b1b;}.publish-dialog{width:min(600px,100%);}.form-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin:16px 0;}.time-input-group{display:flex;align-items:center;gap:6px;}.hour-input,.minute-input{width:56px;text-align:center;}.time-separator{font-weight:700;color:#475569;}.period-select{width:auto;}input[type=number].hour-input::-webkit-outer-spin-button,input[type=number].hour-input::-webkit-inner-spin-button,input[type=number].minute-input::-webkit-outer-spin-button,input[type=number].minute-input::-webkit-inner-spin-button{-webkit-appearance:none;margin:0;}
.saved-pages figcaption{display:flex;align-items:center;justify-content:center;gap:10px;}.edit-page-btn{padding:4px 12px;font-size:12px;}
.edit-region-dialog{width:min(900px,100%);}
.edit-canvas{position:relative;max-width:100%;width:fit-content;margin:12px auto;touch-action:none;cursor:crosshair;}
.edit-canvas img{display:block;max-width:100%;max-height:70vh;width:auto;height:auto;user-select:none;-webkit-user-drag:none;}
.edit-box{position:absolute;border:2px dashed #4338ca;background:rgba(67,56,202,.12);pointer-events:none;}
.edit-result-overlay{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;background:white;}
.edit-panel{background:white;border:1px solid #cbd5e1;border-radius:10px;padding:16px;margin-top:12px;}
.edit-chips{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px;}.edit-chips button{padding:6px 12px;font-size:12px;background:#eef2ff;border-color:#c7d2fe;color:#3730a3;}
div.pub-chips{display:flex;flex-wrap:wrap;gap:8px;}.pub-chips .status-badge{display:inline-flex;align-items:center;gap:6px;}
.chip-x{padding:0;width:16px;height:16px;min-width:16px;border:none;background:rgba(0,0,0,.15);color:inherit;border-radius:50%;font-size:10px;line-height:1;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;}.chip-x:disabled{opacity:.5;cursor:not-allowed;}
.publish-pages{display:flex;flex-wrap:wrap;gap:12px;margin:12px 0;}
.publish-page{display:flex;flex-direction:column;align-items:center;gap:6px;width:110px;padding:8px;border:1px solid #cbd5e1;border-radius:8px;background:white;font-size:12px;font-weight:600;cursor:pointer;}
.publish-page.unchecked{opacity:.45;}
.publish-page img{width:100%;height:110px;object-fit:contain;background:#f5f7fb;border-radius:4px;}
.publish-page-loading{width:100%;height:110px;display:flex;align-items:center;justify-content:center;background:#f5f7fb;border-radius:4px;color:#94a3b8;}
.publish-page input{width:auto;}
.edit-panel textarea{background:white;border:1px solid #cbd5e1;border-radius:8px;padding:10px;color:#172033;width:100%;font:inherit;resize:vertical;}
</style>
