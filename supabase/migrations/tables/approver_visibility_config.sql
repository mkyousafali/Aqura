--
-- Name: approver_visibility_config; Type: TABLE; Schema: public;
--

CREATE TABLE public.approver_visibility_config (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    visibility_type character varying(50) DEFAULT 'global'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    updated_by uuid,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT approver_visibility_type_check CHECK (((visibility_type)::text = ANY ((ARRAY['global'::character varying, 'branch_specific'::character varying, 'multiple_branches'::character varying])::text[])))
);


--
-- Name: approver_visibility_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.approver_visibility_config_id_seq OWNED BY public.approver_visibility_config.id;


--
-- Name: approver_visibility_config id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config ALTER COLUMN id SET DEFAULT nextval('public.approver_visibility_config_id_seq'::regclass);


--
-- Name: approver_visibility_config approver_visibility_config_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_pkey PRIMARY KEY (id);


--
-- Name: approver_visibility_config approver_visibility_config_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_user_id_key UNIQUE (user_id);


--
-- Name: idx_approver_visibility_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_visibility_active ON public.approver_visibility_config USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approver_visibility_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_visibility_type ON public.approver_visibility_config USING btree (visibility_type);


--
-- Name: idx_approver_visibility_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_approver_visibility_user_id ON public.approver_visibility_config USING btree (user_id);


--
-- Name: approver_visibility_config approver_visibility_config_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER approver_visibility_config_timestamp_update BEFORE UPDATE ON public.approver_visibility_config FOR EACH ROW EXECUTE FUNCTION public.update_approver_visibility_config_timestamp();


--
-- Name: approver_visibility_config approver_visibility_config_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_visibility_config approver_visibility_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_visibility_config approver_visibility_config_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: approver_visibility_config Allow all access to approver_visibility_config; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to approver_visibility_config" ON public.approver_visibility_config USING (true) WITH CHECK (true);


--
-- Name: approver_visibility_config; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.approver_visibility_config ENABLE ROW LEVEL SECURITY;