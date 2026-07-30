<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale, switchLocale } from '$lib/i18n';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let mobileMenuOpen = false;

	function closeMobileMenu() {
		mobileMenuOpen = false;
	}

	// Branding layout loaded from the login_layout table (falls back to hardcoded defaults when empty)
	let layout: any = null;

	// About section image gallery - shows a fixed-size slideshow when there is more than 1 enabled image,
	// so the section never resizes to fit the images. Shows nothing when there is no data.
	let activeAboutImage = 0;
	let aboutSlideshowTimer: ReturnType<typeof setInterval> | null = null;
	$: aboutImagesRaw = Array.isArray(layout?.about?.images) ? layout.about.images : [];
	$: aboutImagesEnabled = aboutImagesRaw
		.filter((it: any) => (typeof it === 'string' ? !!it : it && it.enabled !== false && !!it.url))
		.map((it: any) => (typeof it === 'string' ? it : it.url));
	$: aboutImages = aboutImagesEnabled.length
		? aboutImagesEnabled
		: layout?.about?.image_url
			? [layout.about.image_url]
			: [];
	$: if (aboutImages.length <= 1) activeAboutImage = 0;
	$: {
		if (aboutSlideshowTimer) clearInterval(aboutSlideshowTimer);
		if (aboutImages.length > 1) {
			aboutSlideshowTimer = setInterval(() => {
				activeAboutImage = (activeAboutImage + 1) % aboutImages.length;
			}, 4000);
		}
	}

	$: isAr = $currentLocale === 'ar';

	// Bilingual text pulled from layout.home_content, with hardcoded EN/AR fallbacks
	$: navLabel = layout?.home_content?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'الرئيسية' : 'Home');
	$: headlinePrefix =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.headline_prefix ?? (isAr ? 'جودة تثق بها،' : 'Quality You Trust,');
	$: headlineHighlight =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.headline_highlight ?? (isAr ? 'تجربة' : 'Experience');
	$: headlineSuffix =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.headline_suffix ?? (isAr ? 'تحبها حقًا.' : 'You Love.');
	$: taglineText =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.tagline ??
		(isAr
			? 'من البقالة الطازجة إلى الوجبات اللذيذة والقهوة العطرة والعصائر المنعشة والأزياء الأنيقة – كل ما تحتاجه في مكان واحد.'
			: 'From fresh groceries to delicious meals, aromatic coffee, refreshing juices and stylish fashion – everything you need, all in one place.');
	$: contactBtnLabel =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.contact_btn_label ?? (isAr ? 'تواصل معنا' : 'Contact Us');
	$: signupBtnLabel =
		layout?.home_content?.[isAr ? 'ar' : 'en']?.signup_btn_label ?? (isAr ? 'تسجيل الدخول / اشتراك' : 'Sign Up / Login');

	// Enable/disable toggles for each Home block, managed from BrandingManager's Home section
	$: homeBlockEnabled = {
		navButton: layout?.home_content?.enabled_blocks?.navButton !== false,
		mainTag: layout?.home_content?.enabled_blocks?.mainTag !== false,
		tagline: layout?.home_content?.enabled_blocks?.tagline !== false,
		contactBtn: layout?.home_content?.enabled_blocks?.contactBtn !== false,
		signupBtn: layout?.home_content?.enabled_blocks?.signupBtn !== false,
		logo: layout?.home_content?.enabled_blocks?.logo !== false
	};

	// Nav bar buttons for the other sections - bilingual label, color and enable/disable, all editable per-section in BrandingManager
	$: aboutNavVisible = layout?.about?.enabled_blocks?.navButton !== false;
	$: aboutNavText = layout?.about?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'من نحن' : 'About');
	$: aboutNavColor = layout?.about?.nav_color;

	$: servicesNavVisible = layout?.services?.enabled_blocks?.navButton !== false;
	$: servicesNavText = layout?.services?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'الخدمات' : 'Services');
	$: servicesNavColor = layout?.services?.nav_color;

	$: galleryNavVisible = layout?.gallery?.enabled_blocks?.navButton !== false;
	$: galleryNavText = layout?.gallery?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'معرض الصور' : 'Gallery');
	$: galleryNavColor = layout?.gallery?.nav_color;

	$: offersNavVisible = layout?.offers?.enabled_blocks?.navButton !== false;
	$: offersNavText = layout?.offers?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'العروض' : 'Offers');
	$: offersNavColor = layout?.offers?.nav_color;

	$: careersNavVisible = layout?.careers?.nav_enabled !== false;
	$: careersNavText = layout?.careers?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'الوظائف' : 'Careers');
	$: careersNavColor = layout?.careers?.nav_color;

	$: contactNavVisible = layout?.contact?.nav_enabled !== false;
	$: contactNavText = layout?.contact?.[isAr ? 'ar' : 'en']?.nav_label ?? (isAr ? 'تواصل' : 'Contact');
	$: contactNavColor = layout?.contact?.nav_color;

	// Trust badges - managed from BrandingManager's Home section; falls back to defaults when empty
	const defaultBadges = [
		{ icon: '✔', title: 'Fresh & Quality', title_ar: 'طازج وعالي الجودة', desc: 'Always fresh, always the best.', desc_ar: 'دائمًا طازج، دائمًا الأفضل.', enabled: true },
		{ icon: '👥', title: 'Great Service', title_ar: 'خدمة رائعة', desc: 'We care for our customers.', desc_ar: 'نحن نهتم بعملائنا.', enabled: true },
		{ icon: '🛡️', title: 'Trusted & Reliable', title_ar: 'موثوق وجدير بالثقة', desc: 'Quality you can depend on.', desc_ar: 'جودة يمكنك الاعتماد عليها.', enabled: true }
	];
	$: trustBadges = (
		Array.isArray(layout?.home_content?.badges) && layout.home_content.badges.length
			? layout.home_content.badges
			: defaultBadges
	).filter((b: any) => b.enabled !== false);

	function toggleSiteLanguage() {
		switchLocale(isAr ? 'en' : 'ar');
	}

	// Cache the layout in localStorage (stale-while-revalidate) so repeat visits render the
	// real branding instantly instead of waiting on the network round-trip to the self-hosted API.
	const LAYOUT_CACHE_KEY = 'login_layout_cache_v1';

	function loadLayoutFromCache() {
		if (typeof window === 'undefined') return;
		try {
			const cached = window.localStorage.getItem(LAYOUT_CACHE_KEY);
			if (cached) layout = JSON.parse(cached);
		} catch (e) {
			// Ignore malformed/unavailable cache
		}
	}

	async function loadLayout() {
		try {
			const { data, error } = await supabase.rpc('get_login_layout');
			if (error) throw error;
			layout = data;
			if (typeof window !== 'undefined') {
				try {
					window.localStorage.setItem(LAYOUT_CACHE_KEY, JSON.stringify(data));
				} catch (e) {
					// Storage full/unavailable - not critical
				}
			}
		} catch (e) {
			console.error('Failed to load login layout:', e);
		}
	}

	onMount(() => {
		// Show cached branding immediately (if we have any from a previous visit), then
		// revalidate in the background - avoids the plain fallback screen on repeat visits.
		loadLayoutFromCache();
		loadLayout();
		loadOffers();
		loadJobVacancies();
		loadBranches();
		loadSocialLinks();
		startOfferAutoScroll();

		// Realtime subscriptions open extra TLS/websocket connections which compete with the
		// initial data requests on slower/distant connections. Defer them slightly so the
		// critical first paint isn't held up by connection setup for live-refresh channels.
		let channel: ReturnType<typeof supabase.channel> | undefined;
		let offersChannel: ReturnType<typeof supabase.channel> | undefined;
		let vacanciesChannel: ReturnType<typeof supabase.channel> | undefined;
		let branchesChannel: ReturnType<typeof supabase.channel> | undefined;

		const realtimeTimer = setTimeout(() => {
			// Live-refresh the branding as soon as it's changed/saved in BrandingManager (no manual reload needed)
			channel = supabase
				.channel('public:login_layout')
				.on('postgres_changes', { event: '*', schema: 'public', table: 'login_layout' }, () => {
					loadLayout();
				})
				.subscribe();

			// Live-refresh offers as soon as they change in the Offers module
			offersChannel = supabase
				.channel('public:view_offer')
				.on('postgres_changes', { event: '*', schema: 'public', table: 'view_offer' }, () => {
					loadOffers();
				})
				.subscribe();

			// Live-refresh job vacancies as soon as they change in the Careers module
			vacanciesChannel = supabase
				.channel('public:career_job_vacancies')
				.on('postgres_changes', { event: '*', schema: 'public', table: 'career_job_vacancies' }, () => {
					loadJobVacancies();
				})
				.subscribe();

			// Live-refresh branch locations as soon as they change in the Branches module
			branchesChannel = supabase
				.channel('public:branches')
				.on('postgres_changes', { event: '*', schema: 'public', table: 'branches' }, () => {
					loadBranches();
				})
				.subscribe();
		}, 2000);

		return () => {
			clearTimeout(realtimeTimer);
			if (channel) supabase.removeChannel(channel);
			if (offersChannel) supabase.removeChannel(offersChannel);
			if (vacanciesChannel) supabase.removeChannel(vacanciesChannel);
			if (branchesChannel) supabase.removeChannel(branchesChannel);
		};
	});

	onDestroy(() => {
		if (aboutSlideshowTimer) clearInterval(aboutSlideshowTimer);
		if (offerAnimFrame) cancelAnimationFrame(offerAnimFrame);
	});

	function goTeam() {
		if (typeof window !== 'undefined' && window.innerWidth <= 768) {
			goto('/mobile-interface/login');
		} else {
			goto('/login/employee?mode=desktop');
		}
	}

	// Careers section - Job Ads are managed from BrandingManager's Careers tab and live in
	// public.career_job_vacancies; only enabled vacancies are shown here.
	let jobVacancies: any[] = [];

	async function loadJobVacancies() {
		try {
			const { data, error } = await supabase
				.from('career_job_vacancies')
				.select('*')
				.eq('enabled', true)
				.order('display_order', { ascending: true })
				.order('created_at', { ascending: false });
			if (error) throw error;
			jobVacancies = data || [];
		} catch (e) {
			console.error('Failed to load job vacancies:', e);
		}
	}

	function getVacancyTitle(v: any) {
		return isAr ? v.title_ar || v.title_en : v.title_en;
	}
	function getVacancyDept(v: any) {
		return isAr ? v.department_ar || v.department_en : v.department_en;
	}
	function getVacancyType(v: any) {
		return isAr ? v.employment_type_ar || v.employment_type_en : v.employment_type_en;
	}
	function getVacancyLocation(v: any) {
		return isAr ? v.location_ar || v.location_en : v.location_en;
	}
	function getVacancyButtonText(v: any) {
		return isAr ? v.button_text_ar || v.button_text_en || 'تقديم' : v.button_text_en || 'Apply';
	}

	$: vacanciesVisible = jobVacancies.length > 0;

	// Careers headline/branding text - managed from BrandingManager's Careers > Headline Manager
	$: careersHeadingText = layout?.careers?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'وظائف' : 'Careers');
	$: careersTaglineText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.tagline ?? (isAr ? 'انضم إلى فريقنا المتنامي' : 'Join Our Growing Team');
	$: careersCvFormHeadingText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.cv_form_heading ?? (isAr ? 'أرسل لنا سيرتك الذاتية' : 'Send Us Your CV');
	$: careersVacanciesHeadingText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.vacancies_heading ?? (isAr ? 'الوظائف المتاحة' : 'Available Vacancies');
	$: careersSubmitBtnText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.submit_btn ?? (isAr ? 'إرسال الطلب' : 'Submit Application');
	$: careersSuccessMessageText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.success_message ??
		(isAr ? 'شكرًا لك! تم إرسال طلبك.' : 'Thank you! Your application has been submitted.');
	$: careersErrorMessageText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.error_message ??
		(isAr ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.' : 'Something went wrong. Please try again.');
	$: careersTeamLoginBtnText = layout?.careers?.[isAr ? 'ar' : 'en']?.team_login_btn ?? (isAr ? 'دخول الفريق' : 'Team Login');
	$: careersTeamLoginTaglineText =
		layout?.careers?.[isAr ? 'ar' : 'en']?.team_login_tagline ?? (isAr ? 'هل أنت بالفعل جزء من فريقنا؟' : 'Already part of our team?');
	$: careersTeamLoginTaglineEnabled = layout?.careers?.team_login_tagline_enabled ?? true;
	$: careersColors = layout?.careers?.colors || {};

	const defaultCareersLabels: Record<string, { en: string; ar: string }> = {
		full_name: { en: 'Full Name', ar: 'الاسم الكامل' },
		nationality: { en: 'Nationality', ar: 'الجنسية' },
		position: { en: 'Position Applying For', ar: 'الوظيفة المتقدم لها' },
		dob: { en: 'Date of Birth', ar: 'تاريخ الميلاد' },
		email: { en: 'Email Address', ar: 'البريد الإلكتروني' },
		whatsapp: { en: 'WhatsApp Number', ar: 'رقم واتساب' },
		other_contact: { en: 'Other Contact Number (optional)', ar: 'رقم تواصل آخر (اختياري)' },
		cv_upload: { en: 'Upload CV (optional)', ar: 'رفع السيرة الذاتية (اختياري)' },
		message: { en: 'Short message (optional)', ar: 'رسالة قصيرة (اختياري)' }
	};

	function getCareersLabel(key: string) {
		const fromLayout = layout?.careers?.[isAr ? 'ar' : 'en']?.labels?.[key];
		return fromLayout || defaultCareersLabels[key][isAr ? 'ar' : 'en'];
	}
	function getCareersPlaceholder(key: string) {
		return layout?.careers?.[isAr ? 'ar' : 'en']?.placeholders?.[key] || '';
	}

	let applicantName = '';
	let applicantNationality = '';
	let applicantDob = '';
	let applicantEmail = '';
	let applicantWhatsapp = '';
	let applicantOtherContact = '';
	let applicantPosition = '';
	let applicantVacancyId: string | null = null;
	let applicantMessage = '';
	let applicantCvFile: File | null = null;
	let applicationSubmitted = false;
	let applicationSubmitting = false;
	let applicationError = '';

	function applyToVacancy(job: any) {
		applicantPosition = getVacancyTitle(job);
		applicantVacancyId = job.id;
		if (typeof document !== 'undefined') {
			document.getElementById('cv-form')?.scrollIntoView({ behavior: 'smooth' });
		}
	}

	function handleCvFileChange(event: Event) {
		const input = event.target as HTMLInputElement;
		applicantCvFile = input.files?.[0] || null;
	}

	let cvFileInputEl: HTMLInputElement;
	let cvCameraInputEl: HTMLInputElement;

	function triggerCvFilePicker() {
		cvFileInputEl?.click();
	}
	function triggerCvCameraPicker() {
		cvCameraInputEl?.click();
	}

	async function handleApply(event: SubmitEvent) {
		event.preventDefault();
		if (applicationSubmitting) return;
		if (!applicantName || !applicantNationality || !applicantDob || !applicantEmail || !applicantWhatsapp) {
			applicationError = careersErrorMessageText;
			return;
		}
		applicationSubmitting = true;
		applicationError = '';
		try {
			let cvFileUrl: string | null = null;
			if (applicantCvFile) {
				const ext = applicantCvFile.name.split('.').pop() || 'pdf';
				const path = `careers/cv-applications/cv-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
				const { error: uploadErr } = await supabase.storage
					.from('branding-docs')
					.upload(path, applicantCvFile, { upsert: true, cacheControl: '3600' });
				if (uploadErr) throw uploadErr;
				const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
				cvFileUrl = data.publicUrl;
			}

			const { error } = await supabase.from('career_cv_applications').insert({
				full_name: applicantName,
				nationality: applicantNationality,
				position_applying_for: applicantPosition || null,
				date_of_birth: applicantDob,
				email: applicantEmail,
				whatsapp_number: applicantWhatsapp,
				other_contact_number: applicantOtherContact || null,
				message: applicantMessage || null,
				cv_file_url: cvFileUrl,
				vacancy_id: applicantVacancyId
			});
			if (error) throw error;

			applicationSubmitted = true;
			applicantName = '';
			applicantNationality = '';
			applicantDob = '';
			applicantEmail = '';
			applicantWhatsapp = '';
			applicantOtherContact = '';
			applicantPosition = '';
			applicantVacancyId = null;
			applicantMessage = '';
			applicantCvFile = null;
		} catch (e) {
			console.error('Failed to submit application:', e);
			applicationError = careersErrorMessageText;
		} finally {
			applicationSubmitting = false;
		}
	}

	// Contact section - heading/tagline/phone/email are managed from BrandingManager's Contact tab;
	// branch locations are loaded live from public.branches (no manual management here).
	let branches: any[] = [];

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar, is_active, location_url')
				.eq('is_active', true);
			if (error) throw error;
			branches = data || [];
		} catch (e) {
			console.error('Failed to load branches:', e);
		}
	}

	function getBranchName(b: any) {
		return isAr ? b.name_ar || b.name_en : b.name_en || b.name_ar;
	}

	function getBranchLocation(b: any) {
		return (isAr ? b.location_ar || b.location_en : b.location_en || b.location_ar || '').trim();
	}

	function getBranchDisplayLabel(b: any) {
		const name = getBranchName(b);
		const loc = getBranchLocation(b);
		return loc ? `${name} - ${loc}` : name;
	}

	function branchHasLocationUrl(b: any) {
		return typeof b.location_url === 'string' && b.location_url.trim().length > 0;
	}

	$: validBranches = branches.filter((b: any) => branchHasLocationUrl(b));

	// Branch dropdown (contact section)
	let branchDropdownOpen = false;
	let branchDropdownRef: HTMLDivElement | undefined;

	function toggleBranchDropdown() {
		branchDropdownOpen = !branchDropdownOpen;
	}

	function closeBranchDropdown() {
		branchDropdownOpen = false;
	}

	function handleWindowClickForBranchDropdown(event: MouseEvent) {
		if (branchDropdownOpen && branchDropdownRef && !branchDropdownRef.contains(event.target as Node)) {
			branchDropdownOpen = false;
		}
	}

	// Social links per branch (public.social_links) - shown once a branch is picked from the dropdown
	let socialLinksData: any[] = [];
	let selectedBranchId: number | null = null;

	async function loadSocialLinks() {
		try {
			const { data, error } = await supabase.from('social_links').select('*');
			if (error) throw error;
			socialLinksData = data || [];
		} catch (e) {
			console.error('Failed to load social links:', e);
		}
	}

	function selectBranch(b: any) {
		selectedBranchId = b.id;
		closeBranchDropdown();
	}

	$: selectedBranchObj = validBranches.find((b: any) => b.id === selectedBranchId) || null;
	$: branchDropdownDisplayText = selectedBranchObj ? getBranchDisplayLabel(selectedBranchObj) : branchDropdownPlaceholder;
	$: selectedSocialLinks = socialLinksData.find((s: any) => s.branch_id === selectedBranchId) || null;

	const socialPlatformLabels: Record<string, { en: string; ar: string }> = {
		facebook: { en: 'Facebook', ar: 'فيسبوك' },
		whatsapp: { en: 'WhatsApp', ar: 'واتس أب' },
		instagram: { en: 'Instagram', ar: 'انستغرام' },
		tiktok: { en: 'TikTok', ar: 'تيك توك' },
		snapchat: { en: 'Snapchat', ar: 'سناب شات' },
		website: { en: 'Website', ar: 'الموقع الإلكتروني' },
		location_link: { en: 'Location', ar: 'الموقع' }
	};

	function getSocialLabel(key: string) {
		return socialPlatformLabels[key]?.[isAr ? 'ar' : 'en'] || key;
	}

	$: socialPlatforms = [
		{ key: 'whatsapp', icon: $iconUrlMap['whatsapp-logo'] || '/icons/whatsapp logo.png', scale: 0.5 },
		{ key: 'instagram', icon: $iconUrlMap['instagram-logo'] || '/icons/instagram logo.png', scale: 2.2 },
		{ key: 'facebook', icon: $iconUrlMap['facebook-logo'] || '/icons/facebook logo.jpg' },
		{ key: 'tiktok', icon: $iconUrlMap['tiktok-logo'] || '/icons/tiktok logo.jpg' },
		{ key: 'snapchat', icon: $iconUrlMap['snapchat-logo'] || '/icons/snapchat logo.png' },
		{ key: 'website', icon: $iconUrlMap['logo'] || '/icons/logo.png' },
		{ key: 'location_link', icon: $iconUrlMap['map-icon'] || '/icons/map icon.png' }
	];

	function openSocialLink(url: string, platform: string) {
		if (!url) return;
		const fullUrl = url.startsWith('http') ? url : `https://${url}`;
		recordSocialLinkClick(platform);
		window.open(fullUrl, '_blank', 'noopener,noreferrer');
	}

	async function recordSocialLinkClick(platform: string) {
		if (!selectedBranchId) return;
		try {
			await supabase.rpc('increment_social_link_click', {
				_branch_id: selectedBranchId,
				_platform: platform
			});
		} catch (e) {
			console.error(`Error recording ${platform} click:`, e);
		}
	}

	$: contactHeadingText = layout?.contact?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'تواصل معنا' : 'Contact Us');
	$: contactTaglineText =
		layout?.contact?.[isAr ? 'ar' : 'en']?.tagline ?? (isAr ? 'يسعدنا التواصل معك' : "We'd Love to Hear From You");
	$: contactBranchesHeadingText =
		layout?.contact?.[isAr ? 'ar' : 'en']?.branches_heading ?? (isAr ? 'مواقع فروعنا' : 'Our Branch Locations');
	$: branchDropdownPlaceholder = isAr ? 'اختر الفرع لعرض الموقع' : 'Select a Branch to View Location';
	$: contactPhoneRaw = (layout?.contact?.phone || '').trim();
	$: contactPhoneValid = contactPhoneRaw.length > 0;
	$: contactPhoneHref = 'tel:' + contactPhoneRaw.replace(/[^\d+]/g, '');

	$: footerCopyrightText =
		layout?.footer?.[isAr ? 'ar' : 'en']?.copyright ??
		(isAr ? '© 2026 يو مارت. جميع الحقوق محفوظة.' : '© 2026 Urban Market. All Rights Reserved.');
	$: contactEmailsRaw = (
		Array.isArray(layout?.contact?.emails) && layout.contact.emails.length
			? layout.contact.emails
			: layout?.contact?.email
				? [layout.contact.email]
				: []
	) as string[];
	$: validContactEmails = contactEmailsRaw
		.map((e) => (e || '').trim())
		.filter((e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e));
	$: contactEmailValid = validContactEmails.length > 0;
	$: contactBranchesValid = validBranches.length > 0;
	$: contactSectionVisible = contactPhoneValid || contactEmailValid || contactBranchesValid;

	// Floating WhatsApp button - reuses the same phone number configured in Contact settings (single source of truth)
	$: whatsappPhoneDigits = contactPhoneRaw.replace(/[^\d]/g, '');
	$: whatsappVisible = contactPhoneValid && whatsappPhoneDigits.length > 0;
	$: whatsappLink = `https://wa.me/${whatsappPhoneDigits}`;

	$: rawCategories = Array.isArray(layout?.services?.categories) ? layout.services.categories : [];
	$: enabledCategories = rawCategories.filter((c: any) => c.enabled !== false);
	$: servicesVisible = enabledCategories.length > 0;
	$: useMarqueeCategories = enabledCategories.length > 5;
	$: servicesHeadingText =
		layout?.services?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'فئاتنا' : 'Our Categories');
	$: servicesTaglineText =
		layout?.services?.[isAr ? 'ar' : 'en']?.tagline ??
		(isAr ? 'كل ما تحتاجه في مكان واحد' : 'Everything You Need, All in One Place');
	$: servicesBlockEnabled = {
		heading: layout?.services?.enabled_blocks?.heading !== false,
		tagline: layout?.services?.enabled_blocks?.tagline !== false
	};

	$: rawFeatures = Array.isArray(layout?.why_choose?.features) ? layout.why_choose.features : [];
	$: enabledFeatures = rawFeatures.filter((f: any) => f.enabled !== false);
	$: whyChooseVisible = enabledFeatures.length > 0;
	$: useMarqueeFeatures = enabledFeatures.length > 5;
	$: whyChooseHeadingText =
		layout?.why_choose?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'لماذا تختارنا' : 'Why Choose Us');
	$: whyChooseTaglineText =
		layout?.why_choose?.[isAr ? 'ar' : 'en']?.tagline ??
		(isAr ? 'نحن ملتزمون بإسعادك' : "We're Committed to Making You Happy");
	$: whyChooseBlockEnabled = {
		heading: layout?.why_choose?.enabled_blocks?.heading !== false,
		tagline: layout?.why_choose?.enabled_blocks?.tagline !== false
	};

	$: rawGalleryItems = Array.isArray(layout?.gallery?.items) ? layout.gallery.items : [];
	$: enabledGalleryItems = rawGalleryItems.filter((g: any) => g.enabled !== false && g.image_url);
	$: galleryVisible = enabledGalleryItems.length > 0;
	$: useMarqueeGallery = enabledGalleryItems.length > 5;
	$: galleryHeadingText =
		layout?.gallery?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'أبرز اللحظات' : 'Highlights');
	$: galleryTaglineText =
		layout?.gallery?.[isAr ? 'ar' : 'en']?.tagline ?? (isAr ? 'لحظات تلهمنا' : 'Moments That Inspire Us');
	$: galleryBlockEnabled = {
		heading: layout?.gallery?.enabled_blocks?.heading !== false,
		tagline: layout?.gallery?.enabled_blocks?.tagline !== false
	};

	// Offers section - heading/tagline come from BrandingManager (layout.offers); the offer
	// cards themselves are loaded live from the Offers module (public.view_offer), filtered to
	// only those currently valid for the configured business time zone.
	const BUSINESS_TIMEZONE = 'Asia/Riyadh';

	function getBusinessNow() {
		const parts = new Intl.DateTimeFormat('en-CA', {
			timeZone: BUSINESS_TIMEZONE,
			year: 'numeric',
			month: '2-digit',
			day: '2-digit',
			hour: '2-digit',
			minute: '2-digit',
			second: '2-digit',
			hour12: false
		}).formatToParts(new Date());
		const map: Record<string, string> = {};
		for (const p of parts) map[p.type] = p.value;
		return { date: `${map.year}-${map.month}-${map.day}`, time: `${map.hour}:${map.minute}:${map.second}` };
	}

	function isOfferCurrentlyValid(offer: any, businessNow: { date: string; time: string }) {
		const { date, time } = businessNow;
		const startTime = offer.start_time || '00:00:00';
		const endTime = offer.end_time || '23:59:00';
		const afterStart = offer.start_date < date || (offer.start_date === date && time >= startTime);
		const beforeEnd = offer.end_date > date || (offer.end_date === date && time <= endTime);
		return afterStart && beforeEnd;
	}

	let validOffers: any[] = [];
	const offerImpressionsTracked = new Set<string>();

	async function loadOffers() {
		try {
			const businessNow = getBusinessNow();
			const { data: offerRows, error: offerError } = await supabase
				.from('view_offer')
				.select('*')
				.gte('end_date', businessNow.date)
				.order('created_at', { ascending: false });
			if (offerError) throw offerError;

			const candidates = (offerRows || []).filter((o: any) => isOfferCurrentlyValid(o, businessNow));

			const branchIds = Array.from(new Set(candidates.map((o: any) => o.branch_id)));
			let branchRows: any[] = [];
			if (branchIds.length) {
				const { data: branchData, error: branchError } = await supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar, location_url')
					.in('id', branchIds);
				if (branchError) throw branchError;
				branchRows = branchData || [];
			}

			validOffers = candidates.map((o: any) => ({
				...o,
				branch: branchRows.find((b: any) => b.id === o.branch_id) || null
			}));

			trackOfferImpressions();
		} catch (e) {
			console.error('Failed to load offers:', e);
		}
	}

	function trackOfferImpressions() {
		for (const offer of validOffers) {
			if (!offerImpressionsTracked.has(offer.id)) {
				offerImpressionsTracked.add(offer.id);
				supabase.rpc('increment_page_visit_count', { offer_id: offer.id }).then(({ error }) => {
					if (error) console.error('Failed to track offer impression:', error);
				});
			}
		}
	}

	const offerFileCache = new Map<string, Blob>();

	function isWhatsAppBrowser() {
		if (typeof navigator === 'undefined') return false;
		return /whatsapp/i.test(navigator.userAgent.toLowerCase());
	}

	async function handleOfferDownload(offer: any) {
		supabase.rpc('increment_view_button_count', { offer_id: offer.id }).then(({ error }) => {
			if (error) console.error('Failed to track offer download:', error);
		});

		const fileUrl = offer.file_url;
		if (!fileUrl || typeof window === 'undefined') return;

		if (isWhatsAppBrowser()) {
			try {
				const response = await fetch(fileUrl);
				const blob = await response.blob();
				const blobUrl = URL.createObjectURL(blob);
				const a = document.createElement('a');
				a.href = blobUrl;
				a.download = `offer_${offer.id}.pdf`;
				a.style.display = 'none';
				document.body.appendChild(a);
				a.click();
				document.body.removeChild(a);
				setTimeout(() => URL.revokeObjectURL(blobUrl), 10000);
			} catch (e) {
				console.error('Offer download failed, falling back to direct link:', e);
				window.location.href = fileUrl;
			}
			return;
		}

		if (offerFileCache.has(offer.id)) {
			window.open(URL.createObjectURL(offerFileCache.get(offer.id)!), `offer_${offer.id}`);
			return;
		}

		// Open the target window synchronously (within the click's user-gesture context) so
		// browsers don't treat it as a blocked popup, then fill it in once the file is fetched.
		const newWin = window.open('', `offer_${offer.id}`);
		if (newWin) {
			try {
				newWin.document.write('Loading…');
			} catch {
				/* ignore */
			}
		}

		try {
			const response = await fetch(fileUrl);
			const blob = await response.blob();
			offerFileCache.set(offer.id, blob);
			const blobUrl = URL.createObjectURL(blob);
			if (newWin) {
				newWin.location.href = blobUrl;
			} else {
				window.open(blobUrl, `offer_${offer.id}`);
			}
		} catch (e) {
			console.error('Offer download failed, falling back to direct link:', e);
			if (newWin) {
				newWin.location.href = fileUrl;
			} else {
				window.open(fileUrl, `offer_${offer.id}`);
			}
		}
	}

	function getOfferName(offer: any) {
		return isAr ? offer.offer_name_ar || offer.offer_name : offer.offer_name_en || offer.offer_name;
	}

	function getOfferBranchName(offer: any) {
		if (!offer.branch) return '';
		return isAr ? offer.branch.name_ar : offer.branch.name_en;
	}

	function getOfferBranchLocation(offer: any) {
		if (!offer.branch) return '';
		return isAr ? offer.branch.location_ar : offer.branch.location_en;
	}

	function formatOfferDate(dateStr: string) {
		if (!dateStr) return '';
		const [y, m, d] = dateStr.split('-');
		return `${d}/${m}/${y}`;
	}

	function formatOfferTime(timeStr: string) {
		if (!timeStr) return '';
		const [h, m] = timeStr.split(':');
		let hour = parseInt(h, 10);
		const period = hour >= 12 ? (isAr ? 'م' : 'PM') : (isAr ? 'ص' : 'AM');
		hour = hour % 12 || 12;
		return `${String(hour).padStart(2, '0')}:${m} ${period}`;
	}

	function formatOfferPeriod(offer: any) {
		const start = `${formatOfferDate(offer.start_date)} ${formatOfferTime(offer.start_time)}`;
		const end = `${formatOfferDate(offer.end_date)} ${formatOfferTime(offer.end_time)}`;
		return `${start} – ${end}`;
	}

	$: offersVisible = validOffers.length > 0;
	$: useMarqueeOffers = validOffers.length > 4;
	$: offersHeadingText =
		layout?.offers?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'عروض خاصة' : 'Special Offers');
	$: offersTaglineText =
		layout?.offers?.[isAr ? 'ar' : 'en']?.tagline ??
		(isAr ? 'عروض لا تريد أن تفوتك' : "Deals You Don't Want to Miss");
	$: offersBlockEnabled = {
		heading: layout?.offers?.enabled_blocks?.heading !== false,
		tagline: layout?.offers?.enabled_blocks?.tagline !== false
	};

	// Offers marquee - a real scrollable track auto-advanced via rAF so it natively supports
	// mouse dragging and touch swiping, and can be paused on hover.
	let offerTrackEl: HTMLDivElement | null = null;
	let offerAutoScrollPaused = false;
	let offerDragging = false;
	let offerDragMoved = false;
	let offerDragStartX = 0;
	let offerDragStartScroll = 0;
	let offerAnimFrame: number | null = null;

	function startOfferAutoScroll() {
		function step() {
			if (offerTrackEl && useMarqueeOffers && !offerAutoScrollPaused && !offerDragging) {
				const dir = isAr ? -1 : 1;
				offerTrackEl.scrollLeft += dir * 0.6;
				const half = offerTrackEl.scrollWidth / 2;
				if (half > 0) {
					if (offerTrackEl.scrollLeft >= half) {
						offerTrackEl.scrollLeft -= half;
					} else if (offerTrackEl.scrollLeft <= 0) {
						offerTrackEl.scrollLeft += half;
					}
				}
			}
			offerAnimFrame = requestAnimationFrame(step);
		}
		offerAnimFrame = requestAnimationFrame(step);
	}

	function handleOfferPointerDown(e: PointerEvent) {
		if (!offerTrackEl) return;
		// Don't start a drag/capture when the gesture begins on an interactive element
		// (Download button, branch map link) - let it handle its own click normally.
		const target = e.target as HTMLElement;
		if (target.closest('button, a')) return;
		offerDragging = true;
		offerDragMoved = false;
		offerDragStartX = e.clientX;
		offerDragStartScroll = offerTrackEl.scrollLeft;
		offerTrackEl.setPointerCapture(e.pointerId);
	}

	function handleOfferPointerMove(e: PointerEvent) {
		if (!offerDragging || !offerTrackEl) return;
		const dx = e.clientX - offerDragStartX;
		if (Math.abs(dx) > 3) offerDragMoved = true;
		offerTrackEl.scrollLeft = offerDragStartScroll - dx;
	}

	function handleOfferPointerUp() {
		offerDragging = false;
	}

	function handleOfferCardClick(e: MouseEvent) {
		// Suppress accidental clicks/downloads triggered right after a drag gesture
		if (offerDragMoved) {
			e.preventDefault();
			e.stopPropagation();
		}
	}


