--
-- Name: lease_rent_payment_entries; Type: TABLE; Schema: public;
--

CREATE TABLE public.lease_rent_payment_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    party_type character varying(10) NOT NULL,
    party_id uuid NOT NULL,
    period_num integer NOT NULL,
    column_name character varying(20) NOT NULL,
    amount numeric(12,2) NOT NULL,
    paid_date date DEFAULT CURRENT_DATE NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: lease_rent_payment_entries lease_rent_payment_entries_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_payment_entries
    ADD CONSTRAINT lease_rent_payment_entries_pkey PRIMARY KEY (id);


--
-- Name: idx_payment_entries_party; Type: INDEX; Schema: public;
--

CREATE INDEX idx_payment_entries_party ON public.lease_rent_payment_entries USING btree (party_type, party_id, period_num, column_name);


--
-- Name: lease_rent_payment_entries allow_all_payment_entries; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_payment_entries ON public.lease_rent_payment_entries USING (true) WITH CHECK (true);


--
-- Name: lease_rent_payment_entries; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.lease_rent_payment_entries ENABLE ROW LEVEL SECURITY;