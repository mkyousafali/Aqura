--
-- Name: social_links; Type: TABLE; Schema: public;
--

CREATE TABLE public.social_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id bigint NOT NULL,
    facebook text,
    whatsapp text,
    instagram text,
    tiktok text,
    snapchat text,
    website text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    location_link text,
    facebook_clicks bigint DEFAULT 0,
    whatsapp_clicks bigint DEFAULT 0,
    instagram_clicks bigint DEFAULT 0,
    tiktok_clicks bigint DEFAULT 0,
    snapchat_clicks bigint DEFAULT 0,
    website_clicks bigint DEFAULT 0,
    location_link_clicks bigint DEFAULT 0
);


--
-- Name: social_links social_links_branch_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT social_links_branch_id_key UNIQUE (branch_id);


--
-- Name: social_links social_links_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT social_links_pkey PRIMARY KEY (id);


--
-- Name: idx_social_links_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_social_links_branch_id ON public.social_links USING btree (branch_id);


--
-- Name: social_links social_links_updated_at_trigger; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER social_links_updated_at_trigger BEFORE UPDATE ON public.social_links FOR EACH ROW EXECUTE FUNCTION public.update_social_links_updated_at();


--
-- Name: social_links fk_social_links_branch; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT fk_social_links_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: social_links Enable all access for social_links; Type: POLICY; Schema: public;
--

CREATE POLICY "Enable all access for social_links" ON public.social_links USING (true) WITH CHECK (true);


--
-- Name: social_links; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.social_links ENABLE ROW LEVEL SECURITY;