--
-- Name: wa_catalogs; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_catalogs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid NOT NULL,
    meta_catalog_id text,
    name text NOT NULL,
    description text,
    status text DEFAULT 'active'::text,
    product_count integer DEFAULT 0,
    synced_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: wa_catalogs wa_catalogs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_catalogs
    ADD CONSTRAINT wa_catalogs_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_catalogs_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_catalogs_account ON public.wa_catalogs USING btree (wa_account_id);


--
-- Name: wa_catalogs wa_catalogs_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_catalogs
    ADD CONSTRAINT wa_catalogs_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_catalogs Allow authenticated full access on wa_catalogs; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated full access on wa_catalogs" ON public.wa_catalogs TO authenticated USING (true) WITH CHECK (true);


--
-- Name: wa_catalogs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_catalogs ENABLE ROW LEVEL SECURITY;