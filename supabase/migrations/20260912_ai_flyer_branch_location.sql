-- get_ai_flyer_generator_init_data's branches list only returned id/name_en/name_ar, so the
-- Publish dialog's branch picker (and branchLabel() badges) had no way to show location, only
-- name (never the raw id — that part was already fine). Add location_en/location_ar.
BEGIN;

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
      SELECT json_agg(json_build_object(
        'id', b.id, 'name_en', b.name_en, 'name_ar', b.name_ar,
        'location_en', b.location_en, 'location_ar', b.location_ar
      ) ORDER BY b.name_en)
      FROM branches b
      WHERE b.is_active = true
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_ai_flyer_generator_init_data() TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