</script>

<svelte:window on:click={handleWindowClickForBranchDropdown} />

<svelte:head>
	<title>Urban Market</title>
</svelte:head>

<div class="page" dir={isAr ? 'rtl' : 'ltr'} style={layout?.main_layout?.bg_color ? `background: ${layout.main_layout.bg_color}` : undefined}>
	<!-- Header -->
	<header class="header" style={layout?.topbar?.bg_color ? `background: ${layout.topbar.bg_color}` : undefined}>
		<div class="header-inner">
			<div class="logo">
				<div class="logo-badge">
					{#if layout?.topbar?.logo_enabled !== false}
						<img class="logo-icon-img" src={layout?.topbar?.logo_url || '/icons/logo.png'} alt="Urban Market logo" />
					{/if}
				</div>
			</div>
			<nav class="nav" class:open={mobileMenuOpen}>
				{#if homeBlockEnabled.navButton}
					<a href="#home" class="active" style={layout?.main_layout?.nav_button_color ? `color: ${layout.main_layout.nav_button_color}` : undefined} on:click={closeMobileMenu}>{navLabel}</a>
				{/if}
				{#if aboutNavVisible}
					<a href="#about" style={aboutNavColor ? `color: ${aboutNavColor}` : undefined} on:click={closeMobileMenu}>{aboutNavText}</a>
				{/if}
				{#if servicesNavVisible}
					<a href="#services" style={servicesNavColor ? `color: ${servicesNavColor}` : undefined} on:click={closeMobileMenu}>{servicesNavText}</a>
				{/if}
				{#if galleryNavVisible}
					<a href="#gallery" style={galleryNavColor ? `color: ${galleryNavColor}` : undefined} on:click={closeMobileMenu}>{galleryNavText}</a>
				{/if}
				{#if offersNavVisible}
					<a href="#offers" style={offersNavColor ? `color: ${offersNavColor}` : undefined} on:click={closeMobileMenu}>{offersNavText}</a>
				{/if}
				{#if careersNavVisible}
					<a href="#careers" style={careersNavColor ? `color: ${careersNavColor}` : undefined} on:click={closeMobileMenu}>{careersNavText}</a>
				{/if}
				{#if contactNavVisible}
					<a href="#contact" style={contactNavColor ? `color: ${contactNavColor}` : undefined} on:click={closeMobileMenu}>{contactNavText}</a>
				{/if}
				<button class="lang-toggle-btn" on:click={toggleSiteLanguage}>{isAr ? 'English' : 'العربية'}</button>
			</nav>
			<button
				class="menu-toggle"
				aria-label="Toggle menu"
				on:click={() => (mobileMenuOpen = !mobileMenuOpen)}
			>
				{mobileMenuOpen ? 'Close' : 'Menu'}
			</button>
		</div>
	</header>

	<!-- Hero -->
	<section class="hero" id="home">
		<div class="hero-inner">
			<div class="hero-text">
				{#if homeBlockEnabled.mainTag}
					<h1 style={layout?.main_layout?.headline_text_color ? `color: ${layout.main_layout.headline_text_color}` : undefined}>
						<span style={layout?.main_layout?.headline_highlight_target === 'prefix' && layout?.main_layout?.headline_highlight_color ? `color: ${layout.main_layout.headline_highlight_color}` : undefined}>{headlinePrefix}</span><br />
						<span style={(layout?.main_layout?.headline_highlight_target ?? 'highlight') === 'highlight' && layout?.main_layout?.headline_highlight_color ? `color: ${layout.main_layout.headline_highlight_color}` : undefined}>{headlineHighlight}</span> <span style={layout?.main_layout?.headline_highlight_target === 'suffix' && layout?.main_layout?.headline_highlight_color ? `color: ${layout.main_layout.headline_highlight_color}` : undefined}>{headlineSuffix}</span>
					</h1>
				{/if}
				{#if homeBlockEnabled.tagline}
					<p style={layout?.main_layout?.tagline_color ? `color: ${layout.main_layout.tagline_color}` : undefined}>
						{taglineText}
					</p>
				{/if}
				<div class="hero-actions">
					{#if homeBlockEnabled.contactBtn}
						<button
							class="btn btn-outline"
							style={layout?.main_layout?.contact_btn_color ? `color: ${layout.main_layout.contact_btn_color}; border-color: ${layout.main_layout.contact_btn_color}` : undefined}
							on:click={() => document.getElementById('contact')?.scrollIntoView({ behavior: 'smooth' })}
						>{contactBtnLabel}</button>
					{/if}
					{#if homeBlockEnabled.signupBtn}
						<a href="/login/customer" class="btn btn-outline" style={layout?.main_layout?.signup_btn_color ? `color: ${layout.main_layout.signup_btn_color}; border-color: ${layout.main_layout.signup_btn_color}` : undefined}>{signupBtnLabel}</a>
					{/if}
					<button
						class="btn btn-outline"
						style={careersColors.team_login_btn ? `color: ${careersColors.team_login_btn}; border-color: ${careersColors.team_login_btn}` : undefined}
						on:click={goTeam}
					>{careersTeamLoginBtnText}</button>
				</div>
			</div>
			{#if homeBlockEnabled.logo}
				<div class="hero-logo-wrap">
					<div class="hero-blob b1"></div>
					<div class="hero-blob b2"></div>
					<div class="hero-blob b3"></div>
					<img class="hero-logo" src={layout?.main_layout?.hero_logo_url || '/icons/logo.png'} alt="Urban Market logo" />
				</div>
			{/if}
		</div>
		{#if trustBadges.length}
			<div class="hero-badges">
				{#each trustBadges as badge}
					<div class="badge">
						<span class="badge-icon">{badge.icon}</span>
						<div>
							<strong>{isAr ? badge.title_ar : badge.title}</strong>
							<p>{isAr ? badge.desc_ar : badge.desc}</p>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</section>

	<!-- About -->
	<section class="about" id="about" class:no-image={!aboutImages.length} style={layout?.about?.bg_color ? `background: ${layout.about.bg_color}` : undefined}>
		{#if aboutImages.length}
			<div class="about-img-wrap" style={layout?.about?.bg_color ? `background: ${layout.about.bg_color}` : undefined}>
				{#each aboutImages as img, i (img + i)}
					<img class="about-img" class:active={i === activeAboutImage} src={img} alt="Store front" />
				{/each}
			</div>
		{/if}
		<div class="about-text">
			{#if layout?.about?.enabled_blocks?.eyebrow !== false}
				<span class="eyebrow" style="color: {layout?.about?.eyebrow_color || '#c8912f'}">{layout?.about?.[isAr ? 'ar' : 'en']?.eyebrow ?? (isAr ? 'من نحن' : 'About Us')}</span>
			{/if}
			{#if layout?.about?.enabled_blocks?.heading !== false}
				<h2 style="color: {layout?.about?.heading_color || '#ffffff'}">{layout?.about?.[isAr ? 'ar' : 'en']?.heading ?? (isAr ? 'أكثر من مجرد متجر، إنها تجربة.' : "More Than a Store, It's an Experience.")}</h2>
			{/if}
			{#if layout?.about?.enabled_blocks?.text !== false}
				<p style="color: {layout?.about?.text_color || '#d7ded9'}">
					{layout?.about?.[isAr ? 'ar' : 'en']?.text ??
						(isAr
							? 'نجمع أفضل ما في الغذاء ونمط الحياة والاحتياجات اليومية تحت سقف واحد. نركز على الجودة والتنوع ورضا العملاء.'
							: 'We bring together the best of food, lifestyle and everyday essentials under one roof. Our focus is on quality, variety and customer satisfaction.')}
				</p>
			{/if}
		</div>
	</section>

	<!-- Categories -->
	{#if servicesVisible}
		<section class="categories" id="services">
			<div class="section-heading">
				{#if servicesBlockEnabled.heading}
					<span class="eyebrow" style="color: {layout?.services?.heading_color || '#c8912f'}">{servicesHeadingText}</span>
				{/if}
				{#if servicesBlockEnabled.tagline}
					<h2 style="color: {layout?.services?.tagline_color || '#1f3d2f'}">{servicesTaglineText}</h2>
				{/if}
			</div>
			<div class="category-grid" class:marquee={useMarqueeCategories}>
				{#if useMarqueeCategories}
					<div class="category-track">
						{#each [...enabledCategories, ...enabledCategories] as cat, i (cat.id + '-' + i)}
							<div class="category-card">
								{#if cat.image_url}
									<div class="category-img-wrap">
										<img src={cat.image_url} alt={isAr ? cat.title_ar : cat.title} />
									</div>
								{/if}
								<strong style="color: {cat.title_color || '#1f3d2f'}">{isAr ? cat.title_ar : cat.title}</strong>
								{#if isAr ? cat.subtitle_ar : cat.subtitle}
									<span class="category-subtitle" style="color: {cat.subtitle_color || '#c8912f'}">{isAr ? cat.subtitle_ar : cat.subtitle}</span>
								{/if}
								<p style="color: {cat.text_color || '#777777'}">{isAr ? cat.text_ar : cat.text}</p>
							</div>
						{/each}
					</div>
				{:else}
					{#each enabledCategories as cat (cat.id)}
						<div class="category-card">
							{#if cat.image_url}
								<div class="category-img-wrap">
									<img src={cat.image_url} alt={isAr ? cat.title_ar : cat.title} />
								</div>
							{/if}
							<strong style="color: {cat.title_color || '#1f3d2f'}">{isAr ? cat.title_ar : cat.title}</strong>
							{#if isAr ? cat.subtitle_ar : cat.subtitle}
								<span class="category-subtitle" style="color: {cat.subtitle_color || '#c8912f'}">{isAr ? cat.subtitle_ar : cat.subtitle}</span>
							{/if}
							<p style="color: {cat.text_color || '#777777'}">{isAr ? cat.text_ar : cat.text}</p>
						</div>
					{/each}
				{/if}
			</div>
		</section>
	{/if}

	<!-- Why Choose Us -->
	{#if whyChooseVisible}
		<section class="why-choose" id="why-choose">
			<div class="section-heading">
				{#if whyChooseBlockEnabled.heading}
					<span class="eyebrow" style="color: {layout?.why_choose?.heading_color || '#c8912f'}">{whyChooseHeadingText}</span>
				{/if}
				{#if whyChooseBlockEnabled.tagline}
					<h2 style="color: {layout?.why_choose?.tagline_color || '#1f3d2f'}">{whyChooseTaglineText}</h2>
				{/if}
			</div>
			<div class="why-grid" class:marquee={useMarqueeFeatures}>
				{#if useMarqueeFeatures}
					<div class="why-track">
						{#each [...enabledFeatures, ...enabledFeatures] as feat, i (feat.id + '-' + i)}
							<div class="why-item">
								{#if feat.image_url}
									<img class="why-item-img" src={feat.image_url} alt={isAr ? feat.title_ar : feat.title} />
								{:else if feat.icon}
									<span class="why-icon" style="color: {feat.icon_color || '#c8912f'}">{feat.icon}</span>
								{/if}
								<strong style="color: {feat.text_color || '#1f3d2f'}">{isAr ? feat.title_ar : feat.title}</strong>
								<p style="color: {feat.text_color || '#777777'}">{isAr ? feat.desc_ar : feat.desc}</p>
							</div>
						{/each}
					</div>
				{:else}
					{#each enabledFeatures as feat (feat.id)}
						<div class="why-item">
							{#if feat.image_url}
								<img class="why-item-img" src={feat.image_url} alt={isAr ? feat.title_ar : feat.title} />
							{:else if feat.icon}
								<span class="why-icon" style="color: {feat.icon_color || '#c8912f'}">{feat.icon}</span>
							{/if}
							<strong style="color: {feat.text_color || '#1f3d2f'}">{isAr ? feat.title_ar : feat.title}</strong>
							<p style="color: {feat.text_color || '#777777'}">{isAr ? feat.desc_ar : feat.desc}</p>
						</div>
					{/each}
				{/if}
			</div>
		</section>
	{/if}

	<!-- Highlights -->
	{#if galleryVisible}
		<section class="highlights" id="gallery">
			<div class="section-heading">
				{#if galleryBlockEnabled.heading}
					<span class="eyebrow" style="color: {layout?.gallery?.heading_color || '#c8912f'}">{galleryHeadingText}</span>
				{/if}
				{#if galleryBlockEnabled.tagline}
					<h2 style="color: {layout?.gallery?.tagline_color || '#1f3d2f'}">{galleryTaglineText}</h2>
				{/if}
			</div>
			<div class="highlight-grid" class:marquee={useMarqueeGallery}>
				{#if useMarqueeGallery}
					<div class="highlight-track">
						{#each [...enabledGalleryItems, ...enabledGalleryItems] as item, i (item.id + '-' + i)}
							<div class="highlight-item">
								<img src={item.image_url} alt={isAr ? item.title_ar || item.title : item.title || 'Highlight'} />
								{#if (isAr ? item.title_ar : item.title) || (isAr ? item.subtitle_ar : item.subtitle) || (isAr ? item.text_ar : item.text)}
									<div class="highlight-caption">
										{#if isAr ? item.title_ar : item.title}
											<strong style="color: {item.title_color || '#1f3d2f'}">{isAr ? item.title_ar : item.title}</strong>
										{/if}
										{#if isAr ? item.subtitle_ar : item.subtitle}
											<span class="highlight-subtitle" style="color: {item.subtitle_color || '#c8912f'}">{isAr ? item.subtitle_ar : item.subtitle}</span>
										{/if}
										{#if isAr ? item.text_ar : item.text}
											<p style="color: {item.text_color || '#777777'}">{isAr ? item.text_ar : item.text}</p>
										{/if}
									</div>
								{/if}
							</div>
						{/each}
					</div>
				{:else}
					{#each enabledGalleryItems as item (item.id)}
						<div class="highlight-item">
							<img src={item.image_url} alt={isAr ? item.title_ar || item.title : item.title || 'Highlight'} />
							{#if (isAr ? item.title_ar : item.title) || (isAr ? item.subtitle_ar : item.subtitle) || (isAr ? item.text_ar : item.text)}
								<div class="highlight-caption">
									{#if isAr ? item.title_ar : item.title}
										<strong style="color: {item.title_color || '#1f3d2f'}">{isAr ? item.title_ar : item.title}</strong>
									{/if}
									{#if isAr ? item.subtitle_ar : item.subtitle}
										<span class="highlight-subtitle" style="color: {item.subtitle_color || '#c8912f'}">{isAr ? item.subtitle_ar : item.subtitle}</span>
									{/if}
									{#if isAr ? item.text_ar : item.text}
										<p style="color: {item.text_color || '#777777'}">{isAr ? item.text_ar : item.text}</p>
									{/if}
								</div>
							{/if}
						</div>
					{/each}
				{/if}
			</div>
		</section>
	{/if}

	<!-- Offers -->
	{#if offersVisible}
		<section class="offers" id="offers">
			{#if offersBlockEnabled.heading || offersBlockEnabled.tagline}
				<div class="section-heading">
					{#if offersBlockEnabled.heading}
						<span class="eyebrow" style="color: {layout?.offers?.heading_color || '#c8912f'}">{offersHeadingText}</span>
					{/if}
					{#if offersBlockEnabled.tagline}
						<h2 style="color: {layout?.offers?.tagline_color || '#1f3d2f'}">{offersTaglineText}</h2>
					{/if}
				</div>
			{/if}
			<div
				class="offer-grid"
				class:marquee={useMarqueeOffers}
				bind:this={offerTrackEl}
				on:mouseenter={() => (offerAutoScrollPaused = true)}
				on:mouseleave={() => (offerAutoScrollPaused = false)}
				on:pointerdown={handleOfferPointerDown}
				on:pointermove={handleOfferPointerMove}
				on:pointerup={handleOfferPointerUp}
				on:pointercancel={handleOfferPointerUp}
			>
				{#each (useMarqueeOffers ? [...validOffers, ...validOffers] : validOffers) as offer, i (offer.id + '-' + i)}
					<div class="offer-card" on:click={handleOfferCardClick}>
						<div class="offer-thumb">
							{#if offer.thumbnail_url}
								<img src={offer.thumbnail_url} alt={getOfferName(offer)} draggable="false" />
							{:else}
								<span class="offer-thumb-placeholder">🏷️</span>
							{/if}
						</div>
						<h3>{getOfferName(offer)}</h3>
						{#if offer.branch}
							<p class="offer-branch">
								📍 {getOfferBranchName(offer)}
								{#if getOfferBranchLocation(offer)}<span> · {getOfferBranchLocation(offer)}</span>{/if}
								{#if offer.branch.location_url}
									<a href={offer.branch.location_url} target="_blank" rel="noopener noreferrer" class="offer-branch-link">🗺️</a>
								{/if}
							</p>
						{/if}
						<button class="offer-download-btn" type="button" on:click={() => handleOfferDownload(offer)}>
							⬇️ {isAr ? 'تحميل' : 'Download'}
						</button>
					</div>
				{/each}
			</div>
		</section>
	{/if}

	<!-- Careers -->
	<section class="careers" id="careers">
		<div class="section-heading">
			<span class="eyebrow" style={careersColors.heading ? `color: ${careersColors.heading}` : undefined}>{careersHeadingText}</span>
			<h2 style={careersColors.tagline ? `color: ${careersColors.tagline}` : undefined}>{careersTaglineText}</h2>
		</div>
		<div class="careers-grid">
			{#if vacanciesVisible}
				<div class="vacancies">
					<h3 style={careersColors.vacancies_heading ? `color: ${careersColors.vacancies_heading}` : undefined}>
						{careersVacanciesHeadingText}
					</h3>
					{#each jobVacancies as job (job.id)}
						<div class="vacancy-card">
							<div>
								<strong style={careersColors.vacancy_title ? `color: ${careersColors.vacancy_title}` : undefined}>
									{getVacancyTitle(job)}
								</strong>
								<p style={careersColors.vacancy_detail ? `color: ${careersColors.vacancy_detail}` : undefined}>
									{[getVacancyDept(job), getVacancyType(job), getVacancyLocation(job)].filter(Boolean).join(' · ')}
								</p>
							</div>
							<button class="btn btn-outline btn-sm" on:click={() => applyToVacancy(job)}>
								{getVacancyButtonText(job)}
							</button>
						</div>
					{/each}
				</div>
			{/if}
			<div class="cv-form" id="cv-form">
				<h3 style={careersColors.form_heading ? `color: ${careersColors.form_heading}` : undefined}>{careersCvFormHeadingText}</h3>
				{#if applicationSubmitted}
					<p class="cv-success">{careersSuccessMessageText}</p>
				{/if}
				{#if applicationError}
					<p class="cv-error">{applicationError}</p>
				{/if}
				<form on:submit={handleApply}>
					<div class="field-wrap">
						<label class="field-label" for="name-field">{getCareersLabel('full_name')}</label>
						<input type="text" id="name-field" bind:value={applicantName} required />
					</div>
					<div class="field-wrap">
						<label class="field-label" for="nationality-field">{getCareersLabel('nationality')}</label>
						<input type="text" id="nationality-field" bind:value={applicantNationality} required />
					</div>
					<div class="field-wrap">
						<label class="field-label" for="position-field">{getCareersLabel('position')}</label>
						<input
							type="text"
							id="position-field"
							placeholder={getCareersPlaceholder('position') || 'e.g. Store Manager'}
							bind:value={applicantPosition}
						/>
					</div>
					<div class="field-wrap">
						<label class="field-label" for="dob-field">{getCareersLabel('dob')}</label>
						<input
							type="date"
							id="dob-field"
							bind:value={applicantDob}
							required
						/>
					</div>
					<div class="field-wrap">
						<label class="field-label" for="email-field">{getCareersLabel('email')}</label>
						<input type="email" id="email-field" bind:value={applicantEmail} required />
					</div>
					<div class="field-wrap">
						<label class="field-label" for="whatsapp-field">{getCareersLabel('whatsapp')}</label>
						<input type="tel" id="whatsapp-field" bind:value={applicantWhatsapp} required />
					</div>
					<div class="field-wrap">
						<label class="field-label" for="other-contact-field">{getCareersLabel('other_contact')}</label>
						<input type="tel" id="other-contact-field" bind:value={applicantOtherContact} />
					</div>
					<div class="field-wrap">
						<label class="field-label" for="cv-file-field">{getCareersLabel('cv_upload')}</label>
						<input
							type="file"
							id="cv-file-field"
							accept=".pdf,.doc,.docx"
							on:change={handleCvFileChange}
							bind:this={cvFileInputEl}
							hidden
						/>
						<input
							type="file"
							id="cv-camera-field"
							accept="image/*"
							capture="environment"
							on:change={handleCvFileChange}
							bind:this={cvCameraInputEl}
							hidden
						/>
						<div class="cv-upload-row">
							<button type="button" class="cv-upload-btn" title="Choose document" aria-label="Choose document" on:click={triggerCvFilePicker}>
								<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
									<path d="M14 2v6h6" />
									<line x1="16" y1="13" x2="8" y2="13" />
									<line x1="16" y1="17" x2="8" y2="17" />
									<line x1="10" y1="9" x2="8" y2="9" />
								</svg>
							</button>
							<button type="button" class="cv-upload-btn" title="Take photo" aria-label="Take photo" on:click={triggerCvCameraPicker}>
								<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
									<circle cx="12" cy="13" r="4" />
								</svg>
							</button>
							{#if applicantCvFile}
								<span class="cv-upload-filename">{applicantCvFile.name}</span>
							{/if}
						</div>
					</div>
					<div class="field-wrap">
						<label class="field-label" for="message-field">{getCareersLabel('message')}</label>
						<textarea
							id="message-field"
							rows="3"
							bind:value={applicantMessage}
						></textarea>
					</div>
					<button
						type="submit"
						class="btn btn-primary"
						style={careersColors.button_text ? `color: ${careersColors.button_text}` : undefined}
						disabled={applicationSubmitting}
					>
						{applicationSubmitting ? '…' : careersSubmitBtnText}
					</button>
				</form>
			</div>
		</div>
		<div class="team-login-row">
			{#if careersTeamLoginTaglineEnabled}
				<span style={careersColors.team_login_tagline ? `color: ${careersColors.team_login_tagline}` : undefined}>
					{careersTeamLoginTaglineText}
				</span>
			{/if}
			<button
				class="btn-team-login"
				style={careersColors.team_login_btn ? `background: ${careersColors.team_login_btn}; border-color: ${careersColors.team_login_btn}; color: #ffffff;` : undefined}
				on:click={goTeam}
			>
				{careersTeamLoginBtnText}
			</button>
		</div>
	</section>

	<!-- Contact -->
	{#if contactSectionVisible}
		<section class="contact" id="contact" style={layout?.contact?.bg_color ? `background: ${layout.contact.bg_color}` : undefined}>
			<div class="contact-text">
				<span
					class="eyebrow light"
					style={layout?.contact?.heading_color ? `color: ${layout.contact.heading_color}` : undefined}
				>
					{contactHeadingText}
				</span>
				<h2 style={layout?.contact?.tagline_color ? `color: ${layout.contact.tagline_color}` : undefined}>
					{contactTaglineText}
				</h2>
				{#if contactPhoneValid || contactEmailValid}
					<ul class="contact-list">
						{#if contactPhoneValid}
							<li><span>📞</span> <a class="contact-link" href={contactPhoneHref}>{contactPhoneRaw}</a></li>
						{/if}
						{#if contactEmailValid}
							{#each validContactEmails as emailAddr (emailAddr)}
								<li><span>✉️</span> <a class="contact-link" href={`mailto:${emailAddr}`}>{emailAddr}</a></li>
							{/each}
						{/if}
					</ul>
				{/if}
				{#if contactBranchesValid}
					<h3 class="contact-branches-heading">{contactBranchesHeadingText}</h3>
					<div class="branch-dropdown" bind:this={branchDropdownRef}>
						<button
							type="button"
							class="branch-dropdown-toggle"
							on:click={toggleBranchDropdown}
							aria-expanded={branchDropdownOpen}
							aria-haspopup="listbox"
						>
							<span class="branch-dropdown-toggle-icon">
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
									<circle cx="12" cy="10" r="3"/>
								</svg>
							</span>
							<span class="branch-dropdown-toggle-text">{branchDropdownDisplayText}</span>
							<svg
								class="branch-dropdown-chevron"
								class:open={branchDropdownOpen}
								width="16"
								height="16"
								viewBox="0 0 24 24"
								fill="none"
								stroke="currentColor"
								stroke-width="2"
							>
								<path d="M6 9l6 6 6-6"/>
							</svg>
						</button>
						{#if branchDropdownOpen}
							<ul class="branch-dropdown-menu" role="listbox">
								{#each validBranches as b (b.id)}
									<li
										class="branch-dropdown-item"
										role="option"
										aria-selected={selectedBranchId === b.id}
										tabindex="0"
										on:click={() => selectBranch(b)}
										on:keydown={(e) => {
											if (e.key === 'Enter' || e.key === ' ') {
												e.preventDefault();
												selectBranch(b);
											}
										}}
									>
										<span class="branch-item-icon">
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
												<circle cx="12" cy="10" r="3"/>
											</svg>
										</span>
										<span class="branch-item-text">
											<span class="branch-item-name">{getBranchDisplayLabel(b)}</span>
										</span>
										{#if branchHasLocationUrl(b)}
											<a
												class="branch-item-link"
												href={b.location_url}
												target="_blank"
												rel="noopener noreferrer"
												on:click={closeBranchDropdown}
												aria-label={isAr ? 'فتح الموقع على الخريطة' : 'Open location on map'}
												title={isAr ? 'فتح الموقع على الخريطة' : 'Open location on map'}
											>
												<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
													<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
													<path d="M15 3h6v6"/>
													<path d="M10 14L21 3"/>
												</svg>
											</a>
										{/if}
									</li>
								{/each}
							</ul>
						{/if}
					</div>
					{#if selectedSocialLinks}
						<div class="branch-social-row">
							{#each socialPlatforms as platform (platform.key)}
								{@const url = selectedSocialLinks[platform.key]}
								{#if url}
									<button
										type="button"
										class="social-icon-btn"
										on:click={() => openSocialLink(url, platform.key)}
										title={getSocialLabel(platform.key)}
									>
										<span class="social-icon-circle">
											<img
												src={platform.icon}
												alt={getSocialLabel(platform.key)}
												style={platform.scale ? `transform: scale(${platform.scale})` : ''}
											/>
										</span>
										<span class="social-icon-label">{getSocialLabel(platform.key)}</span>
									</button>
								{/if}
							{/each}
						</div>
					{:else if selectedBranchId}
						<p class="no-social-links">{isAr ? 'لا توجد روابط تواصل اجتماعي لهذا الفرع' : 'No social links available for this branch'}</p>
					{/if}
				{/if}
			</div>
		</section>
	{/if}

	<!-- Footer -->
	<footer class="footer" style={layout?.footer?.bg_color ? `background: ${layout.footer.bg_color}` : undefined}>
		<div class="footer-bottom">
			<span>{footerCopyrightText}</span>
			<div>
				<a href="/privacy">Privacy Policy</a>
			</div>
		</div>
	</footer>

	{#if whatsappVisible}
		<a
			class="whatsapp-float"
			href={whatsappLink}
			target="_blank"
			rel="noopener noreferrer"
			aria-label="Chat with us on WhatsApp"
			title="Chat with us on WhatsApp"
		>
			<svg viewBox="0 0 24 24" width="30" height="30" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
				<path
					fill="#ffffff"
					d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347zm-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884zm8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413z"
				/>
			</svg>
		</a>
	{/if}
</div>

<style>
	:global(body) {
		margin: 0;
	}

	:global(html),
	:global(body) {
		overflow-x: hidden;
	}

	.page,
	.page *,
	.page *::before,
	.page *::after {
		box-sizing: border-box;
	}

	.page {
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
		color: #2a2a2a;
		background: #f7f2e9;
		position: relative;
	}

	.page::before {
		content: '';
		position: fixed;
		inset: 0;
		z-index: -1;
		background:
			radial-gradient(circle at 12% 15%, rgba(31, 61, 47, 0.35), transparent 40%),
			radial-gradient(circle at 85% 8%, rgba(200, 145, 47, 0.35), transparent 40%),
			radial-gradient(circle at 30% 70%, rgba(200, 145, 47, 0.2), transparent 45%),
			radial-gradient(circle at 90% 85%, rgba(31, 61, 47, 0.3), transparent 45%),
			#f7f2e9;
		filter: blur(70px);
	}

	.page section[id] {
		scroll-margin-top: 100px;
	}

	.eyebrow {
		display: block;
		color: #c8912f;
		font-weight: 700;
		letter-spacing: 1px;
		text-transform: uppercase;
		font-size: 0.85rem;
		margin-bottom: 0.5rem;
	}

	.eyebrow.light {
		color: #e8c273;
	}

	.section-heading {
		text-align: center;
		max-width: 640px;
		margin: 0 auto 3rem;
	}

	.section-heading h2 {
		font-size: 2rem;
		margin: 0;
		color: #1f3d2f;
	}

	/* Header */
	.header {
		background: linear-gradient(
			180deg,
			rgba(50, 50, 50, 0.92) 0%,
			rgba(10, 10, 10, 0.95) 55%,
			rgba(0, 0, 0, 0.97) 100%
		);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.12);
		position: sticky;
		top: 0;
		z-index: 20;
	}

	.header-inner {
		width: 100%;
		margin: 0 auto;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 2.5rem;
		position: relative;
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 700;
		font-size: 1.2rem;
		color: #ffffff;
	}

	.logo-badge {
		display: flex;
		align-items: center;
		justify-content: center;
		background: #ffffff;
		border-radius: 10px;
		padding: 0.4rem 0.9rem;
		box-shadow: 0 4px 14px rgba(0, 0, 0, 0.12);
	}

	.logo-icon-img {
		height: 28px;
		width: auto;
		object-fit: contain;
	}

	.nav {
		display: flex;
		gap: 2rem;
	}

	.nav a {
		color: #d8d8d8;
		text-decoration: none;
		font-size: 0.95rem;
		padding-bottom: 0.35rem;
		border-bottom: 2px solid transparent;
	}

	.nav a.active,
	.nav a:hover {
		color: #ffffff;
		border-bottom-color: #c8912f;
	}

	.lang-toggle-btn {
		background: rgba(255, 255, 255, 0.1);
		border: 1.5px solid rgba(255, 255, 255, 0.35);
		border-radius: 20px;
		color: #ffffff;
		font-size: 0.85rem;
		font-weight: 600;
		padding: 0.35rem 0.9rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.lang-toggle-btn:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.menu-toggle {
		display: none;
		align-items: center;
		justify-content: center;
		background: rgba(255, 255, 255, 0.08);
		border: 1.5px solid rgba(255, 255, 255, 0.3);
		border-radius: 8px;
		color: #ffffff;
		font-size: 0.9rem;
		font-weight: 600;
		padding: 0.5rem 1rem;
		cursor: pointer;
	}

	.btn-team-login {
		background: rgba(200, 145, 47, 0.12);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		color: #c8912f;
		border: 1.5px solid rgba(200, 145, 47, 0.6);
		padding: 0.5rem 1.1rem;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-team-login:hover {
		background: #c8912f;
		color: #161616;
		filter: brightness(1.1);
	}

	/* Hero */
	.hero {
		background: transparent;
		padding: 4rem 2rem 0;
	}

	.hero-inner {
		max-width: 1440px;
		margin: 0 auto;
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 3rem;
		align-items: center;
	}

	.hero-text h1 {
		font-size: 2.8rem;
		line-height: 1.2;
		margin: 0 0 1.25rem;
		color: #1f3d2f;
	}

	.hero-text .accent {
		color: #c8912f;
	}

	.hero-text p {
		color: #555;
		max-width: 480px;
		margin-bottom: 2rem;
		line-height: 1.6;
	}

	.hero-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.btn {
		padding: 0.85rem 1.8rem;
		border-radius: 10px;
		font-weight: 600;
		cursor: pointer;
		border: 1.5px solid rgba(31, 61, 47, 0.5);
		font-size: 0.95rem;
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		display: inline-block;
		text-decoration: none;
	}

	.btn-primary {
		background: rgba(31, 61, 47, 0.75);
		color: #ffffff;
		border-color: rgba(31, 61, 47, 0.8);
	}

	.btn-outline {
		background: rgba(255, 255, 255, 0.25);
		color: #1f3d2f;
	}

	.hero-logo-wrap {
		position: relative;
		height: 340px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.hero-logo {
		position: relative;
		z-index: 1;
		max-width: 70%;
		max-height: 280px;
		object-fit: contain;
		filter: drop-shadow(0 20px 35px rgba(31, 61, 47, 0.25));
		animation: float 4s ease-in-out infinite;
	}

	.hero-blob {
		position: absolute;
		border-radius: 50%;
		filter: blur(30px);
	}

	.hero-blob.b1 {
		width: 220px;
		height: 220px;
		background: rgba(31, 61, 47, 0.25);
		top: 10%;
		left: 15%;
	}

	.hero-blob.b2 {
		width: 180px;
		height: 180px;
		background: rgba(200, 145, 47, 0.3);
		bottom: 10%;
		right: 10%;
	}

	.hero-blob.b3 {
		width: 140px;
		height: 140px;
		background: rgba(31, 61, 47, 0.15);
		bottom: 25%;
		left: 30%;
	}

	@keyframes float {
		0%,
		100% {
			transform: translateY(0);
		}
		50% {
			transform: translateY(-16px);
		}
	}

	.hero-badges {
		max-width: 1440px;
		margin: 3rem auto 0;
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1.5rem;
		padding: 2rem 0;
	}

	.badge {
		display: flex;
		gap: 0.75rem;
		align-items: flex-start;
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 14px;
		padding: 1.1rem;
		box-shadow: 0 8px 24px rgba(31, 61, 47, 0.08);
	}

	.badge-icon {
		color: #c8912f;
		font-size: 1.2rem;
	}

	.badge strong {
		display: block;
		color: #1f3d2f;
		margin-bottom: 0.2rem;
	}

	.badge p {
		margin: 0;
		font-size: 0.85rem;
		color: #777;
	}

	/* About */
	.about {
		background: rgba(31, 61, 47, 0.55);
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border: 1px solid rgba(255, 255, 255, 0.12);
		color: #ffffff;
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 2.5rem;
		align-items: center;
		max-width: 1440px;
		margin: 3rem auto;
		padding: 4rem 2rem;
		border-radius: 24px;
		box-shadow: 0 16px 40px rgba(0, 0, 0, 0.12);
	}

	.about.no-image {
		grid-template-columns: 1fr;
	}

	.about-img-wrap {
		position: relative;
		width: 100%;
		height: 280px;
		border-radius: 6px;
		overflow: hidden;
	}

	.about-img {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		object-fit: contain;
		opacity: 0;
		transition: opacity 1s ease;
	}

	.about-img.active {
		opacity: 1;
	}

	.about-text h2 {
		font-size: 1.9rem;
		margin: 0 0 1rem;
	}

	.about-text p {
		color: #d7ded9;
		line-height: 1.6;
	}

	/* Categories */
	.categories {
		max-width: 1440px;
		margin: 0 auto;
		padding: 5rem 2rem;
	}

	.category-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 1.5rem;
	}

	.category-grid.marquee {
		display: block;
		overflow: hidden;
	}

	.category-track {
		display: flex;
		gap: 1.5rem;
		width: max-content;
		animation: category-scroll 40s linear infinite;
	}

	.category-track .category-card {
		flex: 0 0 220px;
	}

	@keyframes category-scroll {
		from {
			transform: translateX(0);
		}
		to {
			transform: translateX(-50%);
		}
	}

	.category-card {
		text-align: center;
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 16px;
		padding: 1.25rem;
		box-shadow: 0 10px 28px rgba(31, 61, 47, 0.08);
	}

	.category-img-wrap {
		position: relative;
		margin-bottom: 1rem;
	}

	.category-img-wrap img {
		width: 100%;
		height: 140px;
		object-fit: cover;
		border-radius: 6px;
	}

	.category-subtitle {
		display: block;
		font-size: 0.78rem;
		font-weight: 600;
		margin-bottom: 0.35rem;
	}

	.category-card strong {
		display: block;
		color: #1f3d2f;
		margin-bottom: 0.35rem;
	}

	.category-card p {
		font-size: 0.85rem;
		color: #777;
		margin: 0;
	}


	/* Why choose */
	.why-choose {
		background: transparent;
		padding: 5rem 2rem;
	}

	.why-grid {
		max-width: 1440px;
		margin: 0 auto;
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 1.5rem;
		text-align: center;
	}

	.why-grid.marquee {
		display: block;
		overflow: hidden;
	}

	.why-track {
		display: flex;
		gap: 1.5rem;
		width: max-content;
		animation: why-scroll 40s linear infinite;
	}

	.why-track .why-item {
		flex: 0 0 220px;
	}

	@keyframes why-scroll {
		from {
			transform: translateX(0);
		}
		to {
			transform: translateX(-50%);
		}
	}

	.why-item {
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 16px;
		padding: 1.5rem 1.1rem;
		box-shadow: 0 10px 28px rgba(31, 61, 47, 0.08);
	}

	.why-icon {
		font-size: 1.6rem;
		display: block;
		margin-bottom: 0.75rem;
	}

	.why-item-img {
		width: 100%;
		height: 110px;
		object-fit: cover;
		border-radius: 10px;
		margin-bottom: 0.75rem;
	}

	.why-item strong {
		display: block;
		color: #1f3d2f;
		margin-bottom: 0.35rem;
	}

	.why-item p {
		font-size: 0.85rem;
		color: #777;
		margin: 0;
	}

	/* Highlights */
	.highlights {
		max-width: 1440px;
		margin: 0 auto;
		padding: 5rem 2rem;
	}

	.highlight-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 1rem;
	}

	.highlight-grid.marquee {
		display: block;
		overflow: hidden;
	}

	.highlight-track {
		display: flex;
		gap: 1rem;
		width: max-content;
		animation: highlight-scroll 40s linear infinite;
	}

	.highlight-track .highlight-item {
		flex: 0 0 220px;
	}

	@keyframes highlight-scroll {
		from {
			transform: translateX(0);
		}
		to {
			transform: translateX(-50%);
		}
	}

	.highlight-item {
		position: relative;
	}

	.highlight-item img {
		width: 100%;
		height: 150px;
		object-fit: cover;
		border-radius: 6px;
		display: block;
	}

	.highlight-caption {
		padding: 0.5rem 0.1rem 0;
	}

	.highlight-caption strong {
		display: block;
		color: #1f3d2f;
		font-size: 0.9rem;
	}

	.highlight-subtitle {
		display: block;
		font-size: 0.78rem;
		font-weight: 600;
		margin-top: 0.15rem;
	}

	.highlight-caption p {
		font-size: 0.8rem;
		color: #777;
		margin: 0.2rem 0 0;
	}

	/* Offers */
	.offers {
		max-width: 1440px;
		margin: 0 auto;
		padding: 5rem 2rem;
	}

	.offer-grid {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 1.5rem;
	}

	.offer-grid .offer-card {
		flex: 0 1 300px;
	}

	.offer-grid.marquee {
		display: flex;
		gap: 1.5rem;
		overflow-x: auto;
		overflow-y: hidden;
		scrollbar-width: none;
		cursor: grab;
		touch-action: pan-y;
		user-select: none;
	}

	.offer-grid.marquee::-webkit-scrollbar {
		display: none;
	}

	.offer-grid.marquee:active {
		cursor: grabbing;
	}

	.offer-grid.marquee .offer-card {
		flex: 0 0 300px;
	}

	.offer-card {
		position: relative;
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 16px;
		padding: 1.5rem 1.25rem;
		box-shadow: 0 10px 28px rgba(31, 61, 47, 0.08);
		text-align: left;
	}

	.offer-thumb {
		width: 100%;
		height: 380px;
		border-radius: 10px;
		overflow: hidden;
		background: rgba(31, 61, 47, 0.06);
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 0.9rem;
	}

	.offer-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		pointer-events: none;
	}

	.offer-thumb-placeholder {
		font-size: 2rem;
		opacity: 0.4;
	}

	.offer-card h3 {
		margin: 0 0 0.5rem;
		font-size: 1.05rem;
		color: #1f3d2f;
	}

	.offer-branch {
		font-size: 0.82rem;
		color: #555;
		margin: 0 0 0.9rem;
	}

	.offer-branch-link {
		margin-left: 0.35rem;
		text-decoration: none;
	}

	.offer-download-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		background: #c8912f;
		color: #fff;
		border: none;
		border-radius: 999px;
		padding: 0.5rem 1.1rem;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.offer-download-btn:hover {
		background: #b17f28;
	}

	/* Careers */
	.careers {
		max-width: 1440px;
		margin: 0 auto;
		padding: 5rem 2rem;
	}

	.careers-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 3rem;
	}

	.careers-grid:has(.cv-form:only-child) {
		grid-template-columns: 1fr;
		max-width: 640px;
		margin: 0 auto;
	}

	.careers-grid h3 {
		color: #1f3d2f;
		margin: 0 0 1.25rem;
		font-size: 1.2rem;
	}

	.vacancy-card {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 14px;
		padding: 1rem 1.25rem;
		margin-bottom: 1rem;
		box-shadow: 0 8px 22px rgba(31, 61, 47, 0.08);
	}

	.vacancy-card strong {
		display: block;
		color: #1f3d2f;
		margin-bottom: 0.25rem;
	}

	.vacancy-card p {
		margin: 0;
		font-size: 0.8rem;
		color: #777;
	}

	.btn-sm {
		padding: 0.5rem 1rem;
		font-size: 0.85rem;
		white-space: nowrap;
	}

	.cv-form form {
		display: flex;
		flex-direction: column;
		gap: 0.85rem;
	}

	.cv-form {
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 18px;
		padding: 1.75rem;
		box-shadow: 0 10px 28px rgba(31, 61, 47, 0.08);
	}

	.cv-form input,
	.cv-form select,
	.cv-form textarea {
		padding: 0.7rem 0.9rem;
		border: 1px solid rgba(31, 61, 47, 0.15);
		border-radius: 8px;
		font-family: inherit;
		font-size: 0.9rem;
		background: rgba(255, 255, 255, 0.6);
	}

	.cv-form textarea {
		resize: vertical;
	}

	.field-wrap {
		position: relative;
	}

	.field-wrap input,
	.field-wrap textarea,
	.field-wrap select {
		width: 100%;
		box-sizing: border-box;
	}

	.field-label {
		position: absolute;
		top: -0.55rem;
		left: 0.7rem;
		background: rgba(247, 242, 233, 0.95);
		padding: 0 0.35rem;
		font-size: 0.72rem;
		color: #888;
		pointer-events: none;
		border-radius: 4px;
	}

	.cv-upload-row {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.55rem 0.9rem;
		border: 1px solid rgba(31, 61, 47, 0.15);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.6);
	}

	.cv-upload-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 34px;
		height: 34px;
		flex-shrink: 0;
		border: 1px solid rgba(31, 61, 47, 0.2);
		border-radius: 8px;
		background: rgba(31, 61, 47, 0.06);
		color: #1f3d2f;
		cursor: pointer;
		transition: background 0.2s ease, transform 0.15s ease;
	}

	.cv-upload-btn:hover {
		background: rgba(31, 61, 47, 0.14);
		transform: translateY(-1px);
	}

	.cv-upload-filename {
		font-size: 0.82rem;
		color: #555;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.cv-success {
		background: rgba(231, 245, 236, 0.7);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		border: 1px solid rgba(31, 61, 47, 0.15);
		color: #1f3d2f;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		font-size: 0.9rem;
		margin-bottom: 1rem;
	}

	.cv-error {
		background: rgba(200, 40, 40, 0.08);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		border: 1px solid rgba(200, 40, 40, 0.2);
		color: #a12;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		font-size: 0.9rem;
		margin-bottom: 1rem;
	}

	.team-login-row {
		max-width: 1440px;
		margin: 3rem auto 0;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.85rem;
		font-size: 0.85rem;
		color: #777;
	}

	/* Contact */
	.contact {
		position: relative;
		z-index: 3;
		background: rgba(31, 61, 47, 0.55);
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border: 1px solid rgba(255, 255, 255, 0.12);
		color: #ffffff;
		max-width: 900px;
		margin: 3rem auto;
		padding: 4rem 2rem;
		display: flex;
		justify-content: center;
		text-align: center;
		border-radius: 24px;
		box-shadow: 0 16px 40px rgba(0, 0, 0, 0.12);
	}

	.contact-text h2 {
		font-size: 1.8rem;
		margin: 0 0 1.25rem;
	}

	.contact-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
	}

	.contact-list li {
		display: flex;
		gap: 0.75rem;
		align-items: center;
		justify-content: center;
		color: #d7ded9;
		font-size: 0.9rem;
	}

	.contact-link {
		color: inherit;
		text-decoration: none;
	}

	.contact-link:hover {
		text-decoration: underline;
	}

	.contact-branches-heading {
		margin: 1.5rem 0 0.75rem;
		font-size: 1rem;
		font-weight: 700;
		color: #ffffff;
	}

	.branch-dropdown {
		position: relative;
		margin-top: 1.1rem;
		width: 100%;
		max-width: 380px;
		margin-left: auto;
		margin-right: auto;
		text-align: start;
	}

	.branch-dropdown-toggle {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 0.6rem;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.25);
		color: #ffffff;
		padding: 0.75rem 1rem;
		border-radius: 12px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s ease, border-color 0.2s ease;
	}

	.branch-dropdown-toggle:hover {
		background: rgba(255, 255, 255, 0.14);
		border-color: rgba(255, 255, 255, 0.4);
	}

	.branch-dropdown-toggle-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		color: #c8912f;
		flex-shrink: 0;
	}

	.branch-dropdown-toggle-text {
		flex: 1;
		text-align: start;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.branch-dropdown-chevron {
		flex-shrink: 0;
		transition: transform 0.2s ease;
		opacity: 0.8;
	}

	.branch-dropdown-chevron.open {
		transform: rotate(180deg);
	}

	.branch-dropdown-menu {
		list-style: none;
		margin: 0.5rem 0 0;
		padding: 0.4rem;
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		z-index: 30;
		max-height: 280px;
		overflow-y: auto;
		background: rgba(20, 24, 22, 0.97);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 12px;
		box-shadow: 0 20px 45px rgba(0, 0, 0, 0.35);
	}

	.branch-dropdown-item {
		display: flex;
		align-items: center;
		gap: 0.65rem;
		padding: 0.65rem 0.6rem;
		border-radius: 8px;
		text-align: start;
		transition: background 0.15s ease;
	}

	.branch-dropdown-item:hover {
		background: rgba(255, 255, 255, 0.08);
	}

	.branch-dropdown-item + .branch-dropdown-item {
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.branch-item-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		color: #c8912f;
		flex-shrink: 0;
	}

	.branch-item-text {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.1rem;
		min-width: 0;
	}

	.branch-item-name {
		font-size: 0.88rem;
		font-weight: 600;
		color: #ffffff;
	}

	.branch-item-location {
		font-size: 0.76rem;
		color: #b9c2bd;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.branch-item-link {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 30px;
		height: 30px;
		border-radius: 8px;
		flex-shrink: 0;
		color: #ffffff;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		text-decoration: none;
		transition: background 0.2s ease;
	}

	.branch-item-link:hover {
		background: rgba(200, 145, 47, 0.35);
		border-color: rgba(200, 145, 47, 0.6);
	}

	.branch-social-row {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		align-items: flex-start;
		gap: 1.1rem;
		margin-top: 1.25rem;
	}

	.social-icon-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.4rem;
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		color: #ffffff;
		width: 68px;
	}

	.social-icon-circle {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 52px;
		height: 52px;
		border-radius: 50%;
		background: #ffffff;
		overflow: hidden;
		box-shadow: 0 6px 16px rgba(0, 0, 0, 0.18);
		border: 1px solid rgba(255, 255, 255, 0.3);
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}

	.social-icon-btn:hover .social-icon-circle {
		transform: translateY(-3px);
		box-shadow: 0 10px 22px rgba(200, 145, 47, 0.35);
	}

	.social-icon-circle img {
		width: 34px;
		height: 34px;
		object-fit: contain;
	}

	.social-icon-label {
		font-size: 0.72rem;
		font-weight: 600;
		color: #e6e9e7;
		text-align: center;
		line-height: 1.1;
	}

	.no-social-links {
		margin-top: 1rem;
		font-size: 0.8rem;
		color: #b9c2bd;
		text-align: center;
	}

	.whatsapp-float {
		position: fixed;
		left: 1.5rem;
		bottom: 1.5rem;
		z-index: 9999;
		width: 58px;
		height: 58px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #25d366;
		border-radius: 50%;
		box-shadow: 0 6px 18px rgba(0, 0, 0, 0.25);
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}

	.whatsapp-float:hover {
		transform: scale(1.08);
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.32);
	}

	@media (max-width: 720px) {
		.whatsapp-float {
			left: 1rem;
			bottom: 1rem;
			width: 52px;
			height: 52px;
		}
	}

	/* Footer */
	.footer {
		position: relative;
		z-index: 1;
		background: rgba(17, 17, 17, 0.6);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border-top: 1px solid rgba(255, 255, 255, 0.08);
		color: #cfcfcf;
		padding: 4rem 2rem 1.5rem;
	}

	.footer-bottom {
		max-width: 1440px;
		margin: 0 auto;
		display: flex;
		justify-content: space-between;
		font-size: 0.8rem;
	}

	.footer-bottom a {
		color: #b8b8b8;
		text-decoration: none;
		margin-left: 1.25rem;
	}

	@media (max-width: 960px) {
		.hero-inner {
			grid-template-columns: 1fr;
		}

		.hero-logo-wrap {
			height: 260px;
		}

		.about {
			grid-template-columns: 1fr;
		}

		.category-grid,
		.why-grid,
		.highlight-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.careers-grid {
			grid-template-columns: 1fr;
		}

		.hero-badges {
			grid-template-columns: 1fr;
		}

		.header-inner {
			flex-wrap: wrap;
			gap: 1rem;
		}

		.nav {
			flex-wrap: wrap;
			gap: 1rem;
		}
	}

	@media (max-width: 600px) {
		.page section[id] {
			scroll-margin-top: 70px;
		}

		.header-inner {
			padding: 0.85rem 1.25rem;
			flex-wrap: nowrap;
		}

		.menu-toggle {
			display: flex;
		}

		.nav {
			display: none;
			position: absolute;
			top: 100%;
			left: 0;
			right: 0;
			flex-direction: column;
			gap: 0;
			background: rgba(10, 10, 10, 0.97);
			backdrop-filter: blur(16px);
			-webkit-backdrop-filter: blur(16px);
			border-bottom: 1px solid rgba(255, 255, 255, 0.1);
			padding: 0.5rem 1.25rem 1rem;
		}

		.nav.open {
			display: flex;
		}

		.nav a {
			padding: 0.75rem 0;
			border-bottom: 1px solid rgba(255, 255, 255, 0.08);
		}

		.nav a:last-child {
			border-bottom: none;
		}

		.hero {
			padding: 2.5rem 1.25rem 0;
		}

		.hero-text h1 {
			font-size: 2rem;
		}

		.hero-text p {
			max-width: 100%;
		}

		.hero-actions {
			flex-direction: column;
			align-items: stretch;
		}

		.hero-actions .btn {
			text-align: center;
		}

		.hero-logo-wrap {
			height: 200px;
		}

		.hero-badges {
			padding: 1.25rem 0;
		}

		.about,
		.contact {
			margin: 2rem auto;
			padding: 2.5rem 1.25rem;
			border-radius: 16px;
		}

		.about {
			text-align: center;
		}

		.categories,
		.why-choose,
		.highlights,
		.offers,
		.careers {
			padding: 3rem 1.25rem;
		}

		.category-grid,
		.why-grid,
		.highlight-grid,
		.offer-grid {
			grid-template-columns: 1fr;
		}

		.section-heading {
			margin: 0 auto 2rem;
		}

		.section-heading h2 {
			font-size: 1.5rem;
		}

		.vacancy-card {
			flex-direction: column;
			align-items: stretch;
			text-align: center;
		}

		.vacancy-card .btn-sm {
			width: 100%;
		}

		.cv-form {
			padding: 1.25rem;
		}

		.team-login-row {
			flex-direction: column;
			gap: 0.5rem;
			text-align: center;
		}

		.footer-grid {
			grid-template-columns: 1fr;
			gap: 2.5rem;
		}

		.footer-bottom {
			flex-direction: column;
			gap: 0.75rem;
			text-align: center;
		}

		.footer-bottom a {
			margin: 0 0.6rem;
		}

		.newsletter-form {
			flex-direction: column;
		}

		.newsletter-form input {
			border-radius: 8px;
		}

		.newsletter-form button {
			border-radius: 8px;
			padding: 0.6rem 1rem;
			margin-top: 0.5rem;
		}
	}
</style>
