--
-- Name: purchase_voucher_issue_types; Type: TABLE; Schema: public;
--

CREATE TABLE public.purchase_voucher_issue_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type_name character varying NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: purchase_voucher_issue_types purchase_voucher_issue_types_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.purchase_voucher_issue_types
    ADD CONSTRAINT purchase_voucher_issue_types_pkey PRIMARY KEY (id);


--
-- Name: purchase_voucher_issue_types purchase_voucher_issue_types_type_name_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.purchase_voucher_issue_types
    ADD CONSTRAINT purchase_voucher_issue_types_type_name_key UNIQUE (type_name);


--
-- Name: idx_issue_types_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_issue_types_name ON public.purchase_voucher_issue_types USING btree (type_name);


--
-- Name: purchase_voucher_issue_types issue_types_updated_at_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER issue_types_updated_at_trigger BEFORE UPDATE ON public.purchase_voucher_issue_types FOR EACH ROW EXECUTE FUNCTION public.update_issue_types_updated_at();


--
-- Name: purchase_voucher_issue_types; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.purchase_voucher_issue_types ENABLE ROW LEVEL SECURITY;


--
-- Name: purchase_voucher_issue_types pv_issue_types_authenticated_all; Type: POLICY; Schema: public;
--

CREATE POLICY pv_issue_types_authenticated_all ON public.purchase_voucher_issue_types USING (true);


--
-- Name: purchase_voucher_issue_types pv_issue_types_service_role_all; Type: POLICY; Schema: public;
--

CREATE POLICY pv_issue_types_service_role_all ON public.purchase_voucher_issue_types USING (true);