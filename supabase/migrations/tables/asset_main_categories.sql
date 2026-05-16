--
-- Name: asset_main_categories; Type: TABLE; Schema: public;
--

CREATE TABLE public.asset_main_categories (
    id integer NOT NULL,
    group_code character varying(20) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: asset_main_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.asset_main_categories_id_seq OWNED BY public.asset_main_categories.id;


--
-- Name: asset_main_categories id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.asset_main_categories ALTER COLUMN id SET DEFAULT nextval('public.asset_main_categories_id_seq'::regclass);


--
-- Name: asset_main_categories asset_main_categories_group_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_group_code_key UNIQUE (group_code);


--
-- Name: asset_main_categories asset_main_categories_name_en_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_name_en_key UNIQUE (name_en);


--
-- Name: asset_main_categories asset_main_categories_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_pkey PRIMARY KEY (id);


--
-- Name: idx_asset_main_categories_group_code; Type: INDEX; Schema: public;
--

CREATE INDEX idx_asset_main_categories_group_code ON public.asset_main_categories USING btree (group_code);


--
-- Name: idx_asset_main_categories_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_asset_main_categories_name_en ON public.asset_main_categories USING btree (name_en);


--
-- Name: asset_main_categories Allow all access to asset_main_categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to asset_main_categories" ON public.asset_main_categories USING (true) WITH CHECK (true);


--
-- Name: asset_main_categories; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.asset_main_categories ENABLE ROW LEVEL SECURITY;