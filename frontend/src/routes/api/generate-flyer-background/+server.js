import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = env.VITE_SUPABASE_URL || '';
const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';

function getSupabase() {
  return createClient(supabaseUrl, supabaseKey);
}

async function getOpenAiKey() {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('system_api_keys')
      .select('api_key')
      .eq('service_name', 'openai')
      .eq('is_active', true)
      .limit(1)
      .single();
    if (error) throw error;
    return data?.api_key || null;
  } catch (e) {
    console.error('Failed to fetch OpenAI key:', e);
    return null;
  }
}

async function getBrandLogoUrl() {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('login_layout')
      .select('topbar')
      .limit(1)
      .single();
    if (error) throw error;
    return data?.topbar?.logo_url || null;
  } catch (e) {
    console.error('Failed to fetch brand logo (login_layout.topbar.logo_url):', e);
    return null;
  }
}

// Accepts either a data: URL or a remote http(s) URL and returns a Blob for multipart upload.
async function toImageBlob(urlOrDataUrl) {
  if (!urlOrDataUrl) return null;
  if (urlOrDataUrl.startsWith('data:')) {
    const [meta, base64] = urlOrDataUrl.split(',');
    const mimeMatch = /data:(.*);base64/.exec(meta);
    const mime = mimeMatch?.[1] || 'image/png';
    const buffer = Buffer.from(base64, 'base64');
    return new Blob([buffer], { type: mime });
  }
  const res = await fetch(urlOrDataUrl);
  if (!res.ok) throw new Error(`Failed to download reference image: ${urlOrDataUrl}`);
  const arrayBuffer = await res.arrayBuffer();
  const contentType = res.headers.get('content-type') || 'image/png';
  return new Blob([arrayBuffer], { type: contentType });
}

function buildPrompt({ offerDescriptionAr, colorTheme, cardCount, cardPositions, canvasWidth, canvasHeight, hasTemplateReference }) {
  const hasPositions = Array.isArray(cardPositions) && cardPositions.length === cardCount;
  const positionsList = hasPositions
    ? cardPositions
        .map((c, i) => `  Card ${i + 1}: left=${c.x}px, top=${c.y}px, width=${c.width}px, height=${c.height}px`)
        .join('\n')
    : null;

  const layoutSection = hasPositions
    ? `The canvas is exactly ${canvasWidth}×${canvasHeight}px. There are EXACTLY ${cardCount} product card placeholders, at these precise pixel positions (origin top-left, no rotation):
${positionsList}

Reproduce a blank card at each of these exact bounding boxes — matching left/top/width/height/length to the pixel, in the same order — layered on top of the new background/header art. The card's border must sit exactly on the given box (do not add outer padding/margin that shrinks or shifts the effective box). Do not add, remove, merge, resize, or reposition any card, and do not invent extra cards beyond this list.`
    : `Include exactly ${cardCount} product card placeholders, matching the fixed card height established in the reference image. Columns/card width may adjust to fit ${cardCount} cards, but card height must stay fixed.`;

  const referenceIntro = hasTemplateReference
    ? `Two reference images are attached:
1. "template-reference" — the PRIMARY structural reference. Study its header structure, logo position, offer-title position, product-card style, spacing, margins, footer, and overall proportions.
2. "brand-logo" — the exact brand logo. Use it exactly as provided: never redraw, recreate, recolor, restyle, distort, stretch, imitate, or crop important parts of it.`
    : `One reference image is attached: "brand-logo" — the exact brand logo. Use it exactly as provided: never redraw, recreate, recolor, restyle, distort, stretch, imitate, or crop important parts of it.

There is no existing template image to copy from — this is a brand-new template. Design an original A4 promotional flyer background from scratch, following standard retail-flyer conventions: decorative header/occasion artwork across the top, a clean grid of blank product cards in the middle, and a thin footer strip at the bottom.`;

  const structureLine = hasTemplateReference
    ? `Generate a new A4 Portrait flyer background (print-suitable proportions, matching the reference's aspect ratio) that follows the structural logic of the template reference, but with fresh header artwork, background, typography, lighting, and decorations suited to a "${colorTheme}" color theme.`
    : `Generate a new A4 Portrait flyer background (${canvasWidth}×${canvasHeight}px proportions, print-suitable) with header artwork, background, typography, lighting, and decorations suited to a "${colorTheme}" color theme.`;

  return `You are generating a fresh background/header design for a promotional flyer template.

${referenceIntro}

This template's description (in Arabic) is: "${offerDescriptionAr}"
Read it and determine which offer/occasion it refers to, then compose a short, accurate Arabic offer-title text from it to use as the flyer's headline. Do not invent an unrelated offer, and do not add random Arabic phrases that aren't supported by this description.

${structureLine}

Strict requirements:
- ${layoutSection}
- Cards are BLANK placeholders only: clean blank interior, thin visible border, rounded corners where suitable, enough room for later product insertion. Never add product images, product names, prices, price strips, price boxes, currency symbols, or extra information inside the cards.
- Render the composed Arabic offer-title text as bold 3D typography — extruded/dimensional lettering with depth, shading, and a highlight, not flat 2D text. This 3D treatment is mandatory for every generation, not optional. Keep it accurate and legible; creative styling is fine as long as the wording stays true to the description.
- Include one blank date-field placeholder in the footer strip (a plain empty box/bar with a thin border, no text or numbers pre-filled in it — it will be filled in later). Do not put any other text, labels, slogans, or decorative wording anywhere in the footer strip besides this blank date placeholder. Do not add branch names/addresses/location info, or a secondary logo unless the reference image already includes one that must be preserved.
- Keep the product-card area clean and ready for later editing; never let decorations overlap the product cards.
- Pick up at least one of the brand logo's own colors and use it somewhere in the background/header design (an accent, a gradient stop, a border, a decorative shape, etc.) so the flyer visibly ties back to the brand — every generation must do this, not just when it happens to suit the theme. Do this without altering the logo image itself.
- The header should creatively represent the offer/occasion implied by the description, using suitable scene elements, seasonal graphics, cultural motifs, or decorative artwork, without interfering with the product-card area.`;
}

