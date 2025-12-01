<script lang="ts">
	import * as XLSX from 'xlsx';
	import { supabaseAdmin as supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { removeBackground } from '@imgly/background-removal';
	
	let products: any[] = [];
	let filteredProducts: any[] = [];
	let fileInput: HTMLInputElement;
	let imageInput: HTMLInputElement;
	let searchBarcode: string = '';
	let isUploadingImages: boolean = false;
	let uploadProgress: string = '';
	let imageUploadProgress: number = 0; // 0 to 100 for image uploads
	let uploadedImageCount: number = 0;
	let totalImageCount: number = 0;
	let cancelImageUpload: boolean = false;
	let showUploadSuccessPopup: boolean = false;
	let uploadSuccessMessage: string = '';
	let isSavingProducts: boolean = false;
	let hasUnsavedData: boolean = false;
	let saveProgress: number = 0; // 0 to 100
	let totalProducts: number = 0;
	let productsWithImages: number = 0;
	let productsWithoutImages: number = 0;
	let isCalculatingStats: boolean = false;
	let storageImageCache: Set<string> = new Set(); // Cache of barcodes that have images
	let isCacheLoaded: boolean = false;
	
	// Database stats
	let dbTotalProducts: number = 0;
	let dbProductsWithImages: number = 0;
	let dbProductsWithoutImages: number = 0;
	let isLoadingDbStats: boolean = false;
	
	// Products without images view
	let showNoImageProducts: boolean = false;
	let noImageProducts: any[] = [];
	let isLoadingNoImageProducts: boolean = false;
	let uploadingImageForBarcode: string | null = null;
	let noImageSearchQuery: string = '';
	let filteredNoImageProducts: any[] = [];
	
	// All products view
	let showAllProducts: boolean = false;
	let allProductsList: any[] = [];
	let allProductsForDropdowns: any[] = [];
	let isLoadingAllProducts: boolean = false;
	let allProductsSearch: string = '';
	let filteredAllProducts: any[] = [];
	
	// Image loading state
	let loadingImages: Set<string> = new Set(); // Track which images are currently loading
	
	// Web image search
	let showImageSearchPopup: boolean = false;
	let searchingBarcode: string = '';
	let webImages: any[] = [];
	let isSearchingWeb: boolean = false;
	let selectedWebImage: string | null = null;
	let downloadingImage: boolean = false;
	let removingBackground: boolean = false;
	let searchProvider: 'google' | 'duckduckgo' | null = null;
	
	// Image preview popup
	let showImagePreview: boolean = false;
	let previewImageUrl: string = '';
	let previewImageBlob: Blob | null = null;
	let previewBarcode: string = '';
	
	// Edit product popup
	let showEditPopup: boolean = false;
	let editingProduct: any = null;
	let isSavingEdit: boolean = false;
	
	// Create product popup
	let showCreatePopup: boolean = false;
	let newProduct: any = null;
	let isSavingCreate: boolean = false;
	let isCheckingImage: boolean = false;
	let imageCheckStatus: string = '';
	let imageCheckResult: 'success' | 'error' | null = null;
	let foundImageUrl: string = '';
	
	// Filter no-image products based on search query
	$: filteredNoImageProducts = noImageProducts.filter(product => {
		if (!noImageSearchQuery.trim()) return true;
		const query = noImageSearchQuery.toLowerCase();
		return (
			product.barcode?.toLowerCase().includes(query) ||
			product.product_name_en?.toLowerCase().includes(query) ||
			product.product_name_ar?.includes(query)
		);
	});
	
	// Extract unique values for dropdowns
	$: uniqueUnits = [...new Set(allProductsForDropdowns.map(p => p.unit_name).filter(Boolean))].sort();
	$: uniqueParentCategories = [...new Set(allProductsForDropdowns.map(p => p.parent_category).filter(Boolean))].sort();
	$: uniqueParentSubCategories = [...new Set(allProductsForDropdowns.map(p => p.parent_sub_category).filter(Boolean))].sort();
	$: uniqueSubCategories = [...new Set(allProductsForDropdowns.map(p => p.sub_category).filter(Boolean))].sort();
	
	// Quota tracking
	interface QuotaData {
		googleSearches: number;
		googleResetDate: string;
		removeBgUses: number;
		removeBgResetDate: string;
	}
	
	let quotaData: QuotaData = {
		googleSearches: 0,
		googleResetDate: new Date().toISOString().split('T')[0],
		removeBgUses: 0,
		removeBgResetDate: getMonthKey()
	};
	
	const GOOGLE_DAILY_LIMIT = 100;
	const REMOVE_BG_MONTHLY_LIMIT = 50;
	
	// Get current month key (YYYY-MM)
	function getMonthKey(): string {
		const now = new Date();
		return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
	}
	
	// Load quota data from localStorage
	function loadQuotaData() {
		if (typeof window === 'undefined') return;
		
		try {
			const saved = localStorage.getItem('apiQuotaData');
			if (saved) {
				const data = JSON.parse(saved);
				const today = new Date().toISOString().split('T')[0];
				const currentMonth = getMonthKey();
				
				// Reset Google quota if it's a new day
				if (data.googleResetDate !== today) {
					data.googleSearches = 0;
					data.googleResetDate = today;
				}
				
				// Reset Remove.bg quota if it's a new month
				if (data.removeBgResetDate !== currentMonth) {
					data.removeBgUses = 0;
					data.removeBgResetDate = currentMonth;
				}
				
				quotaData = data;
			}
		} catch (error) {
			console.error('Error loading quota data:', error);
		}
	}
	
	// Save quota data to localStorage
	function saveQuotaData() {
		if (typeof window === 'undefined') return;
		
		try {
			localStorage.setItem('apiQuotaData', JSON.stringify(quotaData));
		} catch (error) {
			console.error('Error saving quota data:', error);
		}
	}
	
	// Check if Google search is available
	function isGoogleAvailable(): boolean {
		return quotaData.googleSearches < GOOGLE_DAILY_LIMIT;
	}
	
	// Check if Remove.bg is available
	function isRemoveBgAvailable(): boolean {
		return quotaData.removeBgUses < REMOVE_BG_MONTHLY_LIMIT;
	}
	
	// Increment Google search count
	function incrementGoogleSearch() {
		quotaData.googleSearches++;
		saveQuotaData();
	}
	
	// Increment Remove.bg use count
	function incrementRemoveBg() {
		quotaData.removeBgUses++;
		saveQuotaData();
	}
	
	// Load all images from Supabase Storage once
	async function loadStorageImageCache() {
		if (isCacheLoaded) return;
		
		uploadProgress = 'Loading image list from storage...';
		storageImageCache.clear();
		
		try {
			let allFiles: any[] = [];
			let page = 1;
			let hasMore = true;
			const limit = 1000;
			
			// Use a different approach - keep loading until we get no more files
			while (hasMore && page <= 10) { // Max 10 pages = 10,000 files
				console.log(`Loading page ${page} (limit: ${limit})`);
				
				const { data: files, error } = await supabase.storage
					.from('flyer-product-images')
					.list('', {
						limit: limit,
						offset: (page - 1) * limit
					});
				
				if (error) {
					console.error('Error loading storage files:', error);
					break;
				}
				
				if (!files || files.length === 0) {
					console.log('No more files to load');
					hasMore = false;
					break;
				}
				
				console.log(`Page ${page}: Loaded ${files.length} files`);
				allFiles.push(...files);
				
				// If we got less than limit, we've reached the end
				if (files.length < limit) {
					console.log('Reached end of files');
					hasMore = false;
				}
				
				page++;
				uploadProgress = `Loaded ${allFiles.length} files from storage...`;
			}
			
			console.log(`Total files loaded: ${allFiles.length}`);
			
			// Now process all files and add to cache
			allFiles.forEach(file => {
				// Check if it's a file (not a folder or placeholder)
				if (file.name && !file.name.endsWith('/') && !file.name.includes('.emptyFolder')) {
					const barcode = file.name.replace(/\.(png|jpg|jpeg|webp)$/i, '');
					storageImageCache.add(barcode);
				}
			});
			
			isCacheLoaded = true;
			console.log(`Total images cached: ${storageImageCache.size}`);
			console.log('Sample barcodes:', Array.from(storageImageCache).slice(0, 10));
			uploadProgress = `Cache loaded: ${storageImageCache.size} images`;
			setTimeout(() => { uploadProgress = ''; }, 3000);
			
			// Trigger table refresh by reassigning filteredProducts
			filteredProducts = [...filteredProducts];
		} catch (error) {
			console.error('Error loading storage cache:', error);
			uploadProgress = '';
		}
	}
	
	// Calculate image statistics properly by checking if images exist
	async function updateImageStats() {
		totalProducts = filteredProducts.length;
		
		if (totalProducts === 0) {
			productsWithImages = 0;
			productsWithoutImages = 0;
			return;
		}
		
		// Make sure cache is loaded
		if (!isCacheLoaded) {
			await loadStorageImageCache();
		}
		
		isCalculatingStats = true;
		let withImages = 0;
		let withoutImages = 0;
		
		// Check against cache - super fast!
		filteredProducts.forEach(product => {
			const barcode = String(product.Barcode || product.barcode || '');
			if (!barcode) {
				withoutImages++;
				return;
			}
			
			if (storageImageCache.has(barcode)) {
				withImages++;
			} else {
				withoutImages++;
			}
		});
		
		productsWithImages = withImages;
		productsWithoutImages = withoutImages;
		
		isCalculatingStats = false;
	}
	
	// Update stats when products change
	$: if (filteredProducts.length > 0 && isCacheLoaded) {
		updateImageStats();
	}
	
	// Load products from database on mount
	async function loadProducts() {
		const { data, error } = await supabase
			.from('flyer_products')
			.select('*')
			.order('created_at', { ascending: false });
		
		if (error) {
			console.error('Error loading products:', error);
		} else if (data) {
			products = data.map(p => ({
				Barcode: p.barcode,
				'Product name_en': p.product_name_en,
				'Product name_ar': p.product_name_ar,
				'Unit name': p.unit_name,
				image_url: p.image_url
			}));
			filteredProducts = [...products];
		}
		
		// Load storage image cache after products
		await loadStorageImageCache();
	}
	
	// Load database statistics
	async function loadDatabaseStats() {
		isLoadingDbStats = true;
		
		try {
			// Get total products count
			const { count: totalCount, error: countError } = await supabase
				.from('flyer_products')
				.select('*', { count: 'exact', head: true });
			
			if (countError) {
				console.error('Error loading product count:', countError);
			} else {
				dbTotalProducts = totalCount || 0;
			}
			
			// Get products with images count
			const { count: withImageCount, error: withImageError } = await supabase
				.from('flyer_products')
				.select('*', { count: 'exact', head: true })
				.not('image_url', 'is', null)
				.neq('image_url', '');
			
			if (withImageError) {
				console.error('Error loading with-image count:', withImageError);
			} else {
				dbProductsWithImages = withImageCount || 0;
			}
			
			// Get products without images count
			const { count: noImageCount, error: noImageError } = await supabase
				.from('flyer_products')
				.select('*', { count: 'exact', head: true })
				.or('image_url.is.null,image_url.eq.');
			
			if (noImageError) {
				console.error('Error loading no-image count:', noImageError);
			} else {
				dbProductsWithoutImages = noImageCount || 0;
			}
		} catch (error) {
			console.error('Error loading database stats:', error);
		}
		
		isLoadingDbStats = false;
	}
	
	// Don't load products on mount - start with empty state
	// But load database statistics
	loadDatabaseStats();
	
	function downloadTemplate() {
		// Create template data with sample row
		const templateData = [
			{
				'Barcode': '123456789',
				'Product name english': 'Sample Product',
				'Product name arabic': 'منتج عينة',
				'unit': 'piece',
				'Parent Category': 'Food',
				'Parent Sub Category': 'Dairy',
				'Sub Category': 'Milk'
			}
		];
		
		// Create workbook and worksheet
		const ws = XLSX.utils.json_to_sheet(templateData);
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Products');
		
		// Set column widths
		ws['!cols'] = [
			{ wch: 15 }, // Barcode
			{ wch: 25 }, // Product name english
			{ wch: 25 }, // Product name arabic
			{ wch: 10 }, // unit
			{ wch: 20 }, // Parent Category
			{ wch: 20 }, // Parent Sub Category
			{ wch: 20 }  // Sub Category
		];
		
		// Download file
		XLSX.writeFile(wb, 'Product_Import_Template.xlsx');
	}
	
	function handleImport() {
		fileInput.click();
	}
	
	function handleUploadImages() {
		imageInput.click();
	}
	
	function handleCancelUpload() {
		cancelImageUpload = true;
		uploadProgress = 'Upload cancelled by user';
	}
	
	// Load products without images from database
	async function loadNoImageProducts() {
		isLoadingNoImageProducts = true;
		showNoImageProducts = true;
		
		try {
			const { data, error } = await supabase
				.from('flyer_products')
				.select('*')
				.or('image_url.is.null,image_url.eq.')
				.order('created_at', { ascending: false });
			
			if (error) {
				console.error('Error loading products without images:', error);
				noImageProducts = [];
			} else {
				noImageProducts = data || [];
			}
		} catch (error) {
			console.error('Error:', error);
			noImageProducts = [];
		}
		
		isLoadingNoImageProducts = false;
	}
	
	// Upload single image for a product
	async function uploadSingleImage(event: Event, barcode: string) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		
		if (!file) return;
		
		uploadingImageForBarcode = barcode;
		
		try {
			// Upload to Supabase Storage with barcode as filename
			const { data, error } = await supabase.storage
				.from('flyer-product-images')
				.upload(`${barcode}.png`, file, {
					cacheControl: '3600',
					upsert: true
				});
			
			if (error) {
				console.error(`Failed to upload image for ${barcode}:`, error);
				alert(`Failed to upload image: ${error.message}`);
			} else {
				// Get the public URL
				const { data: urlData } = supabase.storage
					.from('flyer-product-images')
					.getPublicUrl(`${barcode}.png`);
				
				// Update the product in database with image URL
				const { error: updateError } = await supabase
					.from('flyer_products')
					.update({ 
						image_url: urlData.publicUrl,
						updated_at: new Date().toISOString()
					})
					.eq('barcode', barcode);
				
				if (updateError) {
					console.error('Error updating product:', updateError);
				} else {
					// Add to cache
					storageImageCache.add(barcode);
					
					// Reload the products without images
					await loadNoImageProducts();
					await loadDatabaseStats();
					
					alert('Image uploaded successfully!');
				}
			}
		} catch (error) {
			console.error('Error uploading image:', error);
			alert('Error uploading image');
		}
		
		uploadingImageForBarcode = null;
		input.value = '';
	}
	
	function closeNoImageView() {
		showNoImageProducts = false;
		noImageProducts = [];
	}
	
	// Load all products from database
	async function loadAllProducts() {
		showAllProducts = true;
		isLoadingAllProducts = true;
		allProductsList = [];
		
		try {
			const { data, error } = await supabase
				.from('flyer_products')
				.select('*')
				.order('product_name_en', { ascending: true });
			
			if (error) {
				console.error('Error loading all products:', error);
				alert('Error loading products. Please try again.');
			} else {
				// For each product, if image_url is null, try to get it from storage
				const productsWithImages = await Promise.all((data || []).map(async (product) => {
					if (!product.image_url && product.barcode) {
						// Try to get public URL from storage
						const { data: urlData } = supabase.storage
							.from('flyer-product-images')
							.getPublicUrl(`${product.barcode}.png`);
						
						// Return product with potential image URL
						return { ...product, image_url: urlData.publicUrl };
					}
					return product;
				}));
				
				allProductsList = productsWithImages;
				filteredAllProducts = allProductsList;
			}
		} catch (error) {
			console.error('Error loading all products:', error);
			alert('Error loading products. Please try again.');
		}
		
		isLoadingAllProducts = false;
	}
	
	function closeAllProductsView() {
		showAllProducts = false;
		allProductsList = [];
		filteredAllProducts = [];
		allProductsSearch = '';
	}
	
	// Load all products for dropdown data (without showing the view)
	async function loadAllProductsForDropdowns() {
		try {
			const { data, error } = await supabase
				.from('flyer_products')
				.select('unit_name, parent_category, parent_sub_category, sub_category');
			
			if (!error && data) {
				allProductsForDropdowns = data;
				console.log('Loaded dropdown data:', {
					total: data.length,
					units: [...new Set(data.map(p => p.unit_name).filter(Boolean))],
					parentCategories: [...new Set(data.map(p => p.parent_category).filter(Boolean))],
					parentSubCategories: [...new Set(data.map(p => p.parent_sub_category).filter(Boolean))],
					subCategories: [...new Set(data.map(p => p.sub_category).filter(Boolean))]
				});
			}
		} catch (error) {
			console.error('Error loading products for dropdowns:', error);
		}
	}
	
	// Filter all products based on search
	$: {
		if (allProductsSearch.trim() === '') {
			filteredAllProducts = allProductsList;
		} else {
			const search = allProductsSearch.toLowerCase();
			filteredAllProducts = allProductsList.filter(product => 
				product.barcode?.toLowerCase().includes(search) ||
				product.product_name_en?.toLowerCase().includes(search) ||
				product.product_name_ar?.includes(search) ||
				product.unit_name?.toLowerCase().includes(search) ||
				product.parent_category?.toLowerCase().includes(search) ||
				product.parent_sub_category?.toLowerCase().includes(search) ||
				product.sub_category?.toLowerCase().includes(search)
			);
		}
	}
	
	// Search for product images on the web
	async function searchWebForImages(barcode: string, provider: 'google' | 'duckduckgo') {
		searchingBarcode = barcode;
		searchProvider = provider;
		showImageSearchPopup = true;
		isSearchingWeb = true;
		webImages = [];
		
		try {
			// Check quota for Google
			if (provider === 'google' && !isGoogleAvailable()) {
				alert(`Google search quota exceeded (${GOOGLE_DAILY_LIMIT}/day). Resets tomorrow.`);
				isSearchingWeb = false;
				return;
			}
			
			// Find the product details
			const product = noImageProducts.find(p => p.barcode === barcode) || 
			                products.find(p => (p.Barcode || p.barcode) === barcode);
			
			const productNameEn = product?.product_name_en || product?.['Product name_en'] || '';
			const productNameAr = product?.product_name_ar || product?.['Product name_ar'] || '';
			
			// Choose API endpoint based on provider
			const endpoint = provider === 'google' ? '/api/google-search' : '/api/find-image';
			
			// Call the image search API endpoint with all search terms
			const response = await fetch(endpoint, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ 
					barcode,
					productNameEn,
					productNameAr
				})
			});
			
			if (!response.ok) {
				const errorData = await response.json();
				console.error(`${provider} search error:`, errorData);
				
				if (errorData.quota_exceeded) {
					alert(`${provider === 'google' ? 'Google' : 'DuckDuckGo'} search quota exceeded. Please try again later.`);
				} else {
					const errorMsg = errorData.error || 'Failed to search for images';
					const details = errorData.details ? `\n\nDetails: ${JSON.stringify(errorData.details, null, 2)}` : '';
					alert(`${provider === 'google' ? 'Google' : 'DuckDuckGo'} Search Error:\n${errorMsg}${details}`);
				}
				isSearchingWeb = false;
				return;
			}
			
			const data = await response.json();
			webImages = data.images || [];
			
			// Increment Google quota if successful
			if (provider === 'google' && webImages.length > 0) {
				incrementGoogleSearch();
			}
		} catch (error) {
			console.error('Error searching for images:', error);
			alert('Error searching for images. Please try again.');
		}
		
		isSearchingWeb = false;
	}
	
	// Download and upload image from URL
	async function downloadAndUploadImage(imageUrl: string, removeBackgroundType: 'none' | 'api' | 'client' = 'none') {
		if (!searchingBarcode) return;
		
		// Check Remove.bg quota if using API
		if (removeBackgroundType === 'api' && !isRemoveBgAvailable()) {
			alert(`Background removal quota exceeded (${REMOVE_BG_MONTHLY_LIMIT}/month). Resets next month.`);
			return;
		}
		
		downloadingImage = true;
		selectedWebImage = imageUrl;
		if (removeBackgroundType !== 'none') {
			removingBackground = true;
		}
		
		try {
			let blob: Blob;
			
			// Remove background using API (Remove.bg)
			if (removeBackgroundType === 'api') {
				const bgRemoveResponse = await fetch('/api/remove-background', {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json'
					},
					body: JSON.stringify({ 
						imageUrl: imageUrl 
					})
				});
				
				if (!bgRemoveResponse.ok) {
					const errorData = await bgRemoveResponse.json();
					throw new Error(errorData.error || 'Failed to remove background');
				}
				
				const result = await bgRemoveResponse.json();
				
				// Convert base64 data URL to blob
				const base64Response = await fetch(result.imageData);
				blob = await base64Response.blob();
				
				// Increment Remove.bg quota
				incrementRemoveBg();
			} 
			// Remove background using client-side AI (Free, unlimited)
			else if (removeBackgroundType === 'client') {
				// Fetch the image through our proxy
				const proxyUrl = `/api/proxy-image?url=${encodeURIComponent(imageUrl)}`;
				const response = await fetch(proxyUrl);
				
				if (!response.ok) {
					const errorText = await response.text();
					throw new Error(`Failed to fetch image: ${errorText}`);
				}
				
				const imageBlob = await response.blob();
				
				// Verify the blob is valid
				if (imageBlob.size === 0) {
					throw new Error('Downloaded image is empty');
				}
				
				// Use client-side AI to remove background (this runs in the browser)
				console.log('Removing background using client-side AI...');
				blob = await removeBackground(imageBlob);
				console.log('Background removed successfully!');
				
				// Show preview popup instead of uploading directly
				previewImageBlob = blob;
				previewImageUrl = URL.createObjectURL(blob);
				previewBarcode = searchingBarcode;
				showImagePreview = true;
				downloadingImage = false;
				removingBackground = false;
				return; // Don't upload yet, wait for user confirmation
			} 
			// No background removal
			else {
				// Fetch the image through our proxy to avoid CORS issues
				const proxyUrl = `/api/proxy-image?url=${encodeURIComponent(imageUrl)}`;
				const response = await fetch(proxyUrl);
				
				if (!response.ok) {
					const errorText = await response.text();
					throw new Error(`Failed to fetch image: ${errorText}`);
				}
				
				blob = await response.blob();
			}
			
			// Convert to File object
			const file = new File([blob], `${searchingBarcode}.png`, { type: 'image/png' });
			
			// Upload to Supabase Storage
			const { data, error } = await supabase.storage
				.from('flyer-product-images')
				.upload(`${searchingBarcode}.png`, file, {
					cacheControl: '3600',
					upsert: true
				});
			
			if (error) {
				console.error(`Failed to upload image for ${searchingBarcode}:`, error);
				alert(`Failed to upload image: ${error.message}`);
			} else {
				// Get the public URL
				const { data: urlData } = supabase.storage
					.from('flyer-product-images')
					.getPublicUrl(`${searchingBarcode}.png`);
				
				// Update the product in database with image URL
				const { error: updateError } = await supabase
					.from('flyer_products')
					.update({ 
						image_url: urlData.publicUrl,
						updated_at: new Date().toISOString()
					})
					.eq('barcode', searchingBarcode);
				
				if (updateError) {
					console.error('Error updating product:', updateError);
					alert('Error updating product');
				} else {
					// Add to cache
					storageImageCache.add(searchingBarcode);
					
					// Reload the products without images
					await loadNoImageProducts();
					await loadDatabaseStats();
					
					alert('Image uploaded successfully!');
					closeImageSearchPopup();
				}
			}
		} catch (error) {
			console.error('Error downloading/uploading image:', error);
			const errorMessage = error instanceof Error ? error.message : 'Error processing image';
			alert(errorMessage);
		} finally {
			downloadingImage = false;
			removingBackground = false;
			selectedWebImage = null;
		}
		selectedWebImage = null;
		removingBackground = false;
	}
	
	function closeImageSearchPopup() {
		showImageSearchPopup = false;
		searchingBarcode = '';
		webImages = [];
		selectedWebImage = null;
	}
	
	// Upload image from preview
	async function uploadPreviewImage() {
		if (!previewImageBlob || !previewBarcode) return;
		
		downloadingImage = true;
		
		try {
			// Convert to File object
			const file = new File([previewImageBlob], `${previewBarcode}.png`, { type: 'image/png' });
			
			// Upload to Supabase Storage
			const { data, error } = await supabase.storage
				.from('flyer-product-images')
				.upload(`${previewBarcode}.png`, file, {
					cacheControl: '3600',
					upsert: true
				});
			
			if (error) {
				console.error(`Failed to upload image for ${previewBarcode}:`, error);
				alert(`Failed to upload image: ${error.message}`);
			} else {
				// Get the public URL
				const { data: urlData } = supabase.storage
					.from('flyer-product-images')
					.getPublicUrl(`${previewBarcode}.png`);
				
				// Update the product in database with image URL
				const { error: updateError } = await supabase
					.from('flyer_products')
					.update({ image_url: urlData.publicUrl })
					.eq('barcode', previewBarcode);
				
				if (updateError) {
					console.error('Error updating product:', updateError);
				}
				
				// Update cache and stats
				storageImageCache.add(previewBarcode);
				await loadDatabaseStats();
				await loadNoImageProducts();
				
				alert('Image uploaded successfully!');
				closeImagePreview();
				closeImageSearchPopup();
			}
		} catch (error) {
			console.error('Error uploading image:', error);
			alert('Error uploading image. Please try again.');
		} finally {
			downloadingImage = false;
		}
	}
	
	function closeImagePreview() {
		showImagePreview = false;
		if (previewImageUrl) {
			URL.revokeObjectURL(previewImageUrl);
		}
		previewImageUrl = '';
		previewImageBlob = null;
		previewBarcode = '';
	}
	
	// Edit product functions
	function openEditPopup(product: any) {
		editingProduct = { ...product };
		showEditPopup = true;
	}
	
	function closeEditPopup() {
		showEditPopup = false;
		editingProduct = null;
		isSavingEdit = false;
	}
	
	async function saveProductEdit() {
		if (!editingProduct) return;
		
		isSavingEdit = true;
		try {
			const { error } = await supabase
				.from('flyer_products')
				.update({
					product_name_en: editingProduct.product_name_en,
					product_name_ar: editingProduct.product_name_ar,
					unit_name: editingProduct.unit_name,
					parent_category: editingProduct.parent_category || null,
					parent_sub_category: editingProduct.parent_sub_category || null,
					sub_category: editingProduct.sub_category || null,
					updated_at: new Date().toISOString()
				})
				.eq('barcode', editingProduct.barcode);
			
			if (error) {
				console.error('Error updating product:', error);
				alert('Failed to update product: ' + error.message);
			} else {
				alert('Product updated successfully!');
				
				// Reload the appropriate view
				if (showNoImageProducts) {
					await loadNoImageProducts();
				}
				if (showAllProducts) {
					await loadAllProducts();
				}
				
				closeEditPopup();
			}
		} catch (error) {
			console.error('Error saving product:', error);
			alert('Error saving product. Please try again.');
		} finally {
			isSavingEdit = false;
		}
	}
	
	// Create product functions
	function openCreatePopup() {
		newProduct = {
			barcode: '',
			product_name_en: '',
			product_name_ar: '',
			unit_name: '',
			parent_category: '',
			parent_sub_category: '',
			sub_category: '',
			image_url: ''
		};
		isCheckingImage = false;
		imageCheckStatus = '';
		imageCheckResult = null;
		foundImageUrl = '';
		showCreatePopup = true;
	}
	
	function closeCreatePopup() {
		showCreatePopup = false;
		newProduct = null;
		isSavingCreate = false;
		isCheckingImage = false;
		imageCheckStatus = '';
		imageCheckResult = null;
		foundImageUrl = '';
	}
	
	async function saveNewProduct() {
		if (!newProduct) return;
		
		// Validate required fields
		if (!newProduct.barcode || !newProduct.barcode.trim()) {
			alert('Barcode is required!');
			return;
		}
		
		if (!newProduct.product_name_en || !newProduct.product_name_en.trim()) {
			alert('Product name (English) is required!');
			return;
		}
		
		isSavingCreate = true;
		try {
			// Check if barcode already exists
			const { data: existingProduct, error: checkError } = await supabase
				.from('flyer_products')
				.select('barcode')
				.eq('barcode', newProduct.barcode.trim())
				.maybeSingle();
			
			if (existingProduct) {
				alert('A product with this barcode already exists!');
				isSavingCreate = false;
				return;
			}
			
			const { error } = await supabase
				.from('flyer_products')
				.insert({
					barcode: newProduct.barcode.trim(),
					product_name_en: newProduct.product_name_en.trim(),
					product_name_ar: newProduct.product_name_ar?.trim() || null,
					unit_name: newProduct.unit_name?.trim() || null,
					parent_category: newProduct.parent_category?.trim() || null,
					parent_sub_category: newProduct.parent_sub_category?.trim() || null,
					sub_category: newProduct.sub_category?.trim() || null,
					image_url: newProduct.image_url || null,
					created_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				});
			
			if (error) {
				console.error('Error creating product:', error);
				alert('Failed to create product: ' + error.message);
			} else {
				alert('Product created successfully!');
				
				// Reload the appropriate view
				if (showNoImageProducts) {
					await loadNoImageProducts();
				}
				if (showAllProducts) {
					await loadAllProducts();
				}
				
				// Reload database stats
				await loadDatabaseStats();
				
				closeCreatePopup();
			}
		} catch (error) {
			console.error('Error creating product:', error);
			alert('Error creating product. Please try again.');
		} finally {
			isSavingCreate = false;
		}
	}
	
	async function checkImageAvailability() {
		if (!newProduct?.barcode || !newProduct.barcode.trim()) {
			alert('Please enter a barcode first!');
			return;
		}
		
		isCheckingImage = true;
		imageCheckStatus = 'Checking...';
		imageCheckResult = null;
		foundImageUrl = '';
		
		try {
			const barcode = newProduct.barcode.trim();
			const bucketName = 'flyer-product-images';
			
			// Try to get the public URL for the image
			const { data: urlData } = supabase
				.storage
				.from(bucketName)
				.getPublicUrl(`${barcode}.png`);
			
			const imageUrl = urlData.publicUrl;
			
			// Try to fetch the image to verify it exists
			const response = await fetch(imageUrl);
			
			if (response.ok) {
				// Image exists!
				imageCheckStatus = 'Image exists! URL saved automatically.';
				imageCheckResult = 'success';
				foundImageUrl = imageUrl;
				
				// Automatically set the image URL in the newProduct object
				// Use object reassignment to trigger Svelte reactivity
				newProduct = { ...newProduct, image_url: imageUrl };
			} else {
				// Image not found
				imageCheckStatus = 'Image not available for this barcode.';
				imageCheckResult = 'error';
			}
		} catch (error) {
			console.error('Error checking image:', error);
			imageCheckStatus = 'Error checking image availability.';
			imageCheckResult = 'error';
		} finally {
			isCheckingImage = false;
		}
	}

	async function handleImageUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		
		if (!files || files.length === 0) return;
		
		isUploadingImages = true;
		cancelImageUpload = false;
		totalImageCount = files.length;
		uploadedImageCount = 0;
		imageUploadProgress = 0;
		uploadProgress = `Preparing to upload ${files.length} images...`;
		
		let successCount = 0;
		let failedCount = 0;
		
		// Create or ensure bucket exists
		const bucketName = 'flyer-product-images';
		
		// Upload images in batches of 5
		const batchSize = 5;
		for (let i = 0; i < files.length; i += batchSize) {
			// Check if user cancelled
			if (cancelImageUpload) {
				uploadProgress = `Upload cancelled! ${successCount} images uploaded before cancellation.`;
				imageUploadProgress = Math.round((uploadedImageCount / totalImageCount) * 100);
				break;
			}
			
			const batch = Array.from(files).slice(i, i + batchSize);
			
			await Promise.all(
				batch.map(async (file) => {
					// Check if cancelled before processing each file
					if (cancelImageUpload) return;
					
					try {
						// Get filename without extension to use as barcode
						const fileName = file.name;
						const barcode = fileName.replace(/\.[^/.]+$/, ''); // Remove extension
						
						// Upload to Supabase Storage
						const { data, error } = await supabase.storage
							.from(bucketName)
							.upload(`${barcode}.png`, file, {
								cacheControl: '3600',
								upsert: true // Overwrite if exists
							});
						
						if (error) {
							console.error(`Failed to upload ${fileName}:`, error);
							failedCount++;
						} else {
							successCount++;
							// Add to cache immediately
							storageImageCache.add(barcode);
						}
						
						// Update count
						uploadedImageCount++;
						imageUploadProgress = Math.round((uploadedImageCount / totalImageCount) * 100);
						uploadProgress = `Uploading: ${uploadedImageCount} / ${totalImageCount} (${imageUploadProgress}%)`;
					} catch (error) {
						console.error(`Error uploading ${file.name}:`, error);
						failedCount++;
						uploadedImageCount++;
						imageUploadProgress = Math.round((uploadedImageCount / totalImageCount) * 100);
						uploadProgress = `Uploading: ${uploadedImageCount} / ${totalImageCount} (${imageUploadProgress}%)`;
					}
				})
			);
		}
		
		// Only show success popup if not cancelled
		if (!cancelImageUpload) {
			uploadProgress = `Upload complete! ✓ ${successCount} uploaded${failedCount > 0 ? `, ✗ ${failedCount} failed` : ''} out of ${totalImageCount} total`;
			imageUploadProgress = 100;
			
			// Show success popup
			uploadSuccessMessage = `Successfully uploaded ${successCount} image${successCount !== 1 ? 's' : ''}!${failedCount > 0 ? ` ${failedCount} failed.` : ''}`;
			showUploadSuccessPopup = true;
		}
		
		// Refresh the table to show new images
		filteredProducts = [...filteredProducts];
		await updateImageStats();
		
		setTimeout(() => {
			isUploadingImages = false;
			uploadProgress = '';
			imageUploadProgress = 0;
			uploadedImageCount = 0;
			totalImageCount = 0;
			cancelImageUpload = false;
		}, 3000);
		
		// Reset file input
		target.value = '';
	}
	
	async function handleFileChange(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;
		
		const reader = new FileReader();
		
		reader.onload = async (e) => {
			const data = e.target?.result;
			const workbook = XLSX.read(data, { type: 'binary' });
			const sheetName = workbook.SheetNames[0];
			const worksheet = workbook.Sheets[sheetName];
			const jsonData = XLSX.utils.sheet_to_json(worksheet);
			
			// Save to local state
			products = jsonData;
			filteredProducts = jsonData;
			hasUnsavedData = true;
		};
		
		reader.readAsBinaryString(file);
	}
	
	async function handleSave() {
		if (!hasUnsavedData || products.length === 0) return;
		await saveProductsToDatabase(products);
	}
	
	async function saveProductsToDatabase(productList: any[]) {
		isSavingProducts = true;
		saveProgress = 0;
		uploadProgress = 'Starting save process...';
		
		let savedCount = 0;
		let imageFoundCount = 0;
		const totalProducts = productList.length;
		
		for (let i = 0; i < productList.length; i++) {
			const product = productList[i];
			try {
				const barcode = String(product.Barcode || '');
				if (!barcode) continue;
				
				// Check if image actually exists in storage before setting image_url
				let imageUrl = null;
				if (barcode) {
					try {
						// Try to check if the file exists in storage
						const { data: fileList, error: listError } = await supabase.storage
							.from('flyer-product-images')
							.list('', {
								limit: 1,
								search: `${barcode}.png`
							});
						
						// If file exists, get the public URL
						if (fileList && fileList.length > 0) {
							const { data: urlData } = supabase.storage
								.from('flyer-product-images')
								.getPublicUrl(`${barcode}.png`);
							imageUrl = urlData.publicUrl;
							imageFoundCount++;
						}
					} catch (err) {
						// Image doesn't exist, leave imageUrl as null
						console.log(`No image found for ${barcode}`);
					}
				}
				
				// Insert or update product in database
				// upsert will automatically handle both new and existing products
				const { error: dbError } = await supabase
					.from('flyer_products')
					.upsert({
						barcode: barcode,
						product_name_en: product['Product name english'] || product['Product name_en'] || '',
						product_name_ar: product['Product name arabic'] || product['Product name_ar'] || '',
						unit_name: product['unit'] || product['Unit name'] || '',
						parent_category: product['Parent Category'] || '',
						parent_sub_category: product['Parent Sub Category'] || '',
						sub_category: product['Sub Category'] || '',
						image_url: imageUrl, // Will be null if image doesn't exist
						updated_at: new Date().toISOString()
					}, {
						onConflict: 'barcode',
						ignoreDuplicates: false
					});
				
				if (!dbError) {
					savedCount++;
				} else {
					console.error(`Error saving product ${barcode}:`, dbError);
				}
			} catch (error) {
				console.error('Error saving product:', error);
			}
			
			// Update progress
			saveProgress = Math.round(((i + 1) / totalProducts) * 100);
			uploadProgress = `Saved ${savedCount}/${totalProducts} products, ${imageFoundCount} with images...`;
		}
		
		uploadProgress = `Complete! Saved ${savedCount} products with ${imageFoundCount} images.`;
		saveProgress = 100;
		hasUnsavedData = false;
		
		// Clear the file input
		if (fileInput) {
			fileInput.value = '';
		}
		
		// Clear all data - don't reload from database
		products = [];
		filteredProducts = [];
		searchBarcode = '';
		
		// Refresh database statistics
		await loadDatabaseStats();
		
		setTimeout(() => {
			isSavingProducts = false;
			uploadProgress = '';
			saveProgress = 0;
		}, 3000);
	}
	
	function getImagePath(barcode: string, product?: any): string {
		// If product has image_url from database (already uploaded), use it
		if (product && product.image_url) {
			return product.image_url;
		}
		
		// Try to get public URL from storage (it will return URL even if file doesn't exist)
		// The actual check happens on image load error
		if (barcode) {
			const { data } = supabase.storage
				.from('flyer-product-images')
				.getPublicUrl(`${barcode}.png`);
			
			return data.publicUrl;
		}
		
		// Return placeholder if no barcode
		return 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><rect fill="%23f3f4f6" width="100" height="100"/><text x="50" y="50" font-size="12" text-anchor="middle" alignment-baseline="middle" fill="%239ca3af">No Image</text></svg>';
	}
	
	function handleImageError(event: Event) {
		// Show placeholder if image doesn't exist
		const img = event.target as HTMLImageElement;
		const barcode = img.getAttribute('data-barcode');
		if (barcode) {
			loadingImages.delete(barcode);
			loadingImages = loadingImages; // Trigger reactivity
		}
		img.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><rect fill="%23f3f4f6" width="100" height="100"/><text x="50" y="50" font-size="12" text-anchor="middle" alignment-baseline="middle" fill="%239ca3af">No Image</text></svg>';
	}
	
	function handleImageLoad(event: Event) {
		// Remove from loading state when image loads successfully
		const img = event.target as HTMLImageElement;
		const barcode = img.getAttribute('data-barcode');
		if (barcode) {
			loadingImages.delete(barcode);
			loadingImages = loadingImages; // Trigger reactivity
		}
	}
	
	function handleImageLoadStart(barcode: string) {
		// Add to loading state when image starts loading
		loadingImages.add(barcode);
		loadingImages = loadingImages; // Trigger reactivity
	}
	
	function handleSearch() {
		if (!searchBarcode.trim()) {
			filteredProducts = [...products];
		} else {
			filteredProducts = products.filter(product => 
				String(product.Barcode).toLowerCase().includes(searchBarcode.toLowerCase())
			);
		}
	}
	
	async function exportProductsWithoutImages() {
		// Get products without images
		const productsNoImages = await getProductsWithoutImages();
		
		if (productsNoImages.length === 0) {
			alert('All products have images! Nothing to export.');
			return;
		}
		
		// Prepare data for Excel
		const exportData = productsNoImages.map(product => {
			const barcode = product.Barcode || product.barcode || '';
			return {
				'Barcode': barcode,
				'Readable Barcode': `'${barcode}`, // Prefix with ' to force text format in Excel
				'Product name_en': product['Product name_en'] || product.product_name_en || '',
				'Product name_ar': product['Product name_ar'] || product.product_name_ar || '',
				'Unit name': product['Unit name'] || product.unit_name || ''
			};
		});
		
		// Create workbook and worksheet
		const worksheet = XLSX.utils.json_to_sheet(exportData);
		const workbook = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(workbook, worksheet, 'Products Without Images');
		
		// Generate filename with date
		const date = new Date().toISOString().split('T')[0];
		const filename = `products_without_images_${date}.xlsx`;
		
		// Download
		XLSX.writeFile(workbook, filename);
	}
	
	async function getProductsWithoutImages(): Promise<any[]> {
		// Make sure cache is loaded
		if (!isCacheLoaded) {
			await loadStorageImageCache();
		}
		
		const noImageProducts: any[] = [];
		
		// Check against cache - super fast!
		filteredProducts.forEach(product => {
			const barcode = String(product.Barcode || product.barcode || '');
			if (!barcode || !storageImageCache.has(barcode)) {
				noImageProducts.push(product);
			}
		});
		
		return noImageProducts;
	}
	
	// Reactive statement to trigger search when searchBarcode or products changes
	$: {
		searchBarcode;
		products;
		handleSearch();
	}
	
	// Load quota data on mount
	onMount(() => {
		loadQuotaData();
		loadAllProductsForDropdowns();
	});
