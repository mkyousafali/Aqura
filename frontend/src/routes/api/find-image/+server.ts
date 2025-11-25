import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, fetch }) => {
	try {
		const { barcode, productNameEn, productNameAr } = await request.json();
		
		if (!barcode) {
			return json({ error: 'Barcode is required', images: [] }, { status: 400 });
		}
		
		console.log('Searching DuckDuckGo for:', { barcode, productNameEn, productNameAr });
		
		const allImages: any[] = [];
		const seenUrls = new Set<string>();
		
		// Helper function to search and get images
		async function searchAndGetImages(query: string, limit: number, searchType: string) {
			try {
				const searchQuery = encodeURIComponent(query);
				const vqd = await getVqd(searchQuery, fetch);
				
				if (!vqd) {
					console.log(`Could not get VQD token for: ${query}`);
					return [];
				}
				
				const imageUrl = `https://duckduckgo.com/i.js?q=${searchQuery}&vqd=${vqd}&f=,,,,,&p=1&v7=1`;
				
				const imageResponse = await fetch(imageUrl, {
					headers: {
						'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
						'Accept': 'application/json',
					}
				});
				
				if (!imageResponse.ok) {
					console.error(`DuckDuckGo search failed for "${query}":`, imageResponse.status);
					return [];
				}
				
				const data = await imageResponse.json();
				const images = data.results
					? data.results.slice(0, limit).map((result: any) => ({
						url: result.image,
						thumbnail: result.thumbnail || result.image,
						title: result.title || query,
						source: result.url || 'DuckDuckGo',
						searchType: searchType
					}))
					: [];
				
				console.log(`Found ${images.length} images for: ${query}`);
				return images;
			} catch (error) {
				console.error(`Error searching for "${query}":`, error);
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
		const response = await fetch(`https://duckduckgo.com/?q=${query}`, {
			headers: {
				'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
			}
		});
		
		const html = await response.text();
		
		// Extract VQD token from HTML
		const vqdMatch = html.match(/vqd=['"]([^'"]+)['"]/);
		
		return vqdMatch ? vqdMatch[1] : null;
	} catch (error) {
		console.error('Error getting VQD:', error);
		return null;
	}
}
