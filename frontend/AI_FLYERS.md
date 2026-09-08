# AI flyers

The Generate Flyers window has separate manual, AI generation and saved-library tabs. The manual generator remains unchanged.

## Workflow

Select an active offer, enter or edit its headline, then generate. No Flyer Template selection, template query, template configuration or embedded template image is involved.

The server reads the authoritative offer assignments and derives the page count from the highest page number. Products are ordered by page_order within their original page. Compatible variations with the same parent and identical offer terms share their saved card position. Empty intermediate pages are preserved; invalid or conflicting assignments produce a clear error. Product rows never move to different pages.

Each request processes one page. OpenAI GPT-4o mini selects the first page's compact shared design and each page's column count through strict structured output. Later requests reuse exactly the same palette, motif, shadows and bevels. Requests include only the entered offer name, dates, brand colors and current-page product names/order. They contain no template data, product images, embedded image strings, prices or barcodes. Product photos and exact offer values are composed locally. Barcodes remain internal identifiers and are not printed on the flyer.

The separate `/api/ai-flyers/artwork` endpoint calls OpenAI `gpt-image-2` image edits to create a photographic market art plate guided by the user-provided reference at `static/ai-flyer-references/market.jpeg`. The browser sends only the offer ID and headline; the server attaches one 386 KB JPEG as multipart data. It does not send template JSON or database product assets. Artwork is explicitly text-free; all offer text, logo, dates and product information are overlaid from source data. The same generated art plate is reused across independently rendered pages to guarantee consistent artwork. Image generation can take several minutes and requires deployment support for a 300-second route. Provider failures stop generation rather than silently returning the previous CSS-only look.

The renderer creates 1024 x 1536 pages with dimensional headline lettering, large original product photos, cream cards and red current-price/yellow old-price labels. Six product positions use three columns and two rows. The product area runs from y=550 to y=1340; the decorative header and footer surround it. Text fits within its card without repagination. PNG export uses native SVG/CSS rendering at 2x resolution. Multiple PNG pages download as a ZIP; PDF combines the same images in page order. Only complete generations can be saved or downloaded. A source revision check stops a run if the offer changes between pages.

The temporary art image stays in a browser object URL and is baked into the saved PNG pages. It is not duplicated as base64 in source snapshots, sent back on each page request, or uploaded as an orphan storage file. Previously saved pages keep their existing appearance.

## Setup

- Apply `supabase/migrations/20260908_ai_generated_flyers.sql` for the independent saved-flyer table and private storage bucket.
- Configure the active `openai` key in API Keys Manager. The server reads `VITE_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` or the existing `VITE_SUPABASE_SERVICE_KEY`.
- Deploy the frontend and SvelteKit API together. Product images, brand logos and currency icons must be readable with CORS.
- Saved flyers use their captured page files and source snapshot. Existing saved flyers do not change; regenerate to use this workflow.

Provider error messages (with the key redacted) and text request byte counts are returned for diagnosis. Per-page text AI request bodies are capped at 100 KB. Artwork uses a separate binary request/response path, with generated JPEG output capped at 4 MB. No Gemini endpoint or Gemini key is used in this workflow.

OpenAI request format: [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).

## Validation

`npm exec --workspace frontend -- vitest run src/lib/utils/aiFlyer.test.ts src/routes/api/ai-flyers/design/design.test.ts src/routes/api/ai-flyers/artwork/artwork.test.ts`

`node node_modules/svelte-check/bin/svelte-check --workspace frontend --tsconfig ./tsconfig.ai-flyer-check.json`

`node scripts/verify-ai-flyer-request.mjs <offer-uuid>` performs a local dry run with real database reads and substituted AI responses. It never sends offer data to OpenAI or writes database records.

The Week 2 dry run verified three pages, six card positions per page, and identical shared styling. The first two OpenAI request bodies measured 3433 and 2647 bytes. The dry run does not validate live model output or browser rendering.

Artwork endpoint tests mock OpenAI; live generated-art quality and browser export still require a generation run. This change does not guarantee a pixel-identical reproduction of the example artwork.
