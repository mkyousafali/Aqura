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
			.eq('service_name', 'google')
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
				generationConfig: { temperature: 0.3, maxOutputTokens: 200 }
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
