--
-- Name: non_approved_payment_scheduler; Type: TABLE; Schema: public;
--

CREATE TABLE public.non_approved_payment_scheduler (
    id bigint NOT NULL,
    schedule_type text NOT NULL,
    branch_id bigint NOT NULL,
    branch_name text NOT NULL,
    expense_category_id bigint NOT NULL,
    expense_category_name_en text,
    expense_category_name_ar text,
    co_user_id uuid,
    co_user_name text,
    bill_type text,
    bill_number text,
    bill_date date,
    payment_method text,
    due_date date,
    credit_period integer,
    amount numeric NOT NULL,
    bill_file_url text,
    bank_name text,
    iban text,
    description text,
    notes text,
    recurring_type text,
    recurring_metadata jsonb,
    approver_id uuid NOT NULL,
    approver_name text NOT NULL,
    approval_status text DEFAULT 'pending'::text,
    approved_at timestamp with time zone,
    approved_by uuid,
    rejection_reason text,
    expense_scheduler_id bigint,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_non_approved_approval_status CHECK ((approval_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))),
    CONSTRAINT check_non_approved_co_user_for_non_recurring CHECK (((schedule_type = 'recurring'::text) OR ((schedule_type = ANY (ARRAY['single_bill'::text, 'multiple_bill'::text])) AND (co_user_id IS NOT NULL) AND (co_user_name IS NOT NULL)))),
    CONSTRAINT check_non_approved_recurring_type CHECK (((recurring_type IS NULL) OR (recurring_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly_date'::text, 'monthly_day'::text, 'yearly'::text, 'half_yearly'::text, 'quarterly'::text, 'custom'::text])))),
    CONSTRAINT check_non_approved_schedule_type CHECK ((schedule_type = ANY (ARRAY['single_bill'::text, 'multiple_bill'::text, 'recurring'::text])))
);


--
-- Name: non_approved_payment_scheduler_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.non_approved_payment_scheduler_id_seq OWNED BY public.non_approved_payment_scheduler.id;


--
-- Name: non_approved_payment_scheduler id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler ALTER COLUMN id SET DEFAULT nextval('public.non_approved_payment_scheduler_id_seq'::regclass);


--
-- Name: non_approved_payment_scheduler non_approved_payment_scheduler_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT non_approved_payment_scheduler_pkey PRIMARY KEY (id);


--
-- Name: idx_non_approved_scheduler_approval_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_approval_status ON public.non_approved_payment_scheduler USING btree (approval_status);


--
-- Name: idx_non_approved_scheduler_approver_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_approver_id ON public.non_approved_payment_scheduler USING btree (approver_id);


--
-- Name: idx_non_approved_scheduler_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_branch_id ON public.non_approved_payment_scheduler USING btree (branch_id);


--
-- Name: idx_non_approved_scheduler_category_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_category_id ON public.non_approved_payment_scheduler USING btree (expense_category_id);


--
-- Name: idx_non_approved_scheduler_co_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_co_user_id ON public.non_approved_payment_scheduler USING btree (co_user_id) WHERE (co_user_id IS NOT NULL);


--
-- Name: idx_non_approved_scheduler_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_created_at ON public.non_approved_payment_scheduler USING btree (created_at DESC);


--
-- Name: idx_non_approved_scheduler_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_created_by ON public.non_approved_payment_scheduler USING btree (created_by);


--
-- Name: idx_non_approved_scheduler_expense_scheduler_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_expense_scheduler_id ON public.non_approved_payment_scheduler USING btree (expense_scheduler_id) WHERE (expense_scheduler_id IS NOT NULL);


--
-- Name: idx_non_approved_scheduler_schedule_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_non_approved_scheduler_schedule_type ON public.non_approved_payment_scheduler USING btree (schedule_type);


--
-- Name: non_approved_payment_scheduler non_approved_scheduler_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER non_approved_scheduler_updated_at BEFORE UPDATE ON public.non_approved_payment_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_non_approved_scheduler_updated_at();


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_approved_by; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_approved_by FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_approver; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_approver FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_branch; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_category; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_co_user; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_created_by; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_expense_scheduler; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_expense_scheduler FOREIGN KEY (expense_scheduler_id) REFERENCES public.expense_scheduler(id) ON DELETE SET NULL;


--
-- Name: non_approved_payment_scheduler Allow anon insert non_approved_payment_scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert non_approved_payment_scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO anon WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to create non approved scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to create non approved scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to read non approved scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read non approved scheduler" ON public.non_approved_payment_scheduler FOR SELECT TO authenticated USING (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to update non approved scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to update non approved scheduler" ON public.non_approved_payment_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Service role has full access to non approved scheduler; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role has full access to non approved scheduler" ON public.non_approved_payment_scheduler TO service_role USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.non_approved_payment_scheduler USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.non_approved_payment_scheduler FOR DELETE USING (true);


--
-- Name: non_approved_payment_scheduler allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.non_approved_payment_scheduler FOR INSERT WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.non_approved_payment_scheduler FOR SELECT USING (true);


--
-- Name: non_approved_payment_scheduler allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.non_approved_payment_scheduler FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.non_approved_payment_scheduler USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: non_approved_payment_scheduler authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.non_approved_payment_scheduler USING ((auth.uid() IS NOT NULL));


--
-- Name: non_approved_payment_scheduler; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;