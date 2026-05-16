--
-- Name: customer_app_media; Type: TABLE; Schema: public;
--

CREATE TABLE public.customer_app_media (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    media_type character varying(10) NOT NULL,
    slot_number integer NOT NULL,
    title_en character varying(255) NOT NULL,
    title_ar character varying(255) NOT NULL,
    description_en text,
    description_ar text,
    file_url text NOT NULL,
    file_size bigint,
    file_type character varying(50),
    duration integer,
    is_active boolean DEFAULT false,
    display_order integer DEFAULT 0,
    is_infinite boolean DEFAULT false,
    expiry_date timestamp with time zone,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    activated_at timestamp with time zone,
    deactivated_at timestamp with time zone,
    CONSTRAINT customer_app_media_media_type_check CHECK (((media_type)::text = ANY (ARRAY[('video'::character varying)::text, ('image'::character varying)::text]))),
    CONSTRAINT customer_app_media_slot_number_check CHECK (((slot_number >= 1) AND (slot_number <= 6))),
    CONSTRAINT expiry_required_unless_infinite CHECK (((is_infinite = true) OR (expiry_date IS NOT NULL)))
);


--
-- Name: customer_app_media customer_app_media_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT customer_app_media_pkey PRIMARY KEY (id);


--
-- Name: customer_app_media unique_slot_per_type; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT unique_slot_per_type UNIQUE (media_type, slot_number);


--
-- Name: idx_customer_app_media_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_app_media_active ON public.customer_app_media USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_customer_app_media_display_order; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_app_media_display_order ON public.customer_app_media USING btree (display_order);


--
-- Name: idx_customer_app_media_expiry; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_app_media_expiry ON public.customer_app_media USING btree (expiry_date) WHERE (expiry_date IS NOT NULL);


--
-- Name: idx_customer_app_media_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_app_media_type ON public.customer_app_media USING btree (media_type);


--
-- Name: customer_app_media track_media_activation; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER track_media_activation BEFORE UPDATE ON public.customer_app_media FOR EACH ROW EXECUTE FUNCTION public.track_media_activation();


--
-- Name: customer_app_media update_customer_app_media_timestamp; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_customer_app_media_timestamp BEFORE UPDATE ON public.customer_app_media FOR EACH ROW EXECUTE FUNCTION public.update_customer_app_media_timestamp();


--
-- Name: customer_app_media customer_app_media_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT customer_app_media_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


--
-- Name: customer_app_media Allow anon insert customer_app_media; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert customer_app_media" ON public.customer_app_media FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_app_media allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.customer_app_media USING (true) WITH CHECK (true);


--
-- Name: customer_app_media allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.customer_app_media FOR DELETE USING (true);


--
-- Name: customer_app_media allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.customer_app_media FOR INSERT WITH CHECK (true);


--
-- Name: customer_app_media allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.customer_app_media FOR SELECT USING (true);


--
-- Name: customer_app_media allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.customer_app_media FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_app_media anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.customer_app_media USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_app_media authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.customer_app_media USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_app_media; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.customer_app_media ENABLE ROW LEVEL SECURITY;