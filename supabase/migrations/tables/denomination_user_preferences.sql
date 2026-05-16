--
-- Name: denomination_user_preferences; Type: TABLE; Schema: public;
--

CREATE TABLE public.denomination_user_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    default_branch_id integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: denomination_user_preferences denomination_user_preferences_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_pkey PRIMARY KEY (id);


--
-- Name: denomination_user_preferences denomination_user_preferences_user_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_user_id_key UNIQUE (user_id);


--
-- Name: idx_denomination_user_preferences_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_denomination_user_preferences_user_id ON public.denomination_user_preferences USING btree (user_id);


--
-- Name: denomination_user_preferences denomination_user_preferences_default_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: denomination_user_preferences denomination_user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;