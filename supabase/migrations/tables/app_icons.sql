--
-- Name: app_icons; Type: TABLE; Schema: public;
--

CREATE TABLE public.app_icons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    icon_key text NOT NULL,
    category text DEFAULT 'general'::text NOT NULL,
    storage_path text NOT NULL,
    mime_type text,
    file_size bigint DEFAULT 0,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: app_icons app_icons_icon_key_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_icon_key_key UNIQUE (icon_key);


--
-- Name: app_icons app_icons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_pkey PRIMARY KEY (id);


--
-- Name: idx_app_icons_category; Type: INDEX; Schema: public;
--

CREATE INDEX idx_app_icons_category ON public.app_icons USING btree (category);


--
-- Name: idx_app_icons_key; Type: INDEX; Schema: public;
--

CREATE INDEX idx_app_icons_key ON public.app_icons USING btree (icon_key);


--
-- Name: app_icons trg_app_icons_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_app_icons_updated_at BEFORE UPDATE ON public.app_icons FOR EACH ROW EXECUTE FUNCTION public.update_app_icons_updated_at();


--
-- Name: app_icons app_icons_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: app_icons Anyone can view app icons; Type: POLICY; Schema: public;
--

CREATE POLICY "Anyone can view app icons" ON public.app_icons FOR SELECT USING (true);


--
-- Name: app_icons Authenticated users can delete app icons; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can delete app icons" ON public.app_icons FOR DELETE TO authenticated USING (true);


--
-- Name: app_icons Authenticated users can insert app icons; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can insert app icons" ON public.app_icons FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: app_icons Authenticated users can update app icons; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can update app icons" ON public.app_icons FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: app_icons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.app_icons ENABLE ROW LEVEL SECURITY;