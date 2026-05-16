--
-- Name: erp_daily_sales; Type: TABLE; Schema: public;
--

CREATE TABLE public.erp_daily_sales (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    branch_id bigint NOT NULL,
    sale_date date NOT NULL,
    total_bills integer DEFAULT 0,
    gross_amount numeric(18,2) DEFAULT 0,
    tax_amount numeric(18,2) DEFAULT 0,
    discount_amount numeric(18,2) DEFAULT 0,
    total_returns integer DEFAULT 0,
    return_amount numeric(18,2) DEFAULT 0,
    return_tax numeric(18,2) DEFAULT 0,
    net_bills integer DEFAULT 0,
    net_amount numeric(18,2) DEFAULT 0,
    net_tax numeric(18,2) DEFAULT 0,
    last_sync_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: erp_daily_sales erp_daily_sales_branch_id_sale_date_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_branch_id_sale_date_key UNIQUE (branch_id, sale_date);


--
-- Name: erp_daily_sales erp_daily_sales_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_pkey PRIMARY KEY (id);


--
-- Name: idx_erp_daily_sales_branch_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_daily_sales_branch_date ON public.erp_daily_sales USING btree (branch_id, sale_date);


--
-- Name: idx_erp_daily_sales_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_daily_sales_branch_id ON public.erp_daily_sales USING btree (branch_id);


--
-- Name: idx_erp_daily_sales_sale_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_daily_sales_sale_date ON public.erp_daily_sales USING btree (sale_date);


--
-- Name: erp_daily_sales erp_daily_sales_notify_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER erp_daily_sales_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON public.erp_daily_sales FOR EACH ROW EXECUTE FUNCTION public.notify_erp_daily_sales_change();


--
-- Name: erp_daily_sales update_erp_daily_sales_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_erp_daily_sales_updated_at BEFORE UPDATE ON public.erp_daily_sales FOR EACH ROW EXECUTE FUNCTION public.update_erp_daily_sales_updated_at();


--
-- Name: erp_daily_sales erp_daily_sales_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: erp_daily_sales Allow anon insert erp_daily_sales; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert erp_daily_sales" ON public.erp_daily_sales FOR INSERT TO anon WITH CHECK (true);


--
-- Name: erp_daily_sales Allow authenticated users to read sales data; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated users to read sales data" ON public.erp_daily_sales FOR SELECT TO authenticated USING (true);


--
-- Name: erp_daily_sales Allow service role to manage sales data; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role to manage sales data" ON public.erp_daily_sales TO service_role USING (true);


--
-- Name: erp_daily_sales allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.erp_daily_sales USING (true) WITH CHECK (true);


--
-- Name: erp_daily_sales allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.erp_daily_sales FOR DELETE USING (true);


--
-- Name: erp_daily_sales allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.erp_daily_sales FOR INSERT WITH CHECK (true);


--
-- Name: erp_daily_sales allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.erp_daily_sales FOR SELECT USING (true);


--
-- Name: erp_daily_sales allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.erp_daily_sales FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: erp_daily_sales anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.erp_daily_sales USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: erp_daily_sales authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.erp_daily_sales USING ((auth.uid() IS NOT NULL));


--
-- Name: erp_daily_sales; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.erp_daily_sales ENABLE ROW LEVEL SECURITY;