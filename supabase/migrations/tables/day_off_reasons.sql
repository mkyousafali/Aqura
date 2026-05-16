--
-- Name: day_off_reasons; Type: TABLE; Schema: public;
--

CREATE TABLE public.day_off_reasons (
    id character varying(50) NOT NULL,
    reason_en character varying(255) NOT NULL,
    reason_ar character varying(255) NOT NULL,
    is_deductible boolean DEFAULT false,
    is_document_mandatory boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: day_off_reasons day_off_reasons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off_reasons
    ADD CONSTRAINT day_off_reasons_pkey PRIMARY KEY (id);


--
-- Name: day_off_reasons day_off_reasons_reason_en_reason_ar_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off_reasons
    ADD CONSTRAINT day_off_reasons_reason_en_reason_ar_key UNIQUE (reason_en, reason_ar);


--
-- Name: idx_day_off_reasons_deductible; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_reasons_deductible ON public.day_off_reasons USING btree (is_deductible);


--
-- Name: idx_day_off_reasons_document_mandatory; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_reasons_document_mandatory ON public.day_off_reasons USING btree (is_document_mandatory);


--
-- Name: day_off_reasons day_off_reasons_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER day_off_reasons_timestamp_update BEFORE UPDATE ON public.day_off_reasons FOR EACH ROW EXECUTE FUNCTION public.update_day_off_reasons_timestamp();


--
-- Name: day_off_reasons Allow all access to day_off_reasons; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to day_off_reasons" ON public.day_off_reasons USING (true) WITH CHECK (true);


--
-- Name: day_off_reasons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.day_off_reasons ENABLE ROW LEVEL SECURITY;