-- Allow deleting a saved AI-generated flyer from the library (Preview → Delete button in
-- AiFlyerGenerator.svelte). The original migration deliberately only granted SELECT/INSERT
-- ("existing saved records cannot be edited/deleted") — this adds DELETE on the same terms as the
-- existing read/insert policies (anon/authenticated, same as every other flyer module in this app).
-- The existing ai_flyer_page_cleanup storage policy already permits removing a page file once no
-- ai_generated_flyers row references it, so deleting the row first (then the page files) is the
-- correct order — the app does this in deleteFlyer() in AiFlyerGenerator.svelte.
BEGIN;
GRANT DELETE ON public.ai_generated_flyers TO anon, authenticated;
DROP POLICY IF EXISTS ai_flyer_delete ON public.ai_generated_flyers;
CREATE POLICY ai_flyer_delete ON public.ai_generated_flyers FOR DELETE TO anon, authenticated USING (true);
COMMIT;
