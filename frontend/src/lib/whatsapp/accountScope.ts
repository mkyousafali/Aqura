export type WhatsAppAccountScope = 'customer' | 'internal';

export async function getScopedWhatsAppAccount(supabase: any, scope: WhatsAppAccountScope, columns = '*') {
  if (scope === 'internal') {
    const { data: link, error: linkError } = await supabase.from('wa_internal_account').select('account_id').eq('singleton', true).single();
    if (linkError) throw linkError;
    const { data, error } = await supabase.from('wa_accounts').select(columns).eq('id', link.account_id).single();
    if (error) throw error;
    return data;
  }
  const { data, error } = await supabase.from('wa_accounts').select(columns).eq('is_default', true).single();
  if (error) throw error;
  return data;
}
