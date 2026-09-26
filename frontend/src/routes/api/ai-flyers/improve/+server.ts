import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import type { RequestHandler } from '@sveltejs/kit';
import sharp from 'sharp';

export const config = { maxDuration: 300 };

// Fixed, reusable enhancement pass for an already-finished flyer page: same prompt regardless of
// offer/page. The renderer already produced every FACT (prices, names, dates, quantities, page
// number) correctly — those are protected. New decorations are graphical only: the model must
// never invent captions or any other writing inside product cards or elsewhere on the page.
// Known tradeoff: image models can render new text incorrectly/illegibly (unlike copying text
// that's already in the photo) — that's an inherent model limitation, not something this prompt
// can fully guarantee away; the review-before-save flow is what actually catches a bad result.
// Offer Context (see offer_context_ai_flyer_spec.md) is internal AI guidance only, never printed
// on the flyer. A department-specific context (e.g. "Fruit & Vegetable Offer") may lean the header
// decorations into that theme; everything else (the default, and general/occasion contexts like
// "General Supermarket Offer" or "Weekend Offer") must stay department-neutral — this is what stops
// a mixed-grocery flyer from getting a fruit-and-vegetable-market look just because the header art
// defaults that way.
function contextClause(contextName?: string, contextDescription?: string): string {
  const isGeneral = !contextName || /general|weekend|day|weekly|monthly|mega|save|flash|limited|salary|month-end|opening|anniversary|loyalty/i.test(contextName);
  return isGeneral
    ? 'This promotion is a general, department-neutral supermarket offer covering many different product categories. Do not let the header decorations, cart contents, or overall styling make it look like it belongs to one specific department — do not fill the scene with vegetables, fruit, bakery items, or meat imagery unless a product actually on this page is that.'
    : `This promotion's own theme is "${contextName}" (${contextDescription}). The header decorations and overall styling may lean into that theme, but every FACT above still applies unchanged.`;
}

