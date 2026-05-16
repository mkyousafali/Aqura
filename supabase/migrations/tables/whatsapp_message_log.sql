--
-- Name: whatsapp_message_log; Type: TABLE; Schema: public;
--

CREATE TABLE public.whatsapp_message_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone_number character varying(20) NOT NULL,
    message_type character varying(50) DEFAULT 'access_code'::character varying NOT NULL,
    template_name character varying(100),
    template_language character varying(10),
    whatsapp_message_id text,
    status character varying(20) DEFAULT 'sent'::character varying,
    customer_name text,
    error_details text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: whatsapp_message_log whatsapp_message_log_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.whatsapp_message_log
    ADD CONSTRAINT whatsapp_message_log_pkey PRIMARY KEY (id);


--
-- Name: idx_whatsapp_log_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_whatsapp_log_created ON public.whatsapp_message_log USING btree (created_at DESC);


--
-- Name: idx_whatsapp_log_phone; Type: INDEX; Schema: public;
--

CREATE INDEX idx_whatsapp_log_phone ON public.whatsapp_message_log USING btree (phone_number);


--
-- Name: whatsapp_message_log Service role full access on whatsapp_message_log; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on whatsapp_message_log" ON public.whatsapp_message_log USING (true) WITH CHECK (true);


--
-- Name: whatsapp_message_log; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.whatsapp_message_log ENABLE ROW LEVEL SECURITY;