--
-- Name: flyer_offers; Type: TABLE; Schema: public;
--

CREATE TABLE public.flyer_offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id text DEFAULT (gen_random_uuid())::text NOT NULL,
    template_name text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    offer_name text,
    offer_name_id text,
    CONSTRAINT flyer_offers_dates_check CHECK ((end_date >= start_date))
);


--
-- Name: flyer_offers flyer_offers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_pkey PRIMARY KEY (id);


--
-- Name: flyer_offers flyer_offers_template_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_template_id_key UNIQUE (template_id);


--
-- Name: idx_flyer_offers_dates; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offers_dates ON public.flyer_offers USING btree (start_date, end_date);


--
-- Name: idx_flyer_offers_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offers_is_active ON public.flyer_offers USING btree (is_active);


--
-- Name: idx_flyer_offers_offer_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offers_offer_name ON public.flyer_offers USING btree (offer_name);


--
-- Name: idx_flyer_offers_offer_name_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offers_offer_name_id ON public.flyer_offers USING btree (offer_name_id);


--
-- Name: idx_flyer_offers_template_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_flyer_offers_template_id ON public.flyer_offers USING btree (template_id);


--
-- Name: flyer_offers update_flyer_offers_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_flyer_offers_updated_at BEFORE UPDATE ON public.flyer_offers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: flyer_offers flyer_offers_offer_name_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_offer_name_id_fkey FOREIGN KEY (offer_name_id) REFERENCES public.offer_names(id) ON DELETE SET NULL;


--
-- Name: flyer_offers Allow anon insert flyer_offers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert flyer_offers" ON public.flyer_offers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: flyer_offers allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.flyer_offers USING (true) WITH CHECK (true);


--
-- Name: flyer_offers allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.flyer_offers FOR DELETE USING (true);


--
-- Name: flyer_offers allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.flyer_offers FOR INSERT WITH CHECK (true);


--
-- Name: flyer_offers allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.flyer_offers FOR SELECT USING (true);


--
-- Name: flyer_offers allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.flyer_offers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: flyer_offers anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.flyer_offers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: flyer_offers authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.flyer_offers USING ((auth.uid() IS NOT NULL));


--
-- Name: flyer_offers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.flyer_offers ENABLE ROW LEVEL SECURITY;


--
-- Name: flyer_offers flyer_offers_delete_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offers_delete_policy ON public.flyer_offers FOR DELETE TO authenticated USING (true);


--
-- Name: flyer_offers flyer_offers_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offers_insert_policy ON public.flyer_offers FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: flyer_offers flyer_offers_select_all_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offers_select_all_policy ON public.flyer_offers FOR SELECT TO authenticated USING (true);


--
-- Name: flyer_offers flyer_offers_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offers_select_policy ON public.flyer_offers FOR SELECT USING ((is_active = true));


--
-- Name: flyer_offers flyer_offers_update_policy; Type: POLICY; Schema: public;
--

CREATE POLICY flyer_offers_update_policy ON public.flyer_offers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);