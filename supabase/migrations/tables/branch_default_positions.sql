--
-- Name: branch_default_positions; Type: TABLE; Schema: public;
--

CREATE TABLE public.branch_default_positions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id integer NOT NULL,
    branch_manager_user_id uuid,
    purchasing_manager_user_id uuid,
    inventory_manager_user_id uuid,
    accountant_user_id uuid,
    night_supervisor_user_ids uuid[] DEFAULT '{}'::uuid[],
    warehouse_handler_user_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: branch_default_positions branch_default_positions_branch_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_id_key UNIQUE (branch_id);


--
-- Name: branch_default_positions branch_default_positions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_pkey PRIMARY KEY (id);


--
-- Name: idx_branch_default_positions_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branch_default_positions_branch_id ON public.branch_default_positions USING btree (branch_id);


--
-- Name: branch_default_positions branch_default_positions_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER branch_default_positions_timestamp_update BEFORE UPDATE ON public.branch_default_positions FOR EACH ROW EXECUTE FUNCTION public.update_branch_default_positions_timestamp();


--
-- Name: branch_default_positions branch_default_positions_accountant_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_accountant_user_id_fkey FOREIGN KEY (accountant_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_default_positions branch_default_positions_branch_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_manager_user_id_fkey FOREIGN KEY (branch_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_inventory_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_inventory_manager_user_id_fkey FOREIGN KEY (inventory_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_purchasing_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_purchasing_manager_user_id_fkey FOREIGN KEY (purchasing_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_warehouse_handler_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_warehouse_handler_user_id_fkey FOREIGN KEY (warehouse_handler_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions Allow all access to branch_default_positions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to branch_default_positions" ON public.branch_default_positions USING (true) WITH CHECK (true);


--
-- Name: branch_default_positions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.branch_default_positions ENABLE ROW LEVEL SECURITY;