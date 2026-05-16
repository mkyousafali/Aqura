--
-- Name: hr_position_assignments; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_position_assignments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    employee_id uuid NOT NULL,
    position_id uuid NOT NULL,
    department_id uuid NOT NULL,
    level_id uuid NOT NULL,
    branch_id bigint NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    is_current boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: hr_position_assignments hr_position_assignments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_pkey PRIMARY KEY (id);


--
-- Name: idx_hr_assignments_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_assignments_branch_id ON public.hr_position_assignments USING btree (branch_id);


--
-- Name: idx_hr_assignments_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_assignments_employee_id ON public.hr_position_assignments USING btree (employee_id);


--
-- Name: hr_position_assignments hr_position_assignments_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: hr_position_assignments hr_position_assignments_department_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.hr_departments(id);


--
-- Name: hr_position_assignments hr_position_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employees(id);


--
-- Name: hr_position_assignments hr_position_assignments_level_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.hr_levels(id);


--
-- Name: hr_position_assignments hr_position_assignments_position_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_assignments Allow anon insert hr_position_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_position_assignments" ON public.hr_position_assignments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_position_assignments allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_position_assignments USING (true) WITH CHECK (true);


--
-- Name: hr_position_assignments allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_position_assignments FOR DELETE USING (true);


--
-- Name: hr_position_assignments allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_position_assignments FOR INSERT WITH CHECK (true);


--
-- Name: hr_position_assignments allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_position_assignments FOR SELECT USING (true);


--
-- Name: hr_position_assignments allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_position_assignments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_position_assignments anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_position_assignments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_position_assignments authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_position_assignments USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_position_assignments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_position_assignments ENABLE ROW LEVEL SECURITY;