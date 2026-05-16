--
-- Name: task_reminder_logs; Type: TABLE; Schema: public;
--

CREATE TABLE public.task_reminder_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_assignment_id uuid,
    quick_task_assignment_id uuid,
    task_title text NOT NULL,
    assigned_to_user_id uuid,
    deadline timestamp with time zone NOT NULL,
    hours_overdue numeric,
    reminder_sent_at timestamp with time zone DEFAULT now(),
    notification_id uuid,
    status text DEFAULT 'sent'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_single_assignment CHECK ((((task_assignment_id IS NOT NULL) AND (quick_task_assignment_id IS NULL)) OR ((task_assignment_id IS NULL) AND (quick_task_assignment_id IS NOT NULL))))
);


--
-- Name: task_reminder_logs task_reminder_logs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_task_reminder_logs_quick_task; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_reminder_logs_quick_task ON public.task_reminder_logs USING btree (quick_task_assignment_id) WHERE (quick_task_assignment_id IS NOT NULL);


--
-- Name: idx_task_reminder_logs_sent_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_reminder_logs_sent_at ON public.task_reminder_logs USING btree (reminder_sent_at);


--
-- Name: idx_task_reminder_logs_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_reminder_logs_status ON public.task_reminder_logs USING btree (status);


--
-- Name: idx_task_reminder_logs_task_assignment; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_reminder_logs_task_assignment ON public.task_reminder_logs USING btree (task_assignment_id) WHERE (task_assignment_id IS NOT NULL);


--
-- Name: idx_task_reminder_logs_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_reminder_logs_user ON public.task_reminder_logs USING btree (assigned_to_user_id);


--
-- Name: task_reminder_logs task_reminder_logs_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id);


--
-- Name: task_reminder_logs task_reminder_logs_notification_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id);


--
-- Name: task_reminder_logs task_reminder_logs_quick_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_quick_task_assignment_id_fkey FOREIGN KEY (quick_task_assignment_id) REFERENCES public.quick_task_assignments(id) ON DELETE CASCADE;


--
-- Name: task_reminder_logs task_reminder_logs_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: task_reminder_logs Allow anon insert task_reminder_logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert task_reminder_logs" ON public.task_reminder_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_reminder_logs Authenticated users can view all reminder logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can view all reminder logs" ON public.task_reminder_logs FOR SELECT USING ((auth.uid() IS NOT NULL));


--
-- Name: task_reminder_logs Service role can insert reminder logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role can insert reminder logs" ON public.task_reminder_logs FOR INSERT WITH CHECK (true);


--
-- Name: task_reminder_logs Users can view their own reminder logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view their own reminder logs" ON public.task_reminder_logs FOR SELECT USING ((assigned_to_user_id = auth.uid()));


--
-- Name: task_reminder_logs allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.task_reminder_logs USING (true) WITH CHECK (true);


--
-- Name: task_reminder_logs allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.task_reminder_logs FOR DELETE USING (true);


--
-- Name: task_reminder_logs allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.task_reminder_logs FOR INSERT WITH CHECK (true);


--
-- Name: task_reminder_logs allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.task_reminder_logs FOR SELECT USING (true);


--
-- Name: task_reminder_logs allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.task_reminder_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_reminder_logs anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.task_reminder_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_reminder_logs authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.task_reminder_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: task_reminder_logs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.task_reminder_logs ENABLE ROW LEVEL SECURITY;