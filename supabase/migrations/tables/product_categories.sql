--
-- Name: product_categories; Type: TABLE; Schema: public;
--

CREATE TABLE public.product_categories (
    id character varying(10) NOT NULL,
    name_en character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: idx_product_categories_display_order; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_categories_display_order ON public.product_categories USING btree (display_order);


--
-- Name: idx_product_categories_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_categories_is_active ON public.product_categories USING btree (is_active);


--
-- Name: product_categories product_categories_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: product_categories Allow all access to product_categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to product_categories" ON public.product_categories USING (true) WITH CHECK (true);


--
-- Name: product_categories; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;