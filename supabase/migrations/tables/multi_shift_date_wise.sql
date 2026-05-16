--
-- Name: multi_shift_date_wise; Type: TABLE; Schema: public;
--

CREATE TABLE public.multi_shift_date_wise (
    id integer NOT NULL,
    employee_id text NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    shift_start_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    shift_start_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    shift_end_time time without time zone DEFAULT '17:00:00'::time without time zone NOT NULL,
    shift_end_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    is_shift_overlapping_next_day boolean DEFAULT false NOT NULL,
    working_hours numeric(5,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT multi_shift_date_wise_date_check CHECK ((date_from <= date_to))
);


--
-- Name: multi_shift_date_wise_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.multi_shift_date_wise_id_seq OWNED BY public.multi_shift_date_wise.id;


--
-- Name: multi_shift_date_wise id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_date_wise ALTER COLUMN id SET DEFAULT nextval('public.multi_shift_date_wise_id_seq'::regclass);


--
-- Name: multi_shift_date_wise multi_shift_date_wise_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_date_wise
    ADD CONSTRAINT multi_shift_date_wise_pkey PRIMARY KEY (id);


--
-- Name: idx_multi_shift_date_wise_dates; Type: INDEX; Schema: public;
--

CREATE INDEX idx_multi_shift_date_wise_dates ON public.multi_shift_date_wise USING btree (date_from, date_to);


--
-- Name: idx_multi_shift_date_wise_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_multi_shift_date_wise_employee_id ON public.multi_shift_date_wise USING btree (employee_id);


--
-- Name: multi_shift_date_wise multi_shift_date_wise_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER multi_shift_date_wise_timestamp_update BEFORE UPDATE ON public.multi_shift_date_wise FOR EACH ROW EXECUTE FUNCTION public.update_multi_shift_date_wise_timestamp();


--
-- Name: multi_shift_date_wise multi_shift_date_wise_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_date_wise
    ADD CONSTRAINT multi_shift_date_wise_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: multi_shift_date_wise Allow all access to multi_shift_date_wise; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to multi_shift_date_wise" ON public.multi_shift_date_wise USING (true) WITH CHECK (true);


--
-- Name: multi_shift_date_wise; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.multi_shift_date_wise ENABLE ROW LEVEL SECURITY;