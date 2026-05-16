--
-- Name: hr_salary_notes; Type: TABLE; Schema: public;
--

CREATE TABLE public.hr_salary_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id text NOT NULL,
    note_type text NOT NULL,
    note_text text NOT NULL,
    from_date date,
    to_date date,
    until_date date,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_salary_notes_note_type_check CHECK ((note_type = ANY (ARRAY['common'::text, 'specific_period'::text, 'until_date'::text])))
);


--
-- Name: hr_salary_notes hr_salary_notes_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_pkey PRIMARY KEY (id);


--
-- Name: idx_hr_salary_notes_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_salary_notes_created_at ON public.hr_salary_notes USING btree (created_at DESC);


--
-- Name: idx_hr_salary_notes_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_hr_salary_notes_employee_id ON public.hr_salary_notes USING btree (employee_id);


--
-- Name: hr_salary_notes trg_hr_salary_notes_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trg_hr_salary_notes_updated_at BEFORE UPDATE ON public.hr_salary_notes FOR EACH ROW EXECUTE FUNCTION public.set_hr_salary_notes_updated_at();


--
-- Name: hr_salary_notes hr_salary_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: hr_salary_notes hr_salary_notes_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_salary_notes; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.hr_salary_notes ENABLE ROW LEVEL SECURITY;


--
-- Name: hr_salary_notes hr_salary_notes_delete; Type: POLICY; Schema: public;
--

CREATE POLICY hr_salary_notes_delete ON public.hr_salary_notes FOR DELETE TO authenticated USING (true);


--
-- Name: hr_salary_notes hr_salary_notes_insert; Type: POLICY; Schema: public;
--

CREATE POLICY hr_salary_notes_insert ON public.hr_salary_notes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: hr_salary_notes hr_salary_notes_select; Type: POLICY; Schema: public;
--

CREATE POLICY hr_salary_notes_select ON public.hr_salary_notes FOR SELECT TO authenticated USING (true);