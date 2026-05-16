--
-- Name: expense_requisitions; Type: TABLE; Schema: public;
--

CREATE TABLE public.expense_requisitions (
    id bigint NOT NULL,
    requisition_number text NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    approver_id uuid,
    approver_name text,
    expense_category_id bigint,
    expense_category_name_en text,
    expense_category_name_ar text,
    requester_id text NOT NULL,
    requester_name text NOT NULL,
    requester_contact text NOT NULL,
    vat_applicable boolean DEFAULT false,
    amount numeric(15,2) NOT NULL,
    payment_category text NOT NULL,
    description text,
    status text DEFAULT 'pending'::text,
    image_url text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    credit_period integer,
    bank_name text,
    iban text,
    used_amount numeric DEFAULT 0,
    remaining_balance numeric DEFAULT 0,
    requester_ref_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    due_date date,
    internal_user_id uuid,
    request_type text DEFAULT 'external'::text,
    vendor_id integer,
    vendor_name text,
    CONSTRAINT expense_requisitions_request_type_check CHECK ((request_type = ANY (ARRAY['external'::text, 'internal'::text, 'vendor'::text])))
);


--
-- Name: expense_requisitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.expense_requisitions_id_seq OWNED BY public.expense_requisitions.id;


--
-- Name: expense_requisitions id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions ALTER COLUMN id SET DEFAULT nextval('public.expense_requisitions_id_seq'::regclass);


--
-- Name: expense_requisitions expense_requisitions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_pkey PRIMARY KEY (id);


--
-- Name: expense_requisitions expense_requisitions_requisition_number_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_requisition_number_key UNIQUE (requisition_number);


--
-- Name: idx_expense_requisitions_due_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_requisitions_due_date ON public.expense_requisitions USING btree (due_date);


--
-- Name: idx_expense_requisitions_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_requisitions_is_active ON public.expense_requisitions USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_expense_requisitions_remaining_balance; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_requisitions_remaining_balance ON public.expense_requisitions USING btree (remaining_balance);


--
-- Name: idx_expense_requisitions_requester_ref; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_requisitions_requester_ref ON public.expense_requisitions USING btree (requester_ref_id);


--
-- Name: idx_expense_requisitions_status_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_requisitions_status_active ON public.expense_requisitions USING btree (status, is_active);


--
-- Name: idx_requisitions_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requisitions_branch ON public.expense_requisitions USING btree (branch_id);


--
-- Name: idx_requisitions_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requisitions_created_at ON public.expense_requisitions USING btree (created_at DESC);


--
-- Name: idx_requisitions_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requisitions_number ON public.expense_requisitions USING btree (requisition_number);


--
-- Name: idx_requisitions_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_requisitions_status ON public.expense_requisitions USING btree (status);


--
-- Name: expense_requisitions expense_requisitions_expense_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_expense_category_id_fkey FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id);


--
-- Name: expense_requisitions expense_requisitions_internal_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_internal_user_id_fkey FOREIGN KEY (internal_user_id) REFERENCES public.users(id);


--
-- Name: expense_requisitions expense_requisitions_requester_ref_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_requester_ref_id_fkey FOREIGN KEY (requester_ref_id) REFERENCES public.requesters(id);


--
-- Name: expense_requisitions fk_expense_requisitions_branch; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT fk_expense_requisitions_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: expense_requisitions Allow anon insert expense_requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert expense_requisitions" ON public.expense_requisitions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_requisitions Allow authenticated users to create expense requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create expense requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_requisitions Allow authenticated users to delete requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to delete requisitions" ON public.expense_requisitions FOR DELETE TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to insert requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to insert requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_requisitions Allow authenticated users to read expense requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read expense requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to read requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to update expense requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update expense requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions Allow authenticated users to update requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true);


--
-- Name: expense_requisitions Service role has full access to expense requisitions; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role has full access to expense requisitions" ON public.expense_requisitions TO service_role USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.expense_requisitions USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.expense_requisitions FOR DELETE USING (true);


--
-- Name: expense_requisitions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.expense_requisitions FOR INSERT WITH CHECK (true);


--
-- Name: expense_requisitions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.expense_requisitions FOR SELECT USING (true);


--
-- Name: expense_requisitions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.expense_requisitions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.expense_requisitions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_requisitions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.expense_requisitions USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_requisitions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;