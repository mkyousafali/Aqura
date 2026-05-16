--
-- Name: quick_tasks; Type: TABLE; Schema: public;
--

CREATE TABLE public.quick_tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    price_tag character varying(50),
    issue_type character varying(100) NOT NULL,
    priority character varying(50) NOT NULL,
    assigned_by uuid NOT NULL,
    assigned_to_branch_id bigint,
    created_at timestamp with time zone DEFAULT now(),
    deadline_datetime timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    completed_at timestamp with time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    created_from character varying(50) DEFAULT 'quick_task'::character varying,
    updated_at timestamp with time zone DEFAULT now(),
    require_task_finished boolean DEFAULT true,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false,
    incident_id text,
    product_request_id uuid,
    product_request_type character varying(5),
    order_id uuid,
    CONSTRAINT chk_require_task_finished_not_null CHECK ((require_task_finished IS NOT NULL))
);


--
-- Name: quick_tasks quick_tasks_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_pkey PRIMARY KEY (id);


--
-- Name: idx_quick_tasks_assigned_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_assigned_by ON public.quick_tasks USING btree (assigned_by);


--
-- Name: idx_quick_tasks_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_branch ON public.quick_tasks USING btree (assigned_to_branch_id);


--
-- Name: idx_quick_tasks_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_created_at ON public.quick_tasks USING btree (created_at);


--
-- Name: idx_quick_tasks_deadline; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_deadline ON public.quick_tasks USING btree (deadline_datetime);


--
-- Name: idx_quick_tasks_incident_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_incident_id ON public.quick_tasks USING btree (incident_id);


--
-- Name: idx_quick_tasks_issue_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_issue_type ON public.quick_tasks USING btree (issue_type);


--
-- Name: idx_quick_tasks_order_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_order_id ON public.quick_tasks USING btree (order_id);


--
-- Name: idx_quick_tasks_priority; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_priority ON public.quick_tasks USING btree (priority);


--
-- Name: idx_quick_tasks_product_request_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_product_request_id ON public.quick_tasks USING btree (product_request_id);


--
-- Name: idx_quick_tasks_product_request_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_product_request_type ON public.quick_tasks USING btree (product_request_type);


--
-- Name: idx_quick_tasks_require_erp_reference; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_require_erp_reference ON public.quick_tasks USING btree (require_erp_reference) WHERE (require_erp_reference = true);


--
-- Name: idx_quick_tasks_require_photo_upload; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_require_photo_upload ON public.quick_tasks USING btree (require_photo_upload) WHERE (require_photo_upload = true);


--
-- Name: idx_quick_tasks_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_tasks_status ON public.quick_tasks USING btree (status);


--
-- Name: quick_tasks quick_tasks_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_tasks quick_tasks_assigned_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_assigned_to_branch_id_fkey FOREIGN KEY (assigned_to_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: quick_tasks quick_tasks_incident_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id);


--
-- Name: quick_tasks quick_tasks_order_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;


--
-- Name: quick_tasks Allow anon insert quick_tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert quick_tasks" ON public.quick_tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_tasks Allow service role full access to quick_tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role full access to quick_tasks" ON public.quick_tasks TO authenticated USING (true) WITH CHECK (true);


--
-- Name: quick_tasks allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.quick_tasks USING (true) WITH CHECK (true);


--
-- Name: quick_tasks allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.quick_tasks FOR DELETE USING (true);


--
-- Name: quick_tasks allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.quick_tasks FOR INSERT WITH CHECK (true);


--
-- Name: quick_tasks allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.quick_tasks FOR SELECT USING (true);


--
-- Name: quick_tasks allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.quick_tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_tasks anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.quick_tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_tasks authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.quick_tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_tasks; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.quick_tasks ENABLE ROW LEVEL SECURITY;