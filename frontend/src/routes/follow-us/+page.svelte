<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { isAuthenticated } from '$lib/utils/persistentAuth';
	import { iconUrlMap } from '$lib/stores/iconStore';

	interface SocialLink {
		branch_id: number;
		facebook: string | null;
		instagram: string | null;
		twitter: string | null;
		tiktok: string | null;
		youtube: string | null;
		website: string | null;
		whatsapp: string | null;
		snapchat: string | null;
		location_link: string | null;
	}

	interface Branch {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		location_ar: string;
	}

	let socialLinksData: SocialLink[] = [];
	let branchesData: Branch[] = [];
	let selectedBranch: string = '';
	let socialLinks: SocialLink | null = null;
	let isLoading = true;
	let dataLoaded = false;

	const platformLabels = {
		facebook: { en: 'Facebook', ar: 'فيسبوك' },
		whatsapp: { en: 'WhatsApp', ar: 'واتس أب' },
		instagram: { en: 'Instagram', ar: 'انستغرام' },
		tiktok: { en: 'TikTok', ar: 'تيك توك' },
		snapchat: { en: 'Snapchat', ar: 'سناب شات' },
		website: { en: 'Website', ar: 'الموقع الإلكتروني' },
		location_link: { en: 'Location', ar: 'الموقع' }
	};

	$: platforms = [
		{ key: 'snapchat', icon: $iconUrlMap['snapchat-logo'] || '/icons/snapchat logo.png' },
		{ key: 'tiktok', icon: $iconUrlMap['tiktok-logo'] || '/icons/tiktok logo.jpg' },
		{ key: 'location_link', icon: $iconUrlMap['map-icon'] || '/icons/map icon.png' },
		{ key: 'whatsapp', icon: $iconUrlMap['whatsapp-logo'] || '/icons/whatsapp logo.png', scale: 0.5 },
		{ key: 'instagram', icon: $iconUrlMap['instagram-logo'] || '/icons/instagram logo.png', scale: 2.2 },
		{ key: 'facebook', icon: $iconUrlMap['facebook-logo'] || '/icons/facebook logo.jpg' },
		{ key: 'website', icon: $iconUrlMap['logo'] || '/icons/logo.png' }
	];

	function getPlatformLabel(key: string): string {
		const isArabic = $currentLocale === 'ar';
		return platformLabels[key]?.[isArabic ? 'ar' : 'en'] || key;
	}

	async function loadData() {
		try {
			// Load branches
			const { data: branchesResult, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en');
			
			if (branchesError) throw branchesError;
			branchesData = branchesResult || [];

			// Load social links
			const { data: socialLinksResult, error: socialLinksError } = await supabase
				.from('social_links')
				.select('*')
				.order('branch_id');
			
			if (socialLinksError) throw socialLinksError;
			
			socialLinksData = socialLinksResult || [];
			
			if (socialLinksData.length > 0) {
				selectedBranch = socialLinksData[0].branch_id.toString();
				loadSocialLinksForBranch(parseInt(selectedBranch));
			}
		} catch (error) {
			console.error('Error loading data:', error);
		} finally {
			isLoading = false;
			dataLoaded = true;
		}
	}

	function getBranchName(branchId: number): string {
		const branch = branchesData.find(b => b.id === branchId);
		if (!branch) return `Branch #${branchId}`;
		const isArabic = $currentLocale === 'ar';
		const name = isArabic ? branch.name_ar : branch.name_en;
		const location = isArabic ? branch.location_ar : branch.location_en;
		return `${name} - ${location}`;
	}

	function loadSocialLinksForBranch(branchId: number) {
		const data = socialLinksData.find(s => s.branch_id === branchId);
		socialLinks = data || null;
	}

	function handleBranchChange(event: Event) {
		const target = event.target as HTMLSelectElement;
		const value = target.value;
		if (value) {
			selectedBranch = value;
			loadSocialLinksForBranch(parseInt(value));
		}
	}

	function openLink(url: string, platform: string) {
		if (!url) return;
		const fullUrl = url.startsWith('http') ? url : `https://${url}`;
		
		// Track click
		recordLinkClick(selectedBranch, platform);
		
		// Open link
		window.open(fullUrl, '_blank');
	}

	async function recordLinkClick(branchId: string, platform: string) {
		if (!branchId) return;
		
		try {
			await supabase.rpc('increment_social_link_click', {
				_branch_id: parseInt(branchId),
				_platform: platform
			});
		} catch (error) {
			console.error(`Error recording ${platform} click:`, error);
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

	onMount(async () => {
		await loadData();
	});
</script>

<svelte:head>
	<title>Follow Us - Aqura</title>
	<meta name="description" content="Follow Aqura on social media" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<div class="follow-us-page">
	<header class="follow-us-header" class:rtl={$currentLocale === 'ar'} dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
		<div class="top-bar">
			<span class="top-bar-text">{$currentLocale === 'ar' ? 'مرحباً بكم في ايربن ماركت' : 'Welcome To Urban market'}</span>
			<button class="lang-btn" onclick={toggleLanguage} disabled={isLoading}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<circle cx="12" cy="12" r="10"/>
					<line x1="2" y1="12" x2="22" y2="12"/>
					<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
				</svg>
				{$currentLocale === 'ar' ? 'English' : 'العربية'}
			</button>
		</div>
	</header>

	<main class="follow-us-content" class:rtl={$currentLocale === 'ar'} dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
				<p class="thank-you-message">{$currentLocale === 'ar' ? 'شكراً على صبرك' : 'Thank you for patience'}</p>
			</div>
		{:else if dataLoaded}
			<!-- Ahl Urban Header Style -->
			<section class="member-login-section">
				<div class="member-login-card fade-in">
					<div class="member-login-text" style="text-align: center;">
						<h2 class="alternating-text" style="font-size: 2.2rem; margin-bottom: 8px;">
							{#if $currentLocale === 'ar'}
								<span style="color: #13A538">أ</span><span style="color: #f08300">ه</span><span style="color: #13A538">ل</span>&nbsp;<span style="color: #f08300">ا</span><span style="color: #13A538">ي</span><span style="color: #f08300">ر</span><span style="color: #13A538">ب</span><span style="color: #f08300">ن</span>
							{:else}
								<span style="color: #13A538">A</span><span style="color: #f08300">h</span><span style="color: #13A538">l</span>&nbsp;<span style="color: #f08300">U</span><span style="color: #13A538">r</span><span style="color: #f08300">b</span><span style="color: #13A538">a</span><span style="color: #f08300">n</span>
							{/if}
						</h2>
						<p style="color: #13A538; font-weight: 500; margin-bottom: 1.5rem;">
							{#if $currentLocale === 'ar'}
								دعنا نبقى على تواصل! تابعنا على المنصات التالية
							{:else}
								Let's stay connected! Follow us on the following platforms
							{/if}
						</p>
					</div>

					<div class="branch-label-container" style="text-align: center; margin-bottom: 0.5rem;">
						<label for="branch-select" style="font-weight: 600; color: #374151;">{$currentLocale === 'ar' ? 'اختر الفرع:' : 'Select Branch:'}</label>
					</div>

			{#if socialLinksData.length > 0}
				<div class="branch-selector" class:rtl={$currentLocale === 'ar'}>
					<select id="branch-select" value={selectedBranch} onchange={handleBranchChange} class="styled-select">
						<option value="">{$currentLocale === 'ar' ? '-- اختر الفرع --' : '-- Choose Branch --'}</option>
						{#each socialLinksData as data (data.branch_id)}
							<option value={data.branch_id.toString()}>
								{getBranchName(data.branch_id)}
							</option>
						{/each}
					</select>
				</div>

				<div class="social-grid">
					{#if socialLinks}
						{#each platforms as platform}
							{@const url = socialLinks[platform.key]}
							{#if url}
								<button 
									class="social-card-modern"
									onclick={() => openLink(url, platform.key)}
									title={getPlatformLabel(platform.key)}
								>
									<div class="social-icon">
										<img 
											src={platform.icon} 
											alt={getPlatformLabel(platform.key)} 
											class="icon-image"
											style={platform.scale ? `transform: scale(${platform.scale})` : ''}
										/>
									</div>
									<span class="social-label">{getPlatformLabel(platform.key)}</span>
								</button>
							{/if}
						{/each}
					{:else}
						<div class="no-links">
							<p>{$currentLocale === 'ar' ? 'لا توجد روابط اجتماعية' : 'No social links available'}</p>
						</div>
					{/if}
				</div>
				<div class="back-action-container" style="margin-top: 2rem; display: flex; justify-content: center;">
					<button class="btn-member-login-lg" onclick={goBack} style="max-width: 300px; width: 100%; justify-content: center;">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M19 12H5M12 19l-7-7 7-7"/>
						</svg>
						{$currentLocale === 'ar' ? 'العودة' : 'Go Back'}
					</button>
				</div>
			{:else}
				<div class="no-branches" style="text-align: center; padding: 2rem;">
					<p style="color: #64748B;">{$currentLocale === 'ar' ? 'لا توجد فروع متاحة' : 'No branches available'}</p>
					
					<div class="back-action-container" style="margin-top: 2rem; display: flex; justify-content: center;">
						<button class="btn-member-login-lg" onclick={goBack} style="max-width: 300px; width: 100%; justify-content: center;">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M19 12H5M12 19l-7-7 7-7"/>
							</svg>
							{$currentLocale === 'ar' ? 'العودة' : 'Go Back'}
						</button>
					</div>
				</div>
			{/if}
				</div> <!-- end member-login-card -->
			</section> <!-- end member-login-section -->
		{/if}
	</main>
</div>

<style>
	/* Use the same main styles as the home page for coherence */
	.follow-us-page {
		width: 100%;
		min-height: 100vh;
		background: #E8F5E9; /* match login page background tint */
		display: flex;
		flex-direction: column;
	}

	.follow-us-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0;
		background: #13A538;
		color: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 20;
	}
	
	.top-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		padding: 12px 24px;
	}

	.top-bar-text {
		color: white;
		font-weight: 500;
		font-size: 0.95rem;
	}

	.lang-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		background: rgba(255,255,255,0.2);
		border: 1px solid rgba(255,255,255,0.3);
		color: white;
		padding: 6px 12px;
		border-radius: 20px;
		font-size: 0.85rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.lang-btn:hover {
		background: rgba(255,255,255,0.3);
	}

	.follow-us-content {
		flex: 1;
		padding: 1.5rem;
		padding-top: 5rem; /* space for sticky header */
		overflow-y: auto;
		max-width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.member-login-section {
		display: flex;
		justify-content: center;
		width: 100%;
		padding: 24px;
		max-width: 800px;
	}

	.member-login-card {
		background: transparent;
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border-radius: 24px;
		border: none;
		padding: 20px 0;
		box-shadow: none;
		position: relative;
		overflow: hidden;
		width: 100%;
		opacity: 0;
		animation: fadeIn 0.4s ease forwards;
	}

	.member-login-text {
		padding-bottom: 1.5rem;
		margin-bottom: 2rem;
		border-bottom: 1px solid rgba(0, 0, 0, 0.08);
	}

	.branch-selector {
		margin: 0 auto 24px;
		width: 100%;
		max-width: 100%;
	}
	
	.styled-select {
		width: 100%;
		padding: 12px 16px;
		border-radius: 12px;
		border: 2px solid #E2E8F0;
		background-color: #F8FAFC;
		font-size: 1rem;
		font-weight: 500;
		color: #1E293B;
		cursor: pointer;
		outline: none;
		transition: all 0.2s ease;
		appearance: none; /* helps unified styles across browsers */
	}
	
	.styled-select:focus {
		border-color: #13A538;
		background-color: #fff;
		box-shadow: 0 0 0 3px rgba(19, 165, 56, 0.1);
	}

	.social-grid {
		display: flex; flex-direction: column;
		
		gap: 16px;
		width: 100%;
		max-width: 600px;
		margin: 0 auto;
	}
	
	.social-card-modern {
		display: flex;
		flex-direction: row; justify-content: flex-start;
		align-items: center;
		
		gap: 12px;
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 16px;
		padding: 20px 16px;
		cursor: pointer;
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		text-align: center;
		box-shadow: 0 4px 12px rgba(0,0,0,0.08);
	}
	
	.social-card-modern .social-label {
		color: #f8fafc;
	}

	.social-card-modern .icon-image {
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.2);
	}
	
	.social-card-modern:hover {
		transform: translateY(-4px);
		box-shadow: 0 8px 16px rgba(19, 165, 56, 0.2);
		border-color: #13A538;
		background: #0f172a;
	}

	.btn-member-login-lg {
		display: inline-flex;
		align-items: center;
		gap: 12px;
		background: linear-gradient(135deg, #13A538, #108C30);
		color: white;
		border: none;
		padding: 16px 36px;
		border-radius: 14px;
		font-size: 18px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s;
		box-shadow: 0 6px 20px rgba(19,165,56,0.3);
		text-decoration: none;
	}
	.btn-member-login-lg:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(19,165,56,0.4);
	}

	/* Keep original loading classes below */

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 100vh;
		gap: 1.5rem;
		padding: 2rem;
	}

	.loading p {
		margin: 0;
		font-size: 1rem;
		color: #6B7280;
		font-weight: 600;
		gap: 1rem;
	}

	.thank-you-message {
		font-size: 1rem;
		color: #374151;
		font-weight: 600;
		margin-top: 1rem;
		animation: fadeIn 1s ease-in 0.5s both;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgba(249, 115, 22, 0.1);
		border-top-color: #F97316;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.logo-wrapper {
		display: flex;
		justify-content: center;
		margin-bottom: 2rem;
		margin-top: 90px;
		padding: 1.5rem 0;
		background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(249, 115, 22, 0.05) 100%);
		border-radius: 16px;
		border: 2px solid rgba(16, 185, 129, 0.15);
		animation: fadeInUp 0.8s ease-out;
		position: relative;
		overflow: hidden;
	}

	.logo-wrapper::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 2px;
		background: linear-gradient(90deg, transparent, #10B981, #F97316, transparent);
		animation: shimmer 3s ease-in-out infinite;
	}

	@keyframes fadeInUp {
		from {
			opacity: 0;
			transform: translateY(-30px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@keyframes shimmer {
		0%, 100% {
			opacity: 0.5;
		}
		50% {
			opacity: 1;
		}
	}

	.logo-container {
		display: flex;
		justify-content: center;
		align-items: center;
	}

	.app-logo {
		height: 80px;
		width: auto;
		filter: drop-shadow(0 4px 6px rgba(16, 185, 129, 0.2));
	}

	.branch-label-container {
		padding: 0 1.5rem;
		margin-bottom: 1rem;
		text-align: left;
	}

	.branch-label-container label {
		font-weight: 600;
		color: #374151;
		font-size: 14px;
		margin: 0;
		padding: 0;
		display: block;
	}

	:global([dir="rtl"]) .branch-label-container {
		text-align: right;
	}

	.branch-selector {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #F0FDF4 0%, #ECFDF5 100%);
		border: 2px solid #10B981;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.1);
	}

	.branch-selector.rtl {
		flex-direction: row-reverse;
		text-align: right;
	}

	@media (max-width: 480px) {
		.branch-selector {
			flex-direction: column;
			align-items: flex-start;
			gap: 0.75rem;
		}

		.branch-selector.rtl {
			flex-direction: column;
			align-items: flex-end;
		}
	}

	.branch-selector label {
		font-weight: 600;
		color: #111827;
		white-space: nowrap;
	}

	.branch-selector select {
		flex: 1;
		padding: 0.75rem 1rem;
		border: 2px solid #10B981;
		border-radius: 8px;
		font-size: 1rem;
		cursor: pointer !important;
		transition: all 0.3s ease;
		background: white;
		color: #111827;
		font-weight: 500;
		appearance: none;
		-webkit-appearance: none;
		-moz-appearance: none;
		position: relative;
		z-index: 10;
		pointer-events: auto;
		background-image: url('data:image/svg+xml;utf8,<svg fill="black" height="24" viewBox="0 0 20 20" width="24" xmlns="http://www.w3.org/2000/svg"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/></svg>');
		background-repeat: no-repeat;
		background-position: right 0.5rem center;
		background-size: 1.5em 1.5em;
		padding-right: 2.5rem;
	}

	.branch-selector select:hover {
		border-color: #059669;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.15);
	}

	.branch-selector select:focus {
		outline: none;
		border-color: #F97316;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.15);
	}

	.branch-selector.rtl select {
		background-position: left 0.5rem center;
		padding-left: 2.5rem;
		padding-right: 1rem;
	}

	@media (max-width: 480px) {
		.branch-selector select {
			width: 100%;
		}
	}

	.social-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1.5rem;
		position: relative;
		z-index: 1;
	}

	@media (max-width: 768px) {
		.social-grid {
			grid-template-columns: 1fr;
			gap: 1rem;
		}
	}

	@media (max-width: 480px) {
		.social-grid {
			grid-template-columns: 1fr;
			gap: 0.75rem;
		}
	}

	.social-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1.5rem;
		background: linear-gradient(135deg, #FFFFFF 0%, #F0FDF4 100%);
		border: 2px solid #10B981;
		border-radius: 16px;
		color: inherit;
		text-decoration: none;
		cursor: pointer;
		transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
		box-shadow: 0 8px 16px rgba(16, 185, 129, 0.15), 0 2px 4px rgba(0, 0, 0, 0.05);
		position: relative;
		z-index: 1;
		animation: slideUp 0.6s ease-out;
		gap: 1rem;
		font-family: inherit;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.social-card::before {
		content: '';
		position: absolute;
		top: -2px;
		left: 50%;
		transform: translateX(-50%);
		width: 60px;
		height: 20px;
		background: linear-gradient(135deg, #F97316 0%, #FB923C 100%);
		border-radius: 0 0 10px 10px;
		z-index: 10;
		box-shadow: 0 4px 6px rgba(249, 115, 22, 0.2);
	}

	.social-card:hover {
		border-color: #F97316;
		box-shadow: 0 16px 32px rgba(249, 115, 22, 0.25), 0 4px 8px rgba(0, 0, 0, 0.1);
		transform: translateY(-8px);
	}

	.social-card:hover::before {
		animation: ribbon 0.8s ease-in-out infinite;
	}

	@keyframes ribbon {
		0%, 100% {
			transform: translateX(-50%) scaleY(1);
		}
		50% {
			transform: translateX(-50%) scaleY(1.1);
		}
	}

	.social-card:active {
		transform: translateY(-4px);
	}

	.social-icon {
		font-size: 3rem;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100px;
		height: 100px;
		border-radius: 50%;
		overflow: hidden;
	}

	.icon-image {
		max-width: 100%;
		max-height: 100%;
		width: 80px;
		height: 80px;
		object-fit: contain;
		border-radius: 50%;
		padding: 8px;
		background: white;
		filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
	}

	.social-label {
		font-size: 1.1rem;
		font-weight: 700;
		color: #111827;
		text-align: center;
		letter-spacing: 0.3px;
	}

	@media (max-width: 480px) {
		.social-card {
			padding: 1.5rem 1rem;
			gap: 0.75rem;
		}

		.social-icon {
			font-size: 2.5rem;
		}

		.social-label {
			font-size: 1rem;
		}
	}

	.no-links,
	.no-branches {
		text-align: center;
		color: #6B7280;
		padding: 2rem;
		grid-column: 1 / -1;
	}

	/* RTL Support */
	:global([dir="rtl"]) .follow-us-header {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"]) .branch-selector {
		flex-direction: row-reverse;
	}
</style>
