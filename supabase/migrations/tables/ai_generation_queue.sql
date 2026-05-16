--
-- Name: ai_generation_queue; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_generation_queue (
    id bigint NOT NULL,
    job_type text NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    priority integer DEFAULT 0,
    brand_id bigint,
    product_ids character varying[] DEFAULT '{}'::character varying[],
    platform text,
    aspect_ratio text,
    duration_s integer,
    language text,
    speed_mode text,
    prompt text,
    additional_inputs jsonb DEFAULT '{}'::jsonb,
    clarifications jsonb DEFAULT '[]'::jsonb,
    result_file_id bigint,
    error_message text,
    progress_pct integer DEFAULT 0,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ai_generation_queue_job_type_check CHECK ((job_type = ANY (ARRAY['video'::text, 'poster'::text, 'branding_video'::text, 'branding_poster'::text]))),
    CONSTRAINT ai_generation_queue_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'paused'::text, 'completed'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: ai_generation_queue ai_generation_queue_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_generation_queue
    ADD CONSTRAINT ai_generation_queue_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_queue_priority; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_queue_priority ON public.ai_generation_queue USING btree (priority DESC, created_at);


--
-- Name: idx_ai_queue_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_queue_status ON public.ai_generation_queue USING btree (status);


--
-- Name: idx_ai_queue_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_queue_user ON public.ai_generation_queue USING btree (created_by, status);


--
-- Name: ai_generation_queue trg_ai_generation_queue_touch; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_ai_generation_queue_touch BEFORE UPDATE ON public.ai_generation_queue FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();


--
-- Name: ai_generation_queue ai_generation_queue_brand_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_generation_queue
    ADD CONSTRAINT ai_generation_queue_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL;


--
-- Name: ai_generation_queue ai_generation_queue_result_file_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_generation_queue
    ADD CONSTRAINT ai_generation_queue_result_file_id_fkey FOREIGN KEY (result_file_id) REFERENCES public.ai_marketing_files(id) ON DELETE SET NULL;


--
-- Name: ai_generation_queue; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_generation_queue ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_generation_queue allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_generation_queue FOR DELETE USING (true);


--
-- Name: ai_generation_queue allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_generation_queue FOR INSERT WITH CHECK (true);


--
-- Name: ai_generation_queue allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_generation_queue FOR SELECT USING (true);


--
-- Name: ai_generation_queue allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_generation_queue FOR UPDATE USING (true) WITH CHECK (true);