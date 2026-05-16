--
-- Name: order_items; Type: TABLE; Schema: public;
--

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    product_id character varying(50) NOT NULL,
    product_name_ar character varying(255) NOT NULL,
    product_name_en character varying(255) NOT NULL,
    product_sku character varying(100),
    unit_id character varying(50),
    unit_name_ar character varying(100),
    unit_name_en character varying(100),
    unit_size character varying(50),
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    original_price numeric(10,2) NOT NULL,
    discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    final_price numeric(10,2) NOT NULL,
    line_total numeric(10,2) NOT NULL,
    has_offer boolean DEFAULT false NOT NULL,
    offer_id integer,
    offer_name_ar character varying(255),
    offer_name_en character varying(255),
    offer_type character varying(50),
    offer_discount_percentage numeric(5,2),
    offer_special_price numeric(10,2),
    item_type character varying(20) DEFAULT 'regular'::character varying NOT NULL,
    bundle_id uuid,
    bundle_name_ar character varying(255),
    bundle_name_en character varying(255),
    is_bundle_item boolean DEFAULT false NOT NULL,
    is_bogo_free boolean DEFAULT false NOT NULL,
    bogo_group_id uuid,
    tax_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(10,2) DEFAULT 0 NOT NULL,
    item_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.order_items REPLICA IDENTITY FULL;


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: idx_order_items_bundle_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_bundle_id ON public.order_items USING btree (bundle_id);


--
-- Name: idx_order_items_item_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_item_type ON public.order_items USING btree (item_type);


--
-- Name: idx_order_items_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_offer_id ON public.order_items USING btree (offer_id);


--
-- Name: idx_order_items_order_bundle; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_order_bundle ON public.order_items USING btree (order_id, bundle_id);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_order_product; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_order_product ON public.order_items USING btree (order_id, product_id);


--
-- Name: idx_order_items_product_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_product_id ON public.order_items USING btree (product_id);


--
-- Name: idx_order_items_unit_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_items_unit_id ON public.order_items USING btree (unit_id);


--
-- Name: order_items trigger_adjust_product_stock; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_adjust_product_stock BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.adjust_product_stock_on_order_insert();


--
-- Name: order_items trigger_link_offer_usage_to_order; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_link_offer_usage_to_order AFTER INSERT ON public.order_items FOR EACH ROW WHEN (((new.has_offer = true) AND (new.offer_id IS NOT NULL))) EXECUTE FUNCTION public.trigger_log_order_offer_usage();


--
-- Name: order_items trigger_order_items_delete_totals; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_order_items_delete_totals AFTER DELETE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: order_items trigger_order_items_insert_totals; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_order_items_insert_totals AFTER INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: order_items trigger_order_items_update_totals; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_order_items_update_totals AFTER UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: order_items order_items_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: order_items order_items_unit_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id) ON DELETE SET NULL;


--
-- Name: order_items Allow anon insert order_items; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);


--
-- Name: order_items allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.order_items USING (true) WITH CHECK (true);


--
-- Name: order_items allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.order_items FOR DELETE USING (true);


--
-- Name: order_items allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.order_items FOR INSERT WITH CHECK (true);


--
-- Name: order_items allow_insert_order_items; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert_order_items ON public.order_items FOR INSERT WITH CHECK (true);


--
-- Name: order_items allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.order_items FOR SELECT USING (true);


--
-- Name: order_items allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.order_items FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: order_items anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.order_items USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: order_items authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.order_items USING ((auth.uid() IS NOT NULL));


--
-- Name: order_items management_delete_order_items; Type: POLICY; Schema: public;
--

CREATE POLICY management_delete_order_items ON public.order_items FOR DELETE USING (public.has_order_management_access(auth.uid()));


--
-- Name: order_items management_update_order_items; Type: POLICY; Schema: public;
--

CREATE POLICY management_update_order_items ON public.order_items FOR UPDATE USING (public.has_order_management_access(auth.uid()));


--
-- Name: order_items; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;


--
-- Name: order_items system_insert_order_items; Type: POLICY; Schema: public;
--

CREATE POLICY system_insert_order_items ON public.order_items FOR INSERT WITH CHECK ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR public.has_order_management_access(auth.uid())))));


--
-- Name: order_items users_view_order_items; Type: POLICY; Schema: public;
--

CREATE POLICY users_view_order_items ON public.order_items FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR (orders.picker_id = auth.uid()) OR (orders.delivery_person_id = auth.uid()) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())))));