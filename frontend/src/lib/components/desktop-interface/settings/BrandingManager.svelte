<script lang="ts">
	import { onMount } from 'svelte';
	import { iconUrlMap, loadIcons } from '$lib/stores/iconStore';
	import { supabase } from '$lib/utils/supabase';
	import { formatPolicyContent } from '$lib/utils/formatPolicyContent';

	type BrandingTab = 'login-page' | 'app-logos' | 'privacy-policy';

	let activeTab: BrandingTab = 'login-page';

	// Company name (bilingual) - the single source of truth used across the public login,
	// customer login, mobile login and privacy pages instead of hardcoded brand strings.
	let companyNameEn = '';
	let companyNameAr = '';

	const loginPageSections = [
		{ id: 'topbar', icon: '🧭', label: 'Top Bar and Layouts' },
		{ id: 'home', icon: '🏠', label: 'Home' },
		{ id: 'about', icon: 'ℹ️', label: 'About' },
		{ id: 'services', icon: '🛒', label: 'Services' },
		{ id: 'why-choose', icon: '⭐', label: 'Why Choose Us' },
		{ id: 'gallery', icon: '🖼️', label: 'Gallery' },
		{ id: 'offers', icon: '🏷️', label: 'Offers' },
		{ id: 'careers', icon: '💼', label: 'Careers' },
		{ id: 'contact', icon: '☎️', label: 'Contact' },
		{ id: 'footer', icon: '🔻', label: 'Bottom' }
	];

	let activeLoginSection = loginPageSections[0].id;

	onMount(() => {
		loadIcons();
		loadLoginLayout();
		loadJobVacancies();
		loadCvApplications();

		const vacanciesChannel = supabase
			.channel('branding:career_job_vacancies')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'career_job_vacancies' }, () => {
				loadJobVacancies();
			})
			.subscribe();

		const cvChannel = supabase
			.channel('branding:career_cv_applications')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'career_cv_applications' }, () => {
				loadCvApplications();
			})
			.subscribe();

		return () => {
			supabase.removeChannel(vacanciesChannel);
			supabase.removeChannel(cvChannel);
		};
	});

	// login_layout wiring - load/save state
	let layoutLoading = true;
	let savingSection: string | null = null;
	let saveMessage: Record<string, string> = {};

	async function loadLoginLayout() {
		layoutLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_login_layout');
			if (error) throw error;
			if (data) {
				if (data.company) {
					companyNameEn = data.company.name_en ?? companyNameEn;
					companyNameAr = data.company.name_ar ?? companyNameAr;
				}
				if (data.topbar) {
					topBarColor = data.topbar.bg_color ?? topBarColor;
					topBarLogoEnabled = data.topbar.logo_enabled ?? topBarLogoEnabled;
					topBarLogoUrl = data.topbar.logo_url ?? topBarLogoUrl;
				}
				if (data.about) {
					aboutBgColor = data.about.bg_color ?? aboutBgColor;
					if (Array.isArray(data.about.images) && data.about.images.length) {
						const loaded: AboutSlide[] = data.about.images
							.filter(Boolean)
							.map((it: any) =>
								typeof it === 'string' ? { url: it, enabled: true } : { url: it.url, enabled: it.enabled ?? true }
							);
						const slots: (AboutSlide | null)[] = Array(MAX_ABOUT_IMAGES).fill(null);
						loaded.slice(0, MAX_ABOUT_IMAGES).forEach((slide, i) => {
							slots[i] = slide;
						});
						aboutSlides = slots;
					} else if (data.about.image_url) {
						const slots: (AboutSlide | null)[] = Array(MAX_ABOUT_IMAGES).fill(null);
						slots[0] = { url: data.about.image_url, enabled: true };
						aboutSlides = slots;
					}
					const aboutEn = data.about.en || {};
					const aboutAr = data.about.ar || {};
					aboutEyebrow = aboutEn.eyebrow ?? aboutEyebrow;
					aboutEyebrowAr = aboutAr.eyebrow ?? aboutEyebrowAr;
					aboutHeading = aboutEn.heading ?? aboutHeading;
					aboutHeadingAr = aboutAr.heading ?? aboutHeadingAr;
					aboutText = aboutEn.text ?? aboutText;
					aboutTextAr = aboutAr.text ?? aboutTextAr;
					aboutEyebrowColor = data.about.eyebrow_color ?? aboutEyebrowColor;
					aboutHeadingColor = data.about.heading_color ?? aboutHeadingColor;
					aboutTextColor = data.about.text_color ?? aboutTextColor;
					aboutNavLabel = aboutEn.nav_label ?? aboutNavLabel;
					aboutNavLabelAr = aboutAr.nav_label ?? aboutNavLabelAr;
					aboutNavColor = data.about.nav_color ?? aboutNavColor;
					if (data.about.enabled_blocks) {
						aboutBlockEnabled = { ...aboutBlockEnabled, ...data.about.enabled_blocks };
					}
				}
				if (data.contact) {
					contactBgColor = data.contact.bg_color ?? contactBgColor;
					const ctEn = data.contact.en || {};
					const ctAr = data.contact.ar || {};
					contactHeading = ctEn.heading ?? contactHeading;
					contactHeadingAr = ctAr.heading ?? contactHeadingAr;
					contactTagline = ctEn.tagline ?? contactTagline;
					contactTaglineAr = ctAr.tagline ?? contactTaglineAr;
					contactBranchesHeading = ctEn.branches_heading ?? contactBranchesHeading;
					contactBranchesHeadingAr = ctAr.branches_heading ?? contactBranchesHeadingAr;
					contactHeadingColor = data.contact.heading_color ?? contactHeadingColor;
					contactTaglineColor = data.contact.tagline_color ?? contactTaglineColor;
					contactNavLabel = ctEn.nav_label ?? contactNavLabel;
					contactNavLabelAr = ctAr.nav_label ?? contactNavLabelAr;
					contactNavColor = data.contact.nav_color ?? contactNavColor;
					contactNavEnabled = data.contact.nav_enabled ?? contactNavEnabled;
					contactPhone = data.contact.phone ?? contactPhone;
					if (Array.isArray(data.contact.emails) && data.contact.emails.length) {
						contactEmails = [...data.contact.emails];
					} else if (data.contact.email) {
						contactEmails = [data.contact.email];
					}
				}
				if (data.footer) {
					footerBgColor = data.footer.bg_color ?? footerBgColor;
					footerCopyrightText = data.footer.en?.copyright ?? footerCopyrightText;
					footerCopyrightTextAr = data.footer.ar?.copyright ?? footerCopyrightTextAr;
				}
				if (data.privacy_policy) {
					privacyPolicyContentEn = data.privacy_policy.en?.content ?? privacyPolicyContentEn;
					privacyPolicyContentAr = data.privacy_policy.ar?.content ?? privacyPolicyContentAr;
				}
				if (data.main_layout) {
					mainLayoutBgColor = data.main_layout.bg_color ?? mainLayoutBgColor;
					navButtonTextColor = data.main_layout.nav_button_color ?? navButtonTextColor;
					mainTagHighlightColor = data.main_layout.headline_highlight_color ?? mainTagHighlightColor;
					mainTagTextColor = data.main_layout.headline_text_color ?? mainTagTextColor;
					mainTagHighlightTarget = data.main_layout.headline_highlight_target ?? mainTagHighlightTarget;
					taglineTextColor = data.main_layout.tagline_color ?? taglineTextColor;
					contactBtnColor = data.main_layout.contact_btn_color ?? contactBtnColor;
					signupBtnColor = data.main_layout.signup_btn_color ?? signupBtnColor;
					heroLogoUrl = data.main_layout.hero_logo_url ?? heroLogoUrl;
				}
				if (data.home_content) {
					const en = data.home_content.en || {};
					const ar = data.home_content.ar || {};
					navButtonLabel = en.nav_label ?? navButtonLabel;
					navButtonLabelAr = ar.nav_label ?? navButtonLabelAr;
					mainTagHighlightWord = en.headline_highlight ?? mainTagHighlightWord;
					mainTagHighlightWordAr = ar.headline_highlight ?? mainTagHighlightWordAr;
					mainTagPrefix = en.headline_prefix ?? mainTagPrefix;
					mainTagPrefixAr = ar.headline_prefix ?? mainTagPrefixAr;
					mainTagSuffix = en.headline_suffix ?? mainTagSuffix;
					mainTagSuffixAr = ar.headline_suffix ?? mainTagSuffixAr;
					taglineText = en.tagline ?? taglineText;
					taglineTextAr = ar.tagline ?? taglineTextAr;
					contactBtnLabel = en.contact_btn_label ?? contactBtnLabel;
					contactBtnLabelAr = ar.contact_btn_label ?? contactBtnLabelAr;
					signupBtnLabel = en.signup_btn_label ?? signupBtnLabel;
					signupBtnLabelAr = ar.signup_btn_label ?? signupBtnLabelAr;
					if (Array.isArray(data.home_content.badges) && data.home_content.badges.length) {
						badges = data.home_content.badges.map((b: any) => ({
							id: b.id ?? `badge-${Date.now()}-${Math.random()}`,
							icon: b.icon ?? '⭐',
							title: b.title ?? '',
							titleAr: b.title_ar ?? '',
							desc: b.desc ?? '',
							descAr: b.desc_ar ?? '',
							enabled: b.enabled ?? true,
							lang: 'EN'
						}));
					}
					if (data.home_content.enabled_blocks) {
						homeBlockEnabled = { ...homeBlockEnabled, ...data.home_content.enabled_blocks };
					}
				}
				if (data.services) {
					const svcEn = data.services.en || {};
					const svcAr = data.services.ar || {};
					servicesHeading = svcEn.heading ?? servicesHeading;
					servicesHeadingAr = svcAr.heading ?? servicesHeadingAr;
					servicesTagline = svcEn.tagline ?? servicesTagline;
					servicesTaglineAr = svcAr.tagline ?? servicesTaglineAr;
					servicesHeadingColor = data.services.heading_color ?? servicesHeadingColor;
					servicesTaglineColor = data.services.tagline_color ?? servicesTaglineColor;
					servicesNavLabel = svcEn.nav_label ?? servicesNavLabel;
					servicesNavLabelAr = svcAr.nav_label ?? servicesNavLabelAr;
					servicesNavColor = data.services.nav_color ?? servicesNavColor;
					if (data.services.enabled_blocks) {
						servicesBlockEnabled = { ...servicesBlockEnabled, ...data.services.enabled_blocks };
					}
					if (Array.isArray(data.services.categories)) {
						categories = data.services.categories.map((c: any) => ({
							id: c.id ?? makeCategoryId(),
							image_url: c.image_url ?? null,
							title: c.title ?? '',
							title_ar: c.title_ar ?? '',
							subtitle: c.subtitle ?? '',
							subtitle_ar: c.subtitle_ar ?? '',
							text: c.text ?? '',
							text_ar: c.text_ar ?? '',
							title_color: c.title_color ?? '#1f3d2f',
							subtitle_color: c.subtitle_color ?? '#c8912f',
							text_color: c.text_color ?? '#777777',
							enabled: c.enabled ?? true,
							lang: 'EN'
						}));
					}
				}
				if (data.why_choose) {
					const whyEn = data.why_choose.en || {};
					const whyAr = data.why_choose.ar || {};
					whyChooseHeading = whyEn.heading ?? whyChooseHeading;
					whyChooseHeadingAr = whyAr.heading ?? whyChooseHeadingAr;
					whyChooseTagline = whyEn.tagline ?? whyChooseTagline;
					whyChooseTaglineAr = whyAr.tagline ?? whyChooseTaglineAr;
					whyChooseHeadingColor = data.why_choose.heading_color ?? whyChooseHeadingColor;
					whyChooseTaglineColor = data.why_choose.tagline_color ?? whyChooseTaglineColor;
					if (data.why_choose.enabled_blocks) {
						whyChooseBlockEnabled = { ...whyChooseBlockEnabled, ...data.why_choose.enabled_blocks };
					}
					if (Array.isArray(data.why_choose.features)) {
						features = data.why_choose.features.map((f: any) => ({
							id: f.id ?? makeFeatureId(),
							icon: f.icon ?? '⭐',
							image_url: f.image_url ?? null,
							title: f.title ?? '',
							title_ar: f.title_ar ?? '',
							desc: f.desc ?? '',
							desc_ar: f.desc_ar ?? '',
							icon_color: f.icon_color ?? '#c8912f',
							text_color: f.text_color ?? '#1f3d2f',
							enabled: f.enabled ?? true,
							lang: 'EN'
						}));
					}
				}
				if (data.gallery) {
					const galEn = data.gallery.en || {};
					const galAr = data.gallery.ar || {};
					galleryHeading = galEn.heading ?? galleryHeading;
					galleryHeadingAr = galAr.heading ?? galleryHeadingAr;
					galleryTagline = galEn.tagline ?? galleryTagline;
					galleryTaglineAr = galAr.tagline ?? galleryTaglineAr;
					galleryHeadingColor = data.gallery.heading_color ?? galleryHeadingColor;
					galleryTaglineColor = data.gallery.tagline_color ?? galleryTaglineColor;
					galleryNavLabel = galEn.nav_label ?? galleryNavLabel;
					galleryNavLabelAr = galAr.nav_label ?? galleryNavLabelAr;
					galleryNavColor = data.gallery.nav_color ?? galleryNavColor;
					if (data.gallery.enabled_blocks) {
						galleryBlockEnabled = { ...galleryBlockEnabled, ...data.gallery.enabled_blocks };
					}
					if (Array.isArray(data.gallery.items)) {
						galleryItems = data.gallery.items.map((g: any) => ({
							id: g.id ?? makeGalleryItemId(),
							image_url: g.image_url ?? null,
							title: g.title ?? '',
							title_ar: g.title_ar ?? '',
							subtitle: g.subtitle ?? '',
							subtitle_ar: g.subtitle_ar ?? '',
							text: g.text ?? '',
							text_ar: g.text_ar ?? '',
							title_color: g.title_color ?? '#1f3d2f',
							subtitle_color: g.subtitle_color ?? '#c8912f',
							text_color: g.text_color ?? '#777777',
							enabled: g.enabled ?? true,
							lang: 'EN'
						}));
					}
				}
				if (data.offers) {
					const offEn = data.offers.en || {};
					const offAr = data.offers.ar || {};
					offersHeading = offEn.heading ?? offersHeading;
					offersHeadingAr = offAr.heading ?? offersHeadingAr;
					offersTagline = offEn.tagline ?? offersTagline;
					offersTaglineAr = offAr.tagline ?? offersTaglineAr;
					offersHeadingColor = data.offers.heading_color ?? offersHeadingColor;
					offersTaglineColor = data.offers.tagline_color ?? offersTaglineColor;
					offersNavLabel = offEn.nav_label ?? offersNavLabel;
					offersNavLabelAr = offAr.nav_label ?? offersNavLabelAr;
					offersNavColor = data.offers.nav_color ?? offersNavColor;
					if (data.offers.enabled_blocks) {
						offersBlockEnabled = { ...offersBlockEnabled, ...data.offers.enabled_blocks };
					}
				}
				if (data.careers) {
					const cEn = data.careers.en || {};
					const cAr = data.careers.ar || {};
					careersHeading = cEn.heading ?? careersHeading;
					careersHeadingAr = cAr.heading ?? careersHeadingAr;
					careersTagline = cEn.tagline ?? careersTagline;
					careersTaglineAr = cAr.tagline ?? careersTaglineAr;
					careersCvFormHeading = cEn.cv_form_heading ?? careersCvFormHeading;
					careersCvFormHeadingAr = cAr.cv_form_heading ?? careersCvFormHeadingAr;
					careersVacanciesHeading = cEn.vacancies_heading ?? careersVacanciesHeading;
					careersVacanciesHeadingAr = cAr.vacancies_heading ?? careersVacanciesHeadingAr;
					careersSubmitBtn = cEn.submit_btn ?? careersSubmitBtn;
					careersSubmitBtnAr = cAr.submit_btn ?? careersSubmitBtnAr;
					careersApplyBtn = cEn.apply_btn ?? careersApplyBtn;
					careersApplyBtnAr = cAr.apply_btn ?? careersApplyBtnAr;
					careersSuccessMessage = cEn.success_message ?? careersSuccessMessage;
					careersSuccessMessageAr = cAr.success_message ?? careersSuccessMessageAr;
					careersErrorMessage = cEn.error_message ?? careersErrorMessage;
					careersErrorMessageAr = cAr.error_message ?? careersErrorMessageAr;
					careersTeamLoginTagline = cEn.team_login_tagline ?? careersTeamLoginTagline;
					careersTeamLoginTaglineAr = cAr.team_login_tagline ?? careersTeamLoginTaglineAr;
					careersTeamLoginBtn = cEn.team_login_btn ?? careersTeamLoginBtn;
					careersTeamLoginBtnAr = cAr.team_login_btn ?? careersTeamLoginBtnAr;
					careersTeamLoginTaglineEnabled = data.careers.team_login_tagline_enabled ?? careersTeamLoginTaglineEnabled;
					careersNavLabel = cEn.nav_label ?? careersNavLabel;
					careersNavLabelAr = cAr.nav_label ?? careersNavLabelAr;
					careersNavColor = data.careers.nav_color ?? careersNavColor;
					careersNavEnabled = data.careers.nav_enabled ?? careersNavEnabled;
					if (cEn.labels) careersLabelsEn = { ...careersLabelsEn, ...cEn.labels };
					if (cAr.labels) careersLabelsAr = { ...careersLabelsAr, ...cAr.labels };
					if (cEn.placeholders) careersPlaceholdersEn = { ...careersPlaceholdersEn, ...cEn.placeholders };
					if (cAr.placeholders) careersPlaceholdersAr = { ...careersPlaceholdersAr, ...cAr.placeholders };
					if (data.careers.colors) careersColors = { ...careersColors, ...data.careers.colors };
				}
			}
		} catch (e: any) {
			console.error('Failed to load login layout:', e);
		} finally {
			layoutLoading = false;
		}
	}

	async function saveLoginLayoutSection(section: string, data: Record<string, unknown>) {
		savingSection = section;
		saveMessage = { ...saveMessage, [section]: '' };
		try {
			const { error } = await supabase.rpc('update_login_layout_section', {
				p_section: section,
				p_data: data
			});
			if (error) throw error;
			saveMessage = { ...saveMessage, [section]: '✅ Saved' };
		} catch (e: any) {
			console.error(`Failed to save ${section}:`, e);
			saveMessage = { ...saveMessage, [section]: '❌ Failed to save' };
		} finally {
			savingSection = null;
			setTimeout(() => {
				saveMessage = { ...saveMessage, [section]: '' };
			}, 2500);
		}
	}

	function saveTopBarAndLayout() {
		saveLoginLayoutSection('company', {
			name_en: companyNameEn,
			name_ar: companyNameAr
		});
		saveLoginLayoutSection('topbar', {
			bg_color: topBarColor,
			logo_enabled: topBarLogoEnabled,
			logo_url: topBarLogoUrl
		});
		saveLoginLayoutSection('main_layout', {
			bg_color: mainLayoutBgColor,
			nav_button_color: navButtonTextColor,
			headline_highlight_color: mainTagHighlightColor,
			headline_text_color: mainTagTextColor,
			headline_highlight_target: mainTagHighlightTarget,
			tagline_color: taglineTextColor,
			contact_btn_color: contactBtnColor,
			signup_btn_color: signupBtnColor,
			hero_logo_url: heroLogoUrl
		});
	}

	function saveAboutSection() {
		saveLoginLayoutSection('about', {
			bg_color: aboutBgColor,
			images: aboutSlides
				.filter((s): s is { url: string; enabled: boolean } => !!s)
				.map((s) => ({ url: s.url, enabled: s.enabled })),
			en: { eyebrow: aboutEyebrow, heading: aboutHeading, text: aboutText, nav_label: aboutNavLabel },
			ar: { eyebrow: aboutEyebrowAr, heading: aboutHeadingAr, text: aboutTextAr, nav_label: aboutNavLabelAr },
			eyebrow_color: aboutEyebrowColor,
			heading_color: aboutHeadingColor,
			text_color: aboutTextColor,
			nav_color: aboutNavColor,
			enabled_blocks: { ...aboutBlockEnabled }
		});
	}

	function saveContactSection() {
		const cleanEmails = contactEmails.map((e) => e.trim()).filter((e) => e.length > 0);
		saveLoginLayoutSection('contact', {
			bg_color: contactBgColor,
			en: { heading: contactHeading, tagline: contactTagline, branches_heading: contactBranchesHeading, nav_label: contactNavLabel },
			ar: { heading: contactHeadingAr, tagline: contactTaglineAr, branches_heading: contactBranchesHeadingAr, nav_label: contactNavLabelAr },
			heading_color: contactHeadingColor,
			tagline_color: contactTaglineColor,
			nav_color: contactNavColor,
			nav_enabled: contactNavEnabled,
			phone: contactPhone,
			emails: cleanEmails,
			email: cleanEmails[0] ?? ''
		});
	}

	function saveFooterSection() {
		saveLoginLayoutSection('footer', {
			bg_color: footerBgColor,
			en: { copyright: footerCopyrightText },
			ar: { copyright: footerCopyrightTextAr }
		});
	}

	function savePrivacyPolicySection() {
		saveLoginLayoutSection('privacy_policy', {
			en: { content: privacyPolicyContentEn },
			ar: { content: privacyPolicyContentAr }
		});
	}

	function saveServicesSection() {
		saveLoginLayoutSection('services', {
			en: { heading: servicesHeading, tagline: servicesTagline, nav_label: servicesNavLabel },
			ar: { heading: servicesHeadingAr, tagline: servicesTaglineAr, nav_label: servicesNavLabelAr },
			heading_color: servicesHeadingColor,
			tagline_color: servicesTaglineColor,
			nav_color: servicesNavColor,
			enabled_blocks: { ...servicesBlockEnabled },
			categories: categories.map(({ lang, ...rest }) => rest)
		});
	}

	function saveWhyChooseSection() {
		saveLoginLayoutSection('why_choose', {
			en: { heading: whyChooseHeading, tagline: whyChooseTagline },
			ar: { heading: whyChooseHeadingAr, tagline: whyChooseTaglineAr },
			heading_color: whyChooseHeadingColor,
			tagline_color: whyChooseTaglineColor,
			enabled_blocks: { ...whyChooseBlockEnabled },
			features: features.map(({ lang, ...rest }) => rest)
		});
	}

	function saveGallerySection() {
		saveLoginLayoutSection('gallery', {
			en: { heading: galleryHeading, tagline: galleryTagline, nav_label: galleryNavLabel },
			ar: { heading: galleryHeadingAr, tagline: galleryTaglineAr, nav_label: galleryNavLabelAr },
			heading_color: galleryHeadingColor,
			tagline_color: galleryTaglineColor,
			nav_color: galleryNavColor,
			enabled_blocks: { ...galleryBlockEnabled },
			items: galleryItems.map(({ lang, ...rest }) => rest)
		});
	}

	function saveOffersSection() {
		saveLoginLayoutSection('offers', {
			en: { heading: offersHeading, tagline: offersTagline, nav_label: offersNavLabel },
			ar: { heading: offersHeadingAr, tagline: offersTaglineAr, nav_label: offersNavLabelAr },
			heading_color: offersHeadingColor,
			tagline_color: offersTaglineColor,
			nav_color: offersNavColor,
			enabled_blocks: { ...offersBlockEnabled }
		});
	}

	function saveCareersSection() {
		saveLoginLayoutSection('careers', {
			en: {
				heading: careersHeading,
				tagline: careersTagline,
				cv_form_heading: careersCvFormHeading,
				vacancies_heading: careersVacanciesHeading,
				submit_btn: careersSubmitBtn,
				apply_btn: careersApplyBtn,
				success_message: careersSuccessMessage,
				error_message: careersErrorMessage,
				team_login_tagline: careersTeamLoginTagline,
				team_login_btn: careersTeamLoginBtn,
				nav_label: careersNavLabel,
				labels: careersLabelsEn,
				placeholders: careersPlaceholdersEn
			},
			ar: {
				heading: careersHeadingAr,
				tagline: careersTaglineAr,
				cv_form_heading: careersCvFormHeadingAr,
				vacancies_heading: careersVacanciesHeadingAr,
				submit_btn: careersSubmitBtnAr,
				apply_btn: careersApplyBtnAr,
				success_message: careersSuccessMessageAr,
				error_message: careersErrorMessageAr,
				team_login_tagline: careersTeamLoginTaglineAr,
				team_login_btn: careersTeamLoginBtnAr,
				nav_label: careersNavLabelAr,
				labels: careersLabelsAr,
				placeholders: careersPlaceholdersAr
			},
			team_login_tagline_enabled: careersTeamLoginTaglineEnabled,
			nav_color: careersNavColor,
			nav_enabled: careersNavEnabled,
			colors: { ...careersColors }
		});
	}
	function saveHomeSection() {
		saveLoginLayoutSection('main_layout', {
			bg_color: mainLayoutBgColor,
			nav_button_color: navButtonTextColor,
			headline_highlight_color: mainTagHighlightColor,
			headline_text_color: mainTagTextColor,
			headline_highlight_target: mainTagHighlightTarget,
			tagline_color: taglineTextColor,
			contact_btn_color: contactBtnColor,
			signup_btn_color: signupBtnColor,
			hero_logo_url: heroLogoUrl
		});
		saveLoginLayoutSection('home_content', {
			en: {
				nav_label: navButtonLabel,
				headline_prefix: mainTagPrefix,
				headline_highlight: mainTagHighlightWord,
				headline_suffix: mainTagSuffix,
				tagline: taglineText,
				contact_btn_label: contactBtnLabel,
				signup_btn_label: signupBtnLabel
			},
			ar: {
				nav_label: navButtonLabelAr,
				headline_prefix: mainTagPrefixAr,
				headline_highlight: mainTagHighlightWordAr,
				headline_suffix: mainTagSuffixAr,
				tagline: taglineTextAr,
				contact_btn_label: contactBtnLabelAr,
				signup_btn_label: signupBtnLabelAr
			},
			badges: badges.map((b) => ({
				id: b.id,
				icon: b.icon,
				title: b.title,
				title_ar: b.titleAr,
				desc: b.desc,
				desc_ar: b.descAr,
				enabled: b.enabled
			})),
			enabled_blocks: { ...homeBlockEnabled }
		});
	}

	// Home section content blocks - enable/disable + edit are UI only for now
	type HomeBlockId = 'navButton' | 'mainTag' | 'tagline' | 'contactBtn' | 'signupBtn' | 'logo';

	let homeBlockEnabled: Record<HomeBlockId, boolean> = {
		navButton: true,
		mainTag: true,
		tagline: true,
		contactBtn: true,
		signupBtn: true,
		logo: true
	};

	function toggleHomeBlock(id: HomeBlockId) {
		homeBlockEnabled[id] = !homeBlockEnabled[id];
	}

	function editHomeBlock(id: HomeBlockId) {
		// UI only for now - editing functionality will be added later
	}

	// Dual-language toggle (EN/AR) - shown near the Edit button on text blocks
	type LangBlockId = 'navButton' | 'mainTag' | 'tagline' | 'contactBtn' | 'signupBtn';

	let homeBlockLang: Record<LangBlockId, 'EN' | 'AR'> = {
		navButton: 'EN',
		mainTag: 'EN',
		tagline: 'EN',
		contactBtn: 'EN',
		signupBtn: 'EN'
	};

	function toggleHomeBlockLang(id: LangBlockId) {
		homeBlockLang[id] = homeBlockLang[id] === 'EN' ? 'AR' : 'EN';
	}

	// Main nav button name (the "Home" label shown in the top nav bar) - bilingual EN/AR
	let navButtonLabel = 'Home';
	let navButtonLabelAr = 'الرئيسية';
	let navButtonTextColor = '#1f3d2f';

	// Main tag (headline) - prefix + highlighted word + suffix, each bilingual EN/AR, plus colors
	let mainTagPrefix = 'Quality You Trust,';
	let mainTagPrefixAr = 'جودة تثق بها،';
	let mainTagHighlightWord = 'Experience';
	let mainTagHighlightWordAr = 'تجربة';
	let mainTagSuffix = 'You Love.';
	let mainTagSuffixAr = 'تحبها حقًا.';
	let mainTagTextColor = '#1f3d2f';
	let mainTagHighlightColor = '#c8912f';
	type MainTagHighlightTarget = 'prefix' | 'highlight' | 'suffix';
	let mainTagHighlightTarget: MainTagHighlightTarget = 'highlight';

	// Tagline (description) - bilingual EN/AR text + color
	let taglineText =
		'From fresh groceries to delicious meals, aromatic coffee, refreshing juices and stylish fashion – everything you need, all in one place.';
	let taglineTextAr =
		'من البقالة الطازجة إلى الوجبات اللذيذة والقهوة العطرة والعصائر المنعشة والأزياء الأنيقة – كل ما تحتاجه في مكان واحد.';
	let taglineTextColor = '#4b5563';

	// Hero action buttons - each is its own card with its own bilingual label + color picker
	let contactBtnLabel = 'Contact Us';
	let contactBtnLabelAr = 'تواصل معنا';
	let contactBtnColor = '#1f3d2f';
	let signupBtnLabel = 'Sign Up / Login';
	let signupBtnLabelAr = 'تسجيل الدخول / اشتراك';
	let signupBtnColor = '#1f3d2f';

	// Hero section image - separate from the Top Bar logo, managed here in the Home section.
	// Uploaded to the branding-docs bucket; falls back to the static /icons/logo.png file.
	let heroLogoUrl: string | null = null;
	let uploadingHeroLogo = false;

	async function uploadHeroLogo(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingHeroLogo = true;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/hero-logo-${Date.now()}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			heroLogoUrl = data.publicUrl;
		} catch (e: any) {
			console.error('Failed to upload hero logo:', e);
		} finally {
			uploadingHeroLogo = false;
			input.value = '';
		}
	}

	function removeHeroLogo() {
		heroLogoUrl = null;
	}

	// Trust badges - each is its own separate, editable card. Max 5 badges.
	type Badge = {
		id: string;
		icon: string;
		title: string;
		titleAr: string;
		desc: string;
		descAr: string;
		enabled: boolean;
		lang: 'EN' | 'AR';
	};

	const MAX_BADGES = 5;

	let badges: Badge[] = [
		{
			id: 'badge-1',
			icon: '✔',
			title: 'Fresh & Quality',
			titleAr: 'طازج وعالي الجودة',
			desc: 'Always fresh, always the best.',
			descAr: 'دائمًا طازج، دائمًا الأفضل.',
			enabled: true,
			lang: 'EN'
		},
		{
			id: 'badge-2',
			icon: '👥',
			title: 'Great Service',
			titleAr: 'خدمة رائعة',
			desc: 'We care for our customers.',
			descAr: 'نحن نهتم بعملائنا.',
			enabled: true,
			lang: 'EN'
		},
		{
			id: 'badge-3',
			icon: '🛡️',
			title: 'Trusted & Reliable',
			titleAr: 'موثوق وجدير بالثقة',
			desc: 'Quality you can depend on.',
			descAr: 'جودة يمكنك الاعتماد عليها.',
			enabled: true,
			lang: 'EN'
		}
	];

	let editingBadgeId: string | null = null;

	function toggleBadge(id: string) {
		badges = badges.map((b) => (b.id === id ? { ...b, enabled: !b.enabled } : b));
	}

	function toggleBadgeLang(id: string) {
		badges = badges.map((b) => (b.id === id ? { ...b, lang: b.lang === 'EN' ? 'AR' : 'EN' } : b));
	}

	function editBadge(id: string) {
		editingBadgeId = editingBadgeId === id ? null : id;
	}

	function updateBadgeField(id: string, field: 'icon' | 'title' | 'titleAr' | 'desc' | 'descAr', value: string) {
		badges = badges.map((b) => (b.id === id ? { ...b, [field]: value } : b));
	}

	function addBadge() {
		if (badges.length >= MAX_BADGES) return;
		badges = [
			...badges,
			{
				id: `badge-${Date.now()}`,
				icon: '⭐',
				title: 'New Badge',
				titleAr: 'شارة جديدة',
				desc: 'Badge description.',
				descAr: 'وصف الشارة.',
				enabled: true,
				lang: 'EN'
			}
		];
	}

	function removeBadge(id: string) {
		badges = badges.filter((b) => b.id !== id);
		if (editingBadgeId === id) editingBadgeId = null;
	}

	// Services / Categories section
	type ServiceCategory = {
		id: string;
		image_url: string | null;
		title: string;
		title_ar: string;
		subtitle: string;
		subtitle_ar: string;
		text: string;
		text_ar: string;
		title_color: string;
		subtitle_color: string;
		text_color: string;
		enabled: boolean;
		lang: 'EN' | 'AR';
	};

	let servicesHeading = 'Our Categories';
	let servicesHeadingAr = 'فئاتنا';
	let servicesTagline = 'Everything You Need, All in One Place';
	let servicesTaglineAr = 'كل ما تحتاجه في مكان واحد';
	let servicesHeadingColor = '#c8912f';
	let servicesTaglineColor = '#1f3d2f';
	let servicesNavLabel = 'Services';
	let servicesNavLabelAr = 'الخدمات';
	let servicesNavColor = '#1f3d2f';
	let servicesLang: 'EN' | 'AR' = 'EN';
	type ServicesBlockId = 'heading' | 'tagline' | 'navButton';
	let servicesBlockEnabled: Record<ServicesBlockId, boolean> = { heading: true, tagline: true, navButton: true };

	function toggleServicesLang() {
		servicesLang = servicesLang === 'EN' ? 'AR' : 'EN';
	}

	function toggleServicesBlock(id: ServicesBlockId) {
		servicesBlockEnabled = { ...servicesBlockEnabled, [id]: !servicesBlockEnabled[id] };
	}

	let categories: ServiceCategory[] = [];
	let editingCategoryId: string | null = null;
	let uploadingCategoryImageId: string | null = null;
	let categoryImageUploadError: string | null = null;

	function makeCategoryId() {
		return `cat-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
	}

	function addCategory() {
		categories = [
			...categories,
			{
				id: makeCategoryId(),
				image_url: null,
				title: 'New Category',
				title_ar: 'فئة جديدة',
				subtitle: '',
				subtitle_ar: '',
				text: '',
				text_ar: '',
				title_color: '#1f3d2f',
				subtitle_color: '#c8912f',
				text_color: '#777777',
				enabled: true,
				lang: 'EN'
			}
		];
		editingCategoryId = categories[categories.length - 1].id;
	}

	function removeCategory(id: string) {
		categories = categories.filter((c) => c.id !== id);
		if (editingCategoryId === id) editingCategoryId = null;
	}

	function editCategory(id: string) {
		editingCategoryId = editingCategoryId === id ? null : id;
	}

	function toggleCategoryLang(id: string) {
		categories = categories.map((c) => (c.id === id ? { ...c, lang: c.lang === 'EN' ? 'AR' : 'EN' } : c));
	}

	function toggleCategoryEnabled(id: string) {
		categories = categories.map((c) => (c.id === id ? { ...c, enabled: !c.enabled } : c));
	}

	function updateCategoryField(
		id: string,
		field: 'title' | 'title_ar' | 'subtitle' | 'subtitle_ar' | 'text' | 'text_ar' | 'title_color' | 'subtitle_color' | 'text_color',
		value: string
	) {
		categories = categories.map((c) => (c.id === id ? { ...c, [field]: value } : c));
	}

	async function uploadCategoryImage(event: Event, id: string) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingCategoryImageId = id;
		categoryImageUploadError = null;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/category-image-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			categories = categories.map((c) => (c.id === id ? { ...c, image_url: data.publicUrl } : c));
		} catch (e: any) {
			console.error('Failed to upload category image:', e);
			categoryImageUploadError = `Image upload failed: ${e?.message ?? 'unknown error'}. The image was NOT saved — try again.`;
		} finally {
			uploadingCategoryImageId = null;
			input.value = '';
		}
	}

	function removeCategoryImage(id: string) {
		categories = categories.map((c) => (c.id === id ? { ...c, image_url: null } : c));
	}

	// Why Choose Us / Features section
	type WhyChooseFeature = {
		id: string;
		icon: string;
		image_url: string | null;
		title: string;
		title_ar: string;
		desc: string;
		desc_ar: string;
		icon_color: string;
		text_color: string;
		enabled: boolean;
		lang: 'EN' | 'AR';
	};

	let whyChooseHeading = 'Why Choose Us';
	let whyChooseHeadingAr = 'لماذا تختارنا';
	let whyChooseTagline = "We're Committed to Making You Happy";
	let whyChooseTaglineAr = 'نحن ملتزمون بإسعادك';
	let whyChooseHeadingColor = '#c8912f';
	let whyChooseTaglineColor = '#1f3d2f';
	let whyChooseLang: 'EN' | 'AR' = 'EN';
	type WhyChooseBlockId = 'heading' | 'tagline';
	let whyChooseBlockEnabled: Record<WhyChooseBlockId, boolean> = { heading: true, tagline: true };

	function toggleWhyChooseLang() {
		whyChooseLang = whyChooseLang === 'EN' ? 'AR' : 'EN';
	}

	function toggleWhyChooseBlock(id: WhyChooseBlockId) {
		whyChooseBlockEnabled = { ...whyChooseBlockEnabled, [id]: !whyChooseBlockEnabled[id] };
	}

	let features: WhyChooseFeature[] = [];
	let editingFeatureId: string | null = null;
	let uploadingFeatureImageId: string | null = null;
	let featureImageUploadError: string | null = null;

	function makeFeatureId() {
		return `feat-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
	}

	function addFeature() {
		features = [
			...features,
			{
				id: makeFeatureId(),
				icon: '⭐',
				image_url: null,
				title: 'New Feature',
				title_ar: 'ميزة جديدة',
				desc: '',
				desc_ar: '',
				icon_color: '#c8912f',
				text_color: '#1f3d2f',
				enabled: true,
				lang: 'EN'
			}
		];
		editingFeatureId = features[features.length - 1].id;
	}

	function removeFeature(id: string) {
		features = features.filter((f) => f.id !== id);
		if (editingFeatureId === id) editingFeatureId = null;
	}

	function editFeature(id: string) {
		editingFeatureId = editingFeatureId === id ? null : id;
	}

	function toggleFeatureLang(id: string) {
		features = features.map((f) => (f.id === id ? { ...f, lang: f.lang === 'EN' ? 'AR' : 'EN' } : f));
	}

	function toggleFeatureEnabled(id: string) {
		features = features.map((f) => (f.id === id ? { ...f, enabled: !f.enabled } : f));
	}

	function updateFeatureField(
		id: string,
		field: 'icon' | 'icon_color' | 'title' | 'title_ar' | 'desc' | 'desc_ar' | 'text_color',
		value: string
	) {
		features = features.map((f) => (f.id === id ? { ...f, [field]: value } : f));
	}

	function moveFeature(id: string, direction: 'up' | 'down') {
		const idx = features.findIndex((f) => f.id === id);
		if (idx < 0) return;
		const swapIdx = direction === 'up' ? idx - 1 : idx + 1;
		if (swapIdx < 0 || swapIdx >= features.length) return;
		const copy = [...features];
		[copy[idx], copy[swapIdx]] = [copy[swapIdx], copy[idx]];
		features = copy;
	}

	async function uploadFeatureImage(event: Event, id: string) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingFeatureImageId = id;
		featureImageUploadError = null;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/feature-image-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			features = features.map((f) => (f.id === id ? { ...f, image_url: data.publicUrl } : f));
		} catch (e: any) {
			console.error('Failed to upload feature image:', e);
			featureImageUploadError = `Image upload failed: ${e?.message ?? 'unknown error'}. The image was NOT saved — try again.`;
		} finally {
			uploadingFeatureImageId = null;
			input.value = '';
		}
	}

	function removeFeatureImage(id: string) {
		features = features.map((f) => (f.id === id ? { ...f, image_url: null } : f));
	}

	// Gallery / Highlights section
	type GalleryItem = {
		id: string;
		image_url: string | null;
		title: string;
		title_ar: string;
		subtitle: string;
		subtitle_ar: string;
		text: string;
		text_ar: string;
		title_color: string;
		subtitle_color: string;
		text_color: string;
		enabled: boolean;
		lang: 'EN' | 'AR';
	};

	let galleryHeading = 'Highlights';
	let galleryHeadingAr = 'أبرز اللحظات';
	let galleryTagline = 'Moments That Inspire Us';
	let galleryTaglineAr = 'لحظات تلهمنا';
	let galleryHeadingColor = '#c8912f';
	let galleryTaglineColor = '#1f3d2f';
	let galleryNavLabel = 'Gallery';
	let galleryNavLabelAr = 'معرض الصور';
	let galleryNavColor = '#1f3d2f';
	let galleryLang: 'EN' | 'AR' = 'EN';
	type GalleryBlockId = 'heading' | 'tagline' | 'navButton';
	let galleryBlockEnabled: Record<GalleryBlockId, boolean> = { heading: true, tagline: true, navButton: true };

	function toggleGalleryLang() {
		galleryLang = galleryLang === 'EN' ? 'AR' : 'EN';
	}

	function toggleGalleryBlock(id: GalleryBlockId) {
		galleryBlockEnabled = { ...galleryBlockEnabled, [id]: !galleryBlockEnabled[id] };
	}

	let galleryItems: GalleryItem[] = [];
	let editingGalleryItemId: string | null = null;
	let uploadingGalleryImageId: string | null = null;
	let galleryImageUploadError: string | null = null;

	function makeGalleryItemId() {
		return `gal-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
	}

	function addGalleryItem() {
		galleryItems = [
			...galleryItems,
			{
				id: makeGalleryItemId(),
				image_url: null,
				title: '',
				title_ar: '',
				subtitle: '',
				subtitle_ar: '',
				text: '',
				text_ar: '',
				title_color: '#1f3d2f',
				subtitle_color: '#c8912f',
				text_color: '#777777',
				enabled: true,
				lang: 'EN'
			}
		];
		editingGalleryItemId = galleryItems[galleryItems.length - 1].id;
	}

	function removeGalleryItem(id: string) {
		galleryItems = galleryItems.filter((g) => g.id !== id);
		if (editingGalleryItemId === id) editingGalleryItemId = null;
	}

	function editGalleryItem(id: string) {
		editingGalleryItemId = editingGalleryItemId === id ? null : id;
	}

	function toggleGalleryItemLang(id: string) {
		galleryItems = galleryItems.map((g) => (g.id === id ? { ...g, lang: g.lang === 'EN' ? 'AR' : 'EN' } : g));
	}

	function toggleGalleryItemEnabled(id: string) {
		galleryItems = galleryItems.map((g) => (g.id === id ? { ...g, enabled: !g.enabled } : g));
	}

	function updateGalleryItemField(
		id: string,
		field:
			| 'title'
			| 'title_ar'
			| 'subtitle'
			| 'subtitle_ar'
			| 'text'
			| 'text_ar'
			| 'title_color'
			| 'subtitle_color'
			| 'text_color',
		value: string
	) {
		galleryItems = galleryItems.map((g) => (g.id === id ? { ...g, [field]: value } : g));
	}

	function moveGalleryItem(id: string, direction: 'up' | 'down') {
		const idx = galleryItems.findIndex((g) => g.id === id);
		if (idx < 0) return;
		const swapIdx = direction === 'up' ? idx - 1 : idx + 1;
		if (swapIdx < 0 || swapIdx >= galleryItems.length) return;
		const copy = [...galleryItems];
		[copy[idx], copy[swapIdx]] = [copy[swapIdx], copy[idx]];
		galleryItems = copy;
	}

	async function uploadGalleryImage(event: Event, id: string) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingGalleryImageId = id;
		galleryImageUploadError = null;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/gallery-image-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			galleryItems = galleryItems.map((g) => (g.id === id ? { ...g, image_url: data.publicUrl } : g));
		} catch (e: any) {
			console.error('Failed to upload gallery image:', e);
			galleryImageUploadError = `Image upload failed: ${e?.message ?? 'unknown error'}. The image was NOT saved — try again.`;
		} finally {
			uploadingGalleryImageId = null;
			input.value = '';
		}
	}

	function removeGalleryImage(id: string) {
		galleryItems = galleryItems.map((g) => (g.id === id ? { ...g, image_url: null } : g));
	}

	// Offers section - heading/tagline only; individual offer cards are NOT managed
	// here, they are pulled automatically (and live) from the Offers/Coupon module (view_offer table).
	let offersHeading = 'Special Offers';
	let offersHeadingAr = 'عروض خاصة';
	let offersTagline = "Deals You Don't Want to Miss";
	let offersTaglineAr = 'عروض لا تريد أن تفوتك';
	let offersHeadingColor = '#c8912f';
	let offersTaglineColor = '#1f3d2f';
	let offersNavLabel = 'Offers';
	let offersNavLabelAr = 'العروض';
	let offersNavColor = '#1f3d2f';
	let offersLang: 'EN' | 'AR' = 'EN';
	type OffersBlockId = 'heading' | 'tagline' | 'navButton';
	let offersBlockEnabled: Record<OffersBlockId, boolean> = { heading: true, tagline: true, navButton: true };

	function toggleOffersLang() {
		offersLang = offersLang === 'EN' ? 'AR' : 'EN';
	}

	function toggleOffersBlock(id: OffersBlockId) {
		offersBlockEnabled = { ...offersBlockEnabled, [id]: !offersBlockEnabled[id] };
	}

	// ===== Careers section: Job Ads, Received CVs, Headline Manager =====
	let careersSubTab: 'job-ads' | 'received-cvs' | 'headline' = 'job-ads';

	// -- Job Ads --
	let jobVacancies: any[] = [];
	let jobVacanciesLoading = false;
	let deletingVacancyId: string | null = null;
	let viewingVacancy: any = null;

	async function loadJobVacancies() {
		jobVacanciesLoading = true;
		try {
			const { data, error } = await supabase
				.from('career_job_vacancies')
				.select('*')
				.order('display_order', { ascending: true })
				.order('created_at', { ascending: false });
			if (error) throw error;
			jobVacancies = data || [];
		} catch (e) {
			console.error('Failed to load job vacancies:', e);
		} finally {
			jobVacanciesLoading = false;
		}
	}

	function openVacancyForm(id?: string) {
		const url = id ? `/careers-admin/job-vacancy-form?id=${id}` : '/careers-admin/job-vacancy-form';
		window.open(url, 'jobVacancyForm', 'width=980,height=820,resizable=yes,scrollbars=yes');
	}

	async function toggleVacancyEnabled(v: any) {
		try {
			const { error } = await supabase.from('career_job_vacancies').update({ enabled: !v.enabled }).eq('id', v.id);
			if (error) throw error;
			loadJobVacancies();
		} catch (e) {
			console.error('Failed to toggle vacancy:', e);
		}
	}

	async function deleteVacancy(id: string) {
		if (!confirm('Delete this job vacancy? This cannot be undone.')) return;
		deletingVacancyId = id;
		try {
			const { error } = await supabase.from('career_job_vacancies').delete().eq('id', id);
			if (error) throw error;
			loadJobVacancies();
		} catch (e) {
			console.error('Failed to delete vacancy:', e);
		} finally {
			deletingVacancyId = null;
		}
	}

	function viewVacancy(v: any) {
		viewingVacancy = v;
	}

	// -- Received CVs --
	let cvApplications: any[] = [];
	let cvApplicationsLoading = false;
	let viewingApplication: any = null;
	let editingNotesId: string | null = null;
	let notesDraft = '';
	let deletingApplicationId: string | null = null;
	const cvStatusOptions = ['New', 'Under Review', 'Shortlisted', 'Interview Scheduled', 'Selected', 'Rejected'];

	async function loadCvApplications() {
		cvApplicationsLoading = true;
		try {
			const { data, error } = await supabase
				.from('career_cv_applications')
				.select('*')
				.order('created_at', { ascending: false });
			if (error) throw error;
			cvApplications = data || [];
		} catch (e) {
			console.error('Failed to load CV applications:', e);
		} finally {
			cvApplicationsLoading = false;
		}
	}

	async function updateApplicationStatus(app: any, status: string) {
		try {
			const { error } = await supabase
				.from('career_cv_applications')
				.update({ status, updated_at: new Date().toISOString() })
				.eq('id', app.id);
			if (error) throw error;
			loadCvApplications();
		} catch (e) {
			console.error('Failed to update application status:', e);
		}
	}

	function startEditNotes(app: any) {
		editingNotesId = app.id;
		notesDraft = app.internal_notes || '';
	}

	async function saveNotes(app: any) {
		try {
			const { error } = await supabase
				.from('career_cv_applications')
				.update({ internal_notes: notesDraft, updated_at: new Date().toISOString() })
				.eq('id', app.id);
			if (error) throw error;
			editingNotesId = null;
			loadCvApplications();
		} catch (e) {
			console.error('Failed to save notes:', e);
		}
	}

	async function deleteApplication(id: string) {
		if (!confirm('Delete this application? This cannot be undone.')) return;
		deletingApplicationId = id;
		try {
			const { error } = await supabase.from('career_cv_applications').delete().eq('id', id);
			if (error) throw error;
			loadCvApplications();
		} catch (e) {
			console.error('Failed to delete application:', e);
		} finally {
			deletingApplicationId = null;
		}
	}

	function viewApplication(app: any) {
		viewingApplication = app;
	}

	function downloadCv(app: any) {
		if (app.cv_file_url) window.open(app.cv_file_url, '_blank', 'noopener,noreferrer');
	}

	// -- Headline Manager --
	const careersFieldKeys = [
		{ key: 'full_name', label: 'Full Name' },
		{ key: 'nationality', label: 'Nationality' },
		{ key: 'position', label: 'Position Applying For' },
		{ key: 'dob', label: 'Date of Birth' },
		{ key: 'email', label: 'Email Address' },
		{ key: 'whatsapp', label: 'WhatsApp Number' },
		{ key: 'other_contact', label: 'Other Contact Number' },
		{ key: 'cv_upload', label: 'CV Upload' },
		{ key: 'message', label: 'Short Message' }
	];

	let careersHeading = 'Careers';
	let careersHeadingAr = 'وظائف';
	let careersTagline = 'Join Our Growing Team';
	let careersTaglineAr = 'انضم إلى فريقنا المتنامي';
	let careersCvFormHeading = 'Send Us Your CV';
	let careersCvFormHeadingAr = 'أرسل لنا سيرتك الذاتية';
	let careersVacanciesHeading = 'Available Vacancies';
	let careersVacanciesHeadingAr = 'الوظائف المتاحة';
	let careersSubmitBtn = 'Submit Application';
	let careersSubmitBtnAr = 'إرسال الطلب';
	let careersApplyBtn = 'Apply';
	let careersApplyBtnAr = 'تقديم';
	let careersSuccessMessage = 'Thank you! Your application has been submitted.';
	let careersSuccessMessageAr = 'شكرًا لك! تم إرسال طلبك.';
	let careersErrorMessage = 'Something went wrong. Please try again.';
	let careersErrorMessageAr = 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';
	let careersTeamLoginTagline = 'Already part of our team?';
	let careersTeamLoginTaglineAr = 'هل أنت بالفعل جزء من فريقنا؟';
	let careersTeamLoginBtn = 'Team Login';
	let careersTeamLoginBtnAr = 'دخول الفريق';
	let careersTeamLoginTaglineEnabled = true;

	let careersLabelsEn: Record<string, string> = {
		full_name: 'Full Name',
		nationality: 'Nationality',
		position: 'Position Applying For',
		dob: 'Date of Birth',
		email: 'Email Address',
		whatsapp: 'WhatsApp Number',
		other_contact: 'Other Contact Number',
		cv_upload: 'CV Upload',
		message: 'Short Message'
	};
	let careersLabelsAr: Record<string, string> = {
		full_name: 'الاسم الكامل',
		nationality: 'الجنسية',
		position: 'الوظيفة المتقدم لها',
		dob: 'تاريخ الميلاد',
		email: 'البريد الإلكتروني',
		whatsapp: 'رقم واتساب',
		other_contact: 'رقم تواصل آخر',
		cv_upload: 'رفع السيرة الذاتية',
		message: 'رسالة قصيرة'
	};
	let careersPlaceholdersEn: Record<string, string> = {
		full_name: 'Enter your full name',
		nationality: 'Enter your nationality',
		position: '',
		dob: '',
		email: 'you@example.com',
		whatsapp: '+966 5xxxxxxxx',
		other_contact: 'Optional',
		cv_upload: '',
		message: 'Optional message'
	};
	let careersPlaceholdersAr: Record<string, string> = {
		full_name: 'أدخل اسمك الكامل',
		nationality: 'أدخل جنسيتك',
		position: '',
		dob: '',
		email: 'you@example.com',
		whatsapp: '+966 5xxxxxxxx',
		other_contact: 'اختياري',
		cv_upload: '',
		message: 'رسالة اختيارية'
	};

	let careersColors = {
		heading: '#c8912f',
		tagline: '#1f3d2f',
		form_heading: '#1f3d2f',
		vacancies_heading: '#1f3d2f',
		vacancy_title: '#1f3d2f',
		vacancy_detail: '#777777',
		button_text: '#ffffff',
		team_login_btn: '#c8912f',
		team_login_tagline: '#555555'
	};

	let careersNavLabel = 'Careers';
	let careersNavLabelAr = 'الوظائف';
	let careersNavColor = '#1f3d2f';
	let careersNavEnabled = true;

	let careersLang: 'EN' | 'AR' = 'EN';
	function toggleCareersLang() {
		careersLang = careersLang === 'EN' ? 'AR' : 'EN';
	}

	// Top Bar (public login page header) - background color + logo
	let topBarColor = '#111111';
	let topBarLogoEnabled = true;
	// Logo image - stored in the branding-docs bucket, independent of the shared app-icons table.
	// Falls back to the static /icons/logo.png file when no logo has been uploaded yet.
	let topBarLogoUrl: string | null = null;
	let uploadingLogo = false;

	function toggleTopBarLogo() {
		topBarLogoEnabled = !topBarLogoEnabled;
	}

	function editTopBarBlock(id: string) {
		// UI only for now - editing functionality will be added later
	}

	async function uploadTopBarLogo(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingLogo = true;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/logo-${Date.now()}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			topBarLogoUrl = data.publicUrl;
		} catch (e: any) {
			console.error('Failed to upload logo:', e);
		} finally {
			uploadingLogo = false;
			input.value = '';
		}
	}

	function removeTopBarLogo() {
		topBarLogoUrl = null;
	}

	// Background-color-only controls for other page sections
	let aboutBgColor = '#1f3d2f';
	let contactBgColor = '#1f3d2f';
	let footerBgColor = '#111111';
	let footerCopyrightText = '© 2026 Your Company Name. All Rights Reserved.';
	let footerCopyrightTextAr = '© 2026 اسم شركتك. جميع الحقوق محفوظة.';

	// Privacy Policy page (separate standalone tab, falls back to hardcoded page content when empty)
	let privacyPolicyContentEn = '';
	let privacyPolicyContentAr = '';
	let showPrivacyFallbackPreview = false;
	$: privacyPreviewEn = formatPolicyContent(privacyPolicyContentEn);
	$: privacyPreviewAr = formatPolicyContent(privacyPolicyContentAr);

	// Contact section - Headline Manager
	let contactHeading = 'Contact Us';
	let contactHeadingAr = 'تواصل معنا';
	let contactHeadingColor = '#c8912f';
	let contactTagline = "We'd Love to Hear From You";
	let contactTaglineAr = 'يسعدنا التواصل معك';
	let contactTaglineColor = '#ffffff';
	let contactPhone = '';
	let contactEmails: string[] = [''];
	let contactBranchesHeading = 'Our Branch Locations';
	let contactBranchesHeadingAr = 'مواقع فروعنا';
	let contactNavLabel = 'Contact';
	let contactNavLabelAr = 'تواصل';
	let contactNavColor = '#1f3d2f';
	let contactNavEnabled = true;
	let contactLang: 'EN' | 'AR' = 'EN';
	function toggleContactLang() {
		contactLang = contactLang === 'EN' ? 'AR' : 'EN';
	}
	function addContactEmail() {
		contactEmails = [...contactEmails, ''];
	}
	function removeContactEmail(index: number) {
		contactEmails = contactEmails.filter((_, i) => i !== index);
		if (contactEmails.length === 0) contactEmails = [''];
	}

	// About section images (gallery) - stored in the branding-docs bucket, up to MAX_ABOUT_IMAGES fixed slots.
	// Falls back to the static /icons/logo.png file when no image has been uploaded yet.
	// When there is more than 1 enabled image, the login page shows them as a fixed-size slideshow
	// instead of resizing the section to fit each image.
	type AboutSlide = { url: string; enabled: boolean };
	const MAX_ABOUT_IMAGES = 10;
	let aboutSlides: (AboutSlide | null)[] = Array(MAX_ABOUT_IMAGES).fill(null);
	let uploadingAboutImageSlot: number | null = null;
	let aboutImageUploadError: string | null = null;

	async function uploadAboutImageAtSlot(event: Event, slotIndex: number) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		uploadingAboutImageSlot = slotIndex;
		aboutImageUploadError = null;
		try {
			const ext = file.name.split('.').pop() || 'png';
			const path = `login/about-image-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
			const { error: uploadErr } = await supabase.storage
				.from('branding-docs')
				.upload(path, file, { upsert: true, cacheControl: '3600' });
			if (uploadErr) throw uploadErr;
			const { data } = supabase.storage.from('branding-docs').getPublicUrl(path);
			const next = [...aboutSlides];
			next[slotIndex] = { url: data.publicUrl, enabled: next[slotIndex]?.enabled ?? true };
			aboutSlides = next;
		} catch (e: any) {
			console.error('Failed to upload about image:', e);
			aboutImageUploadError = `Slide ${slotIndex + 1} upload failed: ${e?.message ?? 'unknown error'}. The image was NOT saved — try again.`;
		} finally {
			uploadingAboutImageSlot = null;
			input.value = '';
		}
	}

	function removeAboutImageAtSlot(slotIndex: number) {
		const next = [...aboutSlides];
		next[slotIndex] = null;
		aboutSlides = next;
	}

	function toggleAboutSlideEnabled(slotIndex: number) {
		const slide = aboutSlides[slotIndex];
		if (!slide) return;
		const next = [...aboutSlides];
		next[slotIndex] = { ...slide, enabled: !slide.enabled };
		aboutSlides = next;
	}

	// About section text - bilingual EN/AR, editable via a single lang toggle for the whole card group
	let aboutLang: 'EN' | 'AR' = 'EN';
	let aboutEyebrow = 'About Us';
	let aboutEyebrowAr = 'من نحن';
	let aboutHeading = "More Than a Store, It's an Experience.";
	let aboutHeadingAr = 'أكثر من مجرد متجر، إنها تجربة.';
	let aboutText =
		'We bring together the best of food, lifestyle and everyday essentials under one roof. Our focus is on quality, variety and customer satisfaction.';
	let aboutTextAr =
		'نجمع أفضل ما في الغذاء ونمط الحياة والاحتياجات اليومية تحت سقف واحد. نركز على الجودة والتنوع ورضا العملاء.';

	// Colors + enable/disable for each About text block
	let aboutEyebrowColor = '#c8912f';
	let aboutHeadingColor = '#ffffff';
	let aboutTextColor = '#d7ded9';
	let aboutNavLabel = 'About';
	let aboutNavLabelAr = 'من نحن';
	let aboutNavColor = '#1f3d2f';
	type AboutTextBlockId = 'eyebrow' | 'heading' | 'text' | 'navButton';
	let aboutBlockEnabled: Record<AboutTextBlockId, boolean> = {
		eyebrow: true,
		heading: true,
		text: true,
		navButton: true
	};

	function toggleAboutLang() {
		aboutLang = aboutLang === 'EN' ? 'AR' : 'EN';
	}

	function toggleAboutBlock(id: AboutTextBlockId) {
		aboutBlockEnabled = { ...aboutBlockEnabled, [id]: !aboutBlockEnabled[id] };
	}

	// Main Layout (overall page background + shared Home accent colors)
	let mainLayoutBgColor = '#f7f2e9';
