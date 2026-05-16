--
-- Name: button_permissions; Type: TABLE; Schema: public;
--

CREATE TABLE public.button_permissions (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    button_id bigint NOT NULL,
    is_enabled boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: button_permissions button_permissions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT button_permissions_pkey PRIMARY KEY (id);


--
-- Name: button_permissions button_permissions_user_id_button_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT button_permissions_user_id_button_id_key UNIQUE (user_id, button_id);


--
-- Name: idx_button_permissions_button; Type: INDEX; Schema: public;
--

CREATE INDEX idx_button_permissions_button ON public.button_permissions USING btree (button_id);


--
-- Name: idx_button_permissions_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_button_permissions_user ON public.button_permissions USING btree (user_id);


--
-- Name: button_permissions fk_button; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT fk_button FOREIGN KEY (button_id) REFERENCES public.sidebar_buttons(id) ON DELETE CASCADE;


--
-- Name: button_permissions fk_user; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: button_permissions allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.button_permissions FOR DELETE USING (true);


--
-- Name: button_permissions allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.button_permissions FOR INSERT WITH CHECK (true);


--
-- Name: button_permissions allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.button_permissions FOR SELECT USING (true);


--
-- Name: button_permissions allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.button_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_permissions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.button_permissions ENABLE ROW LEVEL SECURITY;