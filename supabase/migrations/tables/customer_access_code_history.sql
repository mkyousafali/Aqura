--
-- Name: customer_access_code_history; Type: TABLE; Schema: public;
--

CREATE TABLE public.customer_access_code_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    old_access_code text,
    new_access_code text NOT NULL,
    generated_by uuid NOT NULL,
    reason text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT customer_access_code_history_reason_check CHECK ((reason = ANY (ARRAY['initial_generation'::text, 'admin_regeneration'::text, 'security_reset'::text, 'customer_request'::text, 're_registration'::text, 'forgot_code_resend'::text, 'pre_registered_upgrade'::text])))
);


--
-- Name: customer_access_code_history customer_access_code_history_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_pkey PRIMARY KEY (id);


--
-- Name: idx_customer_access_code_history_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_access_code_history_created_at ON public.customer_access_code_history USING btree (created_at);


--
-- Name: idx_customer_access_code_history_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_access_code_history_customer_id ON public.customer_access_code_history USING btree (customer_id);


--
-- Name: idx_customer_access_code_history_generated_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_access_code_history_generated_by ON public.customer_access_code_history USING btree (generated_by);


--
-- Name: customer_access_code_history customer_access_code_history_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_access_code_history customer_access_code_history_generated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(id);


--
-- Name: customer_access_code_history Allow anon insert customer_access_code_history; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert customer_access_code_history" ON public.customer_access_code_history FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_access_code_history allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.customer_access_code_history USING (true) WITH CHECK (true);


--
-- Name: customer_access_code_history allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.customer_access_code_history FOR DELETE USING (true);


--
-- Name: customer_access_code_history allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.customer_access_code_history FOR INSERT WITH CHECK (true);


--
-- Name: customer_access_code_history allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.customer_access_code_history FOR SELECT USING (true);


--
-- Name: customer_access_code_history allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.customer_access_code_history FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_access_code_history anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.customer_access_code_history USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_access_code_history authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.customer_access_code_history USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_access_code_history; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.customer_access_code_history ENABLE ROW LEVEL SECURITY;


--
-- Name: customer_access_code_history customer_access_code_history_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_access_code_history_insert_policy ON public.customer_access_code_history FOR INSERT WITH CHECK (true);


--
-- Name: customer_access_code_history customer_access_code_history_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_access_code_history_select_policy ON public.customer_access_code_history FOR SELECT USING (true);


--
-- Name: customer_access_code_history realtime_access_code_history_select; Type: POLICY; Schema: public;
--

CREATE POLICY realtime_access_code_history_select ON public.customer_access_code_history FOR SELECT TO authenticated, anon USING (true);