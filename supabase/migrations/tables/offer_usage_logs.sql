--
-- Name: offer_usage_logs; Type: TABLE; Schema: public;
--

CREATE TABLE public.offer_usage_logs (
    id integer NOT NULL,
    offer_id integer NOT NULL,
    customer_id uuid,
    order_id uuid,
    discount_applied numeric(10,2) NOT NULL,
    original_amount numeric(10,2) NOT NULL,
    final_amount numeric(10,2) NOT NULL,
    cart_items jsonb,
    used_at timestamp with time zone DEFAULT now(),
    session_id character varying(255) DEFAULT NULL::character varying,
    device_type character varying(50) DEFAULT NULL::character varying
);


--
-- Name: offer_usage_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.offer_usage_logs_id_seq OWNED BY public.offer_usage_logs.id;


--
-- Name: offer_usage_logs id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.offer_usage_logs ALTER COLUMN id SET DEFAULT nextval('public.offer_usage_logs_id_seq'::regclass);


--
-- Name: offer_usage_logs offer_usage_logs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_offer_usage_logs_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_usage_logs_customer_id ON public.offer_usage_logs USING btree (customer_id);


--
-- Name: idx_offer_usage_logs_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_usage_logs_offer_id ON public.offer_usage_logs USING btree (offer_id);


--
-- Name: idx_offer_usage_logs_order_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_usage_logs_order_id ON public.offer_usage_logs USING btree (order_id);


--
-- Name: idx_offer_usage_logs_order_offer; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_usage_logs_order_offer ON public.offer_usage_logs USING btree (order_id, offer_id);


--
-- Name: idx_offer_usage_logs_used_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_usage_logs_used_at ON public.offer_usage_logs USING btree (used_at DESC);


--
-- Name: offer_usage_logs offer_usage_logs_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: offer_usage_logs offer_usage_logs_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_usage_logs Allow anon insert offer_usage_logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert offer_usage_logs" ON public.offer_usage_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_usage_logs allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.offer_usage_logs USING (true) WITH CHECK (true);


--
-- Name: offer_usage_logs allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.offer_usage_logs FOR DELETE USING (true);


--
-- Name: offer_usage_logs allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.offer_usage_logs FOR INSERT WITH CHECK (true);


--
-- Name: offer_usage_logs allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.offer_usage_logs FOR SELECT USING (true);


--
-- Name: offer_usage_logs allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.offer_usage_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_usage_logs anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.offer_usage_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_usage_logs authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.offer_usage_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_usage_logs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.offer_usage_logs ENABLE ROW LEVEL SECURITY;