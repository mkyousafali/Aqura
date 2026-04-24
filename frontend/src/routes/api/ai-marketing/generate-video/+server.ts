/**
 * POST /api/ai-marketing/generate-video
 *
 * Generates a short marketing video using Google Veo 2 (text-to-video).
 * Flow:
 *  1. Build prompt from user input + character descriptions + brand hints
 *  2. Start Veo 2 long-running operation
 *  3. Poll until done (max 3 minutes)
 *  4. Upload video to Supabase storage
 *  5. Return signed URL
 */
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';
import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

// ─────────────────────────────────────────────────────────────────────────────
// Token cache (shared module-level cache — same pattern as generate-poster)
// ─────────────────────────────────────────────────────────────────────────────
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

  const clientEmail  = env.GOOGLE_CLIENT_EMAIL;
  const privateKeyRaw = env.GOOGLE_PRIVATE_KEY;
  if (!clientEmail || !privateKeyRaw) throw new Error('Missing Google credentials');
  const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

  const b64url = (buf: Buffer | string) =>
    Buffer.from(buf as any).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

  const now     = Math.floor(Date.now() / 1000);
  const header  = { alg: 'RS256', typ: 'JWT' };
  const payload = { iss: clientEmail, scope: 'https://www.googleapis.com/auth/cloud-platform', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 };
  const input   = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signer  = crypto.createSign('RSA-SHA256');
  signer.update(input);
  const jwt = `${input}.${b64url(signer.sign(privateKey))}`;

  const res  = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt })
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`Token error: ${JSON.stringify(data)}`);
  cachedToken = { value: data.access_token, expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return cachedToken.value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Map platform ratio → Veo-supported aspect ratio
// Veo 2 supports: "16:9", "9:16", "1:1"
// ─────────────────────────────────────────────────────────────────────────────
function toVeoRatio(aspectRatio: string): string {
  if (aspectRatio === '16:9') return '16:9';
  if (aspectRatio === '1:1')  return '1:1';
  return '9:16'; // default for stories/shorts
}

// ─────────────────────────────────────────────────────────────────────────────
// Main handler
// ─────────────────────────────────────────────────────────────────────────────
export const POST: RequestHandler = async ({ request }) => {
  let body: any;
  try { body = await request.json(); }
  catch { return json({ ok: false, message: 'Invalid JSON body' }, { status: 400 }); }

  const {
    brandId,
    platform      = 'instagram_story',
    aspectRatio   = '9:16',
    language      = 'ar',
    extraPrompt   = '',
    characters    = [],
    durationSeconds = 8,
    userId
  } = body;

  const supabase = createClient(
    env.SUPABASE_URL ?? env.VITE_SUPABASE_URL ?? '',
    env.SUPABASE_SERVICE_KEY ?? env.VITE_SUPABASE_SERVICE_KEY ?? ''
  );

  const projectId = env.GOOGLE_PROJECT_ID;
  if (!projectId) return json({ ok: false, message: 'Missing GOOGLE_PROJECT_ID env var' }, { status: 500 });

  // Brand info
  let brandInfo: any = null;
  if (brandId) {
    const { data } = await supabase
      .from('ai_brand_libraries')
      .select('id, name, logo_url, primary_color, accent_color, brand_tone, rules')
      .eq('id', brandId)
      .single();
    brandInfo = data;
  }

  const brandName    = brandInfo?.name          ?? '';
  const logoUrl      = brandInfo?.logo_url       ?? null;
  const primaryColor = brandInfo?.primary_color  ?? '#059669';
  const accentColor  = brandInfo?.accent_color   ?? '#f97316';
  const brandTone    = brandInfo?.brand_tone      ?? 'professional and warm';
  const brandRules   = brandInfo?.rules?.text     ?? '';

  // Resolve logo signed URL if it is a storage path
  let logoSignedUrl: string | null = null;
  if (logoUrl) {
    if (logoUrl.startsWith('http')) {
      logoSignedUrl = logoUrl;
    } else {
      const { data: ls } = await supabase.storage.from('ai-marketing-files').createSignedUrl(logoUrl, 3600);
      logoSignedUrl = ls?.signedUrl ?? null;
    }
  }

  const platformLabels: Record<string, string> = {
    instagram_feed: 'Instagram Feed (square)', instagram_story: 'Instagram Story (vertical)',
    facebook: 'Facebook post', twitter: 'Twitter/X post',
    whatsapp: 'WhatsApp Status', tiktok: 'TikTok short video', custom: 'custom format'
  };
  const platformLabel = platformLabels[platform] || platform;

  // Build the character constraint block
  const characterBlock = (characters as any[])
    .filter((c: any) => c.description || c.name)
    .map((c: any) => {
      const parts: string[] = [];
      if (c.name)        parts.push(`Character: "${c.name}"`);
      if (c.role)        parts.push(`role: ${c.role}`);
      if (c.description) parts.push(`appearance (do not change): ${c.description}`);
      return parts.join(', ');
    })
    .join('. ');

  const charHint  = characterBlock
    ? `IMPORTANT — keep the character exactly as described, do not change appearance: ${characterBlock}.`
    : '';
  // Do NOT include brand name — it causes Veo to render text in the video
  const brandHint = [
    brandTone    ? `Visual style: ${brandTone}.` : '',
    `Color palette: ${primaryColor} and ${accentColor}.`
  ].filter(Boolean).join(' ');

  const videoPrompt = [
    // Hard no-text guard — must be first so it takes priority
    'NO TEXT. NO CAPTIONS. NO SUBTITLES. NO WATERMARKS. NO WRITTEN WORDS OF ANY KIND in the video.',
    charHint,
    extraPrompt.trim(),
    `Cinematic quality, smooth camera movement, vibrant colors, professional marketing video for ${platformLabel}.`,
    brandHint
  ].filter(Boolean).join(' ');

  const veoRatio = toVeoRatio(aspectRatio);
  const dur      = Math.max(5, Math.min(8, Number(durationSeconds) || 8));

  // ── Step 1: Start Veo 2 long-running operation ─────────────────────────
  let accessToken: string;
  let operationName: string;

  try {
    accessToken = await getAccessToken();
    const veoRes = await fetch(
      `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/publishers/google/models/veo-2.0-generate-001:predictLongRunning`,
      {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          instances:  [{ prompt: videoPrompt }],
          parameters: {
            aspectRatio:     veoRatio,
            sampleCount:     1,
            durationSeconds: dur,
            enhancePrompt:   false,
            generateAudio:   false
          }
        })
      }
    );
    if (!veoRes.ok) {
      const errText = await veoRes.text();
      return json({ ok: false, stage: 'veo_start', message: errText, videoPrompt }, { status: 500 });
    }
    const veoData = await veoRes.json();
    operationName = veoData.name;
    if (!operationName) return json({ ok: false, stage: 'veo_start', message: 'No operation name returned', videoPrompt }, { status: 500 });
  } catch (err: any) {
    return json({ ok: false, stage: 'veo_start', message: err?.message ?? String(err), videoPrompt }, { status: 500 });
  }

  // ── Step 2: Poll until done (max 6 min) ───────────────────────────────
  // Veo 2 uses fetchPredictOperation (POST) not the generic operations GET
  let videoB64: string | null = null;
  let mimeType = 'video/mp4';
  const pollStart = Date.now();
  const maxWait   = 360_000; // 6 minutes — Veo 2 typically takes 4–6 min
  const fetchOpUrl = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/publishers/google/models/veo-2.0-generate-001:fetchPredictOperation`;

  while (Date.now() - pollStart < maxWait) {
    await new Promise(r => setTimeout(r, 10_000)); // poll every 10s

    let pollData: any;
    try {
      const pollRes = await fetch(fetchOpUrl, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${accessToken!}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ operationName })
      });
      if (!pollRes.ok) continue;
      pollData = await pollRes.json();
    } catch { continue; }

    if (!pollData.done) continue;

    if (pollData.error) {
      return json({ ok: false, stage: 'veo_poll', message: JSON.stringify(pollData.error), videoPrompt }, { status: 500 });
    }

    const resp = pollData.response ?? {};

    // Try multiple known response shapes for Veo 2
    const videoEntry =
      resp.videos?.[0]               ??   // GenerateVideoResponse shape
      resp.predictions?.[0]          ??   // PredictResponse shape
      resp.generatedSamples?.[0]?.video ?? null;

    if (videoEntry?.bytesBase64Encoded) {
      videoB64 = videoEntry.bytesBase64Encoded;
      mimeType  = videoEntry.mimeType ?? 'video/mp4';
      break;
    }

    // Unknown format — return raw for debugging
    return json({
      ok: false, stage: 'veo_parse',
      message: `Unrecognised Veo response: ${JSON.stringify(resp).slice(0, 600)}`,
      videoPrompt
    }, { status: 500 });
  }

  if (!videoB64) {
    return json({ ok: false, stage: 'veo_timeout', message: 'Video generation timed out after 6 minutes', videoPrompt }, { status: 500 });
  }

  // ── Step 3: Upload to Supabase storage ────────────────────────────────
  const ext         = mimeType.includes('mp4') ? 'mp4' : 'webm';
  const timestamp   = Date.now();
  const storagePath = `generated/videos/${timestamp}.${ext}`;
  const videoBuf    = Buffer.from(videoB64, 'base64');

  const { error: uploadError } = await supabase.storage
    .from('ai-marketing-files')
    .upload(storagePath, videoBuf, { contentType: mimeType, upsert: false });

  if (uploadError) {
    return json({ ok: false, stage: 'upload', message: uploadError.message, videoPrompt }, { status: 500 });
  }

  // ── Step 4: DB record ─────────────────────────────────────────────────
  const { data: fileRecord, error: dbError } = await supabase
    .from('ai_marketing_files')
    .insert({
      brand_id:          brandId || null,
      title:             extraPrompt.slice(0, 120) || (brandName + ' Video'),
      file_type:         'video',
      storage_path:      storagePath,
      thumbnail_url:     storagePath,
      platform,
      aspect_ratio:      aspectRatio,
      language,
      generation_prompt: videoPrompt,
      generation_params: { brandId, platform, aspectRatio, language, extraPrompt, durationSeconds: dur },
      created_by:        userId || null
    })
    .select('id')
    .single();

  if (dbError) console.error('[generate-video] DB insert error:', dbError);

  // ── Step 5: Signed URL ────────────────────────────────────────────────
  const { data: signed } = await supabase.storage
    .from('ai-marketing-files')
    .createSignedUrl(storagePath, 3600);

  return json({
    ok:          true,
    fileId:      fileRecord?.id ?? null,
    signedUrl:   signed?.signedUrl ?? null,
    logoSignedUrl,
    videoPrompt,
    storagePath
  });
};
