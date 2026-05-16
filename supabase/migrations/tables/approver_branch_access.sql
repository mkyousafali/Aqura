--
-- Name: approver_branch_access; Type: TABLE; Schema: public;
--

CREATE TABLE public.approver_branch_access (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    branch_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT approver_branch_access_active_check CHECK (((is_active = true) OR (is_active = false)))
);


--
-- Name: approver_branch_access_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.approver_branch_access_id_seq OWNED BY public.approver_branch_access.id;


--
-- Name: approver_branch_access id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access ALTER COLUMN id SET DEFAULT nextval('public.approver_branch_access_id_seq'::regclass);


--
-- Name: approver_branch_access approver_branch_access_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_pkey PRIMARY KEY (id);


--
-- Name: approver_branch_access approver_branch_access_user_id_branch_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_user_id_branch_id_key UNIQUE (user_id, branch_id);


--
-- Name: idx_approver_branch_access_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_branch_access_active ON public.approver_branch_access USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approver_branch_access_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_branch_access_branch_id ON public.approver_branch_access USING btree (branch_id);


--
-- Name: idx_approver_branch_access_user_branch; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_branch_access_user_branch ON public.approver_branch_access USING btree (user_id, branch_id);


--
-- Name: idx_approver_branch_access_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_branch_access_user_id ON public.approver_branch_access USING btree (user_id);


--
-- Name: approver_branch_access approver_branch_access_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: approver_branch_access approver_branch_access_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_branch_access approver_branch_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: approver_branch_access Allow all access to approver_branch_access; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to approver_branch_access" ON public.approver_branch_access USING (true) WITH CHECK (true);


--
-- Name: approver_branch_access; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.approver_branch_access ENABLE ROW LEVEL SECURITY;