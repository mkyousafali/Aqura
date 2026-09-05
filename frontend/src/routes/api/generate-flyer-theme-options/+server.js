import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = env.VITE_SUPABASE_URL || '';
const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';

// NOTE: text-only model for this quick "suggest color themes" step (separate from the
// gpt-image-2 model used for the actual background image). Not yet confirmed against the
// project's OpenAI account — swap this if it 404s/400s as an unknown model.
const TEXT_MODEL = 'gpt-4o-mini';

async function getOpenAiKey() {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data, error } = await supabase
      .from('system_api_keys')
      .select('api_key')
      .eq('service_name', 'openai')
      .eq('is_active', true)
      .limit(1)
      .single();
    if (error) throw error;
    return data?.api_key || null;
  } catch (e) {
    console.error('Failed to fetch OpenAI key:', e);
    return null;
  }
}

export async function POST({ request }) {
  try {
    const { offerDescriptionAr } = await request.json();

    if (!offerDescriptionAr || !offerDescriptionAr.trim()) {
      return json({ error: 'Arabic offer name/description is required' }, { status: 400 });
    }

    const openAiKey = await getOpenAiKey();
    if (!openAiKey) {
      return json(
        { error: 'OpenAI API key not configured. Set it in API Keys Manager (system_api_keys, service_name = "openai").' },
        { status: 500 }
      );
    }

    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: TEXT_MODEL,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content:
              'You help design promotional flyers. Given a short Arabic description of an offer/occasion, propose exactly 5 short color-theme options (in English, each a few words like "Warm & Festive — gold, red, orange") that suit the occasion and vary meaningfully from each other. Respond with a JSON object: {"themes": ["...", "...", "...", "...", "..."]}'
          },
          {
            role: 'user',
            content: `Offer description (Arabic): "${offerDescriptionAr}"`
          }
        ]
      })
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error('OpenAI theme-suggestion call failed:', errText);
      return json({ error: 'Failed to get theme suggestions', details: errText }, { status: 502 });
    }

    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) {
      return json({ error: 'No theme suggestions returned' }, { status: 502 });
    }

    let themes = [];
    try {
      const parsed = JSON.parse(content);
      themes = Array.isArray(parsed.themes) ? parsed.themes : [];
    } catch (e) {
      console.error('Failed to parse theme-suggestion response:', content);
    }

    if (!themes.length) {
      return json({ error: 'Could not parse theme suggestions' }, { status: 502 });
    }

    return json({ themes });
  } catch (e) {
    console.error('generate-flyer-theme-options error:', e);
    return json({ error: e?.message || 'Unexpected error' }, { status: 500 });
  }
}
