--
-- Name: official_holidays; Type: TABLE; Schema: public;
--

CREATE TABLE public.official_holidays (
    id text DEFAULT (gen_random_uuid())::text NOT NULL,
    holiday_date date NOT NULL,
    name_en text DEFAULT ''::text NOT NULL,
    name_ar text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: official_holidays official_holidays_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.official_holidays
    ADD CONSTRAINT official_holidays_pkey PRIMARY KEY (id);


--
-- Name: official_holidays unique_official_holiday_date; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.official_holidays
    ADD CONSTRAINT unique_official_holiday_date UNIQUE (holiday_date);


--
-- Name: idx_official_holidays_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_official_holidays_date ON public.official_holidays USING btree (holiday_date);


--
-- Name: official_holidays official_holidays_timestamp_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER official_holidays_timestamp_trigger BEFORE UPDATE ON public.official_holidays FOR EACH ROW EXECUTE FUNCTION public.update_official_holidays_timestamp();


--
-- Name: official_holidays Allow all operations on official_holidays; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations on official_holidays" ON public.official_holidays USING (true) WITH CHECK (true);


--
-- Name: official_holidays; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.official_holidays ENABLE ROW LEVEL SECURITY;