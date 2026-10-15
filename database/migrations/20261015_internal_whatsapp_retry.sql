begin;

create or replace function public.invoke_internal_whatsapp_access_worker()
returns void
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare v_url text; v_key text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name='supabase_url' limit 1;
  select decrypted_secret into v_key from vault.decrypted_secrets where name='service_role_key' limit 1;
  if v_url is null or v_key is null then return; end if;
  perform net.http_post(
    url := rtrim(v_url,'/') || '/functions/v1/internal-whatsapp-access',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||v_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
exception when others then
  raise warning 'Unable to invoke Internal WhatsApp access worker: %', sqlerrm;
end;
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
  perform public.invoke_internal_whatsapp_access_worker();
end;
$$;

do $$
declare v_job bigint;
begin
  select jobid into v_job from cron.job where jobname='internal-whatsapp-access-retry';
  if v_job is not null then perform cron.unschedule(v_job); end if;
  perform cron.schedule('internal-whatsapp-access-retry','* * * * *',
    'select public.invoke_internal_whatsapp_access_worker();');
end;
$$;

commit;
