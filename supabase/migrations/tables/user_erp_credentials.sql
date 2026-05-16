--
-- Name: user_erp_credentials; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_erp_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    branch_id bigint NOT NULL,
    erp_username text NOT NULL,
    erp_password text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_erp_credentials uq_user_erp_credentials_user_branch; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT uq_user_erp_credentials_user_branch UNIQUE (user_id, branch_id);


--
-- Name: user_erp_credentials user_erp_credentials_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_pkey PRIMARY KEY (id);


--
-- Name: idx_user_erp_credentials_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_erp_credentials_branch_id ON public.user_erp_credentials USING btree (branch_id);


--
-- Name: idx_user_erp_credentials_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_erp_credentials_user_id ON public.user_erp_credentials USING btree (user_id);


--
-- Name: user_erp_credentials trg_user_erp_credentials_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_user_erp_credentials_updated_at BEFORE UPDATE ON public.user_erp_credentials FOR EACH ROW EXECUTE FUNCTION public.set_user_erp_credentials_updated_at();


--
-- Name: user_erp_credentials user_erp_credentials_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: user_erp_credentials user_erp_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_erp_credentials allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.user_erp_credentials USING (true) WITH CHECK (true);


--
-- Name: user_erp_credentials; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_erp_credentials ENABLE ROW LEVEL SECURITY;