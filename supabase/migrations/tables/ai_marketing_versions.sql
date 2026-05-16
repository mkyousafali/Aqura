--
-- Name: ai_marketing_versions; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_marketing_versions (
    id bigint NOT NULL,
    file_id bigint NOT NULL,
    version_no integer NOT NULL,
    file_data bytea,
    storage_path text,
    thumbnail_path text,
    prompt text,
    edit_note text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_marketing_versions ai_marketing_versions_file_id_version_no_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_versions
    ADD CONSTRAINT ai_marketing_versions_file_id_version_no_key UNIQUE (file_id, version_no);


--
-- Name: ai_marketing_versions ai_marketing_versions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_versions
    ADD CONSTRAINT ai_marketing_versions_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_marketing_versions_file; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_versions_file ON public.ai_marketing_versions USING btree (file_id, version_no DESC);


--
-- Name: ai_marketing_versions ai_marketing_versions_file_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_versions
    ADD CONSTRAINT ai_marketing_versions_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE;


--
-- Name: ai_marketing_versions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_marketing_versions ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_marketing_versions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_marketing_versions FOR DELETE USING (true);


--
-- Name: ai_marketing_versions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_marketing_versions FOR INSERT WITH CHECK (true);


--
-- Name: ai_marketing_versions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_marketing_versions FOR SELECT USING (true);


--
-- Name: ai_marketing_versions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_marketing_versions FOR UPDATE USING (true) WITH CHECK (true);