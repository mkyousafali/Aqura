--
-- Name: day_off; Type: TABLE; Schema: public;
--

CREATE TABLE public.day_off (
    id text NOT NULL,
    employee_id text NOT NULL,
    day_off_date date NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    day_off_reason_id character varying(50),
    approval_status character varying(50) DEFAULT 'pending'::character varying,
    approval_requested_by uuid,
    approval_requested_at timestamp with time zone,
    approval_approved_by uuid,
    approval_approved_at timestamp with time zone,
    approval_notes text,
    document_url text,
    document_uploaded_at timestamp with time zone,
    is_deductible_on_salary boolean DEFAULT false,
    rejection_reason text,
    description text,
    CONSTRAINT day_off_approval_status_check CHECK (((approval_status)::text = ANY ((ARRAY['pending'::character varying, 'sent_for_approval'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);


--
-- Name: day_off day_off_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_pkey PRIMARY KEY (id);


--
-- Name: day_off unique_employee_day_off; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT unique_employee_day_off UNIQUE (employee_id, day_off_date);


--
-- Name: idx_day_off_approval_requested_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_approval_requested_by ON public.day_off USING btree (approval_requested_by);


--
-- Name: idx_day_off_approval_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_approval_status ON public.day_off USING btree (approval_status);


--
-- Name: idx_day_off_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_date ON public.day_off USING btree (day_off_date);


--
-- Name: idx_day_off_description; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_description ON public.day_off USING btree (description);


--
-- Name: idx_day_off_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_employee_id ON public.day_off USING btree (employee_id);


--
-- Name: idx_day_off_reason_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_day_off_reason_id ON public.day_off USING btree (day_off_reason_id);


--
-- Name: day_off day_off_timestamp_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER day_off_timestamp_trigger BEFORE UPDATE ON public.day_off FOR EACH ROW EXECUTE FUNCTION public.update_day_off_timestamp();


--
-- Name: day_off day_off_approval_approved_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_approval_approved_by_fkey FOREIGN KEY (approval_approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_approval_requested_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_approval_requested_by_fkey FOREIGN KEY (approval_requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_day_off_reason_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_day_off_reason_id_fkey FOREIGN KEY (day_off_reason_id) REFERENCES public.day_off_reasons(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: day_off Allow all operations on day_off; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations on day_off" ON public.day_off USING (true) WITH CHECK (true);


--
-- Name: day_off; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.day_off ENABLE ROW LEVEL SECURITY;