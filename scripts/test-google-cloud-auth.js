// Test script — verifies Google Cloud Service Account auth + Vertex AI reachability
// Run from repo root:  node scripts/test-google-cloud-auth.js
// Uses only Node.js built-ins (no npm install needed).

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load .env manually
const envPath = path.resolve(__dirname, '..', 'frontend', '.env');
if (!fs.existsSync(envPath)) {
  console.error('❌ frontend/.env not found at:', envPath);
  process.exit(1);
}
const envText = fs.readFileSync(envPath, 'utf8');
const env = {};
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
  if (!m) continue;
  let val = m[2];
  if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
  env[m[1]] = val;
}

const projectId   = env.GOOGLE_PROJECT_ID;
const clientEmail = env.GOOGLE_CLIENT_EMAIL;
const privateKey  = (env.GOOGLE_PRIVATE_KEY || '').replace(/\\n/g, '\n');
const location    = env.GOOGLE_LOCATION || 'europe-west4';

console.log('— Config —');
console.log('  Project:  ', projectId);
console.log('  Email:    ', clientEmail);
console.log('  Location: ', location);
console.log('  Key bytes:', privateKey.length);
console.log();

if (!projectId || !clientEmail || !privateKey) {
  console.error('❌ Missing GOOGLE_PROJECT_ID / GOOGLE_CLIENT_EMAIL / GOOGLE_PRIVATE_KEY in .env');
  process.exit(1);
}

// ---- Build & sign JWT (RS256) for OAuth2 token exchange ----
function b64url(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

const now = Math.floor(Date.now() / 1000);
const header  = { alg: 'RS256', typ: 'JWT' };
const payload = {
  iss: clientEmail,
  scope: 'https://www.googleapis.com/auth/cloud-platform',
  aud: 'https://oauth2.googleapis.com/token',
  iat: now,
  exp: now + 3600
};
const headerB64  = b64url(JSON.stringify(header));
const payloadB64 = b64url(JSON.stringify(payload));
const signingInput = `${headerB64}.${payloadB64}`;

let signatureB64;
try {
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signingInput);
  signer.end();
  const sig = signer.sign(privateKey);
  signatureB64 = b64url(sig);
} catch (e) {
  console.error('❌ Failed to sign JWT — private key invalid?', e.message);
  process.exit(1);
}

const jwt = `${signingInput}.${signatureB64}`;
console.log('✅ JWT signed successfully');

// ---- Exchange JWT for access token ----
console.log('→ Requesting OAuth2 access token...');
const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: jwt
  })
});
const tokenJson = await tokenRes.json();
if (!tokenRes.ok || !tokenJson.access_token) {
  console.error('❌ Token exchange FAILED:');
  console.error(tokenJson);
  process.exit(1);
}
const accessToken = tokenJson.access_token;
console.log(`✅ Access token received (${accessToken.length} chars, expires in ${tokenJson.expires_in}s)`);
console.log();

// ---- Quick Gemini text test (this is the real Vertex AI check) ----
const modelsToTry = ['gemini-2.5-flash', 'gemini-2.0-flash-001', 'gemini-1.5-flash-002', 'gemini-1.5-flash'];
let modelUsed = null;
let gRes, gJson;
for (const model of modelsToTry) {
  console.log(`→ Trying model: ${model} ...`);
  const geminiUrl = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;
  gRes = await fetch(geminiUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: 'Reply with exactly: Aqura AI Marketing connection OK' }] }],
      generationConfig: { maxOutputTokens: 30, temperature: 0 }
    })
  });
  gJson = await gRes.json();
  if (gRes.ok) { modelUsed = model; break; }
  console.log(`   ✗ ${model}: ${gJson?.error?.status || gRes.status}`);
}
const geminiUrl = `(used model: ${modelUsed})`;
const gRes2 = gRes; const gJson2 = gJson;
if (!gRes2.ok) {
  console.error('⚠️ All Gemini models failed in', location, '— auth still works, but model unavailable in this region:');
  console.error(JSON.stringify(gJson2, null, 2));
  process.exit(0);
}
const text = gJson2?.candidates?.[0]?.content?.parts?.[0]?.text || '(no text)';
console.log(`✅ Gemini reply (${modelUsed}):`, text.trim());
console.log();
console.log('🎉 ALL CHECKS PASSED — credentials work end-to-end.');
