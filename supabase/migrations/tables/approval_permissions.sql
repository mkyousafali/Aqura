--
-- Name: approval_permissions; Type: TABLE; Schema: public;
--

CREATE TABLE public.approval_permissions (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    can_approve_requisitions boolean DEFAULT false NOT NULL,
    requisition_amount_limit numeric(15,2) DEFAULT 0.00,
    can_approve_single_bill boolean DEFAULT false NOT NULL,
    single_bill_amount_limit numeric(15,2) DEFAULT 0.00,
    can_approve_multiple_bill boolean DEFAULT false NOT NULL,
    multiple_bill_amount_limit numeric(15,2) DEFAULT 0.00,
    can_approve_recurring_bill boolean DEFAULT false NOT NULL,
    recurring_bill_amount_limit numeric(15,2) DEFAULT 0.00,
    can_approve_vendor_payments boolean DEFAULT false NOT NULL,
    vendor_payment_amount_limit numeric(15,2) DEFAULT 0.00,
    can_approve_leave_requests boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    is_active boolean DEFAULT true NOT NULL,
    can_approve_purchase_vouchers boolean DEFAULT false NOT NULL,
    can_add_missing_punches boolean DEFAULT false NOT NULL,
    can_receive_customer_incidents boolean DEFAULT false NOT NULL,
    can_receive_employee_incidents boolean DEFAULT false NOT NULL,
    can_receive_maintenance_incidents boolean DEFAULT false NOT NULL,
    can_receive_vendor_incidents boolean DEFAULT false NOT NULL,
    can_receive_vehicle_incidents boolean DEFAULT false NOT NULL,
    can_receive_government_incidents boolean DEFAULT false NOT NULL,
    can_receive_other_incidents boolean DEFAULT false NOT NULL,
    can_receive_finance_incidents boolean DEFAULT false NOT NULL,
    can_receive_pos_incidents boolean DEFAULT false NOT NULL,
    CONSTRAINT approval_permissions_multiple_bill_limit_check CHECK ((multiple_bill_amount_limit >= (0)::numeric)),
    CONSTRAINT approval_permissions_recurring_bill_limit_check CHECK ((recurring_bill_amount_limit >= (0)::numeric)),
    CONSTRAINT approval_permissions_requisition_limit_check CHECK ((requisition_amount_limit >= (0)::numeric)),
    CONSTRAINT approval_permissions_single_bill_limit_check CHECK ((single_bill_amount_limit >= (0)::numeric)),
    CONSTRAINT approval_permissions_vendor_payment_limit_check CHECK ((vendor_payment_amount_limit >= (0)::numeric))
);


--
-- Name: approval_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.approval_permissions_id_seq OWNED BY public.approval_permissions.id;


--
-- Name: approval_permissions id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions ALTER COLUMN id SET DEFAULT nextval('public.approval_permissions_id_seq'::regclass);


--
-- Name: approval_permissions approval_permissions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_pkey PRIMARY KEY (id);


--
-- Name: approval_permissions approval_permissions_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_user_id_key UNIQUE (user_id);


--
-- Name: idx_approval_permissions_add_missing_punches; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_add_missing_punches ON public.approval_permissions USING btree (can_add_missing_punches) WHERE ((can_add_missing_punches = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_customer_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_customer_incidents ON public.approval_permissions USING btree (can_receive_customer_incidents) WHERE ((can_receive_customer_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_employee_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_employee_incidents ON public.approval_permissions USING btree (can_receive_employee_incidents) WHERE ((can_receive_employee_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_finance_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_finance_incidents ON public.approval_permissions USING btree (can_receive_finance_incidents) WHERE ((can_receive_finance_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_government_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_government_incidents ON public.approval_permissions USING btree (can_receive_government_incidents) WHERE ((can_receive_government_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_is_active ON public.approval_permissions USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approval_permissions_leave_requests; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_leave_requests ON public.approval_permissions USING btree (can_approve_leave_requests) WHERE ((can_approve_leave_requests = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_maintenance_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_maintenance_incidents ON public.approval_permissions USING btree (can_receive_maintenance_incidents) WHERE ((can_receive_maintenance_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_multiple_bill; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_multiple_bill ON public.approval_permissions USING btree (can_approve_multiple_bill) WHERE ((can_approve_multiple_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_other_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_other_incidents ON public.approval_permissions USING btree (can_receive_other_incidents) WHERE ((can_receive_other_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_pos_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_pos_incidents ON public.approval_permissions USING btree (can_receive_pos_incidents) WHERE ((can_receive_pos_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_purchase_vouchers; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_purchase_vouchers ON public.approval_permissions USING btree (can_approve_purchase_vouchers) WHERE ((can_approve_purchase_vouchers = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_recurring_bill; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_recurring_bill ON public.approval_permissions USING btree (can_approve_recurring_bill) WHERE ((can_approve_recurring_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_requisitions; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_requisitions ON public.approval_permissions USING btree (can_approve_requisitions) WHERE ((can_approve_requisitions = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_single_bill; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_single_bill ON public.approval_permissions USING btree (can_approve_single_bill) WHERE ((can_approve_single_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_user_id ON public.approval_permissions USING btree (user_id);


--
-- Name: idx_approval_permissions_vehicle_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_vehicle_incidents ON public.approval_permissions USING btree (can_receive_vehicle_incidents) WHERE ((can_receive_vehicle_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_vendor_incidents; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_vendor_incidents ON public.approval_permissions USING btree (can_receive_vendor_incidents) WHERE ((can_receive_vendor_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_vendor_payments; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approval_permissions_vendor_payments ON public.approval_permissions USING btree (can_approve_vendor_payments) WHERE ((can_approve_vendor_payments = true) AND (is_active = true));


--
-- Name: approval_permissions update_approval_permissions_timestamp; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_approval_permissions_timestamp BEFORE UPDATE ON public.approval_permissions FOR EACH ROW EXECUTE FUNCTION public.update_approval_permissions_updated_at();


--
-- Name: approval_permissions approval_permissions_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approval_permissions approval_permissions_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approval_permissions approval_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: approval_permissions Allow all access to approval_permissions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to approval_permissions" ON public.approval_permissions USING (true) WITH CHECK (true);


--
-- Name: approval_permissions Allow all to view approval permissions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all to view approval permissions" ON public.approval_permissions FOR SELECT USING (true);


--
-- Name: approval_permissions Allow anon insert approval_permissions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert approval_permissions" ON public.approval_permissions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: approval_permissions allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.approval_permissions USING (true) WITH CHECK (true);


--
-- Name: approval_permissions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.approval_permissions FOR DELETE USING (true);


--
-- Name: approval_permissions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.approval_permissions FOR INSERT WITH CHECK (true);


--
-- Name: approval_permissions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.approval_permissions FOR SELECT USING (true);


--
-- Name: approval_permissions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.approval_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: approval_permissions anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.approval_permissions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: approval_permissions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.approval_permissions ENABLE ROW LEVEL SECURITY;


--
-- Name: approval_permissions authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.approval_permissions USING ((auth.uid() IS NOT NULL));