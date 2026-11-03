begin;

alter table public.direct_orders
  alter column photo_path drop not null,
  add column revision bigint not null default 1,
  add column updated_at timestamptz not null default now(),
  add column updated_by uuid references public.users(id),
  add column last_mutation_id uuid;

create table public.direct_order_product_photos (
  product_id uuid primary key references public.direct_orders(id) on delete cascade,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  photo_data bytea not null check (octet_length(photo_data) between 1 and 10485760),
  updated_at timestamptz not null default now()
);
alter table public.direct_order_product_photos enable row level security;
revoke all on public.direct_order_product_photos from public, anon, authenticated;
grant select, insert, update on public.direct_order_product_photos to service_role;
comment on table public.direct_order_product_photos is
  'Private Direct Order photos read and saved through RPC; no browser Storage URLs.';

create function public.direct_order_user_allowed(p_actor uuid, p_interface text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(p_interface in ('desktop', 'mobile'), false) and exists (
    select 1 from public.users u
    left join public.interface_permissions ip on ip.user_id = u.id
    where u.id = p_actor and u.status = 'active'
      and (case when p_interface = 'mobile' then ip.mobile_enabled else ip.desktop_enabled end) is not false
      and (u.is_master_admin is true or exists (
        select 1 from public.button_permissions bp
        where bp.user_id = u.id and bp.button_code = 'DIRECT_ORDER' and bp.is_enabled is true
      ))
  );
$$;

create function public.direct_order_actor(p_interface text)
returns uuid language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_actor uuid;
begin
  if auth.uid() is null then raise exception 'Signed-in session required' using errcode = '42501'; end if;
  -- Only trusted Auth identity mappings and server-owned app metadata are used.
  select u.id into v_actor from public.users u
  where (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text or u.id = auth.uid()
    or u.id::text = (auth.jwt() -> 'app_metadata' ->> 'aqura_user_id')
  order by case when (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text then 0 when u.id = auth.uid() then 1 else 2 end
  limit 1;
  if not public.direct_order_user_allowed(v_actor, p_interface) then
    raise exception 'Direct Order access required' using errcode = '42501';
  end if;
  return v_actor;
end;
$$;

create function public.direct_order_server_has_access(p_actor_user_id uuid, p_interface text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public.direct_order_user_allowed(p_actor_user_id, p_interface);
$$;

create function public.direct_order_template_json(p_template public.direct_order_templates)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select (to_jsonb(p_template) - 'created_by') || jsonb_build_object(
    'product_count', (select count(*) from public.direct_orders p where p.template_id = p_template.id)
  );
$$;

create function public.direct_order_product_json(p_product public.direct_orders)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select (to_jsonb(p_product) - 'photo_path' - 'created_by' - 'updated_by' - 'last_mutation_id')
    || jsonb_build_object('has_photo', exists (
      select 1 from public.direct_order_product_photos ph where ph.product_id = p_product.id
    ) or p_product.photo_path is not null);
$$;

create function public.direct_order_decode_photo(p_base64 text, p_mime text)
returns bytea language plpgsql immutable set search_path = public, pg_temp as $$
declare v_data bytea;
begin
  if p_base64 is null then return null; end if;
  if p_mime is null or p_mime not in ('image/jpeg', 'image/png', 'image/webp') or length(p_base64) > 14350000 then
    raise exception 'Unsupported photo or photo exceeds 10 MB' using errcode = '22023';
  end if;
  v_data := decode(p_base64, 'base64');
  if octet_length(v_data) not between 1 and 10485760 then
    raise exception 'Photo must be between 1 byte and 10 MB' using errcode = '22023';
  end if;
  if not (
    (p_mime = 'image/jpeg' and substring(v_data from 1 for 3) = decode('ffd8ff', 'hex'))
    or (p_mime = 'image/png' and substring(v_data from 1 for 8) = decode('89504e470d0a1a0a', 'hex'))
    or (p_mime = 'image/webp' and substring(v_data from 1 for 4) = decode('52494646', 'hex')
      and substring(v_data from 9 for 4) = decode('57454250', 'hex'))
  ) then raise exception 'Invalid image data' using errcode = '22023'; end if;
  return v_data;
end;
$$;

create function public.direct_order_branches(p_interface text default 'desktop')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.direct_order_actor(p_interface);
  return jsonb_build_object('success', true, 'branches', coalesce((
    select jsonb_agg(jsonb_build_object('id', b.id, 'name_en', b.name_en, 'name_ar', b.name_ar,
      'location_en', b.location_en, 'location_ar', b.location_ar) order by b.name_en)
    from public.branches b where b.is_active is true
  ), '[]'::jsonb));
end;
$$;

create function public.direct_order_list_templates(p_before bigint default null, p_limit integer default 50, p_interface text default 'desktop')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_limit integer := greatest(1, least(coalesce(p_limit, 50), 50)); v_rows jsonb;
begin
  perform public.direct_order_actor(p_interface);
  select coalesce(jsonb_agg(public.direct_order_template_json(t::public.direct_order_templates) order by t.order_number desc), '[]'::jsonb)
  into v_rows from (
    select * from public.direct_order_templates where p_before is null or order_number < p_before
    order by order_number desc limit v_limit + 1
  ) t;
  return jsonb_build_object('success', true, 'templates', v_rows - v_limit, 'hasMore', jsonb_array_length(v_rows) > v_limit);
end;
$$;

create function public.direct_order_get_products(p_template_id uuid, p_before bigint default null, p_limit integer default 50, p_interface text default 'desktop')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_template public.direct_order_templates; v_limit integer := greatest(1, least(coalesce(p_limit, 50), 50)); v_rows jsonb;
begin
  perform public.direct_order_actor(p_interface);
  select * into v_template from public.direct_order_templates where id = p_template_id;
  if not found then raise exception 'Order template not found' using errcode = 'P0002'; end if;
  select coalesce(jsonb_agg(public.direct_order_product_json(p::public.direct_orders) order by p.order_number desc), '[]'::jsonb)
  into v_rows from (
    select * from public.direct_orders where template_id = p_template_id and (p_before is null or order_number < p_before)
    order by order_number desc limit v_limit + 1
  ) p;
  return jsonb_build_object('success', true, 'template', public.direct_order_template_json(v_template),
    'orders', v_rows - v_limit, 'hasMore', jsonb_array_length(v_rows) > v_limit);
end;
$$;

create function public.direct_order_get_product(p_template_id uuid, p_product_id uuid, p_interface text default 'desktop')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_product public.direct_orders;
begin
  perform public.direct_order_actor(p_interface);
  select * into v_product from public.direct_orders where id = p_product_id and template_id = p_template_id;
  if not found then raise exception 'Product not found' using errcode = 'P0002'; end if;
  return jsonb_build_object('success', true, 'order', public.direct_order_product_json(v_product));
end;
$$;

create function public.direct_order_get_photo(p_template_id uuid, p_product_id uuid, p_interface text default 'desktop')
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_photo public.direct_order_product_photos; v_revision bigint;
begin
  perform public.direct_order_actor(p_interface);
  select p.revision into v_revision from public.direct_orders p where p.id = p_product_id and p.template_id = p_template_id;
  if not found then raise exception 'Product not found' using errcode = 'P0002'; end if;
  select * into v_photo from public.direct_order_product_photos where product_id = p_product_id;
  if not found then raise exception 'Product photo unavailable' using errcode = 'P0002'; end if;
  return jsonb_build_object('success', true, 'mimeType', v_photo.mime_type,
    'photoBase64', encode(v_photo.photo_data, 'base64'), 'revision', v_revision);
end;
$$;

create function public.direct_order_create_template(p_id uuid, p_shop_name text, p_shop_location text, p_branch_id bigint, p_interface text default 'desktop')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_actor uuid := public.direct_order_actor(p_interface); v_template public.direct_order_templates; v_branch public.branches;
begin
  if p_id is null or coalesce(length(btrim(p_shop_name)), 0) not between 1 and 200
    or coalesce(length(btrim(p_shop_location)), 0) not between 1 and 500 or p_branch_id is null then
    raise exception 'Shop name, shop location and branch are required' using errcode = '22023';
  end if;
  select * into v_template from public.direct_order_templates where id = p_id;
  if found then
    if v_template.created_by <> v_actor then raise exception 'Template ID already in use' using errcode = '42501'; end if;
    return jsonb_build_object('success', true, 'template', public.direct_order_template_json(v_template));
  end if;
  select * into v_branch from public.branches where id = p_branch_id and is_active is true;
  if not found then raise exception 'Select an available branch' using errcode = '22023'; end if;
  insert into public.direct_order_templates(id, shop_name, shop_location, branch_id, branch_name_en, branch_name_ar, created_by)
  values(p_id, btrim(p_shop_name), btrim(p_shop_location), p_branch_id,
    concat_ws(' - ', nullif(v_branch.name_en, ''), nullif(v_branch.location_en, '')),
    concat_ws(' - ', nullif(coalesce(v_branch.name_ar, v_branch.name_en), ''), nullif(coalesce(v_branch.location_ar, v_branch.location_en), '')), v_actor)
  on conflict(id) do nothing;
  select * into v_template from public.direct_order_templates where id = p_id;
  if v_template.created_by <> v_actor then raise exception 'Template ID already in use' using errcode = '42501'; end if;
  return jsonb_build_object('success', true, 'template', public.direct_order_template_json(v_template));
end;
$$;

create function public.direct_order_save_product(
  p_product_id uuid, p_template_id uuid, p_quantity numeric, p_mutation_id uuid,
  p_branch_id bigint default null, p_product_code text default null, p_barcode text default null,
  p_product_name_en text default null, p_photo_base64 text default null, p_photo_mime text default null,
  p_expected_revision bigint default null, p_interface text default 'desktop'
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.direct_order_actor(p_interface); v_template public.direct_order_templates;
  v_product public.direct_orders; v_branch public.branches; v_branch_id bigint; v_photo bytea;
  v_exists boolean; v_name text := nullif(btrim(p_product_name_en), '');
begin
  if p_product_id is null or p_template_id is null or p_mutation_id is null or p_quantity is null
    or not(p_quantity > 0 and p_quantity < 'Infinity'::numeric) then
    raise exception 'Photo and positive quantity are required' using errcode = '22023';
  end if;
  if length(coalesce(p_product_code, '')) > 100 or length(coalesce(p_barcode, '')) > 100 or length(coalesce(v_name, '')) > 2000 then
    raise exception 'Invalid product details' using errcode = '22023';
  end if;
  -- Serialize the same product ID before checking insert/update/retry semantics.
  perform pg_advisory_xact_lock(hashtextextended(p_product_id::text, 0));
  select * into v_template from public.direct_order_templates where id = p_template_id for key share;
  if not found then raise exception 'Order template not found' using errcode = 'P0002'; end if;
  select * into v_product from public.direct_orders where id = p_product_id for update;
  v_exists := found;
  if v_exists then
    if v_product.template_id <> p_template_id then raise exception 'Product belongs to another order' using errcode = '42501'; end if;
    if v_product.last_mutation_id = p_mutation_id and v_product.updated_by = v_actor then
      return jsonb_build_object('success', true, 'order', public.direct_order_product_json(v_product));
    end if;
    if p_expected_revision is null or p_expected_revision <> v_product.revision then
      raise exception 'Product changed. Reopen it before saving.' using errcode = '40001';
    end if;
  elsif p_expected_revision is not null then
    raise exception 'Product no longer exists' using errcode = '40001';
  end if;
  v_photo := public.direct_order_decode_photo(p_photo_base64, p_photo_mime);
  if v_photo is null and (not v_exists or not exists (
    select 1 from public.direct_order_product_photos where product_id = p_product_id
  )) then raise exception 'Product photo is required' using errcode = '22023'; end if;
  v_branch_id := coalesce(p_branch_id, v_template.branch_id);
  if v_branch_id is not null then
    select * into v_branch from public.branches where id = v_branch_id and is_active is true;
    if not found then raise exception 'Select an available branch or leave it empty' using errcode = '22023'; end if;
  end if;
  if v_branch_id is null or nullif(btrim(p_barcode), '') is null then v_name := null; end if;
  if v_exists then
    update public.direct_orders set
      quantity = p_quantity, branch_id = v_branch_id,
      branch_name_en = case when v_branch_id is not null then concat_ws(' - ', nullif(v_branch.name_en, ''), nullif(v_branch.location_en, '')) end,
      branch_name_ar = case when v_branch_id is not null then concat_ws(' - ', nullif(coalesce(v_branch.name_ar, v_branch.name_en), ''), nullif(coalesce(v_branch.location_ar, v_branch.location_en), '')) end,
      product_code = nullif(btrim(p_product_code), ''), barcode = nullif(btrim(p_barcode), ''), product_name_en = v_name,
      revision = revision + 1, updated_at = clock_timestamp(), updated_by = v_actor, last_mutation_id = p_mutation_id
    where id = p_product_id returning * into v_product;
  else
    insert into public.direct_orders(id, template_id, quantity, branch_id, branch_name_en, branch_name_ar,
      product_code, barcode, product_name_en, created_by, updated_by, last_mutation_id)
    values(p_product_id, p_template_id, p_quantity, v_branch_id,
      case when v_branch_id is not null then concat_ws(' - ', nullif(v_branch.name_en, ''), nullif(v_branch.location_en, '')) end,
      case when v_branch_id is not null then concat_ws(' - ', nullif(coalesce(v_branch.name_ar, v_branch.name_en), ''), nullif(coalesce(v_branch.location_ar, v_branch.location_en), '')) end,
      nullif(btrim(p_product_code), ''), nullif(btrim(p_barcode), ''), v_name, v_actor, v_actor, p_mutation_id)
    returning * into v_product;
  end if;
  if v_photo is not null then
    insert into public.direct_order_product_photos(product_id, mime_type, photo_data)
    values(p_product_id, p_photo_mime, v_photo)
    on conflict(product_id) do update set mime_type = excluded.mime_type, photo_data = excluded.photo_data, updated_at = clock_timestamp();
  end if;
  return jsonb_build_object('success', true, 'order', public.direct_order_product_json(v_product));
end;
$$;

-- One-time photo migration helpers are callable only with the server service role.
create function public.direct_order_pending_photo_imports()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'photo_path', p.photo_path)), '[]'::jsonb)
  from (select id, photo_path from public.direct_orders o where photo_path is not null
    and not exists(select 1 from public.direct_order_product_photos ph where ph.product_id = o.id)
    order by order_number limit 50) p;
$$;

create function public.direct_order_import_photo(p_product_id uuid, p_base64 text, p_mime text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare v_data bytea := public.direct_order_decode_photo(p_base64, p_mime);
begin
  if v_data is null then raise exception 'Photo required'; end if;
  perform 1 from public.direct_orders where id = p_product_id for key share;
  if not found then return false; end if;
  insert into public.direct_order_product_photos(product_id, mime_type, photo_data)
  values(p_product_id, p_mime, v_data) on conflict(product_id) do nothing;
  return true;
end;
$$;

do $$
declare f record;
begin
  for f in select p.oid::regprocedure as signature, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any(array[
      'direct_order_user_allowed', 'direct_order_actor', 'direct_order_server_has_access',
      'direct_order_template_json', 'direct_order_product_json', 'direct_order_decode_photo',
      'direct_order_branches', 'direct_order_list_templates', 'direct_order_get_products',
      'direct_order_get_product', 'direct_order_get_photo', 'direct_order_create_template',
      'direct_order_save_product', 'direct_order_pending_photo_imports', 'direct_order_import_photo'
    ])
  loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f.signature);
    if f.proname = any(array['direct_order_branches', 'direct_order_list_templates', 'direct_order_get_products',
      'direct_order_get_product', 'direct_order_get_photo', 'direct_order_create_template', 'direct_order_save_product']) then
      execute format('grant execute on function %s to authenticated', f.signature);
    elsif f.proname = any(array['direct_order_server_has_access', 'direct_order_pending_photo_imports', 'direct_order_import_photo']) then
      execute format('grant execute on function %s to service_role', f.signature);
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
commit;
