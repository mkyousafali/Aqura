--
-- Name: coupon_products; Type: TABLE; Schema: public;
--

CREATE TABLE public.coupon_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    product_name_en character varying(255) NOT NULL,
    product_name_ar character varying(255) NOT NULL,
    product_image_url text,
    original_price numeric(10,2) NOT NULL,
    offer_price numeric(10,2) NOT NULL,
    special_barcode character varying(50) NOT NULL,
    stock_limit integer DEFAULT 0 NOT NULL,
    stock_remaining integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    flyer_product_id character varying(10),
    CONSTRAINT valid_price CHECK (((offer_price >= (0)::numeric) AND (original_price >= offer_price))),
    CONSTRAINT valid_stock CHECK (((stock_remaining >= 0) AND (stock_remaining <= stock_limit)))
);


--
-- Name: coupon_products coupon_products_campaign_barcode_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_campaign_barcode_unique UNIQUE (campaign_id, special_barcode);


--
-- Name: coupon_products coupon_products_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_pkey PRIMARY KEY (id);


--
-- Name: idx_coupon_products_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_products_barcode ON public.coupon_products USING btree (special_barcode);


--
-- Name: idx_coupon_products_campaign; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_products_campaign ON public.coupon_products USING btree (campaign_id);


--
-- Name: idx_coupon_products_stock; Type: INDEX; Schema: public;
--

CREATE INDEX idx_coupon_products_stock ON public.coupon_products USING btree (stock_remaining) WHERE (is_active = true);


--
-- Name: coupon_products trigger_update_coupon_products_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_coupon_products_updated_at BEFORE UPDATE ON public.coupon_products FOR EACH ROW EXECUTE FUNCTION public.update_coupon_products_updated_at();


--
-- Name: coupon_products coupon_products_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_products coupon_products_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_products coupon_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_product_id_fkey FOREIGN KEY (flyer_product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: coupon_products Allow anon insert coupon_products; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert coupon_products" ON public.coupon_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_products allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.coupon_products USING (true) WITH CHECK (true);


--
-- Name: coupon_products allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.coupon_products FOR DELETE USING (true);


--
-- Name: coupon_products allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.coupon_products FOR INSERT WITH CHECK (true);


--
-- Name: coupon_products allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.coupon_products FOR SELECT USING (true);


--
-- Name: coupon_products allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.coupon_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_products anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.coupon_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_products authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.coupon_products USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_products authenticated_view_active_products; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_view_active_products ON public.coupon_products FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));


--
-- Name: coupon_products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.coupon_products ENABLE ROW LEVEL SECURITY;