--
-- Name: user_audit_logs; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_audit_logs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    target_user_id uuid,
    action character varying(100) NOT NULL,
    table_name character varying(100),
    record_id uuid,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    performed_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_audit_logs user_audit_logs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_user_audit_logs_action; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_audit_logs_action ON public.user_audit_logs USING btree (action);


--
-- Name: idx_user_audit_logs_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_audit_logs_created_at ON public.user_audit_logs USING btree (created_at);


--
-- Name: idx_user_audit_logs_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_audit_logs_user_id ON public.user_audit_logs USING btree (user_id);


--
-- Name: user_audit_logs user_audit_logs_performed_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.users(id);


--
-- Name: user_audit_logs user_audit_logs_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_audit_logs user_audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_audit_logs Allow anon insert user_audit_logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert user_audit_logs" ON public.user_audit_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_audit_logs allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.user_audit_logs USING (true) WITH CHECK (true);


--
-- Name: user_audit_logs allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.user_audit_logs FOR DELETE USING (true);


--
-- Name: user_audit_logs allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.user_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: user_audit_logs allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.user_audit_logs FOR SELECT USING (true);


--
-- Name: user_audit_logs allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.user_audit_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_audit_logs anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.user_audit_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_audit_logs authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.user_audit_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: user_audit_logs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;