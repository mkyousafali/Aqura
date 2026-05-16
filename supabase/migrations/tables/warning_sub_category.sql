--
-- Name: warning_sub_category; Type: TABLE; Schema: public;
--

CREATE TABLE public.warning_sub_category (
    id character varying(10) NOT NULL,
    main_category_id character varying(10) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: warning_sub_category warning_sub_category_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_sub_category
    ADD CONSTRAINT warning_sub_category_pkey PRIMARY KEY (id);


--
-- Name: idx_warning_sub_category_main_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_sub_category_main_id ON public.warning_sub_category USING btree (main_category_id);


--
-- Name: idx_warning_sub_category_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_sub_category_name_en ON public.warning_sub_category USING btree (name_en);


--
-- Name: warning_sub_category warning_sub_category_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER warning_sub_category_timestamp_update BEFORE UPDATE ON public.warning_sub_category FOR EACH ROW EXECUTE FUNCTION public.update_warning_sub_category_timestamp();


--
-- Name: warning_sub_category warning_sub_category_main_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_sub_category
    ADD CONSTRAINT warning_sub_category_main_category_id_fkey FOREIGN KEY (main_category_id) REFERENCES public.warning_main_category(id) ON DELETE CASCADE;


--
-- Name: warning_sub_category Allow all access to warning_sub_category; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to warning_sub_category" ON public.warning_sub_category USING (true) WITH CHECK (true);


--
-- Name: warning_sub_category; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.warning_sub_category ENABLE ROW LEVEL SECURITY;