import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    const user = await requireBreakUser(cookies, 'desktop');
    if (!user.isMasterAdmin && !user.isAdmin) {
      return json({ success: false, error: 'Administrator access is required' }, { status: 403 });
    }

    const { data, error } = await databaseClient()
      .from('branches')
      .select('id,name_en,name_ar')
      .eq('is_active', true)
      .order('name_en');
    if (error) throw error;

    return json({
      success: true,
      branches: (data ?? []).map((branch) => ({
        id: branch.id,
        name: branch.name_en || branch.name_ar || `Branch ${branch.id}`,
        nameAr: branch.name_ar
      }))
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Data Manager session required';
    return json({ success: false, error: message }, { status: 401 });
  }
};
