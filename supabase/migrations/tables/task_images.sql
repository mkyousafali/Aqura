--
-- Name: task_images; Type: TABLE; Schema: public;
--

CREATE TABLE public.task_images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    file_name text NOT NULL,
    file_size bigint NOT NULL,
    file_type text NOT NULL,
    file_url text NOT NULL,
    image_type text NOT NULL,
    uploaded_by text NOT NULL,
    uploaded_by_name text,
    created_at timestamp with time zone DEFAULT now(),
    image_width integer,
    image_height integer,
    file_path text,
    attachment_type text DEFAULT 'task_creation'::text,
    CONSTRAINT task_images_attachment_type_check CHECK ((attachment_type = ANY (ARRAY['task_creation'::text, 'task_completion'::text])))
);


--
-- Name: task_images task_images_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_images
    ADD CONSTRAINT task_images_pkey PRIMARY KEY (id);


--
-- Name: idx_task_images_attachment_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_images_attachment_type ON public.task_images USING btree (attachment_type);


--
-- Name: idx_task_images_image_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_images_image_type ON public.task_images USING btree (image_type);


--
-- Name: idx_task_images_task_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_images_task_id ON public.task_images USING btree (task_id);


--
-- Name: idx_task_images_uploaded_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_task_images_uploaded_by ON public.task_images USING btree (uploaded_by);


--
-- Name: task_images task_images_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.task_images
    ADD CONSTRAINT task_images_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_images Allow anon insert task_images; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert task_images" ON public.task_images FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_images Simple create task images policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple create task images policy" ON public.task_images FOR INSERT WITH CHECK (true);


--
-- Name: task_images Simple delete task images policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple delete task images policy" ON public.task_images FOR DELETE USING (true);


--
-- Name: task_images Simple update task images policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple update task images policy" ON public.task_images FOR UPDATE USING (true);


--
-- Name: task_images Simple view task images policy; Type: POLICY; Schema: public;
--

CREATE POLICY "Simple view task images policy" ON public.task_images FOR SELECT USING (true);


--
-- Name: task_images allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.task_images USING (true) WITH CHECK (true);


--
-- Name: task_images allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.task_images FOR DELETE USING (true);


--
-- Name: task_images allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.task_images FOR INSERT WITH CHECK (true);


--
-- Name: task_images allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.task_images FOR SELECT USING (true);


--
-- Name: task_images allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.task_images FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_images anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.task_images USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_images authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.task_images USING ((auth.uid() IS NOT NULL));


--
-- Name: task_images; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;