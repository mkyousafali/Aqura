-- Publish flow: link a saved AI-generated flyer (public.ai_generated_flyers) to a real,
-- scheduled offer row in public.view_offer -- the same table the Login page, Offers page and
-- the WhatsApp Live Chat AI (via get_active_offers) already read from.
--
-- Design: a flyer is only ever linked to a view_offer row at the moment Publish is pressed.
-- There is no "draft" row sitting in view_offer beforehand -- "not yet published" simply means
-- ai_generated_flyers.published_offer_id IS NULL. This keeps view_offer exactly as it is today
-- for every existing manual offer (AddOfferDialog.svelte is untouched; its rows default to the
-- new status of 'published', so they keep behaving exactly as before with zero code changes).
BEGIN;

-- 1. Status lifecycle on view_offer. Existing rows (and every future manual insert) default to
--    'published', matching today's implicit behaviour (an added offer is live immediately).
ALTER TABLE public.view_offer
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('published','unpublished','expired'));

-- 2. Link a flyer to the offer it published, so the AI-Generated Flyers table can show live
--    status via a PostgREST embed (`published_offer_id(status, ...)`) instead of a second query.
--    NULL = never published ("Not Published" in the UI).
ALTER TABLE public.ai_generated_flyers
  ADD COLUMN IF NOT EXISTS published_offer_id uuid REFERENCES public.view_offer(id) ON DELETE SET NULL;

