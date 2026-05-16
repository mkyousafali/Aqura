--
-- Name: requesters; Type: TABLE; Schema: public;
--

CREATE TABLE public.requesters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_id character varying(50) NOT NULL,
    requester_name character varying(255) NOT NULL,
    contact_number character varying(20),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_by uuid,
    updated_by uuid
);


--
-- Name: requesters requesters_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.requesters
    ADD CONSTRAINT requesters_pkey PRIMARY KEY (id);


--
-- Name: requesters requesters_requester_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.requesters
    ADD CONSTRAINT requesters_requester_id_key UNIQUE (requester_id);


--
-- Name: idx_requesters_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requesters_name ON public.requesters USING btree (requester_name);


--
-- Name: idx_requesters_requester_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requesters_requester_id ON public.requesters USING btree (requester_id);


--
-- Name: requesters update_requesters_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_requesters_updated_at BEFORE UPDATE ON public.requesters FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: requesters Allow anon insert requesters; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert requesters" ON public.requesters FOR INSERT TO anon WITH CHECK (true);


--
-- Name: requesters Users can insert requesters; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can insert requesters" ON public.requesters FOR INSERT WITH CHECK (true);


--
-- Name: requesters Users can update requesters; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update requesters" ON public.requesters FOR UPDATE USING (true);


--
-- Name: requesters Users can view all requesters; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view all requesters" ON public.requesters FOR SELECT USING (true);


--
-- Name: requesters allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.requesters USING (true) WITH CHECK (true);


--
-- Name: requesters allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.requesters FOR DELETE USING (true);


--
-- Name: requesters allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.requesters FOR INSERT WITH CHECK (true);


--
-- Name: requesters allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.requesters FOR SELECT USING (true);


--
-- Name: requesters allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.requesters FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: requesters anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.requesters USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: requesters authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.requesters USING ((auth.uid() IS NOT NULL));


--
-- Name: requesters; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;