--
-- Name: product_request_bt; Type: TABLE; Schema: public;
--

CREATE TABLE public.product_request_bt (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_user_id uuid NOT NULL,
    from_branch_id integer NOT NULL,
    to_branch_id integer NOT NULL,
    target_user_id uuid NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    document_url text
);


--
-- Name: product_request_bt product_request_bt_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_pkey PRIMARY KEY (id);


--
-- Name: idx_product_request_bt_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_created ON public.product_request_bt USING btree (created_at);


--
-- Name: idx_product_request_bt_from_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_from_branch ON public.product_request_bt USING btree (from_branch_id);


--
-- Name: idx_product_request_bt_requester; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_requester ON public.product_request_bt USING btree (requester_user_id);


--
-- Name: idx_product_request_bt_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_status ON public.product_request_bt USING btree (status);


--
-- Name: idx_product_request_bt_target; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_target ON public.product_request_bt USING btree (target_user_id);


--
-- Name: idx_product_request_bt_to_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_bt_to_branch ON public.product_request_bt USING btree (to_branch_id);


--
-- Name: product_request_bt product_request_bt_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER product_request_bt_timestamp_update BEFORE UPDATE ON public.product_request_bt FOR EACH ROW EXECUTE FUNCTION public.update_product_request_bt_timestamp();


--
-- Name: product_request_bt product_request_bt_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_bt product_request_bt_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: product_request_bt product_request_bt_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: product_request_bt product_request_bt_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_bt Allow all access to product_request_bt; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to product_request_bt" ON public.product_request_bt USING (true) WITH CHECK (true);


--
-- Name: product_request_bt; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.product_request_bt ENABLE ROW LEVEL SECURITY;