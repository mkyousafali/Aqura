--
-- Name: shelf_paper_templates; Type: TABLE; Schema: public;
--

CREATE TABLE public.shelf_paper_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    template_image_url text NOT NULL,
    field_configuration jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb
);


--
-- Name: shelf_paper_templates shelf_paper_templates_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.shelf_paper_templates
    ADD CONSTRAINT shelf_paper_templates_pkey PRIMARY KEY (id);


--
-- Name: idx_shelf_paper_templates_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_shelf_paper_templates_created_at ON public.shelf_paper_templates USING btree (created_at DESC);


--
-- Name: idx_shelf_paper_templates_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_shelf_paper_templates_created_by ON public.shelf_paper_templates USING btree (created_by);


--
-- Name: idx_shelf_paper_templates_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_shelf_paper_templates_is_active ON public.shelf_paper_templates USING btree (is_active);


--
-- Name: shelf_paper_templates update_shelf_paper_templates_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_shelf_paper_templates_updated_at BEFORE UPDATE ON public.shelf_paper_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: shelf_paper_templates shelf_paper_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.shelf_paper_templates
    ADD CONSTRAINT shelf_paper_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: shelf_paper_templates Allow anon insert shelf_paper_templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert shelf_paper_templates" ON public.shelf_paper_templates FOR INSERT TO anon WITH CHECK (true);


--
-- Name: shelf_paper_templates Users can create templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can create templates" ON public.shelf_paper_templates FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: shelf_paper_templates Users can delete own templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can delete own templates" ON public.shelf_paper_templates FOR DELETE USING ((created_by = auth.uid()));


--
-- Name: shelf_paper_templates Users can update own templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update own templates" ON public.shelf_paper_templates FOR UPDATE USING ((created_by = auth.uid()));


--
-- Name: shelf_paper_templates Users can view active templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view active templates" ON public.shelf_paper_templates FOR SELECT USING ((is_active = true));


--
-- Name: shelf_paper_templates allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.shelf_paper_templates USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_templates allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.shelf_paper_templates FOR DELETE USING (true);


--
-- Name: shelf_paper_templates allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.shelf_paper_templates FOR INSERT WITH CHECK (true);


--
-- Name: shelf_paper_templates allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.shelf_paper_templates FOR SELECT USING (true);


--
-- Name: shelf_paper_templates allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.shelf_paper_templates FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_templates anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.shelf_paper_templates USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: shelf_paper_templates authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.shelf_paper_templates USING ((auth.uid() IS NOT NULL));


--
-- Name: shelf_paper_templates; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.shelf_paper_templates ENABLE ROW LEVEL SECURITY;