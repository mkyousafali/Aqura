--
-- Name: ai_brand_libraries; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_brand_libraries (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    logo_url text,
    primary_color text,
    secondary_color text,
    accent_color text,
    extra_colors jsonb DEFAULT '[]'::jsonb,
    brand_tone text,
    marketing_style text,
    rules jsonb DEFAULT '{}'::jsonb,
    is_default boolean DEFAULT false,
    is_archived boolean DEFAULT false,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_brand_libraries ai_brand_libraries_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_brand_libraries
    ADD CONSTRAINT ai_brand_libraries_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_brand_libraries_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_brand_libraries_active ON public.ai_brand_libraries USING btree (is_archived);


--
-- Name: idx_ai_brand_libraries_default; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_brand_libraries_default ON public.ai_brand_libraries USING btree (is_default) WHERE (is_default = true);


--
-- Name: ai_brand_libraries trg_ai_brand_libraries_touch; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_brand_libraries_touch BEFORE UPDATE ON public.ai_brand_libraries FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();


--
-- Name: ai_brand_libraries trg_ai_brand_single_default; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_brand_single_default BEFORE INSERT OR UPDATE OF is_default ON public.ai_brand_libraries FOR EACH ROW WHEN ((new.is_default = true)) EXECUTE FUNCTION public._ai_brand_enforce_single_default();


--
-- Name: ai_brand_libraries; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_brand_libraries ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_brand_libraries allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_brand_libraries FOR DELETE USING (true);


--
-- Name: ai_brand_libraries allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_brand_libraries FOR INSERT WITH CHECK (true);


--
-- Name: ai_brand_libraries allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_brand_libraries FOR SELECT USING (true);


--
-- Name: ai_brand_libraries allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_brand_libraries FOR UPDATE USING (true) WITH CHECK (true);