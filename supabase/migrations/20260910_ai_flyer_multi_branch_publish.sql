-- Multi-branch, multi-page Publish: a flyer previously linked to at most ONE live offer at a time
-- (public.ai_generated_flyers.published_offer_id, a single nullable column) -- publishing the same
-- flyer to a second branch just moved that one row instead of creating an independent publication.
-- This replaces that single link with a join table, one row per (flyer, branch) publication, each
-- with its own set of included pages, so a flyer can be published to several branches at once,
-- independently, without one disturbing another.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ai_flyer_publications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flyer_id uuid NOT NULL REFERENCES public.ai_generated_flyers(id) ON DELETE CASCADE,
  view_offer_id uuid NOT NULL REFERENCES public.view_offer(id) ON DELETE CASCADE,
  branch_id bigint NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  page_paths text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flyer_id, branch_id)
);
CREATE INDEX IF NOT EXISTS ai_flyer_publications_flyer_id_idx ON public.ai_flyer_publications(flyer_id);

ALTER TABLE public.ai_flyer_publications ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.ai_flyer_publications TO anon, authenticated;
GRANT ALL ON public.ai_flyer_publications TO service_role;
DROP POLICY IF EXISTS ai_flyer_publications_read ON public.ai_flyer_publications;
CREATE POLICY ai_flyer_publications_read ON public.ai_flyer_publications FOR SELECT TO anon, authenticated USING (true);
-- No direct write policy for anon/authenticated -- only the SECURITY DEFINER functions below
-- write here, same as the rest of this feature.

-- Carry forward any flyer that's already published (under the old single-column link) before that
-- column goes away, so nothing already live goes dark.
INSERT INTO public.ai_flyer_publications (flyer_id, view_offer_id, branch_id, page_paths)
SELECT f.id, f.published_offer_id, o.branch_id, f.page_paths
FROM public.ai_generated_flyers f
JOIN public.view_offer o ON o.id = f.published_offer_id
WHERE f.published_offer_id IS NOT NULL
ON CONFLICT (flyer_id, branch_id) DO NOTHING;

ALTER TABLE public.ai_generated_flyers DROP COLUMN IF EXISTS published_offer_id;

-- Publish -- now keyed on (flyer_id, branch_id) via ai_flyer_publications instead of the dropped
-- single column, and takes which pages were actually included in this branch's publication.
DROP FUNCTION IF EXISTS public.publish_ai_flyer(uuid, bigint, text, date, time without time zone, date, time without time zone, text, text);
CREATE OR REPLACE FUNCTION public.publish_ai_flyer(
  p_flyer_id uuid,
  p_branch_id bigint,
  p_offer_name text,
  p_start_date date,
  p_start_time time without time zone,
  p_end_date date,
  p_end_time time without time zone,
  p_file_url text,
  p_thumbnail_url text,
  p_page_paths text[]
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  SELECT view_offer_id INTO v_offer_id FROM ai_flyer_publications WHERE flyer_id = p_flyer_id AND branch_id = p_branch_id;

  IF v_offer_id IS NOT NULL AND EXISTS (SELECT 1 FROM view_offer WHERE id = v_offer_id) THEN
    UPDATE view_offer SET
      offer_name = p_offer_name,
      start_date = p_start_date,
      start_time = p_start_time,
      end_date = p_end_date,
      end_time = p_end_time,
      file_url = p_file_url,
      thumbnail_url = p_thumbnail_url,
      status = 'published',
      updated_at = now()
    WHERE id = v_offer_id;

    UPDATE ai_flyer_publications SET page_paths = p_page_paths, updated_at = now()
    WHERE flyer_id = p_flyer_id AND branch_id = p_branch_id;
  ELSE
    INSERT INTO view_offer (
      offer_name, branch_id, start_date, start_time, end_date, end_time,
      file_url, thumbnail_url, status
    ) VALUES (
      p_offer_name, p_branch_id, p_start_date, p_start_time, p_end_date, p_end_time,
      p_file_url, p_thumbnail_url, 'published'
    ) RETURNING id INTO v_offer_id;

    INSERT INTO ai_flyer_publications (flyer_id, view_offer_id, branch_id, page_paths)
    VALUES (p_flyer_id, v_offer_id, p_branch_id, p_page_paths);
  END IF;

  INSERT INTO ai_flyer_publish_log (flyer_id, view_offer_id, action)
  VALUES (p_flyer_id, v_offer_id, 'publish');

  RETURN v_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.publish_ai_flyer(
  uuid, bigint, text, date, time without time zone, date, time without time zone, text, text, text[]
) TO anon, authenticated;

-- Unpublish -- now targets one specific branch's publication, not "the" single one.
DROP FUNCTION IF EXISTS public.unpublish_ai_flyer(uuid);
CREATE OR REPLACE FUNCTION public.unpublish_ai_flyer(p_flyer_id uuid, p_branch_id bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  SELECT view_offer_id INTO v_offer_id FROM ai_flyer_publications WHERE flyer_id = p_flyer_id AND branch_id = p_branch_id;

  IF v_offer_id IS NOT NULL THEN
    UPDATE view_offer SET status = 'unpublished', updated_at = now() WHERE id = v_offer_id;

    INSERT INTO ai_flyer_publish_log (flyer_id, view_offer_id, action)
    VALUES (p_flyer_id, v_offer_id, 'unpublish');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unpublish_ai_flyer(uuid, bigint) TO anon, authenticated;

-- Auto-expire -- its join back to the owning flyer (for the log) now goes through
-- ai_flyer_publications instead of the dropped published_offer_id column. Logic otherwise
-- unchanged: flip a published offer to expired once its end date+time has passed.
CREATE OR REPLACE FUNCTION public.expire_view_offers() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  WITH expired AS (
    UPDATE view_offer
    SET status = 'expired', updated_at = now()
    WHERE status = 'published'
      AND (end_date + COALESCE(end_time, '23:59:00'::time)) < (timezone('Asia/Riyadh', now()))::timestamp
    RETURNING id
  )
  INSERT INTO ai_flyer_publish_log (flyer_id, view_offer_id, action)
  SELECT p.flyer_id, e.id, 'auto_expire'
  FROM expired e
  JOIN ai_flyer_publications p ON p.view_offer_id = e.id;
END;
$$;

COMMENT ON TABLE public.ai_flyer_publications IS 'One row per (flyer, branch) live publication -- a flyer can be published to several branches at once, each independently, with its own page selection and schedule (schedule/status itself lives on the linked view_offer row).';
COMMENT ON COLUMN public.ai_flyer_publications.page_paths IS 'The subset of this flyer''s saved pages included in this branch''s published PDF.';

COMMIT;

-- Outside the transaction: make PostgREST pick up the dropped column and the new
-- ai_flyer_publications table/relationships immediately.
NOTIFY pgrst, 'reload schema';
