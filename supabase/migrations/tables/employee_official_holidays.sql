--
-- Name: employee_official_holidays; Type: TABLE; Schema: public;
--

CREATE TABLE public.employee_official_holidays (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    employee_id text NOT NULL,
    official_holiday_id text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: employee_official_holidays employee_official_holidays_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_pkey PRIMARY KEY (id);


--
-- Name: employee_official_holidays unique_employee_official_holiday; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT unique_employee_official_holiday UNIQUE (employee_id, official_holiday_id);


--
-- Name: idx_eoh_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_eoh_employee_id ON public.employee_official_holidays USING btree (employee_id);


--
-- Name: idx_eoh_holiday_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_eoh_holiday_id ON public.employee_official_holidays USING btree (official_holiday_id);


--
-- Name: employee_official_holidays employee_official_holidays_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: employee_official_holidays employee_official_holidays_official_holiday_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_official_holiday_id_fkey FOREIGN KEY (official_holiday_id) REFERENCES public.official_holidays(id) ON DELETE CASCADE;


--
-- Name: employee_official_holidays Allow all operations on employee_official_holidays; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations on employee_official_holidays" ON public.employee_official_holidays USING (true) WITH CHECK (true);


--
-- Name: employee_official_holidays; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.employee_official_holidays ENABLE ROW LEVEL SECURITY;