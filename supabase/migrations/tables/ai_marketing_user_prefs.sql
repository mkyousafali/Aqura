--
-- Name: ai_marketing_user_prefs; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_marketing_user_prefs (
    user_id uuid NOT NULL,
    default_brand_id bigint,
    favorite_brand_ids bigint[] DEFAULT '{}'::bigint[],
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_marketing_user_prefs ai_marketing_user_prefs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_user_prefs
    ADD CONSTRAINT ai_marketing_user_prefs_pkey PRIMARY KEY (user_id);


--
-- Name: ai_marketing_user_prefs trg_ai_marketing_user_prefs_touch; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_marketing_user_prefs_touch BEFORE UPDATE ON public.ai_marketing_user_prefs FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();


--
-- Name: ai_marketing_user_prefs ai_marketing_user_prefs_default_brand_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_user_prefs
    ADD CONSTRAINT ai_marketing_user_prefs_default_brand_id_fkey FOREIGN KEY (default_brand_id) REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL;


--
-- Name: ai_marketing_user_prefs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_marketing_user_prefs ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_marketing_user_prefs allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_marketing_user_prefs FOR DELETE USING (true);


--
-- Name: ai_marketing_user_prefs allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_marketing_user_prefs FOR INSERT WITH CHECK (true);


--
-- Name: ai_marketing_user_prefs allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_marketing_user_prefs FOR SELECT USING (true);


--
-- Name: ai_marketing_user_prefs allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_marketing_user_prefs FOR UPDATE USING (true) WITH CHECK (true);