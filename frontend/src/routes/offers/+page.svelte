<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { _, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { sanitizeText } from '$lib/utils/sanitize';
	import { onMount } from 'svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let state = $state({
		offers: [] as any[],
		branches: [] as any[],
		selectedBranchId: '',
		isLoading: true,
		dataLoaded: false,
		downloadingOfferId: null as string | null,
		downloadProgress: 0,
		fileCache: new Map<string, Blob>()
	});

	onMount(async () => {
		await fetchData();
	});

	async function fetchData() {
		try {
			state.isLoading = true;
			
			// Fetch all active offers
			const now = new Date();
			const currentDate = now.toISOString().split('T')[0];
			const currentTime = now.toTimeString().split(' ')[0].substring(0, 5);

			const { data: offerData, error: offerError } = await supabase
				.from('view_offer')
				.select('*')
				.gte('end_date', currentDate)
				.order('created_at', { ascending: false });

			if (offerError) throw offerError;
			
			// Filter out expired offers - only show active/future offers
			state.offers = (offerData || []).filter(offer => {
				// If end date is in the future, it's active
				if (offer.end_date > currentDate) return true;
				
				// If end date is today, check if end time hasn't passed
				if (offer.end_date === currentDate) {
					// Compare times: if current time is before or equal to end time, show it
					return offer.end_time > currentTime;
				}
				
				// Any other case (past dates), don't show
				return false;
			});

			// Get unique branch IDs from offers
			const branchIdsWithOffers = new Set(state.offers.map(o => o.branch_id));
			const branchIdsArray = Array.from(branchIdsWithOffers);

			// Fetch only branches that have active offers
			let branchQuery = supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true);

			// Only apply filter if there are branches with offers
			if (branchIdsArray.length > 0) {
				branchQuery = branchQuery.in('id', branchIdsArray);
			}

			const { data: branchData, error: branchError } = await branchQuery.order('name_en');

			if (branchError) throw branchError;
			
			// Assign branches with sanitized names
			state.branches = (branchData || []).map(branch => ({
				...branch,
				name_en: sanitizeText(branch.name_en),
				name_ar: sanitizeText(branch.name_ar),
				location_en: sanitizeText(branch.location_en),
				location_ar: sanitizeText(branch.location_ar)
			}));
			
			// Enrich offers with branch information
			state.offers = state.offers.map(offer => {
				const branch = state.branches.find(b => b.id === offer.branch_id);
				return {
					...offer,
					branch_name_en: sanitizeText(branch?.name_en || ''),
					branch_name_ar: sanitizeText(branch?.name_ar || ''),
					branch_location_en: sanitizeText(branch?.location_en || ''),
					branch_location_ar: sanitizeText(branch?.location_ar || '')
				};
			});

		} catch (error) {
			console.error('Error fetching offers:', error);
		} finally {
			state.dataLoaded = true;
			state.isLoading = false;
			// Increment page visit count for all offers once data is loaded
			await incrementAllOfferPageVisits();
		}
	}

	function getBranchName(branchId: number) {
		const branch = state.branches.find(b => b.id === branchId);
		if (!branch) return '';
		return $currentLocale === 'ar' ? branch.name_ar : branch.name_en;
	}

	function handleBranchChange(event: Event) {
		const target = event.target as HTMLSelectElement;
		const value = target.value;
		state.selectedBranchId = value;
	}

	function getFilteredOffers() {
		// If no branch selected, return all offers
		if (!state.selectedBranchId) {
			return state.offers;
		}
		// If branch selected, filter offers by that branch
		const branchId = parseInt(state.selectedBranchId);
		const filtered = state.offers.filter(offer => offer.branch_id === branchId);
		return filtered;
	}

	function isWhatsAppBrowser(): boolean {
		const userAgent = navigator.userAgent.toLowerCase();
		return /whatsapp/i.test(userAgent);
	}

	function openOfferFile(fileUrl: string, offerId: string) {
		if (fileUrl) {
			// Increment view button count
			incrementViewButtonCount(offerId);
			
			state.downloadingOfferId = offerId;
			state.downloadProgress = 0;

			// Detect WhatsApp browser and handle differently — fetch as blob then force download
			if (isWhatsAppBrowser()) {
				fetch(fileUrl)
					.then(response => {
						const contentLength = response.headers.get('content-length');
						const total = parseInt(contentLength || '0', 10);
						if (!response.body) throw new Error('No response body');
						const reader = response.body.getReader();
						const chunks: Uint8Array[] = [];
						let loaded = 0;
						return reader.read().then(function processChunk(result): Promise<Blob> {
							if (result.done) {
								return Promise.resolve(new Blob(chunks, { type: 'application/pdf' }));
							}
							chunks.push(result.value);
							loaded += result.value.length;
							if (total > 0) state.downloadProgress = Math.round((loaded / total) * 100);
							return reader.read().then(processChunk);
						});
					})
					.then(blob => {
						const blobUrl = URL.createObjectURL(blob);
						const a = document.createElement('a');
						a.href = blobUrl;
						a.download = `offer_${offerId}.pdf`;
						a.style.display = 'none';
						document.body.appendChild(a);
						a.click();
						document.body.removeChild(a);
						setTimeout(() => URL.revokeObjectURL(blobUrl), 10000);
					})
					.catch(() => {
						// Fallback: navigate directly (lets device handle open/download)
						window.location.href = fileUrl;
					})
					.finally(() => {
						state.downloadingOfferId = null;
						state.downloadProgress = 0;
					});
				return;
			}
			
			// For regular browsers, use blob caching approach
			// Check if file is already cached
			if (state.fileCache.has(offerId)) {
				// Open from cache instantly
				const cachedBlob = state.fileCache.get(offerId);
				const blobUrl = URL.createObjectURL(cachedBlob!);
				window.open(blobUrl, `offer_${offerId}`);
				state.downloadingOfferId = null;
				state.downloadProgress = 0;
				return;
			}
			
			// Fetch and cache the file with progress tracking
			fetch(fileUrl)
				.then(response => {
					// Get total file size
					const contentLength = response.headers.get('content-length');
					const total = parseInt(contentLength || '0', 10);
					
					if (!response.body) throw new Error('No response body');
					
					const reader = response.body.getReader();
					const chunks: Uint8Array[] = [];
					let loaded = 0;
					
					return reader.read().then(function processChunk(result): Promise<Blob> {
						if (result.done) {
							const blob = new Blob(chunks, { type: 'application/pdf' });
							return Promise.resolve(blob);
						}
						
						const chunk = result.value;
						chunks.push(chunk);
						loaded += chunk.length;
						
						// Update progress percentage
						if (total > 0) {
							state.downloadProgress = Math.round((loaded / total) * 100);
						}
						
						return reader.read().then(processChunk);
					});
				})
				.then(blob => {
					// Cache the blob
					state.fileCache.set(offerId, blob);
					
					// Open the cached file
					const blobUrl = URL.createObjectURL(blob);
					window.open(blobUrl, `offer_${offerId}`);
				})
				.catch(error => {
					console.error('Error loading file:', error);
					// Fallback: open directly
					window.open(fileUrl, `offer_${offerId}`);
				})
				.finally(() => {
					state.downloadingOfferId = null;
					state.downloadProgress = 0;
				});
		}
	}

	function formatDate(dateStr: string): string {
		const [year, month, day] = dateStr.split('-');
		return `${day}/${month}/${year}`;
	}

	function convertTo12Hour(time24: string): string {
		const [hours, minutes] = time24.split(':');
		const hour = parseInt(hours);
		const period = hour >= 12 ? 'PM' : 'AM';
		const hour12 = hour % 12 || 12;
		return `${hour12.toString().padStart(2, '0')}:${minutes} ${period}`;
	}

	function getRemainingDays(endDate: string, endTime: string): string {
		const now = new Date();
		const currentDate = now.toISOString().split('T')[0];
		const currentTime = now.toTimeString().split(' ')[0].substring(0, 5);

		const end = new Date(`${endDate}T${endTime}`);
		const current = new Date(`${currentDate}T${currentTime}`);
		const diffMs = end.getTime() - current.getTime();
		
		const isArabic = $currentLocale === 'ar';
		
		if (diffMs < 0) {
			return isArabic ? '⏰ منتهي' : '⏰ Expired';
		}
		
		const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
		const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
		const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

		if (isArabic) {
			if (diffDays === 0 && diffHours === 0) {
				return `⏰ ينتهي في ${diffMinutes} دقيقة`;
			}
			if (diffDays === 0) {
				const hourLabel = diffHours === 1 ? 'ساعة' : 'ساعات';
				const minLabel = diffMinutes === 1 ? 'دقيقة' : 'دقائق';
				return `⏰ ينتهي في ${diffHours} ${hourLabel} و${diffMinutes} ${minLabel}`;
			}
			const dayLabel = diffDays === 1 ? 'يوم' : 'أيام';
			const hourLabel = diffHours === 1 ? 'ساعة' : 'ساعات';
			return `⏰ ينتهي في ${diffDays} ${dayLabel} و${diffHours} ${hourLabel}`;
		} else {
			if (diffDays === 0 && diffHours === 0) {
				return `⏰ Expires in ${diffMinutes} minutes`;
			}
			if (diffDays === 0) {
				return `⏰ Expires in ${diffHours}h ${diffMinutes}m`;
			}
			return `⏰ Expires in ${diffDays}d ${diffHours}h`;
		}
	}

	function goBack() {
		const referrerQuery = $page.url.searchParams.get('referrer');
		if (referrerQuery === 'login') {
			goto('/login');
		} else {
			goto('/customer-interface');
		}
	}

	function toggleLanguage() {
		currentLocale.set($currentLocale === 'en' ? 'ar' : 'en');
	}

	async function incrementViewButtonCount(offerId: string) {
		try {
			const { error } = await supabase
				.rpc('increment_view_button_count', { offer_id: offerId });
			if (error) console.error('Error incrementing view button count:', error);
		} catch (error) {
			console.error('Error:', error);
		}
	}

	async function incrementPageVisitCount(offerId: string) {
		try {
			const { error } = await supabase
				.rpc('increment_page_visit_count', { offer_id: offerId });
			if (error) console.error('Error incrementing page visit count:', error);
		} catch (error) {
			console.error('Error:', error);
		}
	}

	async function incrementAllOfferPageVisits() {
		try {
			// Increment page visit count for all visible offers
			for (const offer of state.offers) {
				await incrementPageVisitCount(String(offer.id));
			}
		} catch (error) {
			console.error('Error incrementing page visits:', error);
		}
	}
