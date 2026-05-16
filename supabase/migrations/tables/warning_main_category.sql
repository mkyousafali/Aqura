--
-- Name: warning_main_category; Type: TABLE; Schema: public;
--

CREATE TABLE public.warning_main_category (
    id character varying(10) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: warning_main_category warning_main_category_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_main_category
    ADD CONSTRAINT warning_main_category_pkey PRIMARY KEY (id);


--
-- Name: idx_warning_main_category_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_main_category_name_en ON public.warning_main_category USING btree (name_en);


--
-- Name: warning_main_category warning_main_category_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER warning_main_category_timestamp_update BEFORE UPDATE ON public.warning_main_category FOR EACH ROW EXECUTE FUNCTION public.update_warning_main_category_timestamp();


--
-- Name: warning_main_category Allow all access to warning_main_category; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to warning_main_category" ON public.warning_main_category USING (true) WITH CHECK (true);


--
-- Name: warning_main_category; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.warning_main_category ENABLE ROW LEVEL SECURITY;