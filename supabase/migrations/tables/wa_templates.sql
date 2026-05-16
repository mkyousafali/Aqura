--
-- Name: wa_templates; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wa_account_id uuid,
    meta_template_id text,
    name character varying(100) NOT NULL,
    category character varying(20) DEFAULT 'UTILITY'::character varying,
    language character varying(10) DEFAULT 'en'::character varying,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    header_type character varying(20) DEFAULT 'none'::character varying,
    header_content text,
    body_text text,
    footer_text text,
    buttons jsonb DEFAULT '[]'::jsonb,
    meta_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: wa_templates wa_templates_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_templates
    ADD CONSTRAINT wa_templates_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_templates_account; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_templates_account ON public.wa_templates USING btree (wa_account_id);


--
-- Name: idx_wa_templates_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_templates_name ON public.wa_templates USING btree (name);


--
-- Name: idx_wa_templates_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_templates_status ON public.wa_templates USING btree (status);


--
-- Name: wa_templates wa_templates_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_templates
    ADD CONSTRAINT wa_templates_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_templates Allow all access to wa_templates; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to wa_templates" ON public.wa_templates USING (true) WITH CHECK (true);


--
-- Name: wa_templates; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_templates ENABLE ROW LEVEL SECURITY;