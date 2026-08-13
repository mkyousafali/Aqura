<script lang="ts">
	import { onMount } from 'svelte';

	let supabase: any = null;
	let loading = true;
	let saving = false;
	let scrollContainer: HTMLDivElement;

	let configId: string | null = null;
	let botNameEn = '';
	let botNameAr = '';

	// Dashboard — bot switch and usage counters
	let isEnabled = false;
	let togglingBot = false;
	let refreshingStats = false;
	let tokensUsed = 0;
	let promptTokensUsed = 0;
	let completionTokensUsed = 0;
	let totalRequests = 0;
	// Gemini pay-as-you-go rate per token, converted to SAR
	$: estimatedCostSar = tokensUsed * 0.00000024 * 3.75;

	// Links — each has its own URL and its own CTA button wording per language.
	// The webhook picks one of these per reply; nothing is hardcoded there.
	interface LinkConfig {
		key: 'app' | 'offers' | 'promotions';
		title: string;
		hint: string;
		urlField: string;
		enField: string;
		arField: string;
		url: string;
		labelEn: string;
		labelAr: string;
	}
	let links: LinkConfig[] = [
		{
			key: 'app', title: '📱 Business App Link',
			hint: 'Default button. Used when the reply is not about offers or promotions, and as the fallback when the other links are empty.',
			urlField: 'app_link', enField: 'app_link_button_en', arField: 'app_link_button_ar',
			url: '', labelEn: '', labelAr: ''
		},
		{
			key: 'offers', title: '🛍️ Offers Link',
			hint: 'Used when the customer asks about offers, prices or points. Falls back to the Business App link if left empty.',
			urlField: 'offers_link', enField: 'offers_link_button_en', arField: 'offers_link_button_ar',
			url: '', labelEn: '', labelAr: ''
		},
		{
			key: 'promotions', title: '🎁 Promotions Link',
			hint: 'Used when the customer asks about promotions, campaigns or giveaways. Falls back to the Business App link if left empty.',
			urlField: 'promotions_link', enField: 'promotions_link_button_en', arField: 'promotions_link_button_ar',
			url: '', labelEn: '', labelAr: ''
		}
	];
	let savingLink: string | null = null;
	let savedLinkKey: string | null = null;

	// Offers: send the branch's active offer PDFs instead of the link
	let offersSendPdf = false;
	let savingOffersPdf = false;
	let offersPdfSaved = false;

	// Behavior Rules (bot_rules)
	let savedBotRules = '';
	let botRulesDraft = '';
	let savingBotRules = false;
	const botRulesExample = `Behaviour the AI must follow that isn't covered by the other sections, e.g.:

- Rate/price enquiries: what to offer, and whether to ask permission before transferring
- Whether the AI may transfer to a human on its own, or only with the customer's consent
- Human support hours to quote to customers
- Formatting limits: how many emojis, how many lines per reply
- How to close a conversation politely`;

	// Training Q&A pairs
	interface QAPair { prompt: string; response: string; }
	let trainingQA: QAPair[] = [];
	let savingTraining = false;
	let trainingSaved = false;

	// Edit state (view vs edit mode per field)
	let editingEn = false;
	let editingAr = false;
	let draftEn = '';
	let draftAr = '';

	// Card 2 — Tone
	const toneOptions = ['friendly', 'professional', 'casual', 'formal', 'empathetic', 'enthusiastic'];
	let savedTone = '';
	let toneDraft = '';
	let savingTone = false;

	// Card 3 — Language Rules
	let savedLanguageRules = '';
	let languageRulesDraft = '';
	let savingLanguageRules = false;
	const languageRulesExample = `## AI Language Rule

1. Automatically detect the language used by the user.
2. Always reply in the same language as the user's latest message unless the user requests another language.
3. If the user mixes languages, reply using the main language while keeping technical terms, names, product names, and codes unchanged.
4. For Arabic, use clear Modern Standard Arabic unless the user specifically requests a dialect.
5. For English, use simple, clear, professional English.
6. Never translate names, IDs, database values, URLs, codes, or technical terms unless explicitly requested.
7. If the user's intended language cannot be confidently detected, default to English.
8. Maintain the selected language throughout the conversation until the user changes languages or asks to switch.
9. When correcting spelling or grammar, preserve the original language and meaning without adding new information.
10. If the user explicitly requests a translation, translate only the requested content and preserve its meaning and structure.`;

	// Card 4 — Business Information (knowledge base the AI can reference when replying)
	let savedBusinessInfo = '';
	let businessInfoDraft = '';
	let savingBusinessInfo = false;
	const businessInfoExample = `Business Name - short description of what you do
Branches: list your branch names/locations
Hours: e.g. 9 AM - 6 PM (Sunday to Thursday)
Delivery areas: your service areas
Website / App: https://yourbrand.com
Contact: support@yourbrand.com

Include anything the AI should know when answering customers: policies, amenities, payment methods, loyalty program details, etc.`;

	// Card 5 — Services
	let savedServicesInfo = '';
	let servicesInfoDraft = '';
	let savingServicesInfo = false;
	const servicesInfoExample = `List the services you offer, and which branch/location each one is available at:

- Service name — available at [branch], not available at [branch]
- Delivery — available / not currently available
- Loyalty program — link to app, how customers use it
- Any other service-specific details (booking, walk-in only, etc.)`;

	// Card 6 — Problem & Issue Handling
	let savedProblemHandling = '';
	let problemHandlingDraft = '';
	let savingProblemHandling = false;
	const problemHandlingExample = `Describe how the AI should handle common problems, e.g.:

- Damaged/defective/expired products: what to collect (photo, receipt, branch), then escalate — never promise a refund/replacement itself
- Duplicate charges: steps to advise the customer, when to escalate
- Price questions the AI can't verify: never guess, escalate instead
- Stock availability questions: never claim available/unavailable, escalate instead
- Any case requiring investigation, approval, compensation, or refund: escalate, never promise the outcome`;

	// Card 2 — Escalation Keywords (exact match → acknowledgement + turn off AI)
	let escalationKeywords: string[] = [];
	let escalationKeywordInput = '';
	let savedAckMessage = '';
	let ackMessageDraft = '';
	let savingEscalation = false;
	let savedEscalationKeywords: string[] = [];
	let escalationHasSavedData = false;

	// Card 2 — Non-Keyword Escalation Rules — free-text instructions the AI judges against
	let savedNonKeywordRules = '';
	let nonKeywordRulesDraft = '';
	const nonKeywordRulesExample = `Escalate to a human agent when the customer:
- Explicitly asks for a manager, supervisor, or human agent
- Expresses frustration, anger, or dissatisfaction with the bot
- Says the bot isn't helping or understanding them
- Repeats the same question multiple times without a satisfying answer
- Uses aggressive tone, ALL CAPS, or repeated punctuation (e.g. "!!!")
- Mentions wanting to file a complaint

Do NOT escalate for general questions about products, offers, hours, or prices — answer those normally.`;

	// Card 2 — Escalation reply texts (language-aware, EN/AR pairs) — sent based on which category the AI decides.
	// General Query: customer asks something the AI can't reliably confirm (price, stock, vacancy, etc.), no frustration.
	let contextGatheringReplyEn = '';
	let contextGatheringReplyAr = '';
	// Complaint/Frustration: customer is upset, dissatisfied, or the issue is unresolved.
	let complaintReplyEn = '';
	let complaintReplyAr = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadIdentity();
	});

	async function loadIdentity() {
		loading = true;
		try {
			const { data } = await supabase
				.from('wa_ai_bot_config')
				.select('id, bot_name, bot_name_ar, tone, language_rules, custom_instructions, services_information, problem_handling_info, escalation_keywords, escalation_ack_message, escalation_rules_instructions, escalation_context_gathering_reply_en, escalation_context_gathering_reply_ar, escalation_complaint_reply_en, escalation_complaint_reply_ar, is_enabled, app_link, app_link_button_en, app_link_button_ar, offers_link, offers_link_button_en, offers_link_button_ar, promotions_link, promotions_link_button_en, promotions_link_button_ar, offers_send_pdf_enabled, bot_rules, training_qa, tokens_used, prompt_tokens_used, completion_tokens_used, total_requests')
				.order('created_at', { ascending: true })
				.limit(1)
				.maybeSingle();

			if (data) {
				configId = data.id;
				botNameEn = data.bot_name || '';
				botNameAr = data.bot_name_ar || '';
				savedTone = data.tone || '';
				toneDraft = savedTone;
				savedLanguageRules = data.language_rules || '';
				languageRulesDraft = savedLanguageRules;
				savedBusinessInfo = data.custom_instructions || '';
				businessInfoDraft = savedBusinessInfo;
				savedServicesInfo = data.services_information || '';
				servicesInfoDraft = savedServicesInfo;
				savedProblemHandling = data.problem_handling_info || '';
				problemHandlingDraft = savedProblemHandling;
				savedEscalationKeywords = Array.isArray(data.escalation_keywords) ? data.escalation_keywords : [];
				escalationKeywords = [...savedEscalationKeywords];
				savedAckMessage = data.escalation_ack_message || '';
				ackMessageDraft = savedAckMessage;

				savedNonKeywordRules = data.escalation_rules_instructions || '';
				nonKeywordRulesDraft = savedNonKeywordRules;
				contextGatheringReplyEn = data.escalation_context_gathering_reply_en || '';
				contextGatheringReplyAr = data.escalation_context_gathering_reply_ar || '';
				complaintReplyEn = data.escalation_complaint_reply_en || '';
				complaintReplyAr = data.escalation_complaint_reply_ar || '';

				isEnabled = data.is_enabled ?? false;
				offersSendPdf = data.offers_send_pdf_enabled ?? false;
				links = links.map((l) => ({
					...l,
					url: data[l.urlField] || '',
					labelEn: data[l.enField] || '',
					labelAr: data[l.arField] || ''
				}));
				savedBotRules = data.bot_rules || '';
				botRulesDraft = savedBotRules;
				trainingQA = Array.isArray(data.training_qa) ? data.training_qa : [];
				tokensUsed = data.tokens_used ?? 0;
				promptTokensUsed = data.prompt_tokens_used ?? 0;
				completionTokensUsed = data.completion_tokens_used ?? 0;
				totalRequests = data.total_requests ?? 0;

				escalationHasSavedData = savedEscalationKeywords.length > 0 || !!savedAckMessage ||
					!!savedNonKeywordRules ||
					!!contextGatheringReplyEn || !!contextGatheringReplyAr ||
					!!complaintReplyEn || !!complaintReplyAr;
			}
		} catch (err) {
			console.error('Error loading bot identity:', err);
		}
		loading = false;
	}

	function startEdit(lang: 'en' | 'ar') {
		if (lang === 'en') { draftEn = botNameEn; editingEn = true; }
		else { draftAr = botNameAr; editingAr = true; }
	}

	function cancelEdit(lang: 'en' | 'ar') {
		if (lang === 'en') editingEn = false;
		else editingAr = false;
	}

	async function saveIdentity(lang: 'en' | 'ar') {
		saving = true;
		try {
			const payload = lang === 'en' ? { bot_name: draftEn } : { bot_name_ar: draftAr };

			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}

			if (lang === 'en') { botNameEn = draftEn; editingEn = false; }
			else { botNameAr = draftAr; editingAr = false; }
		} catch (err) {
			console.error('Error saving bot identity:', err);
		}
		saving = false;
	}

	async function saveTone() {
		savingTone = true;
		try {
			const payload = { tone: toneDraft };
			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedTone = toneDraft;
		} catch (err) {
			console.error('Error saving tone:', err);
		}
		savingTone = false;
	}

	async function saveLanguageRules() {
		savingLanguageRules = true;
		try {
			const payload = { language_rules: languageRulesDraft };
			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedLanguageRules = languageRulesDraft;
		} catch (err) {
			console.error('Error saving language rules:', err);
		}
		savingLanguageRules = false;
	}

	async function saveBusinessInfo() {
		savingBusinessInfo = true;
		try {
			const payload = { custom_instructions: businessInfoDraft };
			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedBusinessInfo = businessInfoDraft;
		} catch (err) {
			console.error('Error saving business information:', err);
		}
		savingBusinessInfo = false;
	}

	async function saveServicesInfo() {
		savingServicesInfo = true;
		try {
			const payload = { services_information: servicesInfoDraft };
			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedServicesInfo = servicesInfoDraft;
		} catch (err) {
			console.error('Error saving services information:', err);
		}
		savingServicesInfo = false;
	}

	async function saveProblemHandling() {
		savingProblemHandling = true;
		try {
			const payload = { problem_handling_info: problemHandlingDraft };
			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedProblemHandling = problemHandlingDraft;
		} catch (err) {
			console.error('Error saving problem handling info:', err);
		}
		savingProblemHandling = false;
	}

	// Single patch helper for the sections migrated from the old AI Bot window.
	// Patches one field group at a time so two sections can never overwrite
	// each other the way the old window's whole-payload save did.
	async function persist(payload: Record<string, any>) {
		if (configId) {
			const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
			if (error) throw error;
		} else {
			const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
			if (error) throw error;
			configId = data.id;
		}
	}

	async function toggleBot() {
		togglingBot = true;
		const next = !isEnabled;
		try {
			await persist({ is_enabled: next });
			isEnabled = next;
		} catch (err) {
			console.error('Error toggling bot:', err);
		}
		togglingBot = false;
	}

	async function refreshStats() {
		refreshingStats = true;
		try {
			const { data } = await supabase
				.from('wa_ai_bot_config')
				.select('tokens_used, prompt_tokens_used, completion_tokens_used, total_requests')
				.eq('id', configId)
				.maybeSingle();
			if (data) {
				tokensUsed = data.tokens_used ?? 0;
				promptTokensUsed = data.prompt_tokens_used ?? 0;
				completionTokensUsed = data.completion_tokens_used ?? 0;
				totalRequests = data.total_requests ?? 0;
			}
		} catch (err) {
			console.error('Error refreshing usage stats:', err);
		}
		refreshingStats = false;
	}

	async function saveOffersSendPdf() {
		savingOffersPdf = true;
		try {
			await persist({ offers_send_pdf_enabled: offersSendPdf });
			offersPdfSaved = true;
			setTimeout(() => (offersPdfSaved = false), 2500);
		} catch (err) {
			console.error('Error saving offers PDF setting:', err);
		}
		savingOffersPdf = false;
	}

	async function saveLink(link: LinkConfig) {
		savingLink = link.key;
		try {
			await persist({
				[link.urlField]: link.url,
				[link.enField]: link.labelEn,
				[link.arField]: link.labelAr
			});
			savedLinkKey = link.key;
			setTimeout(() => {
				if (savedLinkKey === link.key) savedLinkKey = null;
			}, 2500);
		} catch (err) {
			console.error('Error saving link:', err);
		}
		savingLink = null;
	}

	async function saveBotRules() {
		savingBotRules = true;
		try {
			await persist({ bot_rules: botRulesDraft });
			savedBotRules = botRulesDraft;
		} catch (err) {
			console.error('Error saving behavior rules:', err);
		}
		savingBotRules = false;
	}

	function addQAPair() {
		trainingQA = [...trainingQA, { prompt: '', response: '' }];
	}

	function removeQAPair(idx: number) {
		trainingQA = trainingQA.filter((_, i) => i !== idx);
	}

	async function saveTrainingQA() {
		savingTraining = true;
		try {
			const clean = trainingQA.filter((qa) => qa.prompt.trim() || qa.response.trim());
			await persist({ training_qa: clean });
			trainingQA = clean;
			trainingSaved = true;
			setTimeout(() => (trainingSaved = false), 2500);
		} catch (err) {
			console.error('Error saving training examples:', err);
		}
		savingTraining = false;
	}

	function addEscalationKeyword() {
		const word = escalationKeywordInput.trim();
		if (!word) return;
		if (!escalationKeywords.some((k) => k.toLowerCase() === word.toLowerCase())) {
			escalationKeywords = [...escalationKeywords, word];
		}
		escalationKeywordInput = '';
	}

	function removeEscalationKeyword(idx: number) {
		escalationKeywords = escalationKeywords.filter((_, i) => i !== idx);
	}

	function handleEscalationKeywordKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			addEscalationKeyword();
		}
	}

	async function saveEscalation() {
		savingEscalation = true;
		try {
			const payload: Record<string, any> = {
				escalation_keywords: escalationKeywords,
				escalation_ack_message: ackMessageDraft,
				escalation_rules_instructions: nonKeywordRulesDraft,
				escalation_context_gathering_reply_en: contextGatheringReplyEn,
				escalation_context_gathering_reply_ar: contextGatheringReplyAr,
				escalation_complaint_reply_en: complaintReplyEn,
				escalation_complaint_reply_ar: complaintReplyAr,
				escalation_ack_translations: {}, // invalidate cached AI translations so edits take effect immediately
			};

			if (configId) {
				const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select('id').single();
				if (error) throw error;
				configId = data.id;
			}
			savedEscalationKeywords = [...escalationKeywords];
			savedAckMessage = ackMessageDraft;
			savedNonKeywordRules = nonKeywordRulesDraft;
			escalationHasSavedData = true;
		} catch (err) {
			console.error('Error saving escalation settings:', err);
		}
		savingEscalation = false;
	}

	function scrollToSection(id: string) {
		const container = scrollContainer;
		const target = document.getElementById(id);
		if (!container || !target) return;
		const top = target.offsetTop - container.offsetTop - 8;
		container.scrollTo({ top: Math.max(top, 0), behavior: 'smooth' });
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4">
		<div class="flex items-center justify-between">
			<div class="flex items-center gap-3">
				<span class="text-2xl">💬</span>
				<h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">AI Reply</h1>
			</div>
			<div class="flex items-center gap-2 flex-wrap justify-end">
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-dashboard')}>
					📊 Dashboard
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-who-am-i')}>
					🙋 Who am I
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-links')}>
					🔗 Links
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-escalation')}>
					🆘 Escalations
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-language-rules')}>
					🌐 Language Rules
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-business-info')}>
					📚 Business Info
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-services')}>
					🛎️ Services
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-problem-handling')}>
					🛠️ Problem Handling
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-behavior-rules')}>
					📋 Behavior Rules
				</button>
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-training')}>
					🎓 Training
				</button>
			</div>
		</div>
	</div>

	<div class="flex-1 overflow-y-auto p-6" bind:this={scrollContainer}>
		{#if loading}
			<div class="flex justify-center items-center h-full">
				<div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
			</div>
		{:else}
			<div class="grid grid-cols-1 gap-4">
				<!-- Dashboard — status and usage, one compact row -->
				<div id="card-dashboard" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-4 shadow-sm">
					<div class="flex items-center justify-between mb-2.5">
						<h2 class="flex items-center gap-2 text-xs font-bold text-slate-700 uppercase tracking-wide">
							<span class="text-sm">📊</span>
							Dashboard
						</h2>
						<button on:click={refreshStats} disabled={refreshingStats}
							class="text-[10px] text-slate-600 hover:text-emerald-600 font-bold bg-slate-100 hover:bg-emerald-100 px-2.5 py-1 rounded-lg transition-all disabled:opacity-50"
							title="Refresh stats">
							<span class:animate-spin={refreshingStats}>🔄</span> Refresh
						</button>
					</div>

					<div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2">
						<!-- Bot switch -->
						<div class="bg-slate-50 border border-slate-200 rounded-lg p-2.5 flex flex-col justify-between">
							<div class="text-[9px] font-bold text-slate-500 uppercase leading-tight">Bot Status</div>
							<div class="text-sm font-black {isEnabled ? 'text-emerald-600' : 'text-slate-400'} leading-tight my-0.5">
								{isEnabled ? '🟢 Active' : '⚪ Off'}
							</div>
							<button
								class="w-full px-2 py-1 rounded text-[10px] font-bold transition-all disabled:opacity-50 {isEnabled ? 'bg-rose-100 text-rose-700 hover:bg-rose-200' : 'bg-emerald-600 text-white hover:bg-emerald-700'}"
								on:click={toggleBot} disabled={togglingBot}>
								{togglingBot ? '...' : (isEnabled ? 'Turn Off' : 'Turn On')}
							</button>
						</div>

						<div class="bg-gradient-to-br from-blue-50 to-blue-100/50 rounded-lg p-2.5 border border-blue-200/50">
							<div class="text-[9px] font-bold text-blue-600 uppercase leading-tight">Total Tokens</div>
							<div class="text-base font-black text-blue-700 leading-tight mt-1 truncate" title={tokensUsed.toLocaleString()}>{tokensUsed.toLocaleString()}</div>
							<div class="text-[9px] text-blue-600/70">Lifetime</div>
						</div>
						<div class="bg-gradient-to-br from-purple-50 to-purple-100/50 rounded-lg p-2.5 border border-purple-200/50">
							<div class="text-[9px] font-bold text-purple-600 uppercase leading-tight">Input Tokens</div>
							<div class="text-base font-black text-purple-700 leading-tight mt-1 truncate" title={promptTokensUsed.toLocaleString()}>{promptTokensUsed.toLocaleString()}</div>
							<div class="text-[9px] text-purple-600/70">Prompts</div>
						</div>
						<div class="bg-gradient-to-br from-amber-50 to-amber-100/50 rounded-lg p-2.5 border border-amber-200/50">
							<div class="text-[9px] font-bold text-amber-600 uppercase leading-tight">Output Tokens</div>
							<div class="text-base font-black text-amber-700 leading-tight mt-1 truncate" title={completionTokensUsed.toLocaleString()}>{completionTokensUsed.toLocaleString()}</div>
							<div class="text-[9px] text-amber-600/70">Replies</div>
						</div>
						<div class="bg-gradient-to-br from-emerald-50 to-emerald-100/50 rounded-lg p-2.5 border border-emerald-200/50">
							<div class="text-[9px] font-bold text-emerald-600 uppercase leading-tight">API Calls</div>
							<div class="text-base font-black text-emerald-700 leading-tight mt-1 truncate" title={totalRequests.toLocaleString()}>{totalRequests.toLocaleString()}</div>
							<div class="text-[9px] text-emerald-600/70">Messages</div>
						</div>
						<div class="bg-gradient-to-br from-slate-50 to-slate-100 rounded-lg p-2.5 border border-slate-200">
							<div class="text-[9px] font-bold text-slate-600 uppercase leading-tight">Est. Cost</div>
							<div class="text-base font-black text-slate-800 leading-tight mt-1 truncate">
								{estimatedCostSar.toFixed(4)}<span class="text-[10px] text-slate-600 ml-1">SAR</span>
							</div>
							<div class="text-[9px] text-slate-500">Pay-as-you-go</div>
						</div>
					</div>
				</div>

				<div id="card-who-am-i" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">1</span>
						🙋 Who Am I — Bot Identity
					</h2>

					<!-- English Name -->
					<div class="mb-4">
						<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Bot Name (English)</span>
						{#if editingEn}
							<div class="space-y-2">
								<input type="text" bind:value={draftEn} placeholder="e.g. Aqura Assistant"
									class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all" />
								<div class="flex gap-2">
									<button class="flex-1 px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
										on:click={() => saveIdentity('en')} disabled={saving}>{saving ? '...' : 'Save'}</button>
									<button class="flex-1 px-3 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-lg hover:bg-slate-200"
										on:click={() => cancelEdit('en')}>Cancel</button>
								</div>
							</div>
						{:else}
							<div class="flex items-center justify-between px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg">
								<span class="text-sm text-slate-800">{botNameEn || '—'}</span>
								<button class="text-xs font-bold text-blue-600 hover:text-blue-700" on:click={() => startEdit('en')}>✏️ Edit</button>
							</div>
						{/if}
					</div>

					<!-- Arabic Name -->
					<div>
						<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Bot Name (Arabic)</span>
						{#if editingAr}
							<div class="space-y-2">
								<input type="text" dir="rtl" bind:value={draftAr} placeholder="مثلاً: مساعد أكورا"
									class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all" />
								<div class="flex gap-2">
									<button class="flex-1 px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
										on:click={() => saveIdentity('ar')} disabled={saving}>{saving ? '...' : 'Save'}</button>
									<button class="flex-1 px-3 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-lg hover:bg-slate-200"
										on:click={() => cancelEdit('ar')}>Cancel</button>
								</div>
							</div>
						{:else}
							<div class="flex items-center justify-between px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg">
								<span class="text-sm text-slate-800" dir="rtl">{botNameAr || '—'}</span>
								<button class="text-xs font-bold text-blue-600 hover:text-blue-700" on:click={() => startEdit('ar')}>✏️ Edit</button>
							</div>
						{/if}
					</div>

					<!-- Bot Tone -->
					<div class="mt-4">
						<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">🎭 Reply Tone</span>
						<select bind:value={toneDraft}
							class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm capitalize focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all mb-2">
							<option value="" disabled>— Select tone —</option>
							{#each toneOptions as opt}
								<option value={opt} class="capitalize">{opt}</option>
							{/each}
						</select>
						<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
							on:click={saveTone} disabled={savingTone}>
							{savingTone ? '...' : (savedTone ? 'Change' : 'Save')}
						</button>
						{#if savedTone}
							<p class="text-[10px] text-slate-400 mt-2">Current: <span class="capitalize font-bold text-slate-600">{savedTone}</span></p>
						{/if}
					</div>

					</div>

				<!-- Card 2 — Links & CTA Buttons -->
				<div id="card-links" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-1">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">2</span>
						🔗 Links & CTA Buttons
					</h2>
					<p class="text-[10px] text-slate-400 mb-4">Every AI reply carries one CTA button. The AI picks which link fits the customer's question, and the button wording below is what the customer sees — nothing is hardcoded in the bot.</p>

					<div class="space-y-4">
						{#each links as link (link.key)}
							<div class="bg-slate-50 border border-slate-200 rounded-xl p-4">
								<span class="text-xs font-bold text-slate-700 block mb-1">{link.title}</span>
								<p class="text-[10px] text-slate-400 mb-2">{link.hint}</p>

								<span class="text-[10px] font-bold text-slate-500 uppercase mb-1 block">URL</span>
								<input type="text" bind:value={link.url} placeholder="e.g. https://yourbrand.app/login"
									class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 mb-3" />

								<div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
									<div>
										<span class="text-[10px] font-bold text-slate-500 uppercase mb-1 block">Button Text (English)</span>
										<input type="text" bind:value={link.labelEn} placeholder="e.g. Browse Offers 🛍️"
											class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400" />
									</div>
									<div>
										<span class="text-[10px] font-bold text-slate-500 uppercase mb-1 block">Button Text (Arabic)</span>
										<input type="text" dir="rtl" bind:value={link.labelAr} placeholder="مثلاً: تصفح العروض 🛍️"
											class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400" />
									</div>
								</div>

								<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
									on:click={() => saveLink(link)} disabled={savingLink === link.key}>
									{savingLink === link.key ? '...' : (savedLinkKey === link.key ? '✓ Saved' : 'Save')}
								</button>

								{#if link.key === 'offers'}
								<div class="mt-3 pt-3 border-t border-slate-200">
									<label class="flex items-start gap-2 cursor-pointer">
										<input type="checkbox" bind:checked={offersSendPdf} on:change={saveOffersSendPdf}
											disabled={savingOffersPdf} class="accent-emerald-600 mt-0.5" />
										<span>
											<span class="text-xs font-bold text-slate-700">
												Send the offer PDF instead of this link
												{#if savingOffersPdf}<span class="text-slate-400 font-normal">saving…</span>
												{:else if offersPdfSaved}<span class="text-emerald-600 font-normal">✓ saved</span>{/if}
											</span>
											<span class="block text-[10px] text-slate-400 mt-0.5">
												When ticked, an offers question replies with branch buttons — listing only branches whose offers are valid at that moment (start and end date/time checked) — and sends that branch's offer PDF as soon as the customer picks one. The link above is used only as a fallback when nothing is currently running.
											</span>
										</span>
									</label>
								</div>
							{/if}

							{#if link.key === 'app' && !link.url.trim()}
									<p class="text-[10px] text-rose-600 mt-2">⚠️ The Business App link is the fallback for every reply. With it empty and no other link set, replies are sent as plain text with no button.</p>
								{/if}
								{#if link.url.trim() && !(link.labelEn.trim() && link.labelAr.trim())}
									<p class="text-[10px] text-amber-600 mt-2">⚠️ Set both English and Arabic button text — the missing one leaves the button blank for customers writing in that language.</p>
								{/if}
							</div>
						{/each}
					</div>
				</div>

				<!-- Card 2 — Escalation Keywords -->
				<div id="card-escalation" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">3</span>
						🆘 Escalation Rules
					</h2>

					<!-- Keywords list -->
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Escalation Keywords (any language)</span>
					<p class="text-[10px] text-slate-400 mb-2">When a customer's message is <b>exactly</b> one of these words, the acknowledgement below is sent and AI reply is turned off for that customer.</p>
					<div class="flex gap-2 mb-2">
						<input type="text" bind:value={escalationKeywordInput} placeholder="e.g. خدمة, help, aiuto..."
							class="flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all"
							on:keydown={handleEscalationKeywordKeydown} />
						<button class="px-3 py-2 bg-emerald-100 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-200"
							on:click={addEscalationKeyword}>Add</button>
					</div>
					<div class="flex flex-wrap gap-1.5 mb-4">
						{#each escalationKeywords as word, idx}
							<span class="px-2.5 py-1 bg-emerald-100 text-emerald-700 text-xs rounded-full font-bold flex items-center gap-1.5">
								{word}
								<button class="text-emerald-500 hover:text-red-500" on:click={() => removeEscalationKeyword(idx)}>✕</button>
							</span>
						{/each}
						{#if escalationKeywords.length === 0}
							<span class="text-xs text-slate-300">No keywords added yet</span>
						{/if}
					</div>

					<!-- Acknowledgement message -->
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Escalation Acknowledgement Message</span>
					<p class="text-[10px] text-slate-400 mb-2">Written in any language — the AI rephrases it naturally in the customer's own language when sending.</p>
					<textarea bind:value={ackMessageDraft} rows="4" placeholder="e.g. Thank you, our team will contact you shortly."
						class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>

					<hr class="border-slate-200 my-4" />

					<p class="text-[11px] font-bold text-slate-600 mb-1">🧠 Non-Keyword Escalation Rules</p>
					<p class="text-[10px] text-slate-400 mb-2">Written as plain instructions — the AI reads these and decides for itself whether to escalate, instead of matching fixed word/phrase lists. Leave empty to disable this and rely only on the exact keywords above.</p>
					<textarea bind:value={nonKeywordRulesDraft} rows="10" placeholder={nonKeywordRulesExample}
						class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>

					<hr class="border-slate-200 my-4" />

					<p class="text-[11px] font-bold text-slate-600 mb-1">📋 General Query Escalation Reply</p>
					<p class="text-[10px] text-slate-400 mb-3">Sent when the AI escalates because the customer asked something it can't reliably confirm (price, stock, vacancy, etc.) with no sign of frustration.</p>

					<div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
						<div>
							<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">General Query Reply (English)</span>
							<textarea bind:value={contextGatheringReplyEn} rows="4"
								class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y"></textarea>
						</div>
						<div>
							<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">General Query Reply (Arabic)</span>
							<textarea bind:value={contextGatheringReplyAr} dir="rtl" rows="4"
								class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y"></textarea>
						</div>
					</div>

					<hr class="border-slate-200 my-4" />

					<p class="text-[11px] font-bold text-slate-600 mb-1">😤 Complaint / Frustration Escalation Reply</p>
					<p class="text-[10px] text-slate-400 mb-3">Sent when the AI escalates because the customer is frustrated, upset, or the issue remains unresolved.</p>

					<div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
						<div>
							<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Complaint Reply (English)</span>
							<textarea bind:value={complaintReplyEn} rows="4"
								class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y"></textarea>
						</div>
						<div>
							<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Complaint Reply (Arabic)</span>
							<textarea bind:value={complaintReplyAr} dir="rtl" rows="4"
								class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y"></textarea>
						</div>
					</div>

					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveEscalation} disabled={savingEscalation}>
						{savingEscalation ? '...' : (escalationHasSavedData ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 3 — Language Rules -->
				<div id="card-language-rules" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">4</span>
						🌐 Language Rules
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Rules the AI must follow for language handling</span>
					<textarea bind:value={languageRulesDraft} rows="10" placeholder={languageRulesExample}
						class="w-full flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>
					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveLanguageRules} disabled={savingLanguageRules}>
						{savingLanguageRules ? '...' : (savedLanguageRules ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 4 — Business Information -->
				<div id="card-business-info" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">5</span>
						📚 Business Information
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Knowledge base the AI references when replying to customers</span>
					<textarea bind:value={businessInfoDraft} rows="12" placeholder={businessInfoExample}
						class="w-full flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>
					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveBusinessInfo} disabled={savingBusinessInfo}>
						{savingBusinessInfo ? '...' : (savedBusinessInfo ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 5 — Services -->
				<div id="card-services" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">6</span>
						🛎️ Services
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Services offered, by branch — the AI references this when replying to customers</span>
					<textarea bind:value={servicesInfoDraft} rows="14" placeholder={servicesInfoExample}
						class="w-full flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>
					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveServicesInfo} disabled={savingServicesInfo}>
						{savingServicesInfo ? '...' : (savedServicesInfo ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 6 — Problem & Issue Handling -->
				<div id="card-problem-handling" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">7</span>
						🛠️ Problem & Issue Handling
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">How the AI should handle complaints, defects, price/stock questions, and other issues it can't resolve itself</span>
					<textarea bind:value={problemHandlingDraft} rows="16" placeholder={problemHandlingExample}
						class="w-full flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>
					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveProblemHandling} disabled={savingProblemHandling}>
						{savingProblemHandling ? '...' : (savedProblemHandling ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 7 — Behavior Rules -->
				<div id="card-behavior-rules" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">8</span>
						📋 Behavior Rules
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Behaviour not covered by the sections above</span>
					<p class="text-[10px] text-slate-400 mb-2">Keep this short. Anything about language, escalation, tone, services, business info or problem handling belongs in its own section above — repeating it here sends the AI the same instruction twice and the two copies drift apart.</p>
					<textarea bind:value={botRulesDraft} rows="12" placeholder={botRulesExample}
						class="w-full flex-1 px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y mb-3"></textarea>
					<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
						on:click={saveBotRules} disabled={savingBotRules}>
						{savingBotRules ? '...' : (savedBotRules ? 'Change' : 'Save')}
					</button>
				</div>

				<!-- Card 8 — Training Examples -->
				<div id="card-training" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">9</span>
						🎓 Training Examples
					</h2>
					<span class="text-[10px] font-bold text-slate-500 uppercase mb-1.5 block">Sample customer messages and the reply the AI should model</span>
					<p class="text-[10px] text-slate-400 mb-3">Sent to the AI as <b>Customer / Bot</b> example pairs. Empty rows are dropped on save.</p>

					<div class="space-y-3 mb-3">
						{#each trainingQA as qa, idx}
							<div class="bg-slate-50 border border-slate-200 rounded-xl p-3">
								<div class="flex items-center justify-between mb-2">
									<span class="text-[10px] font-bold text-slate-500 uppercase">Example {idx + 1}</span>
									<button class="text-xs font-bold text-rose-500 hover:text-rose-600" on:click={() => removeQAPair(idx)}>✕ Remove</button>
								</div>
								<input type="text" bind:value={qa.prompt} placeholder="Customer says…"
									class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-400 mb-2" />
								<textarea bind:value={qa.response} rows="2" placeholder="Bot should reply…"
									class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-400 resize-y"></textarea>
							</div>
						{:else}
							<p class="text-xs text-slate-400 text-center py-4">No training examples yet.</p>
						{/each}
					</div>

					<div class="flex gap-2">
						<button class="px-3 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-lg hover:bg-slate-200" on:click={addQAPair}>
							+ Add Example
						</button>
						<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50"
							on:click={saveTrainingQA} disabled={savingTraining}>
							{savingTraining ? '...' : (trainingSaved ? '✓ Saved' : 'Save')}
						</button>
					</div>
				</div>
			</div>
		{/if}
	</div>
</div>
