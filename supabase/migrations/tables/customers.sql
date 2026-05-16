--
-- Name: customers; Type: TABLE; Schema: public;
--

CREATE TABLE public.customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    access_code text,
    whatsapp_number character varying(20),
    registration_status text DEFAULT 'pending'::text NOT NULL,
    registration_notes text,
    approved_by uuid,
    approved_at timestamp with time zone,
    access_code_generated_at timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    name text,
    location1_name text,
    location1_url text,
    location2_name text,
    location2_url text,
    location3_name text,
    location3_url text,
    location1_lat double precision,
    location1_lng double precision,
    location2_lat double precision,
    location2_lng double precision,
    location3_lat double precision,
    location3_lng double precision,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    whatsapp_available boolean,
    erp_branch_id integer,
    CONSTRAINT customers_location1_name_len CHECK (((location1_name IS NULL) OR (length(location1_name) <= 120))),
    CONSTRAINT customers_location1_url_len CHECK (((location1_url IS NULL) OR (length(location1_url) <= 2048))),
    CONSTRAINT customers_location2_name_len CHECK (((location2_name IS NULL) OR (length(location2_name) <= 120))),
    CONSTRAINT customers_location2_url_len CHECK (((location2_url IS NULL) OR (length(location2_url) <= 2048))),
    CONSTRAINT customers_location3_name_len CHECK (((location3_name IS NULL) OR (length(location3_name) <= 120))),
    CONSTRAINT customers_location3_url_len CHECK (((location3_url IS NULL) OR (length(location3_url) <= 2048))),
    CONSTRAINT customers_registration_status_check CHECK ((registration_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'suspended'::text, 'pre_registered'::text, 'deleted'::text]))),
    CONSTRAINT customers_whatsapp_format_check CHECK (((whatsapp_number)::text ~ '^\+?[1-9]\d{1,14}$'::text))
);


--
-- Name: customers customers_access_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_access_code_key UNIQUE (access_code);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: customers customers_whatsapp_number_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_whatsapp_number_unique UNIQUE (whatsapp_number);


--
-- Name: idx_customers_access_code; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customers_access_code ON public.customers USING btree (access_code) WHERE (access_code IS NOT NULL);


--
-- Name: idx_customers_approved_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customers_approved_by ON public.customers USING btree (approved_by);


--
-- Name: idx_customers_is_deleted; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customers_is_deleted ON public.customers USING btree (is_deleted) WHERE (is_deleted = true);


--
-- Name: idx_customers_registration_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customers_registration_status ON public.customers USING btree (registration_status);


--
-- Name: idx_customers_whatsapp; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customers_whatsapp ON public.customers USING btree (whatsapp_number) WHERE (whatsapp_number IS NOT NULL);


--
-- Name: customers trigger_update_customers_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.update_customers_updated_at();


--
-- Name: customers customers_approved_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: customers Allow anon insert customers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert customers" ON public.customers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customers allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.customers USING (true) WITH CHECK (true);


--
-- Name: customers allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.customers FOR DELETE USING (true);


--
-- Name: customers allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.customers FOR INSERT WITH CHECK (true);


--
-- Name: customers allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.customers FOR SELECT USING (true);


--
-- Name: customers allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.customers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customers anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.customers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customers authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.customers USING ((auth.uid() IS NOT NULL));


--
-- Name: customers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;


--
-- Name: customers customers_delete_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customers_delete_policy ON public.customers FOR DELETE USING (true);


--
-- Name: customers customers_insert_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customers_insert_policy ON public.customers FOR INSERT WITH CHECK (true);


--
-- Name: customers customers_select_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customers_select_policy ON public.customers FOR SELECT USING (true);


--
-- Name: customers customers_update_policy; Type: POLICY; Schema: public;
--

CREATE POLICY customers_update_policy ON public.customers FOR UPDATE USING (true);


--
-- Name: customers realtime_customers_select; Type: POLICY; Schema: public;
--

CREATE POLICY realtime_customers_select ON public.customers FOR SELECT TO authenticated, anon USING (true);