--
-- Name: quick_task_comments; Type: TABLE; Schema: public;
--

CREATE TABLE public.quick_task_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quick_task_id uuid NOT NULL,
    comment text NOT NULL,
    comment_type character varying(50) DEFAULT 'comment'::character varying,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: quick_task_comments quick_task_comments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_pkey PRIMARY KEY (id);


--
-- Name: idx_quick_task_comments_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_comments_created_by ON public.quick_task_comments USING btree (created_by);


--
-- Name: idx_quick_task_comments_task; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_comments_task ON public.quick_task_comments USING btree (quick_task_id);


--
-- Name: quick_task_comments quick_task_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: quick_task_comments quick_task_comments_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_comments Allow anon insert quick_task_comments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert quick_task_comments" ON public.quick_task_comments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_comments allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.quick_task_comments USING (true) WITH CHECK (true);


--
-- Name: quick_task_comments allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.quick_task_comments FOR DELETE USING (true);


--
-- Name: quick_task_comments allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.quick_task_comments FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_comments allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.quick_task_comments FOR SELECT USING (true);


--
-- Name: quick_task_comments allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.quick_task_comments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_comments anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.quick_task_comments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_comments authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.quick_task_comments USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_comments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.quick_task_comments ENABLE ROW LEVEL SECURITY;