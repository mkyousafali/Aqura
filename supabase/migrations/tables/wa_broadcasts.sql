--
-- Name: wa_broadcasts; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_broadcasts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid,
    name text,
    template_id uuid,
    recipient_filter character varying(20) DEFAULT 'all'::character varying,
    recipient_group_id uuid,
    total_recipients integer DEFAULT 0,
    sent_count integer DEFAULT 0,
    delivered_count integer DEFAULT 0,
    read_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    status character varying(20) DEFAULT 'draft'::character varying,
    scheduled_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    retry_attempted boolean DEFAULT false,
    last_activity text,
    last_activity_at timestamp with time zone
);

ALTER TABLE ONLY public.wa_broadcasts REPLICA IDENTITY FULL;


--
-- Name: wa_broadcasts wa_broadcasts_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_broadcasts_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_broadcasts_account ON public.wa_broadcasts USING btree (wa_account_id);


--
-- Name: idx_wa_broadcasts_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_broadcasts_created ON public.wa_broadcasts USING btree (created_at DESC);


--
-- Name: idx_wa_broadcasts_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_broadcasts_status ON public.wa_broadcasts USING btree (status);


--
-- Name: wa_broadcasts wa_broadcasts_recipient_group_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_recipient_group_id_fkey FOREIGN KEY (recipient_group_id) REFERENCES public.wa_contact_groups(id) ON DELETE SET NULL;


--
-- Name: wa_broadcasts wa_broadcasts_template_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.wa_templates(id) ON DELETE SET NULL;


--
-- Name: wa_broadcasts wa_broadcasts_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_broadcasts Allow all access to wa_broadcasts; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to wa_broadcasts" ON public.wa_broadcasts USING (true) WITH CHECK (true);


--
-- Name: wa_broadcasts; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_broadcasts ENABLE ROW LEVEL SECURITY;