--
-- Name: user_mobile_theme_assignments; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_mobile_theme_assignments (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    theme_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    color_overrides jsonb
);


--
-- Name: user_mobile_theme_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.user_mobile_theme_assignments_id_seq OWNED BY public.user_mobile_theme_assignments.id;


--
-- Name: user_mobile_theme_assignments id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.user_mobile_theme_assignments ALTER COLUMN id SET DEFAULT nextval('public.user_mobile_theme_assignments_id_seq'::regclass);


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_pkey PRIMARY KEY (id);


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_user_id_key UNIQUE (user_id);


--
-- Name: idx_user_mobile_theme_assignments_theme_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_mobile_theme_assignments_theme_id ON public.user_mobile_theme_assignments USING btree (theme_id);


--
-- Name: idx_user_mobile_theme_assignments_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_mobile_theme_assignments_user_id ON public.user_mobile_theme_assignments USING btree (user_id);


--
-- Name: idx_user_theme_overrides; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_theme_overrides ON public.user_mobile_theme_assignments USING btree (user_id) WHERE (color_overrides IS NOT NULL);


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.mobile_themes(id) ON DELETE CASCADE;


--
-- Name: user_mobile_theme_assignments Allow all access to user_mobile_theme_assignments; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to user_mobile_theme_assignments" ON public.user_mobile_theme_assignments USING (true) WITH CHECK (true);


--
-- Name: user_mobile_theme_assignments; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_mobile_theme_assignments ENABLE ROW LEVEL SECURITY;