import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import type { RequestHandler } from '@sveltejs/kit';

export const config = { maxDuration: 300 };
const inputSchema = z.object({
  offerId: z.string().uuid(), offerName: z.string().trim().min(1).max(200), colorTheme: z.string().trim().min(1).max(120),
  // Internal AI visual-direction guidance, e.g. "Fruit & Vegetable Offer" — never printed on the
  // artwork. Optional so this endpoint keeps working before a context is selected.
  contextName: z.string().trim().min(1).max(100).optional(),
  contextDescription: z.string().trim().min(1).max(500).optional()
}).strict();

// A campaign gets one shared art plate. Each page's exact product layer is composed separately.
// No template configurations, database product images, prices or barcodes go to the image model.
export const POST: RequestHandler = async ({ request, fetch, url }) => {
  try {
    if (request.headers.get('origin') && request.headers.get('origin') !== url.origin)
      return json({ error: 'Invalid request origin.' }, { status: 403 });
    const input = inputSchema.safeParse(await request.json());
    if (!input.success) return json({ error: 'Select an offer and enter its name.' }, { status: 400 });
    const databaseUrl = env.VITE_SUPABASE_URL;
    const databaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
    if (!databaseUrl || !databaseKey) throw new Error('Server database configuration is missing.');
    const db = createClient(databaseUrl, databaseKey, { auth: { persistSession: false } });
    const [offer, key, logo] = await Promise.all([
      db.from('flyer_offers').select('id').eq('id', input.data.offerId).eq('is_active', true).single(),
      db.from('system_api_keys').select('api_key').eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle(),
      db.from('login_layout').select('topbar').limit(1).maybeSingle()
    ]);
    if (offer.error || !offer.data) return json({ error: 'This active offer could not be loaded.' }, { status: 400 });
    if (!key.data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');
    const logoUrl = logo.data?.topbar?.logo_url;
    if (!logoUrl) throw new Error('Brand logo not found. Upload it under Branding > Login Page > Top Bar logo first.');
    const logoResponse = await fetch(logoUrl);
    if (!logoResponse.ok) throw new Error('Could not load the brand logo for artwork generation.');
    // Reference: the sibling "Generate New Background" flow (generate-flyer-background/+server.js,
    // used from Flyer Templates) gets genuine per-generation variety by (a) never anchoring the
    // image-edit call to a fixed stock scene photo — it only ever attaches the real brand logo —
    // and (b) letting the model freely decide header artwork FROM THE OFFER'S OWN TEXT, rather than
    // picking from a fixed enumerated list of scene/sign snippets. This endpoint previously did the
    // opposite: it always attached the same market.jpeg (a rope-hung wooden sign photo) as an
    // edit-source image, which kept anchoring every result back to that exact composition no matter
    // how the text prompt was worded — even a per-category lookup table of scene descriptions
    // (tried and discarded here) still came out looking hung-by-ropes because the source photo
    // itself was doing most of the visual work. Switching to the logo-only reference, and to a
    // freeform creative instruction driven by the actual offer name + offer context, matches the
    // approach that's already proven to produce real variety elsewhere in this codebase.
    const name = input.data.contextName || '';
    const isGeneral = !name || /general|weekend|day|weekly|monthly|mega|save|flash|limited|salary|month-end|opening|anniversary|loyalty/i.test(name);
    const contextClause = name
      ? `Offer context (internal guidance only, never render this text anywhere in the image): "${name}" — ${input.data.contextDescription}.`
      : 'No specific offer context was selected.';
    const departmentRule = isGeneral
      ? 'This promotion is general/department-neutral and spans many different product categories — do not skew the scene toward any single department (no fruit/vegetable, bakery, dairy, meat or similar produce-specific imagery) unless the offer context above explicitly names that department. Still make it feel premium and distinctive, not a copy of a previous generation.'
      : 'The offer context above specifically names a department/occasion — let the scene, the sign/plaque/banner shape, its mount, and the decorative elements authentically lean into that theme.';
    const form = new FormData();
    form.append('model', 'gpt-image-2');
    form.append('size', '1024x1536');
    form.append('quality', 'medium');
    form.append('output_format', 'jpeg');
    form.append('output_compression', '85');
    form.append('image[]', await logoResponse.blob(), 'brand-logo.png');
    form.append('prompt', `Create a premium supermarket promotional BACKGROUND ART PLATE, 1024x1536. One reference image is attached: "brand-logo" — it is supplied ONLY so you can sample its colors for the palette below. Do NOT draw, redraw, reproduce, reference, or imitate the logo graphic, its wordmark, or the brand name text anywhere in this image, not even a stylized or partial version — the real logo file will be overlaid separately by the application afterward at a fixed position, so drawing it yourself would duplicate it. Also never draw a second copy of the offer headline: it belongs on the sign/plaque only. The application adds every product, that real logo overlay, and prices later — only the headline described below belongs baked into this image.

${contextClause}
${departmentRule}

Creatively design a rich, photorealistic, premium supermarket promotional scene and a sign/plaque/banner for the headline — genuinely representing this specific offer's occasion or category the way a professional flyer designer would (distinct scene elements, distinct sign shape, distinct mount — hanging, standing, floating, draped, whatever fits best — and distinct decorative motifs each time, not a repeated default). Golden bokeh, dimensional depth, realistic lighting and shadow. No flat vector/cartoon look, no plain gradient. Follow this color theme for the overall palette, header art, and the sign's lettering: ${JSON.stringify(input.data.colorTheme)}. Pick up at least one of the brand logo's own colors somewhere in the design so it visibly ties back to the brand.

Precise composition (these pixel regions are fixed regardless of your creative design):
Top y=0..535: your scene and sign, with the sign/plaque/banner centered at x=230..865,y=95..435. Render this exact Arabic headline text on it, spelled and worded exactly as given, as bold dimensional 3D typography — extruded/carved lettering with real depth, shading and a highlight, filling the sign attractively and staying legible: ${JSON.stringify(input.data.offerName)}. Leave x=15..220,y=0..170 as plain, unobstructed background from your scene — no logo, no wordmark, no text, no plaque, no decorative object placed there at all — that exact box is reserved empty for the real logo file the application overlays afterward. Do not add any other text, fake logos, or a second copy of the headline anywhere else in the image.
Middle y=550..1345: clean warm ivory parchment, almost entirely empty for product cards; only subtle theme-matching accents at extreme left/right edges within 20 pixels. Absolutely NO products, card outlines, price labels or writing in this area.
Bottom y=1360..1536: a footer band styled to match your scene's theme and the color palette, with a dark quiet center reserved for later exact offer information. Do not add footer slogans, icons or dates.

NO watermarks, product packaging, barcodes or invented promotional claims. Everything must be polished, photorealistic and suitable for a professional print advertisement.`);
    const response = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST', headers: { Authorization: `Bearer ${key.data.api_key}` }, body: form,
      signal: AbortSignal.timeout(270000)
    });
    const result = await response.json();
    if (!response.ok) {
      const detail = String(result.error?.message || 'Image generation failed.').replaceAll(key.data.api_key, '[redacted]').slice(0, 600);
      return json({ error: `OpenAI artwork service ${response.status}: ${detail}` }, { status: 502 });
    }
    const encoded = result.data?.[0]?.b64_json;
    if (typeof encoded !== 'string' || !encoded) throw new Error('OpenAI returned no flyer artwork.');
    const bytes = Buffer.from(encoded, 'base64');
    if (bytes.length > 4_000_000) throw new Error('Generated artwork exceeded the export size limit. Please retry.');
    return new Response(bytes, { headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'no-store', 'X-Artwork-Model': 'gpt-image-2' } });
  } catch (error) {
    return json({ error: error instanceof Error && error.name === 'TimeoutError' ? 'OpenAI artwork generation timed out. Please retry.' : 'Could not generate flyer artwork. Check the server configuration and retry.' }, { status: 500 });
  }
};
