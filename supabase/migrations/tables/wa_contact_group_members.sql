--
-- Name: wa_contact_group_members; Type: TABLE; Schema: public;
--

CREATE TABLE public.wa_contact_group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid,
    customer_id uuid,
    added_at timestamp with time zone DEFAULT now()
);


--
-- Name: wa_contact_group_members wa_contact_group_members_group_id_customer_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_group_id_customer_id_key UNIQUE (group_id, customer_id);


--
-- Name: wa_contact_group_members wa_contact_group_members_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_pkey PRIMARY KEY (id);


--
-- Name: idx_wa_group_members_customer; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_group_members_customer ON public.wa_contact_group_members USING btree (customer_id);


--
-- Name: idx_wa_group_members_group; Type: INDEX; Schema: public;
--

CREATE INDEX idx_wa_group_members_group ON public.wa_contact_group_members USING btree (group_id);


--
-- Name: wa_contact_group_members wa_contact_group_members_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: wa_contact_group_members wa_contact_group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.wa_contact_groups(id) ON DELETE CASCADE;


--
-- Name: wa_contact_group_members Service role full access on wa_contact_group_members; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on wa_contact_group_members" ON public.wa_contact_group_members USING (true) WITH CHECK (true);


--
-- Name: wa_contact_group_members; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.wa_contact_group_members ENABLE ROW LEVEL SECURITY;