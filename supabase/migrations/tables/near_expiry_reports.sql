--
-- Name: near_expiry_reports; Type: TABLE; Schema: public;
--

CREATE TABLE public.near_expiry_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_user_id uuid NOT NULL,
    branch_id integer,
    target_user_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    title text,
    CONSTRAINT near_expiry_reports_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reviewed'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: near_expiry_reports near_expiry_reports_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_pkey PRIMARY KEY (id);


--
-- Name: idx_near_expiry_reports_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_near_expiry_reports_branch ON public.near_expiry_reports USING btree (branch_id);


--
-- Name: idx_near_expiry_reports_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_near_expiry_reports_created ON public.near_expiry_reports USING btree (created_at DESC);


--
-- Name: idx_near_expiry_reports_reporter; Type: INDEX; Schema: public;
--

CREATE INDEX idx_near_expiry_reports_reporter ON public.near_expiry_reports USING btree (reporter_user_id);


--
-- Name: idx_near_expiry_reports_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_near_expiry_reports_status ON public.near_expiry_reports USING btree (status);


--
-- Name: idx_near_expiry_reports_target; Type: INDEX; Schema: public;
--

CREATE INDEX idx_near_expiry_reports_target ON public.near_expiry_reports USING btree (target_user_id);


--
-- Name: near_expiry_reports trigger_update_near_expiry_reports_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_near_expiry_reports_updated_at BEFORE UPDATE ON public.near_expiry_reports FOR EACH ROW EXECUTE FUNCTION public.update_near_expiry_reports_updated_at();


--
-- Name: near_expiry_reports near_expiry_reports_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: near_expiry_reports near_expiry_reports_reporter_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_reporter_user_id_fkey FOREIGN KEY (reporter_user_id) REFERENCES public.users(id);


--
-- Name: near_expiry_reports near_expiry_reports_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: near_expiry_reports Allow all access to near_expiry_reports; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to near_expiry_reports" ON public.near_expiry_reports USING (true) WITH CHECK (true);


--
-- Name: near_expiry_reports; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.near_expiry_reports ENABLE ROW LEVEL SECURITY;