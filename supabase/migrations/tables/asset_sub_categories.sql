--
-- Name: asset_sub_categories; Type: TABLE; Schema: public;
--

CREATE TABLE public.asset_sub_categories (
    id integer NOT NULL,
    category_id integer NOT NULL,
    group_code character varying(20) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    useful_life_years character varying(20),
    annual_depreciation_pct numeric(8,4) DEFAULT 0,
    monthly_depreciation_pct numeric(8,4) DEFAULT 0,
    residual_pct character varying(20) DEFAULT '0%'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: asset_sub_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.asset_sub_categories_id_seq OWNED BY public.asset_sub_categories.id;


--
-- Name: asset_sub_categories id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.asset_sub_categories ALTER COLUMN id SET DEFAULT nextval('public.asset_sub_categories_id_seq'::regclass);


--
-- Name: asset_sub_categories asset_items_group_code_name_en_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_group_code_name_en_key UNIQUE (group_code, name_en);


--
-- Name: asset_sub_categories asset_items_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_pkey PRIMARY KEY (id);


--
-- Name: idx_asset_sub_categories_category_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_asset_sub_categories_category_id ON public.asset_sub_categories USING btree (category_id);


--
-- Name: idx_asset_sub_categories_group_code; Type: INDEX; Schema: public;
--

CREATE INDEX idx_asset_sub_categories_group_code ON public.asset_sub_categories USING btree (group_code);


--
-- Name: asset_sub_categories asset_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.asset_main_categories(id) ON DELETE CASCADE;


--
-- Name: asset_sub_categories Allow all access to asset_sub_categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to asset_sub_categories" ON public.asset_sub_categories USING (true) WITH CHECK (true);


--
-- Name: asset_sub_categories; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.asset_sub_categories ENABLE ROW LEVEL SECURITY;