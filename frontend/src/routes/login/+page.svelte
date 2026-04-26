<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { switchLocale, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let mounted = false;
	let showContent = false;
	let showMask = true;
	let maskPollInterval: any = null;
	let branches: any[] = [];
	let isWhatsAppBrowser = false;
	let giftWheelActive = false;

	// Secret dev unmask: click 15 times to dismiss
	let maskClicks = 0;
	let maskTimer: any = null;
	function handleMaskClick() {
		maskClicks++;
		clearTimeout(maskTimer);
		maskTimer = setTimeout(() => { maskClicks = 0; }, 3000);
		if (maskClicks >= 15) {
			showMask = false;
			maskClicks = 0;
		}
	}

	$: isRTL = $currentLocale === 'ar';

	// Keep document direction LTR so browser scrollbar stays on the right
	$: if (typeof document !== 'undefined') {
		document.documentElement.dir = 'ltr';
	}

	function openInExternalBrowser() {
		const url = window.location.href;
		// Android: intent scheme to open in default browser
		const ua = navigator.userAgent || '';
		if (/android/i.test(ua)) {
			window.location.href = 'intent://' + url.replace(/^https?:\/\//, '') + '#Intent;scheme=https;end;';
		} else {
			// iOS and others: window.open triggers Safari
			window.open(url, '_system');
		}
	}

	onMount(async () => {
		mounted = true;
		setTimeout(() => { showContent = true; }, 200);

		// Detect WhatsApp in-app browser
		const ua = navigator.userAgent || '';
		if (/WhatsApp/i.test(ua)) {
			isWhatsAppBrowser = true;
		}

		// Force document direction to LTR so scrollbar stays on right
		document.documentElement.dir = 'ltr';

		// Load mask setting
		try {
			const { data } = await supabase
				.from('delivery_service_settings')
				.select('customer_login_mask_enabled')
				.single();
			if (data) showMask = data.customer_login_mask_enabled;
		} catch {}

		// Check gift wheel status
		try {
			const { data: gwData } = await supabase.rpc('gift_wheel_check_status');
			giftWheelActive = !!(gwData?.active);
		} catch {}

		// Load branches
		try {
			const { data } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar, is_24_hours, operating_start_time, operating_end_time, location_url')
				.eq('is_active', true)
				.order('is_main_branch', { ascending: false });
			if (data) branches = data;
		} catch {}

		maskPollInterval = setInterval(async () => {
			try {
				const { data } = await supabase
					.from('delivery_service_settings')
					.select('customer_login_mask_enabled')
					.single();
				if (data) showMask = data.customer_login_mask_enabled;
			} catch {}
		}, 3000);
	});

	onDestroy(() => {
		if (maskPollInterval) clearInterval(maskPollInterval);
		// Restore document direction based on actual locale when leaving
		if (typeof document !== 'undefined') {
			document.documentElement.dir = $currentLocale === 'ar' ? 'rtl' : 'ltr';
		}
	});

	function toggleLocale() {
		switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
	}

	function goCustomer() {
		goto('/login/customer?minimal=true');
	}

	function scrollToLocations() {
		const el = document.getElementById('locations-section');
		if (el) el.scrollIntoView({ behavior: 'smooth' });
	}

	function goTeam() {
		const isMobile = window.innerWidth <= 768;
		if (isMobile) {
			goto('/mobile-interface/login');
		} else {
			goto('/login/employee?mode=desktop');
		}
	}
</script>

<svelte:head>
	<title>{isRTL ? 'تسجيل الدخول - أربن ماركت' : 'Login - Urban Market'}</title>
	<meta name="description" content="Access Urban Market Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
	<!-- Premium Fonts -->
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=Tajawal:wght@300;400;500;700;800&display=swap" rel="stylesheet" />
</svelte:head>

<div class="login-page" class:mounted dir="ltr">
	{#if isWhatsAppBrowser}
	<div class="wa-browser-banner" dir={isRTL ? 'rtl' : 'ltr'}>
		<span>{isRTL ? '🌐 للحصول على أفضل تجربة، افتح في المتصفح' : '🌐 For the best experience, open in your browser'}</span>
		<button on:click={openInExternalBrowser}>{isRTL ? 'فتح في المتصفح' : 'Open in Browser'}</button>
	</div>
	{/if}
	<!-- Sticky Header (direct child of scroll container so sticky works) -->
	<header class="sticky-header" class:rtl={isRTL} dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Top Bar -->
	<div class="top-bar">
		<span class="top-bar-text">{isRTL ? 'مرحباً بكم في ايربن ماركت' : 'Welcome To Urban market'}</span>
		<button class="lang-btn" on:click={toggleLocale}>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<circle cx="12" cy="12" r="10"/>
				<line x1="2" y1="12" x2="22" y2="12"/>
				<path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
			</svg>
			{$currentLocale === 'ar' ? 'English' : 'العربية'}
		</button>
	</div>

	</header><!-- .sticky-header -->

	<!-- Inner wrapper handles RTL text direction -->
	<div class="login-page-inner" class:rtl={isRTL} dir={isRTL ? 'rtl' : 'ltr'}>

	{#if showContent}
	<!-- Hero Section -->
	<section class="hero">
		<div class="hero-content">
			<div class="hero-text" class:fade-in={showContent}>
				<h1>
					{#if isRTL}
						<span class="hero-dark">احتياجاتك اليومية</span><br/>
						<span class="hero-highlight">كلها في مكان واحد</span>
					{:else}
						<span class="hero-dark">Your Everyday</span><br/>
						<span class="hero-dark">Essentials,</span><br/>
						<span class="hero-highlight">All In One Place</span>
					{/if}
				</h1>
				<p class="hero-sub">
					{isRTL 
						? 'اكتشف المنتجات عالية الجودة والطازجه كل يوم كذالك العروض التي لاتقاوم في سوبر ماركت الحي الخاص بك قم بزيارتنا اليوم لكل مايحتاجه منزلك'
						: 'Discover Fresh Produce, Quality Groceries, And Unbeatable Deals At Your Urban Supermarket. Visit Us Today For Everything Your Home Needs.'}
				</p>

				<!-- Action Buttons -->
				<div class="hero-buttons">
					<a class="btn-primary" href="/follow-us?referrer=login">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
							<circle cx="9" cy="7" r="4"/>
							<line x1="19" y1="8" x2="19" y2="14"/>
							<line x1="22" y1="11" x2="16" y2="11"/>
						</svg>
						{isRTL ? 'تابعنا' : 'Follow Us'}
					</a>
					<a class="btn-outline" href="/offers?referrer=login">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/>
							<line x1="7" y1="7" x2="7.01" y2="7"/>
						</svg>
						{isRTL ? 'العروض' : 'Offers'}
					</a>
					<a class="btn-points" href="/login/customer?view=loyalty">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
						</svg>
						{isRTL ? 'النقاط' : 'Points'}
					</a>
					<a class="btn-customer" href="/login/customer?minimal=true">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm-8 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4z"/>
						</svg>
						{isRTL ? 'اطلب الآن' : 'Order Now'}
					</a>
					<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
					<button class="btn-locate" on:click={scrollToLocations}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
							<circle cx="12" cy="10" r="3"/>
						</svg>
						{isRTL ? 'مواقعنا' : 'Locate Us'}
					</button>
					{#if giftWheelActive}
					<a class="btn-gift-wheel" href="/gift-wheel">
						🎡
						{isRTL ? 'عجلة الهدايا' : 'Gift Wheel'}
					</a>
					{/if}
				</div>

				<!-- Coming Soon Mask (over customer login) -->
				{#if showMask}
					<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
					<div class="mask-notice" on:click={handleMaskClick}>
						<div class="mask-badge">
							<span class="mask-icon">🚀</span>
							<span class="mask-text">{isRTL ? 'قريباً - تسجيل دخول العملاء' : 'Coming Soon â€” Customer Login'}</span>
						</div>
					</div>
				{/if}
			</div>

			<div class="hero-image" class:fade-in={showContent}>
				<img src="/icons/logo.png" alt="Urban Market" class="hero-logo-img" />
				<div class="hero-decorative">
					<div class="deco-circle deco-1"></div>
					<div class="deco-circle deco-2"></div>
					<div class="deco-circle deco-3"></div>
				</div>
			</div>
		</div>
	</section>

	<!-- Features Section -->
	<section class="features">
		<h2 class="features-title">
			{#if isRTL}
				<span class="text-dark">لماذا</span> <span class="text-orange">تتسوق معنا؟</span>
			{:else}
				<span class="text-dark">Why</span> <span class="text-orange">Shop With Us?</span>
			{/if}
		</h2>
		<div class="features-grid">
			<div class="feature-card">
				<div class="feature-icon">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#13A538" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
						<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
						<path d="M9 12l2 2 4-4"/>
					</svg>
				</div>
				<h3>{isRTL ? 'تشكيلة واسعة من المنتجات' : 'Wide Product Selection'}</h3>
				<p>{isRTL 
					? 'من المستلزمات اليومية إلى السلع المتخصصة، ستجد كل ما تحتاجه تحت سقف واحد - منتجات متنوعه، وطازجة، ألبان، وجبات خفيفه والمزيد'
					: 'From daily essentials to specialty goods, find everything you need under one roof â€” diverse products, fresh items, dairy, snacks and more.'}</p>
			</div>

			<div class="feature-card">
				<div class="feature-icon">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#13A538" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
						<path d="M3 21h18"/>
						<path d="M5 21V7l7-4 7 4v14"/>
						<path d="M9 21v-4h6v4"/>
						<rect x="9" y="9" width="2" height="2"/>
						<rect x="13" y="9" width="2" height="2"/>
						<path d="M1 21h22"/>
						<path d="M8 3l4-1 4 1"/>
						<path d="M12 7v-5"/>
					</svg>
				</div>
				<h3>{isRTL ? 'متجر نظيف، آمن ومنظم جيدًا' : 'Clean, Safe & Well-Organized Store'}</h3>
				<p>{isRTL 
					? 'نحافظ على أعلى مستويات النظافة ونضمن تنظيمًا خاليًا من الفوضى لتجربة تسوق سلسة ومريحة.'
					: 'We maintain the highest cleanliness standards and ensure a clutter-free layout for a smooth and comfortable shopping experience.'}</p>
			</div>

			<div class="feature-card">
				<div class="feature-icon">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#13A538" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
						<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
						<circle cx="9" cy="7" r="4"/>
						<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
						<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
					</svg>
				</div>
				<h3>{isRTL ? 'موظفون ودودون وخدمة دفع سريعة' : 'Friendly Staff & Fast Checkout'}</h3>
				<p>{isRTL 
					? 'فريقنا متواجد لمساعدتك بابتسامة، ومنافذ الدفع السريعة لدينا تضمن وقت انتظار قصير، حتى خلال فترات الازدحام.'
					: 'Our team is here to help you with a smile, and our fast checkout counters ensure minimal wait time, even during peak hours.'}</p>
			</div>
		</div>
	</section>

	<!-- Weekly Offers Banner -->
	<section class="offers-banner">
		<div class="offers-content">
			<div class="offers-icon">
				<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
					<polyline points="20 12 20 22 4 22 4 12"/>
					<rect x="2" y="7" width="20" height="5"/>
					<line x1="12" y1="22" x2="12" y2="7"/>
					<path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"/>
					<path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"/>
				</svg>
			</div>
			<h2>
				{#if isRTL}
					<span class="text-dark">أفضل</span> <span class="text-orange">العروض الأسبوعية</span> <span class="text-dark">في الفروع</span>
				{:else}
					<span class="text-dark">Best</span> <span class="text-orange">Weekly Offers</span> <span class="text-dark">In Our Branches</span>
				{/if}
			</h2>
			<p>
				{isRTL 
					? 'زورونا في فروعنا لاستكشاف العروض المميزة والمنتجات الطازجة بأفضل الأسعار'
					: 'Follow us for the latest promotions, fresh products and be the first to know about exclusive discounts'}
			</p>
		</div>
	</section>

	<!-- Locations Section -->
	<section class="locations" id="locations-section">
		<h2 class="section-title">
			{#if isRTL}
				<span class="text-dark">اعثر علينا</span> <span class="text-green">اليوم</span>
			{:else}
				<span class="text-dark">Find Us</span> <span class="text-green">Today</span>
			{/if}
		</h2>
		<p class="section-sub">
			{isRTL 
				? 'قم بزيارة فروعنا للحصول على تجربة تسوق متميزة'
				: 'Visit our conveniently located branches for a premium shopping experience'}
		</p>
		<div class="branch-cards">
			{#each branches.filter(b => b.location_url) as branch (branch.id)}
				<div class="branch-card">
					<div class="branch-avatar">
						<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="" />
					</div>
					<div class="branch-info">
						<h3>{isRTL ? branch.name_ar : branch.name_en}</h3>
						<p>{isRTL ? branch.location_ar : branch.location_en}</p>
						<span class="branch-hours">🕐 {isRTL ? '24 ساعة' : '24 Hours'}</span>
						{#if branch.location_url}
							<a class="branch-location-btn" href={branch.location_url} target="_blank" rel="noopener noreferrer">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
									<circle cx="12" cy="10" r="3"/>
								</svg>
								{isRTL ? 'الموقع' : 'Location'}
							</a>
						{/if}
					</div>
				</div>
			{:else}
				<p style="color: #94a3b8;">{isRTL ? 'جاري تحميل الفروع...' : 'Loading branches...'}</p>
			{/each}
		</div>
	</section>

	<!-- Footer -->
	<footer class="footer">
		<div class="footer-content">
			<div class="footer-logo">
				<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Urban Market" />
				<p>
					{isRTL 
						? 'نحن سوبر ماركت رائد في المملكة العربية السعودية ، نقدم أجود المنتجات المحلية والمستوردة ، إضافة إلى أفضل العلامات التجارية العالمية بأسعار تنافسية ، نسعى لتوفير تجربة تسوق استثنائية وخدمة عملاء متميزة في فروعنا'
						: 'We are a leading supermarket in the Kingdom of Saudi Arabia, offering the finest local and imported products, along with the best global brands at competitive prices. We strive to provide an exceptional shopping experience and outstanding customer service across all our branches.'}
				</p>
			</div>
			<div class="footer-links">
				<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
				<a href="/login/employee" on:click|preventDefault={goTeam} style="cursor:pointer">{isRTL ? 'دخول الفريق' : 'Team Login'}</a>
			</div>
			<div class="footer-email">
				<span>{isRTL ? 'تواصل معنا' : 'Contact Us'}</span>
				<a class="whatsapp-btn" href="https://api.whatsapp.com/send?phone=966567334726&text=%D8%A3%D8%AD%D8%AA%D8%A7%D8%AC%20%D8%A5%D9%84%D9%89%20%D9%85%D8%B3%D8%A7%D8%B9%D8%AF%D8%A9" target="_blank" rel="noopener noreferrer">
					<svg viewBox="0 0 32 32" fill="white" width="18" height="18"><path d="M16.004 0C7.164 0 .002 7.16.002 15.997c0 2.82.737 5.573 2.14 7.998L.006 32l8.27-2.11a15.96 15.96 0 007.728 1.97C24.84 31.86 32 24.7 32 15.997 32 7.16 24.84 0 16.004 0zm0 29.316a13.38 13.38 0 01-7.27-2.136l-.522-.31-4.896 1.25 1.304-4.77-.34-.54A13.34 13.34 0 012.55 15.997c0-7.417 6.038-13.454 13.454-13.454 7.418 0 13.454 6.037 13.454 13.454 0 7.418-6.036 13.32-13.454 13.32zm7.39-10.078c-.405-.202-2.396-1.182-2.768-1.316-.372-.134-.643-.202-.913.202-.27.405-1.048 1.316-1.285 1.588-.237.27-.474.304-.88.1-.405-.2-1.71-.63-3.26-2.01-1.205-1.074-2.018-2.4-2.254-2.806-.237-.405-.025-.624.178-.826.183-.182.405-.474.608-.71.202-.237.27-.405.405-.676.135-.27.068-.507-.034-.71-.1-.202-.913-2.2-1.25-3.012-.33-.79-.665-.684-.913-.697l-.778-.012c-.27 0-.71.1-.08.507-.372.405-1.42 1.384-1.42 3.38 0 1.993 1.453 3.92 1.656 4.192.202.27 2.86 4.36 6.93 6.116.968.418 1.724.668 2.313.855.972.308 1.857.265 2.556.16.78-.116 2.396-.98 2.734-1.925.338-.946.338-1.757.237-1.925-.1-.168-.372-.27-.778-.474z"/></svg>
					{isRTL ? 'واتساب' : 'WhatsApp'}
				</a>
			</div>
		</div>
		<div class="footer-bottom">
			<span>© 2026 Urban Market — {isRTL ? 'جميع الحقوق محفوظة' : 'All Rights Reserved'}</span>
		</div>
		<div class="footer-privacy">
			<a href="/privacy">{isRTL ? 'سياسة الخصوصية' : 'Privacy Policy'}</a>
		</div>
	</footer>
	{/if}
	</div><!-- .login-page-inner -->

	<!-- WhatsApp Float Button -->
	<a class="whatsapp-float" href="https://api.whatsapp.com/send?phone=966567334726&text=%D8%A3%D8%AD%D8%AA%D8%A7%D8%AC%20%D8%A5%D9%84%D9%89%20%D9%85%D8%B3%D8%A7%D8%B9%D8%AF%D8%A9" target="_blank" rel="noopener noreferrer" aria-label="WhatsApp">
		<svg viewBox="0 0 32 32" fill="white" width="32" height="32"><path d="M16.004 0C7.164 0 .002 7.16.002 15.997c0 2.82.737 5.573 2.14 7.998L.006 32l8.27-2.11a15.96 15.96 0 007.728 1.97C24.84 31.86 32 24.7 32 15.997 32 7.16 24.84 0 16.004 0zm0 29.316a13.38 13.38 0 01-7.27-2.136l-.522-.31-4.896 1.25 1.304-4.77-.34-.54A13.34 13.34 0 012.55 15.997c0-7.417 6.038-13.454 13.454-13.454 7.418 0 13.454 6.037 13.454 13.454 0 7.418-6.036 13.32-13.454 13.32zm7.39-10.078c-.405-.202-2.396-1.182-2.768-1.316-.372-.134-.643-.202-.913.202-.27.405-1.048 1.316-1.285 1.588-.237.27-.474.304-.88.1-.405-.2-1.71-.63-3.26-2.01-1.205-1.074-2.018-2.4-2.254-2.806-.237-.405-.025-.624.178-.826.183-.182.405-.474.608-.71.202-.237.27-.405.405-.676.135-.27.068-.507-.034-.71-.1-.202-.913-2.2-1.25-3.012-.33-.79-.665-.684-.913-.697l-.778-.012c-.27 0-.71.1-.08.507-.372.405-1.42 1.384-1.42 3.38 0 1.993 1.453 3.92 1.656 4.192.202.27 2.86 4.36 6.93 6.116.968.418 1.724.668 2.313.855.972.308 1.857.265 2.556.16.78-.116 2.396-.98 2.734-1.925.338-.946.338-1.757.237-1.925-.1-.168-.372-.27-.778-.474z"/></svg>
	</a>
</div><!-- .login-page -->

<style>
	/* WhatsApp Float */
	.whatsapp-float {
		position: fixed;
		bottom: 24px;
		right: 24px;
		z-index: 9999;
		width: 56px;
		height: 56px;
		border-radius: 50%;
		background: #25D366;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 16px rgba(0,0,0,0.25);
		transition: transform 0.2s, box-shadow 0.2s;
		cursor: pointer;
		text-decoration: none;
	}
	.whatsapp-float:hover {
		transform: scale(1.1);
		box-shadow: 0 6px 24px rgba(0,0,0,0.3);
	}
	.whatsapp-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		background: #25D366;
		color: white !important;
		padding: 10px 24px;
		border-radius: 25px;
		text-decoration: none;
		font-size: 0.9rem;
		font-weight: 600;
		margin-top: 12px;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(37,211,102,0.3);
	}
	.whatsapp-btn:hover {
		background: #20BD5A;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(37,211,102,0.4);
	}


	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RESET & BASE â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.login-page {
		background: #f0fdf4;
		height: 100vh;
		height: 100dvh;
		width: 100%;
		direction: ltr; /* Keep scrollbar on right side always */
		opacity: 0;
		transition: opacity 0.4s ease;
		overflow-x: hidden;
		overflow-y: auto;
	}
	.login-page.mounted { opacity: 1; }

	.login-page-inner {
		display: flex;
		flex-direction: column;
		flex: 1;
		width: 100%;
		font-family: 'Plus Jakarta Sans', 'Inter', system-ui, sans-serif;
	}
	.login-page-inner.rtl {
		direction: rtl;
		text-align: right;
		font-family: 'Tajawal', 'Noto Sans Arabic', system-ui, sans-serif;
	}


	/* WhatsApp In-App Browser Banner */
	.wa-browser-banner {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 10px 16px;
		background: #1e293b;
		color: #fff;
		font-size: 0.85rem;
		font-weight: 500;
		z-index: 200;
		flex-wrap: wrap;
	}
	.wa-browser-banner button {
		background: #f08300;
		color: #fff;
		border: none;
		padding: 6px 18px;
		border-radius: 20px;
		font-size: 0.82rem;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.2s;
		white-space: nowrap;
	}
	.wa-browser-banner button:hover {
		background: #d97706;
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• STICKY HEADER â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.sticky-header {
		position: sticky;
		top: 0;
		z-index: 100;
		width: 100%;
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• TOP BAR â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.top-bar {
		background: linear-gradient(135deg, #108C30 0%, #13A538 100%);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 24px;
		font-size: 13px;
		font-weight: 500;
	}
	.top-bar-text { opacity: 0.95; }
	.lang-btn {
		background: transparent;
		border: 1px solid white;
		color: white;
		padding: 4px 14px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		gap: 6px;
	}
	.lang-btn:hover { background: rgba(255,255,255,0.15); }

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• NAVIGATION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.nav-bar {
		background: white;
		padding: 12px 24px;
		box-shadow: 0 1px 3px rgba(0,0,0,0.06);
	}
	.nav-content { display: flex; align-items: center; max-width: 1200px; margin: 0 auto; }
	.nav-logo img { height: 52px; object-fit: contain; }

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• HERO SECTION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.hero {
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 30%, #f0fdf4 70%, #fefce8 100%);
		padding: 60px 24px 40px;
		position: relative;
		overflow: hidden;
	}
	.hero::before {
		content: '';
		position: absolute;
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, rgba(19,165,56,0.08) 0%, transparent 70%);
		top: -100px;
		right: -100px;
		border-radius: 50%;
	}
	.hero-content {
		max-width: 1200px;
		margin: 0 auto;
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 48px;
		align-items: center;
	}
	.hero-text h1 {
		font-size: 3rem;
		font-weight: 800;
		line-height: 1.15;
		margin: 0 0 20px;
		letter-spacing: -0.5px;
	}
	.hero-dark { color: #1a202c; }
	.hero-highlight { color: #f08300; }
	.hero-sub {
		font-size: 1rem;
		color: #64748b;
		line-height: 1.7;
		margin: 0 0 32px;
		max-width: 480px;
	}

	/* Login Buttons */
	.hero-buttons {
		display: flex;
		gap: 16px;
		flex-wrap: wrap;
		position: relative;
	}
	.btn-primary {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		background: linear-gradient(135deg, #108C30, #13A538);
		color: white;
		border: none;
		padding: 14px 32px;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s;
		box-shadow: 0 4px 16px rgba(19,165,56,0.3);
		font-family: inherit;
		text-decoration: none;
	}
	.btn-primary:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 24px rgba(19,165,56,0.4);
	}
	.btn-primary:active { transform: translateY(0); }

	.btn-outline {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		background: white;
		color: #13A538;
		border: 2px solid #13A538;
		padding: 12px 30px;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s;
		font-family: inherit;
		text-decoration: none;
	}
	.btn-outline:hover {
		background: #f0fdf4;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0,0,0,0.08);
	}
	.btn-outline:active { transform: translateY(0); }

	.btn-customer {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		background: #f08300;
		color: white;
		border: none;
		padding: 14px 32px;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s;
		box-shadow: 0 4px 16px rgba(240,131,0,0.3);
		font-family: inherit;
		text-decoration: none;
	}
	.btn-customer:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 24px rgba(240,131,0,0.4);
	}
	.btn-customer:active { transform: translateY(0); }

	.btn-points {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		background: #f08300;
		color: white;
		border: none;
		padding: 14px 32px;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s;
		box-shadow: 0 4px 16px rgba(245,158,11,0.3);
		font-family: inherit;
		text-decoration: none;
	}
	.btn-points:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 24px rgba(245,158,11,0.4);
	}
	.btn-points:active { transform: translateY(0); }

	.btn-locate {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 14px 28px;
		border-radius: 50px;
		font-weight: 700;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.3s;
		text-decoration: none;
		border: 2px solid #13A538;
		background: transparent;
		color: #13A538;
	}
	.btn-locate:hover {
		background: #13A538;
		color: white;
		transform: translateY(-2px);
		box-shadow: 0 6px 24px rgba(19,165,56,0.3);
	}
	.btn-locate:active { transform: translateY(0); }

	.btn-gift-wheel {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 14px 28px;
		border-radius: 50px;
		font-weight: 700;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.3s;
		text-decoration: none;
		border: none;
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
		box-shadow: 0 4px 16px rgba(245,158,11,0.35);
	}
	.btn-gift-wheel:hover {
		background: linear-gradient(135deg, #d97706, #b45309);
		transform: translateY(-2px);
		box-shadow: 0 6px 24px rgba(245,158,11,0.5);
	}
	.btn-gift-wheel:active { transform: translateY(0); }

	/* Coming Soon Mask */
	.mask-notice {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 5;
		cursor: default;
		pointer-events: none;
	}
	.mask-badge {
		display: none;
	}

	/* Hero Image / Logo */
	.hero-image {
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
	}
	.hero-logo-img {
		width: 280px;
		height: 280px;
		object-fit: contain;
		z-index: 2;
		position: relative;
		filter: drop-shadow(0 20px 40px rgba(0,0,0,0.1));
		animation: float 6s ease-in-out infinite;
	}
	@keyframes float {
		0%, 100% { transform: translateY(0); }
		50% { transform: translateY(-12px); }
	}
	.hero-decorative { position: absolute; inset: 0; }
	.deco-circle {
		position: absolute;
		border-radius: 50%;
		opacity: 0.15;
	}
	.deco-1 {
		width: 300px; height: 300px;
		background: #13A538;
		top: 10%; right: 5%;
	}
	.deco-2 {
		width: 180px; height: 180px;
		background: #f08300;
		bottom: 5%; left: 15%;
	}
	.deco-3 {
		width: 100px; height: 100px;
		background: #f08300;
		top: 30%; left: 5%;
	}

	.fade-in {
		animation: fadeSlideUp 0.6s ease forwards;
	}
	@keyframes fadeSlideUp {
		from { opacity: 0; transform: translateY(20px); }
		to { opacity: 1; transform: translateY(0); }
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• FEATURES SECTION â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.features {
		padding: 60px 24px;
		background: white;
		text-align: center;
	}
	.features-title {
		font-size: 2rem;
		font-weight: 800;
		margin: 0 0 40px;
	}
	.text-orange { color: #f08300; }
	.features-grid {
		max-width: 1100px;
		margin: 0 auto;
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 32px;
	}
	.feature-card {
		background: white;
		border-radius: 16px;
		padding: 36px 24px;
		text-align: center;
		box-shadow: 0 2px 12px rgba(0,0,0,0.04);
		transition: all 0.3s;
	}
	.feature-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 8px 24px rgba(0,0,0,0.08);
	}
	.feature-icon {
		width: 72px;
		height: 72px;
		margin: 0 auto 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f0fdf4;
		border-radius: 16px;
	}
	.feature-card h3 {
		font-size: 1.05rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 12px;
	}
	.feature-card p {
		font-size: 0.88rem;
		color: #64748b;
		line-height: 1.65;
		margin: 0;
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• OFFERS BANNER â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.offers-banner {
		background: linear-gradient(135deg, #0B6322 0%, #108C30 50%, #0D7427 100%);
		padding: 64px 24px;
		text-align: center;
		position: relative;
		overflow: hidden;
	}
	.offers-banner::before {
		content: '';
		position: absolute;
		inset: 0;
		background: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.04'%3E%3Ccircle cx='30' cy='30' r='4'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
	}
	.offers-content { position: relative; z-index: 2; }
	.offers-icon {
		font-size: 48px;
		margin-bottom: 16px;
		display: flex;
		justify-content: center;
	}
	.offers-banner h2 {
		font-size: 1.75rem;
		font-weight: 800;
		color: white;
		margin: 0 0 12px;
	}
	.offers-banner .text-dark { color: white; }
	.offers-banner .text-orange { color: #f08300; }
	.offers-banner p {
		font-size: 0.95rem;
		color: rgba(255,255,255,0.8);
		max-width: 520px;
		margin: 0 auto;
		line-height: 1.6;
	}
	.text-green { color: #5ED86A; }
	.text-orange { color: #f08300; }
	.text-dark { color: #1e293b; }

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• LOCATIONS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.locations {
		padding: 64px 24px;
		background: white;
		text-align: center;
	}
	.section-title {
		font-size: 2rem;
		font-weight: 800;
		margin: 0 0 12px;
	}
	.section-sub {
		font-size: 0.95rem;
		color: #64748b;
		margin: 0 0 40px;
		max-width: 560px;
		margin-left: auto;
		margin-right: auto;
	}
	.branch-cards {
		display: flex;
		gap: 24px;
		justify-content: center;
		flex-wrap: wrap;
		max-width: 700px;
		margin: 0 auto;
	}
	.branch-card {
		display: flex;
		align-items: center;
		gap: 16px;
		background: #f8fafc;
		border: 2px solid #e2e8f0;
		border-radius: 16px;
		padding: 20px 28px;
		min-width: 280px;
		transition: all 0.3s;
		text-align: left;
	}
	.rtl .branch-card { text-align: right; }
	.branch-card:hover {
		border-color: #13A538;
		box-shadow: 0 4px 16px rgba(19,165,56,0.12);
	}
	.branch-avatar {
		width: 52px;
		height: 52px;
		border-radius: 50%;
		background: white;
		border: 2px solid #f08300;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		overflow: hidden;
	}
	.branch-avatar img {
		width: 36px;
		height: 36px;
		object-fit: contain;
	}
	.branch-info h3 {
		font-size: 1rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 4px;
	}
	.branch-info p {
		font-size: 0.82rem;
		color: #64748b;
		margin: 0 0 6px;
		line-height: 1.4;
	}
	.branch-hours {
		font-size: 0.78rem;
		color: #13A538;
		font-weight: 600;
	}
	.branch-location-btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		margin-top: 8px;
		padding: 6px 14px;
		background: #13A538;
		color: white;
		border-radius: 20px;
		font-size: 0.78rem;
		font-weight: 600;
		text-decoration: none;
		transition: all 0.2s;
	}
	.branch-location-btn:hover {
		background: #108C30;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(19,165,56,0.3);
	}
	.branch-location-btn svg { flex-shrink: 0; }

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• FOOTER â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	.footer {
		background: #f0fdf4;
		padding: 48px 24px 0;
		border-top: 1px solid #dcfce7;
	}
	.footer-content {
		max-width: 1000px;
		margin: 0 auto;
		display: grid;
		grid-template-columns: 2fr 1fr 1fr;
		gap: 40px;
		padding-bottom: 32px;
	}
	.footer-logo img { height: 48px; margin-bottom: 16px; }
	.footer-logo p {
		font-size: 0.85rem;
		color: #64748b;
		line-height: 1.7;
		margin: 0;
	}
	.footer-links {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.footer-links a {
		display: inline-block;
		padding: 10px 28px;
		background: #1e293b;
		color: #fff;
		text-decoration: none;
		font-size: 0.85rem;
		font-weight: 600;
		letter-spacing: 0.3px;
		border-radius: 8px;
		transition: background 0.2s, transform 0.15s;
	}
	.footer-links a:hover {
		background: #334155;
		transform: translateY(-1px);
	}
	.footer-email {
		text-align: center;
	}
	.footer-email span {
		display: block;
		font-size: 0.85rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 8px;
	}
	.footer-email a {
		color: #13A538;
		text-decoration: none;
		font-size: 0.9rem;
		font-weight: 600;
	}
	.footer-bottom {
		border-top: 1px solid #dcfce7;
		padding: 16px 0 8px;
		text-align: center;
		font-size: 0.8rem;
		color: #94a3b8;
	}
	.footer-privacy {
		text-align: center;
		padding-bottom: 12px;
	}
	.footer-privacy a {
		color: #dc2626;
		text-decoration: none;
		font-size: 0.78rem;
		font-weight: 600;
		transition: color 0.2s;
	}
	.footer-privacy a:hover {
		color: #13A538;
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RESPONSIVE â€” TABLET â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	@media (max-width: 900px) {
		.hero-content {
			grid-template-columns: 1fr;
			gap: 32px;
			text-align: center;
		}
		.hero-text h1 { font-size: 2.2rem; }
		.hero-sub { max-width: 100%; margin-left: auto; margin-right: auto; }
		.hero-buttons { justify-content: center; }
		.hero-image { order: -1; }
		.hero-logo-img { width: 180px; height: 180px; }
		.deco-1 { width: 200px; height: 200px; }
		.deco-2 { width: 120px; height: 120px; }
		.deco-3 { width: 60px; height: 60px; }

		.features-grid { grid-template-columns: 1fr; max-width: 400px; margin: 0 auto; }
		.footer-content { grid-template-columns: 1fr; gap: 28px; text-align: center; }
		.footer-links { align-items: center; }
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RESPONSIVE â€” MOBILE â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	@media (max-width: 600px) {
		.top-bar { padding: 6px 16px; font-size: 11px; }
		.top-bar-text { display: none; }
		.lang-btn { margin-left: auto; }
		.nav-bar { padding: 10px 16px; }
		.nav-logo img { height: 40px; }
		.hero { padding: 32px 16px 24px; }
		.hero-text h1 { font-size: 1.75rem; }
		.hero-sub { font-size: 0.88rem; }
		.hero-logo-img { width: 140px; height: 140px; }

		.hero-buttons { flex-direction: column; align-items: stretch; }
		.btn-primary, .btn-outline, .btn-customer, .btn-points, .btn-locate, .btn-gift-wheel {
			justify-content: center;
			padding: 14px 20px;
			font-size: 15px;
			width: 100%;
		}

		.features { padding: 40px 16px; }
		.feature-card { padding: 28px 20px; }

		.offers-banner { padding: 40px 16px; }
		.offers-banner h2 { font-size: 1.3rem; }

		.locations { padding: 40px 16px; }
		.section-title { font-size: 1.5rem; }
		.branch-cards { flex-direction: column; align-items: stretch; }
		.branch-card { min-width: unset; }

		.footer { padding: 32px 16px 0; }
		.footer-content { gap: 20px; }
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• RESPONSIVE â€” SMALL MOBILE â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	@media (max-width: 380px) {
		.hero-text h1 { font-size: 1.45rem; }
		.hero-sub { font-size: 0.82rem; }
		.hero-logo-img { width: 110px; height: 110px; }
		.btn-primary, .btn-outline, .btn-customer, .btn-points, .btn-locate, .btn-gift-wheel { font-size: 14px; padding: 12px 16px; }
		.feature-card h3 { font-size: 0.95rem; }
		.offers-banner h2 { font-size: 1.15rem; }
		.section-title { font-size: 1.3rem; }
	}

	/* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• LANDSCAPE MOBILE â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
	@media (max-height: 500px) and (orientation: landscape) {
		.hero { padding: 20px 24px; }
		.hero-logo-img { width: 100px; height: 100px; }
		.hero-text h1 { font-size: 1.5rem; }
		.features { padding: 32px 24px; }
		.offers-banner { padding: 32px 24px; }
	}
</style>
