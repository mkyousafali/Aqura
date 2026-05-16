--
-- Name: special_shift_date_wise; Type: TABLE; Schema: public;
--

CREATE TABLE public.special_shift_date_wise (
    id text NOT NULL,
    employee_id text NOT NULL,
    shift_date date NOT NULL,
    shift_start_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    shift_start_buffer numeric(4,2) DEFAULT 0,
    shift_end_time time without time zone DEFAULT '17:00:00'::time without time zone NOT NULL,
    shift_end_buffer numeric(4,2) DEFAULT 0,
    is_shift_overlapping_next_day boolean DEFAULT false,
    working_hours numeric(5,2) DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: special_shift_date_wise special_shift_date_wise_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT special_shift_date_wise_pkey PRIMARY KEY (id);


--
-- Name: special_shift_date_wise unique_employee_date; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT unique_employee_date UNIQUE (employee_id, shift_date);


--
-- Name: idx_special_shift_date_wise_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_special_shift_date_wise_date ON public.special_shift_date_wise USING btree (shift_date);


--
-- Name: idx_special_shift_date_wise_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_special_shift_date_wise_employee_id ON public.special_shift_date_wise USING btree (employee_id);


--
-- Name: special_shift_date_wise special_shift_date_wise_timestamp_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER special_shift_date_wise_timestamp_trigger BEFORE UPDATE ON public.special_shift_date_wise FOR EACH ROW EXECUTE FUNCTION public.update_special_shift_date_wise_timestamp();


--
-- Name: special_shift_date_wise special_shift_date_wise_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT special_shift_date_wise_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: special_shift_date_wise Allow all operations on special_shift_date_wise; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations on special_shift_date_wise" ON public.special_shift_date_wise USING (true) WITH CHECK (true);


--
-- Name: special_shift_date_wise; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.special_shift_date_wise ENABLE ROW LEVEL SECURITY;