--
-- Name: flyer_offer_products; Type: TABLE; Schema: public;
--

CREATE TABLE public.flyer_offer_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id uuid NOT NULL,
    product_barcode text NOT NULL,
    cost numeric(10,2),
    sales_price numeric(10,2),
    offer_price numeric(10,2),
    profit_amount numeric(10,2),
    profit_percent numeric(10,2),
    profit_after_offer numeric(10,2),
    decrease_amount numeric(10,2),
    offer_qty integer DEFAULT 1 NOT NULL,
    limit_qty integer,
    free_qty integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    page_number integer DEFAULT 1,
    page_order integer DEFAULT 1,
    total_sales_price numeric DEFAULT 0,
    total_offer_price numeric DEFAULT 0,
    CONSTRAINT flyer_offer_products_free_qty_check CHECK ((free_qty >= 0)),
    CONSTRAINT flyer_offer_products_offer_qty_check CHECK ((offer_qty >= 0))
);


--
-- Name: flyer_offer_products flyer_offer_products_offer_id_product_barcode_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_offer_id_product_barcode_key UNIQUE (offer_id, product_barcode);


--
-- Name: flyer_offer_products flyer_offer_products_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_pkey PRIMARY KEY (id);


--
-- Name: idx_flyer_offer_products_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offer_products_barcode ON public.flyer_offer_products USING btree (product_barcode);


--
-- Name: idx_flyer_offer_products_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offer_products_offer_id ON public.flyer_offer_products USING btree (offer_id);


--
-- Name: idx_flyer_offer_products_page; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offer_products_page ON public.flyer_offer_products USING btree (offer_id, page_number, page_order);


--
-- Name: flyer_offer_products flyer_offer_products_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.flyer_offers(id) ON DELETE CASCADE;


--
-- Name: flyer_offer_products flyer_offer_products_product_barcode_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_product_barcode_fkey FOREIGN KEY (product_barcode) REFERENCES public.products(barcode) ON DELETE CASCADE;


--
-- Name: flyer_offer_products Allow anon insert flyer_offer_products; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert flyer_offer_products" ON public.flyer_offer_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: flyer_offer_products allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.flyer_offer_products USING (true) WITH CHECK (true);


--
-- Name: flyer_offer_products allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.flyer_offer_products FOR DELETE USING (true);


--
-- Name: flyer_offer_products allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.flyer_offer_products FOR INSERT WITH CHECK (true);


--
-- Name: flyer_offer_products allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.flyer_offer_products FOR SELECT USING (true);


--
-- Name: flyer_offer_products allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.flyer_offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: flyer_offer_products anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.flyer_offer_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: flyer_offer_products authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.flyer_offer_products USING ((auth.uid() IS NOT NULL));


--
-- Name: flyer_offer_products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.flyer_offer_products ENABLE ROW LEVEL SECURITY;


--
-- Name: flyer_offer_products flyer_offer_products_delete_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offer_products_delete_policy ON public.flyer_offer_products FOR DELETE TO authenticated USING (true);


--
-- Name: flyer_offer_products flyer_offer_products_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offer_products_insert_policy ON public.flyer_offer_products FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: flyer_offer_products flyer_offer_products_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offer_products_select_policy ON public.flyer_offer_products FOR SELECT USING (true);


--
-- Name: flyer_offer_products flyer_offer_products_update_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offer_products_update_policy ON public.flyer_offer_products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);