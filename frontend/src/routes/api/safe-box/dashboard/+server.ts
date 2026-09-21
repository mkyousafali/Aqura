import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxAccess } from '$lib/server/safeBoxControl';

const values: Record<string, number> = {
  d500: 50000, d200: 20000, d100: 10000, d50: 5000, d20: 2000,
  d10: 1000, d5: 500, d2: 200, d1: 100, d05: 50, d025: 25,
  coins: 100, damage: 100
};

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    const access = await safeBoxAccess(cookies);
    const userId = access.userId;
    const db = databaseClient();
    const { data: employee, error: employeeError } = await db.from('hr_employee_master')
      .select('current_branch_id,name_en,name_ar').eq('user_id', userId).maybeSingle();
    if (employeeError) throw employeeError;
    if (!employee?.current_branch_id) return json({ error: 'No current branch is assigned to this user.' }, { status: 404 });
    if (!access.canBalance) return json({ ...access, name: employee.name_en || employee.name_ar || '', counts: {}, totalAmount: 0 },
      { headers: { 'Cache-Control': 'no-store' } });
    const { data: record, error } = await db.from('denomination_records').select('counts')
      .eq('branch_id', employee.current_branch_id).eq('record_type', 'main')
      .order('created_at', { ascending: false }).limit(1).maybeSingle();
    if (error) throw error;
    const saved = typeof record?.counts === 'string' ? JSON.parse(record.counts) : record?.counts;
    const safeBox = saved?.safe_box || {};
    const counts = Object.fromEntries(Object.keys(values).map(key => {
      const count = safeBox[key];
      return [key, Number.isSafeInteger(count) && count > 0 ? count : 0];
    }));
    const totalCents = Object.entries(values).reduce((total, [key, cents]) => total + counts[key] * cents, 0);
    return json({ ...access, name: employee.name_en || employee.name_ar || '', counts, totalAmount: totalCents / 100 },
      { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Safe Box dashboard load failed:', error);
    const message = error instanceof Error ? error.message : 'Unable to load Safe Box dashboard.';
    return json({ error: message }, { status: /access|pending Safe Box request/i.test(message) ? 403 : 500 });
  }
};
