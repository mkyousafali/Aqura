--
-- Name: wa_auto_reply_triggers; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_auto_reply_triggers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid,
    name text,
    trigger_words_en text[] DEFAULT '{}'::text[],
    trigger_words_ar text[] DEFAULT '{}'::text[],
    match_type character varying(20) DEFAULT 'contains'::character varying,
    reply_type character varying(20) DEFAULT 'text'::character varying,
    reply_text text,
    reply_media_url text,
    reply_template_id uuid,
    reply_buttons jsonb DEFAULT '[]'::jsonb,
    follow_up_trigger_id uuid,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    trigger_words text[] DEFAULT ARRAY[]::text[],
    response_type character varying(20) DEFAULT 'text'::character varying,
    response_content text,
    response_media_url text,
    response_template_name text,
    response_buttons jsonb DEFAULT '[]'::jsonb,
    follow_up_delay_seconds integer DEFAULT 0,
    follow_up_content text,
    priority integer DEFAULT 0
);


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_auto_reply_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_auto_reply_account ON public.wa_auto_reply_triggers USING btree (wa_account_id);


--
-- Name: idx_wa_auto_reply_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_auto_reply_active ON public.wa_auto_reply_triggers USING btree (is_active);


--
-- Name: idx_wa_auto_reply_order; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_auto_reply_order ON public.wa_auto_reply_triggers USING btree (sort_order);


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_follow_up_trigger_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_follow_up_trigger_id_fkey FOREIGN KEY (follow_up_trigger_id) REFERENCES public.wa_auto_reply_triggers(id) ON DELETE SET NULL;


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_reply_template_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_reply_template_id_fkey FOREIGN KEY (reply_template_id) REFERENCES public.wa_templates(id) ON DELETE SET NULL;


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_auto_reply_triggers Service role full access on wa_auto_reply_triggers; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on wa_auto_reply_triggers" ON public.wa_auto_reply_triggers USING (true) WITH CHECK (true);


--
-- Name: wa_auto_reply_triggers allow_all_wa_auto_reply; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_wa_auto_reply ON public.wa_auto_reply_triggers USING (true) WITH CHECK (true);


--
-- Name: wa_auto_reply_triggers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_auto_reply_triggers ENABLE ROW LEVEL SECURITY;