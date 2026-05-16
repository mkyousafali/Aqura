--
-- Name: gift_wheel_coupons; Type: TABLE; Schema: public;
--

CREATE TABLE public.gift_wheel_coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    reward_id uuid NOT NULL,
    reward_label text,
    reward_type text,
    reward_value numeric,
    max_discount numeric,
    expiry_date date,
    printed_at timestamp with time zone,
    redeemed_at timestamp with time zone,
    redeemed_amount numeric,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    branch_id text,
    bill_number text,
    bill_amount numeric,
    redeemed_bill_number text,
    bill_date text,
    reward_label_en text,
    reward_label_ar text,
    CONSTRAINT gift_wheel_coupons_status_check CHECK ((status = ANY (ARRAY['active'::text, 'issued'::text, 'printed'::text, 'redeemed'::text, 'expired'::text, 'cancelled'::text])))
);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_code_key UNIQUE (code);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_pkey PRIMARY KEY (id);


--
-- Name: idx_gift_wheel_coupons_code; Type: INDEX; Schema: public;
--

CREATE INDEX idx_gift_wheel_coupons_code ON public.gift_wheel_coupons USING btree (code);


--
-- Name: idx_gift_wheel_coupons_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_gift_wheel_coupons_status ON public.gift_wheel_coupons USING btree (status);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_reward_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.gift_wheel_rewards(id) ON DELETE CASCADE;


--
-- Name: gift_wheel_coupons Allow anon all gift_wheel_coupons; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon all gift_wheel_coupons" ON public.gift_wheel_coupons TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_coupons Allow authenticated all gift_wheel_coupons; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated all gift_wheel_coupons" ON public.gift_wheel_coupons TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_coupons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.gift_wheel_coupons ENABLE ROW LEVEL SECURITY;