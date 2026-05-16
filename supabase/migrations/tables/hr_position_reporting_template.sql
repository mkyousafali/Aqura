--
-- Name: hr_position_reporting_template; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_position_reporting_template (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    subordinate_position_id uuid NOT NULL,
    manager_position_1 uuid,
    manager_position_2 uuid,
    manager_position_3 uuid,
    manager_position_4 uuid,
    manager_position_5 uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_no_self_report_1 CHECK ((subordinate_position_id <> manager_position_1)),
    CONSTRAINT chk_no_self_report_2 CHECK ((subordinate_position_id <> manager_position_2)),
    CONSTRAINT chk_no_self_report_3 CHECK ((subordinate_position_id <> manager_position_3)),
    CONSTRAINT chk_no_self_report_4 CHECK ((subordinate_position_id <> manager_position_4)),
    CONSTRAINT chk_no_self_report_5 CHECK ((subordinate_position_id <> manager_position_5))
);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_pkey PRIMARY KEY (id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_subordinate_position_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_subordinate_position_id_key UNIQUE (subordinate_position_id);


--
-- Name: idx_hr_position_template_mgr1; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_mgr1 ON public.hr_position_reporting_template USING btree (manager_position_1);


--
-- Name: idx_hr_position_template_mgr2; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_mgr2 ON public.hr_position_reporting_template USING btree (manager_position_2);


--
-- Name: idx_hr_position_template_mgr3; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_mgr3 ON public.hr_position_reporting_template USING btree (manager_position_3);


--
-- Name: idx_hr_position_template_mgr4; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_mgr4 ON public.hr_position_reporting_template USING btree (manager_position_4);


--
-- Name: idx_hr_position_template_mgr5; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_mgr5 ON public.hr_position_reporting_template USING btree (manager_position_5);


--
-- Name: idx_hr_position_template_subordinate; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_position_template_subordinate ON public.hr_position_reporting_template USING btree (subordinate_position_id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_1_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_1_fkey FOREIGN KEY (manager_position_1) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_2_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_2_fkey FOREIGN KEY (manager_position_2) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_3_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_3_fkey FOREIGN KEY (manager_position_3) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_4_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_4_fkey FOREIGN KEY (manager_position_4) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_5_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_5_fkey FOREIGN KEY (manager_position_5) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_subordinate_position_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_subordinate_position_id_fkey FOREIGN KEY (subordinate_position_id) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template Allow anon insert hr_position_reporting_template; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_position_reporting_template" ON public.hr_position_reporting_template FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_position_reporting_template USING (true) WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_position_reporting_template FOR DELETE USING (true);


--
-- Name: hr_position_reporting_template allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_position_reporting_template FOR INSERT WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_position_reporting_template FOR SELECT USING (true);


--
-- Name: hr_position_reporting_template allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_position_reporting_template FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_position_reporting_template anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_position_reporting_template USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_position_reporting_template authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_position_reporting_template USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_position_reporting_template; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_position_reporting_template ENABLE ROW LEVEL SECURITY;