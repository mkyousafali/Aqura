--
-- Name: push_subscriptions; Type: TABLE; Schema: public;
--

CREATE TABLE public.push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    subscription jsonb NOT NULL,
    endpoint text NOT NULL,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone,
    failed_deliveries integer DEFAULT 0,
    is_active boolean DEFAULT true,
    customer_id uuid,
    CONSTRAINT chk_push_sub_user_or_customer CHECK (((user_id IS NOT NULL) OR (customer_id IS NOT NULL)))
);


--
-- Name: push_subscriptions push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: idx_push_subscriptions_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_push_subscriptions_active ON public.push_subscriptions USING btree (user_id, is_active) WHERE (is_active = true);


--
-- Name: idx_push_subscriptions_customer_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_push_subscriptions_customer_active ON public.push_subscriptions USING btree (customer_id, is_active) WHERE ((is_active = true) AND (customer_id IS NOT NULL));


--
-- Name: idx_push_subscriptions_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_push_subscriptions_customer_id ON public.push_subscriptions USING btree (customer_id) WHERE (customer_id IS NOT NULL);


--
-- Name: idx_push_subscriptions_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id);


--
-- Name: push_subscriptions set_push_subscriptions_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER set_push_subscriptions_updated_at BEFORE UPDATE ON public.push_subscriptions FOR EACH ROW EXECUTE FUNCTION public.update_push_subscriptions_updated_at();


--
-- Name: push_subscriptions fk_push_sub_user_id; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT fk_push_sub_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_subscriptions Allow all access to push_subscriptions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to push_subscriptions" ON public.push_subscriptions USING (true) WITH CHECK (true);


--
-- Name: push_subscriptions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;