--
-- Name: user_theme_assignments; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_theme_assignments (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    theme_id integer NOT NULL,
    assigned_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: user_theme_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.user_theme_assignments_id_seq OWNED BY public.user_theme_assignments.id;


--
-- Name: user_theme_assignments id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments ALTER COLUMN id SET DEFAULT nextval('public.user_theme_assignments_id_seq'::regclass);


--
-- Name: user_theme_assignments user_theme_assignments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_pkey PRIMARY KEY (id);


--
-- Name: user_theme_assignments user_theme_assignments_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_user_id_key UNIQUE (user_id);


--
-- Name: idx_user_theme_assignments_theme_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_theme_assignments_theme_id ON public.user_theme_assignments USING btree (theme_id);


--
-- Name: idx_user_theme_assignments_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_theme_assignments_user_id ON public.user_theme_assignments USING btree (user_id);


--
-- Name: user_theme_assignments user_theme_assignments_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER user_theme_assignments_timestamp_update BEFORE UPDATE ON public.user_theme_assignments FOR EACH ROW EXECUTE FUNCTION public.update_user_theme_assignments_timestamp();


--
-- Name: user_theme_assignments user_theme_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_theme_assignments user_theme_assignments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.desktop_themes(id) ON DELETE CASCADE;


--
-- Name: user_theme_assignments user_theme_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_theme_assignments Allow all access to user_theme_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to user_theme_assignments" ON public.user_theme_assignments USING (true) WITH CHECK (true);


--
-- Name: user_theme_assignments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_theme_assignments ENABLE ROW LEVEL SECURITY;