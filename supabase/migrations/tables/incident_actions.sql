--
-- Name: incident_actions; Type: TABLE; Schema: public;
--

CREATE TABLE public.incident_actions (
    id text DEFAULT ('ACT'::text || nextval('public.incident_actions_id_seq'::regclass)) NOT NULL,
    action_type text NOT NULL,
    recourse_type text,
    action_report jsonb,
    has_fine boolean DEFAULT false,
    fine_amount numeric(10,2) DEFAULT 0,
    fine_threat_amount numeric(10,2) DEFAULT 0,
    is_paid boolean DEFAULT false,
    paid_at timestamp with time zone,
    paid_by text,
    employee_id text NOT NULL,
    incident_id text NOT NULL,
    incident_type_id text,
    created_by text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT incident_actions_action_type_check CHECK ((action_type = ANY (ARRAY['warning'::text, 'investigation'::text, 'termination'::text, 'other'::text]))),
    CONSTRAINT incident_actions_recourse_type_check CHECK ((recourse_type = ANY (ARRAY['warning'::text, 'warning_fine'::text, 'warning_fine_threat'::text, 'warning_fine_termination_threat'::text, 'termination'::text])))
);


--
-- Name: incident_actions incident_actions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_pkey PRIMARY KEY (id);


--
-- Name: idx_incident_actions_action_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_actions_action_type ON public.incident_actions USING btree (action_type);


--
-- Name: idx_incident_actions_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_actions_employee_id ON public.incident_actions USING btree (employee_id);


--
-- Name: idx_incident_actions_has_fine; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_actions_has_fine ON public.incident_actions USING btree (has_fine);


--
-- Name: idx_incident_actions_incident_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_actions_incident_id ON public.incident_actions USING btree (incident_id);


--
-- Name: idx_incident_actions_is_paid; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_actions_is_paid ON public.incident_actions USING btree (is_paid);


--
-- Name: incident_actions incident_actions_incident_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: incident_actions incident_actions_incident_type_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_incident_type_id_fkey FOREIGN KEY (incident_type_id) REFERENCES public.incident_types(id);


--
-- Name: incident_actions Allow all access to incident_actions; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to incident_actions" ON public.incident_actions USING (true) WITH CHECK (true);


--
-- Name: incident_actions; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.incident_actions ENABLE ROW LEVEL SECURITY;