--
-- Name: lease_rent_properties; Type: TABLE; Schema: public;
--

CREATE TABLE public.lease_rent_properties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    location_en character varying(500),
    location_ar character varying(500),
    is_leased boolean DEFAULT false,
    is_rented boolean DEFAULT false,
    created_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: lease_rent_properties lease_rent_property_spaces_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_properties
    ADD CONSTRAINT lease_rent_property_spaces_pkey PRIMARY KEY (id);


--
-- Name: idx_lease_rent_properties_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_lease_rent_properties_created_by ON public.lease_rent_properties USING btree (created_by);


--
-- Name: idx_lease_rent_properties_is_leased; Type: INDEX; Schema: public;
--

CREATE INDEX idx_lease_rent_properties_is_leased ON public.lease_rent_properties USING btree (is_leased);


--
-- Name: idx_lease_rent_properties_is_rented; Type: INDEX; Schema: public;
--

CREATE INDEX idx_lease_rent_properties_is_rented ON public.lease_rent_properties USING btree (is_rented);


--
-- Name: lease_rent_properties lease_rent_properties_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER lease_rent_properties_timestamp_update BEFORE UPDATE ON public.lease_rent_properties FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_property_spaces_timestamp();


--
-- Name: lease_rent_properties lease_rent_property_spaces_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_properties
    ADD CONSTRAINT lease_rent_property_spaces_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_properties Allow all access to lease_rent_properties; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to lease_rent_properties" ON public.lease_rent_properties USING (true) WITH CHECK (true);


--
-- Name: lease_rent_properties; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.lease_rent_properties ENABLE ROW LEVEL SECURITY;