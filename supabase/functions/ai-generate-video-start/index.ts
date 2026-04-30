/**
 * Supabase Edge Function: ai-generate-video-start
 *
 * Starts a Veo 2 video generation operation and returns the operationName immediately.
 * Frontend then polls ai-poll-video every 10s until done.
 *
 * Usage:
 *   POST https://supabase.urbanaqura.com/functions/v1/ai-generate-video-start
 *   Body: { brandId, platform, aspectRatio, language, extraPrompt, characters, durationSeconds, userId }
 *   Returns: { ok: true, operationName, videoPrompt }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ============================================================================
// HARDCODED GOOGLE CLOUD CREDENTIALS (stored securely on server)
// ============================================================================
const GOOGLE_PROJECT_ID = "aqura-488113";
const GOOGLE_CLIENT_EMAIL = "aqura-ai-marketing@aqura-488113.iam.gserviceaccount.com";
const GOOGLE_PRIVATE_KEY = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDSZoshhuYr43OH\nEz7qTzsHu4ZGhai4zhQaa6zXc+5p6plPE/4PMmxPIU2T9D1V3oA0Ylze6KuFbCg7\nL/OR9BruOREjX4YLLWyQBD+hYquGX0nuRbR29cMWISxWB/atEcw+Qw9XKpchTjci\nui13qcChR1TeVzxhCVSIhaymID0iRuSylZxRLTAe3DvrPCltH2WGRTiLAMttVqoa\nXAeK6TYj0UUeqItlkqLA25URxl0hovS5O2rxvKpxp4dxQHkipQ4N0fFbmRBdb/cz\nUmxYyS8mIOT+NyGPAvF3EeD/hIHpz6ieitiwLW4i9/CML9AVGVGxXyRAavMeYAKG\nf5DCu7BZAgMBAAECggEAVHJT5WD/gR4JgG15ExI53yClBCkhTwtnhjMxbEhbqKdA\nYTzk+7SBREFZocil1ZE4Y84W+GDqduKyQw8785jGNlcxScFNS68vo54Q6/VuYsBc\nLAZOKHD7nCY0ZVNM7qn2EAdaYOH3Rqbd+lI/bYf0iMbYiWT6FvhntWPxp7vIzbhr\n5ZyG0KT192wiGs3H6Vc8YhPur25qsxf5r2LFS8t6M04ukA/PS0ozb+ecLvRyv5dt\npByUB1Da0PGA5nNnfmRjO8pmRj8aqi1pcpfkuFUxxkONin1+dHX7eSwv3PJMDC4N\nZ+kFboG84iuWqGrw5aar3S33Yl9L5goUGdLWsX3TAQKBgQD3P5rzY7NTE2MndrSW\nPkixIz3ANik6AH08vBX9D+lORsQJvfhcKJPVU9PgCRwQYGT6OH4JAr4T7u/PhVzs\nJS5m56U3+8IdvaJuqWUTZa2Ka6zVhHcsg5TLr3dv0AsZFAqn99uZCFolSypTT3KA\nBB/xO5ViXjeYwRxif4Hy6Cw8SwKBgQDZ2QxKbzrjnsLz/5YvnCkt6WkY/9kur3hy\nR5LDpJGZZMGI8TXL8CJRiCxWwr3nV+C7A3F4AfHMXxgW/NH5ggT2kD3VPddAFNLy\nvP1QscQIHtbneaR2vQ+gpjSDyF46InCqey1ADKkhQKyr/dBgGXcGuqznuD9cLlW+\n0kphZKNXawKBgAk7T77MtzJf4/DiRsXhV3d9uF2H6CwpPoPZBf0n7e8lR0aR2Ecg\noLxzX9LapDicUMji+Rm/B3fZEQ0vjpOmo7/l4E5h0RKpNPpqysJZpownjxF927FG\nzHR6fbwoCXILRIaXA5UIMc14rADmU4EiJkssjVxZ5juG4ldvKVv3fUdXAoGBAKXo\n36twuvDP4LnjVYY88D+/HAOmFsmvaZPfXq8RjrG8QokA62++GuTtSJdrCSY/jy/e\nl3RGRtjXM4mOUnwrwYvmnrDgwCZVtbKYrHPgbuOgWRtBUTf9FQHMkwIqf1jXEedE\nmFnHSqfAkcELNL97pWLCmRyA/gA+aZ9CmNNDygKxAoGBAN0ZvgKmIpjrRXwM7RYF\nSejYc+DWkHQKar24bqzBepBxgBV3MI4cVypCSpJXf6BBl8YVSovvs51Za76wkcWm\nkA6KEGQEre0LY/UdabdLQiSgIgbgZcRYTkuf6U6YbntU6ViqUuOUlwIG/ZTLLiUw\nKAeewq+RGAmVcQA37PPhtqFu\n-----END PRIVATE KEY-----\n";

// ============================================================================
// TOKEN GENERATION (Web Crypto API — Deno compatible)
// ============================================================================
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

  const b64url = (buf: ArrayBuffer) => {
    const bytes = new Uint8Array(buf);
    let binary = "";
    for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  };

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: GOOGLE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const headerB64 = b64url(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = b64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const keyPem = GOOGLE_PRIVATE_KEY.replace(/\\n/g, "\n");
  const keyLines = keyPem.split("\n").filter((l) => l && !l.includes("BEGIN") && !l.includes("END"));
  const keyBinary = atob(keyLines.join(""));
  const keyBytes = new Uint8Array(keyBinary.length);
  for (let i = 0; i < keyBinary.length; i++) keyBytes[i] = keyBinary.charCodeAt(i);

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBuf = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${b64url(signatureBuf)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }).toString(),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);

  cachedToken = { value: data.access_token, expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return cachedToken.value;
}

function toVeoRatio(aspectRatio: string): string {
  if (aspectRatio === "16:9") return "16:9";
  if (aspectRatio === "1:1") return "1:1";
  return "9:16";
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// ============================================================================
// MAIN HANDLER
// ============================================================================
serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...CORS, "Content-Type": "application/json" } });

  try {
    const body = await req.json();
    const {
      platform = "instagram_story",
      aspectRatio = "9:16",
      language = "ar",
      extraPrompt = "",
      characters = [],
      durationSeconds = 8,
      brandPrimaryColor = "#059669",
      brandAccentColor = "#f97316",
      brandTone = "professional and warm",
    } = body;

    const platformLabels: Record<string, string> = {
      instagram_feed: "Instagram Feed (square)",
      instagram_story: "Instagram Story (vertical)",
      facebook: "Facebook post",
      twitter: "Twitter/X post",
      whatsapp: "WhatsApp Status",
      tiktok: "TikTok short video",
      custom: "custom format",
    };
    const platformLabel = platformLabels[platform] || platform;

    // Build character constraint block
    const characterBlock = (characters as any[])
      .filter((c: any) => c.description || c.name)
      .map((c: any) => {
        const parts: string[] = [];
        if (c.name) parts.push(`Character: "${c.name}"`);
        if (c.role) parts.push(`role: ${c.role}`);
        if (c.description) parts.push(`appearance (do not change): ${c.description}`);
        return parts.join(", ");
      })
      .join(". ");

    const charHint = characterBlock
      ? `IMPORTANT — keep the character exactly as described, do not change appearance: ${characterBlock}.`
      : "";

    const brandHint = [
      brandTone ? `Visual style: ${brandTone}.` : "",
      `Color palette: ${brandPrimaryColor} and ${brandAccentColor}.`,
    ].filter(Boolean).join(" ");

    const videoPrompt = [
      "NO TEXT. NO CAPTIONS. NO SUBTITLES. NO WATERMARKS. NO WRITTEN WORDS OF ANY KIND visible in the video.",
      charHint,
      extraPrompt.trim(),
      `Cinematic quality, smooth camera movement, vibrant colors, professional marketing video for ${platformLabel}.`,
      brandHint,
      "Include upbeat background music and natural ambient sound.",
    ].filter(Boolean).join(" ");

    const veoRatio = toVeoRatio(aspectRatio);
    const dur = Math.max(5, Math.min(8, Number(durationSeconds) || 8));

    console.log("[ai-generate-video-start] Starting Veo 2 operation, prompt length:", videoPrompt.length);

    const accessToken = await getAccessToken();

    const veoRes = await fetch(
      `https://us-central1-aiplatform.googleapis.com/v1/projects/${GOOGLE_PROJECT_ID}/locations/us-central1/publishers/google/models/veo-3.0-generate-001:predictLongRunning`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          instances: [{ prompt: videoPrompt }],
          parameters: {
            aspectRatio: veoRatio,
            sampleCount: 1,
            durationSeconds: dur,
            enhancePrompt: true,
            generateAudio: true,
          },
        }),
      }
    );

    if (!veoRes.ok) {
      const errText = await veoRes.text();
      console.error("[ai-generate-video-start] Veo start failed:", errText);
      return new Response(
        JSON.stringify({ ok: false, stage: "veo_start", message: errText, videoPrompt }),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    const veoData = await veoRes.json();
    const operationName = veoData.name;

    if (!operationName) {
      return new Response(
        JSON.stringify({ ok: false, stage: "veo_start", message: "No operation name returned", videoPrompt }),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    console.log("[ai-generate-video-start] Operation started:", operationName);

    return new Response(
      JSON.stringify({ ok: true, operationName, videoPrompt }),
      { headers: { ...CORS, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[ai-generate-video-start] Error:", err?.message);
    return new Response(
      JSON.stringify({ ok: false, stage: "start", message: err?.message ?? String(err) }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }
});
