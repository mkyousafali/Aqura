import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import type { RequestHandler } from '@sveltejs/kit';

export const config = { maxDuration: 120 };

// Region Edit: regenerates ONE small, user-drawn crop of an already-saved flyer page, not the
// whole page. This is the reliable alternative to constraining a full-page edit with OpenAI's
// `mask` parameter — real-world reports confirm gpt-image-1/2's edit endpoint does soft,
// whole-image regeneration even with a mask, so nothing outside an edited region is actually
// guaranteed to survive. Sending only the crop sidesteps that: the model's entire canvas IS the
// selected area, so there is no "rest of the image" left for it to drift on. The caller
// (AiFlyerGenerator.svelte) crops the region client-side, sends just that crop here, and pastes
// the result back onto the full page at the same coordinates once this returns.
const inputSchema = z.object({
  // A data: URL rather than a Storage URL/multipart upload — the crop is always small (a user-drawn
  // box, not a full page), so it comfortably fits Vercel's request body cap without needing the
  // fetch-from-Storage indirection /improve and /artwork use for their much larger full-page images.
  imageDataUrl: z.string().min(1).max(8_000_000),
  instruction: z.string().trim().min(1).max(300),
  // Internal AI visual-direction guidance, e.g. "Fruit & Vegetable Offer" — optional, minor flavor
  // only; this endpoint's prompt is deliberately literal/narrow and must not invite decoration.
  contextName: z.string().trim().min(1).max(100).optional(),
  contextDescription: z.string().trim().min(1).max(500).optional()
}).strict();

function buildEditRegionPrompt(instruction: string, contextName?: string, contextDescription?: string): string {
  return `This is a small cropped region from a supermarket flyer page. Apply EXACTLY this one change, and nothing else: "${instruction}"

Keep everything else in this crop visually identical to the input — the same background, fonts, colors and style — unless the instruction above specifically asks to change it. Do not add any extra decoration, caption, icon, badge, or content beyond what the instruction asks for; do not redesign, restyle, or "improve" anything not mentioned. If the instruction asks to remove something, cleanly fill that space with a plausible continuation of the surrounding background/pattern rather than leaving a hole or an obvious patch. Any text or numerals you output must be crisp, correctly spelled, and — if Arabic — grammatically correct; never garbled or approximated.${contextName ? `\n\nFor reference only, this flyer's overall theme is "${contextName}" (${contextDescription}) — this does not license adding anything beyond the instruction above.` : ''}`;
}

export const POST: RequestHandler = async ({ request, url }) => {
  try {
    if (request.headers.get('origin') && request.headers.get('origin') !== url.origin)
      return json({ error: 'Invalid request origin.' }, { status: 403 });
    const input = inputSchema.safeParse(await request.json());
    if (!input.success) return json({ error: 'A selected region and an instruction are required.' }, { status: 400 });

    const match = /^data:image\/png;base64,([a-zA-Z0-9+/=]+)$/.exec(input.data.imageDataUrl);
    if (!match) return json({ error: 'The selected region could not be read.' }, { status: 400 });
    const imageBytes = Buffer.from(match[1], 'base64');
    if (!imageBytes.length) return json({ error: 'The selected region is empty.' }, { status: 400 });
    if (imageBytes.length > 6_000_000) return json({ error: 'The selected region is too large — draw a smaller box.' }, { status: 400 });

    const databaseUrl = env.VITE_SUPABASE_URL;
    const databaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
    if (!databaseUrl || !databaseKey) throw new Error('Server database configuration is missing.');
    const db = createClient(databaseUrl, databaseKey, { auth: { persistSession: false } });
    const key = await db.from('system_api_keys').select('api_key').eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle();
    if (!key.data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');

    const form = new FormData();
    form.append('model', 'gpt-image-2');
    form.append('image[]', new Blob([imageBytes], { type: 'image/png' }), 'region.png');
    form.append('prompt', buildEditRegionPrompt(input.data.instruction, input.data.contextName, input.data.contextDescription));
    form.append('quality', 'medium');

    const response = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST', headers: { Authorization: `Bearer ${key.data.api_key}` }, body: form,
      signal: AbortSignal.timeout(100000)
    });
    const result = await response.json();
    if (!response.ok) {
      const detail = String(result.error?.message || 'Region edit failed.').replaceAll(key.data.api_key, '[redacted]').slice(0, 600);
      return json({ error: `OpenAI image service ${response.status}: ${detail}` }, { status: 502 });
    }
    const encoded = result.data?.[0]?.b64_json;
    if (typeof encoded !== 'string' || !encoded) throw new Error('OpenAI returned no edited region.');
    const bytes = Buffer.from(encoded, 'base64');
    return new Response(bytes, { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error && error.name === 'TimeoutError' ? 'Region edit timed out. Please retry.' : 'Could not edit this region. Check the server configuration and retry.' }, { status: 500 });
  }
};
