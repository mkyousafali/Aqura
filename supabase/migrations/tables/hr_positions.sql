--
-- Name: hr_positions; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_positions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    position_title_en character varying(100) NOT NULL,
    position_title_ar character varying(100) NOT NULL,
    department_id uuid NOT NULL,
    level_id uuid NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: hr_positions hr_positions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_pkey PRIMARY KEY (id);


--
-- Name: hr_positions sync_roles_on_position_changes; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER sync_roles_on_position_changes AFTER INSERT OR DELETE OR UPDATE ON public.hr_positions FOR EACH ROW EXECUTE FUNCTION public.sync_user_roles_from_positions();


--
-- Name: hr_positions hr_positions_department_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.hr_departments(id);


--
-- Name: hr_positions hr_positions_level_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.hr_levels(id);


--
-- Name: hr_positions Allow anon insert hr_positions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_positions" ON public.hr_positions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_positions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_positions USING (true) WITH CHECK (true);


--
-- Name: hr_positions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_positions FOR DELETE USING (true);


--
-- Name: hr_positions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_positions FOR INSERT WITH CHECK (true);


--
-- Name: hr_positions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_positions FOR SELECT USING (true);


--
-- Name: hr_positions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_positions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_positions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_positions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_positions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_positions USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_positions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_positions ENABLE ROW LEVEL SECURITY;