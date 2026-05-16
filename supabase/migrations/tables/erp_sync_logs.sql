--
-- Name: erp_sync_logs; Type: TABLE; Schema: public;
--

CREATE TABLE public.erp_sync_logs (
    id integer NOT NULL,
    sync_type text DEFAULT 'auto'::text NOT NULL,
    branches_total integer DEFAULT 0,
    branches_success integer DEFAULT 0,
    branches_failed integer DEFAULT 0,
    products_fetched integer DEFAULT 0,
    products_inserted integer DEFAULT 0,
    products_updated integer DEFAULT 0,
    duration_ms integer DEFAULT 0,
    details jsonb,
    triggered_by text DEFAULT 'pg_cron'::text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: erp_sync_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.erp_sync_logs_id_seq OWNED BY public.erp_sync_logs.id;


--
-- Name: erp_sync_logs id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.erp_sync_logs ALTER COLUMN id SET DEFAULT nextval('public.erp_sync_logs_id_seq'::regclass);


--
-- Name: erp_sync_logs erp_sync_logs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.erp_sync_logs
    ADD CONSTRAINT erp_sync_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_erp_sync_logs_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_erp_sync_logs_created_at ON public.erp_sync_logs USING btree (created_at DESC);


--
-- Name: erp_sync_logs Service role full access on erp_sync_logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Service role full access on erp_sync_logs" ON public.erp_sync_logs USING (true) WITH CHECK (true);


--
-- Name: erp_sync_logs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;