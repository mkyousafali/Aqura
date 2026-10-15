begin;

create or replace function public.normalize_internal_whatsapp_phone(p_phone text)
returns text
language plpgsql
immutable
strict
as $$
declare
  v text := regexp_replace(p_phone, '[^0-9]', '', 'g');
begin
  if left(v, 2) = '00' then v := substring(v from 3); end if;
  if length(v) = 10 and left(v, 1) = '0' then v := '966' || substring(v from 2); end if;
  if length(v) = 9 and left(v, 1) = '5' then v := '966' || v; end if;
  return nullif(v, '');
end;
$$;

create unique index if not exists hr_employee_master_whatsapp_normalized_uidx
  on public.hr_employee_master (public.normalize_internal_whatsapp_phone(whatsapp_number))
  where nullif(btrim(whatsapp_number), '') is not null;

create table if not exists public.wa_internal_account (
  singleton boolean primary key default true check (singleton),
  account_id uuid not null unique references public.wa_accounts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
declare
  v_customer public.wa_accounts%rowtype;
  v_internal_id uuid;
begin
  if not exists (select 1 from public.wa_internal_account where singleton) then
    select * into v_customer
    from public.wa_accounts
    where is_default = true
    order by created_at
    limit 1;

    if v_customer.id is null then
      raise exception 'Customer WhatsApp account not found';
    end if;

    select id into v_internal_id
    from public.wa_accounts
    where phone_number_id = '817737554748880'
    limit 1;

    if v_internal_id is null then
      insert into public.wa_accounts (
        phone_number, display_name, waba_id, phone_number_id, access_token,
        quality_rating, status, is_default, is_active, branch_id,
        meta_business_account_id, meta_access_token
      ) values (
        '+966543541077', 'ايربن ماركت', v_customer.waba_id, '817737554748880', v_customer.access_token,
        null, 'pending', false, true, null,
        v_customer.meta_business_account_id, v_customer.meta_access_token
      ) returning id into v_internal_id;
    end if;

    insert into public.wa_internal_account(singleton, account_id)
    values (true, v_internal_id);
  end if;
end;
$$;

create table if not exists public.wa_internal_security_audit (
  id bigint generated always as identity primary key,
  account_id uuid references public.wa_accounts(id) on delete restrict,
  phone_number text not null,
  event_type text not null check (event_type in ('unauthorized_inbound','blocked','unblocked','send_denied')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.wa_internal_access_jobs (
  id bigint generated always as identity primary key,
  account_id uuid not null references public.wa_accounts(id) on delete restrict,
  employee_id text references public.hr_employee_master(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  phone_number text not null,
  operation text not null check (operation in ('block','unblock')),
  status text not null default 'pending' check (status in ('pending','processing','completed','failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists wa_internal_access_jobs_pending_idx
  on public.wa_internal_access_jobs(status, next_attempt_at);

create or replace function public.is_internal_whatsapp_authorized_phone(p_phone text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.hr_employee_master e
    join public.users u on u.id = e.user_id
    left join public.hr_employee_current_status s on s.employee_id = e.id
    where public.normalize_internal_whatsapp_phone(e.whatsapp_number) = public.normalize_internal_whatsapp_phone(p_phone)
      and u.status = 'active'
      and u.locked_at is null
      and coalesce(s.employment_status, 'Job (With Finger)') <> 'Resigned'
  );
$$;

create or replace function public.is_internal_whatsapp_account(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.wa_internal_account where singleton and account_id = p_account_id);
$$;

create or replace function public.get_internal_whatsapp_account()
returns setof public.wa_accounts
language sql
stable
security definer
set search_path = public
as $$
  select a.* from public.wa_accounts a
  join public.wa_internal_account i on i.account_id = a.id
  where i.singleton;
$$;

create or replace function public.get_internal_whatsapp_contacts(
  p_limit integer default 100,
  p_offset integer default 0,
  p_search text default null
)
returns table (
  employee_id text, user_id uuid, name text, name_ar text, whatsapp_number text,
  employment_status text, user_status text, conversation_id uuid,
  last_message_at timestamptz, unread_count integer, is_inside_24hr boolean,
  total_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with eligible as (
    select e.id employee_id, e.user_id, coalesce(nullif(e.name_en,''),u.username) name,
           e.name_ar, e.whatsapp_number, coalesce(s.employment_status,'Job (With Finger)') employment_status,
           u.status user_status, public.normalize_internal_whatsapp_phone(e.whatsapp_number) normalized_phone
    from public.hr_employee_master e
    join public.users u on u.id=e.user_id and u.status='active' and u.locked_at is null
    left join public.hr_employee_current_status s on s.employee_id=e.id
    where nullif(btrim(e.whatsapp_number),'') is not null
      and coalesce(s.employment_status,'Job (With Finger)') <> 'Resigned'
      and (p_search is null or e.name_en ilike '%'||p_search||'%' or e.name_ar ilike '%'||p_search||'%'
           or e.whatsapp_number ilike '%'||p_search||'%' or u.username ilike '%'||p_search||'%')
  )
  select e.employee_id,e.user_id,e.name,e.name_ar,e.whatsapp_number,e.employment_status,e.user_status,
         c.id,c.last_message_at,coalesce(c.unread_count,0),
         coalesce(c.window_expires_at > now(),false),count(*) over()
  from eligible e
  left join public.wa_internal_account ia on ia.singleton
  left join public.wa_conversations c on c.wa_account_id=ia.account_id
    and public.normalize_internal_whatsapp_phone(c.customer_phone)=e.normalized_phone
  order by coalesce(c.last_message_at,'epoch'::timestamptz) desc,e.name
  limit greatest(p_limit,1) offset greatest(p_offset,0);
$$;

create or replace function public.queue_internal_whatsapp_access(
  p_employee_id text, p_user_id uuid, p_phone text, p_operation text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_account uuid; v_phone text;
begin
  v_phone := public.normalize_internal_whatsapp_phone(p_phone);
  if v_phone is null then return; end if;
  select account_id into v_account from public.wa_internal_account where singleton;
  if v_account is null then return; end if;
  insert into public.wa_internal_access_jobs(account_id,employee_id,user_id,phone_number,operation)
  values(v_account,p_employee_id,p_user_id,v_phone,p_operation);
end;
$$;

create or replace function public.sync_internal_whatsapp_employee_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_employee public.hr_employee_master%rowtype; v_authorized boolean;
begin
  if tg_table_name='hr_employee_master' then
    if tg_op='UPDATE' and old.whatsapp_number is distinct from new.whatsapp_number then
      perform public.queue_internal_whatsapp_access(old.id,old.user_id,old.whatsapp_number,'block');
    end if;
    v_employee := new;
  elsif tg_table_name='users' then
    select * into v_employee from public.hr_employee_master where user_id=new.id;
  else
    select * into v_employee from public.hr_employee_master where id=new.employee_id;
  end if;
  if v_employee.id is null or nullif(btrim(v_employee.whatsapp_number),'') is null then return new; end if;
  v_authorized := public.is_internal_whatsapp_authorized_phone(v_employee.whatsapp_number);
  perform public.queue_internal_whatsapp_access(v_employee.id,v_employee.user_id,v_employee.whatsapp_number,
    case when v_authorized then 'unblock' else 'block' end);
  return new;
end;
$$;

drop trigger if exists trg_internal_wa_employee_access on public.hr_employee_master;
create trigger trg_internal_wa_employee_access after insert or update of whatsapp_number,user_id
on public.hr_employee_master for each row execute function public.sync_internal_whatsapp_employee_access();

drop trigger if exists trg_internal_wa_user_access on public.users;
create trigger trg_internal_wa_user_access after update of status,locked_at
on public.users for each row execute function public.sync_internal_whatsapp_employee_access();

drop trigger if exists trg_internal_wa_status_access on public.hr_employee_status_history;
create trigger trg_internal_wa_status_access after insert or update of status,effective_from,effective_to
on public.hr_employee_status_history for each row execute function public.sync_internal_whatsapp_employee_access();

alter table public.wa_internal_account enable row level security;
alter table public.wa_internal_security_audit enable row level security;
alter table public.wa_internal_access_jobs enable row level security;

drop policy if exists wa_internal_account_authenticated_read on public.wa_internal_account;
create policy wa_internal_account_authenticated_read on public.wa_internal_account for select to authenticated using (true);
drop policy if exists wa_internal_security_audit_authenticated_read on public.wa_internal_security_audit;
create policy wa_internal_security_audit_authenticated_read on public.wa_internal_security_audit for select to authenticated using (true);

grant select on public.wa_internal_account to authenticated;
grant select on public.wa_internal_security_audit to authenticated;
grant execute on function public.get_internal_whatsapp_account() to authenticated,service_role;
grant execute on function public.get_internal_whatsapp_contacts(integer,integer,text) to authenticated,service_role;
grant execute on function public.is_internal_whatsapp_authorized_phone(text) to authenticated,service_role;
grant execute on function public.is_internal_whatsapp_account(uuid) to authenticated,service_role;

commit;
