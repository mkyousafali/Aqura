--
-- Name: wa_messages; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid,
    wa_account_id uuid,
    whatsapp_message_id text,
    direction character varying(10) DEFAULT 'outbound'::character varying NOT NULL,
    message_type character varying(20) DEFAULT 'text'::character varying,
    content text,
    media_url text,
    media_mime_type character varying(50),
    template_name character varying(100),
    template_language character varying(10),
    status character varying(20) DEFAULT 'sent'::character varying,
    sent_by character varying(20) DEFAULT 'user'::character varying,
    sent_by_user_id uuid,
    error_details text,
    created_at timestamp with time zone DEFAULT now(),
    delivered_at timestamp with time zone,
    read_at timestamp with time zone,
    metadata jsonb
);


--
-- Name: wa_messages wa_messages_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_pkey PRIMARY KEY (id);


--
-- Name: wa_messages wa_messages_whatsapp_message_id_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_whatsapp_message_id_unique UNIQUE (whatsapp_message_id);


--
-- Name: idx_wa_messages_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_account ON public.wa_messages USING btree (wa_account_id);


--
-- Name: idx_wa_messages_conv_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_conv_created ON public.wa_messages USING btree (conversation_id, created_at DESC);


--
-- Name: idx_wa_messages_conversation; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_conversation ON public.wa_messages USING btree (conversation_id);


--
-- Name: idx_wa_messages_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_created ON public.wa_messages USING btree (created_at DESC);


--
-- Name: idx_wa_messages_direction; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_direction ON public.wa_messages USING btree (direction);


--
-- Name: idx_wa_messages_wa_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_messages_wa_id ON public.wa_messages USING btree (whatsapp_message_id);


--
-- Name: wa_messages_wamid_unique; Type: INDEX; Schema: public;
--

CREATE UNIQUE INDEX wa_messages_wamid_unique ON public.wa_messages USING btree (whatsapp_message_id) WHERE ((whatsapp_message_id IS NOT NULL) AND (whatsapp_message_id <> ''::text));


--
-- Name: wa_messages wa_messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.wa_conversations(id) ON DELETE CASCADE;


--
-- Name: wa_messages wa_messages_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_messages Service role full access on wa_messages; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on wa_messages" ON public.wa_messages USING (true) WITH CHECK (true);


--
-- Name: wa_messages realtime_wa_messages_select; Type: POLICY; Schema: public;
--

CREATE POLICY realtime_wa_messages_select ON public.wa_messages FOR SELECT TO authenticated, anon USING (true);


--
-- Name: wa_messages; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_messages ENABLE ROW LEVEL SECURITY;