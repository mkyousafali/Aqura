import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';

const PIXABAY_API_KEY = env.PIXABAY_API_KEY || '';
const GOOGLE_API_KEY = env.GOOGLE_API_KEY || '';
const GOOGLE_SEARCH_ENGINE_ID = env.GOOGLE_SEARCH_ENGINE_ID || '';

// Fetch API key from DB (system_api_keys table), fallback to .env value
async function getApiKey(serviceName: string, fallback: string): Promise<string> {
	try {
		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
		if (!supabaseUrl || !supabaseKey) return fallback;
		const res = await fetch(
			`${supabaseUrl}/rest/v1/system_api_keys?service_name=eq.${serviceName}&is_active=eq.true&select=api_key&limit=1`,
			{ headers: { 'apikey': supabaseKey, 'Authorization': `Bearer ${supabaseKey}` } }
		);
		const rows = await res.json();
		if (rows?.[0]?.api_key) return rows[0].api_key;
	} catch { /* ignore, use fallback */ }
	return fallback;
}

// ── Pixabay image search (free, 100 req/min) ──
async function fetchPixabayImages(searchQuery: string, limit: number, pixabayKey: string) {
	const perPage = Math.min(limit, 20);
	const url = `https://pixabay.com/api/?key=${pixabayKey}&q=${encodeURIComponent(searchQuery)}&image_type=photo&per_page=${perPage}&safesearch=true`;

	console.log(`[Pixabay] Searching: "${searchQuery}" (limit: ${perPage})`);
	const response = await fetch(url);
	const data = await response.json();

	if (!response.ok || data.error) {
		console.error(`[Pixabay] Error for "${searchQuery}":`, data);
		return [];
	}

	return (data.hits || []).map((item: any) => ({
		url: item.webformatURL || item.largeImageURL,
		thumbnail: item.previewURL || item.webformatURL,
		title: item.tags || '',
		source: 'pixabay.com'
	}));
}

// ── Google Custom Search (fallback, 100 req/day free) ──
async function fetchGoogleImages(searchQuery: string, limit: number, apiKey: string, searchEngineId: string) {
	const num = Math.min(limit, 10);
	const url = `https://www.googleapis.com/customsearch/v1?key=${apiKey}&cx=${searchEngineId}&q=${encodeURIComponent(searchQuery)}&searchType=image&num=${num}&safe=active`;

	console.log(`[Google CSE] Searching: "${searchQuery}" (limit: ${num})`);
	const response = await fetch(url);
	const data = await response.json();

	if (!response.ok) {
		console.error(`[Google CSE] Error for "${searchQuery}":`, data);
		throw new Error(data.error?.message || 'Google Custom Search API request failed');
	}

	return (data.items || []).map((item: any) => ({
		url: item.link,
		thumbnail: item.image?.thumbnailLink || item.link,
		title: item.title || '',
		source: item.displayLink || 'google.com'
	}));
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { barcode, productNameEn, productNameAr, query } = body;

		// Resolve keys from DB, fallback to .env
		const pixabayKey = await getApiKey('pixabay', PIXABAY_API_KEY);
		const googleKey = await getApiKey('google', GOOGLE_API_KEY);
		const searchEngineId = await getApiKey('google_search_engine_id', GOOGLE_SEARCH_ENGINE_ID);

		// Determine which search engine to use: Pixabay primary, Google CSE fallback
		const usePixabay = !!pixabayKey;
		const useGoogle = !!googleKey && !!searchEngineId;

		if (!usePixabay && !useGoogle) {
			return json({ error: 'No image search API configured. Set pixabay or google keys in API Keys Manager.' }, { status: 500 });
		}

		// Auto-translate Arabic text to English for Pixabay (which doesn't support Arabic well)
		async function translateToEnglish(text: string): Promise<string> {
			// Check if text contains Arabic characters
			if (!/[\u0600-\u06FF]/.test(text)) return text;
			try {
				const res = await fetch(
					`https://translate.googleapis.com/translate_a/single?client=gtx&sl=ar&tl=en&dt=t&q=${encodeURIComponent(text)}`
				);
				const data = await res.json();
				const translated = (data[0] as any[])?.map((s: any) => s[0]).join('') || text;
				console.log(`[Translate] "${text}" → "${translated}"`);
				return translated;
			} catch {
				return text;
			}
		}

		// Unified fetch: try Pixabay first (translate Arabic→English), fall back to Google CSE
		async function fetchImages(searchQuery: string, limit: number) {
			if (usePixabay) {
				const englishQuery = await translateToEnglish(searchQuery);
				const results = await fetchPixabayImages(englishQuery, limit, pixabayKey);
				if (results.length > 0) return results;
			}
			if (useGoogle) {
				return await fetchGoogleImages(searchQuery, limit, googleKey, searchEngineId);
			}
			return [];
		}

		// Simple query mode (used by mobile customer product request)
		if (query) {
			try {
				const images = await fetchImages(query, 10);
				return json({ images });
			} catch (error: any) {
				return json({ error: error.message || 'Search failed' }, { status: 500 });
			}
		}

		if (!barcode) {
			return json({ error: 'Barcode is required' }, { status: 400 });
		}

		const allImages: any[] = [];
		const seenUrls = new Set<string>();

		// 1. Search with barcode (6 best matches)
		try {
			const barcodeImages = await fetchImages(`${barcode} product`, 6);
			barcodeImages.forEach((img: any) => {
				if (!seenUrls.has(img.url)) {
					seenUrls.add(img.url);
					allImages.push({ ...img, searchType: 'barcode' });
				}
			});
		} catch (error) {
			console.error('Error searching by barcode:', error);
		}

		// 2. Search with English product name (3 best matches)
		if (productNameEn && productNameEn.trim()) {
			try {
				const enImages = await fetchImages(`${productNameEn} product`, 3);
				enImages.forEach((img: any) => {
					if (!seenUrls.has(img.url)) {
						seenUrls.add(img.url);
						allImages.push({ ...img, searchType: 'english_name' });
					}
				});
			} catch (error) {
				console.error('Error searching by English name:', error);
			}
		}

		// 3. Search with Arabic product name (3 best matches)
		if (productNameAr && productNameAr.trim()) {
			try {
				const arImages = await fetchImages(`${productNameAr} منتج`, 3);
				arImages.forEach((img: any) => {
					if (!seenUrls.has(img.url)) {
						seenUrls.add(img.url);
						allImages.push({ ...img, searchType: 'arabic_name' });
					}
				});
			} catch (error) {
				console.error('Error searching by Arabic name:', error);
			}
		}

		console.log(`Total unique images found: ${allImages.length}`);
		return json({ images: allImages });
	} catch (error) {
		console.error('Error in image search:', error);
		return json({ error: 'Failed to search images' }, { status: 500 });
	}
};
