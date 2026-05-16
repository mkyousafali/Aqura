--
-- Name: wa_settings; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid,
    business_name text,
    business_description text,
    business_address text,
    business_email text,
    business_website text,
    business_category text,
    profile_picture_url text,
    about_text text,
    webhook_url text,
    webhook_verify_token text,
    webhook_active boolean DEFAULT false,
    business_hours jsonb DEFAULT '{}'::jsonb,
    outside_hours_message text,
    default_language character varying(10) DEFAULT 'en'::character varying,
    notify_new_message boolean DEFAULT true,
    notify_bot_escalation boolean DEFAULT true,
    notify_broadcast_complete boolean DEFAULT true,
    notify_template_status boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    auto_reply_enabled boolean DEFAULT false
);


--
-- Name: wa_settings wa_settings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_pkey PRIMARY KEY (id);


--
-- Name: wa_settings wa_settings_wa_account_id_unique; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_wa_account_id_unique UNIQUE (wa_account_id);


--
-- Name: idx_wa_settings_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_settings_account ON public.wa_settings USING btree (wa_account_id);


--
-- Name: wa_settings wa_settings_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_settings Service role full access on wa_settings; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on wa_settings" ON public.wa_settings USING (true) WITH CHECK (true);


--
-- Name: wa_settings allow_all_wa_settings; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_wa_settings ON public.wa_settings USING (true) WITH CHECK (true);


--
-- Name: wa_settings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_settings ENABLE ROW LEVEL SECURITY;