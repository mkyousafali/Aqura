--
-- Name: receiving_tasks; Type: TABLE; Schema: public;
--

CREATE TABLE public.receiving_tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receiving_record_id uuid NOT NULL,
    role_type character varying(50) NOT NULL,
    assigned_user_id uuid,
    requires_erp_reference boolean DEFAULT false,
    requires_original_bill_upload boolean DEFAULT false,
    requires_reassignment boolean DEFAULT false,
    requires_task_finished_mark boolean DEFAULT true,
    erp_reference_number character varying(255),
    original_bill_uploaded boolean DEFAULT false,
    original_bill_file_path text,
    task_completed boolean DEFAULT false,
    completed_at timestamp with time zone,
    clearance_certificate_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    template_id uuid,
    task_status character varying(50) DEFAULT 'pending'::character varying NOT NULL,
    title text,
    description text,
    priority character varying(20) DEFAULT 'high'::character varying,
    due_date timestamp with time zone,
    completed_by_user_id uuid,
    completion_photo_url text,
    completion_notes text,
    rule_effective_date timestamp with time zone,
    CONSTRAINT receiving_tasks_role_type_check CHECK (((role_type)::text = ANY (ARRAY[('branch_manager'::character varying)::text, ('purchase_manager'::character varying)::text, ('inventory_manager'::character varying)::text, ('night_supervisor'::character varying)::text, ('warehouse_handler'::character varying)::text, ('shelf_stocker'::character varying)::text, ('accountant'::character varying)::text]))),
    CONSTRAINT receiving_tasks_task_status_check CHECK (((task_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('in_progress'::character varying)::text, ('completed'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: receiving_tasks receiving_tasks_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_pkey PRIMARY KEY (id);


--
-- Name: idx_receiving_tasks_assigned_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_assigned_user_id ON public.receiving_tasks USING btree (assigned_user_id);


--
-- Name: idx_receiving_tasks_completion_photo_url; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_completion_photo_url ON public.receiving_tasks USING btree (completion_photo_url) WHERE (completion_photo_url IS NOT NULL);


--
-- Name: idx_receiving_tasks_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_created_at ON public.receiving_tasks USING btree (created_at DESC);


--
-- Name: idx_receiving_tasks_receiving_record_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_receiving_record_id ON public.receiving_tasks USING btree (receiving_record_id);


--
-- Name: idx_receiving_tasks_record_role; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_record_role ON public.receiving_tasks USING btree (receiving_record_id, role_type);


--
-- Name: idx_receiving_tasks_role_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_role_type ON public.receiving_tasks USING btree (role_type);


--
-- Name: idx_receiving_tasks_status_role; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_status_role ON public.receiving_tasks USING btree (task_status, role_type);


--
-- Name: idx_receiving_tasks_task_completed; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_task_completed ON public.receiving_tasks USING btree (task_completed);


--
-- Name: idx_receiving_tasks_task_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_task_status ON public.receiving_tasks USING btree (task_status);


--
-- Name: idx_receiving_tasks_template_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_template_id ON public.receiving_tasks USING btree (template_id);


--
-- Name: idx_receiving_tasks_user_role; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_user_role ON public.receiving_tasks USING btree (assigned_user_id, role_type);


--
-- Name: idx_receiving_tasks_user_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_receiving_tasks_user_status ON public.receiving_tasks USING btree (assigned_user_id, task_status);


--
-- Name: receiving_tasks trigger_update_receiving_tasks_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_receiving_tasks_updated_at BEFORE UPDATE ON public.receiving_tasks FOR EACH ROW EXECUTE FUNCTION public.update_receiving_tasks_updated_at();


--
-- Name: receiving_tasks receiving_tasks_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_tasks receiving_tasks_receiving_record_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_receiving_record_id_fkey FOREIGN KEY (receiving_record_id) REFERENCES public.receiving_records(id) ON DELETE CASCADE;


--
-- Name: receiving_tasks receiving_tasks_template_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.receiving_task_templates(id) ON DELETE SET NULL;


--
-- Name: receiving_tasks Allow anon insert receiving_tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert receiving_tasks" ON public.receiving_tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: receiving_tasks allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.receiving_tasks USING (true) WITH CHECK (true);


--
-- Name: receiving_tasks allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.receiving_tasks FOR DELETE USING (true);


--
-- Name: receiving_tasks allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.receiving_tasks FOR INSERT WITH CHECK (true);


--
-- Name: receiving_tasks allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.receiving_tasks FOR SELECT USING (true);


--
-- Name: receiving_tasks allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.receiving_tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: receiving_tasks anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.receiving_tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: receiving_tasks authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.receiving_tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: receiving_tasks; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.receiving_tasks ENABLE ROW LEVEL SECURITY;