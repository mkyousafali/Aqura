<script lang="ts">
	import { onMount } from 'svelte';

	let supabase: any = null;
	let loading = true;
	let saving = false;
	let scrollContainer: HTMLDivElement;

	let configId: string | null = null;
	let botNameEn = '';
	let botNameAr = '';

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
				.select('id, bot_name, bot_name_ar, tone, language_rules, custom_instructions, services_information, problem_handling_info, escalation_keywords, escalation_ack_message, escalation_rules_instructions, escalation_context_gathering_reply_en, escalation_context_gathering_reply_ar, escalation_complaint_reply_en, escalation_complaint_reply_ar')
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
			<div class="flex items-center gap-2">
				<button
					class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs bg-slate-100 text-slate-600 hover:bg-slate-200 transition-all"
					on:click={() => scrollToSection('card-who-am-i')}>
					🙋 Who am I
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

				<!-- Card 2 — Escalation Keywords -->
				<div id="card-escalation" class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm flex flex-col">
					<h2 class="flex items-center gap-2 text-sm font-bold text-slate-700 uppercase tracking-wide mb-4">
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">2</span>
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
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">3</span>
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
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">4</span>
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
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">5</span>
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
						<span class="w-5 h-5 flex items-center justify-center bg-emerald-600 text-white rounded-full text-[10px]">6</span>
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
			</div>
		{/if}
	</div>
</div>
