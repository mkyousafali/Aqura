--
-- Name: erp_connections; Type: TABLE; Schema: public;
--

CREATE TABLE public.erp_connections (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    server_ip text NOT NULL,
    server_name text,
    database_name text NOT NULL,
    username text NOT NULL,
    password text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    device_id text,
    erp_branch_id integer,
    tunnel_url text
);


--
-- Name: erp_connections erp_connections_branch_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_branch_id_key UNIQUE (branch_id);


--
-- Name: erp_connections erp_connections_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_pkey PRIMARY KEY (id);


--
-- Name: idx_erp_connections_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_connections_branch_id ON public.erp_connections USING btree (branch_id);


--
-- Name: idx_erp_connections_device_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_connections_device_id ON public.erp_connections USING btree (device_id);


--
-- Name: idx_erp_connections_erp_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_connections_erp_branch_id ON public.erp_connections USING btree (erp_branch_id);


--
-- Name: idx_erp_connections_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_connections_is_active ON public.erp_connections USING btree (is_active);


--
-- Name: erp_connections update_erp_connections_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_erp_connections_updated_at BEFORE UPDATE ON public.erp_connections FOR EACH ROW EXECUTE FUNCTION public.update_erp_connections_updated_at();


--
-- Name: erp_connections erp_connections_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: erp_connections Allow anon insert erp_connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert erp_connections" ON public.erp_connections FOR INSERT TO anon WITH CHECK (true);


--
-- Name: erp_connections Allow authenticated users to create ERP connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create ERP connections" ON public.erp_connections FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: erp_connections Allow authenticated users to delete ERP connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to delete ERP connections" ON public.erp_connections FOR DELETE TO authenticated USING (true);


--
-- Name: erp_connections Allow authenticated users to read ERP connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read ERP connections" ON public.erp_connections FOR SELECT TO authenticated USING (true);


--
-- Name: erp_connections Allow authenticated users to update ERP connections; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update ERP connections" ON public.erp_connections FOR UPDATE TO authenticated USING (true);


--
-- Name: erp_connections allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.erp_connections USING (true) WITH CHECK (true);


--
-- Name: erp_connections allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.erp_connections FOR DELETE USING (true);


--
-- Name: erp_connections allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.erp_connections FOR INSERT WITH CHECK (true);


--
-- Name: erp_connections allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.erp_connections FOR SELECT USING (true);


--
-- Name: erp_connections allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.erp_connections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: erp_connections anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.erp_connections USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: erp_connections authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.erp_connections USING ((auth.uid() IS NOT NULL));


--
-- Name: erp_connections; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.erp_connections ENABLE ROW LEVEL SECURITY;