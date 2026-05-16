--
-- Name: branch_sync_config; Type: TABLE; Schema: public;
--

CREATE TABLE public.branch_sync_config (
    id bigint NOT NULL,
    branch_id bigint NOT NULL,
    local_supabase_url text NOT NULL,
    local_supabase_key text NOT NULL,
    is_active boolean DEFAULT true,
    last_sync_at timestamp with time zone,
    last_sync_status text,
    last_sync_details jsonb DEFAULT '{}'::jsonb,
    sync_tables text[] DEFAULT ARRAY['branches'::text, 'users'::text, 'user_sessions'::text, 'user_device_sessions'::text, 'button_permissions'::text, 'sidebar_buttons'::text, 'button_main_sections'::text, 'button_sub_sections'::text, 'interface_permissions'::text, 'user_favorite_buttons'::text, 'erp_synced_products'::text, 'product_categories'::text, 'products'::text, 'product_units'::text, 'offers'::text, 'offer_products'::text, 'offer_names'::text, 'offer_bundles'::text, 'offer_cart_tiers'::text, 'bogo_offer_rules'::text, 'flyer_offers'::text, 'flyer_offer_products'::text, 'customers'::text, 'privilege_cards_master'::text, 'privilege_cards_branch'::text, 'desktop_themes'::text, 'user_theme_assignments'::text, 'erp_connections'::text, 'erp_sync_logs'::text],
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tunnel_url text,
    ssh_user text DEFAULT 'u'::text,
    CONSTRAINT branch_sync_config_last_sync_status_check CHECK ((last_sync_status = ANY (ARRAY['success'::text, 'failed'::text, 'in_progress'::text])))
);


--
-- Name: branch_sync_config branch_sync_config_branch_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_branch_id_key UNIQUE (branch_id);


--
-- Name: branch_sync_config branch_sync_config_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_pkey PRIMARY KEY (id);


--
-- Name: branch_sync_config branch_sync_config_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_sync_config; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.branch_sync_config ENABLE ROW LEVEL SECURITY;


--
-- Name: branch_sync_config branch_sync_config_modify; Type: POLICY; Schema: public;
--

CREATE POLICY branch_sync_config_modify ON public.branch_sync_config TO authenticated USING (true) WITH CHECK (true);


--
-- Name: branch_sync_config branch_sync_config_select; Type: POLICY; Schema: public;
--

CREATE POLICY branch_sync_config_select ON public.branch_sync_config FOR SELECT TO authenticated USING (true);