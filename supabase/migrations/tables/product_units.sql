--
-- Name: product_units; Type: TABLE; Schema: public;
--

CREATE TABLE public.product_units (
    id character varying(10) NOT NULL,
    name_en character varying(50) NOT NULL,
    name_ar character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: product_units product_units_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_units
    ADD CONSTRAINT product_units_pkey PRIMARY KEY (id);


--
-- Name: idx_product_units_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_units_is_active ON public.product_units USING btree (is_active);


--
-- Name: product_units product_units_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_units
    ADD CONSTRAINT product_units_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: product_units Allow all access to product_units; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to product_units" ON public.product_units USING (true) WITH CHECK (true);


--
-- Name: product_units; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.product_units ENABLE ROW LEVEL SECURITY;