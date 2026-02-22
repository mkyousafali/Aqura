import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || '';
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY || '';

async function getGeminiKeyFromDB(): Promise<string | null> {
	try {
		const res = await fetch(
			`${SUPABASE_URL}/rest/v1/system_api_keys?service_name=eq.google&is_active=eq.true&select=api_key&limit=1`,
			{ headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` } }
		);
		const rows: any[] = await res.json();
		return rows?.[0]?.api_key || null;
	} catch {
		return null;
	}
}

interface ButtonDetectionRequest {
	sidebarStructure: string;
	task: string;
}

interface ButtonData {
	code: string;
	name: string;
}

interface SubsectionData {
	name: string;
	buttons: ButtonData[];
	buttonCount: number;
}

interface SectionData {
	name: string;
	subsections: SubsectionData[];
	totalButtons: number;
}

async function detectButtonsWithAI(
	sidebarStructure: string,
	task: string
): Promise<SectionData[]> {
	const GEMINI_KEY = await getGeminiKeyFromDB();

	if (!GEMINI_KEY) {
		throw new Error('Google AI API key not configured. Add Google key in API Keys Manager.');
	}

	const systemPrompt = `You are an expert code analyzer. Your job is to analyze a sidebar/button structure and extract all buttons.

IMPORTANT: You MUST respond with ONLY valid JSON, no other text before or after.

Format your response as:
{
  "sections": [
    {
      "name": "Section Name",
      "subsections": [
        {
          "name": "Subsection Name",
          "buttons": [
            {
              "code": "BUTTON_CODE",
              "name": "Button Display Name"
            }
          ]
        }
      ]
    }
  ]
}`;

	const userMessage = `${task}

Analyze this structure and extract all buttons:
${sidebarStructure}

Return ONLY the JSON structure, nothing else.`;

	try {
		console.log('🚀 Calling Gemini API...');

		let content: string = '';

		const geminiBody = JSON.stringify({
			systemInstruction: { parts: [{ text: systemPrompt }] },
			contents: [{ role: 'user', parts: [{ text: userMessage }] }],
			generationConfig: { temperature: 0.3, maxOutputTokens: 4000 }
		});
		const gr = await fetch(
			`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
			{ method: 'POST', headers: { 'Content-Type': 'application/json' }, body: geminiBody }
		);
		if (gr.ok) {
			const gd = await gr.json();
			content = gd.candidates?.[0]?.content?.parts?.[0]?.text || '';
		} else {
			const errText = await gr.text();
			throw new Error(`Gemini API error ${gr.status}: ${errText}`);
		}

		if (!content) throw new Error('No response from Gemini');
		console.log('✅ AI Response received');
		console.log('📝 Response content preview:', content.substring(0, 100));

		// Try to extract JSON from the response
		let jsonData: any;
		try {
			// First try direct parse
			jsonData = JSON.parse(content);
		} catch {
			// Try to extract JSON from markdown code blocks or text
			const jsonMatch = content.match(/\{[\s\S]*\}/);
			if (jsonMatch) {
				try {
					jsonData = JSON.parse(jsonMatch[0]);
				} catch {
					console.error('❌ Failed to parse extracted JSON:', jsonMatch[0]);
					throw new Error('Could not parse JSON from AI response');
				}
			} else {
				console.error('❌ No JSON found in response:', content);
				throw new Error('No JSON data found in AI response');
			}
		}

		// Validate and normalize the structure
		const sections: SectionData[] = (jsonData.sections || []).map((section: any) => ({
			name: section.name || 'Unknown Section',
			subsections: (section.subsections || []).map((subsection: any) => ({
				name: subsection.name || 'Unknown Subsection',
				buttons: (subsection.buttons || []).map((button: any) => ({
					code: (button.code || '').toUpperCase() || 'UNKNOWN',
					name: button.name || 'Unknown Button'
				})),
				buttonCount: (subsection.buttons || []).length
			})),
			totalButtons: (section.subsections || []).reduce(
				(sum: number, sub: any) => sum + (sub.buttons || []).length,
				0
			)
		}));

		console.log(`✨ Detected ${sections.length} sections with AI`);
		return sections;
	} catch (error) {
		console.error('❌ Error in detectButtonsWithAI:', error);
		throw error;
	}
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		console.log('📨 Received POST request to /api/detect-buttons-ai');

		const body = (await request.json()) as ButtonDetectionRequest;
		const { sidebarStructure, task } = body;

		if (!sidebarStructure) {
			return json({ error: 'sidebarStructure is required' }, { status: 400 });
		}

		const sections = await detectButtonsWithAI(sidebarStructure, task || 'detect all buttons');

		return json({
			success: true,
			sections: sections,
			message: `✨ Successfully detected ${sections.length} sections using AI`
		});
	} catch (error) {
		const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
		console.error('❌ API Error:', errorMessage);

		return json(
			{
				success: false,
				error: errorMessage,
				details: 'Check server logs for more information'
			},
			{ status: 500 }
		);
	}
};
