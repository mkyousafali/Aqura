--
-- Name: denomination_transactions; Type: TABLE; Schema: public;
--

CREATE TABLE public.denomination_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id integer NOT NULL,
    section character varying(20) NOT NULL,
    transaction_type character varying(50) NOT NULL,
    amount numeric(15,2) NOT NULL,
    remarks text,
    apply_denomination boolean DEFAULT false,
    denomination_details jsonb DEFAULT '{}'::jsonb,
    entity_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid NOT NULL,
    CONSTRAINT denomination_transactions_section_check CHECK (((section)::text = ANY ((ARRAY['paid'::character varying, 'received'::character varying])::text[]))),
    CONSTRAINT denomination_transactions_transaction_type_check CHECK (((transaction_type)::text = ANY ((ARRAY['vendor'::character varying, 'expenses'::character varying, 'user'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: denomination_transactions denomination_transactions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_denomination_transactions_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_transactions_branch_id ON public.denomination_transactions USING btree (branch_id);


--
-- Name: idx_denomination_transactions_branch_section; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_transactions_branch_section ON public.denomination_transactions USING btree (branch_id, section);


--
-- Name: idx_denomination_transactions_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_transactions_created_at ON public.denomination_transactions USING btree (created_at DESC);


--
-- Name: idx_denomination_transactions_section; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_transactions_section ON public.denomination_transactions USING btree (section);


--
-- Name: idx_denomination_transactions_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_transactions_type ON public.denomination_transactions USING btree (transaction_type);


--
-- Name: denomination_transactions denomination_transactions_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER denomination_transactions_timestamp_update BEFORE UPDATE ON public.denomination_transactions FOR EACH ROW EXECUTE FUNCTION public.update_denomination_transactions_timestamp();


--
-- Name: denomination_transactions denomination_transactions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: denomination_transactions denomination_transactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: denomination_transactions Allow all access to denomination_transactions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to denomination_transactions" ON public.denomination_transactions USING (true) WITH CHECK (true);


--
-- Name: denomination_transactions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.denomination_transactions ENABLE ROW LEVEL SECURITY;