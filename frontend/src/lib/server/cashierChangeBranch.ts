export async function cashierInBranch(db: any, userId: string, branchId: number): Promise<boolean> {
  const { data, error } = await db.from('hr_employee_master').select('current_branch_id')
    .eq('user_id', userId).maybeSingle();
  if (error) throw error;
  return Number(data?.current_branch_id) === branchId;
}
