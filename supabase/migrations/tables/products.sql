--
-- Name: products; Type: TABLE; Schema: public;
--

CREATE TABLE public.products (
    id character varying(10) NOT NULL,
    barcode text NOT NULL,
    product_name_en text,
    product_name_ar text,
    image_url text,
    category_id character varying(10),
    unit_id character varying(10),
    unit_qty numeric DEFAULT 1 NOT NULL,
    sale_price numeric DEFAULT 0 NOT NULL,
    cost numeric DEFAULT 0 NOT NULL,
    profit numeric DEFAULT 0 NOT NULL,
    profit_percentage numeric DEFAULT 0 NOT NULL,
    current_stock integer DEFAULT 0 NOT NULL,
    minim_qty integer DEFAULT 0 NOT NULL,
    minimum_qty_alert integer DEFAULT 0 NOT NULL,
    maximum_qty integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    is_customer_product boolean DEFAULT true,
    is_variation boolean DEFAULT false NOT NULL,
    parent_product_barcode text,
    variation_group_name_en text,
    variation_group_name_ar text,
    variation_order integer DEFAULT 0,
    variation_image_override text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    modified_by uuid,
    modified_at timestamp with time zone
);


--
-- Name: products flyer_products_pkey1; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_pkey1 PRIMARY KEY (id);


--
-- Name: idx_products_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_barcode ON public.products USING btree (barcode);


--
-- Name: idx_products_category_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_category_id ON public.products USING btree (category_id);


--
-- Name: idx_products_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_created_at ON public.products USING btree (created_at);


--
-- Name: idx_products_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_is_active ON public.products USING btree (is_active);


--
-- Name: idx_products_is_customer_product; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_is_customer_product ON public.products USING btree (is_customer_product);


--
-- Name: idx_products_is_variation; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_is_variation ON public.products USING btree (is_variation);


--
-- Name: idx_products_parent_product_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_parent_product_barcode ON public.products USING btree (parent_product_barcode);


--
-- Name: idx_products_unit_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_products_unit_id ON public.products USING btree (unit_id);


--
-- Name: uq_products_barcode; Type: INDEX; Schema: public;
--

CREATE UNIQUE INDEX uq_products_barcode ON public.products USING btree (barcode);


--
-- Name: products trigger_calculate_flyer_product_profit; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_calculate_flyer_product_profit BEFORE INSERT OR UPDATE OF sale_price, cost ON public.products FOR EACH ROW EXECUTE FUNCTION public.calculate_flyer_product_profit();


--
-- Name: products flyer_products_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.product_categories(id) ON DELETE SET NULL;


--
-- Name: products flyer_products_created_by_fkey1; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_created_by_fkey1 FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: products flyer_products_modified_by_fkey1; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_modified_by_fkey1 FOREIGN KEY (modified_by) REFERENCES auth.users(id);


--
-- Name: products flyer_products_unit_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id) ON DELETE RESTRICT;


--
-- Name: products allow_delete_all; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete_all ON public.products FOR DELETE USING (true);


--
-- Name: products allow_insert_all; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert_all ON public.products FOR INSERT WITH CHECK (true);


--
-- Name: products allow_select_all; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select_all ON public.products FOR SELECT USING (true);


--
-- Name: products allow_update_all; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update_all ON public.products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;