--
-- Name: multi_shift_regular; Type: TABLE; Schema: public;
--

CREATE TABLE public.multi_shift_regular (
    id integer NOT NULL,
    employee_id text NOT NULL,
    shift_start_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    shift_start_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    shift_end_time time without time zone DEFAULT '17:00:00'::time without time zone NOT NULL,
    shift_end_buffer numeric(4,2) DEFAULT 0 NOT NULL,
    is_shift_overlapping_next_day boolean DEFAULT false NOT NULL,
    working_hours numeric(5,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: multi_shift_regular_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.multi_shift_regular_id_seq OWNED BY public.multi_shift_regular.id;


--
-- Name: multi_shift_regular id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_regular ALTER COLUMN id SET DEFAULT nextval('public.multi_shift_regular_id_seq'::regclass);


--
-- Name: multi_shift_regular multi_shift_regular_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_regular
    ADD CONSTRAINT multi_shift_regular_pkey PRIMARY KEY (id);


--
-- Name: idx_multi_shift_regular_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_multi_shift_regular_employee_id ON public.multi_shift_regular USING btree (employee_id);


--
-- Name: multi_shift_regular multi_shift_regular_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER multi_shift_regular_timestamp_update BEFORE UPDATE ON public.multi_shift_regular FOR EACH ROW EXECUTE FUNCTION public.update_multi_shift_regular_timestamp();


--
-- Name: multi_shift_regular multi_shift_regular_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.multi_shift_regular
    ADD CONSTRAINT multi_shift_regular_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: multi_shift_regular Allow all access to multi_shift_regular; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to multi_shift_regular" ON public.multi_shift_regular USING (true) WITH CHECK (true);


--
-- Name: multi_shift_regular; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.multi_shift_regular ENABLE ROW LEVEL SECURITY;