--
-- Name: break_register; Type: TABLE; Schema: public;
--

CREATE TABLE public.break_register (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    employee_id character varying(50) NOT NULL,
    employee_name_en character varying(200),
    employee_name_ar character varying(200),
    branch_id integer,
    reason_id integer NOT NULL,
    reason_note text,
    start_time timestamp with time zone DEFAULT now() NOT NULL,
    end_time timestamp with time zone,
    duration_seconds integer,
    status character varying(20) DEFAULT 'open'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT break_register_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'closed'::character varying])::text[])))
);

ALTER TABLE ONLY public.break_register REPLICA IDENTITY FULL;


--
-- Name: break_register break_register_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.break_register
    ADD CONSTRAINT break_register_pkey PRIMARY KEY (id);


--
-- Name: idx_break_register_employee; Type: INDEX; Schema: public;
--

CREATE INDEX idx_break_register_employee ON public.break_register USING btree (employee_id);


--
-- Name: idx_break_register_start; Type: INDEX; Schema: public;
--

CREATE INDEX idx_break_register_start ON public.break_register USING btree (start_time DESC);


--
-- Name: idx_break_register_user_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_break_register_user_status ON public.break_register USING btree (user_id, status);


--
-- Name: break_register break_register_reason_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.break_register
    ADD CONSTRAINT break_register_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.break_reasons(id);


--
-- Name: break_register Allow all access to break_register; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to break_register" ON public.break_register USING (true) WITH CHECK (true);


--
-- Name: break_register; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.break_register ENABLE ROW LEVEL SECURITY;