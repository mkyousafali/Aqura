--
-- Name: customer_product_requests; Type: TABLE; Schema: public;
--

CREATE TABLE public.customer_product_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_user_id uuid NOT NULL,
    branch_id integer,
    target_user_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customer_product_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reviewed'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: customer_product_requests customer_product_requests_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_pkey PRIMARY KEY (id);


--
-- Name: idx_customer_product_requests_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_product_requests_branch ON public.customer_product_requests USING btree (branch_id);


--
-- Name: idx_customer_product_requests_requester; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_product_requests_requester ON public.customer_product_requests USING btree (requester_user_id);


--
-- Name: idx_customer_product_requests_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_product_requests_status ON public.customer_product_requests USING btree (status);


--
-- Name: idx_customer_product_requests_target; Type: INDEX; Schema: public;
--

CREATE INDEX idx_customer_product_requests_target ON public.customer_product_requests USING btree (target_user_id);


--
-- Name: customer_product_requests customer_product_requests_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: customer_product_requests customer_product_requests_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: customer_product_requests customer_product_requests_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: customer_product_requests Allow all access to customer_product_requests; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to customer_product_requests" ON public.customer_product_requests USING (true) WITH CHECK (true);


--
-- Name: customer_product_requests; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.customer_product_requests ENABLE ROW LEVEL SECURITY;