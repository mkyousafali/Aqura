import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { PIXABAY_API_KEY } from '$env/static/private';

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

		// Resolve Pixabay key from DB, fallback to .env
		const pixabayKey = await getApiKey('pixabay', PIXABAY_API_KEY);

		if (!pixabayKey) {
			return json({ error: 'Pixabay API not configured' }, { status: 500 });
		}

		// Helper function to fetch images from Pixabay
		async function fetchImages(searchQuery: string, limit: number) {
			const url = `https://pixabay.com/api/?key=${pixabayKey}&q=${encodeURIComponent(searchQuery)}&image_type=photo&per_page=${limit}&safesearch=true`;

			console.log(`Fetching Pixabay for: "${searchQuery}" (limit: ${limit})`);
			const response = await fetch(url);
			const data = await response.json();

			if (!response.ok) {
				console.error(`Pixabay API Error for "${searchQuery}":`, data);
				throw new Error(data.message || 'Pixabay API request failed');
			}

			return (data.hits || []).map((item: any) => ({
				url: item.largeImageURL || item.webformatURL,
				thumbnail: item.previewURL || item.webformatURL,
				title: item.tags || '',
				source: 'pixabay.com'
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
