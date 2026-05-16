--
-- Name: erp_synced_products; Type: TABLE; Schema: public;
--

CREATE TABLE public.erp_synced_products (
    id integer NOT NULL,
    barcode character varying(50) NOT NULL,
    auto_barcode character varying(50),
    parent_barcode character varying(50),
    product_name_en character varying(500),
    product_name_ar character varying(500),
    unit_name character varying(100),
    unit_qty numeric(18,6) DEFAULT 1,
    is_base_unit boolean DEFAULT false,
    synced_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    expiry_dates jsonb DEFAULT '[]'::jsonb,
    managed_by jsonb DEFAULT '[]'::jsonb,
    in_process jsonb DEFAULT '[]'::jsonb,
    expiry_hidden boolean DEFAULT false
);


--
-- Name: erp_synced_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.erp_synced_products_id_seq OWNED BY public.erp_synced_products.id;


--
-- Name: erp_synced_products id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.erp_synced_products ALTER COLUMN id SET DEFAULT nextval('public.erp_synced_products_id_seq'::regclass);


--
-- Name: erp_synced_products erp_synced_products_barcode_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_synced_products
    ADD CONSTRAINT erp_synced_products_barcode_key UNIQUE (barcode);


--
-- Name: erp_synced_products erp_synced_products_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_synced_products
    ADD CONSTRAINT erp_synced_products_pkey PRIMARY KEY (id);


--
-- Name: idx_erp_synced_products_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_barcode ON public.erp_synced_products USING btree (barcode);


--
-- Name: idx_erp_synced_products_expiry_dates; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_expiry_dates ON public.erp_synced_products USING gin (expiry_dates);


--
-- Name: idx_erp_synced_products_expiry_hidden; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_expiry_hidden ON public.erp_synced_products USING btree (expiry_hidden) WHERE (expiry_hidden = true);


--
-- Name: idx_erp_synced_products_in_process; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_in_process ON public.erp_synced_products USING gin (in_process);


--
-- Name: idx_erp_synced_products_managed_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_managed_by ON public.erp_synced_products USING gin (managed_by);


--
-- Name: idx_erp_synced_products_parent_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_parent_barcode ON public.erp_synced_products USING btree (parent_barcode);


--
-- Name: idx_erp_synced_products_product_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_synced_products_product_name_en ON public.erp_synced_products USING btree (product_name_en);


--
-- Name: erp_synced_products Allow all access to erp_synced_products; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to erp_synced_products" ON public.erp_synced_products USING (true) WITH CHECK (true);


--
-- Name: erp_synced_products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.erp_synced_products ENABLE ROW LEVEL SECURITY;