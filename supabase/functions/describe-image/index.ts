/**
 * Supabase Edge Function: describe-image
 * 
 * Takes an uploaded image (base64) and returns a concise text description
 * suitable for use as a background/setting description in image/video generation prompts.
 * 
 * Uses Google Gemini 2.5 Flash multimodal model.
 * 
 * Usage:
 *   POST https://your-project.supabase.co/functions/v1/describe-image
 *   Body: { imageB64: "iVBORw0KGgo...", mimeType: "image/jpeg" }
 *   Response: { ok: true, description: "..." }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ============================================================================
// HARDCODED GOOGLE CLOUD CREDENTIALS
// ============================================================================
const GOOGLE_PROJECT_ID = "aqura-488113";
const GOOGLE_CLIENT_EMAIL = "aqura-ai-marketing@aqura-488113.iam.gserviceaccount.com";
const GOOGLE_PRIVATE_KEY = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDSZoshhuYr43OH\nEz7qTzsHu4ZGhai4zhQaa6zXc+5p6plPE/4PMmxPIU2T9D1V3oA0Ylze6KuFbCg7\nL/OR9BruOREjX4YLLWyQBD+hYquGX0nuRbR29cMWISxWB/atEcw+Qw9XKpchTjci\nui13qcChR1TeVzxhCVSIhaymID0iRuSylZxRLTAe3DvrPCltH2WGRTiLAMttVqoa\nXAeK6TYj0UUeqItlkqLA25URxl0hovS5O2rxvKpxp4dxQHkipQ4N0fFbmRBdb/cz\nUmxYyS8mIOT+NyGPAvF3EeD/hIHpz6ieitiwLW4i9/CML9AVGVGxXyRAavMeYAKG\nf5DCu7BZAgMBAAECggEAVHJT5WD/gR4JgG15ExI53yClBCkhTwtnhjMxbEhbqKdA\nYTzk+7SBREFZocil1ZE4Y84W+GDqduKyQw8785jGNlcxScFNS68vo54Q6/VuYsBc\nLAZOKHD7nCY0ZVNM7qn2EAdaYOH3Rqbd+lI/bYf0iMbYiWT6FvhntWPxp7vIzbhr\n5ZyG0KT192wiGs3H6Vc8YhPur25qsxf5r2LFS8t6M04ukA/PS0ozb+ecLvRyv5dt\npByUB1Da0PGA5nNnfmRjO8pmRj8aqi1pcpfkuFUxxkONin1+dHX7eSwv3PJMDC4N\nZ+kFboG84iuWqGrw5aar3S33Yl9L5goUGdLWsX3TAQKBgQD3P5rzY7NTE2MndrSW\nPkixIz3ANik6AH08vBX9D+lORsQJvfhcKJPVU9PgCRwQYGT6OH4JAr4T7u/PhVzs\nJS5m56U3+8IdvaJuqWUTZa2Ka6zVhHcsg5TLr3dv0AsZFAqn99uZCFolSypTT3KA\nBB/xO5ViXjeYwRxif4Hy6Cw8SwKBgQDZ2QxKbzrjnsLz/5YvnCkt6WkY/9kur3hy\nR5LDpJGZZMGI8TXL8CJRiCxWwr3nV+C7A3F4AfHMXxgW/NH5ggT2kD3VPddAFNLy\nvP1QscQIHtbneaR2vQ+gpjSDyF46InCqey1ADKkhQKyr/dBgGXcGuqznuD9cLlW+\n0kphZKNXawKBgAk7T77MtzJf4/DiRsXhV3d9uF2H6CwpPoPZBf0n7e8lR0aR2Ecg\noLxzX9LapDicUMji+Rm/B3fZEQ0vjpOmo7/l4E5h0RKpNPpqysJZpownjxF927FG\nzHR6fbwoCXILRIaXA5UIMc14rADmU4EiJkssjVxZ5juG4ldvKVv3fUdXAoGBAKXo\n36twuvDP4LnjVYY88D+/HAOmFsmvaZPfXq8RjrG8QokA62++GuTtSJdrCSY/jy/e\nl3RGRtjXM4mOUnwrwYvmnrDgwCZVtbKYrHPgbuOgWRtBUTf9FQHMkwIqf1jXEedE\nmFnHSqfAkcELNL97pWLCmRyA/gA+aZ9CmNNDygKxAoGBAN0ZvgKmIpjrRXwM7RYF\nSejYc+DWkHQKar24bqzBepBxgBV3MI4cVypCSpJXf6BBl8YVSovvs51Za76wkcWm\nkA6KEGQEre0LY/UdabdLQiSgIgbgZcRYTkuf6U6YbntU6ViqUuOUlwIG/ZTLLiUw\nKAeewq+RGAmVcQA37PPhtqFu\n-----END PRIVATE KEY-----\n";
const GOOGLE_LOCATION = "europe-west4";

let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const b64url = (buf: ArrayBuffer) => {
    const bytes = new Uint8Array(buf);
    let binary = "";
    for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  };

  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })).buffer);
  const now = Math.floor(Date.now() / 1000);
  const claim = b64url(new TextEncoder().encode(JSON.stringify({
    iss: GOOGLE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  })).buffer);

  const signingInput = `${header}.${claim}`;

  const pemLines = GOOGLE_PRIVATE_KEY.split("\n").filter(l => l && !l.includes("-----"));
  const pemB64 = pemLines.join("");
  const binaryDer = Uint8Array.from(atob(pemB64), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sigBuf = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${b64url(sigBuf)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
  }
  cachedToken = { value: data.access_token, expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return cachedToken.value;
}

async function describeWithGemini(imageB64: string, mimeType: string, language: string, token: string): Promise<string> {
  const url = `https://${GOOGLE_LOCATION}-aiplatform.googleapis.com/v1/projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_LOCATION}/publishers/google/models/gemini-2.5-flash:generateContent`;

  const instruction = language === "ar"
    ? "صف هذه الصورة كمشهد خلفية لإعلان تسويقي. ركّز على المكان (داخلي/خارجي)، الإضاءة، الألوان السائدة، الديكور، الأجواء، والعناصر البصرية المهمة. لا تذكر أي أشخاص. اكتب وصفاً مدمجاً من جملتين أو ثلاث (بحدود 50 كلمة) باللغة الإنجليزية فقط لأنها ستُستخدم في توليد صورة بالذكاء الاصطناعي."
    : "Describe this image as a background scene for a marketing advert. Focus on the setting (indoor/outdoor), lighting, dominant colors, decor, mood, and important visual elements. Do NOT mention any people. Write a concise 2-3 sentence description (~50 words) in English, suitable for use in an AI image generation prompt.";

  const body = {
    contents: [{
      role: "user",
      parts: [
        { inlineData: { mimeType: mimeType || "image/jpeg", data: imageB64 } },
        { text: instruction },
      ],
    }],
    generationConfig: { temperature: 0.4, maxOutputTokens: 200 },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Gemini Vision error [${res.status}]: ${JSON.stringify(data)}`);
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!text) throw new Error(`Gemini returned empty description: ${JSON.stringify(data)}`);
  return String(text).trim();
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { imageB64, mimeType, language = "en" } = await req.json();
    if (!imageB64) throw new Error("Missing imageB64");

    console.log("[describe-image] Request:", { mimeType, language, b64len: imageB64.length });

    const token = await getAccessToken();
    const description = await describeWithGemini(imageB64, mimeType, language, token);

    console.log("[describe-image] Description:", description);

    return new Response(JSON.stringify({ ok: true, description }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err: any) {
    console.error("[describe-image] Error:", err?.message);
    return new Response(JSON.stringify({ ok: false, error: err?.message ?? String(err) }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
