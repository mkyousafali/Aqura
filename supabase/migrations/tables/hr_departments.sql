--
-- Name: hr_departments; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_departments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    department_name_en character varying(100) NOT NULL,
    department_name_ar character varying(100) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: hr_departments hr_departments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_departments
    ADD CONSTRAINT hr_departments_pkey PRIMARY KEY (id);


--
-- Name: hr_departments Allow anon insert hr_departments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_departments" ON public.hr_departments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_departments allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_departments USING (true) WITH CHECK (true);


--
-- Name: hr_departments allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_departments FOR DELETE USING (true);


--
-- Name: hr_departments allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_departments FOR INSERT WITH CHECK (true);


--
-- Name: hr_departments allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_departments FOR SELECT USING (true);


--
-- Name: hr_departments allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_departments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_departments anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_departments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_departments authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_departments USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_departments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_departments ENABLE ROW LEVEL SECURITY;