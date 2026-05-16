--
-- Name: employee_fine_payments; Type: TABLE; Schema: public;
--

CREATE TABLE public.employee_fine_payments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    warning_id uuid,
    payment_method character varying(50),
    payment_amount numeric(10,2) NOT NULL,
    payment_currency character varying(3) DEFAULT 'USD'::character varying,
    payment_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    payment_reference character varying(100),
    payment_notes text,
    processed_by uuid,
    processed_by_username character varying(255),
    account_code character varying(50),
    transaction_id character varying(100),
    receipt_number character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: employee_fine_payments employee_fine_payments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_fine_payments
    ADD CONSTRAINT employee_fine_payments_pkey PRIMARY KEY (id);


--
-- Name: idx_fine_payments_payment_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_fine_payments_payment_date ON public.employee_fine_payments USING btree (payment_date);


--
-- Name: idx_fine_payments_processed_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_fine_payments_processed_by ON public.employee_fine_payments USING btree (processed_by);


--
-- Name: idx_fine_payments_warning_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_fine_payments_warning_id ON public.employee_fine_payments USING btree (warning_id);


--
-- Name: employee_fine_payments employee_fine_payments_processed_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_fine_payments
    ADD CONSTRAINT employee_fine_payments_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: employee_fine_payments Admins can manage all fine payments; Type: POLICY; Schema: public;
--

CREATE POLICY "Admins can manage all fine payments" ON public.employee_fine_payments USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.user_type = 'global'::public.user_type_enum)))));


--
-- Name: employee_fine_payments Allow anon insert employee_fine_payments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert employee_fine_payments" ON public.employee_fine_payments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: employee_fine_payments allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.employee_fine_payments USING (true) WITH CHECK (true);


--
-- Name: employee_fine_payments allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.employee_fine_payments FOR DELETE USING (true);


--
-- Name: employee_fine_payments allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.employee_fine_payments FOR INSERT WITH CHECK (true);


--
-- Name: employee_fine_payments allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.employee_fine_payments FOR SELECT USING (true);


--
-- Name: employee_fine_payments allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.employee_fine_payments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: employee_fine_payments anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.employee_fine_payments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: employee_fine_payments authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.employee_fine_payments USING ((auth.uid() IS NOT NULL));


--
-- Name: employee_fine_payments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.employee_fine_payments ENABLE ROW LEVEL SECURITY;