--
-- Name: coupon_eligible_customers; Type: TABLE; Schema: public;
--

CREATE TABLE public.coupon_eligible_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    mobile_number character varying(20) NOT NULL,
    customer_name character varying(255),
    import_batch_id uuid,
    imported_at timestamp with time zone DEFAULT now(),
    imported_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: coupon_eligible_customers coupon_eligible_customers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_pkey PRIMARY KEY (id);


--
-- Name: coupon_eligible_customers unique_customer_campaign; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT unique_customer_campaign UNIQUE (campaign_id, mobile_number);


--
-- Name: idx_eligible_customers_campaign; Type: INDEX; Schema: public;
--

CREATE INDEX idx_eligible_customers_campaign ON public.coupon_eligible_customers USING btree (campaign_id);


--
-- Name: idx_eligible_customers_mobile; Type: INDEX; Schema: public;
--

CREATE INDEX idx_eligible_customers_mobile ON public.coupon_eligible_customers USING btree (mobile_number);


--
-- Name: coupon_eligible_customers coupon_eligible_customers_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_eligible_customers coupon_eligible_customers_imported_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_imported_by_fkey FOREIGN KEY (imported_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_eligible_customers Allow anon insert coupon_eligible_customers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert coupon_eligible_customers" ON public.coupon_eligible_customers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.coupon_eligible_customers USING (true) WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.coupon_eligible_customers FOR DELETE USING (true);


--
-- Name: coupon_eligible_customers allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.coupon_eligible_customers FOR INSERT WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.coupon_eligible_customers FOR SELECT USING (true);


--
-- Name: coupon_eligible_customers allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.coupon_eligible_customers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_eligible_customers anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.coupon_eligible_customers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_eligible_customers authenticated_check_eligibility; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_check_eligibility ON public.coupon_eligible_customers FOR SELECT TO authenticated USING (true);


--
-- Name: coupon_eligible_customers authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.coupon_eligible_customers USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_eligible_customers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.coupon_eligible_customers ENABLE ROW LEVEL SECURITY;