import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { GOOGLE_API_KEY, GOOGLE_SEARCH_ENGINE_ID } from '$env/static/private';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { barcode, productNameEn, productNameAr } = await request.json();

		if (!barcode) {
			return json({ error: 'Barcode is required' }, { status: 400 });
		}

		if (!GOOGLE_API_KEY || !GOOGLE_SEARCH_ENGINE_ID) {
			return json({ error: 'Google API not configured' }, { status: 500 });
		}

		const allImages: any[] = [];
		const seenUrls = new Set<string>();

		// Helper function to fetch images for a query
		async function fetchImages(searchQuery: string, limit: number) {
			const url = `https://www.googleapis.com/customsearch/v1?key=${GOOGLE_API_KEY}&cx=${GOOGLE_SEARCH_ENGINE_ID}&q=${encodeURIComponent(searchQuery)}&searchType=image&num=${limit}`;
			
			console.log(`Fetching Google search for: "${searchQuery}" (limit: ${limit})`);
			const response = await fetch(url);
			const data = await response.json();

			if (!response.ok) {
				console.error(`Google API Error for "${searchQuery}":`, data);
				throw new Error(data.error?.message || 'Google API request failed');
			}

			const images = data.items?.map((item: any) => ({
				url: item.link,
				thumbnail: item.image?.thumbnailLink || item.link,
				title: item.title,
				source: item.displayLink
			})) || [];

			return images;
		}

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
