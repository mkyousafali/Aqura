--
-- Name: delivery_service_settings; Type: TABLE; Schema: public;
--

CREATE TABLE public.delivery_service_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    minimum_order_amount numeric(10,2) DEFAULT 15.00 NOT NULL,
    is_24_hours boolean DEFAULT true NOT NULL,
    operating_start_time time without time zone,
    operating_end_time time without time zone,
    is_active boolean DEFAULT true NOT NULL,
    display_message_ar text DEFAULT 'التوصيل متاح على مدار الساعة (24/7)'::text,
    display_message_en text DEFAULT 'Delivery available 24/7'::text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    customer_login_mask_enabled boolean DEFAULT true NOT NULL,
    CONSTRAINT delivery_settings_singleton CHECK ((id = '00000000-0000-0000-0000-000000000001'::uuid))
);

ALTER TABLE ONLY public.delivery_service_settings REPLICA IDENTITY FULL;


--
-- Name: delivery_service_settings delivery_service_settings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.delivery_service_settings
    ADD CONSTRAINT delivery_service_settings_pkey PRIMARY KEY (id);


--
-- Name: delivery_service_settings trigger_update_delivery_settings_timestamp; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_delivery_settings_timestamp BEFORE UPDATE ON public.delivery_service_settings FOR EACH ROW EXECUTE FUNCTION public.update_delivery_tiers_timestamp();


--
-- Name: delivery_service_settings delivery_service_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.delivery_service_settings
    ADD CONSTRAINT delivery_service_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: delivery_service_settings Allow anon insert delivery_service_settings; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert delivery_service_settings" ON public.delivery_service_settings FOR INSERT TO anon WITH CHECK (true);


--
-- Name: delivery_service_settings allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.delivery_service_settings USING (true) WITH CHECK (true);


--
-- Name: delivery_service_settings allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.delivery_service_settings FOR DELETE USING (true);


--
-- Name: delivery_service_settings allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.delivery_service_settings FOR INSERT WITH CHECK (true);


--
-- Name: delivery_service_settings allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.delivery_service_settings FOR SELECT USING (true);


--
-- Name: delivery_service_settings allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.delivery_service_settings FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: delivery_service_settings anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.delivery_service_settings USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: delivery_service_settings authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.delivery_service_settings USING ((auth.uid() IS NOT NULL));


--
-- Name: delivery_service_settings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.delivery_service_settings ENABLE ROW LEVEL SECURITY;


--
-- Name: delivery_service_settings delivery_settings_allow_read; Type: POLICY; Schema: public;
--

CREATE POLICY delivery_settings_allow_read ON public.delivery_service_settings FOR SELECT USING (true);