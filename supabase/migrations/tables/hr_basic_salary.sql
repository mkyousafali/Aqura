--
-- Name: hr_basic_salary; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_basic_salary (
    employee_id character varying(50) NOT NULL,
    basic_salary numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    payment_mode character varying(20) DEFAULT 'Bank'::character varying NOT NULL,
    other_allowance numeric(10,2),
    other_allowance_payment_mode character varying(20),
    accommodation_allowance numeric(10,2),
    accommodation_payment_mode character varying(20),
    travel_allowance numeric(10,2),
    travel_payment_mode character varying(20),
    gosi_deduction numeric(10,2),
    total_salary numeric(10,2),
    food_allowance numeric(10,2) DEFAULT 0,
    food_payment_mode text DEFAULT 'Bank'::text,
    food_deduction_active boolean DEFAULT false NOT NULL,
    CONSTRAINT hr_basic_salary_accommodation_payment_mode_check CHECK (((accommodation_payment_mode)::text = ANY ((ARRAY['Bank'::character varying, 'Cash'::character varying])::text[]))),
    CONSTRAINT hr_basic_salary_food_payment_mode_check CHECK ((food_payment_mode = ANY (ARRAY['Bank'::text, 'Cash'::text]))),
    CONSTRAINT hr_basic_salary_other_allowance_payment_mode_check CHECK (((other_allowance_payment_mode)::text = ANY ((ARRAY['Bank'::character varying, 'Cash'::character varying])::text[]))),
    CONSTRAINT hr_basic_salary_payment_mode_check CHECK (((payment_mode)::text = ANY ((ARRAY['Bank'::character varying, 'Cash'::character varying])::text[]))),
    CONSTRAINT hr_basic_salary_travel_payment_mode_check CHECK (((travel_payment_mode)::text = ANY ((ARRAY['Bank'::character varying, 'Cash'::character varying])::text[])))
);


--
-- Name: hr_basic_salary hr_basic_salary_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_basic_salary
    ADD CONSTRAINT hr_basic_salary_pkey PRIMARY KEY (employee_id);


--
-- Name: idx_hr_basic_salary_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_basic_salary_employee_id ON public.hr_basic_salary USING btree (employee_id);


--
-- Name: hr_basic_salary hr_basic_salary_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_basic_salary
    ADD CONSTRAINT hr_basic_salary_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_basic_salary Allow all access to hr_basic_salary; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to hr_basic_salary" ON public.hr_basic_salary USING (true) WITH CHECK (true);


--
-- Name: hr_basic_salary; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_basic_salary ENABLE ROW LEVEL SECURITY;