</script>

<svelte:head>
<title>Latest Offers - Urban Market</title>
<meta name="description" content="View the latest offers from Urban Market" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0" />
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Tajawal:wght@400;500;700;800&display=swap" rel="stylesheet" />
</svelte:head>

<div class="page-wrapper" class:rtl={$currentLocale === 'ar'} dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
<header class="header">
<button class="back-btn" onclick={goBack} aria-label="Go Back">
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
{#if $currentLocale === 'ar'}
<path d="M5 12h14M12 5l7 7-7 7"/>
{:else}
<path d="M19 12H5M12 19l-7-7 7-7"/>
{/if}
</svg>
</button>

<button class="lang-toggle" onclick={toggleLanguage}>
<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
<circle cx="12" cy="12" r="10"/>
<line x1="2" y1="12" x2="22" y2="12"/>
<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
</svg>
<span>{$currentLocale === 'ar' ? 'English' : 'العربية'}</span>
</button>
</header>

<main class="main-content">
<div class="profile-section">
<div class="avatar-container">
<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Urban Market Logo" class="profile-avatar" />
</div>

<h1 class="brand-title">
{#if $currentLocale === 'ar'}
<span class="text-green">أ</span><span class="text-orange">ه</span><span class="text-green">ل</span>&nbsp;<span class="text-orange">ا</span><span class="text-green">ي</span><span class="text-orange">ر</span><span class="text-green">ب</span><span class="text-orange">ن</span>
{:else}
<span class="text-green">A</span><span class="text-orange">h</span><span class="text-green">l</span>&nbsp;<span class="text-orange">U</span><span class="text-green">r</span><span class="text-orange">b</span><span class="text-green">a</span><span class="text-orange">n</span>
{/if}
</h1>

<p class="brand-subtitle">
{$currentLocale === 'ar' ? 'أحدث العروض الحصرية لك' : 'Latest Exclusive Offers For You'}
</p>
</div>

{#if state.isLoading}
<div class="loader">
<div class="spinner"></div>
<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
</div>
{:else if state.dataLoaded}
<div class="links-container fade-in">
<div class="branch-label-container" style="text-align: center; margin-bottom: 0.5rem;">
<label for="branch-select" style="font-weight: 600; color: #374151;">{$currentLocale === 'ar' ? 'اختر الفرع:' : 'Select Branch:'}</label>
</div>
                
{#if state.branches.length > 0}
<div class="branch-selector">
<select id="branch-select" class="styled-select" bind:value={state.selectedBranchId} onchange={handleBranchChange}>
<option value="">{$currentLocale === 'ar' ? '-- كل الفروع --' : '-- All Branches --'}</option>
{#each state.branches as branch}
<option value={branch.id.toString()}>
{$currentLocale === 'ar' ? branch.name_ar + ' - ' + branch.location_ar : branch.name_en + ' - ' + branch.location_en}
</option>
{/each}
</select>
</div>
{/if}

<div class="offers-grid">
{#if getFilteredOffers().length === 0}
<div class="empty-state">
<p>{$currentLocale === 'ar' ? 'لا توجد عروض متاحة في الوقت الحالي' : 'No offers available at the moment'}</p>
</div>
{:else}
{#each getFilteredOffers() as offer (offer.id)}
<div class="offer-card-modern">
<div class="offer-info">
<h3 class="offer-title">{offer.offer_name}</h3>

<div class="offer-meta">
<p class="branch-name">
<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
<circle cx="12" cy="10" r="3"></circle>
</svg>
{$currentLocale === 'ar' ? offer.branch_name_ar + ' - ' + offer.branch_location_ar : offer.branch_name_en + ' - ' + offer.branch_location_en}
</p>
<span class="expiry-badge">
<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
<circle cx="12" cy="12" r="10"></circle>
<polyline points="12 6 12 12 16 14"></polyline>
</svg>
{getRemainingDays(offer.end_date, offer.end_time).replace('⏳ ', '')}
</span>
</div>
</div>

{#if offer.thumbnail_url}
<div class="thumbnail-wrapper">
<img src={offer.thumbnail_url} alt={offer.offer_name} class="offer-thumb-image" />
</div>
{/if}

{#if offer.file_url}
<button 
class="btn-view-offer"
onclick={() => openOfferFile(offer.file_url, offer.id)}
disabled={state.downloadingOfferId === offer.id}
>
{#if state.downloadingOfferId === offer.id}
<div class="spinner-small"></div>
<span>{state.downloadProgress}%</span>
{:else}
<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
<polyline points="14 2 14 8 20 8"></polyline>
<line x1="16" y1="13" x2="8" y2="13"></line>
<line x1="16" y1="17" x2="8" y2="17"></line>
<polyline points="10 9 9 9 8 9"></polyline>
</svg>
<span>{$currentLocale === 'ar' ? 'عرض المجلة' : 'View Magazine'}</span>
{/if}
</button>
{/if}
</div>
{/each}
{/if}
</div>
</div>
{/if}
</main>
</div>

<style>
:global(body) {
margin: 0;
padding: 0;
background-color: #E8F5E9;
}

* {
box-sizing: border-box;
font-family: 'Plus Jakarta Sans', 'Tajawal', sans-serif;
}

.text-green { color: #13A538; }
.text-orange { color: #F08300; }

.page-wrapper {
width: 100%;
min-height: 100vh;
background: #E8F5E9;
display: flex;
flex-direction: column;
align-items: center;
padding-bottom: 3rem;
}

.header {
width: 100%;
max-width: 600px;
display: flex;
justify-content: space-between;
align-items: center;
padding: 1.25rem 1.5rem;
z-index: 10;
}

.back-btn {
width: 44px;
height: 44px;
border-radius: 14px;
background: white;
border: 1px solid #e2e8f0;
display: flex;
align-items: center;
justify-content: center;
color: #0f172a;
cursor: pointer;
transition: all 0.2s;
box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
}

.back-btn:active, .back-btn:hover {
background: #f1f5f9;
transform: translateY(2px);
}

.lang-toggle {
display: flex;
align-items: center;
gap: 8px;
background: white;
border: 1px solid #e2e8f0;
padding: 10px 16px;
border-radius: 20px;
color: #0f172a;
font-weight: 600;
font-size: 0.9rem;
cursor: pointer;
box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
transition: all 0.2s;
}

.lang-toggle:active, .lang-toggle:hover {
background: #f1f5f9;
transform: translateY(2px);
}

.main-content {
width: 100%;
max-width: 600px;
padding: 0 1.5rem;
display: flex;
flex-direction: column;
align-items: center;
}

.profile-section {
display: flex;
flex-direction: column;
align-items: center;
margin-top: 1rem;
margin-bottom: 2.5rem;
text-align: center;
}

.avatar-container {
width: 110px;
height: 110px;
border-radius: 50%;
background: white;
padding: 6px;
box-shadow: 0 10px 25px -5px rgba(19, 165, 56, 0.2);
margin-bottom: 1.25rem;
position: relative;
}

.avatar-container::after {
content: '';
position: absolute;
inset: -4px;
border-radius: 50%;
background: linear-gradient(135deg, #13A538, #F08300);
z-index: -1;
}

.profile-avatar {
width: 100%;
height: 100%;
object-fit: contain;
border-radius: 50%;
background: white;
}

.brand-title {
font-weight: 800;
font-size: 2.2rem;
margin: 0 0 0.5rem 0;
letter-spacing: -0.5px;
}

.brand-subtitle {
color: #13A538;
font-size: 1.05rem;
font-weight: 600;
margin: 0;
}

.links-container {
width: 100%;
display: flex;
flex-direction: column;
gap: 1.5rem;
}

.fade-in {
animation: fadeIn 0.5s ease-out forwards;
}

@keyframes fadeIn {
from { opacity: 0; transform: translateY(10px); }
to { opacity: 1; transform: translateY(0); }
}

.branch-selector {
margin: 0 auto 16px;
width: 100%;
}

.styled-select {
width: 100%;
padding: 12px 16px;
border-radius: 12px;
border: 2px solid #13A538;
background-color: transparent;
font-size: 1rem;
font-weight: 600;
color: #13A538;
cursor: pointer;
outline: none;
transition: all 0.2s ease;
appearance: none;
text-align: center;
}

.styled-select:focus {
border-color: #F08300;
box-shadow: 0 0 0 3px rgba(240, 131, 0, 0.1);
}

.offers-grid {
display: flex;
flex-direction: column;
gap: 20px;
width: 100%;
}

.offer-card-modern {
background: rgba(255, 255, 255, 0.9);
backdrop-filter: blur(10px);
border: 1px solid rgba(19, 165, 56, 0.2);
border-radius: 20px;
padding: 24px;
display: flex;
flex-direction: column;
gap: 16px;
transition: all 0.3s ease;
box-shadow: 0 4px 15px rgba(0,0,0,0.03);
}

.offer-card-modern:hover {
transform: translateY(-4px);
box-shadow: 0 12px 30px rgba(19, 165, 56, 0.12);
border-color: #13A538;
}

.offer-info {
display: flex;
flex-direction: column;
gap: 8px;
}

.offer-title {
margin: 0;
font-size: 1.25rem;
font-weight: 800;
color: #0f172a;
line-height: 1.3;
}

.offer-meta {
display: flex;
flex-direction: column;
gap: 6px;
}

.branch-name {
margin: 0;
font-size: 0.9rem;
color: #64748b;
display: flex;
align-items: center;
gap: 6px;
}

.expiry-badge {
display: inline-flex;
align-items: center;
gap: 6px;
background: rgba(240, 131, 0, 0.1);
color: #d97706;
padding: 4px 10px;
border-radius: 20px;
font-size: 0.8rem;
font-weight: 700;
width: fit-content;
}

.thumbnail-wrapper {
width: 100%;
border-radius: 12px;
overflow: hidden;
background: #f1f5f9;
}

.offer-thumb-image {
width: 100%;
height: auto;
display: block;
object-fit: cover;
max-height: 250px;
}

.btn-view-offer {
display: flex;
align-items: center;
justify-content: center;
gap: 10px;
background: linear-gradient(135deg, #13A538, #0ea5e9);
color: white;
border: none;
padding: 14px 24px;
border-radius: 14px;
font-size: 1rem;
font-weight: 700;
cursor: pointer;
transition: all 0.3s;
box-shadow: 0 4px 12px rgba(19, 165, 56, 0.2);
}

.btn-view-offer:hover:not(:disabled) {
transform: translateY(-2px);
box-shadow: 0 6px 18px rgba(19, 165, 56, 0.3);
}

.btn-view-offer:active:not(:disabled) {
transform: translateY(0);
}

.btn-view-offer:disabled {
opacity: 0.7;
cursor: not-allowed;
}

.spinner-small {
width: 20px;
height: 20px;
border: 3px solid rgba(255,255,255,0.3);
border-top-color: white;
border-radius: 50%;
animation: spin 1s linear infinite;
}

.loader {
display: flex;
flex-direction: column;
align-items: center;
margin-top: 3rem;
}

.spinner {
width: 40px;
height: 40px;
border: 4px solid rgba(19, 165, 56, 0.2);
border-top-color: #13A538;
border-radius: 50%;
animation: spin 1s linear infinite;
margin-bottom: 1rem;
}

@keyframes spin {
to { transform: rotate(360deg); }
}

.empty-state {
text-align: center;
padding: 3rem 1rem;
color: #64748b;
font-weight: 500;
background: rgba(255, 255, 255, 0.7);
border-radius: 16px;
border: 1px dashed rgba(0,0,0,0.05);
}
</style>
