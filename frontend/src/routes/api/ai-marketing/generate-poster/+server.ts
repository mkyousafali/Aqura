/**
 * POST /api/ai-marketing/generate-poster
 *
 * Architecture:
 *  1. Gemini writes a prompt for a DECORATIVE BACKGROUND ONLY (empty zones for products/logo/text)
 *  2. Imagen generates the background
 *  3. Sharp composites ON TOP:
 *     - Real product image(s) from DB/client
 *     - Brand logo
 *     - Product name(s) text
 *     - Price badge(s) with before/after prices
 *     - Optional headline
 */
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';
import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import sharp from 'sharp';

// ─────────────────────────────────────────────────────────────────────────────
// Token cache
// ─────────────────────────────────────────────────────────────────────────────
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

const clientEmail = env.GOOGLE_CLIENT_EMAIL;
const privateKeyRaw = env.GOOGLE_PRIVATE_KEY;
if (!clientEmail || !privateKeyRaw) throw new Error('Missing Google credentials');
const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

const b64url = (buf: Buffer | string) =>
Buffer.from(buf as any).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

const now = Math.floor(Date.now() / 1000);
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
// Gemini text generation
// ─────────────────────────────────────────────────────────────────────────────
async function callGemini(prompt: string, token: string): Promise<string> {
const projectId = env.GOOGLE_PROJECT_ID;
const location  = env.GOOGLE_LOCATION || 'europe-west4';
const model     = 'gemini-2.5-flash';
const url = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;

const res = await fetch(url, {
method: 'POST',
headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }] })
});
const data = await res.json();
if (!res.ok) throw new Error(`Gemini error: ${JSON.stringify(data)}`);
return data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Imagen 3 — text-to-image, with optional subject reference images
// ─────────────────────────────────────────────────────────────────────────────
interface ReferenceImage {
  referenceId:   number;
  referenceType: 'REFERENCE_TYPE_SUBJECT' | 'REFERENCE_TYPE_STYLE';
  image: { bytesBase64Encoded: string };
  subjectImageConfig?: { subjectType: string };
}

