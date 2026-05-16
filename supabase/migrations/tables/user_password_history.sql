--
-- Name: user_password_history; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_password_history (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    password_hash character varying(255) NOT NULL,
    salt character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_password_history user_password_history_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_password_history
    ADD CONSTRAINT user_password_history_pkey PRIMARY KEY (id);


--
-- Name: idx_password_history_user_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_password_history_user_created ON public.user_password_history USING btree (user_id, created_at DESC);


--
-- Name: user_password_history user_password_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_password_history
    ADD CONSTRAINT user_password_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_password_history Allow anon insert user_password_history; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert user_password_history" ON public.user_password_history FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_password_history allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.user_password_history USING (true) WITH CHECK (true);


--
-- Name: user_password_history allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.user_password_history FOR DELETE USING (true);


--
-- Name: user_password_history allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.user_password_history FOR INSERT WITH CHECK (true);


--
-- Name: user_password_history allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.user_password_history FOR SELECT USING (true);


--
-- Name: user_password_history allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.user_password_history FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_password_history anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.user_password_history USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_password_history authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.user_password_history USING ((auth.uid() IS NOT NULL));


--
-- Name: user_password_history; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_password_history ENABLE ROW LEVEL SECURITY;