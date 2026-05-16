--
-- Name: overtime_registrations; Type: TABLE; Schema: public;
--

CREATE TABLE public.overtime_registrations (
    id text NOT NULL,
    employee_id text NOT NULL,
    overtime_date date NOT NULL,
    overtime_minutes integer DEFAULT 0 NOT NULL,
    worked_minutes integer DEFAULT 0,
    notes text,
    created_by text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: overtime_registrations overtime_registrations_employee_id_overtime_date_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_employee_id_overtime_date_key UNIQUE (employee_id, overtime_date);


--
-- Name: overtime_registrations overtime_registrations_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_pkey PRIMARY KEY (id);


--
-- Name: overtime_registrations overtime_registrations_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: overtime_registrations; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.overtime_registrations ENABLE ROW LEVEL SECURITY;


--
-- Name: overtime_registrations overtime_registrations_all; Type: POLICY; Schema: public;
--

CREATE POLICY overtime_registrations_all ON public.overtime_registrations USING (true) WITH CHECK (true);