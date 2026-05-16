--
-- Name: privilege_cards_master; Type: TABLE; Schema: public;
--

CREATE TABLE public.privilege_cards_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    card_number character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: privilege_cards_master privilege_cards_master_card_number_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.privilege_cards_master
    ADD CONSTRAINT privilege_cards_master_card_number_key UNIQUE (card_number);


--
-- Name: privilege_cards_master privilege_cards_master_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.privilege_cards_master
    ADD CONSTRAINT privilege_cards_master_pkey PRIMARY KEY (id);


--
-- Name: idx_privilege_cards_master_card_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_privilege_cards_master_card_number ON public.privilege_cards_master USING btree (card_number);


--
-- Name: privilege_cards_master Allow anon insert privilege_cards_master; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO anon WITH CHECK (true);


--
-- Name: privilege_cards_master Allow authenticated users to create privilege_cards_master; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: privilege_cards_master Allow authenticated users to read privilege_cards_master; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read privilege_cards_master" ON public.privilege_cards_master FOR SELECT TO authenticated USING (true);


--
-- Name: privilege_cards_master Allow authenticated users to update privilege_cards_master; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update privilege_cards_master" ON public.privilege_cards_master FOR UPDATE TO authenticated USING (true);


--
-- Name: privilege_cards_master Service role has full access to privilege_cards_master; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role has full access to privilege_cards_master" ON public.privilege_cards_master TO service_role USING (true);


--
-- Name: privilege_cards_master allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.privilege_cards_master USING (true);


--
-- Name: privilege_cards_master allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.privilege_cards_master FOR DELETE USING (true);


--
-- Name: privilege_cards_master allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.privilege_cards_master FOR INSERT WITH CHECK (true);


--
-- Name: privilege_cards_master allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.privilege_cards_master FOR SELECT USING (true);


--
-- Name: privilege_cards_master allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.privilege_cards_master FOR UPDATE USING (true);


--
-- Name: privilege_cards_master anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.privilege_cards_master USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: privilege_cards_master authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.privilege_cards_master USING ((auth.uid() IS NOT NULL));


--
-- Name: privilege_cards_master; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.privilege_cards_master ENABLE ROW LEVEL SECURITY;