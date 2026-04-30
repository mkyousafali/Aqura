/**
 * Supabase Edge Function: ai-poll-video
 *
 * Polls Veo 2 for a given operationName (returned by ai-generate-video-start).
 * If done, uploads video to Supabase storage, inserts DB record, returns signed URL.
 * If still running, returns { ok: true, done: false }.
 *
 * Usage:
 *   POST https://supabase.urbanaqura.com/functions/v1/ai-poll-video
 *   Body: { operationName, videoPrompt, brandId, platform, aspectRatio, language, extraPrompt, durationSeconds, userId }
 *   Returns (pending): { ok: true, done: false }
 *   Returns (done):    { ok: true, done: true, signedUrl, fileId, logoSignedUrl, videoPrompt }
 *   Returns (error):   { ok: false, stage, message }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ============================================================================
// HARDCODED CREDENTIALS
// ============================================================================
const GOOGLE_PROJECT_ID = "aqura-488113";
const GOOGLE_CLIENT_EMAIL = "aqura-ai-marketing@aqura-488113.iam.gserviceaccount.com";
const GOOGLE_PRIVATE_KEY = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDSZoshhuYr43OH\nEz7qTzsHu4ZGhai4zhQaa6zXc+5p6plPE/4PMmxPIU2T9D1V3oA0Ylze6KuFbCg7\nL/OR9BruOREjX4YLLWyQBD+hYquGX0nuRbR29cMWISxWB/atEcw+Qw9XKpchTjci\nui13qcChR1TeVzxhCVSIhaymID0iRuSylZxRLTAe3DvrPCltH2WGRTiLAMttVqoa\nXAeK6TYj0UUeqItlkqLA25URxl0hovS5O2rxvKpxp4dxQHkipQ4N0fFbmRBdb/cz\nUmxYyS8mIOT+NyGPAvF3EeD/hIHpz6ieitiwLW4i9/CML9AVGVGxXyRAavMeYAKG\nf5DCu7BZAgMBAAECggEAVHJT5WD/gR4JgG15ExI53yClBCkhTwtnhjMxbEhbqKdA\nYTzk+7SBREFZocil1ZE4Y84W+GDqduKyQw8785jGNlcxScFNS68vo54Q6/VuYsBc\nLAZOKHD7nCY0ZVNM7qn2EAdaYOH3Rqbd+lI/bYf0iMbYiWT6FvhntWPxp7vIzbhr\n5ZyG0KT192wiGs3H6Vc8YhPur25qsxf5r2LFS8t6M04ukA/PS0ozb+ecLvRyv5dt\npByUB1Da0PGA5nNnfmRjO8pmRj8aqi1pcpfkuFUxxkONin1+dHX7eSwv3PJMDC4N\nZ+kFboG84iuWqGrw5aar3S33Yl9L5goUGdLWsX3TAQKBgQD3P5rzY7NTE2MndrSW\nPkixIz3ANik6AH08vBX9D+lORsQJvfhcKJPVU9PgCRwQYGT6OH4JAr4T7u/PhVzs\nJS5m56U3+8IdvaJuqWUTZa2Ka6zVhHcsg5TLr3dv0AsZFAqn99uZCFolSypTT3KA\nBB/xO5ViXjeYwRxif4Hy6Cw8SwKBgQDZ2QxKbzrjnsLz/5YvnCkt6WkY/9kur3hy\nR5LDpJGZZMGI8TXL8CJRiCxWwr3nV+C7A3F4AfHMXxgW/NH5ggT2kD3VPddAFNLy\nvP1QscQIHtbneaR2vQ+gpjSDyF46InCqey1ADKkhQKyr/dBgGXcGuqznuD9cLlW+\n0kphZKNXawKBgAk7T77MtzJf4/DiRsXhV3d9uF2H6CwpPoPZBf0n7e8lR0aR2Ecg\noLxzX9LapDicUMji+Rm/B3fZEQ0vjpOmo7/l4E5h0RKpNPpqysJZpownjxF927FG\nzHR6fbwoCXILRIaXA5UIMc14rADmU4EiJkssjVxZ5juG4ldvKVv3fUdXAoGBAKXo\n36twuvDP4LnjVYY88D+/HAOmFsmvaZPfXq8RjrG8QokA62++GuTtSJdrCSY/jy/e\nl3RGRtjXM4mOUnwrwYvmnrDgwCZVtbKYrHPgbuOgWRtBUTf9FQHMkwIqf1jXEedE\nmFnHSqfAkcELNL97pWLCmRyA/gA+aZ9CmNNDygKxAoGBAN0ZvgKmIpjrRXwM7RYF\nSejYc+DWkHQKar24bqzBepBxgBV3MI4cVypCSpJXf6BBl8YVSovvs51Za76wkcWm\nkA6KEGQEre0LY/UdabdLQiSgIgbgZcRYTkuf6U6YbntU6ViqUuOUlwIG/ZTLLiUw\nKAeewq+RGAmVcQA37PPhtqFu\n-----END PRIVATE KEY-----\n";

const SUPABASE_INTERNAL_URL = "http://kong:8000";
const SUPABASE_PUBLIC_URL = "https://supabase.urbanaqura.com";
const SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0";

// ============================================================================
// TOKEN GENERATION
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
      operationName,
      videoPrompt = "",
      brandId = null,
      platform = "instagram_story",
      aspectRatio = "9:16",
      language = "ar",
      extraPrompt = "",
      durationSeconds = 8,
      userId = null,
    } = body;

    if (!operationName) {
      return new Response(
        JSON.stringify({ ok: false, message: "operationName is required" }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    console.log("[ai-poll-video] Polling operation:", operationName);

    // ── Poll Veo 2 operation (once) ──────────────────────────────────────────
    const accessToken = await getAccessToken();

    // Use a 25s timeout so Supabase wall-clock limit doesn't kill us mid-request
    const controller = new AbortController();
    const abortTimer = setTimeout(() => controller.abort(), 25_000);

    let pollRes: Response;
    try {
      pollRes = await fetch(
        `https://us-central1-aiplatform.googleapis.com/v1/projects/${GOOGLE_PROJECT_ID}/locations/us-central1/publishers/google/models/veo-3.0-generate-001:fetchPredictOperation`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
          body: JSON.stringify({ operationName }),
          signal: controller.signal,
        }
      );
    } catch (fetchErr: any) {
      clearTimeout(abortTimer);
      // Timed out or network error — tell frontend to retry
      console.log("[ai-poll-video] Poll fetch timed out or errored, will retry:", fetchErr?.message);
      return new Response(
        JSON.stringify({ ok: true, done: false }),
        { headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }
    clearTimeout(abortTimer);

    if (!pollRes.ok) {
      const errText = await pollRes.text();
      console.error("[ai-poll-video] Poll request failed:", errText);
      // Don't fail hard — might be transient, let frontend retry
      return new Response(
        JSON.stringify({ ok: true, done: false, pollError: errText }),
        { headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    const pollData = await pollRes.json();

    // Still running
    if (!pollData.done) {
      return new Response(
        JSON.stringify({ ok: true, done: false }),
        { headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    // Veo reported an error
    if (pollData.error) {
      return new Response(
        JSON.stringify({ ok: false, done: true, stage: "veo_poll", message: pollData.error?.message ?? JSON.stringify(pollData.error), videoPrompt }),
        { status: 200, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    // Extract video base64
    const resp = pollData.response ?? {};
    const videoEntry =
      resp.videos?.[0] ??
      resp.predictions?.[0] ??
      resp.generatedSamples?.[0]?.video ??
      null;

    if (!videoEntry?.bytesBase64Encoded) {
      return new Response(
        JSON.stringify({ ok: false, done: true, stage: "veo_parse", message: `Unrecognised Veo response: ${JSON.stringify(resp).slice(0, 600)}`, videoPrompt }),
        { status: 200, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    const videoB64 = videoEntry.bytesBase64Encoded as string;
    const mimeType = (videoEntry.mimeType as string | undefined) ?? "video/mp4";
    const ext = mimeType.includes("mp4") ? "mp4" : "webm";
    const timestamp = Date.now();
    const storagePath = `generated/videos/${timestamp}.${ext}`;

    console.log("[ai-poll-video] Video ready, uploading to storage...");

    // ── Upload to Supabase storage via REST ──────────────────────────────────
    const videoBytes = Uint8Array.from(atob(videoB64), (c) => c.charCodeAt(0));

    const uploadRes = await fetch(
      `${SUPABASE_INTERNAL_URL}/storage/v1/object/ai-marketing-files/${storagePath}`,
      {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": mimeType,
          "x-upsert": "false",
        },
        body: videoBytes,
      }
    );

    if (!uploadRes.ok) {
      const uploadErr = await uploadRes.text();
      console.error("[ai-poll-video] Storage upload failed:", uploadErr);
      return new Response(
        JSON.stringify({ ok: false, done: true, stage: "upload", message: uploadErr, videoPrompt }),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    console.log("[ai-poll-video] Uploaded to storage:", storagePath);

    // ── Get brand name for DB record ─────────────────────────────────────────
    let brandName = "";
    let logoStoragePath: string | null = null;
    if (brandId) {
      try {
        const brandRes = await fetch(
          `${SUPABASE_INTERNAL_URL}/rest/v1/ai_brand_libraries?id=eq.${brandId}&select=name,logo_url&limit=1`,
          {
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            },
          }
        );
        if (brandRes.ok) {
          const brands = await brandRes.json();
          if (Array.isArray(brands) && brands.length > 0) {
            brandName = brands[0].name ?? "";
            logoStoragePath = brands[0].logo_url ?? null;
          }
        }
      } catch (e) {
        console.error("[ai-poll-video] Brand fetch error:", e);
      }
    }

    // ── Insert DB record ─────────────────────────────────────────────────────
    const dbPayload = {
      brand_id: brandId || null,
      title: extraPrompt.slice(0, 120) || (brandName ? `${brandName} Video` : "Marketing Video"),
      file_type: "video",
      storage_path: storagePath,
      thumbnail_url: storagePath,
      platform,
      aspect_ratio: aspectRatio,
      language,
      generation_prompt: videoPrompt,
      generation_params: { brandId, platform, aspectRatio, language, extraPrompt, durationSeconds },
      created_by: userId || null,
    };

    const dbRes = await fetch(`${SUPABASE_INTERNAL_URL}/rest/v1/ai_marketing_files`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(dbPayload),
    });

    let fileId: string | null = null;
    if (dbRes.ok) {
      const dbData = await dbRes.json();
      fileId = Array.isArray(dbData) ? dbData[0]?.id ?? null : dbData?.id ?? null;
    } else {
      console.error("[ai-poll-video] DB insert error:", await dbRes.text());
    }

    // ── Get signed URL ───────────────────────────────────────────────────────
    const signRes = await fetch(
      `${SUPABASE_INTERNAL_URL}/storage/v1/object/sign/ai-marketing-files/${storagePath}`,
      {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ expiresIn: 3600 }),
      }
    );

    let signedUrl: string | null = null;
    if (signRes.ok) {
      const signData = await signRes.json();
      // signedURL returned by storage is "/object/sign/..." (without /storage/v1)
      const signedPath = signData.signedURL ?? signData.signedUrl ?? null;
      if (signedPath) {
        const prefix = signedPath.startsWith("/storage/v1") ? "" : "/storage/v1";
        signedUrl = `${SUPABASE_PUBLIC_URL}${prefix}${signedPath}`;
      }
    }

    // ── Get logo signed URL ──────────────────────────────────────────────────
    let logoSignedUrl: string | null = null;
    if (logoStoragePath) {
      if (logoStoragePath.startsWith("http")) {
        logoSignedUrl = logoStoragePath;
      } else {
        try {
          const logoSignRes = await fetch(
            `${SUPABASE_INTERNAL_URL}/storage/v1/object/sign/ai-marketing-files/${logoStoragePath}`,
            {
              method: "POST",
              headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({ expiresIn: 3600 }),
            }
          );
          if (logoSignRes.ok) {
            const logoSignData = await logoSignRes.json();
            const logoSignedPath = logoSignData.signedURL ?? logoSignData.signedUrl ?? null;
            if (logoSignedPath) {
              const prefix = logoSignedPath.startsWith("/storage/v1") ? "" : "/storage/v1";
              logoSignedUrl = `${SUPABASE_PUBLIC_URL}${prefix}${logoSignedPath}`;
            }
          }
        } catch (e) {
          console.error("[ai-poll-video] Logo sign error:", e);
        }
      }
    }

    console.log("[ai-poll-video] Done. fileId:", fileId, "signedUrl:", signedUrl ? "✅" : "❌");

    return new Response(
      JSON.stringify({
        ok: true,
        done: true,
        signedUrl,
        fileId,
        logoSignedUrl,
        videoPrompt,
        storagePath,
      }),
      { headers: { ...CORS, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[ai-poll-video] Error:", err?.message);
    return new Response(
      JSON.stringify({ ok: false, done: true, stage: "poll", message: err?.message ?? String(err) }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }
});
