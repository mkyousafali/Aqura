--
-- Name: wa_conversations; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid,
    customer_id uuid,
    customer_phone character varying(20) NOT NULL,
    customer_name text,
    last_message_at timestamp with time zone,
    last_message_preview text,
    unread_count integer DEFAULT 0,
    is_bot_handling boolean DEFAULT false,
    bot_type character varying(20),
    status character varying(20) DEFAULT 'active'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    branch_id uuid,
    handled_by character varying(20) DEFAULT 'bot'::character varying,
    window_expires_at timestamp with time zone,
    needs_human boolean DEFAULT false,
    is_sos boolean DEFAULT false
);


--
-- Name: wa_conversations wa_conversations_account_phone_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_account_phone_unique UNIQUE (wa_account_id, customer_phone);


--
-- Name: wa_conversations wa_conversations_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_conv_account_status_lastmsg; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conv_account_status_lastmsg ON public.wa_conversations USING btree (wa_account_id, status, last_message_at DESC);


--
-- Name: idx_wa_conversations_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conversations_account ON public.wa_conversations USING btree (wa_account_id);


--
-- Name: idx_wa_conversations_customer; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conversations_customer ON public.wa_conversations USING btree (customer_id);


--
-- Name: idx_wa_conversations_last_msg; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conversations_last_msg ON public.wa_conversations USING btree (last_message_at DESC);


--
-- Name: idx_wa_conversations_phone; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conversations_phone ON public.wa_conversations USING btree (customer_phone);


--
-- Name: idx_wa_conversations_sos; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_conversations_sos ON public.wa_conversations USING btree (is_sos) WHERE (is_sos = true);


--
-- Name: wa_conversations wa_conversations_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: wa_conversations wa_conversations_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_conversations Allow all access to wa_conversations; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to wa_conversations" ON public.wa_conversations USING (true) WITH CHECK (true);


--
-- Name: wa_conversations; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_conversations ENABLE ROW LEVEL SECURITY;