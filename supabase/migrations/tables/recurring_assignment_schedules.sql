--
-- Name: recurring_assignment_schedules; Type: TABLE; Schema: public;
--

CREATE TABLE public.recurring_assignment_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    assignment_id uuid NOT NULL,
    repeat_type text NOT NULL,
    repeat_interval integer DEFAULT 1 NOT NULL,
    repeat_on_days integer[],
    repeat_on_date integer,
    repeat_on_month integer,
    execute_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    timezone text DEFAULT 'UTC'::text,
    start_date date NOT NULL,
    end_date date,
    max_occurrences integer,
    is_active boolean DEFAULT true,
    last_executed_at timestamp with time zone,
    next_execution_at timestamp with time zone NOT NULL,
    executions_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by text NOT NULL,
    CONSTRAINT chk_max_occurrences_positive CHECK (((max_occurrences IS NULL) OR (max_occurrences > 0))),
    CONSTRAINT chk_next_execution_after_start CHECK (((next_execution_at)::date >= start_date)),
    CONSTRAINT chk_repeat_interval_positive CHECK ((repeat_interval > 0)),
    CONSTRAINT chk_schedule_bounds CHECK (((end_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT recurring_assignment_schedules_repeat_type_check CHECK ((repeat_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text, 'custom'::text])))
);


--
-- Name: recurring_assignment_schedules recurring_assignment_schedules_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.recurring_assignment_schedules
    ADD CONSTRAINT recurring_assignment_schedules_pkey PRIMARY KEY (id);


--
-- Name: idx_recurring_schedules_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_recurring_schedules_active ON public.recurring_assignment_schedules USING btree (is_active, repeat_type);


--
-- Name: idx_recurring_schedules_assignment_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_recurring_schedules_assignment_id ON public.recurring_assignment_schedules USING btree (assignment_id);


--
-- Name: idx_recurring_schedules_next_execution; Type: INDEX; Schema: public;
--

CREATE INDEX idx_recurring_schedules_next_execution ON public.recurring_assignment_schedules USING btree (next_execution_at, is_active) WHERE (is_active = true);


--
-- Name: recurring_assignment_schedules fk_recurring_schedules_assignment; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.recurring_assignment_schedules
    ADD CONSTRAINT fk_recurring_schedules_assignment FOREIGN KEY (assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: recurring_assignment_schedules Allow anon insert recurring_assignment_schedules; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert recurring_assignment_schedules" ON public.recurring_assignment_schedules FOR INSERT TO anon WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.recurring_assignment_schedules USING (true) WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.recurring_assignment_schedules FOR DELETE USING (true);


--
-- Name: recurring_assignment_schedules allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.recurring_assignment_schedules FOR INSERT WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.recurring_assignment_schedules FOR SELECT USING (true);


--
-- Name: recurring_assignment_schedules allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.recurring_assignment_schedules FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: recurring_assignment_schedules anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.recurring_assignment_schedules USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: recurring_assignment_schedules authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.recurring_assignment_schedules USING ((auth.uid() IS NOT NULL));


--
-- Name: recurring_assignment_schedules; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;