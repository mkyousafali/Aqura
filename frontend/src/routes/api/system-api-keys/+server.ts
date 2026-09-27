import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { findApiService, RETIRED_API_SERVICES } from '$lib/config/apiServices';

const respond = (body: unknown, status = 200) => json(body, { status, headers: { 'Cache-Control': 'no-store' } });
const fail = (error: string, status = 400) => respond({ success: false, error }, status);
function getSupabase() {
 return createClient(env.VITE_SUPABASE_URL || '', env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || '');
}
export const GET: RequestHandler = async () => {
 try {
  const { data, error } = await getSupabase().from('system_api_keys').select('*').order('service_name');
  if (error) return fail('Unable to load API keys.', 500);
  return respond({ success: true, keys: data || [] });
 } catch { return fail('Unable to load API keys.', 500); }
};
export const POST: RequestHandler = async ({ request }) => {
 let params: any;
 try { params = await request.json(); } catch { return fail('Invalid JSON.'); }
 if (!params || typeof params !== 'object') return fail('Invalid request.');
 const { action, id } = params;
 if (!['insert', 'rotate', 'update', 'toggle', 'delete'].includes(action)) return fail('Unknown action.');
 if (action !== 'insert' && (id === undefined || id === null || id === '')) return fail('id is required.');
 if (['insert', 'rotate', 'update'].includes(action) && (typeof params.api_key !== 'string' || !params.api_key.trim())) return fail('A non-empty API key is required.');
 if (action === 'toggle' && typeof params.is_active !== 'boolean') return fail('is_active must be true or false.');
 const serviceName = typeof params.service_name === 'string' ? params.service_name.trim() : '';
 if (action === 'insert' && (!serviceName || RETIRED_API_SERVICES.includes(serviceName))) return fail('Choose an active service.');
 try {
  const table = getSupabase().from('system_api_keys');
  let query;
  if (action === 'insert') {
   query = table.insert({ service_name: serviceName, api_key: params.api_key.trim(), description: findApiService(serviceName)?.description || params.description || '', is_active: true });
  } else if (action === 'delete') {
   query = table.delete().eq('id', id);
  } else {
   const values: Record<string, unknown> = action === 'toggle' ? { is_active: params.is_active } : { api_key: params.api_key.trim() };
   if (action === 'update') {
    if (typeof params.description === 'string') values.description = params.description;
    if (typeof params.is_active === 'boolean') values.is_active = params.is_active;
   }
   query = table.update(values).eq('id', id);
  }
  const { data, error } = await query.select('*').maybeSingle();
  if (error) return error.code === '23505' ? fail('This service already has a key. Use Replace key.', 409) : fail('Unable to save API key changes.', 500);
  if (!data) return fail('Key no longer exists. Refresh the list.', 404);
  return respond({ success: true, ...(action === 'delete' ? {} : { key: data }) });
 } catch { return fail('Unable to save API key changes.', 500); }
};
