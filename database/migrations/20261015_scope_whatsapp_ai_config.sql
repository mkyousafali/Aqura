begin;

alter table public.wa_ai_bot_config
  add column if not exists wa_account_id uuid;

do $$
declare
  v_customer_account uuid;
  v_internal_account uuid;
begin
  select id
    into v_customer_account
    from public.wa_accounts
   where is_default = true
   order by created_at
   limit 1;

  if v_customer_account is null then
    raise exception 'Default customer WhatsApp account was not found';
  end if;

  update public.wa_ai_bot_config
     set wa_account_id = v_customer_account
   where wa_account_id is null;

  select account_id
    into v_internal_account
    from public.wa_internal_account
   where singleton = true;

  if v_internal_account is null then
    raise exception 'Internal WhatsApp account was not found';
  end if;

  insert into public.wa_ai_bot_config (wa_account_id, is_enabled)
  values (v_internal_account, false)
  on conflict do nothing;
end
$$;

alter table public.wa_ai_bot_config
  alter column wa_account_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'wa_ai_bot_config_wa_account_id_fkey'
       and conrelid = 'public.wa_ai_bot_config'::regclass
  ) then
    alter table public.wa_ai_bot_config
      add constraint wa_ai_bot_config_wa_account_id_fkey
      foreign key (wa_account_id) references public.wa_accounts(id) on delete cascade;
  end if;
end
$$;

create unique index if not exists wa_ai_bot_config_account_uidx
  on public.wa_ai_bot_config (wa_account_id);

commit;
