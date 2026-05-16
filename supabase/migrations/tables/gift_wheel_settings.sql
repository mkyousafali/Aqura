--
-- Name: gift_wheel_settings; Type: TABLE; Schema: public;
--

CREATE TABLE public.gift_wheel_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    active boolean DEFAULT false NOT NULL,
    start_datetime timestamp with time zone,
    end_datetime timestamp with time zone,
    daily_limit integer DEFAULT 100 NOT NULL,
    timezone text DEFAULT 'Asia/Riyadh'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    minimum_bill_amount numeric DEFAULT 0 NOT NULL
);


--
-- Name: gift_wheel_settings gift_wheel_settings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_settings
    ADD CONSTRAINT gift_wheel_settings_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_settings Allow anon all gift_wheel_settings; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon all gift_wheel_settings" ON public.gift_wheel_settings TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_settings Allow authenticated all gift_wheel_settings; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated all gift_wheel_settings" ON public.gift_wheel_settings TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_settings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.gift_wheel_settings ENABLE ROW LEVEL SECURITY;