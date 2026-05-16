--
-- Name: interface_permissions; Type: TABLE; Schema: public;
--

CREATE TABLE public.interface_permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    desktop_enabled boolean DEFAULT true NOT NULL,
    mobile_enabled boolean DEFAULT true NOT NULL,
    customer_enabled boolean DEFAULT false NOT NULL,
    updated_by uuid NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    cashier_enabled boolean DEFAULT false
);


--
-- Name: interface_permissions interface_permissions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_pkey PRIMARY KEY (id);


--
-- Name: interface_permissions interface_permissions_user_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_user_unique UNIQUE (user_id);


--
-- Name: idx_interface_permissions_cashier; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_cashier ON public.interface_permissions USING btree (cashier_enabled) WHERE (cashier_enabled = true);


--
-- Name: idx_interface_permissions_customer; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_customer ON public.interface_permissions USING btree (customer_enabled);


--
-- Name: idx_interface_permissions_desktop; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_desktop ON public.interface_permissions USING btree (desktop_enabled);


--
-- Name: idx_interface_permissions_mobile; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_mobile ON public.interface_permissions USING btree (mobile_enabled);


--
-- Name: idx_interface_permissions_updated_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_updated_by ON public.interface_permissions USING btree (updated_by);


--
-- Name: idx_interface_permissions_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_interface_permissions_user_id ON public.interface_permissions USING btree (user_id);


--
-- Name: interface_permissions trigger_update_interface_permissions_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_interface_permissions_updated_at BEFORE UPDATE ON public.interface_permissions FOR EACH ROW EXECUTE FUNCTION public.update_interface_permissions_updated_at();


--
-- Name: interface_permissions interface_permissions_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: interface_permissions interface_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interface_permissions Allow anon insert interface_permissions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert interface_permissions" ON public.interface_permissions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: interface_permissions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.interface_permissions USING (true) WITH CHECK (true);


--
-- Name: interface_permissions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.interface_permissions FOR DELETE USING (true);


--
-- Name: interface_permissions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.interface_permissions FOR INSERT WITH CHECK (true);


--
-- Name: interface_permissions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.interface_permissions FOR SELECT USING (true);


--
-- Name: interface_permissions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.interface_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: interface_permissions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.interface_permissions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: interface_permissions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.interface_permissions USING ((auth.uid() IS NOT NULL));


--
-- Name: interface_permissions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.interface_permissions ENABLE ROW LEVEL SECURITY;


--
-- Name: interface_permissions interface_permissions_delete_policy; Type: POLICY; Schema: public;
--

CREATE POLICY interface_permissions_delete_policy ON public.interface_permissions FOR DELETE USING (true);


--
-- Name: interface_permissions interface_permissions_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY interface_permissions_insert_policy ON public.interface_permissions FOR INSERT WITH CHECK (true);


--
-- Name: interface_permissions interface_permissions_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY interface_permissions_select_policy ON public.interface_permissions FOR SELECT USING (true);


--
-- Name: interface_permissions interface_permissions_update_policy; Type: POLICY; Schema: public;
--

CREATE POLICY interface_permissions_update_policy ON public.interface_permissions FOR UPDATE USING (true);