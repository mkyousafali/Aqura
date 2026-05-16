--
-- Name: assets; Type: TABLE; Schema: public;
--

CREATE TABLE public.assets (
    id integer NOT NULL,
    asset_id character varying(30) NOT NULL,
    sub_category_id integer NOT NULL,
    asset_name_en character varying(255) NOT NULL,
    asset_name_ar character varying(255) NOT NULL,
    purchase_date date,
    purchase_value numeric(12,2) DEFAULT 0,
    branch_id integer,
    invoice_url text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.assets_id_seq OWNED BY public.assets.id;


--
-- Name: assets id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.assets ALTER COLUMN id SET DEFAULT nextval('public.assets_id_seq'::regclass);


--
-- Name: assets assets_asset_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_asset_id_key UNIQUE (asset_id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: idx_assets_asset_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_assets_asset_id ON public.assets USING btree (asset_id);


--
-- Name: idx_assets_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_assets_branch_id ON public.assets USING btree (branch_id);


--
-- Name: idx_assets_sub_category_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_assets_sub_category_id ON public.assets USING btree (sub_category_id);


--
-- Name: assets assets_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: assets assets_sub_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_sub_category_id_fkey FOREIGN KEY (sub_category_id) REFERENCES public.asset_sub_categories(id) ON DELETE RESTRICT;


--
-- Name: assets Allow all access to assets; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to assets" ON public.assets USING (true) WITH CHECK (true);


--
-- Name: assets; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;