import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = env.VITE_SUPABASE_URL || '';
const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';

// NOTE: same text-only model used for the "suggest color themes" step
// (see /api/generate-flyer-theme-options) — kept in sync deliberately.
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
    const { offerNameEn } = await request.json();

    if (!offerNameEn || !offerNameEn.trim()) {
      return json({ error: 'English offer name is required' }, { status: 400 });
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
              'You help name promotional retail offers for flyers in the Gulf/Saudi market. Given a short English ' +
              'description of an offer or occasion, propose exactly 6 short, catchy Arabic offer-name options ' +
              'suitable as the headline of a flyer banner (e.g. "عروض العيد", "تخفيضات نهاية الأسبوع"). Vary the ' +
              'tone and phrasing across the options. Respond with a JSON object: {"names": ["...", "...", "...", "...", "...", "..."]}'
          },
          {
            role: 'user',
            content: `Offer name/occasion (English): "${offerNameEn}"`
          }
        ]
      })
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error('OpenAI offer-name call failed:', errText);
      return json({ error: 'Failed to generate offer names', details: errText }, { status: 502 });
    }

    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) {
      return json({ error: 'No offer names returned' }, { status: 502 });
    }

    let names = [];
    try {
      const parsed = JSON.parse(content);
      names = Array.isArray(parsed.names) ? parsed.names : [];
    } catch (e) {
      console.error('Failed to parse offer-name response:', content);
    }

    if (!names.length) {
      return json({ error: 'Could not parse offer name suggestions' }, { status: 502 });
    }

    return json({ names });
  } catch (e) {
    console.error('generate-offer-names error:', e);
    return json({ error: e?.message || 'Unexpected error' }, { status: 500 });
  }
}
