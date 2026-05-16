--
-- Name: vip_redemptions; Type: TABLE; Schema: public;
--

CREATE TABLE public.vip_redemptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid,
    whatsapp_number text NOT NULL,
    bill_number text NOT NULL,
    bill_amount numeric(12,2) NOT NULL,
    discounted_value numeric(12,2) NOT NULL,
    redeemed_date date DEFAULT CURRENT_DATE NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now() NOT NULL,
    cashier_id text,
    branch_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vip_redemptions vip_redemptions_number_date_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vip_redemptions
    ADD CONSTRAINT vip_redemptions_number_date_unique UNIQUE (whatsapp_number, redeemed_date);


--
-- Name: vip_redemptions vip_redemptions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.vip_redemptions
    ADD CONSTRAINT vip_redemptions_pkey PRIMARY KEY (id);


--
-- Name: idx_vip_redemptions_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vip_redemptions_customer_id ON public.vip_redemptions USING btree (customer_id);


--
-- Name: idx_vip_redemptions_redeemed_date; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vip_redemptions_redeemed_date ON public.vip_redemptions USING btree (redeemed_date);


--
-- Name: idx_vip_redemptions_whatsapp_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_vip_redemptions_whatsapp_number ON public.vip_redemptions USING btree (whatsapp_number);


--
-- Name: vip_redemptions trg_vip_redemptions_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_vip_redemptions_updated_at BEFORE UPDATE ON public.vip_redemptions FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();


--
-- Name: vip_redemptions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.vip_redemptions ENABLE ROW LEVEL SECURITY;


--
-- Name: vip_redemptions vip_redemptions_delete; Type: POLICY; Schema: public;
--

CREATE POLICY vip_redemptions_delete ON public.vip_redemptions FOR DELETE TO authenticated, anon USING (true);


--
-- Name: vip_redemptions vip_redemptions_insert; Type: POLICY; Schema: public;
--

CREATE POLICY vip_redemptions_insert ON public.vip_redemptions FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: vip_redemptions vip_redemptions_select; Type: POLICY; Schema: public;
--

CREATE POLICY vip_redemptions_select ON public.vip_redemptions FOR SELECT TO authenticated, anon USING (true);


--
-- Name: vip_redemptions vip_redemptions_update; Type: POLICY; Schema: public;
--

CREATE POLICY vip_redemptions_update ON public.vip_redemptions FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);