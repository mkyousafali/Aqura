--
-- Name: hr_salary_statements; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_salary_statements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    statement_name text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    data_json jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_salary_statements_dates_chk CHECK ((end_date >= start_date)),
    CONSTRAINT hr_salary_statements_name_chk CHECK ((length(TRIM(BOTH FROM statement_name)) > 0))
);


--
-- Name: hr_salary_statements hr_salary_statements_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_salary_statements
    ADD CONSTRAINT hr_salary_statements_pkey PRIMARY KEY (id);


--
-- Name: hr_salary_statements_dates_idx; Type: INDEX; Schema: public;
--

CREATE INDEX hr_salary_statements_dates_idx ON public.hr_salary_statements USING btree (start_date, end_date);


--
-- Name: hr_salary_statements_updated_at_idx; Type: INDEX; Schema: public;
--

CREATE INDEX hr_salary_statements_updated_at_idx ON public.hr_salary_statements USING btree (updated_at DESC);


--
-- Name: hr_salary_statements hr_salary_statements_set_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER hr_salary_statements_set_updated_at BEFORE UPDATE ON public.hr_salary_statements FOR EACH ROW EXECUTE FUNCTION public.tg_hr_salary_statements_set_updated_at();


--
-- Name: hr_salary_statements; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_salary_statements ENABLE ROW LEVEL SECURITY;