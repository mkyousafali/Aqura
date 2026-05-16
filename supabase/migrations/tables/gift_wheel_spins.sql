--
-- Name: gift_wheel_spins; Type: TABLE; Schema: public;
--

CREATE TABLE public.gift_wheel_spins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bill_number text NOT NULL,
    bill_amount numeric DEFAULT 0 NOT NULL,
    bill_image_url text,
    reward_id uuid,
    reward_label text,
    coupon_code text,
    is_winner boolean DEFAULT false NOT NULL,
    rejected boolean DEFAULT false NOT NULL,
    reject_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    bill_date text,
    reward_label_ar text,
    reward_label_en text,
    manual_entry boolean DEFAULT false NOT NULL,
    manual_entry_by uuid,
    manual_entry_username text
);


--
-- Name: gift_wheel_spins gift_wheel_spins_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_spins
    ADD CONSTRAINT gift_wheel_spins_pkey PRIMARY KEY (id);


--
-- Name: idx_gift_wheel_spins_bill_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_gift_wheel_spins_bill_number ON public.gift_wheel_spins USING btree (bill_number);


--
-- Name: idx_gift_wheel_spins_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_gift_wheel_spins_created_at ON public.gift_wheel_spins USING btree (created_at);


--
-- Name: gift_wheel_spins gift_wheel_spins_reward_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.gift_wheel_spins
    ADD CONSTRAINT gift_wheel_spins_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.gift_wheel_rewards(id);


--
-- Name: gift_wheel_spins Allow anon all gift_wheel_spins; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon all gift_wheel_spins" ON public.gift_wheel_spins TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_spins Allow authenticated all gift_wheel_spins; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated all gift_wheel_spins" ON public.gift_wheel_spins TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_spins; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.gift_wheel_spins ENABLE ROW LEVEL SECURITY;