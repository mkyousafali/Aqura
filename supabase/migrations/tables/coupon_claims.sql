--
-- Name: coupon_claims; Type: TABLE; Schema: public;
--

CREATE TABLE public.coupon_claims (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    customer_mobile character varying(20) NOT NULL,
    product_id uuid,
    branch_id bigint,
    claimed_by_user uuid,
    claimed_at timestamp with time zone DEFAULT now(),
    print_count integer DEFAULT 1,
    barcode_scanned boolean DEFAULT false,
    validity_date date NOT NULL,
    status character varying(20) DEFAULT 'claimed'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    max_claims_per_customer integer DEFAULT 1,
    CONSTRAINT valid_status CHECK (((status)::text = ANY (ARRAY[('claimed'::character varying)::text, ('redeemed'::character varying)::text, ('expired'::character varying)::text])))
);


--
-- Name: coupon_claims coupon_claims_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_pkey PRIMARY KEY (id);


--
-- Name: idx_coupon_claims_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_branch ON public.coupon_claims USING btree (branch_id);


--
-- Name: idx_coupon_claims_campaign; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_campaign ON public.coupon_claims USING btree (campaign_id);


--
-- Name: idx_coupon_claims_customer_campaign; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_customer_campaign ON public.coupon_claims USING btree (campaign_id, customer_mobile);


--
-- Name: idx_coupon_claims_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_date ON public.coupon_claims USING btree (claimed_at);


--
-- Name: idx_coupon_claims_mobile; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_mobile ON public.coupon_claims USING btree (customer_mobile);


--
-- Name: idx_coupon_claims_product; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_claims_product ON public.coupon_claims USING btree (product_id);


--
-- Name: coupon_claims coupon_claims_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: coupon_claims coupon_claims_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_claims coupon_claims_claimed_by_user_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_claimed_by_user_fkey FOREIGN KEY (claimed_by_user) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_claims coupon_claims_product_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.coupon_products(id) ON DELETE SET NULL;


--
-- Name: coupon_claims Allow anon insert coupon_claims; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert coupon_claims" ON public.coupon_claims FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_claims allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.coupon_claims USING (true) WITH CHECK (true);


--
-- Name: coupon_claims allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.coupon_claims FOR DELETE USING (true);


--
-- Name: coupon_claims allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.coupon_claims FOR INSERT WITH CHECK (true);


--
-- Name: coupon_claims allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.coupon_claims FOR SELECT USING (true);


--
-- Name: coupon_claims allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.coupon_claims FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_claims anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.coupon_claims USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_claims authenticated_create_claims; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_create_claims ON public.coupon_claims FOR INSERT TO authenticated WITH CHECK ((claimed_by_user = auth.uid()));


--
-- Name: coupon_claims authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.coupon_claims USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_claims; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.coupon_claims ENABLE ROW LEVEL SECURITY;