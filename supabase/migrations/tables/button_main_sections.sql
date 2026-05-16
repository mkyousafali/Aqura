--
-- Name: button_main_sections; Type: TABLE; Schema: public;
--

CREATE TABLE public.button_main_sections (
    id bigint NOT NULL,
    section_name_en character varying(255) NOT NULL,
    section_name_ar character varying(255) NOT NULL,
    section_code character varying(50) NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: button_main_sections button_main_sections_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_main_sections
    ADD CONSTRAINT button_main_sections_pkey PRIMARY KEY (id);


--
-- Name: button_main_sections button_main_sections_section_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_main_sections
    ADD CONSTRAINT button_main_sections_section_code_key UNIQUE (section_code);


--
-- Name: idx_button_main_sections_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_button_main_sections_active ON public.button_main_sections USING btree (is_active);


--
-- Name: button_main_sections allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.button_main_sections FOR DELETE USING (true);


--
-- Name: button_main_sections allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.button_main_sections FOR INSERT WITH CHECK (true);


--
-- Name: button_main_sections allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.button_main_sections FOR SELECT USING (true);


--
-- Name: button_main_sections allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.button_main_sections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_main_sections; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.button_main_sections ENABLE ROW LEVEL SECURITY;