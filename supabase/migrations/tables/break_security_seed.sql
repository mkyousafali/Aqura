--
-- Name: break_security_seed; Type: TABLE; Schema: public;
--

CREATE TABLE public.break_security_seed (
    id integer DEFAULT 1 NOT NULL,
    seed text DEFAULT encode(extensions.gen_random_bytes(32), 'hex'::text) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT break_security_seed_id_check CHECK ((id = 1))
);


--
-- Name: break_security_seed break_security_seed_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.break_security_seed
    ADD CONSTRAINT break_security_seed_pkey PRIMARY KEY (id);


--
-- Name: break_security_seed; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.break_security_seed ENABLE ROW LEVEL SECURITY;