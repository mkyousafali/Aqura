begin;

create table if not exists public.iqama_sadad_documents (
  id uuid primary key default gen_random_uuid(),
  source_file_name text not null,
  employee_name text not null,
  employee_branch_id bigint references public.branches(id) on delete restrict,
  iqama_number text not null,
  sadad_number text not null unique,
  duration_months integer,
  detected_amount numeric(14,2),
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid not null references public.users(id),
  updated_at timestamptz not null default now(),
  constraint iqama_sadad_documents_iqama_check check (iqama_number ~ '^[0-9]{10}$'),
  constraint iqama_sadad_documents_sadad_check check (sadad_number ~ '^[0-9]{12,18}$'),
  constraint iqama_sadad_documents_file_check check (btrim(source_file_name) <> '')
);

create index if not exists iqama_sadad_documents_iqama_idx on public.iqama_sadad_documents(iqama_number);
create index if not exists iqama_sadad_documents_branch_idx on public.iqama_sadad_documents(employee_branch_id);

alter table public.iqama_sadad_documents enable row level security;
revoke all on public.iqama_sadad_documents from public, anon, authenticated;
grant all on public.iqama_sadad_documents to service_role;

create or replace function public.get_iqama_sadad_documents()
returns table (
  id uuid,
  source_file_name text,
  employee_name text,
  employee_branch_id bigint,
  employee_branch text,
  iqama_number text,
  sadad_number text,
  duration_months integer,
  detected_amount numeric,
  created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return query
    select d.id, d.source_file_name, d.employee_name, d.employee_branch_id,
      case when b.id is null then 'No branch configured'::text
        else concat_ws(' - ', coalesce(b.name_en, b.name_ar, 'Branch ' || b.id), nullif(coalesce(b.location_en, b.location_ar, ''), ''))::text end,
      d.iqama_number, d.sadad_number, d.duration_months, d.detected_amount, d.created_at
    from public.iqama_sadad_documents d
    left join public.branches b on b.id = d.employee_branch_id
    order by d.created_at desc;
end;
$$;

create or replace function public.save_iqama_sadad_documents(p_documents jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id(); v_document jsonb; v_count integer := 0;
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if p_documents is null or jsonb_typeof(p_documents) <> 'array' or jsonb_array_length(p_documents) = 0 then
    raise exception 'At least one ready document is required.';
  end if;
  for v_document in select value from jsonb_array_elements(p_documents)
  loop
    if coalesce(v_document->>'iqama_number', '') !~ '^[0-9]{10}$'
      or coalesce(v_document->>'sadad_number', '') !~ '^[0-9]{12,18}$' then
      raise exception 'Every saved document requires a valid Iqama and SADAD number.';
    end if;
    insert into public.iqama_sadad_documents (
      source_file_name, employee_name, employee_branch_id, iqama_number, sadad_number,
      duration_months, detected_amount, created_by, updated_by, updated_at
    ) values (
      btrim(v_document->>'source_file_name'), coalesce(nullif(btrim(v_document->>'employee_name'), ''), 'Not detected'),
      nullif(v_document->>'employee_branch_id', '')::bigint, v_document->>'iqama_number', v_document->>'sadad_number',
      nullif(v_document->>'duration_months', '')::integer, nullif(v_document->>'detected_amount', '')::numeric,
      v_actor, v_actor, now()
    ) on conflict (sadad_number) do update set
      source_file_name = excluded.source_file_name, employee_name = excluded.employee_name,
      employee_branch_id = excluded.employee_branch_id, iqama_number = excluded.iqama_number,
      duration_months = excluded.duration_months, detected_amount = excluded.detected_amount,
      updated_by = v_actor, updated_at = now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.get_iqama_sadad_documents(), public.save_iqama_sadad_documents(jsonb) from public, anon;
grant execute on function public.get_iqama_sadad_documents(), public.save_iqama_sadad_documents(jsonb) to authenticated;

commit;