function buildImprovePrompt(contextName?: string, contextDescription?: string): string {
  return `Improve this exact uploaded flyer, making it look like a professionally upgraded version of the same flyer — richer and more premium, not a redesigned or different one.

${contextClause(contextName, contextDescription)}

These FACTS must stay 100% unchanged — never alter, invent, or remove any of them:

All prices and old (struck-through) prices
All quantities, unit counts, and offer/badge numbers (e.g. "٣" on a multi-buy badge)
Every existing small badge, pill, or seal already printed on a product card — a quantity circle
(e.g. "٣ حبة"), a variety/assortment label (e.g. "متنوع"), a per-customer purchase-limit ribbon
(e.g. "لكل عميل / ٢ كرتون"), or any similar tag — must be kept exactly where it is, unchanged. Never
remove it, cover it, or restyle over it with your own decoration; any new graphical tag or icon is
an ADDITIONAL text-free element placed elsewhere on the card, never a replacement for one already there.
A single product card can legitimately carry two or three of these badges at once, stacked or placed
close together in the same corner (for example: an assortment label, a purchase-limit ribbon, and a
quantity circle all on one card). When badges are stacked or crowded like this, treat each one as a
completely separate, independent element — read and reproduce each badge's own number on its own,
never let one badge's number influence, average with, or bleed into another nearby badge's number.
More badges on one card means more care here, not less.
Product names (Arabic and English)
Offer dates and the page number
Number of product cards and their positions/arrangement
The logo, and the main Arabic offer title's wording
The existing Aqura brand logo is the only company/store logo permitted. Never replace it with a
product manufacturer, vendor, supermarket, or invented logo, and never add another company logo.
Keep the complete existing offer/expiry-date plaque and page number visible on every page.
Every product's own image — never replace, redraw, or regenerate a product photo itself
Never duplicate a product, its package, any badge, name, or price. Each item visible in the input
must appear exactly once in the output, in its original position and at its original scale.
Treat every product photo as a completely locked photographic region. Preserve every original pixel
inside the product silhouette, including all packaging artwork, brand logos, colors, shapes, fine
print, Arabic writing, English writing, numbers, weights, volumes, seals, and label text printed on
the physical product. Do not clean up, sharpen, translate, correct, recreate, stylize, obscure, or
reinterpret packaging text. Never place a decorative element over any part of a product image.

Digits and numerals are the single most common thing you get wrong here — every price, old price,
quantity badge number, date, and page number is made of digits, and you must reproduce each one
pixel-for-pixel identical to the input. Never redraw, regenerate, restyle, or reinterpret a digit
or Arabic numeral anywhere in the image, even inside a badge you are otherwise restyling — copy
that exact number through unchanged and only enhance the shape/color/shadow around it.

Within those limits, you may and should add tasteful decorative content to make this look like a
real premium supermarket flyer:

Requirement #1, the single highest-priority decoration, required on every one of the product cards
with no exception — do this even if you skip everything else in this list: paint a solid, clearly
visible colored accent stripe along the BOTTOM edge of every product card, using the EXACT same
color as that card's own new text-free graphical tag/icon — not merely a similar hue from the same
general category, the same literal color. A water product may use a blue droplet tag and therefore
a matching blue stripe. Apply that same rule to every other card — whatever color that card's new icon is, its stripe must be that same
color, so different cards end up with visibly different stripe colors that each genuinely match their
own graphical tag, not one same plain gold/tan border repeated on all of them and not a stripe color picked
independently of that card's badge. If you find yourself giving a card a stripe color that does not
match its own badge, that is wrong — fix it before finishing.
Add a small product-appropriate GRAPHICAL tag or icon to each card, such as a water droplet, wheat stalk, leaf, flower, shield, sparkle, or simple quality medallion. These new tags must contain absolutely no letters, words, numbers, pseudo-writing, or captions in any language. Keep them visually distinct from existing quantity, assortment, and purchase-limit badges, and never place them over a product photo, product name, price, or existing badge.
On every single product card, also add a few small ambient decorative particles floating loosely around that product's own photo (never overlapping the photo, its name, or its price) that echo what that specific product physically is — light blue water droplets floating around a water bottle, soft flour/wheat dust or a few wheat grains floating around a flour bag, small flower petals floating around a tissue pack, a light milk splash or swirl around a milk product, a cream swirl around a cheese product, and so on for whatever each product is. This must appear around every product card the same way, not only one or two of them.
Improve product-card depth with clean rounded corners, soft premium shadows, subtle highlights, and better separation from the background, on top of the required bottom accent stripe above.
Make the main wooden offer-title board richer and more premium with realistic wood texture, depth, shadows, ropes, and surrounding leaves. Improve the 3D appearance of the Arabic offer title while keeping the exact same wording.
Add supermarket promotional decorations around the header where there is empty space, such as a shopping cart, a plain percentage symbol, a megaphone, or leaves. These must be purely graphical shapes/icons with no new lettering, wording, slogans, captions, pseudo-writing, or text-bearing tags.
Redesign the bottom footer strip into a richer decorated band with a nicer leafy/wave background and text-free graphical icons only. Keep the exact existing offer dates and page number unchanged, and add no new captions or wording.
Do not create any new text anywhere on the flyer. The only text permitted in the output is text already present in the uploaded image, reproduced exactly and only once.
Improve overall lighting, depth, contrast, and shadows for a premium supermarket-advertising appearance.

The final result must still clearly be THIS flyer — same offer, same products at the same prices in the same positions — just dressed up with the kind of tasteful marketing decoration a real published supermarket flyer would have.`;
}

// The page image is fetched server-side from its own signed Supabase Storage URL rather than
// uploaded in the request body. This app is deployed on Vercel (see vercel.json), whose Serverless
// Functions hard-cap the incoming request body at 4.5MB regardless of any app-level size check —
// a flyer page captured via html-to-image at pixelRatio:2 routinely exceeds that, which is exactly
// why Improve worked on `vite dev` (no such limit) but failed in production with a raw "Request
// Entity Too Large" 413 that isn't even JSON. Fetching the already-saved page from Storage instead
// keeps the browser→function request tiny (just a URL + a couple of short strings) — the large
// transfer becomes this function's own outbound fetch to Storage, which isn't subject to that cap.
const inputSchema = z.object({
  pageUrl: z.string().url(),
  flyerId: z.string().uuid(),
  pageNumber: z.number().int().positive().max(100),
  contextName: z.string().trim().min(1).max(100).optional(),
  contextDescription: z.string().trim().min(1).max(500).optional()
}).strict();

