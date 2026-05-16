--
-- Name: hr_analysed_attendance_data; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_analysed_attendance_data (
    id bigint NOT NULL,
    employee_id text NOT NULL,
    shift_date date NOT NULL,
    status text DEFAULT 'Absent'::text NOT NULL,
    worked_minutes integer DEFAULT 0 NOT NULL,
    late_minutes integer DEFAULT 0 NOT NULL,
    under_minutes integer DEFAULT 0 NOT NULL,
    shift_start_time time without time zone,
    shift_end_time time without time zone,
    check_in_time time without time zone,
    check_out_time time without time zone,
    employee_name_en text,
    employee_name_ar text,
    branch_id text,
    nationality text,
    analyzed_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    overtime_minutes integer DEFAULT 0
);


--
-- Name: hr_analysed_attendance_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.hr_analysed_attendance_data_id_seq OWNED BY public.hr_analysed_attendance_data.id;


--
-- Name: hr_analysed_attendance_data id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.hr_analysed_attendance_data ALTER COLUMN id SET DEFAULT nextval('public.hr_analysed_attendance_data_id_seq'::regclass);


--
-- Name: hr_analysed_attendance_data hr_analysed_attendance_data_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT hr_analysed_attendance_data_pkey PRIMARY KEY (id);


--
-- Name: hr_analysed_attendance_data unique_employee_shift_date; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT unique_employee_shift_date UNIQUE (employee_id, shift_date);


--
-- Name: idx_analysed_att_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_analysed_att_branch ON public.hr_analysed_attendance_data USING btree (branch_id);


--
-- Name: idx_analysed_att_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_analysed_att_date ON public.hr_analysed_attendance_data USING btree (shift_date);


--
-- Name: idx_analysed_att_emp_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_analysed_att_emp_date ON public.hr_analysed_attendance_data USING btree (employee_id, shift_date);


--
-- Name: idx_analysed_att_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_analysed_att_employee_id ON public.hr_analysed_attendance_data USING btree (employee_id);


--
-- Name: idx_analysed_att_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_analysed_att_status ON public.hr_analysed_attendance_data USING btree (status);


--
-- Name: hr_analysed_attendance_data fk_analysed_employee; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT fk_analysed_employee FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_analysed_attendance_data Allow all access to hr_analysed_attendance_data; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to hr_analysed_attendance_data" ON public.hr_analysed_attendance_data USING (true) WITH CHECK (true);


--
-- Name: hr_analysed_attendance_data; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_analysed_attendance_data ENABLE ROW LEVEL SECURITY;