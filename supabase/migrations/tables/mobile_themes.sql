--
-- Name: mobile_themes; Type: TABLE; Schema: public;
--

CREATE TABLE public.mobile_themes (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    is_default boolean DEFAULT false,
    colors jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid
);


--
-- Name: mobile_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.mobile_themes_id_seq OWNED BY public.mobile_themes.id;


--
-- Name: mobile_themes id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.mobile_themes ALTER COLUMN id SET DEFAULT nextval('public.mobile_themes_id_seq'::regclass);


--
-- Name: mobile_themes mobile_themes_name_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_name_key UNIQUE (name);


--
-- Name: mobile_themes mobile_themes_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_pkey PRIMARY KEY (id);


--
-- Name: idx_mobile_themes_is_default; Type: INDEX; Schema: public;
--

CREATE INDEX idx_mobile_themes_is_default ON public.mobile_themes USING btree (is_default);


--
-- Name: mobile_themes mobile_themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mobile_themes Allow all access to mobile_themes; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to mobile_themes" ON public.mobile_themes USING (true) WITH CHECK (true);


--
-- Name: mobile_themes; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.mobile_themes ENABLE ROW LEVEL SECURITY;