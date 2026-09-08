-- Independent completed-flyer library. Does not modify offers, products or manual templates.
BEGIN;
CREATE TABLE IF NOT EXISTS public.ai_generated_flyers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id uuid REFERENCES public.flyer_offers(id) ON DELETE SET NULL,
  title text NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  start_date date NOT NULL,
  end_date date NOT NULL CHECK (end_date >= start_date),
  page_count integer NOT NULL CHECK (page_count > 0),
  product_count integer NOT NULL CHECK (product_count > 0),
  page_paths text[] NOT NULL,
  snapshot jsonb NOT NULL,
  model text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (cardinality(page_paths) = page_count)
);
CREATE INDEX IF NOT EXISTS ai_generated_flyers_created_at_idx ON public.ai_generated_flyers(created_at DESC);
ALTER TABLE public.ai_generated_flyers ENABLE ROW LEVEL SECURITY;
-- This ERP uses its own login with the anon database role, as do the existing flyer modules.
-- Permit library reads and additions only; existing saved records cannot be edited/deleted.
GRANT SELECT, INSERT ON public.ai_generated_flyers TO anon, authenticated;
GRANT ALL ON public.ai_generated_flyers TO service_role;
DROP POLICY IF EXISTS ai_flyer_read ON public.ai_generated_flyers;
CREATE POLICY ai_flyer_read ON public.ai_generated_flyers FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS ai_flyer_insert ON public.ai_generated_flyers;
CREATE POLICY ai_flyer_insert ON public.ai_generated_flyers FOR INSERT TO anon, authenticated WITH CHECK (true);

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('ai-generated-flyers','ai-generated-flyers',false,20971520,ARRAY['image/png'])
ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS ai_flyer_page_read ON storage.objects;
CREATE POLICY ai_flyer_page_read ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id = 'ai-generated-flyers');
DROP POLICY IF EXISTS ai_flyer_page_insert ON storage.objects;
CREATE POLICY ai_flyer_page_insert ON storage.objects FOR INSERT TO anon, authenticated
WITH CHECK (bucket_id = 'ai-generated-flyers');
DROP POLICY IF EXISTS ai_flyer_page_cleanup ON storage.objects;
CREATE POLICY ai_flyer_page_cleanup ON storage.objects FOR DELETE TO anon, authenticated
USING (bucket_id = 'ai-generated-flyers' AND NOT EXISTS (
  SELECT 1 FROM public.ai_generated_flyers f WHERE storage.objects.name = ANY(f.page_paths)
));
COMMENT ON TABLE public.ai_generated_flyers IS 'Saved AI-designed flyers with immutable source snapshots and ordered PNG page files in the dedicated ai-generated-flyers bucket.';
COMMIT;