export async function POST({ request }) {
  try {
    const {
      templateImageUrl,
      offerDescriptionAr,
      colorTheme,
      cardCount,
      cardPositions,
      canvasWidth,
      canvasHeight
    } = await request.json();

    if (!offerDescriptionAr || !offerDescriptionAr.trim()) {
      return json({ error: 'Arabic offer name/description is required (fill in the template Description field)' }, { status: 400 });
    }
    if (!colorTheme) {
      return json({ error: 'Color theme is required' }, { status: 400 });
    }
    if (!cardCount || cardCount < 1) {
      return json({ error: 'Invalid product card count' }, { status: 400 });
    }

    const [openAiKey, logoUrl] = await Promise.all([getOpenAiKey(), getBrandLogoUrl()]);

    if (!openAiKey) {
      return json(
        { error: 'OpenAI API key not configured. Set it in API Keys Manager (system_api_keys, service_name = "openai").' },
        { status: 500 }
      );
    }
    if (!logoUrl) {
      return json(
        { error: 'Brand logo not found. Upload it under Branding > Login Page > Top Bar logo first.' },
        { status: 500 }
      );
    }

    const [templateBlob, logoBlob] = await Promise.all([
      templateImageUrl ? toImageBlob(templateImageUrl) : Promise.resolve(null),
      toImageBlob(logoUrl)
    ]);

    const prompt = buildPrompt({
      offerDescriptionAr,
      colorTheme,
      cardCount,
      cardPositions,
      canvasWidth: canvasWidth || 794,
      canvasHeight: canvasHeight || 1123,
      hasTemplateReference: !!templateBlob
    });

    const form = new FormData();
    form.append('model', 'gpt-image-2');
    if (templateBlob) form.append('image[]', templateBlob, 'template-reference.png');
    form.append('image[]', logoBlob, 'brand-logo.png');
    form.append('prompt', prompt);
    form.append('size', '1024x1536');
    form.append('quality', 'medium');

    const openaiRes = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST',
      headers: { Authorization: `Bearer ${openAiKey}` },
      body: form
    });

    if (!openaiRes.ok) {
      const errText = await openaiRes.text();
      console.error('OpenAI image generation failed:', errText);
      return json({ error: 'Image generation failed', details: errText }, { status: 502 });
    }

    const result = await openaiRes.json();
    const b64 = result?.data?.[0]?.b64_json;
    if (!b64) {
      return json({ error: 'No image returned from OpenAI' }, { status: 502 });
    }

    const imageBuffer = Buffer.from(b64, 'base64');
    const fileName = `first-page-generated-${Date.now()}.png`;

    const supabase = getSupabase();
    const { error: uploadError } = await supabase.storage
      .from('flyer-templates')
      .upload(fileName, imageBuffer, { contentType: 'image/png', upsert: false });

    if (uploadError) {
      console.error('Failed to upload generated background:', uploadError);
      return json({ error: 'Failed to save generated image' }, { status: 500 });
    }

    const { data: { publicUrl } } = supabase.storage.from('flyer-templates').getPublicUrl(fileName);

    return json({ imageUrl: publicUrl });
  } catch (e) {
    console.error('generate-flyer-background error:', e);
    return json({ error: e?.message || 'Unexpected error' }, { status: 500 });
  }
}
