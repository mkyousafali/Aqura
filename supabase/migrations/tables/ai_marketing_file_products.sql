--
-- Name: ai_marketing_file_products; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_marketing_file_products (
    file_id bigint NOT NULL,
    product_id character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: ai_marketing_file_products ai_marketing_file_products_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_file_products
    ADD CONSTRAINT ai_marketing_file_products_pkey PRIMARY KEY (file_id, product_id);


--
-- Name: idx_ai_marketing_fp_product; Type: INDEX; Schema: public;
--

CREATE INDEX idx_ai_marketing_fp_product ON public.ai_marketing_file_products USING btree (product_id);


--
-- Name: ai_marketing_file_products ai_marketing_file_products_file_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_file_products
    ADD CONSTRAINT ai_marketing_file_products_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE;


--
-- Name: ai_marketing_file_products ai_marketing_file_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_marketing_file_products
    ADD CONSTRAINT ai_marketing_file_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: ai_marketing_file_products; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_marketing_file_products ENABLE ROW LEVEL SECURITY;


--
-- Name: ai_marketing_file_products allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.ai_marketing_file_products FOR DELETE USING (true);


--
-- Name: ai_marketing_file_products allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.ai_marketing_file_products FOR INSERT WITH CHECK (true);


--
-- Name: ai_marketing_file_products allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.ai_marketing_file_products FOR SELECT USING (true);


--
-- Name: ai_marketing_file_products allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.ai_marketing_file_products FOR UPDATE USING (true) WITH CHECK (true);