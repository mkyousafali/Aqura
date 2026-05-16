--
-- Name: deleted_bundle_offers; Type: TABLE; Schema: public;
--

CREATE TABLE public.deleted_bundle_offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_offer_id integer NOT NULL,
    offer_data jsonb NOT NULL,
    bundles_data jsonb NOT NULL,
    deleted_at timestamp with time zone DEFAULT now(),
    deleted_by uuid,
    deletion_reason text
);


--
-- Name: deleted_bundle_offers deleted_bundle_offers_original_offer_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_original_offer_id_key UNIQUE (original_offer_id);


--
-- Name: deleted_bundle_offers deleted_bundle_offers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_pkey PRIMARY KEY (id);


--
-- Name: idx_deleted_bundle_offers_deleted_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_deleted_bundle_offers_deleted_at ON public.deleted_bundle_offers USING btree (deleted_at DESC);


--
-- Name: idx_deleted_bundle_offers_deleted_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_deleted_bundle_offers_deleted_by ON public.deleted_bundle_offers USING btree (deleted_by);


--
-- Name: idx_deleted_bundle_offers_original_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_deleted_bundle_offers_original_id ON public.deleted_bundle_offers USING btree (original_offer_id);


--
-- Name: deleted_bundle_offers deleted_bundle_offers_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: deleted_bundle_offers Allow anon insert deleted_bundle_offers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert deleted_bundle_offers" ON public.deleted_bundle_offers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: deleted_bundle_offers Allow authenticated users to archive offers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to archive offers" ON public.deleted_bundle_offers FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: deleted_bundle_offers Allow authenticated users to view deleted offers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to view deleted offers" ON public.deleted_bundle_offers FOR SELECT TO authenticated USING (true);


--
-- Name: deleted_bundle_offers allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.deleted_bundle_offers USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.deleted_bundle_offers FOR DELETE USING (true);


--
-- Name: deleted_bundle_offers allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.deleted_bundle_offers FOR INSERT WITH CHECK (true);


--
-- Name: deleted_bundle_offers allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.deleted_bundle_offers FOR SELECT USING (true);


--
-- Name: deleted_bundle_offers allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.deleted_bundle_offers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.deleted_bundle_offers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: deleted_bundle_offers authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.deleted_bundle_offers USING ((auth.uid() IS NOT NULL));


--
-- Name: deleted_bundle_offers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.deleted_bundle_offers ENABLE ROW LEVEL SECURITY;