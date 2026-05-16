--
-- Name: vip_campaign_settings; Type: TABLE; Schema: public;
--

CREATE TABLE public.vip_campaign_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    activated_by text,
    activated_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    instruction_poster_path text,
    instruction_poster_mime_type text,
    start_datetime timestamp with time zone,
    end_datetime timestamp with time zone
);


--
-- Name: vip_campaign_settings vip_campaign_settings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vip_campaign_settings
    ADD CONSTRAINT vip_campaign_settings_pkey PRIMARY KEY (id);


--
-- Name: vip_campaign_settings trg_vip_campaign_settings_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_vip_campaign_settings_updated_at BEFORE UPDATE ON public.vip_campaign_settings FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();


--
-- Name: vip_campaign_settings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.vip_campaign_settings ENABLE ROW LEVEL SECURITY;


--
-- Name: vip_campaign_settings vip_campaign_settings_delete; Type: POLICY; Schema: public;
--

CREATE POLICY vip_campaign_settings_delete ON public.vip_campaign_settings FOR DELETE TO authenticated, anon USING (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_insert; Type: POLICY; Schema: public;
--

CREATE POLICY vip_campaign_settings_insert ON public.vip_campaign_settings FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_select; Type: POLICY; Schema: public;
--

CREATE POLICY vip_campaign_settings_select ON public.vip_campaign_settings FOR SELECT TO authenticated, anon USING (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_update; Type: POLICY; Schema: public;
--

CREATE POLICY vip_campaign_settings_update ON public.vip_campaign_settings FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);