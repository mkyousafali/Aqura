--
-- Name: ai_notifications; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_notifications (
    id bigint NOT NULL,
    user_id uuid,
    type text NOT NULL,
    title text NOT NULL,
    message text,
    job_id bigint,
    file_id bigint,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_notifications ai_notifications_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_notifications
    ADD CONSTRAINT ai_notifications_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_notifications_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_notifications_user ON public.ai_notifications USING btree (user_id, is_read, created_at DESC);


--
-- Name: ai_notifications ai_notifications_file_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_notifications
    ADD CONSTRAINT ai_notifications_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE;


--
-- Name: ai_notifications ai_notifications_job_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_notifications
    ADD CONSTRAINT ai_notifications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.ai_generation_queue(id) ON DELETE CASCADE;


--
-- Name: ai_notifications; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_notifications ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_notifications allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_notifications FOR DELETE USING (true);


--
-- Name: ai_notifications allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_notifications FOR INSERT WITH CHECK (true);


--
-- Name: ai_notifications allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_notifications FOR SELECT USING (true);


--
-- Name: ai_notifications allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_notifications FOR UPDATE USING (true) WITH CHECK (true);