--
-- Name: product_request_st; Type: TABLE; Schema: public;
--

CREATE TABLE public.product_request_st (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_user_id uuid NOT NULL,
    branch_id integer NOT NULL,
    target_user_id uuid NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    document_url text
);


--
-- Name: product_request_st product_request_st_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_pkey PRIMARY KEY (id);


--
-- Name: idx_product_request_st_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_st_branch ON public.product_request_st USING btree (branch_id);


--
-- Name: idx_product_request_st_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_st_created ON public.product_request_st USING btree (created_at);


--
-- Name: idx_product_request_st_requester; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_st_requester ON public.product_request_st USING btree (requester_user_id);


--
-- Name: idx_product_request_st_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_st_status ON public.product_request_st USING btree (status);


--
-- Name: idx_product_request_st_target; Type: INDEX; Schema: public;
--

CREATE INDEX idx_product_request_st_target ON public.product_request_st USING btree (target_user_id);


--
-- Name: product_request_st product_request_st_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER product_request_st_timestamp_update BEFORE UPDATE ON public.product_request_st FOR EACH ROW EXECUTE FUNCTION public.update_product_request_st_timestamp();


--
-- Name: product_request_st product_request_st_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_st product_request_st_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: product_request_st product_request_st_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: product_request_st Allow all access to product_request_st; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to product_request_st" ON public.product_request_st USING (true) WITH CHECK (true);


--
-- Name: product_request_st; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.product_request_st ENABLE ROW LEVEL SECURITY;