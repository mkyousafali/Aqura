import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, fetch }) => {
	try {
		const { barcode, productNameEn, productNameAr } = await request.json();
		
		if (!barcode) {
			return json({ error: 'Barcode is required', images: [] }, { status: 400 });
		}
		
		console.log('[DuckDuckGo] Starting search for:', { barcode, productNameEn, productNameAr });
		
		const allImages: any[] = [];
		const seenUrls = new Set<string>();
		
		// Helper function to search and get images
		async function searchAndGetImages(query: string, limit: number, searchType: string) {
			try {
				console.log(`[DuckDuckGo] Searching for: "${query}" (${searchType})`);
				const searchQuery = encodeURIComponent(query);
				const vqd = await getVqd(searchQuery, fetch);
				
				if (!vqd) {
					console.error(`[DuckDuckGo] Could not get VQD token for: ${query}`);
					return [];
				}
				
				console.log(`[DuckDuckGo] Got VQD token for "${query}": ${vqd.substring(0, 20)}...`);
				
				const imageUrl = `https://duckduckgo.com/i.js?q=${searchQuery}&vqd=${vqd}&f=,,,,,&p=1&v7=1`;
				
				const imageResponse = await fetch(imageUrl, {
					headers: {
						'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
						'Accept': 'application/json',
						'Accept-Language': 'en-US,en;q=0.9',
						'Referer': 'https://duckduckgo.com/',
					}
				});
				
				if (!imageResponse.ok) {
					console.error(`[DuckDuckGo] Image search failed for "${query}": ${imageResponse.status} ${imageResponse.statusText}`);
					const errorText = await imageResponse.text();
					console.error(`[DuckDuckGo] Error response:`, errorText.substring(0, 500));
					return [];
				}
				
				const data = await imageResponse.json();
				console.log(`[DuckDuckGo] Response data structure:`, Object.keys(data));
				
				if (!data.results || data.results.length === 0) {
					console.warn(`[DuckDuckGo] No results found for "${query}"`);
					return [];
				}
				
				const images = data.results.slice(0, limit).map((result: any) => ({
					url: result.image,
					thumbnail: result.thumbnail || result.image,
					title: result.title || query,
					source: result.url || 'DuckDuckGo',
					searchType: searchType
				}));
				
				console.log(`[DuckDuckGo] Found ${images.length} images for: ${query}`);
				return images;
			} catch (error) {
				console.error(`[DuckDuckGo] Error searching for "${query}":`, error);
				return [];
			}
		}
		
		// 1. Search with barcode (6 best matches)
		const barcodeImages = await searchAndGetImages(`${barcode} product`, 6, 'barcode');
		barcodeImages.forEach((img: any) => {
			if (!seenUrls.has(img.url)) {
				seenUrls.add(img.url);
				allImages.push(img);
			}
		});
		
		// 2. Search with English product name (3 best matches)
		if (productNameEn && productNameEn.trim()) {
			const enImages = await searchAndGetImages(`${productNameEn} product`, 3, 'english_name');
			enImages.forEach((img: any) => {
				if (!seenUrls.has(img.url)) {
					seenUrls.add(img.url);
					allImages.push(img);
				}
			});
		}
		
		// 3. Search with Arabic product name (3 best matches)
		if (productNameAr && productNameAr.trim()) {
			const arImages = await searchAndGetImages(`${productNameAr} منتج`, 3, 'arabic_name');
			arImages.forEach((img: any) => {
				if (!seenUrls.has(img.url)) {
					seenUrls.add(img.url);
					allImages.push(img);
				}
			});
		}
		
		console.log(`Total unique images found: ${allImages.length}`);
		return json({ images: allImages, barcode });
			
	} catch (error) {
		console.error('Error finding image:', error);
		return json({ error: 'Failed to search for images', images: [] }, { status: 500 });
	}
};

// Helper function to get VQD token (required for DuckDuckGo API)
async function getVqd(query: string, fetch: typeof globalThis.fetch): Promise<string | null> {
	try {
		console.log(`[DuckDuckGo] Getting VQD token for query: ${query}`);
		const response = await fetch(`https://duckduckgo.com/?q=${query}`, {
			headers: {
				'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
				'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
				'Accept-Language': 'en-US,en;q=0.9',
			}
		});
		
		if (!response.ok) {
			console.error(`[DuckDuckGo] VQD fetch failed: ${response.status} ${response.statusText}`);
			return null;
		}
		
		const html = await response.text();
		console.log(`[DuckDuckGo] Received HTML length: ${html.length}`);
		
		// Try multiple patterns to extract VQD token
		let vqdMatch = html.match(/vqd=['"]([^'"]+)['"]/);
		
		if (!vqdMatch) {
			// Try alternative pattern
			vqdMatch = html.match(/vqd[=:](\d+-\d+-\d+)/);
		}
		
		if (!vqdMatch) {
			// Try another pattern from script tags
			vqdMatch = html.match(/["']vqd["']:\s*["']([^"']+)["']/);
		}
		
		if (vqdMatch && vqdMatch[1]) {
			console.log(`[DuckDuckGo] Found VQD token: ${vqdMatch[1].substring(0, 20)}...`);
			return vqdMatch[1];
		}
		
		console.error(`[DuckDuckGo] Could not extract VQD token from HTML`);
		console.log(`[DuckDuckGo] HTML sample:`, html.substring(0, 1000));
		return null;
	} catch (error) {
		console.error('[DuckDuckGo] Error getting VQD:', error);
		return null;
	}
}
