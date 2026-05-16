--
-- Name: branch_default_delivery_receivers; Type: TABLE; Schema: public;
--

CREATE TABLE public.branch_default_delivery_receivers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id bigint NOT NULL,
    user_id uuid NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_branch_id_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_branch_id_user_id_key UNIQUE (branch_id, user_id);


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_pkey PRIMARY KEY (id);


--
-- Name: idx_branch_delivery_receivers_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branch_delivery_receivers_branch ON public.branch_default_delivery_receivers USING btree (branch_id) WHERE (is_active = true);


--
-- Name: idx_branch_delivery_receivers_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branch_delivery_receivers_user ON public.branch_default_delivery_receivers USING btree (user_id) WHERE (is_active = true);


--
-- Name: branch_default_delivery_receivers set_branch_delivery_receivers_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER set_branch_delivery_receivers_updated_at BEFORE UPDATE ON public.branch_default_delivery_receivers FOR EACH ROW EXECUTE FUNCTION public.update_branch_delivery_receivers_updated_at();


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: branch_default_delivery_receivers Allow all access to branch_default_delivery_receivers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to branch_default_delivery_receivers" ON public.branch_default_delivery_receivers USING (true) WITH CHECK (true);


--
-- Name: branch_default_delivery_receivers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.branch_default_delivery_receivers ENABLE ROW LEVEL SECURITY;