--
-- Name: sidebar_buttons; Type: TABLE; Schema: public;
--

CREATE TABLE public.sidebar_buttons (
    id bigint NOT NULL,
    main_section_id bigint NOT NULL,
    subsection_id bigint NOT NULL,
    button_name_en character varying(255) NOT NULL,
    button_name_ar character varying(255) NOT NULL,
    button_code character varying(100) NOT NULL,
    icon character varying(50),
    display_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: sidebar_buttons sidebar_buttons_main_section_id_subsection_id_button_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT sidebar_buttons_main_section_id_subsection_id_button_code_key UNIQUE (main_section_id, subsection_id, button_code);


--
-- Name: sidebar_buttons sidebar_buttons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT sidebar_buttons_pkey PRIMARY KEY (id);


--
-- Name: idx_sidebar_buttons_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_sidebar_buttons_active ON public.sidebar_buttons USING btree (is_active);


--
-- Name: idx_sidebar_buttons_main; Type: INDEX; Schema: public;
--

CREATE INDEX idx_sidebar_buttons_main ON public.sidebar_buttons USING btree (main_section_id);


--
-- Name: idx_sidebar_buttons_sub; Type: INDEX; Schema: public;
--

CREATE INDEX idx_sidebar_buttons_sub ON public.sidebar_buttons USING btree (subsection_id);


--
-- Name: sidebar_buttons fk_main_section; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES public.button_main_sections(id) ON DELETE CASCADE;


--
-- Name: sidebar_buttons fk_sub_section; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT fk_sub_section FOREIGN KEY (subsection_id) REFERENCES public.button_sub_sections(id) ON DELETE CASCADE;


--
-- Name: sidebar_buttons allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.sidebar_buttons FOR DELETE USING (true);


--
-- Name: sidebar_buttons allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.sidebar_buttons FOR INSERT WITH CHECK (true);


--
-- Name: sidebar_buttons allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.sidebar_buttons FOR SELECT USING (true);


--
-- Name: sidebar_buttons allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.sidebar_buttons FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: sidebar_buttons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.sidebar_buttons ENABLE ROW LEVEL SECURITY;