</script>

<div class="branding-manager">
	<div class="header">
		<div class="header-left">
			<span class="header-icon">🎨</span>
			<div>
				<h2 class="header-title">Branding</h2>
				<p class="header-subtitle">Manage the public login page and app logos</p>
			</div>
		</div>
	</div>

	<div class="tab-bar">
		<button
			class="tab-btn"
			class:active={activeTab === 'login-page'}
			on:click={() => (activeTab = 'login-page')}
		>
			<span class="tab-icon">🖥️</span>
			Login Page
		</button>
		<button
			class="tab-btn"
			class:active={activeTab === 'app-logos'}
			on:click={() => (activeTab = 'app-logos')}
		>
			<span class="tab-icon">🖼️</span>
			App Logos
		</button>
		<button
			class="tab-btn"
			class:active={activeTab === 'privacy-policy'}
			on:click={() => (activeTab = 'privacy-policy')}
		>
			<span class="tab-icon">📜</span>
			Privacy Policy
		</button>
	</div>

	<div class="tab-content">
		{#if activeTab === 'login-page'}
			<div class="login-page-layout">
				<div class="section-bar">
					{#each loginPageSections as section}
						<button
							class="section-btn"
							class:active={activeLoginSection === section.id}
							on:click={() => (activeLoginSection = section.id)}
						>
							<span class="section-icon">{section.icon}</span>
							{section.label}
						</button>
					{/each}
				</div>
				<div class="content-panel">
					{#each loginPageSections as section}
						{#if activeLoginSection === section.id}
							{#if section.id === 'topbar'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'topbar'} on:click={saveTopBarAndLayout}>
											{savingSection === 'topbar' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['topbar']}<span class="save-msg">{saveMessage['topbar']}</span>{/if}
										{#if saveMessage['main_layout']}<span class="save-msg">{saveMessage['main_layout']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block mirror-block-topbar">
											<div class="mirror-block-header">
												<span class="mirror-block-name">� Company Name</span>
											</div>
											<p class="block-hint">Used everywhere the company name appears across the public login, customer login, mobile login, and privacy policy pages — instead of a hardcoded brand name.</p>
											<div class="block-controls">
												<label class="block-control">
													<span>Company Name (English)</span>
													<input type="text" bind:value={companyNameEn} placeholder="e.g. Your Company Name" />
												</label>
												<label class="block-control">
													<span>Company Name (Arabic)</span>
													<input type="text" dir="rtl" bind:value={companyNameAr} placeholder="مثلاً: اسم شركتك" />
												</label>
											</div>
										</div>
										<div class="mirror-block mirror-block-topbar">
											<div class="mirror-block-header">
												<span class="mirror-block-name">�🎨 Top Bar Background</span>
												<div class="mirror-block-toolbar">
													<button
														class="edit-btn"
														title="Edit"
														on:click={() => editTopBarBlock('color')}
													>
														✏️ Edit
													</button>
												</div>
											</div>
											<div class="mirror-topbar-preview" style="background: {topBarColor}">
												<div class="mirror-topbar-logo-badge">
													{#if topBarLogoEnabled}
														<img class="mirror-topbar-logo-img" src={topBarLogoUrl || '/icons/logo.png'} alt="Logo" />
													{/if}
												</div>
												<div class="mirror-topbar-nav">
													<span class="mirror-topbar-link active">Home</span>
													<span class="mirror-topbar-link">About</span>
													<span class="mirror-topbar-link">Services</span>
													<span class="mirror-topbar-link">Contact</span>
													<span class="mirror-topbar-lang">EN / العربية</span>
												</div>
											</div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Background color</span>
													<input type="color" bind:value={topBarColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!topBarLogoEnabled}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🖼️ Top Bar Logo</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={topBarLogoEnabled}
														title={topBarLogoEnabled ? 'Disable' : 'Enable'}
														on:click={toggleTopBarLogo}
													>
														<span class="toggle-knob"></span>
													</button>
													<button
														class="edit-btn"
														title="Edit"
														on:click={() => editTopBarBlock('logo')}
													>
														✏️ Edit
													</button>
												</div>
											</div>
											<div class="mirror-topbar-logo-preview" style="background: {topBarColor}">
												<div class="mirror-topbar-logo-badge">
													<img class="mirror-topbar-logo-img" src={topBarLogoUrl || '/icons/logo.png'} alt="Logo" />
												</div>
											</div>
											<div class="block-controls">
												<label class="block-control upload-control">
													<span>Upload logo (branding-docs)</span>
													<input type="file" accept="image/*" on:change={uploadTopBarLogo} disabled={uploadingLogo} />
												</label>
												{#if uploadingLogo}<span class="save-msg">Uploading…</span>{/if}
												{#if topBarLogoUrl}
													<button class="edit-btn" type="button" on:click={removeTopBarLogo}>✖ Remove (use static fallback)</button>
												{/if}
											</div>
										</div>
										<div class="mirror-block mirror-block-bgcolor">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🎨 Main Layout Colors</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: {mainLayoutBgColor}"></div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Page background color</span>
													<input type="color" bind:value={mainLayoutBgColor} />
												</label>
												<label class="block-control block-control-color">
													<span>Nav button label color</span>
													<input type="color" bind:value={navButtonTextColor} />
												</label>
												<label class="block-control block-control-color">
													<span>Headline highlight color</span>
													<input type="color" bind:value={mainTagHighlightColor} />
												</label>
												<label class="block-control block-control-color">
													<span>Tagline text color</span>
													<input type="color" bind:value={taglineTextColor} />
												</label>
												<label class="block-control block-control-color">
													<span>Contact Us button color</span>
													<input type="color" bind:value={contactBtnColor} />
												</label>
												<label class="block-control block-control-color">
													<span>Sign Up / Login button color</span>
													<input type="color" bind:value={signupBtnColor} />
												</label>
											</div>
										</div>
									</div>
								</div>
							{:else if section.id === 'home'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'home_content'} on:click={saveHomeSection}>
											{savingSection === 'home_content' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['home_content']}<span class="save-msg">{saveMessage['home_content']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
									<div class="mirror-block mirror-block-nav" class:disabled={!homeBlockEnabled.navButton}>
										<div class="mirror-block-header">
											<span class="mirror-block-name">🧭 Nav Button Label</span>
											<div class="mirror-block-toolbar">
												<button
													class="toggle-switch"
													class:on={homeBlockEnabled.navButton}
													title={homeBlockEnabled.navButton ? 'Disable' : 'Enable'}
													on:click={() => toggleHomeBlock('navButton')}
												>
													<span class="toggle-knob"></span>
												</button>
												<button
													class="lang-btn"
													title="Switch language"
													on:click={() => toggleHomeBlockLang('navButton')}
												>
													{homeBlockLang.navButton}
												</button>
												<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('navButton')}>
													✏️ Edit
												</button>
											</div>
										</div>
										<div class="mirror-nav-preview">
											<span class="mirror-nav-btn" style="color: {navButtonTextColor}">{homeBlockLang.navButton === 'EN' ? navButtonLabel : navButtonLabelAr}</span>
										</div>
										<div class="block-controls">
											<label class="block-control">
												<span>Button name ({homeBlockLang.navButton})</span>
												{#if homeBlockLang.navButton === 'EN'}
													<input type="text" bind:value={navButtonLabel} />
												{:else}
													<input type="text" bind:value={navButtonLabelAr} dir="rtl" />
												{/if}
											</label>
											<label class="block-control block-control-color">
												<span>Text color</span>
												<input type="color" bind:value={navButtonTextColor} />
											</label>
										</div>
									</div>
									<div class="mirror-block mirror-block-tall" class:disabled={!homeBlockEnabled.mainTag}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">🔠 Main Headline</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={homeBlockEnabled.mainTag}
															title={homeBlockEnabled.mainTag ? 'Disable' : 'Enable'}
															on:click={() => toggleHomeBlock('mainTag')}
														>
															<span class="toggle-knob"></span>
														</button>
														<button
															class="lang-btn"
															title="Switch language"
															on:click={() => toggleHomeBlockLang('mainTag')}
														>
															{homeBlockLang.mainTag}
														</button>
														<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('mainTag')}>
															✏️ Edit
														</button>
													</div>
												</div>
												<div class="mirror-hero-text">
													<h1 style="color: {mainTagTextColor}">
														<span style="color: {mainTagHighlightTarget === 'prefix' ? mainTagHighlightColor : mainTagTextColor}"
														>{homeBlockLang.mainTag === 'EN' ? mainTagPrefix : mainTagPrefixAr}</span
													><br />
														<span style="color: {mainTagHighlightTarget === 'highlight' ? mainTagHighlightColor : mainTagTextColor}"
														>{homeBlockLang.mainTag === 'EN' ? mainTagHighlightWord : mainTagHighlightWordAr}</span
													> <span style="color: {mainTagHighlightTarget === 'suffix' ? mainTagHighlightColor : mainTagTextColor}"
														>{homeBlockLang.mainTag === 'EN' ? mainTagSuffix : mainTagSuffixAr}</span
													>
													</h1>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Headline start ({homeBlockLang.mainTag})</span>
														{#if homeBlockLang.mainTag === 'EN'}
															<input type="text" bind:value={mainTagPrefix} />
														{:else}
															<input type="text" bind:value={mainTagPrefixAr} dir="rtl" />
														{/if}
													</label>
													<label class="block-control">
														<span>Highlighted word ({homeBlockLang.mainTag})</span>
														{#if homeBlockLang.mainTag === 'EN'}
															<input type="text" bind:value={mainTagHighlightWord} />
														{:else}
															<input type="text" bind:value={mainTagHighlightWordAr} dir="rtl" />
														{/if}
													</label>
													<label class="block-control">
														<span>Headline end ({homeBlockLang.mainTag})</span>
														{#if homeBlockLang.mainTag === 'EN'}
															<input type="text" bind:value={mainTagSuffix} />
														{:else}
															<input type="text" bind:value={mainTagSuffixAr} dir="rtl" />
														{/if}
													</label>
													<label class="block-control">
														<span>Which part is highlighted?</span>
														<select bind:value={mainTagHighlightTarget}>
															<option value="prefix">Headline start</option>
															<option value="highlight">Highlighted word</option>
															<option value="suffix">Headline end</option>
														</select>
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={mainTagTextColor} />
													</label>
													<label class="block-control block-control-color">
														<span>Highlight color</span>
														<input type="color" bind:value={mainTagHighlightColor} />
													</label>
												</div>
											</div>
											<div class="mirror-block" class:disabled={!homeBlockEnabled.tagline}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">📝 Tagline / Description</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={homeBlockEnabled.tagline}
															title={homeBlockEnabled.tagline ? 'Disable' : 'Enable'}
															on:click={() => toggleHomeBlock('tagline')}
														>
															<span class="toggle-knob"></span>
														</button>
														<button
															class="lang-btn"
															title="Switch language"
															on:click={() => toggleHomeBlockLang('tagline')}
														>
															{homeBlockLang.tagline}
														</button>
														<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('tagline')}>
															✏️ Edit
														</button>
													</div>
												</div>
												<div class="mirror-hero-text">
													<p style="color: {taglineTextColor}">
														{homeBlockLang.tagline === 'EN' ? taglineText : taglineTextAr}
													</p>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Tagline text ({homeBlockLang.tagline})</span>
														{#if homeBlockLang.tagline === 'EN'}
															<textarea rows="2" bind:value={taglineText}></textarea>
														{:else}
															<textarea rows="2" bind:value={taglineTextAr} dir="rtl"></textarea>
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={taglineTextColor} />
													</label>
												</div>
											</div>
											<div class="mirror-block" class:disabled={!homeBlockEnabled.contactBtn}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">🔘 Contact Us Button</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={homeBlockEnabled.contactBtn}
															title={homeBlockEnabled.contactBtn ? 'Disable' : 'Enable'}
															on:click={() => toggleHomeBlock('contactBtn')}
														>
															<span class="toggle-knob"></span>
														</button>
														<button
															class="lang-btn"
															title="Switch language"
															on:click={() => toggleHomeBlockLang('contactBtn')}
														>
															{homeBlockLang.contactBtn}
														</button>
														<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('contactBtn')}>
															✏️ Edit
														</button>
													</div>
												</div>
												<div class="mirror-hero-actions">
													<button class="mirror-btn mirror-btn-outline" style="color: {contactBtnColor}; border-color: {contactBtnColor}">{homeBlockLang.contactBtn === 'EN' ? contactBtnLabel : contactBtnLabelAr}</button>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Button text ({homeBlockLang.contactBtn})</span>
														{#if homeBlockLang.contactBtn === 'EN'}
															<input type="text" bind:value={contactBtnLabel} />
														{:else}
															<input type="text" bind:value={contactBtnLabelAr} dir="rtl" />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Button color</span>
														<input type="color" bind:value={contactBtnColor} />
													</label>
												</div>
											</div>
											<div class="mirror-block" class:disabled={!homeBlockEnabled.signupBtn}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">🔘 Sign Up / Login Button</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={homeBlockEnabled.signupBtn}
															title={homeBlockEnabled.signupBtn ? 'Disable' : 'Enable'}
															on:click={() => toggleHomeBlock('signupBtn')}
														>
															<span class="toggle-knob"></span>
														</button>
														<button
															class="lang-btn"
															title="Switch language"
															on:click={() => toggleHomeBlockLang('signupBtn')}
														>
															{homeBlockLang.signupBtn}
														</button>
														<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('signupBtn')}>
															✏️ Edit
														</button>
													</div>
												</div>
												<div class="mirror-hero-actions">
													<button class="mirror-btn mirror-btn-outline" style="color: {signupBtnColor}; border-color: {signupBtnColor}">{homeBlockLang.signupBtn === 'EN' ? signupBtnLabel : signupBtnLabelAr}</button>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Button text ({homeBlockLang.signupBtn})</span>
														{#if homeBlockLang.signupBtn === 'EN'}
															<input type="text" bind:value={signupBtnLabel} />
														{:else}
															<input type="text" bind:value={signupBtnLabelAr} dir="rtl" />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Button color</span>
														<input type="color" bind:value={signupBtnColor} />
													</label>
												</div>
											</div>
									<div class="mirror-block" class:disabled={!homeBlockEnabled.logo}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🖼️ Hero Section Image</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={homeBlockEnabled.logo}
														title={homeBlockEnabled.logo ? 'Disable' : 'Enable'}
														on:click={() => toggleHomeBlock('logo')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="edit-btn" title="Edit" on:click={() => editHomeBlock('logo')}>
														✏️ Edit
													</button>
												</div>
											</div>
											<div class="mirror-hero-logo-wrap">
												<div class="mirror-hero-blob b1"></div>
												<div class="mirror-hero-blob b2"></div>
												<div class="mirror-hero-blob b3"></div>
												<img class="mirror-hero-logo" src={heroLogoUrl || '/icons/logo.png'} alt="Company logo" />
											</div>
											<div class="block-controls">
												<label class="block-control upload-control">
													<span>Upload hero image (branding-docs)</span>
													<input type="file" accept="image/*" on:change={uploadHeroLogo} disabled={uploadingHeroLogo} />
												</label>
												{#if uploadingHeroLogo}<span class="save-msg">Uploading…</span>{/if}
												{#if heroLogoUrl}
													<button class="edit-btn" type="button" on:click={removeHeroLogo}>✖ Remove (use static fallback)</button>
												{/if}
											</div>
									</div>
									{#each badges as badge (badge.id)}
										<div class="mirror-block" class:disabled={!badge.enabled}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🛡️ Trust Badge</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={badge.enabled}
														title={badge.enabled ? 'Disable' : 'Enable'}
														on:click={() => toggleBadge(badge.id)}
													>
														<span class="toggle-knob"></span>
													</button>
													<button
														class="lang-btn"
														title="Switch language"
														on:click={() => toggleBadgeLang(badge.id)}
													>
														{badge.lang}
													</button>
													<button class="edit-btn" title="Edit" on:click={() => editBadge(badge.id)}>
														{editingBadgeId === badge.id ? '✅ Done' : '✏️ Edit'}
													</button>
													<button
														class="remove-btn"
														title="Remove badge"
														on:click={() => removeBadge(badge.id)}
													>
														✕
													</button>
												</div>
											</div>
											<div class="mirror-hero-badges">
												<div class="mirror-badge">
													<span class="mirror-badge-icon">{badge.icon}</span>
													<div>
														<strong>{badge.lang === 'EN' ? badge.title : badge.titleAr}</strong>
														<p>{badge.lang === 'EN' ? badge.desc : badge.descAr}</p>
													</div>
												</div>
											</div>
											{#if editingBadgeId === badge.id}
												<div class="block-controls">
													<label class="block-control">
														<span>Icon (emoji)</span>
														<input
															type="text"
															value={badge.icon}
															on:input={(e) => updateBadgeField(badge.id, 'icon', e.currentTarget.value)}
														/>
													</label>
													<label class="block-control">
														<span>Title ({badge.lang})</span>
														{#if badge.lang === 'EN'}
															<input
																type="text"
																value={badge.title}
																on:input={(e) => updateBadgeField(badge.id, 'title', e.currentTarget.value)}
															/>
														{:else}
															<input
																type="text"
																dir="rtl"
																value={badge.titleAr}
																on:input={(e) => updateBadgeField(badge.id, 'titleAr', e.currentTarget.value)}
															/>
														{/if}
													</label>
													<label class="block-control">
														<span>Description ({badge.lang})</span>
														{#if badge.lang === 'EN'}
															<textarea
																rows="2"
																value={badge.desc}
																on:input={(e) => updateBadgeField(badge.id, 'desc', e.currentTarget.value)}
															></textarea>
														{:else}
															<textarea
																rows="2"
																dir="rtl"
																value={badge.descAr}
																on:input={(e) => updateBadgeField(badge.id, 'descAr', e.currentTarget.value)}
															></textarea>
														{/if}
													</label>
												</div>
											{/if}
										</div>
									{/each}
									{#if badges.length < MAX_BADGES}
										<button class="mirror-block mirror-block-add" on:click={addBadge}>
											<span class="add-badge-icon">＋</span>
											<span>Add Badge</span>
											<span class="add-badge-count">{badges.length}/{MAX_BADGES}</span>
										</button>
									{/if}
									</div>
								</div>
							{:else if section.id === 'about'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button
											class="save-btn"
											disabled={savingSection === 'about' || uploadingAboutImageSlot !== null}
											on:click={saveAboutSection}
										>
											{uploadingAboutImageSlot !== null
												? 'Waiting for image upload…'
												: savingSection === 'about'
													? 'Saving…'
													: '💾 Save Changes'}
										</button>
										{#if saveMessage['about']}<span class="save-msg">{saveMessage['about']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block mirror-block-bgcolor">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🎨 About Section Background</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: {aboutBgColor}"></div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Background color</span>
													<input type="color" bind:value={aboutBgColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!aboutBlockEnabled.navButton}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧭 Nav Button</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={aboutBlockEnabled.navButton}
														title={aboutBlockEnabled.navButton ? 'Disable' : 'Enable'}
														on:click={() => toggleAboutBlock('navButton')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleAboutLang}>{aboutLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {aboutNavColor}; font-weight: 700;">
												{aboutLang === 'EN' ? aboutNavLabel : aboutNavLabelAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Nav label ({aboutLang})</span>
													{#if aboutLang === 'EN'}
														<input type="text" bind:value={aboutNavLabel} />
													{:else}
														<input type="text" bind:value={aboutNavLabelAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={aboutNavColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block mirror-block-topbar">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🖼️ About Images ({aboutSlides.filter(Boolean).length}/{MAX_ABOUT_IMAGES})</span>
											</div>
											<p class="about-slots-hint">Up to {MAX_ABOUT_IMAGES} slides. More than 1 enabled slide shows as a slideshow without resizing the section. Falls back to the static logo when no data.</p>
											{#if aboutImageUploadError}<p class="about-slots-error">⚠️ {aboutImageUploadError}</p>{/if}
											<div class="about-slots-grid">
												{#each Array(MAX_ABOUT_IMAGES) as _, slotIndex}
													<div class="about-slot-card" class:disabled={aboutSlides[slotIndex] && !aboutSlides[slotIndex]?.enabled}>
														<div class="about-slot-header">
															<span class="about-slot-label">Slide {slotIndex + 1}</span>
															{#if aboutSlides[slotIndex]}
																<button
																	class="toggle-switch toggle-switch-sm"
																	class:on={aboutSlides[slotIndex]?.enabled}
																	title={aboutSlides[slotIndex]?.enabled ? 'Disable' : 'Enable'}
																	on:click={() => toggleAboutSlideEnabled(slotIndex)}
																>
																	<span class="toggle-knob"></span>
																</button>
															{/if}
														</div>
														<div class="about-slot-thumb">
															<img src={aboutSlides[slotIndex]?.url || '/icons/logo.png'} alt="Slide {slotIndex + 1}" />
															{#if aboutSlides[slotIndex]}
																<button
																	class="remove-btn"
																	type="button"
																	title="Remove image"
																	on:click={() => removeAboutImageAtSlot(slotIndex)}
																>✕</button>
															{/if}
														</div>
														<label class="about-slot-upload">
															{uploadingAboutImageSlot === slotIndex
																? 'Uploading…'
																: aboutSlides[slotIndex]
																	? 'Replace'
																	: 'Upload'}
															<input
																type="file"
																accept="image/*"
																on:change={(e) => uploadAboutImageAtSlot(e, slotIndex)}
																disabled={uploadingAboutImageSlot !== null}
															/>
														</label>
													</div>
												{/each}
											</div>
										</div>
										<div class="mirror-block" class:disabled={!aboutBlockEnabled.eyebrow}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ About Eyebrow Tag</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={aboutBlockEnabled.eyebrow}
														title={aboutBlockEnabled.eyebrow ? 'Disable' : 'Enable'}
														on:click={() => toggleAboutBlock('eyebrow')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleAboutLang}>{aboutLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {aboutEyebrowColor}; font-weight: 600;">
												{aboutLang === 'EN' ? aboutEyebrow : aboutEyebrowAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Eyebrow text ({aboutLang})</span>
													{#if aboutLang === 'EN'}
														<input type="text" bind:value={aboutEyebrow} />
													{:else}
														<input type="text" bind:value={aboutEyebrowAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={aboutEyebrowColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!aboutBlockEnabled.heading}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 About Heading</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={aboutBlockEnabled.heading}
														title={aboutBlockEnabled.heading ? 'Disable' : 'Enable'}
														on:click={() => toggleAboutBlock('heading')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleAboutLang}>{aboutLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {aboutHeadingColor}; font-weight: 700;">
												{aboutLang === 'EN' ? aboutHeading : aboutHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({aboutLang})</span>
													{#if aboutLang === 'EN'}
														<input type="text" bind:value={aboutHeading} />
													{:else}
														<input type="text" bind:value={aboutHeadingAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={aboutHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!aboutBlockEnabled.text}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">📝 About Description</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={aboutBlockEnabled.text}
														title={aboutBlockEnabled.text ? 'Disable' : 'Enable'}
														on:click={() => toggleAboutBlock('text')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleAboutLang}>{aboutLang}</button>
												</div>
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Description ({aboutLang})</span>
													{#if aboutLang === 'EN'}
														<textarea rows="3" bind:value={aboutText}></textarea>
													{:else}
														<textarea rows="3" bind:value={aboutTextAr} dir="rtl"></textarea>
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={aboutTextColor} />
												</label>
											</div>
										</div>
									</div>
								</div>
							{:else if section.id === 'contact'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'contact'} on:click={saveContactSection}>
											{savingSection === 'contact' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['contact']}<span class="save-msg">{saveMessage['contact']}</span>{/if}
										<button class="lang-btn" style="margin-left: auto;" title="Switch language" on:click={toggleContactLang}>
											{contactLang}
										</button>
									</div>
									<p class="about-slots-hint">
										Branch locations are <strong>not</strong> managed here — they are pulled automatically from the
										Branches module (active branches with a valid location link). This controls only the section
										heading, tagline, phone number and email address.
									</p>
									<div class="mirror-card-grid">
										<div class="mirror-block mirror-block-bgcolor">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🎨 Contact Section Background</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: {contactBgColor}"></div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Background color</span>
													<input type="color" bind:value={contactBgColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!contactNavEnabled}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧭 Nav Button</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={contactNavEnabled}
														title={contactNavEnabled ? 'Disable' : 'Enable'}
														on:click={() => (contactNavEnabled = !contactNavEnabled)}
													>
														<span class="toggle-knob"></span>
													</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {contactNavColor}; font-weight: 700;">
												{contactLang === 'EN' ? contactNavLabel : contactNavLabelAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Nav label ({contactLang})</span>
													{#if contactLang === 'EN'}
														<input type="text" bind:value={contactNavLabel} />
													{:else}
														<input type="text" dir="rtl" bind:value={contactNavLabelAr} />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={contactNavColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Small Heading</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {contactHeadingColor}; font-weight: 700;">
												{contactLang === 'EN' ? contactHeading : contactHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({contactLang})</span>
													{#if contactLang === 'EN'}
														<input type="text" bind:value={contactHeading} />
													{:else}
														<input type="text" dir="rtl" bind:value={contactHeadingAr} />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={contactHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 Main Tagline</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {contactTaglineColor}; font-weight: 700;">
												{contactLang === 'EN' ? contactTagline : contactTaglineAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Tagline ({contactLang})</span>
													{#if contactLang === 'EN'}
														<input type="text" bind:value={contactTagline} />
													{:else}
														<input type="text" dir="rtl" bind:value={contactTaglineAr} />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={contactTaglineColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">📞 Phone Number (optional)</span>
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Phone number</span>
													<input type="tel" placeholder="e.g. +966 5xxxxxxxx" bind:value={contactPhone} />
												</label>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">✉️ Email Address(es) (optional)</span>
											</div>
											<div class="block-controls">
												{#each contactEmails as _, i}
													<label class="block-control contact-email-row">
														<span>Email {i + 1}</span>
														<div class="contact-email-input-row">
															<input type="email" placeholder="e.g. hello@yourbrand.com" bind:value={contactEmails[i]} />
															<button
																type="button"
																class="remove-btn"
																title="Remove email"
																disabled={contactEmails.length === 1}
																on:click={() => removeContactEmail(i)}
															>
																🗑️
															</button>
														</div>
													</label>
												{/each}
												<button type="button" class="lang-btn" on:click={addContactEmail}>＋ Add Another Email</button>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">📍 Branch Locations Heading</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {contactTaglineColor}; font-weight: 700;">
												{contactLang === 'EN' ? contactBranchesHeading : contactBranchesHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({contactLang})</span>
													{#if contactLang === 'EN'}
														<input type="text" bind:value={contactBranchesHeading} />
													{:else}
														<input type="text" dir="rtl" bind:value={contactBranchesHeadingAr} />
													{/if}
												</label>
											</div>
										</div>
									</div>
								</div>
							{:else if section.id === 'footer'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'footer'} on:click={saveFooterSection}>
											{savingSection === 'footer' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['footer']}<span class="save-msg">{saveMessage['footer']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block mirror-block-bgcolor">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🎨 Bottom Section Background</span>
											</div>
											<div class="mirror-bgcolor-preview" style="background: {footerBgColor}"></div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Background color</span>
													<input type="color" bind:value={footerBgColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block">
											<div class="mirror-block-header">
												<span class="mirror-block-name">©️ Rights Reserved Text</span>
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Text (English)</span>
													<input type="text" bind:value={footerCopyrightText} />
												</label>
												<label class="block-control">
													<span>Text (Arabic)</span>
													<input type="text" dir="rtl" bind:value={footerCopyrightTextAr} />
												</label>
											</div>
										</div>
									</div>
								</div>
							{:else if section.id === 'services'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'services'} on:click={saveServicesSection}>
											{savingSection === 'services' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['services']}<span class="save-msg">{saveMessage['services']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block" class:disabled={!servicesBlockEnabled.navButton}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧭 Nav Button</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={servicesBlockEnabled.navButton}
														title={servicesBlockEnabled.navButton ? 'Disable' : 'Enable'}
														on:click={() => toggleServicesBlock('navButton')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleServicesLang}>{servicesLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {servicesNavColor}; font-weight: 700;">
												{servicesLang === 'EN' ? servicesNavLabel : servicesNavLabelAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Nav label ({servicesLang})</span>
													{#if servicesLang === 'EN'}
														<input type="text" bind:value={servicesNavLabel} />
													{:else}
														<input type="text" bind:value={servicesNavLabelAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={servicesNavColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!servicesBlockEnabled.heading}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Services Heading</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={servicesBlockEnabled.heading}
														title={servicesBlockEnabled.heading ? 'Disable' : 'Enable'}
														on:click={() => toggleServicesBlock('heading')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleServicesLang}>{servicesLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {servicesHeadingColor}; font-weight: 700;">
												{servicesLang === 'EN' ? servicesHeading : servicesHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({servicesLang})</span>
													{#if servicesLang === 'EN'}
														<input type="text" bind:value={servicesHeading} />
													{:else}
														<input type="text" bind:value={servicesHeadingAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={servicesHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!servicesBlockEnabled.tagline}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 Services Tagline</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={servicesBlockEnabled.tagline}
														title={servicesBlockEnabled.tagline ? 'Disable' : 'Enable'}
														on:click={() => toggleServicesBlock('tagline')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleServicesLang}>{servicesLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {servicesTaglineColor}; font-weight: 700;">
												{servicesLang === 'EN' ? servicesTagline : servicesTaglineAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Tagline ({servicesLang})</span>
													{#if servicesLang === 'EN'}
														<input type="text" bind:value={servicesTagline} />
													{:else}
														<input type="text" bind:value={servicesTaglineAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={servicesTaglineColor} />
												</label>
											</div>
										</div>
									</div>
									<div class="mirror-block" style="margin-top: 1rem;">
										<div class="mirror-block-header">
											<span class="mirror-block-name">🗂️ Categories ({categories.length})</span>
										</div>
										<p class="about-slots-hint">
											Add unlimited categories. Each can have an optional image, title, subtitle, description text and
											custom colors, plus its own enable/disable switch. Up to 5 show in the current layout on the login
											page; more than 5 enabled categories scroll slowly from left to right.
										</p>
										{#if categoryImageUploadError}<p class="about-slots-error">⚠️ {categoryImageUploadError}</p>{/if}
										<div class="category-manage-grid">
											{#each categories as cat (cat.id)}
												<div class="category-manage-card" class:disabled={!cat.enabled}>
													<div class="about-slot-header">
														<span class="about-slot-label">{cat.title || 'Untitled'}</span>
														<button
															class="toggle-switch toggle-switch-sm"
															class:on={cat.enabled}
															title={cat.enabled ? 'Disable' : 'Enable'}
															on:click={() => toggleCategoryEnabled(cat.id)}
														>
															<span class="toggle-knob"></span>
														</button>
													</div>
													<div class="about-slot-thumb">
														{#if cat.image_url}
															<img src={cat.image_url} alt={cat.title} />
															<button class="remove-btn" title="Remove image" on:click={() => removeCategoryImage(cat.id)}>✕</button>
														{:else}
															<span class="category-thumb-placeholder">No image</span>
														{/if}
													</div>
													<label class="about-slot-upload">
														{uploadingCategoryImageId === cat.id ? 'Uploading…' : cat.image_url ? 'Replace' : 'Upload'}
														<input
															type="file"
															accept="image/*"
															on:change={(e) => uploadCategoryImage(e, cat.id)}
															disabled={uploadingCategoryImageId !== null}
														/>
													</label>
													<div class="category-manage-actions">
														<button class="lang-btn" title="Switch language" on:click={() => toggleCategoryLang(cat.id)}>{cat.lang}</button>
														<button class="edit-btn" title="Edit" on:click={() => editCategory(cat.id)}>
															{editingCategoryId === cat.id ? '✅ Done' : '✏️ Edit'}
														</button>
														<button class="remove-btn" title="Remove category" on:click={() => removeCategory(cat.id)}>✕</button>
													</div>
													{#if editingCategoryId === cat.id}
														<div class="block-controls">
															<label class="block-control">
																<span>Title ({cat.lang})</span>
																{#if cat.lang === 'EN'}
																	<input
																		type="text"
																		value={cat.title}
																		on:input={(e) => updateCategoryField(cat.id, 'title', e.currentTarget.value)}
																	/>
																{:else}
																	<input
																		type="text"
																		dir="rtl"
																		value={cat.title_ar}
																		on:input={(e) => updateCategoryField(cat.id, 'title_ar', e.currentTarget.value)}
																	/>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Title color</span>
																<input
																	type="color"
																	value={cat.title_color}
																	on:input={(e) => updateCategoryField(cat.id, 'title_color', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control">
																<span>Subtitle ({cat.lang})</span>
																{#if cat.lang === 'EN'}
																	<input
																		type="text"
																		value={cat.subtitle}
																		on:input={(e) => updateCategoryField(cat.id, 'subtitle', e.currentTarget.value)}
																	/>
																{:else}
																	<input
																		type="text"
																		dir="rtl"
																		value={cat.subtitle_ar}
																		on:input={(e) => updateCategoryField(cat.id, 'subtitle_ar', e.currentTarget.value)}
																	/>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Subtitle color</span>
																<input
																	type="color"
																	value={cat.subtitle_color}
																	on:input={(e) => updateCategoryField(cat.id, 'subtitle_color', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control">
																<span>Description ({cat.lang})</span>
																{#if cat.lang === 'EN'}
																	<textarea
																		rows="2"
																		value={cat.text}
																		on:input={(e) => updateCategoryField(cat.id, 'text', e.currentTarget.value)}
																	></textarea>
																{:else}
																	<textarea
																		rows="2"
																		dir="rtl"
																		value={cat.text_ar}
																		on:input={(e) => updateCategoryField(cat.id, 'text_ar', e.currentTarget.value)}
																	></textarea>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Description color</span>
																<input
																	type="color"
																	value={cat.text_color}
																	on:input={(e) => updateCategoryField(cat.id, 'text_color', e.currentTarget.value)}
																/>
															</label>
														</div>
													{/if}
												</div>
											{/each}
											<button class="category-manage-add" type="button" on:click={addCategory}>
												<span class="add-badge-icon">＋</span>
												<span>Add Category</span>
											</button>
										</div>
									</div>
								</div>
							{:else if section.id === 'why-choose'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'why_choose'} on:click={saveWhyChooseSection}>
											{savingSection === 'why_choose' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['why_choose']}<span class="save-msg">{saveMessage['why_choose']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block" class:disabled={!whyChooseBlockEnabled.heading}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Why Choose Us Heading</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={whyChooseBlockEnabled.heading}
														title={whyChooseBlockEnabled.heading ? 'Disable' : 'Enable'}
														on:click={() => toggleWhyChooseBlock('heading')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleWhyChooseLang}>{whyChooseLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {whyChooseHeadingColor}; font-weight: 700;">
												{whyChooseLang === 'EN' ? whyChooseHeading : whyChooseHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({whyChooseLang})</span>
													{#if whyChooseLang === 'EN'}
														<input type="text" bind:value={whyChooseHeading} />
													{:else}
														<input type="text" bind:value={whyChooseHeadingAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={whyChooseHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!whyChooseBlockEnabled.tagline}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 Why Choose Us Tagline</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={whyChooseBlockEnabled.tagline}
														title={whyChooseBlockEnabled.tagline ? 'Disable' : 'Enable'}
														on:click={() => toggleWhyChooseBlock('tagline')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleWhyChooseLang}>{whyChooseLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {whyChooseTaglineColor}; font-weight: 700;">
												{whyChooseLang === 'EN' ? whyChooseTagline : whyChooseTaglineAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Tagline ({whyChooseLang})</span>
													{#if whyChooseLang === 'EN'}
														<input type="text" bind:value={whyChooseTagline} />
													{:else}
														<input type="text" bind:value={whyChooseTaglineAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={whyChooseTaglineColor} />
												</label>
											</div>
										</div>
									</div>
									<div class="mirror-block" style="margin-top: 1rem;">
										<div class="mirror-block-header">
											<span class="mirror-block-name">⭐ Features ({features.length})</span>
										</div>
										<p class="about-slots-hint">
											Add unlimited features. Each can have an optional icon or uploaded image, a title, description text
											and custom icon/text colors, plus its own enable/disable switch and display order. Up to 5 enabled
											features show in the current layout on the login page; more than 5 enabled features scroll slowly
											from left to right.
										</p>
										{#if featureImageUploadError}<p class="about-slots-error">⚠️ {featureImageUploadError}</p>{/if}
										<div class="category-manage-grid">
											{#each features as feat, idx (feat.id)}
												<div class="category-manage-card" class:disabled={!feat.enabled}>
													<div class="about-slot-header">
														<span class="about-slot-label">{feat.title || 'Untitled'}</span>
														<button
															class="toggle-switch toggle-switch-sm"
															class:on={feat.enabled}
															title={feat.enabled ? 'Disable' : 'Enable'}
															on:click={() => toggleFeatureEnabled(feat.id)}
														>
															<span class="toggle-knob"></span>
														</button>
													</div>
													<div class="about-slot-thumb">
														{#if feat.image_url}
															<img src={feat.image_url} alt={feat.title} />
															<button class="remove-btn" title="Remove image" on:click={() => removeFeatureImage(feat.id)}>✕</button>
														{:else}
															<span class="category-thumb-placeholder">{feat.icon || 'No icon'}</span>
														{/if}
													</div>
													<label class="about-slot-upload">
														{uploadingFeatureImageId === feat.id ? 'Uploading…' : feat.image_url ? 'Replace image' : 'Upload image'}
														<input
															type="file"
															accept="image/*"
															on:change={(e) => uploadFeatureImage(e, feat.id)}
															disabled={uploadingFeatureImageId !== null}
														/>
													</label>
													<div class="category-manage-actions">
														<button class="lang-btn" title="Move up" disabled={idx === 0} on:click={() => moveFeature(feat.id, 'up')}>⬆️</button>
														<button class="lang-btn" title="Move down" disabled={idx === features.length - 1} on:click={() => moveFeature(feat.id, 'down')}>⬇️</button>
														<button class="lang-btn" title="Switch language" on:click={() => toggleFeatureLang(feat.id)}>{feat.lang}</button>
														<button class="edit-btn" title="Edit" on:click={() => editFeature(feat.id)}>
															{editingFeatureId === feat.id ? '✅ Done' : '✏️ Edit'}
														</button>
														<button class="remove-btn" title="Remove feature" on:click={() => removeFeature(feat.id)}>✕</button>
													</div>
													{#if editingFeatureId === feat.id}
														<div class="block-controls">
															<label class="block-control">
																<span>Icon (emoji, optional)</span>
																<input
																	type="text"
																	value={feat.icon}
																	maxlength="4"
																	on:input={(e) => updateFeatureField(feat.id, 'icon', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control block-control-color">
																<span>Icon color</span>
																<input
																	type="color"
																	value={feat.icon_color}
																	on:input={(e) => updateFeatureField(feat.id, 'icon_color', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control">
																<span>Title ({feat.lang})</span>
																{#if feat.lang === 'EN'}
																	<input
																		type="text"
																		value={feat.title}
																		on:input={(e) => updateFeatureField(feat.id, 'title', e.currentTarget.value)}
																	/>
																{:else}
																	<input
																		type="text"
																		dir="rtl"
																		value={feat.title_ar}
																		on:input={(e) => updateFeatureField(feat.id, 'title_ar', e.currentTarget.value)}
																	/>
																{/if}
															</label>
															<label class="block-control">
																<span>Description ({feat.lang})</span>
																{#if feat.lang === 'EN'}
																	<textarea
																		rows="2"
																		value={feat.desc}
																		on:input={(e) => updateFeatureField(feat.id, 'desc', e.currentTarget.value)}
																	></textarea>
																{:else}
																	<textarea
																		rows="2"
																		dir="rtl"
																		value={feat.desc_ar}
																		on:input={(e) => updateFeatureField(feat.id, 'desc_ar', e.currentTarget.value)}
																	></textarea>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Text color</span>
																<input
																	type="color"
																	value={feat.text_color}
																	on:input={(e) => updateFeatureField(feat.id, 'text_color', e.currentTarget.value)}
																/>
															</label>
														</div>
													{/if}
												</div>
											{/each}
											<button class="category-manage-add" type="button" on:click={addFeature}>
												<span class="add-badge-icon">＋</span>
												<span>Add Feature</span>
											</button>
										</div>
									</div>
								</div>
							{:else if section.id === 'gallery'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'gallery'} on:click={saveGallerySection}>
											{savingSection === 'gallery' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['gallery']}<span class="save-msg">{saveMessage['gallery']}</span>{/if}
									</div>
									<div class="mirror-card-grid">
										<div class="mirror-block" class:disabled={!galleryBlockEnabled.navButton}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧭 Nav Button</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={galleryBlockEnabled.navButton}
														title={galleryBlockEnabled.navButton ? 'Disable' : 'Enable'}
														on:click={() => toggleGalleryBlock('navButton')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleGalleryLang}>{galleryLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {galleryNavColor}; font-weight: 700;">
												{galleryLang === 'EN' ? galleryNavLabel : galleryNavLabelAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Nav label ({galleryLang})</span>
													{#if galleryLang === 'EN'}
														<input type="text" bind:value={galleryNavLabel} />
													{:else}
														<input type="text" bind:value={galleryNavLabelAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={galleryNavColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!galleryBlockEnabled.heading}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Gallery Heading</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={galleryBlockEnabled.heading}
														title={galleryBlockEnabled.heading ? 'Disable' : 'Enable'}
														on:click={() => toggleGalleryBlock('heading')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleGalleryLang}>{galleryLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {galleryHeadingColor}; font-weight: 700;">
												{galleryLang === 'EN' ? galleryHeading : galleryHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({galleryLang})</span>
													{#if galleryLang === 'EN'}
														<input type="text" bind:value={galleryHeading} />
													{:else}
														<input type="text" bind:value={galleryHeadingAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={galleryHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!galleryBlockEnabled.tagline}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 Gallery Tagline</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={galleryBlockEnabled.tagline}
														title={galleryBlockEnabled.tagline ? 'Disable' : 'Enable'}
														on:click={() => toggleGalleryBlock('tagline')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleGalleryLang}>{galleryLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {galleryTaglineColor}; font-weight: 700;">
												{galleryLang === 'EN' ? galleryTagline : galleryTaglineAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Tagline ({galleryLang})</span>
													{#if galleryLang === 'EN'}
														<input type="text" bind:value={galleryTagline} />
													{:else}
														<input type="text" bind:value={galleryTaglineAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={galleryTaglineColor} />
												</label>
											</div>
										</div>
									</div>
									<div class="mirror-block" style="margin-top: 1rem;">
										<div class="mirror-block-header">
											<span class="mirror-block-name">🖼️ Gallery Items ({galleryItems.length})</span>
										</div>
										<p class="about-slots-hint">
											Add unlimited gallery items. Each needs an image, plus an optional title, subtitle and description
											text with custom colors, its own enable/disable switch and display order. Up to 5 enabled items show
											in the current layout on the login page; more than 5 enabled items scroll slowly from left to right.
										</p>
										{#if galleryImageUploadError}<p class="about-slots-error">⚠️ {galleryImageUploadError}</p>{/if}
										<div class="category-manage-grid">
											{#each galleryItems as item, idx (item.id)}
												<div class="category-manage-card" class:disabled={!item.enabled}>
													<div class="about-slot-header">
														<span class="about-slot-label">{item.title || 'Untitled'}</span>
														<button
															class="toggle-switch toggle-switch-sm"
															class:on={item.enabled}
															title={item.enabled ? 'Disable' : 'Enable'}
															on:click={() => toggleGalleryItemEnabled(item.id)}
														>
															<span class="toggle-knob"></span>
														</button>
													</div>
													<div class="about-slot-thumb">
														{#if item.image_url}
															<img src={item.image_url} alt={item.title || 'Gallery item'} />
															<button class="remove-btn" title="Remove image" on:click={() => removeGalleryImage(item.id)}>✕</button>
														{:else}
															<span class="category-thumb-placeholder">No image</span>
														{/if}
													</div>
													<label class="about-slot-upload">
														{uploadingGalleryImageId === item.id ? 'Uploading…' : item.image_url ? 'Replace image' : 'Upload image'}
														<input
															type="file"
															accept="image/*"
															on:change={(e) => uploadGalleryImage(e, item.id)}
															disabled={uploadingGalleryImageId !== null}
														/>
													</label>
													<div class="category-manage-actions">
														<button class="lang-btn" title="Move up" disabled={idx === 0} on:click={() => moveGalleryItem(item.id, 'up')}>⬆️</button>
														<button class="lang-btn" title="Move down" disabled={idx === galleryItems.length - 1} on:click={() => moveGalleryItem(item.id, 'down')}>⬇️</button>
														<button class="lang-btn" title="Switch language" on:click={() => toggleGalleryItemLang(item.id)}>{item.lang}</button>
														<button class="edit-btn" title="Edit" on:click={() => editGalleryItem(item.id)}>
															{editingGalleryItemId === item.id ? '✅ Done' : '✏️ Edit'}
														</button>
														<button class="remove-btn" title="Remove item" on:click={() => removeGalleryItem(item.id)}>✕</button>
													</div>
													{#if editingGalleryItemId === item.id}
														<div class="block-controls">
															<label class="block-control">
																<span>Title ({item.lang}) — optional</span>
																{#if item.lang === 'EN'}
																	<input
																		type="text"
																		value={item.title}
																		on:input={(e) => updateGalleryItemField(item.id, 'title', e.currentTarget.value)}
																	/>
																{:else}
																	<input
																		type="text"
																		dir="rtl"
																		value={item.title_ar}
																		on:input={(e) => updateGalleryItemField(item.id, 'title_ar', e.currentTarget.value)}
																	/>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Title color</span>
																<input
																	type="color"
																	value={item.title_color}
																	on:input={(e) => updateGalleryItemField(item.id, 'title_color', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control">
																<span>Subtitle ({item.lang}) — optional</span>
																{#if item.lang === 'EN'}
																	<input
																		type="text"
																		value={item.subtitle}
																		on:input={(e) => updateGalleryItemField(item.id, 'subtitle', e.currentTarget.value)}
																	/>
																{:else}
																	<input
																		type="text"
																		dir="rtl"
																		value={item.subtitle_ar}
																		on:input={(e) => updateGalleryItemField(item.id, 'subtitle_ar', e.currentTarget.value)}
																	/>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Subtitle color</span>
																<input
																	type="color"
																	value={item.subtitle_color}
																	on:input={(e) => updateGalleryItemField(item.id, 'subtitle_color', e.currentTarget.value)}
																/>
															</label>
															<label class="block-control">
																<span>Description ({item.lang}) — optional</span>
																{#if item.lang === 'EN'}
																	<textarea
																		rows="2"
																		value={item.text}
																		on:input={(e) => updateGalleryItemField(item.id, 'text', e.currentTarget.value)}
																	></textarea>
																{:else}
																	<textarea
																		rows="2"
																		dir="rtl"
																		value={item.text_ar}
																		on:input={(e) => updateGalleryItemField(item.id, 'text_ar', e.currentTarget.value)}
																	></textarea>
																{/if}
															</label>
															<label class="block-control block-control-color">
																<span>Description color</span>
																<input
																	type="color"
																	value={item.text_color}
																	on:input={(e) => updateGalleryItemField(item.id, 'text_color', e.currentTarget.value)}
																/>
															</label>
														</div>
													{/if}
												</div>
											{/each}
											<button class="category-manage-add" type="button" on:click={addGalleryItem}>
												<span class="add-badge-icon">＋</span>
												<span>Add Gallery Item</span>
											</button>
										</div>
									</div>
								</div>
							{:else if section.id === 'offers'}
								<div class="home-mirror">
									<div class="section-save-bar">
										<button class="save-btn" disabled={savingSection === 'offers'} on:click={saveOffersSection}>
											{savingSection === 'offers' ? 'Saving…' : '💾 Save Changes'}
										</button>
										{#if saveMessage['offers']}<span class="save-msg">{saveMessage['offers']}</span>{/if}
									</div>
									<p class="about-slots-hint">
										This controls only the section heading and tagline. Individual offer cards are <strong>not</strong>
										managed here — they are pulled automatically from the Offers module and shown on the login page
										whenever they are currently valid (within their branch, date and time range).
									</p>
									<div class="mirror-card-grid">
										<div class="mirror-block" class:disabled={!offersBlockEnabled.navButton}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧭 Nav Button</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={offersBlockEnabled.navButton}
														title={offersBlockEnabled.navButton ? 'Disable' : 'Enable'}
														on:click={() => toggleOffersBlock('navButton')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleOffersLang}>{offersLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {offersNavColor}; font-weight: 700;">
												{offersLang === 'EN' ? offersNavLabel : offersNavLabelAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Nav label ({offersLang})</span>
													{#if offersLang === 'EN'}
														<input type="text" bind:value={offersNavLabel} />
													{:else}
														<input type="text" bind:value={offersNavLabelAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={offersNavColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!offersBlockEnabled.heading}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Offers Heading</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={offersBlockEnabled.heading}
														title={offersBlockEnabled.heading ? 'Disable' : 'Enable'}
														on:click={() => toggleOffersBlock('heading')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleOffersLang}>{offersLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {offersHeadingColor}; font-weight: 700;">
												{offersLang === 'EN' ? offersHeading : offersHeadingAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Heading ({offersLang})</span>
													{#if offersLang === 'EN'}
														<input type="text" bind:value={offersHeading} />
													{:else}
														<input type="text" bind:value={offersHeadingAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={offersHeadingColor} />
												</label>
											</div>
										</div>
										<div class="mirror-block" class:disabled={!offersBlockEnabled.tagline}>
											<div class="mirror-block-header">
												<span class="mirror-block-name">🔠 Offers Tagline</span>
												<div class="mirror-block-toolbar">
													<button
														class="toggle-switch"
														class:on={offersBlockEnabled.tagline}
														title={offersBlockEnabled.tagline ? 'Disable' : 'Enable'}
														on:click={() => toggleOffersBlock('tagline')}
													>
														<span class="toggle-knob"></span>
													</button>
													<button class="lang-btn" title="Switch language" on:click={toggleOffersLang}>{offersLang}</button>
												</div>
											</div>
											<div class="mirror-bgcolor-preview" style="background: transparent; color: {offersTaglineColor}; font-weight: 700;">
												{offersLang === 'EN' ? offersTagline : offersTaglineAr}
											</div>
											<div class="block-controls">
												<label class="block-control">
													<span>Tagline ({offersLang})</span>
													{#if offersLang === 'EN'}
														<input type="text" bind:value={offersTagline} />
													{:else}
														<input type="text" bind:value={offersTaglineAr} dir="rtl" />
													{/if}
												</label>
												<label class="block-control block-control-color">
													<span>Text color</span>
													<input type="color" bind:value={offersTaglineColor} />
												</label>
											</div>
										</div>
									</div>
								</div>
							{:else if section.id === 'careers'}
								<div class="home-mirror">
									<div class="careers-subtabs">
										<button class="lang-btn" class:on={careersSubTab === 'job-ads'} on:click={() => (careersSubTab = 'job-ads')}>
											💼 Job Ads
										</button>
										<button class="lang-btn" class:on={careersSubTab === 'received-cvs'} on:click={() => (careersSubTab = 'received-cvs')}>
											📄 Received CVs
										</button>
										<button class="lang-btn" class:on={careersSubTab === 'headline'} on:click={() => (careersSubTab = 'headline')}>
											🔠 Headline Manager
										</button>
									</div>

									{#if careersSubTab === 'job-ads'}
										<div class="section-save-bar">
											<button class="save-btn" type="button" on:click={() => openVacancyForm()}>＋ Add Job Vacancy</button>
										</div>
										{#if jobVacanciesLoading}
											<p class="about-slots-hint">Loading vacancies…</p>
										{:else if jobVacancies.length === 0}
											<p class="about-slots-hint">No job vacancies yet. Click "Add Job Vacancy" to create one.</p>
										{:else}
											<table class="careers-table">
												<thead>
													<tr>
														<th>Job Title</th>
														<th>Branch / Location</th>
														<th>Type</th>
														<th>Closing Date</th>
														<th>Status</th>
														<th>Order</th>
														<th>Created</th>
														<th>Actions</th>
													</tr>
												</thead>
												<tbody>
													{#each jobVacancies as v (v.id)}
														<tr class:disabled-row={!v.enabled}>
															<td>{v.title_en}</td>
															<td>{v.location_en || '—'}</td>
															<td>{v.employment_type_en || '—'}</td>
															<td>{v.closing_date || '—'}</td>
															<td>{v.enabled ? '✅ Enabled' : '⛔ Disabled'}</td>
															<td>{v.display_order}</td>
															<td>{new Date(v.created_at).toLocaleDateString()}</td>
															<td class="careers-actions">
																<button class="lang-btn" title="View" on:click={() => viewVacancy(v)}>👁️</button>
																<button class="lang-btn" title="Edit" on:click={() => openVacancyForm(v.id)}>✏️</button>
																<button class="lang-btn" title={v.enabled ? 'Disable' : 'Enable'} on:click={() => toggleVacancyEnabled(v)}>
																	{v.enabled ? '⛔' : '✅'}
																</button>
																<button
																	class="remove-btn"
																	title="Delete"
																	disabled={deletingVacancyId === v.id}
																	on:click={() => deleteVacancy(v.id)}
																>
																	🗑️
																</button>
															</td>
														</tr>
													{/each}
												</tbody>
											</table>
										{/if}

										{#if viewingVacancy}
											<div class="careers-modal-backdrop" on:click={() => (viewingVacancy = null)}>
												<div class="careers-modal" on:click|stopPropagation>
													<h3>{viewingVacancy.title_en}</h3>
													<p><strong>Department:</strong> {viewingVacancy.department_en || '—'}</p>
													<p><strong>Type:</strong> {viewingVacancy.employment_type_en || '—'}</p>
													<p><strong>Location:</strong> {viewingVacancy.location_en || '—'}</p>
													<p><strong>Short Description:</strong> {viewingVacancy.short_desc_en || '—'}</p>
													<p><strong>Full Description:</strong> {viewingVacancy.full_desc_en || '—'}</p>
													<p><strong>Requirements:</strong> {viewingVacancy.requirements_en || '—'}</p>
													<p><strong>Responsibilities:</strong> {viewingVacancy.responsibilities_en || '—'}</p>
													<p><strong>Experience:</strong> {viewingVacancy.experience_en || '—'}</p>
													<p><strong>Salary/Benefits:</strong> {viewingVacancy.salary_en || '—'}</p>
													<p><strong>Closing Date:</strong> {viewingVacancy.closing_date || '—'}</p>
													<button class="save-btn" type="button" on:click={() => (viewingVacancy = null)}>Close</button>
												</div>
											</div>
										{/if}
									{:else if careersSubTab === 'received-cvs'}
										{#if cvApplicationsLoading}
											<p class="about-slots-hint">Loading applications…</p>
										{:else if cvApplications.length === 0}
											<p class="about-slots-hint">No CV applications received yet.</p>
										{:else}
											<table class="careers-table">
												<thead>
													<tr>
														<th>Applicant</th>
														<th>Nationality</th>
														<th>Position</th>
														<th>Email</th>
														<th>WhatsApp</th>
														<th>CV</th>
														<th>Submitted</th>
														<th>Status</th>
														<th>Actions</th>
													</tr>
												</thead>
												<tbody>
													{#each cvApplications as app (app.id)}
														<tr>
															<td>{app.full_name}</td>
															<td>{app.nationality || '—'}</td>
															<td>{app.position_applying_for || '—'}</td>
															<td>{app.email || '—'}</td>
															<td>{app.whatsapp_number || '—'}</td>
															<td>
																{#if app.cv_file_url}
																	<button class="lang-btn" title="Download CV" on:click={() => downloadCv(app)}>⬇️</button>
																{:else}
																	—
																{/if}
															</td>
															<td>{new Date(app.created_at).toLocaleDateString()}</td>
															<td>
																<select value={app.status} on:change={(e) => updateApplicationStatus(app, e.currentTarget.value)}>
																	{#each cvStatusOptions as opt}
																		<option value={opt}>{opt}</option>
																	{/each}
																</select>
															</td>
															<td class="careers-actions">
																<button class="lang-btn" title="View full application" on:click={() => viewApplication(app)}>👁️</button>
																<button class="lang-btn" title="Add/Edit internal notes" on:click={() => startEditNotes(app)}>📝</button>
																<button
																	class="remove-btn"
																	title="Delete"
																	disabled={deletingApplicationId === app.id}
																	on:click={() => deleteApplication(app.id)}
																>
																	🗑️
																</button>
															</td>
														</tr>
														{#if editingNotesId === app.id}
															<tr>
																<td colspan="9">
																	<div class="careers-notes-editor">
																		<textarea rows="2" bind:value={notesDraft} placeholder="Internal notes (not visible to applicant)"></textarea>
																		<button class="save-btn" type="button" on:click={() => saveNotes(app)}>💾 Save Notes</button>
																		<button class="lang-btn" type="button" on:click={() => (editingNotesId = null)}>Cancel</button>
																	</div>
																</td>
															</tr>
														{/if}
													{/each}
												</tbody>
											</table>
										{/if}

										{#if viewingApplication}
											<div class="careers-modal-backdrop" on:click={() => (viewingApplication = null)}>
												<div class="careers-modal" on:click|stopPropagation>
													<h3>{viewingApplication.full_name}</h3>
													<p><strong>Nationality:</strong> {viewingApplication.nationality || '—'}</p>
													<p><strong>Position Applying For:</strong> {viewingApplication.position_applying_for || '—'}</p>
													<p><strong>Date of Birth:</strong> {viewingApplication.date_of_birth || '—'}</p>
													<p><strong>Email:</strong> {viewingApplication.email || '—'}</p>
													<p><strong>WhatsApp:</strong> {viewingApplication.whatsapp_number || '—'}</p>
													<p><strong>Other Contact:</strong> {viewingApplication.other_contact_number || '—'}</p>
													<p><strong>Message:</strong> {viewingApplication.message || '—'}</p>
													<p><strong>Status:</strong> {viewingApplication.status}</p>
													<p><strong>Internal Notes:</strong> {viewingApplication.internal_notes || '—'}</p>
													<button class="save-btn" type="button" on:click={() => (viewingApplication = null)}>Close</button>
												</div>
											</div>
										{/if}
									{:else if careersSubTab === 'headline'}
										<div class="section-save-bar">
											<button class="save-btn" disabled={savingSection === 'careers'} on:click={saveCareersSection}>
												{savingSection === 'careers' ? 'Saving…' : '💾 Save Changes'}
											</button>
											{#if saveMessage['careers']}<span class="save-msg">{saveMessage['careers']}</span>{/if}
											<button class="lang-btn" style="margin-left: auto;" title="Switch language" on:click={toggleCareersLang}>
												{careersLang}
											</button>
										</div>
										<div class="mirror-card-grid">
											<div class="mirror-block" class:disabled={!careersNavEnabled}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">🧭 Nav Button</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={careersNavEnabled}
															title={careersNavEnabled ? 'Disable' : 'Enable'}
															on:click={() => (careersNavEnabled = !careersNavEnabled)}
														>
															<span class="toggle-knob"></span>
														</button>
													</div>
												</div>
												<div class="mirror-bgcolor-preview" style="background: transparent; color: {careersNavColor}; font-weight: 700;">
													{careersLang === 'EN' ? careersNavLabel : careersNavLabelAr}
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Nav label ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersNavLabel} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersNavLabelAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={careersNavColor} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">🏷️ Small Heading</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Heading ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersHeading} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersHeadingAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={careersColors.heading} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">🔠 Main Tagline</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Tagline ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersTagline} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersTaglineAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={careersColors.tagline} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">📄 "Send Us Your CV" Heading</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Heading ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersCvFormHeading} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersCvFormHeadingAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={careersColors.form_heading} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">📋 "Available Vacancies" Heading</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Heading ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersVacanciesHeading} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersVacanciesHeadingAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Text color</span>
														<input type="color" bind:value={careersColors.vacancies_heading} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">🔘 Submit Button Text</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Text ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersSubmitBtn} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersSubmitBtnAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Button text color</span>
														<input type="color" bind:value={careersColors.button_text} />
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">🔘 Apply Button Text</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Text ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersApplyBtn} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersApplyBtnAr} />
														{/if}
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">✅ Success Message</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Message ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersSuccessMessage} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersSuccessMessageAr} />
														{/if}
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header"><span class="mirror-block-name">⚠️ Error Message</span></div>
												<div class="block-controls">
													<label class="block-control">
														<span>Message ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersErrorMessage} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersErrorMessageAr} />
														{/if}
													</label>
												</div>
											</div>
											<div class="mirror-block">
												<div class="mirror-block-header">
													<span class="mirror-block-name">🔑 Team Login Button</span>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Button Text ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersTeamLoginBtn} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersTeamLoginBtnAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Button color</span>
														<input type="color" bind:value={careersColors.team_login_btn} />
													</label>
												</div>
											</div>
											<div class="mirror-block" class:disabled={!careersTeamLoginTaglineEnabled}>
												<div class="mirror-block-header">
													<span class="mirror-block-name">💬 Team Login Tagline</span>
													<div class="mirror-block-toolbar">
														<button
															class="toggle-switch"
															class:on={careersTeamLoginTaglineEnabled}
															title={careersTeamLoginTaglineEnabled ? 'Disable' : 'Enable'}
															on:click={() => (careersTeamLoginTaglineEnabled = !careersTeamLoginTaglineEnabled)}
														>
															<span class="toggle-knob"></span>
														</button>
													</div>
												</div>
												<div class="block-controls">
													<label class="block-control">
														<span>Tagline ({careersLang})</span>
														{#if careersLang === 'EN'}
															<input type="text" bind:value={careersTeamLoginTagline} />
														{:else}
															<input type="text" dir="rtl" bind:value={careersTeamLoginTaglineAr} />
														{/if}
													</label>
													<label class="block-control block-control-color">
														<span>Tagline color</span>
														<input type="color" bind:value={careersColors.team_login_tagline} />
													</label>
												</div>
											</div>
										</div>

										<div class="mirror-block" style="margin-top: 1rem;">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🏷️ Vacancy Card Colors</span>
											</div>
											<div class="block-controls">
												<label class="block-control block-control-color">
													<span>Vacancy title color</span>
													<input type="color" bind:value={careersColors.vacancy_title} />
												</label>
												<label class="block-control block-control-color">
													<span>Vacancy detail color</span>
													<input type="color" bind:value={careersColors.vacancy_detail} />
												</label>
											</div>
										</div>

										<div class="mirror-block" style="margin-top: 1rem;">
											<div class="mirror-block-header">
												<span class="mirror-block-name">🧾 CV Form Field Labels &amp; Placeholders ({careersLang})</span>
											</div>
											<p class="about-slots-hint">
												These control the labels and placeholder text shown on each field of the "Send Us Your CV" form.
											</p>
											<div class="block-controls">
												{#each careersFieldKeys as f (f.key)}
													{#if careersLang === 'EN'}
														<label class="block-control">
															<span>{f.label} — label</span>
															<input type="text" bind:value={careersLabelsEn[f.key]} />
														</label>
														<label class="block-control">
															<span>{f.label} — placeholder</span>
															<input type="text" bind:value={careersPlaceholdersEn[f.key]} />
														</label>
													{:else}
														<label class="block-control">
															<span>{f.label} — label</span>
															<input type="text" dir="rtl" bind:value={careersLabelsAr[f.key]} />
														</label>
														<label class="block-control">
															<span>{f.label} — placeholder</span>
															<input type="text" dir="rtl" bind:value={careersPlaceholdersAr[f.key]} />
														</label>
													{/if}
												{/each}
											</div>
										</div>
									{/if}
								</div>
							{:else}
							<div class="placeholder">
								<span class="placeholder-icon">{section.icon}</span>
								<h3>{section.label}</h3>
								<p>Manage the "{section.label}" section of the public login page here.</p>
							</div>
						{/if}
					{/if}
				{/each}
				</div>
			</div>
		{:else if activeTab === 'app-logos'}
			<div class="content-panel">
				<div class="placeholder">
					<span class="placeholder-icon">🖼️</span>
					<h3>App Logos</h3>
					<p>Manage the logos used across the app here.</p>
				</div>
			</div>
		{:else if activeTab === 'privacy-policy'}
			<div class="content-panel privacy-policy-panel">
				<div class="home-mirror privacy-policy-mirror">
					<div class="section-save-bar">
						<button
							class="save-btn"
							disabled={savingSection === 'privacy_policy'}
							on:click={savePrivacyPolicySection}
						>
							{savingSection === 'privacy_policy' ? 'Saving…' : '💾 Save Changes'}
						</button>
						{#if saveMessage['privacy_policy']}<span class="save-msg">{saveMessage['privacy_policy']}</span>{/if}
						<button class="lang-btn" on:click={() => (showPrivacyFallbackPreview = !showPrivacyFallbackPreview)}>
							{showPrivacyFallbackPreview ? '✖ Hide Fallback Preview' : '👁 Preview Fallback Content'}
						</button>
					</div>
					<p class="privacy-policy-note">
						This lets you fully replace the content shown on the public <code>/privacy</code> page. Leave both
						fields empty to keep showing the current default Privacy Policy page shown below.
					</p>
					{#if showPrivacyFallbackPreview}
						<div class="privacy-fallback-preview">
							<div class="privacy-fallback-preview-label">
								Live preview of the current default <code>/privacy</code> page (shown to visitors when a field is empty)
							</div>
							<iframe title="Default Privacy Policy fallback preview" src="/privacy" class="privacy-fallback-iframe"></iframe>
						</div>
					{/if}
					<div class="privacy-policy-grid">
						<div class="mirror-block privacy-policy-block">
							<div class="mirror-block-header">
								<span class="mirror-block-name">🇬🇧 Privacy Policy Content (English)</span>
								{#if !privacyPolicyContentEn.trim()}<span class="privacy-fallback-badge">Using fallback</span>{/if}
							</div>
							<div class="block-controls">
								<label class="block-control">
									<span>HTML or plain text (leave empty to use default page)</span>
									<textarea bind:value={privacyPolicyContentEn}></textarea>
								</label>
								<div class="privacy-live-preview">
									<div class="privacy-live-preview-label">Live preview — how this will actually look</div>
									<div class="privacy-live-preview-body">
										{#if privacyPreviewEn}
											{@html privacyPreviewEn}
										{:else}
											<span class="privacy-preview-empty">Nothing typed yet — fallback page will be shown.</span>
										{/if}
									</div>
								</div>
							</div>
						</div>
						<div class="mirror-block privacy-policy-block">
							<div class="mirror-block-header">
								<span class="mirror-block-name">🇸🇦 Privacy Policy Content (Arabic)</span>
								{#if !privacyPolicyContentAr.trim()}<span class="privacy-fallback-badge">Using fallback</span>{/if}
							</div>
							<div class="block-controls">
								<label class="block-control">
									<span>HTML or plain text (leave empty to use default page)</span>
									<textarea dir="rtl" bind:value={privacyPolicyContentAr}></textarea>
								</label>
								<div class="privacy-live-preview" dir="rtl">
									<div class="privacy-live-preview-label">معاينة حية — كيف سيبدو المحتوى فعلياً</div>
									<div class="privacy-live-preview-body">
										{#if privacyPreviewAr}
											{@html privacyPreviewAr}
										{:else}
											<span class="privacy-preview-empty">لم يتم كتابة أي نص بعد — سيتم عرض صفحة الافتراضية.</span>
										{/if}
									</div>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.branding-manager {
		position: relative;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f5f7fb 0%, #eef1f8 50%, #f7f2e9 100%);
		min-height: 100%;
		color: #2a2a3a;
		font-family: inherit;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.branding-manager::before {
		content: '';
		position: absolute;
		inset: 0;
		z-index: 0;
		background:
			radial-gradient(circle at 15% 20%, rgba(59, 130, 246, 0.18), transparent 45%),
			radial-gradient(circle at 85% 10%, rgba(200, 145, 47, 0.18), transparent 45%),
			radial-gradient(circle at 30% 85%, rgba(31, 61, 47, 0.12), transparent 45%);
		filter: blur(40px);
	}

	.header,
	.tab-bar,
	.tab-content {
		position: relative;
		z-index: 1;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.25rem;
		padding: 1rem 1.25rem;
		background: rgba(255, 255, 255, 0.5);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 16px;
		box-shadow: 0 8px 24px rgba(31, 61, 47, 0.08);
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.header-icon {
		font-size: 2rem;
	}

	.header-title {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 700;
		color: #1f2937;
	}

	.header-subtitle {
		margin: 0;
		font-size: 0.8rem;
		color: #6b7280;
	}

	.tab-bar {
		display: flex;
		gap: 0.6rem;
		margin-bottom: 1.25rem;
	}

	.tab-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: rgba(255, 255, 255, 0.45);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		color: #4b5563;
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 10px;
		padding: 0.6rem 1.25rem;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		box-shadow: 0 6px 16px rgba(31, 61, 47, 0.06);
		transition: background 0.2s, color 0.2s, border-color 0.2s, box-shadow 0.2s;
	}

	.tab-btn:hover {
		background: rgba(255, 255, 255, 0.7);
		color: #1f2937;
	}

	.tab-btn.active {
		background: rgba(59, 130, 246, 0.85);
		color: #ffffff;
		border-color: rgba(59, 130, 246, 0.85);
		box-shadow: 0 8px 20px rgba(59, 130, 246, 0.3);
	}

	.tab-icon {
		font-size: 1rem;
	}

	.tab-content {
		flex: 1;
		display: flex;
	}

	.login-page-layout {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.section-bar {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.section-btn {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		color: #4b5563;
		border: 1px solid rgba(255, 255, 255, 0.55);
		border-radius: 999px;
		padding: 0.45rem 1rem;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		box-shadow: 0 4px 12px rgba(31, 61, 47, 0.05);
		transition: background 0.2s, color 0.2s, border-color 0.2s, box-shadow 0.2s;
	}

	.section-btn:hover {
		background: rgba(255, 255, 255, 0.65);
		color: #1f2937;
	}

	.section-btn.active {
		background: rgba(200, 145, 47, 0.85);
		color: #ffffff;
		border-color: rgba(200, 145, 47, 0.85);
		box-shadow: 0 6px 16px rgba(200, 145, 47, 0.3);
	}

	.section-icon {
		font-size: 0.95rem;
	}

	.content-panel {
		width: 100%;
		background: rgba(255, 255, 255, 0.5);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(255, 255, 255, 0.6);
		border-radius: 16px;
		padding: 2rem;
		display: flex;
		align-items: stretch;
		justify-content: center;
		min-height: 320px;
		box-shadow: 0 10px 28px rgba(31, 61, 47, 0.08);
	}

	.placeholder {
		text-align: center;
		color: #6b7280;
		max-width: 360px;
		align-self: center;
	}

	.placeholder-icon {
		display: block;
		font-size: 2.5rem;
		margin-bottom: 0.75rem;
	}

	.placeholder h3 {
		margin: 0 0 0.5rem;
		color: #1f2937;
		font-size: 1.05rem;
	}

	.placeholder p {
		margin: 0;
		font-size: 0.85rem;
		line-height: 1.5;
	}

	/* Home section mirror (exact replica of the public login page Hero section) */
	.home-mirror {
		width: 100%;
		background: #f7f2e9;
		border-radius: 12px;
		padding: 3rem 2rem 2rem;
		overflow: hidden;
	}

	.mirror-card-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1.25rem;
		align-items: stretch;
	}

	/* Editable content block wrapper (enable/disable + edit controls) */
	.mirror-block {
		position: relative;
		display: flex;
		flex-direction: column;
		height: 230px;
		border: 1.5px dashed rgba(31, 61, 47, 0.25);
		border-radius: 10px;
		padding: 0.75rem 0.75rem 0.5rem;
		transition: opacity 0.2s, border-color 0.2s;
		background: rgba(255, 255, 255, 0.35);
		overflow: hidden;
	}

	.mirror-block:hover {
		border-color: rgba(200, 145, 47, 0.6);
	}

	.mirror-block.disabled {
		opacity: 0.4;
	}

	.mirror-block-tall {
		height: 340px;
	}

	.mirror-block-nav {
		grid-column: 1 / -1;
		height: auto;
		min-height: 120px;
	}

	.mirror-nav-preview {
		display: flex;
		align-items: center;
		background: rgba(255, 255, 255, 0.6);
		border-radius: 8px;
		padding: 0.5rem 0.9rem;
	}

	.mirror-nav-btn {
		font-weight: 700;
		font-size: 0.9rem;
	}

	/* Top Bar section preview */
	.mirror-block-topbar {
		grid-column: 1 / -1;
		height: auto;
		min-height: 120px;
	}

	.mirror-topbar-preview,
	.mirror-topbar-logo-preview {
		display: flex;
		align-items: center;
		gap: 1rem;
		border-radius: 8px;
		padding: 0.6rem 1rem;
		transition: background 0.2s;
	}

	.mirror-topbar-logo-preview {
		justify-content: center;
		height: 110px;
	}

	.mirror-topbar-logo-badge {
		display: flex;
		align-items: center;
		justify-content: center;
		background: #ffffff;
		border-radius: 8px;
		padding: 0.3rem 0.7rem;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
		flex-shrink: 0;
	}

	.mirror-topbar-logo-img {
		height: 22px;
		width: auto;
		object-fit: contain;
		display: block;
	}

	.about-slots-hint {
		font-size: 0.78rem;
		color: #6b7280;
		margin: 0 0 0.6rem;
	}

	.about-slots-error {
		font-size: 0.78rem;
		color: #b91c1c;
		font-weight: 600;
		margin: 0 0 0.6rem;
	}

	.about-slots-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.5rem;
	}

	.about-slot-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.3rem;
		background: rgba(0, 0, 0, 0.03);
		border-radius: 8px;
		padding: 0.4rem;
	}

	.about-slot-card.disabled {
		opacity: 0.45;
	}

	.about-slot-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		gap: 0.3rem;
	}

	.toggle-switch-sm {
		width: 26px;
		height: 14px;
	}

	.toggle-switch-sm .toggle-knob {
		width: 10px;
		height: 10px;
	}

	.toggle-switch-sm.on .toggle-knob {
		transform: translateX(12px);
	}

	.about-slot-label {
		font-size: 0.68rem;
		font-weight: 600;
		color: #6b7280;
	}

	.about-slot-thumb {
		position: relative;
		width: 100%;
		aspect-ratio: 1 / 1;
		border-radius: 6px;
		overflow: hidden;
		background: rgba(0, 0, 0, 0.05);
	}

	.about-slot-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}

	.about-slot-thumb .remove-btn {
		position: absolute;
		top: 2px;
		right: 2px;
		width: 18px;
		height: 18px;
		font-size: 0.6rem;
		line-height: 1;
		padding: 0;
	}

	.about-slot-upload {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		font-size: 0.68rem;
		font-weight: 600;
		color: #1f3d2f;
		background: #ffffff;
		border: 1px solid rgba(31, 61, 47, 0.25);
		border-radius: 6px;
		padding: 0.2rem 0.5rem;
		cursor: pointer;
		width: 100%;
	}

	.about-slot-upload input[type='file'] {
		position: absolute;
		inset: 0;
		opacity: 0;
		cursor: pointer;
	}

	@media (max-width: 720px) {
		.about-slots-grid {
			grid-template-columns: repeat(3, 1fr);
		}
	}

	.careers-subtabs {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.careers-subtabs .lang-btn.on {
		background: #1f3d2f;
		color: #fff;
	}

	.careers-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.85rem;
	}

	.careers-table th,
	.careers-table td {
		text-align: left;
		padding: 0.55rem 0.6rem;
		border-bottom: 1px solid rgba(0, 0, 0, 0.08);
	}

	.careers-table th {
		font-weight: 700;
		color: #1f3d2f;
		background: rgba(0, 0, 0, 0.03);
	}

	.careers-table tr.disabled-row td {
		opacity: 0.5;
	}

	.careers-table select {
		padding: 0.3rem 0.4rem;
		border-radius: 6px;
		border: 1px solid #ddd;
		font-size: 0.8rem;
	}

	.careers-actions {
		display: flex;
		gap: 0.3rem;
		white-space: nowrap;
	}

	.careers-notes-editor {
		display: flex;
		gap: 0.5rem;
		align-items: flex-start;
		padding: 0.5rem 0;
	}

	.careers-notes-editor textarea {
		flex: 1;
		font-family: inherit;
		font-size: 0.85rem;
		padding: 0.4rem 0.5rem;
		border-radius: 8px;
		border: 1px solid #ddd;
		resize: vertical;
	}

	.contact-email-row {
		width: 100%;
	}

	.contact-email-input-row {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.contact-email-input-row input {
		flex: 1;
	}

	.careers-modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.4);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.careers-modal {
		background: #fff;
		border-radius: 12px;
		padding: 1.5rem;
		max-width: 560px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
	}

	.careers-modal h3 {
		margin: 0 0 1rem;
		color: #1f3d2f;
	}

	.careers-modal p {
		font-size: 0.85rem;
		color: #444;
		margin: 0 0 0.5rem;
	}

	.category-manage-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
		gap: 0.6rem;
	}

	.category-manage-card {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		background: rgba(0, 0, 0, 0.03);
		border-radius: 8px;
		padding: 0.5rem;
	}

	.category-manage-card.disabled {
		opacity: 0.45;
	}

	.category-manage-actions {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.3rem;
	}

	.category-thumb-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		font-size: 0.68rem;
		color: #9ca3af;
	}

	.category-manage-add {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		min-height: 120px;
		background: rgba(31, 61, 47, 0.05);
		border: 1px dashed rgba(31, 61, 47, 0.3);
		border-radius: 8px;
		color: #1f3d2f;
		font-weight: 600;
		font-size: 0.78rem;
		cursor: pointer;
	}

	.mirror-topbar-nav {
		display: flex;
		flex-wrap: wrap;
		gap: 1.1rem;
	}

	.mirror-topbar-link {
		color: #d8d8d8;
		font-size: 0.85rem;
		border-bottom: 2px solid transparent;
		padding-bottom: 0.2rem;
	}

	.mirror-topbar-link.active {
		color: #ffffff;
		border-bottom-color: #c8912f;
		font-weight: 600;
	}

	.mirror-topbar-lang {
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.35);
		border-radius: 14px;
		color: #ffffff;
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.2rem 0.6rem;
	}

	/* Simple background-color-only cards (About / Contact / Bottom sections) */
	.mirror-block-bgcolor {
		grid-column: 1 / -1;
		height: auto;
		min-height: 120px;
	}

	.mirror-bgcolor-preview {
		height: 70px;
		border-radius: 8px;
		border: 1px solid rgba(255, 255, 255, 0.4);
		transition: background 0.2s;
	}

	.section-save-bar {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.save-btn {
		padding: 0.5rem 1rem;
		border-radius: 8px;
		border: none;
		background: #1f3d2f;
		color: #fff;
		font-weight: 600;
		font-size: 0.85rem;
		cursor: pointer;
		transition: opacity 0.2s;
	}

	.save-btn:hover:not(:disabled) {
		opacity: 0.85;
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.save-msg {
		font-size: 0.85rem;
		font-weight: 500;
	}

	.mirror-block-toolbar {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 0.5rem;
		margin-bottom: 0.4rem;
	}

	.mirror-block-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.5rem;
		margin-bottom: 0.4rem;
	}

	.block-hint {
		font-size: 0.7rem;
		color: #8a9690;
		margin: 0 0 0.6rem;
		line-height: 1.4;
	}

	.mirror-block-header .mirror-block-toolbar {
		margin-bottom: 0;
	}

	.mirror-block-name {
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: #7a8a80;
		white-space: nowrap;
	}

	.toggle-switch {
		position: relative;
		width: 34px;
		height: 18px;
		background: rgba(31, 61, 47, 0.25);
		border: none;
		border-radius: 999px;
		cursor: pointer;
		padding: 2px;
		transition: background 0.2s;
	}

	.toggle-switch.on {
		background: #1f3d2f;
	}

	.toggle-knob {
		display: block;
		width: 14px;
		height: 14px;
		background: #ffffff;
		border-radius: 50%;
		transition: transform 0.2s;
		transform: translateX(0);
	}

	.toggle-switch.on .toggle-knob {
		transform: translateX(16px);
	}

	.edit-btn {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		background: rgba(255, 255, 255, 0.7);
		border: 1px solid rgba(31, 61, 47, 0.3);
		color: #1f3d2f;
		border-radius: 999px;
		padding: 0.2rem 0.65rem;
		font-size: 0.7rem;
		font-weight: 600;
		cursor: pointer;
	}

	.edit-btn:hover {
		background: #ffffff;
	}

	.lang-btn {
		background: rgba(59, 130, 246, 0.12);
		border: 1px solid rgba(59, 130, 246, 0.4);
		color: #2563eb;
		border-radius: 999px;
		padding: 0.2rem 0.55rem;
		font-size: 0.65rem;
		font-weight: 700;
		letter-spacing: 0.03em;
		cursor: pointer;
		min-width: 32px;
	}

	.lang-btn:hover {
		background: rgba(59, 130, 246, 0.2);
	}

	.remove-btn {
		background: rgba(220, 38, 38, 0.1);
		border: 1px solid rgba(220, 38, 38, 0.35);
		color: #dc2626;
		border-radius: 999px;
		width: 22px;
		height: 22px;
		line-height: 1;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
	}

	.remove-btn:hover {
		background: rgba(220, 38, 38, 0.2);
	}

	.mirror-block-add {
		height: 230px;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 0.35rem;
		border: 1.5px dashed rgba(200, 145, 47, 0.5);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.25);
		color: #c8912f;
		font-weight: 700;
		font-size: 0.85rem;
		cursor: pointer;
		transition: background 0.2s, border-color 0.2s;
	}

	.mirror-block-add:hover {
		background: rgba(255, 255, 255, 0.45);
		border-color: #c8912f;
	}

	.add-badge-icon {
		font-size: 1.4rem;
		line-height: 1;
	}

	.add-badge-count {
		font-size: 0.65rem;
		font-weight: 600;
		color: #7a8a80;
	}

	.block-controls {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
		margin-top: 0.6rem;
		padding-top: 0.6rem;
		border-top: 1px dashed rgba(31, 61, 47, 0.2);
	}

	.block-control {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #5c6b63;
	}

	.block-control input[type='text'] {
		border: 1px solid rgba(31, 61, 47, 0.25);
		border-radius: 6px;
		padding: 0.3rem 0.5rem;
		font-size: 0.75rem;
		background: rgba(255, 255, 255, 0.7);
		color: #1f3d2f;
		min-width: 140px;
	}

	.block-control textarea {
		border: 1px solid rgba(31, 61, 47, 0.25);
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		font-size: 0.78rem;
		font-family: 'Courier New', monospace;
		background: rgba(255, 255, 255, 0.7);
		color: #1f3d2f;
		width: 100%;
		resize: vertical;
	}

	.privacy-policy-note {
		font-size: 0.8rem;
		color: #5c6b63;
		margin: 0.25rem 0 1rem;
	}

	.privacy-policy-panel {
		align-items: stretch;
		min-height: calc(100vh - 260px);
	}

	.privacy-policy-mirror {
		display: flex;
		flex-direction: column;
		flex: 1;
	}

	.privacy-policy-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.25rem;
		align-items: stretch;
		flex: 1;
		min-height: 0;
	}

	.privacy-policy-block {
		display: flex;
		flex-direction: column;
		min-height: 0;
	}

	.privacy-policy-block .block-controls {
		flex: 1;
		display: flex;
		min-height: 0;
	}

	.privacy-policy-block .block-control {
		width: 100%;
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
		min-height: 0;
	}

	.privacy-policy-block .block-control textarea {
		flex: 1 1 45%;
		min-height: 160px;
		height: 100%;
	}

	.privacy-live-preview {
		flex: 1 1 45%;
		min-height: 160px;
		display: flex;
		flex-direction: column;
		border: 1px solid rgba(31, 61, 47, 0.2);
		border-radius: 8px;
		background: #fff;
		overflow: hidden;
	}

	.privacy-live-preview-label {
		font-size: 0.68rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		color: #5c6b63;
		padding: 0.4rem 0.6rem;
		background: rgba(31, 61, 47, 0.06);
		flex-shrink: 0;
	}

	.privacy-live-preview-body {
		flex: 1;
		overflow-y: auto;
		padding: 0.75rem 0.9rem;
		font-size: 0.85rem;
		line-height: 1.6;
		color: #1f3d2f;
	}

	.privacy-live-preview-body :global(p) {
		margin: 0 0 0.75rem;
	}

	.privacy-live-preview-body :global(p:last-child) {
		margin-bottom: 0;
	}

	.privacy-preview-empty {
		font-size: 0.8rem;
		color: #9aa5a0;
		font-style: italic;
	}

	.privacy-fallback-badge {
		font-size: 0.65rem;
		font-weight: 700;
		color: #9a6a1c;
		background: rgba(200, 145, 47, 0.18);
		border-radius: 999px;
		padding: 0.15rem 0.55rem;
		margin-left: auto;
	}

	.privacy-fallback-preview {
		margin-bottom: 1rem;
		border: 1px solid rgba(31, 61, 47, 0.2);
		border-radius: 10px;
		overflow: hidden;
		background: #fff;
	}

	.privacy-fallback-preview-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #5c6b63;
		padding: 0.5rem 0.75rem;
		background: rgba(31, 61, 47, 0.06);
	}

	.privacy-fallback-iframe {
		width: 100%;
		height: 420px;
		border: none;
		display: block;
	}

	@media (max-width: 960px) {
		.privacy-policy-grid {
			grid-template-columns: 1fr;
		}
	}

	.block-control select {
		border: 1px solid rgba(31, 61, 47, 0.25);
		border-radius: 6px;
		padding: 0.3rem 0.5rem;
		font-size: 0.75rem;
		background: rgba(255, 255, 255, 0.7);
		color: #1f3d2f;
		min-width: 140px;
	}

	.block-control-color {
		flex-direction: row;
		align-items: center;
		gap: 0.4rem;
	}

	.block-control input[type='color'] {
		width: 28px;
		height: 28px;
		padding: 0;
		border: 1px solid rgba(31, 61, 47, 0.25);
		border-radius: 6px;
		background: none;
		cursor: pointer;
	}

	.mirror-hero-text {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.mirror-hero-text h1 {
		font-size: 1.05rem;
		line-height: 1.3;
		margin: 0 0 0.4rem;
		color: #1f3d2f;
	}

	.mirror-accent {
		color: #c8912f;
	}

	.mirror-hero-text p {
		color: #555;
		margin: 0;
		line-height: 1.5;
		font-size: 0.75rem;
	}

	.mirror-hero-actions {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.85rem;
	}

	.mirror-btn {
		padding: 0.55rem 1.1rem;
		border-radius: 10px;
		font-weight: 600;
		cursor: default;
		border: 1.5px solid rgba(31, 61, 47, 0.5);
		font-size: 0.8rem;
	}

	.mirror-btn-outline {
		background: rgba(255, 255, 255, 0.4);
		color: #1f3d2f;
	}

	.mirror-hero-logo-wrap {
		position: relative;
		flex: 1;
		min-height: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.mirror-hero-logo {
		position: relative;
		z-index: 1;
		max-width: 70%;
		max-height: 100px;
		object-fit: contain;
		filter: drop-shadow(0 12px 20px rgba(31, 61, 47, 0.25));
	}

	.mirror-hero-blob {
		position: absolute;
		border-radius: 50%;
		filter: blur(18px);
	}

	.mirror-hero-blob.b1 {
		width: 80px;
		height: 80px;
		background: rgba(31, 61, 47, 0.25);
		top: 10%;
		left: 15%;
	}

	.mirror-hero-blob.b2 {
		width: 65px;
		height: 65px;
		background: rgba(200, 145, 47, 0.3);
		bottom: 10%;
		right: 10%;
	}

	.mirror-hero-blob.b3 {
		width: 50px;
		height: 50px;
		background: rgba(31, 61, 47, 0.15);
		bottom: 25%;
		left: 30%;
	}

	.mirror-hero-badges {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.mirror-badge {
		display: flex;
		gap: 0.5rem;
		align-items: flex-start;
		background: rgba(255, 255, 255, 0.55);
		border: 1px solid rgba(255, 255, 255, 0.7);
		border-radius: 10px;
		padding: 0.5rem 0.65rem;
		box-shadow: 0 4px 12px rgba(31, 61, 47, 0.08);
	}

	.mirror-badge-icon {
		color: #c8912f;
		font-size: 0.95rem;
	}

	.mirror-badge strong {
		display: block;
		color: #1f3d2f;
		margin-bottom: 0.1rem;
		font-size: 0.8rem;
	}

	.mirror-badge p {
		margin: 0;
		font-size: 0.7rem;
		color: #777;
	}

	@media (max-width: 900px) {
		.mirror-card-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (max-width: 700px) {
		.mirror-card-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
