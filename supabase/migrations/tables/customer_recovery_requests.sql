--
-- Name: customer_recovery_requests; Type: TABLE; Schema: public;
--

CREATE TABLE public.customer_recovery_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid,
    whatsapp_number character varying(20) NOT NULL,
    customer_name text,
    request_type text DEFAULT 'account_recovery'::text NOT NULL,
    verification_status text DEFAULT 'pending'::text NOT NULL,
    verification_notes text,
    processed_by uuid,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT customer_recovery_requests_request_type_check CHECK ((request_type = ANY (ARRAY['account_recovery'::text, 'access_code_request'::text]))),
    CONSTRAINT customer_recovery_requests_verification_status_check CHECK ((verification_status = ANY (ARRAY['pending'::text, 'verified'::text, 'rejected'::text, 'processed'::text]))),
    CONSTRAINT customer_recovery_requests_whatsapp_format_check CHECK (((whatsapp_number)::text ~ '^\+?[1-9]\d{1,14}$'::text))
);


--
-- Name: customer_recovery_requests customer_recovery_requests_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_pkey PRIMARY KEY (id);


--
-- Name: idx_customer_recovery_requests_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_created_at ON public.customer_recovery_requests USING btree (created_at);


--
-- Name: idx_customer_recovery_requests_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_customer_id ON public.customer_recovery_requests USING btree (customer_id);


--
-- Name: idx_customer_recovery_requests_processed_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_processed_by ON public.customer_recovery_requests USING btree (processed_by);


--
-- Name: idx_customer_recovery_requests_request_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_request_type ON public.customer_recovery_requests USING btree (request_type);


--
-- Name: idx_customer_recovery_requests_verification_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_verification_status ON public.customer_recovery_requests USING btree (verification_status);


--
-- Name: idx_customer_recovery_requests_whatsapp; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_recovery_requests_whatsapp ON public.customer_recovery_requests USING btree (whatsapp_number);


--
-- Name: customer_recovery_requests trigger_update_customer_recovery_requests_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_customer_recovery_requests_updated_at BEFORE UPDATE ON public.customer_recovery_requests FOR EACH ROW EXECUTE FUNCTION public.update_customer_recovery_requests_updated_at();


--
-- Name: customer_recovery_requests customer_recovery_requests_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_recovery_requests customer_recovery_requests_processed_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.users(id);


--
-- Name: customer_recovery_requests Allow anon insert customer_recovery_requests; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert customer_recovery_requests" ON public.customer_recovery_requests FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.customer_recovery_requests USING (true) WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.customer_recovery_requests FOR DELETE USING (true);


--
-- Name: customer_recovery_requests allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.customer_recovery_requests FOR SELECT USING (true);


--
-- Name: customer_recovery_requests allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.customer_recovery_requests FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_recovery_requests anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.customer_recovery_requests USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_recovery_requests authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.customer_recovery_requests USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_recovery_requests; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.customer_recovery_requests ENABLE ROW LEVEL SECURITY;


--
-- Name: customer_recovery_requests customer_recovery_requests_delete_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_recovery_requests_delete_policy ON public.customer_recovery_requests FOR DELETE USING (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_recovery_requests_insert_policy ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_recovery_requests_select_policy ON public.customer_recovery_requests FOR SELECT USING (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_update_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customer_recovery_requests_update_policy ON public.customer_recovery_requests FOR UPDATE USING (true);