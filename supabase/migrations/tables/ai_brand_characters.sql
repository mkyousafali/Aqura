--
-- Name: ai_brand_characters; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_brand_characters (
    id bigint NOT NULL,
    brand_id bigint NOT NULL,
    name text NOT NULL,
    role text,
    image_url text,
    description text,
    voice_id text,
    display_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    ai_prompt text
);


--
-- Name: ai_brand_characters ai_brand_characters_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_brand_characters
    ADD CONSTRAINT ai_brand_characters_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_brand_characters_brand; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_brand_characters_brand ON public.ai_brand_characters USING btree (brand_id);


--
-- Name: ai_brand_characters ai_brand_characters_brand_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_brand_characters
    ADD CONSTRAINT ai_brand_characters_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.ai_brand_libraries(id) ON DELETE CASCADE;


--
-- Name: ai_brand_characters; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_brand_characters ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_brand_characters allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_brand_characters FOR DELETE USING (true);


--
-- Name: ai_brand_characters allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_brand_characters FOR INSERT WITH CHECK (true);


--
-- Name: ai_brand_characters allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_brand_characters FOR SELECT USING (true);


--
-- Name: ai_brand_characters allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_brand_characters FOR UPDATE USING (true) WITH CHECK (true);