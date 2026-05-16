--
-- Name: user_favorite_buttons; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_favorite_buttons (
    id text NOT NULL,
    employee_id text,
    user_id uuid NOT NULL,
    favorite_config jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_favorite_buttons unique_user_favorite; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_favorite_buttons
    ADD CONSTRAINT unique_user_favorite UNIQUE (user_id);


--
-- Name: user_favorite_buttons user_favorite_buttons_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_favorite_buttons
    ADD CONSTRAINT user_favorite_buttons_pkey PRIMARY KEY (id);


--
-- Name: idx_user_favorite_buttons_employee_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_favorite_buttons_employee_id ON public.user_favorite_buttons USING btree (employee_id);


--
-- Name: idx_user_favorite_buttons_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_favorite_buttons_user_id ON public.user_favorite_buttons USING btree (user_id);


--
-- Name: user_favorite_buttons Allow all access to user_favorite_buttons; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to user_favorite_buttons" ON public.user_favorite_buttons USING (true) WITH CHECK (true);


--
-- Name: user_favorite_buttons; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_favorite_buttons ENABLE ROW LEVEL SECURITY;