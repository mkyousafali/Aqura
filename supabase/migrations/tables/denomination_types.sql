--
-- Name: denomination_types; Type: TABLE; Schema: public;
--

CREATE TABLE public.denomination_types (
    id integer NOT NULL,
    code character varying(20) NOT NULL,
    value numeric(10,2) NOT NULL,
    label character varying(50) NOT NULL,
    label_ar character varying(50),
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: denomination_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.denomination_types_id_seq OWNED BY public.denomination_types.id;


--
-- Name: denomination_types id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.denomination_types ALTER COLUMN id SET DEFAULT nextval('public.denomination_types_id_seq'::regclass);


--
-- Name: denomination_types denomination_types_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_types
    ADD CONSTRAINT denomination_types_code_key UNIQUE (code);


--
-- Name: denomination_types denomination_types_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_types
    ADD CONSTRAINT denomination_types_pkey PRIMARY KEY (id);


--
-- Name: idx_denomination_types_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_types_active ON public.denomination_types USING btree (is_active, sort_order);


--
-- Name: denomination_types denomination_types_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER denomination_types_updated_at BEFORE UPDATE ON public.denomination_types FOR EACH ROW EXECUTE FUNCTION public.update_denomination_updated_at();


--
-- Name: denomination_types; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.denomination_types ENABLE ROW LEVEL SECURITY;


--
-- Name: denomination_types denomination_types_delete; Type: POLICY; Schema: public;
--

CREATE POLICY denomination_types_delete ON public.denomination_types FOR DELETE USING (true);


--
-- Name: denomination_types denomination_types_insert; Type: POLICY; Schema: public;
--

CREATE POLICY denomination_types_insert ON public.denomination_types FOR INSERT WITH CHECK (true);


--
-- Name: denomination_types denomination_types_select; Type: POLICY; Schema: public;
--

CREATE POLICY denomination_types_select ON public.denomination_types FOR SELECT USING (true);


--
-- Name: denomination_types denomination_types_update; Type: POLICY; Schema: public;
--

CREATE POLICY denomination_types_update ON public.denomination_types FOR UPDATE USING (true);