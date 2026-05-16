--
-- Name: quick_task_user_preferences; Type: TABLE; Schema: public;
--

CREATE TABLE public.quick_task_user_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    default_branch_id bigint,
    default_price_tag character varying(50),
    default_issue_type character varying(100),
    default_priority character varying(50),
    selected_user_ids uuid[],
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: quick_task_user_preferences quick_task_user_preferences_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_pkey PRIMARY KEY (id);


--
-- Name: quick_task_user_preferences quick_task_user_preferences_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_user_id_key UNIQUE (user_id);


--
-- Name: idx_quick_task_user_preferences_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_user_preferences_branch ON public.quick_task_user_preferences USING btree (default_branch_id);


--
-- Name: idx_quick_task_user_preferences_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_user_preferences_user ON public.quick_task_user_preferences USING btree (user_id);


--
-- Name: quick_task_user_preferences quick_task_user_preferences_default_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: quick_task_user_preferences quick_task_user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_task_user_preferences Allow anon insert quick_task_user_preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert quick_task_user_preferences" ON public.quick_task_user_preferences FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_user_preferences Users can delete their own preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can delete their own preferences" ON public.quick_task_user_preferences FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: quick_task_user_preferences Users can insert their own preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can insert their own preferences" ON public.quick_task_user_preferences FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: quick_task_user_preferences Users can update their own preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update their own preferences" ON public.quick_task_user_preferences FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: quick_task_user_preferences Users can view their own preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view their own preferences" ON public.quick_task_user_preferences FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: quick_task_user_preferences allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.quick_task_user_preferences USING (true) WITH CHECK (true);


--
-- Name: quick_task_user_preferences allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.quick_task_user_preferences FOR DELETE USING (true);


--
-- Name: quick_task_user_preferences allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.quick_task_user_preferences FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_user_preferences allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.quick_task_user_preferences FOR SELECT USING (true);


--
-- Name: quick_task_user_preferences allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.quick_task_user_preferences FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_user_preferences anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.quick_task_user_preferences USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_user_preferences authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.quick_task_user_preferences USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_user_preferences; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.quick_task_user_preferences ENABLE ROW LEVEL SECURITY;