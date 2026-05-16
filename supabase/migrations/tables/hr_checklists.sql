--
-- Name: hr_checklists; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_checklists (
    id character varying(20) DEFAULT ('CL'::text || nextval('public.hr_checklists_id_seq'::regclass)) NOT NULL,
    checklist_name_en text,
    checklist_name_ar text,
    question_ids jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: hr_checklists hr_checklists_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_checklists
    ADD CONSTRAINT hr_checklists_pkey PRIMARY KEY (id);


--
-- Name: idx_hr_checklists_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_checklists_created ON public.hr_checklists USING btree (created_at DESC);


--
-- Name: hr_checklists hr_checklists_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER hr_checklists_timestamp_update BEFORE UPDATE ON public.hr_checklists FOR EACH ROW EXECUTE FUNCTION public.update_hr_checklists_timestamp();


--
-- Name: hr_checklists Allow all access to hr_checklists; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to hr_checklists" ON public.hr_checklists USING (true) WITH CHECK (true);


--
-- Name: hr_checklists; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_checklists ENABLE ROW LEVEL SECURITY;