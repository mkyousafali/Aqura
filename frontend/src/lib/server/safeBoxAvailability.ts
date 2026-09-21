import { databaseClient } from '$lib/server/breakRegisterAuth';

export const changeDenominations = {
  d500: 50000, d200: 20000, d100: 10000, d50: 5000, d20: 2000,
  d10: 1000, d5: 500, d2: 200, d1: 100, d05: 50, d025: 25
};

export async function readSafeBoxAvailability(branchId: number): Promise<Record<string, number>> {
  const { data, error } = await databaseClient().from('denomination_records')
    .select('counts').eq('branch_id', branchId).eq('record_type', 'main')
    .order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (error) throw error;
  const counts = typeof data?.counts === 'string' ? JSON.parse(data.counts) : data?.counts;
  const safeBox = counts?.safe_box;
  return Object.fromEntries(Object.keys(changeDenominations).map(key => {
    const value = safeBox?.[key];
    return [key, Number.isSafeInteger(value) && value > 0 ? value : 0];
  }));
}