async function callImagen(
  prompt:          string,
  aspectRatio:     string,
  token:           string,
  referenceImages: ReferenceImage[] = [],
  model = 'imagen-3.0-fast-generate-001'
): Promise<string> {
const projectId = env.GOOGLE_PROJECT_ID;
const url = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/publishers/google/models/${model}:predict`;

const instance: any = { prompt };
if (referenceImages.length > 0) instance.referenceImages = referenceImages;

const res = await fetch(url, {
method: 'POST',
headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
body: JSON.stringify({
instances: [instance],
parameters: { sampleCount: 1, aspectRatio, safetyFilterLevel: 'block_some', personGeneration: 'allow_adult' }
})
});
const data = await res.json();
if (!res.ok) throw new Error(`Imagen error: ${JSON.stringify(data)}`);
const b64 = data?.predictions?.[0]?.bytesBase64Encoded;
if (!b64) throw new Error(`Imagen returned no image. Response: ${JSON.stringify(data)}`);
return b64;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetch a remote image as Buffer (8 s timeout)
// ─────────────────────────────────────────────────────────────────────────────
async function fetchImageBuffer(url: string): Promise<Buffer | null> {
try {
const ctrl = new AbortController();
const t = setTimeout(() => ctrl.abort(), 8000);
const res = await fetch(url, { signal: ctrl.signal });
clearTimeout(t);
if (!res.ok) return null;
return Buffer.from(await res.arrayBuffer());
} catch {
return null;
}
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────────────────
interface Rect { left: number; top: number; width: number; height: number }

function calcProductZones(W: number, H: number, count: number): Rect[] {
const zones: Rect[] = [];
const topOffset  = Math.round(H * 0.09);
const zoneH      = Math.round(H * 0.52);
const totalWidth = Math.round(W * 0.86);
const startX     = Math.round(W * 0.07);
const gap        = Math.round(W * 0.03);

if (count === 1) {
const zoneW = Math.round(totalWidth * 0.60);
zones.push({ left: Math.round((W - zoneW) / 2), top: topOffset, width: zoneW, height: zoneH });
} else if (count === 2) {
const zoneW = Math.round((totalWidth - gap) / 2);
zones.push({ left: startX, top: topOffset, width: zoneW, height: zoneH });
zones.push({ left: startX + zoneW + gap, top: topOffset, width: zoneW, height: zoneH });
} else {
const zoneW = Math.round((totalWidth - gap * 2) / 3);
for (let i = 0; i < 3; i++) {
zones.push({ left: startX + i * (zoneW + gap), top: topOffset, width: zoneW, height: zoneH });
}
}
return zones;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
	const h = hex.replace('#', '').padEnd(6, '0');
	return {
		r: parseInt(h.substring(0, 2), 16) || 0,
		g: parseInt(h.substring(2, 4), 16) || 0,
		b: parseInt(h.substring(4, 6), 16) || 0,
	};
}

async function roundedImage(
	buf: Buffer, w: number, h: number, radius: number,
	bg: { r: number; g: number; b: number } = { r: 255, g: 255, b: 255 }
): Promise<Buffer> {
	const svg = `<svg width="${w}" height="${h}"><rect x="0" y="0" width="${w}" height="${h}" rx="${radius}" ry="${radius}" fill="white"/></svg>`;
	return sharp(buf)
		.resize(w, h, { fit: 'contain', background: { r: bg.r, g: bg.g, b: bg.b, alpha: 255 } })
		.composite([{ input: Buffer.from(svg), blend: 'dest-in' }])
		.png()
		.toBuffer();
}

function isDark(hex: string): boolean {
const h = hex.replace('#', '');
const r = parseInt(h.substring(0, 2), 16) || 0;
const g = parseInt(h.substring(2, 4), 16) || 0;
const b = parseInt(h.substring(4, 6), 16) || 0;
return (0.299 * r + 0.587 * g + 0.114 * b) < 128;
}

function escSvg(s: string): string {
return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

/** Truncate text so it fits within maxWidth pixels at given fontSize */
function truncSvg(text: string, fontSize: number, maxWidth: number, charWidthFactor = 0.58): string {
	const maxChars = Math.floor(maxWidth / (fontSize * charWidthFactor));
	if (!text || text.length <= maxChars) return text;
	return text.substring(0, Math.max(1, maxChars - 1)) + '…';
}

// ─────────────────────────────────────────────────────────────────────────────
// SVG overlay: product names + price badges + headline + brand name
// ─────────────────────────────────────────────────────────────────────────────
// librsvg-compatible SVG builder:
// - NO rgba() → use fill + fill-opacity / opacity separately
// - NO dominant-baseline → use explicit y offsets
// - NO filter references on elements (not reliable in librsvg)
// - NO direction attribute on text
function buildOverlaySVG(opts: {
	W: number; H: number;
	products: Array<{
		nameAr:           string;
		nameEn:           string;
		priceBeforeOffer: string;
		priceAfterOffer:  string;
		zone:             Rect;
	}>;
	headline:     string;
	brandName:    string;
	accentColor:  string;
	primaryColor: string;
	language:     'ar' | 'en';
}): string {
	const { W, H, products, headline, brandName, accentColor, primaryColor, language } = opts;
	const fontFam = 'Arial';

	// ── Build defs for headline gradient (must be before use) ───────────────
	const hFS       = Math.round(W * 0.064);
	const hY        = Math.round(H * 0.095);
	const gradTop   = hY - hFS - 4;
	const gradBot   = hY + 6;

	// Gold surface gradient: near-white highlight → pure gold → accent → deep brown
	const headlineDefs = headline.trim() ? `<defs>
  <linearGradient id="hsurf" x1="0" y1="${gradTop}" x2="0" y2="${gradBot}" gradientUnits="userSpaceOnUse">
    <stop offset="0%" stop-color="#fffde8"/>
    <stop offset="18%" stop-color="#ffd700"/>
    <stop offset="55%" stop-color="${accentColor}"/>
    <stop offset="100%" stop-color="#6b2800"/>
  </linearGradient>
</defs>` : '';

	let svg = `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">${headlineDefs}`;

	// ── Headline — proper 3D extruded style ──────────────────────────────────
	if (headline.trim()) {
		const hPad = Math.round(hFS * 0.55);
		const hW   = Math.min(W - 12, headline.length * hFS * 0.70 + hPad * 2);
		const hX   = Math.round((W - hW) / 2);
		const cx   = Math.round(W / 2);

		// Semi-transparent dark pill backing (keeps text readable on any bg)
		svg += `<rect x="${hX}" y="${hY - hFS - hPad + 8}" width="${hW}" height="${hFS + hPad * 2}" rx="16" fill="#000000" fill-opacity="0.52"/>`;

		// ── Drop shadow (deepest, largest offset) ──
		svg += `<text x="${cx + 14}" y="${hY + 14}" font-family="${fontFam}" font-size="${hFS}" font-weight="bold" fill="#000000" fill-opacity="0.72" text-anchor="middle">${escSvg(headline)}</text>`;

		// ── Extrusion body: 10 stacked layers = dark crimson "depth" ──
		// Bottom-most body layer to top-most body layer
		for (let d = 10; d >= 1; d--) {
			// Gradually lighten body from deep maroon to mid-red as we go up
			const rVal = Math.round(80 + d * 8);  // 88 → 160
			const bodyFill = `rgb(${rVal},0,0)`;
			svg += `<text x="${cx + d}" y="${hY + d}" font-family="${fontFam}" font-size="${hFS}" font-weight="bold" fill="${bodyFill}" fill-opacity="1" text-anchor="middle">${escSvg(headline)}</text>`;
		}

		// ── Gold gradient surface (main, top layer) ──
		svg += `<text x="${cx}" y="${hY}" font-family="${fontFam}" font-size="${hFS}" font-weight="bold" fill="url(#hsurf)" text-anchor="middle">${escSvg(headline)}</text>`;

		// ── Specular highlight: semi-transparent white shifted up-left ──
		svg += `<text x="${cx - 2}" y="${hY - 4}" font-family="${fontFam}" font-size="${hFS}" font-weight="bold" fill="#ffffff" fill-opacity="0.22" text-anchor="middle">${escSvg(headline)}</text>`;
	}

	// Per-product overlays
	for (const p of products) {
		const { zone, nameAr, nameEn, priceBeforeOffer, priceAfterOffer } = p;
		const cx  = Math.round(zone.left + zone.width / 2);

		// ── Name band: fixed at bottom of zone, always shows AR + EN ──────────
		const arFS    = Math.round(W * 0.028);
		const enFS    = Math.round(W * 0.017);
		const bandPad = Math.round(zone.width * 0.06);
		const textW   = zone.width - bandPad * 2;
		const bandH   = Math.round(zone.height * 0.22); // covers bottom 22% of zone
		const bandY   = zone.top + zone.height - bandH;   // anchored to zone bottom

		svg += `<rect x="${zone.left}" y="${bandY}" width="${zone.width}" height="${bandH}" rx="0" fill="#000000" fill-opacity="0.78"/>`;

		// Arabic name (large, bold)
		const arY = bandY + Math.round(arFS * 1.25);
		if (nameAr) {
			svg += `<text x="${cx}" y="${arY}" font-family="${fontFam}" font-size="${arFS}" font-weight="bold" fill="#ffffff" text-anchor="middle">${escSvg(truncSvg(nameAr, arFS, textW))}</text>`;
		}
		// English name (smaller, grey, below Arabic)
		const enY = arY + Math.round(enFS * 1.6);
		if (nameEn) {
			svg += `<text x="${cx}" y="${enY}" font-family="${fontFam}" font-size="${enFS}" fill="#bbbbbb" text-anchor="middle">${escSvg(truncSvg(nameEn, enFS, textW))}</text>`;
		}

		// ── Price badge: right side, centred at 62% of zone height (above name band) ──
		const hasPrices = priceBeforeOffer || priceAfterOffer;
		if (hasPrices) {
			const badgeR  = Math.round(zone.width * 0.27);
			const badgeCX = zone.left + zone.width - Math.round(badgeR * 0.55);
			const badgeCY = zone.top  + Math.round(zone.height * 0.60);
			const tc      = isDark(accentColor) ? '#ffffff' : '#1a1a1a';

			// Drop shadow
			svg += `<circle cx="${badgeCX + 4}" cy="${badgeCY + 4}" r="${badgeR}" fill="#000000" fill-opacity="0.35"/>`;
			// Main badge
			svg += `<circle cx="${badgeCX}" cy="${badgeCY}" r="${badgeR}" fill="${accentColor}"/>`;
			// Inner ring
			svg += `<circle cx="${badgeCX}" cy="${badgeCY}" r="${Math.round(badgeR * 0.88)}" fill="none" stroke="#ffffff" stroke-width="2" stroke-opacity="0.35"/>`;

			if (priceBeforeOffer && priceAfterOffer) {
				// Two-price layout: before (small, struck) + after (large, bold)
				const smFS  = Math.round(badgeR * 0.28);
				const lgFS  = Math.round(badgeR * 0.52);
				const sarFS = Math.round(badgeR * 0.20);

				// Before price: placed in upper portion of circle
				const beforeY = badgeCY - Math.round(badgeR * 0.28);
				// Strikethrough line at mid-character height
				const stY     = beforeY - Math.round(smFS * 0.40);
				const stHalf  = Math.round(smFS * String(priceBeforeOffer).length * 0.44);

				svg += `<text x="${badgeCX}" y="${beforeY}" font-family="${fontFam}" font-size="${smFS}" fill="#ffffff" fill-opacity="0.55" text-anchor="middle">${escSvg(priceBeforeOffer)}</text>`;
				// Red strikethrough line
				svg += `<line x1="${badgeCX - stHalf}" y1="${stY}" x2="${badgeCX + stHalf}" y2="${stY}" stroke="#ff3333" stroke-width="2.5" stroke-opacity="1"/>`;

				// After price: large, bold, centred below
				const afterY = badgeCY + Math.round(badgeR * 0.18);
				svg += `<text x="${badgeCX}" y="${afterY}" font-family="${fontFam}" font-size="${lgFS}" font-weight="bold" fill="${tc}" text-anchor="middle">${escSvg(priceAfterOffer)}</text>`;

				// SAR label below after price
				const sarY = badgeCY + Math.round(badgeR * 0.52);
				svg += `<text x="${badgeCX}" y="${sarY}" font-family="${fontFam}" font-size="${sarFS}" fill="${tc}" text-anchor="middle">SAR</text>`;
			} else {
				// Single price
				const lgFS  = Math.round(badgeR * 0.52);
				const sarFS = Math.round(badgeR * 0.22);
				const priceY = badgeCY + Math.round(lgFS * 0.28);
				const sarY   = priceY + sarFS + 4;
				const pv     = priceAfterOffer || priceBeforeOffer;
				svg += `<text x="${badgeCX}" y="${priceY}" font-family="${fontFam}" font-size="${lgFS}" font-weight="bold" fill="${tc}" text-anchor="middle">${escSvg(pv)}</text>`;
				svg += `<text x="${badgeCX}" y="${sarY}" font-family="${fontFam}" font-size="${sarFS}" fill="${tc}" text-anchor="middle">SAR</text>`;
			}
		}
	}

	svg += '</svg>';
	return svg;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sharp compositing
// ─────────────────────────────────────────────────────────────────────────────
async function compositePoster(opts: {
backgroundB64: string;
products: Array<{
imageBuffer:      Buffer | null;
nameAr:           string;
nameEn:           string;
priceBeforeOffer: string;
priceAfterOffer:  string;
}>;
logoBuffer:   Buffer | null;
headline:     string;
brandName:    string;
accentColor:  string;
primaryColor: string;
language:     'ar' | 'en';
}): Promise<Buffer> {
const { backgroundB64, products, logoBuffer, headline, brandName, accentColor, primaryColor, language } = opts;

const bgBuf  = Buffer.from(backgroundB64, 'base64');
const bgMeta = await sharp(bgBuf).metadata();
const W = bgMeta.width  ?? 1080;
const H = bgMeta.height ?? 1080;

const composites: sharp.OverlayOptions[] = [];
const zones = calcProductZones(W, H, products.length);

// Product images — pad=0.01 so product fills the full zone
for (let i = 0; i < products.length; i++) {
const p    = products[i];
const zone = zones[i];
if (!p.imageBuffer) continue;

const pad    = 0.01;
const innerW = Math.round(zone.width  * (1 - pad * 2));
const innerH = Math.round(zone.height * (1 - pad * 2));
const innerL = zone.left + Math.round(zone.width  * pad);
const innerT = zone.top  + Math.round(zone.height * pad);

try {
	const radius  = Math.round(Math.min(innerW, innerH) * 0.04);
	const bgRgb   = hexToRgb(primaryColor);
	const prodBuf = await roundedImage(p.imageBuffer, innerW, innerH, radius, bgRgb);
	composites.push({ input: prodBuf, left: innerL, top: innerT });
} catch {
	const bgRgb = hexToRgb(primaryColor);
	const resized = await sharp(p.imageBuffer)
		.resize(innerW, innerH, { fit: 'contain', background: { r: bgRgb.r, g: bgRgb.g, b: bgRgb.b, alpha: 255 } })
		.png().toBuffer();
	composites.push({ input: resized, left: innerL, top: innerT });
}
}

// Brand logo — white rounded-rect backing + logo on top
if (logoBuffer) {
const logoSize  = Math.round(W * 0.13);
const logoPad   = Math.round(W * 0.025);
const bgPadding = Math.round(logoSize * 0.18);
const bgSize    = logoSize + bgPadding * 2;
const logoLeft  = language === 'ar' ? W - logoSize - logoPad : logoPad;
const logoTop   = logoPad;
try {
	// White rounded-rect behind logo
	const logoBgSvg = `<svg width="${bgSize}" height="${bgSize}" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="0" width="${bgSize}" height="${bgSize}" rx="${Math.round(bgSize * 0.16)}" fill="#ffffff"/></svg>`;
	const logoBgPng = await sharp(Buffer.from(logoBgSvg)).png().toBuffer();
	const bgLeft = logoLeft - bgPadding;
	const bgTop  = logoTop - bgPadding;
	composites.push({ input: logoBgPng, left: Math.max(0, bgLeft), top: Math.max(0, bgTop) });
	// Logo image on top
	const logoResized = await sharp(logoBuffer)
		.resize(logoSize, logoSize, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 0 } })
		.png().toBuffer();
	composites.push({ input: logoResized, left: logoLeft, top: logoTop });
} catch { /* skip */ }
}

