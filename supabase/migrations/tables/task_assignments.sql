--
-- Name: task_assignments; Type: TABLE; Schema: public;
--

CREATE TABLE public.task_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    assignment_type text NOT NULL,
    assigned_to_user_id uuid,
    assigned_to_branch_id bigint,
    assigned_by uuid NOT NULL,
    assigned_by_name text,
    assigned_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'assigned'::text,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    schedule_date date,
    schedule_time time without time zone,
    deadline_date date,
    deadline_time time without time zone,
    deadline_datetime timestamp with time zone,
    is_reassignable boolean DEFAULT true,
    is_recurring boolean DEFAULT false,
    recurring_pattern jsonb,
    notes text,
    priority_override text,
    require_task_finished boolean DEFAULT true,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false,
    reassigned_from uuid,
    reassignment_reason text,
    reassigned_at timestamp with time zone,
    CONSTRAINT chk_deadline_consistency CHECK ((((deadline_date IS NULL) AND (deadline_time IS NULL)) OR (deadline_date IS NOT NULL))),
    CONSTRAINT chk_priority_override_valid CHECK (((priority_override IS NULL) OR (priority_override = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text])))),
    CONSTRAINT chk_schedule_consistency CHECK ((((schedule_date IS NULL) AND (schedule_time IS NULL)) OR (schedule_date IS NOT NULL)))
);


--
-- Name: task_assignments task_assignments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (id);


--
-- Name: task_assignments task_assignments_task_id_assignment_type_assigned_to_user_i_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key UNIQUE (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id);


--
-- Name: idx_task_assignments_assigned_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_assigned_by ON public.task_assignments USING btree (assigned_by);


--
-- Name: idx_task_assignments_assigned_to_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_assigned_to_branch_id ON public.task_assignments USING btree (assigned_to_branch_id);


--
-- Name: idx_task_assignments_assigned_to_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_assigned_to_user_id ON public.task_assignments USING btree (assigned_to_user_id);


--
-- Name: idx_task_assignments_assignment_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_assignment_type ON public.task_assignments USING btree (assignment_type);


--
-- Name: idx_task_assignments_deadline_datetime; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_deadline_datetime ON public.task_assignments USING btree (deadline_datetime) WHERE (deadline_datetime IS NOT NULL);


--
-- Name: idx_task_assignments_overdue; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_overdue ON public.task_assignments USING btree (deadline_datetime, status) WHERE ((deadline_datetime IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])));


--
-- Name: idx_task_assignments_reassignable; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_reassignable ON public.task_assignments USING btree (is_reassignable, status) WHERE (is_reassignable = true);


--
-- Name: idx_task_assignments_recurring; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_recurring ON public.task_assignments USING btree (is_recurring, status) WHERE (is_recurring = true);


--
-- Name: idx_task_assignments_schedule_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_schedule_date ON public.task_assignments USING btree (schedule_date) WHERE (schedule_date IS NOT NULL);


--
-- Name: idx_task_assignments_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_status ON public.task_assignments USING btree (status);


--
-- Name: idx_task_assignments_task_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_assignments_task_id ON public.task_assignments USING btree (task_id);


--
-- Name: task_assignments cleanup_assignment_notifications_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER cleanup_assignment_notifications_trigger AFTER DELETE ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.trigger_cleanup_assignment_notifications();


--
-- Name: task_assignments trigger_update_deadline_datetime; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_deadline_datetime BEFORE INSERT OR UPDATE OF deadline_date, deadline_time ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.update_deadline_datetime();


--
-- Name: task_assignments fk_task_assignments_reassigned_from; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_task_assignments_reassigned_from FOREIGN KEY (reassigned_from) REFERENCES public.task_assignments(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_assigned_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_to_branch_id_fkey FOREIGN KEY (assigned_to_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_assignments Allow anon insert task_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert task_assignments" ON public.task_assignments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_assignments Allow service role full access to task_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role full access to task_assignments" ON public.task_assignments TO authenticated USING (true) WITH CHECK (true);


--
-- Name: task_assignments Emergency: Allow all inserts for task_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Emergency: Allow all inserts for task_assignments" ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: task_assignments Simple create task assignments policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple create task assignments policy" ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: task_assignments Simple update task assignments policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple update task assignments policy" ON public.task_assignments FOR UPDATE USING (true);


--
-- Name: task_assignments Simple view task assignments policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple view task assignments policy" ON public.task_assignments FOR SELECT USING (true);


--
-- Name: task_assignments allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.task_assignments USING (true) WITH CHECK (true);


--
-- Name: task_assignments allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.task_assignments FOR DELETE USING (true);


--
-- Name: task_assignments allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: task_assignments allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.task_assignments FOR SELECT USING (true);


--
-- Name: task_assignments allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.task_assignments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_assignments anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.task_assignments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_assignments authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.task_assignments USING ((auth.uid() IS NOT NULL));


--
-- Name: task_assignments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;