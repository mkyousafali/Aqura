--
-- Name: branches; Type: TABLE; Schema: public;
--

CREATE TABLE public.branches (
    id bigint NOT NULL,
    name_en character varying(255) NOT NULL,
    name_ar character varying(255) NOT NULL,
    location_en character varying(500) NOT NULL,
    location_ar character varying(500) NOT NULL,
    is_active boolean DEFAULT true,
    is_main_branch boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by bigint,
    updated_by bigint,
    vat_number character varying(50),
    delivery_service_enabled boolean DEFAULT true NOT NULL,
    pickup_service_enabled boolean DEFAULT true NOT NULL,
    minimum_order_amount numeric(10,2) DEFAULT 15.00,
    is_24_hours boolean DEFAULT true,
    operating_start_time time without time zone,
    operating_end_time time without time zone,
    delivery_message_ar text,
    delivery_message_en text,
    delivery_is_24_hours boolean DEFAULT true,
    delivery_start_time time without time zone,
    delivery_end_time time without time zone,
    pickup_is_24_hours boolean DEFAULT true,
    pickup_start_time time without time zone,
    pickup_end_time time without time zone,
    location_url text,
    latitude double precision,
    longitude double precision,
    CONSTRAINT check_vat_number_not_empty CHECK (((vat_number IS NULL) OR (length(TRIM(BOTH FROM vat_number)) > 0)))
);


--
-- Name: branches_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.branches_id_seq OWNED BY public.branches.id;


--
-- Name: branches id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.branches ALTER COLUMN id SET DEFAULT nextval('public.branches_id_seq'::regclass);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: idx_branches_active; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branches_active ON public.branches USING btree (is_active);


--
-- Name: idx_branches_main; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branches_main ON public.branches USING btree (is_main_branch);


--
-- Name: idx_branches_name_ar; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branches_name_ar ON public.branches USING btree (name_ar);


--
-- Name: idx_branches_name_en; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branches_name_en ON public.branches USING btree (name_en);


--
-- Name: idx_branches_vat_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_branches_vat_number ON public.branches USING btree (vat_number) WHERE (vat_number IS NOT NULL);


--
-- Name: branches branches_notify_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER branches_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.notify_branches_change();


--
-- Name: branches trigger_update_branches_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_branches_updated_at BEFORE UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.update_branches_updated_at();


--
-- Name: branches allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.branches FOR DELETE USING (true);


--
-- Name: branches allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.branches FOR INSERT WITH CHECK (true);


--
-- Name: branches allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.branches FOR SELECT USING (true);


--
-- Name: branches allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.branches FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: branches; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;


--
-- Name: branches rls_delete; Type: POLICY; Schema: public;
--

CREATE POLICY rls_delete ON public.branches FOR DELETE USING (true);


--
-- Name: branches rls_insert; Type: POLICY; Schema: public;
--

CREATE POLICY rls_insert ON public.branches FOR INSERT WITH CHECK (true);


--
-- Name: branches rls_select; Type: POLICY; Schema: public;
--

CREATE POLICY rls_select ON public.branches FOR SELECT USING (true);


--
-- Name: branches rls_update; Type: POLICY; Schema: public;
--

CREATE POLICY rls_update ON public.branches FOR UPDATE WITH CHECK (true);