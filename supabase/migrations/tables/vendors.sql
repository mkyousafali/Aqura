--
-- Name: vendors; Type: TABLE; Schema: public;
--

CREATE TABLE public.vendors (
    erp_vendor_id integer NOT NULL,
    vendor_name text NOT NULL,
    salesman_name text,
    salesman_contact text,
    supervisor_name text,
    supervisor_contact text,
    vendor_contact_number text,
    payment_method text,
    credit_period integer,
    bank_name text,
    iban text,
    status text DEFAULT 'Active'::text,
    last_visit timestamp without time zone,
    categories text[],
    delivery_modes text[],
    place text,
    location_link text,
    return_expired_products text,
    return_expired_products_note text,
    return_near_expiry_products text,
    return_near_expiry_products_note text,
    return_over_stock text,
    return_over_stock_note text,
    return_damage_products text,
    return_damage_products_note text,
    no_return boolean DEFAULT false,
    no_return_note text,
    vat_applicable text DEFAULT 'VAT Applicable'::text,
    vat_number text,
    no_vat_note text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    branch_id bigint NOT NULL,
    payment_priority text DEFAULT 'Normal'::text,
    CONSTRAINT vendors_payment_priority_check CHECK ((payment_priority = ANY (ARRAY['Most'::text, 'Medium'::text, 'Normal'::text, 'Low'::text])))
);


--
-- Name: vendors vendors_erp_vendor_branch_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_erp_vendor_branch_unique UNIQUE (erp_vendor_id, branch_id);


--
-- Name: vendors vendors_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (erp_vendor_id, branch_id);


--
-- Name: idx_vendors_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_branch_id ON public.vendors USING btree (branch_id) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_vendors_branch_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_branch_status ON public.vendors USING btree (branch_id, status) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_vendors_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_created_at ON public.vendors USING btree (created_at);


--
-- Name: idx_vendors_erp_vendor_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_erp_vendor_id ON public.vendors USING btree (erp_vendor_id);


--
-- Name: idx_vendors_payment_method; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_payment_method ON public.vendors USING gin (to_tsvector('english'::regconfig, payment_method));


--
-- Name: idx_vendors_payment_priority; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_payment_priority ON public.vendors USING btree (payment_priority);


--
-- Name: idx_vendors_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_status ON public.vendors USING btree (status);


--
-- Name: idx_vendors_vat_applicable; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_vat_applicable ON public.vendors USING btree (vat_applicable);


--
-- Name: idx_vendors_vendor_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vendors_vendor_name ON public.vendors USING btree (vendor_name);


--
-- Name: vendors vendors_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: vendors allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.vendors FOR DELETE USING (true);


--
-- Name: vendors allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.vendors FOR INSERT WITH CHECK (true);


--
-- Name: vendors allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.vendors FOR SELECT USING (true);


--
-- Name: vendors allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.vendors FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: vendors rls_delete; Type: POLICY; Schema: public;
--

CREATE POLICY rls_delete ON public.vendors FOR DELETE USING (true);


--
-- Name: vendors rls_insert; Type: POLICY; Schema: public;
--

CREATE POLICY rls_insert ON public.vendors FOR INSERT WITH CHECK (true);


--
-- Name: vendors rls_select; Type: POLICY; Schema: public;
--

CREATE POLICY rls_select ON public.vendors FOR SELECT USING (true);


--
-- Name: vendors rls_update; Type: POLICY; Schema: public;
--

CREATE POLICY rls_update ON public.vendors FOR UPDATE WITH CHECK (true);


--
-- Name: vendors; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;