-- 3. Publish/unpublish/auto-expire audit log -- lets the AI-Generated Flyers UI show how many
--    times a flyer was published/unpublished, and gives a full history of status changes.
CREATE TABLE IF NOT EXISTS public.ai_flyer_publish_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  flyer_id uuid NOT NULL REFERENCES public.ai_generated_flyers(id) ON DELETE CASCADE,
  view_offer_id uuid REFERENCES public.view_offer(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (action IN ('publish','unpublish','auto_expire')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_flyer_publish_log_flyer_id_idx ON public.ai_flyer_publish_log(flyer_id);

ALTER TABLE public.ai_flyer_publish_log ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.ai_flyer_publish_log TO anon, authenticated;
GRANT ALL ON public.ai_flyer_publish_log TO service_role;
DROP POLICY IF EXISTS ai_flyer_publish_log_read ON public.ai_flyer_publish_log;
CREATE POLICY ai_flyer_publish_log_read ON public.ai_flyer_publish_log FOR SELECT TO anon, authenticated USING (true);
-- No direct INSERT policy for anon/authenticated -- rows are only ever written by the
-- SECURITY DEFINER functions below, never inserted directly by the browser.

-- 4. Publish -- creates the view_offer row the first time, or updates the same row on every
--    later re-publish (so counters like view_button_count/page_visit_count survive edits).
--    SECURITY DEFINER is required here because ai_generated_flyers deliberately grants no UPDATE
--    to anon/authenticated ("existing saved records cannot be edited/deleted" by hand) -- this
--    function is the one controlled exception, touching only published_offer_id.
CREATE OR REPLACE FUNCTION public.publish_ai_flyer(
  p_flyer_id uuid,
  p_branch_id bigint,
  p_offer_name text,
  p_start_date date,
  p_start_time time without time zone,
  p_end_date date,
  p_end_time time without time zone,
  p_file_url text,
  p_thumbnail_url text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  SELECT published_offer_id INTO v_offer_id FROM ai_generated_flyers WHERE id = p_flyer_id;

  IF v_offer_id IS NOT NULL AND EXISTS (SELECT 1 FROM view_offer WHERE id = v_offer_id) THEN
    UPDATE view_offer SET
      branch_id = p_branch_id,
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
  ELSE
    INSERT INTO view_offer (
      offer_name, branch_id, start_date, start_time, end_date, end_time,
      file_url, thumbnail_url, status
    ) VALUES (
      p_offer_name, p_branch_id, p_start_date, p_start_time, p_end_date, p_end_time,
      p_file_url, p_thumbnail_url, 'published'
    ) RETURNING id INTO v_offer_id;

    UPDATE ai_generated_flyers SET published_offer_id = v_offer_id WHERE id = p_flyer_id;
  END IF;

  INSERT INTO ai_flyer_publish_log (flyer_id, view_offer_id, action)
  VALUES (p_flyer_id, v_offer_id, 'publish');

  RETURN v_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.publish_ai_flyer(
  uuid, bigint, text, date, time without time zone, date, time without time zone, text, text
) TO anon, authenticated;

-- 5. Unpublish -- pulls the offer immediately (Live Chat AI and the public pages both check
--    status), without deleting the view_offer row, so Publish again just flips it back live
--    with the same id/counters.
CREATE OR REPLACE FUNCTION public.unpublish_ai_flyer(p_flyer_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  SELECT published_offer_id INTO v_offer_id FROM ai_generated_flyers WHERE id = p_flyer_id;

  IF v_offer_id IS NOT NULL THEN
    UPDATE view_offer SET status = 'unpublished', updated_at = now() WHERE id = v_offer_id;

    INSERT INTO ai_flyer_publish_log (flyer_id, view_offer_id, action)
    VALUES (p_flyer_id, v_offer_id, 'unpublish');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unpublish_ai_flyer(uuid) TO anon, authenticated;

-- 6. Auto-expire -- flips a published offer to 'expired' once its end date+time has passed, and
--    logs it against the flyer that published it (if any). Scheduled below via pg_cron.
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
  SELECT f.id, e.id, 'auto_expire'
  FROM expired e
  JOIN ai_generated_flyers f ON f.published_offer_id = e.id;
END;
$$;

-- Run every minute. pg_cron is already enabled and already runs other jobs in this project;
-- this is the first one tracked in a migration rather than set up ad hoc.
SELECT cron.schedule('expire-view-offers', '* * * * *', $$SELECT public.expire_view_offers();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-view-offers');

-- 7. The WhatsApp Live Chat AI integration -- get_active_offers is the single function the
--    whatsapp-webhook edge function calls to decide which offer PDFs are "active" right now.
--    Adding the status check here is the entire integration; the edge function itself needs no
--    changes since it already just calls this RPC.
CREATE OR REPLACE FUNCTION public.get_active_offers(p_branch_id bigint DEFAULT NULL::bigint)
RETURNS TABLE(id uuid, offer_name character varying, offer_name_en character varying, offer_name_ar character varying, branch_id bigint, branch_name_en text, branch_name_ar text, location_en text, location_ar text, file_url text, start_date date, end_date date, start_time time without time zone, end_time time without time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT o.id,
         o.offer_name,
         o.offer_name_en,
         o.offer_name_ar,
         o.branch_id,
         b.name_en::text,
         b.name_ar::text,
         b.location_en::text,
         b.location_ar::text,
         o.file_url,
         o.start_date,
         o.end_date,
         o.start_time,
         o.end_time
  FROM view_offer o
  JOIN branches b ON b.id = o.branch_id
  WHERE (p_branch_id IS NULL OR o.branch_id = p_branch_id)
    AND (o.start_date + COALESCE(o.start_time, '00:00:00'::time))
          <= (timezone('Asia/Riyadh', now()))::timestamp
    AND (o.end_date + COALESCE(o.end_time, '23:59:00'::time))
          >= (timezone('Asia/Riyadh', now()))::timestamp
    AND COALESCE(o.file_url, '') <> ''
    AND o.status = 'published'
  ORDER BY b.location_en, o.created_at DESC;
$$;

COMMENT ON COLUMN public.view_offer.status IS 'published (live/scheduled), unpublished (manually pulled) or expired (auto-flipped by expire_view_offers via pg_cron). Every pre-existing and manually-added row defaults to published, matching prior behaviour.';
COMMENT ON COLUMN public.ai_generated_flyers.published_offer_id IS 'The view_offer row this flyer published, if any. NULL = never published.';
COMMENT ON TABLE public.ai_flyer_publish_log IS 'Audit trail of publish/unpublish/auto_expire actions against ai_generated_flyers, one row per action.';

COMMIT;

-- Outside the transaction (NOTIFY doesn't need one): make PostgREST pick up the new
-- ai_generated_flyers -> view_offer FK immediately, so AiFlyerGenerator.svelte's
-- `offer:view_offer(...)` embed works right away instead of waiting for the next auto-reload.
NOTIFY pgrst, 'reload schema';
