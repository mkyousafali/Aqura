--
-- Name: wa_contact_groups; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_contact_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    customer_count integer DEFAULT 0,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: wa_contact_groups wa_contact_groups_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_contact_groups
    ADD CONSTRAINT wa_contact_groups_pkey PRIMARY KEY (id);


--
-- Name: wa_contact_groups Service role full access on wa_contact_groups; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on wa_contact_groups" ON public.wa_contact_groups USING (true) WITH CHECK (true);


--
-- Name: wa_contact_groups; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_contact_groups ENABLE ROW LEVEL SECURITY;