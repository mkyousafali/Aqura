--
-- Name: lease_rent_payments; Type: TABLE; Schema: public;
--

CREATE TABLE public.lease_rent_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    party_type character varying(10) NOT NULL,
    party_id uuid NOT NULL,
    period_num integer NOT NULL,
    period_from date NOT NULL,
    period_to date NOT NULL,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    paid_amount numeric(12,2) DEFAULT 0 NOT NULL,
    is_fully_paid boolean DEFAULT false NOT NULL,
    paid_at timestamp with time zone DEFAULT now(),
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    paid_contract numeric(12,2) DEFAULT 0,
    paid_outside numeric(12,2) DEFAULT 0,
    paid_utility numeric(12,2) DEFAULT 0,
    paid_security numeric(12,2) DEFAULT 0,
    paid_other numeric(12,2) DEFAULT 0,
    paid_date date,
    CONSTRAINT lease_rent_payments_party_type_check CHECK (((party_type)::text = ANY ((ARRAY['rent'::character varying, 'lease'::character varying])::text[])))
);


--
-- Name: lease_rent_payments lease_rent_payments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_payments lease_rent_payments_unique_period; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_unique_period UNIQUE (party_type, party_id, period_num);


--
-- Name: idx_payments_party; Type: INDEX; Schema: public;
--

CREATE INDEX idx_payments_party ON public.lease_rent_payments USING btree (party_type, party_id);


--
-- Name: idx_payments_party_period; Type: INDEX; Schema: public;
--

CREATE UNIQUE INDEX idx_payments_party_period ON public.lease_rent_payments USING btree (party_type, party_id, period_num);


--
-- Name: lease_rent_payments lease_rent_payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: lease_rent_payments Allow all access to lease_rent_payments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to lease_rent_payments" ON public.lease_rent_payments USING (true) WITH CHECK (true);


--
-- Name: lease_rent_payments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.lease_rent_payments ENABLE ROW LEVEL SECURITY;