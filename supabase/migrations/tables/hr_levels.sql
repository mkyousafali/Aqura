--
-- Name: hr_levels; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_levels (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    level_name_en character varying(100) NOT NULL,
    level_name_ar character varying(100) NOT NULL,
    level_order integer NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: hr_levels hr_levels_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_levels
    ADD CONSTRAINT hr_levels_pkey PRIMARY KEY (id);


--
-- Name: hr_levels Allow anon insert hr_levels; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_levels" ON public.hr_levels FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_levels allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_levels USING (true) WITH CHECK (true);


--
-- Name: hr_levels allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_levels FOR DELETE USING (true);


--
-- Name: hr_levels allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_levels FOR INSERT WITH CHECK (true);


--
-- Name: hr_levels allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_levels FOR SELECT USING (true);


--
-- Name: hr_levels allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_levels FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_levels anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_levels USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_levels authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_levels USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_levels; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_levels ENABLE ROW LEVEL SECURITY;