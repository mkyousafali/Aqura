--
-- Name: day_off_weekday; Type: TABLE; Schema: public;
--

CREATE TABLE public.day_off_weekday (
    id text NOT NULL,
    employee_id text NOT NULL,
    weekday integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT day_off_weekday_weekday_check CHECK (((weekday >= 0) AND (weekday <= 6)))
);


--
-- Name: day_off_weekday day_off_weekday_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT day_off_weekday_pkey PRIMARY KEY (id);


--
-- Name: day_off_weekday unique_employee_weekday_dayoff; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT unique_employee_weekday_dayoff UNIQUE (employee_id, weekday);


--
-- Name: idx_day_off_weekday_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_weekday_employee_id ON public.day_off_weekday USING btree (employee_id);


--
-- Name: idx_day_off_weekday_weekday; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_weekday_weekday ON public.day_off_weekday USING btree (weekday);


--
-- Name: day_off_weekday day_off_weekday_updated_at_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER day_off_weekday_updated_at_trigger BEFORE UPDATE ON public.day_off_weekday FOR EACH ROW EXECUTE FUNCTION public.update_day_off_weekday_updated_at();


--
-- Name: day_off_weekday day_off_weekday_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT day_off_weekday_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: day_off_weekday Allow all operations on day_off_weekday; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations on day_off_weekday" ON public.day_off_weekday USING (true) WITH CHECK (true);


--
-- Name: day_off_weekday; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.day_off_weekday ENABLE ROW LEVEL SECURITY;