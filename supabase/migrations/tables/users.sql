--
-- Name: users; Type: TABLE; Schema: public;
--

CREATE TABLE public.users (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    salt character varying(100) NOT NULL,
    quick_access_code character varying(255) NOT NULL,
    quick_access_salt character varying(100) NOT NULL,
    user_type public.user_type_enum DEFAULT 'branch_specific'::public.user_type_enum NOT NULL,
    employee_id uuid,
    branch_id bigint,
    position_id uuid,
    avatar text,
    avatar_small_url text,
    avatar_medium_url text,
    avatar_large_url text,
    is_first_login boolean DEFAULT true,
    failed_login_attempts integer DEFAULT 0,
    locked_at timestamp with time zone,
    locked_by uuid,
    last_login_at timestamp with time zone,
    password_expires_at timestamp with time zone,
    last_password_change timestamp with time zone DEFAULT now(),
    created_by bigint,
    updated_by bigint,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    ai_translation_enabled boolean DEFAULT false NOT NULL,
    is_master_admin boolean DEFAULT false,
    is_admin boolean DEFAULT false,
    CONSTRAINT users_employee_branch_check CHECK (((user_type = 'global'::public.user_type_enum) OR ((user_type = 'branch_specific'::public.user_type_enum) AND (branch_id IS NOT NULL))))
);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_quick_access_code_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_quick_access_code_key UNIQUE (quick_access_code);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_users_ai_translation_enabled; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_ai_translation_enabled ON public.users USING btree (ai_translation_enabled);


--
-- Name: idx_users_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_branch_id ON public.users USING btree (branch_id);


--
-- Name: idx_users_branch_lookup; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_branch_lookup ON public.users USING btree (branch_id) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_users_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_created_at ON public.users USING btree (created_at);


--
-- Name: idx_users_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_employee_id ON public.users USING btree (employee_id);


--
-- Name: idx_users_employee_lookup; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_employee_lookup ON public.users USING btree (employee_id) WHERE (employee_id IS NOT NULL);


--
-- Name: idx_users_is_admin; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_is_admin ON public.users USING btree (is_admin);


--
-- Name: idx_users_is_master_admin; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_is_master_admin ON public.users USING btree (is_master_admin);


--
-- Name: idx_users_last_login; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_last_login ON public.users USING btree (last_login_at);


--
-- Name: idx_users_position_lookup; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_position_lookup ON public.users USING btree (position_id) WHERE (position_id IS NOT NULL);


--
-- Name: idx_users_quick_access; Type: INDEX; Schema: public;
--

CREATE UNIQUE INDEX idx_users_quick_access ON public.users USING btree (quick_access_code);


--
-- Name: idx_users_username; Type: INDEX; Schema: public;
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: users trigger_create_default_interface_permissions; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_create_default_interface_permissions AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.create_default_interface_permissions();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users users_audit_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER users_audit_trigger AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.log_user_action();


--
-- Name: users users_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: users users_employee_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employees(id) ON DELETE SET NULL;


--
-- Name: users users_locked_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES public.users(id);


--
-- Name: users Allow all users to view users table; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all users to view users table" ON public.users FOR SELECT USING (true);


--
-- Name: users Allow anon insert users; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert users" ON public.users FOR INSERT TO anon WITH CHECK (true);


--
-- Name: users Allow service role full access to users; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow service role full access to users" ON public.users TO authenticated USING (true) WITH CHECK (true);


--
-- Name: users allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.users USING (true) WITH CHECK (true);


--
-- Name: users allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.users FOR DELETE USING (true);


--
-- Name: users allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.users FOR INSERT WITH CHECK (true);


--
-- Name: users allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.users FOR SELECT USING (true);


--
-- Name: users allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.users FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: users anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.users USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: users authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.users USING ((auth.uid() IS NOT NULL));


--
-- Name: users; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;