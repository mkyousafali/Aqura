--
-- Name: tasks; Type: TABLE; Schema: public;
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    require_task_finished boolean DEFAULT false,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false,
    can_escalate boolean DEFAULT false,
    can_reassign boolean DEFAULT false,
    created_by text NOT NULL,
    created_by_name text,
    created_by_role text,
    status text DEFAULT 'draft'::text,
    priority text DEFAULT 'medium'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    due_date date,
    due_time time without time zone,
    due_datetime timestamp with time zone,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((title || ' '::text) || COALESCE(description, ''::text)))) STORED,
    metadata jsonb,
    CONSTRAINT tasks_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])))
);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: idx_tasks_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_created_at ON public.tasks USING btree (created_at DESC);


--
-- Name: idx_tasks_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_created_by ON public.tasks USING btree (created_by);


--
-- Name: idx_tasks_deleted_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_deleted_at ON public.tasks USING btree (deleted_at);


--
-- Name: idx_tasks_due_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_due_date ON public.tasks USING btree (due_date) WHERE (due_date IS NOT NULL);


--
-- Name: idx_tasks_metadata; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_metadata ON public.tasks USING gin (metadata);


--
-- Name: idx_tasks_search_vector; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_search_vector ON public.tasks USING gin (search_vector);


--
-- Name: idx_tasks_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);


--
-- Name: tasks cleanup_task_notifications_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER cleanup_task_notifications_trigger AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.trigger_cleanup_task_notifications();


--
-- Name: tasks Allow anon insert tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert tasks" ON public.tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: tasks Allow service role full access to tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role full access to tasks" ON public.tasks TO authenticated USING (true) WITH CHECK (true);


--
-- Name: tasks Emergency: Allow all inserts for tasks; Type: POLICY; Schema: public;
--

CREATE POLICY "Emergency: Allow all inserts for tasks" ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: tasks Simple create tasks policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple create tasks policy" ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: tasks Simple update tasks policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple update tasks policy" ON public.tasks FOR UPDATE USING (true);


--
-- Name: tasks Simple view tasks policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple view tasks policy" ON public.tasks FOR SELECT USING ((deleted_at IS NULL));


--
-- Name: tasks allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.tasks USING (true) WITH CHECK (true);


--
-- Name: tasks allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.tasks FOR DELETE USING (true);


--
-- Name: tasks allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: tasks allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.tasks FOR SELECT USING (true);


--
-- Name: tasks allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: tasks anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: tasks authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: tasks; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;