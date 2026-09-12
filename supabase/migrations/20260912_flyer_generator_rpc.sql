-- Converts the Generate Flyers window's remaining direct table/query access to RPC functions,
-- and fixes the AI Generated Flyers library to stop showing flyers whose every publication has
-- already expired (a flyer that was published and every branch's schedule for it has since
-- ended, per view_offer.status = 'expired', auto-flipped by expire_view_offers() via pg_cron).
-- A flyer that was never published, or still has at least one non-expired publication
-- (published or manually unpublished/paused), keeps showing -- it's still relevant/available.
BEGIN;

-- ============================================================================
-- 1. "Generate Without AI" tab (ManualFlyerGenerator.svelte) -- initial load.
-- Replaces 3 separate onMount reads (active offers, flyer templates list, custom fonts) with
-- one round trip.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_manual_flyer_generator_init_data()
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'success', true,
    'offers', COALESCE((
      SELECT json_agg(json_build_object(
        'id', o.id, 'template_id', o.template_id, 'template_name', o.template_name,
        'start_date', o.start_date, 'end_date', o.end_date, 'is_active', o.is_active,
        'created_at', o.created_at, 'offer_name_id', o.offer_name_id,
        'offer_names', CASE WHEN n.id IS NULL THEN NULL
          ELSE json_build_object('name_ar', n.name_ar, 'name_en', n.name_en) END
      ) ORDER BY o.created_at DESC)
      FROM flyer_offers o LEFT JOIN offer_names n ON n.id = o.offer_name_id
      WHERE o.is_active = true
    ), '[]'::json),
    'templates', COALESCE((
      SELECT json_agg(json_build_object(
        'id', t.id, 'name', t.name, 'description', t.description, 'is_default', t.is_default,
        'is_active', t.is_active, 'category', t.category, 'usage_count', t.usage_count,
        'created_at', t.created_at
      ) ORDER BY t.is_default DESC, t.usage_count DESC)
      FROM flyer_templates t
      WHERE t.is_active = true AND t.deleted_at IS NULL
    ), '[]'::json),
    'fonts', COALESCE((
      SELECT json_agg(json_build_object(
        'id', f.id, 'name', f.name, 'font_url', f.font_url, 'file_name', f.file_name,
        'file_size', f.file_size, 'created_by', f.created_by, 'created_at', f.created_at,
        'original_file_name', f.original_file_name
      ) ORDER BY f.name)
      FROM shelf_paper_fonts f
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_manual_flyer_generator_init_data() TO anon, authenticated;

-- ============================================================================
-- 2. "Generate Without AI" tab -- full template detail, loaded on demand when the user picks a
-- template (handleTemplateChange). Replaces the single-row .select().eq('id',...).single() read.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_flyer_template_detail(p_template_id uuid)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'id', t.id, 'name', t.name, 'description', t.description,
    'first_page_image_url', t.first_page_image_url, 'sub_page_image_urls', t.sub_page_image_urls,
    'first_page_configuration', t.first_page_configuration,
    'sub_page_configurations', t.sub_page_configurations, 'metadata', t.metadata,
    'is_active', t.is_active, 'is_default', t.is_default, 'category', t.category,
    'usage_count', t.usage_count, 'created_at', t.created_at
  ) INTO v_result
  FROM flyer_templates t
  WHERE t.id = p_template_id;

  IF v_result IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Template not found');
  END IF;

  RETURN json_build_object('success', true, 'data', v_result);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_flyer_template_detail(uuid) TO anon, authenticated;

-- ============================================================================
-- 3. "Generate Without AI" tab -- save a template's field configuration (saveTemplateConfiguration).
-- Replaces the direct .update() on flyer_templates.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_flyer_template_configuration(
  p_template_id uuid,
  p_first_page_configuration jsonb,
  p_sub_page_configurations jsonb
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE flyer_templates
  SET first_page_configuration = p_first_page_configuration,
      sub_page_configurations = p_sub_page_configurations
  WHERE id = p_template_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Template not found');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_flyer_template_configuration(uuid, jsonb, jsonb) TO anon, authenticated;

-- ============================================================================
-- 4. "Generate With AI" / "AI Generated Flyers" tabs (AiFlyerGenerator.svelte) -- initial load.
-- Replaces 3 separate onMount reads (active offers, offer contexts, branches) with one round trip.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_ai_flyer_generator_init_data()
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'success', true,
    'offers', COALESCE((
      SELECT json_agg(json_build_object(
        'id', o.id, 'template_name', o.template_name, 'start_date', o.start_date,
        'end_date', o.end_date,
        'offer_names', CASE WHEN n.id IS NULL THEN NULL
          ELSE json_build_object('name_en', n.name_en, 'name_ar', n.name_ar) END
      ) ORDER BY o.created_at DESC)
      FROM flyer_offers o LEFT JOIN offer_names n ON n.id = o.offer_name_id
      WHERE o.is_active = true
    ), '[]'::json),
    'contexts', COALESCE((
      SELECT json_agg(json_build_object('id', c.id, 'name', c.name, 'description', c.description) ORDER BY c.sort_order)
      FROM flyer_offer_contexts c
      WHERE c.is_active = true
    ), '[]'::json),
    'branches', COALESCE((
      SELECT json_agg(json_build_object('id', b.id, 'name_en', b.name_en, 'name_ar', b.name_ar) ORDER BY b.name_en)
      FROM branches b
      WHERE b.is_active = true
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_ai_flyer_generator_init_data() TO anon, authenticated;

-- ============================================================================
-- 5. "Generate With AI" tab -- save a completed AI flyer (save()). Replaces the direct .insert()
-- plus its client-side "does it already exist" recovery check -- ON CONFLICT DO NOTHING makes a
-- retry of the same client-generated id a safe no-op, matching that recovery logic server-side.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_ai_generated_flyer(
  p_id uuid,
  p_offer_id uuid,
  p_title text,
  p_start_date date,
  p_end_date date,
  p_page_count integer,
  p_product_count integer,
  p_page_paths text[],
  p_snapshot jsonb,
  p_model text
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO ai_generated_flyers (
    id, offer_id, title, start_date, end_date, page_count, product_count, page_paths, snapshot, model
  ) VALUES (
    p_id, p_offer_id, p_title, p_start_date, p_end_date, p_page_count, p_product_count, p_page_paths, p_snapshot, p_model
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN json_build_object('success', true, 'id', p_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_ai_generated_flyer(
  uuid, uuid, text, date, date, integer, integer, text[], jsonb, text
) TO anon, authenticated;

-- ============================================================================
-- 6. "AI Generated Flyers" tab -- the library list (loadLibrary()). Replaces the direct
-- .select(...).range(...) query, AND is the actual fix for the reported problem: excludes any
-- flyer whose every publication has expired, computed and paginated server-side (the previous
-- client-side range-then-filter approach couldn't do this without breaking "has more" pagination,
-- since filtering after the page was already sliced could silently shrink a page below its
-- requested size).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_ai_flyer_library(
  p_page integer DEFAULT 0,
  p_page_size integer DEFAULT 20
) RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'success', true,
    'total_count', COALESCE(MAX(page_row.total_count), 0),
    'has_more', (p_page + 1) * p_page_size < COALESCE(MAX(page_row.total_count), 0),
    'data', COALESCE(json_agg(
      json_build_object(
        'id', page_row.id, 'title', page_row.title, 'start_date', page_row.start_date,
        'end_date', page_row.end_date, 'page_count', page_row.page_count,
        'product_count', page_row.product_count, 'page_paths', page_row.page_paths,
        'created_at', page_row.created_at, 'context', page_row.context,
        'publications', page_row.publications
      ) ORDER BY page_row.created_at DESC
    ), '[]'::json)
  ) INTO v_result
  FROM (
    SELECT
      r.id, r.title, r.start_date, r.end_date, r.page_count, r.product_count,
      r.page_paths, r.created_at,
      r.snapshot->'context' AS context,
      COALESCE(pubs.publications, '[]'::json) AS publications,
      count(*) OVER() AS total_count
    FROM ai_generated_flyers r
    LEFT JOIN LATERAL (
      SELECT json_agg(json_build_object(
        'branch_id', p.branch_id,
        'page_paths', p.page_paths,
        'offer', json_build_object(
          'status', vo.status, 'start_date', vo.start_date, 'start_time', vo.start_time,
          'end_date', vo.end_date, 'end_time', vo.end_time
        )
      )) AS publications
      FROM ai_flyer_publications p JOIN view_offer vo ON vo.id = p.view_offer_id
      WHERE p.flyer_id = r.id
    ) pubs ON true
    WHERE
      -- Never published -- still relevant/available to publish.
      NOT EXISTS (SELECT 1 FROM ai_flyer_publications p WHERE p.flyer_id = r.id)
      -- Or has at least one publication that hasn't expired (still live, or manually
      -- unpublished/paused rather than run its course) -- still relevant.
      OR EXISTS (
        SELECT 1 FROM ai_flyer_publications p
        JOIN view_offer vo ON vo.id = p.view_offer_id
        WHERE p.flyer_id = r.id AND vo.status <> 'expired'
      )
    ORDER BY r.created_at DESC
    LIMIT p_page_size OFFSET p_page * p_page_size
  ) page_row;

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_ai_flyer_library(integer, integer) TO anon, authenticated;

-- ============================================================================
-- 7. "AI Generated Flyers" tab -- delete a saved flyer (deleteFlyer()). Replaces the direct
-- .delete(); the page-file cleanup in storage still happens client-side afterward exactly as
-- before (Storage has no RPC equivalent, and the delete-order comment in AiFlyerGenerator.svelte
-- about the storage cleanup policy still applies).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_ai_generated_flyer(p_id uuid) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM ai_generated_flyers WHERE id = p_id;
  RETURN json_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_ai_generated_flyer(uuid) TO anon, authenticated;

COMMIT;

-- Outside the transaction: make PostgREST pick up the new functions immediately.
NOTIFY pgrst, 'reload schema';
