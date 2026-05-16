--
-- Name: receiving_task_templates; Type: TABLE; Schema: public;
--

CREATE TABLE public.receiving_task_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    role_type character varying(50) NOT NULL,
    title_template text NOT NULL,
    description_template text NOT NULL,
    require_erp_reference boolean DEFAULT false NOT NULL,
    require_original_bill_upload boolean DEFAULT false NOT NULL,
    require_task_finished_mark boolean DEFAULT true NOT NULL,
    priority character varying(20) DEFAULT 'high'::character varying NOT NULL,
    deadline_hours integer DEFAULT 24 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    depends_on_role_types text[] DEFAULT '{}'::text[],
    require_photo_upload boolean DEFAULT false,
    CONSTRAINT receiving_task_templates_deadline_hours_check CHECK (((deadline_hours > 0) AND (deadline_hours <= 168))),
    CONSTRAINT receiving_task_templates_priority_check CHECK (((priority)::text = ANY (ARRAY[('low'::character varying)::text, ('medium'::character varying)::text, ('high'::character varying)::text, ('urgent'::character varying)::text]))),
    CONSTRAINT receiving_task_templates_role_type_check CHECK (((role_type)::text = ANY (ARRAY[('branch_manager'::character varying)::text, ('purchase_manager'::character varying)::text, ('inventory_manager'::character varying)::text, ('night_supervisor'::character varying)::text, ('warehouse_handler'::character varying)::text, ('shelf_stocker'::character varying)::text, ('accountant'::character varying)::text])))
);


--
-- Name: receiving_task_templates receiving_task_templates_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_task_templates
    ADD CONSTRAINT receiving_task_templates_pkey PRIMARY KEY (id);


--
-- Name: receiving_task_templates receiving_task_templates_role_type_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_task_templates
    ADD CONSTRAINT receiving_task_templates_role_type_unique UNIQUE (role_type);


--
-- Name: idx_receiving_task_templates_priority; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_task_templates_priority ON public.receiving_task_templates USING btree (priority);


--
-- Name: idx_receiving_task_templates_role_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_task_templates_role_type ON public.receiving_task_templates USING btree (role_type);


--
-- Name: receiving_task_templates trigger_update_receiving_task_templates_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_receiving_task_templates_updated_at BEFORE UPDATE ON public.receiving_task_templates FOR EACH ROW EXECUTE FUNCTION public.update_receiving_task_templates_updated_at();


--
-- Name: receiving_task_templates Allow anon insert receiving_task_templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert receiving_task_templates" ON public.receiving_task_templates FOR INSERT TO anon WITH CHECK (true);


--
-- Name: receiving_task_templates allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.receiving_task_templates USING (true) WITH CHECK (true);


--
-- Name: receiving_task_templates allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.receiving_task_templates FOR DELETE USING (true);


--
-- Name: receiving_task_templates allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.receiving_task_templates FOR INSERT WITH CHECK (true);


--
-- Name: receiving_task_templates allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.receiving_task_templates FOR SELECT USING (true);


--
-- Name: receiving_task_templates allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.receiving_task_templates FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: receiving_task_templates anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.receiving_task_templates USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: receiving_task_templates authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.receiving_task_templates USING ((auth.uid() IS NOT NULL));


--
-- Name: receiving_task_templates; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.receiving_task_templates ENABLE ROW LEVEL SECURITY;