import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import sharp from 'sharp';
import type { RequestHandler } from '@sveltejs/kit';

export const config = { maxDuration: 300 };

const cardSchema = z.object({
  pageOrder: z.number().int().positive(),
  x: z.number().min(0).max(1024), y: z.number().min(0).max(1536),
  width: z.number().positive().max(1024), height: z.number().positive().max(1536),
  namesAr: z.array(z.string().max(200)).max(12), namesEn: z.array(z.string().max(200)).max(12),
  unitName: z.string().max(80).optional(), offerQty: z.number().nonnegative().optional(),
  freeQty: z.number().nonnegative().optional(), limitQty: z.number().nonnegative().nullable().optional(),
  isVariation: z.boolean()
}).strict();

const inputSchema = z.object({
  offerId: z.string().uuid(), pageNumber: z.number().int().positive().max(100),
  colorTheme: z.string().trim().min(1).max(120),
  contextName: z.string().trim().min(1).max(100).optional(),
  cards: z.array(cardSchema).min(1).max(16)
}).strict();

async function cleanCardOverlay(bytes: Buffer, width: number, height: number): Promise<Buffer> {
  const pixels = await sharp(bytes).resize(width, height, { fit: 'fill' }).ensureAlpha().raw().toBuffer();
  // Some image-generation responses ignore `background: transparent` on later page requests and
  // paint an opaque white/off-white rectangle through each card. Chroma-key neutral bright pixels
  // out before applying the geometric safety mask. Colored decoration remains; the fake white
  // canvas becomes transparent and can no longer cover the real product or earlier elements.
  for (let offset = 0; offset < pixels.length; offset += 4) {
    const r = pixels[offset], g = pixels[offset + 1], b = pixels[offset + 2];
    const high = Math.max(r, g, b), low = Math.min(r, g, b);
    const brightness = (r + g + b) / 3;
    if (brightness >= 238 && high - low <= 24) pixels[offset + 3] = 0;
    else if (brightness >= 218 && high - low <= 16) pixels[offset + 3] = Math.min(pixels[offset + 3], Math.round((238 - brightness) / 20 * 255));
  }
  return sharp(pixels, { raw: { width, height, channels: 4 } }).png().toBuffer();
}

export const POST: RequestHandler = async ({ request, url }) => {
  try {
    if (request.headers.get('origin') && request.headers.get('origin') !== url.origin) return json({ error: 'Invalid request origin.' }, { status: 403 });
    const input = inputSchema.safeParse(await request.json());
    if (!input.success) return json({ error: 'Valid product-card information is required.' }, { status: 400 });
    const databaseUrl = env.VITE_SUPABASE_URL, databaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
    if (!databaseUrl || !databaseKey) throw new Error('Server database configuration is missing.');
    const db = createClient(databaseUrl, databaseKey, { auth: { persistSession: false } });
    const [offer, key] = await Promise.all([
      db.from('flyer_offers').select('id').eq('id', input.data.offerId).eq('is_active', true).single(),
      db.from('system_api_keys').select('api_key').eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle()
    ]);
    if (offer.error || !offer.data) return json({ error: 'This active offer could not be loaded.' }, { status: 400 });
    if (!key.data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');

    const generateCard = async (card: z.infer<typeof cardSchema>) => {
      const identity = [...card.namesEn, ...card.namesAr].filter(Boolean).join(' / ');
      const prompt = `Create a transparent square PNG containing a coordinated cluster of decorative details for this one supermarket product card.

Product identity: ${identity}. Unit: ${card.unitName || 'unspecified'}. Variation group: ${card.isVariation ? 'yes' : 'no'}.
Color direction: ${input.data.colorTheme}. Campaign context: ${input.data.contextName || 'general supermarket offer'}.

Create small-to-medium supporting details such as ingredients, leaves, grains, slices, droplets, splashes, frost, particles, or flowing accents genuinely associated with THIS PRODUCT ONLY. Arrange them naturally around the outer area and corners, with enough visible decoration to enrich the card while keeping the center clear for the real product image. Product names and all other existing content must not be recreated. Ingredient accuracy is mandatory: never infer an ingredient not explicitly named; generic oil is not olive oil.

STRICT: transparent background with only the supporting decorative details. NEVER draw a retail product, package, bottle, bag, can, carton, box, produce pile, hero food item, solid card panel, price, badge, logo, brand, letter, word, number, label, ribbon, seal, or watermark. Do not create a frame or continuous border and do not fill the center with an opaque color. This output belongs to one card only; include nothing related to another product.`;
      const response = await fetch('https://api.openai.com/v1/images/generations', {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key.data.api_key}` }, signal: AbortSignal.timeout(270000),
        body: JSON.stringify({ model: 'gpt-image-2.5-sunburst', size: '1024x1024', quality: 'high', background: 'transparent', output_format: 'png', prompt })
      });
      const result = await response.json();
      if (!response.ok) throw new Error(String(result.error?.message || `Element generation failed for card ${card.pageOrder}.`).replaceAll(key.data.api_key, '[redacted]').slice(0, 600));
      const encoded = result.data?.[0]?.b64_json;
      if (typeof encoded !== 'string' || !encoded) throw new Error(`OpenAI returned no decoration for card ${card.pageOrder}.`);
      const width = Math.max(1, Math.round(card.width)), height = Math.max(1, Math.round(card.height));
      return { input: await cleanCardOverlay(Buffer.from(encoded, 'base64'), width, height), left: Math.round(card.x), top: Math.round(card.y) };
    };

    // Small batches keep the request within provider rate limits while still finishing a six-card
    // page comfortably inside the serverless timeout.
    const layers: { input: Buffer; left: number; top: number }[] = [];
    for (let i = 0; i < input.data.cards.length; i += 3) layers.push(...await Promise.all(input.data.cards.slice(i, i + 3).map(generateCard)));
    const overlay = await sharp({ create: { width: 1024, height: 1536, channels: 4, background: '#00000000' } }).composite(layers).png().toBuffer();
    return new Response(overlay, { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error && error.name === 'TimeoutError' ? 'Decorative element generation timed out. Please retry.' : 'Could not generate product elements.' }, { status: 500 });
  }
};
