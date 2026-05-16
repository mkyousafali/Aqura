--
-- Name: user_device_sessions; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_device_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id character varying(100) NOT NULL,
    session_token character varying(255) NOT NULL,
    device_type character varying(20) NOT NULL,
    browser_name character varying(50),
    user_agent text,
    ip_address inet,
    is_active boolean DEFAULT true,
    login_at timestamp with time zone DEFAULT now(),
    last_activity timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_device_sessions_device_type_check CHECK (((device_type)::text = ANY (ARRAY[('mobile'::character varying)::text, ('desktop'::character varying)::text])))
);


--
-- Name: user_device_sessions user_device_sessions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_device_sessions user_device_sessions_user_id_device_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_user_id_device_id_key UNIQUE (user_id, device_id);


--
-- Name: idx_user_device_sessions_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_device_sessions_active ON public.user_device_sessions USING btree (is_active);


--
-- Name: idx_user_device_sessions_device_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_device_sessions_device_id ON public.user_device_sessions USING btree (device_id);


--
-- Name: idx_user_device_sessions_expires_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_device_sessions_expires_at ON public.user_device_sessions USING btree (expires_at);


--
-- Name: idx_user_device_sessions_last_activity; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_device_sessions_last_activity ON public.user_device_sessions USING btree (last_activity);


--
-- Name: idx_user_device_sessions_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_device_sessions_user_id ON public.user_device_sessions USING btree (user_id);


--
-- Name: user_device_sessions trigger_user_device_sessions_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_user_device_sessions_updated_at BEFORE UPDATE ON public.user_device_sessions FOR EACH ROW EXECUTE FUNCTION public.update_user_device_sessions_updated_at();


--
-- Name: user_device_sessions user_device_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_device_sessions Admins can view all device sessions; Type: POLICY; Schema: public;
--

CREATE POLICY "Admins can view all device sessions" ON public.user_device_sessions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: user_device_sessions Allow anon insert user_device_sessions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert user_device_sessions" ON public.user_device_sessions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_device_sessions Users can manage their own device sessions; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can manage their own device sessions" ON public.user_device_sessions USING ((user_id = auth.uid()));


--
-- Name: user_device_sessions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.user_device_sessions USING (true) WITH CHECK (true);


--
-- Name: user_device_sessions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.user_device_sessions FOR DELETE USING (true);


--
-- Name: user_device_sessions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.user_device_sessions FOR INSERT WITH CHECK (true);


--
-- Name: user_device_sessions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.user_device_sessions FOR SELECT USING (true);


--
-- Name: user_device_sessions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.user_device_sessions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_device_sessions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.user_device_sessions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_device_sessions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.user_device_sessions USING ((auth.uid() IS NOT NULL));


--
-- Name: user_device_sessions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;