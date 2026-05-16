--
-- Name: button_sub_sections; Type: TABLE; Schema: public;
--

CREATE TABLE public.button_sub_sections (
    id bigint NOT NULL,
    main_section_id bigint NOT NULL,
    subsection_name_en character varying(255) NOT NULL,
    subsection_name_ar character varying(255) NOT NULL,
    subsection_code character varying(50) NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: button_sub_sections button_sub_sections_main_section_id_subsection_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT button_sub_sections_main_section_id_subsection_code_key UNIQUE (main_section_id, subsection_code);


--
-- Name: button_sub_sections button_sub_sections_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT button_sub_sections_pkey PRIMARY KEY (id);


--
-- Name: idx_button_sub_sections_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_button_sub_sections_active ON public.button_sub_sections USING btree (is_active);


--
-- Name: idx_button_sub_sections_main; Type: INDEX; Schema: public;
--

CREATE INDEX idx_button_sub_sections_main ON public.button_sub_sections USING btree (main_section_id);


--
-- Name: button_sub_sections fk_main_section; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES public.button_main_sections(id) ON DELETE CASCADE;


--
-- Name: button_sub_sections allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.button_sub_sections FOR DELETE USING (true);


--
-- Name: button_sub_sections allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.button_sub_sections FOR INSERT WITH CHECK (true);


--
-- Name: button_sub_sections allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.button_sub_sections FOR SELECT USING (true);


--
-- Name: button_sub_sections allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.button_sub_sections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_sub_sections; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.button_sub_sections ENABLE ROW LEVEL SECURITY;