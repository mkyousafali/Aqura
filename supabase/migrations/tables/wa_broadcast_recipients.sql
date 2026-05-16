--
-- Name: wa_broadcast_recipients; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_broadcast_recipients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    broadcast_id uuid,
    customer_id uuid,
    phone_number character varying(20) NOT NULL,
    customer_name text,
    whatsapp_message_id text,
    status character varying(20) DEFAULT 'pending'::character varying,
    error_details text,
    sent_at timestamp with time zone
);

ALTER TABLE ONLY public.wa_broadcast_recipients REPLICA IDENTITY FULL;


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_broadcast_recip_broadcast; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_broadcast_recip_broadcast ON public.wa_broadcast_recipients USING btree (broadcast_id);


--
-- Name: idx_wa_broadcast_recip_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_broadcast_recip_status ON public.wa_broadcast_recipients USING btree (status);


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_broadcast_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_broadcast_id_fkey FOREIGN KEY (broadcast_id) REFERENCES public.wa_broadcasts(id) ON DELETE CASCADE;


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: wa_broadcast_recipients Allow all access to wa_broadcast_recipients; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to wa_broadcast_recipients" ON public.wa_broadcast_recipients USING (true) WITH CHECK (true);


--
-- Name: wa_broadcast_recipients; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_broadcast_recipients ENABLE ROW LEVEL SECURITY;