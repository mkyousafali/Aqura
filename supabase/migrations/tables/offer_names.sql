--
-- Name: offer_names; Type: TABLE; Schema: public;
--

CREATE TABLE public.offer_names (
    id text NOT NULL,
    name_en text NOT NULL,
    name_ar text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: offer_names offer_names_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_names
    ADD CONSTRAINT offer_names_pkey PRIMARY KEY (id);


--
-- Name: offer_names Allow all access to offer_names; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to offer_names" ON public.offer_names USING (true) WITH CHECK (true);


--
-- Name: offer_names; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.offer_names ENABLE ROW LEVEL SECURITY;