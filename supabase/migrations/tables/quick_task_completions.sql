--
-- Name: quick_task_completions; Type: TABLE; Schema: public;
--

CREATE TABLE public.quick_task_completions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quick_task_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    completed_by_user_id uuid NOT NULL,
    completion_notes text,
    photo_path text,
    erp_reference character varying(255),
    completion_status character varying(50) DEFAULT 'submitted'::character varying NOT NULL,
    verified_by_user_id uuid,
    verified_at timestamp with time zone,
    verification_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_completion_status_valid CHECK (((completion_status)::text = ANY (ARRAY[('submitted'::character varying)::text, ('verified'::character varying)::text, ('rejected'::character varying)::text, ('pending_review'::character varying)::text]))),
    CONSTRAINT chk_verified_at_when_verified CHECK (((((completion_status)::text <> 'verified'::text) AND (verified_at IS NULL)) OR (((completion_status)::text = 'verified'::text) AND (verified_at IS NOT NULL))))
);


--
-- Name: quick_task_completions quick_task_completions_assignment_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_assignment_unique UNIQUE (assignment_id);


--
-- Name: quick_task_completions quick_task_completions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_pkey PRIMARY KEY (id);


--
-- Name: idx_quick_task_completions_assignment; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_assignment ON public.quick_task_completions USING btree (assignment_id);


--
-- Name: idx_quick_task_completions_completed_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_completed_by ON public.quick_task_completions USING btree (completed_by_user_id);


--
-- Name: idx_quick_task_completions_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_created_at ON public.quick_task_completions USING btree (created_at DESC);


--
-- Name: idx_quick_task_completions_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_status ON public.quick_task_completions USING btree (completion_status);


--
-- Name: idx_quick_task_completions_task; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_task ON public.quick_task_completions USING btree (quick_task_id);


--
-- Name: idx_quick_task_completions_verified_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_quick_task_completions_verified_by ON public.quick_task_completions USING btree (verified_by_user_id) WHERE (verified_by_user_id IS NOT NULL);


--
-- Name: quick_task_completions trigger_update_quick_task_completions_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_quick_task_completions_updated_at BEFORE UPDATE ON public.quick_task_completions FOR EACH ROW EXECUTE FUNCTION public.update_quick_task_completions_updated_at();


--
-- Name: quick_task_completions quick_task_completions_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.quick_task_assignments(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_completed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_completed_by_user_id_fkey FOREIGN KEY (completed_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_verified_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_verified_by_user_id_fkey FOREIGN KEY (verified_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: quick_task_completions Allow anon insert quick_task_completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert quick_task_completions" ON public.quick_task_completions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_completions Allow service role full access to quick_task_completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role full access to quick_task_completions" ON public.quick_task_completions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions Managers can verify completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Managers can verify completions" ON public.quick_task_completions FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: quick_task_completions Managers can view all completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Managers can view all completions" ON public.quick_task_completions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: quick_task_completions Users can insert their own completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can insert their own completions" ON public.quick_task_completions FOR INSERT WITH CHECK ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_completions Users can update their own completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can update their own completions" ON public.quick_task_completions FOR UPDATE USING ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_completions Users can view their own completions; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view their own completions" ON public.quick_task_completions FOR SELECT USING ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_completions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.quick_task_completions USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.quick_task_completions FOR DELETE USING (true);


--
-- Name: quick_task_completions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.quick_task_completions FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_completions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.quick_task_completions FOR SELECT USING (true);


--
-- Name: quick_task_completions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.quick_task_completions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.quick_task_completions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_completions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.quick_task_completions USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_completions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.quick_task_completions ENABLE ROW LEVEL SECURITY;