--
-- Name: incidents; Type: TABLE; Schema: public;
--

CREATE TABLE public.incidents (
    id text NOT NULL,
    incident_type_id text NOT NULL,
    employee_id text,
    branch_id bigint NOT NULL,
    violation_id text,
    what_happened jsonb NOT NULL,
    witness_details jsonb,
    report_type text DEFAULT 'employee_related'::text NOT NULL,
    reports_to_user_ids uuid[] DEFAULT ARRAY[]::uuid[] NOT NULL,
    claims_status text,
    claimed_user_id uuid,
    resolution_status public.resolution_status DEFAULT 'reported'::public.resolution_status NOT NULL,
    user_statuses jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    attachments jsonb DEFAULT '[]'::jsonb,
    investigation_report jsonb,
    related_party jsonb,
    resolution_report jsonb
);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: idx_incidents_attachments; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_attachments ON public.incidents USING gin (attachments);


--
-- Name: idx_incidents_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_branch_id ON public.incidents USING btree (branch_id);


--
-- Name: idx_incidents_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_created_at ON public.incidents USING btree (created_at DESC);


--
-- Name: idx_incidents_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_employee_id ON public.incidents USING btree (employee_id);


--
-- Name: idx_incidents_incident_type_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_incident_type_id ON public.incidents USING btree (incident_type_id);


--
-- Name: idx_incidents_related_party; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_related_party ON public.incidents USING gin (related_party) WHERE (related_party IS NOT NULL);


--
-- Name: idx_incidents_reports_to_user_ids; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_reports_to_user_ids ON public.incidents USING gin (reports_to_user_ids);


--
-- Name: idx_incidents_resolution_report; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_resolution_report ON public.incidents USING gin (resolution_report) WHERE (resolution_report IS NOT NULL);


--
-- Name: idx_incidents_resolution_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_resolution_status ON public.incidents USING btree (resolution_status);


--
-- Name: idx_incidents_violation_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incidents_violation_id ON public.incidents USING btree (violation_id);


--
-- Name: incidents incidents_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: incidents incidents_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id);


--
-- Name: incidents incidents_incident_type_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_incident_type_id_fkey FOREIGN KEY (incident_type_id) REFERENCES public.incident_types(id);


--
-- Name: incidents incidents_violation_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_violation_id_fkey FOREIGN KEY (violation_id) REFERENCES public.warning_violation(id);


--
-- Name: incidents Allow all access to incidents; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to incidents" ON public.incidents USING (true) WITH CHECK (true);


--
-- Name: incidents; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;