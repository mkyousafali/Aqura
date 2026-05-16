--
-- Name: gift_wheel_rewards; Type: TABLE; Schema: public;
--

CREATE TABLE public.gift_wheel_rewards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    label text NOT NULL,
    reward_type text DEFAULT 'percentage'::text NOT NULL,
    value numeric DEFAULT 0 NOT NULL,
    max_discount numeric,
    min_bill numeric DEFAULT 0 NOT NULL,
    weight integer DEFAULT 1 NOT NULL,
    usage_limit integer,
    usage_count integer DEFAULT 0 NOT NULL,
    expiry_date date,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    validity_days integer DEFAULT 7 NOT NULL,
    reward_label_en text,
    reward_label_ar text,
    CONSTRAINT gift_wheel_rewards_reward_type_check CHECK ((reward_type = ANY (ARRAY['percentage'::text, 'fixed'::text, 'no_reward'::text])))
);


--
-- Name: gift_wheel_rewards gift_wheel_rewards_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_rewards
    ADD CONSTRAINT gift_wheel_rewards_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_rewards Allow anon all gift_wheel_rewards; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon all gift_wheel_rewards" ON public.gift_wheel_rewards TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_rewards Allow authenticated all gift_wheel_rewards; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated all gift_wheel_rewards" ON public.gift_wheel_rewards TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_rewards; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.gift_wheel_rewards ENABLE ROW LEVEL SECURITY;