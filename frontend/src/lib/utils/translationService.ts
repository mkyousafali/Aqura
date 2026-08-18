// Translation service using Gemini API (keys from DB)
export interface TranslationOptions {
	text: string;
	targetLanguage: 'ar' | 'en';
	sourceLanguage?: 'ar' | 'en';
}

async function getGeminiKey(): Promise<string | null> {
	try {
		const { supabase } = await import('$lib/utils/supabase');
		const { data } = await supabase
			.from('system_api_keys')
			.select('api_key')
				.eq('service_name', 'google_gemini')
			.eq('is_active', true)
			.maybeSingle();
		if (data?.api_key) return data.api_key;
	} catch { /* ignore */ }
	return null;
}

async function callGemini(systemPrompt: string, userPrompt: string, geminiKey: string): Promise<string> {
	const res = await fetch(
		`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
		{
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				systemInstruction: { parts: [{ text: systemPrompt }] },
				contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
				// thinkingBudget: 0 turns off Gemini 2.5's internal "thinking" pass —
				// without it, thinking tokens were eating most of maxOutputTokens
				// (verified: a 200-token budget left ~8 tokens for the actual answer,
				// silently truncating short replies mid-word). These are short,
				// single-step text tasks that don't benefit from extra reasoning.
				generationConfig: { temperature: 0.3, maxOutputTokens: 500, thinkingConfig: { thinkingBudget: 0 } }
			})
		}
	);
	if (!res.ok) throw new Error(`Gemini error: ${res.status}`);
	const d = await res.json();
	return d.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
}

export async function translateText(options: TranslationOptions): Promise<string> {
	const { text, targetLanguage, sourceLanguage } = options;

	if (!text || text.trim() === '') {
		return '';
	}

	try {
		const geminiKey = await getGeminiKey();
		if (!geminiKey) throw new Error('No AI translation provider configured. Add a Google API key in API Keys Manager.');

		const prompt = sourceLanguage
			? `Translate the following text from ${sourceLanguage === 'en' ? 'English' : 'Arabic'} to ${targetLanguage === 'en' ? 'English' : 'Arabic'}. Provide only the translation without any additional text:\n\n${text}`
			: `Translate the following text to ${targetLanguage === 'en' ? 'English' : 'Arabic'}. Provide only the translation without any additional text:\n\n${text}`;

		return await callGemini(
			'You are a professional translator. Provide only the translation without any additional explanation or text.',
			prompt,
			geminiKey
		);
	} catch (error) {
		console.error('Translation error:', error);
		throw error;
	}
}

export async function correctSpelling(text: string): Promise<string> {
	if (!text || text.trim() === '') {
		return text;
	}

	try {
		const geminiKey = await getGeminiKey();
		if (!geminiKey) return text;

		const corrected = await callGemini(
			'You are a spelling and grammar corrector. Fix any spelling mistakes in the given English text. Return ONLY the corrected text, nothing else. Keep the same meaning and style. If the text is already correct, return it as-is.',
			text,
			geminiKey
		);
		return corrected || text;
	} catch {
		return text;
	}
}

export interface CorrectedProductName {
	en: string;
	ar: string;
}

// Dedicated to product names (not shared with correctSpelling, which is used
// by checklist text and has different rules). A store employee typing fast
// often gets both the spelling AND the word order wrong (e.g. "apple amerca"
// meant as "American Apple") — so unlike correctSpelling, this one is
// explicitly allowed to reorder into natural product-name grammar, but must
// not invent or drop any of the meaningful words the user actually typed.
export async function correctAndTranslateProductName(text: string): Promise<CorrectedProductName> {
	const trimmed = (text || '').trim();
	if (!trimmed) return { en: '', ar: '' };

	const geminiKey = await getGeminiKey();
	if (!geminiKey) throw new Error('No AI translation provider configured. Add a Google API key in API Keys Manager.');

	const systemPrompt = `You correct retail product names typed quickly by a store employee, who may type the words in the wrong order and/or misspell them.
1. Rewrite the text as a clean, natural, properly-ordered English product name — put descriptive/origin adjectives before the noun, the way real product names read (e.g. "American Apple", "Turkish Delight", "Saudi Dates"). Fix any spelling mistakes. Keep every meaningful word the user typed — do not add new descriptive words and do not drop any.
2. Translate that corrected name into natural, commonly-used Arabic, in standard Arabic grammar order (noun then adjective, e.g. تفاح أمريكي), the way it would appear on a product label in a Middle Eastern grocery store.

Respond with ONLY a JSON object, no markdown formatting, no code fences, in exactly this shape:
{"corrected_en": "...", "arabic": "..."}`;

	const raw = await callGemini(systemPrompt, trimmed, geminiKey);
	const jsonText = raw.replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/```\s*$/i, '').trim();

	try {
		const parsed = JSON.parse(jsonText);
		return {
			en: (parsed.corrected_en || trimmed).toString().trim(),
			ar: (parsed.arabic || '').toString().trim()
		};
	} catch {
		// If the model didn't return valid JSON, fall back to treating the raw
		// reply as the corrected English and leave Arabic for the user to fill in.
		return { en: raw || trimmed, ar: '' };
	}
}
