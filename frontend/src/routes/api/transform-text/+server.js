import { json } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";

// Function to create OpenAI client with error handling
function createOpenAIClient() {
  try {
    const apiKey =
      env.OPENAI_API_KEY ||
      env.VITE_OPENAI_API_KEY ||
      process.env.OPENAI_API_KEY ||
      process.env.VITE_OPENAI_API_KEY;

    if (!apiKey) {
      console.warn("No OpenAI API key found in environment variables");
      return null;
    }

    // Dynamic import to avoid initialization errors during build
    return import("openai").then(({ default: OpenAI }) => {
      return new OpenAI({ apiKey });
    });
  } catch (error) {
    console.error("Failed to create OpenAI client:", error);
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

    // Create OpenAI client
    const openaiClientPromise = createOpenAIClient();
    if (!openaiClientPromise) {
      console.error("Failed to create OpenAI client");
      return json(
        {
          error: "OpenAI API key not configured. Please check server environment variables.",
        },
        { status: 500 }
      );
    }

    const openai = await openaiClientPromise;
    const body = await request.json();
    
    console.log("Request body received:", JSON.stringify(body, null, 2));

    const {
      text = '',
      language = 'en',
      type = 'general' // 'investigation', 'warning', 'general'
    } = body;

    if (!text.trim()) {
      return json({ error: "No text provided" }, { status: 400 });
    }

    const languageName = languageNames[language]?.name || 'English';
    
    // Build the prompt based on type
    let typeInstruction = '';
    if (type === 'investigation') {
      typeInstruction = 'This is an HR investigation report.';
    } else if (type === 'warning') {
      typeInstruction = 'This is a formal warning letter.';
    } else {
      typeInstruction = 'This is a professional document.';
    }

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

    console.log("Sending prompt to OpenAI...");

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: `You are a professional text editor who corrects spelling, grammar, and improves tone. You only respond with the corrected text, nothing else. You keep the text in ${languageName} and do not translate it.`
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 2000
    });

    const transformedText = completion.choices[0]?.message?.content || text;
    
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
