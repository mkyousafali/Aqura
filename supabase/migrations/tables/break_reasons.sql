--
-- Name: break_reasons; Type: TABLE; Schema: public;
--

CREATE TABLE public.break_reasons (
    id integer NOT NULL,
    name_en character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    requires_note boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: break_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.break_reasons_id_seq OWNED BY public.break_reasons.id;


--
-- Name: break_reasons id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.break_reasons ALTER COLUMN id SET DEFAULT nextval('public.break_reasons_id_seq'::regclass);


--
-- Name: break_reasons break_reasons_name_en_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.break_reasons
    ADD CONSTRAINT break_reasons_name_en_unique UNIQUE (name_en);


--
-- Name: break_reasons break_reasons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.break_reasons
    ADD CONSTRAINT break_reasons_pkey PRIMARY KEY (id);


--
-- Name: break_reasons Allow all access to break_reasons; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to break_reasons" ON public.break_reasons USING (true) WITH CHECK (true);


--
-- Name: break_reasons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.break_reasons ENABLE ROW LEVEL SECURITY;