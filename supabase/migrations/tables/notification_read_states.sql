--
-- Name: notification_read_states; Type: TABLE; Schema: public;
--

CREATE TABLE public.notification_read_states (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    notification_id uuid NOT NULL,
    user_id text NOT NULL,
    read_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    is_read boolean DEFAULT false NOT NULL
);


--
-- Name: notification_read_states notification_read_states_notification_id_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_notification_id_user_id_key UNIQUE (notification_id, user_id);


--
-- Name: notification_read_states notification_read_states_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_pkey PRIMARY KEY (id);


--
-- Name: idx_notification_read_states_notification_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_notification_read_states_notification_id ON public.notification_read_states USING btree (notification_id);


--
-- Name: idx_notification_read_states_notification_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_notification_read_states_notification_user ON public.notification_read_states USING btree (notification_id, user_id);


--
-- Name: idx_notification_read_states_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_notification_read_states_user_id ON public.notification_read_states USING btree (user_id);


--
-- Name: notification_read_states notification_read_states_notification_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;


--
-- Name: notification_read_states Allow anon insert notification_read_states; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert notification_read_states" ON public.notification_read_states FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notification_read_states Users can insert own read states; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can insert own read states" ON public.notification_read_states FOR INSERT WITH CHECK (true);


--
-- Name: notification_read_states Users can update own read states; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update own read states" ON public.notification_read_states FOR UPDATE USING (true);


--
-- Name: notification_read_states Users can view own read states; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view own read states" ON public.notification_read_states FOR SELECT USING (true);


--
-- Name: notification_read_states allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.notification_read_states USING (true) WITH CHECK (true);


--
-- Name: notification_read_states allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.notification_read_states FOR DELETE USING (true);


--
-- Name: notification_read_states allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.notification_read_states FOR INSERT WITH CHECK (true);


--
-- Name: notification_read_states allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.notification_read_states FOR SELECT USING (true);


--
-- Name: notification_read_states allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.notification_read_states FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notification_read_states anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.notification_read_states USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notification_read_states authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.notification_read_states USING ((auth.uid() IS NOT NULL));


--
-- Name: notification_read_states; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;