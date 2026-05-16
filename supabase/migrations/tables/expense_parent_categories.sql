--
-- Name: expense_parent_categories; Type: TABLE; Schema: public;
--

CREATE TABLE public.expense_parent_categories (
    id bigint NOT NULL,
    name_en text NOT NULL,
    name_ar text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true
);


--
-- Name: expense_parent_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.expense_parent_categories_id_seq OWNED BY public.expense_parent_categories.id;


--
-- Name: expense_parent_categories id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.expense_parent_categories ALTER COLUMN id SET DEFAULT nextval('public.expense_parent_categories_id_seq'::regclass);


--
-- Name: expense_parent_categories expense_parent_categories_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_parent_categories
    ADD CONSTRAINT expense_parent_categories_pkey PRIMARY KEY (id);


--
-- Name: idx_expense_parent_categories_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_parent_categories_is_active ON public.expense_parent_categories USING btree (is_active);


--
-- Name: expense_parent_categories Allow admin users to delete parent categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow admin users to delete parent categories" ON public.expense_parent_categories FOR DELETE TO authenticated USING (true);


--
-- Name: expense_parent_categories Allow admin users to insert parent categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow admin users to insert parent categories" ON public.expense_parent_categories FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_parent_categories Allow admin users to update parent categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow admin users to update parent categories" ON public.expense_parent_categories FOR UPDATE TO authenticated USING (true);


--
-- Name: expense_parent_categories Allow anon insert expense_parent_categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert expense_parent_categories" ON public.expense_parent_categories FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_parent_categories Allow authenticated users to read parent categories; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read parent categories" ON public.expense_parent_categories FOR SELECT TO authenticated USING (true);


--
-- Name: expense_parent_categories allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.expense_parent_categories USING (true) WITH CHECK (true);


--
-- Name: expense_parent_categories allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.expense_parent_categories FOR DELETE USING (true);


--
-- Name: expense_parent_categories allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.expense_parent_categories FOR INSERT WITH CHECK (true);


--
-- Name: expense_parent_categories allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.expense_parent_categories FOR SELECT USING (true);


--
-- Name: expense_parent_categories allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.expense_parent_categories FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_parent_categories anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.expense_parent_categories USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_parent_categories authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.expense_parent_categories USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_parent_categories; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.expense_parent_categories ENABLE ROW LEVEL SECURITY;