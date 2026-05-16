--
-- Name: offer_products; Type: TABLE; Schema: public;
--

CREATE TABLE public.offer_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id integer NOT NULL,
    product_id character varying(50) NOT NULL,
    offer_qty integer DEFAULT 1 NOT NULL,
    offer_percentage numeric(5,2),
    offer_price numeric(10,2),
    max_uses integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_part_of_variation_group boolean DEFAULT false NOT NULL,
    variation_group_id uuid,
    variation_parent_barcode text,
    added_by uuid,
    added_at timestamp with time zone DEFAULT now(),
    CONSTRAINT at_least_one_discount CHECK (((offer_percentage IS NOT NULL) OR (offer_price IS NOT NULL))),
    CONSTRAINT valid_offer_price CHECK (((offer_price IS NULL) OR (offer_price >= (0)::numeric))),
    CONSTRAINT valid_offer_qty CHECK ((offer_qty > 0)),
    CONSTRAINT valid_percentage CHECK (((offer_percentage IS NULL) OR ((offer_percentage >= (0)::numeric) AND (offer_percentage <= (100)::numeric))))
);


--
-- Name: offer_products offer_products_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_pkey PRIMARY KEY (id);


--
-- Name: offer_products unique_offer_product; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT unique_offer_product UNIQUE (offer_id, product_id);


--
-- Name: idx_offer_products_active_lookup; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_active_lookup ON public.offer_products USING btree (offer_id, product_id);


--
-- Name: idx_offer_products_is_variation; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_is_variation ON public.offer_products USING btree (is_part_of_variation_group) WHERE (is_part_of_variation_group = true);


--
-- Name: idx_offer_products_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_offer_id ON public.offer_products USING btree (offer_id);


--
-- Name: idx_offer_products_product_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_product_id ON public.offer_products USING btree (product_id);


--
-- Name: idx_offer_products_variation_group_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_variation_group_id ON public.offer_products USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);


--
-- Name: idx_offer_products_variation_parent; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_products_variation_parent ON public.offer_products USING btree (variation_parent_barcode) WHERE (variation_parent_barcode IS NOT NULL);


--
-- Name: offer_products update_offer_products_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_offer_products_updated_at BEFORE UPDATE ON public.offer_products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: offer_products offer_products_added_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.users(id);


--
-- Name: offer_products offer_products_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_products offer_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: offer_products Allow anon insert offer_products; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert offer_products" ON public.offer_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_products Authenticated users can manage offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can manage offer products" ON public.offer_products TO authenticated USING (true) WITH CHECK (true);


--
-- Name: offer_products Public can view active offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Public can view active offer products" ON public.offer_products FOR SELECT USING ((offer_id IN ( SELECT offers.id
   FROM public.offers
  WHERE ((offers.is_active = true) AND (offers.start_date <= now()) AND (offers.end_date >= now())))));


--
-- Name: offer_products Users can delete offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can delete offer products" ON public.offer_products FOR DELETE USING (true);


--
-- Name: offer_products Users can insert offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can insert offer products" ON public.offer_products FOR INSERT WITH CHECK (true);


--
-- Name: offer_products Users can update offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update offer products" ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_products Users can view offer products; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view offer products" ON public.offer_products FOR SELECT USING (true);


--
-- Name: offer_products allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.offer_products USING (true) WITH CHECK (true);


--
-- Name: offer_products allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.offer_products FOR DELETE USING (true);


--
-- Name: offer_products allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.offer_products FOR INSERT WITH CHECK (true);


--
-- Name: offer_products allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.offer_products FOR SELECT USING (true);


--
-- Name: offer_products allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_products anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.offer_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_products authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.offer_products USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.offer_products ENABLE ROW LEVEL SECURITY;