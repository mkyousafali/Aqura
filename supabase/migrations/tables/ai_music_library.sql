--
-- Name: ai_music_library; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_music_library (
    id bigint NOT NULL,
    name text NOT NULL,
    file_url text NOT NULL,
    duration_s integer,
    mood text,
    tags text[] DEFAULT '{}'::text[],
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_music_library ai_music_library_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_music_library
    ADD CONSTRAINT ai_music_library_pkey PRIMARY KEY (id);


--
-- Name: ai_music_library; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_music_library ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_music_library allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_music_library FOR DELETE USING (true);


--
-- Name: ai_music_library allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_music_library FOR INSERT WITH CHECK (true);


--
-- Name: ai_music_library allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_music_library FOR SELECT USING (true);


--
-- Name: ai_music_library allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_music_library FOR UPDATE USING (true) WITH CHECK (true);