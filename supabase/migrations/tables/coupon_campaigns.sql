--
-- Name: coupon_campaigns; Type: TABLE; Schema: public;
--

CREATE TABLE public.coupon_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_name character varying(255),
    campaign_code character varying(50) NOT NULL,
    description text,
    validity_start_date timestamp with time zone,
    validity_end_date timestamp with time zone,
    is_active boolean DEFAULT true,
    terms_conditions_en text,
    terms_conditions_ar text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone NOT NULL,
    max_claims_per_customer integer DEFAULT 1,
    CONSTRAINT valid_campaign_dates CHECK ((end_date > start_date)),
    CONSTRAINT valid_max_claims CHECK ((max_claims_per_customer > 0))
);


--
-- Name: coupon_campaigns coupon_campaigns_campaign_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_campaign_code_key UNIQUE (campaign_code);


--
-- Name: coupon_campaigns coupon_campaigns_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_pkey PRIMARY KEY (id);


--
-- Name: idx_campaigns_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_campaigns_active ON public.coupon_campaigns USING btree (is_active) WHERE (deleted_at IS NULL);


--
-- Name: idx_campaigns_code; Type: INDEX; Schema: public;
--

CREATE INDEX idx_campaigns_code ON public.coupon_campaigns USING btree (campaign_code);


--
-- Name: idx_campaigns_validity; Type: INDEX; Schema: public;
--

CREATE INDEX idx_campaigns_validity ON public.coupon_campaigns USING btree (validity_start_date, validity_end_date);


--
-- Name: coupon_campaigns trigger_update_coupon_campaigns_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_coupon_campaigns_updated_at BEFORE UPDATE ON public.coupon_campaigns FOR EACH ROW EXECUTE FUNCTION public.update_coupon_campaigns_updated_at();


--
-- Name: coupon_campaigns coupon_campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_campaigns Allow anon insert coupon_campaigns; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert coupon_campaigns" ON public.coupon_campaigns FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_campaigns allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.coupon_campaigns USING (true) WITH CHECK (true);


--
-- Name: coupon_campaigns allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.coupon_campaigns FOR DELETE USING (true);


--
-- Name: coupon_campaigns allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.coupon_campaigns FOR INSERT WITH CHECK (true);


--
-- Name: coupon_campaigns allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.coupon_campaigns FOR SELECT USING (true);


--
-- Name: coupon_campaigns allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.coupon_campaigns FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_campaigns anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.coupon_campaigns USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_campaigns authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.coupon_campaigns USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_campaigns authenticated_view_active_campaigns; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_view_active_campaigns ON public.coupon_campaigns FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));


--
-- Name: coupon_campaigns; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.coupon_campaigns ENABLE ROW LEVEL SECURITY;