// SVG text/price overlay
const overlayData = products.map((p, i) => ({
nameAr:           p.nameAr,
nameEn:           p.nameEn,
priceBeforeOffer: p.priceBeforeOffer,
priceAfterOffer:  p.priceAfterOffer,
zone:             zones[i]
}));
const svg = buildOverlaySVG({ W, H, products: overlayData, headline, brandName, accentColor, primaryColor, language });
composites.push({ input: Buffer.from(svg) });

return sharp(bgBuf).composite(composites).png().toBuffer();
}

// ─────────────────────────────────────────────────────────────────────────────
// POST handler
// ─────────────────────────────────────────────────────────────────────────────
export const POST: RequestHandler = async ({ request }) => {
const projectId = env.GOOGLE_PROJECT_ID;
if (!projectId || !env.GOOGLE_CLIENT_EMAIL || !env.GOOGLE_PRIVATE_KEY) {
return json({ ok: false, message: 'Google Cloud credentials not configured' }, { status: 400 });
}

let body: any;
try { body = await request.json(); }
catch { return json({ ok: false, message: 'Invalid JSON body' }, { status: 400 }); }

const { brandId, products: clientProducts = [], platform, aspectRatio = '1:1', language = 'ar', extraPrompt = '', headline = '', characters: clientCharacters = [], userId } = body;

const supabase = createClient(
env.SUPABASE_URL ?? env.VITE_SUPABASE_URL ?? '',
env.SUPABASE_SERVICE_KEY ?? env.VITE_SUPABASE_SERVICE_KEY ?? ''
);

// Brand info
let brandInfo: any = null;
if (brandId) {
const { data } = await supabase
.from('ai_brand_libraries')
.select('id, name, primary_color, secondary_color, accent_color, brand_tone, rules, logo_url')
.eq('id', brandId)
.single();
brandInfo = data;
}

const brandName    = brandInfo?.name         ?? 'Urban Market';
const primaryColor = brandInfo?.primary_color ?? '#059669';
const accentColor  = brandInfo?.accent_color  ?? '#f97316';
const brandTone    = brandInfo?.brand_tone     ?? 'professional and warm';
const brandRules   = brandInfo?.rules?.text    ?? '';

const products   = (clientProducts as any[]).slice(0, 3);
const productIds = products.map((p: any) => p.id).filter(Boolean);

const platformLabels: Record<string, string> = {
instagram_feed: 'Instagram Feed (square)', instagram_story: 'Instagram Story (vertical)',
facebook: 'Facebook post', twitter: 'Twitter/X post',
whatsapp: 'WhatsApp Status', tiktok: 'TikTok thumbnail', custom: 'custom format'
};
const platformLabel = platformLabels[platform] || platform;

// ── Step 1: Build Imagen prompt ───────────────────────────────────────
const productCount   = products.length;
const hasOfferPrices = products.some((p: any) => p.priceAfterOffer || p.priceBeforeOffer);

let accessToken: string;
let backgroundPrompt: string;
let backgroundB64: string;

try {
accessToken = await getAccessToken();

if (productCount === 0) {
  const charList = clientCharacters as any[];
  const hasCharacters = charList.length > 0;
  const brandHint    = brandRules ? ` Brand style: ${brandRules}.` : '';
  const colorHint    = `Color palette: primary ${primaryColor}, accent ${accentColor}.`;
  const platformHint = `Optimized for ${platformLabel}.`;
  const qualityHint  = '3D cartoon animation style, photorealistic quality, cinematic lighting.';

  if (hasCharacters) {
    // Use Imagen subject-reference: pass character image(s) as reference so Imagen draws
    // the character naturally IN the described scene — no compositing needed
    const charDescBlock = charList
      .filter((c: any) => c.description || c.name)
      .map((c: any) => [c.name, c.role, c.description].filter(Boolean).join(', '))
      .join('; ');

    backgroundPrompt = [
      charDescBlock ? `${charDescBlock},` : '',
      extraPrompt.trim() || 'standing in an attractive supermarket setting, welcoming pose',
      colorHint, platformHint, qualityHint, brandHint
    ].filter(Boolean).join(' ');
  } else {
    // No characters — send user's prompt DIRECTLY to Imagen without modification
    backgroundPrompt = [extraPrompt.trim(), colorHint, platformHint, qualityHint, brandHint].filter(Boolean).join(' ');
  }
} else {
  // ── Products present: Gemini writes a background-with-product-zones prompt ──
  const bgPromptInstruction = `You are a retail poster background designer.
Write ONE Imagen 3 prompt for a DECORATIVE BACKGROUND ONLY for a ${platformLabel} marketing poster.

The background must:
1. Have ${productCount === 1 ? 'one large, clean, bright rectangular/oval empty space in the center' : `${productCount} clearly separated, clean empty rectangular zones side-by-side in the center`} — these zones must be visually distinct (white, cream, or frosted glass) so product images can be placed there
2. Have a wide horizontal semi-transparent dark band across the lower third — for product names text
3. ${hasOfferPrices ? `Have ${productCount} empty circular badge space(s) at bottom-right of each product zone — for price labels` : ''}
4. Have a small clean square zone in the top-${language === 'ar' ? 'right' : 'left'} corner for a brand logo (leave it empty)
5. Be filled with attractive decorative elements AROUND these empty zones: branded gradients, bokeh lights, geometric shapes, ribbons, confetti, or soft patterns
6. Use brand colors: primary ${primaryColor}, accent ${accentColor}
7. NO text, NO numbers, NO products, NO logos anywhere in the generated image
8. Style: ${brandTone}, premium retail, photorealistic quality
9. Platform: ${platformLabel}
${brandRules ? `Brand rules: ${brandRules}` : ''}
${extraPrompt ? `Extra: ${extraPrompt}` : ''}

Output ONLY the Imagen 3 prompt text — no preamble, no markdown.`;
  backgroundPrompt = (await callGemini(bgPromptInstruction, accessToken)).trim();
  if (!backgroundPrompt) throw new Error('Gemini returned empty background prompt');
}
} catch (err: any) {
return json({ ok: false, stage: 'prompt_generation', message: err?.message ?? String(err) }, { status: 500 });
}

try {
  // For no-products with characters: fetch char images, convert to base64, pass as subject references
  let referenceImages: ReferenceImage[] = [];
  if (productCount === 0 && (clientCharacters as any[]).length > 0) {
    const charList = clientCharacters as any[];
    const charUrlResults = await Promise.all(charList.map(async (c: any) => {
      if (!c.image_url) return null;
      const url = (c.image_url.startsWith('http') || c.image_url.startsWith('blob:'))
        ? c.image_url
        : (await supabase.storage.from('ai-marketing-files').createSignedUrl(c.image_url, 300)).data?.signedUrl ?? null;
      return url ? fetchImageBuffer(url) : null;
    }));

    referenceImages = charUrlResults
      .map((buf, i) => buf ? ({
        referenceId:   i + 1,
        referenceType: 'REFERENCE_TYPE_SUBJECT' as const,
        image: { bytesBase64Encoded: buf.toString('base64') },
        subjectImageConfig: { subjectType: 'SUBJECT_TYPE_DEFAULT' }
      }) : null)
      .filter((r): r is ReferenceImage => r !== null);
  }

  async function tryImagen(prompt: string, ratio: string, token: string, refs: ReferenceImage[] = []): Promise<string> {
    try {
      return await callImagen(prompt, ratio, token, refs, 'imagen-3.0-fast-generate-001');
    } catch (e: any) {
      const msg = String(e?.message ?? '');
      if (msg.includes('429') || msg.includes('RESOURCE_EXHAUSTED') || msg.includes('quota')) {
        // Fast model quota hit — fall back to full model
        return await callImagen(prompt, ratio, token, refs, 'imagen-3.0-generate-001');
      }
      throw e;
    }
  }

  try {
    backgroundB64 = await tryImagen(backgroundPrompt, aspectRatio, accessToken!, referenceImages);
  } catch (refErr: any) {
    // Subject reference not supported — fall back to text-only generation
    if (referenceImages.length > 0 && String(refErr?.message).includes('INVALID_ARGUMENT')) {
      backgroundB64 = await tryImagen(backgroundPrompt, aspectRatio, accessToken!, []);
    } else {
      throw refErr;
    }
  }
} catch (err: any) {
return json({ ok: false, stage: 'imagen', message: err?.message ?? String(err), imagePrompt: backgroundPrompt }, { status: 500 });
}

// ── Step 2: Fetch assets & composite (only when products exist) ───────
let finalBuffer: Buffer;

if (productCount === 0) {
  // Character was generated IN the image by Imagen subject-reference — only composite logo
  const logoSignedUrl: string | null = brandInfo?.logo_url
    ? (await supabase.storage.from('ai-marketing-files').createSignedUrl(brandInfo.logo_url, 300)).data?.signedUrl ?? null
    : null;
  const logoBuffer = logoSignedUrl ? await fetchImageBuffer(logoSignedUrl) : null;
  const bgBuf = Buffer.from(backgroundB64, 'base64');

  if (logoBuffer) {
    try {
      const bgMeta = await sharp(bgBuf).metadata();
      const W = bgMeta.width  ?? 1080;
      const logoSize  = Math.round(W * 0.13);
      const logoPad   = Math.round(W * 0.025);
      const bgPadding = Math.round(logoSize * 0.18);
      const bgSize    = logoSize + bgPadding * 2;
      const logoLeft  = language === 'ar' ? W - logoSize - logoPad : logoPad;
      const logoTop   = logoPad;
      const logoBgSvg = `<svg width="${bgSize}" height="${bgSize}" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="0" width="${bgSize}" height="${bgSize}" rx="${Math.round(bgSize * 0.16)}" fill="#ffffff"/></svg>`;
      const logoBgPng   = await sharp(Buffer.from(logoBgSvg)).png().toBuffer();
      const logoResized = await sharp(logoBuffer).resize(logoSize, logoSize, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 0 } }).png().toBuffer();
      finalBuffer = await sharp(bgBuf)
        .composite([
          { input: logoBgPng,   left: Math.max(0, logoLeft - bgPadding), top: Math.max(0, logoTop - bgPadding) },
          { input: logoResized, left: logoLeft, top: logoTop }
        ])
        .flatten({ background: { r: 255, g: 255, b: 255 } })
        .png().toBuffer();
    } catch {
      finalBuffer = await sharp(bgBuf).flatten({ background: { r: 255, g: 255, b: 255 } }).png().toBuffer();
    }
  } else {
    finalBuffer = await sharp(bgBuf).flatten({ background: { r: 255, g: 255, b: 255 } }).png().toBuffer();
  }
} else {
  // Products present — full compositing pipeline
  const logoSignedUrl: string | null = brandInfo?.logo_url
    ? (await supabase.storage.from('ai-marketing-files').createSignedUrl(brandInfo.logo_url, 300)).data?.signedUrl ?? null
    : null;

  const [logoBuffer, ...productBuffers] = await Promise.all([
    logoSignedUrl ? fetchImageBuffer(logoSignedUrl) : Promise.resolve(null),
    ...products.map((p: any) => p.image_url ? fetchImageBuffer(p.image_url) : Promise.resolve(null))
  ]);

  const productData = products.map((p: any, i: number) => ({
    imageBuffer:      (productBuffers[i] as Buffer | null),
    nameAr:           p.product_name_ar || p.product_name_en || '',
    nameEn:           p.product_name_en || p.product_name_ar || '',
    priceBeforeOffer: String(p.priceBeforeOffer ?? ''),
    priceAfterOffer:  String(p.priceAfterOffer  ?? '')
  }));

  try {
    finalBuffer = await compositePoster({
      backgroundB64,
      products: productData,
      logoBuffer: logoBuffer as Buffer | null,
      headline,
      brandName,
      accentColor,
      primaryColor,
      language
    });
  } catch (err: any) {
    return json({ ok: false, stage: 'composite', message: err?.message ?? String(err), imagePrompt: backgroundPrompt }, { status: 500 });
  }
}

