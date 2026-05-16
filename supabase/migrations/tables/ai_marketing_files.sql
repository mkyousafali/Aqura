--
-- Name: ai_marketing_files; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_marketing_files (
    id bigint NOT NULL,
    name text NOT NULL,
    file_type text NOT NULL,
    file_data bytea,
    storage_path text,
    thumbnail_path text,
    mime_type text,
    file_size_bytes bigint,
    brand_id bigint,
    platform text,
    aspect_ratio text,
    duration_s integer,
    language text,
    price_before numeric,
    price_offer numeric,
    prompt text,
    additional_requirements text,
    speed_mode text,
    font_choice text,
    music_id bigint,
    music_mode text,
    edit_history jsonb DEFAULT '[]'::jsonb,
    folder text DEFAULT '/'::text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ai_marketing_files_file_type_check CHECK ((file_type = ANY (ARRAY['video'::text, 'poster'::text, 'branding_video'::text, 'branding_poster'::text]))),
    CONSTRAINT ai_marketing_files_music_mode_check CHECK ((music_mode = ANY (ARRAY['user'::text, 'ai'::text, 'none'::text])))
);


--
-- Name: ai_marketing_files ai_marketing_files_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_files
    ADD CONSTRAINT ai_marketing_files_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_marketing_files_brand; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_brand ON public.ai_marketing_files USING btree (brand_id);


--
-- Name: idx_ai_marketing_files_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_created ON public.ai_marketing_files USING btree (created_at DESC);


--
-- Name: idx_ai_marketing_files_folder; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_folder ON public.ai_marketing_files USING btree (folder);


--
-- Name: idx_ai_marketing_files_lang; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_lang ON public.ai_marketing_files USING btree (language);


--
-- Name: idx_ai_marketing_files_platform; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_platform ON public.ai_marketing_files USING btree (platform);


--
-- Name: idx_ai_marketing_files_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_files_type ON public.ai_marketing_files USING btree (file_type);


--
-- Name: ai_marketing_files trg_ai_marketing_files_touch; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_marketing_files_touch BEFORE UPDATE ON public.ai_marketing_files FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();


--
-- Name: ai_marketing_files ai_marketing_files_brand_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_files
    ADD CONSTRAINT ai_marketing_files_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL;


--
-- Name: ai_marketing_files ai_marketing_files_music_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_files
    ADD CONSTRAINT ai_marketing_files_music_id_fkey FOREIGN KEY (music_id) REFERENCES public.ai_music_library(id) ON DELETE SET NULL;


--
-- Name: ai_marketing_files; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_marketing_files ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_marketing_files allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_marketing_files FOR DELETE USING (true);


--
-- Name: ai_marketing_files allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_marketing_files FOR INSERT WITH CHECK (true);


--
-- Name: ai_marketing_files allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_marketing_files FOR SELECT USING (true);


--
-- Name: ai_marketing_files allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_marketing_files FOR UPDATE USING (true) WITH CHECK (true);