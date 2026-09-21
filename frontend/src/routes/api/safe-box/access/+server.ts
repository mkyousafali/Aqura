import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { safeBoxAccess } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    return json(await safeBoxAccess(cookies), { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Safe Box access denied.' }, { status: 403 });
  }
};
