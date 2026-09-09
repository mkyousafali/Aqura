import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import type { RequestHandler } from '@sveltejs/kit';

export const config = { maxDuration: 300 };

// Fixed, reusable enhancement pass for an already-finished flyer page: same prompt regardless of
// offer/page. The renderer already produced every FACT (prices, names, dates, quantities, page
// number) correctly — those are protected. Per-product taglines/captions are asked for here, in
// this one pass only — do not also add a separate code-rendered badge system elsewhere for this.
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
(e.g. "٣ حبة"), a variety/assortment label (e.g. "متنوع"), or any similar tag — must be kept exactly
where it is, unchanged. Never remove it, cover it, or restyle over it with your own decoration; any
new caption or icon you add is an ADDITIONAL element placed elsewhere on the card, never a
replacement for one that is already there.
Product names (Arabic and English)
Offer dates and the page number
Number of product cards and their positions/arrangement
The logo, and the main Arabic offer title's wording
Every product's own image — never replace, redraw, or regenerate a product photo itself

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
color as that card's own caption badge/icon — not merely a similar hue from the same general
category, the same literal color. The water product is the model example of this done correctly: its
caption badge/icon is blue, so its bottom stripe is that identical blue. Apply that same rule to every
other card — whatever color that card's own badge/icon already is, its stripe must be that same
color, so different cards end up with visibly different stripe colors that each genuinely match their
own badge, not one same plain gold/tan border repeated on all of them and not a stripe color picked
independently of that card's badge. If you find yourself giving a card a stripe color that does not
match its own badge, that is wrong — fix it before finishing.
Give each product a short (2-3 word maximum) Arabic promotional caption placed near it, genuinely grounded in what that product actually is — softness for tissue, family nutrition for a staple food, freshness for produce, a value callout for a steep discount, a quality/trust angle for a premium brand. Pair each caption with a small matching icon or badge (a droplet, a heart, wheat stalks, soft petals, a ribbon), added as a new element alongside (never replacing) any badge already on that card. The caption must be short enough to render fully inside its badge at a size that is completely legible — never let it get cropped, cut off, blurry, or run outside its own badge, and make sure the Arabic spelling and grammar are correct, not garbled. If a caption would not fit legibly, shorten it further rather than shrinking it into illegibility. Never invent a caption that misrepresents the product, and never let a caption or its badge cover the product photo, its name, its price, or any existing badge on that card.
On every single product card, also add a few small ambient decorative particles floating loosely around that product's own photo (never overlapping the photo, its name, or its price) that echo what that specific product physically is — light blue water droplets floating around a water bottle, soft flour/wheat dust or a few wheat grains floating around a flour bag, small flower petals floating around a tissue pack, a light milk splash or swirl around a milk product, a cream swirl around a cheese product, and so on for whatever each product is. This must appear around every product card the same way, not only one or two of them.
Improve product-card depth with clean rounded corners, soft premium shadows, subtle highlights, and better separation from the background, on top of the required bottom accent stripe above.
Make the main wooden offer-title board richer and more premium with realistic wood texture, depth, shadows, ropes, and surrounding leaves. Improve the 3D appearance of the Arabic offer title while keeping the exact same wording.
Add supermarket promotional decorations around the header where there is empty space, such as a shopping cart, a plain percentage symbol, a megaphone, or leaves. These header decorations must be PURELY graphical shapes/icons — never add any new lettering, wording, or a text-bearing tag/badge/note here (no invented slogans like "أقوى العروض"), since new Arabic text rendered into a busy decorative shape like this reliably comes out misspelled or garbled. The only places new Arabic text is allowed at all are the short per-product captions and the footer's short experience captions, both described elsewhere in this list, which have their own legibility rules — nowhere else, and nothing in the header itself, may carry new invented wording.
Redesign the bottom footer strip into a richer decorated band with a nicer leafy/wave background — keep the exact offer dates and page number it already shows exactly as they are, and you may add a short row of generic supermarket-experience captions with small icons (e.g. a different shopping experience, fresh products daily, trusted quality), each short enough to stay fully legible and never overlapping the existing date/page-number text.
Improve overall lighting, depth, contrast, and shadows for a premium supermarket-advertising appearance.

The final result must still clearly be THIS flyer — same offer, same products at the same prices in the same positions — just dressed up with the kind of tasteful marketing decoration a real published supermarket flyer would have.`;
}

export const POST: RequestHandler = async ({ request, url }) => {
  try {
    if (request.headers.get('origin') && request.headers.get('origin') !== url.origin)
      return json({ error: 'Invalid request origin.' }, { status: 403 });
    const form = await request.formData();
    const image = form.get('image');
    if (!(image instanceof File) || !image.size) return json({ error: 'A flyer page image is required.' }, { status: 400 });
    if (image.size > 20_000_000) return json({ error: 'This flyer page is too large to improve (over 20MB).' }, { status: 400 });
    const contextName = form.get('contextName');
    const contextDescription = form.get('contextDescription');

    const databaseUrl = env.VITE_SUPABASE_URL;
    const databaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
    if (!databaseUrl || !databaseKey) throw new Error('Server database configuration is missing.');
    const db = createClient(databaseUrl, databaseKey, { auth: { persistSession: false } });
    const key = await db.from('system_api_keys').select('api_key').eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle();
    if (!key.data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');

    const form2 = new FormData();
    form2.append('model', 'gpt-image-2');
    form2.append('image[]', image, 'flyer-page.png');
    form2.append('prompt', buildImprovePrompt(
      typeof contextName === 'string' && contextName.trim() ? contextName.trim() : undefined,
      typeof contextDescription === 'string' && contextDescription.trim() ? contextDescription.trim() : undefined
    ));
    form2.append('size', '1024x1536');
    form2.append('quality', 'medium');

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
