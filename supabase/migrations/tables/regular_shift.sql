--
-- Name: regular_shift; Type: TABLE; Schema: public;
--

CREATE TABLE public.regular_shift (
    id text NOT NULL,
    shift_start_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    shift_start_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    shift_end_time time without time zone DEFAULT '17:00:00'::time without time zone NOT NULL,
    shift_end_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    is_shift_overlapping_next_day boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    working_hours numeric(5,2) DEFAULT 0
);


--
-- Name: regular_shift regular_shift_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.regular_shift
    ADD CONSTRAINT regular_shift_pkey PRIMARY KEY (id);


--
-- Name: idx_regular_shift_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_regular_shift_created_at ON public.regular_shift USING btree (created_at);


--
-- Name: idx_regular_shift_updated_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_regular_shift_updated_at ON public.regular_shift USING btree (updated_at);


--
-- Name: regular_shift calculate_working_hours_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER calculate_working_hours_trigger BEFORE INSERT OR UPDATE ON public.regular_shift FOR EACH ROW EXECUTE FUNCTION public.calculate_working_hours();


--
-- Name: regular_shift regular_shift_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER regular_shift_timestamp_update BEFORE UPDATE ON public.regular_shift FOR EACH ROW EXECUTE FUNCTION public.update_regular_shift_timestamp();


--
-- Name: regular_shift regular_shift_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.regular_shift
    ADD CONSTRAINT regular_shift_id_fkey FOREIGN KEY (id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: regular_shift Allow all access to regular_shift; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to regular_shift" ON public.regular_shift USING (true) WITH CHECK (true);


--
-- Name: regular_shift; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.regular_shift ENABLE ROW LEVEL SECURITY;