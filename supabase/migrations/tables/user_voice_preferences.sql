--
-- Name: user_voice_preferences; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_voice_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    locale text NOT NULL,
    voice_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_voice_preferences_locale_check CHECK ((locale = ANY (ARRAY['en'::text, 'ar'::text])))
);


--
-- Name: user_voice_preferences user_voice_preferences_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_voice_preferences
    ADD CONSTRAINT user_voice_preferences_pkey PRIMARY KEY (id);


--
-- Name: user_voice_preferences user_voice_preferences_user_id_locale_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_voice_preferences
    ADD CONSTRAINT user_voice_preferences_user_id_locale_key UNIQUE (user_id, locale);


--
-- Name: idx_user_voice_preferences_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_user_voice_preferences_user_id ON public.user_voice_preferences USING btree (user_id);


--
-- Name: user_voice_preferences Allow all access to user_voice_preferences; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to user_voice_preferences" ON public.user_voice_preferences USING (true) WITH CHECK (true);


--
-- Name: user_voice_preferences Allow all operations for authenticated users; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all operations for authenticated users" ON public.user_voice_preferences TO authenticated USING (true) WITH CHECK (true);


--
-- Name: user_voice_preferences; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.user_voice_preferences ENABLE ROW LEVEL SECURITY;