const kind = (field: any) => field?.label || field?.type || '';
function cardFields(slot: any): any[] {
  if (slot.field?.fields?.length) return slot.field.fields.filter((field: any) => kind(field) !== 'barcode');
  const w = Number(slot.field.width), h = Number(slot.field.height), p = slot.products?.[0] || {}, badge = Math.min(w, h) * .22;
  return [
    { label: 'image', x: w * .02, y: h * .02, width: w * .96, height: h * .7 },
    { label: 'product_name_ar', x: w * .045, y: h * .735, width: w * .91, height: h * .09 },
    { label: 'product_name_en', x: w * .045, y: h * .825, width: w * .91, height: h * .075 },
    ...(Number(p.offer_qty) > 1 || Number(p.limit_qty) > 1 ? [{ label: 'offer_qty_badge', x: w * .97 - badge, y: h * .02, width: badge, height: badge }] : []),
    ...(slot.products?.length > 1 ? [{ label: 'assorted_badge', x: w * .02, y: h * .02, width: w * .3, height: h * .065 }] : []),
    ...(Number(p.limit_qty) > 0 ? [{ label: 'limit_qty_badge', x: 0, y: h * .10, width: w * .38, height: h * .13 }] : []),
    { label: 'price', x: w * .64, y: h * .48, width: w * .31, height: h * .075 },
    { label: 'offer_price', x: w * .59, y: h * .55, width: w * .38, height: h * .14 },
    ...(Number(p.free_qty) > 0 ? [{ label: 'free_qty', x: w * .03, y: h * .905, width: w * .94, height: h * .065 }] : [])
  ];
}

async function buildProtectionMask(page: any, width: number, height: number): Promise<Buffer> {
  const sx = width / 1024, sy = height / 1536;
  const layers: any[] = [];
  // These regions are rendered correctly before Improve and contain identity/factual content.
  // Keep them opaque in the edit mask so the image model cannot replace the Aqura logo with an
  // invented vendor logo, rewrite the offer name, or remove the date/page-number information.
  const fixedPageRegions = [
    { x: 15, y: 0, width: 205, height: 170 },       // Aqura logo reserve
    { x: 230, y: 95, width: 635, height: 340 },     // exact offer-title sign and wording
    { x: 20, y: 1360, width: 350, height: 176 },    // offer/expiry date plaque
    { x: 875, y: 1430, width: 149, height: 106 }    // page number
  ];
  for (const region of fixedPageRegions) {
    layers.push({
      input: { create: { width: Math.round(region.width * sx), height: Math.round(region.height * sy), channels: 4, background: '#ffffffff' } },
      left: Math.round(region.x * sx), top: Math.round(region.y * sy)
    });
  }
  const factual = new Set(['product_name_ar', 'product_name_en', 'price', 'offer_price', 'offer_qty_badge', 'assorted_badge', 'limit_qty_badge', 'free_qty', 'unit_name', 'variation_text_ar', 'variation_text_en']);
  for (const slot of page?.slots || []) {
    const fields = cardFields(slot);
    for (const field of fields.filter((item: any) => factual.has(kind(item)))) {
      const w = Math.max(1, Math.round(Number(field.width) * sx)), h = Math.max(1, Math.round(Number(field.height) * sy));
      layers.push({ input: { create: { width: w, height: h, channels: 4, background: '#ffffffff' } }, left: Math.round((Number(slot.field.x) + Number(field.x || 0)) * sx), top: Math.round((Number(slot.field.y) + Number(field.y || 0)) * sy) });
    }
    const imageField = fields.find((field: any) => kind(field) === 'image');
    if (!imageField) continue;
    const variant = slot.products.length > 1;
    const urls = variant ? slot.products.map((p: any) => p.image_url).filter(Boolean) : Array(Math.min(Number(slot.products[0]?.offer_qty) || 1, 5)).fill(slot.products[0]?.image_url).filter(Boolean);
    const overlap = variant ? .55 : .4, scale = urls.length === 1 ? 100 : 100 / (1 + (urls.length - 1) * (1 - overlap));
    const step = scale * (1 - overlap), yOffset = variant ? 10 : 0, yStep = variant ? 4 : 5;
    const heightScale = urls.length === 1 ? 100 : Math.min(88, 100 - yOffset - (urls.length - 1) * yStep);
    for (const [index, imageUrl] of urls.entries()) try {
      const response = await fetch(imageUrl); if (!response.ok) continue;
      const targetWidth = Math.max(1, Math.round(Number(imageField.width) * (urls.length === 1 ? 1 : scale / 100) * sx));
      const targetHeight = Math.max(1, Math.round(Number(imageField.height) * heightScale / 100 * sy));
      const product = await sharp(Buffer.from(await response.arrayBuffer())).trim().resize(targetWidth, targetHeight, { fit: 'contain', position: variant ? 'centre' : 'south', background: '#00000000' }).png().toBuffer();
      const silhouette = await sharp({ create: { width: targetWidth, height: targetHeight, channels: 4, background: '#ffffffff' } }).composite([{ input: product, blend: 'dest-in' }]).png().toBuffer();
      layers.push({ input: silhouette, left: Math.round((Number(slot.field.x) + Number(imageField.x || 0) + (urls.length === 1 ? 0 : index * step * Number(imageField.width) / 100)) * sx), top: Math.round((Number(slot.field.y) + Number(imageField.y || 0) + (urls.length === 1 ? 0 : (yOffset + index * yStep) * Number(imageField.height) / 100)) * sy) });
    } catch { /* Keep Improve available if one source product image is temporarily unavailable. */ }
  }
  return sharp({ create: { width, height, channels: 4, background: '#00000000' } }).composite(layers).png().toBuffer();
}

