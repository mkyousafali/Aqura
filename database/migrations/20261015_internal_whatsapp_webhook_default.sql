begin;

update public.wa_settings s
   set webhook_active = true,
       updated_at = now()
  from public.wa_internal_account i
 where i.singleton = true
   and s.wa_account_id = i.account_id
   and s.webhook_active is distinct from true;

create or replace function public.default_internal_whatsapp_webhook_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
      from public.wa_internal_account i
     where i.singleton = true
       and i.account_id = new.wa_account_id
  ) then
    new.webhook_active := true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_default_internal_whatsapp_webhook_active on public.wa_settings;
create trigger trg_default_internal_whatsapp_webhook_active
before insert on public.wa_settings
for each row
execute function public.default_internal_whatsapp_webhook_active();

commit;
