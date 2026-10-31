begin;
create temp table vendors (branch_id bigint, erp_vendor_id integer, vendor_name text);
create temp table users (id uuid, username text);
create temp table expense_scheduler (
 id serial primary key, schedule_type text, branch_id bigint, branch_name text,
 vendor_id integer, vendor_name text, expense_category_id integer,
 expense_category_name_en text, expense_category_name_ar text, requisition_id integer,
 requisition_number text, co_user_id uuid, co_user_name text, payment_method text,
 amount numeric, description text, bill_type text, due_date date, approver_id uuid,
 approver_name text, approval_status text, created_by uuid, recurring_metadata jsonb,
 recurring_type text, status text, is_paid boolean
);
create temp table non_approved_payment_scheduler (like pg_temp.expense_scheduler including all);
-- INSTALL_GENERATOR_HERE
-- INSTALL_MIGRATION_HERE
create temp table qa_results(name text);
create function pg_temp.qa_assert(ok boolean, name text) returns void language plpgsql as $$
begin if not coalesce(ok,false) then raise exception 'FAIL: %', name; end if;
 insert into pg_temp.qa_results values(name); end; $$;
do $tests$
declare
 source_name text; mode text; parent_id integer; actor uuid:=gen_random_uuid();
 metadata jsonb; denied boolean;
begin
 insert into pg_temp.vendors values(3,1508,'Canonical Vendor'),(1,99,'Other branch vendor');
 insert into pg_temp.users values(actor,'Test User');
 foreach source_name in array array['non_approved_payment_scheduler','expense_scheduler'] loop
  foreach mode in array array['daily','weekly','monthly_date','monthly_day','custom'] loop
   metadata := jsonb_build_object('until_date',current_date+14,'weekday',extract(dow from current_date)::integer,
    'month_position','end','until_month',to_char(current_date+interval '2 months','YYYY-MM'),
    'day_of_month',1,'custom_dates',jsonb_build_array((current_date+1)::text,(current_date+2)::text));
   execute format('insert into pg_temp.%I(schedule_type,branch_id,branch_name,vendor_id,vendor_name,recurring_type,recurring_metadata,created_by,amount) values(''recurring'',3,''Branch'',1508,''stale name'',$1,$2,$3,100) returning id',source_name)
    into parent_id using mode,metadata,actor;
   perform * from pg_temp.generate_recurring_occurrences(parent_id,source_name);
   execute format('select count(*) > 0 and bool_and(vendor_id=1508 and vendor_name=''Canonical Vendor'') from pg_temp.%I where recurring_metadata->>''parent_schedule_id''=$1',source_name)
    into denied using parent_id::text;
   perform pg_temp.qa_assert(denied,source_name || ' ' || mode || ' occurrences keep canonical vendor');
  end loop;
 end loop;
 denied:=false;
 begin insert into pg_temp.non_approved_payment_scheduler(branch_id,vendor_id) values(3,99);
 exception when others then denied:=true; end;
 perform pg_temp.qa_assert(denied,'cross-branch vendor is rejected');
 insert into pg_temp.non_approved_payment_scheduler(branch_id) values(3) returning id into parent_id;
 perform pg_temp.qa_assert((select vendor_id is null from pg_temp.non_approved_payment_scheduler where id=parent_id),'general expense remains supported');
end;
$tests$;
select 'PASS: '||count(*)||' scheduler vendor assertions' from pg_temp.qa_results;
rollback;
