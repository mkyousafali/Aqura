--
-- Name: biometric_connections; Type: TABLE; Schema: public;
--

CREATE TABLE public.biometric_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id integer NOT NULL,
    branch_name text NOT NULL,
    server_ip text NOT NULL,
    server_name text,
    database_name text NOT NULL,
    username text NOT NULL,
    password text NOT NULL,
    device_id text NOT NULL,
    terminal_sn text,
    is_active boolean DEFAULT true,
    last_sync_at timestamp with time zone,
    last_employee_sync_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    branch_location_code text
);


--
-- Name: biometric_connections biometric_connections_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT biometric_connections_pkey PRIMARY KEY (id);


--
-- Name: biometric_connections unique_branch_device; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT unique_branch_device UNIQUE (branch_id, device_id);


--
-- Name: idx_biometric_connections_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_biometric_connections_active ON public.biometric_connections USING btree (is_active);


--
-- Name: idx_biometric_connections_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_biometric_connections_branch ON public.biometric_connections USING btree (branch_id);


--
-- Name: idx_biometric_connections_device; Type: INDEX; Schema: public;
--

CREATE INDEX idx_biometric_connections_device ON public.biometric_connections USING btree (device_id);


--
-- Name: idx_biometric_connections_terminal; Type: INDEX; Schema: public;
--

CREATE INDEX idx_biometric_connections_terminal ON public.biometric_connections USING btree (terminal_sn);


--
-- Name: biometric_connections biometric_connections_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT biometric_connections_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: biometric_connections Allow anon insert biometric_connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert biometric_connections" ON public.biometric_connections FOR INSERT TO anon WITH CHECK (true);


--
-- Name: biometric_connections Enable delete for authenticated users; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable delete for authenticated users" ON public.biometric_connections FOR DELETE USING ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable insert for authenticated users; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable insert for authenticated users" ON public.biometric_connections FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable read for authenticated users; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable read for authenticated users" ON public.biometric_connections FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable update for authenticated users; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable update for authenticated users" ON public.biometric_connections FOR UPDATE USING ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.biometric_connections USING (true) WITH CHECK (true);


--
-- Name: biometric_connections allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.biometric_connections FOR DELETE USING (true);


--
-- Name: biometric_connections allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.biometric_connections FOR INSERT WITH CHECK (true);


--
-- Name: biometric_connections allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.biometric_connections FOR SELECT USING (true);


--
-- Name: biometric_connections allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.biometric_connections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: biometric_connections anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.biometric_connections USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: biometric_connections authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.biometric_connections USING ((auth.uid() IS NOT NULL));


--
-- Name: biometric_connections; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.biometric_connections ENABLE ROW LEVEL SECURITY;