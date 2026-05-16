--
-- Name: cashier_device_bindings; Type: TABLE; Schema: public;
--

CREATE TABLE public.cashier_device_bindings (
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    device_name text,
    app_kind text DEFAULT 'windows'::text NOT NULL,
    session_token text NOT NULL,
    bound_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cashier_device_bindings cashier_device_bindings_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.cashier_device_bindings
    ADD CONSTRAINT cashier_device_bindings_pkey PRIMARY KEY (user_id);


--
-- Name: idx_cashier_device_bindings_device; Type: INDEX; Schema: public;
--

CREATE INDEX idx_cashier_device_bindings_device ON public.cashier_device_bindings USING btree (device_id);


--
-- Name: cashier_device_bindings cashier_bindings_select; Type: POLICY; Schema: public;
--

CREATE POLICY cashier_bindings_select ON public.cashier_device_bindings FOR SELECT USING (true);


--
-- Name: cashier_device_bindings; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.cashier_device_bindings ENABLE ROW LEVEL SECURITY;