export const POST: RequestHandler = async ({ request, url }) => {
  try {
    if (request.headers.get('origin') && request.headers.get('origin') !== url.origin)
      return json({ error: 'Invalid request origin.' }, { status: 403 });
    const input = inputSchema.safeParse(await request.json());
    if (!input.success) return json({ error: 'A saved flyer page is required.' }, { status: 400 });
    const pageResponse = await fetch(input.data.pageUrl);
    if (!pageResponse.ok) throw new Error('Could not load this flyer page for improving.');
    const image = await pageResponse.blob();
    if (!image.size) return json({ error: 'This flyer page is empty.' }, { status: 400 });
    if (image.size > 20_000_000) return json({ error: 'This flyer page is too large to improve (over 20MB).' }, { status: 400 });

    const databaseUrl = env.VITE_SUPABASE_URL;
    const databaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
    if (!databaseUrl || !databaseKey) throw new Error('Server database configuration is missing.');
    const db = createClient(databaseUrl, databaseKey, { auth: { persistSession: false } });
    const [key, flyer] = await Promise.all([
      db.from('system_api_keys').select('api_key').eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle(),
      db.from('ai_generated_flyers').select('snapshot').eq('id', input.data.flyerId).single()
    ]);
    if (!key.data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');
    const savedPage = flyer.data?.snapshot?.pages?.find((page: any) => Number(page.pageNumber) === input.data.pageNumber);
    if (flyer.error || !savedPage) throw new Error('Could not load the saved flyer layout.');

    const imageBuffer = Buffer.from(await image.arrayBuffer());
    const metadata = await sharp(imageBuffer).metadata();
    if (!metadata.width || !metadata.height) throw new Error('Could not read the saved flyer dimensions.');
    const protectionMask = await buildProtectionMask(savedPage, metadata.width, metadata.height);

    const form2 = new FormData();
    form2.append('model', 'gpt-image-2.5-sunburst');
    form2.append('image[]', image, 'flyer-page.png');
    form2.append('mask', new Blob([new Uint8Array(protectionMask)], { type: 'image/png' }), 'protected-facts-mask.png');
    form2.append('prompt', buildImprovePrompt(input.data.contextName, input.data.contextDescription));
    form2.append('size', '1024x1536');
    form2.append('quality', 'max');

    const response = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST', headers: { Authorization: `Bearer ${key.data.api_key}` }, body: form2,
      signal: AbortSignal.timeout(270000)
    });
    const result = await response.json();
    if (!response.ok) {
      const detail = String(result.error?.message || 'Image improvement failed.').replaceAll(key.data.api_key, '[redacted]').slice(0, 600);
      return json({ error: `OpenAI image service ${response.status}: ${detail}` }, { status: 502 });
    }
    const encoded = result.data?.[0]?.b64_json;
    if (typeof encoded !== 'string' || !encoded) throw new Error('OpenAI returned no improved image.');
    const bytes = Buffer.from(encoded, 'base64');
    return new Response(bytes, { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error && error.name === 'TimeoutError' ? 'Image improvement timed out. Please retry.' : 'Could not improve this flyer page. Check the server configuration and retry.' }, { status: 500 });
  }
};
