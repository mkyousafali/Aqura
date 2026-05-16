--
-- Name: default_incident_users; Type: TABLE; Schema: public;
--

CREATE TABLE public.default_incident_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    incident_type_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: default_incident_users default_incident_users_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_pkey PRIMARY KEY (id);


--
-- Name: default_incident_users default_incident_users_user_id_incident_type_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_user_id_incident_type_id_key UNIQUE (user_id, incident_type_id);


--
-- Name: idx_default_incident_users_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_default_incident_users_type ON public.default_incident_users USING btree (incident_type_id);


--
-- Name: idx_default_incident_users_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_default_incident_users_user ON public.default_incident_users USING btree (user_id);


--
-- Name: default_incident_users default_incident_users_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: default_incident_users default_incident_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: default_incident_users Allow all access to default_incident_users; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to default_incident_users" ON public.default_incident_users USING (true) WITH CHECK (true);


--
-- Name: default_incident_users; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.default_incident_users ENABLE ROW LEVEL SECURITY;