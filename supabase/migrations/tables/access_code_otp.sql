--
-- Name: access_code_otp; Type: TABLE; Schema: public;
--

CREATE TABLE public.access_code_otp (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    otp_code character varying(6) NOT NULL,
    email character varying(255) NOT NULL,
    whatsapp_number character varying(20) NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:05:00'::interval) NOT NULL,
    verified boolean DEFAULT false,
    attempts integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: access_code_otp access_code_otp_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.access_code_otp
    ADD CONSTRAINT access_code_otp_pkey PRIMARY KEY (id);


--
-- Name: idx_access_code_otp_expires; Type: INDEX; Schema: public;
--

CREATE INDEX idx_access_code_otp_expires ON public.access_code_otp USING btree (expires_at);


--
-- Name: idx_access_code_otp_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_access_code_otp_user ON public.access_code_otp USING btree (user_id);


--
-- Name: access_code_otp access_code_otp_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.access_code_otp
    ADD CONSTRAINT access_code_otp_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: access_code_otp; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.access_code_otp ENABLE ROW LEVEL SECURITY;


--
-- Name: access_code_otp anon_insert; Type: POLICY; Schema: public;
--

CREATE POLICY anon_insert ON public.access_code_otp FOR INSERT TO anon WITH CHECK (true);


--
-- Name: access_code_otp service_role_all; Type: POLICY; Schema: public;
--

CREATE POLICY service_role_all ON public.access_code_otp TO service_role USING (true) WITH CHECK (true);