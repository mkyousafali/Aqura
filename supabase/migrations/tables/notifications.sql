--
-- Name: notifications; Type: TABLE; Schema: public;
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    created_by character varying(255) DEFAULT 'system'::character varying NOT NULL,
    created_by_name character varying(100) DEFAULT 'System'::character varying NOT NULL,
    created_by_role character varying(50) DEFAULT 'Admin'::character varying NOT NULL,
    target_users jsonb,
    target_roles jsonb,
    target_branches jsonb,
    scheduled_for timestamp with time zone,
    sent_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    has_attachments boolean DEFAULT false NOT NULL,
    read_count integer DEFAULT 0 NOT NULL,
    total_recipients integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    metadata jsonb,
    task_id uuid,
    task_assignment_id uuid,
    priority character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    status character varying(20) DEFAULT 'published'::character varying NOT NULL,
    target_type character varying(50) DEFAULT 'all_users'::character varying NOT NULL,
    type character varying(50) DEFAULT 'info'::character varying NOT NULL
);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: idx_notifications_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at DESC);


--
-- Name: notifications trigger_create_notification_recipients; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_create_notification_recipients AFTER INSERT ON public.notifications FOR EACH ROW WHEN (((new.status)::text = 'published'::text)) EXECUTE FUNCTION public.create_notification_recipients();


--
-- Name: notifications notifications_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: notifications Allow anon insert notifications; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert notifications" ON public.notifications FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notifications Emergency: Allow all inserts for notifications; Type: POLICY; Schema: public;
--

CREATE POLICY "Emergency: Allow all inserts for notifications" ON public.notifications FOR INSERT WITH CHECK (true);


--
-- Name: notifications allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.notifications USING (true) WITH CHECK (true);


--
-- Name: notifications allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.notifications FOR DELETE USING (true);


--
-- Name: notifications allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.notifications FOR INSERT WITH CHECK (true);


--
-- Name: notifications allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.notifications FOR SELECT USING (true);


--
-- Name: notifications allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.notifications FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notifications anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.notifications USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notifications authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.notifications USING ((auth.uid() IS NOT NULL));


--
-- Name: notifications; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;