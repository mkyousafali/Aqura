--
-- Name: pos_deduction_transfers; Type: TABLE; Schema: public;
--

CREATE TABLE public.pos_deduction_transfers (
    id text NOT NULL,
    box_number integer NOT NULL,
    branch_id integer NOT NULL,
    cashier_user_id text NOT NULL,
    closed_by uuid,
    short_amount numeric(10,2) DEFAULT 0 NOT NULL,
    status public.pos_deduction_status DEFAULT 'Proposed'::public.pos_deduction_status NOT NULL,
    date_created_box timestamp with time zone NOT NULL,
    date_closed_box timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    completed_by_name character varying(255),
    box_operation_id uuid NOT NULL,
    applied boolean DEFAULT false
);


--
-- Name: pos_deduction_transfers pos_deduction_transfers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_pkey PRIMARY KEY (id, box_number, date_closed_box);


--
-- Name: idx_pos_deduction_transfers_applied; Type: INDEX; Schema: public;
--

CREATE INDEX idx_pos_deduction_transfers_applied ON public.pos_deduction_transfers USING btree (applied);


--
-- Name: idx_pos_deduction_transfers_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_pos_deduction_transfers_branch ON public.pos_deduction_transfers USING btree (branch_id);


--
-- Name: idx_pos_deduction_transfers_cashier; Type: INDEX; Schema: public;
--

CREATE INDEX idx_pos_deduction_transfers_cashier ON public.pos_deduction_transfers USING btree (cashier_user_id);


--
-- Name: idx_pos_deduction_transfers_date_closed; Type: INDEX; Schema: public;
--

CREATE INDEX idx_pos_deduction_transfers_date_closed ON public.pos_deduction_transfers USING btree (date_closed_box);


--
-- Name: pos_deduction_transfers trigger_update_pos_deduction_transfers_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_pos_deduction_transfers_updated_at BEFORE UPDATE ON public.pos_deduction_transfers FOR EACH ROW EXECUTE FUNCTION public.update_pos_deduction_transfers_updated_at();


--
-- Name: pos_deduction_transfers pos_deduction_transfers_box_operation_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_box_operation_id_fkey FOREIGN KEY (box_operation_id) REFERENCES public.box_operations(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_cashier_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_cashier_user_id_fkey FOREIGN KEY (cashier_user_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_closed_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_id_fkey FOREIGN KEY (id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers Allow all access to pos_deduction_transfers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to pos_deduction_transfers" ON public.pos_deduction_transfers USING (true) WITH CHECK (true);


--
-- Name: pos_deduction_transfers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.pos_deduction_transfers ENABLE ROW LEVEL SECURITY;