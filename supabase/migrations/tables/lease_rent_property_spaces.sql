--
-- Name: lease_rent_property_spaces; Type: TABLE; Schema: public;
--

CREATE TABLE public.lease_rent_property_spaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    property_id uuid NOT NULL,
    space_number character varying(100) NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_pkey1; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_pkey1 PRIMARY KEY (id);


--
-- Name: lease_rent_property_spaces unique_property_space_number; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT unique_property_space_number UNIQUE (property_id, space_number);


--
-- Name: idx_lease_rent_property_spaces_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_lease_rent_property_spaces_created_by ON public.lease_rent_property_spaces USING btree (created_by);


--
-- Name: idx_lease_rent_property_spaces_property_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_lease_rent_property_spaces_property_id ON public.lease_rent_property_spaces USING btree (property_id);


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER lease_rent_property_spaces_timestamp_update BEFORE UPDATE ON public.lease_rent_property_spaces FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_property_spaces_timestamp();


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_created_by_fkey1; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_created_by_fkey1 FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_property_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.lease_rent_properties(id) ON DELETE CASCADE;


--
-- Name: lease_rent_property_spaces Allow all access to lease_rent_property_spaces; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to lease_rent_property_spaces" ON public.lease_rent_property_spaces USING (true) WITH CHECK (true);


--
-- Name: lease_rent_property_spaces; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.lease_rent_property_spaces ENABLE ROW LEVEL SECURITY;