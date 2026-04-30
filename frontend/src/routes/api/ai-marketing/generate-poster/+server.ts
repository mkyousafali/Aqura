/**
 * POST /api/ai-marketing/generate-poster
 *
 * Simple pipeline:
 *  1. Receive { prompt, platform, aspectRatio, userId }
 *  2. Send prompt directly to Gemini image generation
 *  3. Upload result to Supabase storage
 *  4. Return signed URL
 */
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';
import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

export const config = { maxDuration: 300 };

let cachedToken = null;

async function getAccessToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;
  const clientEmail   = env.GOOGLE_CLIENT_EMAIL;
  const privateKeyRaw = env.GOOGLE_PRIVATE_KEY;
  if (!clientEmail || !privateKeyRaw) throw new Error('Missing GOOGLE_CLIENT_EMAIL or GOOGLE_PRIVATE_KEY');
  const privateKey = privateKeyRaw.replace(/\\n/g, '\n');
  const b64url = (buf) =>
    Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
  const now = Math.floor(Date.now() / 1000);
  const header  = { alg: 'RS256', typ: 'JWT' };
  const payload = { iss: clientEmail, scope: 'https://www.googleapis.com/auth/cloud-platform', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 };
  const input = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(input);
  const jwt = `${input}.${b64url(signer.sign(privateKey))}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt })
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`Token exchange failed [${res.status}]: ${JSON.stringify(data)}`);
  cachedToken = { value: data.access_token, expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return cachedToken.value;
}

async function generateImageWithGemini(prompt, token) {
  const projectId = env.GOOGLE_PROJECT_ID;
  const model = 'gemini-2.0-flash-preview-image-generation';
  const url = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/publishers/google/models/${model}:generateContent`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig: { responseModalities: ['IMAGE'] } })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Gemini image gen [${res.status}]: ${JSON.stringify(data).substring(0, 600)}`);
  const parts   = data?.candidates?.[0]?.content?.parts ?? [];
  const imgPart = parts.find((p) => p.inlineData?.mimeType?.startsWith('image/'));
  if (!imgPart) throw new Error('Gemini returned no image');
  return { b64: imgPart.inlineData.data, mimeType: imgPart.inlineData.mimeType };
}

export const POST = async ({ request }) => {
  if (!env.GOOGLE_PROJECT_ID || !env.GOOGLE_CLIENT_EMAIL || !env.GOOGLE_PRIVATE_KEY)
    return json({ ok: false, message: 'Missing Google credentials' }, { status: 500 });
  let body;
  try { body = await request.json(); }
  catch { return json({ ok: false, message: 'Invalid JSON body' }, { status: 400 }); }
  const { prompt, platform = 'instagram_feed', aspectRatio = '1:1', userId } = body;
  if (!prompt?.trim()) return json({ ok: false, message: 'Prompt is required' }, { status: 400 });
  const supabase = createClient(env.SUPABASE_URL ?? env.VITE_SUPABASE_URL ?? '', env.SUPABASE_SERVICE_KEY ?? env.VITE_SUPABASE_SERVICE_KEY ?? '');
  try {
    const token = await getAccessToken();
    console.log('[generate-poster] Gemini:', JSON.stringify(prompt).substring(0, 200));
    const { b64, mimeType } = await generateImageWithGemini(prompt.trim(), token);
    const ext = mimeType.includes('png') ? 'png' : 'jpg';
    const storagePath = `generated/posters/${Date.now()}.${ext}`;
    const imageBuffer = Buffer.from(b64, 'base64');
    const { error: uploadError } = await supabase.storage.from('ai-marketing-files').upload(storagePath, imageBuffer, { contentType: mimeType, upsert: false });
    if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);
    try {
      await supabase.from('ai_marketing_files').insert({
        title: prompt.trim().substring(0, 120), file_type: 'poster', storage_path: storagePath,
        thumbnail_url: storagePath, platform, aspect_ratio: aspectRatio, generation_prompt: prompt,
        generation_params: { platform, aspectRatio, prompt }, created_by: userId || null
      });
    } catch {}
    const { data: signed } = await supabase.storage.from('ai-marketing-files').createSignedUrl(storagePath, 3600);
    return json({ ok: true, signedUrl: signed?.signedUrl ?? null, storagePath });
  } catch (err) {
    console.error('[generate-poster]', err?.message);
    return json({ ok: false, message: err?.message ?? String(err) }, { status: 500 });
  }
};
