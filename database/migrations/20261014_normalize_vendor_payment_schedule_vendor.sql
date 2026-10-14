begin;

-- vendor_payment_schedule previously copied vendor_name into every payment row.
-- The vendor master is now the single source of truth for both paid and unpaid
-- payments. Keep the existing API field name through a read-only joined view.

create or replace function public.auto_create_payment_schedule()
returns trigger
language plpgsql
as $$
declare
    schedule_date timestamptz;
    existing_schedule_id uuid;
    v_branch_name text;
    v_final_amount numeric;
begin
    if (tg_op = 'UPDATE' and old.certificate_url is null and new.certificate_url is not null) or
       (tg_op = 'INSERT' and new.certificate_url is not null) then
        select id into existing_schedule_id
        from public.vendor_payment_schedule
        where receiving_record_id = new.id
        limit 1;

        if existing_schedule_id is null then
            select name_en into v_branch_name
            from public.branches
            where id = new.branch_id
            limit 1;

            v_final_amount := new.bill_amount -
                coalesce(new.expired_return_amount, 0) -
                coalesce(new.near_expiry_return_amount, 0) -
                coalesce(new.over_stock_return_amount, 0) -
                coalesce(new.damage_return_amount, 0);

            if new.due_date is not null then
                schedule_date := new.due_date;
            elsif new.credit_period is not null then
                schedule_date := new.created_at + (new.credit_period || ' days')::interval;
            else
                schedule_date := new.created_at + interval '30 days';
            end if;

            insert into public.vendor_payment_schedule (
                receiving_record_id, bill_number, vendor_id, branch_id, branch_name,
                bill_date, bill_amount, final_bill_amount, payment_method, bank_name,
                iban, due_date, credit_period, vat_number, scheduled_date, is_paid,
                original_due_date, original_bill_amount, original_final_amount,
                receiver_user_id, created_at, updated_at
            ) values (
                new.id, new.bill_number, new.vendor_id, new.branch_id, v_branch_name,
                new.bill_date, new.bill_amount, v_final_amount, new.payment_method,
                new.bank_name, new.iban, new.due_date, new.credit_period, new.vendor_vat_number,
                schedule_date, false, new.due_date, new.bill_amount, v_final_amount,
                new.user_id, now(), now()
            );
            raise notice 'Auto-created payment schedule for receiving record: % (certificate: %)', new.id, new.certificate_url;
        else
            raise notice 'Payment schedule already exists for receiving record: %', new.id;
        end if;
    end if;

    return new;
end;
$$;

alter table public.vendor_payment_schedule
    alter column vendor_id type integer using vendor_id::integer;

alter table public.vendor_payment_schedule
    alter column vendor_id set not null;

alter table public.vendor_payment_schedule
    alter column branch_id set not null;

alter table public.vendor_payment_schedule
    add constraint vendor_payment_schedule_vendor_fkey
    foreign key (vendor_id, branch_id)
    references public.vendors (erp_vendor_id, branch_id)
    on update cascade
    on delete restrict;

alter table public.vendor_payment_schedule
    drop column vendor_name;

create or replace view public.vendor_payment_schedule_with_vendor
with (security_invoker = true)
as
select
    s.*,
    v.vendor_name
from public.vendor_payment_schedule s
join public.vendors v
  on v.erp_vendor_id = s.vendor_id
 and v.branch_id = s.branch_id;

grant select on public.vendor_payment_schedule_with_vendor to anon, authenticated, service_role, replication_user;

create or replace function public.get_paid_vendor_payments(p_date_from date, p_date_to date)
returns table(
    id uuid,
    bill_number character varying,
    vendor_name character varying,
    final_bill_amount numeric,
    bill_date date,
    branch_id integer,
    payment_method character varying,
    bank_name character varying,
    iban character varying,
    is_paid boolean,
    paid_date timestamp without time zone,
    due_date date,
    payment_reference character varying
)
language sql
stable
security definer
set search_path = public
as $$
    select
        s.id,
        s.bill_number,
        v.vendor_name::character varying,
        s.final_bill_amount,
        s.bill_date,
        s.branch_id,
        s.payment_method,
        s.bank_name,
        s.iban,
        s.is_paid,
        s.paid_date,
        s.due_date,
        s.payment_reference
    from public.vendor_payment_schedule s
    join public.vendors v
      on v.erp_vendor_id = s.vendor_id
     and v.branch_id = s.branch_id
    where s.is_paid = true
      and s.due_date >= p_date_from
      and s.due_date <= p_date_to
    order by s.due_date desc;
