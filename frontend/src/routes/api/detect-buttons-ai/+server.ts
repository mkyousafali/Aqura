import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';

const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

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
	const OPENAI_API_KEY = env.OPENAI_API_KEY;

	if (!OPENAI_API_KEY || OPENAI_API_KEY.trim() === '') {
		throw new Error('OpenAI API key is not configured. Set OPENAI_API_KEY in .env');
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
		console.log('🚀 Calling OpenAI API...');

		const requestBody = JSON.stringify({
			model: 'gpt-4-turbo',
			messages: [
				{
					role: 'system',
					content: systemPrompt
				},
				{
					role: 'user',
					content: userMessage
				}
			],
			temperature: 0.3,
			max_tokens: 4000
		});

		const response = await fetch(OPENAI_API_URL, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Authorization: `Bearer ${OPENAI_API_KEY}`
			},
			body: requestBody
		});

		console.log(`📡 OpenAI Response Status: ${response.status}`);

		if (!response.ok) {
			const errorText = await response.text();
			console.error('❌ OpenAI API Error Response:', errorText);
			throw new Error(`OpenAI API returned ${response.status}: ${errorText}`);
		}

		const responseData = await response.json();
		console.log('✅ OpenAI Response received');

		if (!responseData.choices || !responseData.choices[0]?.message?.content) {
			console.error('❌ Invalid response structure:', responseData);
			throw new Error('Invalid response structure from OpenAI API');
		}

		const content = responseData.choices[0].message.content;
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
					throw new Error('Could not parse JSON from OpenAI response');
				}
			} else {
				console.error('❌ No JSON found in response:', content);
				throw new Error('No JSON data found in OpenAI response');
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
