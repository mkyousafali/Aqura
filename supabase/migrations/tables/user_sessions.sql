--
-- Name: user_sessions; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    session_token character varying(255) NOT NULL,
    login_method character varying(20) NOT NULL,
    ip_address inet,
    user_agent text,
    is_active boolean DEFAULT true,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    CONSTRAINT user_sessions_login_method_check CHECK (((login_method)::text = ANY (ARRAY[('quick_access'::character varying)::text, ('username_password'::character varying)::text])))
);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_session_token_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_session_token_key UNIQUE (session_token);


--
-- Name: idx_user_sessions_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_sessions_active ON public.user_sessions USING btree (is_active);


--
-- Name: idx_user_sessions_token; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_sessions_token ON public.user_sessions USING btree (session_token);


--
-- Name: idx_user_sessions_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions Allow anon insert user_sessions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert user_sessions" ON public.user_sessions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_sessions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.user_sessions USING (true) WITH CHECK (true);


--
-- Name: user_sessions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.user_sessions FOR DELETE USING (true);


--
-- Name: user_sessions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.user_sessions FOR INSERT WITH CHECK (true);


--
-- Name: user_sessions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.user_sessions FOR SELECT USING (true);


--
-- Name: user_sessions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.user_sessions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_sessions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.user_sessions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_sessions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.user_sessions USING ((auth.uid() IS NOT NULL));


--
-- Name: user_sessions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;