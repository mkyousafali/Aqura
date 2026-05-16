--
-- Name: frontend_builds; Type: TABLE; Schema: public;
--

CREATE TABLE public.frontend_builds (
    id integer NOT NULL,
    version text NOT NULL,
    file_name text NOT NULL,
    file_size bigint DEFAULT 0 NOT NULL,
    storage_path text NOT NULL,
    notes text,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: frontend_builds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.frontend_builds_id_seq OWNED BY public.frontend_builds.id;


--
-- Name: frontend_builds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.frontend_builds ALTER COLUMN id SET DEFAULT nextval('public.frontend_builds_id_seq'::regclass);


--
-- Name: frontend_builds frontend_builds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.frontend_builds
    ADD CONSTRAINT frontend_builds_pkey PRIMARY KEY (id);


--
-- Name: frontend_builds frontend_builds_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.frontend_builds
    ADD CONSTRAINT frontend_builds_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id);


--
-- Name: frontend_builds Authenticated users can insert frontend_builds; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can insert frontend_builds" ON public.frontend_builds FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: frontend_builds Authenticated users can read frontend_builds; Type: POLICY; Schema: public;
--

CREATE POLICY "Authenticated users can read frontend_builds" ON public.frontend_builds FOR SELECT TO authenticated USING (true);


--
-- Name: frontend_builds Service role full access to frontend_builds; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access to frontend_builds" ON public.frontend_builds TO service_role USING (true) WITH CHECK (true);


--
-- Name: frontend_builds; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.frontend_builds ENABLE ROW LEVEL SECURITY;