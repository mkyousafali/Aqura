--
-- Name: incident_types; Type: TABLE; Schema: public;
--

CREATE TABLE public.incident_types (
    id text NOT NULL,
    incident_type_en text NOT NULL,
    incident_type_ar text NOT NULL,
    description_en text,
    description_ar text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: incident_types incident_types_incident_type_ar_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_incident_type_ar_key UNIQUE (incident_type_ar);


--
-- Name: incident_types incident_types_incident_type_en_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_incident_type_en_key UNIQUE (incident_type_en);


--
-- Name: incident_types incident_types_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_pkey PRIMARY KEY (id);


--
-- Name: idx_incident_types_is_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_incident_types_is_active ON public.incident_types USING btree (is_active) WHERE (is_active = true);


--
-- Name: incident_types Allow all access to incident_types; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to incident_types" ON public.incident_types USING (true) WITH CHECK (true);


--
-- Name: incident_types; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.incident_types ENABLE ROW LEVEL SECURITY;