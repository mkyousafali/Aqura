--
-- Name: processed_fingerprint_transactions; Type: TABLE; Schema: public;
--

CREATE TABLE public.processed_fingerprint_transactions (
    id text NOT NULL,
    center_id text NOT NULL,
    employee_id text NOT NULL,
    branch_id text NOT NULL,
    punch_date date NOT NULL,
    punch_time time without time zone NOT NULL,
    status text,
    processed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: processed_fingerprint_transactions processed_fingerprint_transactions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.processed_fingerprint_transactions
    ADD CONSTRAINT processed_fingerprint_transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_processed_fingerprint_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_processed_fingerprint_branch_id ON public.processed_fingerprint_transactions USING btree (branch_id);


--
-- Name: idx_processed_fingerprint_center_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_processed_fingerprint_center_id ON public.processed_fingerprint_transactions USING btree (center_id);


--
-- Name: idx_processed_fingerprint_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_processed_fingerprint_employee_id ON public.processed_fingerprint_transactions USING btree (employee_id);


--
-- Name: idx_processed_fingerprint_punch_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_processed_fingerprint_punch_date ON public.processed_fingerprint_transactions USING btree (punch_date);


--
-- Name: processed_fingerprint_transactions processed_fingerprint_transactions_center_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.processed_fingerprint_transactions
    ADD CONSTRAINT processed_fingerprint_transactions_center_id_fkey FOREIGN KEY (center_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: processed_fingerprint_transactions Allow all access to processed_fingerprint_transactions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to processed_fingerprint_transactions" ON public.processed_fingerprint_transactions USING (true) WITH CHECK (true);


--
-- Name: processed_fingerprint_transactions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.processed_fingerprint_transactions ENABLE ROW LEVEL SECURITY;