$$;

create or replace function public.get_vendor_pending_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    result jsonb;
    vps_paid numeric := 0;
    vps_unpaid numeric := 0;
    exp_paid numeric := 0;
    exp_unpaid numeric := 0;
    vendor_count integer := 0;
    vendors_arr jsonb;
    methods_arr jsonb;
begin
    select
        coalesce(sum(case when is_paid then final_bill_amount else 0 end), 0),
        coalesce(sum(case when not is_paid then final_bill_amount else 0 end), 0)
    into vps_paid, vps_unpaid
    from public.vendor_payment_schedule;

    select
        coalesce(sum(case when is_paid then amount else 0 end), 0),
        coalesce(sum(case when not is_paid then amount else 0 end), 0)
    into exp_paid, exp_unpaid
    from public.expense_scheduler
    where vendor_id is not null;

    with all_vendors as (
        select s.vendor_id::text as vid, v.vendor_name as vname, 1 as priority
        from public.vendor_payment_schedule s
        join public.vendors v
          on v.erp_vendor_id = s.vendor_id
         and v.branch_id = s.branch_id
        union all
        select vendor_id::text, vendor_name, 2
        from public.expense_scheduler
        where vendor_id is not null and vendor_name is not null
    ),
    deduped as (
        select distinct on (vid) vid, vname
        from all_vendors
        order by vid, priority, vname
    )
    select
        count(*),
        coalesce(jsonb_agg(jsonb_build_object('vendor_id', vid, 'vendor_name', vname) order by vname), '[]'::jsonb)
    into vendor_count, vendors_arr
    from deduped;

    with all_methods as (
        select distinct payment_method as m
        from public.vendor_payment_schedule
        where payment_method is not null and payment_method <> ''
        union
        select distinct payment_method
        from public.expense_scheduler
        where payment_method is not null and payment_method <> '' and vendor_id is not null
    )
    select coalesce(jsonb_agg(m order by m), '[]'::jsonb)
    into methods_arr
    from all_methods;

    result := jsonb_build_object(
        'global_total_paid', vps_paid + exp_paid,
        'global_total_unpaid', vps_unpaid + exp_unpaid,
        'global_grand_total', vps_paid + exp_paid + vps_unpaid + exp_unpaid,
        'total_vendor_count', vendor_count,
        'vendors', vendors_arr,
        'payment_methods', methods_arr
    );

    return result;
end;
$$;

create or replace function public.get_vendors_with_unpaid_balances()
returns table(
    vendor_id text,
    vendor_name text,
    unpaid_payments numeric,
    unpaid_expenses numeric,
    total_unpaid numeric
)
language sql
security definer
set search_path = public
as $$
    with normalized_payments as (
        select s.*, v.vendor_name
        from public.vendor_payment_schedule s
        join public.vendors v
          on v.erp_vendor_id = s.vendor_id
         and v.branch_id = s.branch_id
    )
    select
        coalesce(vps.vendor_id::text, es.vendor_id::text),
        coalesce(vps.vendor_name, es.vendor_name),
        coalesce(sum(case when vps.is_paid = false then vps.final_bill_amount else 0 end), 0),
        coalesce(sum(case when es.is_paid = false then es.amount else 0 end), 0),
        coalesce(sum(case when vps.is_paid = false then vps.final_bill_amount else 0 end), 0) +
        coalesce(sum(case when es.is_paid = false then es.amount else 0 end), 0)
    from normalized_payments vps
    full outer join public.expense_scheduler es
      on vps.vendor_id = es.vendor_id
     and vps.vendor_name = es.vendor_name
    where vps.vendor_id is not null or es.vendor_id is not null
    group by coalesce(vps.vendor_id::text, es.vendor_id::text), coalesce(vps.vendor_name, es.vendor_name)
    order by 5 desc;
$$;

notify pgrst, 'reload schema';

commit;
