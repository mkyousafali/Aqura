--
-- Name: hr_insurance_companies; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_insurance_companies (
    id character varying(15) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: hr_insurance_companies hr_insurance_companies_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_insurance_companies
    ADD CONSTRAINT hr_insurance_companies_pkey PRIMARY KEY (id);


--
-- Name: idx_hr_insurance_companies_name_ar; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_insurance_companies_name_ar ON public.hr_insurance_companies USING btree (name_ar);


--
-- Name: idx_hr_insurance_companies_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_insurance_companies_name_en ON public.hr_insurance_companies USING btree (name_en);


--
-- Name: hr_insurance_companies trg_generate_insurance_company_id; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_generate_insurance_company_id BEFORE INSERT ON public.hr_insurance_companies FOR EACH ROW EXECUTE FUNCTION public.generate_insurance_company_id();


--
-- Name: hr_insurance_companies Allow all access to hr_insurance_companies; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to hr_insurance_companies" ON public.hr_insurance_companies USING (true) WITH CHECK (true);


--
-- Name: hr_insurance_companies; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_insurance_companies ENABLE ROW LEVEL SECURITY;