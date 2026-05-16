--
-- Name: lease_rent_special_changes; Type: TABLE; Schema: public;
--

CREATE TABLE public.lease_rent_special_changes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    party_type character varying(10) NOT NULL,
    party_id uuid NOT NULL,
    field_name character varying(50) NOT NULL,
    old_value numeric(12,2) DEFAULT 0,
    new_value numeric(12,2) NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    till_end_of_contract boolean DEFAULT false,
    payment_period character varying(20) DEFAULT 'monthly'::character varying,
    reason text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    CONSTRAINT lease_rent_special_changes_party_type_check CHECK (((party_type)::text = ANY ((ARRAY['rent'::character varying, 'lease'::character varying])::text[])))
);


--
-- Name: lease_rent_special_changes lease_rent_special_changes_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_special_changes
    ADD CONSTRAINT lease_rent_special_changes_pkey PRIMARY KEY (id);


--
-- Name: idx_special_changes_dates; Type: INDEX; Schema: public;
--

CREATE INDEX idx_special_changes_dates ON public.lease_rent_special_changes USING btree (effective_from, effective_until);


--
-- Name: idx_special_changes_party; Type: INDEX; Schema: public;
--

CREATE INDEX idx_special_changes_party ON public.lease_rent_special_changes USING btree (party_type, party_id);


--
-- Name: lease_rent_special_changes lease_rent_special_changes_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_special_changes
    ADD CONSTRAINT lease_rent_special_changes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: lease_rent_special_changes allow_all_lease_rent_special_changes; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_lease_rent_special_changes ON public.lease_rent_special_changes USING (true) WITH CHECK (true);


--
-- Name: lease_rent_special_changes; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.lease_rent_special_changes ENABLE ROW LEVEL SECURITY;