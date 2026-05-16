--
-- Name: system_api_keys; Type: TABLE; Schema: public;
--

CREATE TABLE public.system_api_keys (
    id integer NOT NULL,
    service_name character varying(100) NOT NULL,
    api_key text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: system_api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.system_api_keys_id_seq OWNED BY public.system_api_keys.id;


--
-- Name: system_api_keys id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.system_api_keys ALTER COLUMN id SET DEFAULT nextval('public.system_api_keys_id_seq'::regclass);


--
-- Name: system_api_keys system_api_keys_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.system_api_keys
    ADD CONSTRAINT system_api_keys_pkey PRIMARY KEY (id);


--
-- Name: system_api_keys system_api_keys_service_name_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.system_api_keys
    ADD CONSTRAINT system_api_keys_service_name_key UNIQUE (service_name);


--
-- Name: idx_system_api_keys_service_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_system_api_keys_service_name ON public.system_api_keys USING btree (service_name);


--
-- Name: system_api_keys system_api_keys_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER system_api_keys_timestamp_update BEFORE UPDATE ON public.system_api_keys FOR EACH ROW EXECUTE FUNCTION public.update_system_api_keys_timestamp();


--
-- Name: system_api_keys Enable all access to system_api_keys; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable all access to system_api_keys" ON public.system_api_keys USING (true) WITH CHECK (true);


--
-- Name: system_api_keys; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.system_api_keys ENABLE ROW LEVEL SECURITY;