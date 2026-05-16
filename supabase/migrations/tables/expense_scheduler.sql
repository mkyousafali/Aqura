--
-- Name: expense_scheduler; Type: TABLE; Schema: public;
--

CREATE TABLE public.expense_scheduler (
    id bigint NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    expense_category_id bigint,
    expense_category_name_en text,
    expense_category_name_ar text,
    requisition_id bigint,
    requisition_number text,
    co_user_id uuid,
    co_user_name text,
    bill_type text NOT NULL,
    bill_number text,
    bill_date date,
    payment_method text,
    due_date date,
    credit_period integer,
    amount numeric NOT NULL,
    bill_file_url text,
    description text,
    notes text,
    is_paid boolean DEFAULT false,
    paid_date timestamp with time zone,
    status text DEFAULT 'pending'::text,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now(),
    bank_name text,
    iban text,
    payment_reference character varying(255),
    schedule_type text DEFAULT 'single_bill'::text,
    recurring_type text,
    recurring_metadata jsonb,
    approver_id uuid,
    approver_name text,
    vendor_id integer,
    vendor_name text,
    CONSTRAINT check_approver_for_recurring CHECK (((schedule_type <> 'recurring'::text) OR ((schedule_type = 'recurring'::text) AND (approver_id IS NOT NULL) AND (approver_name IS NOT NULL)))),
    CONSTRAINT check_co_user_for_non_recurring CHECK (((schedule_type = 'recurring'::text) OR (schedule_type = 'expense_requisition'::text) OR (schedule_type = 'closed_requisition_bill'::text) OR ((schedule_type = ANY (ARRAY['single_bill'::text, 'multiple_bill'::text])) AND (co_user_id IS NOT NULL) AND (co_user_name IS NOT NULL)))),
    CONSTRAINT check_recurring_type_values CHECK ((((schedule_type <> 'recurring'::text) AND (recurring_type IS NULL)) OR ((schedule_type = 'recurring'::text) AND (recurring_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly_date'::text, 'monthly_day'::text, 'yearly'::text, 'half_yearly'::text, 'quarterly'::text, 'custom'::text]))))),
    CONSTRAINT check_schedule_type_values CHECK ((schedule_type = ANY (ARRAY['single_bill'::text, 'multiple_bill'::text, 'recurring'::text, 'expense_requisition'::text, 'closed_requisition_bill'::text])))
);


--
-- Name: expense_scheduler_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.expense_scheduler_id_seq OWNED BY public.expense_scheduler.id;


--
-- Name: expense_scheduler id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler ALTER COLUMN id SET DEFAULT nextval('public.expense_scheduler_id_seq'::regclass);


--
-- Name: expense_scheduler expense_scheduler_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT expense_scheduler_pkey PRIMARY KEY (id);


--
-- Name: idx_expense_scheduler_approver_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_approver_id ON public.expense_scheduler USING btree (approver_id) WHERE (approver_id IS NOT NULL);


--
-- Name: idx_expense_scheduler_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_branch_id ON public.expense_scheduler USING btree (branch_id);


--
-- Name: idx_expense_scheduler_category_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_category_id ON public.expense_scheduler USING btree (expense_category_id);


--
-- Name: idx_expense_scheduler_co_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_co_user_id ON public.expense_scheduler USING btree (co_user_id);


--
-- Name: idx_expense_scheduler_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_created_at ON public.expense_scheduler USING btree (created_at DESC);


--
-- Name: idx_expense_scheduler_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_created_by ON public.expense_scheduler USING btree (created_by);


--
-- Name: idx_expense_scheduler_credit_period; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_credit_period ON public.expense_scheduler USING btree (credit_period);


--
-- Name: idx_expense_scheduler_due_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_due_date ON public.expense_scheduler USING btree (due_date);


--
-- Name: idx_expense_scheduler_due_date_paid; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_due_date_paid ON public.expense_scheduler USING btree (due_date, is_paid);


--
-- Name: idx_expense_scheduler_is_paid; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_is_paid ON public.expense_scheduler USING btree (is_paid);


--
-- Name: idx_expense_scheduler_payment_reference; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_payment_reference ON public.expense_scheduler USING btree (payment_reference) WHERE (payment_reference IS NOT NULL);


--
-- Name: idx_expense_scheduler_recurring_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_recurring_type ON public.expense_scheduler USING btree (recurring_type) WHERE (recurring_type IS NOT NULL);


--
-- Name: idx_expense_scheduler_requisition_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_requisition_id ON public.expense_scheduler USING btree (requisition_id);


--
-- Name: idx_expense_scheduler_schedule_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_schedule_type ON public.expense_scheduler USING btree (schedule_type);


--
-- Name: idx_expense_scheduler_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_expense_scheduler_status ON public.expense_scheduler USING btree (status);


--
-- Name: expense_scheduler expense_scheduler_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER expense_scheduler_updated_at BEFORE UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_expense_scheduler_updated_at();


--
-- Name: expense_scheduler sync_requisition_balance_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER sync_requisition_balance_trigger AFTER INSERT OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.sync_requisition_balance();


--
-- Name: expense_scheduler trigger_update_requisition_balance; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_requisition_balance AFTER INSERT OR DELETE OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_requisition_balance();


--
-- Name: expense_scheduler trigger_update_requisition_balance_old; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_requisition_balance_old BEFORE DELETE OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_requisition_balance_old();


--
-- Name: expense_scheduler fk_expense_scheduler_approver; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_approver FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: expense_scheduler fk_expense_scheduler_branch; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_category; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE SET NULL;


--
-- Name: expense_scheduler fk_expense_scheduler_co_user; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_created_by; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_requisition; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_requisition FOREIGN KEY (requisition_id) REFERENCES public.expense_requisitions(id) ON DELETE SET NULL;


--
-- Name: expense_scheduler Allow anon insert expense_scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert expense_scheduler" ON public.expense_scheduler FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_scheduler Allow authenticated users to create expense scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create expense scheduler" ON public.expense_scheduler FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_scheduler Allow authenticated users to read expense scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read expense scheduler" ON public.expense_scheduler FOR SELECT TO authenticated USING (true);


--
-- Name: expense_scheduler Allow authenticated users to update expense scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update expense scheduler" ON public.expense_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler Service role has full access to expense scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role has full access to expense scheduler" ON public.expense_scheduler TO service_role USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.expense_scheduler USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.expense_scheduler FOR DELETE USING (true);


--
-- Name: expense_scheduler allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.expense_scheduler FOR INSERT WITH CHECK (true);


--
-- Name: expense_scheduler allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.expense_scheduler FOR SELECT USING (true);


--
-- Name: expense_scheduler allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.expense_scheduler FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.expense_scheduler USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_scheduler authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.expense_scheduler USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_scheduler; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.expense_scheduler ENABLE ROW LEVEL SECURITY;