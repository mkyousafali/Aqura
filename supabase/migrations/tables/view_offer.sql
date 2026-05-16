--
-- Name: view_offer; Type: TABLE; Schema: public;
--

CREATE TABLE public.view_offer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_name character varying(255) NOT NULL,
    branch_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    file_url text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    start_time time without time zone DEFAULT '00:00:00'::time without time zone,
    end_time time without time zone DEFAULT '23:59:00'::time without time zone,
    thumbnail_url text,
    view_button_count integer DEFAULT 0,
    page_visit_count integer DEFAULT 0
);


--
-- Name: view_offer view_offer_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.view_offer
    ADD CONSTRAINT view_offer_pkey PRIMARY KEY (id);


--
-- Name: idx_view_offer_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_view_offer_branch_id ON public.view_offer USING btree (branch_id);


--
-- Name: idx_view_offer_dates; Type: INDEX; Schema: public;
--

CREATE INDEX idx_view_offer_dates ON public.view_offer USING btree (start_date, end_date);


--
-- Name: idx_view_offer_datetime; Type: INDEX; Schema: public;
--

CREATE INDEX idx_view_offer_datetime ON public.view_offer USING btree (start_date, start_time, end_date, end_time);


--
-- Name: view_offer view_offer_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.view_offer
    ADD CONSTRAINT view_offer_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: view_offer Allow anon insert view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: view_offer Allow authenticated users to create view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: view_offer Allow authenticated users to read view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read view_offer" ON public.view_offer FOR SELECT USING (true);


--
-- Name: view_offer Allow authenticated users to update view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update view_offer" ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: view_offer Enable all access for view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable all access for view_offer" ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: view_offer Service role has full access to view_offer; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role has full access to view_offer" ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: view_offer allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: view_offer allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.view_offer FOR DELETE USING (true);


--
-- Name: view_offer allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: view_offer allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.view_offer FOR SELECT USING (true);


--
-- Name: view_offer allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: view_offer anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.view_offer USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: view_offer authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.view_offer USING ((auth.uid() IS NOT NULL));


--
-- Name: view_offer; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.view_offer ENABLE ROW LEVEL SECURITY;