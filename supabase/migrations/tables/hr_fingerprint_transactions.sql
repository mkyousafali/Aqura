--
-- Name: hr_fingerprint_transactions; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_fingerprint_transactions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    employee_id character varying(20) NOT NULL,
    name character varying(200),
    branch_id bigint NOT NULL,
    date date NOT NULL,
    "time" time without time zone NOT NULL,
    status character varying(20) NOT NULL,
    device_id character varying(50),
    created_at timestamp with time zone DEFAULT now(),
    location text,
    processed boolean DEFAULT false,
    CONSTRAINT chk_hr_fingerprint_punch CHECK (((status)::text = ANY (ARRAY[('Check In'::character varying)::text, ('Check Out'::character varying)::text, ('Break In'::character varying)::text, ('Break Out'::character varying)::text, ('Overtime In'::character varying)::text, ('Overtime Out'::character varying)::text])))
);


--
-- Name: hr_fingerprint_transactions hr_fingerprint_transactions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT hr_fingerprint_transactions_pkey PRIMARY KEY (id);


--
-- Name: hr_fingerprint_transactions unique_fingerprint_transaction; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT unique_fingerprint_transaction UNIQUE (employee_id, date, "time", status, branch_id);


--
-- Name: idx_fingerprint_transactions_processed; Type: INDEX; Schema: public;
--

CREATE INDEX idx_fingerprint_transactions_processed ON public.hr_fingerprint_transactions USING btree (processed);


--
-- Name: idx_hr_fingerprint_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_fingerprint_branch_id ON public.hr_fingerprint_transactions USING btree (branch_id);


--
-- Name: idx_hr_fingerprint_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_fingerprint_date ON public.hr_fingerprint_transactions USING btree (date);


--
-- Name: idx_hr_fingerprint_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_fingerprint_employee_id ON public.hr_fingerprint_transactions USING btree (employee_id);


--
-- Name: idx_hr_fingerprint_punch_state; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_fingerprint_punch_state ON public.hr_fingerprint_transactions USING btree (status);


--
-- Name: hr_fingerprint_transactions hr_fingerprint_transactions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: hr_fingerprint_transactions Allow anon insert hr_fingerprint_transactions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert hr_fingerprint_transactions" ON public.hr_fingerprint_transactions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.hr_fingerprint_transactions USING (true) WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.hr_fingerprint_transactions FOR DELETE USING (true);


--
-- Name: hr_fingerprint_transactions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.hr_fingerprint_transactions FOR INSERT WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.hr_fingerprint_transactions FOR SELECT USING (true);


--
-- Name: hr_fingerprint_transactions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.hr_fingerprint_transactions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.hr_fingerprint_transactions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_fingerprint_transactions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.hr_fingerprint_transactions USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_fingerprint_transactions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;