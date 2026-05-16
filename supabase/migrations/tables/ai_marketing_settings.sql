--
-- Name: ai_marketing_settings; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_marketing_settings (
    id smallint DEFAULT 1 NOT NULL,
    google_api_key text,
    google_project_id text,
    google_location text DEFAULT 'europe-west4'::text,
    auto_retry boolean DEFAULT true,
    speed_mode_default text DEFAULT 'quality'::text,
    default_duration_seconds integer DEFAULT 15,
    default_platform text DEFAULT 'instagram'::text,
    default_language text DEFAULT 'ar'::text,
    base_instructions text DEFAULT ''::text,
    max_clarification_qs integer DEFAULT 10,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ai_marketing_settings_id_check CHECK ((id = 1)),
    CONSTRAINT ai_marketing_settings_speed_mode_default_check CHECK ((speed_mode_default = ANY (ARRAY['fast'::text, 'quality'::text])))
);


--
-- Name: ai_marketing_settings ai_marketing_settings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_settings
    ADD CONSTRAINT ai_marketing_settings_pkey PRIMARY KEY (id);


--
-- Name: ai_marketing_settings trg_ai_marketing_settings_touch; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_marketing_settings_touch BEFORE UPDATE ON public.ai_marketing_settings FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();


--
-- Name: ai_marketing_settings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_marketing_settings ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_marketing_settings allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_marketing_settings FOR DELETE USING (true);


--
-- Name: ai_marketing_settings allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_marketing_settings FOR INSERT WITH CHECK (true);


--
-- Name: ai_marketing_settings allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_marketing_settings FOR SELECT USING (true);


--
-- Name: ai_marketing_settings allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_marketing_settings FOR UPDATE USING (true) WITH CHECK (true);