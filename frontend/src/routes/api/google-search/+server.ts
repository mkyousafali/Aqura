import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';

const GOOGLE_API_KEY = env.GOOGLE_API_KEY || '';
const GOOGLE_SEARCH_ENGINE_ID = env.GOOGLE_SEARCH_ENGINE_ID || '';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || '';
const SUPABASE_SERVICE_KEY = process.env.VITE_SUPABASE_SERVICE_KEY || '';

// Fetch API key from DB (system_api_keys table), fallback to .env value
async function getApiKey(serviceName: string, fallback: string): Promise<string> {
	try {
		const res = await fetch(
			`${SUPABASE_URL}/rest/v1/system_api_keys?service_name=eq.${serviceName}&is_active=eq.true&select=api_key&limit=1`,
			{ headers: { 'apikey': SUPABASE_SERVICE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}` } }
		);
		const rows = await res.json();
		if (rows?.[0]?.api_key) return rows[0].api_key;
	} catch { /* ignore, use fallback */ }
	return fallback;
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { barcode, productNameEn, productNameAr, query } = body;

		// Resolve Google API key and Search Engine ID from DB, fallback to .env
		const apiKey = await getApiKey('google', GOOGLE_API_KEY);
		const searchEngineId = await getApiKey('google_search_engine_id', GOOGLE_SEARCH_ENGINE_ID);

		if (!apiKey || !searchEngineId) {
			return json({ error: 'Google Custom Search API not configured. Set google and google_search_engine_id in API Keys Manager.' }, { status: 500 });
		}

		// Helper function to fetch images from Google Custom Search
		async function fetchImages(searchQuery: string, limit: number) {
			const num = Math.min(limit, 10); // Google CSE max is 10 per request
			const url = `https://www.googleapis.com/customsearch/v1?key=${apiKey}&cx=${searchEngineId}&q=${encodeURIComponent(searchQuery)}&searchType=image&num=${num}&safe=active`;

			console.log(`Fetching Google CSE for: "${searchQuery}" (limit: ${num})`);
			const response = await fetch(url);
			const data = await response.json();

			if (!response.ok) {
				console.error(`Google CSE API Error for "${searchQuery}":`, data);
				throw new Error(data.error?.message || 'Google Custom Search API request failed');
			}

			return (data.items || []).map((item: any) => ({
				url: item.link,
				thumbnail: item.image?.thumbnailLink || item.link,
				title: item.title || '',
				source: item.displayLink || 'google.com'
			}));
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
		console.error('Error in Google search:', error);
		return json({ error: 'Failed to search images' }, { status: 500 });
	}
};
