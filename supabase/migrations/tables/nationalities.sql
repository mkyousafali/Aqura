--
-- Name: nationalities; Type: TABLE; Schema: public;
--

CREATE TABLE public.nationalities (
    id character varying(10) NOT NULL,
    name_en character varying(100) NOT NULL,
    name_ar character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: nationalities nationalities_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.nationalities
    ADD CONSTRAINT nationalities_pkey PRIMARY KEY (id);


--
-- Name: nationalities Allow all access to nationalities; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to nationalities" ON public.nationalities USING (true) WITH CHECK (true);


--
-- Name: nationalities; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.nationalities ENABLE ROW LEVEL SECURITY;