</script>

<div class="space-y-6">
	<!-- Edit Product Popup -->
	{#if showCreatePopup && newProduct}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" on:click={closeCreatePopup}>
			<div class="bg-white rounded-lg shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden" on:click|stopPropagation>
				<!-- Header -->
				<div class="bg-gradient-to-r from-green-600 to-emerald-600 p-4 flex items-center justify-between">
					<div class="flex items-center gap-3">
						<div class="bg-white bg-opacity-20 rounded-lg p-2">
							<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
							</svg>
						</div>
						<div>
							<h3 class="text-lg font-bold text-white">Create New Product</h3>
							<p class="text-xs text-green-100">Add a new product to the database</p>
						</div>
					</div>
					<button 
						on:click={closeCreatePopup}
						class="text-white hover:bg-white hover:bg-opacity-20 rounded-lg p-2 transition-colors"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>
				
				<!-- Content -->
				<div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
					<div class="space-y-4">
						<!-- Barcode -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Barcode <span class="text-red-500">*</span>
							</label>
							<input
								type="text"
								bind:value={newProduct.barcode}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Enter product barcode"
							/>
							
							<!-- Check Image Availability Button -->
							<div class="mt-2">
								<button
									type="button"
									on:click={checkImageAvailability}
									disabled={isCheckingImage || !newProduct.barcode?.trim()}
									class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-lg transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
								>
									{#if isCheckingImage}
										<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
											<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
											<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
										</svg>
										Checking...
									{:else}
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
										</svg>
										Check Image Availability
									{/if}
								</button>
								
								<!-- Image Check Status -->
								{#if imageCheckStatus}
									<div class="mt-2 p-3 rounded-lg flex items-start gap-2 {imageCheckResult === 'success' ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}">
										{#if imageCheckResult === 'success'}
											<svg class="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
											</svg>
											<div class="flex-1">
												<p class="text-sm font-semibold text-green-800">{imageCheckStatus}</p>
												{#if foundImageUrl}
													<p class="text-xs text-green-600 mt-1 break-all">{foundImageUrl}</p>
												{/if}
											</div>
										{:else}
											<svg class="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
											</svg>
											<p class="text-sm font-semibold text-red-800">{imageCheckStatus}</p>
										{/if}
									</div>
								{/if}
							</div>
						</div>
						
						<!-- Product Name English -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Product Name (English) <span class="text-red-500">*</span>
							</label>
							<input
								type="text"
								bind:value={newProduct.product_name_en}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Enter product name in English"
							/>
						</div>
						
						<!-- Product Name Arabic -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Product Name (Arabic)
							</label>
							<input
								type="text"
								bind:value={newProduct.product_name_ar}
								dir="rtl"
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="أدخل اسم المنتج بالعربية"
							/>
						</div>
						
						<!-- Unit Name -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Unit ({uniqueUnits.length} options)
							</label>
							<select
								bind:value={newProduct.unit_name}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueUnits as unit}
									<option value={unit}>{unit}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={newProduct.unit_name}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Or type custom unit"
							/>
						</div>
						
						<!-- Parent Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Parent Category ({uniqueParentCategories.length} options)
							</label>
							<select
								bind:value={newProduct.parent_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueParentCategories as category}
									<option value={category}>{category}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={newProduct.parent_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Or type custom category"
							/>
						</div>
						
						<!-- Parent Sub Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Parent Sub Category ({uniqueParentSubCategories.length} options)
							</label>
							<select
								bind:value={newProduct.parent_sub_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueParentSubCategories as subCategory}
									<option value={subCategory}>{subCategory}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={newProduct.parent_sub_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Or type custom sub category"
							/>
						</div>
						
						<!-- Sub Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Sub Category ({uniqueSubCategories.length} options)
							</label>
							<select
								bind:value={newProduct.sub_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueSubCategories as subCategory}
									<option value={subCategory}>{subCategory}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={newProduct.sub_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
								placeholder="Or type custom sub category"
							/>
						</div>
					</div>
				</div>
				
				<!-- Footer -->
				<div class="bg-gray-50 px-6 py-4 flex items-center justify-end gap-3 border-t border-gray-200">
					<button
						on:click={closeCreatePopup}
						class="px-4 py-2 text-gray-700 font-semibold rounded-lg hover:bg-gray-200 transition-colors"
						disabled={isSavingCreate}
					>
						Cancel
					</button>
					<button
						on:click={saveNewProduct}
						disabled={isSavingCreate}
						class="px-6 py-2 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isSavingCreate}
							<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Creating...
						{:else}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
							</svg>
							Create Product
						{/if}
					</button>
				</div>
			</div>
		</div>
	{/if}
	
	{#if showEditPopup && editingProduct}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" on:click={closeEditPopup}>
			<div class="bg-white rounded-lg shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden" on:click|stopPropagation>
				<!-- Header -->
				<div class="bg-gradient-to-r from-blue-600 to-indigo-600 p-4 flex items-center justify-between">
					<div class="flex items-center gap-3">
						<div class="bg-white bg-opacity-20 rounded-lg p-2">
							<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
							</svg>
						</div>
						<div>
							<h3 class="text-lg font-bold text-white">Edit Product</h3>
							<p class="text-xs text-blue-100">Barcode: {editingProduct.barcode}</p>
						</div>
					</div>
					<button 
						on:click={closeEditPopup}
						class="text-white hover:bg-white hover:bg-opacity-20 rounded-lg p-2 transition-colors"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>
				
				<!-- Content -->
				<div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
					<div class="space-y-4">
						<!-- Product Name English -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Product Name (English)
							</label>
							<input
								type="text"
								bind:value={editingProduct.product_name_en}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="Enter product name in English"
							/>
						</div>
						
						<!-- Product Name Arabic -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Product Name (Arabic)
							</label>
							<input
								type="text"
								bind:value={editingProduct.product_name_ar}
								dir="rtl"
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="أدخل اسم المنتج بالعربية"
							/>
						</div>
						
						<!-- Unit Name -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Unit ({uniqueUnits.length} options)
							</label>
							<select
								bind:value={editingProduct.unit_name}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueUnits as unit}
									<option value={unit}>{unit}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={editingProduct.unit_name}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="Or type custom unit"
							/>
						</div>
						
						<!-- Parent Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Parent Category ({uniqueParentCategories.length} options)
							</label>
							<select
								bind:value={editingProduct.parent_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueParentCategories as category}
									<option value={category}>{category}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={editingProduct.parent_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="Or type custom category"
							/>
						</div>
						
						<!-- Parent Sub Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Parent Sub Category ({uniqueParentSubCategories.length} options)
							</label>
							<select
								bind:value={editingProduct.parent_sub_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueParentSubCategories as subCategory}
									<option value={subCategory}>{subCategory}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={editingProduct.parent_sub_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="Or type custom sub category"
							/>
						</div>
						
						<!-- Sub Category -->
						<div>
							<label class="block text-sm font-semibold text-gray-700 mb-2">
								Sub Category ({uniqueSubCategories.length} options)
							</label>
							<select
								bind:value={editingProduct.sub_category}
								class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
							>
								<option value="">-- Select or type below --</option>
								{#each uniqueSubCategories as subCategory}
									<option value={subCategory}>{subCategory}</option>
								{/each}
							</select>
							<input
								type="text"
								bind:value={editingProduct.sub_category}
								class="w-full px-4 py-2 mt-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
								placeholder="Or type custom sub category"
							/>
						</div>
					</div>
				</div>
				
				<!-- Footer -->
				<div class="bg-gray-50 px-6 py-4 flex items-center justify-end gap-3 border-t border-gray-200">
					<button
						on:click={closeEditPopup}
						class="px-4 py-2 text-gray-700 font-semibold rounded-lg hover:bg-gray-200 transition-colors"
						disabled={isSavingEdit}
					>
						Cancel
					</button>
					<button
						on:click={saveProductEdit}
						disabled={isSavingEdit}
						class="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{#if isSavingEdit}
							<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Saving...
						{:else}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
							</svg>
							Save Changes
						{/if}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Success Popup -->
	{#if showUploadSuccessPopup}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" on:click={() => showUploadSuccessPopup = false}>
			<div class="bg-white rounded-lg shadow-2xl p-6 max-w-md w-full mx-4 transform transition-all" on:click|stopPropagation>
				<div class="flex items-center justify-center mb-4">
					<div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
						<svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
						</svg>
					</div>
				</div>
				<h3 class="text-2xl font-bold text-center text-gray-800 mb-2">Upload Successful!</h3>
				<p class="text-center text-gray-600 mb-6">{uploadSuccessMessage}</p>
				<button 
					on:click={() => showUploadSuccessPopup = false}
					class="w-full px-6 py-3 bg-gradient-to-r from-green-600 to-teal-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200"
				>
					Close
				</button>
			</div>
		</div>
	{/if}

	<!-- Image Preview Popup (After Background Removal) -->
	{#if showImagePreview}
		<div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4" on:click={closeImagePreview}>
			<div class="bg-white rounded-lg shadow-2xl max-w-3xl w-full max-h-[90vh] overflow-hidden flex flex-col" on:click|stopPropagation>
				<!-- Header -->
				<div class="bg-gradient-to-r from-blue-600 to-purple-600 p-6 flex items-center justify-between">
					<div>
						<h3 class="text-2xl font-bold text-white">✨ Background Removed!</h3>
						<p class="text-white text-opacity-90 mt-1">
							Barcode: {previewBarcode}
						</p>
					</div>
					<button 
						on:click={closeImagePreview}
						class="px-4 py-2 bg-white text-gray-700 font-semibold rounded-lg hover:bg-gray-50 transition-colors"
					>
						Close
					</button>
				</div>
				
				<!-- Image Preview -->
				<div class="flex-1 overflow-y-auto p-6 bg-gray-50">
					<div class="bg-white rounded-lg shadow-lg p-4 mb-6">
						<h4 class="text-lg font-semibold text-gray-800 mb-4">Preview Image:</h4>
						<div class="relative">
							<!-- Checkered background to show transparency -->
							<div class="absolute inset-0 bg-checkered rounded-lg"></div>
							<img 
								src={previewImageUrl}
								alt="Preview"
								class="relative w-full h-auto max-h-96 object-contain rounded-lg"
							/>
						</div>
					</div>
					
					<!-- Action Buttons -->
					<div class="flex gap-4 justify-center">
						<button
							on:click={closeImagePreview}
							class="px-6 py-3 bg-gray-500 hover:bg-gray-600 text-white font-semibold rounded-lg transition-colors flex items-center gap-2"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
							Cancel
						</button>
						<button
							on:click={uploadPreviewImage}
							disabled={downloadingImage}
							class="px-6 py-3 bg-gradient-to-r from-green-600 to-teal-600 hover:shadow-lg text-white font-semibold rounded-lg transition-all flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if downloadingImage}
								<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
									<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
									<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
								</svg>
								Uploading...
							{:else}
								<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
								</svg>
								Upload Image
							{/if}
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Web Image Search Popup -->
	{#if showImageSearchPopup}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" on:click={closeImageSearchPopup}>
			<div class="bg-white rounded-lg shadow-2xl max-w-5xl w-full max-h-[90vh] overflow-hidden flex flex-col" on:click|stopPropagation>
				<!-- Header -->
				<div class="bg-gradient-to-r {searchProvider === 'google' ? 'from-blue-600 to-blue-700' : 'from-orange-600 to-red-600'} p-6 flex items-center justify-between">
					<div>
						<h3 class="text-2xl font-bold text-white">
							{searchProvider === 'google' ? '🔍 Google Search' : '🦆 DuckDuckGo Search'}
						</h3>
						<p class="text-white text-opacity-90 mt-1">
							Barcode: {searchingBarcode}
						</p>
						<div class="flex gap-4 mt-2 text-xs text-white text-opacity-80">
							<span>
								Google: {quotaData.googleSearches}/{GOOGLE_DAILY_LIMIT} today
							</span>
							<span>
								Remove.bg: {quotaData.removeBgUses}/{REMOVE_BG_MONTHLY_LIMIT} this month
							</span>
						</div>
					</div>
					<button 
						on:click={closeImageSearchPopup}
						class="px-4 py-2 bg-white text-gray-700 font-semibold rounded-lg hover:bg-gray-50 transition-colors"
					>
						Close
					</button>
				</div>
				
				<!-- Content -->
				<div class="flex-1 overflow-y-auto p-6">
					{#if isSearchingWeb}
						<div class="flex flex-col items-center justify-center py-12">
							<svg class="animate-spin w-12 h-12 text-green-600 mb-4" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							<p class="text-gray-600">Searching for images...</p>
						</div>
					{:else if webImages.length === 0}
						<div class="flex flex-col items-center justify-center py-12">
							<svg class="w-24 h-24 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							<h4 class="text-xl font-semibold text-gray-800 mb-2">No images found</h4>
							<p class="text-gray-600">Try searching with a different barcode or upload manually.</p>
						</div>
					{:else}
						<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
							{#each webImages as image, index (image.url || index)}
								<div class="relative group">
									<img 
										src={`/api/proxy-image?url=${encodeURIComponent(image.url || image)}`}
										alt="Product {index + 1}"
										class="w-full h-48 object-cover rounded-lg border-2 border-gray-200 hover:border-green-500 transition-all"
										loading="lazy"
										on:error={(e) => {
											const img = e.target;
											img.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><rect fill="%23f3f4f6" width="100" height="100"/><text x="50" y="50" font-size="10" text-anchor="middle" alignment-baseline="middle" fill="%239ca3af">Image Unavailable</text></svg>';
										}}
									/>
									<div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-60 transition-all duration-200 flex items-center justify-center gap-2 opacity-0 group-hover:opacity-100 rounded-lg">
										{#if downloadingImage && selectedWebImage === (image.url || image)}
											<div class="bg-white rounded-lg px-4 py-3 flex items-center gap-2">
												<svg class="animate-spin w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24">
													<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
													<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
												</svg>
												<span class="text-sm font-semibold text-gray-700">Uploading...</span>
											</div>
										{:else if removingBackground && selectedWebImage === (image.url || image)}
											<div class="bg-white rounded-lg px-4 py-3 flex items-center gap-2">
												<svg class="animate-spin w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24">
													<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
													<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
												</svg>
												<span class="text-sm font-semibold text-gray-700">Removing Background...</span>
											</div>
										{:else}
											<div class="flex flex-col gap-2">
												<!-- Use As-Is Button -->
												<button
													on:click={() => downloadAndUploadImage(image.url || image, 'none')}
													disabled={downloadingImage || removingBackground}
													class="bg-green-600 hover:bg-green-700 text-white rounded-lg px-3 py-2 flex items-center gap-2 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
												>
													<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
													</svg>
													<span class="text-xs font-semibold">Use This</span>
												</button>
												
												<!-- Free AI Background Removal Button (Client-side) -->
												<button
													on:click={() => downloadAndUploadImage(image.url || image, 'client')}
													disabled={downloadingImage || removingBackground}
													class="bg-blue-600 hover:bg-blue-700 text-white rounded-lg px-3 py-2 flex items-center gap-2 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed text-xs font-semibold"
													title="Free AI background removal (runs in browser, unlimited)"
												>
													<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
													</svg>
													<span>AI Remove (Free)</span>
													<span class="text-[9px] opacity-75">(∞)</span>
												</button>
												
												<!-- Remove.bg API Button -->
												<button
													on:click={() => downloadAndUploadImage(image.url || image, 'api')}
													disabled={downloadingImage || removingBackground || !isRemoveBgAvailable()}
													class="rounded-lg px-3 py-2 flex items-center gap-2 transition-colors text-white text-xs font-semibold {isRemoveBgAvailable() ? 'bg-purple-600 hover:bg-purple-700' : 'bg-gray-400 cursor-not-allowed'}"
													title={isRemoveBgAvailable() ? `Remove.bg API (${quotaData.removeBgUses}/${REMOVE_BG_MONTHLY_LIMIT} used this month)` : 'Monthly quota exceeded'}
												>
													<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
													</svg>
													<span>Remove.bg</span>
													<span class="text-[9px] opacity-75">({quotaData.removeBgUses}/{REMOVE_BG_MONTHLY_LIMIT})</span>
												</button>
											</div>
										{/if}
									</div>
								</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<!-- Image Upload Progress Bar -->
	{#if isUploadingImages && imageUploadProgress >= 0}
		<div class="bg-white rounded-lg shadow-md p-4 border-2 border-green-200">
			<div class="flex items-center justify-between mb-2">
				<div class="flex items-center gap-2">
					<svg class="animate-spin w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<span class="text-sm font-semibold text-gray-700">Uploading Images</span>
				</div>
				<div class="flex items-center gap-3">
					<span class="text-sm font-medium text-gray-600">{uploadedImageCount} / {totalImageCount}</span>
					<span class="text-sm font-bold text-green-600">{imageUploadProgress}%</span>
					{#if !cancelImageUpload}
						<button 
							on:click={handleCancelUpload}
							class="px-3 py-1 bg-red-500 hover:bg-red-600 text-white text-xs font-semibold rounded transition-colors duration-200"
						>
							Cancel
						</button>
					{/if}
				</div>
			</div>
			<div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
				<div 
					class="bg-gradient-to-r from-green-600 to-teal-600 h-3 rounded-full transition-all duration-300 ease-out"
					style="width: {imageUploadProgress}%"
				></div>
			</div>
			{#if uploadProgress}
				<p class="text-xs text-gray-600 mt-2">{uploadProgress}</p>
			{/if}
		</div>
	{/if}

	<!-- Saving Products Progress Bar -->
	{#if isSavingProducts && saveProgress > 0}
		<div class="bg-white rounded-lg shadow-md p-4">
			<div class="flex items-center justify-between mb-2">
				<span class="text-sm font-semibold text-gray-700">Saving Progress</span>
				<span class="text-sm font-bold text-blue-600">{saveProgress}%</span>
			</div>
			<div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
				<div 
					class="bg-gradient-to-r from-blue-600 to-purple-600 h-3 rounded-full transition-all duration-300 ease-out"
					style="width: {saveProgress}%"
				></div>
			</div>
			{#if uploadProgress}
				<p class="text-xs text-gray-600 mt-2">{uploadProgress}</p>
			{/if}
		</div>
	{/if}

	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-3xl font-bold text-gray-800">Product Dashboard</h1>
			<p class="text-gray-600 mt-1">Manage your products by importing from Excel</p>
			{#if hasUnsavedData}
				<p class="text-sm text-orange-600 mt-2 font-semibold">
					⚠️ You have unsaved data. Click "Save to Database" to save.
				</p>
			{/if}
		</div>
		
		<div class="flex gap-3">
			{#if hasUnsavedData}
				<button 
					on:click={handleSave}
					disabled={isSavingProducts}
					class="px-6 py-3 bg-gradient-to-r from-green-600 to-teal-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{#if isSavingProducts}
						<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Saving...
					{:else}
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
						</svg>
						Save to Database
					{/if}
				</button>
			{/if}
			
			<button 
				on:click={openCreatePopup}
				class="px-6 py-3 bg-gradient-to-r from-emerald-600 to-green-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 flex items-center gap-2"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
				</svg>
				Create Product
			</button>
			
			<button 
				on:click={handleUploadImages}
				disabled={isUploadingImages}
				class="px-6 py-3 bg-gradient-to-r from-green-600 to-teal-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
			>
				{#if isUploadingImages}
					<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					Uploading...
				{:else}
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
					</svg>
					Upload Images
				{/if}
			</button>
			
			<button 
				on:click={downloadTemplate}
				class="px-6 py-3 bg-gradient-to-r from-indigo-600 to-blue-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 flex items-center gap-2"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
				</svg>
				Download Template
			</button>
			
			<button 
				on:click={handleImport}
				disabled={isSavingProducts}
				class="px-6 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
				</svg>
				Import from Excel
			</button>
		</div>
	</div>

	<!-- Database Statistics Cards -->
	<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
		<!-- Total Products in Database Card -->
		<div class="bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden">
			<div class="bg-gradient-to-r from-blue-600 to-indigo-600 p-4">
				<div class="flex items-center justify-between">
					<div class="flex items-center gap-3">
						<div class="bg-white bg-opacity-20 rounded-lg p-2">
							<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
							</svg>
						</div>
						<h3 class="text-white font-bold text-lg">Total Products</h3>
					</div>
				</div>
			</div>
			<div class="p-5 bg-gradient-to-br from-gray-50 to-white">
				{#if isLoadingDbStats}
					<div class="flex items-center justify-center gap-2 py-4">
						<svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						<span class="text-sm text-gray-600">Loading...</span>
					</div>
				{:else}
					<div class="flex items-center justify-between">
						<div>
							<p class="text-4xl font-bold text-gray-900 mb-1">{dbTotalProducts.toLocaleString()}</p>
							<p class="text-sm text-gray-500">Products in database</p>
						</div>
						{#if dbTotalProducts > 0}
							<button
								on:click={loadAllProducts}
								class="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold rounded-md transition-colors"
							>
								View All
							</button>
						{/if}
					</div>
				{/if}
			</div>
		</div>

		<!-- Products Without Images Card -->
		<div class="bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden">
			<div class="bg-gradient-to-r from-orange-600 to-red-600 p-4">
				<div class="flex items-center justify-between">
					<div class="flex items-center gap-3">
						<div class="bg-white bg-opacity-20 rounded-lg p-2">
							<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
							</svg>
						</div>
						<h3 class="text-white font-bold text-lg">Missing Images</h3>
					</div>
				</div>
			</div>
			<div class="p-5 bg-gradient-to-br from-gray-50 to-white">
				{#if isLoadingDbStats}
					<div class="flex items-center justify-center gap-2 py-4">
						<svg class="animate-spin w-6 h-6 text-orange-600" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						<span class="text-sm text-gray-600">Loading...</span>
					</div>
				{:else}
					<div class="flex items-center justify-between">
						<div>
							<p class="text-4xl font-bold text-gray-900 mb-1">{dbProductsWithoutImages.toLocaleString()}</p>
							<p class="text-sm text-gray-500">Products without images</p>
						</div>
						{#if dbProductsWithoutImages > 0}
							<button
								on:click={loadNoImageProducts}
								class="px-3 py-1.5 bg-orange-600 hover:bg-orange-700 text-white text-xs font-semibold rounded-md transition-colors"
							>
								Upload
							</button>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	</div>
	
	<!-- Hidden file inputs -->
	<input
		type="file"
		bind:this={fileInput}
		on:change={handleFileChange}
		accept=".xlsx,.xls"
		class="hidden"
	/>
	
	<input
		type="file"
		bind:this={imageInput}
		on:change={handleImageUpload}
		accept="image/*"
		multiple
		webkitdirectory
		directory
		class="hidden"
	/>
	
	<!-- Products Without Images View -->
	{#if showNoImageProducts}
		<div class="bg-white rounded-lg shadow-lg overflow-hidden border border-gray-200">
			<div class="bg-white border-b border-gray-200">
				<div class="flex items-center justify-between p-4">
					<div class="flex items-center gap-3">
						<div class="bg-gradient-to-br from-orange-600 to-red-600 rounded-lg p-2">
							<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
							</svg>
						</div>
						<div>
							<h2 class="text-xl font-bold text-gray-900">Products Without Images</h2>
							<p class="text-sm text-gray-500 mt-0.5">Upload images for products below</p>
						</div>
					</div>
					<button 
						on:click={closeNoImageView}
						class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold text-sm rounded-lg transition-colors"
					>
						Close
					</button>
				</div>
				
				<!-- Search Bar -->
				<div class="px-4 pb-4">
					<div class="relative">
						<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
							<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
							</svg>
						</div>
						<input
							type="text"
							bind:value={noImageSearchQuery}
							placeholder="Search by barcode or product name..."
							class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
						/>
						{#if noImageSearchQuery}
							<button
								on:click={() => noImageSearchQuery = ''}
								class="absolute inset-y-0 right-0 pr-3 flex items-center"
							>
								<svg class="w-5 h-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
								</svg>
							</button>
						{/if}
					</div>
				</div>
			</div>
			
			{#if isLoadingNoImageProducts}
				<div class="p-12 text-center">
					<svg class="animate-spin w-12 h-12 mx-auto text-red-600" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<p class="text-gray-600 mt-4">Loading products...</p>
				</div>
			{:else if noImageProducts.length === 0}
				<div class="p-12 text-center">
					<svg class="w-24 h-24 mx-auto text-green-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					<h3 class="text-xl font-semibold text-gray-800 mb-2">All products have images!</h3>
					<p class="text-gray-600">Great job! All products in the database have images.</p>
				</div>
			{:else}
				<div class="overflow-x-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Barcode
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Product Name (EN)
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Product Name (AR)
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Unit Name
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Upload Image
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Web Search
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Edit
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#if filteredNoImageProducts.length === 0}
								<tr>
									<td colspan="7" class="px-6 py-12 text-center">
										<svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
										</svg>
										<p class="text-gray-500 text-lg font-medium">No products found</p>
										<p class="text-gray-400 text-sm mt-1">Try adjusting your search query</p>
									</td>
								</tr>
							{:else}
								{#each filteredNoImageProducts as product (product.barcode)}
								<tr class="hover:bg-gray-50 transition-colors">
									<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
										{product.barcode}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900" dir="ltr">
										{product.product_name_en || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900" dir="rtl">
										{product.product_name_ar || '-'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										{product.unit_name || '-'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap">
										<div class="flex items-center gap-2">
											<label 
												for="upload-{product.barcode}"
												class="px-4 py-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white text-sm font-semibold rounded-lg hover:shadow-lg cursor-pointer transition-all duration-200 flex items-center gap-2"
											>
												{#if uploadingImageForBarcode === product.barcode}
													<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
														<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
														<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
													</svg>
													Uploading...
												{:else}
													<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
														<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
													</svg>
													Choose Image
												{/if}
											</label>
											<input
												id="upload-{product.barcode}"
												type="file"
												accept="image/*"
												on:change={(e) => uploadSingleImage(e, product.barcode)}
												disabled={uploadingImageForBarcode !== null}
												class="hidden"
											/>
										</div>
									</td>
									<td class="px-6 py-4 whitespace-nowrap">
										<div class="flex flex-col gap-2">
											<!-- Google Search Button -->
											<button
												on:click={() => searchWebForImages(product.barcode, 'google')}
												disabled={!isGoogleAvailable()}
												class="px-3 py-2 text-white text-xs font-semibold rounded-lg transition-all duration-200 flex items-center gap-2 {isGoogleAvailable() ? 'bg-gradient-to-r from-blue-600 to-blue-700 hover:shadow-lg' : 'bg-gray-400 cursor-not-allowed'}"
												title={isGoogleAvailable() ? `Google (${quotaData.googleSearches}/${GOOGLE_DAILY_LIMIT} used today)` : 'Daily quota exceeded'}
											>
												<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
													<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
													<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
													<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
													<path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
												</svg>
												<span class="hidden xl:inline">Google</span>
												<span class="text-[10px] opacity-75">({quotaData.googleSearches}/{GOOGLE_DAILY_LIMIT})</span>
											</button>
											
											<!-- DuckDuckGo Search Button -->
											<button
												on:click={() => searchWebForImages(product.barcode, 'duckduckgo')}
												class="px-3 py-2 bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-semibold rounded-lg hover:shadow-lg transition-all duration-200 flex items-center gap-2"
												title="DuckDuckGo (Unlimited)"
											>
												<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
													<path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm0 23C5.925 23 1 18.075 1 12S5.925 1 12 1s11 4.925 11 11-4.925 11-11 11z"/>
													<path d="M12 6c-3.309 0-6 2.691-6 6s2.691 6 6 6 6-2.691 6-6-2.691-6-6-6z"/>
												</svg>
												<span class="hidden xl:inline">DuckDuckGo</span>
												<span class="text-[10px] opacity-75">(∞)</span>
											</button>
										</div>
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-center">
										<button
											on:click={() => openEditPopup(product)}
											class="px-3 py-1.5 bg-amber-600 text-white text-xs font-semibold rounded-lg hover:bg-amber-700 transition-colors flex items-center gap-1.5 mx-auto"
											title="Edit product details"
										>
											<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
											</svg>
											Edit
										</button>
									</td>
								</tr>
								{/each}
							{/if}
						</tbody>
					</table>
				</div>
				
				<div class="bg-gray-50 px-6 py-4 border-t border-gray-200">
					<p class="text-sm text-gray-700">
						{#if noImageSearchQuery.trim()}
							Showing <span class="font-semibold">{filteredNoImageProducts.length}</span> of <span class="font-semibold">{noImageProducts.length}</span> products
						{:else}
							Total Products Without Images: <span class="font-semibold">{noImageProducts.length}</span>
						{/if}
					</p>
				</div>
			{/if}
		</div>
	{/if}
	
	<!-- All Products View -->
	{#if showAllProducts}
		<div class="bg-white rounded-lg shadow-lg overflow-hidden border border-gray-200">
			<div class="bg-white border-b border-gray-200">
				<div class="flex items-center justify-between p-4">
					<div class="flex items-center gap-3">
						<div class="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-lg p-2">
							<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
							</svg>
						</div>
						<div>
							<h2 class="text-xl font-bold text-gray-900">All Products in Database</h2>
							<p class="text-sm text-gray-500 mt-0.5">Browse and search all products</p>
						</div>
					</div>
					<button 
						on:click={closeAllProductsView}
						class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold text-sm rounded-lg transition-colors"
					>
						Close
					</button>
				</div>
			</div>
			
			{#if isLoadingAllProducts}
				<div class="p-12 text-center">
					<svg class="animate-spin w-12 h-12 mx-auto text-blue-600" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<p class="text-gray-600 mt-4">Loading products...</p>
				</div>
			{:else if allProductsList.length === 0}
				<div class="p-12 text-center">
					<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
					</svg>
					<h3 class="text-xl font-semibold text-gray-800 mb-2">No Products Found</h3>
					<p class="text-gray-600">Import products from Excel to get started.</p>
				</div>
			{:else}
				<!-- Stats Cards -->
				<div class="bg-white p-6 border-b border-gray-200">
					<div class="flex gap-8 justify-center">
						<div class="text-center bg-gradient-to-br from-blue-50 to-blue-100 rounded-xl p-4 min-w-[150px]">
							<p class="text-4xl font-bold text-blue-700 mb-1">{allProductsList.length}</p>
							<p class="text-sm font-semibold text-gray-700">Total Products</p>
						</div>
						<div class="text-center bg-gradient-to-br from-green-50 to-green-100 rounded-xl p-4 min-w-[150px]">
							<p class="text-4xl font-bold text-green-700 mb-1">{dbProductsWithImages}</p>
							<p class="text-sm font-semibold text-gray-700">With Images</p>
						</div>
						<div class="text-center bg-gradient-to-br from-red-50 to-red-100 rounded-xl p-4 min-w-[150px]">
							<p class="text-4xl font-bold text-red-700 mb-1">{dbProductsWithoutImages}</p>
							<p class="text-sm font-semibold text-gray-700">Without Images</p>
						</div>
					</div>
				</div>
				
				<!-- Search Bar -->
				<div class="bg-gray-50 p-4 border-b border-gray-200">
					<div class="relative">
						<input
							type="text"
							bind:value={allProductsSearch}
							placeholder="Search by barcode, name (English/Arabic)..."
							class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
						<svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</div>
					<p class="text-sm text-gray-600 mt-2">
						Showing {filteredAllProducts.length} of {allProductsList.length} products
					</p>
				</div>
				
				<!-- Products Table -->
				<div class="overflow-x-auto max-h-[600px] overflow-y-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-100 sticky top-0 z-10">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Image
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Actions
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Barcode
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Product Name (English)
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Product Name (Arabic)
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Unit
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Parent Category
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Parent Sub Category
								</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
									Sub Category
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each filteredAllProducts as product (product.barcode)}
								<tr class="hover:bg-gray-50 transition-colors">
									<td class="px-6 py-4 whitespace-nowrap">
										<div class="w-16 h-16 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden relative">
											{#if loadingImages.has(product.barcode)}
												<!-- Loading Spinner -->
												<div class="absolute inset-0 flex items-center justify-center bg-gray-100">
													<svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
														<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
														<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
													</svg>
												</div>
											{/if}
											{#if product.image_url}
												<img 
													src={product.image_url}
													alt={product.product_name_en || product.barcode}
													data-barcode={product.barcode}
													class="w-full h-full object-contain"
													on:loadstart={() => handleImageLoadStart(product.barcode)}
													on:load={handleImageLoad}
													on:error={handleImageError}
												/>
											{:else}
												<svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
												</svg>
											{/if}
										</div>
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-center">
										<input
											type="file"
											id="update-image-{product.barcode}"
											accept="image/*"
											on:change={(e) => uploadSingleImage(e, product.barcode)}
											class="hidden"
										/>
										<button
											on:click={() => document.getElementById(`update-image-${product.barcode}`)?.click()}
											disabled={uploadingImageForBarcode === product.barcode}
											class="px-3 py-1.5 bg-blue-600 text-white text-xs font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1.5 mx-auto"
											title="Update product image"
										>
											{#if uploadingImageForBarcode === product.barcode}
												<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
													<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
													<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
												</svg>
												Uploading...
											{:else}
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
												</svg>
												Update Image
											{/if}
										</button>
										<button
											on:click={() => openEditPopup(product)}
											class="px-3 py-1.5 bg-amber-600 text-white text-xs font-semibold rounded-lg hover:bg-amber-700 transition-colors flex items-center gap-1.5 mx-auto"
											title="Edit product details"
										>
											<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
											</svg>
											Edit
										</button>
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
										{product.barcode}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900" dir="ltr">
										{product.product_name_en || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900" dir="rtl">
										{product.product_name_ar || '-'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										{product.unit_name || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900">
										{product.parent_category || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900">
										{product.parent_sub_category || '-'}
									</td>
									<td class="px-6 py-4 text-sm text-gray-900">
								{product.sub_category || '-'}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>				<div class="bg-gray-50 px-6 py-4 border-t border-gray-200">
					<p class="text-sm text-gray-700">
						Total Products: <span class="font-semibold">{allProductsList.length}</span>
					</p>
				</div>
			{/if}
		</div>
	{/if}
	
	<!-- Search Bar and Stats -->
	{#if products.length > 0}
		<div class="bg-white rounded-lg shadow-md p-4">
			<!-- Search Bar -->
			<div class="flex items-center gap-2 mb-2">
				<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
				</svg>
				<input
					type="text"
					bind:value={searchBarcode}
					placeholder="Search by barcode..."
					class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
				/>
				{#if searchBarcode}
					<button
						on:click={() => searchBarcode = ''}
						class="px-4 py-2 text-gray-600 hover:text-gray-800 transition-colors"
					>
						Clear
					</button>
				{/if}
			</div>
			<p class="text-sm text-gray-500 mt-2">
				Showing {filteredProducts.length} of {products.length} products
			</p>
		</div>
	{/if}
	
	<!-- Products Table -->
	{#if filteredProducts.length > 0}
		<div class="bg-white rounded-lg shadow-lg overflow-hidden">
			<div class="overflow-x-auto">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						<tr>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Image
							</th>
							<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
								Actions
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Barcode
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Product Name (EN)
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Product Name (AR)
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Unit
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Parent Category
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Parent Sub Category
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Sub Category
							</th>
						</tr>
					</thead>
					<tbody class="bg-white divide-y divide-gray-200">
						{#each filteredProducts as product, index (`${product.Barcode || 'no-barcode'}-${index}`)}
							<tr class="hover:bg-gray-50 transition-colors">
								<td class="px-6 py-4 whitespace-nowrap">
									<div class="w-16 h-16 rounded-lg border border-gray-200 flex items-center justify-center overflow-hidden relative">
										{#if loadingImages.has(product.Barcode)}
											<!-- Loading Spinner -->
											<div class="absolute inset-0 flex items-center justify-center bg-gray-100">
												<svg class="animate-spin w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24">
													<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
													<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
												</svg>
											</div>
										{/if}
										<img 
											src={getImagePath(product.Barcode, product)} 
											alt={product['Product name english'] || product['Product name_en'] || 'Product'}
											data-barcode={product.Barcode}
											on:loadstart={() => handleImageLoadStart(product.Barcode)}
											on:load={handleImageLoad}
											on:error={handleImageError}
											class="w-full h-full object-cover"
										/>
									</div>
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
									{product.Barcode || ''}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900" dir="ltr">
									{product['Product name english'] || product['Product name_en'] || product.Product_name_en || ''}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900" dir="rtl">
									{product['Product name arabic'] || product['Product name_ar'] || product.Product_name_ar || ''}
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
									{product['unit'] || product['Unit name'] || product.Unit_name || ''}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900">
									{product['Parent Category'] || ''}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900">
									{product['Parent Sub Category'] || ''}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900">
									{product['Sub Category'] || ''}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			
			<!-- Table Footer -->
			<div class="bg-gray-50 px-6 py-4 border-t border-gray-200">
				<p class="text-sm text-gray-700">
					Total Products: <span class="font-semibold">{filteredProducts.length}</span>
					{#if searchBarcode}
						<span class="text-gray-500">of {products.length}</span>
					{/if}
				</p>
			</div>
		</div>
	{:else if products.length > 0}
		<!-- No Results State -->
		<div class="bg-white rounded-lg shadow-lg p-12 text-center">
			<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
			</svg>
			<h3 class="text-xl font-semibold text-gray-800 mb-2">No products found</h3>
			<p class="text-gray-600 mb-6">Try adjusting your search term</p>
			<button
				on:click={() => searchBarcode = ''}
				class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
			>
				Clear Search
			</button>
		</div>
	{/if}
</div>


<style>
	/* Checkered background pattern to show transparency */
	.bg-checkered {
		background-image: 
			linear-gradient(45deg, #e5e7eb 25%, transparent 25%),
			linear-gradient(-45deg, #e5e7eb 25%, transparent 25%),
			linear-gradient(45deg, transparent 75%, #e5e7eb 75%),
			linear-gradient(-45deg, transparent 75%, #e5e7eb 75%);
		background-size: 20px 20px;
		background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
	}
</style>
