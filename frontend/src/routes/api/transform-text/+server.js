import { json } from "@sveltejs/kit";
import { env } from '$env/dynamic/private';

async function getGeminiKey() {
  try {
    const supabaseUrl = env.VITE_SUPABASE_URL || '';
    const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
    if (!supabaseUrl || !supabaseKey) {
      console.error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in env');
      return null;
    }
    const res = await fetch(
      `${supabaseUrl}/rest/v1/system_api_keys?service_name=eq.google&is_active=eq.true&select=api_key&limit=1`,
      { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
    );
    const rows = await res.json();
    return rows?.[0]?.api_key || null;
  } catch (e) {
    console.error('Failed to fetch Gemini key:', e);
    return null;
  }
}

// Language name mapping
const languageNames = {
  ar: { name: 'Arabic', nativeName: 'العربية' },
  en: { name: 'English', nativeName: 'English' },
  ml: { name: 'Malayalam', nativeName: 'മലയാളം' },
  bn: { name: 'Bengali', nativeName: 'বাংলা' },
  hi: { name: 'Hindi', nativeName: 'हिंदी' },
  ur: { name: 'Urdu', nativeName: 'اردو' },
  ta: { name: 'Tamil', nativeName: 'தமிழ்' }
};

export async function POST({ request }) {
  try {
    console.log("Transform Text API accessed...");

    const GEMINI_KEY = await getGeminiKey();
    if (!GEMINI_KEY) {
      return json(
        { error: "Google AI API key not configured. Set it in API Keys Manager." },
        { status: 500 }
      );
    }

    const body = await request.json();
    console.log("Request body received:", JSON.stringify(body, null, 2));

    const {
      text = '',
      language = 'en',
      type = 'general'
    } = body;

    if (!text.trim()) {
      return json({ error: "No text provided" }, { status: 400 });
    }

    const languageName = languageNames[language]?.name || 'English';
    
    let typeInstruction = '';
    if (type === 'investigation') {
      typeInstruction = 'This is an HR investigation report.';
    } else if (type === 'warning') {
      typeInstruction = 'This is a formal warning letter.';
    } else {
      typeInstruction = 'This is a professional document.';
    }

    const systemPrompt = `You are a professional text editor who corrects spelling, grammar, and improves tone. You only respond with the corrected text, nothing else. You keep the text in ${languageName} and do not translate it.`;

    const prompt = `You are a professional editor. ${typeInstruction}

Please correct the following text:
1. Fix all spelling mistakes
2. Fix all grammar errors
3. Improve the tone to be professional and formal
4. Keep the same meaning and content
5. Keep it in ${languageName} language
6. Do NOT translate to any other language
7. Do NOT add any extra content or explanations

Original text:
${text}

Corrected text:`;

    console.log("Sending prompt to Gemini...");

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.3, maxOutputTokens: 2000 }
        })
      }
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      throw new Error(`Gemini API error ${geminiRes.status}: ${errText}`);
    }

    const geminiData = await geminiRes.json();
    const transformedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || text;
    
    console.log("Transformed text length:", transformedText.length);

    return json({
      success: true,
      transformedText: transformedText.trim()
    });

  } catch (error) {
    console.error("Error transforming text:", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Failed to transform text",
      },
      { status: 500 }
    );
  }
}
