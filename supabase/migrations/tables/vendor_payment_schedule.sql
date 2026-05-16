--
-- Name: vendor_payment_schedule; Type: TABLE; Schema: public;
--

CREATE TABLE public.vendor_payment_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receiving_record_id uuid,
    bill_number character varying(255),
    vendor_id character varying(255),
    vendor_name character varying(255),
    branch_id integer,
    branch_name character varying(255),
    bill_date date,
    bill_amount numeric(15,2),
    final_bill_amount numeric(15,2),
    payment_method character varying(100),
    bank_name character varying(255),
    iban character varying(255),
    due_date date,
    credit_period integer,
    vat_number character varying(100),
    scheduled_date timestamp without time zone DEFAULT now(),
    paid_date timestamp without time zone,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    original_due_date date,
    original_bill_amount numeric(15,2),
    original_final_amount numeric(15,2),
    is_paid boolean DEFAULT false,
    payment_reference character varying(255),
    task_id uuid,
    task_assignment_id uuid,
    receiver_user_id uuid,
    accountant_user_id uuid,
    verification_status text DEFAULT 'pending'::text,
    verified_by uuid,
    verified_date timestamp with time zone,
    transaction_date timestamp with time zone,
    original_bill_url text,
    created_by uuid,
    pr_excel_verified boolean DEFAULT false,
    pr_excel_verified_by uuid,
    pr_excel_verified_date timestamp with time zone,
    discount_amount numeric(15,2) DEFAULT 0,
    discount_notes text,
    grr_amount numeric(15,2) DEFAULT 0,
    grr_reference_number text,
    grr_notes text,
    pri_amount numeric(15,2) DEFAULT 0,
    pri_reference_number text,
    pri_notes text,
    last_adjustment_date timestamp with time zone,
    last_adjusted_by uuid,
    adjustment_history jsonb DEFAULT '[]'::jsonb,
    approval_status text DEFAULT 'pending'::text NOT NULL,
    approval_requested_by uuid,
    approval_requested_at timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    approval_notes text,
    assigned_approver_id uuid,
    CONSTRAINT check_discount_amount_positive CHECK ((discount_amount >= (0)::numeric)),
    CONSTRAINT check_grr_amount_positive CHECK ((grr_amount >= (0)::numeric)),
    CONSTRAINT check_pri_amount_positive CHECK ((pri_amount >= (0)::numeric)),
    CONSTRAINT check_total_deductions_valid CHECK ((((COALESCE(discount_amount, (0)::numeric) + COALESCE(grr_amount, (0)::numeric)) + COALESCE(pri_amount, (0)::numeric)) <= COALESCE(original_final_amount, final_bill_amount, bill_amount))),
    CONSTRAINT vendor_payment_approval_status_check CHECK ((approval_status = ANY (ARRAY['pending'::text, 'sent_for_approval'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_pkey PRIMARY KEY (id);


--
-- Name: idx_vendor_payment_approval_requested_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_approval_requested_by ON public.vendor_payment_schedule USING btree (approval_requested_by);


--
-- Name: idx_vendor_payment_approval_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_approval_status ON public.vendor_payment_schedule USING btree (approval_status) WHERE (approval_status = 'sent_for_approval'::text);


--
-- Name: idx_vendor_payment_approved_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_approved_by ON public.vendor_payment_schedule USING btree (approved_by);


--
-- Name: idx_vendor_payment_assigned_approver; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_assigned_approver ON public.vendor_payment_schedule USING btree (assigned_approver_id);


--
-- Name: idx_vendor_payment_schedule_accountant_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_accountant_user_id ON public.vendor_payment_schedule USING btree (accountant_user_id);


--
-- Name: idx_vendor_payment_schedule_adjustments; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_adjustments ON public.vendor_payment_schedule USING btree (last_adjustment_date) WHERE (last_adjustment_date IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule USING btree (branch_id);


--
-- Name: idx_vendor_payment_schedule_due_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_due_date ON public.vendor_payment_schedule USING btree (due_date);


--
-- Name: idx_vendor_payment_schedule_due_date_paid; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_due_date_paid ON public.vendor_payment_schedule USING btree (due_date, is_paid);


--
-- Name: idx_vendor_payment_schedule_grr_ref; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_grr_ref ON public.vendor_payment_schedule USING btree (grr_reference_number) WHERE (grr_reference_number IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_is_paid; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_is_paid ON public.vendor_payment_schedule USING btree (is_paid);


--
-- Name: idx_vendor_payment_schedule_paid_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_paid_date ON public.vendor_payment_schedule USING btree (paid_date);


--
-- Name: idx_vendor_payment_schedule_pr_excel_verified; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified ON public.vendor_payment_schedule USING btree (pr_excel_verified);


--
-- Name: idx_vendor_payment_schedule_pr_excel_verified_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified_by ON public.vendor_payment_schedule USING btree (pr_excel_verified_by);


--
-- Name: idx_vendor_payment_schedule_pri_ref; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_pri_ref ON public.vendor_payment_schedule USING btree (pri_reference_number) WHERE (pri_reference_number IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_receiving_record_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_receiving_record_id ON public.vendor_payment_schedule USING btree (receiving_record_id);


--
-- Name: idx_vendor_payment_schedule_task_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule USING btree (task_id);


--
-- Name: idx_vendor_payment_schedule_vendor_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_vendor_id ON public.vendor_payment_schedule USING btree (vendor_id);


--
-- Name: idx_vendor_payment_schedule_verification_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendor_payment_schedule_verification_status ON public.vendor_payment_schedule USING btree (verification_status);


--
-- Name: vendor_payment_schedule trg_update_final_bill_amount; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_update_final_bill_amount BEFORE INSERT OR UPDATE OF discount_amount, grr_amount, pri_amount, bill_amount ON public.vendor_payment_schedule FOR EACH ROW EXECUTE FUNCTION public.update_final_bill_amount_on_adjustment();


--
-- Name: vendor_payment_schedule vendor_payment_approval_requested_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_approval_requested_by_fkey FOREIGN KEY (approval_requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_approved_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_assigned_approver_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_assigned_approver_fkey FOREIGN KEY (assigned_approver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_pr_excel_verified_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_pr_excel_verified_by_fkey FOREIGN KEY (pr_excel_verified_by) REFERENCES public.users(id);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_receiving_record_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_receiving_record_id_fkey FOREIGN KEY (receiving_record_id) REFERENCES public.receiving_records(id) ON DELETE CASCADE;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_task_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.vendor_payment_schedule ENABLE ROW LEVEL SECURITY;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_delete; Type: POLICY; Schema: public;
--

CREATE POLICY vendor_payment_schedule_delete ON public.vendor_payment_schedule FOR DELETE USING (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_insert; Type: POLICY; Schema: public;
--

CREATE POLICY vendor_payment_schedule_insert ON public.vendor_payment_schedule FOR INSERT WITH CHECK (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_select; Type: POLICY; Schema: public;
--

CREATE POLICY vendor_payment_schedule_select ON public.vendor_payment_schedule FOR SELECT USING (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_update; Type: POLICY; Schema: public;
--

CREATE POLICY vendor_payment_schedule_update ON public.vendor_payment_schedule FOR UPDATE USING (true);