// ── Step 4: Upload composited image ───────────────────────────────────
const timestamp   = Date.now();
const storagePath = `generated/posters/${timestamp}.png`;

const { error: uploadError } = await supabase.storage
.from('ai-marketing-files')
.upload(storagePath, finalBuffer, { contentType: 'image/png', upsert: false });

if (uploadError) {
return json({ ok: false, stage: 'upload', message: uploadError.message, imagePrompt: backgroundPrompt }, { status: 500 });
}

// ── Step 5: DB record ─────────────────────────────────────────────────
const title = headline ||
(products.length > 0
? products.map((p: any) => language === 'ar' ? (p.product_name_ar || p.product_name_en) : (p.product_name_en || p.product_name_ar)).filter(Boolean).join(', ')
: brandName + ' Poster');

const { data: fileRecord, error: dbError } = await supabase
.from('ai_marketing_files')
.insert({
brand_id:          brandId || null,
title,
file_type:         'poster',
storage_path:      storagePath,
thumbnail_url:     storagePath,
platform,
aspect_ratio:      aspectRatio,
language,
generation_prompt: backgroundPrompt,
generation_params: { brandId, productIds, platform, aspectRatio, language, extraPrompt, headline },
created_by:        userId || null
})
.select('id')
.single();

if (dbError) console.error('[generate-poster] DB insert error:', dbError);

if (fileRecord?.id && products.length > 0) {
await supabase.from('ai_marketing_file_products').insert(
products.map((p: any, i: number) => ({ file_id: fileRecord.id, product_id: p.id, sort_order: i }))
);
}

// ── Step 6: Signed URL ────────────────────────────────────────────────
const { data: signed } = await supabase.storage
.from('ai-marketing-files')
.createSignedUrl(storagePath, 3600);

return json({
ok:          true,
fileId:      fileRecord?.id ?? null,
signedUrl:   signed?.signedUrl ?? null,
imagePrompt: backgroundPrompt,
storagePath
});
};
