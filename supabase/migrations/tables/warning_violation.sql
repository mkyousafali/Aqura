--
-- Name: warning_violation; Type: TABLE; Schema: public;
--

CREATE TABLE public.warning_violation (
    id character varying(10) NOT NULL,
    sub_category_id character varying(10) NOT NULL,
    main_category_id character varying(10) NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: warning_violation warning_violation_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_pkey PRIMARY KEY (id);


--
-- Name: idx_warning_violation_main_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_violation_main_id ON public.warning_violation USING btree (main_category_id);


--
-- Name: idx_warning_violation_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_violation_name_en ON public.warning_violation USING btree (name_en);


--
-- Name: idx_warning_violation_sub_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_warning_violation_sub_id ON public.warning_violation USING btree (sub_category_id);


--
-- Name: warning_violation warning_violation_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER warning_violation_timestamp_update BEFORE UPDATE ON public.warning_violation FOR EACH ROW EXECUTE FUNCTION public.update_warning_violation_timestamp();


--
-- Name: warning_violation warning_violation_main_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_main_category_id_fkey FOREIGN KEY (main_category_id) REFERENCES public.warning_main_category(id) ON DELETE CASCADE;


--
-- Name: warning_violation warning_violation_sub_category_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_sub_category_id_fkey FOREIGN KEY (sub_category_id) REFERENCES public.warning_sub_category(id) ON DELETE CASCADE;


--
-- Name: warning_violation Allow all access to warning_violation; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to warning_violation" ON public.warning_violation USING (true) WITH CHECK (true);


--
-- Name: warning_violation; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.warning_violation ENABLE ROW LEVEL SECURITY;