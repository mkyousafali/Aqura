import { json } from "@sveltejs/kit";
import { generateOpenAIText } from '$lib/server/openaiText';

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
    } else if (type === 'chat') {
      typeInstruction = 'This is a customer-facing WhatsApp chat message. The tone must be warm, polite, respectful, and customer-friendly. Use courteous language like "Dear customer", "Thank you", "We appreciate", "Please", etc.';
    } else {
      typeInstruction = 'This is a professional document.';
    }

    const systemPrompt = type === 'chat'
      ? `You are a professional customer service text editor. You correct spelling, grammar, and transform the tone to be warm, polite, respectful, and customer-friendly. You only respond with the corrected text, nothing else. Detect the language of the input text automatically and keep the text in that same language — do NOT translate it.`
      : `You are a professional text editor who corrects spelling, grammar, and improves tone. You only respond with the corrected text, nothing else. You keep the text in ${languageName} and do not translate it.`;

    const prompt = type === 'chat'
      ? `You are a polite customer service editor. ${typeInstruction}

Please correct the following message:
1. Fix all spelling mistakes
2. Fix all grammar errors
3. Make the tone warm, polite, respectful and customer-friendly
4. Use courteous phrases appropriate for customer service
5. Keep the same meaning and content
6. Detect the language automatically and keep it in that SAME language
7. Do NOT translate to any other language
8. Do NOT add any extra content or explanations
9. Do NOT add greetings or sign-offs unless they exist in the original

Original message:
${text}

Polished message:`
      : `You are a professional editor. ${typeInstruction}

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

    console.log("Sending prompt to OpenAI...");

    const transformedText = await generateOpenAIText({
      systemPrompt: systemPrompt, prompt,
      temperature: 0.3, maxTokens: 2000
    });
    
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
