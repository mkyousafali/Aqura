begin;

alter table public.direct_order_templates
  add column branch_id bigint references public.branches(id) on delete set null,
  add column branch_name_en text,
  add column branch_name_ar text;

comment on column public.direct_order_templates.branch_id is
  'Branch selected when creating the template; used as the default branch for product entry and barcode lookup.';

-- Keep the older single-product creation flow compatible with the new fields.
create or replace function public.direct_orders_assign_legacy_template() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.template_id is null then
    insert into public.direct_order_templates
      (created_by, created_at, branch_id, branch_name_en, branch_name_ar)
    values
      (new.created_by, new.created_at, new.branch_id, new.branch_name_en, new.branch_name_ar)
    returning id into new.template_id;
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';
commit;
